import SwiftUI
import UIKit

struct StudySessionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var designSettings: DesignSettings
    let deck: Deck
    let studyMode: StudyMode

    @State private var cards: [WordCard] = []
    @State private var cardOrder = StudyCardOrder()
    @State private var presentationID = UUID()
    @State private var isLoading = false
    @State private var loadErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var dragOffset = CGSize.zero
    @State private var isTouchingCard = false
    /// 今回のタッチで回答を出したか。指を離したときのタップで裏返さないために使う。
    @State private var didRevealOnTouch = false
    @State private var hasCrossedCommitThreshold = false
    @State private var showAnswer = false
    @State private var isFlipped = false
    /// ドラッグを横（カード送り）と縦（裏面のスクロール）のどちらに割り当てたか。
    @State private var dragAxis: DragAxis?
    @State private var answerQueue = StudyAnswerQueue()
    @State private var flyawayCards: [FlyawayCard] = []
    @State private var isUndoingAnswer = false
    @State private var editingWord: WordCard?
    @State private var taggingWord: WordCard?
    @State private var sessionAnswers: [Bool] = []
    @State private var sessionProgresses: [LearningProgress] = []
    @State private var answerHistory: [AnswerCheckpoint] = []
    @StateObject private var audioPlaybackService = AudioPlaybackService()

    init(deck: Deck, studyMode: StudyMode = .all) {
        self.deck = deck
        self.studyMode = studyMode
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isLoading, loadErrorMessage == nil, !cards.isEmpty {
                StudyBridgeHeader(progress: cardOrder.progress) { dismiss() }
                    .zIndex(1)
            }

            ZStack {
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
                } else if cards.isEmpty {
                    StudyStatusView(
                        symbol: "rectangle.stack.badge.minus",
                        title: emptyMessage,
                        message: "別の学習モードを選ぶか、デッキに戻ってください。",
                        actionTitle: "デッキに戻る"
                    ) { dismiss() }
                } else if index < cards.count {
                    cardStack
                } else {
                    StudyCompletionView(
                        correctCount: sessionAnswers.filter { $0 }.count,
                        incorrectCount: sessionAnswers.filter { !$0 }.count,
                        studiedCount: sessionAnswers.count,
                        accuracyText: accuracyText,
                        weakCount: weakCount
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            saveFailureBanner
            actionBar
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task(id: presentationID) {
            playCurrentCardAudioSequence()
        }
        .onChange(of: isFlipped) { _, isFlipped in
            if isFlipped {
                audioPlaybackService.stop()
            }
        }
        .onDisappear {
            audioPlaybackService.stop()
            CardImageCache.stopPrefetching()
        }
        .sheet(item: $editingWord) { word in
            WordEditSheet(word: word) { savedWord in
                if let currentIndex = cards.firstIndex(where: { $0.id == savedWord.id }) {
                    cards[currentIndex] = savedWord
                }
            }
                .presentationDetents([.large])
        }
        .sheet(item: $taggingWord) { word in
            TagSheet(word: word) { savedWord in
                if let currentIndex = cards.firstIndex(where: { $0.id == savedWord.id }) {
                    cards[currentIndex] = savedWord
                }
            }
                .presentationDetents([.medium])
        }
        .task { await load() }
    }

    /// 束の中のカードはすべて同じ寸法・同じ位置に重ねる。順位による拡大縮小も位置差も
    /// つけないので、トップが抜けても次のカードは動かない。交代を待つアニメーションが
    /// 無く、現れた瞬間から捌ける。
    private var cardStack: some View {
        GeometryReader { proxy in
            let width = max(0, min(350, proxy.size.width, proxy.size.height * 0.575))

            ZStack {
                // 戻る途中のカードを中央の控えにも描くと、同じ1枚が二重に見えてしまう。
                if let nextIndex = cardOrder.next,
                   !flyawayCards.contains(where: { $0.card.id == cards[nextIndex].id }) {
                    StudyCardView(card: cards[nextIndex], showAnswer: false)
                        .allowsHitTesting(false)
                        // ponytail: 控えは読み上げ対象外。VoiceOverの詳細調整は後日の一括対応。
                        .accessibilityHidden(true)
                        .zIndex(0)
                }

                StudyCardView(card: cards[index], showAnswer: showAnswer, isFlipped: isFlipped)
                    .id(presentationID)
                    .opacity(isWaitingForRepeatedCard ? 0 : 1)
                    .allowsHitTesting(!isUndoingAnswer && !isWaitingForRepeatedCard)
                    .swipeAnswerTint(horizontalOffset: dragOffset.width)
                    .zIndex(1)
                    .backSwipeProtectedRegion()
                    // 左は参考の translate(...) rotate(...) と同じ順。移動量まで回転させない。
                    .rotationEffect(.degrees(Double(min(dragOffset.width, 0) / 30)))
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(max(dragOffset.width, 0) / 24)))
                    // 裏面の ScrollView に横方向のドラッグを食われないよう、同時認識にする。
                    // どちらの操作かは動き出しの向きで決め、決めた後は最後まで変えない。
                    // 指が触れた瞬間に回答を出し、そのまま確定ラインまで滑らせれば、
                    // 1回のスワイプで回答まで済ませられる。
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                if !isTouchingCard {
                                    isTouchingCard = true
                                    didRevealOnTouch = !showAnswer
                                    if !showAnswer {
                                        HapticFeedbackService.swipeThresholdCrossed()
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            showAnswer = true
                                        }
                                    }
                                }

                                if dragAxis == nil {
                                    dragAxis = DragAxis(translation: value.translation)
                                }

                                guard dragAxis == .horizontal else { return }
                                dragOffset = value.translation
                                let reachedCommit = abs(value.translation.width) > SwipeThreshold.commit
                                if reachedCommit && !hasCrossedCommitThreshold {
                                    HapticFeedbackService.swipeThresholdCrossed()
                                }
                                hasCrossedCommitThreshold = reachedCommit
                            }
                            .onEnded { value in
                                let axis = dragAxis
                                dragAxis = nil
                                isTouchingCard = false
                                hasCrossedCommitThreshold = false
                                guard axis == .horizontal else { return }
                                if value.translation.width > SwipeThreshold.commit {
                                    swipe(isCorrect: true)
                                } else if value.translation.width < -SwipeThreshold.commit {
                                    swipe(isCorrect: false, exitDistance: max(500, proxy.size.width))
                                } else {
                                    // タッチで出した回答は、ここで隠し直さない。
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.78)) {
                                        dragOffset = .zero
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        // タッチで回答を出した直後のタップは、表示だけで止める。
                        if didRevealOnTouch {
                            didRevealOnTouch = false
                        } else {
                            advanceCardFace()
                        }
                    }

                // 見送ったカードは独立した層で飛ばす。トップカードの入れ替えはこの演出を
                // 待たないので、飛んでいる最中でも次のカードをスワイプできる。
                ForEach(flyawayCards) { item in
                    FlyawayCardView(item: item) { finished in
                        flyawayCards.removeAll { $0.id == finished.id }
                    }
                }
            }
            .frame(width: width, height: width / 0.575)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 18)
        // カードの影がアクションバーや進捗バーにかからないよう、上下に広めの余白を取る。
        .padding(.vertical, WireMetrics.spacingXL)
        // カードの外の余白は、画面の中央より右のタップを正解、左を不正解にする（Anki式）。
        // カードより後ろに敷くので、カード上のタップとスワイプはカードが受け取る。
        // 戻る操作の保護領域にはしないので、余白から始めた戻るスワイプはそのまま効く。
        .background {
            GeometryReader { zone in
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        answerByMarginTap(
                            isCorrect: location.x >= zone.size.width / 2,
                            exitDistance: max(500, zone.size.width)
                        )
                    }
            }
            // ponytail: 余白タップは補助操作。VoiceOverの詳細対応は後日の一括対応。
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        if !isLoading, index < cards.count {
            // 48ptの押せる大きさを保ち、狭い画面ではボタン間の余白だけ縮める。
            ViewThatFits(in: .horizontal) {
                toolbar(spacing: WireMetrics.spacingS)
                toolbar(spacing: WireMetrics.spacingXS)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.top, WireMetrics.spacingXS)
            .padding(.bottom, WireMetrics.spacingXL)
            .backSwipeProtectedRegion()
        }
    }

    private func toolbar(spacing: CGFloat) -> some View {
        HStack(spacing: spacing) {
            toolbarButton("tag", label: "タグ", action: tagCurrentCard)
            audioButton(
                urls: [currentCard?.wordAudioURL, currentCard?.audioURL],
                symbol: "speaker.wave.2",
                label: "単語と例文の音声を再生"
            )
            audioButton(
                urls: [currentCard?.audioURL],
                symbol: "text.bubble",
                label: "例文の音声を再生"
            )
            toolbarButton(
                "arrow.uturn.backward",
                label: "ひとつ戻す",
                isDisabled: answerHistory.isEmpty || !answerQueue.isEmpty || isUndoingAnswer,
                action: undo
            )
            toolbarButton("square.and.pencil", label: "単語を編集", action: editCurrentCard)
        }
        .wordListBarChrome()
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage, index < cards.count || !answerQueue.isEmpty {
            // 色相を使わずに異常を示す（破線 + 文言）。
            VStack(spacing: WireMetrics.spacingS) {
                Text("回答を保存できませんでした")
                    .wireFont(.label)
                Text(saveErrorMessage)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                Button("同じ回答をもう一度保存") {
                    retryAnswer()
                }
                .buttonStyle(.wireSecondary)
                .disabled(answerQueue.isDraining || isUndoingAnswer)
            }
            .frame(maxWidth: .infinity)
            .padding(WireMetrics.spacingL)
            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil, dashed: true)
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private func toolbarButton(
        _ symbol: String,
        label: String,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            WordListActionBarIcon(symbol: symbol, isActive: false)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .accessibilityLabel(label)
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        do {
            cards = try await appState.studyDataSource.fetchStudyQueue(deckId: deck.id, mode: studyMode)
            audioPlaybackService.stop()
            cardOrder = StudyCardOrder(count: cards.count)
            presentationID = UUID()
            sessionAnswers = []
            sessionProgresses = []
            answerHistory = []
            answerQueue.reset()
            flyawayCards = []
            saveErrorMessage = nil
            prefetchUpcomingMedia()
        } catch {
            cards = []
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }

    private var emptyMessage: String {
        switch studyMode {
        case .newOnly:
            return "新規カードはありません。"
        case .reviewOnly:
            return "復習期限のカードはありません。"
        case .all:
            return "今日の学習は完了です。"
        case .weakOnly:
            return "苦手カードはまだありません。"
        }
    }

    private func drainAnswerQueue() {
        drainStudyAnswerQueue($answerQueue, appState: appState, saveErrorMessage: $saveErrorMessage) { pending, savedAnswer in
            if pending.cardIndex < cards.count {
                cards[pending.cardIndex] = pending.card
                    .withLearningProgress(savedAnswer.progress)
            }
            sessionAnswers.append(pending.isCorrect)
            sessionProgresses.append(savedAnswer.progress)
            answerHistory.append(
                AnswerCheckpoint(
                    cardIndex: pending.cardIndex,
                    originalCard: pending.card,
                    previousProgress: savedAnswer.previousProgress,
                    isCorrect: pending.isCorrect
                )
            )
        }
    }

    /// カードの見送りと保存を切り離す。行列へ積んだらすぐ次のカードへ進むので、
    /// 飛ばす演出や通信の完了待ちでスワイプが塞がることはない。
    private func submitAnswer(isCorrect: Bool, exitDistance: CGFloat) {
        guard index < cards.count, !isUndoingAnswer else { return }
        saveErrorMessage = nil

        let answeredCard = cards[index]
        let nextPresentationID = UUID()
        let target: CGFloat = isCorrect ? 700 : -exitDistance
        flyawayCards.append(
            FlyawayCard(
                card: answeredCard,
                showAnswer: showAnswer,
                isFlipped: isFlipped,
                start: dragOffset,
                end: CGSize(width: target, height: isCorrect ? dragOffset.height : 0),
                isCorrect: isCorrect,
                repeatedPresentationID: !isCorrect && cardOrder.remaining.count == 1 ? nextPresentationID : nil
            )
        )
        answerQueue.enqueue(
            cardIndex: index,
            card: answeredCard,
            isCorrect: isCorrect,
            attempt: AnswerSaveAttempt(isRetry: cardOrder.isRetry)
        )

        audioPlaybackService.stop()
        cardOrder.answer(isCorrect: isCorrect)
        presentationID = nextPresentationID
        // 素早く一巡したら、再出題されたカードと古い演出を二重に見せない。
        flyawayCards.removeAll {
            $0.card.id == currentCard?.id && $0.repeatedPresentationID != presentationID
        }
        showAnswer = false
        isFlipped = false
        dragOffset = .zero
        prefetchUpcomingMedia()

        drainAnswerQueue()
    }

    /// タップ1回で1段ずつ進める。回答前→回答表示→裏、裏からは回答表示の表へ戻す。
    /// 回答前には戻さない。
    private func advanceCardFace() {
        HapticFeedbackService.tap()
        withAnimation(.easeInOut(duration: 0.32)) {
            if !showAnswer {
                showAnswer = true
            } else {
                isFlipped.toggle()
            }
        }
    }

    /// 余白のタップで評価する。回答前の1回目は回答を出すだけにし、見ずに評価させない。
    /// カードを触っている最中のタップは、離したときのスワイプと二重に評価しないよう無視する。
    private func answerByMarginTap(isCorrect: Bool, exitDistance: CGFloat) {
        guard index < cards.count,
              !isTouchingCard,
              !isUndoingAnswer,
              !isWaitingForRepeatedCard else { return }
        guard showAnswer else {
            advanceCardFace()
            return
        }
        HapticFeedbackService.swipeThresholdCrossed()
        submitAnswer(isCorrect: isCorrect, exitDistance: exitDistance)
    }

    private func retryAnswer() {
        saveErrorMessage = nil
        drainAnswerQueue()
    }

    private func swipe(isCorrect: Bool, exitDistance: CGFloat = 700) {
        submitAnswer(isCorrect: isCorrect, exitDistance: exitDistance)
    }

    private func undo() {
        guard let checkpoint = answerHistory.last,
              answerQueue.isEmpty,
              !isUndoingAnswer else { return }
        Task { await restore(checkpoint) }
    }

    private func restore(_ checkpoint: AnswerCheckpoint) async {
        isUndoingAnswer = true
        defer { isUndoingAnswer = false }
        do {
            guard let cardId = checkpoint.originalCard.cardId else { return }
            try await appState.studyDataSource.restoreLearningProgress(
                cardId: cardId,
                previousProgress: checkpoint.previousProgress
            )

            audioPlaybackService.stop()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                cards[checkpoint.cardIndex] = checkpoint.originalCard
                    .withLearningProgress(checkpoint.previousProgress)
                cardOrder.undo(cardIndex: checkpoint.cardIndex, isCorrect: checkpoint.isCorrect)
                presentationID = UUID()
                flyawayCards = []
                sessionAnswers.removeLast()
                sessionProgresses.removeLast()
                answerHistory.removeLast()
                showAnswer = false
                isFlipped = false
                dragOffset = .zero
            }
            prefetchUpcomingMedia()
            appState.markStudyDataChanged()
        } catch {
            saveErrorMessage = "取り消しを保存できませんでした。もう一度お試しください。"
        }
    }

    private var index: Int { cardOrder.current ?? cards.count }

    /// 最後の1枚は、戻っている実物だけを見せる。中央に同じカードを先出ししない。
    private var isWaitingForRepeatedCard: Bool {
        flyawayCards.contains { $0.repeatedPresentationID == presentationID }
    }

    private var currentCard: WordCard? {
        index < cards.count ? cards[index] : nil
    }

    /// 新しいカードが表面で現れたときだけ、単語から例文の順に各音声を1回鳴らす。
    private func playCurrentCardAudioSequence() {
        guard let currentCard, !isFlipped else { return }
        audioPlaybackService.playSequence(
            urls: [currentCard.wordAudioURL, currentCard.audioURL].compactMap { $0 }
        )
    }

    /// 渡した順に続けて鳴らす。押し始めの1本が鳴っている間だけ停止の見た目にし、
    /// もう一度押すと途中でも止める。鳴らせる音声が1本も無いカードでは押せない。
    private func audioButton(urls: [URL?], symbol: String, label: String) -> some View {
        StudyAudioButton(service: audioPlaybackService, urls: urls, symbol: symbol, label: label)
    }

    /// 現在のカードから数枚先までを温める。1枚消費するたびに窓が1つ先へずれるので、
    /// 常に読み込み済みの控えが残る。取得済みのものは各キャッシュ側で弾かれる。
    private func prefetchUpcomingMedia() {
        let upcoming = cardOrder.remaining
            .prefix(CardImageCache.prefetchWindow)
            .map { cards[$0] }
        CardImageCache.prefetch(urls: upcoming.compactMap(\.illustrationURL))
    }

    private func editCurrentCard() {
        guard index < cards.count else { return }
        editingWord = cards[index]
    }

    private func tagCurrentCard() {
        guard index < cards.count else { return }
        taggingWord = cards[index]
    }

    private var accuracyText: String {
        guard !sessionAnswers.isEmpty else { return "0%" }
        let correctCount = sessionAnswers.filter { $0 }.count
        let accuracy = Double(correctCount) / Double(sessionAnswers.count) * 100
        return "\(Int(accuracy.rounded()))%"
    }

    private var weakCount: Int {
        sessionProgresses.filter(\.isWeak).count
    }

}

