import XCTest
@testable import Weather

/// L4: data/error texts, rain outlook summaries, forecast age, on-device summary (prompt and facts) in both languages.
final class DataLocalizationTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_800_000_000)

    private func bundle(_ code: String) throws -> Bundle {
        let path = try XCTUnwrap(Bundle.main.path(forResource: code, ofType: "lproj"))
        return try XCTUnwrap(Bundle(path: path))
    }
    private func keys(_ code: String) throws -> [String: String] {
        let path = try XCTUnwrap(try bundle(code).path(forResource: "Localizable", ofType: "strings"))
        return try XCTUnwrap(NSDictionary(contentsOfFile: path) as? [String: String])
    }
    private func forecast(_ rates: [Double?], referenceOffset: TimeInterval = 0) -> RainForecast {
        let start = reference.addingTimeInterval(referenceOffset)
        return RainForecast(referenceTime: start, samples: rates.enumerated().map { index, rate in
            RainSample(date: start.addingTimeInterval(Double(index * 300)), amountMM: rate.map { $0 / 12 })
        })
    }

    func testEveryL4KeyExistsInBothLanguagesWithSamePlaceholders() throws {
        let de = try keys("de"), en = try keys("en")
        let l4 = de.keys.filter { key in ["DATA_", "OUTLOOK_", "INTERP_", "STORE_"].contains { key.hasPrefix($0) } }
        XCTAssertGreaterThan(l4.count, 50)
        for key in l4 {
            let german = try XCTUnwrap(de[key]), english = try XCTUnwrap(en[key], key)
            XCTAssertFalse(english.isEmpty, key)
            XCTAssertNotEqual(german, english, key)
            XCTAssertEqual(german.components(separatedBy: "%").count, english.components(separatedBy: "%").count, "placeholders \(key)")
        }
    }

    func testDataErrorsAreTranslatedAndKeepGermanWording() throws {
        let all: [DWDDataError] = [.unsupportedLocation, .invalidResponse, .emptyBody, .oversizedBody, .malformedPayload, .unexpectedPayload,
                                   .invalidTimeFormat, .serviceFailure, .runUnavailable, .unavailable, .staleData, .incompleteForecast, .mismatchedRun]
        let de = try bundle("de"), en = try bundle("en")
        XCTAssertEqual(Set(all.map { $0.message(bundle: en) }).count, all.count, "English messages are distinguishable")
        for error in all {
            XCTAssertNotEqual(error.message(bundle: de), error.message(bundle: en))
            XCTAssertFalse(error.message(bundle: en).contains("Wetterdaten"))
        }
        XCTAssertEqual(DWDDataError.invalidResponse.message(bundle: de), "Die Wetterdaten konnten nicht gelesen werden.")
        XCTAssertEqual(DWDDataError.invalidResponse.message(bundle: en), "The weather data could not be read.")
        XCTAssertEqual(DWDDataError.emptyBody.message(bundle: en), "The weather data could not be read (empty response).")
    }

    func testForecastAgeFollowsLanguage() throws {
        let value = forecast([0])
        let de = try bundle("de"), en = try bundle("en")
        XCTAssertEqual(value.ageDescription(at: reference.addingTimeInterval(360), bundle: de), "Stand vor 6 Min.")
        XCTAssertEqual(value.ageDescription(at: reference.addingTimeInterval(360), bundle: en), "Data from 6 min ago")
        XCTAssertEqual(value.ageDescription(at: reference.addingTimeInterval(3900), bundle: de), "Stand vor 1 Std. 5 Min.")
        XCTAssertEqual(value.ageDescription(at: reference.addingTimeInterval(3900), bundle: en), "Data from 1 h 5 min ago")
    }

    func testOutlookSummaryFollowsLanguage() throws {
        let de = try bundle("de"), en = try bundle("en")
        let cases: [(RainForecast, Date, String, String)] = [
            (forecast([0, 0, 0]), reference, "Vorerst kein messbarer Regen erwartet", "No measurable rain expected for now"),
            (forecast([0, 0, 0, 0, 0, 2]), reference, "Regen voraussichtlich in etwa 25 Min.", "Rain expected in about 25 min"),
            (forecast([2, 2, 2]), reference, "Regen am ausgewählten Ort", "Rain at the selected place"),
            (forecast([0]), reference.addingTimeInterval(21 * 60), "Prognosedaten sind veraltet", "Forecast data is out of date"),
            (forecast([0, nil]), reference, "Keine verlässliche Regenaussage verfügbar", "No reliable rain forecast available"),
        ]
        for (value, now, german, english) in cases {
            XCTAssertEqual(value.summary(at: now, bundle: de), german)
            XCTAssertEqual(value.summary(at: now, bundle: en), english)
        }
        XCTAssertEqual(RainOutlook.evaluate(nil, at: reference).summary(bundle: en), "No current forecast available")
    }

    @MainActor func testForecastFactsAndPromptAreLanguageSpecific() throws {
        let de = try bundle("de"), en = try bundle("en")
        for fact in ForecastFact.allCases {
            XCTAssertNotEqual(fact.text(bundle: de), fact.text(bundle: en))
        }
        XCTAssertEqual(ForecastFact.dry.text(bundle: en), "The remaining radar data shows no measurable rain.")
        let snapshot = InterpretationSnapshot(forecast: forecast([0, 0, 2, 3, 0, 0]), hasCurrentError: false, now: reference, bundle: en)
        XCTAssertTrue(snapshot.facts.count > 1)
        XCTAssertTrue(snapshot.fallback.hasPrefix("The remaining radar data contains rain."))
        let prompt = ForecastInterpretation.prompt(for: snapshot, bundle: en)
        XCTAssertTrue(prompt.hasPrefix("Allowed supported facts:\nrain: The remaining radar data contains rain."))
        XCTAssertTrue(ForecastInterpretation.prompt(for: snapshot, bundle: de).hasPrefix("Zulässige belegte Fakten:\nrain: Die verbleibenden Radardaten enthalten Regen."))
        XCTAssertTrue(ForecastInterpretation.instructions(bundle: en).contains("in English"))
        XCTAssertTrue(ForecastInterpretation.instructions(bundle: de).contains("auf Deutsch"))
        XCTAssertEqual(snapshot.render([.rain], bundle: en), "The remaining radar data contains rain.")
    }

    @MainActor func testModelLocaleFollowsAppLanguage() {
        XCTAssertEqual(ForecastInterpretation.modelLocale(language: "de").identifier, "de_DE")
        XCTAssertEqual(ForecastInterpretation.modelLocale(language: "en").identifier, "en_US")
    }

    func testSourceAttributionKeepsTheDWDName() throws {
        let de = try keys("de"), en = try keys("en")
        XCTAssertEqual(de["STORE_ATTRIBUTION"], "Quelle: Deutscher Wetterdienst")
        XCTAssertEqual(en["STORE_ATTRIBUTION"], "Source: Deutscher Wetterdienst")
        XCTAssertTrue(en["WARN_SOURCE_ISSUED"]?.hasPrefix("Source: Deutscher Wetterdienst, issued") == true)
    }
}
