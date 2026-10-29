import XCTest
@testable import Weather

final class TimelineSlotTests: XCTestCase {
    func testIndexFollowsInputImmediatelyAndClamps() {
        XCTAssertEqual(TimelineSlot.index(for: 0, count: 10), 0)
        XCTAssertEqual(TimelineSlot.index(for: 2.9999, count: 10), 3)
        XCTAssertEqual(TimelineSlot.index(for: 4.4, count: 10), 4)
        XCTAssertEqual(TimelineSlot.index(for: 99, count: 10), 9)
        XCTAssertEqual(TimelineSlot.index(for: -3, count: 10), 0)
        XCTAssertEqual(TimelineSlot.index(for: .nan, count: 10), 0)
        XCTAssertEqual(TimelineSlot.index(for: 1, count: 0), 0)
    }

    func testStatusIsLoadingUntilReportedAndFailedOnlyWithoutSuccess() {
        let now = Date()
        func state(requested: Int, succeeded: Int, failed: Int, pending: Int) -> RadarLoadState {
            var s = RadarLoadState(contextID: UUID(), frameDate: now, referenceTime: now, reloadRevision: 0)
            s.requested = requested; s.succeeded = succeeded; s.failed = failed; s.pending = pending
            return s
        }
        XCTAssertEqual(TimelineSlot.status(for: nil), .loading)
        XCTAssertEqual(TimelineSlot.status(for: state(requested: 4, succeeded: 1, failed: 0, pending: 3)), .loading)
        XCTAssertEqual(TimelineSlot.status(for: state(requested: 4, succeeded: 0, failed: 4, pending: 0)), .failed)
        XCTAssertEqual(TimelineSlot.status(for: state(requested: 4, succeeded: 3, failed: 1, pending: 0)), .ready)
    }
}
