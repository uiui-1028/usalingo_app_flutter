import SwiftUI
import UIKit

/// 距離の補間値は参照JSと共通。brightnessは加算ではなくRGBへの乗算。
struct AudioCarouselStyle {
    static let centerScale: CGFloat = 1.06
    static let sideScale: CGFloat = 0.92
    let progress: CGFloat
    private var t: CGFloat { min(abs(progress), 1) }
    var scale: CGFloat { Self.centerScale + (Self.sideScale - Self.centerScale) * t }
    var rotation: CGFloat { min(12, max(-12, progress * -7)) }
    var depth: CGFloat { 35 - 95 * t }
    var opacity: Double { 1 - 0.6 * min(Double(abs(progress)) / 2.3, 1) }
    var saturation: Double { 1.08 - 0.46 * min(Double(abs(progress)) / 2, 1) }
    var brightness: Double { 1 - 0.32 * min(Double(abs(progress)) / 2, 1) }
}

/// CSSのtransform-origin: center center。透視変換もカード中央を基準にする。
struct AudioCarouselProjection: GeometryEffect {
    let style: AudioCarouselStyle
    let isEnabled: Bool

    func effectValue(size: CGSize) -> ProjectionTransform {
        guard isEnabled else { return ProjectionTransform(CGAffineTransform.identity) }
        var transform = CATransform3DIdentity
        transform.m34 = -1 / 1000
        transform = CATransform3DTranslate(transform, 0, 0, style.depth)
        transform = CATransform3DRotate(transform, style.rotation * .pi / 180, 1, 0, 0)
        let centered = CATransform3DConcat(
            CATransform3DMakeTranslation(-size.width / 2, -size.height / 2, 0), transform
        )
        return ProjectionTransform(CATransform3DConcat(
            centered, CATransform3DMakeTranslation(size.width / 2, size.height / 2, 0)
        ))
    }
}

/// ドラッグの向き。動き出しの成分が大きいほうへ倒し、その操作だけを通す。
enum DragAxis {
    case horizontal
    case vertical

    /// 動き出しの数ポイントは指のぶれで向きが定まらないので、
    /// 一定距離を超えるまで判定を保留する。
    init?(translation: CGSize) {
        guard hypot(translation.width, translation.height) >= 8 else { return nil }
        self = abs(translation.width) >= abs(translation.height) ? .horizontal : .vertical
    }
}

/// 1本の指の向きを、なぞり始めに一度だけ決めて覚える。指を離すまで決め直さないので、
/// 途中で斜めにずれても、もう一方の向きの操作（戻る・めくり・スクロールなど）を同時に動かさない。
struct DragAxisLock: Equatable {
    private var start: CGPoint?
    private var decided: DragAxis?

    /// いまの指の向き。決まるまでは nil。始まりの場所が変われば新しい指として決め直すので、
    /// システムに指を取り上げられて離した知らせが来なくても、前の指の向きを持ち越さない。
    mutating func axis(start: CGPoint, translation: CGSize) -> DragAxis? {
        if start != self.start {
            self.start = start
            decided = nil
        }
        if decided == nil { decided = DragAxis(translation: translation) }
        return decided
    }

    /// 指を離した。
    mutating func reset() {
        self = DragAxisLock()
    }
}

