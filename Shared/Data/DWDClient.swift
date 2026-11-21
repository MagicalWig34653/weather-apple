import Foundation

actor DWDClient {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport
    private let clock: @Sendable () -> Date
    private let retryDelay: @Sendable (Int) -> TimeInterval
    private let requestTimeout: TimeInterval
    /// Reading of the running forecast load for the progress bar (measured only where every request reports a total).
    nonisolated let progress: LoadProgress
    private var cachedRuns: (fetchedAt: Date, dates: [Date])?
    private var pendingRuns: Task<[Date], Error>?
    private struct PointKey: Hashable {
        let coordinate: WeatherCoordinate
        let reference: Date
    }
    private var pendingPoints: [PointKey: Task<RainForecast, Error>] = [:]
    private var pointCache: [WeatherCoordinate: (fetchedAt: Date, forecast: RainForecast)] = [:]

    /// Request and whole-resource limit in seconds. The DWD WMS point query measurably needs 0.1 to 15 s (20.11.2026),
    /// so the visible app waits longer than widget and watch, which have a short time budget of their own.
    struct Timeouts: Sendable {
        let request: TimeInterval
        let resource: TimeInterval
        static let interactive = Timeouts(request: 25, resource: 30)
        static let background = Timeouts(request: 10, resource: 15)
    }

    init(transport: Transport? = nil, clock: @escaping @Sendable () -> Date = { Date() },
         retryDelay: @escaping @Sendable (Int) -> TimeInterval = { DWDRetryPolicy.delay(afterAttempt: $0) },
         timeouts: Timeouts = .interactive, progress: LoadProgress = LoadProgress()) {
        self.progress = progress
        self.clock = clock
        self.retryDelay = retryDelay
        self.requestTimeout = timeouts.request
        if let transport { self.transport = transport }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = timeouts.request
            configuration.timeoutIntervalForResource = timeouts.resource
            configuration.httpMaximumConnectionsPerHost = 4
            let session = URLSession(configuration: configuration)
            self.transport = { request in
                // With a progress handle (visible app) the body is read in a stream, so received bytes and the announced
                // `Content-Length` reach the bar; without one (widget, watch) the plain call stays.
                guard let handle = LoadProgress.activeRequest else {
                    let (data, response) = try await session.data(for: request)
                    guard let response = response as? HTTPURLResponse else { throw DWDDataError.invalidResponse }
                    return (data, response)
                }
                let (bytes, response) = try await session.bytes(for: request)
                guard let response = response as? HTTPURLResponse else { throw DWDDataError.invalidResponse }
                // A compressed answer announces the encoded length while the stream delivers decoded bytes: not comparable.
                let encoded = response.value(forHTTPHeaderField: "Content-Encoding").map { $0.lowercased() != "identity" } ?? false
                let announced: Int64? = response.expectedContentLength > 0 && !encoded ? response.expectedContentLength : nil
                var data = Data()
                if let announced, announced <= 2 * 1024 * 1024 { data.reserveCapacity(Int(announced)) }
                handle.report(expected: announced, received: 0)
                var count: Int64 = 0
                for try await byte in bytes {
                    data.append(byte)
                    count += 1
                    if count % 1024 == 0 { handle.report(expected: announced, received: count) }
                    if count > 2 * 1024 * 1024 + 1 { break }   // the size limit below rejects it; do not read on
                }
                handle.report(expected: announced, received: count)
                return (data, response)
            }
        }
    }

    /// `expectedNewest`: the run a fresh index should contain; the 5-minute index cache is skipped only
    /// while its newest run is older than that, otherwise the caches stay in use.
    func forecast(at coordinate: WeatherCoordinate, expectedNewest: Date? = nil) async throws -> RainForecast {
        guard coordinate.isSupported else { throw DWDDataError.unsupportedLocation }
        progress.begin(plannedRequests: cachedRuns(expectedNewest: expectedNewest) == nil && pendingRuns == nil ? 2 : 1)
        defer { progress.finish() }
        // Resolve the current run first: a still-fresh point must not hide a newer run.
        let dates = try await runs(expectedNewest: expectedNewest)
        try Task.checkCancellation()
        guard let reference = dates.last else { throw DWDDataError.unavailable }
        let now = clock()
        if let cached = pointCache[coordinate], now.timeIntervalSince(cached.fetchedAt) < 300,
           cached.forecast.referenceTime == reference, !cached.forecast.isStale(at: now) {
            return cached.forecast
        }
        let key = PointKey(coordinate: coordinate, reference: reference)
        if let pending = pendingPoints[key] {
            let forecast = try await pending.value
            try Task.checkCancellation()
            return forecast
        }
        // The shared task belongs to the client. Cancelling one consumer must not cancel another.
        let task = Task {
            let data = try await fetch(DWDRequest.pointURL(at: coordinate, referenceTime: reference))
            return try DWDResponse.forecast(from: data, expectedReference: reference, now: clock())
        }
        pendingPoints[key] = task
        do {
            let forecast = try await task.value
            pendingPoints[key] = nil
            // Bounded, memory-only cache. Never persist coordinate-bearing request URLs to disk.
            if pointCache.count >= 20 {
                if let oldest = pointCache.min(by: { $0.value.fetchedAt < $1.value.fetchedAt })?.key {
                    pointCache[oldest] = nil
                }
            }
            pointCache[coordinate] = (clock(), forecast)
            try Task.checkCancellation()
            return forecast
        } catch {
            pendingPoints[key] = nil
            throw error
        }
    }

    func radarRunTimeline(before unavailableReference: Date? = nil) async throws -> DWDRadarTimeline {
        let runs = try await runs()
        guard let reference = runs.last(where: { date in
            (unavailableReference.map { date < $0 } ?? true)
                && clock().timeIntervalSince(date) <= RainForecast.maximumAge
        }) else { throw DWDDataError.staleData }
        let history = runs.filter { $0 >= reference.addingTimeInterval(-3600) && $0 < reference }
        let nowcast = (0...24).map { reference.addingTimeInterval(Double($0 * 300)) }
        return DWDRadarTimeline(referenceTime: reference, dates: history + nowcast)
    }

    /// The cached run index while it may still be used (so no index request is needed).
    private func cachedRuns(expectedNewest: Date?) -> [Date]? {
        let now = clock()
        if let cachedRuns, now.timeIntervalSince(cachedRuns.fetchedAt) < 300,
           let latest = cachedRuns.dates.last,
           now.timeIntervalSince(latest) <= RainForecast.maximumAge,
           expectedNewest.map({ latest >= $0 }) ?? true {
            return cachedRuns.dates
        }
        return nil
    }

    private func runs(expectedNewest: Date? = nil) async throws -> [Date] {
        if let dates = cachedRuns(expectedNewest: expectedNewest) { return dates }
        if let pendingRuns { return try await pendingRuns.value }
        let task = Task {
            let data = try await fetch(DWDRequest.indexURL)
            return try DWDRunIndex.dates(from: data, now: clock())
        }
        pendingRuns = task
        do {
            let dates = try await task.value
            cachedRuns = (clock(), dates)
            pendingRuns = nil
            return dates
        } catch {
            pendingRuns = nil
            throw error
        }
    }

    /// At most `DWDRetryPolicy.maxAttempts` requests per call. Retries cover the HTTP-200
    /// `InvalidDimensionValue` answer, HTTP 502/503/504 and transient `URLError`s only.
    private func fetch(_ url: URL, attempt: Int = 1) async throws -> Data {
        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: requestTimeout)
        request.setValue("Showers (native iOS rain radar)", forHTTPHeaderField: "User-Agent")
        let canRetry = attempt < DWDRetryPolicy.maxAttempts
        let (data, response): (Data, HTTPURLResponse)
        let tracker = progress.startRequest()
        var completed = false
        defer { progress.endRequest(tracker, completed: completed) }
        do { (data, response) = try await LoadProgress.$activeRequest.withValue(tracker) { try await transport(request) } }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch let error as URLError where canRetry && DWDRetryPolicy.isTransient(error) {
            progress.endRequest(tracker, completed: false)
            return try await retry(url, attempt: attempt)
        }
        catch { throw DWDDataError.unavailable }
        if canRetry, DWDRetryPolicy.isTransient(statusCode: response.statusCode) {
            progress.endRequest(tracker, completed: false)
            return try await retry(url, attempt: attempt)
        }
        guard (200...299).contains(response.statusCode) else { throw DWDDataError.unavailable }
        guard !data.isEmpty else { throw DWDDataError.emptyBody }
        guard data.count <= 2 * 1024 * 1024 else { throw DWDDataError.oversizedBody }
        if let error = DWDResponse.serviceError(in: data) {
            if DWDRetryPolicy.shouldRetry(error, attempt: attempt) {
                progress.endRequest(tracker, completed: false)
                return try await retry(url, attempt: attempt)
            }
            throw error
        }
        completed = true
        return data
    }

    private func retry(_ url: URL, attempt: Int) async throws -> Data {
        try await Task.sleep(for: .seconds(retryDelay(attempt)))
        return try await fetch(url, attempt: attempt + 1)
    }
}
