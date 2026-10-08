import Foundation
import Network

/// 学習タブのデッキが使う画像・音声を、バックグラウンドで端末へ先取りする。
///
/// 要件は docs/plans/deck-gallery-redesign-requirements.md の D1〜D5・B1〜B5・T2。
/// - 学習タブのデッキに端末に無いファイルがあれば、いつでも取りに行く（B2）。要らなくなったファイルは消す（B5）。
/// - ギャラリーから新しく追加したデッキは「開けない」印を付け、100% になるまで進み具合を出す（D3・B1）。
///   持っているデッキの取り直しは開けるまま、何も出さない（B3・T3）。
/// - アプリを閉じても iOS のバックグラウンドダウンロードで続け、次の起動で途中から続ける（D4）。
/// - 失敗は黙って取り直し、何度もだめなときだけ新しいデッキを「失敗」にする（T2）。
@MainActor
final class MediaDownloader: NSObject, ObservableObject {
    static let shared = MediaDownloader()
    static let sessionIdentifier = "jp.usalingo.media-download"
    /// 1つのファイルを何回まで取り直すか。超えたら、そのファイルを使う新しいデッキを「失敗」にする。
    static let maximumAttempts = 3

    /// 新しく追加して、まだ開けないデッキ（端末の番号）の進み具合。0...1。
    @Published private(set) var progress: [Int: Double] = [:]
    /// 何度取り直してもだめで止まっている、新しく追加したデッキ。
    @Published private(set) var failedDeckIds: Set<Int> = []
    /// いまの回線が従量制（モバイル回線など）か。
    @Published private(set) var isExpensiveNetwork = false

