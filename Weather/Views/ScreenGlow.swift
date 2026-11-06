import SwiftUI
import UIKit

/// Scrub glow tones and motion rules (pure, unit-testable).
/// While the slider is dragged the glow breathes slowly and a lighter highlight wanders around the frame;
/// with Reduced Motion it stays static.
enum ScreenGlow {
    /// Scrub glow: blue for a time in the past (measurement), orange for the future (forecast).
    /// "Now" itself still counts as past; the same rule as the forecast marker of the slider.
    static func isForecast(date: Date, reference: Date) -> Bool { date > reference }

    static let pastColor = Color(red: 0.10, green: 0.45, blue: 1.00)
    static let futureColor = Color.orange

    static let breathPeriod: TimeInterval = 3.6
    static let orbitPeriod: TimeInterval = 14

    /// Siri-like intensity modulation: three incommensurable sines, between 0.55 and 1 (1 when static).
    static func breath(at time: TimeInterval) -> Double {
        let wave = 0.5 * sin(time / breathPeriod * 2 * .pi)
            + 0.3 * sin(time / 2.3 * 2 * .pi + 1.1)
            + 0.2 * sin(time / 5.9 * 2 * .pi + 2.4)
        return 0.775 + 0.225 * wave
    }

    /// Slightly varying frame width factor, between 0.8 and 1.2.
    static func widthScale(at time: TimeInterval) -> Double {
        1 + 0.2 * sin(time / 4.7 * 2 * .pi + 0.6)
    }

    /// Subtle colour variance around the base tone (past: blue/cyan/indigo/violet, future: orange/amber/red/pink).
    static func palette(future: Bool) -> [Color] {
        future
            ? [futureColor, Color(red: 1.0, green: 0.72, blue: 0.18), Color(red: 1.0, green: 0.36, blue: 0.22), Color(red: 1.0, green: 0.42, blue: 0.62)]
            : [pastColor, Color(red: 0.12, green: 0.78, blue: 1.0), Color(red: 0.33, green: 0.30, blue: 0.95), Color(red: 0.60, green: 0.38, blue: 0.95)]
    }

    /// Closed gradient ring of the palette, shifted by `shift` colours so two layers differ.
    static func ringStops(future: Bool, shift: Int) -> [Color] {
        let colors = palette(future: future)
        let ring = (0..<colors.count).map { colors[($0 + shift) % colors.count] }
        return ring + [ring[0]]
    }

    /// Rotation of the gradient in degrees; 0 for Reduced Motion.
    static func orbitAngle(at time: TimeInterval, reduceMotion: Bool) -> Double {
        reduceMotion ? 0 : (time / orbitPeriod * 360).truncatingRemainder(dividingBy: 360)
    }

    /// Gradient stops of one tone: the base colour with a lighter highlight that wanders with the rotation.
    static func stops(for color: Color) -> [Color] {
        [color, color.mix(with: .white, by: 0.45), color, color.mix(with: .black, by: 0.12), color]
    }
}

/// Observable state of the scrub glow; only the two values below, the view animates between them.
@MainActor @Observable
final class ScrubGlowModel {
    var visible = false
    var future = false
}

/// Scrub frame: both tones are stacked and cross-fade by opacity, so passing "now" blends softly.
/// The timeline only ticks while the glow is visible (active gesture); after the fade-out nothing runs.
struct ScrubGlowView: View {
    let model: ScrubGlowModel
    let reduceMotion: Bool
    @State private var start = Date()

