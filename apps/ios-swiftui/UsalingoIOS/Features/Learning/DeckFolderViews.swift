import SwiftUI

// MARK: - 並びの組み立て

/// 学習タブに並べる1項目。フォルダは中のデッキを持つ（2層まで）。
enum DeckTreeItem: Hashable, Identifiable {
    case deck(Deck)
    case folder(LocalDeckFolder, decks: [Deck])

    var id: String {
        switch self {
        case .deck(let deck): return "deck-\(deck.id)"
        case .folder(let folder, _): return "folder-\(folder.id)"
        }
    }

    var layoutEntry: DeckLayoutEntry {
        switch self {
        case .deck(let deck): return .deck(deck.id)
        case .folder(let folder, _): return .folder(folder.id)
        }
    }
}

/// 保存した並びと、いまあるデッキから、学習タブの並びを作る。見た目と切り離して確かめられる。
enum DeckTree {
    /// 覚えた順に並べる。消えたデッキは詰め、覚えていないデッキは末尾へ足す。
    /// 1つのデッキは1か所にしか出さない。フォルダの中にあるデッキはフォルダ側を優先する。
    /// 中のデッキがなくなったフォルダは並べない（自動で消える）。
    static func build(decks: [Deck], layout: [DeckLayoutEntry], folders: [LocalDeckFolder]) -> [DeckTreeItem] {
        let decksById = Dictionary(decks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var placed = Set<Int>()
        func take(_ id: Int) -> Deck? {
            guard !placed.contains(id), let deck = decksById[id] else { return nil }
            placed.insert(id)
            return deck
        }

        var children: [Int: [Deck]] = [:]
        for folder in folders where children[folder.id] == nil {
            children[folder.id] = folder.deckIds.compactMap(take)
        }
        let foldersById = Dictionary(folders.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        var items: [DeckTreeItem] = []
        var placedFolders = Set<Int>()
        for entry in layout {
            switch entry {
            case .deck(let id):
                if let deck = take(id) { items.append(.deck(deck)) }
            case .folder(let id):
                if let folder = foldersById[id], children[id]?.isEmpty == false, placedFolders.insert(id).inserted {
                    items.append(.folder(folder, decks: children[id] ?? []))
                }
            }
        }
        for folder in folders where children[folder.id]?.isEmpty == false && placedFolders.insert(folder.id).inserted {
            items.append(.folder(folder, decks: children[folder.id] ?? []))
        }
        for deck in decks where !placed.contains(deck.id) {
            placed.insert(deck.id)
            items.append(.deck(deck))
        }
        return items
    }

    /// 組み立てた並びに合わせて、フォルダの中身を消えたデッキの無い形へ整える。並びにない（空になった）フォルダは捨てる。
    static func folders(in tree: [DeckTreeItem], from folders: [LocalDeckFolder]) -> [LocalDeckFolder] {
        var deckIds: [Int: [Int]] = [:]
        for case .folder(let folder, let decks) in tree {
            deckIds[folder.id] = decks.map(\.id)
        }
        var seen = Set<Int>()
        return folders.compactMap { folder in
            guard let ids = deckIds[folder.id], seen.insert(folder.id).inserted else { return nil }
            var folder = folder
            folder.deckIds = ids
            return folder
        }
    }
}

// MARK: - ドラッグで並べ替え・フォルダにまとめる

/// カルーセルに並ぶ1枚。フォルダの中のデッキは、フォルダを開いているときだけ並ぶ。
enum DeckRow: Equatable {
    case deck(Int, folder: Int?)
    case folder(Int)

    var entry: DeckLayoutEntry {
        switch self {
        case .deck(let id, _): return .deck(id)
        case .folder(let id): return .folder(id)
        }
    }

    var isTopLevel: Bool {
        if case .deck(_, let folder) = self { return folder == nil }
        return true
    }

    var parentFolder: Int? {
        if case .deck(_, let folder) = self { return folder }
        return nil
    }
}

/// 指を離した場所。カードの上下の端なら、その前か後ろへ差し込む。真ん中なら重ねる。
enum DeckDropTarget: Equatable {
    enum Zone: Equatable { case before, onto, after }

    case row(Int, Zone)
    /// 先頭の空き枠。
    case start
    /// 末尾の空き枠。
    case end
}

/// 運び始めた場所。一覧の1枚か、開いたフォルダの中のタイルか。
enum DeckDragSource: Equatable {
    /// `decks` の中での位置。
    case row(Int)
    /// フォルダ（学習用のデッキ番号）の中のデッキ。
    case child(deckId: Int, folderDeckId: Int)
}

/// 落としたときに行う並びの変更。
enum DeckDropAction: Equatable {
    /// 一番上の階層の `index` 番目へ動かす（動かすものを除いた並びでの位置）。
    case moveToTop(DeckLayoutEntry, index: Int)
    /// フォルダの `index` 番目（nil なら末尾）へ入れる。
    case moveIntoFolder(deckId: Int, folderId: Int, index: Int?)
    /// 2つのデッキを新しいフォルダにまとめる。フォルダは `withDeckId` の場所にできる。
    case makeFolder(deckId: Int, withDeckId: Int)
}

/// ホーム画面のアイコンのように、デッキを別のデッキへ重ねるとフォルダにまとめ、
/// カードの間へ落とすと並べ替える。見た目と切り離してあるので、単体で確かめられる。
enum DeckDrop {
    static func rows(for tree: [DeckTreeItem], expandedFolderIds: Set<Int>) -> [DeckRow] {
        tree.flatMap { item -> [DeckRow] in
            switch item {
            case .deck(let deck):
                return [.deck(deck.id, folder: nil)]
            case .folder(let folder, let decks):
                let children = expandedFolderIds.contains(folder.id) ? decks.map { DeckRow.deck($0.id, folder: folder.id) } : []
                return [.folder(folder.id)] + children
            }
        }
    }

    /// `dragged` 番目の1枚を `target` へ落としたときの変更。何も変わらないときは nil。
    static func action(rows: [DeckRow], dragged: Int, target: DeckDropTarget) -> DeckDropAction? {
        guard rows.indices.contains(dragged) else { return nil }
        let moving = rows[dragged]
        let topLevel = rows.enumerated().filter { $0.offset != dragged && $0.element.isTopLevel }.map(\.element)

        switch target {
        case .start:
            return .moveToTop(moving.entry, index: 0)
        case .end:
            return .moveToTop(moving.entry, index: topLevel.count)
        case .row(let index, var zone):
            guard rows.indices.contains(index), index != dragged else { return nil }
            let hovered = rows[index]

            if zone == .onto, case .deck(let deckId, _) = moving {
                switch hovered {
                case .folder(let folderId):
                    return .moveIntoFolder(deckId: deckId, folderId: folderId, index: nil)
                case .deck(let targetId, nil):
                    return .makeFolder(deckId: deckId, withDeckId: targetId)
                case .deck(_, let folderId?):
                    return .moveIntoFolder(deckId: deckId, folderId: folderId,
                                           index: childIndex(of: index, in: rows, folder: folderId, dragged: dragged) + 1)
                }
            }
            // フォルダは重ねられない。下半分なら後ろ、上半分なら前へ差し込む扱いにする。
            if zone == .onto { zone = .after }

            if case .deck(let deckId, _) = moving {
                // 開いたフォルダの中のデッキの前後は、そのフォルダの中。
                if let folderId = hovered.parentFolder {
                    let position = childIndex(of: index, in: rows, folder: folderId, dragged: dragged)
                    return .moveIntoFolder(deckId: deckId, folderId: folderId, index: zone == .before ? position : position + 1)
                }
                // 開いたフォルダの見出しのすぐ後ろは、そのフォルダの先頭。
                if case .folder(let folderId) = hovered, zone == .after,
                   rows.enumerated().contains(where: { $0.offset != dragged && $0.element.parentFolder == folderId }) {
                    return .moveIntoFolder(deckId: deckId, folderId: folderId, index: 0)
                }
            }

            // 一番上の階層へ。フォルダの中のデッキに重なったときは、そのフォルダの後ろへ。
            let anchor: DeckRow
            if let folderId = hovered.parentFolder {
                anchor = .folder(folderId)
                zone = .after
            } else {
                anchor = hovered
            }
            guard let position = topLevel.firstIndex(of: anchor) else { return nil }
            return .moveToTop(moving.entry, index: zone == .before ? position : position + 1)
        }
    }

    /// フォルダの中で、`row` 番目のデッキが何番目か。動かしているデッキは数えない。
    private static func childIndex(of row: Int, in rows: [DeckRow], folder: Int, dragged: Int) -> Int {
        rows[..<row].enumerated().filter { $0.offset != dragged && $0.element.parentFolder == folder }.count
    }
}

enum DeckFolderNaming {
    static let defaultName = "新規フォルダ"

    /// 空のまま作ったフォルダにも名前を付ける。
    static func name(from input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? defaultName : trimmed
    }
}

// MARK: - 長押しメニュー

/// 長押しで開くメニューの中身と、押したカードと指の画面上の位置。
struct DeckMenuTarget: Identifiable {
    let deck: Deck
    let cardFrame: CGRect
    /// 長押しした指の場所。ボタンはここを中心に扇形に並ぶ。
    var anchor: CGPoint
    let items: [DeckMenuItem]

    var id: Int { deck.id }

    var layout: DeckRadialMenuLayout {
        DeckRadialMenuLayout(anchor: anchor, cardFrame: cardFrame, count: items.count)
    }
}

/// 長押しメニューのボタンの並び。指の場所を中心に扇形に置く。見た目と切り離してあるので、単体で確かめられる。
///
/// 上に余白があれば上へ、なければ下へ開き、カードの中央の側へ傾けて画面の外へはみ出さないようにする。
/// 指を離さずにボタンの方へ動かすと選び、そのまま待つと決まる（ドウェル選択）。
struct DeckRadialMenuLayout {
    /// 指の場所からボタンの中心までの距離。
    static let radius: CGFloat = 84
    static let buttonSize: CGFloat = 56
    /// 隣どうしのボタンの角度の差。
    static let spread: Double = 50
    /// 指がここより上にあるときは下へ開く。
    static let opensDownBelowY: CGFloat = 220
    /// 指をこれだけ動かすまでは、どのボタンも選ばない。
    static let selectDistance: CGFloat = 36
    /// ボタンの外側にこれだけ余裕を持たせて、選んだままにする。
    static let reach: CGFloat = radius + 44
    /// 指をこれだけ動かすまでは、向きにかかわらずメニューを続ける。指の小さな揺れで運び始めないため。
    static let reorderDistance: CGFloat = 20
    /// 選んだボタンに指を置いたまま、決まるまで待つ時間。
    static let dwellDuration = 0.5
    /// 決まるまでの輪が、ボタンの何倍の大きさから縮み始めるか。
    static let approachStartScale: CGFloat = 1.9
    /// ボタンの並ぶ扇の両側にこれだけ角度の余裕を持たせて、ボタンへ向かう途中とみなす。
    static let approachMargin: Double = 30

    let anchor: CGPoint
    /// ボタンごとの向き。度で、右が 0、下が 90（画面の座標と同じ向き）。
    let angles: [Double]

    init(anchor: CGPoint, cardFrame: CGRect, count: Int) {
        self.anchor = anchor
        let opensUp = anchor.y >= Self.opensDownBelowY
        let towardRight = anchor.x < cardFrame.midX
        let base: Double = (opensUp ? -90 : 90) + (towardRight == opensUp ? 30 : -30)
        angles = (0..<count).map { base + (Double($0) - Double(count - 1) / 2) * Self.spread }
    }

    var centers: [CGPoint] {
        angles.map { point(at: $0, distance: Self.radius) }
    }

    /// 選んだボタンの名前を出す場所。扇の真ん中の外側。
    var labelCenter: CGPoint {
        let middle = angles.isEmpty ? -90 : (angles.first! + angles.last!) / 2
        return point(at: middle, distance: Self.radius + Self.buttonSize / 2 + 28)
    }

    /// 指の下で選ばれているボタン。動かした距離が短すぎるときと、遠すぎるときは選ばない。
    func item(at location: CGPoint) -> Int? {
        let distance = hypot(location.x - anchor.x, location.y - anchor.y)
        guard distance >= Self.selectDistance, distance <= Self.reach else { return nil }
        return sector(of: location)
    }

    /// メニューを続けるか。まだ少ししか動いていないか、ボタンの並ぶ側の広い扇の中にいれば続ける。
    /// 続けないときは、呼ぶ側がデッキを運び始める。
    func keepsMenu(_ location: CGPoint) -> Bool {
        let distance = hypot(location.x - anchor.x, location.y - anchor.y)
        guard distance <= Self.reach else { return false }
        guard distance >= Self.reorderDistance, let first = angles.first, let last = angles.last else { return true }
        let angle = atan2(location.y - anchor.y, location.x - anchor.x) * 180 / .pi
        return abs(remainder(angle - (first + last) / 2, 360)) <= (last - first) / 2 + Self.approachMargin
    }

    /// 指の向きに最も近いボタン。角度の差が隣との中間を超えたら、どれでもない。
    private func sector(of location: CGPoint) -> Int? {
        let angle = atan2(location.y - anchor.y, location.x - anchor.x) * 180 / .pi
        let differences = angles.map { abs(remainder(angle - $0, 360)) }
        guard let nearest = differences.indices.min(by: { differences[$0] < differences[$1] }),
              differences[nearest] <= Self.spread / 2 else { return nil }
        return nearest
    }

    private func point(at angle: Double, distance: CGFloat) -> CGPoint {
        let radians = angle * .pi / 180
        return CGPoint(x: anchor.x + distance * CGFloat(cos(radians)), y: anchor.y + distance * CGFloat(sin(radians)))
    }
}

/// 長押しメニューで指を離したときの結果。
enum DeckMenuRelease: Equatable {
    /// このボタンを選んだ。
    case choose(Int)
    /// どのボタンも選ばずに離した。
    case dismiss
}

/// 長押しメニュー。指の場所に輪を出し、そのまわりに丸いボタンを扇形に並べる（ラジアルメニュー）。
/// 背景は強く暗くぼかし、押したカードの形だけ切り抜いて見せる。
///
/// 指を離さずにボタンへ動かすと、そのボタンが大きくなり、指の場所の輪が中心へ縮む。
/// 選んだボタンのまわりには大きな輪が出てボタンのフチへ縮み、重なったら決まる（音ゲーのアプローチサークル）。
/// 決まる前に離すと、開いたときの逆の動きで閉じる。支援技術から開いたときは、タップで選ぶ。
struct DeckRadialMenuOverlay: View {
    /// 背景を暗くする濃さ。0...1。
    static let dimOpacity: Double = 0.6

    let target: DeckMenuTarget
    /// 指を離さずに選んでいるボタン。
    let highlighted: Int?
    /// 指を離した結果。閉じてから、選んだ操作があれば渡す。
    let release: DeckMenuRelease?
    /// 閉じ終えたときに呼ぶ。メニューで選んだ操作があれば渡す。
    let onFinish: ((() -> Void)?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        let layout = target.layout
        ZStack {
            backdrop
                .contentShape(Rectangle())
                .onTapGesture { close(then: nil) }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel("メニューを閉じる")

            originRing
                .position(layout.anchor)

            ForEach(target.items.indices, id: \.self) { index in
                let item = target.items[index]
                Button {
                    close(then: item.action)
                } label: {
                    Image(systemName: item.systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .accessibilityHidden(true)
                }
                .buttonStyle(RadialButtonStyle(isHighlighted: highlighted == index,
                                               isDestructive: item.role == .destructive))
                .accessibilityLabel(item.title)
                .scaleEffect(isShown || reduceMotion ? 1 : 0.3)
                .position(isShown || reduceMotion ? layout.centers[index] : layout.anchor)
            }

            if let highlighted, target.items.indices.contains(highlighted) {
                ApproachRing()
                    .position(layout.centers[highlighted])
                    .id(highlighted)

                Text(target.items[highlighted].title)
                    .wireFont(.label, color: WireColor.ink)
                    .padding(.horizontal, WireMetrics.spacingM)
                    .padding(.vertical, WireMetrics.spacingS)
                    .background(Capsule().fill(WireColor.surface))
                    .fixedSize()
                    .position(layout.labelCenter)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .ignoresSafeArea()
        .opacity(isShown ? 1 : 0)
        .animation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.75), value: highlighted)
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) { isShown = true }
        }
        .onChange(of: release) { _, release in
            switch release {
            case .choose(let index) where target.items.indices.contains(index):
                close(then: target.items[index].action)
            case .dismiss:
                close(then: nil)
            default:
                break
            }
        }
    }

    /// 長押しした場所の輪。ボタンを選ぶと中心へ縮み、選んでいる先へ目を向けさせる。
    /// 開くときは小さい輪から広がり、閉じるときはまた縮む。
    private var originRing: some View {
        let isSelecting = highlighted != nil
        let scale: CGFloat = reduceMotion ? 1 : (!isShown ? 0.5 : (isSelecting ? 0.4 : 1))
        return ZStack {
            Circle()
                .strokeBorder(WireColor.surface.opacity(0.8), lineWidth: 2)
                .frame(width: 84, height: 84)
            Circle()
                .fill(WireColor.surface.opacity(0.85))
                .frame(width: 56, height: 56)
        }
        .shadow(color: .black.opacity(0.3), radius: 6)
        .scaleEffect(scale)
        .opacity(isSelecting ? 0.5 : 1)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// 画面全体をぼかして暗くし、押したカードの形だけ抜く。
    private var backdrop: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Color.black.opacity(Self.dimOpacity)
        }
        .mask {
            Rectangle()
                .overlay {
                    RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                        .frame(width: target.cardFrame.width, height: target.cardFrame.height)
                        .position(x: target.cardFrame.midX, y: target.cardFrame.midY)
                        .blendMode(.destinationOut)
                }
                .compositingGroup()
        }
        .accessibilityHidden(true)
    }

