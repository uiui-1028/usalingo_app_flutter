import XCTest
@testable import UsalingoIOS

final class WordListViewModelTests: XCTestCase {
    func testDetailPagingWrapsBothEndsInDisplayedOrder() {
        let words = [makeWord(id: 3, text: "carrot"), makeWord(id: 1, text: "apple"), makeWord(id: 2, text: "banana")]
        var selection = WordDetailSelection(word: words[0], words: words)
        selection.move(by: -1)
        XCTAssertEqual(selection.current.id, 2)
        selection.move(by: 1)
        XCTAssertEqual(selection.current.id, 3)
        selection.move(by: 1)
        XCTAssertEqual(selection.current.id, 1)
    }

    func testDetailPagingSingleWordAndMissingSelectionStayValid() {
        let apple = makeWord(id: 1, text: "apple")
        for words in [[], [apple], [makeWord(id: 2, text: "banana")]] {
            var selection = WordDetailSelection(word: apple, words: words)
            selection.move(by: -1)
            selection.move(by: 1)
            XCTAssertEqual(selection.current, apple)
            XCTAssertEqual(selection.words.count, 1)
        }
    }

    func testDetailPagingPreservesEditsWhenReturningToWord() {
        let apple = makeWord(id: 1, text: "apple")
        let banana = makeWord(id: 2, text: "banana")
        var selection = WordDetailSelection(word: apple, words: [apple, banana])
        selection.select(id: banana.id)
        let edited = makeWord(id: 2, text: "edited banana")
        selection.replace(edited)
        selection.move(by: 1)
        XCTAssertEqual(selection.current, apple)
        selection.move(by: 1)
        XCTAssertEqual(selection.current, edited)
        XCTAssertEqual(selection.words.map(\.id), [1, 2])
        selection.select(id: 99)
        XCTAssertEqual(selection.current, edited)
    }

    @MainActor
    func testLoadWithoutDeckFetchesWordList() async {
        let apple = makeWord(id: 1, text: "apple")
        let dataSource = FakeStudyDataSource(wordList: [apple])
        let viewModel = WordListViewModel()

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [apple.id])
        XCTAssertTrue(viewModel.message.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testLoadWithDeckFetchesDeckCards() async {
        let deck = Deck(id: 7, deckName: "Deck 7", description: nil)
        let card = makeWord(id: 2, text: "banana")
        let dataSource = FakeStudyDataSource(deckCards: [7: [card]])
        let viewModel = WordListViewModel(deck: deck)

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [card.id])
    }

    @MainActor
    func testLoadDoesNotOverwritePreviewWords() async {
        let preview = [makeWord(id: 1, text: "preview")]
        let dataSource = FakeStudyDataSource(wordList: [makeWord(id: 2, text: "remote")])
        let viewModel = WordListViewModel(previewWords: preview)

        await viewModel.load(dataSource: dataSource)

        XCTAssertEqual(viewModel.words.map(\.id), [1])
    }

    @MainActor
    func testLoadFailureSetsUserFacingMessage() async {
        let dataSource = FakeStudyDataSource(error: LocalStudyError.deckNotFound)
        let viewModel = WordListViewModel()

        await viewModel.load(dataSource: dataSource)

        XCTAssertTrue(viewModel.words.isEmpty)
        XCTAssertFalse(viewModel.message.isEmpty)
    }

    @MainActor
    func testLoadDecksOpensPreferredDeckOrFallsBackToFirst() async {
        let decks = [Deck(id: 1, deckName: "A", description: nil), Deck(id: 2, deckName: "B", description: nil)]
        let dataSource = FakeStudyDataSource(
            deckCards: [1: [makeWord(id: 10, text: "a")], 2: [makeWord(id: 20, text: "b")]],
            decks: decks
        )

        let remembered = WordListViewModel()
        await remembered.loadDecks(dataSource: dataSource, preferredDeckID: 2)
        XCTAssertEqual(remembered.decks.map(\.id), [1, 2])
        XCTAssertEqual(remembered.deck?.id, 2)
        XCTAssertEqual(remembered.words.map(\.id), [20])

        let missing = WordListViewModel()
        await missing.loadDecks(dataSource: dataSource, preferredDeckID: 99)
        XCTAssertEqual(missing.deck?.id, 1)
        XCTAssertEqual(missing.words.map(\.id), [10])
    }

