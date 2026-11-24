#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import SwiftUI

/// Design A "tinted glass": a tone gradient over the system background, one large time sentence, symbol in a tinted tile.
/// No ActivityKit here, so the cards can be rendered in unit tests (`LiveActivityImageTests`).

// MARK: Tone colors

extension RainActivityPresentation.Tone {
    /// Text/symbol tint. Light uses darker values so that the tint stays readable on the light glass (contrast, not decoration).
    func tint(_ scheme: ColorScheme) -> Color {
        switch (self, scheme) {
        case (.rain, .dark): return Color(red: 0.35, green: 0.78, blue: 0.98)
        case (.rain, _): return Color(red: 0.04, green: 0.48, blue: 0.66)
        case (.dry, .dark): return Color(red: 0.35, green: 0.85, blue: 0.5)
        case (.dry, _): return Color(red: 0.1, green: 0.5, blue: 0.2)
        case (.stale, .dark): return Color(red: 1.0, green: 0.7, blue: 0.2)
        case (.stale, _): return Color(red: 0.74, green: 0.38, blue: 0.0)
        }
    }

    /// Text/symbol tint of the lock screen card only (Build 58, lighter again in Build 59 for the translucent card over mid-dark wallpaper): the plain dark
    /// tints would fall below 4.5:1 there. Same hues, lighter. Light scheme and Watch/island keep `tint(_:)`.
    func lockTint(_ scheme: ColorScheme) -> Color {
        guard scheme == .dark else { return tint(scheme) }
        switch self {
        case .rain: return Color(red: 0.68, green: 0.93, blue: 1.0)
        case .dry: return Color(red: 0.66, green: 0.97, blue: 0.72)
        case .stale: return Color(red: 1.0, green: 0.89, blue: 0.58)
        }
    }
}

