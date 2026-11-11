#!/usr/bin/env swift
// Contrast measurement from UI-test dumps (AccessibilityAuditTests.testContrastDump): for each name.json (element
// frames in points) next to name.png the text colour (extreme pixels inside the frame) is compared with the
// background (median of a ring around the frame), WCAG contrast ratio.
// Usage: swift tools/contrast_measure.swift <dir> > contrast.tsv
// Limits: anti-aliasing and glass over a map make the background a range, not a value; `spread` is the standard
// deviation of the ring luminance (high = unreliable). Frames of multi-line text give a lower bound of the real contrast.
import CoreGraphics
import Foundation
import ImageIO

func luminance(_ r: Double, _ g: Double, _ b: Double) -> Double {
    func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
}

struct Pixels {
    let width: Int, height: Int
    let data: [UInt8]
    init?(path: String) {
        guard let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        width = image.width; height = image.height
        var buffer = [UInt8](repeating: 0, count: width * height * 4)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(data: &buffer, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        data = buffer
    }
    func rgb(_ x: Int, _ y: Int) -> (Double, Double, Double)? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        let i = (y * width + x) * 4
        return (Double(data[i]) / 255, Double(data[i + 1]) / 255, Double(data[i + 2]) / 255)
    }
}

func hex(_ c: (Double, Double, Double)) -> String {
    String(format: "#%02X%02X%02X", Int(c.0 * 255 + 0.5), Int(c.1 * 255 + 0.5), Int(c.2 * 255 + 0.5))
}

let dir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let files = (try FileManager.default.contentsOfDirectory(atPath: dir)).filter { $0.hasSuffix(".json") }.sorted()
print("screen\ttype\tlabel\tfg\tbg\tratio\tspread\tsize_pt")
for file in files {
    let name = String(file.dropLast(5))
    guard let json = try? JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: dir + "/" + file))) as? [String: Any],
          let screen = json["screen"] as? [String: Double], let elements = json["elements"] as? [[String: Any]],
          let image = Pixels(path: dir + "/" + name + ".png") else { continue }
    let scale = Double(image.width) / (screen["w"] ?? 1)
    var seen = Set<String>()
    for element in elements {
        guard let label = element["label"] as? String, let type = element["type"] as? Int,
              let x = element["x"] as? Double, let y = element["y"] as? Double, let w = element["w"] as? Double, let h = element["h"] as? Double
        else { continue }
        // staticText (48) and buttons (9) with visible text only; skip huge containers and off-screen frames.
        guard type == 48 || type == 9, w < (screen["w"] ?? 0) * 0.98, h < 200, w >= 6, h >= 6 else { continue }
        let key = "\(label)|\(Int(x))|\(Int(y))"
        guard seen.insert(key).inserted else { continue }
        let x0 = Int(x * scale), y0 = Int(y * scale), x1 = Int((x + w) * scale), y1 = Int((y + h) * scale)
        guard x1 <= image.width, y1 <= image.height, x0 >= 0, y0 >= 0 else { continue }
        // Background ring: 4 px outside the frame.
        var ring: [Double] = [], ringColors: [(Double, Double, Double)] = []
        for xx in stride(from: x0, to: x1, by: 2) {
            for yy in [y0 - 4, y1 + 4] { if let c = image.rgb(xx, yy) { ring.append(luminance(c.0, c.1, c.2)); ringColors.append(c) } }
        }
        for yy in stride(from: y0, to: y1, by: 2) {
            for xx in [x0 - 4, x1 + 4] { if let c = image.rgb(xx, yy) { ring.append(luminance(c.0, c.1, c.2)); ringColors.append(c) } }
        }
        guard ring.count > 4 else { continue }
        let order = ring.enumerated().sorted { $0.element < $1.element }.map(\.offset)
        let bg = ringColors[order[order.count / 2]]
        let bgL = luminance(bg.0, bg.1, bg.2)
        let mean = ring.reduce(0, +) / Double(ring.count)
        let spread = (ring.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(ring.count)).squareRoot()
        // Foreground: pixels inside the frame furthest from the background luminance; average of the extreme 3 %.
        var inside: [((Double, Double, Double), Double)] = []
        for yy in y0..<y1 { for xx in x0..<x1 { if let c = image.rgb(xx, yy) { inside.append((c, abs(luminance(c.0, c.1, c.2) - bgL))) } } }
        guard !inside.isEmpty else { continue }
        inside.sort { $0.1 > $1.1 }
        let top = Array(inside.prefix(max(3, inside.count / 33)))
        let fg = (top.map { $0.0.0 }.reduce(0, +) / Double(top.count), top.map { $0.0.1 }.reduce(0, +) / Double(top.count), top.map { $0.0.2 }.reduce(0, +) / Double(top.count))
        let fgL = luminance(fg.0, fg.1, fg.2)
        let ratio = (max(fgL, bgL) + 0.05) / (min(fgL, bgL) + 0.05)
        print("\(name)\t\(type == 48 ? "text" : "button")\t\(label.replacingOccurrences(of: "\t", with: " ").prefix(48))\t\(hex(fg))\t\(hex(bg))\t\(String(format: "%.2f", ratio))\t\(String(format: "%.3f", spread))\t\(Int(h))")
    }
}