    /// ボタンを指の場所へ吸い込み、輪を縮めながら薄くして閉じる。開くときの逆の動き。
    private func close(then action: (() -> Void)?) {
        guard isShown else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.25, dampingFraction: 0.9)) {
            isShown = false
        } completion: {
            onFinish(action)
        }
    }
}

/// 選んだボタンのまわりに出て、`dwellDuration` かけてボタンのフチへ縮む輪。フチに重なったときにボタンが決まる。
/// 「動きを減らす」では大きさを変えず、薄い輪をだんだん濃くする。
private struct ApproachRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isClosed = false

    var body: some View {
        // 選んだボタンは 1.18 倍に大きくなるので、そのフチに重なる大きさで止める。
        let size = DeckRadialMenuLayout.buttonSize * 1.18
        Circle()
            .strokeBorder(WireColor.surface, lineWidth: 3)
            .frame(width: size, height: size)
            .shadow(color: .black.opacity(0.35), radius: 4)
            .scaleEffect(isClosed || reduceMotion ? 1 : DeckRadialMenuLayout.approachStartScale)
            .opacity(isClosed ? 1 : 0.25)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: DeckRadialMenuLayout.dwellDuration)) { isClosed = true }
            }
    }
}

/// メニューの丸いボタン。ふだんは白地に黒い絵、選ぶと大きくなり黒地（消す操作は赤地）に白い絵になる。
private struct RadialButtonStyle: ButtonStyle {
    let isHighlighted: Bool
    let isDestructive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let active = isHighlighted || configuration.isPressed
        configuration.label
            .foregroundStyle(active ? WireColor.surface : WireColor.ink)
            .frame(width: DeckRadialMenuLayout.buttonSize, height: DeckRadialMenuLayout.buttonSize)
            .background(Circle().fill(active ? (isDestructive ? Color.red : WireColor.ink) : WireColor.surface))
            .overlay(Circle().strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHair))
            .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
            .scaleEffect(active && !reduceMotion ? 1.18 : 1)
            .contentShape(Circle())
    }
}
