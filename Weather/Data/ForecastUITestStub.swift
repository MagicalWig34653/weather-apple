#if DEBUG
import Foundation

/// UI tests only (Debug builds): `-UITestForecast delayed|failed|behind` simulates the DWD run index and point
/// queries without network. The shown run is `ageMinutes` old (default: one grid step behind the expected run).
/// - `delayed`: first index query answers at once, later ones after 12 s ("Aktualisiere …" stays visible).
/// - `failed`: first index query answers, all later ones fail with HTTP 503.
/// - `behind`: queries always answer with the same (older) run, the index never offers a newer one.
enum ForecastUITestStub {
    static var mode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestForecast"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private final class Counter: @unchecked Sendable {
        private let lock = NSLock()
        private var indexes = 0
        func nextIndex() -> Int { lock.lock(); defer { lock.unlock() }; indexes += 1; return indexes }
    }

    static func client(mode: String) -> DWDClient {
        let counter = Counter()
        let runs = RadarPollSchedule.nominal(at: Date()).addingTimeInterval(mode == "behind" ? -900 : -300)
        return DWDClient(transport: { request in
            let url = request.url ?? DWDRequest.indexURL
            func response(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            if url.absoluteString == DWDRequest.indexURL.absoluteString {
                if counter.nextIndex() > 1 {
                    if mode == "failed" { return (Data(), response(503)) }
                    if mode == "delayed" { try await Task.sleep(for: .seconds(12)) }
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
        })
    }
}
#endif
