import Foundation

actor DWDClient {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport
    private let clock: @Sendable () -> Date
    private let retryDelay: @Sendable (Int) -> TimeInterval
    private var cachedRuns: (fetchedAt: Date, dates: [Date])?
    private var pendingRuns: Task<[Date], Error>?
    private struct PointKey: Hashable {
        let coordinate: WeatherCoordinate
        let reference: Date
    }
    private var pendingPoints: [PointKey: Task<RainForecast, Error>] = [:]
    private var pointCache: [WeatherCoordinate: (fetchedAt: Date, forecast: RainForecast)] = [:]

    init(transport: Transport? = nil, clock: @escaping @Sendable () -> Date = { Date() },
         retryDelay: @escaping @Sendable (Int) -> TimeInterval = { RadarRetryPolicy.delay(afterAttempt: $0) }) {
        self.clock = clock
        self.retryDelay = retryDelay
        if let transport { self.transport = transport }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 10
            configuration.timeoutIntervalForResource = 15
            configuration.httpMaximumConnectionsPerHost = 4
            let session = URLSession(configuration: configuration)
            self.transport = { request in
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw DWDDataError.invalidResponse }
                return (data, response)
            }
        }
    }

    func forecast(at coordinate: WeatherCoordinate) async throws -> RainForecast {
        guard coordinate.isSupported else { throw DWDDataError.unsupportedLocation }
        // Resolve the current run first: a still-fresh point must not hide a newer run.
        let dates = try await runs()
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

    func radarTimeline(before unavailableReference: Date? = nil) async throws -> RadarTimeline {
        let runs = try await runs()
        guard let reference = runs.last(where: { date in
            (unavailableReference.map { date < $0 } ?? true)
                && clock().timeIntervalSince(date) <= RainForecast.maximumAge
        }) else { throw DWDDataError.staleData }
        let history = runs.filter { $0 >= reference.addingTimeInterval(-3600) && $0 < reference }
        let nowcast = (0...24).map { reference.addingTimeInterval(Double($0 * 300)) }
        return RadarTimeline(referenceTime: reference, dates: history + nowcast)
    }

    private func runs() async throws -> [Date] {
        let now = clock()
        if let cachedRuns, now.timeIntervalSince(cachedRuns.fetchedAt) < 300,
           let latest = cachedRuns.dates.last,
           now.timeIntervalSince(latest) <= RainForecast.maximumAge {
            return cachedRuns.dates
        }
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

    private func fetch(_ url: URL, attempt: Int = 1) async throws -> Data {
        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("Weather/0.1 (native iOS rain radar)", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, HTTPURLResponse)
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw DWDDataError.unavailable }
        guard (200...299).contains(response.statusCode) else { throw DWDDataError.unavailable }
        guard !data.isEmpty, data.count <= 2 * 1024 * 1024 else { throw DWDDataError.invalidResponse }
        if let error = DWDResponse.serviceError(in: data) {
            if RadarRetryPolicy.shouldRetry(error, attempt: attempt) {
                try await Task.sleep(for: .seconds(retryDelay(attempt)))
                return try await fetch(url, attempt: attempt + 1)
            }
            throw error
        }
        return data
    }
}
