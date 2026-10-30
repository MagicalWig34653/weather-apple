import Foundation

/// Radar cache backend (public ShowerNow service). The app sends no location, cookies or
/// identifying headers; the server sees only the request itself (IP address technically).
enum RadarBackendConfig {
    static let productionBaseURL = URL(string: "https://showernow.linolaske.de/v1/radar/")!
    /// Same freshness bound as the direct DWD path (`RainForecast.maximumAge`).
    static let maximumDataAge: TimeInterval = RainForecast.maximumAge
    /// Re-check interval for `latest.json` while the app is visible (ETag, 304 is cheap).
    static let pollInterval: TimeInterval = 60
    /// After the backend delivered no usable images, stay on the direct path for a while.
    static let imageFailureBlockInterval: TimeInterval = 300
    static let maximumManifestBytes = 256 * 1024
    static let maximumImageBytes = 1_048_576

    /// Debug builds accept `-radar-backend-url <https-url>` so the fallback path can be exercised.
    static func baseURL(arguments: [String] = ProcessInfo.processInfo.arguments) -> URL {
        #if DEBUG
        if let index = arguments.firstIndex(of: "-radar-backend-url"), arguments.indices.contains(index + 1),
           var components = URLComponents(string: arguments[index + 1]),
           components.scheme == "https" || components.scheme == "http", components.host != nil {
            if !components.path.hasSuffix("/") { components.path += "/" }
            if let url = components.url { return url }
        }
        #endif
        return productionBaseURL
    }
}

enum RadarBackendError: Error, Equatable, Sendable {
    case unsupportedSchema(Int)
    case invalid
    case notPublished
    case unreachable
    case stale
}

/// Web-Mercator bounding box in meters (EPSG:3857).
struct RadarBounds: Equatable, Sendable {
    let minX: Double, minY: Double, maxX: Double, maxY: Double
    static let halfWorld = 20_037_508.342789244
}

struct RadarManifest: Equatable, Sendable {
    enum Kind: String, Sendable { case analysis, forecast }
    struct Slot: Equatable, Sendable {
        let time: Date
        let kind: Kind
        let path: String
        let url: URL
    }

    let run: String
    let referenceTime: Date
    let generatedAt: Date
    let stepMinutes: Int
    let imageWidth: Int
    let imageHeight: Int
    let bounds: RadarBounds
    let slots: [Slot]
    let attribution: String
    let modificationNotice: String

    /// Data age is measured from the nominal run time (as for the direct DWD path);
    /// `generated_at` is only a plausibility bound.
    func isFresh(at now: Date) -> Bool {
        now.timeIntervalSince(referenceTime) <= RadarBackendConfig.maximumDataAge
            && referenceTime.timeIntervalSince(now) <= 60
            && generatedAt.timeIntervalSince(now) <= 60
    }

    func slot(at date: Date) -> Slot? { slots.first { $0.time == date } }

    var timeline: RadarTimeline {
        RadarTimeline(referenceTime: referenceTime, dates: slots.map(\.time), backend: self)
    }

    // MARK: Parsing

    private struct SchemaProbe: Decodable { let schema: Int }
    private struct Raw: Decodable {
        struct Image: Decodable {
            let format: String, width: Int, height: Int, projection: String, bbox: [Double]
        }
        struct RawSlot: Decodable { let time: String, kind: String, path: String }
        let schema: Int, run: String
        let referenceTime: String, generatedAt: String
        let stepMinutes: Int
        let image: Image
        let slots: [RawSlot]
        let attribution: String, modificationNotice: String
    }

    static func parse(_ data: Data, baseURL: URL) throws -> RadarManifest {
        guard !data.isEmpty, data.count <= RadarBackendConfig.maximumManifestBytes else { throw RadarBackendError.invalid }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let probe: SchemaProbe
        do { probe = try decoder.decode(SchemaProbe.self, from: data) } catch { throw RadarBackendError.invalid }
        guard probe.schema == 1 else { throw RadarBackendError.unsupportedSchema(probe.schema) }
        let raw: Raw
        do { raw = try decoder.decode(Raw.self, from: data) } catch { throw RadarBackendError.invalid }

        guard isRunID(raw.run),
              let reference = DWDRequest.date(raw.referenceTime), let generated = DWDRequest.date(raw.generatedAt),
              (1...60).contains(raw.stepMinutes),
              raw.image.format == "image/webp", raw.image.projection == "EPSG:3857",
              (1...4096).contains(raw.image.width), (1...4096).contains(raw.image.height),
              raw.image.bbox.count == 4, raw.image.bbox.allSatisfy({ $0.isFinite && abs($0) <= RadarBounds.halfWorld + 1 }),
              raw.image.bbox[0] < raw.image.bbox[2], raw.image.bbox[1] < raw.image.bbox[3],
              !raw.attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !raw.modificationNotice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...200).contains(raw.slots.count) else { throw RadarBackendError.invalid }

