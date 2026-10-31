import Foundation
import Observation

/// Map layers shown over the base map. Exactly one is active; `.radar` is the default and keeps its own
/// code path (cache backend with DWD fallback). All other layers exist only on the cache backend
/// (`/v1/layers/<id>/`) and have NO direct DWD fallback. `cloudmask` is shown as the "Sonne" layer: the app
/// combines the cloud mask with the computed sun position (`SunOverlay`).
enum RadarLayer: String, CaseIterable, Identifiable, Sendable {
    case radar, pressure, lightning, clouds, cloudmask

    var id: String { rawValue }

    /// Layers the user can choose (the cloud mask is the data basis of the sun layer).
    static let selectable: [RadarLayer] = [.radar, .pressure, .lightning, .clouds, .cloudmask]
    /// Layers fetched from the backend's `/v1/layers/<id>/` API.
    static let backendLayers: [RadarLayer] = [.pressure, .lightning, .clouds, .cloudmask]

    var isBackendLayer: Bool { self != .radar }

    var title: String {
        switch self {
        case .radar: "Regenradar"
        case .pressure: "Luftdruck"
        case .lightning: "Blitze"
        case .clouds: "Wolken"
        case .cloudmask: "Sonne"
        }
    }

    /// German VoiceOver name.
    var spokenName: String {
        switch self {
        case .radar: "Regenradar"
        case .pressure: "Luftdruck, Isobaren"
        case .lightning: "Blitze"
        case .clouds: "Wolken, Satellitenbild"
        case .cloudmask: "Sonne, Rückblick aus Satellit und Sonnenstand"
        }
    }

    var symbolName: String {
        switch self {
        case .radar: "cloud.rain"
        case .pressure: "gauge.with.dots.needle.33percent"
        case .lightning: "bolt.fill"
        case .clouds: "cloud"
        case .cloudmask: "sun.max"
        }
    }

    /// VoiceOver label of the time slider.
    var timeAxisLabel: String { self == .radar ? "Radarzeitpunkt" : "Zeitpunkt \(title)" }

    /// Own time grid per layer (minutes); only documentation/tests, the real step comes from the manifest.
    var nominalStepMinutes: Int {
        switch self {
        case .radar, .lightning: 5
        case .clouds: 10
        case .cloudmask: 15
        case .pressure: 60
        }
    }

    /// Re-check interval of `latest.json` for the visible, active layer (ETag, 304 is cheap).
    var pollInterval: TimeInterval {
        switch self {
        case .radar, .lightning: 60
        case .clouds, .cloudmask: 120
        case .pressure: 300
        }
    }

    /// Observation layers: newest slot must not be older than this. A stale "now" would pass for current weather.
    var maximumObservationAge: TimeInterval {
        switch self {
        case .lightning: 30 * 60
        case .clouds, .cloudmask: 2 * 3600
        case .pressure, .radar: 0
        }
    }

    /// Forecast layer (pressure): run reference must not be older than this.
    static let maximumForecastRunAge: TimeInterval = 18 * 3600

    /// Most slots prefetched around the selected one (`nil` = whole catalogue). Cloud images are
    /// hundreds of KB each, so only a window is preloaded; pressure and lightning images are tiny.
    var prefetchSlotLimit: Int? {
        switch self {
        case .clouds, .cloudmask: 19
        default: nil
        }
    }

    /// Map overlay opacity. Cloud images are opaque RGB, isobars and lightning are transparent PNG-like.
    var overlayOpacity: Double {
        switch self {
        case .radar: 0.72
        case .clouds: 0.8
        case .cloudmask: 0.85
        case .pressure, .lightning: 0.9
        }
    }

    /// Caption below the slider time.
    func frameCaption(isForecast: Bool) -> String {
        switch self {
        case .cloudmask: "Rückblick"
        case .radar, .lightning, .clouds: isForecast ? "Vorhersage" : "Messung"
        case .pressure: isForecast ? "Vorhersage" : "Modell"
        }
    }

    var backendPathComponent: String { rawValue }
}

enum LayerAvailability: Equatable, Sendable {
    /// Not asked yet.
    case unknown
    case available
    /// `404`: the operator did not enable the layer (`LAYERS`) or nothing is published yet.
    case notPublished
    /// Network error or server error; may work later.
    case unreachable
    /// Unreadable or unsupported manifest.
    case invalid
    /// Manifest is valid but its data is too old to be shown as current.
    case stale

