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

/// "Zuhause" with a pin (for areas: "Umland · Umkreis 10 km").
struct RainTitleRow: View {
    let title: String
    let isRegion: Bool
    var compact = false
    var font: Font?

    var body: some View {
        Label {
            Text(title).lineLimit(1)
        } icon: {
            Image(systemName: isRegion ? "mappin.and.ellipse" : "mappin")
        }
        .labelStyle(.titleAndIcon)
        .font(font ?? (compact ? Font.footnote : .subheadline).weight(.medium))
        .foregroundStyle(.secondary)
    }
}

/// The large element: "Regen in 8:00" (label plus countdown in the tint) or one statement ("Es regnet").
struct RainHeroView: View {
    enum Size { case lock, island, watch }
    let p: RainActivityPresentation
    let size: Size
    @Environment(\.colorScheme) private var scheme

    private var tint: Color { p.tone.tint(scheme) }

    var body: some View {
        switch p.hero {
        case .countdown(let label, let target):
            let countdown = Text(timerInterval: RainActivityTiming.countdownInterval(now: .now, target: target),
                                 countsDown: true, showsHours: false)
                .monospacedDigit()
            if size == .watch {
                // Smart Stack card is only 69.5 to 80.5 pt high: label and countdown share one line.
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(label).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.7)
                    countdown.font(.system(size: 26, weight: .bold)).minimumScaleFactor(0.6).lineLimit(1)
                }
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(label).font(font).lineLimit(1).minimumScaleFactor(0.6)
                    countdown.font(font).foregroundStyle(tint).lineLimit(1).minimumScaleFactor(0.6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        case .statement(let text):
            VStack(alignment: .leading, spacing: 2) {
                Text(text).font(size == .watch ? .system(size: 20, weight: .bold) : font)
                    .foregroundStyle(p.tone == .stale ? tint : .primary)
                    .lineLimit(1).minimumScaleFactor(0.6)
                if let detail = p.heroDetail, !(size == .watch && p.tone == .stale) {
                    Text(detail).font(size == .watch ? .system(size: 11) : size == .lock ? .caption : .subheadline)
                        .foregroundStyle(.secondary).lineLimit(size == .watch ? 1 : 2).minimumScaleFactor(size == .watch ? 0.75 : 1)
                }
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

    var body: some View {
        if let region = p.region, region.shortShareText != nil || region.intensityText != nil {
            VStack(alignment: .leading, spacing: 3) {
                let share = region.shortShareText, level = region.intensityText
                ViewThatFits(in: .horizontal) {
                    line(share, level).lineLimit(1)
                    VStack(alignment: .leading, spacing: 0) { if let share { Text(share).fontWeight(.semibold) }; if let level { Text(level).foregroundStyle(.secondary) } }
                }
                .font(.footnote)
                if let fraction = region.barFraction { RainShareBar(fraction: fraction, tint: tint, height: 4) }
            }
        }
    }

    private func line(_ share: String?, _ level: String?) -> Text {
        switch (share, level) {
        case let (share?, level?): return Text(share).fontWeight(.semibold) + Text(" · ").foregroundStyle(.secondary) + Text(level).foregroundStyle(.secondary)
        case let (share?, nil): return Text(share).fontWeight(.semibold)
        case let (nil, level?): return Text(level).foregroundStyle(.secondary)
        default: return Text("")
        }
    }
}

// MARK: Lock screen (iPhone, iPad) and Dynamic Island expanded

struct RainLockScreenView: View {
    let p: RainActivityPresentation
    let title: String?
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let tint = p.tone.tint(scheme)
        VStack(alignment: .leading, spacing: 4) {
            // Accessibility sizes: name and "Stand" stack instead of cutting the name.
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2)) : AnyLayout(HStackLayout())
            layout {
                if let title { RainTitleRow(title: title, isRegion: p.region != nil, compact: true) }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                Text(WidgetAsOfText.string(for: p.referenceTime)).font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .center, spacing: 10) {
                RainHeroView(p: p, size: .lock)
                Spacer(minLength: 0)
                RainSymbolTile(symbol: p.symbol, tint: tint, side: 36)
            }
            RainLockRegionDetails(p: p, tint: tint)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background { RainGlassTint(tint: tint) }
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
