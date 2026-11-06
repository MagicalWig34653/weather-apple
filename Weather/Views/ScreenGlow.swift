import SwiftUI
import UIKit

/// Short glow that runs once around the display edge when the forecast area is entered.
/// Rules (pure, unit-testable): it plays only on entering, rotates once, ends by itself, and with
/// Reduced Motion it only fades in and out without rotation.
enum ScreenGlow {
    static func shouldPlay(entered: Bool, wasShown: Bool) -> Bool { entered && !wasShown }

    static func rotationDuration(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 0 : 2.0 }

    static func totalDuration(reduceMotion: Bool) -> TimeInterval { reduceMotion ? 1.2 : 2.2 }

    static let fadeIn: TimeInterval = 0.3
    static let fadeOut: TimeInterval = 0.7

    /// Opacity envelope at `elapsed` seconds: quick fade in, hold, softer fade out.
    static func opacity(at elapsed: TimeInterval, total: TimeInterval) -> Double {
        guard elapsed >= 0, elapsed <= total else { return 0 }
        if elapsed < fadeIn { return elapsed / fadeIn }
        if elapsed > total - fadeOut { return max(0, (total - elapsed) / fadeOut) }
        return 1
    }

    /// Scrub glow: blue for a time in the past (measurement), orange for the future (forecast).
    /// "Now" itself still counts as past; the same rule as the forecast marker of the slider.
    static func isForecast(date: Date, reference: Date) -> Bool { date > reference }

    static let pastColor = Color(red: 0.10, green: 0.45, blue: 1.00)
    static let futureColor = Color.orange

    /// Palette of the app icon: blue, cyan and green-teal.
    static let colors: [Color] = [
        Color(red: 0.10, green: 0.45, blue: 1.00), .cyan, Color(red: 0.15, green: 0.85, blue: 0.65),
        Color(red: 0.20, green: 0.60, blue: 1.00), Color(red: 0.10, green: 0.45, blue: 1.00)
    ]
}

/// The glow frame itself: soft wide halo plus a thin bright line, rotating gradient, display-corner shaped.
struct ScreenGlowView: View {
    let reduceMotion: Bool
    @State private var start = Date()

    var body: some View {
        let total = ScreenGlow.totalDuration(reduceMotion: reduceMotion)
        let rotation = ScreenGlow.rotationDuration(reduceMotion: reduceMotion)
        TimelineView(.animation(paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(start)
            let angle = rotation > 0 ? elapsed / rotation * 360 : 0
            let gradient = AngularGradient(colors: ScreenGlow.colors, center: .center, angle: .degrees(angle))
            ZStack {
                RoundedRectangle(cornerRadius: ScreenGlowPresenter.cornerRadius, style: .continuous).strokeBorder(gradient, lineWidth: 16).blur(radius: 14).opacity(0.7)
                RoundedRectangle(cornerRadius: ScreenGlowPresenter.cornerRadius, style: .continuous).strokeBorder(gradient, lineWidth: 6).blur(radius: 4)
                RoundedRectangle(cornerRadius: ScreenGlowPresenter.cornerRadius, style: .continuous).strokeBorder(gradient, lineWidth: 2)
            }
            .drawingGroup()
            .opacity(ScreenGlow.opacity(at: elapsed, total: total))
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(!ScreenGlowPresenter.exposesForTests)
        .accessibilityIdentifier("forecast-glow")
    }
}

/// Observable state of the scrub glow; only the two values below, the view animates between them.
@MainActor @Observable
final class ScrubGlowModel {
    var visible = false
    var future = false
}

/// Static frame (no timeline, no rotation): both tones are stacked and cross-fade by opacity, so passing "now"
/// blends softly and nothing keeps running while the glow rests.
struct ScrubGlowView: View {
    let model: ScrubGlowModel
    let reduceMotion: Bool

    var body: some View {
        let radius = ScreenGlowPresenter.cornerRadius
        ZStack {
            frame(ScreenGlow.pastColor, radius: radius).opacity(model.future ? 0 : 1)
            frame(ScreenGlow.futureColor, radius: radius).opacity(model.future ? 1 : 0)
        }
        .drawingGroup()
        .opacity(model.visible ? 1 : 0)
        .animation(reduceMotion ? .linear(duration: 0.2) : .easeInOut(duration: 0.35), value: model.future)
        .animation(.easeInOut(duration: reduceMotion ? 0.2 : 0.4), value: model.visible)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(!ScreenGlowPresenter.exposesForTests)
        .accessibilityIdentifier("scrub-glow")
        .accessibilityValue(model.future ? "forecast" : "measurement")
    }

    private func frame(_ color: Color, radius: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: 16).blur(radius: 14).opacity(0.7)
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: 6).blur(radius: 4)
            RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(color, lineWidth: 2)
        }
    }
}

/// A window that never takes touches.
private final class PassthroughWindow: UIWindow {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? { nil }
}

/// Shows the glow in its own click-through window above everything (including sheets) and removes it afterwards.
/// Only public API; nothing keeps running once the effect ended.
@MainActor
enum ScreenGlowPresenter {
    private static var window: UIWindow?
    private static var generation = 0

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

    static func play(reduceMotion: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone || UIDevice.current.userInterfaceIdiom == .pad,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene })
                  .first(where: { $0.activationState == .foregroundActive }) else { return }
        generation += 1
        let mine = generation
        hide()
        let host = UIHostingController(rootView: ScreenGlowView(reduceMotion: reduceMotion))
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
        window = glow
        let total = ScreenGlow.totalDuration(reduceMotion: reduceMotion)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(total + 0.1))
            if generation == mine { hide() }
        }
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

    private static func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
