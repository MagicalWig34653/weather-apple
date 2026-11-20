import SwiftUI

/// Dark glass behind controls while a data layer colours the whole map brightly (temperature, dew point, humidity, clouds):
/// white labels on the normally clear glass fell to 2.4 to 3.0 : 1 there (measured directly at the elements, `LayerContrastUITests`).
/// The scrim is a black tint of the existing glass (no new material), only in dark mode and only for those layers; everything
/// else keeps the clear glass. 0 = unchanged.
private struct GlassScrimKey: EnvironmentKey { static let defaultValue = 0.0 }

extension EnvironmentValues {
    var glassScrim: Double {
        get { self[GlassScrimKey.self] }
        set { self[GlassScrimKey.self] = newValue }
    }
}

extension RadarLayer {
    /// The layer's data image colours (almost) the whole map with light colours (measured coverage 100 %, colour luminance 0.62 to 0.78).
    var coversMapBrightly: Bool { [.temperature, .dewpoint, .humidity, .clouds].contains(self) }

    /// Tint opacity of the glass behind controls in dark mode (0 for layers that leave the map alone).
    static let brightLayerScrim = 0.45
}

private struct ReadableGlass<S: Shape>: ViewModifier {
    @Environment(\.glassScrim) private var scrim
    let shape: S
    let interactive: Bool

    func body(content: Content) -> some View {
        let base: Glass = scrim > 0 ? .regular.tint(.black.opacity(scrim)) : .regular
        content.glassEffect(interactive ? base.interactive() : base, in: shape)
    }
}

extension View {
    /// `glassEffect(.regular, in:)` that darkens with the environment's `glassScrim`.
    func readableGlass<S: Shape>(_ shape: S, interactive: Bool = false) -> some View {
        modifier(ReadableGlass(shape: shape, interactive: interactive))
    }
}
