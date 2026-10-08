import SwiftUI

/// 表示切り替え（リスト / カード）。2種類しかないので、押すたびにもう一方へ切り替える。
/// アイコンは今の表示を示す。
struct WordListDisplayModeToggle: View {
    @Binding var selectedMode: WordListDisplayMode

    var body: some View {
        Button {
            selectedMode = selectedMode == .list ? .cards : .list
        } label: {
            WordListActionBarIcon(symbol: selectedMode.symbol, isActive: false)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("表示切り替え")
        .accessibilityValue(selectedMode.title)
    }
}

/// 赤シートのオン・オフ。右に1つだけ置く小さなバーで、オンにしても形は変わらない。
struct WordListRedSheetBar: View {
    @Binding var isRedSheetEnabled: Bool
    @Binding var selectedDisplayMode: WordListDisplayMode
    let canToggleRedSheet: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            guard selectedDisplayMode == .list else { return }
            withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.88)) {
                isRedSheetEnabled.toggle()
            }
        } label: {
            Image(systemName: "rectangle.fill")
                .foregroundStyle(.red)
                .frame(width: 48, height: 48)
                .glassBarSelection(isRedSheetEnabled, in: Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!canToggleRedSheet || selectedDisplayMode != .list)
        .accessibilityLabel("赤シート")
        .accessibilityValue(isRedSheetEnabled ? "オン" : "オフ")
        .accessibilityHint("意味欄を隠すシートを切り替えます")
        .wordListBarChrome()
    }
}

/// 画面下端に浮かべる2本のバー。左が絞り込み・並べ替え・検索・表示切り替え、右が赤シート。
/// 検索を開いている間は、左のバーが横いっぱいに広がるので右のバーは引っ込める。
/// 赤シート中は、左のバーの中身を赤シート専用の操作に入れ替える。右のバーはそのまま。
struct WordListBottomBars<RedSheetActions: View>: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter
    @Binding var selectedSort: WordSortOption
    @Binding var searchText: String
    @Binding var selectedDisplayMode: WordListDisplayMode
    @Binding var isRedSheetEnabled: Bool
    let canToggleRedSheet: Bool
    @ViewBuilder let redSheetActions: RedSheetActions

    @State private var isSearchExpanded = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // 左のバーは左端、右のバーは右端に留める。中身が変わっても、真ん中へ寄せ直さない。
        ViewThatFits(in: .horizontal) {
            HStack(spacing: WireMetrics.spacingS) {
                actionBar
                Spacer(minLength: 0)
                trailingBar
            }
            VStack(alignment: .leading, spacing: WireMetrics.spacingS) {
                trailingBar
                    .frame(maxWidth: .infinity, alignment: .trailing)
                actionBar
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingXL)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSearchExpanded)
    }

    @ViewBuilder private var actionBar: some View {
        if isRedSheetEnabled {
            redSheetActions
                .transition(.opacity)
        } else {
            WordListActionBar(
                tags: tags,
                selectedTag: $selectedTag,
                selectedStatusFilter: $selectedStatusFilter,
                selectedDueFilter: $selectedDueFilter,
                selectedSort: $selectedSort,
                searchText: $searchText,
                isSearchExpanded: $isSearchExpanded,
                selectedDisplayMode: $selectedDisplayMode
            )
            .transition(.opacity)
        }
    }

    @ViewBuilder private var trailingBar: some View {
        if !isSearchExpanded {
            WordListRedSheetBar(
                isRedSheetEnabled: $isRedSheetEnabled,
                selectedDisplayMode: $selectedDisplayMode,
                canToggleRedSheet: canToggleRedSheet
            )
            .opacity(selectedDisplayMode == .list ? 1 : 0)
            .allowsHitTesting(selectedDisplayMode == .list)
            .accessibilityHidden(selectedDisplayMode != .list)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: selectedDisplayMode)
        }
    }

}

