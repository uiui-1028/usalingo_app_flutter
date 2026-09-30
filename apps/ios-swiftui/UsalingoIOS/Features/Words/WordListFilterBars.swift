import SwiftUI

/// 表示切り替え（リスト / カード）。操作バーの横に、もう1本の小さなバーとして置く。
/// 選択中のアイコンを入口にして、メニューで表示形式を選ぶ。
struct WordListDisplayModeBar: View {
    @Binding var selectedMode: WordListDisplayMode

    var body: some View {
        Menu {
            ForEach(WordListDisplayMode.allCases) { mode in
                Button {
                    selectedMode = mode
                } label: {
                    Label(mode.title, systemImage: selectedMode == mode ? "checkmark" : mode.symbol)
                }
            }
        } label: {
            WordListActionBarIcon(symbol: selectedMode.symbol, isActive: false)
        }
        .accessibilityLabel("表示切り替え")
        .accessibilityValue(selectedMode.title)
        .wordListBarChrome()
    }
}

/// 画面下端に浮かべる2本のバー。左が絞り込み・並べ替え・検索、右が表示切り替え。
/// 検索を開いている間は、左のバーが横いっぱいに広がるので右のバーは引っ込める。
/// 赤シート中は左のバーを赤シートボタンだけに畳み、右に赤シート専用のバーを出す。
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

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: WireMetrics.spacingS) {
                actionBar
                trailingBar
            }
            VStack(spacing: WireMetrics.spacingS) {
                trailingBar
                actionBar
            }
        }
        .padding(.horizontal, WireMetrics.screenPadding)
        .padding(.bottom, WireMetrics.spacingXL)
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: isSearchExpanded)
    }

    private var actionBar: some View {
        WordListActionBar(
            tags: tags,
            selectedTag: $selectedTag,
            selectedStatusFilter: $selectedStatusFilter,
            selectedDueFilter: $selectedDueFilter,
            selectedSort: $selectedSort,
            searchText: $searchText,
            isSearchExpanded: $isSearchExpanded,
            isRedSheetEnabled: $isRedSheetEnabled,
            selectedDisplayMode: $selectedDisplayMode,
            canToggleRedSheet: canToggleRedSheet
        )
    }

    @ViewBuilder private var trailingBar: some View {
        if isRedSheetEnabled {
            redSheetActions
                .transition(.move(edge: .trailing).combined(with: .opacity))
        } else if !isSearchExpanded {
            WordListDisplayModeBar(selectedMode: $selectedDisplayMode)
        }
    }

}

/// 絞り込み・並べ替え・検索をひとまとめにした、画面下端の浮動バー。
/// シェルのタブバーと同じ形・同じ位置に置き、検索は押した時だけバーの中を広げる。
struct WordListActionBar: View {
    let tags: [String]
    @Binding var selectedTag: String?
    @Binding var selectedStatusFilter: WordStatusFilter
    @Binding var selectedDueFilter: WordDueFilter
    @Binding var selectedSort: WordSortOption
    @Binding var searchText: String
    @Binding var isSearchExpanded: Bool
    @Binding var isRedSheetEnabled: Bool
    @Binding var selectedDisplayMode: WordListDisplayMode
    let canToggleRedSheet: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        HStack(spacing: WireMetrics.spacingS) {
            if !isSearchExpanded && !isRedSheetEnabled {
                WordListFilterMenu(
                    tags: tags,
                    selectedTag: $selectedTag,
                    selectedStatusFilter: $selectedStatusFilter,
                    selectedDueFilter: $selectedDueFilter
                )

                WordListSortMenu(selectedSort: $selectedSort)
            }

            if !isSearchExpanded {
                Button {
                    if !isRedSheetEnabled { selectedDisplayMode = .list }
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
                .disabled(!canToggleRedSheet)
                .accessibilityLabel("赤シート")
                .accessibilityValue(isRedSheetEnabled ? "オン" : "オフ")
                .accessibilityHint("意味欄を隠すシートを切り替えます")
            }

            if !isRedSheetEnabled {
                searchControl
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

/// 単語リストの上端に浮かべるガラスのパネル。進み具合のバーと、左右の列を選ぶプルダウン。
/// カード表示では列が無いので、`columns` を nil にしてバーだけ出す。
struct WordListColumnHeader: View {
    /// 0...1 の進み具合。
    let progress: Double
    var columns: (left: Binding<WordListColumn>, right: Binding<WordListColumn>)?

    var body: some View {
        VStack(spacing: WireMetrics.spacingS) {
            WordListProgressBar(progress: progress)

            if let columns {
                HStack(spacing: WireMetrics.spacingS) {
                    columnMenu(columns.left, onLeft: true, other: columns.right)
                    columnMenu(columns.right, onLeft: false, other: columns.left)
                }
            }
        }
        .padding(WireMetrics.spacingM)
        .glassBarSurface(in: RoundedRectangle(cornerRadius: WireMetrics.radiusLarge, style: .continuous))
    }

    private func columnMenu(
        _ selection: Binding<WordListColumn>,
        onLeft: Bool,
        other: Binding<WordListColumn>
    ) -> some View {
        Menu {
            ForEach(WordListColumn.allCases) { column in
                Button {
                    let left = onLeft ? selection.wrappedValue : other.wrappedValue
                    let right = onLeft ? other.wrappedValue : selection.wrappedValue
                    let chosen = WordListColumn.choosing(column, onLeft: onLeft, left: left, right: right)
                    selection.wrappedValue = onLeft ? chosen.left : chosen.right
                    other.wrappedValue = onLeft ? chosen.right : chosen.left
                } label: {
                    if selection.wrappedValue == column {
                        Label(column.title, systemImage: "checkmark")
                    } else {
                        Text(column.title)
                    }
                }
            }
        } label: {
            HStack(spacing: WireMetrics.spacingXS) {
                Text(selection.wrappedValue.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .accessibilityHidden(true)
            }
            .wireFont(.label, color: .primary)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassBarSelection(true, in: Capsule())
            .contentShape(Capsule())
        }
        .accessibilityLabel(onLeft ? "左の列" : "右の列")
        .accessibilityValue(selection.wrappedValue.title)
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