    @MainActor
    func testEachDeckEntryLoadsItsOwnWordsInsteadOfRememberedOrFirstDeck() async {
        let decks = [1, 2, 4].map { Deck(id: $0, deckName: "Deck \($0)", description: nil) }
        let source = FakeStudyDataSource(
            deckCards: [1: [makeWord(id: 10, text: "a")], 2: [makeWord(id: 20, text: "b")], 4: [makeWord(id: 40, text: "d")]],
            decks: decks
        )
        for remembered in [nil, 1] as [Int?] {
            for deck in decks {
                let model = WordListViewModel(deck: deck)
                await model.loadDecks(dataSource: source, preferredDeckID: remembered)
                XCTAssertEqual(model.deck?.id, deck.id)
                XCTAssertEqual(model.words.map(\.id), [deck.id * 10])
            }
        }
    }

    @MainActor
    func testExplicitEntryCanLoadAllDecksAndFoldersAbsentFromDeckCatalog() async {
        let first = Deck(id: 1, deckName: "A", description: nil)
        let folderID = LocalStudyDataSource.folderDeckId(folderId: 1)
        let source = FakeStudyDataSource(
            deckCards: [1: [makeWord(id: 10, text: "a")], -1: [makeWord(id: 90, text: "all")], folderID: [makeWord(id: 80, text: "folder")]],
            decks: [first]
        )
        for (id, wordID) in [(-1, 90), (folderID, 80)] {
            let model = WordListViewModel(deck: Deck(id: id, deckName: "集約", description: nil))
            await model.loadDecks(dataSource: source, preferredDeckID: 1)
            XCTAssertEqual(model.deck?.id, id)
            XCTAssertEqual(model.words.map(\.id), [wordID])
        }
    }

    @MainActor
    func testSpecifiedDeckDoesNotDependOnLoadingDeckCatalog() async {
        let deck = Deck(id: 2, deckName: "B", description: nil)
        let source = FakeStudyDataSource(deckCards: [2: [makeWord(id: 20, text: "b")]], deckError: LocalStudyError.deckNotFound)
        let model = WordListViewModel(deck: deck)
        await model.loadDecks(dataSource: source, preferredDeckID: nil)
        XCTAssertEqual(model.deck?.id, 2)
        XCTAssertEqual(model.words.map(\.id), [20])
        XCTAssertTrue(model.message.isEmpty)
    }

    @MainActor
    func testSpecifiedDeckLoadFailureKeepsRequestedDeckAndShowsError() async {
        let deck = Deck(id: 2, deckName: "B", description: nil)
        let source = FakeStudyDataSource(error: LocalStudyError.deckNotFound, decks: [Deck(id: 1, deckName: "A", description: nil)])
        let model = WordListViewModel(deck: deck)
        await model.loadDecks(dataSource: source, preferredDeckID: 1)
        XCTAssertEqual(model.deck?.id, 2)
        XCTAssertTrue(model.words.isEmpty)
        XCTAssertFalse(model.message.isEmpty)
    }

    @MainActor
    func testLoadDecksWithoutDecksShowsNoWords() async {
        let dataSource = FakeStudyDataSource(wordList: [makeWord(id: 1, text: "other")])
        let viewModel = WordListViewModel()

        await viewModel.loadDecks(dataSource: dataSource, preferredDeckID: nil)

        XCTAssertNil(viewModel.deck)
        XCTAssertTrue(viewModel.words.isEmpty)
        XCTAssertTrue(viewModel.deckMessage.isEmpty)
    }

    @MainActor
    func testLoadDecksFailureKeepsErrorInBanner() async {
        let dataSource = FakeStudyDataSource(deckError: LocalStudyError.deckNotFound)
        let viewModel = WordListViewModel()

        await viewModel.loadDecks(dataSource: dataSource, preferredDeckID: nil)

        XCTAssertTrue(viewModel.decks.isEmpty)
        XCTAssertFalse(viewModel.deckMessage.isEmpty)
        XCTAssertTrue(viewModel.message.isEmpty)
    }

