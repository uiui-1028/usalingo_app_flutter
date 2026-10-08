import SwiftUI

/// 学習画面を土台にした外枠。下の純正タブバーで遊び方を選ぶ。
/// 学習画面を横になぞるか、上の左右のボタンを押すと、学習画面が横へずれて、左から Design、右から Profile のメニューが出てくる。
struct AppShellView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// 開き終えている引き出し。
    @State private var openedScreen: ShellScreen?
    /// 学習画面の裏に見せている引き出し。閉じる動きが終わるまで残す。
    @State private var revealedScreen: ShellScreen?
    /// 一度開いた引き出し。閉じても片付けずに裏へ残し、次はすぐ出せるようにする。
    @State private var loadedScreens: Set<ShellScreen> = []
    /// 横になぞっている間の指の移動量。
    @State private var dragWidth: CGFloat?
    /// なぞり始めの向きで、横（引き出し）か縦（デッキを回す）かを一度だけ決める。
    @State private var isHorizontalDrag: Bool?
    @GestureState private var isTouching = false
    @AppStorage(DeckPlayStyle.storageKey) private var playStyle: DeckPlayStyle = .card

    var body: some View {
        GeometryReader { proxy in
            // 学習画面の端を少し残し、そこを押せば戻れるようにする。
            let panelWidth = proxy.size.width * 0.85
            let offset = contentOffset(translation: dragWidth ?? 0, panelWidth: panelWidth)

            ZStack {
                ForEach(ShellScreen.allCases, id: \.self) { screen in
                    if loadedScreens.contains(screen) {
                        let isRevealed = revealedScreen == screen
                        panel(screen)
                            .frame(width: panelWidth)
                            .frame(maxWidth: .infinity, alignment: screen == .design ? .leading : .trailing)
                            .opacity(isRevealed ? 1 : 0)
                            .allowsHitTesting(isRevealed)
                            .accessibilityHidden(!isRevealed)
                    }
                }

                learningScreen(topInset: proxy.safeAreaInsets.top)
                    .overlay {
                        if openedScreen != nil {
                            // ponytail: VoiceOver は戻るボタンだけ用意し、ずれた学習画面の中身を隠す調整は後でまとめて行う。
                            Button {
                                setOpenedScreen(nil)
                            } label: {
                                Color.clear.contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("学習画面に戻る")
                        }
                    }
                    // ずれた量に応じて、端末の角に合わせて丸め、影を付ける。
                    // 影は学習画面ごと描き直さずに済むよう、裏に敷いた形だけに付ける。
                    .mask {
                        RoundedRectangle(cornerRadius: min(abs(offset) / 3, 40), style: .continuous)
                            .ignoresSafeArea()
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 40, style: .continuous)
                            .fill(WireColor.background)
                            .shadow(color: .black.opacity(0.18), radius: 24)
                            .opacity(offset == 0 ? 0 : 1)
                            .ignoresSafeArea()
                    }
                    .offset(x: offset)
            }
            // 学習画面の上でも引き出しの上でも、横になぞって開け閉めできる。
            // 子画面を開いている間（バーを隠している間）は、横になぞっても開かない。
            .simultaneousGesture(drawerDrag(panelWidth: panelWidth),
                                 including: appState.isShellChromeHidden ? .subviews : .all)
        }
        // 名前の変更などでキーボードが出ても、遊び方のバーを押し上げずにキーボードの裏へ残す。
        // 子画面を開いている間（バーを隠している間）は、入力欄がキーボードをよけられるよう効かせない。
        .ignoresSafeArea(.keyboard, edges: appState.isShellChromeHidden ? [] : .bottom)
        .background(WireColor.background.ignoresSafeArea())
        .onChange(of: isTouching) { _, touching in
            // システムによるジェスチャー中断では onEnded が呼ばれないので、いまの開き具合へ戻す。
            if !touching, isHorizontalDrag != nil {
                isHorizontalDrag = nil
                if dragWidth != nil { setOpenedScreen(openedScreen) }
            }
        }
        // ログアウトや退会で利用者がいなくなったら、引き出しを閉じて、ログインや退会のお知らせを出せるようにする。
        .onChange(of: appState.session == nil) { _, isSignedOut in
            if isSignedOut { setOpenedScreen(nil) }
        }
    }

    private func learningScreen(topInset: CGFloat) -> some View {
        LearningDashboardView(topControls: AnyView(topControls.padding(.top, topInset)))
            // 引き出しを開いている間は、残った端を押しても学習画面の中身が反応せず、戻るボタンだけが受ける。
            .allowsHitTesting(openedScreen == nil)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !appState.isShellChromeHidden {
                    PlayStyleTabBar(selection: $playStyle)
                        // 古いOSのバーの地を、ホームインジケータの下まで伸ばす。
                        .ignoresSafeArea(edges: .bottom)
                        .background { bottomFade }
                }
            }
    }

    @ViewBuilder
    private var topControls: some View {
        if !appState.isShellChromeHidden {
            HStack {
                screenButton(.design)
                Spacer()
                screenButton(.profile)
            }
            .padding(.horizontal, WireMetrics.screenPadding)
        }
    }

    @ViewBuilder
    private func panel(_ screen: ShellScreen) -> some View {
        switch screen {
        case .design: DesignDashboardView()
        case .profile: ProfileDashboardView()
        }
    }

    // MARK: - 引き出しを動かす

    private func drawerDrag(panelWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .updating($isTouching) { _, state, _ in
                state = true
            }
            .onChanged { value in
                if isHorizontalDrag == nil {
                    isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                }
                guard isHorizontalDrag == true else { return }
                dragWidth = value.translation.width
                let offset = contentOffset(translation: value.translation.width, panelWidth: panelWidth)
                if offset != 0 { reveal(offset > 0 ? .design : .profile) }
            }
            .onEnded { value in
                defer { isHorizontalDrag = nil }
                guard isHorizontalDrag == true else { return }
                let offset = contentOffset(translation: value.predictedEndTranslation.width, panelWidth: panelWidth)
                setOpenedScreen(restingScreen(at: offset, panelWidth: panelWidth))
            }
    }

    /// 学習画面をずらす量。左の Design を出すときは右へ、右の Profile を出すときは左へずらす。
    /// 開いている側からは、反対側の引き出しへ一度に飛び越えない。
    private func contentOffset(translation: CGFloat, panelWidth: CGFloat) -> CGFloat {
        let base = (openedScreen?.direction ?? 0) * panelWidth
        let lower: CGFloat = openedScreen == .design ? 0 : -panelWidth
        let upper: CGFloat = openedScreen == .profile ? 0 : panelWidth
        return min(max(base + translation, lower), upper)
    }

    /// 指を離したあとに落ち着く先。開くのも閉じるのも、引き出しの幅の3分の1を超えて動かせば切り替える。
    private func restingScreen(at offset: CGFloat, panelWidth: CGFloat) -> ShellScreen? {
        if let openedScreen {
            return abs(offset) > panelWidth * 2 / 3 ? openedScreen : nil
        }
        guard abs(offset) > panelWidth / 3 else { return nil }
        return offset > 0 ? .design : .profile
    }

    private func reveal(_ screen: ShellScreen) {
        revealedScreen = screen
        loadedScreens.insert(screen)
    }

    private func setOpenedScreen(_ screen: ShellScreen?) {
        if let screen { reveal(screen) }
        let hidePanel = {
            if openedScreen == nil, dragWidth == nil { revealedScreen = nil }
        }
        guard !reduceMotion else {
            openedScreen = screen
            dragWidth = nil
            hidePanel()
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.86)) {
            openedScreen = screen
            dragWidth = nil
        } completion: {
            hidePanel()
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
            setOpenedScreen(openedScreen == screen ? nil : screen)
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

/// 学習画面の左右から出すメニュー。
enum ShellScreen: String, CaseIterable {
    case design = "Design"
    case profile = "Profile"

    var symbol: String {
        switch self {
        case .design: return "paintpalette"
        case .profile: return "person.crop.circle"
        }
    }

    /// 引き出しを出すときに学習画面をずらす向き。
    var direction: CGFloat {
        self == .design ? 1 : -1
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
