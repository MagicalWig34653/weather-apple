import Foundation

/// Minimal widget provider diagnostics for the Info screen: only timestamps and a coarse outcome, no places,
/// coordinates or identifiers. Stored in the App Group defaults.
struct WidgetDiagnostics: Equatable, Sendable {
    enum Outcome: String, Sendable { case live, cache, unavailable }
    var lastRun: Date
    var outcome: Outcome
    var dataReference: Date?
    var nextReload: Date

    private static let key = "widget.diagnostics.v1"

    static func record(_ value: WidgetDiagnostics, defaults: UserDefaults? = UserDefaults(suiteName: SharedConfig.appGroup)) {
        var dict: [String: Any] = ["run": value.lastRun.timeIntervalSince1970, "outcome": value.outcome.rawValue,
                                   "next": value.nextReload.timeIntervalSince1970]
        if let ref = value.dataReference { dict["ref"] = ref.timeIntervalSince1970 }
        defaults?.set(dict, forKey: key)
    }

    static func load(defaults: UserDefaults? = UserDefaults(suiteName: SharedConfig.appGroup)) -> WidgetDiagnostics? {
        guard let d = defaults?.dictionary(forKey: key), let run = d["run"] as? Double, let next = d["next"] as? Double,
              let raw = d["outcome"] as? String, let outcome = Outcome(rawValue: raw) else { return nil }
        return WidgetDiagnostics(lastRun: Date(timeIntervalSince1970: run), outcome: outcome,
                                 dataReference: (d["ref"] as? Double).map { Date(timeIntervalSince1970: $0) },
                                 nextReload: Date(timeIntervalSince1970: next))
    }
}
