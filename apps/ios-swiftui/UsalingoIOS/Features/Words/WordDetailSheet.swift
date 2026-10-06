import SwiftUI
import UIKit

/// 単語リストから開く単語詳細。デッキ追加画面（`DeckLibraryView`）と同じ組み立てで、
/// 上に主役のカード、下に標準のシートを置く。シートは頭（単語・意味と CEFR・品詞・習得度）と約7割（ほかの情報）の2段。
/// 頭でカードをタップするとシートが上がり、上がっている間はシートの外をタップすると頭へ戻る。
/// 単語の移動は、シートの中を横に払うか、頭のときに背景を横に払う。
struct WordDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 頭の高さ。単語・意味・3項目と、下に浮かべたアクションバーが入る高さ。文字の大きさに合わせて伸ばす。
    @ScaledMetric(relativeTo: .largeTitle) private var peekHeight: CGFloat = 314
    @State private var selection: WordDetailSelection
    @State private var pagingDirection: UIPageViewController.NavigationDirection = .forward
    @State private var cardID: WordCard.ID
    @State private var pagingProgress: CGFloat = 0
    @State private var backgroundPaging = false
    @State private var backgroundSettling = false
    @State private var isEditing = false
    @State private var isTagging = false
    @State private var isExpanded = false
    @State private var isSheetPresented = false
    let onSaved: (WordCard) -> Void

    private var word: WordCard { selection.current }
    private var peek: PresentationDetent { .height(peekHeight) }

    init(word: WordCard, words: [WordCard] = [], onSaved: @escaping (WordCard) -> Void) {
        _selection = State(initialValue: WordDetailSelection(word: word, words: words))
        _cardID = State(initialValue: word.id)
        self.onSaved = onSaved
    }

    var body: some View {
        GeometryReader { geometry in
            let top = geometry.safeAreaInsets.top
            let bottom = geometry.safeAreaInsets.bottom
            let screenHeight = geometry.size.height + top + bottom
            // シートの上端（安全域の内側の座標）。高さで止める段は下の安全域の上に積まれ、
            // 割合で止める段は、画面の上の安全域を除いた高さに対する割合になる。
            let sheetTop = isExpanded
                ? screenHeight - (screenHeight - top) * GallerySheetDetent.expandedFraction - top
                : geometry.size.height - peekHeight
            let stageTop: CGFloat = isExpanded ? WireMetrics.spacingS : 56
            let stageHeight = max(80, sheetTop - stageTop - WireMetrics.spacingS)
            let cardHeight = min(stageHeight, min(350, geometry.size.width - 56) / 0.74)
            ZStack(alignment: .top) {
                // 頭のときは、背景を横に払っても単語を移れる。カードの上は裏返しに使うので、背景だけで受ける。
                WireColor.background
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .gesture(pagingGesture(width: geometry.size.width), including: isExpanded ? .none : .all)

                cardCarousel(cardHeight: cardHeight, width: geometry.size.width)
                    .frame(maxWidth: .infinity)
                    .frame(height: stageHeight)
                    .padding(.top, stageTop)

                if isExpanded {
                    // シートの外（上のカードと背景）をタップしたら、シートを頭に戻す。
                    Color.clear
                        .contentShape(Rectangle())
                        .ignoresSafeArea()
                        .onTapGesture { isExpanded = false }
                        .accessibilityLabel("詳細を閉じる")
                        .accessibilityAddTraits(.isButton)
                }
            }
            .coordinateSpace(name: "wordDetailViewport")
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: isExpanded)
        }
        // シートを閉じ切ってから詳細を閉じる。シートを出したまま閉じると、画面だけが先に消えてしまう。
        .sheet(isPresented: $isSheetPresented, onDismiss: { dismiss() }) { sheet }
        .onAppear { isSheetPresented = true }
    }

    private var sheet: some View {
        WordDetailPager(
            words: selection.words,
            selectedID: word.id,
            isExpanded: isExpanded,
            direction: pagingDirection,
            reduceMotion: reduceMotion || backgroundPaging,
            onProgress: { if !backgroundPaging { pagingProgress = $0 } }
        ) { id in
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                selection.select(id: id)
                cardID = id
                pagingProgress = 0
                backgroundPaging = false
                backgroundSettling = false
            }
        }
        // 中身をシートの下端まで流す。下の安全域で切ると、バーの下に切れ目が見える。
        .ignoresSafeArea(edges: .bottom)
        .accessibilityAction(named: "次の単語") { moveWord(by: 1) }
        .accessibilityAction(named: "前の単語") { moveWord(by: -1) }
        .overlay(alignment: .bottom) { actionBar }
        .sheet(isPresented: $isEditing) {
            WordEditSheet(word: word) { savedWord in
                selection.replace(savedWord)
                onSaved(savedWord)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isTagging) {
            TagSheet(word: word) { savedWord in
                selection.replace(savedWord)
                onSaved(savedWord)
            }
            .presentationDetents([.medium, .large])
        }
        .presentationDetents([peek, GallerySheetDetent.expanded], selection: Binding(
            get: { isExpanded ? GallerySheetDetent.expanded : peek },
            set: { isExpanded = $0 == GallerySheetDetent.expanded }
        ))
        // 7割でも後ろを暗くしない。上のカードを明るいまま見せ、外のタップを受けられるようにする。
        .presentationBackgroundInteraction(.enabled)
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
    }

    /// 単語リストと同じ丸ピルのバー。デッキ追加画面のダウンロードボタンと同じく、シートの下に浮かべる。
    private var actionBar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button { isTagging = true } label: {
                WordListActionBarIcon(symbol: "tag", isActive: !word.tags.isEmpty)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("タグを編集")

            Button { isEditing = true } label: {
                WordListActionBarIcon(symbol: "square.and.pencil", isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("単語を編集")

            Button { isSheetPresented = false } label: {
                WordListActionBarIcon(symbol: "xmark", isActive: false)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("単語リストに戻る")
        }
        .wordListBarChrome()
        .padding(.bottom, WireMetrics.spacingS)
        // デッキ追加画面のダウンロードボタンと同じ置き場所にそろえる。
        .offset(y: 10)
    }

    private func cardCarousel(cardHeight: CGFloat, width: CGFloat) -> some View {
        let baseIndex = selection.words.firstIndex(where: { $0.id == cardID }) ?? selection.index
        let offsets = selection.words.count > 1 && !reduceMotion ? [-1, 0, 1] : [0]
        return ZStack {
            ForEach(offsets, id: \.self) { offset in
                let index = WordDetailSelection.wrappedIndex(baseIndex + offset, count: selection.words.count)
                let position = CGFloat(offset) - (reduceMotion ? 0 : pagingProgress)
                InteractiveWordCard(word: selection.words[index], reduceMotion: reduceMotion)
                    .id(selection.words[index].id)
                    .frame(width: cardHeight * 0.74, height: cardHeight)
                    // 触れる範囲を札の形へ切り直す。中の傾き（3D 回転）で判定が
                    // 札の外まで広がると、背景のスワイプを奪ってしまうため。
                    .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard))
                    .onTapGesture { isExpanded = true }
                    .accessibilityAction(named: "詳細を表示") { isExpanded = true }
                    .modifier(WordCardArc(position: position, travel: width))
                    .allowsHitTesting(offset == 0 && pagingProgress == 0)
                    .accessibilityHidden(offset != 0)
            }
        }
    }

    private func pagingGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12, coordinateSpace: .named("wordDetailViewport"))
            .onChanged { value in
                guard !backgroundSettling, selection.words.count > 1,
                      abs(value.translation.width) > abs(value.translation.height),
                      cardID == word.id else { return }
                backgroundPaging = true
                pagingProgress = min(1, max(-1, -value.translation.width / max(1, width)))
            }
            .onEnded { value in
                if backgroundPaging { settlePaging(translation: value.translation.width) }
            }
    }

    private func settlePaging(translation: CGFloat) {
        guard !backgroundSettling else { return }
        backgroundSettling = true
        let step = abs(translation) > 45 ? (translation < 0 ? 1 : -1) : 0
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.24)) {
            pagingProgress = CGFloat(step)
        } completion: {
            if step == 0 {
                backgroundPaging = false
                backgroundSettling = false
            } else {
                moveWord(by: step)
            }
        }
    }

    private func moveWord(by step: Int) {
        guard selection.words.count > 1, cardID == word.id else { return }
        pagingDirection = step > 0 ? .forward : .reverse
        selection.move(by: step)
    }
}


