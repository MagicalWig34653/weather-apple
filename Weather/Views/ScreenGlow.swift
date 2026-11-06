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

    /// Slow breathing of the glow strength, between 0.82 and 1.
    static func breath(at time: TimeInterval) -> Double {
        0.91 + 0.09 * sin(time / breathPeriod * 2 * .pi)
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
            ZStack {
                frame(ScreenGlow.pastColor, radius: radius, angle: angle).opacity(model.future ? 0 : 1)
                frame(ScreenGlow.futureColor, radius: radius, angle: angle).opacity(model.future ? 1 : 0)
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

    private func frame(_ color: Color, radius: CGFloat, angle: Angle) -> some View {
        let gradient = AngularGradient(colors: ScreenGlow.stops(for: color), center: .center, angle: angle)
        return ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(gradient, lineWidth: 16).blur(radius: 14).opacity(0.7)
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(gradient, lineWidth: 6).blur(radius: 4)
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(gradient, lineWidth: 2)
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