    /// Offered in the picker. `404`/invalid/stale layers are greyed out; unknown and unreachable can be tried.
    var isSelectable: Bool {
        switch self {
        case .unknown, .available, .unreachable: true
        case .notPublished, .invalid, .stale: false
        }
    }

    var hint: String? {
        switch self {
        case .unknown, .available: nil
        case .notPublished: "nicht verfügbar"
        case .unreachable: "nicht erreichbar"
        case .invalid: "nicht lesbar"
        case .stale: "nicht aktuell"
        }
    }
}

// MARK: - Manifest

struct RadarLayerLegendRef: Equatable, Sendable {
    let url: URL
    let width: Int
    let height: Int
    /// Legend images are only loaded from the sources the backend names (DWD, EUMETView), over https.
    static let allowedHosts: Set<String> = ["maps.dwd.de", "view.eumetsat.int"]
}

/// `/v1/layers/<layer>/latest.json` (schema 1): own slot catalogue, time grid and sources per layer.
/// The slot images are served exactly like radar images, so the whole-image overlay is reused through
/// `backend` (a `RadarManifest` with the layer's slots, kind `observation` mapped to `.analysis`).
struct RadarLayerManifest: Equatable, Sendable {
    enum Kind: String, Sendable { case forecast, observation }

    let layer: RadarLayer
    let title: String
    let kind: Kind
    let run: String
    let referenceTime: Date
    let generatedAt: Date
    let stepMinutes: Int
    let forecastHorizonMinutes: Int?
    let historyHours: Int?
    let legend: RadarLayerLegendRef?
    let backend: RadarManifest

    var attribution: String { backend.attribution }
    var modificationNotice: String { backend.modificationNotice }
    var slots: [RadarManifest.Slot] { backend.slots }
    var radarAttribution: RadarAttribution { RadarAttribution(attribution: attribution, modificationNotice: modificationNotice) }

    static let maximumSlots = 600

    /// Observation: newest slot not older than the layer's limit. Forecast: run young enough and not exhausted.
    func isFresh(at now: Date) -> Bool {
        guard generatedAt.timeIntervalSince(now) <= 60, let first = slots.first?.time, let last = slots.last?.time else { return false }
        switch kind {
        case .observation:
            return last.timeIntervalSince(now) <= 60 && now.timeIntervalSince(last) <= layer.maximumObservationAge
        case .forecast:
            return referenceTime.timeIntervalSince(now) <= 60
                && now.timeIntervalSince(referenceTime) <= RadarLayer.maximumForecastRunAge
                && last >= now && first <= last
        }
    }

    /// The "now" marker of this layer's own time axis: the newest slot for observations, the slot of the
    /// current hour (latest slot not after `now`) for the forecast layer.
    func nowSlotTime(at now: Date) -> Date {
        let times = slots.map(\.time)
        switch kind {
        case .observation:
            return times.last(where: { $0 <= referenceTime }) ?? times.last ?? referenceTime
        case .forecast:
            return times.last(where: { $0 <= now }) ?? times.first ?? referenceTime
        }
    }

    func timeline(at now: Date) -> RadarTimeline {
        RadarTimeline(referenceTime: nowSlotTime(at: now), dates: slots.map(\.time), backend: backend)
    }

    // MARK: Parsing

    private struct SchemaProbe: Decodable { let schema: Int }
    private struct Raw: Decodable {
        struct RawSlot: Decodable { let time: String, kind: String, path: String }
        struct RawLegend: Decodable { let url: String, width: Int, height: Int }
        let schema: Int, layer: String, title: String, kind: String, run: String
        let referenceTime: String, generatedAt: String
        let stepMinutes: Int
        let forecastHorizonMinutes: Int?, historyHours: Int?
        let image: RadarImageInfo
        let slots: [RawSlot]
        let attribution: String, modificationNotice: String
        let legend: RawLegend?
    }

