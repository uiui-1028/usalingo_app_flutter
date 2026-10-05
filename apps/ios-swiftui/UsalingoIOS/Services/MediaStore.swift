import Foundation

/// 先取りした画像・音声を、消えない場所に置く（要件 D1）。
///
/// パスは Storage と同じ `"<bucket>/<object name>"` で、端末にも同じ並びで置く。一時キャッシュと違って
/// 上限で勝手に消さない。消すのは `prune(keeping:)` だけで、学習タブのデッキが使う分だけを残す（要件 B5）。
/// 置き場所は Application Support。iCloud のバックアップには載せない（いつでも取り直せるため）。
///
/// 画面の描画中にも何度も聞かれるので、端末にあるファイルとその大きさはメモリに持っておく。
final class MediaStore: @unchecked Sendable {
    static let shared = MediaStore()

    private let root: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    /// 端末にあるファイルのパスと、その大きさ（バイト）。
    private var sizes: [String: Int64] = [:]

    init(root: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.root = root ?? Self.defaultRoot(fileManager: fileManager)
        try? fileManager.createDirectory(at: self.root, withIntermediateDirectories: true)
        var excluded = URLResourceValues()
        excluded.isExcludedFromBackup = true
        var rootURL = self.root
        try? rootURL.setResourceValues(excluded)
        sizes = scan()
    }

    /// 端末にあれば、そのファイルの URL。
    func localURL(for path: String) -> URL? {
        guard Self.isSafe(path), contains(path) else { return nil }
        return root.appendingPathComponent(path)
    }

    func contains(_ path: String) -> Bool {
        lock.withLock { sizes[path] != nil }
    }

    /// 端末にあるファイルの大きさの合計。無いパスは数えない。
    func storedBytes(of paths: some Sequence<String>) -> Int64 {
        lock.withLock { paths.reduce(0) { $0 + (sizes[$1] ?? 0) } }
    }

    /// ダウンロードし終えた一時ファイルを、決まった場所へ移す。
    func store(_ temporaryFile: URL, for path: String) throws {
        guard Self.isSafe(path) else { throw MediaStoreError.unsafePath }
        let destination = root.appendingPathComponent(path)
        try fileManager.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.moveItem(at: temporaryFile, to: destination)
        let size = (try? fileManager.attributesOfItem(atPath: destination.path)[.size] as? Int64) ?? 0
        lock.withLock { sizes[path] = size }
    }

    /// `paths` に無いファイルを消す。消したパスを返す。
    @discardableResult
    func prune(keeping paths: Set<String>) -> [String] {
        let removed = lock.withLock { sizes.keys.filter { !paths.contains($0) } }
        for path in removed {
            try? fileManager.removeItem(at: root.appendingPathComponent(path))
        }
        lock.withLock { removed.forEach { sizes[$0] = nil } }
        return removed
    }

    /// サーバーの値から作るパスなので、置き場所の外を指すものは受け付けない。
    static func isSafe(_ path: String) -> Bool {
        guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\") else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false)
            .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    private func scan() -> [String: Int64] {
        guard let enumerator = fileManager.enumerator(
            at: root, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]
        ) else { return [:] }
        let prefix = root.standardizedFileURL.path + "/"
        var found: [String: Int64] = [:]
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            let path = String(url.standardizedFileURL.path.dropFirst(prefix.count))
            found[path] = Int64(values?.fileSize ?? 0)
        }
        return found
    }

    private static func defaultRoot(fileManager: FileManager) -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appendingPathComponent("Media", isDirectory: true)
    }
}

enum MediaStoreError: Error {
    case unsafePath
}
