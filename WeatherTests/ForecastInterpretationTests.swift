import XCTest
@testable import Weather

@MainActor
final class ForecastInterpretationTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    private func forecast(_ amounts: [Double?], reference: Date? = nil) -> RainForecast {
        RainForecast(referenceTime: reference ?? now, samples: amounts.enumerated().map {
            RainSample(date: now.addingTimeInterval(Double($0.offset) * 300), amountMM: $0.element)
        })
    }

    private func snapshot(_ amounts: [Double?] = [0, 0.1, 1]) -> InterpretationSnapshot {
        InterpretationSnapshot(forecast: forecast(amounts), hasCurrentError: false, now: now)
    }

    func testOnlySupportedFactsRenderAndNeverInventDryConditions() {
        let value = snapshot()
        XCTAssertNotNil(value.render([.mixed, .changingIntensity]))
        XCTAssertNil(value.render([.dry]))
        XCTAssertNil(value.render([.rain, .rain]))
        XCTAssertNil(value.render([]))
        XCTAssertNil(value.render([.rain, .mixed, .changingIntensity]))
    }

    func testStaleMissingAndFailedDataCannotGenerateFacts() {
        XCTAssertTrue(snapshot([nil, 0]).facts.isEmpty)
        let stale = InterpretationSnapshot(forecast: forecast([0, 1], reference: now.addingTimeInterval(-1201)), hasCurrentError: false, now: now)
        XCTAssertTrue(stale.facts.isEmpty)
        let failed = InterpretationSnapshot(forecast: forecast([0, 1]), hasCurrentError: true, now: now)
        XCTAssertTrue(failed.facts.isEmpty)
        XCTAssertFalse(failed.fallback.contains("kein messbarer"))
    }

    func testFingerprintIncludesAllValuesRunAndRemainingIntervals() {
        let original = snapshot()
        XCTAssertNotEqual(original, snapshot([0, 0.2, 1]))
        XCTAssertNotEqual(original, InterpretationSnapshot(forecast: forecast([0, 0.1, 1], reference: now.addingTimeInterval(-300)), hasCurrentError: false, now: now))
        XCTAssertNotEqual(original, InterpretationSnapshot(forecast: forecast([0, 0.1, 1]), hasCurrentError: false, now: now.addingTimeInterval(1)))
    }

    func testUnavailableAndSingleFactDoNotCallGenerator() async {
        var calls = 0
        let model = ForecastInterpretation(availability: { "Nicht verfügbar" }, generate: { _ in calls += 1; return [.rain] })
        await model.interpret(snapshot())
        XCTAssertEqual(model.notice, "Nicht verfügbar")
        await model.interpret(snapshot([0, 0]))
        XCTAssertEqual(calls, 0)
        XCTAssertNil(model.text)
    }

    func testValidatedResultCachedButChangedForecastRegenerates() async {
        var calls = 0
        let model = ForecastInterpretation(availability: { nil }, generate: { _ in calls += 1; return [.mixed] })
        await model.interpret(snapshot())
        XCTAssertTrue(model.usedModel)
        await model.interpret(snapshot())
        XCTAssertEqual(calls, 1)
        await model.interpret(snapshot([0, 0.2, 1]))
        XCTAssertEqual(calls, 2)
    }

    func testInvalidModelFactsAndGenerationFailureKeepFallback() async {
        let invalid = ForecastInterpretation(availability: { nil }, generate: { _ in [.dry] })
        await invalid.interpret(snapshot())
        XCTAssertNil(invalid.text)
        XCTAssertFalse(invalid.usedModel)
        let failed = ForecastInterpretation(availability: { nil }, generate: { _ in throw CancellationError() })
        await failed.interpret(snapshot())
        XCTAssertNil(failed.text)
    }

    func testResetRejectsLateResultAndPreventsConcurrentGeneration() async {
        var continuation: CheckedContinuation<[ForecastFact], Never>?
        var calls = 0
        let model = ForecastInterpretation(availability: { nil }, generate: { _ in
            calls += 1
            return await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { await model.interpret(snapshot()) }
        while continuation == nil { await Task.yield() }
        model.reset()
        await model.interpret(snapshot([0, 0.2, 1]))
        XCTAssertEqual(calls, 1)
        continuation?.resume(returning: [.mixed])
        await task.value
        XCTAssertNil(model.text)
        XCTAssertFalse(model.isGenerating)
    }
    func testCancelledRequestCannotPublishResult() async {
        var continuation: CheckedContinuation<[ForecastFact], Never>?
        let model = ForecastInterpretation(availability: { nil }, generate: { _ in
            await withCheckedContinuation { continuation = $0 }
        })
        let task = Task { await model.interpret(snapshot()) }
        while continuation == nil { await Task.yield() }
        task.cancel()
        continuation?.resume(returning: [.mixed])
        await task.value
        XCTAssertNil(model.text)
        XCTAssertFalse(model.usedModel)
        XCTAssertFalse(model.isGenerating)
    }

}
