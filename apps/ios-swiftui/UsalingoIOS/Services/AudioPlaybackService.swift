import AVFoundation
import Foundation

/// 学習音声を読み込む。
///
/// 追加したデッキの音声は先取りして端末にある（`MediaStore`）ので、その端末のファイルを読む。
/// 端末に無いときだけ配信元から取る。一時キャッシュは持たない（要件 C1）。同じ URL の同時取得は1本にまとめる。
actor CardAudioCache {
    typealias Loader = @Sendable (URL) async throws -> Data

    static let shared = CardAudioCache()

    private let load: Loader
    private var inFlight: [URL: Task<Data, Error>] = [:]

    init(load: @escaping Loader = CardAudioCache.download) {
        self.load = load
    }

    func data(for url: URL) async throws -> Data {
        if let running = inFlight[url] {
            return try await running.value
        }
        let task = Task { try await load(url) }
        inFlight[url] = task
        defer { inFlight[url] = nil }
        return try await task.value
    }

    /// 以前の一時キャッシュ（最大100MB）を片付ける。もう使わないので、起動のたびに残っていれば消す。
    nonisolated static func removeLegacyStorage(fileManager: FileManager = .default) {
        guard let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        try? fileManager.removeItem(at: caches.appendingPathComponent("jp.usalingo.card-audio", isDirectory: true))
    }

    /// エラー応答の本文を音声として扱わないよう、2xx 以外は失敗にする。端末のファイルはそのまま読む。
    @Sendable private static func download(_ url: URL) async throws -> Data {
        if url.isFileURL { return try Data(contentsOf: url) }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse, !(200..<300).contains(response.statusCode) {
            throw URLError(.badServerResponse)
        }
        guard !data.isEmpty else { throw URLError(.zeroByteResource) }
        return data
    }
}

@MainActor
final class AudioPlaybackService: NSObject, ObservableObject {
    /// 再生中（または読み込み中）の音声。単語と例文のどちらが鳴っているかを画面で見分ける。
    @Published private(set) var playingURL: URL?

    private let cache: CardAudioCache
    private var player: AVAudioPlayer?
    private var loadTask: Task<Void, Never>?
    private var queuedURLs: [URL] = []

    init(cache: CardAudioCache = .shared) {
        self.cache = cache
    }

    /// カード表面の音声を指定順に1回ずつ鳴らす。取得や再生に失敗した音声は飛ばす。
    func playSequence(urls: [URL]) {
        stop()
        queuedURLs = urls
        playNext()
    }

    private func playNext() {
        guard player == nil, loadTask == nil else { return }
        guard !queuedURLs.isEmpty else {
            playingURL = nil
            return
        }

        let url = queuedURLs.removeFirst()
        playingURL = url
        loadTask = Task { [cache] in
            let data = try? await cache.data(for: url)
            guard !Task.isCancelled else { return }
            loadTask = nil
            guard playingURL == url else { return }
            guard let data, let audioPlayer = try? AVAudioPlayer(data: data) else {
                finishCurrentPlayback()
                return
            }
            audioPlayer.delegate = self
            player = audioPlayer
            if !audioPlayer.play() {
                finishCurrentPlayback()
            }
        }
    }

    func stop() {
        queuedURLs.removeAll()
        loadTask?.cancel()
        loadTask = nil
        player?.stop()
        player = nil
        playingURL = nil
    }
}

extension AudioPlaybackService: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finish(player) }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.finish(player) }
    }

    /// 止めたあとに届いた古い終了通知で、次に鳴らした音声を止めない。
    private func finish(_ finished: AVAudioPlayer) {
        guard finished === player else { return }
        finishCurrentPlayback()
    }

    private func finishCurrentPlayback() {
        player?.stop()
        player = nil
        playingURL = nil
        playNext()
    }
}
