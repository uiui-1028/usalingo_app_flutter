import SwiftUI

struct WordLibraryCard: View {
    let word: WordCard

    var body: some View {
        GeometryReader { geometry in
            let width = max(1, geometry.size.width)
            // 詳細カードと同じ350ptの配置を縮め、単語以外の文字は灰色の箱にする。
            StudyCardFace(fill: word.isSuspended ? Color(white: 0.78) : WireColor.surface) {
                StudyCardFront(card: word, content: WordCardContent(card: word), showAnswer: true,
                               placeholderProgress: Double(min(1, max(0, (280 - width) / 80))))
            }
            .frame(width: 350, height: 350 / 0.74)
            .grayscale(word.isSuspended ? 1 : 0)
            .scaleEffect(width / 350)
            .frame(width: width, height: geometry.size.height)
        }
        .aspectRatio(0.74, contentMode: .fit)
        .contentShape(RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous))
        // ponytail: VoiceOverは詳細な読み上げを後日まとめて整え、今は単語と開く操作だけを公開する。
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(word.text)
        .accessibilityHint("単語の詳細を開きます")
    }
}

/// 先頭・末尾の余白を示す飾り。単語や進捗の対象にはせず、操作も受けない。
struct WordLibraryEmptyCard: View {
    var body: some View {
        RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
            .strokeBorder(Color.gray, style: StrokeStyle(lineWidth: WireMetrics.strokeBase, dash: [6, 4]))
            .aspectRatio(0.74, contentMode: .fit)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
            columnText(leftColumn, font: .titleS, color: word.isSuspended ? Color(white: 0.3) : .primary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.vertical, 20)
                .frame(maxHeight: .infinity, alignment: .leading)
                .containerRelativeFrame(.horizontal, count: columnCount, spacing: 0)

            if let middleColumn {
                columnText(middleColumn, font: .body, color: word.isSuspended ? Color(white: 0.3) : .primary)
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

            columnText(rightColumn, font: .body, color: word.isSuspended ? Color(white: 0.3) : Color(red: 0.65, green: 0.09, blue: 0.1))
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
                            .foregroundStyle(
                                checkResult ? WireColor.answerIncorrect : WireColor.surface,
                                checkResult ? WireColor.answerCorrect : WireColor.answerIncorrect
                            )
                            .overlay {
                                Circle().strokeBorder(WireColor.answerIncorrect, lineWidth: 1)
                                    .accessibilityHidden(true)
                            }
                            .padding(.trailing, 10)
                            .accessibilityLabel(checkResult ? "わかる" : "わからない")
                    }
                }
        }
        .frame(minHeight: 80)
        .fixedSize(horizontal: false, vertical: true)
        // チェック中の行だけ、正解色を薄めたピンクにする。
        .background(word.isSuspended ? Color(white: 0.78) : (isCheckTarget ? WireColor.answerCorrect.opacity(0.10) : WireColor.surface))
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
        .fontWeight(word.isSuspended ? .regular : nil)
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
