import XCTest
@testable import UsalingoIOS

final class StudyCardOrderTests: XCTestCase {
    func testIncorrectCardReturnsAfterAllRemainingCards() {
        var order = StudyCardOrder(count: 3)
        order.answer(isCorrect: false)
        XCTAssertEqual(order.remaining, [1, 2, 0])
        XCTAssertEqual(order.progress, 0)
        order.answer(isCorrect: true)
        order.answer(isCorrect: true)
        XCTAssertEqual(order.remaining, [0])
        XCTAssertEqual(order.completedCount, 2)
        XCTAssertEqual(order.progress, 2.0 / 3.0)
        order.answer(isCorrect: true)
        XCTAssertNil(order.current)
        XCTAssertEqual(order.progress, 1)
    }

    func testLastCardRepeatsUntilCorrectWithoutDuplicating() {
        var order = StudyCardOrder(count: 1)
        for _ in 0..<10 {
            order.answer(isCorrect: false)
            XCTAssertEqual(order.remaining, [0])
            XCTAssertEqual(order.progress, 0)
            XCTAssertNil(order.next)
        }
        order.answer(isCorrect: true)
        XCTAssertEqual(order.remaining, [])
        XCTAssertEqual(order.progress, 1)
    }

    func testUndoMixedAnswersRestoresExactOrderAndProgress() {
        var order = StudyCardOrder(count: 3)
        let answers = [false, true, false, false, true, true]
        var checkpoints: [(Int, Bool, [Int], Double)] = []
        for isCorrect in answers {
            checkpoints.append((order.current!, isCorrect, order.remaining, order.progress))
            order.answer(isCorrect: isCorrect)
        }
        XCTAssertNil(order.current)
        for (index, isCorrect, remaining, progress) in checkpoints.reversed() {
            order.undo(cardIndex: index, isCorrect: isCorrect)
            XCTAssertEqual(order.remaining, remaining)
            XCTAssertEqual(order.progress, progress)
        }
        XCTAssertEqual(order.remaining, [0, 1, 2])
    }

    func testUndoLastIncorrectCardDoesNotDuplicateIt() {
        var order = StudyCardOrder(count: 1)
        order.answer(isCorrect: false)
        order.undo(cardIndex: 0, isCorrect: false)
        XCTAssertEqual(order.remaining, [0])
    }

    func testEmptyQueueIgnoresAnswer() {
        var order = StudyCardOrder()
        order.answer(isCorrect: false)
        XCTAssertNil(order.current)
        XCTAssertEqual(order.progress, 0)
    }

    func testNewSessionStartsWithOriginalOrder() {
        var order = StudyCardOrder(count: 3)
        order.answer(isCorrect: false)
        order.answer(isCorrect: true)
        order = StudyCardOrder(count: 3)
        XCTAssertEqual(order.remaining, [0, 1, 2])
        XCTAssertEqual(order.progress, 0)
    }

    func testOnlyCardsMissedInThisSessionAreRetriesAndUndoClearsIt() {
        var order = StudyCardOrder(count: 2)
        XCTAssertFalse(order.isRetry)
        order.answer(isCorrect: false)
        XCTAssertFalse(order.isRetry, "まだ解いていない2枚目")
        order.answer(isCorrect: true)
        XCTAssertTrue(order.isRetry)
        order.answer(isCorrect: false)
        XCTAssertTrue(order.isRetry, "やり直しでも間違えたら、次もやり直し")

        order.undo(cardIndex: 0, isCorrect: false)
        XCTAssertTrue(order.isRetry, "1回目の不正解はまだ残っている")
        order.undo(cardIndex: 1, isCorrect: true)
        order.undo(cardIndex: 0, isCorrect: false)
        XCTAssertEqual(order.remaining, [0, 1])
        XCTAssertFalse(order.isRetry)
    }
}
