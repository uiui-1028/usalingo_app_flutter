import SwiftUI

/// デッキの学習状況を5列のマスで一覧にする。
///
/// 一度でも学習したカードは絵柄で出し、SRS の段階（Lv.1〜5、習得は5）に合わせて
/// 不透明度と彩度を 20% ずつ上げる。まだ学習していないカードは番号だけの空きマスにする。
/// 開き方は、学習タブの長押しメニューと、各学習モードの進み具合のバーの2つ。
struct DeckProgressGridView: View {
    static let columnCount = 5
    private static let spacing: CGFloat = 6

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck
    /// 学習モードから開いたときの出題中のカード。そこまで送って枠で示す。
    var currentCardId: Int?

    @State private var cards: [WordCard] = []
    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var selectedWord: WordCard?
    @State private var headerHeight: CGFloat = 0

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                grid
                    .padding(.horizontal, WireMetrics.screenPadding)
                    .padding(.top, headerHeight + WireMetrics.spacingM)
                    .padding(.bottom, WireMetrics.spacingXL)
            }
            .overlay {
                if isLoading {
                    ProgressView()
                } else if let loadErrorMessage {
                    StudyStatusView(
                        symbol: "wifi.exclamationmark",
                        title: "カードを読み込めませんでした",
                        message: loadErrorMessage,
                        actionTitle: "もう一度試す"
                    ) {
                        Task { await load() }
                    }
                    .padding(WireMetrics.screenPadding)
                }
            }
            // 一覧は浮いたヘッダーの裏を通す。
            .overlay(alignment: .top) {
                header
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { headerHeight = $0 }
            }
            .task {
                await load()
                guard let currentCardId, cards.contains(where: { $0.id == currentCardId }) else { return }
                reader.scrollTo(currentCardId, anchor: .center)
            }
        }
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word, words: cards.filter(\.isStudied)) { savedWord in
                if let index = cards.firstIndex(where: { $0.id == savedWord.id }) {
                    cards[index] = savedWord
                }
            }
        }
    }

    private var header: some View {
        StudyBridgeHeader(backLabel: "戻る", onBack: { dismiss() }) {
            HStack(spacing: WireMetrics.spacingS) {
                Text(deck.deckName)
                    .wireFont(.titleS)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: WireMetrics.spacingS)
                if !isLoading, loadErrorMessage == nil {
                    Text("\(studiedCount)/\(cards.count)")
                        .wireFont(.label)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var studiedCount: Int {
        cards.filter(\.isStudied).count
    }

    private var grid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: Self.columnCount),
            spacing: Self.spacing
        ) {
            ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                cell(card, number: index + 1)
                    .id(card.id)
            }
        }
    }

    private func cell(_ card: WordCard, number: Int) -> some View {
        let shape = RoundedRectangle(cornerRadius: WireMetrics.radiusSmall, style: .continuous)
        return shape
            .fill(WireColor.groupL3)
            .aspectRatio(0.74, contentMode: .fit)
            .overlay {
                if let strength = card.studyStrength {
                    // 一時停止中かどうかは区別しない。
                    WordLibraryCard(word: card.withSuspension(false))
                        .saturation(strength)
                        .opacity(strength)
                        .cardTapTarget { selectedWord = card }
                } else {
                    Text(String(format: "%03d", number))
                        .wireFont(.titleS, color: WireColor.subText)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(WireMetrics.spacingXS)
                        // ponytail: VoiceOverは後日まとめて整える。今は番号だけを読む。
                        .accessibilityLabel("\(number) 未学習")
                }
            }
            .overlay {
                if card.id == currentCardId {
                    shape.strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeHeavy)
                        .padding(-WireMetrics.spacingXS / 2)
                        .accessibilityHidden(true)
                }
            }
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        defer { isLoading = false }
        do {
            cards = try await appState.studyDataSource.fetchCards(deckId: deck.id)
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
    }
}

extension WordCard {
    /// 一度でも学習したカード。
    var isStudied: Bool { learning != nil }

    /// 一覧で絵柄を出す濃さ。未学習は nil、Lv.1〜5 を 0.2〜1.0 に、習得は 1.0 にする。
    var studyStrength: Double? {
        guard let learning else { return nil }
        if learningStatus == "mastered" { return 1 }
        return Double(min(5, max(1, learning.srsLevel))) / 5
    }
}
