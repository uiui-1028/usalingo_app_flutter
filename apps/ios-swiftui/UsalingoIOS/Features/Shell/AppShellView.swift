import SwiftUI

/// 学習画面を土台にした外枠。下の純正タブバーで遊び方を選び、Design と Profile は上の左右のボタンからシートで開く。
struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @State private var openedScreen: ShellScreen?
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card

    var body: some View {
        LearningDashboardView()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !appState.isShellChromeHidden {
                    PlayStyleTabBar(selection: $playStyle)
                        // 古いOSのバーの地を、ホームインジケータの下まで伸ばす。
                        .ignoresSafeArea(edges: .bottom)
                        .background { bottomFade }
                }
            }
            // 名前の変更などでキーボードが出ても、遊び方のバーを押し上げずにキーボードの裏へ残す。
            // 子画面を開いている間（バーを隠している間）は、入力欄がキーボードをよけられるよう効かせない。
            .ignoresSafeArea(.keyboard, edges: appState.isShellChromeHidden ? [] : .bottom)
            .overlay(alignment: .top) {
                if !appState.isShellChromeHidden {
                    HStack {
                        screenButton(.design)
                        Spacer()
                        screenButton(.profile)
                    }
                    .padding(.horizontal, WireMetrics.screenPadding)
                }
            }
            .sheet(item: $openedScreen) { screen in
                switch screen {
                case .design: DesignDashboardView()
                case .profile: ProfileDashboardView()
                }
            }
    }

    /// 重なるデッキでバーが見えにくくならないよう、バーの少し上から画面の下端へ、すりガラスと遊び方の地の色を薄く敷く。
    /// ponytail: すりガラスはぼかしの強さが一定で、見える量だけを下へ増やす。下ほど強くぼかすには
    /// デッキ一覧へシェーダーが要るが、フォルダの中の ScrollView（UIKit）がシェーダーで描けないので見送った。
    private var bottomFade: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
            .overlay(
                LinearGradient(
                    colors: [playStyle.background.opacity(0), playStyle.background.opacity(0.6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                // 学習画面の下地と同じ速さで色を変える。
                .animation(.easeOut(duration: 0.2), value: playStyle)
            )
            .padding(.top, -WireMetrics.spacingXL)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func screenButton(_ screen: ShellScreen) -> some View {
        Button {
            openedScreen = screen
        } label: {
            Image(systemName: screen.symbol)
                .font(.system(size: 20))
                .foregroundStyle(WireColor.ink)
                .frame(width: 44, height: 44)
                .glassBarSurface(in: Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(screen.rawValue)
    }
}

/// 学習画面の上から開く画面。
enum ShellScreen: String, Identifiable {
    case design = "Design"
    case profile = "Profile"

    var id: Self { self }

    var symbol: String {
        switch self {
        case .design: return "paintpalette"
        case .profile: return "person.crop.circle"
        }
    }
}

/// 遊び方を選ぶ純正のタブバー。画面は切り替えず、選んだ遊び方を返すだけ。iOS 26 からはシステムが Liquid Glass で描く。
/// TabView にすると遊び方ごとに学習画面が別々に作られ、開いたフォルダや並びの状態を保てないため、バーだけを使う。
/// ponytail: 単体の UITabBar には、後ろを流れる内容をぼかす効果（スクロール端の効果）が付かない。デッキ一覧は
/// スクロールビューではないので今は困らない。要るなら学習画面の状態を親へ持ち上げて TabView に替える。
struct PlayStyleTabBar: UIViewRepresentable {
    @Binding var selection: DeckPlayStyle

    func makeUIView(context: Context) -> UITabBar {
        let tabBar = UITabBar()
        tabBar.items = DeckPlayStyle.allCases.enumerated().map { index, style in
            UITabBarItem(title: style.title, image: UIImage(systemName: style.symbol), tag: index)
        }
        tabBar.tintColor = UIColor(WireColor.ink)
        tabBar.delegate = context.coordinator
        return tabBar
    }

    func updateUIView(_ tabBar: UITabBar, context: Context) {
        context.coordinator.selection = $selection
        let index = DeckPlayStyle.allCases.firstIndex(of: selection) ?? 0
        if tabBar.selectedItem?.tag != index {
            tabBar.selectedItem = tabBar.items?[index]
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITabBar, context: Context) -> CGSize? {
        guard let width = proposal.width else { return nil }
        let height = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        return CGSize(width: width, height: height)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selection: $selection)
    }

    final class Coordinator: NSObject, UITabBarDelegate {
        var selection: Binding<DeckPlayStyle>

        init(selection: Binding<DeckPlayStyle>) {
            self.selection = selection
        }

        func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
            selection.wrappedValue = DeckPlayStyle.allCases[item.tag]
        }
    }
}

/// 選択枠が指の下へ滑って来る、横に等分したセグメント。デッキ追加画面のジャンルで使う。
/// 固定した等分の領域で、表示位置と選択判定をそろえる。地の面と高さは使う側が決める。
struct SegmentSlider<Item: Hashable, Label: View>: View {
    let items: [Item]
    @Binding var selection: Item
    /// 支援技術で読み上げる名前。
    let title: (Item) -> String
    @ViewBuilder let label: (Item) -> Label

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @GestureState private var isTouchActive = false
    @State private var drag: DragGesture.Value?
    @State private var dragOrigin: Int?
    @State private var hapticIndex: Int?

    var body: some View {
        GeometryReader { geometry in
            let selectedIndex = items.firstIndex(of: selection) ?? 0
            let itemWidth = geometry.size.width / CGFloat(max(items.count, 1))
            let canDrag = dragOrigin != nil
            let translation = canDrag ? (drag?.translation.width ?? 0) : 0
            let indicatorX = min(max(CGFloat(dragOrigin ?? selectedIndex) * itemWidth + translation, 0), geometry.size.width - itemWidth)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(WireColor.ink.opacity(0.16))
                    .overlay(Capsule().strokeBorder(WireColor.ink, lineWidth: 1))
                    .frame(width: itemWidth)
                    .offset(x: indicatorX)
                    // @AppStorage の書き換えは withAnimation の外で描き直されることがあるので、
                    // 選択が変わったときの移動はここでも必ず滑らかにする。
                    .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82), value: selection)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)

                HStack(spacing: 0) {
                    ForEach(items, id: \.self) { item in
                        Button {
                            selection = item
                        } label: {
                            label(item)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(title(item))
                        .accessibilityAddTraits(selection == item ? .isSelected : [])
                    }
                }
            }
            .contentShape(Rectangle())
            // タッチはバー全体で一度だけ確定する。各Buttonは支援技術からの選択にも使う。
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isTouchActive) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        // 追従は短く、弾ませずにわずかな柔らかさだけを付ける。
                        withAnimation(reduceMotion ? nil : .interactiveSpring(response: 0.16, dampingFraction: 1, blendDuration: 0.08)) {
                            if drag == nil {
                                // タブバーと同じく、どの項目から触れても選択枠がその指の下へ滑って来て、
                                // そのまま横へ滑らせて選べる。
                                dragOrigin = PlayStyleBarHitTest.index(at: value.startLocation, size: geometry.size, count: items.count)
                                hapticIndex = selectedIndex
                            }
                            drag = value
                        }
                        if dragOrigin != nil,
                           let candidate = PlayStyleBarHitTest.nearestIndex(atX: value.location.x, width: geometry.size.width, count: items.count),
                           candidate != hapticIndex {
                            HapticFeedbackService.detent()
                            hapticIndex = candidate
                        }
                    }
                    .onEnded { value in
                        let index = PlayStyleBarHitTest.selection(
                            from: value.startLocation, to: value.location, size: geometry.size, count: items.count
                        )
                        // 確定先へ吸い付いた最後だけ、ごく小さく弾ませる。
                        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82)) {
                            if let index { selection = items[index] }
                            clearDrag()
                        }
                    }
            )
            .onChange(of: isTouchActive) { _, active in
                // システムによるジェスチャー中断では onEnded が呼ばれない。
                if !active, drag != nil {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        clearDrag()
                    }
                }
            }
        }
    }

    private func clearDrag() {
        drag = nil
        dragOrigin = nil
        hapticIndex = nil
    }
}

enum PlayStyleBarHitTest {
    static func index(at point: CGPoint, size: CGSize, count: Int) -> Int? {
        guard count > 0, size.width > 0, size.height > 0,
              point.x.isFinite, point.y.isFinite,
              CGRect(origin: .zero, size: size).contains(point) else { return nil }
        return min(Int(point.x / (size.width / CGFloat(count))), count - 1)
    }

    /// バーの中で触れ始めたら、どのアイコンからでも、離した横位置にいちばん近いアイコンを選ぶ。
    /// バーを上下に離れても横位置だけで決める。
    static func selection(from start: CGPoint, to end: CGPoint, size: CGSize, count: Int) -> Int? {
        guard index(at: start, size: size, count: count) != nil else { return nil }
        return nearestIndex(atX: end.x, width: size.width, count: count)
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