    /// `layersBaseURL` is `…/v1/layers/<layer>/`; slot URLs must stay below it on the same origin.
    static func parse(_ data: Data, expected: RadarLayer, layersBaseURL: URL) throws -> RadarLayerManifest {
        guard !data.isEmpty, data.count <= RadarBackendConfig.maximumManifestBytes else { throw RadarBackendError.invalid }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let probe: SchemaProbe
        do { probe = try decoder.decode(SchemaProbe.self, from: data) } catch { throw RadarBackendError.invalid }
        guard probe.schema == 1 else { throw RadarBackendError.unsupportedSchema(probe.schema) }
        let raw: Raw
        do { raw = try decoder.decode(Raw.self, from: data) } catch { throw RadarBackendError.invalid }

        guard raw.layer == expected.rawValue, let kind = Kind(rawValue: raw.kind),
              RadarManifest.isRunID(raw.run),
              let reference = DWDRequest.date(raw.referenceTime), let generated = DWDRequest.date(raw.generatedAt),
              (1...180).contains(raw.stepMinutes),
              let bounds = raw.image.validatedBounds,
              !raw.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !raw.attribution.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !raw.modificationNotice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              (1...maximumSlots).contains(raw.slots.count) else { throw RadarBackendError.invalid }

        var slots: [RadarManifest.Slot] = []
        for item in raw.slots {
            guard let time = DWDRequest.date(item.time), RadarManifest.isSafe(path: item.path),
                  let url = URL(string: item.path, relativeTo: layersBaseURL)?.absoluteURL,
                  url.host == layersBaseURL.host, url.scheme == layersBaseURL.scheme,
                  url.path.hasPrefix(layersBaseURL.path) else { throw RadarBackendError.invalid }
            let slotKind: RadarManifest.Kind
            switch (kind, item.kind) {
            case (.observation, "observation"): slotKind = .analysis
            case (.forecast, "analysis"): slotKind = .analysis
            case (.forecast, "forecast"): slotKind = .forecast
            default: throw RadarBackendError.invalid
            }
            if let last = slots.last, time <= last.time { throw RadarBackendError.invalid }
            slots.append(RadarManifest.Slot(time: time, kind: slotKind, path: item.path, url: url))
        }

        var legend: RadarLayerLegendRef?
        if let rawLegend = raw.legend {
            // A malformed legend reference only drops the legend; the layer itself stays usable.
            if let url = URL(string: rawLegend.url), url.scheme == "https",
               let host = url.host, RadarLayerLegendRef.allowedHosts.contains(host),
               (1...2000).contains(rawLegend.width), (1...2000).contains(rawLegend.height) {
                legend = RadarLayerLegendRef(url: url, width: rawLegend.width, height: rawLegend.height)
            }
        }

        let backend = RadarManifest(run: raw.run, referenceTime: reference, generatedAt: generated,
                                    stepMinutes: raw.stepMinutes, imageWidth: raw.image.width,
                                    imageHeight: raw.image.height, bounds: bounds, slots: slots,
                                    attribution: raw.attribution, modificationNotice: raw.modificationNotice)
        return RadarLayerManifest(layer: expected, title: raw.title, kind: kind, run: raw.run, referenceTime: reference,
                                  generatedAt: generated, stepMinutes: raw.stepMinutes,
                                  forecastHorizonMinutes: raw.forecastHorizonMinutes, historyHours: raw.historyHours,
                                  legend: legend, backend: backend)
    }
}

extension RadarBackendConfig {
    /// `…/v1/radar/` -> `…/v1/layers/<layer>/` (also for a Debug `-radar-backend-url` override).
    static func layersBaseURL(for layer: RadarLayer, radarBaseURL: URL = RadarBackendConfig.baseURL()) -> URL {
        var root = radarBaseURL
        if root.lastPathComponent == "radar" { root.deleteLastPathComponent() }
        return root.appendingPathComponent("layers", isDirectory: true)
            .appendingPathComponent(layer.backendPathComponent, isDirectory: true)
    }
}

// MARK: - Client

