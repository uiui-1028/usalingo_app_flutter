import Foundation

@MainActor
final class WordListViewModel: ObservableObject {
    @Published var words: [WordCard]
    @Published var searchText = ""
    @Published var selectedTagFilter: String?
    @Published var selectedStatusFilter: WordStatusFilter = .all
    @Published var selectedDueFilter: WordDueFilter = .all
    @Published var selectedSort: WordSortOption = .registered
    @Published var selectedDisplayMode: WordListDisplayMode
    @Published var message = ""
    @Published var isLoading = false
    /// バナーに並べる所持デッキ。
    @Published private(set) var decks: [Deck] = []
    /// デッキ一覧の取得失敗。単語側の `message` とは混ぜない。
    @Published private(set) var deckMessage = ""

    /// いま単語を表示しているデッキ。nil なら全デッキの単語リスト。
    @Published private(set) var deck: Deck?
    private let previewWords: [WordCard]?
    private let hasSpecifiedDeck: Bool

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list
    ) {
        self.deck = deck
        hasSpecifiedDeck = deck != nil
        self.previewWords = previewWords
        words = previewWords ?? []
        selectedDisplayMode = displayMode
    }

    var availableTags: [String] {
        Array(Set(words.flatMap(\.tags))).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    var filteredWords: [WordCard] {
        let tagFilteredWords: [WordCard]
        if let selectedTagFilter {
            tagFilteredWords = words.filter { $0.tags.contains(selectedTagFilter) }
        } else {
            tagFilteredWords = words
        }

        let statusFilteredWords = tagFilteredWords.filter { selectedStatusFilter.matches($0) }
        let dueFilteredWords = statusFilteredWords.filter { selectedDueFilter.matches($0) }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return selectedSort.sort(dueFilteredWords) }

        let searchedWords = dueFilteredWords.filter { word in
            word.text.lowercased().contains(query)
                || word.meaning.lowercased().contains(query)
                || (word.sentenceEnglish?.lowercased().contains(query) ?? false)
                || (word.sentenceJapanese?.lowercased().contains(query) ?? false)
                || word.tags.contains { $0.lowercased().contains(query) }
        }
        return selectedSort.sort(searchedWords)
    }

    func load(dataSource: any StudyDataSource) async {
        guard previewWords == nil else { return }
        let requestedDeckID = deck?.id
        isLoading = true
        // 後から始めた取得がまだ走っているなら、スピナーはそちらに任せる。
        defer { if deck?.id == requestedDeckID { isLoading = false } }

        do {
            let loaded: [WordCard]
            if let requestedDeckID {
                loaded = try await dataSource.fetchCards(deckId: requestedDeckID)
            } else {
                loaded = try await dataSource.fetchWordList()
            }
            // 取得中に別のデッキへ送られていたら、古い結果で上書きしない。
            guard deck?.id == requestedDeckID else { return }
            words = loaded
            clearMissingTagFilter()
            message = ""
        } catch {
            guard deck?.id == requestedDeckID else { return }
            message = UserFacingError.message(for: error)
        }
    }

    /// 入口で指定されたデッキを読み、指定がない入口だけ記憶中・先頭のデッキを使う。
    func loadDecks(dataSource: any StudyDataSource, preferredDeckID: Int?) async {
        guard previewWords == nil else { return }
        if hasSpecifiedDeck {
            await load(dataSource: dataSource)
            return
        }
        do {
            decks = try await dataSource.fetchDecks()
            deckMessage = ""
        } catch {
            decks = []
            words = []
            deckMessage = "デッキを読み込めませんでした。"
            return
        }
        guard let selected = decks.first(where: { $0.id == preferredDeckID }) ?? decks.first else {
            deck = nil
            words = []
            message = ""
            return
        }
        deck = selected
        await load(dataSource: dataSource)
    }

    /// バナーで選んだデッキへ単語を差し替える。
    /// タグはデッキごとに違うので解除し、並べ替えと表示モードは好みとして残す。
    func selectDeck(_ newDeck: Deck, dataSource: any StudyDataSource) async {
        guard previewWords == nil, newDeck.id != deck?.id else { return }
        deck = newDeck
        // 前のデッキの単語を残すと、取得に失敗したときに別デッキの中身に見える。
        words = []
        selectedTagFilter = nil
        await load(dataSource: dataSource)
    }

    @discardableResult
    func replaceWord(_ savedWord: WordCard) -> WordCard {
        if let index = words.firstIndex(where: { $0.id == savedWord.id }) {
            words[index] = savedWord
        }
        clearMissingTagFilter()
        return savedWord
    }

    func clearMissingTagFilter() {
        if let selectedTagFilter, !availableTags.contains(selectedTagFilter) {
            self.selectedTagFilter = nil
        }
    }

    func removeWord(id: Int) {
        words.removeAll { $0.id == id }
        clearMissingTagFilter()
    }
}

