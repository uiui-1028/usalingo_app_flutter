import SwiftUI

/// 学習タブの空き枠から開く、公式デッキを1つ選んで追加する画面。
///
/// 上にジャンルのセグメント、真ん中に学習タブと同じ縦のカルーセル、下に標準のシートを置く。
/// シートは頭（収録語数・容量・レベル）と約7割（詳しい情報と単語一覧）の2段で、中身はカルーセルの
/// 中央のデッキに合わせて変わる。要件は docs/plans/deck-gallery-redesign-requirements.md。
/// 追加できたら `onAdded` にサーバーのデッキ番号を渡す。戻るのは呼び出し側が決める。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onAdded: (Int) -> Void

    @State private var genre = GalleryGenre.exam
    @State private var decks: [OfficialDeck] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    /// カルーセルの中央にいるデッキ（サーバーの番号）。
    @State private var selectedId: Int?
    /// デッキごとの収録カード。読めなかったデッキは入らない。
    @State private var cardsByDeck: [Int: [WordCard]] = [:]
    @State private var covers: [Int: URL] = [:]
    /// 学習タブにある公式デッキ（端末の番号）ごとの、サーバーの単語番号。重なる語数を数えるのに使う。
    @State private var ownedWords: [Int: Set<Int>] = [:]
    @State private var isSheetPresented = false
    @State private var detent = GallerySheetDetent.peek
    @State private var isDownloading = false
    @State private var downloadMessage: String?
    /// シートを閉じ切ってから行うこと。シートを出したまま戻ると、画面だけが先に消えてしまう。
    @State private var afterSheetDismiss: (() -> Void)?

    private var genreDecks: [OfficialDeck] { decks.filter(genre.contains) }
    private var selectedDeck: OfficialDeck? { genreDecks.first { $0.id == selectedId } }
    /// シートが7割まで上がっている。カードを1枚だけ上に出し、回せなくする。
    private var isFocused: Bool { detent == GallerySheetDetent.expanded }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content(in: proxy)
                if !isFocused {
                    topBar
                        .padding(.horizontal, WireMetrics.screenPadding)
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: isFocused)
        }
        .background(WireColor.background)
        .toolbar(.hidden, for: .navigationBar)
        // ヘッダーを隠すと戻るスワイプも止まるので、ほかの画面と同じ仕組みで戻す。
        .background { BackSwipeEnabler(canBegin: { !isFocused }) }
        .sheet(isPresented: $isSheetPresented, onDismiss: runAfterSheetDismiss) { sheet }
        .task { await reload() }
        .onChange(of: genre) { _, _ in selectFirstDeckIfNeeded() }
        .onChange(of: selectedDeck?.id) { _, _ in updateSheetPresence() }
        .onChange(of: selectedId) { _, _ in downloadMessage = nil }
        .onDisappear { isSheetPresented = false }
    }

    // MARK: - 画面

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if loadFailed || genreDecks.isEmpty {
            GalleryUnavailableBoard { Task { await reload() } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let peekCover = max(0, GallerySheetDetent.peekHeight - proxy.safeAreaInsets.bottom)
            let areaHeight = proxy.size.height - peekCover
            DeckGalleryCarousel(
                decks: genreDecks,
                selectedId: selectedId,
                covers: covers,
                isLocked: isFocused,
                onSelect: { selectedId = $0.id },
                onOpen: { detent = GallerySheetDetent.expanded }
            )
            .padding(.horizontal, WireMetrics.screenPadding)
            .frame(height: areaHeight)
            .modifier(FocusedCardPlacement(isFocused: isFocused, areaHeight: areaHeight, proxy: proxy))
        }
    }

    /// 左に戻るアイコン、右にジャンルのセグメント。どちらもカルーセルの上に浮かぶガラスの板。
    private var topBar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button(action: leave) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(WireColor.ink)
                    .frame(width: 56, height: 56)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .glassBarSurface(in: Circle())
            .accessibilityLabel("戻る")

            SegmentSlider(items: GalleryGenre.allCases, selection: $genre, title: \.rawValue) { genre in
                Text(genre.rawValue).wireFont(.label)
            }
            .frame(height: 48)
            .padding(WireMetrics.spacingXS)
            .glassBarSurface(in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("ジャンル")
        }
        .padding(.top, WireMetrics.spacingXS)
    }

    @ViewBuilder
    private var sheet: some View {
        Group {
            if let deck = selectedDeck {
                DeckGallerySheet(
                    deck: deck,
                    words: cardsByDeck[deck.id],
                    overlap: overlapCount(for: deck),
                    isDownloading: isDownloading,
                    message: downloadMessage,
                    isExpanded: isFocused,
                    onDownload: { download(deck) }
                )
            } else {
                Color.clear
            }
        }
        .presentationDetents([GallerySheetDetent.peek, GallerySheetDetent.expanded], selection: $detent)
        // 7割でも後ろを暗くしない。上に出したカードを明るいまま見せる。カルーセルは7割の間は止めてある。
        .presentationBackgroundInteraction(.enabled)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }

    // MARK: - 動き

    private func leave() {
        afterSheetDismiss = { dismiss() }
        if isSheetPresented {
            isSheetPresented = false
        } else {
            runAfterSheetDismiss()
        }
    }

    private func runAfterSheetDismiss() {
        let action = afterSheetDismiss
        afterSheetDismiss = nil
        action?()
    }

    /// 選べるデッキがあるときだけシートを出す。無いときは看板だけを見せる。
    private func updateSheetPresence() {
        let shouldPresent = selectedDeck != nil && afterSheetDismiss == nil
        if !shouldPresent { detent = GallerySheetDetent.peek }
        if isSheetPresented != shouldPresent { isSheetPresented = shouldPresent }
    }

    private func selectFirstDeckIfNeeded() {
        detent = GallerySheetDetent.peek
        if selectedDeck == nil { selectedId = genreDecks.first?.id }
    }

    private func reload() async {
        isLoading = decks.isEmpty
        defer {
            isLoading = false
            selectFirstDeckIfNeeded()
            updateSheetPresence()
        }
        do {
            decks = try await appState.fetchOfficialDecks()
            loadFailed = false
        } catch {
            loadFailed = decks.isEmpty
            return
        }
        await loadOwnedWords()
        await loadCards()
    }

    /// デッキごとの収録カードを並行して読み、表紙を学習タブと同じ選び方で決める。
    /// ponytail: 表紙のために全デッキのカードを読む。デッキが増えて重くなったら、
    /// 表紙に使うイラストを decks の列で指定する形（要件 U5 の後続）に置き換える。
    private func loadCards() async {
        let ids = decks.map(\.id).filter { cardsByDeck[$0] == nil }
        await withTaskGroup(of: (Int, [WordCard]?).self) { group in
            for id in ids {
                group.addTask { [appState] in (id, try? await appState.fetchOfficialDeckCards(deckId: id)) }
            }
            let store = DeckCoverStore()
            for await (id, cards) in group {
                guard let cards else { continue }
                cardsByDeck[id] = cards
                // 端末は公式デッキのカード番号の符号を反転して持つ（`LocalStudyDataSource.makeCachedCard`）。
                // 学習タブと同じ1枚を選び、覚えた1枚を互いに上書きし合わないよう、同じ番号に直してから選ぶ。
                let cachedForm = cards.map { $0.withCardId($0.cardId.map { -$0 }) }
                covers[id] = store.coverURL(deckId: LocalStudyDataSource.cachedDeckId(remoteDeckId: id), cards: cachedForm)
            }
        }
    }

    private func loadOwnedWords() async {
        let dataSource = appState.localStudy
        guard let owned = try? await dataSource.fetchDecks() else { return }
        var words: [Int: Set<Int>] = [:]
        for deck in owned {
            guard let cards = try? await dataSource.fetchCards(deckId: deck.id) else { continue }
            // 公式デッキの単語は、サーバーの単語番号の符号を反転して持っている。元の番号に戻して比べる。
            // 端末で作ったデッキの単語は番号の体系が違い、サーバーの単語と突き合わせられないので数えない。
            words[deck.id] = Set(cards.filter { $0.wordId < 0 }.map { -$0.wordId })
        }
        ownedWords = words
    }

    private func overlapCount(for deck: OfficialDeck) -> Int? {
        guard let cards = cardsByDeck[deck.id] else { return nil }
        return DeckGalleryFacts.overlapCount(
            words: cards,
            ownedWords: ownedWords,
            excludingDeckId: LocalStudyDataSource.cachedDeckId(remoteDeckId: deck.id)
        )
    }

    private func download(_ deck: OfficialDeck) {
        guard !isDownloading, !deck.isAdded else { return }
        isDownloading = true
        downloadMessage = nil
        Task { @MainActor in
            defer { isDownloading = false }
            do {
                try await appState.addOfficialDeck(id: deck.id)
                afterSheetDismiss = { onAdded(deck.id) }
                isSheetPresented = false
            } catch {
                downloadMessage = UserFacingError.message(for: error)
            }
        }
    }
}