    @MainActor
    func testSelectDeckSwapsWordsAndClearsOnlyTagFilter() async {
        let decks = [Deck(id: 1, deckName: "A", description: nil), Deck(id: 2, deckName: "B", description: nil)]
        let dataSource = FakeStudyDataSource(
            deckCards: [1: [makeWord(id: 10, text: "a", tags: ["x"])], 2: [makeWord(id: 20, text: "b")]],
            decks: decks
        )
        let viewModel = WordListViewModel()
        await viewModel.loadDecks(dataSource: dataSource, preferredDeckID: nil)
        viewModel.selectedTagFilter = "x"
        viewModel.selectedSort = .alphabetical

        await viewModel.selectDeck(decks[1], dataSource: dataSource)

        XCTAssertEqual(viewModel.deck?.id, 2)
        XCTAssertEqual(viewModel.words.map(\.id), [20])
        XCTAssertNil(viewModel.selectedTagFilter)
        XCTAssertEqual(viewModel.selectedSort, .alphabetical)
        XCTAssertFalse(viewModel.isLoading)
    }

    @MainActor
    func testFilteredWordsAppliesTagStatusDueAndSearch() {
        let viewModel = WordListViewModel(previewWords: [
            makeWord(id: 1, text: "apple", tags: ["fruit"], learningStatus: "learning"),
            makeWord(id: 2, text: "banana", tags: ["fruit"], learningStatus: "mastered"),
            makeWord(id: 3, text: "carrot", tags: ["vegetable"], learningStatus: "learning")
        ])

        viewModel.selectedTagFilter = "fruit"
        viewModel.selectedStatusFilter = .learning
        XCTAssertEqual(viewModel.filteredWords.map(\.id), [1])

        viewModel.selectedStatusFilter = .all
        viewModel.searchText = "ban"
        XCTAssertEqual(viewModel.filteredWords.map(\.id), [2])
    }

    @MainActor
    func testReplaceWordUpdatesWordsAndClearsMissingTagFilter() {
        let original = makeWord(id: 1, text: "apple", tags: ["fruit"])
        let viewModel = WordListViewModel(previewWords: [original])
        viewModel.selectedTagFilter = "fruit"

        let updated = makeWord(id: 1, text: "apple", tags: [])
        let returned = viewModel.replaceWord(updated)

        XCTAssertEqual(returned.tags, [])
        XCTAssertEqual(viewModel.words.first?.tags, [])
        XCTAssertNil(viewModel.selectedTagFilter)
    }

    func testChoosingColumnAlreadyOnOtherSideSwapsSides() {
        let left = WordListColumn.choosing(.meaning, onLeft: true, left: .word, right: .meaning)
        XCTAssertEqual(left.left, .meaning)
        XCTAssertEqual(left.right, .word)

        let right = WordListColumn.choosing(.word, onLeft: false, left: .word, right: .meaning)
        XCTAssertEqual(right.left, .meaning)
        XCTAssertEqual(right.right, .word)
    }

    func testChoosingNewColumnKeepsOtherSide() {
        let chosen = WordListColumn.choosing(.etymology, onLeft: false, left: .word, right: .meaning)
        XCTAssertEqual(chosen.left, .word)
        XCTAssertEqual(chosen.right, .etymology)
    }

    func testColumnValueIsEmptyWhenDataIsMissing() {
        let word = makeWord(id: 1, text: "apple")
        XCTAssertEqual(WordListColumn.word.value(of: word), "apple")
        XCTAssertEqual(WordListColumn.meaning.value(of: word), "meaning")
        XCTAssertEqual(WordListColumn.sentenceEnglish.value(of: word), "")
        XCTAssertEqual(WordListColumn.etymology.value(of: word), "")
        XCTAssertEqual(WordListColumn.synonyms.value(of: word), "")
    }

