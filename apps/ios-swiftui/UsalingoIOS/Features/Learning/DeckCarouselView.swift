import SwiftUI

/// 学習タブの並びの1枠。デッキか、両端に置く空き枠。
enum DeckSlot: Hashable, Identifiable {
    case deck(Deck)
    case empty(DeckSlotEdge)

    var id: String {
        switch self {
        case .deck(let deck): return "deck-\(deck.id)"
        case .empty(let edge): return "empty-\(edge)"
        }
    }

    var deck: Deck? {
        if case .deck(let deck) = self { return deck }
        return nil
    }

    /// 先頭と末尾に空き枠を1つずつ置く。デッキが無いときは空き枠1つだけにする。
    static func slots(for decks: [Deck]) -> [DeckSlot] {
        guard !decks.isEmpty else { return [.empty(.bottom)] }
        return [.empty(.top)] + decks.map(DeckSlot.deck) + [.empty(.bottom)]
    }
}

/// カルーセルの1枚がふつうのデッキか、フォルダか、フォルダの中のデッキか。
enum DeckCardRole: Equatable {
    case deck
    case folder(isExpanded: Bool)
    case child

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

/// 長押しメニューの1行。
struct DeckMenuItem: Identifiable {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let action: () -> Void

    var id: String { title }
}

/// 空き枠がどちらの端か。追加したデッキはこの端へ入る。
enum DeckSlotEdge: Hashable {
    case top
    case bottom
}

/// 学習画面のデッキ一覧。上下のスワイプで回す平面のカルーセル。
///
/// 動きは音声モードのカルーセル（`AudioCarouselMotion`）と同じで、枠に磁石のように吸い付き、
/// 指を離すと勢いに応じた枠でピタッと止まる。中央の枠だけが縦に広がり、デッキなら表紙・名前・進み具合を
/// 見せる。ほかは表紙と名前だけの細い帯にする。両端の空き枠をタップするとデッキを足せる。
/// 空き枠も中央では同じだけ広げる。高さがそろうので、どの枠の間でも1枠ぶんの移動量が同じになる。
struct DeckCarouselView: View {
    /// 見た目の寸法。帯と中央の大きさはここだけで決める。
    private enum Metrics {
        static let bandHeight: CGFloat = 64
        static let expandedHeight: CGFloat = 240
        static let spacing: CGFloat = 10
        /// 表紙が占める横幅の割合。帯でも中央でも同じ幅にして、高さだけを伸ばす。
        static let coverWidthRatio: CGFloat = 0.45
        /// 帯の横幅。中央のカードより少し細くして、主役を目立たせる。
        static let bandWidthRatio: CGFloat = 0.92
        /// フォルダの中のデッキを右へ寄せる幅。
        static let childIndent: CGFloat = 24
    }

    private let layout = DeckCarouselLayout(
        bandHeight: Metrics.bandHeight,
        expandedHeight: Metrics.expandedHeight,
        spacing: Metrics.spacing
    )

    let decks: [Deck]
    /// 最初に中央へ置くデッキ。見つからなければ先頭のデッキにする。
    let centeredDeckId: Int?
    let coverURL: (Deck) -> URL?
    let summary: (Deck) -> DeckProgressSummary
    let onOpen: (Deck) -> Void
    let onSelect: (Deck) -> Void
    let onAdd: (DeckSlotEdge) -> Void
    /// その枠がフォルダか、フォルダの中のデッキか。
    var role: (Deck) -> DeckCardRole = { _ in .deck }
    /// フォルダのカードに重ねて見せる、中のデッキ。
    var children: (Deck) -> [Deck] = { _ in [] }
    /// フォルダの「＋」。中のデッキを出し入れする。
    var onToggleFolder: (Deck) -> Void = { _ in }
    /// 長押し。押したカードの画面上の位置を渡し、呼ぶ側が自前のメニューを重ねる。
    let onLongPress: (Deck, CGRect) -> Void
    /// 長押しのまま指を動かし始めた。呼ぶ側はメニューを閉じる。
    var onDragStart: (Deck) -> Void = { _ in }
    /// 指を離した。番号はどちらも `decks` の中での位置。
    var onDrop: (Int, DeckDropTarget) -> Void = { _, _ in }