/// 絞り込み・並べ替え・検索・表示切り替えをひとまとめにした、画面下端の浮動バー。
/// シェルのタブバーと同じ形・同じ位置に置き、検索は押した時だけバーの中を広げる。
struct WordListActionBar: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter
    @Binding var selectedSort: WordSortOption
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    @Binding var selectedDisplayMode: WordListDisplayMode

    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            if !isSearchExpanded {
                WordListFilterMenu(
                    tags: tags,
                    selectedTag: $selectedTag,
                    selectedStatusFilter: $selectedStatusFilter,
                    selectedDueFilter: $selectedDueFilter
                )

                WordListSortMenu(selectedSort: $selectedSort)
            }

            searchControl

            if !isSearchExpanded {
                WordListDisplayModeToggle(selectedMode: $selectedDisplayMode)
            }
        }
        .wordListBarChrome()
    }

    /// 閉じている間はアイコン1つ。開くとバーの残りを押し広げて入力欄になる。
    private var searchControl: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button {
                if isSearchExpanded {
                    closeSearch()
                } else {
                    isSearchExpanded = true
                    isSearchFocused = true
                }
            } label: {
                Image(systemName: isSearchExpanded ? "xmark" : "magnifyingglass")
                    .wireFont(.label, color: .primary)
                    .frame(minWidth: 48, minHeight: 48)
                    .glassBarSelection(isSearching, in: Capsule())
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isSearchExpanded ? "検索を閉じる" : "検索")

            if isSearchExpanded {
                TextField("英単語・意味・例文を検索", text: $searchText)
                    .wireFont(.label)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                    // 変換途中の文字は欄が消えた後に確定して戻ってくることがあるので、
                    // 閉じる時の消去は欄が消えたこの時点でもう一度行う。
                    .onDisappear { searchText = "" }
            }
        }
        .frame(maxWidth: isSearchExpanded ? .infinity : nil)
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func closeSearch() {
        isSearchFocused = false
        isSearchExpanded = false
        searchText = ""
    }
}

/// 絞り込み。タグ・学習状態・復習予定の3種類をセクションで束ねる。
struct WordListFilterMenu: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter

    var body: some View {
        Menu {
            if !tags.isEmpty {
                Section("タグ") {
                    Button {
                        selectedTag = nil
                    } label: {
                        Label("すべて", systemImage: selectedTag == nil ? "checkmark" : "tag")
                    }

                    ForEach(tags, id: \.self) { tag in
                        Button {
                            selectedTag = tag
                        } label: {
                            Label(tag, systemImage: selectedTag == tag ? "checkmark" : "tag")
                        }
                    }
                }
            }

            Section("学習状態") {
                ForEach(WordStatusFilter.allCases) { filter in
                    Button {
                        selectedStatusFilter = filter
                    } label: {
                        Label(filter.title, systemImage: selectedStatusFilter == filter ? "checkmark" : filter.symbol)
                    }
                }
            }

            Section("復習予定") {
                ForEach(WordDueFilter.allCases) { filter in
                    Button {
                        selectedDueFilter = filter
                    } label: {
                        Label(filter.title, systemImage: selectedDueFilter == filter ? "checkmark" : filter.symbol)
                    }
                }
            }

            if isFiltering {
                Section {
                    Button(role: .destructive) {
                        selectedTag = nil
                        selectedStatusFilter = .all
                        selectedDueFilter = .all
                    } label: {
                        Label("フィルターを解除", systemImage: "arrow.counterclockwise")
                    }
                }
            }
        } label: {
            WordListActionBarIcon(
                symbol: isFiltering
                    ? "line.3.horizontal.decrease.circle.fill"
                    : "line.3.horizontal.decrease.circle",
                isActive: isFiltering
            )
        }
        .accessibilityLabel("フィルター")
    }

    private var isFiltering: Bool {
        selectedTag != nil || selectedStatusFilter != .all || selectedDueFilter != .all
    }
}

struct WordListSortMenu: View {
    @Binding var selectedSort: WordSortOption

    var body: some View {
        Menu {
            ForEach(WordSortOption.allCases) { option in
                Button {
                    selectedSort = option
                } label: {
                    Label(option.title, systemImage: selectedSort == option ? "checkmark" : option.symbol)
                }
            }
        } label: {
            WordListActionBarIcon(
                symbol: "arrow.up.arrow.down",
                isActive: selectedSort != .registered
            )
        }
        .accessibilityLabel("並び替え")
    }
}

/// 浮動バーの中のボタン1つ分の見た目。シェルのタブと同じ丸ピル。
struct WordListActionBarIcon: View {
    let symbol: String
    let isActive: Bool

