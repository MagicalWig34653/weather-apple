#if DEBUG
import CoreGraphics
import Foundation
import ImageIO

/// UI tests only (Debug builds): `-UITestRadar fixture` serves a fixed radar manifest and generated rain images,
/// so the map shows rain without network and without "Radar … lädt" or missing-tile notices. The time is frozen
/// like the forecast stub's (reference 09:40 local, "now" 09:50); light and dark appearance show the same data.
enum RadarUITestStub {
    static var isActive: Bool {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestRadar"),
              CommandLine.arguments.indices.contains(index + 1) else { return false }
        return CommandLine.arguments[index + 1] == "fixture"
    }

    /// Run 08:40 UTC (= forecast stub run), slots from 07:40 to 10:40 UTC in 5-minute steps.
    static let reference = DWDRequest.date("2026-11-18T08:40:00.000Z")!
    static let firstSlot = reference.addingTimeInterval(-3600)
    static let width = 1024, height = 1311
    private static let bbox = [612257.0, 5942074.0, 1736584.0, 7381298.0]

    static var backend: RadarBackendClient {
        RadarBackendClient(transport: { request in
            let url = request.url ?? RadarBackendConfig.baseURL()
            func http(_ code: Int) -> HTTPURLResponse { HTTPURLResponse(url: url, statusCode: code, httpVersion: nil, headerFields: nil)! }
            switch url.lastPathComponent {
            case "latest.json": return (manifestJSON(), http(200))
            case "history.json": return (historyJSON(), http(200))
            default: return (Data(), http(404))
            }
        }, clock: { ForecastUITestStub.now })
    }

    private static func name(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmm'Z'"
        return formatter.string(from: date)
    }

    static func manifestJSON() -> Data {
        let iso = DWDRequest.timestamp
        let run = name(reference)
        let slots = (0...36).map { step -> String in
            let time = firstSlot.addingTimeInterval(Double(step * 300))
            let kind = time <= reference ? "analysis" : "forecast"
            return "{\"time\":\"\(iso(time))\",\"kind\":\"\(kind)\",\"path\":\"\(run)/\(name(time)).webp\"}"
        }
        let json = "{\"schema\":1,\"run\":\"\(run)\",\"reference_time\":\"\(iso(reference))\",\"generated_at\":\"\(iso(reference.addingTimeInterval(190)))\","
            + "\"step_minutes\":5,\"forecast_horizon_minutes\":120,\"image\":{\"format\":\"image/webp\",\"width\":\(width),\"height\":\(height),"
            + "\"projection\":\"EPSG:3857\",\"bbox\":\(bbox),\"bbox_wgs84\":[5.5,47.0,15.6,55.1]},"
            + "\"attribution\":\"Quelle: Deutscher Wetterdienst\",\"modification_notice\":\"Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben\","
            + "\"slots\":[\(slots.joined(separator: ","))]}"
        return Data(json.utf8)
    }

    /// `-UITestRadarHistoryHours <48|72>`: `history.json` like the backend of PR #4 (that many hours, `history` block, one hole
    /// of 6 times and one missing time); `-UITestRadarOldest <hours>`: the source reaches back only that far (leading hole).
    /// Without the argument: today's stub (the hour before the manifest's first slot, no block).
    private static func argument(_ name: String) -> Int? {
        guard let index = CommandLine.arguments.firstIndex(of: name), CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return Int(CommandLine.arguments[index + 1])
    }
    static var historyHours: Int? { argument("-UITestRadarHistoryHours").flatMap { [48, 72].contains($0) ? $0 : nil } }

