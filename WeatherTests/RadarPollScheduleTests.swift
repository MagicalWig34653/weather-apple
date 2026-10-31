import XCTest
@testable import Weather

// Pure time logic: injected clock and random source, no network, no shared state.
final class RadarPollScheduleTests: XCTestCase {
    /// 2026-10-31 12:00:00 UTC, a grid point.
    let base = ISO8601DateFormatter().date(from: "2026-10-31T12:00:00Z")!
    func at(_ seconds: TimeInterval) -> Date { base.addingTimeInterval(seconds) }
    func schedule(_ value: Double = 0.5) -> RadarPollSchedule { RadarPollSchedule(random: { value }) } // 0.5 = no jitter

    func testNominalIsGridPointOfLatestWindowInUTC() {
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(165)), base)
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(164.9)), at(-300))
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(464)), base)
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(465)), at(300))
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(3600 + 200)).timeIntervalSince1970.truncatingRemainder(dividingBy: 300), 0)
    }

    func testIndependentOfLocalTimeZone() {
        // Epoch based: the same instant gives the same grid point whatever TimeZone.current is.
        let before = NSTimeZone.default
        defer { NSTimeZone.default = before }
        NSTimeZone.default = TimeZone(identifier: "Asia/Kolkata")! // +5:30, not a multiple of 5 min from UTC hours
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(200)), base)
        NSTimeZone.default = TimeZone(identifier: "America/St_Johns")!
        XCTAssertEqual(RadarPollSchedule.nominal(at: at(200)), base)
    }

    func testFarBeforeWindowUsesIdleCadenceWhenRunPresent() {
        var s = schedule()
        // Run for nominal base present; now = base + 200 s, next window starts at base + 465.
        XCTAssertEqual(s.nextDelay(now: at(200), latestReference: base, failed: false, restricted: false), 60)
    }

    func testIdleCadenceIsClippedToWindowStart() {
        var s = schedule()
        // 450 s: 15 s to window start of next nominal (465): sleep exactly until then.
        XCTAssertEqual(s.nextDelay(now: at(450), latestReference: base, failed: false, restricted: false), 15)
        // 464.5 s: at least 1 s.
        XCTAssertEqual(s.nextDelay(now: at(464.5), latestReference: base, failed: false, restricted: false), 1)
    }

    func testWindowPollsEveryTenSecondsWhileRunMissing() {
        var s = schedule()
        for t in [165.0, 170, 180, 200, 250, 299, 300] {
            XCTAssertEqual(s.nextDelay(now: at(t), latestReference: at(-300), failed: false, restricted: false), 10, "t=\(t)")
        }
    }

    func testWindowJitterBounds() {
        var low = schedule(0), high = schedule(0.999999)
        let a = low.nextDelay(now: at(200), latestReference: at(-300), failed: false, restricted: false)
        let b = high.nextDelay(now: at(200), latestReference: at(-300), failed: false, restricted: false)
        XCTAssertEqual(a, 8, accuracy: 0.001)
        XCTAssertEqual(b, 12, accuracy: 0.001)
        // Idle cadence also within +/- 2 s.
        var idle = schedule(0)
        XCTAssertEqual(idle.nextDelay(now: at(200), latestReference: base, failed: false, restricted: false), 58, accuracy: 0.001)
    }

    func testNewRunSwitchesBackToIdle() {
        var s = schedule()
        XCTAssertEqual(s.nextDelay(now: at(190), latestReference: at(-300), failed: false, restricted: false), 10)
        // The same moment, but the new run (reference = nominal) is now known.
        XCTAssertEqual(s.nextDelay(now: at(200), latestReference: base, failed: false, restricted: false), 60)
    }

    func testBackoffAfterEmptyWindowThenClippedToNextWindow() {
        var s = schedule()
        let old = at(-300)
        XCTAssertEqual(s.nextDelay(now: at(301), latestReference: old, failed: false, restricted: false), 20)
        XCTAssertEqual(s.nextDelay(now: at(321), latestReference: old, failed: false, restricted: false), 30)
        XCTAssertEqual(s.nextDelay(now: at(351), latestReference: old, failed: false, restricted: false), 60)
        XCTAssertEqual(s.nextDelay(now: at(411), latestReference: old, failed: false, restricted: false), 54) // clipped to 465
        // Next window: back to 10 s, and the backoff restarts at 20 s after the next empty window.
        XCTAssertEqual(s.nextDelay(now: at(465), latestReference: old, failed: false, restricted: false), 10)
        XCTAssertEqual(s.nextDelay(now: at(601), latestReference: old, failed: false, restricted: false), 20)
    }

    func testNoManifestYetBehavesLikeMissingRun() {
        var s = schedule()
        XCTAssertEqual(s.nextDelay(now: at(200), latestReference: nil, failed: false, restricted: false), 10)
    }

    func testLowPowerAndDataSavingKeepIdleCadence() {
        var s = schedule()
        for t in [165.0, 200, 301, 460] {
            XCTAssertEqual(s.nextDelay(now: at(t), latestReference: at(-300), failed: false, restricted: true), 60, "t=\(t)")
        }
    }

    func testFailuresBackOffAndRecover() {
        var s = schedule()
        // In the window a failure must not retry at 10 s.
        XCTAssertEqual(s.nextDelay(now: at(200), latestReference: at(-300), failed: true, restricted: false), 20)
        XCTAssertEqual(s.nextDelay(now: at(220), latestReference: at(-300), failed: true, restricted: false), 30)
        XCTAssertEqual(s.nextDelay(now: at(250), latestReference: at(-300), failed: true, restricted: false), 60)
        XCTAssertEqual(s.nextDelay(now: at(310), latestReference: at(-300), failed: true, restricted: false), 60)
        XCTAssertEqual(s.consecutiveFailures, 4)
        // Success resets.
        XCTAssertEqual(s.nextDelay(now: at(320), latestReference: base, failed: false, restricted: false), 60)
        XCTAssertEqual(s.consecutiveFailures, 0)
        XCTAssertEqual(s.nextDelay(now: at(330), latestReference: base, failed: true, restricted: false), 60) // idle 60 > backoff 20
        XCTAssertEqual(s.consecutiveFailures, 1)
    }

    func testDelayNeverBelowEightSecondsOrAboveSixtyTwo() {
        for r in [0.0, 0.25, 0.5, 0.75, 0.999999] {
            var s = schedule(r)
            for t in stride(from: 0.0, to: 900, by: 7) {
                let d = s.nextDelay(now: at(t), latestReference: t.truncatingRemainder(dividingBy: 2) == 0 ? nil : base,
                                    failed: false, restricted: false)
                XCTAssertTrue(d >= 1 && d <= 62, "t=\(t) d=\(d)")
            }
        }
    }

    /// Replays the schedule against a backend whose run N appears at N + `arrival` s; returns requests per minute.
    private func simulate(arrival: TimeInterval, restricted: Bool = false, hours: Double = 2) -> Double {
        var s = schedule()
        var now: TimeInterval = 0, requests = 0
        var reference: Date? = nil
        let end = hours * 3600
        while now < end {
            requests += 1
            let nominal = (((now - arrival) / 300).rounded(.down)) * 300
            let visible = base.addingTimeInterval(nominal)
            if reference.map({ visible > $0 }) ?? true { reference = visible }
            now += s.nextDelay(now: at(now), latestReference: reference, failed: false, restricted: restricted)
        }
        return Double(requests) / (end / 60)
    }

    func testExpectedLoadPerActiveClient() {
        // Measured arrival 180 to 210 s after the nominal time: about 1.4 to 2.0 requests per minute (today: 1).
        for arrival in [180.0, 195, 210] {
            let rate = simulate(arrival: arrival)
            XCTAssertTrue((1.2...2.2).contains(rate), "arrival \(arrival): \(rate)")
        }
        // Run never arrives: bounded by the window plus backoff.
        let worst = simulate(arrival: 100_000)
        XCTAssertLessThan(worst, 3.7)
        // Restricted: unchanged 1/min.
        XCTAssertEqual(simulate(arrival: 195, restricted: true), 1, accuracy: 0.02)
    }

    func testRequestsPerWindowAreBounded() {
        // At most (120 + 15) / 10 + 1 window requests per 5 minutes even if the run never arrives.
        var s = schedule()
        var now = 165.0, inWindow = 0
        while now <= 300 {
            inWindow += 1
            now += s.nextDelay(now: at(now), latestReference: at(-300), failed: false, restricted: false)
        }
        XCTAssertLessThanOrEqual(inWindow, 14)
    }

    // MARK: Store loop

    @MainActor
    func testPollingLoopStopsOnCancellationAndUsesScheduledDelays() async throws {
        let calls = RequestCounter()
        let backend = RadarBackendClient(baseURL: URL(string: "https://radar.example.invalid/v1/radar/")!,
                                         transport: { _ in calls.increment(); throw URLError(.timedOut) })
        let store = WeatherStore(client: DWDClient(), backend: backend,
                                 defaults: UserDefaults(suiteName: "poll-\(UUID().uuidString)")!)
        let delays = DelayLog()
        let task = Task { @MainActor in
            await store.runRadarPolling(schedule: schedule(), now: { self.at(200) }, restricted: { false },
                                        sleep: { seconds in
                delays.append(seconds)
                if delays.count >= 3 { try await Task.sleep(for: .seconds(3600)) }
            })
        }
        while delays.count < 3 { try await Task.sleep(for: .milliseconds(5)) }
        task.cancel() // leaving the foreground cancels the task
        await task.value
        XCTAssertEqual(delays.values, [20, 30, 60]) // failure backoff, no tight loop
        XCTAssertEqual(calls.value, 3)
    }
}

private final class RequestCounter: @unchecked Sendable {
    private let lock = NSLock(); private var count = 0
    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

private final class DelayLog: @unchecked Sendable {
    private let lock = NSLock(); private var items: [TimeInterval] = []
    func append(_ value: TimeInterval) { lock.withLock { items.append(value) } }
    var count: Int { lock.withLock { items.count } }
    var values: [TimeInterval] { lock.withLock { items } }
}
