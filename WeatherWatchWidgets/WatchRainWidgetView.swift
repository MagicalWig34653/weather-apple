import SwiftUI
import WidgetKit

struct WatchRainWidgetView: View {
    let entry: WeatherWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var presentation: WatchWidgetPresentation { WatchWidgetPresentation(entry: entry) }

    var body: some View {
        content
            .containerBackground(.fill.tertiary, for: .widget)
            .widgetURL(entry.deepLinkURL)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder
    private var content: some View {
        switch family {
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        case .accessoryCorner:
            compact.widgetLabel {
                Text(entry.place?.name ?? "ShowerNow")
            }
        default: compact
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.place?.name ?? "ShowerNow")
                .font(.headline).lineLimit(1)
            Label(presentation.status, systemImage: presentation.symbolName)
                .font(.caption).lineLimit(2).minimumScaleFactor(0.8)
            HStack(spacing: 3) {
                Text(presentation.isCached ? "DWD · Saved" : "DWD · Run")
                runTime
            }
            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Keep the freshness marker inside the face, even on faces without corner labels.
    private var compact: some View {
        VStack(spacing: 1) {
            Image(systemName: presentation.symbolName).font(.caption)
            Text(presentation.compactStatus)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.65)
            runTime.font(.system(size: 10)).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Inline complications support a single label. Omit the name here to retain state and time.
    private var inline: some View {
        Label {
            if let referenceTime = entry.referenceTime {
                Text("\(referenceTime, style: .time) \(presentation.compactStatus)")
            } else {
                Text(presentation.compactStatus)
            }
        } icon: {
            Image(systemName: presentation.symbolName)
        }
    }

    @ViewBuilder
    private var runTime: some View {
        if let referenceTime = entry.referenceTime {
            // Absolute time stays truthful even after WidgetKit exhausts the planned entries.
            Text(referenceTime, style: .time).monospacedDigit()
        } else {
            Text("—")
        }
    }

    private var accessibilityText: String {
        [entry.place?.name ?? "ShowerNow", presentation.status, presentation.age,
         presentation.isCached ? WatchWidgetText.string("Saved forecast") : nil]
            .compactMap { $0 }.joined(separator: ". ")
    }
}
