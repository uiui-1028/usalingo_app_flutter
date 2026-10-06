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

    func testEveryRetryKeepsIncorrectHistoryAndExistingReviewCalculation() {
        var order = StudyCardOrder(count: 1)
        let now = Date(timeIntervalSince1970: 1_735_732_800)
        var progress = LearningProgress.initial(userId: "user", cardId: 42, now: now)
        for isCorrect in [false, false, true] {
            order.answer(isCorrect: isCorrect)
            progress = progress.marking(isCorrect: isCorrect, now: now)
        }
        XCTAssertNil(order.current)
        XCTAssertEqual(progress.incorrectCount, 2)
        XCTAssertEqual(progress.repetitions, 1)
        XCTAssertEqual(progress.intervalDays, 1)
        XCTAssertEqual(progress.easinessFactor, 2.1, accuracy: 0.000_001)
    }
}
