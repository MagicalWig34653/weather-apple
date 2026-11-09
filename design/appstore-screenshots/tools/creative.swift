// Creative-Asset (Product-Page-Header / Suchergebnis): App-Icon, Name, Kurztext und zwei echte App-Screenshots auf Blau.
// Nutzung: swiftc -O creative.swift -o creative; ./creative <icon.png> <shot1.png> <shot2.png> <aus.png> <breite> <hoehe> "<Name>" "<Zeile1>" "<Zeile2>"
// Inhalt liegt in einer mittigen 3:2-Zone (Hoehe = Bildhoehe), links/rechts davon nur Hintergrund (Sicherheitsbereich, Apple-Vorlagen nicht eingesehen).
// Ausgabe exakt breite x hoehe, sRGB, ohne Alphakanal.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count >= 10, let W = Int(a[5]), let H = Int(a[6]) else { print("Nutzung siehe Kopf"); exit(1) }
func load(_ p: String) -> CGImage {
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: p) as CFURL, nil), let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { print("Fehler: \(p)"); exit(1) }
    return i
}
let icon = load(a[1]), shot1 = load(a[2]), shot2 = load(a[3])
let w = CGFloat(W), h = CGFloat(H)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
let top = NSColor(srgbRed: 0.20, green: 0.45, blue: 0.80, alpha: 1), bot = NSColor(srgbRed: 0.10, green: 0.27, blue: 0.58, alpha: 1)
ctx.drawLinearGradient(CGGradient(colorsSpace: cs, colors: [top.cgColor, bot.cgColor] as CFArray, locations: [0, 1])!, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])
let zoneW = min(w, h * 1.5), x0 = (w - zoneW) / 2   // mittige 3:2-Zone

// masked: Bild hat schon eigene Rundung (ictool-Icon mit Alpha): nur mit Schatten zeichnen, kein Schwarz-Unterbau, kein Clip.
func rounded(_ img: CGImage, rect: CGRect, radius: CGFloat, shadow: Bool, masked: Bool = false) {
    if masked {
        ctx.saveGState()
        if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -h * 0.012), blur: h * 0.04, color: NSColor(white: 0, alpha: 0.35).cgColor) }
        ctx.draw(img, in: rect); ctx.restoreGState(); return
    }
    ctx.saveGState()
    if shadow { ctx.setShadow(offset: CGSize(width: 0, height: -h * 0.012), blur: h * 0.04, color: NSColor(white: 0, alpha: 0.35).cgColor) }
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
    ctx.draw(img, in: rect)
    ctx.restoreGState()
}
// Telefone rechts in der Zone: hinten Orte, vorn Radar; unten angeschnitten
let ph = h * 1.02, pw = ph * CGFloat(shot1.width) / CGFloat(shot1.height)
let frontX = x0 + zoneW - pw - zoneW * 0.04
rounded(shot2, rect: CGRect(x: frontX - pw * 0.62, y: -h * 0.16, width: pw, height: ph), radius: pw * 0.11, shadow: true)
rounded(shot1, rect: CGRect(x: frontX, y: -h * 0.05, width: pw, height: ph), radius: pw * 0.11, shadow: true)

// Icon + Text links in der Zone
// Leere Zeile 1 ("") entfaellt; Block wird dann nach unten zentriert nachgefuehrt.
let dy = a[8].isEmpty ? -h * 0.07 : 0
let ic = h * 0.20, tx = x0 + zoneW * 0.06
rounded(icon, rect: CGRect(x: tx, y: h * 0.62 + dy, width: ic, height: ic), radius: ic * 0.2237, shadow: true, masked: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
func text(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, y: CGFloat) {
    NSAttributedString(string: s, attributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: NSColor(white: 1, alpha: alpha)]).draw(at: NSPoint(x: tx, y: y))
}
text(a[7], size: h * 0.085, weight: .bold, alpha: 1, y: h * 0.47 + dy)
if !a[8].isEmpty { text(a[8], size: h * 0.045, weight: .semibold, alpha: 1, y: h * 0.37) }
text(a[9], size: h * 0.045, weight: .regular, alpha: a[8].isEmpty ? 1 : 0.85, y: h * 0.30 + dy + (a[8].isEmpty ? h * 0.07 : 0))
NSGraphicsContext.restoreGraphicsState()

let out = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[4]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(out, ctx.makeImage()!, nil); CGImageDestinationFinalize(out)
