import Foundation

/// User setting: how far back the radar timeline reaches. Local only (UserDefaults).
enum RadarPastWindow {
    static let options = [1, 2, 6, 12, 24, 48]
    static let defaultHours = 2
    static let defaultsKey = "radarPastHours"
    /// Past covered by the direct DWD path (12 analyses, about one hour), whatever the setting says.
    static let directHours = 1

    static func load(_ defaults: UserDefaults) -> Int {
        let stored = defaults.integer(forKey: defaultsKey)
        return options.contains(stored) ? stored : defaultHours
    }

    static func save(_ hours: Int, to defaults: UserDefaults) {
        guard options.contains(hours) else { return }
        defaults.set(hours, forKey: defaultsKey)
    }

    static func label(_ hours: Int) -> String { hours == 1 ? "1 Stunde" : "\(hours) Stunden" }
}

/// Parsed `history.json`: analysis slots only (the past), ascending, 5-minute grid, gaps allowed.
/// Slot `path` values are opaque to the app (never rebuilt from `time`).
struct RadarHistory: Equatable, Sendable {
    let run: String
    let generatedAt: Date
    let stepMinutes: Int
    let historyHours: Int
    let imageWidth: Int
    let imageHeight: Int
    let bounds: RadarBounds
    let slots: [RadarManifest.Slot]

    static let maximumSlots = 1000
    static let maximumHistoryHours = 168

    private struct SchemaProbe: Decodable { let schema: Int }
    private struct Raw: Decodable {
        struct RawSlot: Decodable { let time: String, kind: String, path: String }
        let schema: Int, run: String, generatedAt: String, stepMinutes: Int, historyHours: Int
        let image: RadarImageInfo
        let slots: [RawSlot]
    }

    static func parse(_ data: Data, baseURL: URL, now: Date = Date()) throws -> RadarHistory {
        guard !data.isEmpty, data.count <= 4 * RadarBackendConfig.maximumManifestBytes else { throw RadarBackendError.invalid }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let probe: SchemaProbe
        do { probe = try decoder.decode(SchemaProbe.self, from: data) } catch { throw RadarBackendError.invalid }
        guard probe.schema == 1 else { throw RadarBackendError.unsupportedSchema(probe.schema) }
        let raw: Raw
        do { raw = try decoder.decode(Raw.self, from: data) } catch { throw RadarBackendError.invalid }

        guard RadarManifest.isRunID(raw.run), let generated = DWDRequest.date(raw.generatedAt),
              generated.timeIntervalSince(now) <= 60,
              (1...60).contains(raw.stepMinutes), (1...maximumHistoryHours).contains(raw.historyHours),
              let bounds = raw.image.validatedBounds,
              (1...maximumSlots).contains(raw.slots.count) else { throw RadarBackendError.invalid }

        var slots: [RadarManifest.Slot] = []
        for item in raw.slots {
            guard let time = DWDRequest.date(item.time), item.kind == "analysis",
                  isSafe(path: item.path), let url = URL(string: item.path, relativeTo: baseURL)?.absoluteURL,
                  url.host == baseURL.host, url.scheme == baseURL.scheme,
                  url.path.hasPrefix(baseURL.path), url.query == nil,
                  time <= generated.addingTimeInterval(60) else { throw RadarBackendError.invalid }
            if let last = slots.last, time <= last.time { throw RadarBackendError.invalid }
            slots.append(RadarManifest.Slot(time: time, kind: .analysis, path: item.path, url: url))
        }
        return RadarHistory(run: raw.run, generatedAt: generated, stepMinutes: raw.stepMinutes,
                            historyHours: raw.historyHours, imageWidth: raw.image.width, imageHeight: raw.image.height,
                            bounds: bounds, slots: slots)
    }

    /// Relative `.webp` path below `/v1/radar/` (up to four plain segments): no scheme, traversal, query.
    static func isSafe(path: String) -> Bool {
        path.range(of: #"^([0-9A-Za-z_-]{1,64}/){0,3}[0-9A-Za-z_-]{1,64}\.webp$"#, options: .regularExpression) != nil
    }
}

/// Builds the timeline manifest from `latest.json` plus (optional) history, filtered to the chosen past.
enum RadarTimelineComposer {
    /// Latest already reaches back far enough (within one step) when it covers the wanted past.
    static func needsHistory(latest: RadarManifest, hours: Int) -> Bool {
        guard let earliest = latest.slots.first(where: { $0.kind == .analysis })?.time else { return true }
        let wanted = latest.referenceTime.addingTimeInterval(-Double(hours) * 3600)
        return wanted < earliest.addingTimeInterval(-Double(latest.stepMinutes) * 60)
    }

    /// History is used only if it matches latest's image geometry (one overlay, one bounding box).
    static func isCompatible(_ history: RadarHistory, with latest: RadarManifest) -> Bool {
        history.imageWidth == latest.imageWidth && history.imageHeight == latest.imageHeight
            && history.bounds == latest.bounds
    }

    /// Past of `hours` before the reference time + latest's analysis/forecast; deduplicated by time
    /// (latest wins), ascending. Without usable history: latest's own past, also filtered.
    static func compose(latest: RadarManifest, history: RadarHistory?, hours: Int) -> RadarManifest {
        let cutoff = latest.referenceTime.addingTimeInterval(-Double(hours) * 3600)
        var byTime: [Date: RadarManifest.Slot] = [:]
        if let history, isCompatible(history, with: latest) {
            for slot in history.slots where slot.time >= cutoff && slot.time <= latest.referenceTime { byTime[slot.time] = slot }
        }
        for slot in latest.slots where slot.kind == .forecast || slot.time >= cutoff { byTime[slot.time] = slot }
        let slots = byTime.values.sorted { $0.time < $1.time }
        return RadarManifest(run: latest.run, referenceTime: latest.referenceTime, generatedAt: latest.generatedAt,
                             stepMinutes: latest.stepMinutes, imageWidth: latest.imageWidth, imageHeight: latest.imageHeight,
                             bounds: latest.bounds, slots: slots, attribution: latest.attribution,
                             modificationNotice: latest.modificationNotice)
    }
}

/// What the UI can say about the longer past.
enum RadarHistoryStatus: Equatable, Sendable {
    /// Latest alone covers the chosen past (or the direct DWD path is in use).
    case notNeeded
    case loaded(hours: Int)
    case unavailable
}