/// Soft tone wash over the system background; stronger when the user turned transparency off.
struct RainGlassTint: View {
    let tint: Color
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        LinearGradient(colors: [tint.opacity(reduceTransparency ? 0.30 : 0.24), tint.opacity(reduceTransparency ? 0.16 : 0.06)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// MARK: Lock screen backdrop (iPhone only)

/// Which backdrop numbers the lock screen card uses. `.legacy` is the state of Build 56 and exists only so that tests can render
/// before/after images and measure the difference in one run; production always uses `.brighter`.
enum RainLockGlassMode { case brighter, legacy }

/// Opacities of the lock screen backdrop on top of the system glass: a tone wash (top left to bottom right) and a white lightener.
/// Only the lock screen card reads these; the Watch card keeps `RainGlassTint` unchanged.
///
/// Why these numbers (Lino 21.11.2026: "bisschen dunkel"; the system draws the lock screen card on dark glass): the first attempt
/// (flatter wash, mean luminance x1.31 = +3 L*) was hardly visible next to Build 56. Now the wash is stronger at the top and much
/// stronger at the bottom (dark: top 0.24 -> 0.28, bottom 0.06 -> 0.18) plus a faint white lightener (0.03). On the test stand-in
/// glass this is about +8.5 L* (mean luminance x1.9) in dark, the tone wash stays visible. The ceiling is the contrast of the tone
/// text (hero value, symbol) against the brightest pixel: >= 4.5:1 allows at most Y 0.0727 (rain).
///
/// Build 58 (Lino's device photo of Build 57, Zustand trocken: card centre L* 5 to 7, darker than the wallpaper L* 14, i.e. "schwarz")
/// added an opaque black base and a strong wash (surface L* 37). Build 59 (Lino 24.11.: "zu deckend ... durchsichtig ... nur etwas
/// getoent") takes the opaque base back for the normal case: translucent card with a light tone wash; the opaque L* 37 variant remains
/// only for reduce transparency. The tone text of the card is lighter (`RainActivityPresentation.Tone.lockTint`, same hues) and the
/// secondary text is white 80 % (`darkSecondaryText`, >= 4.5:1) as in Build 58.
struct RainLockGlassStyle: Equatable {
    var washTop: Double
    var washBottom: Double
    var lightenTop: Double
    var lightenBottom: Double
    /// Layer under the wash: opaque black for the dark card with reduce transparency (Build 58 look, independent of the background), a thin
    /// black scrim (alpha 0.17) for the translucent dark card. Nil for the light card.
    var opaqueBase: Color?

    init(washTop: Double, washBottom: Double, lightenTop: Double, lightenBottom: Double, opaqueBase: Color? = nil) {
        self.washTop = washTop; self.washBottom = washBottom; self.lightenTop = lightenTop; self.lightenBottom = lightenBottom
        self.opaqueBase = opaqueBase
    }

    // Build 56 (legacy), identical to `RainGlassTint`.
    static let legacyNormal = RainLockGlassStyle(washTop: 0.24, washBottom: 0.06, lightenTop: 0, lightenBottom: 0)
    static let legacyReducedTransparency = RainLockGlassStyle(washTop: 0.30, washBottom: 0.16, lightenTop: 0, lightenBottom: 0)

    // Dark appearance (the lock screen card on a real device is always rendered dark).
    // Build 59 (Lino 24.11.2026, TestFlight Build 58: "Die LA ist zu deckend. Die sollte so wie die LA von T3 durchsichtig sein. Nur halt
    // etwas getoent."): the system material behind the card is switched off (`activityBackgroundTint(.clear)` in `RainLiveActivity`), the
    // wallpaper shows through. The card brings its own light layers: a thin black scrim (0.17, keeps white text readable on mid-bright
    // wallpapers, replaces the dark system material) and a tone wash (top 0.28, bottom 0.12). Mean coverage about 0.32 (test limit 0.35;
    // Build 58: 1.0 = opaque).
    static let brighterDark = RainLockGlassStyle(washTop: 0.28, washBottom: 0.12, lightenTop: 0, lightenBottom: 0, opaqueBase: Color.black.opacity(0.17))
    // Reduce transparency: the opaque variant of Build 58 (opaque black base + wash 0.45/0.38 + lightener 0.05, surface about L* 37 in every
    // state, independent of the system background). The user asked for less transparency, so nothing shows through here.
    static let brighterDarkReducedTransparency = RainLockGlassStyle(washTop: 0.45, washBottom: 0.38, lightenTop: 0.05, lightenBottom: 0.05, opaqueBase: .black)
    // Brighter, light appearance (iPad/preview only; the tone tints are dark here, so the wash is weak and the lightener strong).
    static let brighterLight = RainLockGlassStyle(washTop: 0.10, washBottom: 0.02, lightenTop: 0.42, lightenBottom: 0.42)
    static let brighterLightReducedTransparency = RainLockGlassStyle(washTop: 0.10, washBottom: 0.04, lightenTop: 0.40, lightenBottom: 0.40)

    /// Secondary text of the dark lock screen card (name, "Stand", detail line). System secondary (white 60 %) gives only 4.45 to
    /// 4.52:1 on Build 56 and would drop to about 3.5:1 on the brighter backdrop; white 70 % keeps it above 5:1.
    static let darkSecondaryText = Color.white.opacity(0.80)

    static func resolve(_ mode: RainLockGlassMode, scheme: ColorScheme, reduceTransparency: Bool) -> RainLockGlassStyle {
        switch (mode, scheme, reduceTransparency) {
        case (.legacy, _, false): return legacyNormal
        case (.legacy, _, true): return legacyReducedTransparency
        case (.brighter, .dark, false): return brighterDark
        case (.brighter, .dark, true): return brighterDarkReducedTransparency
        case (.brighter, _, false): return brighterLight
        case (.brighter, _, true): return brighterLightReducedTransparency
        }
    }
}

/// Tone wash plus white lightener over the system background of the lock screen card.
struct RainLockGlassTint: View {
    let tint: Color
    var mode: RainLockGlassMode = .brighter
    /// Tests only: replaces the system setting.
    var reduceTransparencyOverride: Bool?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let style = RainLockGlassStyle.resolve(mode, scheme: scheme, reduceTransparency: reduceTransparencyOverride ?? reduceTransparency)
        ZStack {
            if let base = style.opaqueBase { base }
            LinearGradient(colors: [tint.opacity(style.washTop), tint.opacity(style.washBottom)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if style.lightenTop > 0 || style.lightenBottom > 0 {
                LinearGradient(colors: [Color.white.opacity(style.lightenTop), Color.white.opacity(style.lightenBottom)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
    }
}

/// Symbol in a rounded tinted tile.
struct RainSymbolTile: View {
    let symbol: String
    let tint: Color
    var side: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: side * 0.46 * scale, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(tint)
            .frame(width: side * scale, height: side * scale)
            .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: side * 0.3 * scale, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// Secondary text color: `nil` keeps the system secondary style (Watch, island), a color replaces it (lock screen card only).
private struct RainSecondaryText: ViewModifier {
    let color: Color?
    @ViewBuilder func body(content: Content) -> some View {
        if let color { content.foregroundStyle(color) } else { content.foregroundStyle(.secondary) }
    }
}

private extension View {
    func rainSecondary(_ color: Color?) -> some View { modifier(RainSecondaryText(color: color)) }
}

/// "Zuhause" with a pin (for areas: "Umland · Umkreis 10 km").
struct RainTitleRow: View {
    let title: String
    let isRegion: Bool
    var compact = false
    var font: Font?
    var secondary: Color?

    var body: some View {
        Label {
            Text(title).lineLimit(1)
        } icon: {
            Image(systemName: isRegion ? "mappin.and.ellipse" : "mappin")
        }
        .labelStyle(.titleAndIcon)
        .font(font ?? (compact ? Font.footnote : .subheadline).weight(.medium))
        .rainSecondary(secondary)
    }
}

/// The large element: "Regen in 8:00" (label plus countdown in the tint) or one statement ("Es regnet").
struct RainHeroView: View {
    enum Size { case lock, island, watch }
    let p: RainActivityPresentation
    let size: Size
    /// Lock screen only: replaces the system secondary color of the detail line.
    var secondary: Color?
    /// Lock screen card only: replaces the tone tint of the text (`lockTint`).
    var toneTint: Color?
    @Environment(\.colorScheme) private var scheme

    private var tint: Color { toneTint ?? p.tone.tint(scheme) }

    var body: some View {
        switch p.hero {
        case .countdown(let label, let target):
            labelAndValue(label, Text(timerInterval: RainActivityTiming.countdownInterval(now: .now, target: target),
                                      countsDown: true, showsHours: false))
        case .clock(let label, let date):
            labelAndValue(label, Text(date, style: .time))
        case .statement(let text):
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(size == .watch ? .system(size: 20, weight: .bold) : font)
                    .foregroundStyle(p.tone == .stale ? tint : .primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let detail = p.heroDetail, !(size == .watch && p.tone == .stale) {
                    Text(detail).font(size == .watch ? .system(size: 11) : size == .lock ? .caption : .subheadline)
                        .rainSecondary(secondary).lineLimit(size == .watch ? 1 : 2).minimumScaleFactor(size == .watch ? 0.75 : 1)
                }
            }
        }
    }

    /// "Regen in" + value (countdown or clock time); the Smart Stack card shares one line.
    @ViewBuilder private func labelAndValue(_ label: String, _ value: Text) -> some View {
        let value = value.monospacedDigit()
        if size == .watch {
            // Smart Stack card is only 69.5 to 80.5 pt high: label and value share one line.
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
                value.font(.system(size: 26, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).font(font).lineLimit(1).minimumScaleFactor(0.6)
                value.font(font).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var font: Font {
        switch size {
        case .lock: return .system(.title2, weight: .bold)
        case .island: return .system(.title, weight: .bold)
        case .watch: return .system(.title3, weight: .bold)
        }
    }
}

/// Thin share bar (custom, so it renders in `ImageRenderer` and takes the tone).
struct RainShareBar: View {
    let fraction: Double
    let tint: Color
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.22))
                Capsule().fill(tint).frame(width: geo.size.width * min(1, max(0, fraction)))
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

/// Area share, bar and strongest level (areas only).
struct RainRegionDetails: View {
    let p: RainActivityPresentation
    let tint: Color
    /// The expanded island title is name-only (the leading region is narrow), so the radius moves into the details.
    var showsRadius = false

    var body: some View {
        if let region = p.region, region.shareText != nil || region.intensityText != nil {
            VStack(alignment: .leading, spacing: 3) {
                if let share = region.shareText { Text(share).font(.subheadline.weight(.semibold)) }
                if let fraction = region.barFraction {
                    RainShareBar(fraction: fraction, tint: tint)
                }
                let caption = [region.intensityText, showsRadius ? region.radiusText : nil].compactMap { $0 }.joined(separator: " · ")
                if !caption.isEmpty { Text(caption).font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.8) }
            }
        }
    }
}

/// Lock screen area details in as few lines as possible: "34 % nass · Stärkste Stufe 4 (leicht)" (two lines if it does not fit), thin bar.
struct RainLockRegionDetails: View {
    let p: RainActivityPresentation
    let tint: Color
    var secondary: Color?

    var body: some View {
        if let region = p.region, region.shortShareText != nil || region.intensityText != nil {
            VStack(alignment: .leading, spacing: 3) {
                let share = region.shortShareText, level = region.intensityText
                ViewThatFits(in: .horizontal) {
                    line(share, level).lineLimit(1)
                    VStack(alignment: .leading, spacing: 0) { if let share { Text(share).fontWeight(.semibold) }; if let level { Text(level).rainSecondary(secondary) } }
                }
                .font(.footnote)
                if let fraction = region.barFraction { RainShareBar(fraction: fraction, tint: tint, height: 4) }
            }
        }
    }

    private func dim(_ text: Text) -> Text { secondary.map { text.foregroundStyle($0) } ?? text.foregroundStyle(.secondary) }

    private func line(_ share: String?, _ level: String?) -> Text {
        switch (share, level) {
        case let (share?, level?): return Text(share).fontWeight(.semibold) + dim(Text(" · ")) + dim(Text(level))
        case let (share?, nil): return Text(share).fontWeight(.semibold)
        case let (nil, level?): return dim(Text(level))
        default: return Text("")
        }
    }
}

// MARK: Lock screen (iPhone, iPad) and Dynamic Island expanded

struct RainLockScreenView: View {
    let p: RainActivityPresentation
    let title: String?
    /// Tests only: `.legacy` renders the Build 56 backdrop for before/after images.
    var glassMode: RainLockGlassMode = .brighter
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let tint = p.tone.tint(scheme)
        let textTint = glassMode == .brighter ? p.tone.lockTint(scheme) : tint
        let secondary: Color? = glassMode == .brighter && scheme == .dark ? RainLockGlassStyle.darkSecondaryText : nil
        VStack(alignment: .leading, spacing: 4) {
            // Accessibility sizes: name and "Stand" stack instead of cutting the name.
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout())
            layout {
                if let title { RainTitleRow(title: title, isRegion: p.region != nil, compact: true, secondary: secondary) }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text(WidgetAsOfText.string(for: p.referenceTime)).font(.caption).rainSecondary(secondary)
            }
            HStack(alignment: .center, spacing: 10) {
                RainHeroView(p: p, size: .lock, secondary: secondary, toneTint: textTint)
                Spacer(minLength: 0)
                RainSymbolTile(symbol: p.symbol, tint: textTint, side: 36)
            }
            RainLockRegionDetails(p: p, tint: textTint, secondary: secondary)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background { RainLockGlassTint(tint: tint, mode: glassMode) }
        .accessibilityElement(children: .combine)
    }
}

/// Body of the expanded Dynamic Island (below the leading/trailing title row).
struct RainIslandBottom: View {
    let p: RainActivityPresentation
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            RainHeroView(p: p, size: .island)
            RainRegionDetails(p: p, tint: p.tone.tint(scheme), showsRadius: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Watch Smart Stack (ActivityFamily.small)

/// Compact card for the Smart Stack. Apple specifies 152 x 69.5 pt (40 mm) to 198 x 81.5 pt (Ultra 3/4) for a Live Activity there
/// (HIG "Live Activities", Specifications, checked 20.11.2026), so: no bar, no extra lines, fixed (not scaling) type.
/// Priorities: countdown or statement, place/area, "Stand" or the area share only when the title row has room.
struct RainWatchCardView: View {
    let p: RainActivityPresentation
    let title: String?
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let tint = p.tone.tint(scheme)
        VStack(alignment: .leading, spacing: 1) {
            titleRow(tint: tint)
            HStack(alignment: .center, spacing: 6) {
                RainHeroView(p: p, size: .watch)
                Spacer(minLength: 0)
                RainSymbolTile(symbol: p.symbol, tint: tint, side: 22)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)   // centered in the system card (69.5 to 81.5 pt high)
        .dynamicTypeSize(...DynamicTypeSize.large)
        .background { RainGlassTint(tint: tint) }
        .accessibilityElement(children: .combine)
    }

    private var stand: some View {
        HStack(spacing: 3) {
            if p.tone == .stale { Image(systemName: "clock").accessibilityHidden(true) }
            Text(WidgetAsOfText.string(for: p.referenceTime))
        }
    }

    /// Title, then the first of "share" (areas) and "Stand" that still fits next to it.
    @ViewBuilder private func titleRow(tint: Color) -> some View {
        let name = Group {
            if let title { RainTitleRow(title: title, isRegion: p.region != nil, font: .system(size: 12, weight: .medium)) }
        }
        let secondary = Color.secondary
        ViewThatFits(in: .horizontal) {
            if let share = p.watchShareText, p.tone != .stale {
                HStack(spacing: 6) { name; Spacer(minLength: 2); Text(share).lineLimit(1) }
                    .font(.system(size: 11)).foregroundStyle(secondary).fixedSize(horizontal: true, vertical: false)
            }
            HStack(spacing: 6) { name; Spacer(minLength: 2); stand }
                .font(.system(size: 11)).foregroundStyle(p.tone == .stale ? tint : secondary).fixedSize(horizontal: true, vertical: false)
            HStack { name; Spacer(minLength: 0) }
        }
    }
}
