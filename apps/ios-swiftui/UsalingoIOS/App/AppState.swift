import Combine
import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var session: AuthSession? {
        didSet {
            guard session?.user.id != oldValue?.user.id
                || session?.user.isAnonymousAccount != oldValue?.user.isAnonymousAccount else { return }
            handleSessionChange()
        }
    }
    @Published var isRestoringSession = true
    @Published var isResettingPassword = false
    @Published var isShellChromeHidden = false
    @Published var authMessage = ""
    @Published private(set) var studyDataVersion = 0 {
        didSet { scheduleMediaReconcile() }
    }
    /// 単語リストのバナーで最後に選んだデッキ。画面を出入りしても同じデッキを開く。
    var wordListDeckID: Int?

    func redSheetCheckpointStore(deckId: Int?) -> RedSheetCheckpointStore {
        RedSheetCheckpointStore(accountId: session?.user.id ?? authService.cachedUserId() ?? "guest",
                                deckId: deckId, defaults: defaults)
    }
    @Published private(set) var isDeletingAccount = false
    @Published var accountDeletionNotice: String?

    let designSettings: DesignSettings

    /// ローカル同梱データ層（D-1）。デッキ一覧・入出力はこの実体を直接使う。
    @Published private(set) var localStudy: LocalStudyDataSource

    /// 学習画面が使うデータ層。通信状態や認証状態にかかわらず、回答を端末へ先に保存する。
    /// Supabase は認証や、既存の復元用バックアップにだけ使う。
    var studyDataSource: any StudyDataSource {
        localStudy
    }

    /// 学習記録のバックアップを裏側で行う係（G-3）。画面からは触らない。
    private lazy var backupSyncer = makeBackupSyncer(localStudy)

    @Published private(set) var requiresSignIn = false

    // MARK: 画像・音声の先取り（要件 D1〜D7・B1〜B6）

    /// 先取りの係。プレビューとテストでは持たない（裏でダウンロードを始めないため）。
    let mediaDownloader: MediaDownloader?
    /// ギャラリーで押してから、学習タブに入るまでのデッキ。学習タブの空き枠の内側に、ダウンロード中として出す。
    @Published private(set) var addingDecks: [PendingDeckAdd] = []
    /// モバイル回線で、持っているデッキの画像・音声を取りに行ってよいか聞いている（B4）。分かれば大きさを添える。
    @Published private(set) var isAskingMediaConsent = false
    @Published private(set) var mediaConsentBytes: Int64?
    /// この起動の間にモバイル回線での先取りを許したか、断ったか。断ったら次の起動まで聞かない。
    private var allowsExpensiveMediaDownload = false
    private var declinedExpensiveMediaDownload = false
    private var mediaReconcileTask: Task<Void, Never>?
    private var mediaSubscriptions: Set<AnyCancellable> = []

    private var needsReconnect = false
    private var retryDelay = 2.0
    private var authGeneration = 0

    private let connectionIsConfigured: Bool
    private let authService: AuthService
    private let remoteStudy: any RemoteStudyImporting
    private let accountDeletionService: any AccountDeletionServicing
    private let defaults: UserDefaults
    private let makeBackupSyncer: @MainActor (LocalStudyDataSource) -> StudyBackupSyncer

    /// 「まだ登録していない人」。未接続中、または匿名アカウントを指す。
    /// 学習記録はどちらの場合も端末へ保存する。
    var isGuest: Bool {
        session?.user.isAnonymousAccount ?? true
    }

    init(
        restoresSession: Bool = true,
        defaults: UserDefaults = .standard,
        authService: AuthService = AuthService(),
        remoteStudy: any RemoteStudyImporting = StudyService(),
        accountDeletionService: any AccountDeletionServicing = AccountDeletionService(),
        connectionIsConfigured: Bool = SupabaseConfig.isConfigured,
        localStudy: LocalStudyDataSource? = nil,
        mediaDownloader: MediaDownloader? = nil,
        makeBackupSyncer: @escaping @MainActor (LocalStudyDataSource) -> StudyBackupSyncer = { StudyBackupSyncer(localStudy: $0) }
    ) {
        // 既定値の式はメインスレッドの外で評価されるため、ここで作る。
        let localStudy = localStudy ?? LocalStudyDataSource()
        let cachedUserId = authService.cachedUserId()
        // 認証保存の直後やファイルコピーの途中で終了した場合も、次の起動で
        // コピーを完了する。失敗時は元の棚を開き、記録を隠さない。
        if let anonymousId = authService.cachedAnonymousUserId(), localStudy.hasPendingGuestHandoff {
            do {
                try localStudy.adoptPendingGuestStudy(for: anonymousId)
                self.localStudy = localStudy.forAccount(id: anonymousId)
            } catch {
                self.localStudy = localStudy.forAccount(id: nil)
            }
        } else {
            self.localStudy = localStudy.forAccount(id: cachedUserId)
        }
        self.defaults = defaults
        self.connectionIsConfigured = connectionIsConfigured
        self.authService = authService
        self.remoteStudy = remoteStudy
        self.accountDeletionService = accountDeletionService
        self.makeBackupSyncer = makeBackupSyncer
        self.mediaDownloader = mediaDownloader
        designSettings = DesignSettings(defaults: defaults)
        if let mediaDownloader {
            // 学習タブがダウンロードの進み具合で描き直されるよう、係の変化を伝える。
            mediaDownloader.objectWillChange
                .sink { [weak self] in self?.objectWillChange.send() }
                .store(in: &mediaSubscriptions)
            // Wi-Fi につながったら、待たせていた分を確認なしで始める。
            mediaDownloader.$isExpensiveNetwork
                .removeDuplicates()
                .dropFirst()
                .sink { [weak self] _ in self?.scheduleMediaReconcile() }
                .store(in: &mediaSubscriptions)
            scheduleMediaReconcile()
        }
        guard restoresSession else {
            isRestoringSession = false
            return
        }
        if cachedUserId == nil {
            do { try self.localStudy.beginGuestHandoffIfPristine() }
            catch { startupMessage = UserFacingError.message(for: error) }
        }
        Task { await restoreSession() }
    }

    func setSession(_ session: AuthSession) {
        authGeneration += 1
        requiresSignIn = false
        needsReconnect = false
        startupMessage = nil
        self.session = session
    }

    func signOut() {
        do { try localStudy.cancelPendingGuestHandoff() }
        catch {
            authMessage = UserFacingError.message(for: error)
            return
        }
        do { try authService.signOut() }
        catch {
            authMessage = UserFacingError.message(for: error)
            return
        }
        authGeneration += 1
        requiresSignIn = false
        startupMessage = nil
        let hadSession = session != nil
        session = nil
        if !hadSession { handleSessionChange() }
        isResettingPassword = false
        // サインアウト後も端末の学習は止めず、裏側で新しい匿名アカウントを作る。
        Task { await startAnonymousSession() }
    }

    func handleIncomingURL(_ url: URL) {
        Task {
            do {
                if let recovered = try await authService.recoverSession(from: url) {
                    setSession(recovered)
                    isResettingPassword = true
                    return
                }
                setSession(try await authService.sessionFromConfirmationCallback(url: url))
                authMessage = "メール確認が完了しました。"
            } catch {
                authMessage = UserFacingError.message(for: error)
            }
        }
    }

    func setRecoveredPassword(_ password: String, confirmation: String) async throws {
        guard password == confirmation else { throw AuthError.passwordsDoNotMatch }
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updatePassword(password, currentPassword: nil, nonce: nil, accessToken: session.accessToken)
        isResettingPassword = false
    }

    func updatePassword(_ password: String, currentPassword: String, nonce: String? = nil) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updatePassword(password, currentPassword: currentPassword, nonce: nonce, accessToken: session.accessToken)
    }

    /// いまの匿名アカウントを会員登録へ育てる。端末の学習記録はそのまま残る。
    func linkAnonymousAccount(email: String, password: String) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        guard session.user.isAnonymousAccount else { throw AuthError.alreadyRegistered }
        try await authService.linkEmailAndPassword(
            email: email,
            password: password,
            accessToken: session.accessToken
        )
    }

    func updateEmail(_ email: String, currentPassword: String) async throws {
        guard let session else { throw AuthError.sessionRestoreFailed }
        try await authService.updateEmail(email, currentEmail: session.user.email ?? "", currentPassword: currentPassword, accessToken: session.accessToken)
    }

    func deleteAccount(password: String, confirmation: String) async throws {
        guard !isDeletingAccount else { throw AccountDeletionClientError.alreadyInProgress }
        guard confirmation == "退会" else { throw AccountDeletionClientError.invalidConfirmation }
        guard let session else { throw AuthError.sessionRestoreFailed }

        isDeletingAccount = true
        defer { isDeletingAccount = false }
        _ = try await accountDeletionService.withdraw(
            password: password,
            confirmation: confirmation,
            accessToken: session.accessToken
        )

        backupSyncer.stop()
        var resetError: Error?
        do {
            try localStudy.reset()
        } catch {
            resetError = error
        }
        do {
            try authService.signOut()
        } catch {
            resetError = error
        }
        designSettings.reset()
        DeckOrderStore(accountId: session.user.id, defaults: defaults).removeAll()
        RedSheetCheckpointStore(accountId: session.user.id, deckId: nil, defaults: defaults).removeAll()
        self.session = nil
        isResettingPassword = false
        isShellChromeHidden = false
        studyDataVersion = 0
        if resetError != nil {
            accountDeletionNotice = "アカウントは削除しましたが、端末の初期化を完了できませんでした。"
            throw AccountDeletionClientError.localResetFailed
        }
        accountDeletionNotice = "アカウントと学習記録を削除しました。この操作は取り消せません。"
    }

    func clearAccountDeletionNotice() {
        accountDeletionNotice = nil
    }

    func handleAuthCallback(_ url: URL) async {
        do {
            setSession(try await authService.sessionFromConfirmationCallback(url: url))
            authMessage = "メール確認が完了しました。"
        } catch {
            authMessage = UserFacingError.message(for: error)
        }
    }

    func markStudyDataChanged() {
        studyDataVersion += 1
        guard let session else { return }
        backupSyncer.scheduleUpload(session: session)
    }

    /// アプリが非アクティブなら、待機中の送信は次の前面表示まで待つ。
    func pauseStudyBackup() {
        backupSyncer.pause()
    }

    /// 再接続後に、バックアップを取り直す。
    func flushStudyBackup() async {
        guard let session else { return }
        await backupSyncer.flush(session: session)
    }

    /// ログイン・セッション復元で利用者が変わったときだけ、バックアップの同期をやり直す。
    private func handleSessionChange() {
        backupSyncer.stop()
        localStudy = localStudy.forAccount(id: session?.user.id ?? authService.cachedUserId())
        backupSyncer = makeBackupSyncer(localStudy)
        studyDataVersion += 1
        // 匿名アカウントへの端末スナップショット送信は、外部保存の範囲を
        // 広げないため従来どおり行わない。登録済みアカウントだけ既存の控えを使う。
        guard let session else { return }
        Task { [weak self] in
            guard let self, self.session?.user.id == session.user.id else { return }
            if !session.user.isAnonymousAccount {
                await self.backupSyncer.start(session: session) { [weak self] in
                    self?.studyDataVersion += 1
                }
            }
            await self.refreshOfficialContent(session: session)
        }
    }

    func refreshOfficialContentIfConnected() async {
        guard let session else { return }
        await refreshOfficialContent(session: session)
    }

    private func refreshOfficialContent(session: AuthSession) async {
        // 失敗しても、最後に成功した端末版を使い続ける。学習と回答保存は止めない。
        do {
            try await loadOfficialContent(session: session)
        } catch {
            guard self.session?.user.id == session.user.id else { return }
            if case .response(status: 401, code: _) = error as? ConnectionFailure {
                needsReconnect = true
            } else {
                recordConnectionFailure(error)
            }
        }
    }

    private func loadOfficialContent(session: AuthSession) async throws {
        let accountStudy = localStudy
        let decks = try await remoteStudy.fetchDecks(session: session)
        var cardsByDeck: [Int: [WordCard]] = [:]
        for deck in decks {
            cardsByDeck[deck.id] = try await remoteStudy.fetchCards(deckId: deck.id, session: session)
        }
        let progress = try await remoteStudy.fetchAllLearningProgress(session: session)
        guard self.session?.user.id == session.user.id, localStudy === accountStudy else { return }
        try accountStudy.cacheRemoteDecks(decks, cardsByDeck: cardsByDeck, progress: progress, userId: session.user.id)
        studyDataVersion += 1
    }

    // MARK: - デッキ追加（ギャラリー）

    /// ギャラリーに並べる公式デッキ。追加済みかどうかも一緒に返す。
    func fetchOfficialDecks() async throws -> [OfficialDeck] {
        let decks = try await remoteStudy.fetchOfficialDecks(session: try connectedSession())
        // この端末の学習タブから外したデッキは、追加し直せるよう「未追加」として見せる。
        return decks.map { official in
            var official = official
            official.isAdded = official.isAdded
                && !localStudy.isHidden(deckId: LocalStudyDataSource.cachedDeckId(remoteDeckId: official.deck.id))
            // 押したあと、学習タブに入る途中のデッキも追加済みとして見せ、二重に追加させない。
            if addingDecks.contains(where: { $0.id == official.id }) { official.isAdded = true }
            return official
        }
    }

    /// ギャラリーの詳細画面で見せる、公式デッキの収録単語。
    func fetchOfficialDeckCards(deckId: Int) async throws -> [WordCard] {
        try await remoteStudy.fetchCards(deckId: deckId, session: try connectedSession())
    }

    /// 公式デッキを学習タブへ追加し、端末の控えまで更新してから戻る。
    func addOfficialDeck(id: Int) async throws {
        let session = try connectedSession()
        try localStudy.unhideDeck(id: LocalStudyDataSource.cachedDeckId(remoteDeckId: id))
        try await remoteStudy.addOfficialDeck(id: id, session: session)
        try await loadOfficialContent(session: session)
    }

    /// ギャラリーでダウンロードを押した。すぐ学習タブへ戻れるよう、追加と先取りは裏で進める（R4・R5）。
    /// 学習タブに出た瞬間から開けないよう、追加の前に「開けない」印を付ける（D3）。
    func beginAddingDeck(_ official: OfficialDeck, coverURL: URL?, atTop: Bool) {
        guard !addingDecks.contains(where: { $0.id == official.id }) else { return }
        let pending = PendingDeckAdd(official: official, coverURL: coverURL, atTop: atTop)
        mediaDownloader?.lock(deckId: pending.localDeckId, expectedBytes: official.mediaBytes)
        DeckOrderStore(accountId: session?.user.id ?? "guest").selectedDeckId = pending.localDeckId
        addingDecks.append(pending)
        Task { await runAdding(pending) }
    }

    /// 追加が何度もだめで止まったデッキを、利用者の「再試行」でやり直す。
    func retryAdding(_ pending: PendingDeckAdd) {
        guard let index = addingDecks.firstIndex(where: { $0.id == pending.id }) else { return }
        addingDecks[index].isFailed = false
        Task { await runAdding(addingDecks[index]) }
    }

    /// 追加の記録と文字データの読み込み。つながらなければ間を空けながら1分ほど取り直し、それでもだめなら「失敗」にする（T2）。
    /// ponytail: この段階はメモリにしか持たないので、終わる前にアプリを閉じると追加は残らない（ギャラリーから追加し直す）。
    /// 長く切れたままの人が多ければ、端末に覚えて次の起動で続ける形にする。
    private func runAdding(_ pending: PendingDeckAdd) async {
        let waits: [Double] = [2, 4, 8, 16, 30]
        for attempt in 0...waits.count {
            do {
                try await addOfficialDeck(id: pending.id)
                try? localStudy.placeDeck(id: pending.localDeckId, atTop: pending.atTop)
                if let index = addingDecks.firstIndex(where: { $0.id == pending.id }) {
                    addingDecks[index].isPlaced = true
                }
                markStudyDataChanged()
                return
            } catch {
                guard attempt < waits.count else { break }
                try? await Task.sleep(for: .seconds(waits[attempt]))
            }
        }
        if let index = addingDecks.firstIndex(where: { $0.id == pending.id }) {
            addingDecks[index].isFailed = true
        }
    }

    /// 学習タブが読み直して、並びに入れ終えたデッキを出せたら、追加の途中の枠を片付ける。
    func clearPlacedAdds(presentDeckIds: Set<Int>) {
        addingDecks.removeAll { $0.isPlaced && presentDeckIds.contains($0.localDeckId) }
    }

    /// 学習タブのカードに出す、ダウンロードの状態。開けるデッキは nil。
    func downloadState(forDeckId deckId: Int) -> DeckDownloadState? {
        guard let mediaDownloader, mediaDownloader.isLocked(deckId) else { return nil }
        if mediaDownloader.failedDeckIds.contains(deckId) { return .failed }
        return .downloading(mediaDownloader.progress[deckId] ?? 0)
    }

    func retryDownload(deckId: Int) {
        mediaDownloader?.retry(deckId: deckId)
    }

    /// モバイル回線での先取りの確認への答え（B4）。
    func answerMediaConsent(allow: Bool) {
        isAskingMediaConsent = false
        if allow {
            allowsExpensiveMediaDownload = true
            scheduleMediaReconcile()
        } else {
            declinedExpensiveMediaDownload = true
        }
    }

    private func scheduleMediaReconcile() {
        guard mediaDownloader != nil else { return }
        mediaReconcileTask?.cancel()
        mediaReconcileTask = Task { [weak self] in
            // 読み直しが続けて起きることが多いので、少し待ってまとめる。
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await self?.reconcileMedia()
        }
    }

    /// 学習タブのデッキが使うファイルに合わせて、要らないファイルを消し、足りないファイルを取りに行く（B2・B5）。
    /// デッキを外したとき・サインアウト・退会・アカウントの切り替えのどれでも、学習タブが変われば読み直しでここへ来る。
    private func reconcileMedia() async {
        guard let mediaDownloader else { return }
        let source = localStudy
        // 学習タブを読めなかったときは何もしない。空とみなして全部消してしまわないため。
        guard let decks = try? await source.fetchDecks() else { return }
        var paths: [Int: Set<String>] = [:]
        for deck in decks {
            guard let cards = try? await source.fetchCards(deckId: deck.id) else { return }
            paths[deck.id] = Set(cards.flatMap(\.mediaPaths))
        }
        guard source === localStudy, !Task.isCancelled else { return }
        let waiting = await mediaDownloader.reconcile(paths, allowsExpensiveNetwork: allowsExpensiveMediaDownload)
        guard waiting, !declinedExpensiveMediaDownload, !isAskingMediaConsent else { return }
        mediaConsentBytes = await missingMediaBytes(paths)
        isAskingMediaConsent = true
    }

    /// 確認に添える大きさ。デッキの容量から、端末にある分を引く。容量を読めなければ nil。
    private func missingMediaBytes(_ paths: [Int: Set<String>]) async -> Int64? {
        guard let catalog = try? await fetchOfficialDecks() else { return nil }
        let total = catalog.reduce(Int64(0)) { sum, official in
            let id = LocalStudyDataSource.cachedDeckId(remoteDeckId: official.id)
            guard let deckPaths = paths[id], let bytes = official.mediaBytes else { return sum }
            return sum + max(0, bytes - MediaStore.shared.storedBytes(of: deckPaths))
        }
        return total > 0 ? total : nil
    }

    private func connectedSession() throws -> AuthSession {
        guard let session else {
            throw SupabaseError.badResponse("サーバーに接続できないため、デッキを読み込めませんでした。")
        }
        return session
    }

    private func restoreSession() async {
        isRestoringSession = true
        let generation = authGeneration
        defer { isRestoringSession = false }
        startupMessage = nil
        guard connectionIsConfigured else {
            recordConnectionFailure(ConnectionFailure.configuration)
            return
        }
        do {
            let restored: AuthSession
            if let saved = try await authService.restoreSession() {
                restored = saved
            } else {
                restored = try await authService.signInAnonymously()
            }
            guard generation == authGeneration, !Task.isCancelled else { return }
            try acceptSession(restored)
            needsReconnect = false
            requiresSignIn = false
        } catch {
            guard generation == authGeneration, !Task.isCancelled else { return }
            // 回線やサーバーの一時的な失敗では、元の利用者の棚を開いたままにする。
            recordConnectionFailure(error)
        }
    }

    private func startAnonymousSession() async {
        await restoreSession()
    }

    @Published var startupMessage: String?

    private func recordConnectionFailure(_ error: Error) {
        if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
        needsReconnect = ConnectionFailure.isTemporary(error)
        if case .signInRequired = error as? ConnectionFailure {
            requiresSignIn = true
            backupSyncer.stop()
            session = nil
        }
        // 一時的な切断は静かに回復する。対応が必要な失敗だけ案内する。
        startupMessage = needsReconnect ? nil : UserFacingError.message(for: error)
    }

    func retryStartup() async {
        guard !isRestoringSession, !requiresSignIn else { return }
        await restoreSession()
    }

    /// SwiftUIのtaskに所有させ、アプリが非アクティブになると待機も取り消す。
    func maintainForegroundConnection() async {
        while !Task.isCancelled {
            await reconnectIfNeeded()
            let retrying = needsReconnect || backupSyncer.needsRetry
            let delay = retrying ? retryDelay : 30
            retryDelay = retrying ? min(retryDelay * 2, 60) : 2
            do { try await Task.sleep(for: .seconds(delay + Double.random(in: 0...1))) }
            catch { return }
        }
    }

    func reconnectIfNeeded() async {
        guard !isRestoringSession, !requiresSignIn, startupMessage == nil else { return }
        if let failure = backupSyncer.lastFailure, !ConnectionFailure.isTemporary(failure) {
            if case .response(status: 401, code: _) = failure as? ConnectionFailure {
                needsReconnect = true
            } else {
                recordConnectionFailure(failure)
                return
            }
        }
        let expiring = session?.expiresAt.map { TimeInterval($0) <= Date().timeIntervalSince1970 + 60 } ?? false
        guard session == nil || needsReconnect || expiring || backupSyncer.needsRetry else { return }
        let reconnecting = needsReconnect || backupSyncer.needsRetry
        let previousId = session?.user.id
        await restoreSession()
        if session != nil, !needsReconnect, previousId == session?.user.id, !Task.isCancelled {
            await refreshOfficialContentIfConnected()
            if reconnecting, let session {
                await backupSyncer.retry(session: session) { [weak self] in
                    self?.studyDataVersion += 1
                }
            }
        }
    }

    private func acceptSession(_ restored: AuthSession) throws {
        if restored.user.isAnonymousAccount {
            try localStudy.adoptPendingGuestStudy(for: restored.user.id)
        } else {
            try localStudy.cancelPendingGuestHandoff()
        }
        session = restored
    }

}

#if DEBUG
extension AppState {
    static var preview: AppState {
        AppState(restoresSession: false)
    }
}
#endif
