import SwiftUI
import XCTest
@testable import Weather

/// Renders the design-A cards (lock screen, expanded island, Watch Smart Stack) with `ImageRenderer`, light and dark.
/// Approximation only: the system background/blur, the real Dynamic Island hardware shape and the Smart Stack frame are not
/// drawn (flat stand-ins). PNGs are written only when `TEST_RUNNER_LA_IMAGE_DIR` is set; the assertions run always.
@MainActor
final class LiveActivityImageTests: XCTestCase {
    private struct Sample { let id: String; let state: RainActivityAttributes.ContentState; let name: String; let radius: Int? }

    private func samples() -> [Sample] {
        let now = Date()
        func s(_ phase: RainActivityAttributes.Phase, in min: Double? = nil, ageMin: Double = 4, maxClass: Int = 3,
               wet: Int? = nil, peak: Int? = nil, radius: Int? = nil) -> RainActivityAttributes.ContentState {
            .init(phase: phase, eventDate: min.map { now.addingTimeInterval($0 * 60) }, intensityClass: maxClass,
                  referenceTime: now.addingTimeInterval(-ageMin * 60), wetSharePercent: wet, peakSharePercent: peak, regionRadiusKm: radius)
        }
        return [
            .init(id: "1-kommt", state: s(.startsIn, in: 8.5, maxClass: 2), name: "Zuhause", radius: nil),
            .init(id: "2-laeuft", state: s(.raining), name: "Zuhause", radius: nil),
            .init(id: "3-endet", state: s(.endsIn, in: 5.5, ageMin: 1), name: "Zuhause", radius: nil),
            .init(id: "4-veraltet", state: s(.raining, ageMin: 36), name: "Zuhause", radius: nil),
            .init(id: "5-gebiet-kommt", state: s(.startsIn, in: 12.5, maxClass: 4, wet: 0, peak: 34, radius: 10), name: "Umland", radius: 10),
            .init(id: "6-gebiet-laeuft", state: s(.raining, maxClass: 4, wet: 34, peak: 60, radius: 10), name: "Umland", radius: 10),
        ]
    }

    private func presentation(_ sample: Sample) -> (RainActivityPresentation, String) {
        let p = RainActivityPresentation(state: sample.state, contextIsStale: false, now: Date(), localRadiusKm: sample.radius)
        return (p, p.region.flatMap { $0.title(name: sample.name) } ?? sample.name)
    }