/// ジャンル。公式デッキを大きなくくりで分けるだけで、目立たせるデッキは作らない（要件 R1）。
enum GalleryGenre: String, CaseIterable {
    case exam = "大学受験"
    case toeic = "TOEIC"

    // ponytail: 公式デッキは今は大学受験向けだけなので、全部を大学受験に入れる。
    // TOEIC のデッキを配るときに decks へジャンルの列を足し、ここをその列で分ける。
    func contains(_ deck: OfficialDeck) -> Bool {
        self == .exam
    }
}

/// シートの止まる高さ。頭は収録語数・容量・レベルとダウンロードボタンが見える高さ。
enum GallerySheetDetent {
    static let peekHeight: CGFloat = 174
    static let peek = PresentationDetent.height(peekHeight)
    /// 上に出すカードの下端とシートの上端をなるべく近づけるため、7割より少し高く止める。
    static let expandedFraction: CGFloat = 0.72
    static let expanded = PresentationDetent.fraction(expandedFraction)
}

/// シートが上がったとき、中央のカードをシートの上の空きへ縮めて寄せる。隣の帯はカルーセルが隠す。
private struct FocusedCardPlacement: ViewModifier {
    let isFocused: Bool
    let areaHeight: CGFloat
    let proxy: GeometryProxy

