// Kopfzeilen-Variante eines Store-Screenshots: Textzeile oben, unverzerrter Screenshot darunter (unten angeschnitten).
// Nutzung: swift headline.swift <eingabe.png> <ausgabe.png> <breite> <hoehe> "<Kopfzeile>" "<Untertitel>" [light|dark]
// Ausgabe: exakt breite x hoehe, RGB ohne Alphakanal. Schrift: SF (Systemschrift), nur lokal, keine Netzdienste.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let a = CommandLine.arguments
guard a.count >= 7, let W = Int(a[3]), let H = Int(a[4]),
      let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: a[1]) as CFURL, nil),
      let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else {
    FileHandle.standardError.write(Data("Nutzung: headline.swift in.png out.png W H Kopfzeile Untertitel [light|dark]\n".utf8)); exit(1)
}
let dark = a.count > 7 && a[7] == "dark"
let w = CGFloat(W), h = CGFloat(H)
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0, space: cs,
                    bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!

// Hintergrund: ruhiger Verlauf
let top = dark ? NSColor(srgbRed: 0.05, green: 0.09, blue: 0.17, alpha: 1) : NSColor(srgbRed: 0.20, green: 0.45, blue: 0.80, alpha: 1)
let bottom = dark ? NSColor(srgbRed: 0.02, green: 0.04, blue: 0.09, alpha: 1) : NSColor(srgbRed: 0.10, green: 0.27, blue: 0.58, alpha: 1)
let grad = CGGradient(colorsSpace: cs, colors: [top.cgColor, bottom.cgColor] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: h), end: CGPoint(x: 0, y: 0), options: [])

// Text (Koordinaten: Ursprung unten links)
let unit = min(w, h * 0.5)  // Schriftgroesse haengt an der Breite (iPad: an der halben Hoehe)
let titleSize = unit * 0.095, subSize = unit * 0.045
let marginTop = h * 0.045
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
let para = NSMutableParagraphStyle(); para.alignment = .center
func draw(_ s: String, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, topY: CGFloat) -> CGFloat {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: NSColor(white: 1, alpha: alpha), .paragraphStyle: para]
    let str = NSAttributedString(string: s, attributes: attrs)
    let r = str.boundingRect(with: NSSize(width: w * 0.9, height: h), options: [.usesLineFragmentOrigin])
    str.draw(with: NSRect(x: w * 0.05, y: h - topY - r.height, width: w * 0.9, height: r.height), options: [.usesLineFragmentOrigin])
    return topY + r.height
}
var y = draw(a[5], size: titleSize, weight: .bold, alpha: 1, topY: marginTop)
if !a[6].isEmpty { y = draw(a[6], size: subSize, weight: .medium, alpha: 0.85, topY: y + titleSize * 0.12) }
NSGraphicsContext.restoreGraphicsState()

// Screenshot: gleichmaessig skaliert, zentriert, unten angeschnitten
let sw = w * (h / w > 1.6 ? 0.80 : 0.74)
let sh = sw * CGFloat(img.height) / CGFloat(img.width)
let sx = (w - sw) / 2
let sTop = y + h * 0.035
let rect = CGRect(x: sx, y: h - sTop - sh, width: sw, height: sh)
let radius = sw * 0.075
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -w * 0.012), blur: w * 0.04, color: NSColor(white: 0, alpha: 0.35).cgColor)
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
ctx.setFillColor(NSColor.black.cgColor); ctx.fillPath()
ctx.restoreGState()
ctx.saveGState()
ctx.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)); ctx.clip()
ctx.interpolationQuality = .high
ctx.draw(img, in: rect)
ctx.restoreGState()

let out = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: a[2]) as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, out, nil)
guard CGImageDestinationFinalize(dest) else { exit(2) }