    private static let coordinateSpace = "deckCarousel"
    /// 端からこの距離まで指を寄せると、カルーセルを1枚ずつ送る。
    private static let autoScrollEdge: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = AudioCarouselMotion()
    /// 中央で止まっている枠。動いている途中は、指を離したあと止まるまで変えない。
    @State private var centerIndex = 0
    /// カードごとの画面上の位置。書き換えても描き直さないよう、参照で持つ。
    @State private var cardFrames = CardFrameBox()
    /// 長押しが決まった枠。指を離すまで持つ。
    @State private var pressedIndex: Int?
    /// 長押しのあと指で運んでいるカード。
    @State private var drag: CardDrag?
    @GestureState private var isPressing = false
    /// 端へ寄せて送っている向き。-1 で上、1 で下、0 で止める。
    @State private var autoScrollDirection = 0
    @State private var viewportSize: CGSize = .zero

    private struct CardDrag {
        let deck: Deck
        let slotIndex: Int
        var location: CGPoint
        var target: DeckDropTarget?
    }

    private var slots: [DeckSlot] { DeckSlot.slots(for: decks) }

    var body: some View {
        GeometryReader { proxy in
            let center = -motion.position / layout.stride

            ZStack {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let offset = CGFloat(index) - center
                    let y = layout.y(offset: offset)
                    // 画面の外の枠は描かない。
                    if abs(y) < proxy.size.height {
                        let expansion = layout.expansion(offset: offset)
                        slotView(slot, index: index, expansion: expansion,
                                 width: proxy.size.width, height: layout.height(offset: offset))
                            .offset(y: y)
                            .zIndex(Double(expansion))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            .overlay { dragOverlay(size: proxy.size, center: center) }
            .coordinateSpace(name: Self.coordinateSpace)
            .onAppear { viewportSize = proxy.size }
            .onChange(of: proxy.size) { _, size in viewportSize = size }
        }
        .onAppear { synchronize() }
        .onDisappear { motion.stop() }
        .onChange(of: slots.map(\.id)) { _, _ in synchronize() }
        .onChange(of: reduceMotion) { _, reduced in
            if reduced, motion.isMoving {
                motion.snap(to: motion.nearestIndex, animated: false, completion: complete)
            }
        }
        .onChange(of: isPressing) { _, pressing in
            // システムに指を取り上げられたときは onEnded が来ないので、ここで片付ける。
            if !pressing { cancelPress() }
        }
        .task(id: autoScrollDirection) { await autoScroll() }
    }

    // MARK: - 1枠

    @ViewBuilder
    private func slotView(_ slot: DeckSlot, index: Int, expansion: CGFloat,
                          width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (Metrics.bandWidthRatio + (1 - Metrics.bandWidthRatio) * expansion)
        Group {
            switch slot {
            case .deck(let deck):
                let merging = isMergeTarget(rowIndex: index - 1)
                Group {
                    if case .folder(let isExpanded) = role(deck) {
                        folderCard(deck, isExpanded: isExpanded, expansion: expansion, width: cardWidth, height: height)
                    } else {
                        deckCard(deck, expansion: expansion, width: cardWidth, height: height)
                    }
                }
                .modifier(cardInteractions(deck, index: index))
                .overlay {
                    if merging {
                        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                            .strokeBorder(WireColor.ink, lineWidth: 3)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .scaleEffect(merging ? 1.04 : 1)
                // 位置の記録より外で寄せ、メニューの切り抜きとカードの位置をそろえる。
                .offset(x: role(deck) == .child ? Metrics.childIndent / 2 : 0)
                .opacity(drag?.slotIndex == index ? 0.35 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: merging)
            case .empty(let edge):
                emptyCard(edge, width: cardWidth, height: height)
            }
        }
        // ponytail: VoiceOver は中央の枠だけを読み、上下の操作で隣へ移すだけの最低限。
        // 作り込みは後でまとめて行う（AGENTS.md の方針）。
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: snap(to: centerIndex + 1)
            case .decrement: snap(to: centerIndex - 1)
            @unknown default: break
            }
        }
        .accessibilityHidden(index != centerIndex)
    }

    private func deckCard(_ deck: Deck, expansion: CGFloat, width fullWidth: CGFloat, height: CGFloat) -> some View {
        let progress = summary(deck)
        let isChild = role(deck) == .child
        // フォルダの中のデッキは、少し右へ寄せて細くし、どのフォルダの下かを見せる。
        let width = isChild ? fullWidth - Metrics.childIndent : fullWidth

        return HStack(alignment: .top, spacing: WireMetrics.spacingM) {
            DeckCoverImage(url: coverURL(deck), symbol: DeckCoverSymbol.forDeck(id: deck.id))
                .frame(width: width * Metrics.coverWidthRatio)
                .frame(maxHeight: .infinity)

            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                Text(deck.deckName)
                    .wireFont(expansion > 0.5 ? .titleS : .label)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                // 中央へ近づくほど、進み具合を浮かび上がらせる。
                VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                    DeckMasteryBar(
                        masteredCount: progress.masteredCount,
                        totalCount: progress.totalCount,
                        ratio: progress.masteryRatio,
                        percentText: progress.masteryPercentText
                    )
                    ViewThatFits(in: .horizontal) {
                        DeckStatusChips(summary: progress)
                        DeckStatusChips(summary: progress, axis: .vertical)
                    }
                }
                .opacity(Double(expansion))
            }
            .padding(.vertical, WireMetrics.spacingS)
        }
        .padding(WireMetrics.spacingS)
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
    }

