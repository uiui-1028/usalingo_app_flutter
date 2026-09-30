import SwiftUI

/// 単語一覧の上に1枚だけ重ねる赤シート。一覧のスクロールとは独立していて、答えを出しても動かない。
/// 右半分を覆う不透明な板で、つまみは連続値で動き、空レコードも同じ量だけ動く。
/// 紙の赤シートのように、隠す行より少し下・区切り線より少し左へずらして重ねる。
struct RedSheetLayer: View {
    /// 隠す行の上端から下げる量。
    static let topOffset: CGFloat = 3
    /// 列の区切り線から左へはみ出す量。
    static let leadingOverlap: CGFloat = 5
    private static let cornerRadius: CGFloat = 12

    @Binding var topRatio: CGFloat
    let availableHeight: CGFloat
    let minimumTopRatio: CGFloat
    let maximumTopRatio: CGFloat
    @State private var dragStartTop: CGFloat?

    private var restingTop: CGFloat {
        RedSheetPosition.top(
            availableHeight: availableHeight,
            ratio: RedSheetPosition.clampedRatio(topRatio, minimum: minimumTopRatio, maximum: maximumTopRatio)
        )
    }

    var body: some View {
        ZStack(alignment: .top) {
            // 右と下は画面端まで続くので、見える左上だけを丸める。
            // 答えの文字は行の内側に余白があるので、角丸やずらした分から見えることはない。
            UnevenRoundedRectangle(topLeadingRadius: Self.cornerRadius, style: .continuous)
                .fill(Color(red: 1, green: 0.18, blue: 0.23))
                .padding(.top, restingTop + Self.topOffset)
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            Capsule()
                .fill(.white)
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .named("wordListViewport"))
                        .onChanged { value in
                            if dragStartTop == nil { dragStartTop = restingTop }
                            guard let dragStartTop else { return }
                            let top = dragStartTop + value.translation.height
                            topRatio = RedSheetPosition.clampedRatio(
                                top / max(1, availableHeight),
                                minimum: minimumTopRatio,
                                maximum: maximumTopRatio
                            )
                        }
                        .onEnded { _ in
                            dragStartTop = nil
                        }
                )
                .onTapGesture { }
                .accessibilityLabel("赤シートの高さ")
                .accessibilityValue("画面下から\(Int(((1 - topRatio) * 100).rounded()))パーセント")
                .accessibilityHint("上下にドラッグして滑らかに調整します")
                .accessibilityAdjustableAction { direction in
                    switch direction {
                    case .increment:
                        topRatio = RedSheetPosition.clampedRatio(topRatio - 0.01, minimum: minimumTopRatio, maximum: maximumTopRatio)
                    case .decrement:
                        topRatio = RedSheetPosition.clampedRatio(topRatio + 0.01, minimum: minimumTopRatio, maximum: maximumTopRatio)
                    @unknown default: break
                    }
                }
                .offset(y: restingTop + Self.topOffset)
                .backSwipeProtectedRegion()
        }
        .clipped()
    }
}

enum RedSheetPosition {
    static func top(availableHeight: CGFloat, ratio: CGFloat) -> CGFloat {
        max(0, availableHeight) * ratio
    }

    static func clampedRatio(_ ratio: CGFloat, minimum: CGFloat, maximum: CGFloat) -> CGFloat {
        min(maximum, max(minimum, ratio))
    }
}
