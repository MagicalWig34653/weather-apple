#if DEBUG
import Foundation

/// UI tests only (Debug builds): `-UITestLayers wms|d2` simulates the layer manifests without network.
/// `wms`: temperature from the WMS source (legend image); `d2`: temperature and dew point from ICON-D2 with scale ids
/// (relative humidity stays unavailable, like with the server flag off); `d2rh`: like `d2` plus relative humidity.
/// All other layers answer 404.
extension RadarLayerStore {
    static var uiTestMode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestLayers"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    static func uiTestClient(mode: String, radarBaseURL: URL) -> RadarLayerClient {
        RadarLayerClient(radarBaseURL: radarBaseURL, transport: { request in
            let id = request.url?.pathComponents.dropLast().last ?? ""
            let url = request.url ?? radarBaseURL
            func response(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            let known: [String: (title: String, notice: String, extra: [String: Any])] = mode == "wms"
                ? ["temperature": ("Temperatur 2 m (ICON-EU)", "Datenbasis: Deutscher Wetterdienst (ICON-EU), Lufttemperatur 2 m bildlich wiedergegeben",
                                   ["source": "wms"])]
                : ["temperature": ("Temperatur 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), Lufttemperatur 2 m bildlich wiedergegeben",
                                   ["source": "icon_d2", "scale": "t2m-d2-v1"]),
                   "dewpoint": ("Taupunkt 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), Taupunkt 2 m bildlich wiedergegeben",
                                ["source": "icon_d2", "scale": "td-d2-v1"]),
                   "humidity": ("Relative Feuchte 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), relative Feuchte 2 m bildlich wiedergegeben",
                                ["source": "icon_d2", "scale": "rh-d2-v1"])]
            guard let entry = known[id], id != "humidity" || mode == "d2rh", request.url?.lastPathComponent == "latest.json" else { return (Data(), response(404)) }
            let now = Date()
            let start = Date(timeIntervalSince1970: (now.timeIntervalSince1970 / 3600).rounded(.down) * 3600 - 3600)
            let iso = ISO8601DateFormatter()
            let compact = DateFormatter()
            compact.locale = Locale(identifier: "en_US_POSIX"); compact.timeZone = TimeZone(identifier: "UTC")
            compact.dateFormat = "yyyyMMdd'T'HHmm'Z'"
            let run = compact.string(from: start)
            let slots = (0..<49).map { hour -> [String: Any] in
                let time = start.addingTimeInterval(Double(hour) * 3600)
                return ["time": iso.string(from: time), "kind": hour == 0 ? "analysis" : "forecast",
                        "path": "\(run)/\(compact.string(from: time)).webp"]
            }
            var object: [String: Any] = [
                "schema": 1, "layer": id, "title": entry.title, "kind": "forecast", "run": run,
                "reference_time": iso.string(from: start), "generated_at": iso.string(from: now.addingTimeInterval(-60)),
                "step_minutes": 60, "forecast_horizon_minutes": 2880,
                "image": ["format": "image/webp", "width": 1024, "height": 1311, "projection": "EPSG:3857",
                          "bbox": [612257.0, 5942074.0, 1736584.0, 7381298.0], "bbox_wgs84": [5.5, 47.0, 15.6, 55.1]],
                "slots": slots, "attribution": "Quelle: Deutscher Wetterdienst", "modification_notice": entry.notice]
            if mode == "wms" {
                object["legend"] = ["url": "https://maps.dwd.de/geoserver/ows?service=WMS&version=1.3.0&request=GetLegendGraphic&format=image/png&layer=dwd:Icon-eu_reg00625_fd_gl_T&style=icon-eu_reg00625_fd_gl_t_isoarea_tkb",
                                    "width": 88, "height": 505]
            }
            object.merge(entry.extra) { $1 }
            return ((try? JSONSerialization.data(withJSONObject: object)) ?? Data(), response(200))
        })
    }
}
#endif