    var body: some View {
        Image(systemName: symbol)
            .wireFont(.label, color: .primary)
            .frame(minWidth: 48, minHeight: 48)
            .glassBarSelection(isActive, in: Capsule())
            .contentShape(Capsule())
    }
}

extension View {
    /// 浮動バー1本分のガラス面。
    func wordListBarChrome() -> some View {
        padding(WireMetrics.spacingM)
            .glassBarSurface(in: Capsule())
    }
}

/// 単語リストの上端に浮かべるガラスのパネル。進み具合のバーと、列を選ぶプルダウン。
/// 2列のときは左の列の右に×を置き、押すと列の追加か入れ替えを選べる。カード表示では列が無いので、`columns` を nil にしてバーだけ出す。
struct WordListColumnHeader: View {
    /// 0...1 の進み具合。
    let progress: Double
    var columns: Binding<[WordListColumn]>?

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            WordListProgressBar(progress: progress)

            if let columns {
                HStack(alignment: .top, spacing: WireMetrics.spacingS) {
                    columnMenu(columns, at: 0)
                    // 3列にしたあとは、追加も入れ替えも出さない。
                    if columns.wrappedValue.count < WordListColumn.maximumCount {
                        columnActionMenu(columns)
                    }
                    ForEach(1..<columns.wrappedValue.count, id: \.self) { index in
                        columnMenu(columns, at: index)
                    }
                }
                // 矢印はパネルの下の余白へはみ出させ、パネルの高さを変えない。
                .padding(.bottom, -SpeechBubbleShape.arrowHeight)
            }
        }
        .padding(WireMetrics.spacingM)
        .glassBarSurface(in: RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous))
    }

    private func columnMenu(_ columns: Binding<[WordListColumn]>, at index: Int) -> some View {
        let current = columns.wrappedValue[index]
        return Menu {
            ForEach(WordListColumn.allCases) { column in
                Button {
                    columns.wrappedValue = WordListColumn.choosing(column, at: index, in: columns.wrappedValue)
                } label: {
                    if current == column {
                        Label(column.title, systemImage: "checkmark")
                    } else {
                        Text(column.title)
                    }
                }
            }
            if columns.wrappedValue.count == WordListColumn.maximumCount {
                Divider()
                Button("列を削除", systemImage: "trash", role: .destructive) {
                    columns.wrappedValue = WordListColumn.removing(at: index, from: columns.wrappedValue)
                }
            }
        } label: {
            Text(current.title)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .wireFont(.label, color: .primary)
                .frame(maxWidth: .infinity, minHeight: 44)
                .padding(.bottom, SpeechBubbleShape.arrowHeight)
                .glassBarSelection(true, in: SpeechBubbleShape())
                .contentShape(SpeechBubbleShape())
        }
        .accessibilityLabel(Self.positionTitle(index: index, count: columns.wrappedValue.count))
        .accessibilityValue(current.title)
    }

    /// 2列のときだけ出す列の操作。「列を追加」はまだ出していない項目を真ん中に3列目として足し、
    /// 「列の入れ替え」は左右を入れ替える。
    private func columnActionMenu(_ columns: Binding<[WordListColumn]>) -> some View {
        Menu {
            Menu("列を追加", systemImage: "plus") {
                ForEach(WordListColumn.allCases.filter { !columns.wrappedValue.contains($0) }) { column in
                    Button(column.title) {
                        columns.wrappedValue = WordListColumn.adding(column, to: columns.wrappedValue)
                    }
                }
            }

            Button("列の入れ替え", systemImage: "arrow.left.arrow.right") {
                columns.wrappedValue = WordListColumn.rotatedLeft(columns.wrappedValue)
            }
        } label: {
            Image(systemName: "plus")
                .font(.body.weight(.bold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .glassBarSelection(true, in: Circle())
                .contentShape(Circle())
        }
        .accessibilityLabel("列の操作")
        .accessibilityValue(columns.wrappedValue.map(\.title).joined(separator: "、"))
    }

    private static func positionTitle(index: Int, count: Int) -> String {
        if index == 0 { return "左の列" }
        return index == count - 1 ? "右の列" : "真ん中の列"
    }
}

/// 列ボタンの吹き出しの形。丸いブロックの下の真ん中から、先の丸い矢印で下の列を指す。
/// 半透明で塗るので、ブロックと矢印を1つの形にまとめて重なりが濃くならないようにする。
struct SpeechBubbleShape: Shape {
    static let arrowWidth: CGFloat = 22
    static let arrowHeight: CGFloat = 8
    private static let tipRadius: CGFloat = 3

    func path(in rect: CGRect) -> Path {
        let bubble = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height - Self.arrowHeight)
        // 付け根をブロックへ少し埋めて、継ぎ目が出ないようにする。
        let baseY = bubble.maxY - 1
        let left = CGPoint(x: bubble.midX - Self.arrowWidth / 2, y: baseY)
        let right = CGPoint(x: bubble.midX + Self.arrowWidth / 2, y: baseY)
        var arrow = Path()
        arrow.move(to: left)
        arrow.addArc(tangent1End: CGPoint(x: bubble.midX, y: rect.maxY), tangent2End: right, radius: Self.tipRadius)
        arrow.addLine(to: right)
        arrow.closeSubpath()
        return Capsule().path(in: bubble).union(arrow)
    }
}

