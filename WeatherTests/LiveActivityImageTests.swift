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
    // MARK: Lock screen backdrop, brighter than Build 56 (Lino 21.11.2026: "bisschen dunkel"), iPhone card only

    private static let lockBackdropSize = CGSize(width: 370, height: 88)

    /// Pinned Build 56 numbers (top, bottom wash opacity), deliberately NOT read from production code.
    private static let pinnedLegacyWash: (normal: (Double, Double), reduced: (Double, Double)) = ((0.24, 0.06), (0.30, 0.16))

    private static let allTones: [(name: String, tone: RainActivityPresentation.Tone)] = [("regen", .rain), ("trocken", .dry), ("veraltet", .stale)]

    /// Opaque stand-in for the wallpaper behind the glass (a flat mid-dark gray; mid gray for the light appearance).
    private func backdrop(_ scheme: ColorScheme) -> Color { Color(white: scheme == .dark ? 0.12 : 0.55) }

    private func stack<V: View>(_ layer: V, scheme: ColorScheme) -> some View {
        ZStack { backdrop(scheme); glass(scheme); layer }.frame(width: Self.lockBackdropSize.width, height: Self.lockBackdropSize.height)
    }

    private func pinnedLegacy(tint: Color, reduced: Bool) -> some View {
        let w = reduced ? Self.pinnedLegacyWash.reduced : Self.pinnedLegacyWash.normal
        return LinearGradient(colors: [tint.opacity(w.0), tint.opacity(w.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func image<V: View>(_ view: V, scheme: ColorScheme, name: String? = nil) throws -> UIImage {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, scheme).environment(\.dynamicTypeSize, .large))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, "no image for \(name ?? "-")")
        if let name, let dir = ProcessInfo.processInfo.environment["LA_IMAGE_DIR"], let data = image.pngData() {
            try FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
        }
        return image
    }

    private struct Scan { var mean: Double; var meanRGB: [Double]; var brightest: [Double]; var darkest: [Double] }

    private static func lin(_ c: Double) -> Double { c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    /// WCAG relative luminance of an sRGB color with components 0...1.
    private static func luminance(_ rgb: [Double]) -> Double { 0.2126 * lin(rgb[0]) + 0.7152 * lin(rgb[1]) + 0.0722 * lin(rgb[2]) }
    /// CIE lightness L* of a relative luminance Y.
    private static func lightness(_ y: Double) -> Double { y > 0.008856 ? 116 * cbrt(y) - 16 : 903.3 * y }
    /// WCAG contrast ratio (L1 + 0.05) / (L2 + 0.05), L1 the lighter.
    private static func contrast(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

    /// Mean relative luminance (linear light, WCAG formula, sRGB bitmap) and the brightest/darkest pixel of an opaque render.
    private func scan(_ image: UIImage) throws -> Scan {
        let cg = try XCTUnwrap(image.cgImage)
        let w = cg.width, h = cg.height
        var data = [UInt8](repeating: 0, count: w * h * 4)
        let drawn = data.withUnsafeMutableBytes { ptr -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let ctx = CGContext(data: ptr.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
            return true
        }
        XCTAssertTrue(drawn)
        var sumY = 0.0, sumRGB = [0.0, 0.0, 0.0]
        var best = (y: -1.0, rgb: [0.0, 0.0, 0.0]), worst = (y: 2.0, rgb: [0.0, 0.0, 0.0])
        for i in 0..<(w * h) {
            let red = Double(data[i * 4]) / 255, green = Double(data[i * 4 + 1]) / 255, blue = Double(data[i * 4 + 2]) / 255
            let rgb: [Double] = [red, green, blue]
            let y = Self.luminance(rgb)
            sumY += y
            for k in 0..<3 { sumRGB[k] += rgb[k] }
            if y > best.y { best = (y, rgb) }
            if y < worst.y { worst = (y, rgb) }
        }
        let n = Double(w * h)
        return Scan(mean: sumY / n, meanRGB: sumRGB.map { $0 / n }, brightest: best.rgb, darkest: worst.rgb)
    }

    private func rgb(_ color: UIColor, _ scheme: ColorScheme) -> (rgb: [Double], alpha: Double) {
        let resolved = color.resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        resolved.getRed(&r, green: &g, blue: &b, alpha: &a)
        return ([Double(r), Double(g), Double(b)], Double(a))
    }

    private func schemeName(_ scheme: ColorScheme) -> String { scheme == .dark ? "dunkel" : "hell" }

    /// (a) Numeric: the mean background luminance of the lock screen card against Build 56, expressed in CIE L* of the mean relative
    /// luminance. Bands of the L* difference to Build 56 (stand-in glass): dark 0 to +8 (Lino 24.11.2026: translucent, only lightly tinted;
    /// the card must stay close to the glass of Build 56 and may not lift into an opaque surface; until 23.11. the band was +15 to +22 for the
    /// opaque L* 37 surface), dark with reduce transparency +10 to +16 (opaque variant, absolute target in
    /// `testLockBackdropReducedTransparencyIsOpaqueWithFixedLightness`), light and light with reduce transparency +5 to +16 (iPad/preview only,
    /// unchanged). Rain/dry/stale. Red against Build 58: the opaque base gives +15 to +22 in dark.
    func testLockBackdropMeanLuminanceRisesAgainstBuild56() throws {
        var failures: [String] = []
        var report: [String: [String: Double]] = [:]
        for scheme in [ColorScheme.dark, .light] {
            for reduced in [false, true] {
                for (toneName, tone) in Self.allTones {
                    let tint = tone.tint(scheme)
                    let key = "\(schemeName(scheme))-\(reduced ? "transparenz-reduziert" : "normal")-\(toneName)"
                    let old = try scan(image(stack(pinnedLegacy(tint: tint, reduced: reduced), scheme: scheme), scheme: scheme, name: "lock-bg-vorher-\(key)"))
                    let new = try scan(image(stack(RainLockGlassTint(tint: tint, mode: .brighter, reduceTransparencyOverride: reduced), scheme: scheme),
                                             scheme: scheme, name: "lock-bg-nachher-\(key)"))
                    // The legacy mode of production code must be the pinned Build 56 backdrop (so before/after images are truthful).
                    let legacyMode = try scan(image(stack(RainLockGlassTint(tint: tint, mode: .legacy, reduceTransparencyOverride: reduced), scheme: scheme), scheme: scheme))
                    if abs(legacyMode.mean - old.mean) > 1e-6 { failures.append("\(key): legacy mode \(legacyMode.mean) != pinned \(old.mean)") }
                    let delta = Self.lightness(new.mean) - Self.lightness(old.mean)
                    report[key] = ["Y-vorher": old.mean, "Y-nachher": new.mean, "Y-faktor": new.mean / old.mean,
                                   "Lstar-vorher": Self.lightness(old.mean), "Lstar-nachher": Self.lightness(new.mean), "deltaLstar": delta]
                    let band: ClosedRange<Double> = scheme == .dark ? (reduced ? 10...16 : 0...8) : 5...16
                    if !band.contains(delta) {
                        failures.append("\(key): delta L* \(delta) (Y \(old.mean) -> \(new.mean)) outside \(band)")
                    }
                }
            }
        }
        writeJSON(report, name: "lock-luminance-ratios.json")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// The five card states of Build 58 as presentations: rain, starts soon, area, dry (Dashboard test / probe), stale (tone amber).
    private func lockStates() -> [(name: String, p: RainActivityPresentation)] {
        let now = Date()
        func make(_ phase: RainActivityAttributes.Phase, in min: Double? = nil, ageMin: Double = 4, maxClass: Int = 3, wet: Int? = nil,
                  peak: Int? = nil, radius: Int? = nil) -> RainActivityPresentation {
            let state = RainActivityAttributes.ContentState(phase: phase, eventDate: min.map { now.addingTimeInterval($0 * 60) }, intensityClass: maxClass,
                                                            referenceTime: now.addingTimeInterval(-ageMin * 60), wetSharePercent: wet, peakSharePercent: peak, regionRadiusKm: radius)
            return RainActivityPresentation(state: state, contextIsStale: false, now: now, localRadiusKm: radius)
        }
        return [("rain", make(.raining)), ("starting", make(.startsIn, in: 8.5, maxClass: 2)),
                ("area", make(.raining, maxClass: 4, wet: 34, peak: 60, radius: 10)), ("dry", make(.dry, maxClass: 0)),
                ("stale", make(.raining, ageMin: 36))]
    }

    /// Reduce transparency (system setting): the dark card keeps the opaque variant of Build 58 (Lino 24.11.2026: "Transparenz reduzieren" may
    /// stay non-translucent). Its surface must be L* 34 to 42 in EVERY state, whatever the system draws behind it (black, white, gray).
    func testLockBackdropReducedTransparencyIsOpaqueWithFixedLightness() throws {
        var failures: [String] = []
        var report: [String: [String: Double]] = [:]
        let scheme = ColorScheme.dark
        for (stateName, p) in lockStates() {
            var lightnessByBase: [Double] = []
            for (baseName, base) in [("schwarz", Color.black), ("weiss", Color.white), ("grau", Color(white: 0.3))] {
                let layer = RainLockGlassTint(tint: p.tone.tint(scheme), reduceTransparencyOverride: true)
                let view = ZStack { base; glass(scheme); layer }.frame(width: Self.lockBackdropSize.width, height: Self.lockBackdropSize.height)
                let key = "\(stateName)-transparenz-reduziert-\(baseName)"
                let scanned = try scan(image(view, scheme: scheme, name: "lock-bg-opak-\(key)"))
                let lightness = Self.lightness(scanned.mean)
                lightnessByBase.append(lightness)
                report[key] = ["Y": scanned.mean, "Lstar": lightness]
                if !(34...42).contains(lightness) { failures.append("\(key): L* \(lightness) outside 34...42") }
            }
            if let lo = lightnessByBase.min(), let hi = lightnessByBase.max(), hi - lo > 0.5 {
                failures.append("\(stateName): card depends on the system background (L* \(lo) to \(hi))")
            }
        }
        writeJSON(report, name: "lock-bg-opak.json")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// Target of Lino 24.11.2026 (TestFlight Build 58, "Die LA ist zu deckend. ... so wie die LA von T3 durchsichtig ... nur halt etwas
    /// getoent"): the dark lock screen card lets the background show through and is only lightly tinted in every state.
    /// Measured on the card layer alone over a black, a white and a gray ground (compositing is affine, so the difference white - black of
    /// the mean encoded channel values is exactly 1 - mean coverage):
    ///  - mean coverage of the tint layer <= 0.30 (and >= 0.10, so there is still a tint), Build 58: 1.0 (opaque black base);
    ///  - the card over white is at least 50 L* lighter than over black (the ground really shows through; Build 58: 0);
    ///  - the tint stays recognisable over mid gray: chroma (max - min of the encoded mean channels) 0.04 to 0.20, and the three tones
    ///    (rain, dry, stale) differ pairwise by at least 0.05 (Euclid, encoded mean RGB).
    /// Red against Build 58 (opaque base). The opaque variant with reduce transparency is covered by the test above.
    func testLockBackdropIsTranslucentAndOnlyLightlyTinted() throws {
        var failures: [String] = []
        var report: [String: [String: Double]] = [:]
        let scheme = ColorScheme.dark
        var grayMeans: [String: [Double]] = [:]
        for (stateName, p) in lockStates() {
            func scanned(over base: Color, name: String) throws -> Scan {
                let layer = RainLockGlassTint(tint: p.tone.tint(scheme), reduceTransparencyOverride: false)
                let view = ZStack { base; layer }.frame(width: Self.lockBackdropSize.width, height: Self.lockBackdropSize.height)
                return try scan(image(view, scheme: scheme, name: "lock-bg-durchscheinend-\(stateName)-\(name)"))
            }
            let black = try scanned(over: .black, name: "schwarz"), white = try scanned(over: .white, name: "weiss")
            let gray = try scanned(over: Color(white: 0.5), name: "grau")
            let coverage = 1 - (0..<3).map { white.meanRGB[$0] - black.meanRGB[$0] }.reduce(0, +) / 3
            let gap = Self.lightness(white.mean) - Self.lightness(black.mean)
            let chroma = (gray.meanRGB.max() ?? 0) - (gray.meanRGB.min() ?? 0)
            grayMeans[stateName] = gray.meanRGB
            report[stateName] = ["Deckung": coverage, "LstarWeissMinusSchwarz": gap, "Chroma-grau": chroma]
            if !(0.10...0.30).contains(coverage) { failures.append("\(stateName): coverage \(coverage) outside 0.10...0.30") }
            if gap < 50 { failures.append("\(stateName): card over white only \(gap) L* lighter than over black (< 50)") }
            if !(0.04...0.20).contains(chroma) { failures.append("\(stateName): tint chroma \(chroma) outside 0.04...0.20") }
        }
        let byTone: [(String, String)] = [("rain", "dry"), ("rain", "stale"), ("dry", "stale")]
        for (a, b) in byTone {
            guard let x = grayMeans[a], let y = grayMeans[b] else { continue }
            let distance = sqrt((0..<3).map { pow(x[$0] - y[$0], 2) }.reduce(0, +))
            report["ton-\(a)-\(b)"] = ["Abstand": distance]
            if distance < 0.05 { failures.append("tones \(a)/\(b) hardly differ: \(distance) < 0.05") }
        }
        writeJSON(report, name: "lock-bg-durchscheinend.json")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// (b) Contrast against the worst background pixel (the brightest for light text in dark, the darkest for dark text in light):
    /// primary text >= 4.5:1; tinted text/symbols (hero value, symbol tile) >= 4.5:1 in dark (Build 56: 5.8 to 6.1) and >= 3:1 in the
    /// light stand-in (Build 56: 2.0 to 2.4); secondary text (lock screen secondary color, dark: white 70 %) not worse than Build 56 (system secondary).
    func testLockBackdropKeepsTextContrast() throws {
        var failures: [String] = []
        var report: [String: [String: Double]] = [:]
        for scheme in [ColorScheme.dark, .light] {
            for reduced in [false, true] {
                for (toneName, tone) in Self.allTones {
                    let tint = tone.tint(scheme)
                    let key = "\(schemeName(scheme))-\(reduced ? "transparenz-reduziert" : "normal")-\(toneName)"
                    let old = try scan(image(stack(pinnedLegacy(tint: tint, reduced: reduced), scheme: scheme), scheme: scheme))
                    let new = try scan(image(stack(RainLockGlassTint(tint: tint, mode: .brighter, reduceTransparencyOverride: reduced), scheme: scheme), scheme: scheme))
                    func measure(_ scan: Scan, secondaryOverride: Color?, tintColor: Color) -> (primary: Double, tint: Double, secondary: Double) {
                        let bg = scheme == .dark ? scan.brightest : scan.darkest
                        let bgY = Self.luminance(bg)
                        let primary = rgb(.label, scheme).rgb
                        let tintRGB = rgb(UIColor(tintColor), scheme).rgb
                        let sec = secondaryOverride.map { rgb(UIColor($0), scheme) } ?? rgb(.secondaryLabel, scheme)
                        let secOnBg = (0..<3).map { sec.rgb[$0] * sec.alpha + bg[$0] * (1 - sec.alpha) }
                        return (Self.contrast(Self.luminance(primary), bgY), Self.contrast(Self.luminance(tintRGB), bgY),
                                Self.contrast(Self.luminance(secOnBg), bgY))
                    }
                    let o = measure(old, secondaryOverride: nil, tintColor: tint)
                    // Build 58: the card uses the lighter lock screen tone text (`lockTint`) on the brighter surface.
                    let n = measure(new, secondaryOverride: scheme == .dark ? RainLockGlassStyle.darkSecondaryText : nil, tintColor: tone.lockTint(scheme))
                    report[key] = ["primaer-vorher": o.primary, "primaer-nachher": n.primary, "toenung-vorher": o.tint, "toenung-nachher": n.tint,
                                   "sekundaer-vorher": o.secondary, "sekundaer-nachher": n.secondary]
                    if n.primary < 4.5 { failures.append("\(key): primary \(n.primary) < 4.5") }
                    let tintLimit = scheme == .dark ? 4.5 : 3.0
                    if n.tint < tintLimit { failures.append("\(key): tint \(n.tint) < \(tintLimit) (before \(o.tint))") }
                    if n.secondary < o.secondary - 0.05 { failures.append("\(key): secondary \(n.secondary) worse than Build 56 \(o.secondary)") }
                    if scheme == .dark && n.secondary < 4.5 { failures.append("\(key): secondary \(n.secondary) < 4.5") }
                }
            }
        }
        writeJSON(report, name: "lock-contrast.json")
        XCTAssertTrue(failures.isEmpty, failures.joined(separator: "\n"))
    }

    /// Before/after images of the whole lock screen card in the same scenes (LA_IMAGE_DIR: `lock-vorher-*`, `lock-nachher-*`), light and
    /// dark. Wiring check: the card really uses the new backdrop (brighter than the legacy mode) and keeps exactly the same size.
    func testLockScreenCardBeforeAfterImagesAndWiring() throws {
        for scheme in [ColorScheme.dark, .light] {
            for sample in samples() {
                let (p, title) = presentation(sample)
                func card(_ mode: RainLockGlassMode) -> some View {
                    RainLockScreenView(p: p, title: title, glassMode: mode)
                        .frame(width: 370).background(glass(scheme)).background(backdrop(scheme))
                }
                let before = try image(card(.legacy), scheme: scheme, name: "lock-vorher-\(schemeName(scheme))-\(sample.id)")
                let after = try image(card(.brighter), scheme: scheme, name: "lock-nachher-\(schemeName(scheme))-\(sample.id)")
                XCTAssertEqual(before.size, after.size, "card size must not change: \(sample.id) \(scheme)")
                XCTAssertGreaterThan(try scan(after).mean, try scan(before).mean, "card not brighter: \(sample.id) \(scheme)")
            }
        }
    }

    /// (c) "Only the iPhone card": the Watch card keeps `RainGlassTint` (pixel-identical to the pinned Build 56 gradient, byte-equal PNG),
    /// the tone text colors are pinned (never darker), the island has no tinted glass. Before/after of the Watch/island PNGs from the
    /// other tests (`watch-*`, `island-*`) can additionally be compared byte for byte between Build 56 and this branch.
    func testWatchCardBackdropAndToneColorsAreUnchanged() throws {
        let reduced = UIAccessibility.isReduceTransparencyEnabled
        let size = CGSize(width: 152, height: 69.5)
        for scheme in [ColorScheme.dark, .light] {
            for (toneName, tone) in Self.allTones {
                let tint = tone.tint(scheme)
                let w = reduced ? Self.pinnedLegacyWash.reduced : Self.pinnedLegacyWash.normal
                let reference = LinearGradient(colors: [tint.opacity(w.0), tint.opacity(w.1)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(width: size.width, height: size.height)
                let actual = RainGlassTint(tint: tint).frame(width: size.width, height: size.height)
                let a = try XCTUnwrap(image(actual, scheme: scheme).pngData())
                let r = try XCTUnwrap(image(reference, scheme: scheme).pngData())
                XCTAssertEqual(a, r, "Watch backdrop changed: \(schemeName(scheme)) \(toneName)")
            }
        }
        // Text/symbol colors of Build 56 (RainActivityCards.swift `tint(_:)`), unchanged.
        let pinned: [(RainActivityPresentation.Tone, ColorScheme, [Double])] = [
            (.rain, .dark, [0.35, 0.78, 0.98]), (.rain, .light, [0.04, 0.48, 0.66]),
            (.dry, .dark, [0.35, 0.85, 0.5]), (.dry, .light, [0.1, 0.5, 0.2]),
            (.stale, .dark, [1.0, 0.7, 0.2]), (.stale, .light, [0.74, 0.38, 0.0]),
        ]
        for (tone, scheme, expected) in pinned {
            let actual = rgb(UIColor(tone.tint(scheme)), scheme).rgb
            for k in 0..<3 { XCTAssertEqual(actual[k], expected[k], accuracy: 0.005, "\(tone) \(scheme) channel \(k)") }
        }
    }

    private func writeJSON(_ object: Any, name: String) {
        guard let dir = ProcessInfo.processInfo.environment["LA_IMAGE_DIR"],
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]) else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent(name))
    }
}
