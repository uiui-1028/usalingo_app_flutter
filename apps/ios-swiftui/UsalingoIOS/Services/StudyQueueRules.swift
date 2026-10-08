import Foundation

/// 出題キューの上限。オンライン（`StudyService`）と端末（`LocalStudyDataSource`）で
/// 必ず同じ値を使うため、定義はここ1か所だけに置く。
enum StudyQueueLimit {
    // ponytail: 一時的に実質無制限。元は review 20 / new 10 / futureReview 20 / weak 20。
    static let review = 9999
    static let new = 9999
    static let futureReview = 9999
    static let weak = 9999
}

/// 復習期限の判定と出題順。保存先がサーバでも端末でも同じ順番になるよう、
/// 判定の実装をここへ集める。
enum StudyQueueRules {
    /// Supabase と端末JSONの両方で使う ISO8601 の読み取り。小数秒あり・なしのどちらも受ける。
    static func parseDate(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        if let date = formatter.date(from: value) {
            return date
        }
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: value)
    }

    static func nextReviewDate(for card: WordCard) -> Date? {
        guard let value = card.learning?.nextReviewDate else { return nil }
        return parseDate(value)
    }

    /// 期限は日付で判定する。期限の時刻に関係なく、その日の0時から出題する。
    static func isDue(_ dueDate: Date, now: Date) -> Bool {
        dueDate < startOfTomorrow(now)
    }

    static func isDue(_ value: String, now: Date) -> Bool {
        parseDate(value).map { isDue($0, now: now) } ?? false
    }

    static func isDue(_ card: WordCard, now: Date) -> Bool {
        card.learning.map { isDue($0.nextReviewDate, now: now) } ?? false
    }

    /// 端末の日付で翌日の0時。サーバへの期限問い合わせもこの境界を使う。
    static func startOfTomorrow(_ now: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)) ?? now
    }

    static func sortByNextReviewDateThenId(_ left: WordCard, _ right: WordCard) -> Bool {
        let leftDate = nextReviewDate(for: left)
        let rightDate = nextReviewDate(for: right)
        switch (leftDate, rightDate) {
        case let (leftDate?, rightDate?):
            if leftDate != rightDate { return leftDate < rightDate }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        case (nil, nil):
            break
        }
        return left.id < right.id
    }

    /// 今日の分。期限が今日までの復習 → 新規、の順に上限まで詰める。
    /// 解いたカードは正誤どちらでも期限が明日以降になるので、その日のうちは二度と入らない。
    static func limitedStudyQueue(_ cards: [WordCard], now: Date = Date()) -> [WordCard] {
        let dueCards = cards
            .filter { isDue($0, now: now) }
            .sorted(by: sortByNextReviewDateThenId)
            .prefix(StudyQueueLimit.review)
        let newCards = cards
            .filter { $0.learning == nil }
            .sorted { $0.id < $1.id }
            .prefix(StudyQueueLimit.new)
        return Array(dueCards) + Array(newCards)
    }

    /// ラジオ用。今日の分に絞らず、今日の分のあとへ期限前の復習も続ける。
    static func allCardsQueue(_ cards: [WordCard], now: Date = Date()) -> [WordCard] {
        let futureReviewCards = cards
            .filter { card in
                guard card.learning != nil else { return false }
                return !isDue(card, now: now)
            }
            .sorted(by: sortByNextReviewDateThenId)
            .prefix(StudyQueueLimit.futureReview)

        return limitedStudyQueue(cards, now: now) + Array(futureReviewCards)
    }

    /// 連続学習日数。今日から1日ずつさかのぼり、記録が途切れるまで数える。
    static func currentStreak(from dates: [Date], now: Date = Date()) -> Int {
        let calendar = Calendar.current
        let reviewedDays = Set(dates.map { calendar.startOfDay(for: $0) })
        var day = calendar.startOfDay(for: now)
        var streak = 0
        while reviewedDays.contains(day) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }
}
