import XCTest
@testable import UsalingoIOS

/// 先取りした画像・音声の置き場所と、ダウンロードの進み具合の数え方を確かめる。
final class MediaStoreTests: XCTestCase {
    private func makeStore() -> (MediaStore, URL) {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("usalingo-media-\(UUID().uuidString)")
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return (MediaStore(root: root), root)
    }

    private func temporaryFile(_ text: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data(text.utf8).write(to: url)
        return url
    }

    /// 置いたファイルは Storage と同じパスで引け、次の起動（作り直し）でも残っている。
    func testStoredFileIsFoundByPathAfterRelaunch() throws {
        let (store, root) = makeStore()
        let path = "content-images/simple/000/example-000001.webp"

        try store.store(try temporaryFile("webp"), for: path)

        XCTAssertEqual(try Data(contentsOf: XCTUnwrap(store.localURL(for: path))), Data("webp".utf8))
        let relaunched = MediaStore(root: root)
        XCTAssertTrue(relaunched.contains(path))
        XCTAssertEqual(relaunched.storedBytes(of: [path, "content-audio/word/000/pron-000001.mp3"]), 4)
    }

    /// 学習タブのデッキが使わなくなったファイルだけを消す（要件 B5）。
    func testPruneKeepsOnlyFilesStillInUse() throws {
        let (store, _) = makeStore()
        let kept = "content-audio/word/000/pron-000001.mp3"
        let removed = "content-audio/word/000/pron-000002.mp3"
        try store.store(try temporaryFile("a"), for: kept)
        try store.store(try temporaryFile("b"), for: removed)

        XCTAssertEqual(store.prune(keeping: [kept]), [removed])

        XCTAssertTrue(store.contains(kept))
        XCTAssertFalse(store.contains(removed))
        XCTAssertNil(store.localURL(for: removed))
    }

    /// サーバーの値から作るパスなので、置き場所の外を指すものは受け付けない。
    func testRejectsPathsOutsideTheStore() throws {
        let (store, _) = makeStore()

        XCTAssertFalse(MediaStore.isSafe("../secret"))
        XCTAssertFalse(MediaStore.isSafe("/etc/passwd"))
        XCTAssertFalse(MediaStore.isSafe("content-images//a.webp"))
        XCTAssertTrue(MediaStore.isSafe("content-images/simple/000/example-000001.webp"))
        XCTAssertThrowsError(try store.store(try temporaryFile("x"), for: "a/../../b"))
    }

    /// 進み具合はデッキの容量を分母にしたバイト数で、そろうまでは 99% で止める（要件 B1）。
    func testProgressCountsBytesAgainstDeckSizeAndStopsShortOfDone() {
        XCTAssertEqual(MediaDownloader.fraction(storedBytes: 300, receivedBytes: 200, expectedBytes: 1_000,
                                                storedCount: 3, totalCount: 10), 0.5, accuracy: 0.001)
        XCTAssertEqual(MediaDownloader.fraction(storedBytes: 1_200, receivedBytes: 0, expectedBytes: 1_000,
                                                storedCount: 9, totalCount: 10), 0.99, accuracy: 0.001)
        XCTAssertEqual(MediaDownloader.fraction(storedBytes: 1_000, receivedBytes: 0, expectedBytes: 1_000,
                                                storedCount: 10, totalCount: 10), 1)
    }

    /// 容量が分からないデッキは、ファイルの数で数える。
    func testProgressFallsBackToFileCountWithoutDeckSize() {
        XCTAssertEqual(MediaDownloader.fraction(storedBytes: 0, receivedBytes: 0, expectedBytes: 0,
                                                storedCount: 1, totalCount: 4), 0.25, accuracy: 0.001)
    }

    /// 先取りするのは、配信元のパスを持つ画像・例文音声・単語音声だけ。
    func testCardMediaPathsSkipMissingAndAbsoluteURLs() {
        let card = WordCard(id: 1, cardId: 1, text: "create", senses: [WordSense(meaning: "作る")],
                            sentenceEnglish: nil, sentenceJapanese: nil,
                            imageAssetPath: "https://example.com/own.webp",
                            audioAssetPath: "content-audio/example/simple/000/example-000001.mp3",
                            wordAudioAssetPath: "",
                            tags: [], learningStatus: nil, learning: nil)

        XCTAssertEqual(card.mediaPaths, ["content-audio/example/simple/000/example-000001.mp3"])
    }
}