    var body: some View {
        let radius = ScreenGlowPresenter.cornerRadius
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion || !model.visible)) { context in
            let t = context.date.timeIntervalSince(start)
            let angle = Angle.degrees(ScreenGlow.orbitAngle(at: t, reduceMotion: reduceMotion))
            let breath = reduceMotion ? 1 : ScreenGlow.breath(at: t)
            let width = reduceMotion ? 1 : ScreenGlow.widthScale(at: t)
            ZStack {
                frame(future: false, radius: radius, angle: angle, width: width).opacity(model.future ? 0 : 1)
                frame(future: true, radius: radius, angle: angle, width: width).opacity(model.future ? 1 : 0)
            }
            .drawingGroup()
            .opacity(breath)
        }
        .opacity(model.visible ? 1 : 0)
        .animation(reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.35), value: model.future)
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.5), value: model.visible)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(!ScreenGlowPresenter.exposesForTests)
        .accessibilityIdentifier("scrub-glow")
        .accessibilityValue(model.future ? "forecast" : "measurement")
    }

    /// Two counter-rotating colour rings with different speeds blend into each other along the edge.
    private func frame(future: Bool, radius: CGFloat, angle: Angle, width: Double) -> some View {
        let a = AngularGradient(colors: ScreenGlow.ringStops(future: future, shift: 0), center: .center, angle: angle)
        let b = AngularGradient(colors: ScreenGlow.ringStops(future: future, shift: 2), center: .center, angle: .degrees(120) - angle * 1.6)
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        return ZStack {
            shape.strokeBorder(a, lineWidth: 18 * width).blur(radius: 15).opacity(0.55)
            shape.strokeBorder(b, lineWidth: 14 * width).blur(radius: 11).opacity(0.5)
            shape.strokeBorder(a, lineWidth: 6 * width).blur(radius: 4).opacity(0.85)
            shape.strokeBorder(b, lineWidth: 3 * width).blur(radius: 1.5).opacity(0.6)
            shape.strokeBorder(a, lineWidth: 1.5)
        }
    }
}

/// A window that never takes touches.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

/// Shows the scrub glow in its own click-through window above everything (including sheets) and removes it after release.
/// Only public API; nothing keeps running once the effect ended.
@MainActor
enum ScreenGlowPresenter {
    /// Display corner radius without private API: devices with a Dynamic Island / notch have about 47 to 62 pt
    /// (safe-area top >= 50), home-button iPhones and iPads are square or nearly so. Only used for the glow shape.
    static var cornerRadius: CGFloat {
        let top = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first?.windows.first?.safeAreaInsets.top ?? 0
        if UIDevice.current.userInterfaceIdiom == .pad { return top > 24 ? 18 : 0 }
        return top >= 59 ? 55 : (top >= 47 ? 47 : (top >= 44 ? 40 : 0))
    }

    static var exposesForTests: Bool {
        #if DEBUG
        CommandLine.arguments.contains("-UITestExposeGlow")
        #else
        false
        #endif
    }

    // MARK: Scrub glow

    private static var scrubWindow: UIWindow?
    private static var scrubModel: ScrubGlowModel?
    private static var scrubGeneration = 0

    /// Shows or updates the scrub glow while the slider is dragged; call `endScrub` on release.
    static func updateScrub(isForecast: Bool, reduceMotion: Bool) {
        scrubGeneration += 1
        if let model = scrubModel, scrubWindow != nil {
            model.visible = true
            model.future = isForecast
            return
        }
        guard let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive }) else { return }
        let model = ScrubGlowModel()
        model.future = isForecast
        let host = UIHostingController(rootView: ScrubGlowView(model: model, reduceMotion: reduceMotion))
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        let glow = PassthroughWindow(windowScene: scene)
        glow.frame = scene.coordinateSpace.bounds
        glow.rootViewController = host
        host.view.frame = glow.bounds
        glow.backgroundColor = .clear
        glow.isUserInteractionEnabled = false
        glow.windowLevel = .alert + 1
        glow.isHidden = false
        scrubWindow = glow
        scrubModel = model
        // Fade in on the next turn so the first frame starts transparent.
        Task { @MainActor in model.visible = true }
    }

    /// Fades the scrub glow out and removes its window afterwards (nothing stays alive).
    static func endScrub() {
        guard let model = scrubModel else { return }
        scrubGeneration += 1
        let mine = scrubGeneration
        model.visible = false
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.6))
            guard scrubGeneration == mine else { return }
            scrubWindow?.isHidden = true
            scrubWindow?.rootViewController = nil
            scrubWindow = nil
            scrubModel = nil
        }
    }
}
