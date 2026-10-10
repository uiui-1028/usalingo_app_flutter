import SwiftUI

/// 学習タブのデッキ一覧の見せ方。上のボタンの間の切り替えで選び、端末に覚えておく。
enum DeckListStyle: String, CaseIterable {
    case carousel
    case icon

    static let storageKey = "learning.deckListStyle"

    var title: String {
        switch self {
        case .carousel: return "カルーセル"
        case .icon: return "アイコン"
        }
    }

    var symbol: String {
        switch self {
        case .carousel: return "rectangle.grid.1x2"
        case .icon: return "square.grid.2x2"
        }
    }
}

/// アイコンビューの並び計算。見た目と切り離してあるので、単体で確かめられる。
/// 横2列に左から右、上から下へ詰めて並べる。
struct DeckIconGridLayout {
    static let columns = 2

    let width: CGFloat
    let spacing: CGFloat
    /// 表紙の下に置く名前の高さ。
    let nameHeight: CGFloat

    var cellWidth: CGFloat { max(0, (width - spacing) / CGFloat(Self.columns)) }
    /// 表紙は正方形。その下に名前を置く。
    var cellHeight: CGFloat { cellWidth + nameHeight + WireMetrics.spacingXS }
    var rowStride: CGFloat { cellHeight + spacing }

    func origin(of position: Int) -> CGPoint {
        CGPoint(x: CGFloat(position % Self.columns) * (cellWidth + spacing),
                y: CGFloat(position / Self.columns) * rowStride)
    }

    func rowCount(cells: Int) -> Int {
        (max(cells, 1) + Self.columns - 1) / Self.columns
    }

    /// 並びの中の点が何番目の枠か、その枠の左端からどれだけ右か（0〜1）。
    func hit(_ point: CGPoint) -> (position: Int, fractionX: CGFloat) {
        let column = point.x < cellWidth + spacing / 2 ? 0 : 1
        let row = max(0, Int((point.y / rowStride).rounded(.down)))
        let left = CGFloat(column) * (cellWidth + spacing)
        let fraction = cellWidth > 0 ? (point.x - left) / cellWidth : 0.5
        return (row * Self.columns + column, min(max(fraction, 0), 1))
    }
}

/// 一番上の階層で運ぶときの、空き箱と落とし先の決め方。カルーセルの帯と同じ決まりを横2列に当てはめる。
/// 枠の左端なら前、右端なら後ろ、真ん中なら重ねる。空き箱の上にいる間は落とし先を変えない。
enum DeckIconGridDrop {
    /// - Parameters:
    ///   - position: 指の下の枠の番号（空き箱を含めた並びで）。
    ///   - remaining: 運ぶものを除いた、一番上の階層の行の番号。
    ///   - gap: 今の空き箱の位置（`remaining` の隙間の番号）。
    ///   - canMerge: 重ねて落とせるか（フォルダは重ねられない）。
    static func update(position: Int, fractionX: CGFloat, remaining: [Int], gap: Int,
                       canMerge: Bool) -> (gap: Int, target: DeckDropTarget?) {
        guard !remaining.isEmpty else { return (0, nil) }
        // 並びの後ろの空いた所は末尾。
        if position > remaining.count { return (remaining.count, .end) }
        let position = max(0, position)
        guard position != gap else { return (gap, insertionTarget(gap: gap, remaining: remaining)) }
        let index = position < gap ? position : position - 1
        if canMerge, fractionX > 0.25, fractionX < 0.75 {
            return (gap, .row(remaining[index], .onto))
        }
        let newGap = fractionX < 0.5 ? index : index + 1
        return (newGap, insertionTarget(gap: newGap, remaining: remaining))
    }

    /// 空き箱の位置を、落とし先に直す。空き箱のすぐ後ろの行の前、と読む。
    static func insertionTarget(gap: Int, remaining: [Int]) -> DeckDropTarget {
        if gap <= 0 { return .start }
        if gap >= remaining.count { return .end }
        return .row(remaining[gap], .before)
    }
}

