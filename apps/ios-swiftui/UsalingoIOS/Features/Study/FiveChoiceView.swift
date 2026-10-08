import SwiftUI

struct FiveChoiceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState
    let deck: Deck

    @State private var game: FiveChoiceGame?
    @State private var source: (any StudyDataSource)?
    @State private var isLoading = true
    @State private var loadErrorMessage: String?
    @State private var saveErrorMessage: String?
    @State private var answerQueue = StudyAnswerQueue()
    @State private var showsLeaveConfirmation = false
    @StateObject private var audioPlaybackService = AudioPlaybackService()

    var body: some View {
        VStack(spacing: 0) {
            StudyBridgeHeader(progress: game?.progress ?? 0, isBackDisabled: answerQueue.isDraining) {
                if answerQueue.isEmpty { dismiss() } else { showsLeaveConfirmation = true }
            }
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            saveFailureBanner
            footer
        }
        .background(WireColor.background)
        .background {
            BackSwipeEnabler()
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task { await load() }
        .onAppear { appState.isShellChromeHidden = true }
        .onDisappear {
            appState.isShellChromeHidden = false
            audioPlaybackService.stop()
        }
        .confirmationDialog("未保存の回答があります", isPresented: $showsLeaveConfirmation, titleVisibility: .visible) {
            Button("保存せずに戻る", role: .destructive) { dismiss() }
            Button("学習に戻る", role: .cancel) { }
        } message: {
            Text("保存をやり直す場合は、この画面に戻って「もう一度保存」を押してください。")
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            ProgressView("5択を準備しています")
        } else if let loadErrorMessage {
            StudyStatusView(
                symbol: "exclamationmark.triangle",
                title: "カードを読み込めませんでした",
                message: loadErrorMessage,
                actionTitle: "もう一度試す"
            ) { Task { await load() } }
        } else if let game, let question = game.question {
            // 結果側だけにタップ判定を置く。回答した同じタップで次の問題へ飛ばない。
            // 見ただけの問題は、左右の余白での自己評価だけを受け付ける。
            if game.selectedIndex != nil {
                questionScroll(question, game: game)
                    .contentShape(Rectangle())
                    .onTapGesture { advance() }
                    .accessibilityElement(children: .contain)
                    .accessibilityAction(named: Text("次の問題へ")) { advance() }
            } else {
                questionScroll(question, game: game)
            }
        } else if game?.questionCount == 0 {
            StudyStatusView(
                symbol: "rectangle.stack.badge.minus",
                title: "今日の学習は完了です",
                message: "別の学習モードを選ぶか、デッキに戻ってください。",
                actionTitle: "デッキに戻る"
            ) { dismiss() }
        } else if game?.answeredCount == 0 {
            StudyStatusView(
                symbol: "rectangle.stack.badge.minus",
                title: "5択を作れる問題がありません",
                message: "重複や似た意味を除くと、選択肢が足りません。学習するデッキを追加するか、別のモードをお試しください。",
                actionTitle: "デッキに戻る"
            ) { dismiss() }
        } else {
            VStack(spacing: WireMetrics.spacingM) {
                Image(systemName: "checkmark.circle").wireFont(.titleL)
                Text(answerQueue.isEmpty ? "学習完了" : "回答を保存しています")
                    .wireFont(.titleL)
                if let game, game.skippedCount > 0 {
                    Text("選択肢が足りない\(game.skippedCount)問は出題しませんでした。")
                        .wireFont(.caption)
                }
            }
            .multilineTextAlignment(.center)
            .padding(WireMetrics.screenPadding)
        }
    }

    private func questionScroll(_ question: FiveChoiceGame.Question, game: FiveChoiceGame) -> some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: WireMetrics.spacingL) {
                    partOfSpeechRow(question.card, revealed: game.isRevealed)
                    Text(question.card.text)
                        .wireFont(.titleL)
                        .multilineTextAlignment(.center)
                        .padding(WireMetrics.spacingXL)
                        .frame(maxWidth: .infinity)
                        .outlineSurface(radius: WireMetrics.radiusLarge, shadow: .card)
                        .accessibilityIdentifier("fiveChoice.question")

                    VStack(spacing: WireMetrics.spacingM) {
                        ForEach(question.choices.indices, id: \.self) { index in
                            if game.isRevealed {
                                choice(question.choices[index], index: index, question: question, game: game)
                            } else {
                                Button {
                                    answer(at: index)
                                } label: {
                                    choice(question.choices[index], index: index, question: question, game: game)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("fiveChoice.answer.\(index)")
                            }
                        }
                    }
                    .accessibilityElement(children: .contain)
                    Spacer(minLength: 0)
                }
                .padding(WireMetrics.screenPadding)
                .frame(minHeight: geometry.size.height, alignment: .top)
                .frame(maxWidth: .infinity)
                // 部品の無い余白のタップ。選ぶ前は答えを見るだけ（記録しない）、見た後は
                // 画面の中央より右を正解、左を不正解として自己評価する。答え合わせ後は次へ進む。
                // 部品より後ろに敷くので、品詞の帯・問題文・選択肢の上のタップはそれぞれが受け取る。
                .background {
                    GeometryReader { zone in
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                tapMargin(isRightSide: location.x >= zone.size.width / 2)
                            }
                    }
                    // ponytail: 余白タップは補助操作。VoiceOverの詳細対応は後日の一括対応。
                    .accessibilityHidden(true)
                }
            }
        }
    }

    private func choice(_ card: WordCard, index: Int, question: FiveChoiceGame.Question, game: FiveChoiceGame) -> some View {
        let isCorrect = game.isRevealed && index == question.correctIndex
        let isWrong = game.isRevealed && index == game.selectedIndex && !isCorrect
        let status = isCorrect ? "正解" : (isWrong ? "不正解" : "")
        // 正誤だけに色を添え、色を見分けなくても記号と文言で判断できるようにする。
        let color: Color = isCorrect ? WireColor.answerCorrect : WireColor.answerIncorrect

        return VStack(spacing: WireMetrics.spacingXS) {
            VStack(spacing: WireMetrics.spacingXS) {
                if !status.isEmpty {
                    Label(status, systemImage: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .wireFont(.caption, color: WireColor.answerIncorrect)
                }
                Text(card.meaning)
                    .wireFont(.body, color: WireColor.answerIncorrect)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(WireMetrics.spacingM)
            .frame(maxWidth: .infinity, minHeight: 52)
            .outlineSurface(
                radius: WireMetrics.radiusControl,
                stroke: isCorrect || isWrong ? WireMetrics.strokeHeavy : WireMetrics.strokeHair,
                shadow: nil,
                dashed: isWrong,
                fill: isCorrect || isWrong ? color.opacity(0.08) : WireColor.surface
            )
            if game.isRevealed {
                Text(card.text)
                    .wireFont(.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(game.isRevealed ? "\(card.meaning)、\(card.text)" : card.meaning)
        .accessibilityValue(status)
    }

    private func partOfSpeechRow(_ card: WordCard, revealed: Bool) -> some View {
        let active = WordCardContent(card: card).partsOfSpeech
        // 接続詞への置き換えも答え合わせ後に行い、品詞を先に明かさない。
        let parts = WordPartOfSpeech.displayOrder.map { part in
            revealed && active.contains(.conjunction) && part == .preposition ? WordPartOfSpeech.conjunction : part
        }
        return HStack(spacing: 0) {
            ForEach(parts) { part in
                let highlighted = revealed && active.contains(part)
                Text(part.rawValue)
                    .wireFont(.caption, color: highlighted ? WireColor.ink : WireColor.subText)
                    .fontWeight(highlighted ? .bold : .regular)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, WireMetrics.spacingXS)
                    .background {
                        if highlighted {
                            Capsule().fill(WireColor.groupL3)
                                .shadow(color: WireColor.ink.opacity(0.2), radius: 1, x: 0, y: -1)
                        }
                    }
                    .accessibilityAddTraits(highlighted ? .isSelected : [])
            }
        }
        .padding(WireMetrics.spacingXS)
        .outlineSurface(radius: WireMetrics.radiusPill, shadow: nil)
    }

    /// 下端の道具の帯。カード学習と同じガラスの帯に、音声2つだけを置く。
    private var footer: some View {
        HStack(spacing: WireMetrics.spacingS) {
            audioButton(
                urls: [game?.question?.card.wordAudioURL, game?.question?.card.audioURL],
                symbol: "speaker.wave.2",
                label: "単語と例文の音声を再生"
            )
            audioButton(
                urls: [game?.question?.card.audioURL],
                symbol: "text.bubble",
                label: "例文の音声を再生"
            )
            if answerQueue.isDraining { ProgressView().accessibilityLabel("回答を保存中") }
        }
        .wordListBarChrome()
        .frame(maxWidth: .infinity)
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.top, WireMetrics.spacingXS)
        .padding(.bottom, WireMetrics.spacingXL)
        .background {
            if game?.selectedIndex != nil {
                Color.clear.contentShape(Rectangle()).onTapGesture { advance() }
            }
        }
    }

    private func audioButton(urls: [URL?], symbol: String, label: String) -> some View {
        StudyAudioButton(service: audioPlaybackService, urls: urls, symbol: symbol, label: label)
    }

    @ViewBuilder
    private var saveFailureBanner: some View {
        if let saveErrorMessage {
            VStack(spacing: WireMetrics.spacingS) {
                Text("回答を保存できませんでした").wireFont(.label)
                Text(saveErrorMessage).wireFont(.caption)
                Button("もう一度保存") {
                    self.saveErrorMessage = nil
                    drainAnswers()
                }
                .buttonStyle(.wireSecondary)
                .disabled(answerQueue.isDraining)
            }
            .multilineTextAlignment(.center)
            .padding(WireMetrics.spacingM)
            .outlineSurface(radius: WireMetrics.radiusControl, shadow: nil, dashed: true)
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    private func answer(at index: Int) {
        guard var game, let question = game.question,
              let isCorrect = game.answer(at: index) else { return }
        self.game = game
        HapticFeedbackService.tap()
        enqueueAnswer(question, isCorrect: isCorrect, answeredCount: game.answeredCount)
    }

    private func tapMargin(isRightSide: Bool) {
        guard var game, let question = game.question else { return }
        if game.selectedIndex != nil {
            advance()
        } else if game.isPeeking {
            guard game.grade(isCorrect: isRightSide) else { return }
            self.game = game
            audioPlaybackService.stop()
            HapticFeedbackService.tap()
            enqueueAnswer(question, isCorrect: isRightSide, answeredCount: game.answeredCount)
        } else {
            game.peek()
            self.game = game
            HapticFeedbackService.tap()
        }
    }

    private func enqueueAnswer(_ question: FiveChoiceGame.Question, isCorrect: Bool, answeredCount: Int) {
        answerQueue.enqueue(
            cardIndex: answeredCount - 1,
            card: question.card,
            isCorrect: isCorrect,
            attempt: AnswerSaveAttempt(isRetry: question.isRetry)
        )
        if saveErrorMessage == nil { drainAnswers() }
    }

    private func advance() {
        guard var game, game.selectedIndex != nil else { return }
        audioPlaybackService.stop()
        game.advance()
        self.game = game
        HapticFeedbackService.tap()
    }

    private func drainAnswers() {
        guard let source else { return }
        drainStudyAnswerQueue($answerQueue, appState: appState, saveErrorMessage: $saveErrorMessage, source: source)
    }

    private func load() async {
        isLoading = true
        loadErrorMessage = nil
        let source = appState.studyDataSource
        self.source = source
        do {
            game = try await FiveChoiceGame.load(deckId: deck.id, source: source)
        } catch is CancellationError {
            return
        } catch {
            loadErrorMessage = UserFacingError.message(for: error)
        }
        isLoading = false
    }
}