/// 学習中の「不正解・補助操作・正解」を同じ見た目と配置で並べる共通バー。
struct StudyAnswerActionBar<Toolbar: View>: View {
    let correctSymbol: String
    let incorrectLabel: String
    let correctLabel: String
    let isDisabled: Bool
    let onIncorrect: () -> Void
    let onCorrect: () -> Void
    @ViewBuilder let toolbar: Toolbar

    init(
        correctSymbol: String = "checkmark",
        incorrectLabel: String = "不正解",
        correctLabel: String = "正解",
        isDisabled: Bool = false,
        onIncorrect: @escaping () -> Void,
        onCorrect: @escaping () -> Void,
        @ViewBuilder toolbar: () -> Toolbar
    ) {
        self.correctSymbol = correctSymbol
        self.incorrectLabel = incorrectLabel
        self.correctLabel = correctLabel
        self.isDisabled = isDisabled
        self.onIncorrect = onIncorrect
        self.onCorrect = onCorrect
        self.toolbar = toolbar()
    }

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button(action: onIncorrect) {
                Image(systemName: "xmark")
                    .foregroundStyle(WireColor.surface)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(WireColor.answerIncorrect))
            }
            .buttonStyle(.glassBarIcon(diameter: 52))
            .glassBarSurface(in: Circle())
            .disabled(isDisabled)
            .accessibilityLabel(incorrectLabel)

            toolbar

            Button(action: onCorrect) {
                Image(systemName: correctSymbol)
                    .foregroundStyle(WireColor.answerIncorrect)
                    .frame(width: 52, height: 52)
                    .background(Circle().fill(WireColor.answerCorrect))
            }
            .buttonStyle(.glassBarIcon(diameter: 52, isSelected: true))
            .glassBarSurface(in: Circle())
            .disabled(isDisabled)
            .accessibilityLabel(correctLabel)
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.top, WireMetrics.spacingXS)
        .padding(.bottom, WireMetrics.screenPadding)
        .backSwipeProtectedRegion()
    }
}

