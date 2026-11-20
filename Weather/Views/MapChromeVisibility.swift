import CoreGraphics

/// Whether the screen's own controls (header, forecast pill, notices, map buttons, legend) are hidden so the map
/// is free while the time slider is dragged. Pure state, free of UI so every start and end case is unit-testable.
/// Build 53: the controls go away once the finger has really moved; map, slider and time value always stay.
struct MapChromeVisibility: Equatable {
    /// Finger travel (points, from the touch-down point) from which a touch counts as a drag. A tap or a tiny wobble
    /// never hides anything, so a short touch does not flicker the screen.
    static let activationDistance: CGFloat = 8

    private(set) var isDragging = false
    private(set) var isChromeHidden = false

    /// Called for every drag event with the total travel since touch-down. Once hidden, the controls stay hidden until
    /// the drag ends (the finger returning to the start point must not make them flicker back).
    mutating func dragMoved(distance: CGFloat) {
        isDragging = true
        if distance.isFinite, distance >= Self.activationDistance { isChromeHidden = true }
    }

    /// Every way a drag can end (lift, cancel, interruption, disappear, background, layer switch) calls this one function.
    mutating func dragEnded() {
        isDragging = false
        isChromeHidden = false
    }
}
