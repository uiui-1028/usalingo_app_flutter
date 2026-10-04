import SwiftUI
import UniformTypeIdentifiers

/// デッキを開くときの遊び方。タブバー上の切り替えバーで選び、端末に覚えておく。
enum DeckPlayStyle: String, CaseIterable, Identifiable {
    // バーには宣言順に左から並ぶ。
    case card
    case choice
    case match
    case list
    case audio

    static let storageKey = "learning.deckPlayStyle"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .card: return "カード"
        case .choice: return "5択"
        case .list: return "リスト"
        case .audio: return "音声"
        case .match: return "ペア"
        }
    }

    /// バーに並べるアイコン。5つを1行に収めるため、名前は選んだものだけ出す。
    var symbol: String {
        switch self {
        case .card: return "rectangle.on.rectangle"
        case .choice: return "checklist"
        case .list: return "list.bullet"
        case .audio: return "waveform"
        case .match: return "square.grid.3x2"
        }
    }
}

/// 学習タブ。表紙・名前・進み具合をまとめたカードを上下に回して選び、中央のカードを
/// タップすると、選んだ遊び方でそのデッキを開く。両端の空き枠からデッキを1つずつ足す。
struct LearningDashboardView: View {
    @EnvironmentObject private var appState: AppState

    /// 学習タブの並び。フォルダは中のデッキを持つ。
    @State private var tree: [DeckTreeItem] = []
    /// 「＋」で開いているフォルダ。一度に1つだけ開く。
    @State private var openFolderId: Int?
    /// 長押しでデッキを運んでいる最中。タブバーと遊び方のバーを隠して、並べ替えに集中させる。
    @State private var isArranging = false
    @State private var renamingDeck: Deck?
    @State private var renameText = ""
    @State private var folderPendingDeletion: LocalDeckFolder?
    @State private var deckPendingDeletion: Deck?
    @State private var menuTarget: DeckMenuTarget?
    /// 長押しのまま指を動かして選んでいるメニューのボタン。
    @State private var menuHighlight: Int?
    /// 一度ボタンを選んだら、指を離すまでメニューを続け、運ぶ操作へ切り替えない。
    @State private var isMenuLocked = false
    /// 長押しメニューで指を離した結果。
    @State private var menuRelease: DeckMenuRelease?
    /// メニューで選んだ操作。シートや確認を重ねないよう、メニューが閉じ切ってから行う。
    @State private var pendingMenuAction: (() -> Void)?
    /// デッキごとの進み具合。カードを読み終えるまでは空のまま出す。
    @State private var summaries: [Int: DeckProgressSummary] = [:]
    /// デッキごとの表紙画像。選んだ1枚は `DeckCoverStore` が端末へ覚えている。
    @State private var covers: [Int: URL] = [:]
    @State private var studyLaunch: StudyLaunch?
    @State private var isShowingLibrary = false
    /// 空き枠から開いたライブラリで追加したデッキを、どちらの端へ入れるか。
    @State private var addEdge: DeckSlotEdge = .bottom
    @State private var wordListDeck: Deck?
    @State private var radioDeck: Deck?
    @State private var matchingDeck: Deck?
    @State private var choiceDeck: Deck?
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            content
                .navigationDestination(item: $studyLaunch) { launch in
                    StudySessionView(deck: launch.deck, studyMode: launch.mode)
                }
                .navigationDestination(isPresented: $isShowingLibrary) {
                    DeckLibraryView(onAdded: placeAddedDeck)
                }
                .navigationDestination(item: $wordListDeck) { deck in
                    WordListView(deck: deck)
                }
                .navigationDestination(item: $radioDeck) { deck in
                    AudioRadioView(deck: deck)
                }
                .navigationDestination(item: $matchingDeck) { deck in
                    MatchingGameView(deck: deck)
                }
                .navigationDestination(item: $choiceDeck) { deck in
                    FiveChoiceView(deck: deck)
                }
        }
        .task(id: reloadKey) { await reload() }
        .onChange(of: appState.session?.user.id) { _, _ in
            // 利用者が変わったら、前の人の教材を開いている画面を閉じる。
            studyLaunch = nil
            isShowingLibrary = false
            wordListDeck = nil
            radioDeck = nil
            matchingDeck = nil
            choiceDeck = nil
            tree = []
            openFolderId = nil
            covers = [:]
        }
        // タブバーの出し入れは push / pop が始まった時点で決める。子画面の
        // onAppear / onDisappear は遷移が終わってから呼ばれるため、そこで戻すと
        // 学習タブが出そろった後にバーが浮き上がってきてしまう。
        .onChange(of: isCoveringScreenPresented) { _, isPresented in
            // 隠すときだけ下へ滑らせる。戻すときは即座に出し、pop に合わせて
            // 浮き上がったり薄く現れたりしないようにする。
            withAnimation(isPresented ? .spring(response: 0.28, dampingFraction: 0.86) : nil) {
                appState.isShellChromeHidden = isPresented || isArranging
            }
        }
        .onChange(of: isArranging) { _, arranging in
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                appState.isShellChromeHidden = arranging || isCoveringScreenPresented
            }
        }
    }

    /// タブバーの上に重なる全画面の子画面が出ているか。
    private var isCoveringScreenPresented: Bool {
        studyLaunch != nil
            || isShowingLibrary
            || wordListDeck != nil
            || radioDeck != nil
            || matchingDeck != nil
    }

    /// デッキのカードを上下に回すカルーセル。お知らせがあるときだけ下に足す。
    /// カルーセルは画面全体を使い、常に画面の真ん中を中心にする。タブバーや遊び方のバーはその上に重なる層なので、
    /// 出し入れしてもカルーセルの大きさと位置は変えない（並べ替えでバーを隠したときに跳ねないように）。
    private var content: some View {
        carousel
            .padding(.horizontal, WireMetrics.screenPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(edges: .vertical)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                notice
                    .padding(.horizontal, WireMetrics.screenPadding)
                    .padding(.bottom, WireMetrics.spacingM)
            }
    }

    private var carousel: some View {
        DeckCarouselView(
            decks: decks,
            centeredDeckId: deckOrder.selectedDeckId,
            coverURL: { covers[$0.id] },
            summary: summary(for:),
            onOpen: open,
            onSelect: select,
            onAdd: { edge in
                addEdge = edge
                isShowingLibrary = true
            },
            role: role(of:),
            children: { deck in folder(of: deck).map(childDecks(of:)) ?? [] },
            onToggleFolder: toggleFolder,
            onLongPress: presentMenu(for:cardFrame:anchor:),
            onPressMove: trackMenu(at:),
            onPressEnd: { menuRelease = menuHighlight.map { .choose($0) } ?? .dismiss },
            onDragStart: { _ in
                // 長押しのまま動かし始めたら、メニューを閉じて並べ替えに移る。
                pendingMenuAction = nil
                withoutAnimation { menuTarget = nil }
                isArranging = true
            },
            onDragEnd: { isArranging = false },
            onDrop: drop(from:target:),
            onReorderInFolder: reorderInFolder(deckId:folderDeckId:index:)
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // 長押しメニューはタブバーまで覆うよう全画面に重ねる。下から出てくる動きは消し、中で薄く出す。
        .fullScreenCover(item: $menuTarget, onDismiss: runPendingMenuAction) { target in
            DeckRadialMenuOverlay(target: target, highlighted: menuHighlight, release: menuRelease) { action in
                pendingMenuAction = action
                menuHighlight = nil
                menuRelease = nil
                withoutAnimation { menuTarget = nil }
            }
            .presentationBackground(.clear)
        }
        .alert("名前を変更", isPresented: Binding(
            get: { renamingDeck != nil },
            set: { if !$0 { renamingDeck = nil } }
        )) {
            TextField("名前", text: $renameText)
            Button("キャンセル", role: .cancel) { renamingDeck = nil }
            Button("保存") { commitRename() }
        } message: {
            Text(renameMessage)
        }
        .confirmationDialog(
            "フォルダを削除しますか？",
            isPresented: Binding(
                get: { folderPendingDeletion != nil },
                set: { if !$0 { folderPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: folderPendingDeletion
        ) { folder in
            Button("フォルダを削除", role: .destructive) {
                if openFolderId == folder.id { openFolderId = nil }
                changeLayout { try $0.deleteFolder(folder.id) }
            }
        } message: { _ in
            Text("中のデッキは消えずに、フォルダの外へ出ます。")
        }
        .confirmationDialog(
            "デッキを削除しますか？",
            isPresented: Binding(
                get: { deckPendingDeletion != nil },
                set: { if !$0 { deckPendingDeletion = nil } }
            ),
            titleVisibility: .visible,
            presenting: deckPendingDeletion
        ) { deck in
            Button("削除", role: .destructive) { delete(deck) }
        } message: { deck in
            Text(appState.studyDataSource.canManage(deck)
                ? "このデッキのカードは端末から消えます。"
                : "この端末の学習タブから外します。学習の記録は残り、ギャラリーから追加し直せます。")
        }
    }

    // MARK: - フォルダ

    /// カルーセルに並べる順。フォルダの中のデッキは、フォルダのカードの中に並べる。
    private var decks: [Deck] {
        tree.map { item in
            switch item {
            case .deck(let deck): return deck
            case .folder(let folder, _): return appState.localStudy.folderDeck(folder)
            }
        }
    }

    /// フォルダを学習画面へ渡すときのデッキ番号から、そのフォルダを引く。
    private func folder(of deck: Deck) -> LocalDeckFolder? {
        folder(deckId: deck.id)
    }

    private func folder(deckId: Int) -> LocalDeckFolder? {
        for case .folder(let folder, _) in tree where LocalStudyDataSource.folderDeckId(folderId: folder.id) == deckId {
            return folder
        }
        return nil
    }

    private func childDecks(of folder: LocalDeckFolder) -> [Deck] {
        for case .folder(let candidate, let children) in tree where candidate.id == folder.id {
            return children
        }
        return []
    }

    /// 長押しで運んだカードを落とした。並べ替えか、フォルダへの出し入れか、新しいフォルダにまとめる。
    /// フォルダの中から運んだデッキは、並びの最後に「そのフォルダの中のデッキ」として足して同じ決まりで扱う。
    private func drop(from origin: DeckDragSource, target: DeckDropTarget) {
        var rows = DeckDrop.rows(for: tree, expandedFolderIds: [])
        let dragged: Int
        switch origin {
        case .row(let index):
            dragged = index
        case .child(let deckId, let folderDeckId):
            guard let folder = folder(deckId: folderDeckId) else { return }
            rows.append(.deck(deckId, folder: folder.id))
            dragged = rows.count - 1
        }
        guard let action = DeckDrop.action(rows: rows, dragged: dragged, target: target) else { return }
        HapticFeedbackService.success()
        withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
            changeLayout { source in
                switch action {
                case .moveToTop(let entry, let index):
                    try source.moveEntry(entry, toTopLevelIndex: index)
                    // 落としたカードを中央に置く。
                    switch entry {
                    case .deck(let id): deckOrder.selectedDeckId = id
                    case .folder(let id): deckOrder.selectedDeckId = LocalStudyDataSource.folderDeckId(folderId: id)
                    }
                case .moveIntoFolder(let deckId, let folderId, let index):
                    try source.moveDeck(deckId, toFolder: folderId, at: index)
                    deckOrder.selectedDeckId = LocalStudyDataSource.folderDeckId(folderId: folderId)
                case .makeFolder(let deckId, let targetId):
                    let folder = try source.createFolder(named: DeckFolderNaming.defaultName, containing: targetId)
                    try source.moveDeck(deckId, toFolder: folder.id)
                    deckOrder.selectedDeckId = LocalStudyDataSource.folderDeckId(folderId: folder.id)
                }
            }
        }
    }

    /// 開いたフォルダの中で並べ替えた。
    private func reorderInFolder(deckId: Int, folderDeckId: Int, index: Int) {
        guard let folder = folder(deckId: folderDeckId) else { return }
        changeLayout { try $0.moveDeck(deckId, toFolder: folder.id, at: index) }
    }

    /// 中央に止まったカードを覚える。開いたフォルダから離れたら、そのフォルダを閉じる。
    private func select(_ deck: Deck) {
        deckOrder.selectedDeckId = deck.id
        if let open = openFolderId, LocalStudyDataSource.folderDeckId(folderId: open) != deck.id {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) { openFolderId = nil }
        }
    }

    private func role(of deck: Deck) -> DeckCardRole {
        if let folder = folder(of: deck) {
            return .folder(isExpanded: openFolderId == folder.id)
        }
        return .deck
    }

    private func toggleFolder(_ deck: Deck) {
        guard let folder = folder(of: deck) else { return }
        openFolderId = openFolderId == folder.id ? nil : folder.id
    }

    /// 同じデッキでもう一度呼ばれたときは、指の場所だけ置き直す。
    private func presentMenu(for deck: Deck, cardFrame: CGRect, anchor: CGPoint) {
        if menuTarget?.id == deck.id {
            withoutAnimation { menuTarget?.anchor = anchor }
            return
        }
        menuHighlight = nil
        menuRelease = nil
        isMenuLocked = false
        let target = DeckMenuTarget(deck: deck, cardFrame: cardFrame, anchor: anchor, items: menuItems(for: deck))
        withoutAnimation { menuTarget = target }
    }

    /// 長押しのまま動かした指の下のボタンを選ぶ。メニューを続けないなら false を返し、運ぶ操作に譲る。
    /// 並べ替えのボタンに乗ったら、その場でデッキを持ち上げる。
    private func trackMenu(at location: CGPoint) -> Bool {
        guard let target = menuTarget else { return false }
        let layout = target.layout
        let item = layout.item(at: location)
        if let item, target.items[item].startsDrag { return false }
        if item != menuHighlight {
            menuHighlight = item
            if item != nil { HapticFeedbackService.detent() }
        }
        if item != nil { isMenuLocked = true }
        return isMenuLocked || layout.keepsMenu(location)
    }

    private func runPendingMenuAction() {
        let action = pendingMenuAction
        pendingMenuAction = nil
        action?()
    }

    private func withoutAnimation(_ change: () -> Void) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction, change)
    }

    /// 長押しメニュー。名前の変更、並べ替え、削除。消す操作は最後に置き、選ぶと赤くなる。
    /// 並べ替えのボタンへ指を動かすと、そのままデッキを運べる。ボタンを使わずに長押しのまま動かしても運べる。
    private func menuItems(for deck: Deck) -> [DeckMenuItem] {
        let folder = folder(of: deck)
        return [
            DeckMenuItem(title: "名前を変更", systemImage: "pencil") { beginRename(deck) },
            // ponytail: 支援技術からタップしたときは何もせず閉じるだけ。並べ替えの代わりの操作は後でまとめて作る。
            DeckMenuItem(title: "並び替え", systemImage: "arrow.up.arrow.down", startsDrag: true) {},
            DeckMenuItem(title: "削除", systemImage: "trash", role: .destructive) {
                if let folder { folderPendingDeletion = folder } else { deckPendingDeletion = deck }
            }
        ]
    }

    private func beginRename(_ deck: Deck) {
        renameText = deck.deckName
        renamingDeck = deck
    }

    private var renameMessage: String {
        guard let deck = renamingDeck else { return "" }
        if folder(of: deck) != nil || appState.studyDataSource.canManage(deck) { return "" }
        return "配信中のデッキは、この端末での表示名だけが変わります。空にすると元の名前に戻ります。"
    }

    private func commitRename() {
        guard let deck = renamingDeck else { return }
        renamingDeck = nil
        if let folder = folder(of: deck) {
            let name = DeckFolderNaming.name(from: renameText)
            changeLayout { try $0.renameFolder(folder.id, to: name) }
        } else {
            let name = renameText
            changeLayout { try $0.renameDeck(deck, to: name) }
        }
    }

    /// 並びやフォルダを変えて保存し、読み直す。バックアップにも載せる。
    private func changeLayout(_ change: (LocalStudyDataSource) throws -> Void) {
        do {
            try change(appState.localStudy)
            errorMessage = nil
            appState.markStudyDataChanged()
        } catch {
            errorMessage = "変更を保存できませんでした。\(UserFacingError.advice(for: error))"
        }
    }

    /// 読み込みや削除に失敗したときだけ出すお知らせ。
    @ViewBuilder
    private var notice: some View {
        if let errorMessage {
            // 色相を使わずに異常を示す（破線 + 文言）。
            Text(errorMessage)
                .wireFont(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(WireMetrics.spacingM)
                .outlineSurface(
                    radius: WireMetrics.radiusControl,
                    shadow: nil,
                    dashed: true,
                    fill: BentoTone.l3.fill
                )
        }
    }

    /// デッキ全体を学習開始の入口にする。
    private func open(_ deck: Deck) {
        switch playStyle {
        case .card:
            studyLaunch = StudyLaunch(deck: deck, mode: .all)
        case .choice:
            choiceDeck = deck
        case .list:
            wordListDeck = deck
        case .audio:
            radioDeck = deck
        case .match:
            matchingDeck = deck
        }
    }

    /// ライブラリで追加した公式デッキを、選んだ空き枠の端へ入れて中央に置き、学習タブへ戻る。
    private func placeAddedDeck(remoteDeckId: Int) {
        let deckId = LocalStudyDataSource.cachedDeckId(remoteDeckId: remoteDeckId)
        do {
            try appState.localStudy.placeDeck(id: deckId, atTop: addEdge == .top)
        } catch {
            errorMessage = "デッキの並びを保存できませんでした。\(UserFacingError.advice(for: error))"
        }
        deckOrder.selectedDeckId = deckId
        isShowingLibrary = false
        // 読み直しは追加の時点で上がる `studyDataVersion` にまかせる。ここでも呼ぶと、
        // 全デッキのカードを2回読むことになる。
    }

    /// 並び順と最後に選んだデッキ。利用者ごとに分けて覚える。
    private var deckOrder: DeckOrderStore {
        DeckOrderStore(accountId: appState.session?.user.id ?? "guest")
    }

    /// そのデッキの進み具合。まだ読めていないデッキは 0 枚として出す。
    private func summary(for deck: Deck) -> DeckProgressSummary {
        summaries[deck.id] ?? .empty
    }

    private var reloadKey: String {
        "\(appState.session?.user.id ?? "guest")-\(appState.studyDataVersion)"
    }

    private func reload() async {
        let dataSource = appState.localStudy
        let order = deckOrder
        do {
            let fetched = try await dataSource.fetchDecks()
            guard appState.localStudy === dataSource else { return }
            // 並びを初めて作るときだけ、以前この端末に覚えていた並び順から始める。
            let seed = dataSource.hasDeckLayout ? [] : order.arranged(fetched).map(\.id)
            tree = try dataSource.arrangedDeckTree(for: fetched, seed: seed)
            errorMessage = nil
            let folderDecks = dataSource.deckFolders.map(dataSource.folderDeck)
            await loadDeckDetails(for: fetched + folderDecks, from: dataSource)
        } catch {
            guard appState.localStudy === dataSource else { return }
            tree = []
            summaries = [:]
            covers = [:]
            errorMessage = UserFacingError.message(for: error)
        }
    }

    /// デッキごとの進み具合と表紙を、同じカード一覧から一度に作る。
    /// 1件が読めなくても残りのデッキは出す。
    ///
    /// ponytail: 数え方はデッキのカードを全部読む素直なやり方。デッキが増えるか
    /// 1デッキが大きくなって一覧の表示が遅れたら、データ層に件数だけを返す
    /// 問い合わせ（`fetchDeckCounts` と同じ置き場所）を足して置き換える。
    private func loadDeckDetails(for decks: [Deck], from dataSource: LocalStudyDataSource) async {
        let store = DeckCoverStore()
        var loadedSummaries: [Int: DeckProgressSummary] = [:]
        var loadedCovers: [Int: URL] = [:]
        for deck in decks {
            guard let cards = try? await dataSource.fetchCards(deckId: deck.id) else { continue }
            loadedSummaries[deck.id] = DeckProgressSummary(cards: cards)
            loadedCovers[deck.id] = store.coverURL(deckId: deck.id, cards: cards)
        }
        // 利用者が切り替わっていたら、前の人の結果は捨てる。
        guard appState.localStudy === dataSource else { return }
        summaries = loadedSummaries
        covers = loadedCovers
    }

    private func delete(_ deck: Deck) {
        let dataSource = appState.studyDataSource

        // 中央のデッキを消したら、詰めて上がってくる下の隣を中央にする。下が無ければ上の隣。
        let order = deckOrder
        if (order.selectedDeckId ?? decks.first?.id) == deck.id,
           let index = decks.firstIndex(of: deck) {
            let neighbor = decks.indices.contains(index + 1) ? decks[index + 1]
                : decks.indices.contains(index - 1) ? decks[index - 1] : nil
            order.selectedDeckId = neighbor?.id
        }

        // 配信中のデッキは、この端末の学習タブから外すだけ。学習の記録は残す。
        guard dataSource.canManage(deck) else {
            changeLayout { try $0.hideDeck(id: deck.id) }
            return
        }

        Task {
            do {
                try await dataSource.deleteDeck(id: deck.id)
                errorMessage = nil
                await reload()
            } catch {
                errorMessage = "デッキを削除できませんでした。\(UserFacingError.advice(for: error))"
            }
        }
    }
}

#if DEBUG
#Preview("Learning Dashboard") {
    LearningDashboardView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif

/// 学習画面へ渡す組み合わせ。`navigationDestination(item:)` に載せるためだけの入れ物。
struct StudyLaunch: Identifiable, Hashable {
    let deck: Deck
    let mode: StudyMode

    var id: String { "\(deck.id)-\(mode.rawValue)" }
}