/// チェック開始時の順序を保ち、表示上の判定と保存の完了を分ける。
@MainActor
final class RedSheetCheckModel: ObservableObject {
    @Published private(set) var words: [WordCard] = []
    @Published private(set) var index = 0
    @Published var isAnswerVisible = false
    @Published private(set) var answers: [Int: Bool] = [:]
    @Published private(set) var pendingCount = 0
    @Published private(set) var isSaving = false
    @Published private(set) var isUndoing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var canUndo = false
    @Published private(set) var hasSession = false
    @Published private(set) var removedIDs: Set<Int> = []
    @Published var sheetTopRatio: CGFloat = 0.55
    @Published var coveredColumns = 1 { didSet { persistCheckpoint() } }
    @Published private(set) var resumeErrorMessage: String?

    private var queue = StudyAnswerQueue()
    private var savedAnswers: [Int: SavedAnswer] = [:]
    private var source: (any StudyDataSource)?
    private var didSave: ((WordCard) -> Void)?
    private var saveTask: Task<Void, Never>?
    private var checkpointStore: RedSheetCheckpointStore?

    var current: WordCard? { words.indices.contains(index) ? words[index] : nil }
    var isStarted: Bool { hasSession }
    var isComplete: Bool { isStarted && current == nil }
    var canLeave: Bool { pendingCount == 0 && !isUndoing }

    func start(words: [WordCard], source: any StudyDataSource, didSave: @escaping (WordCard) -> Void) {
        guard canLeave, !words.isEmpty, words.allSatisfy({ $0.cardId != nil }) else { return }
        self.words = words
        hasSession = true
        self.source = source
        self.didSave = didSave
        index = 0
        removedIDs = []
        answers = [:]
        savedAnswers = [:]
        queue.reset()
        isAnswerVisible = false
        canUndo = false
        errorMessage = nil
        advancePastInactiveWords()
        persistCheckpoint()
    }

