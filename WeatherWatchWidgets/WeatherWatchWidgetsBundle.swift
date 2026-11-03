import SwiftUI
import WidgetKit

@main
struct WeatherWatchWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WatchRainWidget()
    }
}

struct WatchRainWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WatchWidgetKind.forecast, intent: WeatherWidgetIntent.self,
                               provider: WatchWidgetProvider()) { entry in
            WatchRainWidgetView(entry: entry)
        }
        .configurationDisplayName("Rain forecast")
        .description("Rain for a saved place, with the DWD run time.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline, .accessoryCorner])
    }
}