/// 学習タブのデッキ一覧の、アイコンの見せ方。縦2列に表紙と名前のマスを並べ、上下にスクロールする。
/// カルーセルと違って中央のデッキを大きくしない。タップで選んだ遊び方で開き、フォルダはその場で中を広げる。
/// 長押しのメニュー、運んで並べ替える操作、フォルダへの出し入れはカルーセルと同じ決まりで行う。
struct DeckIconGridView: View {
    let decks: [Deck]
    /// 最後に選んだデッキ。ピンクの枠で示し、最初はここが見えるようにスクロールする。
    let selectedDeckId: Int?
    let coverURL: (Deck) -> URL?
    let onOpen: (Deck) -> Void
    let onSelect: (Deck) -> Void
    let onAdd: () -> Void
    var role: (Deck) -> DeckCardRole = { _ in .deck }
    var children: (Deck) -> [Deck] = { _ in [] }
    var onToggleFolder: (Deck) -> Void = { _ in }
    var isDrawerDragging = false
    let onLongPress: (Deck, CGRect, CGPoint) -> Void
    var onPressMove: (CGPoint) -> Bool = { _ in false }
    var onPressEnd: () -> Void = {}
    var liftDeckId: Int?
    var onDragStart: (Deck) -> Void = { _ in }
    var onDragEnd: () -> Void = {}
    var onDrop: (DeckDragSource, DeckDropTarget) -> Void = { _, _ in }
    var onReorderInFolder: (_ deckId: Int, _ folderDeckId: Int, _ index: Int) -> Void = { _, _, _ in }
    var adding: [PendingDeckAdd] = []
    var downloadState: (Deck) -> DeckDownloadState? = { _ in nil }
    var onRetryAdding: (PendingDeckAdd) -> Void = { _ in }
    var onRetryDownload: (Deck) -> Void = { _ in }
    /// 上に重なるデザインとプロフィールのボタンの下端（画面の座標）。一覧はその下から始める。0 は分からないとき。
    var topControlsBottom: CGFloat = 0

