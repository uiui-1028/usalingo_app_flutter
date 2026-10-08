/// カード本体の位置は固定し、未正解のカードの出題順だけを動かす。
struct StudyCardOrder {
    private(set) var remaining: [Int]
    let totalCount: Int
    /// 不正解で末尾へ回したカード。次に出たときの答えは「やり直し」になる。
    private var missCounts: [Int: Int] = [:]

    init(count: Int = 0) {
        totalCount = max(0, count)
        remaining = Array(0..<totalCount)
    }

    var current: Int? { remaining.first }
    var next: Int? { remaining.dropFirst().first }
    var isRetry: Bool { current.map { missCounts[$0, default: 0] > 0 } ?? false }
    var completedCount: Int { totalCount - remaining.count }
    var progress: Double {
        totalCount == 0 ? 0 : Double(completedCount) / Double(totalCount)
    }

    mutating func answer(isCorrect: Bool) {
        guard !remaining.isEmpty else { return }
        let answered = remaining.removeFirst()
        if !isCorrect {
            remaining.append(answered)
            missCounts[answered, default: 0] += 1
        }
    }

    /// 保存済みの直前の回答だけを取り消す。不正解で末尾へ回したカードも元へ戻す。
    mutating func undo(cardIndex: Int, isCorrect: Bool) {
        if !isCorrect {
            remaining.removeLast()
            missCounts[cardIndex, default: 1] -= 1
        }
        remaining.insert(cardIndex, at: 0)
    }
}
