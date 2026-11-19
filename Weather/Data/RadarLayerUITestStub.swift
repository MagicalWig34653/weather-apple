#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// UI tests only (Debug builds): `-UITestLayers wms|d2` simulates the layer manifests without network.
/// `wms`: temperature from the WMS source (legend image); `d2`: temperature and dew point from ICON-D2 with scale ids
/// (relative humidity stays unavailable, like with the server flag off); `d2rh`: like `d2` plus relative humidity.
/// `all`: every layer of the menu is offered (rain Europe and world, both pressure layers, temperature, dew point, relative humidity,
/// lightning, clouds, sun) and all slot images are generated locally (`UITestLayerImage`), so UI tests show real layers.
/// All other layers answer 404.
extension RadarLayerStore {
    nonisolated static var uiTestMode: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestLayers"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private nonisolated static func allLayerEntries() -> [String: (title: String, notice: String, extra: [String: Any])] {
        let dwd = "Datenbasis: Deutscher Wetterdienst"
        return [
            "radar_eu": ("Regenradar Europa (OPERA)", "Daten umprojiziert und eingefärbt",
                         ["kind": "observation", "step": 300.0,
                          "attribution": "Radardaten Europa: EUMETNET OPERA (CIRRUS), CC BY 4.0, Quelle: MeteoGate"]),
            // World map like the backend of PR #2 (2048 x 995, 60° S to 70° N, 10 min, observation only).
            "radar_world": ("Regenradar Welt (NOAA RRQPE)", "Datenbasis: NOAA Enterprise Rainfall Rate (RRQPE, Blend), Daten umprojiziert, gefiltert und eingefärbt; aus Satellitendaten geschätzt",
                            ["kind": "observation", "step": 600.0, "source": "noaa_rrqpe",
                             "attribution": "Quelle: NOAA, von Showers verarbeitet; aus Satellitendaten geschätzt, ungenauer",
                             "image": ["format": "image/webp", "width": 2048, "height": 995, "projection": "EPSG:3857",
                                       "bbox": [-20037508.0, -8399738.0, 20037508.0, 11068716.0], "bbox_wgs84": [-180.0, -60.0, 180.0, 70.0]]]),
            "pressure": ("Luftdruck Deutschland", "\(dwd) (ICON), Isobaren berechnet", [:]),
            "pressure_eu": ("Luftdruck Europa", "\(dwd) (ICON), Isobaren berechnet", [:]),
            "lightning": ("Blitze", "\(dwd) (NowCastMIX), bildlich wiedergegeben", ["kind": "observation", "step": 300.0]),
            "clouds": ("Wolken (Satellit)", "Daten: EUMETSAT, bildlich wiedergegeben", ["kind": "observation", "step": 600.0]),
            "cloudmask": ("Sonne (Wolkenmaske)", "Daten: EUMETSAT, bildlich wiedergegeben", ["kind": "observation", "step": 900.0]),
            "temperature": ("Temperatur 2 m (ICON-D2)", "\(dwd) (ICON-D2), Lufttemperatur 2 m bildlich wiedergegeben",
                            ["source": "icon_d2", "scale": "t2m-d2-v1"]),
            "dewpoint": ("Taupunkt 2 m (ICON-D2)", "\(dwd) (ICON-D2), Taupunkt 2 m bildlich wiedergegeben",
                         ["source": "icon_d2", "scale": "td-d2-v1"]),
            "humidity": ("Relative Feuchte 2 m (ICON-D2)", "\(dwd) (ICON-D2), relative Feuchte 2 m bildlich wiedergegeben",
                         ["source": "icon_d2", "scale": "rh-d2-v1"]),
        ]
    }

    private nonisolated static let stubStart = Date()
    private nonisolated static var outageLayer: String {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestOutageLayer"), CommandLine.arguments.indices.contains(index + 1) else { return "radar_world" }
        return CommandLine.arguments[index + 1]
    }
    private nonisolated static func argument(_ name: String) -> TimeInterval? {
        guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return TimeInterval(CommandLine.arguments[index + 1])
    }

    static func uiTestClient(mode: String, radarBaseURL: URL) -> RadarLayerClient {
        RadarLayerClient(radarBaseURL: radarBaseURL, transport: { request in
            let id = request.url?.pathComponents.dropLast().last ?? ""
            let url = request.url ?? radarBaseURL
            func response(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            let known: [String: (title: String, notice: String, extra: [String: Any])] = mode == "all" ? allLayerEntries() : mode == "wms"
                ? ["temperature": ("Temperatur 2 m (ICON-EU)", "Datenbasis: Deutscher Wetterdienst (ICON-EU), Lufttemperatur 2 m bildlich wiedergegeben",
                                   ["source": "wms"])]
                : ["temperature": ("Temperatur 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), Lufttemperatur 2 m bildlich wiedergegeben",
                                   ["source": "icon_d2", "scale": "t2m-d2-v1"]),
                   "dewpoint": ("Taupunkt 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), Taupunkt 2 m bildlich wiedergegeben",
                                ["source": "icon_d2", "scale": "td-d2-v1"]),
                   "humidity": ("Relative Feuchte 2 m (ICON-D2)", "Datenbasis: Deutscher Wetterdienst (ICON-D2), relative Feuchte 2 m bildlich wiedergegeben",
                                ["source": "icon_d2", "scale": "rh-d2-v1"])]
            guard let entry = known[id], id != "humidity" || mode == "d2rh" || mode == "all", request.url?.lastPathComponent == "latest.json" else { return (Data(), response(404)) }
            // `-UITestWithoutLayer <id>`: the backend does not offer this layer at all (always 404), e.g. today's production
            // backend without `radar_world`.
            if let index = CommandLine.arguments.firstIndex(of: "-UITestWithoutLayer"), CommandLine.arguments.indices.contains(index + 1),
               CommandLine.arguments[index + 1] == id { return (Data(), response(404)) }
            // `-UITestOutageAfter <s>`: the layer `-UITestOutageLayer` (default `radar_world`) disappears (404) that many seconds
            // after the first request; with `-UITestOutageFor <s>` it comes back after that long (outage, then recovery).
            if id == outageLayer, let limit = argument("-UITestOutageAfter") {
                let elapsed = Date().timeIntervalSince(stubStart)
                if elapsed > limit, elapsed <= limit + (argument("-UITestOutageFor") ?? .infinity) { return (Data(), response(404)) }
            }
            let now = Date()
            let observation = (entry.extra["kind"] as? String) == "observation"
            let step = (entry.extra["step"] as? Double) ?? 3600
            let count = observation ? 13 : 49
            // Observation: the newest slot lies a few minutes back; forecast: the hour before now, then 48 hours.
            let start = observation
                ? Date(timeIntervalSince1970: (now.timeIntervalSince1970 / step).rounded(.down) * step - Double(count - 1) * step)
                : Date(timeIntervalSince1970: (now.timeIntervalSince1970 / 3600).rounded(.down) * 3600 - 3600)
            let iso = ISO8601DateFormatter()
            let compact = DateFormatter()
            compact.locale = Locale(identifier: "en_US_POSIX"); compact.timeZone = TimeZone(identifier: "UTC")
            compact.dateFormat = "yyyyMMdd'T'HHmm'Z'"
            let run = compact.string(from: start)
            let slots = (0..<count).map { index -> [String: Any] in
                let time = start.addingTimeInterval(Double(index) * step)
                return ["time": iso.string(from: time), "kind": observation ? "observation" : (index == 0 ? "analysis" : "forecast"),
                        "path": "\(run)/\(compact.string(from: time)).webp"]
            }
            let referenceTime = observation ? start.addingTimeInterval(Double(count - 1) * step) : start
            var object: [String: Any] = [
                "schema": 1, "layer": id, "title": entry.title, "kind": observation ? "observation" : "forecast", "run": run,
                "reference_time": iso.string(from: referenceTime), "generated_at": iso.string(from: now.addingTimeInterval(-60)),
                "step_minutes": Int(step / 60), "forecast_horizon_minutes": observation ? 0 : 2880,
                "image": ["format": "image/webp", "width": 1024, "height": 1311, "projection": "EPSG:3857",
                          "bbox": [612257.0, 5942074.0, 1736584.0, 7381298.0], "bbox_wgs84": [5.5, 47.0, 15.6, 55.1]],
                "slots": slots, "attribution": (entry.extra["attribution"] as? String) ?? "Quelle: Deutscher Wetterdienst",
                "modification_notice": entry.notice]
            if mode == "wms" {
                object["legend"] = ["url": "https://maps.dwd.de/geoserver/ows?service=WMS&version=1.3.0&request=GetLegendGraphic&format=image/png&layer=dwd:Icon-eu_reg00625_fd_gl_T&style=icon-eu_reg00625_fd_gl_t_isoarea_tkb",
                                    "width": 88, "height": 505]
            }
            object.merge(entry.extra.filter { !["kind", "step", "attribution"].contains($0.key) }) { $1 }
            return ((try? JSONSerialization.data(withJSONObject: object)) ?? Data(), response(200))
        })
    }
}