/// A shallow arc toward the viewer: the inner edge comes forward as a card
/// leaves the center. The background and the sheet keep their own geometry.
private struct WordCardArc: AnimatableModifier {
    var position: CGFloat
    let travel: CGFloat
    var animatableData: CGFloat {
        get { position }
        set { position = newValue }
    }

    func body(content: Content) -> some View {
        let distance = min(1, abs(position))
        let arc = sin(distance * .pi)
        content
            .scaleEffect(1 + 0.045 * arc)
            .rotation3DEffect(.degrees(Double(position) * 18),
                              axis: (x: 0, y: 1, z: 0), perspective: 0.45)
            .offset(x: position * travel, y: 8 * arc)
            .zIndex(Double(1 - distance))
    }
}

// Keep the list's order stable for the lifetime of this presentation, including
// when an edit changes a search match or sort key in the underlying list.
struct WordDetailSelection {
    private(set) var words: [WordCard]
    private(set) var index: Int
    var current: WordCard { words[index] }

    init(word: WordCard, words: [WordCard]) {
        if let index = words.firstIndex(where: { $0.id == word.id }) {
            self.words = words
            self.words[index] = word
            self.index = index
        } else {
            self.words = [word]
            self.index = 0
        }
    }

    mutating func move(by step: Int) {
        index = Self.wrappedIndex(index + step % words.count, count: words.count)
    }