    private func wallpaper(_ scheme: ColorScheme) -> LinearGradient {
        scheme == .dark
            ? LinearGradient(colors: [Color(red: 0.25, green: 0.12, blue: 0.4), Color(red: 0.05, green: 0.2, blue: 0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
            : LinearGradient(colors: [Color(red: 1, green: 0.85, blue: 0.8), Color(red: 0.72, green: 0.82, blue: 1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Flat stand-in for the system glass behind a lock screen card.
    private func glass(_ scheme: ColorScheme) -> Color { scheme == .dark ? Color.black.opacity(0.35) : Color.white.opacity(0.55) }

    private func render<V: View>(_ view: V, size: CGSize, scheme: ColorScheme, name: String, scale: CGFloat = 3) throws -> CGSize {
        let framed = view.frame(width: size.width).environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: framed)
        renderer.scale = scale
        let image = try XCTUnwrap(renderer.uiImage, "no image for \(name)")
        if let dir = ProcessInfo.processInfo.environment["LA_IMAGE_DIR"], let data = image.pngData() {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image.size
    }

    /// Card heights in pt (the card alone, no wallpaper margin). Lino 20.11.: "viel zu gross"; before the compaction a place card
    /// was 103 to 119 pt (area 148 to 173 pt) in the render and about 118 pt in the real system (place, raining).
    static let maxLockHeightPlace: CGFloat = 88
    static let maxLockHeightRegion: CGFloat = 116

    func testLockScreenCardsRenderForAllStatesLightAndDark() throws {
        var heights: [String: Double] = [:]
        var failures: [String] = []
        for scheme in [ColorScheme.light, .dark] {
            for sample in samples() {
                let (p, title) = presentation(sample)
                let card = RainLockScreenView(p: p, title: title)
                    .background(glass(scheme)).clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                let name = "lock-\(scheme == .dark ? "dunkel" : "hell")-\(sample.id)"
                let size = try render(card, size: CGSize(width: 370, height: 0), scheme: scheme, name: name)
                heights[name] = Double(size.height)
                let limit = sample.radius == nil ? Self.maxLockHeightPlace : Self.maxLockHeightRegion
                if size.height > limit { failures.append("\(name) \(size.height) pt > \(limit) pt") }
                XCTAssertEqual(size.width, 370, accuracy: 0.5)
                XCTAssertGreaterThan(size.height, 60, name)
            }
        }
        if let dir = ProcessInfo.processInfo.environment["LA_IMAGE_DIR"] {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try JSONSerialization.data(withJSONObject: heights, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: dir).appendingPathComponent("lock-heights.json"))
        }
        XCTAssertTrue(failures.isEmpty, "lock screen card too tall: \(failures.joined(separator: "; "))")
    }

    func testExpandedIslandRendersForAllStatesLightAndDark() throws {
        for scheme in [ColorScheme.light, .dark] {
            for sample in samples() {
                let (p, title) = presentation(sample)
                let island = VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: p.symbol).foregroundStyle(p.color)
                            Text(p.watchTitle(name: sample.name) ?? title).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        Text(WidgetAsOfText.string(for: p.referenceTime)).font(.caption).foregroundStyle(.secondary)
                    }
                    RainIslandBottom(p: p)
                }
                .padding(.horizontal, 22).padding(.vertical, 18)
                .background(Color.black, in: RoundedRectangle(cornerRadius: 44, style: .continuous))
                .environment(\.colorScheme, .dark)   // the island is always dark
                .padding(10).background(wallpaper(scheme))
                let size = try render(island, size: CGSize(width: 374, height: 0), scheme: scheme,
                                      name: "island-\(scheme == .dark ? "dunkel" : "hell")-\(sample.id)")
                XCTAssertGreaterThan(size.height, 80, "\(sample.id)")
            }
        }
    }

    /// Smart Stack Live Activity sizes in pt, Apple HIG "Live Activities" > Specifications (checked 20.11.2026):
    /// 40 mm 152 x 69.5, 46 mm 194 x 80.5. Lino 20.11.: the preview card was about twice as high as expected (earlier phase: 139 to 159 pt).
    static let watchSizes: [(name: String, size: CGSize)] = [("40mm", CGSize(width: 152, height: 69.5)), ("46mm", CGSize(width: 194, height: 80.5))]

    func testWatchCardFitsSystemSizeForAllStates() throws {
        // watchOS has no light mode; the light render is only a comparison.
        var failures: [String] = []
        for (watch, size) in Self.watchSizes {
            for scheme in [ColorScheme.dark, .light] {
                for sample in samples() {
                    let (p, _) = presentation(sample)
                    let fill = scheme == .dark ? Color(white: 0.11) : Color.white.opacity(0.7)
                    let card = RainWatchCardView(p: p, title: p.watchTitle(name: sample.name)).background(fill)
                    // Ideal height at the system width must not exceed the system height.
                    let rendered = try render(card, size: CGSize(width: size.width, height: 0), scheme: scheme,
                                              name: "watch-ideal-\(watch)-\(scheme == .dark ? "dunkel" : "hell")-\(sample.id)", scale: 2)
                    if rendered.height > size.height { failures.append("\(watch) \(sample.id) \(scheme): \(rendered.height) pt > \(size.height) pt") }
                    // File in the exact system size (render, no system proof): 152 x 69.5 pt = 304 x 139 px @2x, 194 x 80.5 pt = 388 x 161 px @2x.
                    let exact = RainWatchCardView(p: p, title: p.watchTitle(name: sample.name))
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .background(fill)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    _ = try render(exact, size: CGSize(width: size.width, height: size.height), scheme: scheme,
                                   name: "watch-render-\(watch)-\(size.width)x\(size.height)pt-2x-\(scheme == .dark ? "dunkel" : "hell")-\(sample.id)", scale: 2)
                    XCTAssertEqual(rendered.width, size.width, accuracy: 0.5)
                }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testWatchCardDoesNotGrowWithDynamicType() throws {
        var failures: [String] = []
        for (watch, size) in Self.watchSizes {
            for sample in samples() {
                let (p, _) = presentation(sample)
                let card = RainWatchCardView(p: p, title: p.watchTitle(name: sample.name))
                    .frame(width: size.width).environment(\.dynamicTypeSize, .accessibility3).environment(\.colorScheme, .dark)
                let renderer = ImageRenderer(content: card)
                renderer.scale = 3
                let image = try XCTUnwrap(renderer.uiImage)
                if image.size.height > size.height { failures.append("\(watch) \(sample.id): \(image.size.height) pt > \(size.height) pt") }
            }
        }
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    func testLargeDynamicTypeStaysRenderable() throws {
        let (p, title) = presentation(samples()[4])
        for type in [DynamicTypeSize.xxxLarge, .accessibility3] {
            let view = RainLockScreenView(p: p, title: title)
                .frame(width: 402).environment(\.dynamicTypeSize, type).environment(\.colorScheme, .dark).background(wallpaper(.dark))
            let renderer = ImageRenderer(content: view)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertGreaterThan(image.size.height, 100)
            if let dir = ProcessInfo.processInfo.environment["LA_IMAGE_DIR"], let data = image.pngData() {
                try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
                try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("lock-dunkel-schrift-\(type)-gebiet.png"))
            }
        }
    }
}
