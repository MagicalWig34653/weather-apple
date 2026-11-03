import XCTest
@testable import Weather

final class SharedOutlookTests: XCTestCase {
    private let reference = Date(timeIntervalSince1970: 1_800_000_000)

    private func forecast(_ rates: [Double?]) -> RainForecast {
        RainForecast(referenceTime: reference, samples: rates.enumerated().map { index, rate in
            RainSample(date: reference.addingTimeInterval(Double(index * 300)), amountMM: rate.map { $0 / 12 })
        })
    }

    func testStatesAndExistingSummaryWording() {
        let cases: [([Double?], RainOutlook.State, Int?, String)] = [
            ([0, 0, 0], .dry, nil, "Vorerst kein messbarer Regen erwartet"),
            ([0, 0.1, 0], .startsIn, 5, "Regen voraussichtlich in etwa 5 Min."),
            ([2, 2, 2], .rainingNow, nil, "Regen am ausgewählten Ort"),
            ([2, 2, 0], .endsIn, 10, "Regen am ausgewählten Ort"),
            ([nil, 2, 0], .noData, nil, "Regen möglich · Daten teilweise unvollständig"),
            ([nil, 0, 0], .noData, nil, "Keine verlässliche Regenaussage verfügbar"),
            ([], .noData, nil, "Keine aktuelle Prognose verfügbar")
        ]
        for (rates, state, minutes, summary) in cases {
            let value = forecast(rates)
            let outlook = RainOutlook.evaluate(value, at: reference)
            XCTAssertEqual(outlook.state, state)
            XCTAssertEqual(outlook.minutes, minutes)
            XCTAssertEqual(value.summary(at: reference), summary)
        }
        XCTAssertEqual(RainOutlook.evaluate(nil, at: reference).state, .noData)
    }

    func testTwentyMinuteBoundaryAndFutureRunNeverProduceDryWhenStale() {
        let dry = forecast(Array(repeating: 0, count: 25))
        XCTAssertEqual(RainOutlook.evaluate(dry, at: reference.addingTimeInterval(1200)).state, .dry)
        XCTAssertEqual(RainOutlook.evaluate(dry, at: reference.addingTimeInterval(1200.001)).state, .stale)
        XCTAssertNotEqual(RainOutlook.evaluate(dry, at: reference.addingTimeInterval(-60)).state, .stale)
        XCTAssertEqual(RainOutlook.evaluate(dry, at: reference.addingTimeInterval(-60.001)).state, .stale)
    }

    func testTimeArgumentAdvancesTransitionAndExhaustedDataIsUnknown() {
        let value = forecast([0, 0, 2, 2, 0])
        XCTAssertEqual(RainOutlook.evaluate(value, at: reference).minutes, 10)
        XCTAssertEqual(RainOutlook.evaluate(value, at: reference.addingTimeInterval(61)).minutes, 8)
        let current = RainOutlook.evaluate(value, at: reference.addingTimeInterval(301))
        XCTAssertEqual(current.state, .endsIn)
        XCTAssertEqual(current.minutes, 14)
        XCTAssertEqual(RainOutlook.evaluate(forecast([0]), at: reference.addingTimeInterval(1)).state, .noData)
    }

    func testUnknownValuesAndGapsPreventInventedEnd() {
        XCTAssertEqual(RainOutlook.evaluate(forecast([2, nil, 0]), at: reference).state, .rainingNow)
        let gap = RainForecast(referenceTime: reference, samples: [
            RainSample(date: reference, amountMM: 1),
            RainSample(date: reference.addingTimeInterval(600), amountMM: 0)
        ])
        XCTAssertEqual(RainOutlook.evaluate(gap, at: reference).state, .rainingNow)
    }

    func testIntensityBoundaries() {
        let cases: [(Double, RainOutlook.Intensity)] = [
            (0, .none), (0.099, .none), (0.1, .light), (1.99, .light),
            (2, .moderate), (7.49, .moderate), (7.5, .heavy)
        ]
        for (rate, expected) in cases {
            XCTAssertEqual(RainOutlook.Intensity(rateMMPerHour: rate), expected)
        }
    }
}
