#if WIDGET_LOGIC_TESTS
@testable import Weather
#endif
import Foundation

/// "Stand 21:10" / "As of 9:10 PM". The format string is looked up explicitly: `Text("KEY \(date)")` would turn
/// into the key "KEY %@", which does not exist in any table and showed the raw key in Build 44.
enum WidgetAsOfText {
    static func string(for date: Date, bundle: Bundle = .main, locale: Locale = .current) -> String {
        let format = NSLocalizedString("WIDGET_AS_OF", bundle: bundle, value: "Stand %@", comment: "Widget data timestamp")
        return String(format: format, LocaleFormat.time(date, locale: locale))
    }
}
