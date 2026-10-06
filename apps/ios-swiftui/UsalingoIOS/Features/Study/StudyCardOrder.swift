/// カード本体の位置は固定し、未正解のカードの出題順だけを動かす。
struct StudyCardOrder {
    private(set) var remaining: [Int]
    let totalCount: Int

    init(count: Int = 0) {
        totalCount = max(0, count)
        remaining = Array(0..<totalCount)
    }

    var current: Int? { remaining.first }
    var next: Int? { remaining.dropFirst().first }
    var completedCount: Int { totalCount - remaining.count }
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    mutating func answer(isCorrect: Bool) {
        guard !remaining.isEmpty else { return }
        let answered = remaining.removeFirst()
        if !isCorrect { remaining.append(answered) }
    }

    /// 保存済みの直前の回答だけを取り消す。不正解で末尾へ回したカードも元へ戻す。
    mutating func undo(cardIndex: Int, isCorrect: Bool) {
        if !isCorrect { remaining.removeLast() }
        remaining.insert(cardIndex, at: 0)
    }
}
