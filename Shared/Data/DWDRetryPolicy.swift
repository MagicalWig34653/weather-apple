import Foundation

/// Bounded retries for direct DWD requests, independent of the radar backend.
enum DWDRetryPolicy {
    static let maxAttempts = 3

    static func delay(afterAttempt attempt: Int, jitter: Double = Double.random(in: 0.75...1.25)) -> TimeInterval {
        0.3 * pow(2, Double(max(0, attempt - 1))) * jitter
    }

    static func shouldRetry(_ error: Error?, attempt: Int) -> Bool {
        (error as? DWDDataError) == .runUnavailable && attempt < maxAttempts
    }

    static func isTransient(statusCode: Int) -> Bool { [502, 503, 504].contains(statusCode) }

    static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed: true
        default: false
        }
    }
}
