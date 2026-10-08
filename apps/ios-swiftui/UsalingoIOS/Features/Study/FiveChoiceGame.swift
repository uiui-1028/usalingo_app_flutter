import Foundation

/// 英→日の5択。選択肢は出題時に一度だけ作り、答え合わせまで同じ並びを保つ。
/// 間違えた問題は1周の最後へ回し、正解するまで出す。
struct FiveChoiceGame {
    struct Question {
        let card: WordCard
        let choices: [WordCard]
        /// この回ですでに間違えた問題。保存では学習記録を進めない。
        let isRetry: Bool
        var correctIndex: Int { choices.firstIndex { $0.id == card.id }! }
    }

    private var cards: [WordCard]
    /// 重複を除いた出題数。やり直しで `cards` が伸びても進み具合の分母は変えない。
    let questionCount: Int
    private var missedCardIds: Set<Int> = []
    private let candidates: [Candidate]
    private let shufflesOrder: Bool
    private var nextCardIndex = 0
    private(set) var question: Question?
    private(set) var selectedIndex: Int?
    /// 選ぶ前に答えだけを見た状態。記録はせず、自己評価（`grade`）を待つ。
    private(set) var isPeeking = false
    private(set) var answeredCount = 0
    private(set) var correctCount = 0
    private(set) var skippedCount = 0

    var isFinished: Bool { question == nil }
    var isRevealed: Bool { selectedIndex != nil || isPeeking }
    /// 正解した問題の割合。間違えた問題は進めない。
    var progress: Double { questionCount == 0 ? 0 : Double(correctCount) / Double(questionCount) }

    init(cards: [WordCard], candidates: [WordCard], shufflesOrder: Bool = true) {
        var seen = Set<Int>()
        let uniqueCards = cards.filter { seen.insert($0.id).inserted }
        self.cards = shufflesOrder ? uniqueCards.shuffled() : uniqueCards
        questionCount = uniqueCards.count
        self.shufflesOrder = shufflesOrder
        self.candidates = candidates.map(Candidate.init).filter(\.isUsable)
        prepareQuestion()
    }

    /// 公開されている全単語ではなく、学習タブに追加済みのデッキだけを読む。
    /// 出題は今日の分（期限が来た復習と新規）だけ。選択肢には今日解いた単語も使う。
    static func load(deckId: Int, source: any StudyDataSource) async throws -> FiveChoiceGame {
        let decks = try await source.fetchDecks()
        let isFolder = LocalStudyDataSource.isFolderDeckId(deckId)
        guard isFolder || decks.contains(where: { $0.id == deckId }) else { throw LocalStudyError.deckNotFound }
        var cards: [WordCard] = []
        var candidates: [WordCard] = []
        for deck in decks {
            try Task.checkCancellation()
            let deckCards = try await source.fetchCards(deckId: deck.id).filter { !$0.isSuspended }
            if deck.id == deckId { cards = deckCards }
            candidates.append(contentsOf: deckCards)
        }
        // フォルダは一覧に無いので、中のデッキをまとめたカードを直接読む。
        if isFolder {
            cards = try await source.fetchCards(deckId: deckId).filter { !$0.isSuspended }
        }
        try Task.checkCancellation()
        return FiveChoiceGame(cards: StudyQueueRules.limitedStudyQueue(cards), candidates: candidates)
    }

    /// 1問につき最初の回答だけを返す。無効な番号や連打では学習記録を増やさない。
    mutating func answer(at index: Int) -> Bool? {
        guard let question, !isRevealed, question.choices.indices.contains(index) else { return nil }
        selectedIndex = index
        let isCorrect = index == question.correctIndex
        record(isCorrect: isCorrect, card: question.card)
        return isCorrect
    }

    /// 選ばずに答えを見る。学習記録はまだ増やさない。
    mutating func peek() {
        guard question != nil, !isRevealed else { return }
        isPeeking = true
    }

    /// 答えを見た後の自己評価。記録して、そのまま次の問題へ進む。
    mutating func grade(isCorrect: Bool) -> Bool {
        guard let question, isPeeking else { return false }
        record(isCorrect: isCorrect, card: question.card)
        isPeeking = false
        prepareQuestion()
        return true
    }

    /// 選んで答え合わせした問題だけを進める。見ただけの問題は自己評価を待つ。
    mutating func advance() {
        guard selectedIndex != nil else { return }
        selectedIndex = nil
        prepareQuestion()
    }

    private mutating func record(isCorrect: Bool, card: WordCard) {
        answeredCount += 1
        if isCorrect {
            correctCount += 1
        } else {
            missedCardIds.insert(card.id)
            cards.append(card)
        }
    }

    private mutating func prepareQuestion() {
        question = nil
        while nextCardIndex < cards.count {
            let card = cards[nextCardIndex]
            nextCardIndex += 1
            let correct = Candidate(card: card)
            guard correct.isUsable else {
                skippedCount += 1
                continue
            }

            var picked = [correct]
            let pool = shufflesOrder ? candidates.shuffled() : candidates
            for candidate in pool {
                guard !candidate.conflicts(with: correct),
                      !picked.contains(where: {
                          $0.card.id == candidate.card.id || $0.card.wordId == candidate.card.wordId
                              || $0.word == candidate.word || $0.meanings == candidate.meanings
                      }) else { continue }
                picked.append(candidate)
                if picked.count == 5 { break }
            }
            guard picked.count == 5 else {
                skippedCount += 1
                continue
            }
            let choices = picked.map(\.card)
            question = Question(
                card: card,
                choices: shufflesOrder ? choices.shuffled() : choices,
                isRetry: missedCardIds.contains(card.id)
            )
            return
        }
    }

    private struct Candidate {
        let card: WordCard
        let word: String
        let meanings: Set<String>
        let synonymWords: Set<String>
        let synonymMeanings: Set<String>

        var isUsable: Bool { !word.isEmpty && !meanings.isEmpty }

        init(card: WordCard) {
            self.card = card
            word = Self.normalized(card.text)
            meanings = Self.meaningKeys(card.meaning)
            synonymWords = Set(card.synonyms.map { Self.normalized($0.word) }.filter { !$0.isEmpty })
            synonymMeanings = card.synonyms.reduce(into: Set<String>()) {
                $0.formUnion(Self.meaningKeys($1.meaning))
            }
        }

        func conflicts(with other: Candidate) -> Bool {
            // ponytail: 表現の異なる同義語の完全判定はしない。必要なら確認済み候補データを追加する。
            card.id == other.card.id || card.wordId == other.card.wordId || word == other.word
                || !meanings.isDisjoint(with: other.meanings)
                || synonymWords.contains(other.word) || other.synonymWords.contains(word)
                || !synonymMeanings.isDisjoint(with: other.meanings)
                || !other.synonymMeanings.isDisjoint(with: meanings)
        }

        private static func normalized(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
                .components(separatedBy: .whitespacesAndNewlines).joined()
        }

        private static func meaningKeys(_ text: String) -> Set<String> {
            Set(text.components(separatedBy: CharacterSet(charactersIn: "／/、,，;；\n"))
                .map(normalized).filter { !$0.isEmpty })
        }
    }
}