    func body(content: Content) -> some View {
        let top = proxy.safeAreaInsets.top
        let screenHeight = proxy.size.height + top + proxy.safeAreaInsets.bottom
        // 割合で止めるシートの高さは、画面の上の安全域を除いた高さに対する割合になる。
        let sheetTop = screenHeight - (screenHeight - top) * GallerySheetDetent.expandedFraction - top
        let regionTop = WireMetrics.spacingS
        let regionBottom = sheetTop - WireMetrics.spacingS
        let scale = min(1, max(0.3, (regionBottom - regionTop) / DeckCarouselView.Metrics.expandedHeight))
        let offset = (regionTop + regionBottom) / 2 - areaHeight / 2
        content
            .scaleEffect(isFocused ? scale : 1)
            .offset(y: isFocused ? offset : 0)
    }
}

/// デッキが無いジャンルと、読み込めなかったときに出す看板（要件 G10）。
private struct GalleryUnavailableBoard: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: WireMetrics.spacingM) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(WireColor.ink)
                .accessibilityHidden(true)
            Text("読み込めません").wireFont(.titleS)
            Button("もう一度読み込む", action: onRetry)
                .buttonStyle(.bordered)
                .tint(WireColor.ink)
        }
        .padding(WireMetrics.spacingXL)
        .accessibilityIdentifier("galleryLoadMessage")
    }
}

// MARK: - カルーセル

/// デッキ追加画面の縦のカルーセル。動き（`AudioCarouselMotion`）と寸法は学習タブと同じで、
/// 空き枠・長押し・フォルダは持たない。中央のカードをタップすると `onOpen` を呼ぶ。
private struct DeckGalleryCarousel: View {
    private typealias Metrics = DeckCarouselView.Metrics

    let decks: [OfficialDeck]
    let selectedId: Int?
    let covers: [Int: URL]
    /// シートが7割のあいだは回さず、中央の1枚だけを見せる（要件 G1）。
    let isLocked: Bool
    let onSelect: (OfficialDeck) -> Void
    let onOpen: () -> Void

    private let layout = DeckCarouselLayout(
        bandHeight: Metrics.bandHeight,
        expandedHeight: Metrics.expandedHeight,
        spacing: Metrics.spacing
    )

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = AudioCarouselMotion()
    @State private var centerIndex = 0