    /// 絞り込みを変えても前回の対象・順番を保ち、答えを隠して再開する。
    func resume(words initialWords: [WordCard], availableWords: [WordCard], source: any StudyDataSource,
                store: RedSheetCheckpointStore?, didSave: @escaping (WordCard) -> Void) {
        guard canLeave else { return }
        if checkpointStore?.key != store?.key {
            reset()
            checkpointStore = store
        }
        self.source = source
        self.didSave = didSave
        if !isStarted, let snapshot = store?.load() {
            hasSession = true
            let available = Dictionary(availableWords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            words = snapshot.wordIDs.compactMap { available[$0] }
            let positions = Dictionary(words.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
            index = snapshot.wordIDs.prefix(snapshot.index).filter { positions[$0] != nil }.count
            answers = snapshot.answers.filter { positions[$0.key] != nil }
            removedIDs = snapshot.removedIDs.intersection(Set(positions.keys))
            savedAnswers = Dictionary(snapshot.savedAnswers.compactMap { oldIndex, answer in
                positions[snapshot.wordIDs[oldIndex]].map { ($0, answer) }
            }, uniquingKeysWith: { first, _ in first })
            canUndo = snapshot.canUndo
            for pending in snapshot.pending {
                guard let newIndex = positions[pending.card.id] else { continue }
                let attempt = makeSaveAttempt(prepared: pending.prepared)
                queue.enqueue(cardIndex: newIndex, card: pending.card, isCorrect: pending.isCorrect, attempt: attempt)
            }
            pendingCount = queue.pending.count
            // 復元途中に部分的な記録を上書きしない。
            let attached = checkpointStore
            checkpointStore = nil
            sheetTopRatio = snapshot.sheetTopRatio
            coveredColumns = snapshot.coveredColumns
            checkpointStore = attached
        }
        if !isStarted {
            start(words: initialWords, source: source, didSave: didSave)
        } else {
            refreshWords(availableWords)
        }
        isAnswerVisible = false
        persistCheckpoint()
        retry()
    }

    /// 通常リストでの編集・削除も、再開する順番には反映する。
    private func refreshWords(_ availableWords: [WordCard]) {
        let available = Dictionary(availableWords.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        for position in words.indices {
            if let updated = available[words[position].id] { words[position] = updated }
            else { removedIDs.insert(words[position].id) }
        }
        advancePastInactiveWords()
    }

    private func makeSaveAttempt(prepared: SavedAnswer? = nil) -> AnswerSaveAttempt {
        let attempt = AnswerSaveAttempt()
        attempt.prepared = prepared
        attempt.didPrepare = { [weak self] in try self?.writeCheckpoint() }
        return attempt
    }

    func submit(isCorrect: Bool) {
        guard let current, isAnswerVisible, !isUndoing else { return }
        answers[current.id] = isCorrect
        queue.enqueue(cardIndex: index, card: current, isCorrect: isCorrect, attempt: makeSaveAttempt())
        pendingCount = queue.pending.count
        index += 1
        advancePastInactiveWords()
        isAnswerVisible = false
        canUndo = true
        persistCheckpoint()
        // 失敗は次の判定で消さない。再送ボタンで明示的に再開する。
        if errorMessage == nil { retry() }
    }

    func revealAnswer() {
        guard current != nil, !isUndoing else { return }
        isAnswerVisible = true
    }

    func replaceWord(_ word: WordCard) {
        guard let index = words.firstIndex(where: { $0.id == word.id }) else { return }
        words[index] = word
        advancePastInactiveWords()
        persistCheckpoint()
    }

    /// 配列の位置は回答キューが使うので維持し、削除行だけ表示から外す。
    func removeWord(id: Int) {
        removedIDs.insert(id)
        advancePastInactiveWords()
        persistCheckpoint()
    }

    private func advancePastInactiveWords() {
        let previousIndex = index
        while let current, current.isSuspended || removedIDs.contains(current.id) { index += 1 }
        if index != previousIndex { isAnswerVisible = false }
        if let lastAnswered = words[..<min(index, words.count)].last(where: { answers[$0.id] != nil }),
           lastAnswered.isSuspended || removedIDs.contains(lastAnswered.id) { canUndo = false }
    }

    func retry() {
        persistCheckpoint()
        guard let source, !isUndoing, queue.beginDraining() else { return }
        errorMessage = nil
        isSaving = true
        saveTask = Task {
            while let pending = queue.next {
                guard !Task.isCancelled else { return }
                do {
                    let saved = try await source.saveAnswerWithUndo(card: pending.card, isCorrect: pending.isCorrect, attempt: pending.attempt)
                    guard !Task.isCancelled else { return }
                    savedAnswers[pending.cardIndex] = saved
                    didSave?(pending.card.withLearningProgress(saved.progress))
                    queue.completeFirst()
                    pendingCount = queue.pending.count
                    persistCheckpoint()
                } catch {
                    guard !Task.isCancelled else { return }
                    errorMessage = "未保存の判定があります。\(UserFacingError.message(for: error))"
                    break
                }
                // 取り消し要求が来たら、実行中の1件だけを終えて止まる。
                if isUndoing { break }
            }
            queue.endDraining()
            isSaving = false
        }
    }

    func undo() async {
        guard canUndo, !isUndoing, index > 0, let source else { return }
        isUndoing = true
        await saveTask?.value
        guard let previousIndex = words.indices.prefix(index).last(where: {
            answers[words[$0].id] != nil && !words[$0].isSuspended && !removedIDs.contains(words[$0].id)
        }) else { isUndoing = false; return }
        let card = words[previousIndex]
        do {
            // 送信後に応答だけ失われた場合も、送信前の控えから確実に戻す。
            let pending = queue.pending.last.flatMap { $0.cardIndex == previousIndex ? $0 : nil }
            if let saved = savedAnswers[previousIndex] ?? pending?.attempt.prepared, let cardId = card.cardId {
                try await source.restoreLearningProgress(cardId: cardId, previousProgress: saved.previousProgress)
                didSave?(card)
                savedAnswers.removeValue(forKey: previousIndex)
            }
            queue.removeLast(cardIndex: previousIndex)
            answers.removeValue(forKey: card.id)
            index = previousIndex
            isAnswerVisible = false
            canUndo = false
            pendingCount = queue.pending.count
            errorMessage = nil
        } catch {
            errorMessage = "取り消しを保存できませんでした。「戻る」でもう一度お試しください。"
        }
        isUndoing = false
        persistCheckpoint()
        if errorMessage == nil { retry() }
    }

    func reset() {
        guard canLeave else { return }
        words = []
        hasSession = false
        removedIDs = []
        answers = [:]
        index = 0
        canUndo = false
        isAnswerVisible = false
        errorMessage = nil
        savedAnswers = [:]
        source = nil
        didSave = nil
    }

    /// 画面のアカウントが変わる際は、前の棚へ記録を残して参照を切る。
    func detach() {
        // 各変更時に保存済み。退会後に呼ばれても、削除された棚を作り直さない。
        saveTask?.cancel()
        checkpointStore = nil
        queue.reset()
        pendingCount = 0
        isSaving = false
        isUndoing = false
        reset()
        sheetTopRatio = 0.55
        coveredColumns = 1
        resumeErrorMessage = nil
    }

    private func writeCheckpoint() throws {
        guard let checkpointStore, isStarted, !words.isEmpty else { return }
        try checkpointStore.save(RedSheetCheckpoint(
            wordIDs: words.map(\.id), index: index, answers: answers, removedIDs: removedIDs,
            sheetTopRatio: sheetTopRatio, coveredColumns: coveredColumns,
            pending: queue.pending.map {
                RedSheetCheckpoint.Pending(cardIndex: $0.cardIndex, card: $0.card,
                    isCorrect: $0.isCorrect, prepared: $0.attempt.prepared)
            }, savedAnswers: savedAnswers, canUndo: canUndo
        ))
    }

    private func persistCheckpoint() {
        do {
            try writeCheckpoint()
            resumeErrorMessage = nil
        } catch {
            resumeErrorMessage = "再開位置を保存できませんでした。\(UserFacingError.message(for: error))"
        }
    }

    /// フック操作中は表示だけを追従させ、指を離した時に位置を保存する。
    func rememberSheetPosition() {
        persistCheckpoint()
    }
}

/// 再開位置は学習履歴とは別に、端末のアカウント・デッキ単位で保管する。
struct RedSheetCheckpoint: Codable {
    struct Pending: Codable {
        let cardIndex: Int
        let card: WordCard
        let isCorrect: Bool
        let prepared: SavedAnswer?
    }
    let wordIDs: [Int]
    let index: Int
    let answers: [Int: Bool]
    let removedIDs: Set<Int>
    let sheetTopRatio: CGFloat
    let coveredColumns: Int
    let pending: [Pending]
    let savedAnswers: [Int: SavedAnswer]
    let canUndo: Bool

    var isValid: Bool {
        !wordIDs.isEmpty && Set(wordIDs).count == wordIDs.count
            && (0...wordIDs.count).contains(index)
            && sheetTopRatio.isFinite && (0.30...0.80).contains(sheetTopRatio)
            && (1...2).contains(coveredColumns)
            && Set(answers.keys).isSubset(of: Set(wordIDs))
            && savedAnswers.keys.allSatisfy { wordIDs.indices.contains($0) }
            && pending.allSatisfy {
                wordIDs.indices.contains($0.cardIndex) && wordIDs[$0.cardIndex] == $0.card.id
                    && $0.card.cardId != nil && $0.cardIndex < index
                    && ($0.prepared == nil || $0.prepared?.progress.cardId == $0.card.cardId)
            }
    }
}

struct RedSheetCheckpointStore {
    let key: String
    private let accountPrefix: String
    private let defaults: UserDefaults

    init(accountId: String, deckId: Int?, defaults: UserDefaults = .standard) {
        accountPrefix = "words.redSheet.\(accountId)."
        key = accountPrefix + (deckId.map(String.init) ?? "all")
        self.defaults = defaults
    }

    func load() -> RedSheetCheckpoint? {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(RedSheetCheckpoint.self, from: data),
              snapshot.isValid else { return nil }
        return snapshot
    }

    func save(_ snapshot: RedSheetCheckpoint) throws {
        guard snapshot.isValid else { throw CocoaError(.coderInvalidValue) }
        defaults.set(try JSONEncoder().encode(snapshot), forKey: key)
    }

    func removeAll() {
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(accountPrefix) {
            defaults.removeObject(forKey: key)
        }
    }
}
