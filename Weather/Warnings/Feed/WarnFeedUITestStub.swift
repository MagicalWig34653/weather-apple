#if DEBUG
import Foundation

/// UI tests only (Debug builds): `-UITestWarnings fixture|empty|stale|offline` simulates the feed without network.
/// `fixture` also pretends the saved place "Berlin" lies in district 111000000.
extension WarnFeedStore {
    static var uiTestMode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestWarnings"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    static func uiTestTransport(mode: String) -> Transport {
        { request in
            if mode == "offline" { throw URLError(.notConnectedToInternet) }
            let now = Date()
            let iso = ISO8601DateFormatter()
            func time(_ offset: TimeInterval) -> String { iso.string(from: now.addingTimeInterval(offset)) }
            let fetched = mode == "stale" ? time(-3 * 3600) : time(-120)
            let warnings: [[String: Any]] = mode == "empty" ? [] : [
                ["id": "ui.severe", "kind": "severe_weather", "severity": 3, "event": "GEWITTER", "sent": time(-2700),
                 "onset": time(-1800), "expires": time(3 * 3600), "headline": "Amtliche UNWETTERWARNUNG vor GEWITTER",
                 "text": "Es treten Gewitter auf. Dabei gibt es Windböen bis 70 km/h (Bft 8) sowie Starkregen um 25 l/qm in einer Stunde.",
                 "instruction": "ACHTUNG! Hinweis auf mögliche Gefahren: Während eines Gewitters können Windböen und Starkregen auftreten.\nHandlungsempfehlungen:\nGefahrenbereiche meiden.",
                 "lang": "de", "warncell_ids": ["111000000", "102000000"]],
                ["id": "ui.frost", "kind": "frost", "severity": 1, "event": "FROST", "sent": time(-600),
                 "onset": time(6 * 3600), "expires": time(20 * 3600), "headline": "Amtliche WARNUNG vor FROST",
                 "text": "Es tritt leichter Frost zwischen -1 °C und -5 °C auf.",
                 "instruction": "Hinweis auf: mögliche Frostschäden.\nHandlungsempfehlungen:\nggf. Frostschutzmaßnahmen ergreifen",
                 "lang": "de", "warncell_ids": ["111000000", "105315000"]],
                ["id": "ui.ice", "kind": "ice", "severity": 4, "event": "GLATTEIS", "sent": time(-300),
                 "onset": time(2 * 3600), "expires": time(9 * 3600), "headline": "Amtliche WARNUNG vor EXTREMEM GLATTEIS",
                 "text": "Es tritt extremes Glatteis auf.", "instruction": "Hinweis auf mögliche Gefahren: Straßen und Wege sind spiegelglatt.",
                 "lang": "de", "warncell_ids": ["909184999"]],
            ]
            let body: [String: Any] = ["schema": 1, "source": "dwd", "fetched_at": fetched, "warnings": warnings]
            let data = try JSONSerialization.data(withJSONObject: body)
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (data, response)
        }
    }
}
#endif