    private let store: MediaStore
    private let defaults: UserDefaults
    /// 学習タブのデッキ（端末の番号）ごとの、使うファイル。
    private var jobs: [Int: Set<String>] = [:]
    /// 新しく追加して開けないデッキと、そのデッキの容量（`decks.media_bytes`）。端末に覚えて、閉じても続ける。
    private var lockedDecks: [Int: Int64] {
        didSet { defaults.set(lockedDecks.reduce(into: [String: Int64]()) { $0[String($1.key)] = $1.value }, forKey: Self.lockedKey) }
    }
    private var inFlight: Set<String> = []
    private var receivedBytes: [String: Int64] = [:]
    private var attempts: [String: Int] = [:]
    private var restoredTasks = false
    private var backgroundCompletionHandler: (() -> Void)?
    private let monitor = NWPathMonitor()
    private static let lockedKey = "media.lockedDecks"

    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        return URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
    }()

    init(store: MediaStore = .shared, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.lockedKey) as? [String: Int64] ?? [:]
        lockedDecks = saved.reduce(into: [:]) { result, item in
            if let id = Int(item.key) { result[id] = item.value }
        }
        super.init()
        monitor.pathUpdateHandler = { [weak self] path in
            let expensive = path.isExpensive
            Task { @MainActor in self?.isExpensiveNetwork = expensive }
        }
        monitor.start(queue: .main)
    }

    // MARK: - 呼ぶ側

    /// ギャラリーから追加するデッキに、追加の前に「開けない」印を付ける。学習タブに出た瞬間から開けないようにする。
    func lock(deckId: Int, expectedBytes: Int64?) {
        lockedDecks[deckId] = expectedBytes ?? 0
        failedDeckIds.remove(deckId)
        progress[deckId] = 0
    }

    func isLocked(_ deckId: Int) -> Bool {
        lockedDecks[deckId] != nil
    }

    /// 学習タブのデッキと、それぞれが使うファイルに合わせる。要らないファイルを消し、足りないファイルを取りに行く。
    /// `allowsExpensiveNetwork` が false でモバイル回線のときは、持っているデッキの分は始めない。
    /// 新しく追加したデッキの分は、ギャラリーで利用者が承知しているので始める（D7）。
    /// 始めずに待たせたファイルがあれば true を返す。呼ぶ側は確認を出す（B4）。
    @discardableResult
    func reconcile(_ decks: [Int: Set<String>], allowsExpensiveNetwork: Bool) async -> Bool {
        await restoreTasksIfNeeded()
        jobs = decks
        let required = decks.values.reduce(into: Set<String>()) { $0.formUnion($1) }
        store.prune(keeping: required)
        cancelTasks(notIn: required)

        let waitsForConsent = isExpensiveNetwork && !allowsExpensiveNetwork
        var waiting = false
        for (deckId, paths) in decks {
            let missing = paths.filter { !store.contains($0) && !inFlight.contains($0) }
            guard !missing.isEmpty else { continue }
            if waitsForConsent && !isLocked(deckId) {
                waiting = true
                continue
            }
            missing.forEach(startDownload)
        }
        updateProgress()
        return waiting
    }

    /// 失敗で止まったデッキを、利用者の「再試行」で取り直す。
    func retry(deckId: Int) {
        guard let paths = jobs[deckId] else { return }
        failedDeckIds.remove(deckId)
        for path in paths where !store.contains(path) && !inFlight.contains(path) {
            attempts[path] = 0
            startDownload(path)
        }
        updateProgress()
    }

    /// アプリが裏で起こされたとき（`handleEventsForBackgroundURLSession`）に呼ぶ。終わったら iOS に知らせる。
    func handleBackgroundEvents(_ completionHandler: @escaping () -> Void) {
        backgroundCompletionHandler = completionHandler
        _ = session
    }

    // MARK: - 進み具合

    /// 新しく追加したデッキの進み具合（B1）。分母は `decks.media_bytes`。全部そろうまでは 99% で止める。
    /// 容量が分からないときは、ファイルの数で数える。
    nonisolated static func fraction(
        storedBytes: Int64, receivedBytes: Int64, expectedBytes: Int64,
        storedCount: Int, totalCount: Int
    ) -> Double {
        guard totalCount > 0 else { return 0 }
        if storedCount >= totalCount { return 1 }
        let ratio = expectedBytes > 0
            ? Double(storedBytes + receivedBytes) / Double(expectedBytes)
            : Double(storedCount) / Double(totalCount)
        return min(0.99, max(0, ratio))
    }

    private func updateProgress() {
        var next: [Int: Double] = [:]
        for (deckId, expected) in lockedDecks {
            guard let paths = jobs[deckId], !paths.isEmpty else {
                next[deckId] = progress[deckId] ?? 0
                continue
            }
            let storedCount = paths.filter(store.contains).count
            let value = Self.fraction(
                storedBytes: store.storedBytes(of: paths),
                receivedBytes: paths.reduce(0) { $0 + (receivedBytes[$1] ?? 0) },
                expectedBytes: expected,
                storedCount: storedCount,
                totalCount: paths.count
            )
            if value >= 1 {
                lockedDecks[deckId] = nil
                failedDeckIds.remove(deckId)
            } else {
                next[deckId] = value
            }
        }
        // 細かな書き込みのたびに画面を描き直さないよう、1% 以上動いたときだけ出し直す。
        let changed = next.keys != progress.keys
            || next.contains { abs($0.value - (progress[$0.key] ?? -1)) >= 0.01 }
        if changed { progress = next }
    }

    // MARK: - ダウンロード

    private func startDownload(_ path: String) {
        guard MediaStore.isSafe(path), let url = SupabaseConfig.publicStorageURL(for: path) else { return }
        let task = session.downloadTask(with: url)
        task.taskDescription = path
        inFlight.insert(path)
        task.resume()
    }

    /// 前の起動で始めたダウンロードは iOS が続けているので、同じファイルを二重に頼まない。
    private func restoreTasksIfNeeded() async {
        guard !restoredTasks else { return }
        restoredTasks = true
        let tasks = await session.allTasks
        inFlight.formUnion(tasks.compactMap(\.taskDescription))
    }

    private func cancelTasks(notIn required: Set<String>) {
        let stale = inFlight.subtracting(required)
        guard !stale.isEmpty else { return }
        inFlight.subtract(stale)
        stale.forEach { receivedBytes[$0] = nil }
        session.getAllTasks { tasks in
            tasks.filter { stale.contains($0.taskDescription ?? "") }.forEach { $0.cancel() }
        }
    }

    private func finish(_ path: String, succeeded: Bool) {
        inFlight.remove(path)
        receivedBytes[path] = nil
        if succeeded {
            attempts[path] = nil
        } else if jobs.values.contains(where: { $0.contains(path) }) {
            let count = (attempts[path] ?? 0) + 1
            attempts[path] = count
            if count < Self.maximumAttempts {
                // 少し待ってから取り直す。回線が切れているだけなら、iOS がつながるまで待ってくれる。
                Task {
                    try? await Task.sleep(for: .seconds(Double(count) * 2))
                    guard !store.contains(path), !inFlight.contains(path) else { return }
                    startDownload(path)
                }
            } else {
                let decks = jobs.filter { $0.value.contains(path) && isLocked($0.key) }.keys
                failedDeckIds.formUnion(decks)
            }
        }
        updateProgress()
    }
}

