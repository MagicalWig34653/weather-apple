// Nutzung: swift strip-alpha.swift <datei.png> ...   (ersetzt die Datei durch eine PNG ohne Alphakanal)
import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

for path in CommandLine.arguments.dropFirst() {
    let url = URL(fileURLWithPath: path)
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil),
          let ctx = CGContext(data: nil, width: img.width, height: img.height, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { print("skip \(path)"); continue }
    ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
    guard let out = ctx.makeImage(), let dst = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { continue }
    CGImageDestinationAddImage(dst, out, nil); CGImageDestinationFinalize(dst)
}
