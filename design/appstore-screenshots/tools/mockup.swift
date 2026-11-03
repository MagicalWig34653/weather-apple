// Schematische Vorschau (kein Apple-Original): Suchergebnis-Karte und Produktseiten-Kopf mit dem Creative-Asset.
// Nutzung: swiftc -O mockup.swift -o mockup; ./mockup <icon.png> <suche-3x2.png> <header-21x9.png> <aus.png> "<Untertitel>"
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
let a = CommandLine.arguments
func load(_ p: String) -> CGImage { let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil)!; return CGImageSourceCreateImageAtIndex(s, 0, nil)! }
let icon = load(a[1]), search = load(a[2]), header = load(a[3])
let W = 2400, H = 1500
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(NSColor(white: 0.93, alpha: 1).cgColor); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
func clipRound(_ r: CGRect, _ rad: CGFloat, _ f: () -> Void) { ctx.saveGState(); ctx.addPath(CGPath(roundedRect: r, cornerWidth: rad, cornerHeight: rad, transform: nil)); ctx.clip(); f(); ctx.restoreGState() }
func txt(_ s: String, _ x: CGFloat, _ y: CGFloat, _ size: CGFloat, _ w: NSFont.Weight, _ c: NSColor = .black) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: w), .foregroundColor: c]).draw(at: NSPoint(x: x, y: y)) }
func button(_ x: CGFloat, _ y: CGFloat) {
    let r = CGRect(x: x, y: y, width: 190, height: 80); ctx.setFillColor(NSColor(white: 0.9, alpha: 1).cgColor)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.fillPath(); txt("Laden", x + 52, y + 22, 38, .bold, NSColor.systemBlue) }
func appRow(_ x: CGFloat, _ y: CGFloat, _ sub: String) {
    clipRound(CGRect(x: x, y: y, width: 150, height: 150), 34) { ctx.draw(icon, in: CGRect(x: x, y: y, width: 150, height: 150)) }
    txt("Showers", x + 180, y + 80, 48, .semibold); txt(sub, x + 180, y + 28, 36, .regular, .gray); button(x + 720, y + 35) }
// Links: Suchergebnis (Karte 3:2)
txt("Suchergebnis (Tab Suche)", 100, 1400, 40, .bold, .darkGray)
let cx: CGFloat = 100, cw: CGFloat = 1000, cy: CGFloat = 560
ctx.setFillColor(NSColor.white.cgColor); ctx.addPath(CGPath(roundedRect: CGRect(x: cx, y: cy - 220, width: cw, height: 220 + 667 + 60), cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.fillPath()
clipRound(CGRect(x: cx + 30, y: cy + 30, width: cw - 60, height: 667 - 30 + 30), 28) { ctx.draw(search, in: CGRect(x: cx + 30, y: cy + 30, width: cw - 60, height: (cw - 60) * 2 / 3)) }
appRow(cx + 40, cy - 190, a[5])
// Rechts: Produktseite mit Kopf (21:9)
txt("Produktseite (Kopf)", 1280, 1400, 40, .bold, .darkGray)
let hx: CGFloat = 1280, hw: CGFloat = 1020, hh = hw * 1646 / 3840
ctx.setFillColor(NSColor.white.cgColor); ctx.addPath(CGPath(roundedRect: CGRect(x: hx, y: 540, width: hw, height: 750), cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.fillPath()
clipRound(CGRect(x: hx + 30, y: 1280 - hh - 30 + 0, width: hw - 60, height: hh), 24) { ctx.draw(header, in: CGRect(x: hx + 30, y: 1280 - hh - 30, width: hw - 60, height: (hw - 60) * 1646 / 3840)) }
appRow(hx + 40, 1280 - hh - 240, a[5])
txt("Schematisch; Zuschnitt in App Store Connect (Preview-Tool) nicht geprüft.", 100, 60, 32, .regular, .gray)
let out = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[4]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out, ctx.makeImage()!, nil); CGImageDestinationFinalize(out)
