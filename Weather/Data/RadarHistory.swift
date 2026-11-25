import Foundation

/// User setting: how far back the radar timeline reaches. Local only (UserDefaults).
enum RadarPastWindow {
    static let options = [1, 2, 6, 12, 24, 48, 72]
    /// The standard window of every map without a choice (the step marked "(Standard)"), whatever the server offers.
    static let defaultHours = 6
    static let defaultsKey = "radarPastHours"
    /// Past covered by the direct DWD path (12 analyses, about one hour), whatever the setting says.
    static let directHours = 1

    /// Effective hours: the stored choice, else the standard.
    static func load(_ defaults: UserDefaults) -> Int { choice(defaults) ?? defaultHours }

    /// The user's explicit choice; `nil` = never chosen. Builds 50 and 52 write `radarPastHours` only when the user picks a
    /// step (the key is absent on a fresh install and after "never touched"), so a stored valid step IS a choice - also 2 -
    /// and an absent, corrupt or unknown value means "never chosen" (such a value is left in place, not rewritten).
    static func choice(_ defaults: UserDefaults) -> Int? {
        // A launch argument (`-radarPastHours 48`, UI tests) arrives as text in the argument domain: accept both.
        let stored: Int?
        switch defaults.object(forKey: defaultsKey) {
        case let number as NSNumber where CFGetTypeID(number) != CFBooleanGetTypeID(): stored = Int(exactly: number.doubleValue)
        case let text as String: stored = Int(text)
        default: stored = nil
        }
        guard let stored, options.contains(stored) else { return nil }
        return stored
    }
    static func clear(_ defaults: UserDefaults) { defaults.removeObject(forKey: defaultsKey) }

    static func save(_ hours: Int, to defaults: UserDefaults) {
        guard options.contains(hours) else { return }
        defaults.set(hours, forKey: defaultsKey)
    }

    /// Whether a step is greyed out: the direct DWD path has one hour; the cache backend offers what it reports.
    static func isUnavailable(_ hours: Int, direct: Bool, serverHours: Int?) -> Bool {
        if direct { return hours > directHours }
        if let serverHours { return hours > max(serverHours, directHours) }
        return false
    }

    /// Hours of past the shown timeline really has when that is clearly less than the chosen past (more than 1.5 grid steps short,
    /// so rounding of slot times stays quiet); `nil` otherwise. Only says so - the choice and the timeline stay as they are.
    static func shortfallHours(chosen: Int, span: TimeInterval, stepMinutes: Int) -> Int? {
        let tolerance = Double(max(stepMinutes, 1)) * 60 * RadarTimelineGaps.tolerance
        guard span >= 0, span + tolerance < Double(chosen) * 3600 else { return nil }
        return min(max(Int((span / 3600).rounded()), directHours), max(chosen - 1, directHours))
    }

    static func shortHistoryText(available: Int, chosen: Int) -> String {
        String(format: NSLocalizedString("RADAR_HISTORY_SHORT", value: "Diese Karte reicht nur %1$@ zurück – gewählt sind %2$@.", comment: "Radar: the chosen past is longer than the data"),
               label(available), label(chosen))
    }

    /// Row text of one step in the setting: the step that is the standard carries the mark "(Standard)", always the same step
    /// whatever the user chose; the check mark is separate and follows the choice.
    static func optionLabel(_ hours: Int, standard: Int) -> String {
        hours == standard
            ? String(format: NSLocalizedString("INFO_PAST_OPTION_DEFAULT", value: "%@ (Standard)", comment: "Info: the step that is the standard window"), label(hours))
            : label(hours)
    }

    static func label(_ hours: Int) -> String {
        hours == 1 ? NSLocalizedString("RADAR_PAST_WINDOW_ONE", value: "1 Stunde", comment: "History window")
            : String(format: NSLocalizedString("RADAR_PAST_WINDOW_MANY", value: "%d Stunden", comment: "History window"), hours)
    }
}

/// Parsed `history.json`: analysis slots only (the past), ascending, 5-minute grid, gaps allowed. Since backend PR #4 the
/// duration is 48 or 72 hours and an additive `history` block (`info`) reports the oldest slot and the holes.
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
    /// Additive `history` block (PR #4); `nil` for today's backend or a malformed block.
    var info: RadarHistoryInfo? = nil

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
                            bounds: bounds, slots: slots, info: RadarHistoryInfo.parse(manifestData: data))
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
        var info: RadarHistoryInfo?
        if let history, isCompatible(history, with: latest) {
            info = history.info
            for slot in history.slots where slot.time >= cutoff && slot.time <= latest.referenceTime { byTime[slot.time] = slot }
        }
        for slot in latest.slots where slot.kind == .forecast || slot.time >= cutoff { byTime[slot.time] = slot }
        let slots = byTime.values.sorted { $0.time < $1.time }
        return RadarManifest(run: latest.run, referenceTime: latest.referenceTime, generatedAt: latest.generatedAt,
                             stepMinutes: latest.stepMinutes, imageWidth: latest.imageWidth, imageHeight: latest.imageHeight,
                             bounds: latest.bounds, slots: slots, attribution: latest.attribution,
                             modificationNotice: latest.modificationNotice, history: info, windowStart: cutoff)
    }
}

/// What the UI can say about the longer past.
enum RadarHistoryStatus: Equatable, Sendable {
    /// Latest alone covers the chosen past (or the direct DWD path is in use).
    case notNeeded
    case loaded(hours: Int)
    case unavailable
}
