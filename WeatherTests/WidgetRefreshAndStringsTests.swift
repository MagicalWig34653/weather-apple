import Foundation
import XCTest
@testable import Weather

/// Build 44 showed the raw key "WIDGET_AS_OF 21:10" in the widget (`Text("KEY \(date)")` looks up "KEY %@").
/// These tests read the symbolic keys used by the extension sources and check the BUILT bundles (de and en).
@MainActor
final class WidgetRefreshAndStringsTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let place = SavedPlace(name: "Testort", coordinate: WeatherCoordinate(latitude: 50, longitude: 10))

    // MARK: Strings in built bundles

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    private func bundles() -> [(name: String, bundle: Bundle, sources: [String])] {
        var result: [(name: String, bundle: Bundle, sources: [String])] = []
        if let plugIns = Bundle.main.builtInPlugInsURL,
           let b = Bundle(url: plugIns.appendingPathComponent("WeatherWidgets.appex")) {
            result.append(("WeatherWidgets", b, ["WeatherWidgets"]))
        }
        let watchApp = Bundle.main.bundleURL.appendingPathComponent("Watch/WeatherWatch.app")
        if let b = Bundle(url: watchApp.appendingPathComponent("PlugIns/WeatherWatchWidgets.appex")) {
            result.append(("WeatherWatchWidgets", b, ["WeatherWatchWidgets"]))
        }
        if let b = Bundle(url: watchApp) { result.append(("WeatherWatch", b, ["WeatherWatch"])) }
        return result
    }

    /// The Watch targets use natural-language keys (the English text); collect the literals of UI calls instead.
    private func naturalKeys(inDirectory dir: String) throws -> Set<String> {
        let root = repoRoot.appendingPathComponent(dir)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" && !$0.path.contains("Preview") } ?? []
        let regex = try NSRegularExpression(pattern: #"(?:Text|Label|Button|navigationTitle|accessibilityLabel|accessibilityHint|NSLocalizedString)\(\s*"([^"\\]+)""#)
        var keys = Set<String>()
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            let ns = text as NSString
            for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let key = ns.substring(with: m.range(at: 1))
                XCTAssertFalse(key.contains("\\("), "Interpolated key in \(file.lastPathComponent): \(key)")
                if key != "Showers", key != "\u{2014}" { keys.insert(key) }
            }
        }
        return keys
    }

    private func symbolicKeys(inDirectory dir: String) throws -> Set<String> {
        let root = repoRoot.appendingPathComponent(dir)
        let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" } ?? []
        let regex = try NSRegularExpression(pattern: #""([A-Z][A-Z0-9_]{3,})(?: [^"]*)?""#)
        var keys = Set<String>()
        for file in files where !file.path.contains("Preview") {
            let text = try String(contentsOf: file, encoding: .utf8)
            let ns = text as NSString
            for m in regex.matches(in: text, range: NSRange(location: 0, length: ns.length)) {
                let key = ns.substring(with: m.range(at: 1))
                if ["WIDGET_", "ACTIVITY_", "REGION_ACTIVITY_", "WATCH_", "COMPLICATION_"].contains(where: key.hasPrefix) { keys.insert(key) }
                // An interpolated key can never be found in a strings table.
                XCTAssertFalse(ns.substring(with: m.range(at: 0)).contains("\\("),
                               "Interpolated key in \(file.lastPathComponent): \(ns.substring(with: m.range(at: 0)))")
            }
        }
        return keys
    }

    func testExtensionKeysExistInBuiltBundlesInBothLanguages() throws {
        let found = bundles()
        try XCTSkipIf(found.isEmpty, "No embedded extension bundles in this test host")
        try XCTSkipUnless(FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("WeatherWidgets").path), "Sources not reachable")
        for (name, bundle, dirs) in found {
            var keys = Set<String>()
            let natural = name.hasPrefix("WeatherWatch")
            for d in dirs { keys.formUnion(natural ? try naturalKeys(inDirectory: d) : try symbolicKeys(inDirectory: d)) }
            if natural {
                // Natural-language keys are passed through helpers in the Watch code: compare the built tables instead.
                let tables = try ["de", "en"].map { code -> [String: String] in
                    let path = try XCTUnwrap(bundle.path(forResource: "Localizable", ofType: "strings", inDirectory: nil, forLocalization: code),
                                             "\(name): Localizable.strings (\(code)) missing in built bundle")
                    return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
                }
                XCTAssertFalse(tables[0].isEmpty, "\(name): empty table")
                XCTAssertEqual(Set(tables[0].keys), Set(tables[1].keys), "\(name): de/en keys differ in built bundle")
                for (code, table) in zip(["de", "en"], tables) {
                    for (k, v) in table { XCTAssertFalse(v.isEmpty, "\(name) \(code): empty value for \(k)") }
                }
                continue
            }
            XCTAssertFalse(keys.isEmpty, "\(name): no keys found, scan broken")
            for code in ["de", "en"] {
                let path = try XCTUnwrap(bundle.path(forResource: code, ofType: "lproj"), "\(name): \(code).lproj missing in built bundle")
                let lang = try XCTUnwrap(Bundle(path: path))
                for key in keys.sorted() {
                    let value = lang.localizedString(forKey: key, value: "@@MISSING@@", table: nil)
                    let shared = lang.localizedString(forKey: key, value: "@@MISSING@@", table: "SharedTexts")
                    XCTAssertTrue(value != "@@MISSING@@" || shared != "@@MISSING@@", "\(name) \(code): key \(key) missing")
                    if !natural { XCTAssertNotEqual(value, key, "\(name) \(code): key \(key) resolves to itself") }
                }
            }
        }
    }

    func testAsOfTextIsLocalizedInBothLanguages() throws {
        let b = try XCTUnwrap(bundles().first { $0.name == "WeatherWidgets" }?.bundle)
        let date = Date(timeIntervalSince1970: 1_800_000_000)
        for (code, prefix) in [("de", "Stand "), ("en", "As of ")] {
            let lang = try XCTUnwrap(Bundle(path: try XCTUnwrap(b.path(forResource: code, ofType: "lproj"))))
            let text = WidgetAsOfText.string(for: date, bundle: lang, locale: Locale(identifier: code))
            XCTAssertTrue(text.hasPrefix(prefix), text)
            XCTAssertFalse(text.contains("WIDGET_AS_OF"))
            XCTAssertFalse(text.contains("%"))
        }
    }

    // MARK: Refresh policy

    private func forecast(reference: Date) -> RainForecast {
        RainForecast(referenceTime: reference, samples: (0...24).map {
            RainSample(date: reference.addingTimeInterval(Double($0 * 300)), amountMM: 0)
        })
    }

    func testLiveFetchReloadsSoonerThanFifteenMinutes() {
        let r = WidgetForecastResult(place: place, forecast: forecast(reference: now), source: .live, issue: nil)
        XCTAssertEqual(WidgetTimelineBuilder.build(for: r, at: now).reloadDate, now.addingTimeInterval(600))
    }

    func testFailedOrCachedFetchRetriesAfterFiveMinutes() {
        for source in [WidgetForecastResult.Source.cache, .unavailable] {
            let r = WidgetForecastResult(place: place, forecast: nil, source: source, issue: .forecastUnavailable)
            XCTAssertEqual(WidgetTimelineBuilder.build(for: r, at: now).reloadDate, now.addingTimeInterval(300))
        }
    }

    func testOldDataIsMarkedStaleInLaterEntries() {
        let r = WidgetForecastResult(place: place, forecast: forecast(reference: now.addingTimeInterval(-8 * 60)), source: .live, issue: nil)
        let entries = WidgetTimelineBuilder.build(for: r, at: now).entries
        XCTAssertNotEqual(entries.first?.outlook.state, .stale)
        XCTAssertEqual(entries.last?.outlook.state, .stale)
    }
}

final class WidgetDiagnosticsTests: XCTestCase {
    func testRoundTripStoresOnlyTimesAndOutcome() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "diag-test-\(UUID())"))
        XCTAssertNil(WidgetDiagnostics.load(defaults: defaults))
        let v = WidgetDiagnostics(lastRun: Date(timeIntervalSince1970: 100), outcome: .cache,
                                  dataReference: Date(timeIntervalSince1970: 50), nextReload: Date(timeIntervalSince1970: 400))
        WidgetDiagnostics.record(v, defaults: defaults)
        XCTAssertEqual(WidgetDiagnostics.load(defaults: defaults), v)
    }
}
