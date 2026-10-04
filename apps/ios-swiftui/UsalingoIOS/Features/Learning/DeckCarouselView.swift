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

/// カルーセルの1枚がふつうのデッキか、フォルダか。
enum DeckCardRole: Equatable {
    case deck
    case folder(isExpanded: Bool)

    var isFolder: Bool {
        if case .folder = self { return true }
        return false
    }
}

/// 長押しメニューの1つのボタン。
struct DeckMenuItem: Identifiable {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    /// 決まったら、押さえている指の下でデッキを持ち上げて運び始める。
    var startsDrag = false
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
        /// 開いたフォルダの中に縦に積む、横幅いっぱいの行。
        static let tileHeight: CGFloat = 64
        static let tileSpacing: CGFloat = 8
        /// 開いたフォルダの上に置く、名前と下線の見出し。
        static let folderHeaderHeight: CGFloat = 56
        /// 開いたフォルダが画面の高さに占める上限。超える分はフォルダの中だけでスクロールする。
        static let openFolderMaxRatio: CGFloat = 0.72
        /// 帯だけを並べるときの、1枠ぶんの間隔。
        static var bandStride: CGFloat { bandHeight + spacing }
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
    /// その枠がフォルダか。開いているか。
    var role: (Deck) -> DeckCardRole = { _ in .deck }
    /// フォルダの中のデッキ。閉じているときは表紙を重ね、開くと横幅いっぱいの行で縦に積む。
    var children: (Deck) -> [Deck] = { _ in [] }
    /// フォルダの「＋」「－」。
    var onToggleFolder: (Deck) -> Void = { _ in }
    /// 長押し。押したカードと指の画面上の位置を渡し、呼ぶ側が自前のメニューを重ねる。
    let onLongPress: (Deck, CGRect, CGPoint) -> Void
    /// 長押しのまま指を動かした。指の画面上の位置を渡す。メニューを続けるなら true を返し、
    /// そのときはデッキを運び始めない。
    var onPressMove: (CGPoint) -> Bool = { _ in false }
    /// 長押しのあと、デッキを運ばずに指を離した。呼ぶ側はメニューを閉じる。
    var onPressEnd: () -> Void = {}
    /// メニューで並び替えが決まったデッキ。押さえている指の下で持ち上げて運び始める。
    var liftDeckId: Int?
    /// 長押しのまま指を動かし始めた。呼ぶ側はメニューを閉じる。
    var onDragStart: (Deck) -> Void = { _ in }
    /// 運び終えた（落とした・取りやめた）。
    var onDragEnd: () -> Void = {}
    /// 一覧の上で指を離した。
    var onDrop: (DeckDragSource, DeckDropTarget) -> Void = { _, _ in }
    /// 開いたフォルダの中で並べ替えた。デッキ、フォルダ（学習用のデッキ番号）、動かした先の位置。
    var onReorderInFolder: (_ deckId: Int, _ folderDeckId: Int, _ index: Int) -> Void = { _, _, _ in }

