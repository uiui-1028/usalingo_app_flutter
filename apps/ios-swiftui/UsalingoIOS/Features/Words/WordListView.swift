import SwiftUI

struct WordListView: View {
    /// 詳細ページへ組み込むときは、バナーを省いて単語シートだけを表示する。
    private let sheetOnly: Bool
    /// シートが画面の高さに占める割合。デッキ選択バナーを戻すときに再び使う。
    private static let sheetHeightRatio: CGFloat = 0.75
    /// 浮動バーの高さと下余白のぶん、最後の行が隠れないように空ける量。
    @State private var bottomBarClearance: CGFloat = 96
    /// 赤シート上端は、初期状態では画面下から55%（上から45%）。
    private static let initialRedSheetTopRatio: CGFloat = 0.45
    private static let minimumRedSheetTopRatio: CGFloat = 0.30
    private static let maximumRedSheetTopRatio: CGFloat = 0.80
    @State private var isRedSheetEnabled = false
    @AppStorage(WordListColumn.leftStorageKey) private var leftColumn: WordListColumn = .word
    @AppStorage(WordListColumn.rightStorageKey) private var rightColumn: WordListColumn = .meaning
    /// 上のパネル（と端末上端の余白）のぶん、一覧の先頭を下げる量。
    @State private var headerClearance: CGFloat = 0
    @State private var redSheetTopRatio = Self.initialRedSheetTopRatio
    @State private var rowFrames: [Int: CGRect] = [:]
    @State private var lastRowHeight: CGFloat = 80
    @StateObject private var check = RedSheetCheckModel()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: WordListViewModel
    @State private var selectedWord: WordCard?
    @State private var taggingWord: WordCard?
    @State private var editingWord: WordCard?

    init(
        deck: Deck? = nil,
        previewWords: [WordCard]? = nil,
        displayMode: WordListDisplayMode = .list,
        previewRedSheetEnabled: Bool = false,
        previewCheck: RedSheetCheckModel? = nil,
        sheetOnly: Bool = false
    ) {
        self.sheetOnly = sheetOnly
        _check = StateObject(wrappedValue: previewCheck ?? RedSheetCheckModel())
        _isRedSheetEnabled = State(initialValue: previewWords != nil && previewRedSheetEnabled && displayMode == .list)
        _viewModel = StateObject(wrappedValue: WordListViewModel(
            deck: deck,
            previewWords: previewWords,
            displayMode: displayMode
        ))
    }