/// 回答は指が触れた瞬間に出す。確定ラインまで滑らせて離したときだけ正誤として保存する。
private enum SwipeThreshold {
    static let commit: CGFloat = 100
}

/// ドラッグの向き。動き出しの成分が大きいほうへ倒し、その操作だけを通す。
private enum DragAxis {
    case horizontal
    case vertical

    /// 動き出しの数ポイントは指のぶれで向きが定まらないので、
    /// 一定距離を超えるまで判定を保留する。
    init?(translation: CGSize) {
        guard hypot(translation.width, translation.height) >= 8 else { return nil }
        self = abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical
    }
}

/// 見送ったカードを飛ばすためだけの控え。トップカードとは別の層に置くので、
/// この演出が終わるのを待たずに次のカードを操作できる。
private struct FlyawayCard: Identifiable {
    let id = UUID()
    let card: WordCard
    let showAnswer: Bool
    let isFlipped: Bool
    let start: CGSize
    let end: CGSize
    let isCorrect: Bool
    let repeatedPresentationID: UUID?
}

private struct FlyawayCardView: View {
    let item: FlyawayCard
    let onFinished: (FlyawayCard) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var offset: CGSize?

    var body: some View {
        Group {
            if item.isCorrect {
                correctCard
            } else {
                ReturningStudyCardView(item: item, onFinished: onFinished)
            }
        }
        .allowsHitTesting(false)
        // ponytail: 演出の控えは読み上げ対象外。VoiceOverの詳細調整は後日の一括対応。
        .accessibilityHidden(true)
    }

