#if DEBUG
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// UI tests only (Debug builds): `-UITestForecast delayed|failed|failonce|behind|current` simulates the DWD run index,
/// point queries and the radar cache without network, with a frozen clock so light and dark screenshots show the same texts.
/// - `delayed`: first index query answers at once, later ones after 40 s ("Aktualisiere …" stays visible).
/// - `delayedreturn`: like `delayed`, but only from the first trip to the background on: index queries before that answer at once.
///   With the frozen clock a newer run is always "expected", so in about half of the cold starts the loop starts a second request
///   right after the start-up load (it races with the scene becoming active); with `delayed` that request stalls for 40 s and the
///   header already "refreshes" at the start. Here it is answered at once (invisible), and the load the test triggers by going to
///   the background and back is the first one that stalls. For tests that need "start settled" before they trigger the load.
/// - `failed`: first index query answers, all later ones fail with HTTP 503.
/// - `failonce`: exactly one failing load (the 2nd to 4th index request, i.e. one query with its retries), then normal answers.
/// - `current`: the shown run is the expected newest one (normal state, "Stand vor 5 Min.").
/// - `behind`: the index never offers a newer run than the shown one ("Stand vor 10 Min.").
/// - `slowbehind`: like `behind`, later index queries answer after 6 s (load ends without newer data).
/// - `slowfailed`: later index queries fail with HTTP 503 after 4 s each (load ends with an error).
/// - `slowfailedreturn`, `slowfreshreturn`: like `slowfailed` / `slowfresh`, but only from the first trip to the background on (before that like
///   `behind`: answers at once). Same reason as `delayedreturn`: the early loop request of the frozen clock must not run visibly at the start
///   (Build 58: the start is settled in every cold start, the tests need no restart window).
/// - `rununavailable`: from the 2nd index query on the index lists the NEWER run 08:45, but the first 6 point queries for it
///   (two loads with their three attempts each) answer HTTP 200 with a WMS `InvalidDimensionValue` report (run not ready), then
///   the service delivers that run (Build 53, fix 5d0c741: a not ready run is no failure).
/// - `failrecover`: index queries 2 to 7 (two loads with three attempts each) fail with HTTP 503 (confirmed failure), then the
///   index lists the newer run 08:45 and everything answers normally (recovery clears the failure text).
/// - `measured`: later loads report their sizes like a transport with `Content-Length` (index 100 of 100 bytes and the NEWER run 08:45,
///   point query for it 100 of 300 bytes, then it stalls for 90 s): the bar is measured at 50 % ("Aktualisiere …" stays visible). `delayed` is the
///   counterpart without any size (bar runs through, no percent).
/// - `slowfresh`: later index queries answer after 6 s and list the NEWER run 08:45 (load ends with new data: the bar ends after success).
/// All other modes show the run 08:40 UTC (10 minutes old), while a newer one is expected.
enum ForecastUITestStub {
    static var mode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestForecast"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    /// Frozen "now" (09:50 in Berlin): 5 minutes after the grid point 08:45 UTC, so the run 08:45 is expected and the
    /// request time (+ 200 s) and grace (+ 60 s) have passed. Used by the store, the DWD client and the forecast header.
    static let now = DWDRequest.date("2026-11-18T08:50:00.000Z")!

