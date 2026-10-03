import XCTest
import CoreGraphics
@testable import UsalingoIOS

final class PlayStyleBarHitTestTests: XCTestCase {
    private let size = CGSize(width: 300, height: 48)

    func testTapSelectsEveryMode() {
        for index in 0..<5 {
            let point = CGPoint(x: 30 + index * 60, y: 24)
            XCTAssertEqual(PlayStyleBarHitTest.selection(from: point, to: point, size: size, count: 5), index)
        }
    }

    func testDragFromSelectedModeReachesEveryDestination() {
        for source in 0..<5 {
            for destination in 0..<5 {
                XCTAssertEqual(PlayStyleBarHitTest.selection(
                    from: CGPoint(x: 30 + source * 60, y: 24),
                    to: CGPoint(x: 30 + destination * 60, y: 24),
                    size: size, count: 5
                ), destination)
            }
        }
    }

    /// タブバーと同じく、選択中でないアイコンから触れて滑らせても選べる。
    func testDragFromUnselectedModeSelectsWhereItIsReleased() {
        XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 90, y: 24), to: CGPoint(x: 270, y: 24), size: size, count: 5), 4)
    }

    func testDiagonalDragOutsideBarSelectsByHorizontalPosition() {
        for y in [CGFloat(-200), 24, 250] {
            for destination in 0..<5 {
                let end = CGPoint(x: CGFloat(30 + destination * 60), y: y)
                XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 150, y: 24), to: end, size: size, count: 5), destination)
                XCTAssertEqual(PlayStyleBarHitTest.nearestIndex(atX: end.x, width: size.width, count: 5), destination)
            }
        }
    }

    func testDragPastHorizontalEndsSelectsEndIcons() {
        for y in [CGFloat(-200), 250] {
            XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 150, y: 24), to: CGPoint(x: -500, y: y), size: size, count: 5), 0)
            XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 150, y: 24), to: CGPoint(x: 800, y: y), size: size, count: 5), 4)
        }
    }

    func testStartingOutsideBarCannotSelect() {
        XCTAssertNil(PlayStyleBarHitTest.selection(from: CGPoint(x: 150, y: 60), to: CGPoint(x: 270, y: 24), size: size, count: 5))
    }

    func testCellBoundariesMatchFixedLayout() {
        XCTAssertEqual(PlayStyleBarHitTest.index(at: CGPoint(x: 59.9, y: 24), size: size, count: 5), 0)
        XCTAssertEqual(PlayStyleBarHitTest.index(at: CGPoint(x: 60, y: 24), size: size, count: 5), 1)
        XCTAssertEqual(PlayStyleBarHitTest.index(at: CGPoint(x: 299.9, y: 24), size: size, count: 5), 4)
        XCTAssertNil(PlayStyleBarHitTest.index(at: CGPoint(x: 300, y: 24), size: size, count: 5))
    }

    func testShortDragAcrossBoundarySelectsNearestIcon() {
        XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 59, y: 24), to: CGPoint(x: 61, y: 24), size: size, count: 5), 1)
        XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 61, y: 24), to: CGPoint(x: 59, y: 24), size: size, count: 5), 0)
    }

    func testReleaseOnEitherSideOfEveryBoundarySelectsNearestIcon() {
        for boundary in 1..<5 {
            let x = CGFloat(boundary * 60)
            for delta in [CGFloat(-0.1), 0, 0.1] {
                XCTAssertEqual(PlayStyleBarHitTest.selection(from: CGPoint(x: 30, y: 24), to: CGPoint(x: x + delta, y: 24), size: size, count: 5), delta < 0 ? boundary - 1 : boundary)
            }
        }
    }

    func testInvalidLayoutDoesNotSelect() {
        XCTAssertNil(PlayStyleBarHitTest.index(at: .zero, size: .zero, count: 5))
        XCTAssertNil(PlayStyleBarHitTest.index(at: .zero, size: size, count: 0))
        XCTAssertNil(PlayStyleBarHitTest.index(at: CGPoint(x: CGFloat.nan, y: 24), size: size, count: 5))
    }
}