    var body: some View {
        GeometryReader { proxy in
            let center = -motion.position / layout.stride
            ZStack {
                ForEach(Array(decks.enumerated()), id: \.element.id) { index, deck in
                    let offset = CGFloat(index) - center
                    let y = layout.y(offset: offset)
                    if abs(y) < proxy.size.height {
                        card(deck, index: index, expansion: layout.expansion(offset: offset),
                             width: proxy.size.width, height: layout.height(offset: offset))
                            .offset(y: y)
                            .zIndex(Double(layout.expansion(offset: offset)))
                            .opacity(isLocked && index != centerIndex ? 0 : 1)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture, including: isLocked ? .subviews : .all)
        }
        .onAppear(perform: synchronize)
        .onDisappear { motion.stop() }
        .onChange(of: decks.map(\.id)) { _, _ in synchronize() }
    }

    private func card(_ deck: OfficialDeck, index: Int, expansion: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (Metrics.bandWidthRatio + (1 - Metrics.bandWidthRatio) * expansion)
        // 追加済みは面を暗くして文字を白にする（要件 G6）。膜を文字の上に重ねると文字まで沈むので、面の色を変える。
        let textColor = deck.isAdded ? WireColor.surface : WireColor.ink
        return HStack(alignment: .top, spacing: WireMetrics.spacingM) {
            DeckCoverImage(url: covers[deck.id],
                           symbol: DeckCoverSymbol.forDeck(id: LocalStudyDataSource.cachedDeckId(remoteDeckId: deck.id)))
                .overlay {
                    if deck.isAdded {
                        RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    }
                }
                .frame(width: cardWidth * Metrics.coverWidthRatio)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(deck.deck.deckName)
                    .wireFont(expansion > 0.5 ? .titleS : .label, color: textColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let description = deck.deck.description {
                    Text(description)
                        .wireFont(.caption, color: deck.isAdded ? WireColor.surface.opacity(0.85) : WireColor.subText)
                        .lineLimit(2)
                        .opacity(Double(expansion))
                }
            }
            .padding(.vertical, WireMetrics.spacingS)
        }
        .padding(WireMetrics.spacingS)
        .frame(width: cardWidth, height: height, alignment: .topLeading)
        .clipped()
        .outlineSurface(radius: WireMetrics.radiusCard,
                        fill: deck.isAdded ? Color(white: 0.32) : BentoTone.l2.fill)
        .contentShape(Rectangle())
        .onTapGesture { index == centerIndex ? onOpen() : snap(to: index) }
        // ponytail: VoiceOver は中央の枠だけを読み、上下の操作で隣へ移すだけの最低限。
        .accessibilityElement(children: .combine)
        .accessibilityValue(deck.isAdded ? "追加済み" : "")
        .accessibilityAddTraits(.isButton)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: snap(to: centerIndex + 1)
            case .decrement: snap(to: centerIndex - 1)
            @unknown default: break
            }
        }
        .accessibilityHidden(index != centerIndex)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard decks.count > 1 else { return }
                if !motion.isDragging {
                    motion.beginDrag(at: value.time.timeIntervalSinceReferenceDate)
                }
                motion.drag(translation: value.translation.height, at: value.time.timeIntervalSinceReferenceDate)
            }
            .onEnded { value in
                guard motion.isDragging else { return }
                motion.endDrag(at: value.time.timeIntervalSinceReferenceDate,
                               animated: !reduceMotion, completion: complete)
            }
    }

    private func synchronize() {
        centerIndex = decks.firstIndex { $0.id == selectedId } ?? 0
        motion.configure(stride: layout.stride, count: decks.count, index: centerIndex)
        if decks.indices.contains(centerIndex) { onSelect(decks[centerIndex]) }
    }

    private func snap(to index: Int) {
        let target = min(max(0, index), decks.count - 1)
        guard target != centerIndex, !isLocked else { return }
        motion.snap(to: target, animated: !reduceMotion, completion: complete)
    }

    private func complete(at index: Int) {
        centerIndex = index
        onSelect(decks[index])
    }
}

// MARK: - シート

/// シートの中身。上に収録語数・容量・レベル、その下にほかの情報と、シート内シートの単語一覧。
/// ダウンロードボタンはタブバーと同じく地を持たずに下へ浮かべ、ボタンの周りは下の一覧が透ける。
private struct DeckGallerySheet: View {
    let deck: OfficialDeck
    let words: [WordCard]?
    let overlap: Int?
    let isDownloading: Bool
    let message: String?
    /// 7割まで上がっているか。頭だけのときは3項目だけを見せ、ボタンの周りに下の情報を透かさない。
    let isExpanded: Bool
    let onDownload: () -> Void