    mutating func select(id: WordCard.ID) {
        guard let index = words.firstIndex(where: { $0.id == id }) else { return }
        self.index = index
    }

    mutating func replace(_ savedWord: WordCard) {
        guard let index = words.firstIndex(where: { $0.id == savedWord.id }) else { return }
        words[index] = savedWord
    }

    static func wrappedIndex(_ index: Int, count: Int) -> Int {
        guard count > 0 else { return 0 }
        return (index % count + count) % count
    }
}

/// Native horizontal paging arbitrates with each page's vertical ScrollView.
/// Only this region receives the paging gesture; the 3D card is a sibling.
private struct WordDetailPager: UIViewControllerRepresentable {
    let words: [WordCard]
    let selectedID: WordCard.ID
    let isExpanded: Bool
    let direction: UIPageViewController.NavigationDirection
    let reduceMotion: Bool
    let onProgress: (CGFloat) -> Void
    let onSelected: (WordCard.ID) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let controller = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal)
        controller.view.backgroundColor = .clear
        controller.delegate = context.coordinator
        controller.dataSource = words.count > 1 ? context.coordinator : nil
        controller.setViewControllers([context.coordinator.page(id: selectedID)], direction: .forward, animated: false)
        if let scrollView = controller.view.subviews.compactMap({ $0 as? UIScrollView }).first {
            context.coordinator.observe(scrollView)
        }
        return controller
    }

    func updateUIViewController(_ controller: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        guard !context.coordinator.isTransitioning else { return }
        guard let current = controller.viewControllers?.first as? Page else { return }
        if current.wordID == selectedID {
            // Saving an edit or moving the sheet refreshes the page without resetting the presenter.
            if let updated = words.first(where: { $0.id == selectedID }),
               current.word != updated || current.isExpanded != isExpanded {
                current.word = updated
                current.isExpanded = isExpanded
                current.rootView = WordDetailPage(word: updated, isExpanded: isExpanded)
            }
        } else {
            let coordinator = context.coordinator
            coordinator.isTransitioning = true
            controller.setViewControllers([coordinator.page(id: selectedID)], direction: direction, animated: !reduceMotion) { _ in
                // Defer SwiftUI state changes until the representable update finishes.
                DispatchQueue.main.async {
                    coordinator.isTransitioning = false
                    coordinator.parent.onSelected(selectedID)
                }
            }
        }
    }

    final class Page: UIHostingController<WordDetailPage> {
        var word: WordCard
        var isExpanded: Bool
        var wordID: WordCard.ID { word.id }

        init(word: WordCard, isExpanded: Bool) {
            self.word = word
            self.isExpanded = isExpanded
            super.init(rootView: WordDetailPage(word: word, isExpanded: isExpanded))
            view.backgroundColor = .clear
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: WordDetailPager
        var isTransitioning = false
        private var offsetObservation: NSKeyValueObservation?
        init(_ parent: WordDetailPager) { self.parent = parent }

        func observe(_ scrollView: UIScrollView) {
            // Observe without replacing UIPageViewController's private scroll delegate.
            offsetObservation = scrollView.observe(\.contentOffset, options: [.new]) { [weak self] scrollView, _ in
                let width = scrollView.bounds.width
                guard width > 0 else { return }
                let progress = min(1, max(-1, (scrollView.contentOffset.x - width) / width))
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.isTransitioning else { return }
                    self.parent.onProgress(progress)
                }
            }
        }

        func page(id: WordCard.ID) -> Page {
            Page(word: parent.words.first(where: { $0.id == id }) ?? parent.words[0], isExpanded: parent.isExpanded)
        }

        private func neighbor(of controller: UIViewController, step: Int) -> UIViewController? {
            guard parent.words.count > 1, let current = controller as? Page,
                  let index = parent.words.firstIndex(where: { $0.id == current.wordID }) else { return nil }
            let next = WordDetailSelection.wrappedIndex(index + step, count: parent.words.count)
            return Page(word: parent.words[next], isExpanded: parent.isExpanded)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            neighbor(of: viewController, step: -1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            neighbor(of: viewController, step: 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            isTransitioning = true
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            isTransitioning = false
            guard let page = pageViewController.viewControllers?.first as? Page else { return }
            parent.onSelected(page.wordID)
        }
    }
}

/// 1語ぶんのシートの中身。頭のときは単語・意味と3項目だけを見せ、ほかは7割まで上げたときに出す。
private struct WordDetailPage: View {
    let word: WordCard
    let isExpanded: Bool

    /// 浮かべたアクションバーの下に、最後の項目が隠れないよう空ける量。
    private static let footerClearance: CGFloat = 88

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(word.text).font(.largeTitle.bold())
                Text(word.meaning).font(.title3)
                metrics
                // 頭のときは、バーの周りに下の情報を透かさない。
                Group {
                    WordMetaRow(word: word)
                    if !word.tags.isEmpty { TagChipRow(tags: word.tags) }
                    DetailBlock(title: "例文", text: word.sentenceEnglish ?? "例文は準備中です。")
                    if let japanese = word.sentenceJapanese {
                        DetailBlock(title: "日本語", text: japanese)
                    }
                    DetailBlock(title: "学習メモ", text: word.learning?.studySummary ?? "まだ学習していないカードです。")
                    DetailBlock(title: "覚え方 · サンプル", text: "絵の場面を思い浮かべながら、単語を声に出してみましょう。")
                }
                .opacity(isExpanded ? 1 : 0)
                .accessibilityHidden(!isExpanded)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
        }
        .scrollDisabled(!isExpanded)
        .contentMargins(.bottom, Self.footerClearance, for: .scrollContent)
        .animation(.easeOut(duration: 0.2), value: isExpanded)
        .foregroundStyle(WireColor.ink)
    }

    /// デッキ追加画面の収録語数・容量・レベルと同じ帯に、CEFR・品詞・習得度を並べる。
    private var metrics: some View {
        SheetMetricsRow {
            SheetMetric(title: "CEFR") { Text(word.cefrLevel ?? "—").wireFont(.titleS) }
            Divider()
            SheetMetric(title: "品詞") {
                Text(WordPartOfSpeech(englishOrJapanese: word.partOfSpeech)?.rawValue ?? word.partOfSpeech ?? "—")
                    .wireFont(.titleS)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            Divider()
            SheetMetric(title: "習得度") {
                StarRating(filled: word.masteryStars, label: "星3つ中\(word.masteryStars)つ")
            }
        }
    }
}

