import SwiftUI
import UIKit

/// 左へ開き、深く引くと休止／再開する。右向きは閉じるときだけ受け、戻る操作へ譲る。
enum WordRowSwipe {
    static let buttonWidth: CGFloat = 76
    static let revealWidth: CGFloat = buttonWidth * 2
    static func commits(offset: CGFloat, width: CGFloat) -> Bool {
        -offset >= max(revealWidth + 40, width * 0.65)
    }
}

struct WordRowActions<Content: View>: View {
    let word: WordCard
    @Binding var openedID: Int?
    let isDisabled: Bool
    let onTap: (CGPoint) -> Void
    let onSuspend: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let onHold: (CGRect, CGPoint) -> Void
    let onHoldMove: (CGPoint) -> Void
    /// 長押しを終えた。指を離したときは true、システムに取り上げられたときは false。
    let onHoldEnd: (Bool) -> Void
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragOffset: CGFloat?
    @State private var dragStart: CGFloat = 0
    @State private var crossedThreshold = false
    private var offset: CGFloat { dragOffset ?? (openedID == word.id ? -WordRowSwipe.revealWidth : 0) }

    var body: some View {
        content
            .overlay {
                WordRowTouchSurface(isDisabled: isDisabled, isOpen: openedID == word.id,
                    onTap: { point in
                        if openedID != nil { close() } else { onTap(point) }
                    },
                    onPan: handlePan,
                    onHold: { frame, point, _ in close(); onHold(frame, point) },
                    onHoldMove: onHoldMove, onHoldEnd: onHoldEnd)
                .accessibilityHidden(true)
            }
            .offset(x: offset)
            .background(alignment: .trailing) {
                if offset < 0 {
                    GeometryReader { proxy in
                        let committed = WordRowSwipe.commits(offset: offset, width: proxy.size.width)
                        HStack(spacing: 0) {
                            if !committed {
                                action("削除", image: "trash", color: .red, action: onDelete)
                            }
                            action(word.isSuspended ? "再開" : "休止",
                                   image: word.isSuspended ? "play.fill" : "pause.fill",
                                   color: Color(white: 0.35), action: onSuspend)
                                .frame(maxWidth: committed ? .infinity : nil)
                        }
                        .frame(width: max(0, -offset), height: proxy.size.height, alignment: .trailing)
                        .clipped()
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .clipped()
            .onChange(of: openedID) { _, id in
                if id != word.id { dragOffset = nil }
            }
            // ponytail: 主操作のラベルと起動だけを用意。支援技術の詳細な調整は後でまとめる。
            .accessibilityAction(named: word.isSuspended ? "再開" : "休止", onSuspend)
            .accessibilityAction(named: "削除", onDelete)
            .accessibilityAction(named: "編集", onEdit)
            .accessibilityAction { onTap(.zero) }
    }

    private func action(_ title: String, image: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            close()
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: image).accessibilityHidden(true)
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(minWidth: WordRowSwipe.buttonWidth, maxWidth: .infinity, maxHeight: .infinity)
            .background(color)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }

    private func close() {
        withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
            dragOffset = nil
            openedID = nil
        }
    }

    private func handlePan(_ translation: CGFloat, _ width: CGFloat, _ state: UIGestureRecognizer.State) {
        switch state {
        case .began:
            dragStart = openedID == word.id ? -WordRowSwipe.revealWidth : 0
            openedID = word.id
            crossedThreshold = false
            dragOffset = min(0, max(-width, dragStart + translation))
        case .changed:
            dragOffset = min(0, max(-width, dragStart + translation))
            let crossed = WordRowSwipe.commits(offset: offset, width: width)
            if crossed && !crossedThreshold { HapticFeedbackService.detent() }
            crossedThreshold = crossed
        case .ended:
            let commit = WordRowSwipe.commits(offset: offset, width: width)
            let reveal = -offset >= WordRowSwipe.buttonWidth
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) {
                dragOffset = nil
                openedID = !commit && reveal ? word.id : nil
            }
            if commit { onSuspend() }
        default:
            close()
        }
    }
}

/// UIKit が最初に横方向を判定するので、縦スクロールと戻るスワイプを横操作で奪わない。
struct WordRowTouchSurface: UIViewRepresentable {
    let isDisabled: Bool
    let isOpen: Bool
    let onTap: (CGPoint) -> Void
    var onPan: ((CGFloat, CGFloat, UIGestureRecognizer.State) -> Void)? = nil
    let onHold: (CGRect, CGPoint, CGRect) -> Void
    let onHoldMove: (CGPoint) -> Void
    /// 長押しを終えた。指を離したときは true、システムに取り上げられたときは false。
    let onHoldEnd: (Bool) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let coordinator = context.coordinator
        let hold = UILongPressGestureRecognizer(target: coordinator, action: #selector(Coordinator.hold(_:)))
        hold.minimumPressDuration = 0.35
        hold.delegate = coordinator
        let tap = UITapGestureRecognizer(target: coordinator, action: #selector(Coordinator.tap(_:)))
        // カード一覧では横操作を登録せず、スクロールと戻るスワイプへ譲る。
        if onPan != nil {
            let pan = UIPanGestureRecognizer(target: coordinator, action: #selector(Coordinator.pan(_:)))
            pan.delegate = coordinator
            tap.require(toFail: pan)
            view.addGestureRecognizer(pan)
        }
        tap.require(toFail: hold)
        view.addGestureRecognizer(hold)
        view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.parent = self
        // 回答保存中も通常のタップで次を判定できる。保存待ちは横操作と長押しだけ保留する。
        uiView.isUserInteractionEnabled = true
    }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var parent: WordRowTouchSurface
        init(_ parent: WordRowTouchSurface) { self.parent = parent }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard !parent.isDisabled else { return false }
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view)
            return abs(velocity.x) > abs(velocity.y) && (velocity.x < 0 || parent.isOpen)
        }
        @objc func tap(_ gesture: UITapGestureRecognizer) {
            parent.onTap(gesture.location(in: gesture.view))
        }
        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            parent.onPan?(gesture.translation(in: gesture.view).x, gesture.view?.bounds.width ?? 0, gesture.state)
        }
        @objc func hold(_ gesture: UILongPressGestureRecognizer) {
            guard let view = gesture.view, let window = view.window else { return }
            let point = gesture.location(in: window)
            switch gesture.state {
            case .began: parent.onHold(view.convert(view.bounds, to: window), point, window.bounds)
            case .changed: parent.onHoldMove(point)
            case .ended: parent.onHoldEnd(true)
            case .cancelled, .failed: parent.onHoldEnd(false)
            default: break
            }
        }
    }
}
