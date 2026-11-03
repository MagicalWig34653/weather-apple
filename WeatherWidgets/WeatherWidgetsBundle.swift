import SwiftUI
import WidgetKit

@main
struct WeatherWidgetsBundle: WidgetBundle {
    var body: some Widget {
        WeatherWidget()
        RainLiveActivity()
    }
}