    private static let coordinateSpace = "deckCarousel"
    private static let gridCoordinateSpace = "deckFolderGrid"
    /// 端からこの距離まで指を寄せると、カルーセルを1枚ずつ送る。
    private static let autoScrollEdge: CGFloat = 72

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = AudioCarouselMotion()
    /// 中央で止まっている枠。動いている途中は、指を離したあと止まるまで変えない。
    @State private var centerIndex = 0
    /// カードごとの画面上の位置。書き換えても描き直さないよう、参照で持つ。
    @State private var cardFrames = CardFrameBox()
    /// 長押しが決まったデッキ。指を離すまで持つ。
    @State private var pressedDeckId: Int?
    /// 長押しが決まったデッキと、その出どころ。メニューで並び替えが決まったときに持ち上げる。
    @State private var pressedCard: (deck: Deck, source: CardDrag.Source)?
    /// 長押しのあと指で運んでいるカード。
    @State private var drag: CardDrag?
    @GestureState private var isPressing = false
    /// 長押しの途中（メニューが出る前）で押さえているデッキ。そのカードを少し縮めて、押していることを見せる。
    /// 指を離して長押しをやめたときは、ばねで元の大きさへ戻す。
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.25, dampingFraction: 0.7)))
    private var holdingDeckId: Int?
    /// 端へ寄せて送っている向き。-1 で上、1 で下、0 で止める。
    @State private var autoScrollDirection = 0
    @State private var viewportSize: CGSize = .zero
    /// 開いたフォルダの中のスクロール量。
    @State private var gridScrollOffset: CGFloat = 0

    private struct CardDrag {
        enum Source: Equatable {
            /// 一覧の1枚。番号は `slots` での位置。
            case slot(Int)
            /// 開いたフォルダの中のタイル。番号はフォルダの `slots` での位置。
            case child(folderSlot: Int)
        }

        let deck: Deck
        let source: Source
        var location: CGPoint
        /// フォルダの中のタイルを、まだそのフォルダの中で動かしている。
        var isInFolder: Bool
        /// 帯に並べた一覧で空き箱を置く位置。運ぶカードを除いた並びの、隙間の番号。
        var gap: Int
        var target: DeckDropTarget?
        /// フォルダの中で空き箱を置く位置。
        var tileGap: Int
    }

    private struct Placement {
        var y: CGFloat
        var height: CGFloat
        var expansion: CGFloat
    }

    private var slots: [DeckSlot] { DeckSlot.slots(for: decks) }

    /// 帯だけを並べて運んでいる最中か。運び始めると、中央のカードも帯に戻して見た目の急な変化をなくす。
    private var isBandMode: Bool { drag.map { !$0.isInFolder } ?? false }

    var body: some View {
        GeometryReader { proxy in
            let center = -motion.position / layout.stride

            ZStack {
                ForEach(Array(slots.enumerated()), id: \.element.id) { index, slot in
                    let place = placement(of: index, center: center, size: proxy.size)
                    // 画面の外の枠は描かない。ただし運んでいるカード（とその元のフォルダ）は消さない。
                    // 消すと、指で押さえている操作そのものが打ち切られてしまう。
                    if abs(place.y) < proxy.size.height || isDragOrigin(index) {
                        slotView(slot, index: index, expansion: place.expansion,
                                 width: proxy.size.width, height: place.height)
                            .offset(y: place.y)
                            .zIndex(Double(place.expansion))
                    }
                }
                if let drag, isBandMode {
                    dropPlaceholder(width: proxy.size.width * Metrics.bandWidthRatio, height: Metrics.bandHeight)
                        .offset(y: (CGFloat(drag.gap) - center) * Metrics.bandStride)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(dragGesture)
            // 長押しは指の場所を教えてくれないので、触れた場所をここで覚えておき、メニューをその下に出す。
            // 回すための `dragGesture` より外に付ける。内に付けると、こちらが指を先に取ってスクロールできなくなる。
            .simultaneousGesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        // 新しい指なら、前の指の目印が残っていても外す（指を取り上げられて onEnded が来なかったとき）。
                        if cardFrames.touchDown != value.startLocation { cardFrames.isTapSuppressed = false }
                        cardFrames.touchDown = value.startLocation
                    }
                    // 指を離したときのタップを除き終えてから、次の指のために目印を外す。
                    .onEnded { _ in DispatchQueue.main.async { cardFrames.isTapSuppressed = false } }
            )
            .overlay { floatingCard(size: proxy.size) }
            .coordinateSpace(name: Self.coordinateSpace)
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: { cardFrames.origin = $0 }
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
        .onChange(of: liftDeckId) { _, id in lift(id) }
    }

    // MARK: - 並べ方

    /// 枠の縦位置と大きさ。運んでいる間は全部を帯にして、空き箱の分だけ後ろをずらす。
    /// 開いたフォルダは縦に伸ばし、上下の枠をその分だけ外へ押し出す。
    private func placement(of index: Int, center: CGFloat, size: CGSize) -> Placement {
        if let drag, isBandMode {
            let position = virtualIndex(of: index, in: drag) ?? CGFloat(index)
            return Placement(y: (position - center) * Metrics.bandStride, height: Metrics.bandHeight, expansion: 0)
        }
        let offset = CGFloat(index) - center
        var place = Placement(y: layout.y(offset: offset), height: layout.height(offset: offset),
                              expansion: layout.expansion(offset: offset))
        if let open = openFolderSlot, let folder = slots[open].deck {
            let extra = openFolderHeight(childCount: children(folder).count, size: size) - layout.expandedHeight
            let openExpansion = layout.expansion(offset: CGFloat(open) - center)
            if index == open {
                place.height += extra * openExpansion
            } else {
                place.y += (index < open ? -1 : 1) * extra / 2 * openExpansion
            }
        }
        return place
    }

    /// 運ぶカードを除き、空き箱を差し込んだ並びでの位置。運んでいるカード自身は nil。
    private func virtualIndex(of slotIndex: Int, in drag: CardDrag) -> CGFloat? {
        guard let position = remainingSlots(for: drag).firstIndex(of: slotIndex) else { return nil }
        return CGFloat(position < drag.gap ? position : position + 1)
    }

    /// 運ぶカードを除いた枠の番号。フォルダの中から運ぶタイルは一覧の枠ではないので、全部残る。
    private func remainingSlots(for drag: CardDrag) -> [Int] {
        if case .slot(let dragged) = drag.source { return slots.indices.filter { $0 != dragged } }
        return Array(slots.indices)
    }

    /// 運んでいるカードの元の枠か。フォルダの中のタイルを運んでいるときは、そのフォルダ。
    private func isDragOrigin(_ index: Int) -> Bool {
        guard let drag else { return false }
        return drag.source == .slot(index) || drag.source == .child(folderSlot: index)
    }

    private var openFolderSlot: Int? {
        slots.firstIndex { slot in
            guard let deck = slot.deck else { return false }
            return role(deck) == .folder(isExpanded: true)
        }
    }

    private func openFolderHeight(childCount: Int, size: CGSize) -> CGFloat {
        let content = gridContentHeight(count: childCount) + WireMetrics.spacingS * 2 + Metrics.folderHeaderHeight
        return min(max(layout.expandedHeight, content), max(layout.expandedHeight, size.height * Metrics.openFolderMaxRatio))
    }

    private func gridContentHeight(count: Int) -> CGFloat {
        let rows = CGFloat(max(1, count))
        return rows * Metrics.tileHeight + (rows - 1) * Metrics.tileSpacing
    }

    // MARK: - 1枠

    @ViewBuilder
    private func slotView(_ slot: DeckSlot, index: Int, expansion: CGFloat,
                          width: CGFloat, height: CGFloat) -> some View {
        let cardWidth = width * (Metrics.bandWidthRatio + (1 - Metrics.bandWidthRatio) * expansion)
        Group {
            switch slot {
            case .deck(let deck):
                let merging = drag.map { $0.target == .row(index - 1, .onto) } ?? false
                Group {
                    if case .folder(let isOpen) = role(deck) {
                        folderCard(deck, slotIndex: index, isOpen: isOpen && !isBandMode,
                                   keepsGrid: drag?.source == .child(folderSlot: index), expansion: expansion,
                                   width: cardWidth, height: height)
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
                .opacity(drag?.source == .slot(index) ? 0 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: merging)
            case .empty(let edge):
                // 運んでいる間は、デッキを足す空き枠を隠す。
                emptyCard(edge, width: cardWidth, height: height)
                    .opacity(isBandMode ? 0 : 1)
                    .allowsHitTesting(!isBandMode)
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

    private func deckCard(_ deck: Deck, expansion: CGFloat, width: CGFloat, height: CGFloat) -> some View {
        let progress = summary(deck)

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

    /// フォルダのカード。閉じているときは中のデッキの表紙を上に重ね、下のガラスの帯に名前と「＋」を置く。
    /// 帯の高さは細い帯の枠と同じなので、中央から離れると帯だけが残る。
    /// 開くと上に名前と下線の見出しを出し、中のデッキを横幅いっぱいの行で縦に積む。「−」は右上の角にかける。
    /// `keepsGrid` は、中の行を運んでいる間。フォルダを閉じても運んでいる行を画面に残し、
    /// 指で押さえている操作が途中で打ち切られないようにする（見えないまま残す）。
    private func folderCard(_ deck: Deck, slotIndex: Int, isOpen: Bool, keepsGrid: Bool, expansion: CGFloat,
                            width: CGFloat, height: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)

        return ZStack(alignment: .bottom) {
            if !isOpen {
                coverStack(children(deck), height: height)
                    .opacity(Double(expansion))
            }
            if isOpen || keepsGrid {
                folderGrid(deck, slotIndex: slotIndex, width: width, height: max(0, height - Metrics.folderHeaderHeight))
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, Metrics.folderHeaderHeight)
                    .opacity(isOpen ? 1 : 0)
            }

            if isOpen {
                VStack(alignment: .leading, spacing: WireMetrics.spacingXS) {
                    Text(deck.deckName)
                        .wireFont(.titleL)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Rectangle()
                        .fill(WireColor.ink)
                        .frame(height: 2)
                        .accessibilityHidden(true)
                }
                // 右上の角にかけたボタンに名前が隠れないよう、右を空ける。
                .padding(.leading, WireMetrics.spacingM)
                .padding(.trailing, 36)
                .frame(height: Metrics.folderHeaderHeight)
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                HStack(spacing: WireMetrics.spacingS) {
                    Text(deck.deckName)
                        .wireFont(expansion > 0.5 ? .titleS : .label, color: WireColor.surface)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    folderToggle(deck, slotIndex: slotIndex, isOpen: false)
                }
                .padding(.horizontal, WireMetrics.spacingM)
                .frame(height: Metrics.bandHeight)
                // 白い文字が表紙の上でも読めるよう、ぼかしに暗い色を重ねる。
                .background(Color.black.opacity(0.35))
                .background(.ultraThinMaterial)
            }
        }
        .frame(width: width, height: height)
        .background(BentoTone.l2.fill)
        .clipShape(shape)
        .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
        .overlay(alignment: .topTrailing) {
            if isOpen {
                folderToggle(deck, slotIndex: slotIndex, isOpen: true)
                    .offset(x: 8, y: -8)
            }
        }
    }

    /// フォルダを開く「＋」と閉じる「−」。白い丸に細い縁を付ける。
    private func folderToggle(_ deck: Deck, slotIndex: Int, isOpen: Bool) -> some View {
        Button {
            toggleFolder(deck, at: slotIndex)
        } label: {
            Image(systemName: isOpen ? "minus" : "plus")
                .font(.body.weight(.bold))
                .foregroundStyle(WireColor.ink)
                .frame(width: 40, height: 40)
                .background(Circle().fill(WireColor.surface))
                .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isOpen ? "フォルダを閉じる" : "フォルダを開く")
    }

    /// 閉じたフォルダの上半分。中のデッキの表紙を、少しずつ傾けて重ねる。
    private func coverStack(_ decks: [Deck], height: CGFloat) -> some View {
        let covers = Array(decks.prefix(4))
        let coverSize = max(0, min(130, height - Metrics.bandHeight - WireMetrics.spacingS))
        return HStack(spacing: -coverSize * 0.3) {
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
        .accessibilityHidden(true)
    }

    /// 開いたフォルダの中。中のデッキを横幅いっぱいの行で縦に積み、入りきらなければこの中だけスクロールする。
    /// 中で運んでいる間は、運ぶ行を除いて並べ、空き箱の分だけ後ろをずらす。
    private func folderGrid(_ folder: Deck, slotIndex: Int, width: CGFloat, height: CGFloat) -> some View {
        let decks = children(folder)
        let padding = WireMetrics.spacingS
        let tileWidth = max(0, width - padding * 2)
        let movingId = drag.flatMap { $0.source == .child(folderSlot: slotIndex) ? $0.deck.id : nil }
        let isMovingInside = drag?.isInFolder == true && movingId != nil
        let contentHeight = gridContentHeight(count: decks.count)
        /// 運んでいるタイルを除いた並びでの位置。空き箱の分だけ後ろをずらす。
        func position(of deck: Deck) -> Int {
            let index = decks.filter { $0.id != movingId }.firstIndex { $0.id == deck.id } ?? 0
            return isMovingInside && index >= (drag?.tileGap ?? 0) ? index + 1 : index
        }

        func origin(of position: Int) -> CGPoint {
            CGPoint(x: 0, y: CGFloat(position) * (Metrics.tileHeight + Metrics.tileSpacing))
        }

        return ScrollView {
            ZStack(alignment: .topLeading) {
                ForEach(decks) { child in
                    // 運んでいるタイルは見えないまま元の場所に残す（指の下には浮かべた写しを出す）。
                    let place = child.id == movingId ? origin(of: drag?.tileGap ?? 0) : origin(of: position(of: child))
                    childTile(child, folderSlot: slotIndex, width: tileWidth)
                        .offset(x: place.x, y: place.y)
                        .opacity(child.id == movingId ? 0 : 1)
                }
                if isMovingInside, let gap = drag?.tileGap {
                    dropPlaceholder(width: tileWidth, height: Metrics.tileHeight)
                        .offset(x: origin(of: gap).x, y: origin(of: gap).y)
                }
            }
            .frame(width: width - padding * 2, height: contentHeight, alignment: .topLeading)
            .padding(padding)
            .background {
                GeometryReader { content in
                    Color.clear.preference(
                        key: FolderGridOffsetKey.self,
                        value: -content.frame(in: .named(Self.gridCoordinateSpace)).minY
                    )
                }
            }
        }
        .coordinateSpace(name: Self.gridCoordinateSpace)
        // 長押しで掴んでいる間は、フォルダの中のスクロールに指を取られないよう止める。
        .scrollDisabled(contentHeight + padding * 2 <= height || pressedDeckId != nil)
        .scrollIndicators(.hidden)
        .onPreferenceChange(FolderGridOffsetKey.self) { gridScrollOffset = $0 }
    }

    /// 開いたフォルダの中の1行。左半分に表紙、右に暗い地で名前を置く。
    /// 押すとそのデッキだけを開き、長押しでメニュー、そのまま動かすと運べる。
    private func childTile(_ deck: Deck, folderSlot: Int, width: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
        return HStack(spacing: 0) {
            DeckCoverImage(url: coverURL(deck), symbol: DeckCoverSymbol.forDeck(id: deck.id))
                .frame(width: width / 2)
            Text(deck.deckName)
                .wireFont(.label, color: WireColor.surface)
                .lineLimit(2)
                .padding(.horizontal, WireMetrics.spacingS)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: width, height: Metrics.tileHeight)
        .background(WireColor.ink)
        .clipShape(shape)
        .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
        .contentShape(Rectangle())
        .scaleEffect(holdScale(deck))
        .onTapGesture { tap { onOpen(deck) } }
        .gesture(pressGesture(deck: deck, source: .child(folderSlot: folderSlot)))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { cardFrames.frames[deck.id] = $0 }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(deck.deckName)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "メニュー") { presentMenu(for: deck) }
    }

    /// 運んでいるカードを置ける場所。点線の空き箱で見せる。
    private func dropPlaceholder(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
            .fill(BentoTone.l3.fill)
            .overlay(
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .strokeBorder(WireColor.ink, style: StrokeStyle(lineWidth: WireMetrics.strokeBase, dash: [6, 5]))
            )
            .frame(width: width, height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// タップで開き、長押しでメニュー、長押しのまま動かすと並べ替え。
    private func cardInteractions(_ deck: Deck, index: Int) -> some ViewModifier {
        CardInteractions(
            deck: deck,
            isFolder: role(deck).isFolder,
            progress: summary(deck),
            onTap: { tap { index == centerIndex ? onOpen(deck) : snap(to: index) } },
            press: pressGesture(deck: deck, source: .slot(index)),
            holdScale: holdScale(deck),
            onFrame: { cardFrames.frames[deck.id] = $0 },
            onMenu: { presentMenu(for: deck) }
        )
    }

    /// 指の場所が分からないとき（支援技術から開くときなど）は、カードの真ん中に出す。
    private func presentMenu(for deck: Deck, at location: CGPoint? = nil) {
        HapticFeedbackService.swipeThresholdCrossed()
        let frame = cardFrames.frames[deck.id] ?? .zero
        onLongPress(deck, frame, location ?? CGPoint(x: frame.midX, y: frame.midY))
    }

    /// このカルーセルの座標を、画面の座標に直す。
    private func global(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + cardFrames.origin.x, y: point.y + cardFrames.origin.y)
    }

    /// 中央でないフォルダの「＋」は、中央へ寄せてから開く。
    private func toggleFolder(_ deck: Deck, at index: Int) {
        if index != centerIndex { snap(to: index) }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) {
            onToggleFolder(deck)
        }
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

    /// 長押しが決まるまでの時間。
    private static let holdDuration = 0.45
    /// 長押しの途中で縮めるカードの大きさ。
    private static let holdScale: CGFloat = 0.96

    private func holdScale(_ deck: Deck) -> CGFloat {
        holdingDeckId == deck.id && !reduceMotion ? Self.holdScale : 1
    }

    /// カードのタップ。長押しが決まった同じ指で離したときは、タップとみなさない。
    /// タップは押していた長さを問わないので、そのままだとメニューを出したあと離したときにもデッキが開いてしまう。
    /// ponytail: 長押しとタップを `exclusively` で組むと、長押しをやめたときにタップまで取れなくなるので、目印で除く。
    private func tap(_ action: () -> Void) {
        guard !cardFrames.isTapSuppressed else { return }
        action()
    }

    /// 長押しと、そのあと指で運ぶ操作。
    private func pressGesture(deck: Deck, source: CardDrag.Source) -> AnyGesture<Void> {
        let press = LongPressGesture(minimumDuration: Self.holdDuration)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace)))
            .updating($isPressing) { _, state, _ in state = true }
            .updating($holdingDeckId) { value, state, transaction in
                // 押し始めから長押しが決まるまでゆっくり縮め、決まったらばねで戻してメニューを出す。
                var holding: Int?
                if case .first(true) = value { holding = deck.id }
                guard state != holding else { return }
                transaction.animation = holding == nil
                    ? .spring(response: 0.25, dampingFraction: 0.7)
                    : .easeOut(duration: Self.holdDuration)
                state = holding
            }
            .onChanged { value in
                guard case .second(true, let dragValue) = value else { return }
                if pressedDeckId != deck.id {
                    pressedDeckId = deck.id
                    pressedCard = (deck, source)
                    cardFrames.isTapSuppressed = true
                    presentMenu(for: deck, at: cardFrames.touchDown)
                }
                guard let dragValue else { return }
                cardFrames.pressLocation = dragValue.location
                if drag == nil {
                    // メニューのボタンの側へ向かう指は、選ぶ操作としてメニューへ渡す。
                    // それ以外の向きへはっきり動かしたら、メニューをやめて運び始める。
                    if onPressMove(global(dragValue.location)) { return }
                    guard hypot(dragValue.translation.width, dragValue.translation.height) > 8 else { return }
                    beginDrag(deck, source: source, at: dragValue.location)
                }
                updateDrag(to: dragValue.location)
            }
            .onEnded { _ in finishDrag() }
        return AnyGesture(press.map { _ in () })
    }

    private func beginDrag(_ deck: Deck, source: CardDrag.Source, at location: CGPoint) {
        onDragStart(deck)
        var started = CardDrag(deck: deck, source: source, location: location, isInFolder: false, gap: 0, tileGap: 0)
        switch source {
        case .slot(let index):
            // 帯に戻すとき、運ぶカードがあった場所を空き箱にしておく。ほかの枠は動かない。
            started.gap = index
            if let open = openFolderSlot, let folder = slots[open].deck { onToggleFolder(folder) }
        case .child(let folderSlot):
            started.isInFolder = true
            started.gap = folderSlot + 1
            if let folder = slots[folderSlot].deck {
                started.tileGap = children(folder).firstIndex { $0.id == deck.id } ?? 0
            }
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) {
            drag = started
        }
    }

    private func updateDrag(to location: CGPoint) {
        guard var current = drag else { return }
        current.location = location
        let previousGap = (current.gap, current.tileGap)
        let previousTarget = current.target

        if current.isInFolder, case .child(let folderSlot) = current.source {
            if let rect = openFolderRect(folderSlot: folderSlot), rect.contains(location),
               let folder = slots[folderSlot].deck {
                current.tileGap = tileIndex(at: location, in: rect, count: children(folder).count - 1)
            } else {
                // フォルダの外へ出たら、フォルダを閉じて一覧の上で運ぶ。
                current.isInFolder = false
                if let folder = slots[folderSlot].deck { onToggleFolder(folder) }
                updateBandTarget(&current)
            }
        } else {
            updateBandTarget(&current)
        }

        if (current.gap, current.tileGap) != previousGap || current.target != previousTarget {
            HapticFeedbackService.detent()
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.86)) {
            drag = current
        }
        let edge = Self.autoScrollEdge
        autoScrollDirection = current.isInFolder ? 0
            : (location.y < edge ? -1 : (location.y > viewportSize.height - edge ? 1 : 0))
    }

    /// 帯に並べた一覧で、指の下の枠に合わせて空き箱を動かす。枠の真ん中なら重ねる先にする。
    /// 空き箱を枠の前後へ差し込むので、指が空き箱の上にある間は落とし先が変わらない。
    private func updateBandTarget(_ drag: inout CardDrag) {
        let remaining = remainingSlots(for: drag)
        guard remaining.count >= 2 else {
            drag.target = nil
            return
        }
        let center = -motion.position / layout.stride
        let position = center + (drag.location.y - viewportSize.height / 2) / Metrics.bandStride
        let index = min(max(0, Int(position.rounded())), remaining.count)
        let fraction = position - CGFloat(index)

        if index != drag.gap {
            let slotIndex = remaining[index < drag.gap ? index : index - 1]
            switch slots[slotIndex] {
            case .empty(.top):
                drag.gap = 1
            case .empty(.bottom):
                drag.gap = remaining.count - 1
            case .deck:
                if abs(fraction) < 0.25, !role(drag.deck).isFolder {
                    drag.target = .row(slotIndex - 1, .onto)
                    return
                }
                let below = index < drag.gap ? index : index - 1
                drag.gap = fraction < 0 ? below : below + 1
            }
            drag.gap = min(max(1, drag.gap), remaining.count - 1)
        }
        drag.target = insertionTarget(gap: drag.gap, remaining: remaining)
    }

    /// 空き箱の位置を、落とし先に直す。空き箱のすぐ後ろの枠の前、と読む。
    private func insertionTarget(gap: Int, remaining: [Int]) -> DeckDropTarget {
        if gap <= 1 { return .start }
        if gap >= remaining.count - 1 { return .end }
        return .row(remaining[gap] - 1, .before)
    }

    /// 開いたフォルダのカードの、画面上（このカルーセルの座標）の場所。
    private func openFolderRect(folderSlot: Int) -> CGRect? {
        guard openFolderSlot == folderSlot else { return nil }
        let center = -motion.position / layout.stride
        let place = placement(of: folderSlot, center: center, size: viewportSize)
        let midY = viewportSize.height / 2 + place.y
        return CGRect(x: 0, y: midY - place.height / 2, width: viewportSize.width, height: place.height)
    }

    /// フォルダの中で、指の下にある行の位置。
    private func tileIndex(at point: CGPoint, in rect: CGRect, count: Int) -> Int {
        let gridTop = rect.minY + Metrics.folderHeaderHeight + WireMetrics.spacingS - gridScrollOffset
        let row = max(0, Int((point.y - gridTop) / (Metrics.tileHeight + Metrics.tileSpacing)))
        return min(row, max(0, count))
    }

    private func finishDrag() {
        let finished = drag
        let wasPressed = pressedDeckId != nil
        cancelPress()
        guard let finished else {
            if wasPressed { onPressEnd() }
            return
        }
        switch finished.source {
        case .slot(let index):
            guard let target = finished.target else { return }
            onDrop(.row(index - 1), target)
        case .child(let folderSlot):
            guard let folder = slots[folderSlot].deck else { return }
            if finished.isInFolder {
                onReorderInFolder(finished.deck.id, folder.id, finished.tileGap)
            } else if let target = finished.target {
                onDrop(.child(deckId: finished.deck.id, folderDeckId: folder.id), target)
            }
        }
    }

    /// メニューで並び替えが決まった。指はまだ押さえているので、その場で持ち上げる。
    private func lift(_ deckId: Int?) {
        guard let deckId, drag == nil, let pressedCard, pressedCard.deck.id == deckId else { return }
        beginDrag(pressedCard.deck, source: pressedCard.source, at: cardFrames.pressLocation)
        updateDrag(to: cardFrames.pressLocation)
    }

    private func cancelPress() {
        pressedDeckId = nil
        pressedCard = nil
        autoScrollDirection = 0
        guard drag != nil else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) {
            drag = nil
        }
        onDragEnd()
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

    /// 指で運んでいるカード。帯の大きさで指の下に浮かべる。指には触れない。
    @ViewBuilder
    private func floatingCard(size: CGSize) -> some View {
        if let drag {
            HStack(spacing: WireMetrics.spacingM) {
                DeckCoverImage(url: coverURL(drag.deck),
                               symbol: role(drag.deck).isFolder ? "folder" : DeckCoverSymbol.forDeck(id: drag.deck.id))
                    .frame(width: 48, height: 48)
                Text(drag.deck.deckName)
                    .wireFont(.label)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(WireMetrics.spacingS)
            .frame(width: size.width * Metrics.bandWidthRatio, height: Metrics.bandHeight)
            .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
            .scaleEffect(1.05)
            .shadow(color: .black.opacity(0.2), radius: 12, y: 6)
            .position(drag.location)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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

private struct FolderGridOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// カードのタップ・長押し・位置の記録・読み上げを、デッキとフォルダで共通にまとめる。
private struct CardInteractions: ViewModifier {
    let deck: Deck
    let isFolder: Bool
    let progress: DeckProgressSummary
    let onTap: () -> Void
    let press: AnyGesture<Void>
    /// 長押しの途中で縮める大きさ。
    let holdScale: CGFloat
    let onFrame: (CGRect) -> Void
    let onMenu: () -> Void

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .scaleEffect(holdScale)
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
    /// カルーセルそのものの画面上の左上。指の場所を画面の座標に直すのに使う。
    var origin: CGPoint = .zero
    /// 最後に指が触れた画面上の場所。
    var touchDown: CGPoint?
    /// いまの指で長押しが決まった。離したときのタップを無視する。
    var isTapSuppressed = false
    /// 長押しのあと指がいる場所（カルーセルの座標）。
    var pressLocation: CGPoint = .zero
}