extension WordCard {
    /// 習得度の星（3つ中いくつ塗るか）。未学習は0、復習中は Lv.1〜2 で1・Lv.3 以上で2、習得済みは3。
    var masteryStars: Int {
        switch learningStatus {
        case "mastered": 3
        case "learning": (learning?.srsLevel ?? 1) >= 3 ? 2 : 1
        default: 0
        }
    }
}

/// 詳細シートの主役カード。指の位置で傾き、横に払うと表裏がめくれる。
///
/// - 傾き: 指の「位置」を見る。カードの中心からの距離を角度に写す。
/// - めくり: 指の「移動量」を見る。deadZone を越えた分だけ Y 軸に回し、
///   離した時点で 0° か 180° の近い方へ寄せる。
///   途中で止めても角度が飛ばないよう、離した瞬間に
///   `baseAngle` へ現在角をそのまま引き継いでから寄せている。
///
/// 裏面は学習カードと同じ `StudyCardBack` を使う。裏の情報設計は1か所に置く。
private struct InteractiveWordCard: View {
    let word: WordCard
    let reduceMotion: Bool

    /// 指を離したあとに残る角度。0 が表、180 が裏。
    @State private var baseAngle: Double = 0
    /// いま指で動かしている分の横移動量。離すと 0 に戻る。
    @State private var flipDrag: CGFloat = 0
    /// カードが回っている最中か。裏面のスクロールを開けてよいかの判定に使う。
    @State private var isTurning = false
    @GestureState private var touch: CGPoint?

