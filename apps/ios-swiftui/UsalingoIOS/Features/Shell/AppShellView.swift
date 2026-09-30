import SwiftUI

struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selectedTab = 1
    @State private var isTabBarHiddenByScroll = false
    @State private var previousVerticalDragTranslation: CGFloat?
    @GestureState private var isPlayStyleTouchActive = false
    @State private var playStyleDrag: DragGesture.Value?
    @State private var playStyleDragOrigin: Int?
    @State private var playStyleHapticIndex: Int?
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card

    var body: some View {
        TabView(selection: $selectedTab) {
            DesignDashboardView()
                .tabItem { Label("Design", systemImage: "paintpalette") }
                .tag(0)
                .glassTabBar(tabBarVisibility)

            LearningDashboardView()
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if !appState.isShellChromeHidden {
                        playStyleBar
                            .padding(.horizontal, WireMetrics.screenPadding)
                            .padding(.bottom, WireMetrics.spacingM)
                    }
                }
                .tabItem { Label("Game", systemImage: "bolt") }
                .tag(1)
                .glassTabBar(tabBarVisibility)

            ProfileDashboardView(onScrollDrag: updateTabBarVisibility)
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
                .tag(2)
                .glassTabBar(tabBarVisibility)
        }
        .onChange(of: selectedTab) { _, _ in
            isTabBarHiddenByScroll = false
            previousVerticalDragTranslation = nil
        }
        .onChange(of: appState.isShellChromeHidden) { _, isHidden in
            previousVerticalDragTranslation = nil
            if !isHidden {
                isTabBarHiddenByScroll = false
            }
        }
    }

    private var tabBarVisibility: Visibility {
        appState.isShellChromeHidden || isTabBarHiddenByScroll ? .hidden : .visible
    }

    private func updateTabBarVisibility(_ value: DragGesture.Value?) {
        guard let value else {
            previousVerticalDragTranslation = nil
            return
        }
        // 横スクロール（保存済みコンセプトなど）の僅かな縦ブレでは反応しない。
        guard abs(value.translation.height) > abs(value.translation.width) else {
            previousVerticalDragTranslation = nil
            return
        }

        defer { previousVerticalDragTranslation = value.translation.height }
        guard let previousVerticalDragTranslation else { return }

        let verticalMovement = value.translation.height - previousVerticalDragTranslation
        guard abs(verticalMovement) > 0.5 else { return }
        isTabBarHiddenByScroll = verticalMovement < 0
    }

    /// 固定した5等分の領域で、表示位置と選択判定をそろえる。
    private var playStyleBar: some View {
        GeometryReader { geometry in
            let styles = DeckPlayStyle.allCases
            let selectedIndex = styles.firstIndex(of: playStyle) ?? 0
            let itemWidth = geometry.size.width / CGFloat(styles.count)
            let canDrag = playStyleDragOrigin != nil
            let translation = canDrag ? (playStyleDrag?.translation.width ?? 0) : 0
            let indicatorX = min(max(CGFloat(playStyleDragOrigin ?? selectedIndex) * itemWidth + translation, 0), geometry.size.width - itemWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WireColor.ink.opacity(0.16))
                    .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: 1))
                    .frame(width: itemWidth)
                    .offset(x: indicatorX)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(styles) { style in
                        Button {
                            playStyle = style
                        } label: {
                            Image(systemName: style.symbol)
                                .font(.system(size: 20))
                                .foregroundStyle(WireColor.ink)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(style.title)
                        .accessibilityAddTraits(playStyle == style ? .isSelected : [])
                    }
                }
            }
            .contentShape(Rectangle())
            // タッチはバー全体で一度だけ確定する。各Buttonは支援技術からの選択にも使う。
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPlayStyleTouchActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        if playStyleDrag == nil {
                            let start = PlayStyleBarHitTest.index(at: value.startLocation, size: geometry.size, count: styles.count)
                            playStyleDragOrigin = start == selectedIndex ? selectedIndex : nil
                            playStyleHapticIndex = selectedIndex
                        }
                        // 追従は短く、弾ませずにわずかな柔らかさだけを付ける。
                        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.16, dampingFraction: 1, blendDuration: 0.08)) {
                            playStyleDrag = value
                        }
                        if playStyleDragOrigin != nil,
                           let candidate = PlayStyleBarHitTest.nearestIndex(atX: value.location.x, width: geometry.size.width, count: styles.count),
                           candidate != playStyleHapticIndex {
                            HapticFeedbackService.detent()
                            playStyleHapticIndex = candidate
                        }
                    }
                    .onEnded { value in
                        let index = PlayStyleBarHitTest.selection(
                            from: value.startLocation, to: value.location,
                            selectedIndex: playStyleDragOrigin ?? selectedIndex, size: geometry.size, count: styles.count
                        )
                        // 確定先へ吸い付いた最後だけ、ごく小さく弾ませる。
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                            if let index { playStyle = styles[index] }
                            clearPlayStyleDrag()
                        }
                    }
            )
            .onChange(of: isPlayStyleTouchActive) { _, active in
                // システムによるジェスチャー中断では onEnded が呼ばれない。
                if !active, playStyleDrag != nil {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        clearPlayStyleDrag()
                    }
                }
            }
        }
        .frame(height: 48)
        .padding(WireMetrics.spacingXS)
        .background(WireColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: 1))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("デッキの遊び方")
    }

    private func clearPlayStyleDrag() {
        playStyleDrag = nil
        playStyleDragOrigin = nil
        playStyleHapticIndex = nil
    }
}

enum PlayStyleBarHitTest {
    static func index(at point: CGPoint, size: CGSize, count: Int) -> Int? {
        guard count > 0, size.width > 0, size.height > 0,
              point.x.isFinite, point.y.isFinite,
              CGRect(origin: .zero, size: size).contains(point) else { return nil }
        return min(Int(point.x / (size.width / CGFloat(count))), count - 1)
    }

    static func selection(from start: CGPoint, to end: CGPoint, selectedIndex: Int, size: CGSize, count: Int) -> Int? {
        guard let startIndex = index(at: start, size: size, count: count) else { return nil }
        // 選択中から始めたドラッグは、バーを上下に離れても横位置だけで確定する。
        if startIndex == selectedIndex {
            return nearestIndex(atX: end.x, width: size.width, count: count)
        }
        guard let endIndex = index(at: end, size: size, count: count) else { return nil }
        if hypot(end.x - start.x, end.y - start.y) < 5 {
            return startIndex == endIndex ? endIndex : nil
        }
        return nil
    }

    static func nearestIndex(atX x: CGFloat, width: CGFloat, count: Int) -> Int? {
        guard count > 0, width.isFinite, width > 0, x.isFinite else { return nil }
        let clampedX = min(max(x, 0), width)
        return min(Int(clampedX / (width / CGFloat(count))), count - 1)
    }
}

#if DEBUG
#Preview("App Shell") {
    AppShellView()
        .environmentObject(AppState.preview)
        .environmentObject(DesignSettings())
}
#endif