actor RadarLayerClient {
    enum Outcome: Equatable, Sendable {
        case fresh(RadarLayerManifest)
        /// `404`: layer not enabled or nothing published. Not an error for the user.
        case notPublished
        case unreachable
        case invalid
        case stale
    }

    private struct Cached { var etag: String?; var manifest: RadarLayerManifest }

    let radarBaseURL: URL
    private let transport: RadarBackendClient.Transport
    private let clock: @Sendable () -> Date
    private var cache: [RadarLayer: Cached] = [:]

    init(radarBaseURL: URL = RadarBackendConfig.baseURL(), transport: RadarBackendClient.Transport? = nil,
         clock: @escaping @Sendable () -> Date = { Date() }) {
        self.radarBaseURL = radarBaseURL
        self.transport = transport ?? RadarBackendClient.makeTransport()
        self.clock = clock
    }

    func latest(_ layer: RadarLayer) async -> Outcome {
        guard layer.isBackendLayer else { return .invalid }
        let base = RadarBackendConfig.layersBaseURL(for: layer, radarBaseURL: radarBaseURL)
        var request = URLRequest(url: base.appendingPathComponent("latest.json"),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 6)
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let etag = cache[layer]?.etag { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        let data: Data, response: HTTPURLResponse
        do { (data, response) = try await transport(request) } catch { return .unreachable }
        let manifest: RadarLayerManifest
        switch response.statusCode {
        case 304:
            guard let cached = cache[layer] else { return .invalid }
            manifest = cached.manifest
        case 200:
            do { manifest = try RadarLayerManifest.parse(data, expected: layer, layersBaseURL: base) }
            catch { return .invalid }
            cache[layer] = Cached(etag: response.value(forHTTPHeaderField: "ETag"), manifest: manifest)
        case 404:
            cache[layer] = nil
            return .notPublished
        default:
            return .unreachable
        }
        return manifest.isFresh(at: clock()) ? .fresh(manifest) : .stale
    }
}

// MARK: - State

/// What the app knows about one layer.
struct LayerSnapshot: Equatable {
    var availability: LayerAvailability = .unknown
    var manifest: RadarLayerManifest?
    var timeline: RadarTimeline?
    var selectedFrame = 0
}

extension RadarTimeline: Equatable {
    static func == (lhs: RadarTimeline, rhs: RadarTimeline) -> Bool {
        lhs.referenceTime == rhs.referenceTime && lhs.dates == rhs.dates && lhs.backend == rhs.backend
    }
}

/// Layer choice and per-layer manifests. Exactly one layer is active; selecting a layer never changes
/// the radar timeline or its fallback logic.
@MainActor @Observable
final class RadarLayerStore {
    private(set) var active: RadarLayer = .radar
    private(set) var snapshots: [RadarLayer: LayerSnapshot] = [:]
    private(set) var loading: Set<RadarLayer> = []

    @ObservationIgnored private let client: RadarLayerClient
    @ObservationIgnored private let clock: () -> Date
    @ObservationIgnored private var lastProbe = Date.distantPast
    /// Minimum distance between two availability probes of all layers.
    static let probeInterval: TimeInterval = 300

    init(radarBaseURL: URL = RadarBackendConfig.baseURL(), client: RadarLayerClient? = nil,
         clock: @escaping () -> Date = { Date() }) {
        self.client = client ?? RadarLayerClient(radarBaseURL: radarBaseURL)
        self.clock = clock
    }

    func snapshot(_ layer: RadarLayer) -> LayerSnapshot { snapshots[layer] ?? LayerSnapshot() }
    func availability(_ layer: RadarLayer) -> LayerAvailability {
        layer == .radar ? .available : snapshot(layer).availability
    }
    func isSelectable(_ layer: RadarLayer) -> Bool { availability(layer).isSelectable }
    var isLoading: Bool { loading.contains(active) }

    var activeTimeline: RadarTimeline? { active == .radar ? nil : snapshot(active).timeline }
    var activeManifest: RadarLayerManifest? { active == .radar ? nil : snapshot(active).manifest }

    /// Chooses a layer. Unavailable layers (404, invalid, stale) are refused; the data is loaded right away.
    @discardableResult
    func select(_ layer: RadarLayer) -> Bool {
        guard RadarLayer.selectable.contains(layer), isSelectable(layer) else { return false }
        active = layer
        if layer.isBackendLayer { Task { await refresh(layer) } }
        return true
    }

    func setFrame(_ index: Int, for layer: RadarLayer) {
        guard layer.isBackendLayer, var value = snapshots[layer], let count = value.timeline?.dates.count,
              (0..<count).contains(index), value.selectedFrame != index else { return }
        value.selectedFrame = index
        snapshots[layer] = value
    }

    /// Loads `latest.json` of one layer and updates its state. A layer that turns out to be unavailable
    /// while active silently hands the map back to the radar (no error banner for `404`).
    func refresh(_ layer: RadarLayer) async {
        guard layer.isBackendLayer, !loading.contains(layer) else { return }
        loading.insert(layer)
        let outcome = await client.latest(layer)
        loading.remove(layer)
        apply(outcome, to: layer, now: clock())
    }

    func apply(_ outcome: RadarLayerClient.Outcome, to layer: RadarLayer, now: Date) {
        var value = snapshots[layer] ?? LayerSnapshot()
        switch outcome {
        case .fresh(let manifest):
            let timeline = manifest.timeline(at: now)
            if value.manifest != manifest || value.timeline != timeline {
                let previousDate = value.timeline.flatMap { $0.dates.indices.contains(value.selectedFrame) ? $0.dates[value.selectedFrame] : nil }
                value.selectedFrame = RadarTimelineSelection.index(
                    previous: previousDate, previousReference: value.timeline?.referenceTime,
                    dates: timeline.dates, reference: timeline.referenceTime)
                value.manifest = manifest
                value.timeline = timeline
            }
            value.availability = .available
        case .notPublished, .invalid, .stale:
            value.availability = outcome == .notPublished ? .notPublished : outcome == .invalid ? .invalid : .stale
            value.manifest = nil
            value.timeline = nil
            value.selectedFrame = 0
        case .unreachable:
            // Keep still-fresh data over a short outage; otherwise there is nothing honest to show.
            if let manifest = value.manifest, manifest.isFresh(at: now) {
                value.availability = .available
            } else {
                value.availability = .unreachable
                value.manifest = nil
                value.timeline = nil
                value.selectedFrame = 0
            }
        }
        if snapshots[layer] != value { snapshots[layer] = value }
        if active == layer, !value.availability.isSelectable { active = .radar }
    }

    /// Asks all optional layers once whether they exist (404 -> greyed out). Throttled; with
    /// `restricted` (Low Power / Low Data) only the active layer is refreshed.
    func probeAll(force: Bool = false, restricted: Bool = false) async {
        let now = clock()
        guard force || now.timeIntervalSince(lastProbe) >= Self.probeInterval else { return }
        lastProbe = now
        let targets = restricted ? [active].filter(\.isBackendLayer) : RadarLayer.selectable.filter(\.isBackendLayer)
        let tasks = targets.map { layer in Task { await self.refresh(layer) } }
        for task in tasks { await task.value }
    }

    /// Visible-app poll for the active backend layer; returns when the layer changes or the task is cancelled.
    func runPolling(for layer: RadarLayer, restricted: @escaping () -> Bool = { false },
                    sleep: (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }) async {
        guard layer.isBackendLayer else { return }
        while !Task.isCancelled, active == layer {
            await refresh(layer)
            do { try await sleep(layer.pollInterval * (restricted() ? 2 : 1)) } catch { return }
        }
    }
}

// MARK: - Display state (active layer or radar)

extension WeatherStore {
    var activeLayer: RadarLayer { layers.active }

    /// Timeline shown on the map and the slider: the radar's, or the active layer's own.
    var displayTimeline: RadarTimeline? { layers.active == .radar ? timeline : layers.activeTimeline }

    var displayFrameIndex: Int {
        get { layers.active == .radar ? selectedFrame : layers.snapshot(layers.active).selectedFrame }
        set {
            if layers.active == .radar { selectedFrame = newValue } else { layers.setFrame(newValue, for: layers.active) }
        }
    }

    var displayFrameDate: Date? {
        guard let timeline = displayTimeline, timeline.dates.indices.contains(displayFrameIndex) else { return nil }
        return timeline.dates[displayFrameIndex]
    }

    var displayFrameReference: Date? {
        guard let timeline = displayTimeline, let date = displayFrameDate else { return nil }
        return min(date, timeline.referenceTime)
    }

    var displayIsForecastFrame: Bool {
        guard let date = displayFrameDate, let timeline = displayTimeline else { return false }
        return date > timeline.referenceTime
    }

    /// Source line of the active layer: the manifest's own attribution for layers, the radar's for the radar.
    var displayAttributionLine: String? {
        if layers.active == .radar {
            guard timeline != nil else { return nil }
            return "\(radarAttribution.attribution) · \(radarSource.label)"
                + (historyStatus == .unavailable && radarSource == .cache ? " · Historie nicht verfügbar" : "")
        }
        guard let manifest = layers.activeManifest else { return nil }
        return "\(manifest.attribution) · \(RadarSource.cache.label)"
    }
}