extension MediaDownloader: URLSessionDownloadDelegate {
    /// 一時ファイルはこの関数を抜けると消えるので、ここで移す。代わりの置き場所は `delegateQueue` がメインなので画面と同じ。
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let path = downloadTask.taskDescription else { return }
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
        var succeeded = false
        if (200..<300).contains(status) {
            succeeded = (try? store.store(location, for: path)) != nil
        }
        MainActor.assumeIsolated { finish(path, succeeded: succeeded) }
    }

    nonisolated func urlSession(
        _ session: URLSession, downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64
    ) {
        guard let path = downloadTask.taskDescription else { return }
        MainActor.assumeIsolated {
            receivedBytes[path] = totalBytesWritten
            updateProgress()
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        // 成功は didFinishDownloadingTo で片付け済み。取りやめたものは、取りやめた側が片付け済み。
        guard let error, (error as? URLError)?.code != .cancelled, let path = task.taskDescription else { return }
        MainActor.assumeIsolated { finish(path, succeeded: false) }
    }

    nonisolated func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        MainActor.assumeIsolated {
            backgroundCompletionHandler?()
            backgroundCompletionHandler = nil
        }
    }
}

/// 学習タブでの、ダウンロード中のデッキの見せ方（T1・T2）。
enum DeckDownloadState: Equatable {
    case downloading(Double)
    case failed

    /// フォルダの見せ方。中のデッキの状態をまとめ、1デッキのときと同じ見せ方にする（要件 X16）。
    /// どれもダウンロード中でなければ nil。1つでも止まっていれば「失敗」。
    /// ％は中のデッキの％をならしたもので、終わったデッキは100%として数える。
    /// ponytail: 箱の中のデッキの容量はほぼ同じ（約11MB）なので、バイト数で重みを付けずにならす。
    /// 容量が大きく違うデッキを同じ箱に入れるようになったら、デッキの容量で重みを付ける。
    static func combined(_ states: [DeckDownloadState?]) -> DeckDownloadState? {
        guard states.contains(where: { $0 != nil }) else { return nil }
        if states.contains(.failed) { return .failed }
        let total = states.reduce(0.0) { sum, state in
            if case .downloading(let ratio) = state { return sum + ratio }
            return sum + 1
        }
        return .downloading(total / Double(states.count))
    }
}

/// ギャラリーで押してから、学習タブに入るまで（追加の記録と文字データの読み込み中）の箱。
struct PendingDeckAdd: Identifiable, Hashable {
    let box: OfficialBox
    let coverURL: URL?
    let atTop: Bool
    /// 箱をフォルダにして入れるときの、押した時点で取っておいたフォルダの番号。1つで入るデッキは nil。
    var folderId: Int? = nil
    var isFailed = false
    /// 学習タブの並びに入れ終えた。学習タブが読み直してデッキを出すまで、この枠を残して途切れさせない。
    var isPlaced = false

    var id: String { box.id }
    var name: String { box.name }
    /// 追加するデッキ（サーバーの番号）。押した時点で学習タブに無かったものだけ。
    var deckIds: [Int] { box.missingDecks.map(\.id) }
    /// 学習タブに入ったときの番号（フォルダならフォルダの番号）。入る前から同じ番号でカルーセルの中央に置く。
    var localDeckId: Int {
        if let folderId { return LocalStudyDataSource.folderDeckId(folderId: folderId) }
        return LocalStudyDataSource.cachedDeckId(remoteDeckId: box.decks[0].id)
    }
}