    /// この距離までは傾きだけ。越えた分からめくりが始まる。
    private let deadZone: CGFloat = 26

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            let height = max(1, geometry.size.height)
            let x = touch.map { min(1, max(-1, ($0.x / width - 0.5) * 2)) } ?? 0
            let y = touch.map { min(1, max(-1, ($0.y / height - 0.5) * 2)) } ?? 0
            // めくり始めたら傾きを譲る。2つの回転が同じ軸で重ならないようにする。
            let tilt = reduceMotion ? 0 : Double(max(0, 1 - abs(flipDrag) / deadZone))
            let angle = baseAngle + flipAngle(for: flipDrag, width: width)
            let showsBack = isBack(angle)
            let placeholderProgress = Double(min(1, max(0, (280 - width) / 80)))

            // 小さい枠で再配置すると画像が押しつぶされるため、通常のカード幅で
            // 配置してから全体を縮める。文字だけは 280〜200pt の間で灰色へ変える。
            face(showsBack: showsBack, placeholderProgress: placeholderProgress)
            .frame(width: 350, height: 350 / 0.74)
            .scaleEffect(width / 350)
            .frame(width: width, height: height)
            .rotation3DEffect(.degrees(-y * 13 * tilt), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(angle + x * 13 * tilt), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .scaleEffect(touch == nil || reduceMotion ? 1 : 1.025)
            .animation(touch == nil && !reduceMotion ? .spring(response: 0.4, dampingFraction: 0.7) : nil, value: touch)
            .simultaneousGesture(
                DragGesture(minimumDistance: 3, coordinateSpace: .named("wordCardTouch"))
                    .updating($touch) { value, state, _ in state = value.location }
                    .onChanged { value in
                        if !isTurning, abs(value.translation.width) > deadZone { isTurning = true }
                        flipDrag = value.translation.width
                    }
                    .onEnded { value in settle(value, width: width) }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(showsBack ? "\(word.text) の裏面" : word.text)
            .accessibilityHint("タップで詳細を表示。左右に払うと裏返ります")
            .accessibilityAction(named: showsBack ? "表に戻す" : "裏返す") { flip() }
        }
        .coordinateSpace(name: "wordCardTouch")
    }

    // MARK: - 面