    /// 浮かべたボタンの下に、一覧の最後の行が隠れないよう空ける量。
    private static let footerClearance: CGFloat = 88

    var body: some View {
        VStack(spacing: WireMetrics.spacingL) {
            metrics
                .padding(.horizontal, WireMetrics.screenPadding)
                .padding(.top, WireMetrics.spacingXL)
            // 残りの高さだけを使う。頭だけのときは高さが足りず、はみ出した分はシートの外に隠れる。
            // GeometryReader に入れないと、はみ出した中身にシート全体が押し上げられて3項目まで隠れる。
            GeometryReader { _ in
                VStack(spacing: WireMetrics.spacingL) {
                    details.padding(.horizontal, WireMetrics.screenPadding)
                    wordSheet
                }
            }
            .opacity(isExpanded ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isExpanded)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { downloadArea }
    }

    private var metrics: some View {
        HStack(spacing: 0) {
            metric("収録語数") { Text(words.map { "\($0.count)語" } ?? "—").wireFont(.titleS) }
            Divider()
            metric("容量") { Text(DeckGalleryFacts.sizeText(deck.mediaBytes)).wireFont(.titleS) }
            Divider()
            metric("レベル") { level }
        }
        .frame(height: 64)
        .padding(.vertical, WireMetrics.spacingS)
        .overlay(alignment: .top) { Divider() }
        .overlay(alignment: .bottom) { Divider() }
    }

    private func metric(_ title: String, @ViewBuilder value: () -> some View) -> some View {
        VStack(spacing: WireMetrics.spacingXS) {
            Text(title).wireFont(.caption)
            value()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// 易・中・難を、3つのうち塗った星の数で見せる（易 ★☆☆、中 ★★☆、難 ★★★）。
    @ViewBuilder
    private var level: some View {
        if let difficulty = deck.difficulty {
            HStack(spacing: 2) {
                ForEach(1...3, id: \.self) { step in
                    Image(systemName: step <= difficulty.level ? "star.fill" : "star")
                }
            }
            .font(.headline)
            .foregroundStyle(WireColor.ink)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(difficulty.title)
        } else {
            Text("—").wireFont(.titleS)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            if let description = deck.deck.description {
                Text(description).wireFont(.body)
            }
            detailRow("重なる語数", overlap.map(DeckGalleryFacts.overlapText) ?? "—")
            if let words, !words.isEmpty {
                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    Text("品詞の内訳").wireFont(.caption)
                    PartOfSpeechBar(parts: DeckGalleryFacts.partsOfSpeech(words))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: nil, fill: WireColor.surface)
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).wireFont(.caption)
            Spacer()
            Text(value).wireFont(.label)
        }
        .accessibilityElement(children: .combine)
    }

    /// 単語一覧。上端だけ角を丸めたシート内シートに入れ、この中だけでスクロールする（旧デッキ詳細と同じ形）。
    /// 赤シートは付けない（要件 R10）。行は単語一覧と同じ見た目にする。
    private var wordSheet: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: WireMetrics.radiusLarge,
                                           topTrailingRadius: WireMetrics.radiusLarge, style: .continuous)
        return Group {
            if let words {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(words) { word in
                            WordRow(word: word)
                        }
                    }
                }
                .contentMargins(.bottom, Self.footerClearance, for: .scrollContent)
                .scrollIndicators(.hidden)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .clipShape(shape)
        .background { shape.fill(WireColor.surface).ignoresSafeArea(edges: .bottom) }
        .overlay {
            shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase)
                .ignoresSafeArea(edges: .bottom)
                .allowsHitTesting(false)
        }
    }

    private var downloadArea: some View {
        VStack(spacing: WireMetrics.spacingS) {
            if let message {
                Text(message)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, WireMetrics.spacingS)
                    .background(.regularMaterial, in: Capsule())
                    .accessibilityIdentifier("galleryDownloadMessage")
            }
            Button(action: onDownload) {
                HStack(spacing: WireMetrics.spacingS) {
                    if isDownloading { ProgressView().tint(.white) }
                    Text(deck.isAdded ? "追加済み" : isDownloading ? "追加中…" : "ダウンロード")
                }
                .font(.headline)
                // 白い文字は #FF5D97 の上では基準のコントラストに届かない。利用者の判断で今はこのまま（要件 G5）。
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .pinkGlassSurface(in: Capsule())
            .disabled(isDownloading || deck.isAdded)
            // 追加済みは透かさずに色を抜いて示す。薄くすると、後ろの一覧がボタン越しに透けて読みにくい。
            .saturation(deck.isAdded ? 0 : 1)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingS)
        // 利用者の希望で、ふつうの置き場所より10pt下げる。
        .offset(y: 10)
    }
}