    private func makeWord(
        id: Int,
        text: String,
        tags: [String] = [],
        learningStatus: String? = nil
    ) -> WordCard {
        WordCard(
            id: id,
            text: text,
            meaning: "meaning",
            partOfSpeech: nil,
            sentenceEnglish: nil,
            sentenceJapanese: nil,
            imageAssetPath: nil,
            audioAssetPath: nil,
            tags: tags,
            learningStatus: learningStatus,
            learning: nil
        )
    }
}

@MainActor
final class RedSheetCheckTests: XCTestCase {
    func testRelaunchRestoresOrderJudgmentsAndGeometryWithoutSavingAgain() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let source = FakeStudyDataSource()
        var saves = 0
        source.saveHandler = { card, correct in
            saves += 1
            return self.saved(card: card, correct: correct)
        }
        let first = RedSheetCheckModel()
        first.resume(words: words, availableWords: words, source: source, store: store) { _ in }
        answer(first, true)
        await settle(first)
        first.sheetTopRatio = 0.7
        first.coveredColumns = 2
        first.rememberSheetPosition()
        first.revealAnswer()

        let restored = RedSheetCheckModel()
        restored.resume(words: Array(words.reversed()), availableWords: Array(words.reversed()), source: source, store: store) { _ in }
        XCTAssertEqual(restored.words.map(\.id), [1, 2, 3])
        XCTAssertEqual(restored.current?.id, 2)
        XCTAssertEqual(restored.answers[1], true)
        XCTAssertEqual(restored.sheetTopRatio, 0.7)
        XCTAssertEqual(restored.coveredColumns, 2)
        XCTAssertFalse(restored.isAnswerVisible)
        XCTAssertEqual(saves, 1)
    }

    func testResumeKeepsOriginalMembershipAndSkipsMissingAndSuspendedWords() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let first = RedSheetCheckModel()
        first.resume(words: words, availableWords: words, source: FakeStudyDataSource(), store: store) { _ in }
        let newWord = words[0].withSuspension(true)
        let restored = RedSheetCheckModel()
        restored.resume(words: [words[2]], availableWords: [words[2], newWord], source: FakeStudyDataSource(), store: store) { _ in }
        XCTAssertEqual(restored.words.map(\.id), [1, 3])
        XCTAssertEqual(restored.current?.id, 3)
        XCTAssertTrue(restored.words[0].isSuspended)
    }

    func testSameScreenResumeHidesAnswerAndResetKeepsGeometryAndLearningHistory() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let source = FakeStudyDataSource()
        var saves = 0
        source.saveHandler = { card, correct in
            saves += 1
            return self.saved(card: card, correct: correct)
        }
        let model = RedSheetCheckModel()
        model.resume(words: words, availableWords: words, source: source, store: store) { _ in }
        answer(model, false)
        await settle(model)
        model.sheetTopRatio = 0.4
        model.coveredColumns = 2
        model.revealAnswer()
        model.resume(words: [words[2]], availableWords: words, source: source, store: store) { _ in }
        XCTAssertEqual(model.current?.id, 2)
        XCTAssertFalse(model.isAnswerVisible)
        model.start(words: [words[2]], source: source) { _ in }
        XCTAssertEqual(model.current?.id, 3)
        XCTAssertTrue(model.answers.isEmpty)
        XCTAssertEqual(model.index, 0)
        XCTAssertEqual(model.sheetTopRatio, 0.4)
        XCTAssertEqual(model.coveredColumns, 2)
        XCTAssertEqual(store.load()?.wordIDs, [3])
        XCTAssertEqual(saves, 1, "再開とリセットは学習履歴を変更しない")
    }

    func testCheckpointIsolationAndInvalidDataFallback() throws {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let model = RedSheetCheckModel()
        model.resume(words: words, availableWords: words, source: FakeStudyDataSource(), store: store) { _ in }
        XCTAssertNotNil(store.load())
        XCTAssertNil(RedSheetCheckpointStore(accountId: "b", deckId: 1, defaults: defaults).load())
        XCTAssertNil(RedSheetCheckpointStore(accountId: "a", deckId: 2, defaults: defaults).load())
        XCTAssertNil(RedSheetCheckpointStore(accountId: "a", deckId: nil, defaults: defaults).load())
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(try XCTUnwrap(store.load()))) as? [String: Any])
        object["index"] = -1
        defaults.set(try JSONSerialization.data(withJSONObject: object), forKey: store.key)
        XCTAssertNil(store.load())
        defaults.set(Data("broken".utf8), forKey: store.key)
        XCTAssertNil(store.load())
    }

    func testPendingAnswerSurvivesRelaunchWithPreparedResultAndDoesNotCountTwice() async {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let source = FakeStudyDataSource()
        var fail = true
        var preparations = 0
        source.attemptSaveHandler = { card, correct, attempt in
            if attempt.prepared == nil {
                preparations += 1
                attempt.prepared = self.saved(card: card, correct: correct)
            }
            try attempt.didPrepare?()
            if fail { throw URLError(.cannotWriteToFile) }
            return try XCTUnwrap(attempt.prepared)
        }
        let first = RedSheetCheckModel()
        first.resume(words: words, availableWords: words, source: source, store: store) { _ in }
        answer(first, true)
        await settle(first)
        XCTAssertEqual(store.load()?.pending.count, 1)
        XCTAssertNotNil(store.load()?.pending.first?.prepared)
        fail = false
        let restored = RedSheetCheckModel()
        restored.resume(words: words, availableWords: words, source: source, store: store) { _ in }
        await settle(restored)
        XCTAssertEqual(preparations, 1)
        XCTAssertEqual(restored.current?.id, 2)
        XCTAssertEqual(restored.pendingCount, 0)
        XCTAssertEqual(store.load()?.pending.count, 0)
    }

    func testDeletedOriginalSessionDoesNotAutomaticallyIncludeNewWords() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let store = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        defer { store.removeAll() }
        let first = RedSheetCheckModel()
        first.resume(words: [words[0]], availableWords: words, source: FakeStudyDataSource(), store: store) { _ in }
        let restored = RedSheetCheckModel()
        restored.resume(words: [words[2]], availableWords: [words[2]], source: FakeStudyDataSource(), store: store) { _ in }
        XCTAssertTrue(restored.isComplete)
        XCTAssertTrue(restored.words.isEmpty)
        XCTAssertNil(restored.current)
    }

    func testAccountCheckpointCleanupDoesNotDeleteOtherAccountsOrRecreateDeletedRecord() {
        let defaults = UserDefaults(suiteName: UUID().uuidString)!
        let firstStore = RedSheetCheckpointStore(accountId: "a", deckId: 1, defaults: defaults)
        let secondStore = RedSheetCheckpointStore(accountId: "a", deckId: 2, defaults: defaults)
        let otherStore = RedSheetCheckpointStore(accountId: "b", deckId: 1, defaults: defaults)
        defer { firstStore.removeAll(); otherStore.removeAll() }
        let first = RedSheetCheckModel()
        first.resume(words: words, availableWords: words, source: FakeStudyDataSource(), store: firstStore) { _ in }
        let second = RedSheetCheckModel()
        second.resume(words: words, availableWords: words, source: FakeStudyDataSource(), store: secondStore) { _ in }
        let other = RedSheetCheckModel()
        other.resume(words: words, availableWords: words, source: FakeStudyDataSource(), store: otherStore) { _ in }
        firstStore.removeAll()
        first.detach()
        second.detach()
        XCTAssertNil(firstStore.load())
        XCTAssertNil(secondStore.load())
        XCTAssertNotNil(otherStore.load())
    }

    func testDetachPreventsOldAccountSaveFromChangingNewSession() async {
        let source = FakeStudyDataSource()
        var continuation: CheckedContinuation<SavedAnswer, Error>?
        source.saveHandler = { _, _ in
            try await withCheckedThrowingContinuation { continuation = $0 }
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in XCTFail("前アカウントの結果を新画面へ渡さない") }
        answer(model, true)
        for _ in 0..<1000 where continuation == nil { await Task.yield() }
        model.detach()
        model.start(words: [words[2]], source: FakeStudyDataSource()) { _ in }
        continuation?.resume(returning: saved(card: words[0], correct: true))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.current?.id, 3)
        XCTAssertTrue(model.answers.isEmpty)
        XCTAssertEqual(model.pendingCount, 0)
    }

    func testSuspendedRowsStayVisibleButAreSkippedAndUndoReturnsToAnsweredWord() async {
        let source = FakeStudyDataSource()
        let model = RedSheetCheckModel()
        source.saveHandler = { card, correct in self.saved(card: card, correct: correct) }
        model.start(words: [words[0], words[1].withSuspension(true), words[2]], source: source) { _ in }
        XCTAssertEqual(model.words.count, 3)
        answer(model, true)
        await settle(model)
        XCTAssertEqual(model.current?.id, 3)
        await model.undo()
        XCTAssertEqual(model.current?.id, 1)
        XCTAssertFalse(model.isAnswerVisible)
    }

    func testRemovingOrSuspendingCurrentRowAdvancesWithoutAnAnswer() {
        let model = RedSheetCheckModel()
        model.start(words: words, source: FakeStudyDataSource()) { _ in }
        model.revealAnswer()
        model.replaceWord(words[0].withSuspension(true))
        XCTAssertEqual(model.current?.id, 2)
        XCTAssertFalse(model.isAnswerVisible)
        model.removeWord(id: 2)
        XCTAssertEqual(model.current?.id, 3)
        model.removeWord(id: 3)
        XCTAssertTrue(model.isComplete)
        XCTAssertTrue(model.answers.isEmpty)
        XCTAssertEqual(model.pendingCount, 0)
    }

    func testReplacingAnotherWordDoesNotReenableASecondUndo() async {
        let source = FakeStudyDataSource()
        source.saveHandler = { card, correct in self.saved(card: card, correct: correct) }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        answer(model, true)
        await settle(model)
        await model.undo()
        model.replaceWord(words[2].withTags(["tag"]))
        XCTAssertFalse(model.canUndo)
    }

    func testRowSwipeOnlyCommitsDeepLeftwardMovement() {
        XCTAssertFalse(WordRowSwipe.commits(offset: 240, width: 360))
        XCTAssertFalse(WordRowSwipe.commits(offset: -WordRowSwipe.revealWidth, width: 360))
        XCTAssertTrue(WordRowSwipe.commits(offset: -240, width: 360))
        XCTAssertFalse(WordRowSwipe.commits(offset: -100, width: 200))
    }

    func testAllSuspendedRowsCompleteWithoutSavingAndCopiesKeepSuspension() throws {
        let model = RedSheetCheckModel()
        let suspended = words.map { $0.withSuspension(true) }
        model.start(words: suspended, source: FakeStudyDataSource()) { _ in }
        XCTAssertTrue(model.isComplete)
        XCTAssertTrue(model.canLeave)
        XCTAssertTrue(suspended[0].withTags(["tag"]).withLearningProgress(nil).isSuspended)
        let decoded = try JSONDecoder().decode(WordCard.self, from: JSONEncoder().encode(suspended[0]))
        XCTAssertTrue(decoded.isSuspended)
    }

    func testTapRevealsThenJudgmentSubmits() {
        let model = RedSheetCheckModel()
        model.start(words: words, source: FakeStudyDataSource()) { _ in }

        model.revealAnswer()
        XCTAssertTrue(model.isAnswerVisible)
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.answers.isEmpty)

        model.submit(isCorrect: true)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.isAnswerVisible)
    }

    func testRevealRequiredAndJudgmentAdvancesBeforeSaving() async {
        let source = FakeStudyDataSource()
        let model = RedSheetCheckModel()
        var resume: CheckedContinuation<SavedAnswer, Error>?
        source.saveHandler = { card, correct in
            try await withCheckedThrowingContinuation { resume = $0 }
        }
        model.start(words: words, source: source) { _ in }
        model.submit(isCorrect: true)
        XCTAssertEqual(model.index, 0)
        model.isAnswerVisible = true
        model.submit(isCorrect: true)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.isAnswerVisible)
        XCTAssertEqual(model.pendingCount, 1)
        XCTAssertFalse(model.canLeave)
        for _ in 0..<1000 where resume == nil { await Task.yield() }
        resume?.resume(returning: saved(card: words[0], correct: true))
        await settle(model)
        XCTAssertTrue(model.canLeave)
    }

    func testFailedSaveKeepsAdvancingAndRetriesInOrderWithoutRepeatingSavedCards() async {
        let source = FakeStudyDataSource()
        var calls: [Int] = []
        var fails = true
        source.saveHandler = { card, correct in
            calls.append(card.id)
            if card.id == 2 && fails { throw URLError(.notConnectedToInternet) }
            return self.saved(card: card, correct: correct)
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        answer(model, false)
        await settle(model)
        answer(model, true)
        XCTAssertTrue(model.isComplete)
        XCTAssertEqual(model.pendingCount, 2)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(calls, [1, 2])
        fails = false
        model.retry()
        await settle(model)
        XCTAssertEqual(calls, [1, 2, 2, 3])
        XCTAssertEqual(model.pendingCount, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testUndoSavedAnswerRestoresPreviousProgressAndIsOnlyOneStep() async {
        let source = FakeStudyDataSource()
        let previous = LearningProgress.initial(userId: "test", cardId: 2).marking(isCorrect: false)
        source.saveHandler = { card, correct in
            SavedAnswer(progress: previous.marking(isCorrect: correct), previousProgress: previous)
        }
        var restored: Int?
        source.restoreHandler = { cardId, progress in
            restored = cardId
            XCTAssertEqual(progress?.incorrectCount, 1)
        }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        answer(model, false)
        await settle(model)
        await model.undo()
        XCTAssertEqual(restored, 2)
        XCTAssertEqual(model.index, 1)
        XCTAssertNil(model.answers[2])
        XCTAssertEqual(model.answers[1], true)
        XCTAssertFalse(model.canUndo)
        XCTAssertFalse(model.isAnswerVisible)
        await model.undo()
        XCTAssertEqual(model.index, 1)
    }

    func testUndoUnsentLastAnswerPreservesEarlierPendingAnswer() async {
        let source = FakeStudyDataSource()
        source.saveHandler = { _, _ in throw URLError(.notConnectedToInternet) }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        answer(model, false)
        await model.undo()
        await settle(model)
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.pendingCount, 1)
        XCTAssertNil(model.answers[2])
        XCTAssertFalse(model.canLeave)
    }

    func testUndoDuringSaveWaitsAndRestoresOnce() async {
        let source = FakeStudyDataSource()
        var resume: CheckedContinuation<SavedAnswer, Error>?
        source.saveHandler = { _, _ in
            try await withCheckedThrowingContinuation { resume = $0 }
        }
        var restores = 0
        source.restoreHandler = { _, _ in restores += 1 }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, false)
        for _ in 0..<1000 where resume == nil { await Task.yield() }
        let undo = Task { await model.undo() }
        for _ in 0..<1000 where !model.isUndoing { await Task.yield() }
        resume?.resume(returning: saved(card: words[0], correct: false))
        await undo.value
        XCTAssertEqual(restores, 1)
        XCTAssertEqual(model.index, 0)
        XCTAssertTrue(model.answers.isEmpty)
        XCTAssertEqual(model.pendingCount, 0)
    }

    func testFailedUndoCanBeRetriedWithoutChangingDisplayedAnswer() async {
        let source = FakeStudyDataSource()
        source.saveHandler = { card, correct in self.saved(card: card, correct: correct) }
        source.restoreHandler = { _, _ in throw URLError(.notConnectedToInternet) }
        let model = RedSheetCheckModel()
        model.start(words: words, source: source) { _ in }
        answer(model, true)
        await settle(model)
        await model.undo()
        XCTAssertEqual(model.index, 1)
        XCTAssertEqual(model.answers[1], true)
        XCTAssertTrue(model.canUndo)
        XCTAssertNotNil(model.errorMessage)
        source.restoreHandler = { _, _ in }
        await model.undo()
        XCTAssertEqual(model.index, 0)
        XCTAssertNil(model.errorMessage)
    }

    func testUnsavablePreviewCannotStart() {
        let model = RedSheetCheckModel()
        let word = WordCard(id: 9, text: "preview", meaning: "見本", partOfSpeech: nil,
                            sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                            audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        model.start(words: [word], source: FakeStudyDataSource()) { _ in }
        XCTAssertFalse(model.isStarted)
    }

    private var words: [WordCard] {
        (1...3).map { id in
            WordCard(id: id, cardId: id, text: "word \(id)", meaning: "意味", partOfSpeech: nil,
                     sentenceEnglish: nil, sentenceJapanese: nil, imageAssetPath: nil,
                     audioAssetPath: nil, tags: [], learningStatus: nil, learning: nil)
        }
    }

    private func saved(card: WordCard, correct: Bool) -> SavedAnswer {
        SavedAnswer(progress: LearningProgress.initial(userId: "test", cardId: card.id).marking(isCorrect: correct), previousProgress: nil)
    }

    private func answer(_ model: RedSheetCheckModel, _ correct: Bool) {
        model.isAnswerVisible = true
        model.submit(isCorrect: correct)
    }

    private func settle(_ model: RedSheetCheckModel) async {
        for _ in 0..<1000 where model.isSaving { await Task.yield() }
        XCTAssertFalse(model.isSaving)
    }
}

private final class FakeStudyDataSource: StudyDataSource {
    var attemptSaveHandler: ((WordCard, Bool, AnswerSaveAttempt) async throws -> SavedAnswer)?
    var saveHandler: ((WordCard, Bool) async throws -> SavedAnswer)?
    var restoreHandler: ((Int, LearningProgress?) async throws -> Void)?
    private let wordList: [WordCard]
    private let deckCards: [Int: [WordCard]]
    private let error: Error?
    private let decks: [Deck]
    private let deckError: Error?

    init(
        wordList: [WordCard] = [],
        deckCards: [Int: [WordCard]] = [:],
        error: Error? = nil,
        decks: [Deck] = [],
        deckError: Error? = nil
    ) {
        self.wordList = wordList
        self.deckCards = deckCards
        self.error = error
        self.decks = decks
        self.deckError = deckError
    }

    func fetchDecks() async throws -> [Deck] {
        if let deckError { throw deckError }
        return decks
    }
    func fetchDeckCounts(deckId: Int) async throws -> StudyDeckCounts { StudyDeckCounts(newCount: 0, dueCount: 0) }

    func fetchCards(deckId: Int) async throws -> [WordCard] {
        if let error { throw error }
        return deckCards[deckId] ?? []
    }

    func fetchWordList() async throws -> [WordCard] {
        if let error { throw error }
        return wordList
    }

    func fetchStudyQueue(deckId: Int, mode: StudyMode) async throws -> [WordCard] { [] }
    func fetchStudyStats() async throws -> StudyStats { .empty }
    func saveAnswer(card: WordCard, isCorrect: Bool) async throws -> LearningProgress { throw LocalStudyError.missingCardId }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool) async throws -> SavedAnswer {
        guard let saveHandler else { throw LocalStudyError.missingCardId }
        return try await saveHandler(card, isCorrect)
    }
    func saveAnswerWithUndo(card: WordCard, isCorrect: Bool, attempt: AnswerSaveAttempt) async throws -> SavedAnswer {
        if let attemptSaveHandler { return try await attemptSaveHandler(card, isCorrect, attempt) }
        return try await saveAnswerWithUndo(card: card, isCorrect: isCorrect)
    }
    func restoreLearningProgress(cardId: Int, previousProgress: LearningProgress?) async throws {
        try await restoreHandler?(cardId, previousProgress)
    }
    func fetchTags(wordId: Int) async throws -> [String]? { nil }
    func saveTags(_ tags: Set<String>, wordId: Int) async throws {}
    func saveWordOverride(_ payload: WordOverridePayload) async throws -> WordCard { throw LocalStudyError.deckNotFound }
    func canManage(_ deck: Deck) -> Bool { false }
    var supportsDeckReordering: Bool { false }
    var supportsDeckFileTransfer: Bool { false }
    func deleteDeck(id: Int) async throws { throw LocalStudyError.deckNotFound }
}
