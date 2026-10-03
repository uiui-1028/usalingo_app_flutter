import XCTest
@testable import UsalingoIOS

final class WordListColumnLayoutTests: XCTestCase {
    func testChoosingSwapsWithTheColumnThatAlreadyShowsIt() {
        let columns: [WordListColumn] = [.word, .partOfSpeech, .meaning]

        XCTAssertEqual(
            WordListColumn.choosing(.meaning, at: 0, in: columns),
            [.meaning, .partOfSpeech, .word]
        )
        XCTAssertEqual(
            WordListColumn.choosing(.etymology, at: 1, in: columns),
            [.word, .etymology, .meaning]
        )
    }

    func testTwoColumnChoosingKeepsItsBehavior() {
        let chosen = WordListColumn.choosing(.meaning, onLeft: true, left: .word, right: .meaning)

        XCTAssertEqual(chosen.left, .meaning)
        XCTAssertEqual(chosen.right, .word)
    }

    func testAddingPutsTheNewColumnInTheMiddleUpToThree() {
        let three = WordListColumn.adding(.partOfSpeech, to: [.word, .meaning])

        XCTAssertEqual(three, [.word, .partOfSpeech, .meaning])
        XCTAssertEqual(WordListColumn.adding(.etymology, to: three), three)
        XCTAssertEqual(WordListColumn.adding(.word, to: [.word, .meaning]), [.word, .meaning])
    }

    func testRemovingNeverGoesBelowTwoColumns() {
        XCTAssertEqual(
            WordListColumn.removing(at: 0, from: [.word, .partOfSpeech, .meaning]),
            [.partOfSpeech, .meaning]
        )
        XCTAssertEqual(WordListColumn.removing(at: 0, from: [.word, .meaning]), [.word, .meaning])
    }

    func testRotatingShiftsEveryColumnLeft() {
        XCTAssertEqual(
            WordListColumn.rotatedLeft([.word, .partOfSpeech, .meaning]),
            [.partOfSpeech, .meaning, .word]
        )
        XCTAssertEqual(WordListColumn.rotatedLeft([.word, .meaning]), [.meaning, .word])
    }

    func testRedSheetWidthSnapsToColumnBoundaries() {
        XCTAssertEqual(RedSheetPosition.coveredColumns(start: 1, translation: -40, columnWidth: 130, maximum: 2), 1)
        XCTAssertEqual(RedSheetPosition.coveredColumns(start: 1, translation: -70, columnWidth: 130, maximum: 2), 2)
        XCTAssertEqual(RedSheetPosition.coveredColumns(start: 1, translation: -400, columnWidth: 130, maximum: 2), 2)
        XCTAssertEqual(RedSheetPosition.coveredColumns(start: 2, translation: 400, columnWidth: 130, maximum: 2), 1)
    }

    func testRubberBandResistsMoreTheFurtherItIsPulledAndNeverExceedsTheView() {
        XCTAssertEqual(RubberBand.offset(for: 0, dimension: 600), 0)
        let small = RubberBand.offset(for: 50, dimension: 600)
        let large = RubberBand.offset(for: 500, dimension: 600)
        XCTAssertGreaterThan(small, 0)
        XCTAssertLessThan(small, 50, "引いた量より少なく動く")
        XCTAssertLessThan(large / 500, small / 50, "引くほど重くなる")
        XCTAssertLessThan(RubberBand.offset(for: 100_000, dimension: 600), 600)
        XCTAssertEqual(RubberBand.offset(for: -50, dimension: 600), -small, accuracy: 0.0001)
    }
}
