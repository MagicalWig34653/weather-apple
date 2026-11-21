import Foundation

/// Measurable progress of one load (e.g. the point forecast: run index, then point query).
///
/// A fraction exists only where it is real: every request the load plans must have reported a total size
/// (`Content-Length`) and bytes received. One unknown total (the DWD answers are chunked, 21.11.2026) makes the
/// whole reading `.indeterminate`; no percent is ever estimated. The value never moves backwards during one load
/// (a retry starts at zero bytes again).
final class LoadProgress: @unchecked Sendable {
    enum Reading: Equatable, Sendable { case indeterminate, measured(Double) }

    /// Handle of one request. The transport reports through `LoadProgress.activeRequest` (a task-local), so the
    /// `DWDClient.Transport` signature stays as it is and tests, stubs and the real transport use the same path.
    final class Request: @unchecked Sendable {
        fileprivate let owner: LoadProgress
        fileprivate var expected: Int64?
        fileprivate var received: Int64 = 0
        fileprivate var done = false
        fileprivate init(owner: LoadProgress) { self.owner = owner }

        func report(expected: Int64?, received: Int64) {
            owner.lock.withLock {
                self.expected = expected.flatMap { $0 > 0 ? $0 : nil }
                self.received = max(received, 0)
                owner.updateHighWater()
            }
        }
    }

    @TaskLocal static var activeRequest: Request?

    private let lock = NSLock()
    private var planned = 0
    private var requests: [Request] = []
    private var highWater = 0.0

    var reading: Reading { lock.withLock { current() } }

    /// Starts a load that will make `plannedRequests` requests (0 = unknown, never measured).
    func begin(plannedRequests: Int) {
        lock.withLock { planned = plannedRequests; requests = []; highWater = 0 }
    }

    func startRequest() -> Request {
        let request = Request(owner: self)
        lock.withLock { requests.append(request) }
        return request
    }

    /// `completed: false` (failure, retry, cancellation) drops the request's bytes; the high-water mark keeps the value.
    func endRequest(_ request: Request, completed: Bool) {
        lock.withLock {
            if completed { request.done = true } else { requests.removeAll { $0 === request } }
        }
    }

    func finish() {
        lock.withLock { planned = 0; requests = []; highWater = 0 }
    }

    // Callers hold the lock.
    private func fraction() -> Double? {
        guard planned > 0, requests.count == planned, requests.allSatisfy({ $0.expected != nil }) else { return nil }
        let total = requests.reduce(Int64(0)) { $0 + ($1.expected ?? 0) }
        guard total > 0 else { return nil }
        let received = requests.reduce(Int64(0)) { $0 + ($1.done ? ($1.expected ?? 0) : min($1.received, $1.expected ?? 0)) }
        return min(Double(received) / Double(total), 1)
    }

    private func updateHighWater() { if let value = fraction() { highWater = max(highWater, value) } }

    private func current() -> Reading {
        guard let value = fraction() else { return .indeterminate }
        return .measured(max(value, highWater))
    }
}
