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

// MARK: - 移動先を選ぶシート

/// 「フォルダに移動」で開く、ファイルAppの「移動」に倣ったシート。
/// 新しいフォルダを作って入れるか、既存のフォルダを選ぶ。
struct DeckFolderPickerSheet: View {
    let deckName: String
    let folders: [LocalDeckFolder]
    /// いま入っているフォルダ。選べないようにする。
    let currentFolderId: Int?
    let onCreate: (String) -> Void
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isNamingNewFolder = false
    @State private var newFolderName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        newFolderName = ""
                        isNamingNewFolder = true
                    } label: {
                        Label("新規フォルダ", systemImage: "folder.badge.plus")
                    }
                }

                if !folders.isEmpty {
                    Section("フォルダ") {
                        ForEach(folders) { folder in
                            Button {
                                onSelect(folder.id)
                                dismiss()
                            } label: {
                                HStack {
                                    Label(folder.name, systemImage: "folder")
                                    Spacer()
                                    if folder.id == currentFolderId {
                                        Image(systemName: "checkmark")
                                            .accessibilityHidden(true)
                                    }
                                }
                            }
                            .disabled(folder.id == currentFolderId)
                            .accessibilityAddTraits(folder.id == currentFolderId ? .isSelected : [])
                        }
                    }
                }
            }
            .navigationTitle("「\(deckName)」の移動先")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
            .alert("新規フォルダ", isPresented: $isNamingNewFolder) {
                TextField("フォルダ名", text: $newFolderName)
                Button("キャンセル", role: .cancel) { }
                Button("作成") {
                    onCreate(DeckFolderNaming.name(from: newFolderName))
                    dismiss()
                }
            } message: {
                Text("このフォルダに「\(deckName)」を入れます。")
            }
        }
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

// MARK: - 並び替えシート

/// 取っ手で並べ替える編集一覧。一番上の階層と、フォルダの中をそれぞれの区切りで並べ替える。
/// 階層をまたぐ移動はしない（フォルダへの出し入れは長押しメニューで行う）。
struct DeckReorderSheet: View {
    let onSave: (_ layout: [DeckLayoutEntry], _ folderDeckIds: [Int: [Int]]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var items: [DeckTreeItem]
    @State private var folderChildren: [Int: [Deck]]

    init(tree: [DeckTreeItem], onSave: @escaping (_ layout: [DeckLayoutEntry], _ folderDeckIds: [Int: [Int]]) -> Void) {
        self.onSave = onSave
        _items = State(initialValue: tree)
        var children: [Int: [Deck]] = [:]
        for case .folder(let folder, let decks) in tree {
            children[folder.id] = decks
        }
        _folderChildren = State(initialValue: children)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("学習タブ") {
                    ForEach(items) { item in
                        row(for: item)
                    }
                    .onMove { items.move(fromOffsets: $0, toOffset: $1) }
                }

                ForEach(folders) { folder in
                    Section(folder.name) {
                        let decks = folderChildren[folder.id] ?? []
                        if decks.isEmpty {
                            Text("デッキはありません")
                                .foregroundStyle(.secondary)
                        }
                        ForEach(decks) { deck in
                            Label(deck.deckName, systemImage: "rectangle.stack")
                        }
                        .onMove { folderChildren[folder.id]?.move(fromOffsets: $0, toOffset: $1) }
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("並び替え")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
                        onSave(items.map(\.layoutEntry), folderChildren.mapValues { $0.map(\.id) })
                        dismiss()
                    }
                }
            }
        }
    }

    private var folders: [LocalDeckFolder] {
        items.compactMap { item in
            if case .folder(let folder, _) = item { return folder }
            return nil
        }
    }

    @ViewBuilder
    private func row(for item: DeckTreeItem) -> some View {
        switch item {
        case .deck(let deck):
            Label(deck.deckName, systemImage: "rectangle.stack")
        case .folder(let folder, _):
            Label(folder.name, systemImage: "folder")
        }
    }
}