    /// 正解側はこれまでの移動・回転・時間を保つ。
    private var correctCard: some View {
        let current = offset ?? item.start
        return StudyCardView(card: item.card, showAnswer: item.showAnswer, isFlipped: item.isFlipped)
            .swipeAnswerTint(horizontalOffset: current.width)
            .offset(current)
            .rotationEffect(.degrees(Double(current.width / 24)))
            .opacity(offset == nil ? 1 : 0)
            .zIndex(2)
            .onAppear {
                guard !reduceMotion else {
                    onFinished(item)
                    return
                }
                withAnimation(.easeIn(duration: 0.2)) {
                    offset = item.end
                } completion: {
                    onFinished(item)
                }
            }
    }
}

/// 左へ消えた後、0.9倍の大きさで最背面から同じ場所へ戻る。
private struct ReturningStudyCardView: View {
    let item: FlyawayCard
    let onFinished: (FlyawayCard) -> Void

    private enum Phase {
        case released, offscreen, returning
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase = Phase.released

    var body: some View {
        let isReturning = phase == .returning
        let position = isReturning ? .zero : (phase == .released ? item.start : item.end)
        let angle = isReturning ? 0 : (phase == .released ? Double(item.start.width / 30) : -30)

        StudyCardView(
            card: item.card,
            showAnswer: isReturning ? false : item.showAnswer,
            isFlipped: isReturning ? false : item.isFlipped
        )
            .swipeAnswerTint(horizontalOffset: isReturning ? 0 : item.start.width)
            .scaleEffect(isReturning ? 0.9 : 1)
            .blur(radius: isReturning ? 4 : 0)
            // 答え・判定色・大きさ・ぼかしを画面外で切り替え、移動・回転・透明度を遷移させる。
            .animation(nil, value: phase)
            .rotationEffect(.degrees(angle))
            .offset(position)
            .opacity(phase == .offscreen ? 0 : (isReturning ? 0.7 : 1))
            .zIndex(isReturning ? -1 : 2)
            .onAppear {
                guard !reduceMotion else {
                    onFinished(item)
                    return
                }
                withAnimation(.easeIn(duration: 0.3), completionCriteria: .removed) {
                    phase = .offscreen
                } completion: {
                    // 透明になった後で重なり順を下げ、位置と透明度を一緒に戻す。
                    withAnimation(.easeOut(duration: 0.2), completionCriteria: .removed) {
                        phase = .returning
                    } completion: {
                        onFinished(item)
                    }
                }
            }
    }
}

private struct AnswerCheckpoint {
    let cardIndex: Int
    let originalCard: WordCard
    let previousProgress: LearningProgress?
    let isCorrect: Bool
}

/// 読み込み失敗・カードなしなど、学習系の画面で共通に出す案内。
struct StudyStatusView: View {
    let symbol: String
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        WireCard {
            VStack(spacing: WireMetrics.spacingM) {
                Image(systemName: symbol)
                    .wireFont(.titleL)
                Text(title)
                    .wireFont(.titleS)
                    .multilineTextAlignment(.center)
                Text(message)
                    .wireFont(.caption)
                    .multilineTextAlignment(.center)
                Button(actionTitle, action: action)
                    .buttonStyle(.wirePrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(WireMetrics.spacingXL)
    }
}

/// 学習を終えたときのまとめ。カード・神経衰弱のどちらからも出す。
struct StudyCompletionView: View {
    let correctCount: Int
    let incorrectCount: Int
    let studiedCount: Int
    let accuracyText: String
    let weakCount: Int

    var body: some View {
        VStack(spacing: WireMetrics.spacingL) {
            Image(systemName: "sparkles")
                .wireFont(.titleL)

            VStack(spacing: WireMetrics.spacingXS) {
                Text("学習完了")
                    .wireFont(.titleL)
                Text("今日の学習はここまで。")
                    .wireFont(.caption)
            }

            VStack(spacing: WireMetrics.spacingM) {
                HStack(spacing: WireMetrics.spacingM) {
                    CompletionMetric(title: "正解", value: "\(correctCount)")
                    CompletionMetric(title: "不正解", value: "\(incorrectCount)")
                }
                HStack(spacing: WireMetrics.spacingM) {
                    CompletionMetric(title: "今回学習", value: "\(studiedCount)")
                    CompletionMetric(title: "正答率", value: accuracyText)
                }
                CompletionMetric(title: "苦手", value: "\(weakCount)")
            }
        }
        .padding(WireMetrics.spacingXL)
    }
}

private struct CompletionMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: WireMetrics.spacingXS) {
            Text(title)
                .wireFont(.caption)
            Text(value)
                .wireFont(.titleL)
        }
        .frame(maxWidth: .infinity)
        .padding(WireMetrics.spacingM)
        .outlineSurface(radius: WireMetrics.radiusCard, shadow: .card)
    }
}