/// フレームごとに座標そのものを更新する。SwiftUIの暗黙アニメーションで札を再移動しない。
///
/// 手ざわりは Final Cut Pro のマグネティックタイムラインのように、枠へはっきり吸い付かせる。
/// - ドラッグ中は指に滑らかに付いてくる。枠の近くでは少しゆっくり、枠の境いでは少し速く動かし、
///   止まったり跳んだりさせずに、やわらかく枠へ引き寄せる。
/// - 指を離すと、勢いから行き先を決めて短い時間で行き過ぎずに止まる。滑ってから寄せる2段階はしない。
/// - 指で動かしたときだけ、枠の境いを越えるたびに軽く振動させる。自動送りはゆったり動かし、振動もしない。
@MainActor
final class AudioCarouselMotion: ObservableObject {
    private enum Magnet {
        /// 磁力の強さ。枠の近くでは指の (1 - strength) 倍、境いでは (1 + strength) 倍の速さで動く。
        /// 1 未満なら向きが逆になることはなく、指とのずれは最大で枠の間隔の strength / 2π。
        static let strength: CGFloat = 0.5
        /// 指を離したときの勢いを、どれだけ先まで見込むか（ミリ秒）。
        static let flickProjection: CGFloat = 150
        /// これより速く離したら、少なくとも1枠は進める（points / millisecond）。
        static let flickMinVelocity: CGFloat = 0.3
        /// 手で動かしたあとの止まり方。遠いほど少しだけ長くかける。
        static let snapBase: TimeInterval = 0.18
        static let snapPerSlot: TimeInterval = 0.04
        static let snapMax: TimeInterval = 0.34
        /// 自動送りのゆったりした動き。
        static let gentleSnap: TimeInterval = 0.420
    }

    @Published private(set) var position: CGFloat = 0
    private(set) var velocity: CGFloat = 0 // points / millisecond（参照JSと同じ）
    private(set) var isDragging = false
    private(set) var isMoving = false
    /// 枠に吸い付いたときに呼ぶ。テストでは差し替えて数える。
    var onDetent: (() -> Void)?
    private var stride: CGFloat = 174
    private var lastIndex = 0
    private var minimum: CGFloat { -CGFloat(lastIndex) * stride }
    var nearestIndex: Int { min(lastIndex, max(0, Int((-position / stride).rounded()))) }
    /// 指が指している位置。磁力で枠に張り付いている間は `position` とずれる。
    private var fingerPosition: CGFloat = 0
    /// 最後に吸い付いた枠。同じ枠で振動を繰り返さない。
    private var detentIndex = 0
    private var lastTranslation: CGFloat = 0
    private var lastDragTime: TimeInterval = 0
    private var snapStart: CGFloat = 0
    private var snapTarget: Int?
    private var snapElapsed: TimeInterval = 0
    private var snapDuration: TimeInterval = Magnet.gentleSnap
    private var isGentleSnap = false
    private var completion: ((Int) -> Void)?
    private var displayLink: CADisplayLink?
    private var previousFrame: TimeInterval = 0

    // CADisplayLinkはtargetを強参照するため、弱参照の中継を挟む。
    @MainActor
    private final class TickTarget: NSObject {
        weak var motion: AudioCarouselMotion?
        @objc func tick(_ link: CADisplayLink) { motion?.tick(link) }
    }

    func configure(stride: CGFloat, count: Int, index: Int) {
        stop()
        self.stride = stride
        lastIndex = max(0, count - 1)
        position = -CGFloat(index) * stride
        detentIndex = index
    }

    func beginDrag(at time: TimeInterval) {
        stop()
        isDragging = true
        // 見えている位置から指の位置を逆算し、つかんだ瞬間に札が跳ばないようにする。
        fingerPosition = unmagnetized(position)
        lastTranslation = 0
        lastDragTime = time
        velocity = 0
    }

    func drag(translation: CGFloat, at time: TimeInterval) {
        let delta = translation - lastTranslation
        let dt = max((time - lastDragTime) * 1000, 1)
        fingerPosition = rubberBand(fingerPosition + delta, resistance: 0.28)
        move(to: magnetized(fingerPosition), detents: true)
        if time > lastDragTime { velocity = velocity * 0.68 + delta / dt * 0.32 }
        lastTranslation = translation
        lastDragTime = time
    }

    /// 勢いから行き先を1つ決め、そこへまっすぐ止める。
    func endDrag(at time: TimeInterval, animated: Bool, completion: @escaping (Int) -> Void) {
        isDragging = false
        // 指を止めてから離した場合、古い速度でフリックしない。
        if time - lastDragTime > 0.08 { velocity = 0 }
        let current = (-fingerPosition / stride).rounded()
        var target = current
        // 「視差効果を減らす」ときは勢いを使わず、いちばん近い枠で止める。
        if animated {
            target = (-(fingerPosition + velocity * Magnet.flickProjection) / stride).rounded()
            if abs(velocity) > Magnet.flickMinVelocity, target == current {
                target += velocity < 0 ? 1 : -1
            }
        }
        snap(to: min(max(Int(target), 0), lastIndex), animated: animated, completion: completion)
    }