/// 品詞の内訳を、横に積んだ帯と凡例で見せる。色は使わず、墨の濃淡で分ける。
private struct PartOfSpeechBar: View {
    let parts: [DeckGalleryFacts.PartCount]

    private var total: Int { max(1, parts.reduce(0) { $0 + $1.count }) }

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            GeometryReader { proxy in
                HStack(spacing: 1) {
                    ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                        Rectangle()
                            .fill(shade(index))
                            .frame(width: max(0, proxy.size.width * CGFloat(part.count) / CGFloat(total) - 1))
                    }
                }
            }
            .frame(height: 10)
            .clipShape(Capsule())
            .accessibilityHidden(true)

            ViewThatFits(in: .horizontal) {
                legend(axis: .horizontal)
                legend(axis: .vertical)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func legend(axis: Axis) -> some View {
        let layout = axis == .horizontal
            ? AnyLayout(HStackLayout(spacing: WireMetrics.spacingM))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: WireMetrics.spacingXS))
        return layout {
            ForEach(Array(parts.enumerated()), id: \.offset) { index, part in
                HStack(spacing: WireMetrics.spacingXS) {
                    Circle().fill(shade(index)).frame(width: 8, height: 8).accessibilityHidden(true)
                    Text("\(part.title) \(part.count)").wireFont(.caption)
                }
            }
        }
    }

    private func shade(_ index: Int) -> Color {
        WireColor.ink.opacity(max(0.15, 1 - Double(index) * 0.2))
    }
}

/// デッキ詳細に出す数え方。画面から切り離して確かめられるようにしてある。
enum DeckGalleryFacts {
    struct PartCount: Equatable {
        let title: String
        let count: Int
    }

    /// 主の意味の品詞ごとの語数。多い順で、分からない品詞は「その他」として最後に置く。
    static func partsOfSpeech(_ words: [WordCard]) -> [PartCount] {
        var counts: [WordPartOfSpeech: Int] = [:]
        var others = 0
        for word in words {
            if let part = WordPartOfSpeech(englishOrJapanese: word.partOfSpeech) {
                counts[part, default: 0] += 1
            } else {
                others += 1
            }
        }
        let known = counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.rawValue < $1.key.rawValue }
            .map { PartCount(title: $0.key.rawValue, count: $0.value) }
        return others > 0 ? known + [PartCount(title: "その他", count: others)] : known
    }

    /// 学習タブにあるほかのデッキと同じ単語の数。追加済みなら、そのデッキ自身は数えない。
    /// `ownedWords` はデッキ（端末の番号）ごとの、サーバーの単語番号。
    static func overlapCount(words: [WordCard], ownedWords: [Int: Set<Int>], excludingDeckId: Int) -> Int {
        let owned = ownedWords.filter { $0.key != excludingDeckId }.values.reduce(into: Set<Int>()) { $0.formUnion($1) }
        return Set(words.map(\.wordId)).intersection(owned).count
    }

    static func overlapText(_ count: Int) -> String {
        count == 0 ? "重なりなし" : "追加済みのデッキと\(count)語重なる"
    }

    /// 容量。同期がまだ値を入れていなければ「—」。
    static func sizeText(_ bytes: Int64?) -> String {
        guard let bytes else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

private extension View {
    /// ピンクのダウンロードボタン。新しいOSはピンクに色づけたガラス、旧OSはピンクの面。
    @ViewBuilder
    func pinkGlassSurface<S: Shape>(in shape: S) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            glassEffect(.regular.tint(WireColor.answerCorrect).interactive(), in: shape)
        } else {
            background(WireColor.answerCorrect, in: shape)
        }
        #else
        background(WireColor.answerCorrect, in: shape)
        #endif
    }
}