private extension View {
    /// 3乗カーブで後半ほど濃くなる判定パネル。確定ラインで85%、指を戻すと消える。
    func swipeAnswerTint(horizontalOffset: CGFloat) -> some View {
        let progress = min(abs(horizontalOffset) / SwipeThreshold.commit, 1)
        let isCorrect = horizontalOffset >= 0
        let color = isCorrect ? WireColor.answerCorrect : WireColor.answerIncorrect
        return overlay {
            ZStack {
                RoundedRectangle(cornerRadius: WireMetrics.radiusCard, style: .continuous)
                    .fill(color.opacity(0.85))
                Image(systemName: isCorrect ? "circle" : "xmark")
                    .font(.system(size: 83.2, weight: .semibold))
                    .foregroundStyle(WireColor.surface)
            }
            .opacity(Double(progress * progress * progress))
            .allowsHitTesting(false)
            // ponytail: 判定パネルは装飾。VoiceOverの詳細対応は後日まとめて行う。
            .accessibilityHidden(true)
        }
    }
}

/// 押すと順に鳴らし、鳴っている間にもう一度押すと止める音声ボタン。カード学習と5択で使う。
struct StudyAudioButton: View {
    @ObservedObject var service: AudioPlaybackService
    let urls: [URL?]
    let symbol: String
    let label: String

    var body: some View {
        let queue = urls.compactMap { $0 }
        let isPlayingThis = service.playingURL != nil && service.playingURL == queue.first
        Button {
            guard !queue.isEmpty else { return }
            if isPlayingThis {
                service.stop()
            } else {
                service.playSequence(urls: queue)
            }
        } label: {
            WordListActionBarIcon(
                symbol: isPlayingThis ? "speaker.slash" : symbol,
                isActive: false
            )
        }
        .buttonStyle(.plain)
        .disabled(queue.isEmpty)
        .accessibilityLabel(label)
    }
}
