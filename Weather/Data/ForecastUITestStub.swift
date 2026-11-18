#if DEBUG
import Foundation

/// UI tests only (Debug builds): `-UITestForecast delayed|failed|failonce|behind|current` simulates the DWD run index,
/// point queries and the radar cache without network, with a frozen clock so light and dark screenshots show the same texts.
/// - `delayed`: first index query answers at once, later ones after 40 s ("Aktualisiere …" stays visible).
/// - `failed`: first index query answers, all later ones fail with HTTP 503.
/// - `failonce`: exactly one failing load (the 2nd to 4th index request, i.e. one query with its retries), then normal answers.
/// - `current`: the shown run is the expected newest one (normal state, "Stand vor 5 Min.").
/// - `behind`: the index never offers a newer run than the shown one ("Stand vor 10 Min.").
/// - `slowbehind`: like `behind`, later index queries answer after 6 s (load ends without newer data).
/// - `slowfailed`: later index queries fail with HTTP 503 after 4 s each (load ends with an error).
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
    }

    static func client(mode: String) -> DWDClient {
        let counter = Counter()
        let runs = RadarPollSchedule.nominal(at: now).addingTimeInterval(mode == "current" ? 0 : -300)
        return DWDClient(transport: { request in
            let url = request.url ?? DWDRequest.indexURL
            func response(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            if url.absoluteString == DWDRequest.indexURL.absoluteString {
                let number = counter.nextIndex()
                if number == 1, mode == "firstload" { try await Task.sleep(for: .seconds(25)) }
                if number > 1 {
                    if mode == "failed" || (mode == "failonce" && number <= 4) { return (Data(), response(503)) }
                    if mode == "delayed" { try await Task.sleep(for: .seconds(40)) }
                    if mode == "slowfailed" { try await Task.sleep(for: .seconds(4)); return (Data(), response(503)) }
                    if mode == "slowbehind" { try await Task.sleep(for: .seconds(6)) }
                }
                let day = DateFormatter()
                day.locale = Locale(identifier: "en_US_POSIX"); day.timeZone = TimeZone(identifier: "UTC")
                day.dateFormat = "yyyyMMdd_HHmm"
                return (Data("<a href=\"composite_rv_\(day.string(from: runs)).tar\">x</a>".utf8), response(200))
            }
            let features = (0..<25).map { step -> String in
                let time = DWDRequest.timestamp(runs.addingTimeInterval(Double(step * 300)))
                let value = step % 7 < 3 ? 0.6 : -0.001
                return "{\"type\":\"Feature\",\"id\":\"f\(step)\",\"geometry\":null,\"properties\":{\"RV_ANALYSIS\":\(value),\"TIME\":\"\(time)\",\"REFERENCE_TIME\":\"\(DWDRequest.timestamp(runs))\"}}"
            }
            return (Data("{\"type\":\"FeatureCollection\",\"features\":[\(features.joined(separator: ","))]}".utf8), response(200))
        }, clock: { now })
    }
}
#endif
