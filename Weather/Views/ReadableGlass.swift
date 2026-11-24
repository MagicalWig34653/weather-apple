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

/// Dark mode: the clear glass over a mid-grey or coloured map left white labels at 3.2 to 4.5 : 1 (Welt, Europa, Blitze, plain radar;
/// measured directly at the elements). Elements that fell below their target there get this minimum tint; elements that already passed
/// everywhere (round symbol buttons, time pill) keep the clear glass.
let darkGlassFloor = 0.35

private struct ReadableGlass<S: Shape>: ViewModifier {
    @Environment(\.glassScrim) private var layerScrim
    @Environment(\.colorScheme) private var colorScheme
    let shape: S
    let interactive: Bool
    let floor: Double

    func body(content: Content) -> some View {
        let scrim = colorScheme == .dark ? max(layerScrim, floor) : layerScrim
        let base: Glass = scrim > 0 ? .regular.tint(.black.opacity(scrim)) : .regular
        content.glassEffect(interactive ? base.interactive() : base, in: shape)
    }
}

extension View {
    /// `glassEffect(.regular, in:)` that darkens with the environment's `glassScrim`.
    /// `floor`: minimum dark-mode tint for elements that need it (`darkGlassFloor`); 0 keeps the clear glass.
    func readableGlass<S: Shape>(_ shape: S, interactive: Bool = false, floor: Double = 0) -> some View {
        modifier(ReadableGlass(shape: shape, interactive: interactive, floor: floor))
    }
}
