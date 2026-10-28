import Foundation

actor DWDClient {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let transport: Transport
    private let clock: @Sendable () -> Date
    private var cachedRuns: (fetchedAt: Date, dates: [Date])?
    private var pendingRuns: Task<[Date], Error>?
    private var pointCache: [WeatherCoordinate: (fetchedAt: Date, forecast: RainForecast)] = [:]

    init(transport: Transport? = nil, clock: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = clock
        if let transport { self.transport = transport }
        else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
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
        let now = clock()
        if let cached = pointCache[coordinate], now.timeIntervalSince(cached.fetchedAt) < 300,
           !cached.forecast.isStale(at: now) {
            return cached.forecast
        }
        let dates = try await runs()
        guard let reference = dates.last else { throw DWDDataError.unavailable }
        let data = try await fetch(DWDRequest.pointURL(at: coordinate, referenceTime: reference))
        let forecast = try DWDResponse.forecast(from: data, expectedReference: reference, now: clock())
        // Bounded, memory-only cache. Never persist coordinate-bearing request URLs to disk.
        if pointCache.count >= 20 { pointCache.removeAll() }
        pointCache[coordinate] = (clock(), forecast)
        return forecast
    }

    func radarTimeline() async throws -> RadarTimeline {
        let runs = try await runs()
        guard let reference = runs.last else { throw DWDDataError.unavailable }
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

    private func fetch(_ url: URL) async throws -> Data {
        try Task.checkCancellation()
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.setValue("Weather/0.1 (native iOS rain radar)", forHTTPHeaderField: "User-Agent")
        let (data, response): (Data, HTTPURLResponse)
        do { (data, response) = try await transport(request) }
        catch is CancellationError { throw CancellationError() }
        catch let error as URLError where error.code == .cancelled { throw CancellationError() }
        catch { throw DWDDataError.unavailable }
        guard (200...299).contains(response.statusCode) else { throw DWDDataError.unavailable }
        guard !data.isEmpty, data.count <= 2 * 1024 * 1024 else { throw DWDDataError.invalidResponse }
        return data
    }
}
