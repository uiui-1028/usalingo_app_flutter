import SwiftUI
import UIKit

@main
struct UsalingoIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState(mediaDownloader: .shared)
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.designSettings)
                .tint(WireColor.ink)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    appState.handleIncomingURL(url)
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    await appState.refreshOfficialContentIfConnected()
                    await appState.maintainForegroundConnection()
                }
                .onChange(of: scenePhase) { _, phase in
                    guard phase != .active else { return }
                    appState.pauseStudyBackup()
                }
        }
    }
}

/// iOS からの知らせのうち、SwiftUI の `App` では受け取れないものだけを受ける。
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // 以前の音声の一時キャッシュ（最大100MB）は使わなくなったので、裏で片付ける（要件 C1）。
        Task.detached(priority: .utility) { CardAudioCache.removeLegacyStorage() }
        return true
    }

    /// 閉じている間に画像・音声のダウンロードが進んだとき、iOS がアプリを裏で起こして知らせる（要件 D4）。
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == MediaDownloader.sessionIdentifier else {
            completionHandler()
            return
        }
        MediaDownloader.shared.handleBackgroundEvents(completionHandler)
    }
}

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    @State private var showsConnectionDetail = false
    @State private var showsSignIn = false

    var body: some View {
        ZStack {
            if appState.isResettingPassword {
                PasswordResetView()
            } else {
                AppShellView()
                    .overlay(alignment: .top) {
                        if appState.startupMessage != nil {
                            Button(appState.requiresSignIn ? "ログインが必要です" : "接続を確認してください") {
                                showsConnectionDetail = true
                            }
                            .wireFont(.caption)
                            .padding(WireMetrics.spacingS)
                            .background(WireColor.groupL3, in: Capsule())
                            // ponytail: VoiceOverの詳細案内は後日。主ボタンの標準ラベルだけ使う。
                        }
                    }
            }
        }
        .onChange(of: appState.requiresSignIn) { _, required in
            if !required { showsSignIn = false }
        }
        .sheet(isPresented: $showsSignIn) {
            AuthView()
                .environmentObject(appState)
        }
        .alert("接続について", isPresented: $showsConnectionDetail) {
            if appState.requiresSignIn {
                Button("ログイン") { showsSignIn = true }
            } else {
                Button("再試行") { Task { await appState.retryStartup() } }
            }
            Button("閉じる", role: .cancel) { }
        } message: {
            Text(appState.startupMessage ?? "接続は回復しました。")
        }
        .alert("アカウントを削除しました", isPresented: Binding(
            get: { appState.accountDeletionNotice != nil },
            set: { if !$0 { appState.clearAccountDeletionNotice() } }
        )) {
            Button("確認") { appState.clearAccountDeletionNotice() }
        } message: {
            Text(appState.accountDeletionNotice ?? "")
        }
    }
}

private struct PasswordResetView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var confirmation = ""
    @State private var message = ""
    @State private var isSaving = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(spacing: WireMetrics.spacingXL) {
                    VStack(spacing: WireMetrics.spacingS) {
                        Text("新しいパスワード")
                            .wireFont(.titleL)
                        Text("8文字以上で入力してください。")
                            .wireFont(.caption)
                    }
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                    VStack(spacing: WireMetrics.spacingM) {
                        WireFieldBox {
                            SecureField("新しいパスワード", text: $password)
                        }
                        WireFieldBox {
                            SecureField("もう一度入力", text: $confirmation)
                        }
                    }

                    Button("パスワードを保存") {
                        Task { await save() }
                    }
                    .buttonStyle(.wirePrimary)
                    .disabled(isSaving)

                    if !message.isEmpty {
                        // 色相を使わずに異常を示す（破線 + 文言）。
                        Text(message)
                            .wireFont(.caption)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(WireMetrics.spacingM)
                            .outlineSurface(
                                radius: WireMetrics.radiusControl,
                                shadow: nil,
                                dashed: true
                            )
                    }
                }
                .padding(WireMetrics.screenPadding)
                .frame(maxWidth: .infinity)
                .frame(minHeight: proxy.size.height, alignment: .center)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background(WireColor.background)
    }

    private func save() async {
        isSaving = true
        defer { isSaving = false }
        do {
            try await appState.setRecoveredPassword(password, confirmation: confirmation)
        } catch {
            message = UserFacingError.message(for: error)
        }
    }
}