    /// フォルダのカード。中のデッキの表紙を上に重ね、下のガラスの帯に名前と「＋」を置く。
    /// 帯の高さは細い帯の枠と同じなので、中央から離れると帯だけが残る。
    private func folderCard(_ deck: Deck, isExpanded: Bool, expansion: CGFloat,
                            width: CGFloat, height: CGFloat) -> some View {
        let covers = Array(children(deck).prefix(4))
        let coverSize = max(0, min(130, height - Metrics.bandHeight - WireMetrics.spacingS))
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)

        return ZStack(alignment: .bottom) {
            HStack(spacing: -coverSize * 0.3) {
                if covers.isEmpty {
                    DeckCoverImage(url: nil, symbol: "folder")
                        .frame(width: coverSize, height: coverSize)
                }
                ForEach(Array(covers.enumerated()), id: \.element.id) { offset, child in
                    DeckCoverImage(url: coverURL(child), symbol: DeckCoverSymbol.forDeck(id: child.id))
                        .frame(width: coverSize, height: coverSize)
                        .rotationEffect(.degrees(offset.isMultiple(of: 2) ? -4 : 4))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .padding(.top, WireMetrics.spacingS)
            .opacity(Double(expansion))
            .accessibilityHidden(true)

            HStack(spacing: WireMetrics.spacingS) {
                Text(deck.deckName)
                    .wireFont(expansion > 0.5 ? .titleS : .label, color: WireColor.surface)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    onToggleFolder(deck)
                } label: {
                    Image(systemName: isExpanded ? "minus" : "plus")
                        .font(.body.weight(.bold))
                        .foregroundStyle(WireColor.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(WireColor.surface))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isExpanded ? "フォルダを閉じる" : "フォルダを開く")
            }
            .padding(.horizontal, WireMetrics.spacingM)
            .frame(height: Metrics.bandHeight)
            // 白い文字が表紙の上でも読めるよう、ぼかしに暗い色を重ねる。
            .background(Color.black.opacity(0.35))
            .background(.ultraThinMaterial)
        }
        .frame(width: width, height: height)
        .background(BentoTone.l2.fill)
        .clipShape(shape)
        .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
    }

    /// タップで開き、長押しでメニュー、長押しのまま動かすと並べ替え。
    private func cardInteractions(_ deck: Deck, index: Int) -> some ViewModifier {
        CardInteractions(
            deck: deck,
            isFolder: role(deck).isFolder,
            progress: summary(deck),
            onTap: { index == centerIndex ? onOpen(deck) : snap(to: index) },
            press: pressGesture(deck: deck, index: index),
            onFrame: { cardFrames.frames[deck.id] = $0 },
            onMenu: { presentMenu(for: deck) }
        )
    }

