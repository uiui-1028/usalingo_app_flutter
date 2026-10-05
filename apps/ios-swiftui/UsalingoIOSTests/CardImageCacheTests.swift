import XCTest
@testable import UsalingoIOS

final class CardImageCacheTests: XCTestCase {
    /// 追加したデッキの画像は先取りして端末にあるので、一時キャッシュは表紙ぐらいの小ささにする。
    func testUsesSmallDiskCache() {
        XCTAssertEqual(CardImageCache.diskCacheSizeLimit, 20 * 1024 * 1024)
    }

    func testRemovingCacheIsSafeWhenNoImagesHaveBeenLoaded() {
        CardImageCache.removeAll()
    }

    /// 音声は一時キャッシュを持たないので、取るたびに読み込む。
    func testAudioIsLoadedEachTimeWithoutCache() async throws {
        let counter = LoadCounter()
        let cache = CardAudioCache { _ in
            await counter.increment()
            return Data("mp3".utf8)
        }
        let url = URL(string: "https://example.com/content-audio/word/000001.mp3")!

        _ = try await cache.data(for: url)
        _ = try await cache.data(for: url)

        let loadCount = await counter.value
        XCTAssertEqual(loadCount, 2)
    }

    /// 先取りした端末のファイルは、通信せずにそのまま読む。
    func testDownloadedAudioIsReadFromTheDevice() async throws {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("usalingo-audio-\(UUID().uuidString).mp3")
        try Data("local".utf8).write(to: file)
        addTeardownBlock { try? FileManager.default.removeItem(at: file) }

        let data = try await CardAudioCache.shared.data(for: file)

        XCTAssertEqual(data, Data("local".utf8))
    }

    func testFailedAudioDownloadIsReported() async {
        let failing = CardAudioCache { _ in throw URLError(.notConnectedToInternet) }
        let url = URL(string: "https://example.com/content-audio/word/000002.mp3")!

        do {
            _ = try await failing.data(for: url)
            XCTFail("取得に失敗した音声を返してはいけない")
        } catch {}
    }
}

private actor LoadCounter {
    private(set) var value = 0

    func increment() {
        value += 1
    }
}