    /// 単語一覧を端末の上端から下端まで囲いなしで置く。一覧は上のパネルの裏を通って上端まで流れる。
    /// 背面のデッキ選択バナーは外してある（復活させるならコミット履歴から戻す）。
    var body: some View {
        GeometryReader { proxy in
            if sheetOnly {
                sheet(topInset: 0, bottomInset: 0)
            } else {
                let insets = proxy.safeAreaInsets
                sheet(topInset: insets.top, bottomInset: insets.bottom)
                    .ignoresSafeArea()
                    .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88), value: isRedSheetEnabled)
            }
        }
        // 操作はすべてシートの中の浮動バーに集めたので、上のヘッダーごと消す。
        // ヘッダーを消すと戻るスワイプも一緒に止まるため、学習画面と同じ仕組みで戻す。
        .toolbar(sheetOnly && !isRedSheetEnabled ? .visible : .hidden, for: .navigationBar)
        .background {
            if !sheetOnly || isRedSheetEnabled { BackSwipeEnabler() }
            // 未保存の判定を置いたまま画面を離れない。再タップできる赤シートボタンを使う。
            if isRedSheetEnabled { BackSwipeProtectedRegionMarker() }
        }
        .onChange(of: isRedSheetEnabled) { _, enabled in
            if enabled {
                redSheetTopRatio = Self.initialRedSheetTopRatio
                startCheck()
            } else {
                check.reset()
            }
        }
        .fullScreenCover(item: $selectedWord) { word in
            WordDetailSheet(word: word, words: viewModel.filteredWords) { savedWord in
                _ = viewModel.replaceWord(savedWord)
            }
        }
        .sheet(item: $editingWord) { word in
            WordEditSheet(word: word) { savedWord in
                _ = viewModel.replaceWord(savedWord)
                check.replaceWord(savedWord)
            }
            .presentationDetents([.large])
        }
        .sheet(item: $taggingWord) { word in
            TagSheet(word: word) { savedWord in
                _ = viewModel.replaceWord(savedWord)
                check.replaceWord(savedWord)
            }
            .presentationDetents([.medium])
        }
        .task(id: appState.session?.user.id ?? "guest") {
            if sheetOnly {
                await viewModel.load(dataSource: appState.studyDataSource)
            } else {
                await viewModel.loadDecks(
                    dataSource: appState.studyDataSource,
                    preferredDeckID: appState.wordListDeckID
                )
            }
        }
        // 浮いているタブバーが一覧の末尾に重なるので、この画面にいる間は
        // シェルの操作面を隠す。戻る導線はスワイプが担う。
        .onAppear {
            if !sheetOnly { appState.isShellChromeHidden = true }
        }
        .onDisappear {
            if !sheetOnly { appState.isShellChromeHidden = false }
        }
    }

    /// 単語一覧の面。高さは固定で、中身だけが縦に流れる。
    /// 詳細ページへ組み込むとき（`sheetOnly`）だけ、上端を角丸の枠で切り取る。
    private func sheet(topInset: CGFloat, bottomInset: CGFloat) -> some View {
        GeometryReader { proxy in
            // 一覧のレイヤーと赤シートのレイヤーを分ける。赤シートは一覧と一緒にスクロールしない。
            ZStack(alignment: .topTrailing) {
                wordScroll(bottomInset: bottomInset, viewportHeight: proxy.size.height)
                    .overlay {
                        if isRedSheetEnabled && check.isStarted && !check.isComplete {
                            RedSheetStudyTapLayer(
                                isAnswerVisible: check.isAnswerVisible,
                                isDisabled: check.current == nil || check.isUndoing,
                                onReveal: revealCurrentAnswer,
                                onJudge: judgeCurrentAnswer
                            )
                        }
                    }

                if isRedSheetEnabled && viewModel.selectedDisplayMode == .list
                    && !displayedWords.isEmpty && !viewModel.isLoading && !check.isComplete {
                    RedSheetLayer(
                        topRatio: $redSheetTopRatio,
                        availableHeight: proxy.size.height,
                        minimumTopRatio: Self.minimumRedSheetTopRatio,
                        maximumTopRatio: Self.maximumRedSheetTopRatio
                    )
                    .frame(width: proxy.size.width / 2, height: proxy.size.height)
                    .zIndex(1)
                }

                if !sheetOnly {
                    WordListColumnHeader(
                        progress: progress(viewportHeight: proxy.size.height),
                        columns: viewModel.selectedDisplayMode == .list
                            ? (left: $leftColumn, right: $rightColumn)
                            : nil
                    )
                    .padding(.horizontal, WireMetrics.screenPadding)
                    .padding(.top, topInset + WireMetrics.spacingXS)
                    .background {
                        GeometryReader { header in
                            Color.clear.preference(
                                key: WordListHeaderHeightKey.self,
                                value: header.size.height + WireMetrics.spacingS
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .zIndex(2)
                }
            }
            .coordinateSpace(name: "wordListViewport")
            .onPreferenceChange(WordListHeaderHeightKey.self) { headerClearance = $0 }
            .onPreferenceChange(WordListRowFramesKey.self) { frames in
                rowFrames = frames
                if let id = displayedWords.last?.id, let height = frames[id]?.height {
                    lastRowHeight = height
                }
            }
            .onChange(of: displayedWords.last?.id) { _, _ in lastRowHeight = 80 }
        }
            .background(WireColor.surface)
            .clipShape(sheetOnly ? AnyShape(sheetShape) : AnyShape(Rectangle()))
            .overlay {
                if sheetOnly {
                    sheetShape
                        .strokeBorder(WireColor.ink, lineWidth: WireMetrics.strokeBase)
                }
            }
            // 左のバーに絞り込み・並べ替え・検索、右のバーに表示切り替えを収める。
            // 赤シート中は左を赤シートボタンだけに畳み、右に赤シート専用のバーを出す。
            // 横に触ることが多いので、ここから始めたスワイプでは戻さない。
            .overlay(alignment: .bottom) {
                VStack(spacing: 10) {
                    if isRedSheetEnabled { redSheetSaveStatus }
                    WordListBottomBars(
                        tags: viewModel.availableTags,
                        selectedTag: $viewModel.selectedTagFilter,
                        selectedStatusFilter: $viewModel.selectedStatusFilter,
                        selectedDueFilter: $viewModel.selectedDueFilter,
                        selectedSort: $viewModel.selectedSort,
                        searchText: $viewModel.searchText,
                        selectedDisplayMode: $viewModel.selectedDisplayMode,
                        isRedSheetEnabled: $isRedSheetEnabled,
                        canToggleRedSheet: check.canLeave
                    ) {
                        redSheetActionBar
                    }
                }
                .background {
                    GeometryReader { bar in
                        Color.clear.preference(key: WordListBarHeightKey.self, value: bar.size.height)
                    }
                }
                .padding(.bottom, bottomInset)
                .backSwipeProtectedRegion()
            }
            .onPreferenceChange(WordListBarHeightKey.self) { bottomBarClearance = $0 }
            .onChange(of: viewModel.selectedDisplayMode) { _, mode in
                if mode == .cards { isRedSheetEnabled = false }
            }
    }

    /// 上端だけ角丸、下端は画面の端まで。引っ張って大きさは変えない。
    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: WireMetrics.radiusLarge,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: WireMetrics.radiusLarge,
            style: .continuous
        )
    }

    /// `List` の行に置いたタップは、行の余白や左右の背景まで一緒に反応してしまう。
    /// 背景は戻るスワイプが使う場所なので、行の枠だけがタップに応えるよう
    /// 自前の縦並びにする（この画面はスワイプ削除も並べ替えも使わない）。
    private func wordScroll(bottomInset: CGFloat, viewportHeight: CGFloat) -> some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(spacing: 0) {
                    if viewModel.isLoading {
                        ProgressView()
                            .tint(WireColor.ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, WireMetrics.spacingXL)
                    } else if !viewModel.message.isEmpty && viewModel.words.isEmpty {
                        WordListErrorBox(info: WordListErrorInfo(rawMessage: viewModel.message)) {
                            Task { await viewModel.load(dataSource: appState.studyDataSource) }
                        }
                        .padding(.vertical, WireMetrics.spacingXL)
                    } else if displayedWords.isEmpty {
                        ContentUnavailableView("単語がありません", systemImage: "magnifyingglass", description: Text("検索条件またはタグを変更してください"))
                            .padding(.vertical, WireMetrics.spacingXL)
                    } else if viewModel.selectedDisplayMode == .cards {
                        LazyVGrid(columns: cardColumns, spacing: WireMetrics.spacingM) {
                            ForEach(displayedWords) { word in
                                WordLibraryCard(word: word)
                                    .cardTapTarget { selectedWord = word }
                                    .reportsWordListFrame(id: word.id)
                            }
                        }
                        .padding(WireMetrics.screenPadding)
                    } else {
                        if isRedSheetEnabled && check.isStarted {
                            RedSheetEmptyRecords(height: max(0, redSheetTop(in: viewportHeight) - headerClearance))
                        }
                        ForEach(Array(displayedWords.enumerated()), id: \.element.id) { index, word in
                            WordRow(
                                word: word,
                                number: index + 1,
                                hidesAnswerFromAccessibility: answerIsHidden(at: index),
                                checkResult: check.answers[word.id],
                                reservesCheckResultSpace: check.isStarted,
                                isCheckTarget: check.current?.id == word.id,
                                leftColumn: leftColumn,
                                rightColumn: rightColumn
                            )
                                .cardTapTarget(radius: 0) {
                                    if check.isStarted {
                                        if word.id == check.current?.id { check.isAnswerVisible = true }
                                    } else {
                                        selectedWord = word
                                    }
                                }
                                .id(word.id)
                                .reportsWordListFrame(id: word.id)
                        }
                    }
                }
                .scrollTargetLayout(isEnabled: viewModel.selectedDisplayMode == .list)
                // 上のパネルの下から始める。スクロールするとパネルの裏へ入る。
                .padding(.top, headerClearance)
                // 最終行も上端へ揃えられる余白。カード表示は従来どおりの余白。
                .padding(.bottom, viewModel.selectedDisplayMode == .list
                    ? WordListRowSnapping.bottomPadding(
                        viewportHeight: viewportHeight - headerClearance,
                        lastRowHeight: lastRowHeight
                    )
                    : bottomBarClearance + bottomInset)
            }
            .scrollIndicators(.hidden)
            .scrollDisabled(isRedSheetEnabled)
            .scrollTargetBehavior(WordListRowScrollBehavior(
                isEnabled: viewModel.selectedDisplayMode == .list,
                topInset: headerClearance
            ))
            .onChange(of: check.isAnswerVisible) { _, visible in
                guard visible, let id = check.current?.id else { return }
                let rowHeight = rowFrames[id]?.height ?? lastRowHeight
                let anchorY = max(0, min(1,
                    (redSheetTop(in: viewportHeight) - rowHeight) / max(1, viewportHeight - rowHeight)
                ))
                // 赤シートは固定し、答えの行だけをシートの上へ送る。
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    reader.scrollTo(id, anchor: UnitPoint(x: 0, y: anchorY))
                }
            }
            .onChange(of: check.current?.id) { _, id in
                guard let id else { return }
                let rowHeight = rowFrames[id]?.height ?? lastRowHeight
                let anchorY = min(1, redSheetTop(in: viewportHeight) / max(1, viewportHeight - rowHeight))
                // 判定のたびに次の単語を赤シートの基準位置まで1行ずつ上げる。
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                    reader.scrollTo(id, anchor: UnitPoint(x: 0, y: anchorY))
                }
            }
        }
    }

    private var displayedWords: [WordCard] { check.isStarted ? check.words : viewModel.filteredWords }

    /// 上のパネルの進み具合。赤シートのチェック中は判定した数、リストはパネルのすぐ下の行、
    /// カードは画面に見えている最後のカードの位置で測る。
    private func progress(viewportHeight: CGFloat) -> Double {
        let count = displayedWords.count
        guard count > 0 else { return 0 }
        if isRedSheetEnabled && check.isStarted {
            return Double(check.index) / Double(count)
        }
        let visible = displayedWords.indices.filter { index in
            guard let frame = rowFrames[displayedWords[index].id] else { return false }
            return frame.maxY > headerClearance + 1 && frame.minY < viewportHeight
        }
        guard let first = visible.first, let last = visible.last else { return 0 }
        let position = viewModel.selectedDisplayMode == .cards ? last : first
        return Double(position + 1) / Double(count)
    }
    private func redSheetTop(in viewportHeight: CGFloat) -> CGFloat {
        RedSheetPosition.top(availableHeight: viewportHeight, ratio: redSheetTopRatio)
    }

    private func answerIsHidden(at index: Int) -> Bool {
        guard isRedSheetEnabled else { return false }
        guard check.isStarted else { return true }
        return index > check.index || (index == check.index && !check.isAnswerVisible)
    }

    private func startCheck() {
        check.start(words: viewModel.filteredWords, source: appState.studyDataSource) { word in
            viewModel.replaceWord(word)
            appState.markStudyDataChanged()
        }
    }

    private func revealCurrentAnswer() {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
            check.revealAnswer()
        }
    }

    private func judgeCurrentAnswer(isCorrect: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
            check.submit(isCorrect: isCorrect)
        }
    }

    @ViewBuilder
    private var redSheetSaveStatus: some View {
        if let error = check.errorMessage {
            VStack(spacing: WireMetrics.spacingS) {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button("もう一度保存", action: check.retry)
                    .buttonStyle(.wireSecondary)
                    .disabled(check.pendingCount == 0 || check.isSaving || check.isUndoing)
            }
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    /// 赤シート中だけ出す、いまの1語への操作。カードモードと同じガラスのボタン。
    private var redSheetActionBar: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button {
                (leftColumn, rightColumn) = (rightColumn, leftColumn)
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.glassBarIcon(diameter: 48))
            .accessibilityLabel("左右の列を入れ替え")
            .accessibilityValue("左 \(leftColumn.title)、右 \(rightColumn.title)")

            Button {
                taggingWord = check.current
            } label: {
                Image(systemName: "tag")
            }
            .buttonStyle(.glassBarIcon(diameter: 48))
            .disabled(check.current == nil)
            .accessibilityLabel("タグ")

            Button {
                editingWord = check.current
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.glassBarIcon(diameter: 48))
            .disabled(check.current == nil)
            .accessibilityLabel("単語を編集")
        }
        .wordListBarChrome()
    }

    private var cardColumns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible())
        ]
    }
}