/// UI tests only: slot images of the stubbed layers, drawn locally (1024 x 1311, like the manifest says), so the map
/// shows a real overlay instead of "image missing". Colours follow each layer's family; no network.
nonisolated enum UITestLayerImage {
    static func data(forLayer id: String) -> Data? {
        // The world stub follows the backend's world image (2048 x 995); the loader checks the manifest size.
        let (width, height) = id == "radar_world" ? (2048, 995) : (1024, 1311)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let (r, g, b, a) = color(id, Double(x) / Double(width), Double(y) / Double(height))
                let i = (y * width + x) * 4
                // Premultiplied RGBA.
                pixels[i] = UInt8(r * a * 255); pixels[i + 1] = UInt8(g * a * 255); pixels[i + 2] = UInt8(b * a * 255); pixels[i + 3] = UInt8(a * 255)
            }
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, "public.png" as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }

    private static func ramp(_ t: Double, _ stops: [(Double, Double, Double)]) -> (Double, Double, Double) {
        let scaled = min(max(t, 0), 1) * Double(stops.count - 1)
        let i = min(Int(scaled), stops.count - 2), f = scaled - Double(i)
        return (stops[i].0 + (stops[i + 1].0 - stops[i].0) * f, stops[i].1 + (stops[i + 1].1 - stops[i].1) * f,
                stops[i].2 + (stops[i + 1].2 - stops[i].2) * f)
    }

    private static func color(_ id: String, _ x: Double, _ y: Double) -> (Double, Double, Double, Double) {
        let wave = 0.5 + 0.5 * sin(x * 9 + y * 5) * cos(y * 7 - x * 3)
        switch id {
        case "temperature":
            let c = ramp(1 - (0.65 * y + 0.35 * wave), [(0.2, 0.3, 0.8), (0.5, 0.8, 0.95), (1, 0.9, 0.5), (0.95, 0.5, 0.2), (0.75, 0.15, 0.1)])
            return (c.0, c.1, c.2, 0.85)
        case "dewpoint", "humidity":
            let c = ramp(0.6 * wave + 0.4 * x, [(0.95, 0.9, 0.7), (0.5, 0.8, 0.6), (0.2, 0.6, 0.8), (0.1, 0.3, 0.6)])
            return (c.0, c.1, c.2, 0.85)
        case "radar_eu", "radar_world":
            let blob = sin(x * 14) * cos(y * 11)
            guard blob > 0.15 else { return (0, 0, 0, 0) }
            let c = ramp((blob - 0.15) / 0.85, [(0.4, 0.8, 0.95), (0.2, 0.7, 0.3), (0.95, 0.9, 0.2), (0.9, 0.2, 0.15)])
            return (c.0, c.1, c.2, 0.8)
        case "pressure", "pressure_eu":
            let d = hypot(x - 0.4, y - 0.45)
            return abs((d * 12).truncatingRemainder(dividingBy: 1) - 0.5) < 0.04 ? (0.15, 0.15, 0.2, 0.9) : (0, 0, 0, 0)
        case "lightning":
            let spot = sin(x * 40) * cos(y * 36)
            return spot > 0.93 ? (1, 0.85, 0.1, 0.95) : (0, 0, 0, 0)
        case "clouds":
            let v = 0.55 + 0.45 * wave
            return (v, v, v, 0.8)
        default:
            return wave > 0.55 ? (0.9, 0.9, 0.95, 0.7) : (0, 0, 0, 0)
        }
    }
}
#endif