    /// `gentle` は自動送り用。ゆったり動かし、振動させない。
    func snap(to index: Int, animated: Bool, gentle: Bool = false, completion: @escaping (Int) -> Void) {
        stop()
        self.completion = completion
        snapTarget = index
        snapStart = position
        snapElapsed = 0
        isGentleSnap = gentle
        let slots = abs(-CGFloat(index) * stride - position) / max(stride, 1)
        snapDuration = gentle
            ? Magnet.gentleSnap
            : min(Magnet.snapBase + Magnet.snapPerSlot * TimeInterval(slots), Magnet.snapMax)
        if animated {
            startDisplayLink()
        } else {
            position = -CGFloat(index) * stride
            finish(at: index)
        }
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isMoving = false
        isDragging = false
        snapTarget = nil
        completion = nil
    }

    private func startDisplayLink() {
        let target = TickTarget()
        target.motion = self
        let link = CADisplayLink(target: target, selector: #selector(TickTarget.tick(_:)))
        previousFrame = CACurrentMediaTime()
        displayLink = link
        isMoving = true
        link.add(to: .main, forMode: .common)
    }

    private func tick(_ link: CADisplayLink) {
        let dt = max(0, link.timestamp - previousFrame)
        previousFrame = link.timestamp
        advanceFrame(seconds: dt)
    }

    // 時間を注入できるようにし、60Hz/120Hz・長いドラッグの逆戻りをテストする。
    func advanceFrame(seconds: TimeInterval) {
        guard isMoving, let target = snapTarget else { return }
        snapElapsed += seconds
        let t = min(snapElapsed / snapDuration, 1)
        // 自動送りは長く減速させ、手で動かしたあとは短く止めて余韻を残さない。
        let eased = isGentleSnap ? 1 - pow(1 - t, 4) : 1 - pow(1 - t, 3)
        move(to: snapStart + (-CGFloat(target) * stride - snapStart) * eased, detents: !isGentleSnap)
        if t >= 1 { finish(at: target) }
    }

    /// 枠の近くでは遅く、境いでは速くして、やわらかく枠へ引き寄せる。
    /// 枠と境いの上では指と同じ位置になり、その間もなめらかにつながる。
    /// 端より先（ゴムで伸びている間）は磁力をかけない。
    private func magnetized(_ raw: CGFloat) -> CGFloat {
        guard stride > 0, raw <= 0, raw >= minimum else { return raw }
        let slot = -raw / stride
        return -(slot - Magnet.strength * sin(2 * .pi * slot) / (2 * .pi)) * stride
    }

    /// `magnetized` の逆。単調に増えるので、ニュートン法で数回たどれば十分に合う。
    private func unmagnetized(_ shown: CGFloat) -> CGFloat {
        guard stride > 0, shown <= 0, shown >= minimum else { return shown }
        let target = -shown / stride
        var slot = target
        for _ in 0..<4 {
            let error = slot - Magnet.strength * sin(2 * .pi * slot) / (2 * .pi) - target
            slot -= error / (1 - Magnet.strength * cos(2 * .pi * slot))
        }
        return -slot * stride
    }

    /// 位置を動かし、枠の境いを越えて中央の枠が入れ替わったら1回だけ振動させる。
    private func move(to newPosition: CGFloat, detents: Bool) {
        position = newPosition
        guard detents, stride > 0 else { return }
        let index = Int((-newPosition / stride).rounded())
        guard (0...lastIndex).contains(index), index != detentIndex else { return }
        detentIndex = index
        if let onDetent { onDetent() } else { HapticFeedbackService.detent() }
    }

    private func rubberBand(_ y: CGFloat, resistance: CGFloat) -> CGFloat {
        if y > 0 { return y * resistance }
        if y < minimum { return minimum + (y - minimum) * resistance }
        return y
    }

    private func finish(at index: Int) {
        let callback = completion
        detentIndex = index
        stop()
        callback?(index)
    }
}