private struct WordListBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 96
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct WordListHeaderHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    /// 一覧の行・カードの位置を、上のパネルの進み具合と赤シートの位置合わせに渡す。
    func reportsWordListFrame(id: Int) -> some View {
        background {
            GeometryReader { item in
                Color.clear.preference(
                    key: WordListRowFramesKey.self,
                    value: [id: item.frame(in: .named("wordListViewport"))]
                )
            }
        }
    }
}

private struct WordListRowFramesKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, new in new })
    }
}

private struct WordListRowScrollBehavior: ScrollTargetBehavior {
    let isEnabled: Bool
    /// 上のパネルの高さ。行の先頭はパネルの裏ではなく、そのすぐ下に止める。
    var topInset: CGFloat = 0

    func updateTarget(_ target: inout ScrollTarget, context: TargetContext) {
        guard isEnabled else { return }
        // 指追従と減速は標準のまま、停止位置だけ各行の先頭に合わせる。
        ViewAlignedScrollTargetBehavior(limitBehavior: .never).updateTarget(&target, context: context)
        target.rect.origin.y = max(0, target.rect.origin.y - topInset)
    }
}

enum WordListRowSnapping {
    static func bottomPadding(viewportHeight: CGFloat, lastRowHeight: CGFloat) -> CGFloat {
        max(0, viewportHeight - lastRowHeight)
    }
}

