import XCTest
@testable import Weather

final class SharedDWDTests: XCTestCase {
    func testSharedRetryPolicyMatchesExistingBoundedRetryBehavior() {
        XCTAssertEqual(DWDRetryPolicy.maxAttempts, 3)
        XCTAssertEqual(DWDRetryPolicy.delay(afterAttempt: 1, jitter: 1), 0.3)
        XCTAssertEqual(DWDRetryPolicy.delay(afterAttempt: 2, jitter: 1), 0.6)
        XCTAssertTrue(DWDRetryPolicy.shouldRetry(DWDDataError.runUnavailable, attempt: 2))
        XCTAssertFalse(DWDRetryPolicy.shouldRetry(DWDDataError.runUnavailable, attempt: 3))
        XCTAssertFalse(DWDRetryPolicy.shouldRetry(DWDDataError.malformedPayload, attempt: 1))
        for status in [502, 503, 504] { XCTAssertTrue(DWDRetryPolicy.isTransient(statusCode: status)) }
        for status in [200, 400, 404, 500] { XCTAssertFalse(DWDRetryPolicy.isTransient(statusCode: status)) }
        for code in [URLError.Code.timedOut, .networkConnectionLost, .cannotConnectToHost, .dnsLookupFailed] {
            XCTAssertTrue(DWDRetryPolicy.isTransient(URLError(code)))
        }
        for code in [URLError.Code.cancelled, .notConnectedToInternet, .dataNotAllowed] {
            XCTAssertFalse(DWDRetryPolicy.isTransient(URLError(code)))
        }
    }
}