    /// `history.json`: the hour before the manifest's first slot (06:40 to 07:35 UTC), same image block as the manifest.
    static func historyJSON() -> Data {
        let iso = DWDRequest.timestamp
        let hours = historyHours
        // Window of PR #4: (reference - hours) up to the slot before latest's first one.
        let expected = hours.map { ($0 - 1) * 12 } ?? 12
        let oldestIndex = hours != nil ? (argument("-UITestRadarOldest").map { max(0, expected - ($0 - 1) * 12) } ?? 0) : 0
        let holeStart = expected / 2, missingOne = expected / 5
        let missing: Set<Int> = hours == nil ? [] : Set(holeStart..<(holeStart + 6)).union([missingOne])
        func time(_ index: Int) -> Date { firstSlot.addingTimeInterval(Double(index - expected) * 300) }
        let present = (oldestIndex..<expected).filter { !missing.contains($0) }
        let slots = present.map { step -> String in
            "{\"time\":\"\(iso(time(step)))\",\"kind\":\"analysis\",\"path\":\"history/\(name(time(step))).webp\"}"
        }
        var block = ""
        if let hours {
            var gaps: [String] = []
            if oldestIndex > 0 { gaps.append("{\"from\":\"\(iso(time(0)))\",\"to\":\"\(iso(time(oldestIndex - 1)))\",\"slots\":\(oldestIndex)}") }
            for (from, to) in [(missingOne, missingOne), (holeStart, holeStart + 5)] where from >= oldestIndex {
                gaps.append("{\"from\":\"\(iso(time(from)))\",\"to\":\"\(iso(time(to)))\",\"slots\":\(to - from + 1)}")
            }
            block = "\"history\":{\"hours\":\(hours),\"oldest\":\"\(iso(time(oldestIndex)))\",\"expected\":\(expected),\"present\":\(present.count),"
                + "\"complete\":false,\"gaps\":[\(gaps.joined(separator: ","))]},"
        }
        let json = "{\"schema\":1,\"run\":\"\(name(reference))\",\"generated_at\":\"\(iso(reference.addingTimeInterval(190)))\","
            + "\"step_minutes\":5,\"history_hours\":\(hours ?? 48),\(block)\"image\":{\"format\":\"image/webp\",\"width\":\(width),\"height\":\(height),"
            + "\"projection\":\"EPSG:3857\",\"bbox\":\(bbox),\"bbox_wgs84\":[5.5,47.0,15.6,55.1]},"
            + "\"attribution\":\"Quelle: Deutscher Wetterdienst\",\"modification_notice\":\"Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben\","
            + "\"slots\":[\(slots.joined(separator: ","))]}"
        return Data(json.utf8)
    }

    /// Image fetch for `BackendRadarLoader`: a PNG with rain cells; the cells move east with the slot time.
    static func fetch(_ url: URL) async throws -> Data {
        let stem = url.deletingPathExtension().lastPathComponent
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyyMMdd'T'HHmm'Z'"
        let time = formatter.date(from: stem) ?? reference
        let step = Int(time.timeIntervalSince(firstSlot) / 300)
        return render(step: step)
    }

    private static func pixel(lon: Double, lat: Double) -> CGPoint {
        let radius = 6378137.0
        let x = lon * .pi / 180 * radius
        let y = log(tan(.pi / 4 + lat * .pi / 360)) * radius
        return CGPoint(x: (x - bbox[0]) / (bbox[2] - bbox[0]) * Double(width), y: (1 - (y - bbox[1]) / (bbox[3] - bbox[1])) * Double(height))
    }

    private static func render(step: Int) -> Data {
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        // CoreGraphics origin is bottom-left; the pixel helper uses top-left.
        func cell(_ lon: Double, _ lat: Double, _ rx: Double, _ ry: Double) {
            let p = pixel(lon: lon + Double(step) * 0.04, lat: lat)
            let rings: [(CGFloat, [CGFloat])] = [(1.0, [0.45, 0.80, 0.85, 0.55]), (0.72, [0.15, 0.65, 0.25, 0.75]),
                                                 (0.45, [0.95, 0.85, 0.15, 0.85]), (0.22, [0.90, 0.30, 0.10, 0.90])]
            for (scale, c) in rings {
                context.setFillColor(red: c[0] * c[3], green: c[1] * c[3], blue: c[2] * c[3], alpha: c[3])
                context.fillEllipse(in: CGRect(x: p.x - rx * scale, y: CGFloat(height) - p.y - ry * scale, width: rx * scale * 2, height: ry * scale * 2))
            }
        }
        cell(13.0, 52.9, 150, 95)   // north-west of Berlin, reaches the place in the forecast slots
        cell(10.3, 53.6, 120, 70)
        cell(12.3, 50.9, 110, 80)
        let image = context.makeImage()!
        let data = NSMutableData()
        let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, image, nil)
        CGImageDestinationFinalize(destination)
        return data as Data
    }
}
#endif
