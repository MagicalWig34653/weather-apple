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

    private static func hide() {
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