enum RedSheetTapAction: Equatable {
    case reveal
    case judge(isCorrect: Bool)

    static func resolve(isAnswerVisible: Bool, tapX: CGFloat, width: CGFloat) -> Self {
        guard isAnswerVisible else { return .reveal }
        return .judge(isCorrect: tapX >= width / 2)
    }
}

/// 最初の単語を赤シート位置から始めるための、番号も文字もない空レコード。
private struct RedSheetEmptyRecords: View {
    let height: CGFloat
    private let rowHeight: CGFloat = 80

    var body: some View {
        let count = max(1, Int(ceil(height / rowHeight)))
        VStack(spacing: 0) {
            ForEach(0..<count, id: \.self) { index in
                Rectangle()
                    .fill(index.isMultiple(of: 2) ? WireColor.ink.opacity(0.04) : WireColor.surface)
                    .frame(height: rowHeight)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(WireColor.ink.opacity(0.12)).frame(height: 1)
                    }
            }
        }
        .frame(height: height, alignment: .bottom)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// 未表示ならどこをタップしても答えを見せ、表示後は画面の左右で判定する。
private struct RedSheetStudyTapLayer: View {
    let isAnswerVisible: Bool
    let isDisabled: Bool
    let onReveal: () -> Void
    let onJudge: (Bool) -> Void

    var body: some View {
        GeometryReader { proxy in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    SpatialTapGesture().onEnded { value in
                        guard !isDisabled else { return }
                        switch RedSheetTapAction.resolve(
                            isAnswerVisible: isAnswerVisible,
                            tapX: value.location.x,
                            width: proxy.size.width
                        ) {
                        case .reveal:
                            onReveal()
                        case let .judge(isCorrect):
                            onJudge(isCorrect)
                        }
                    }
                )
                .accessibilityElement()
                .accessibilityLabel("赤シート学習")
                .accessibilityValue(isAnswerVisible ? "答えを表示中" : "答えは非表示")
                .accessibilityActions {
                    if isAnswerVisible {
                        Button("不正解") {
                            guard !isDisabled else { return }
                            onJudge(false)
                        }
                        Button("正解") {
                            guard !isDisabled else { return }
                            onJudge(true)
                        }
                    } else {
                        Button("答えを表示") {
                            guard !isDisabled else { return }
                            onReveal()
                        }
                    }
                }
        }
    }
}