    /// 表裏は同じ外形に重ねる。半分より回ったところで入れ替える。
    /// 裏面は 180° 逆に回してあり、カードが裏を向いたときに正しい向きで立つ。
    @ViewBuilder
    private func face(showsBack: Bool, placeholderProgress: Double) -> some View {
        ZStack {
            front(placeholderProgress: placeholderProgress)
                .opacity(showsBack ? 0 : 1)
                .allowsHitTesting(!showsBack)
            back(placeholderProgress: placeholderProgress)
                .opacity(showsBack ? 1 : 0)
                .allowsHitTesting(showsBack)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
    }

    private func front(placeholderProgress: Double) -> some View {
        StudyCardFace {
            StudyCardFront(card: word, content: WordCardContent(card: word), showAnswer: true,
                           placeholderProgress: placeholderProgress)
        }
    }

    private func back(placeholderProgress: Double) -> some View {
        StudyCardFace {
            // 回っている間はスクロールを閉じる。理由は `StudyCardBack` 側に書いてある。
            StudyCardBack(content: WordCardContent(card: word), isScrollEnabled: !isTurning,
                          placeholderProgress: placeholderProgress)
        }
    }

    // MARK: - 角度

    /// 横移動量を角度に写す。deadZone のぶんは傾きに使うので差し引く。
    /// カード幅の半分だけ払えば 180°、つまり1回ぶんめくれる。
    private func flipAngle(for translation: CGFloat, width: CGFloat) -> Double {
        let excess = max(0, abs(translation) - deadZone)
        let turn = Double(excess / (width * 0.5)) * 180
        return (translation < 0 ? -1 : 1) * min(360, turn)
    }

    private func isBack(_ angle: Double) -> Bool {
        let normalized = (angle.truncatingRemainder(dividingBy: 360) + 360)
            .truncatingRemainder(dividingBy: 360)
        return normalized > 90 && normalized < 270
    }

    /// 指を離したときに、いちばん近い面へ寄せる。
    /// 勢いを少し足すので、浅く速く払っただけでもめくれる。
    private func settle(_ value: DragGesture.Value, width: CGFloat) {
        let current = baseAngle + flipAngle(for: value.translation.width, width: width)
        let momentum = value.predictedEndTranslation.width - value.translation.width
        let predicted = current + Double(momentum / (width * 0.5)) * 180 * 0.35
        let snapped = (predicted / 180).rounded() * 180

        // 角度を飛ばさずに引き継ぐ。ここは見た目が変わらないので animation を切る。
        var handover = Transaction()
        handover.disablesAnimations = true
        withTransaction(handover) {
            baseAngle = current
            flipDrag = 0
        }
        turn(to: snapped)
    }

    private func flip() {
        isTurning = true
        turn(to: baseAngle + 180)
    }

    /// 目的の角度まで回し、止まったところで裏面のスクロールを開け直す。
    private func turn(to angle: Double) {
        withAnimation(reduceMotion ? nil : .spring(response: 0.45, dampingFraction: 0.82)) {
            baseAngle = angle
        } completion: {
            isTurning = false
        }
    }
}

struct WordMetaRow: View {
    let word: WordCard

    var body: some View {
        // 状態と品詞は上の3項目に出すので、ここでは重ねない。
        HStack(spacing: WireMetrics.spacingS) {
            if let learning = word.learning {
                WirePill(title: "Lv.\(learning.srsLevel)", font: .caption)
            }
            WirePill(title: "\(word.tags.count)タグ", font: .caption)
        }
        .padding(.top, WireMetrics.spacingXS)
    }
}

struct DetailBlock: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
            Text(title)
                .wireFont(.caption)
            Text(text)
                .wireFont(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(WireMetrics.spacingL)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}

extension WordLearningSnapshot {
    var studySummary: String {
        "SRS Lv.\(srsLevel) / \(repetitions)回復習 / 次回: \(formattedNextReviewDate) / 間隔: \(intervalDays)日"
    }

    var formattedNextReviewDate: String {
        let parser = ISO8601DateFormatter()
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: nextReviewDate) {
            return Self.dateFormatter.string(from: date)
        }
        return nextReviewDate
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
