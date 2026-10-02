import UIKit

enum HapticFeedbackService {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func swipeThresholdCrossed() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    /// カルーセルが枠に吸い付いたときの、ダイヤルのような軽い手ごたえ。
    static func detent() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    /// 組がそろったなど、うまくいったときの知らせ。
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// 組が違ったなど、うまくいかなかったときの知らせ。
    static func failure() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