        var slots: [Slot] = []
        for item in raw.slots {
            guard let time = DWDRequest.date(item.time), let kind = Kind(rawValue: item.kind),
                  isSafe(path: item.path), let url = URL(string: item.path, relativeTo: baseURL)?.absoluteURL,
                  url.host == baseURL.host, url.scheme == baseURL.scheme,
                  url.path.hasPrefix(baseURL.path) else { throw RadarBackendError.invalid }
            if let last = slots.last, time <= last.time { throw RadarBackendError.invalid }
            slots.append(Slot(time: time, kind: kind, path: item.path, url: url))
        }
        guard slots.contains(where: { $0.time == reference }) else { throw RadarBackendError.invalid }
        return RadarManifest(run: raw.run, referenceTime: reference, generatedAt: generated, stepMinutes: raw.stepMinutes,
                             imageWidth: raw.image.width, imageHeight: raw.image.height,
                             bounds: RadarBounds(minX: raw.image.bbox[0], minY: raw.image.bbox[1],
                                                 maxX: raw.image.bbox[2], maxY: raw.image.bbox[3]),
                             slots: slots, attribution: raw.attribution, modificationNotice: raw.modificationNotice)
    }

    private static func isRunID(_ text: String) -> Bool {
        text.range(of: #"^\d{8}T\d{4}Z$"#, options: .regularExpression) != nil
    }

    /// Relative `<run>/<slot>.webp` only: no scheme, traversal, query or absolute path.
    static func isSafe(path: String) -> Bool {
        path.range(of: #"^[0-9A-Za-z]{1,32}/[0-9A-Za-z]{1,32}\.webp$"#, options: .regularExpression) != nil
    }
}

/// Selection stays on the same instant across runs; "now" follows the new reference.
enum RadarTimelineSelection {
    static func index(previous: Date?, previousReference: Date?, dates: [Date], reference: Date) -> Int {
        guard !dates.isEmpty else { return 0 }
        let referenceIndex = dates.firstIndex(of: reference)
            ?? dates.indices.min { abs(dates[$0].timeIntervalSince(reference)) < abs(dates[$1].timeIntervalSince(reference)) }!
        guard let previous, previous != previousReference else { return referenceIndex }
        if let exact = dates.firstIndex(of: previous) { return exact }
        return dates.indices.min { abs(dates[$0].timeIntervalSince(previous)) < abs(dates[$1].timeIntervalSince(previous)) }!
    }
}

/// Maps the EPSG:3857 image bounds onto MapKit's map-point space (same projection).
enum RadarImageGeometry {
    static func mapRect(for bounds: RadarBounds, worldSize: Double = 268_435_456) -> (x: Double, y: Double, width: Double, height: Double) {
        let span = 2 * RadarBounds.halfWorld
        let x = (bounds.minX + RadarBounds.halfWorld) / span * worldSize
        let y = (RadarBounds.halfWorld - bounds.maxY) / span * worldSize
        return (x, y, (bounds.maxX - bounds.minX) / span * worldSize, (bounds.maxY - bounds.minY) / span * worldSize)
    }
}

/// Bounded retries for the HTTP-200 `InvalidDimensionValue` XML answers of the DWD GetMap
/// service (measured: about one in three, randomly alternating, also for valid runs).
enum RadarRetryPolicy {
    static let maxAttempts = 3
    /// Delay before retry number `attempt` (1 = first retry): 0.3 s, 0.6 s, each ±25 % jitter.
    static func delay(afterAttempt attempt: Int, jitter: Double = Double.random(in: 0.75...1.25)) -> TimeInterval {
        0.3 * pow(2, Double(max(0, attempt - 1))) * jitter
    }
    static func shouldRetry(_ error: Error?, attempt: Int) -> Bool {
        (error as? DWDDataError) == .runUnavailable && attempt < maxAttempts
    }
}

// MARK: - Client

actor RadarBackendClient {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    enum Outcome: Equatable, Sendable {
        case fresh(RadarManifest, changed: Bool)
        case fallback(RadarBackendError)
    }

    let baseURL: URL
    private let transport: Transport
    private let clock: @Sendable () -> Date
    private var etag: String?
    private var last: RadarManifest?

    init(baseURL: URL = RadarBackendConfig.baseURL(), transport: Transport? = nil,
         clock: @escaping @Sendable () -> Date = { Date() }) {
        self.baseURL = baseURL
        self.clock = clock
        if let transport { self.transport = transport } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.urlCredentialStorage = nil
            configuration.timeoutIntervalForRequest = 6
            configuration.timeoutIntervalForResource = 10
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            self.transport = { request in
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw RadarBackendError.invalid }
                return (data, response)
            }
        }
    }

    func latest() async -> Outcome {
        var request = URLRequest(url: baseURL.appendingPathComponent("latest.json"),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag, last != nil { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport(request) }
        catch { return .fallback(.unreachable) }
        let manifest: RadarManifest
        switch response.statusCode {
        case 304:
            guard let last else { return .fallback(.invalid) }
            manifest = last
        case 200:
            do { manifest = try RadarManifest.parse(data, baseURL: baseURL) }
            catch { return .fallback(error as? RadarBackendError ?? .invalid) }
        case 404:
            etag = nil; last = nil
            return .fallback(.notPublished)
        default:
            return .fallback(.unreachable)
        }
        let changed = manifest != last
        if response.statusCode == 200 { etag = response.value(forHTTPHeaderField: "ETag") }
        last = manifest
        guard manifest.isFresh(at: clock()) else { return .fallback(.stale) }
        return .fresh(manifest, changed: changed)
    }
}