/// 上のパネルの進み具合。色相を使わず、墨の濃淡だけで示す。
struct WordListProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            Capsule()
                .fill(WireColor.ink.opacity(0.12))
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(WireColor.ink)
                        .frame(width: proxy.size.width * min(1, max(0, progress)))
                }
        }
        .frame(height: 8)
        .accessibilityElement()
        .accessibilityLabel("進み具合")
        .accessibilityValue("\(Int((min(1, max(0, progress)) * 100).rounded()))パーセント")
    }
}

/// 学習画面の上端に浮かべるヘッダー。戻るボタンと中身を2枚のガラスに分け、
/// iOS 26 ではガラス同士を溶け合わせて、ブリッジでつないだ1つの形に見せる。
/// 中身は進み具合のバーが基本で、学習状況の一覧ではデッキ名と枚数を載せる。
///
/// ponytail: iOS 17〜25 にはガラスの融合が無いので、すき間を空けた2枚の板になる。
/// 同じくびれを古いOSでも出すなら、2枚とつなぎ目を1つの Shape として描いて板にする。
struct StudyBridgeHeader<Center: View>: View {
    var isBackDisabled = false
    var backLabel = "学習に戻る"
    /// 中身を押したとき。nil なら押せない。
    var onCenterTap: (() -> Void)?
    var centerLabel = ""
    let onBack: () -> Void
    @ViewBuilder let center: Center

    private let height: CGFloat = 48

    var body: some View {
        bridge
            .padding(.horizontal, WireMetrics.screenPadding)
            .padding(.top, WireMetrics.spacingXS)
    }

    @ViewBuilder
    private var bridge: some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            // 2枚のすき間より広い間合いを渡すと、すき間がガラスのつなぎ目になる。
            GlassEffectContainer(spacing: WireMetrics.spacingXL) { segments }
        } else {
            segments
        }
        #else
        segments
        #endif
    }

    private var segments: some View {
        HStack(spacing: WireMetrics.spacingS) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .wireFont(.label, color: .primary)
                    .frame(width: height, height: height)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isBackDisabled)
            .glassBarSurface(in: Circle())
            .accessibilityLabel(backLabel)

            centerSegment
                .padding(.horizontal, WireMetrics.spacingL)
                .frame(maxWidth: .infinity)
                .frame(height: height)
                .glassBarSurface(in: Capsule())
        }
    }

    @ViewBuilder
    private var centerSegment: some View {
        if let onCenterTap {
            Button(action: onCenterTap) {
                center
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            // ponytail: VoiceOverは後日まとめて整える。今は押せることと行き先だけを出す。
            .accessibilityLabel(centerLabel)
        } else {
            center
        }
    }
}

extension StudyBridgeHeader where Center == WordListProgressBar {
    /// 進み具合のバーを載せる学習画面用。`onProgressTap` を渡すとバーから学習状況を開ける。
    init(
        progress: Double,
        isBackDisabled: Bool = false,
        onProgressTap: (() -> Void)? = nil,
        onBack: @escaping () -> Void
    ) {
        self.init(
            isBackDisabled: isBackDisabled,
            onCenterTap: onProgressTap,
            centerLabel: "学習状況を開く",
            onBack: onBack
        ) {
            WordListProgressBar(progress: progress)
        }
    }
}