    /// The simulator's radar cache is unreachable, so the map falls back to the direct DWD path with the frozen run.
    static let backend = RadarBackendClient(transport: { _ in throw URLError(.notConnectedToInternet) }, clock: { now })

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var indexes = 0
        func nextIndex() -> Int { lock.lock(); defer { lock.unlock() }; indexes += 1; return indexes }
        private var points = 0
        func nextPoint() -> Int { lock.lock(); defer { lock.unlock() }; points += 1; return points }
    }

    /// `delayedreturn`: true once the app went to the background for the first time.
    private final class BackgroundTrip: @unchecked Sendable {
        private let lock = NSLock()
        private var left = false
        var hasLeft: Bool { lock.lock(); defer { lock.unlock() }; return left }
        init() {
            #if canImport(UIKit)
            NotificationCenter.default.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
                guard let self else { return }
                self.lock.lock(); self.left = true; self.lock.unlock()
            }
            #endif
        }
    }

    static func client(mode requested: String) -> DWDClient {
        let counter = Counter()
        let trip = BackgroundTrip()
        let runs = RadarPollSchedule.nominal(at: now).addingTimeInterval(requested == "current" ? 0 : -300)
        return DWDClient(transport: { request in
            // `slowfailedreturn` / `slowfreshreturn`: like `behind` (answers at once, no newer run) until the first trip to the background,
            // then exactly `slowfailed` / `slowfresh`.
            let mode = requested.hasSuffix("return") && requested != "delayedreturn" ? (trip.hasLeft ? String(requested.dropLast("return".count)) : "behind") : requested
            let url = request.url ?? DWDRequest.indexURL
            func response(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            if url.absoluteString == DWDRequest.indexURL.absoluteString {
                let number = counter.nextIndex()
                if number == 1, mode == "firstload" { try await Task.sleep(for: .seconds(25)) }
                if number > 1 {
                    if mode == "measured" { LoadProgress.activeRequest?.report(expected: 100, received: 100) }
                    if mode == "failed" || (mode == "failonce" && number <= 4) || (mode == "failrecover" && number <= 7) { return (Data(), response(503)) }
                    if mode == "delayed" || (mode == "delayedreturn" && trip.hasLeft) { try await Task.sleep(for: .seconds(40)) }
                    if mode == "slowfailed" { try await Task.sleep(for: .seconds(4)); return (Data(), response(503)) }
                    if mode == "slowbehind" || mode == "slowfresh" { try await Task.sleep(for: .seconds(6)) }
                }
                let day = DateFormatter()
                day.locale = Locale(identifier: "en_US_POSIX"); day.timeZone = TimeZone(identifier: "UTC")
                day.dateFormat = "yyyyMMdd_HHmm"
                let listsNewer = (mode == "rununavailable" && number > 1) || (mode == "slowfresh" && number > 1) || (mode == "measured" && number > 1) || (mode == "failrecover" && number > 7)
                return (Data("<a href=\"composite_rv_\(day.string(from: listsNewer ? runs.addingTimeInterval(300) : runs)).tar\">x</a>".utf8), response(200))
            }
            let point = counter.nextPoint()
            if mode == "measured", point > 1 {
                LoadProgress.activeRequest?.report(expected: 300, received: 100)
                try await Task.sleep(for: .seconds(90))
            }
            if mode == "rununavailable", (2...7).contains(point) {
                let report = "<?xml version=\"1.0\"?><ServiceExceptionReport><ServiceException code=\"InvalidDimensionValue\">Invalid reference time</ServiceException></ServiceExceptionReport>"
                return (Data(report.utf8), response(200))
            }
            // The newer-run modes answer for the run the app asked for (DIM_REFERENCE_TIME); all other modes keep `runs`.
            var reference = runs
            if mode == "rununavailable" || mode == "failrecover" || mode == "slowfresh" || mode == "measured",
               let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "DIM_REFERENCE_TIME" })?.value,
               let asked = DWDRequest.date(value) { reference = asked }
            let features = (0..<25).map { step -> String in
                let time = DWDRequest.timestamp(reference.addingTimeInterval(Double(step * 300)))
                let value = step % 7 < 3 ? 0.6 : -0.001
                return "{\"type\":\"Feature\",\"id\":\"f\(step)\",\"geometry\":null,\"properties\":{\"RV_ANALYSIS\":\(value),\"TIME\":\"\(time)\",\"REFERENCE_TIME\":\"\(DWDRequest.timestamp(reference))\"}}"
            }
            return (Data("{\"type\":\"FeatureCollection\",\"features\":[\(features.joined(separator: ","))]}".utf8), response(200))
        }, clock: { now })
    }
}
#endif
