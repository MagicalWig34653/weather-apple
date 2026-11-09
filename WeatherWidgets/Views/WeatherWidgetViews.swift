import SwiftUI
import WidgetKit

struct WeatherWidgetView: View {
    let entry: WeatherWidgetEntry
    @Environment(\.widgetFamily) private var family

    private var presentation: WidgetPresentation { WidgetPresentation(entry: entry) }

    /// Remaining samples of the next 2 hours.
    private var upcoming: [RainSample] {
        (entry.forecast?.samples ?? []).filter { $0.date >= entry.date.addingTimeInterval(-300) }.prefix(24).map { $0 }
    }

    var body: some View {
        content
            .widgetURL(entry.deepLinkURL)
            .containerBackground(for: .widget) {
                switch family {
                case .accessoryCircular, .accessoryRectangular, .accessoryInline:
                    Color.clear
                default:
                    LinearGradient(colors: [presentation.color.opacity(0.22), Color(.systemBackground)],
                                   startPoint: .top, endPoint: .bottom)
                }
            }
    }

    @ViewBuilder private var content: some View {
        switch family {
        case .systemMedium: medium
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        case .accessoryInline: inline
        default: small
        }
    }

    private var placeName: String { entry.place?.name ?? "Showers" }

    private var ageLabel: some View {
        Group {
            if let ref = entry.referenceTime {
                Text("WIDGET_AS_OF \(ref, style: .time)")
            } else {
                Text("WIDGET_NO_TIMESTAMP")
            }
        }
        .font(.caption2).foregroundStyle(entry.outlook.state == .stale ? .orange : .secondary)
        .lineLimit(1).minimumScaleFactor(0.8)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(placeName, systemImage: "location.fill")
                .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: presentation.symbol).font(.title).foregroundStyle(presentation.color)
                .widgetAccentable()
            Text(presentation.headline).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
            if let detail = presentation.detail {
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            ageLabel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var medium: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Label(placeName, systemImage: "location.fill")
                    .font(.caption.weight(.medium)).foregroundStyle(.secondary).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: presentation.symbol).font(.title).foregroundStyle(presentation.color)
                    .widgetAccentable()
                Text(presentation.headline).font(.headline).lineLimit(2).minimumScaleFactor(0.8)
                if let detail = presentation.detail {
                    Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                ageLabel
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 4) {
                if presentation.showsChart {
                    RainBarChart(samples: upcoming).frame(maxHeight: .infinity)
                    HStack {
                        Text("WIDGET_NOW"); Spacer(); Text("WIDGET_PLUS_1H"); Spacer(); Text("WIDGET_PLUS_2H")
                    }
                    .font(.caption2).foregroundStyle(.secondary)
                } else {
                    Spacer()
                    Text("WIDGET_NO_TREND").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var circular: some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: presentation.symbol).font(.system(size: 14)).widgetAccentable()
                if let m = presentation.minutes, entry.outlook.state != .stale {
                    Text("\(m)").font(.system(size: 18, weight: .semibold, design: .rounded)).minimumScaleFactor(0.6)
                    Text("WIDGET_MIN_UNIT").font(.system(size: 9))
                } else {
                    Text(presentation.short).font(.system(size: 10, weight: .medium))
                        .lineLimit(2).minimumScaleFactor(0.6).multilineTextAlignment(.center)
                }
            }
        }
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Label(placeName, systemImage: presentation.symbol)
                .font(.caption2.weight(.medium)).lineLimit(1).widgetAccentable()
            Text(presentation.headline).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            if presentation.showsChart {
                RainBarChart(samples: Array(upcoming.prefix(12)), barSpacing: 1).frame(height: 14)
            } else if let detail = presentation.detail {
                Text(detail).font(.caption2).lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inline: some View {
        Label {
            Text(presentation.short)
        } icon: {
            Image(systemName: presentation.symbol)
        }
    }
}

struct WeatherWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WeatherWidgetKind.forecast, intent: WeatherWidgetIntent.self,
                               provider: WeatherWidgetProvider()) { entry in
            WeatherWidgetView(entry: entry)
        }
        .configurationDisplayName("WIDGET_NAME")
        .description("WIDGET_DESCRIPTION")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}
