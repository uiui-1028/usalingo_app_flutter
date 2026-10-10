import XCTest
@testable import UsalingoIOS

/// アイコンビューの並び方と、運んで落とす先の決め方を確かめる。
final class DeckIconGridTests: XCTestCase {
    private let layout = DeckIconGridLayout(width: 210, spacing: 10, nameHeight: 20)

    /// 横2列に、左から右、上から下へ並ぶ。
    func testCellsFillTwoColumnsRowByRow() {
        XCTAssertEqual(layout.cellWidth, 100, accuracy: 0.001)
        XCTAssertEqual(layout.origin(of: 0), CGPoint(x: 0, y: 0))
        XCTAssertEqual(layout.origin(of: 1), CGPoint(x: 110, y: 0))
        XCTAssertEqual(layout.origin(of: 2), CGPoint(x: 0, y: layout.rowStride))
        XCTAssertEqual(layout.rowCount(cells: 3), 2)
        XCTAssertEqual(layout.rowCount(cells: 0), 1)
    }

    /// 指の下の枠と、その枠の中の横の位置。
    func testHitFindsCellAndHorizontalFraction() {
        let hit = layout.hit(CGPoint(x: 135, y: layout.rowStride + 5))
        XCTAssertEqual(hit.position, 3)
        XCTAssertEqual(hit.fractionX, 0.25, accuracy: 0.001)
        XCTAssertEqual(layout.hit(CGPoint(x: 10, y: -20)).position, 0)
    }

    /// 枠の左端なら前、右端なら後ろへ空き箱を動かす。
    func testEdgesMoveTheGap() {
        // 行 0, 2, 3 が残り、空き箱は先頭（0）。指は2番目の枠（行 2）の上。
        let before = DeckIconGridDrop.update(position: 2, fractionX: 0.1, remaining: [0, 2, 3], gap: 0, canMerge: true)
        XCTAssertEqual(before.gap, 1)
        XCTAssertEqual(before.target, .row(2, .before))

        let after = DeckIconGridDrop.update(position: 2, fractionX: 0.9, remaining: [0, 2, 3], gap: 0, canMerge: true)
        XCTAssertEqual(after.gap, 2)
        XCTAssertEqual(after.target, .row(3, .before))
    }

    /// 真ん中なら重ねる。フォルダは重ねられないので、前後へ差し込む。
    func testMiddleMergesOnlyWhenAllowed() {
        let merge = DeckIconGridDrop.update(position: 1, fractionX: 0.5, remaining: [0, 1], gap: 2, canMerge: true)
        XCTAssertEqual(merge.gap, 2)
        XCTAssertEqual(merge.target, .row(1, .onto))

        let folder = DeckIconGridDrop.update(position: 1, fractionX: 0.5, remaining: [0, 1], gap: 2, canMerge: false)
        XCTAssertEqual(folder.gap, 2)
        XCTAssertEqual(folder.target, .end)
    }

    /// 空き箱の上では落とし先を変えない。並びの後ろの空いた所は末尾。
    func testPlaceholderAndTrailingSpaceAreStable() {
        let onGap = DeckIconGridDrop.update(position: 1, fractionX: 0.5, remaining: [0, 1, 2], gap: 1, canMerge: true)
        XCTAssertEqual(onGap.gap, 1)
        XCTAssertEqual(onGap.target, .row(1, .before))

        let tail = DeckIconGridDrop.update(position: 9, fractionX: 0.5, remaining: [0, 1, 2], gap: 1, canMerge: true)
        XCTAssertEqual(tail.gap, 3)
        XCTAssertEqual(tail.target, .end)

        XCTAssertEqual(DeckIconGridDrop.insertionTarget(gap: 0, remaining: [4, 5]), .start)
    }
}
