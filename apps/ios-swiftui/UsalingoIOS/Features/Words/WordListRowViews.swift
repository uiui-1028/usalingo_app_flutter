import SwiftUI

struct WordLibraryCard: View {
    let word: WordCard

    var body: some View {
        VStack(spacing: 0) {
            illustration

            Text(word.text)
                .wireFont(.titleS)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, WireMetrics.spacingS)
                .padding(.vertical, WireMetrics.spacingXS)
        }
        .clipShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(word.text)
        .accessibilityHint("単語の詳細を開きます")
    }

    /// 画像は必ず 3:4 の枠へ収め、はみ出した分は枠の内側で切り落とす。
    /// `Color.clear` で枠の大きさを先に決めてから overlay で敷くことで、
    /// `scaledToFill` の画像がカードの外へ広がらないようにする。
    private var illustration: some View {
        Color.clear
            .aspectRatio(3 / 4, contentMode: .fit)
            .overlay {
                illustrationContent
            }
            .clipped()
    }

    @ViewBuilder
    private var illustrationContent: some View {
        if let url = word.illustrationURL {
            CardImage(
                url: url,
                contentMode: .fill,
                showsLoadingIndicator: true
            ) {
                imagePlaceholder()
            }
        } else {
            imagePlaceholder()
        }
    }

    private func imagePlaceholder() -> some View {
        WireImagePlaceholder(radius: WireMetrics.radiusControl)
    }
}

struct WordRow: View {
    let word: WordCard
    var hidesAnswerFromAccessibility = false
    var checkResult: Bool? = nil
    var reservesCheckResultSpace = false
    var isCheckTarget = false
    var leftColumn: WordListColumn = .word
    /// 3列にしたときだけ入る、左右の間の列。
    var middleColumn: WordListColumn? = nil
    var rightColumn: WordListColumn = .meaning
    /// 赤シートが真ん中の列まで覆っているとき。
    var hidesMiddleFromAccessibility = false

    private var columnCount: Int { middleColumn == nil ? 2 : 3 }

    var body: some View {
        HStack(spacing: 0) {
            columnText(leftColumn, font: .titleS, color: .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 20)
                .frame(maxHeight: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal, count: columnCount, spacing: 0)

            if let middleColumn {
                columnText(middleColumn, font: .body, color: .primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 20)
                    .frame(maxHeight: .infinity, alignment: .leading)
                    .containerRelativeFrame(.horizontal, count: columnCount, spacing: 0)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(WireColor.ink.opacity(0.12)).frame(width: 1)
                    }
                    .accessibilityHidden(hidesMiddleFromAccessibility)
            }

            columnText(rightColumn, font: .body, color: Color(red: 0.65, green: 0.09, blue: 0.1))
                .fixedSize(horizontal: false, vertical: true)
                .padding(.leading, 14)
                .padding(.trailing, reservesCheckResultSpace || checkResult != nil ? 42 : 14)
                .padding(.vertical, 20)
                .frame(maxHeight: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal, count: columnCount, spacing: 0)
                .overlay(alignment: .leading) {
                    Rectangle().fill(WireColor.ink.opacity(0.12)).frame(width: 1)
                }
                .accessibilityHidden(hidesAnswerFromAccessibility)
                .overlay(alignment: .trailing) {
                    if let checkResult {
                        Image(systemName: checkResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.system(size: 25, weight: .semibold))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, checkResult ? Color.black : Color.red)
                            .padding(.trailing, 10)
                            .accessibilityLabel(checkResult ? "わかる" : "わからない")
                    }
                }
        }
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        // 行はすべて白。チェック中の行（答えを隠している／評価待ち）だけ灰色にする。
        .background(isCheckTarget ? WireColor.ink.opacity(0.04) : WireColor.surface)
        .overlay(alignment: .bottom) {
            Rectangle().fill(WireColor.ink.opacity(0.12)).frame(height: 1)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(reservesCheckResultSpace
            ? (isCheckTarget ? "チェック中の単語。タップで答えを表示します" : "単語を順番にチェックします")
            : "単語の詳細を開きます")
    }

    /// データが無い項目は、空欄だと列ずれに見えるので「—」を薄く出す。
    /// 揃え方は項目ごとに決まっていて、左右どちらの列に置いても同じ。
    private func columnText(_ column: WordListColumn, font: WireFont, color: Color) -> some View {
        let value = column.value(of: word)
        return Group {
            if value.isEmpty {
                Text("—").wireFont(font, color: .secondary)
            } else {
                Text(value).wireFont(font, color: color)
            }
        }
        .multilineTextAlignment(column.isCentered ? .center : .leading)
        .frame(maxWidth: .infinity, alignment: column.isCentered ? .center : .leading)
    }
}

struct StatusBadge: View {
    let status: String?

    var body: some View {
        WirePill(title: title, isSelected: status == "mastered", font: .caption)
    }

    private var title: String {
        switch status {
        case "learning":
            "復習中"
        case "mastered":
            "習得済み"
        default:
            "未学習"
        }
    }
}

struct TagChipRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: WireMetrics.spacingXS) {
                ForEach(tags, id: \.self) { tag in
                    WirePill(title: tag, font: .caption)
                }
            }
        }
    }
}

extension View {
    /// 囲いの形の中だけをタップ領域にする。
    ///
    /// `List` の行に `Button` を置くと、行の余白や左右の背景まで反応してしまう。
    /// 背景は戻るスワイプが使う場所なので、そこと取り合いにならないよう
    /// カードの角丸の内側でだけタップを受ける。
    func cardTapTarget(
        radius: CGFloat = WireMetrics.radiusCard,
        action: @escaping () -> Void
    ) -> some View {
        contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .onTapGesture(perform: action)
            .accessibilityAddTraits(.isButton)
    }
}