    private func presentMenu(for deck: Deck) {
        HapticFeedbackService.swipeThresholdCrossed()
        onLongPress(deck, cardFrames.frames[deck.id] ?? .zero)
    }

    /// 空き枠。どこにあってもタップでデッキライブラリを開く。
    private func emptyCard(_ edge: DeckSlotEdge, width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
            .fill(BentoTone.l3.fill)
            .overlay {
                Image(systemName: "plus")
                    .wireFont(.titleS)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(WireColor.surface))
                    .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
            }
            .overlay(
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .strokeBorder(WireColor.ink, style: StrokeStyle(lineWidth: WireMetrics.strokeHair, dash: [5, 4]))
            )
            .frame(width: width, height: height)
            .contentShape(Rectangle())
            .onTapGesture { onAdd(edge) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(edge == .top ? "先頭にデッキを追加" : "末尾にデッキを追加")
            .accessibilityHint("デッキライブラリを開きます")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - 長押しで運ぶ

    private func pressGesture(deck: Deck, index: Int) -> AnyGesture<Void> {
        AnyGesture(
            LongPressGesture(minimumDuration: 0.45)
                .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace)))
                .updating($isPressing) { _, state, _ in state = true }
                .onChanged { value in
                    guard case .second(true, let dragValue) = value else { return }
                    if pressedIndex != index {
                        pressedIndex = index
                        presentMenu(for: deck)
                    }
                    guard let dragValue else { return }
                    if drag == nil {
                        // 指を少し動かしたら、メニューをやめて運び始める。
                        guard hypot(dragValue.translation.width, dragValue.translation.height) > 8 else { return }
                        drag = CardDrag(deck: deck, slotIndex: index, location: dragValue.location)
                        onDragStart(deck)
                    }
                    updateDrag(to: dragValue.location)
                }
                .onEnded { _ in finishDrag() }
                .map { _ in () }
        )
    }

    private func updateDrag(to location: CGPoint) {
        guard var current = drag else { return }
        current.location = location
        let target = dropTarget(at: location, rowOfDragged: current.slotIndex - 1)
        if target != current.target {
            current.target = target
            HapticFeedbackService.detent()
        }
        drag = current
        let edge = Self.autoScrollEdge
        autoScrollDirection = location.y < edge ? -1 : (location.y > viewportSize.height - edge ? 1 : 0)
    }

    private func finishDrag() {
        let finished = drag
        cancelPress()
        guard let finished, let target = finished.target else { return }
        onDrop(finished.slotIndex - 1, target)
    }

    private func cancelPress() {
        drag = nil
        pressedIndex = nil
        autoScrollDirection = 0
    }

    /// 端へ寄せている間、1枚ずつ送る。送ったら、指の下の落とし先を選び直す。
    private func autoScroll() async {
        guard autoScrollDirection != 0 else { return }
        while !Task.isCancelled, drag != nil {
            snap(to: centerIndex + autoScrollDirection)
            try? await Task.sleep(for: .seconds(0.45))
            if let location = drag?.location { updateDrag(to: location) }
        }
    }

    /// 指の位置にある枠と、その上・真ん中・下のどこか。
    private func dropTarget(at point: CGPoint, rowOfDragged: Int) -> DeckDropTarget? {
        let center = -motion.position / layout.stride
        for (index, slot) in slots.enumerated() {
            let offset = CGFloat(index) - center
            let midY = viewportSize.height / 2 + layout.y(offset: offset)
            let height = layout.height(offset: offset)
            guard point.y >= midY - (height + layout.spacing) / 2,
                  point.y < midY + (height + layout.spacing) / 2 else { continue }
            switch slot {
            case .empty(.top): return .start
            case .empty(.bottom): return .end
            case .deck:
                guard index - 1 != rowOfDragged else { return nil }
                let ratio = (point.y - (midY - height / 2)) / max(height, 1)
                return .row(index - 1, ratio < 0.25 ? .before : (ratio > 0.75 ? .after : .onto))
            }
        }
        return point.y < viewportSize.height / 2 ? .start : .end
    }

    /// 重ねるとフォルダにまとまる枠か。フォルダは重ねられないので、運んでいるのがフォルダなら出さない。
    private func isMergeTarget(rowIndex: Int) -> Bool {
        guard let drag, drag.target == .row(rowIndex, .onto) else { return false }
        return !role(drag.deck).isFolder
    }

    /// 運んでいるカードと、差し込む位置の線。指には触れない。
    @ViewBuilder
    private func dragOverlay(size: CGSize, center: CGFloat) -> some View {
        if let drag {
            ZStack {
                if let lineY = insertionLineY(for: drag.target, dragged: drag.deck, size: size, center: center) {
                    Capsule()
                        .fill(WireColor.ink)
                        .frame(width: size.width * Metrics.bandWidthRatio, height: 4)
                        .position(x: size.width / 2, y: lineY)
                }
                floatingCard(drag.deck)
                    .frame(width: size.width * Metrics.bandWidthRatio, height: Metrics.bandHeight)
                    .position(drag.location)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    private func insertionLineY(for target: DeckDropTarget?, dragged: Deck, size: CGSize, center: CGFloat) -> CGFloat? {
        let slotIndex: Int
        let isBefore: Bool
        switch target {
        case .none:
            return nil
        case .start:
            slotIndex = 1
            isBefore = true
        case .end:
            slotIndex = slots.count - 2
            isBefore = false
        case .row(let row, let zone):
            // フォルダは重ねられないので、真ん中でも後ろへ差し込む線を出す。
            if zone == .onto, !role(dragged).isFolder { return nil }
            slotIndex = row + 1
            isBefore = zone == .before
        }
        guard slots.indices.contains(slotIndex) else { return nil }
        let offset = CGFloat(slotIndex) - center
        let midY = size.height / 2 + layout.y(offset: offset)
        let half = (layout.height(offset: offset) + layout.spacing) / 2
        return isBefore ? midY - half : midY + half
    }

    private func floatingCard(_ deck: Deck) -> some View {
        HStack(spacing: WireMetrics.spacingM) {
            DeckCoverImage(url: coverURL(deck), symbol: role(deck).isFolder ? "folder" : DeckCoverSymbol.forDeck(id: deck.id))
                .frame(width: 48, height: 48)
            Text(deck.deckName)
                .wireFont(.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(WireMetrics.spacingS)
        .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
        .scaleEffect(1.05)
        .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
    }

    // MARK: - 動かす

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard slots.count > 1 else { return }
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

    /// 覚えているデッキを中央へ置き直す。デッキの増減で並びが変わったときも呼ぶ。
    private func synchronize() {
        let slots = self.slots
        let remembered = slots.firstIndex { $0.deck?.id == centeredDeckId && centeredDeckId != nil }
        let firstDeck = slots.firstIndex { $0.deck != nil }
        centerIndex = remembered ?? firstDeck ?? 0
        motion.configure(stride: layout.stride, count: slots.count, index: centerIndex)
    }

    private func snap(to index: Int) {
        let target = min(max(0, index), slots.count - 1)
        guard target != centerIndex else { return }
        motion.snap(to: target, animated: !reduceMotion, completion: complete)
    }

    private func complete(at index: Int) {
        centerIndex = index
        if let deck = slots[index].deck { onSelect(deck) }
    }
}

/// カードのタップ・長押し・位置の記録・読み上げを、デッキとフォルダで共通にまとめる。
private struct CardInteractions: ViewModifier {
    let deck: Deck
    let isFolder: Bool
    let progress: DeckProgressSummary
    let onTap: () -> Void
    let press: AnyGesture<Void>
    let onFrame: (CGRect) -> Void
    let onMenu: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .gesture(press)
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onFrame($0) }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isFolder ? "フォルダ \(deck.deckName)" : deck.deckName)
            .accessibilityValue("\(progress.totalCount) 語のうち \(progress.masteredCount) 語を習得")
            .accessibilityHint("選んだ遊び方で開きます")
            .accessibilityAddTraits(.isButton)
            // ponytail: 支援技術からは名前付きの操作でメニューを開くだけの最低限。作り込みは後でまとめて行う。
            .accessibilityAction(named: "メニュー", onMenu)
    }
}

/// カルーセルの並び計算。見た目と切り離してあるので、単体で確かめられる。
///
/// 中央の枠ほど高く、離れた枠は帯の高さになる。どの枠も広がり方が同じなので、中央と隣の
/// 中心どうしは常に `stride` だけ離れ、指の移動と枠の移動がそろう。一周はしない。
struct DeckCarouselLayout {
    let bandHeight: CGFloat
    let expandedHeight: CGFloat
    let spacing: CGFloat

    /// 1枠ぶん進むときに動く距離。中央の枠と隣の帯の、中心どうしの間隔と同じ。
    var stride: CGFloat { (bandHeight + expandedHeight) / 2 + spacing }

    /// 中央へどれだけ近いか。`offset` は中央からの枠の数で、0 がちょうど中央、1 以上離れると帯。
    func expansion(offset: CGFloat) -> CGFloat {
        max(0, 1 - abs(offset))
    }

    func height(offset: CGFloat) -> CGFloat {
        bandHeight + (expandedHeight - bandHeight) * expansion(offset: offset)
    }

    /// 画面中央からの縦位置。中央の隣までは `stride` 刻み、その先は帯どうしの間隔で並べる。
    func y(offset: CGFloat) -> CGFloat {
        let distance = abs(offset)
        let y = min(distance, 1) * stride + max(distance - 1, 0) * (bandHeight + spacing)
        return offset < 0 ? -y : y
    }
}

/// 最後に中央へ置いたデッキを端末へ覚えておく。並び順は、フォルダと一緒に学習データ
/// （`LocalStudyLibrary.layout`）へ移した。ここに残る並び順は、移す前の並びを引き継ぐためだけに読む。
///
/// 利用者ごとに分けて覚える。端末で作ったデッキの番号は利用者ごとに 1 から振るので、
/// 分けないと別の人の同じ番号のデッキを指してしまう。
/// 覚えていないデッキは末尾へ足し、消えたデッキは詰める。
struct DeckOrderStore {
    private let orderKey: String
    private let selectedKey: String
    private let defaults: UserDefaults

    init(accountId: String, defaults: UserDefaults = .standard) {
        orderKey = "learning.deckOrder.\(accountId)"
        selectedKey = "learning.selectedDeck.\(accountId)"
        self.defaults = defaults
    }

    /// 覚えた順に並べ、その結果を覚え直す。
    func arranged(_ decks: [Deck]) -> [Deck] {
        let saved = defaults.array(forKey: orderKey) as? [Int] ?? []
        let rank = Dictionary(saved.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let result = decks.enumerated()
            .sorted { lhs, rhs in
                (rank[lhs.element.id] ?? saved.count + lhs.offset)
                    < (rank[rhs.element.id] ?? saved.count + rhs.offset)
            }
            .map(\.element)
        defaults.set(result.map(\.id), forKey: orderKey)
        return result
    }

    var selectedDeckId: Int? {
        get { defaults.object(forKey: selectedKey) as? Int }
        nonmutating set { defaults.set(newValue, forKey: selectedKey) }
    }

    /// 退会したときに、その人の並び順を消す。
    func removeAll() {
        defaults.removeObject(forKey: orderKey)
        defaults.removeObject(forKey: selectedKey)
    }
}

/// デッキの表紙。正方形に切り抜いて枠いっぱいに出す。
/// 画像が無いときと読み込めないときは、デッキの見分け記号を置いた仮表紙にする。
struct DeckCoverImage: View {
    let url: URL?
    let symbol: String

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
        // 大きさは外から渡された正方形に決めさせ、画像はその中へはみ出したぶんを切り落とす。
        // 画像自身に大きさを決めさせると、横長の絵が枠を押し広げてしまう。
        return Color.clear
            .overlay {
                CardImage(url: url, contentMode: .fill, showsLoadingIndicator: false) {
                    fallback
                }
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            .accessibilityHidden(true)
    }

    private var fallback: some View {
        ZStack {
            WireImagePlaceholder(radius: WireMetrics.radiusControl)
            Image(systemName: symbol)
                .wireFont(.titleL)
        }
    }
}

/// カードの位置を覚えておく入れ物。指で回している間は毎フレーム変わるので、描き直しの引き金にしない。
private final class CardFrameBox {
    var frames: [Int: CGRect] = [:]
}
