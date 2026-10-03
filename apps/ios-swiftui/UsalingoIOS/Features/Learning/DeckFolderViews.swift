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
                if let folder = foldersById[id], placedFolders.insert(id).inserted {
                    items.append(.folder(folder, decks: children[id] ?? []))
                }
            }
        }
        for folder in folders where placedFolders.insert(folder.id).inserted {
            items.append(.folder(folder, decks: children[folder.id] ?? []))
        }
        for deck in decks where !placed.contains(deck.id) {
            placed.insert(deck.id)
            items.append(.deck(deck))
        }
        return items
    }

    /// 組み立てた並びに合わせて、フォルダの中身を消えたデッキの無い形へ整える。
    static func folders(in tree: [DeckTreeItem], keepingEmptyFrom folders: [LocalDeckFolder]) -> [LocalDeckFolder] {
        var deckIds: [Int: [Int]] = [:]
        for case .folder(let folder, let decks) in tree {
            deckIds[folder.id] = decks.map(\.id)
        }
        var seen = Set<Int>()
        return folders.compactMap { folder in
            guard seen.insert(folder.id).inserted else { return nil }
            var folder = folder
            folder.deckIds = deckIds[folder.id] ?? []
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

/// 長押しで開くメニューの中身と、押したカードの画面上の位置。
struct DeckMenuTarget: Identifiable {
    let deck: Deck
    let cardFrame: CGRect
    let items: [DeckMenuItem]

    var id: Int { deck.id }
}

/// 長押しメニュー。iOS 標準の長押しメニューより背景を強く暗くぼかすため、自前で重ねる。
/// 押したカードの形だけ切り抜いて見せ、その上か下にメニューを置く。外をタップすると閉じる。
struct DeckActionMenuOverlay: View {
    /// 背景を暗くする濃さ。0...1。
    static let dimOpacity: Double = 0.6

    let target: DeckMenuTarget
    /// 閉じ終えたときに呼ぶ。メニューで選んだ操作があれば渡す。
    let onFinish: ((() -> Void)?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isShown = false

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                backdrop
                    .contentShape(Rectangle())
                    .onTapGesture { close(then: nil) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel("メニューを閉じる")

                menu(in: proxy.size)
            }
        }
        .ignoresSafeArea()
        .opacity(isShown ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { isShown = true }
        }
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

    /// カードが画面の上半分にあれば下へ、下半分にあれば上へ出す。入りきらないときはスクロールさせる。
    private func menu(in size: CGSize) -> some View {
        let card = target.cardFrame
        let opensBelow = card.midY < size.height / 2
        let gap = WireMetrics.spacingS
        let margin = WireMetrics.spacingXL
        let available = max(0, opensBelow ? size.height - card.maxY - gap - margin : card.minY - gap - margin)
        let width = min(260, size.width - WireMetrics.screenPadding * 2)
        let x = min(max(card.minX, WireMetrics.screenPadding), size.width - WireMetrics.screenPadding - width)

        return ViewThatFits(in: .vertical) {
            menuList
            ScrollView { menuList }
        }
        .frame(width: width)
        .frame(maxHeight: available, alignment: opensBelow ? .top : .bottom)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.25), radius: 20, y: 8)
        .scaleEffect(isShown || reduceMotion ? 1 : 0.9, anchor: opensBelow ? .top : .bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: opensBelow ? .topLeading : .bottomLeading)
        .padding(.leading, x)
        .padding(opensBelow ? .top : .bottom, opensBelow ? card.maxY + gap : size.height - card.minY + gap)
    }

    private var menuList: some View {
        VStack(spacing: 0) {
            ForEach(Array(target.items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { Divider() }
                Button {
                    close(then: item.action)
                } label: {
                    HStack(spacing: WireMetrics.spacingM) {
                        Text(item.title)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: item.systemImage)
                            .accessibilityHidden(true)
                    }
                    .foregroundStyle(item.role == .destructive ? Color.red : Color.primary)
                    .padding(.horizontal, WireMetrics.spacingM)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func close(then action: (() -> Void)?) {
        guard isShown else { return }
        withAnimation(reduceMotion ? nil : .easeIn(duration: 0.15)) {
            isShown = false
        } completion: {
            onFinish(action)
        }
    }
}
