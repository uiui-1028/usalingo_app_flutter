import SwiftUI

/// 学習タブの空き枠から開く、公式デッキの箱を1つ選んで追加する画面。
///
/// 上にジャンルのセグメント、真ん中に学習タブと同じ縦のカルーセル、下に標準のシートを置く。
/// シートは頭（収録語数・容量・レベル）と約7割（詳しい情報と単語一覧）の2段で、中身はカルーセルの
/// 中央の箱に合わせて変わる。要件は docs/plans/deck-gallery-redesign-requirements.md と
/// docs/plans/deck-box-requirements.md。
/// ダウンロードを押したら、すぐ `onAdded` に箱と表紙を渡す。追加と画像・音声のダウンロードは呼び出し側が裏で進め、
/// 進み具合は学習タブの枠に出す（要件 R4・R5）。戻るのも呼び出し側が決める。
struct DeckLibraryView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let onAdded: (OfficialBox, URL?) -> Void

    @State private var genre = GalleryGenre.exam
    @State private var boxes: [OfficialBox] = []
    @State private var isLoading = true
    @State private var loadFailed = false
    /// カルーセルの中央にいる箱。
    @State private var selectedId: OfficialBox.ID?
    /// デッキ（サーバーの番号）ごとの収録カード。読めなかったデッキは入らない。
    @State private var cardsByDeck: [Int: [WordCard]] = [:]
    @State private var covers: [OfficialBox.ID: URL] = [:]
    /// 娘（箱の中のデッキ）ごとの表紙。学習タブと同じ選び方で決める。
    @State private var deckCovers: [Int: URL] = [:]
    /// 学習タブにある公式デッキ（端末の番号）ごとの、サーバーの単語番号。重なる語数を数えるのに使う。
    @State private var ownedWords: [Int: Set<Int>] = [:]
    @State private var isSheetPresented = false
    @State private var detent = GallerySheetDetent.peek
    /// モバイル回線で押したときに、確認を出している箱（要件 D7）。
    @State private var boxAwaitingCellularConsent: OfficialBox?
    /// シートを閉じ切ってから行うこと。シートを出したまま戻ると、画面だけが先に消えてしまう。
    @State private var afterSheetDismiss: (() -> Void)?

    private var genreBoxes: [OfficialBox] { boxes.filter { $0.genre == genre } }
    private var selectedBox: OfficialBox? { genreBoxes.first { $0.id == selectedId } }
    /// シートが7割まで上がっている。カードを1枚だけ上に出し、回せなくする。
    private var isFocused: Bool { detent == GallerySheetDetent.expanded }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                content(in: proxy)
                if isFocused {
                    // シートの外（上のカードと背景）をタップしたら、シートを頭に戻して一覧へ帰る。
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { detent = GallerySheetDetent.peek }
                        .accessibilityLabel("一覧に戻る")
                        .accessibilityAddTraits(.isButton)
                } else {
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
        .onChange(of: selectedBox?.id) { _, _ in updateSheetPresence() }
        .onDisappear { isSheetPresented = false }
    }

    // MARK: - 画面

    @ViewBuilder
    private func content(in proxy: GeometryProxy) -> some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if loadFailed || genreBoxes.isEmpty {
            GalleryUnavailableBoard { Task { await reload() } }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let peekCover = max(0, GallerySheetDetent.peekHeight - proxy.safeAreaInsets.bottom)
            let areaHeight = proxy.size.height - peekCover
            DeckGalleryCarousel(
                boxes: genreBoxes,
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
            if let box = selectedBox {
                DeckGallerySheet(
                    box: box,
                    cardsByDeck: cardsByDeck,
                    deckCovers: deckCovers,
                    overlap: overlapCount(for: box),
                    isExpanded: isFocused,
                    onDownload: { download(box) }
                )
                // 別の箱に回したら、選んでいる娘を先頭に戻す（要件 X20）。
                .id(box.id)
            } else {
                Color.clear
            }
        }
        // シートが出ている間は、確認もシートの上に出す。
        .alert("モバイル回線でダウンロードしますか？", isPresented: Binding(
            get: { boxAwaitingCellularConsent != nil },
            set: { if !$0 { boxAwaitingCellularConsent = nil } }
        ), presenting: boxAwaitingCellularConsent) { box in
            Button("やめる", role: .cancel) {}
            Button("ダウンロード") { startAdding(box) }
        } message: { box in
            Text(box.missingBytes.map {
                "約\(ByteCountFormatter.string(fromByteCount: $0, countStyle: .file))を使います。"
            } ?? "画像と音声をダウンロードします。")
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

    /// 選べる箱があるときだけシートを出す。無いときは看板だけを見せる。
    private func updateSheetPresence() {
        let shouldPresent = selectedBox != nil && afterSheetDismiss == nil
        if !shouldPresent { detent = GallerySheetDetent.peek }
        if isSheetPresented != shouldPresent { isSheetPresented = shouldPresent }
    }

    private func selectFirstDeckIfNeeded() {
        detent = GallerySheetDetent.peek
        if selectedBox == nil { selectedId = genreBoxes.first?.id }
    }

    private func reload() async {
        isLoading = boxes.isEmpty
        defer {
            isLoading = false
            selectFirstDeckIfNeeded()
            updateSheetPresence()
        }
        do {
            boxes = try await appState.fetchOfficialBoxes()
            loadFailed = false
        } catch {
            loadFailed = boxes.isEmpty
            return
        }
        await loadOwnedWords()
        await loadCards()
    }

    /// デッキごとの収録カードを並行して読み、娘と箱の表紙を決める。
    /// 箱の表紙は箱で指定した例文の画像。指定が無ければ先頭の娘の表紙にする（要件 X11・X22）。
    /// ponytail: 単語一覧と重なる語数のために、全部の箱のカードを読む。箱が増えて重くなったら、
    /// 中央の箱とその隣だけを読む形にする。
    private func loadCards() async {
        let ids = boxes.flatMap(\.decks).map(\.id).filter { cardsByDeck[$0] == nil }
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
                deckCovers[id] = store.coverURL(deckId: LocalStudyDataSource.cachedDeckId(remoteDeckId: id), cards: cachedForm)
            }
        }
        for box in boxes {
            if let path = box.coverImagePath, let url = SupabaseConfig.publicStorageURL(for: path) {
                covers[box.id] = url
            } else {
                covers[box.id] = deckCovers[box.decks[0].id]
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

    /// 箱ぜんたいの単語のうち、学習タブのほかのデッキにもある数。追加済みなら箱のデッキ自身は数えない。
    private func overlapCount(for box: OfficialBox) -> Int? {
        guard let cards = box.cards(in: cardsByDeck) else { return nil }
        return DeckGalleryFacts.overlapCount(
            words: cards,
            ownedWords: ownedWords,
            excludingDeckIds: Set(box.decks.map { LocalStudyDataSource.cachedDeckId(remoteDeckId: $0.id) })
        )
    }

    /// モバイル回線なら、使う大きさを伝えてから始める（要件 D7）。
    private func download(_ box: OfficialBox) {
        guard !box.isAdded else { return }
        if appState.mediaDownloader?.isExpensiveNetwork == true {
            boxAwaitingCellularConsent = box
        } else {
            startAdding(box)
        }
    }

    private func startAdding(_ box: OfficialBox) {
        afterSheetDismiss = { onAdded(box, covers[box.id]) }
        isSheetPresented = false
    }
}

/// ジャンル。公式デッキを大きなくくりで分けるだけで、目立たせるデッキは作らない（要件 R1）。
enum GalleryGenre: String, CaseIterable {
    case exam = "大学受験"
    case toeic = "TOEIC"

    /// `deck_boxes.genre` の値から。箱に入っていないデッキと知らない値は大学受験に入れる。
    init(code: String?) {
        self = code == "toeic" ? .toeic : .exam
    }
}

/// ギャラリーで選ぶ1つ。公式デッキの箱か、箱に入っていない公式デッキ1つ（要件 X1・X7）。
struct OfficialBox: Identifiable, Hashable {
    /// 箱の番号。箱に入っていないデッキは nil で、そのデッキ1つだけを並べる。
    let boxId: Int?
    let name: String
    let description: String?
    let genre: GalleryGenre
    /// 中のデッキ。箱の中の順（デッキの番号の順）。
    let decks: [OfficialDeck]
    /// 箱ぜんたいの容量と易しさ。同期がまだ入れていなければ nil。
    let mediaBytes: Int64?
    let difficulty: DeckDifficulty?
    /// 箱で指定した表紙の画像。無ければ収録単語のイラストから選ぶ。
    let coverImagePath: String?

    var id: String { boxId.map { "box-\($0)" } ?? "deck-\(decks[0].id)" }
    /// 中のデッキが全部学習タブにあれば追加済み。どのフォルダに入っていてもよい（要件 X7）。
    var isAdded: Bool { decks.allSatisfy(\.isAdded) }
    /// まだ学習タブに無いデッキ。追加するとこれだけを入れる。
    var missingDecks: [OfficialDeck] { decks.filter { !$0.isAdded } }
    /// 学習タブではフォルダにして入れるか。箱に入っていないデッキは、今までどおり1つで入る。
    var makesFolder: Bool { boxId != nil }
    /// 表紙の飾りと表紙の選び方に使う、先頭のデッキの端末の番号。
    var leadLocalDeckId: Int { LocalStudyDataSource.cachedDeckId(remoteDeckId: decks[0].id) }

    /// これからダウンロードする量。足りないデッキの容量の合計で、どれか分からなければ箱の容量。
    var missingBytes: Int64? {
        let sizes = missingDecks.map(\.mediaBytes)
        guard sizes.allSatisfy({ $0 != nil }) else { return mediaBytes }
        return sizes.reduce(Int64(0)) { $0 + ($1 ?? 0) }
    }

    /// 箱ぜんたいの収録カード。まだ読めていないデッキがあれば nil。
    func cards(in cardsByDeck: [Int: [WordCard]]) -> [WordCard]? {
        var cards: [WordCard] = []
        for deck in decks {
            guard let deckCards = cardsByDeck[deck.id] else { return nil }
            cards += deckCards
        }
        return cards
    }

    /// 公式デッキを箱ごとにまとめる。箱は箱の並び順（シリーズ順。要件 X17）、
    /// 箱に入っていないデッキはそのあとにデッキの番号の順で、1つずつの箱にする。
    static func grouping(_ decks: [OfficialDeck]) -> [OfficialBox] {
        let sorted = decks.sorted { $0.id < $1.id }
        var members: [Int: [OfficialDeck]] = [:]
        var records: [Int: DeckBoxRecord] = [:]
        var singles: [OfficialBox] = []
        for deck in sorted {
            guard let box = deck.box else {
                singles.append(OfficialBox(
                    boxId: nil, name: deck.deck.deckName, description: deck.deck.description,
                    genre: .exam, decks: [deck], mediaBytes: deck.mediaBytes,
                    difficulty: deck.difficulty, coverImagePath: nil
                ))
                continue
            }
            members[box.id, default: []].append(deck)
            records[box.id] = box
        }
        let boxes = records.values
            .sorted { ($0.sortOrder, $0.id) < ($1.sortOrder, $1.id) }
            .map { record in
                OfficialBox(
                    boxId: record.id, name: record.boxName, description: record.description,
                    genre: GalleryGenre(code: record.genre), decks: members[record.id] ?? [],
                    mediaBytes: record.mediaBytes, difficulty: record.difficulty,
                    coverImagePath: record.cover?.imageAssetPath
                )
            }
        return boxes + singles
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

/// デッキ追加画面の縦のカルーセル。1枚が1つの箱。動き（`AudioCarouselMotion`）と寸法は学習タブと同じで、
/// 空き枠・長押し・フォルダは持たない。中央のカードをタップすると `onOpen` を呼ぶ。
private struct DeckGalleryCarousel: View {
    private typealias Metrics = DeckCarouselView.Metrics

    let boxes: [OfficialBox]
    let selectedId: OfficialBox.ID?
    let covers: [OfficialBox.ID: URL]
    /// シートが7割のあいだは回さず、中央の1枚だけを見せる（要件 G1）。
    let isLocked: Bool
    let onSelect: (OfficialBox) -> Void
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
                ForEach(Array(boxes.enumerated()), id: \.element.id) { index, box in
                    let offset = CGFloat(index) - center
                    let y = layout.y(offset: offset)
                    if abs(y) < proxy.size.height {
                        card(box, index: index, expansion: layout.expansion(offset: offset),
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
        .onChange(of: boxes.map(\.id)) { _, _ in synchronize() }
    }

    private func card(_ box: OfficialBox, index: Int, expansion: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (Metrics.bandWidthRatio + (1 - Metrics.bandWidthRatio) * expansion)
        // 追加済みは面を暗くして文字を白にする（要件 G6）。膜を文字の上に重ねると文字まで沈むので、面の色を変える。
        let textColor = box.isAdded ? WireColor.surface : WireColor.ink
        return HStack(alignment: .top, spacing: WireMetrics.spacingM) {
            DeckCoverImage(url: covers[box.id], symbol: DeckCoverSymbol.forDeck(id: box.leadLocalDeckId))
                .overlay {
                    if box.isAdded {
                        RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
                            .fill(Color.black.opacity(0.45))
                    }
                }
                .frame(width: cardWidth * Metrics.coverWidthRatio)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(box.name)
                    .wireFont(expansion > 0.5 ? .titleS : .label, color: textColor)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let description = box.description {
                    Text(description)
                        .wireFont(.caption, color: box.isAdded ? WireColor.surface.opacity(0.85) : WireColor.subText)
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
                        fill: box.isAdded ? Color(white: 0.32) : BentoTone.l2.fill)
        .contentShape(Rectangle())
        .onTapGesture { index == centerIndex ? onOpen() : snap(to: index) }
        // ponytail: VoiceOver は中央の枠だけを読み、上下の操作で隣へ移すだけの最低限。
        .accessibilityElement(children: .combine)
        .accessibilityValue(box.isAdded ? "追加済み" : "")
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
                guard boxes.count > 1 else { return }
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
        centerIndex = boxes.firstIndex { $0.id == selectedId } ?? 0
        motion.configure(stride: layout.stride, count: boxes.count, index: centerIndex)
        if boxes.indices.contains(centerIndex) { onSelect(boxes[centerIndex]) }
    }

    private func snap(to index: Int) {
        let target = min(max(0, index), boxes.count - 1)
        guard target != centerIndex, !isLocked else { return }
        motion.snap(to: target, animated: !reduceMotion, completion: complete)
    }

    private func complete(at index: Int) {
        centerIndex = index
        onSelect(boxes[index])
    }
}

// MARK: - シート

/// シートの中身。上に収録語数・容量・レベルを止めておき、その下は丸ごと1つのスクロールにする（要件 X21）。
/// スクロールの中は「説明・重なる語数・品詞の内訳」→「収録デッキ（娘）」→「選んだ娘の単語一覧」。
/// 上の数字・重なる語数・品詞の内訳は箱ぜんたいで数え、娘の行にはその娘の数字を出す（要件 X14・X19）。
/// ダウンロードボタンはタブバーと同じく地を持たずに下へ浮かべ、ボタンの周りは下の一覧が透ける。
private struct DeckGallerySheet: View {
    let box: OfficialBox
    /// デッキ（サーバーの番号）ごとの収録カード。まだ読めていないデッキは入っていない。
    let cardsByDeck: [Int: [WordCard]]
    /// 娘（サーバーの番号）ごとの表紙。
    let deckCovers: [Int: URL]
    let overlap: Int?
    /// 7割まで上がっているか。頭だけのときは3項目だけを見せ、ボタンの周りに下の情報を透かさない。
    let isExpanded: Bool
    let onDownload: () -> Void

    /// 単語一覧に出している娘。最初は先頭（要件 X20）。箱が変わると、呼ぶ側が作り直して先頭に戻す。
    @State private var selectedDeckId: Int?

    /// 浮かべたボタンの下に、一覧の最後の行が隠れないよう空ける量。
    private static let footerClearance: CGFloat = 88

    /// 箱ぜんたいの収録カード。まだ読めていないデッキがあれば nil。
    private var words: [WordCard]? { box.cards(in: cardsByDeck) }
    private var selectedDeck: OfficialDeck { box.decks.first { $0.id == selectedDeckId } ?? box.decks[0] }

    var body: some View {
        VStack(spacing: WireMetrics.spacingL) {
            metrics
                .padding(.horizontal, WireMetrics.screenPadding)
                .padding(.top, WireMetrics.spacingXL)
            // 残りの高さだけを使う。頭だけのときは高さが足りず、はみ出した分はシートの外に隠れる。
            // GeometryReader に入れないと、はみ出した中身にシート全体が押し上げられて3項目まで隠れる。
            GeometryReader { _ in
                ScrollView {
                    VStack(spacing: WireMetrics.spacingL) {
                        details.padding(.horizontal, WireMetrics.screenPadding)
                        if box.decks.count > 1 {
                            deckList.padding(.horizontal, WireMetrics.screenPadding)
                        }
                        wordList
                    }
                }
                .contentMargins(.bottom, Self.footerClearance, for: .scrollContent)
                .scrollIndicators(.hidden)
            }
            .opacity(isExpanded ? 1 : 0)
            .animation(.easeOut(duration: 0.2), value: isExpanded)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .overlay(alignment: .bottom) { downloadArea }
    }

    private var metrics: some View {
        SheetMetricsRow {
            SheetMetric(title: "収録語数") { Text(words.map { "\($0.count)語" } ?? "—").wireFont(.titleS) }
            Divider()
            SheetMetric(title: "容量") { Text(DeckGalleryFacts.sizeText(box.mediaBytes)).wireFont(.titleS) }
            Divider()
            SheetMetric(title: "レベル") { level }
        }
    }

    /// 易・中・難を、3つのうち塗った星の数で見せる（易 ★☆☆、中 ★★☆、難 ★★★）。
    @ViewBuilder
    private var level: some View {
        if let difficulty = box.difficulty {
            StarRating(filled: difficulty.level, label: difficulty.title)
        } else {
            Text("—").wireFont(.titleS)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingM) {
            if let description = box.description {
                Text(description).wireFont(.body)
            }
            detailRow("重なる語数", overlap.map { "\($0)語" } ?? "—")
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

    /// 箱の中のデッキ（娘）。押すと、その娘の単語を下の一覧に出す。1つずつのダウンロードはしない（要件 X18）。
    private var deckList: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text("収録デッキ").wireFont(.caption)
            VStack(spacing: DeckCarouselView.Metrics.tileSpacing) {
                ForEach(box.decks) { deck in
                    GalleryDeckRow(deck: deck, coverURL: deckCovers[deck.id],
                                   wordCount: cardsByDeck[deck.id]?.count,
                                   isSelected: deck.id == selectedDeck.id) {
                        selectedDeckId = deck.id
                    }
                }
            }
        }
    }

    /// 選んだ娘の単語一覧。上端だけ角を丸めた面に入れる。赤シートは付けない（要件 R10）。
    /// 行は単語一覧と同じ見た目にする。
    private var wordList: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: WireMetrics.radiusLarge,
                                           topTrailingRadius: WireMetrics.radiusLarge, style: .continuous)
        return Group {
            if let deckWords = cardsByDeck[selectedDeck.id] {
                LazyVStack(spacing: 0) {
                    ForEach(deckWords) { word in
                        WordRow(word: word)
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(WireMetrics.spacingXL)
            }
        }
        .padding(.top, WireMetrics.spacingS)
        .background { shape.fill(WireColor.surface) }
        .clipShape(shape)
        .overlay {
            shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase)
                .allowsHitTesting(false)
        }
    }

    private var downloadArea: some View {
        Button(action: onDownload) {
            Text(box.isAdded ? "追加済み" : "ダウンロード")
                .font(.headline)
                // 白い文字は #FF5D97 の上では基準のコントラストに届かない。利用者の判断で今はこのまま（要件 G5）。
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, minHeight: 52)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .pinkGlassSurface(in: Capsule())
        .disabled(box.isAdded)
        // 追加済みは透かさずに色を抜いて示す。薄くすると、後ろの一覧がボタン越しに透けて読みにくい。
        .saturation(box.isAdded ? 0 : 1)
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingS)
        // 利用者の希望で、ふつうの置き場所より10pt下げる。
        .offset(y: 10)
    }
}

/// 収録デッキの1行。学習タブの開いたフォルダの行と同じ形（左半分に表紙、右に名前）で、名前の下に
/// そのデッキの語数・容量・★を出す。ふだんは白い地、選んでいる行だけ黒ベタに白い文字（要件 X19）。
private struct GalleryDeckRow: View {
    let deck: OfficialDeck
    let coverURL: URL?
    /// まだ収録カードを読めていなければ nil。
    let wordCount: Int?
    let isSelected: Bool
    let onSelect: () -> Void

    /// 学習タブの行と同じ高さ。文字を大きくしたときは、名前と数字が切れないよう一緒に伸ばす。
    @ScaledMetric(relativeTo: .body) private var rowHeight = DeckCarouselView.Metrics.tileHeight

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
        let textColor = isSelected ? WireColor.surface : WireColor.ink
        Button(action: onSelect) {
            HStack(spacing: 0) {
                DeckCoverImage(url: coverURL,
                               symbol: DeckCoverSymbol.forDeck(id: LocalStudyDataSource.cachedDeckId(remoteDeckId: deck.id)))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text(deck.deck.deckName)
                        .wireFont(.label, color: textColor)
                        .lineLimit(2)
                    HStack(spacing: WireMetrics.spacingXS) {
                        Text("\(wordCount.map { "\($0)語" } ?? "—")・\(DeckGalleryFacts.sizeText(deck.mediaBytes))")
                            .wireFont(.caption, color: textColor)
                        if let difficulty = deck.difficulty {
                            StarRating(filled: difficulty.level, label: difficulty.title, font: .caption, color: textColor)
                        }
                    }
                }
                .padding(.horizontal, WireMetrics.spacingS)
                .padding(.vertical, WireMetrics.spacingXS)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: rowHeight)
            .background(isSelected ? WireColor.ink : WireColor.surface)
            .clipShape(shape)
            .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

/// 下のシートの頭に置く、線で区切った3項目の帯。デッキ追加と単語詳細で使う。
struct SheetMetricsRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 0) { content }
            .frame(height: 64)
            .padding(.vertical, WireMetrics.spacingS)
            .overlay(alignment: .top) { Divider() }
            .overlay(alignment: .bottom) { Divider() }
    }
}

/// `SheetMetricsRow` の1項目。上に小さな見出し、下に値。
struct SheetMetric<Value: View>: View {
    let title: String
    @ViewBuilder let value: Value

    var body: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            Text(title).wireFont(.caption)
            value
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

/// 3つのうち塗った星の数で段階を見せる。
struct StarRating: View {
    let filled: Int
    let label: String
    var font: Font = .headline
    var color: Color = WireColor.ink

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...3, id: \.self) { step in
                Image(systemName: step <= filled ? "star.fill" : "star")
            }
        }
        .font(font)
        .foregroundStyle(color)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
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

    /// 学習タブにあるほかのデッキと同じ単語の数。追加済みなら、その箱のデッキ自身は数えない。
    /// `ownedWords` はデッキ（端末の番号）ごとの、サーバーの単語番号。
    static func overlapCount(words: [WordCard], ownedWords: [Int: Set<Int>], excludingDeckIds: Set<Int>) -> Int {
        let owned = ownedWords.filter { !excludingDeckIds.contains($0.key) }.values.reduce(into: Set<Int>()) { $0.formUnion($1) }
        return Set(words.map(\.wordId)).intersection(owned).count
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