    private static let coordinateSpace = "deckIconGrid"
    /// 端からこの距離まで指を寄せると、1行ずつ送る。
    private static let autoScrollEdge: CGFloat = 72
    private static let holdDuration = 0.35
    private static let holdScale: CGFloat = 0.96

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .subheadline) private var nameHeight: CGFloat = 22
    @State private var frames = GridFrameBox()
    @State private var viewportSize: CGSize = .zero
    /// 一覧の見えている枠の、画面上の上端。
    @State private var viewportTop: CGFloat = 0
    @State private var drag: GridDrag?
    @State private var pressedDeckId: Int?
    @State private var pressedCard: (deck: Deck, source: GridDrag.Source)?
    @State private var isFloating = false
    @State private var floatStart: CGPoint?
    @State private var isSettling = false
    @State private var autoScrollDirection = 0
    @GestureState private var isPressing = false
    @GestureState(resetTransaction: Transaction(animation: .spring(response: 0.25, dampingFraction: 0.7)))
    private var holdingDeckId: Int?

    /// マスに置くもの。
    private enum Cell: Identifiable {
        /// 一番上の階層のデッキかフォルダ。`row` は `decks` の中の番号。
        case deck(Deck, row: Int)
        /// 広げたフォルダの中のデッキ。
        case child(Deck, folderRow: Int)
        case adding(PendingDeckAdd)
        case add

        // 運んでいる間にフォルダの中から外へ出ても同じマスのままにして、押さえている指を途切れさせない。
        var id: String {
            switch self {
            case .deck(let deck, _), .child(let deck, _): return "deck-\(deck.id)"
            case .adding(let pending): return "adding-\(pending.id)"
            case .add: return "add"
            }
        }
    }

    /// マスと、それを置く場所の番号。
    private struct PlacedCell: Identifiable {
        let cell: Cell
        let position: Int

        var id: String { cell.id }
    }

    private struct GridDrag {
        enum Source: Equatable {
            /// 一番上の階層の行。
            case row(Int)
            /// 広げたフォルダ（その行の番号）の中のデッキ。
            case child(folderRow: Int)
        }

        let deck: Deck
        let source: Source
        /// 指の場所（この一覧の見えている枠の座標）。
        var location: CGPoint
        /// フォルダの中のデッキを、まだそのフォルダの中で動かしている。
        var isInFolder: Bool
        /// 一番上の階層で空き箱を置く位置。運ぶものを除いた行の、隙間の番号。
        var gap: Int
        var target: DeckDropTarget?
        /// フォルダの中で空き箱を置く位置。
        var tileGap: Int
    }

    private func layout(width: CGFloat) -> DeckIconGridLayout {
        DeckIconGridLayout(width: width, spacing: WireMetrics.spacingM, nameHeight: nameHeight)
    }

    private var openFolderRow: Int? {
        decks.firstIndex { role($0) == .folder(isExpanded: true) }
    }

    /// 並べるマスと、その場所の番号。運んでいる間は、運ぶマスを空き箱の場所に見えないまま置く。
    private var placedCells: [PlacedCell] {
        guard let drag else {
            var cells: [Cell] = adding.filter(\.atTop).reversed().map(Cell.adding)
            for (row, deck) in decks.enumerated() {
                cells.append(.deck(deck, row: row))
                if role(deck) == .folder(isExpanded: true) {
                    cells += children(deck).map { Cell.child($0, folderRow: row) }
                }
            }
            cells += adding.filter { !$0.atTop }.map(Cell.adding)
            cells.append(.add)
            return cells.enumerated().map { PlacedCell(cell: $0.element, position: $0.offset) }
        }

        // 運んでいる間は、追加の途中のデッキと「＋」を出さない。
        if drag.isInFolder, case .child(let folderRow) = drag.source {
            var result: [PlacedCell] = []
            var position = 0
            for (row, deck) in decks.enumerated() {
                result.append(PlacedCell(cell: .deck(deck, row: row), position: position))
                position += 1
                guard row == folderRow else { continue }
                let others = children(deck).filter { $0.id != drag.deck.id }
                for (index, child) in others.enumerated() {
                    result.append(PlacedCell(cell: .child(child, folderRow: row),
                                             position: position + (index < drag.tileGap ? index : index + 1)))
                }
                result.append(PlacedCell(cell: .child(drag.deck, folderRow: row), position: position + drag.tileGap))
                position += others.count + 1
            }
            return result
        }

        let remaining = remainingRows(for: drag)
        var result = remaining.enumerated().map { index, row in
            PlacedCell(cell: .deck(decks[row], row: row), position: index < drag.gap ? index : index + 1)
        }
        switch drag.source {
        case .row(let row): result.append(PlacedCell(cell: .deck(drag.deck, row: row), position: drag.gap))
        case .child(let folderRow):
            result.append(PlacedCell(cell: .child(drag.deck, folderRow: folderRow), position: drag.gap))
        }
        return result
    }

    private func remainingRows(for drag: GridDrag) -> [Int] {
        if case .row(let dragged) = drag.source { return decks.indices.filter { $0 != dragged } }
        return Array(decks.indices)
    }

    private var placeholderPosition: Int? {
        guard let drag else { return nil }
        if drag.isInFolder, case .child(let folderRow) = drag.source {
            // 広げたフォルダより前のフォルダは閉じているので、行の番号がそのまま場所になる。
            return folderRow + 1 + drag.tileGap
        }
        return drag.gap
    }

    var body: some View {
        GeometryReader { proxy in
            let grid = layout(width: proxy.size.width)
            let cells = placedCells
            let lastPosition = cells.map(\.position).max() ?? 0
            // 運んでいる間は1行足して、末尾へも落とせるようにする。
            let rows = grid.rowCount(cells: lastPosition + 1) + (drag == nil ? 0 : 1)

            ScrollViewReader { scroller in
                ScrollView {
                    ZStack(alignment: .topLeading) {
                        // 自動で送るときの目印。1行に1つ置く。
                        VStack(spacing: grid.spacing) {
                            ForEach(0..<rows, id: \.self) { row in
                                Color.clear.frame(height: grid.cellHeight).id(Self.rowAnchor(row))
                            }
                        }
                        .frame(width: proxy.size.width)
                        .accessibilityHidden(true)

                        if let gap = placeholderPosition {
                            let origin = grid.origin(of: gap)
                            dropPlaceholder(grid)
                                .offset(x: origin.x, y: origin.y)
                        }
                        ForEach(cells) { placed in
                            let origin = grid.origin(of: placed.position)
                            cellView(placed.cell)
                                .frame(width: grid.cellWidth, height: grid.cellHeight)
                                .offset(x: origin.x, y: origin.y)
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.coordinateSpace)) } action: {
                        frames.grid = $0
                    }
                    .padding(.top, topPadding)
                    .padding(.bottom, WireMetrics.spacingXL)
                }
                .scrollIndicators(.hidden)
                // 長押しで掴んでいる間と、引き出しを横になぞっている間は、一覧をスクロールしない。
                .scrollDisabled(pressedDeckId != nil || isDrawerDragging)
                .coordinateSpace(name: Self.coordinateSpace)
                .overlay { floatingCard(grid) }
                .overlay { if isFloating { floatSurface } }
                // 並べ終えてから送る。
                .onAppear { DispatchQueue.main.async { scrollToSelected(scroller) } }
                .task(id: autoScrollDirection) { await autoScroll(scroller, grid: grid, rows: rows) }
            }
            .onGeometryChange(for: CGPoint.self) { $0.frame(in: .global).origin } action: {
                frames.origin = $0
                viewportTop = $0.y
            }
            .onAppear { viewportSize = proxy.size }
            .onChange(of: proxy.size) { _, size in viewportSize = size }
        }
        .onChange(of: isPressing) { _, pressing in
            // システムに指を取り上げられたときは onEnded が来ないので、ここで片付ける。
            if !pressing, !isSettling, !isFloating { cancelPress() }
        }
        .onChange(of: liftDeckId) { _, id in lift(id) }
    }

    /// 上のボタンに1段目が隠れないよう、その下端から始める。分からないときはボタンの高さぶん空ける。
    private var topPadding: CGFloat {
        let covered = topControlsBottom > 0 ? topControlsBottom - viewportTop : 44
        return max(0, covered) + WireMetrics.spacingS
    }

    private static func rowAnchor(_ row: Int) -> String { "deckIconRow-\(row)" }

    /// 最後に選んだデッキが見えるところまでスクロールする。フォルダの中のデッキなら、そのフォルダ。
    private func scrollToSelected(_ scroller: ScrollViewProxy) {
        guard let selectedDeckId,
              let position = placedCells.first(where: { cellDeck($0.cell)?.id == selectedDeckId })?.position
        else { return }
        scroller.scrollTo(Self.rowAnchor(position / DeckIconGridLayout.columns), anchor: .center)
    }

    private func cellDeck(_ cell: Cell) -> Deck? {
        switch cell {
        case .deck(let deck, _), .child(let deck, _): return deck
        case .adding, .add: return nil
        }
    }

    // MARK: - マス

    @ViewBuilder
    private func cellView(_ cell: Cell) -> some View {
        switch cell {
        case .deck(let deck, let row):
            let merging = drag?.target == .row(row, .onto)
            deckTile(deck, isChild: false)
                .modifier(interactions(deck, source: .row(row)))
                .overlay {
                    if merging {
                        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                            .strokeBorder(WireColor.ink, lineWidth: 3)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .scaleEffect(merging ? 1.04 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: merging)
                .animation(nil) { $0.opacity(isDragged(deck) ? 0 : 1) }
        case .child(let deck, let folderRow):
            deckTile(deck, isChild: true)
                .modifier(interactions(deck, source: .child(folderRow: folderRow)))
                .animation(nil) { $0.opacity(isDragged(deck) ? 0 : 1) }
        case .adding(let pending):
            // 学習タブに入るまでは開けず、運べない。
            downloadTile(name: pending.name, coverURL: pending.coverURL, deckId: pending.localDeckId,
                         state: pending.isFailed ? .failed : .downloading(0)) { onRetryAdding(pending) }
        case .add:
            addTile
        }
    }

    private func isDragged(_ deck: Deck) -> Bool { drag?.deck.id == deck.id }

    /// 表紙と名前のマス。フォルダは中の表紙を2×2に並べ、角に開け閉めの印を付ける。
    /// 広げたフォルダの中のデッキは、薄い色の地で囲んでフォルダの中だと分かるようにする。
    @ViewBuilder
    private func deckTile(_ deck: Deck, isChild: Bool) -> some View {
        if let state = downloadState(deck) {
            downloadTile(name: deck.deckName, coverURL: coverURL(deck), deckId: deck.id, state: state) {
                onRetryDownload(deck)
            }
        } else {
            let folderRole = role(deck)
            VStack(spacing: WireMetrics.spacingXS) {
                Group {
                    if case .folder(let isOpen) = folderRole {
                        folderCovers(children(deck))
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: isOpen ? "minus" : "plus")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(WireColor.ink)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(WireColor.surface))
                                    .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
                                    .padding(WireMetrics.spacingXS)
                                    .accessibilityHidden(true)
                            }
                    } else {
                        DeckCoverImage(url: coverURL(deck), symbol: DeckCoverSymbol.forDeck(id: deck.id))
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                Text(deck.deckName)
                    .wireFont(.label)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(maxWidth: .infinity, minHeight: nameHeight, alignment: .leading)
            }
            .padding(WireMetrics.spacingS)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .outlineSurface(radius: WireMetrics.radiusCard, fill: isChild ? BentoTone.l3.fill : BentoTone.l2.fill)
            .overlay {
                if deck.id == selectedDeckId {
                    RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                        .strokeBorder(WireColor.answerCorrect, lineWidth: 3)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// フォルダの中のデッキの表紙を、2×2に小さく並べる。
    private func folderCovers(_ decks: [Deck]) -> some View {
        let covers = Array(decks.prefix(4))
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
        return Group {
            if covers.isEmpty {
                DeckCoverImage(url: nil, symbol: "folder")
            } else {
                Grid(horizontalSpacing: WireMetrics.spacingXS, verticalSpacing: WireMetrics.spacingXS) {
                    ForEach(0..<2, id: \.self) { row in
                        GridRow {
                            ForEach(0..<2, id: \.self) { column in
                                let index = row * 2 + column
                                Group {
                                    if covers.indices.contains(index) {
                                        DeckCoverImage(url: coverURL(covers[index]),
                                                       symbol: DeckCoverSymbol.forDeck(id: covers[index].id))
                                    } else {
                                        Color.clear
                                    }
                                }
                                .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
                .padding(WireMetrics.spacingXS)
                .background(shape.fill(WireColor.surface.opacity(0.6)))
                .overlay(shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase))
            }
        }
        .accessibilityHidden(true)
    }

    /// ダウンロード中のデッキのマス（要件 T1・T2）。表紙を暗くし、％か「読み込めません」と「再試行」を重ねる。
    private func downloadTile(name: String, coverURL: URL?, deckId: Int, state: DeckDownloadState,
                              onRetry: @escaping () -> Void) -> some View {
        let percent: String? = {
            if case .downloading(let value) = state { return "\(Int((value * 100).rounded(.down)))%" }
            return nil
        }()
        return VStack(spacing: WireMetrics.spacingXS) {
            DeckCoverImage(url: coverURL, symbol: DeckCoverSymbol.forDeck(id: deckId))
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: WireMetrics.radiusControl, style: .continuous)
                            .fill(Color.black.opacity(0.5))
                        if let percent {
                            Text(percent)
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(WireColor.surface)
                        } else {
                            VStack(spacing: WireMetrics.spacingXS) {
                                Text("読み込めません").wireFont(.caption, color: WireColor.surface)
                                Button("再試行", action: onRetry)
                                    .buttonStyle(.bordered)
                                    .tint(WireColor.surface)
                            }
                        }
                    }
                }
            Text(name)
                .wireFont(.label)
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: nameHeight, alignment: .leading)
        }
        .padding(WireMetrics.spacingS)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
        // ponytail: VoiceOver は名前と状態を読むだけの最低限。作り込みは後でまとめて行う。
        .accessibilityElement(children: .contain)
        .accessibilityLabel(name)
        .accessibilityValue(percent.map { "ダウンロード中 \($0)" } ?? "読み込めません")
    }

    /// 末尾の「＋」のマス。タップでデッキライブラリを開く。
    private var addTile: some View {
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
            .contentShape(Rectangle())
            .onTapGesture(perform: onAdd)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("デッキを追加")
            .accessibilityHint("デッキライブラリを開きます")
            .accessibilityAddTraits(.isButton)
    }

    private func dropPlaceholder(_ grid: DeckIconGridLayout) -> some View {
        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
            .fill(BentoTone.l3.fill)
            .overlay(
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .strokeBorder(WireColor.ink, style: StrokeStyle(lineWidth: WireMetrics.strokeBase, dash: [6, 5]))
            )
            .frame(width: grid.cellWidth, height: grid.cellHeight)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// 指で運んでいるマス。ピンクの太い枠で光らせて指の下に浮かべる。
    @ViewBuilder
    private func floatingCard(_ grid: DeckIconGridLayout) -> some View {
        if let drag {
            VStack(spacing: WireMetrics.spacingXS) {
                DeckCoverImage(url: coverURL(drag.deck),
                               symbol: role(drag.deck).isFolder ? "folder" : DeckCoverSymbol.forDeck(id: drag.deck.id))
                    .aspectRatio(1, contentMode: .fit)
                Text(drag.deck.deckName)
                    .wireFont(.label)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, minHeight: nameHeight, alignment: .leading)
            }
            .padding(WireMetrics.spacingS)
            .frame(width: grid.cellWidth, height: grid.cellHeight, alignment: .top)
            .outlineSurface(radius: WireMetrics.radiusCard, fill: BentoTone.l2.fill)
            .overlay {
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .strokeBorder(WireColor.answerCorrect, lineWidth: 3)
                    .opacity(isSettling ? 0 : 1)
            }
            .scaleEffect(isSettling ? 1 : 1.05)
            .shadow(color: WireColor.answerCorrect.opacity(isSettling ? 0 : 0.6), radius: 10)
            .shadow(color: .black.opacity(isSettling ? 0 : 0.2), radius: 12, y: 6)
            .position(drag.location)
            .transition(.identity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }

    // MARK: - タップと長押し

    private func interactions(_ deck: Deck, source: GridDrag.Source) -> GridCellInteractions {
        GridCellInteractions(
            deck: deck,
            isFolder: role(deck).isFolder,
            onTap: { tap(deck, source: source) },
            press: pressGesture(deck: deck, source: source),
            holdScale: holdingDeckId == deck.id && !reduceMotion ? Self.holdScale : 1,
            onFrame: { frames.cells[deck.id] = $0 },
            onMenu: { presentMenu(for: deck) }
        )
    }

    /// デッキは選んだ遊び方で開く。フォルダはその場で中を広げる・閉じる。
    /// 長押しが決まった同じ指で離したときは、タップとみなさない。
    /// フォルダの中のデッキは、フォルダを選んだことにする。カルーセルへ戻したとき、そのフォルダを中央に置く。
    private func tap(_ deck: Deck, source: GridDrag.Source) {
        guard !frames.isTapSuppressed, drag == nil else { return }
        if role(deck).isFolder {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.86)) { onToggleFolder(deck) }
            return
        }
        if case .child(let folderRow) = source { onSelect(decks[folderRow]) } else { onSelect(deck) }
        onOpen(deck)
    }

    /// ponytail: 長押しは指の場所を教えてくれないので、メニューはマスの真ん中に出す。指の下に出すには、
    /// カルーセルのように触れた場所を別の指の操作で覚える必要があるが、スクロールの指を奪うおそれがあるので見送った。
    private func presentMenu(for deck: Deck) {
        HapticFeedbackService.swipeThresholdCrossed()
        let frame = frames.cells[deck.id] ?? .zero
        onLongPress(deck, frame, CGPoint(x: frame.midX, y: frame.midY))
    }

    /// 長押しと、そのあと指で運ぶ操作。カルーセルと同じ組み立て。
    private func pressGesture(deck: Deck, source: GridDrag.Source) -> AnyGesture<Void> {
        let press = LongPressGesture(minimumDuration: Self.holdDuration, maximumDistance: 10)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace)))
            .updating($isPressing) { _, state, _ in state = true }
            .updating($holdingDeckId) { value, state, transaction in
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
                    frames.isTapSuppressed = true
                    presentMenu(for: deck)
                }
                guard let dragValue else { return }
                frames.pressLocation = dragValue.location
                if drag == nil {
                    if onPressMove(global(dragValue.location)) { return }
                    guard hypot(dragValue.translation.width, dragValue.translation.height) > 8 else { return }
                    beginDrag(deck, source: source, at: dragValue.location)
                }
                updateDrag(to: dragValue.location)
            }
            .onEnded { _ in finishDrag() }
        return AnyGesture(press.map { _ in () })
    }

    private func global(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x + frames.origin.x, y: point.y + frames.origin.y)
    }

    private func local(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frames.origin.x, y: point.y - frames.origin.y)
    }

    // MARK: - 運ぶ

    private func beginDrag(_ deck: Deck, source: GridDrag.Source, at location: CGPoint) {
        onDragStart(deck)
        var started = GridDrag(deck: deck, source: source, location: location, isInFolder: false, gap: 0, tileGap: 0)
        switch source {
        case .row(let row):
            started.gap = row
            // 一番上の階層のものを運ぶときは、広げたフォルダを閉じる。
            if let open = openFolderRow { onToggleFolder(decks[open]) }
        case .child(let folderRow):
            started.isInFolder = true
            started.gap = folderRow + 1
            started.tileGap = children(decks[folderRow]).firstIndex { $0.id == deck.id } ?? 0
        }
        withAnimation(reduceMotion ? nil : DeckCarouselView.arrangeAnimation) {
            drag = started
        }
    }

    private func updateDrag(to location: CGPoint) {
        guard var current = drag else { return }
        current.location = location
        let previous = (current.gap, current.tileGap, current.target)
        let grid = layout(width: viewportSize.width)
        let point = CGPoint(x: location.x - frames.grid.minX, y: location.y - frames.grid.minY)
        let hit = grid.hit(point)

        if current.isInFolder, case .child(let folderRow) = current.source {
            let count = children(decks[folderRow]).count
            let first = folderRow + 1
            if hit.position >= first, hit.position < first + count {
                current.tileGap = hit.position - first
            } else {
                // フォルダの外へ出たら、フォルダを閉じて一番上の階層で運ぶ。
                current.isInFolder = false
                onToggleFolder(decks[folderRow])
                updateTopLevel(&current, grid: grid, point: point)
            }
        } else {
            updateTopLevel(&current, grid: grid, point: point)
        }

        if (current.gap, current.tileGap) != (previous.0, previous.1) || current.target != previous.2 {
            HapticFeedbackService.detent()
        }
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.86)) {
            drag = current
        }
        let edge = Self.autoScrollEdge
        autoScrollDirection = location.y < edge ? -1 : (location.y > viewportSize.height - edge ? 1 : 0)
    }

    private func updateTopLevel(_ drag: inout GridDrag, grid: DeckIconGridLayout, point: CGPoint) {
        let hit = grid.hit(point)
        let result = DeckIconGridDrop.update(position: hit.position, fractionX: hit.fractionX,
                                             remaining: remainingRows(for: drag), gap: drag.gap,
                                             canMerge: !role(drag.deck).isFolder)
        drag.gap = result.gap
        drag.target = result.target
    }

    /// 指を離した。浮かせたマスを置き場所へ吸い込ませてから、並びを変える。
    private func finishDrag() {
        guard let finished = drag else {
            let wasPressed = pressedDeckId != nil
            cancelPress()
            if wasPressed { onPressEnd() }
            return
        }
        releaseFinger()
        isSettling = true
        withAnimation(reduceMotion ? nil : DeckCarouselView.arrangeAnimation) {
            drag?.location = settlePoint(for: finished)
        } completion: {
            isSettling = false
            drop(finished)
            endDrag()
        }
    }

    /// 吸い込ませる先。重ねるならそのマス、ほかは空き箱。
    private func settlePoint(for drag: GridDrag) -> CGPoint {
        let grid = layout(width: viewportSize.width)
        var position = placeholderPosition ?? 0
        if case .row(let row, .onto) = drag.target,
           let onto = placedCells.first(where: { $0.id == Cell.deck(decks[row], row: row).id }) {
            position = onto.position
        }
        let origin = grid.origin(of: position)
        return CGPoint(x: frames.grid.minX + origin.x + grid.cellWidth / 2,
                       y: frames.grid.minY + origin.y + grid.cellHeight / 2)
    }

    private func drop(_ finished: GridDrag) {
        switch finished.source {
        case .row(let row):
            guard let target = finished.target else { return }
            onDrop(.row(row), target)
        case .child(let folderRow):
            let folder = decks[folderRow]
            if finished.isInFolder {
                onReorderInFolder(finished.deck.id, folder.id, finished.tileGap)
            } else if let target = finished.target {
                onDrop(.child(deckId: finished.deck.id, folderDeckId: folder.id), target)
            }
        }
    }

    /// メニューで並び替えが決まった。指をまだ押さえていればその場で持ち上げ、離したあとなら浮かせて次の指を待つ。
    private func lift(_ deckId: Int?) {
        guard let deckId, drag == nil else { return }
        if let pressedCard {
            guard pressedCard.deck.id == deckId else { return }
            beginDrag(pressedCard.deck, source: pressedCard.source, at: frames.pressLocation)
            updateDrag(to: frames.pressLocation)
            return
        }
        guard let frame = frames.cells[deckId],
              let cell = placedCells.first(where: { cellDeck($0.cell)?.id == deckId })?.cell else { return }
        let location = local(CGPoint(x: frame.midX, y: frame.midY))
        switch cell {
        case .deck(let deck, let row): beginDrag(deck, source: .row(row), at: location)
        case .child(let deck, let folderRow): beginDrag(deck, source: .child(folderRow: folderRow), at: location)
        case .adding, .add: return
        }
        isFloating = true
    }

    /// 浮かせたマスを運ぶ面。どこを触っても指の動いた分だけ動かし、離すとそこへ置く。動かさずに離したらやめる。
    private var floatSurface: some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.coordinateSpace))
                    .onChanged { value in
                        guard let start = floatStart ?? drag?.location else { return }
                        floatStart = start
                        updateDrag(to: CGPoint(x: start.x + value.translation.width,
                                               y: start.y + value.translation.height))
                    }
                    .onEnded { value in
                        floatStart = nil
                        if hypot(value.translation.width, value.translation.height) > 8 {
                            finishDrag()
                        } else {
                            cancelPress()
                        }
                    }
            )
            // ponytail: 支援技術では運べない。タップでやめられるだけ。代わりの操作は後でまとめて作る。
            .accessibilityLabel("並び替えをやめる")
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { cancelPress() }
    }

    private func cancelPress() {
        releaseFinger()
        endDrag()
    }

    private func releaseFinger() {
        pressedDeckId = nil
        pressedCard = nil
        isFloating = false
        floatStart = nil
        autoScrollDirection = 0
        // 指を離したときのタップを除き終えてから、次の指のために目印を外す。
        let frames = frames
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { frames.isTapSuppressed = false }
    }

    private func endDrag() {
        guard drag != nil else { return }
        withAnimation(reduceMotion ? nil : DeckCarouselView.arrangeAnimation) {
            drag = nil
        }
        onDragEnd()
    }

    /// 端へ寄せている間、1行ずつ送る。送ったら、指の下の落とし先を選び直す。
    private func autoScroll(_ scroller: ScrollViewProxy, grid: DeckIconGridLayout, rows: Int) async {
        guard autoScrollDirection != 0 else { return }
        while !Task.isCancelled, drag != nil {
            let top = Int((max(0, -frames.grid.minY) / grid.rowStride).rounded(.down))
            let bottom = Int(((viewportSize.height - frames.grid.minY) / grid.rowStride).rounded(.down))
            let row = autoScrollDirection < 0 ? top - 1 : bottom + 1
            guard row >= 0, row < rows else { return }
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
                scroller.scrollTo(Self.rowAnchor(row), anchor: autoScrollDirection < 0 ? .top : .bottom)
            }
            try? await Task.sleep(for: .seconds(0.45))
            if let location = drag?.location { updateDrag(to: location) }
        }
    }
}

/// マスのタップ・長押し・位置の記録・読み上げを、デッキとフォルダで共通にまとめる。
private struct GridCellInteractions: ViewModifier {
    let deck: Deck
    let isFolder: Bool
    let onTap: () -> Void
    let press: AnyGesture<Void>
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
            // ponytail: VoiceOver は名前と、メニューを開く名前付きの操作だけの最低限。作り込みは後でまとめて行う。
            .accessibilityElement(children: .combine)
            .accessibilityLabel(isFolder ? "フォルダ \(deck.deckName)" : deck.deckName)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction(named: "メニュー", onMenu)
    }
}

/// マスの位置を覚えておく入れ物。スクロールの間は毎フレーム変わるので、描き直しの引き金にしない。
private final class GridFrameBox {
    var cells: [Int: CGRect] = [:]
    /// 一覧の見えている枠の、画面上の左上。
    var origin: CGPoint = .zero
    /// 並びの場所（見えている枠の座標）。スクロールすると上下に動く。
    var grid: CGRect = .zero
    var isTapSuppressed = false
    /// 長押しのあと指がいる場所（見えている枠の座標）。
    var pressLocation: CGPoint = .zero
}
