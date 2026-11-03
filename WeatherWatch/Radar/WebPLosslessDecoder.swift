import Foundation
import CoreGraphics

/// Minimal software decoder for lossless WebP (RIFF "VP8L", no animation, no ICC/EXIF use).
/// watchOS ImageIO has no WebP codec (Simulator: CGImageSource reports count 0), and the radar backend
/// serves lossless WebP. Follows the "WebP Lossless Bitstream Specification". Input is untrusted:
/// every read is bounds-checked and allocations are limited by the caller's width/height.
enum WebPLosslessDecoder {
    enum Failure: Error, Equatable { case notLossless, malformed, dimensionMismatch }

    /// Decodes and returns the `crop` rectangle (top-left origin) as non-premultiplied RGBA.
    static func decodeCropped(_ data: Data, expectedWidth: Int, expectedHeight: Int, crop: CGRect) throws -> CGImage {
        let bytes = [UInt8](data)
        guard bytes.count >= 25, bytes[0..<4] == [0x52, 0x49, 0x46, 0x46], bytes[8..<12] == [0x57, 0x45, 0x42, 0x50],
              bytes[12..<16] == [0x56, 0x50, 0x38, 0x4C] else { throw Failure.notLossless }
        let chunkSize = Int(bytes[16]) | Int(bytes[17]) << 8 | Int(bytes[18]) << 16 | Int(bytes[19]) << 24
        guard chunkSize >= 5, 20 + chunkSize <= bytes.count else { throw Failure.malformed }
        var reader = BitReader(bytes: bytes, start: 20, end: 20 + chunkSize)
        guard reader.bits(8) == 0x2F else { throw Failure.malformed }
        let width = reader.bits(14) + 1, height = reader.bits(14) + 1
        let alphaUsed = reader.bits(1) == 1
        guard reader.bits(3) == 0 else { throw Failure.malformed }
        guard width == expectedWidth, height == expectedHeight else { throw Failure.dimensionMismatch }
        let x0 = Int(crop.minX), y0 = Int(crop.minY), cw = Int(crop.width), ch = Int(crop.height)
        guard cw > 0, ch > 0, x0 >= 0, y0 >= 0, x0 + cw <= width, y0 + ch <= height else { throw Failure.malformed }

        var decoder = Decoder(reader: reader)
        let argb = try decoder.decodeImage(width: width, height: height)
        var rgba = [UInt8](repeating: 0, count: cw * ch * 4)
        for row in 0..<ch {
            for column in 0..<cw {
                let p = argb[(y0 + row) * width + x0 + column]
                let o = (row * cw + column) * 4
                rgba[o] = UInt8((p >> 16) & 0xFF)
                rgba[o + 1] = UInt8((p >> 8) & 0xFF)
                rgba[o + 2] = UInt8(p & 0xFF)
                rgba[o + 3] = alphaUsed ? UInt8(p >> 24) : 0xFF
            }
        }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: cw, height: ch, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: cw * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { throw Failure.malformed }
        return image
    }

    // MARK: Bit reader (LSB first)

    struct BitReader {
        let bytes: [UInt8]
        var position: Int
        let end: Int
        var bitBuffer: UInt64 = 0
        var bitCount = 0
        var overrun = false

        init(bytes: [UInt8], start: Int, end: Int) { self.bytes = bytes; position = start; self.end = end }

        mutating func fill() {
            while bitCount <= 56, position < end {
                bitBuffer |= UInt64(bytes[position]) << UInt64(bitCount)
                position += 1
                bitCount += 8
            }
        }

        mutating func bits(_ n: Int) -> Int {
            if n == 0 { return 0 }
            if bitCount < n { fill() }
            if bitCount < n { overrun = true; return 0 }
            let value = Int(bitBuffer & ((1 << UInt64(n)) - 1))
            bitBuffer >>= UInt64(n)
            bitCount -= n
            return value
        }
    }

    // MARK: Prefix (Huffman) code

    struct PrefixCode {
        // Canonical decode tables (as in zlib's puff): count per length, symbols sorted by code.
        var counts = [Int](repeating: 0, count: 16)
        var symbols: [Int] = []
        var single: Int?

        init(single: Int) { self.single = single }

        init?(lengths: [Int]) {
            guard lengths.allSatisfy({ (0...15).contains($0) }) else { return nil }
            for l in lengths { counts[l] += 1 }
            let used = lengths.count - counts[0]
            if used == 0 { return nil }
            if used == 1 { single = lengths.firstIndex { $0 != 0 }; return }
            // Kraft check: the code must be complete.
            var left = 1
            for len in 1...15 {
                left <<= 1
                left -= counts[len]
                if left < 0 { return nil }
            }
            if left != 0 { return nil }
            var offsets = [Int](repeating: 0, count: 16)
            for len in 1..<15 { offsets[len + 1] = offsets[len] + counts[len] }
            symbols = [Int](repeating: 0, count: used)
            for (symbol, l) in lengths.enumerated() where l != 0 {
                symbols[offsets[l]] = symbol
                offsets[l] += 1
            }
        }

        func read(_ reader: inout BitReader) -> Int? {
            if let single { return single }
            var code = 0, first = 0, index = 0
            for len in 1...15 {
                code |= reader.bits(1)
                let count = counts[len]
                if code - count < first { return symbols[index + (code - first)] }
                index += count
                first += count
                first <<= 1
                code <<= 1
                if reader.overrun { return nil }
            }
            return nil
        }
    }

    struct PrefixGroup {
        var green: PrefixCode, red: PrefixCode, blue: PrefixCode, alpha: PrefixCode, distance: PrefixCode
    }

    // MARK: Image decoding

    struct Transform {
        enum Kind { case predictor, crossColor, subtractGreen, colorIndexing }
        var kind: Kind
        var bits = 0
        var width = 0          // image width at the time the transform was read
        var data: [UInt32] = []
    }

    struct Decoder {
        var reader: BitReader
        init(reader: BitReader) { self.reader = reader }

        static let codeLengthOrder = [17, 18, 0, 1, 2, 3, 4, 5, 16, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]
        static let distanceMap: [(Int, Int)] = [
            (0, 1), (1, 0), (1, 1), (-1, 1), (0, 2), (2, 0), (1, 2), (-1, 2), (2, 1), (-2, 1), (2, 2), (-2, 2),
            (0, 3), (3, 0), (1, 3), (-1, 3), (3, 1), (-3, 1), (2, 3), (-2, 3), (3, 2), (-3, 2), (0, 4), (4, 0),
            (1, 4), (-1, 4), (4, 1), (-4, 1), (3, 3), (-3, 3), (2, 4), (-2, 4), (4, 2), (-4, 2), (0, 5), (3, 4),
            (-3, 4), (4, 3), (-4, 3), (5, 0), (1, 5), (-1, 5), (5, 1), (-5, 1), (2, 5), (-2, 5), (5, 2), (-5, 2),
            (4, 4), (-4, 4), (3, 5), (-3, 5), (5, 3), (-5, 3), (0, 6), (6, 0), (1, 6), (-1, 6), (6, 1), (-6, 1),
            (2, 6), (-2, 6), (6, 2), (-6, 2), (4, 5), (-4, 5), (5, 4), (-5, 4), (3, 6), (-3, 6), (6, 3), (-6, 3),
            (0, 7), (7, 0), (1, 7), (-1, 7), (5, 5), (-5, 5), (7, 1), (-7, 1), (4, 6), (-4, 6), (6, 4), (-6, 4),
            (2, 7), (-2, 7), (7, 2), (-7, 2), (3, 7), (-3, 7), (7, 3), (-7, 3), (5, 6), (-5, 6), (6, 5), (-6, 5),
            (8, 0), (4, 7), (-4, 7), (7, 4), (-7, 4), (8, 1), (8, 2), (6, 6), (-6, 6), (8, 3), (5, 7), (-5, 7),
            (7, 5), (-7, 5), (8, 4), (6, 7), (-6, 7), (7, 6), (-7, 6), (8, 5), (7, 7), (-7, 7), (8, 6), (8, 7)
        ]

        mutating func decodeImage(width: Int, height: Int) throws -> [UInt32] {
            var transforms: [Transform] = []
            var xsize = width
            var seen = Set<Int>()
            while reader.bits(1) == 1 {
                let type = reader.bits(2)
                guard seen.insert(type).inserted else { throw Failure.malformed }
                switch type {
                case 0, 1:
                    var t = Transform(kind: type == 0 ? .predictor : .crossColor)
                    t.bits = reader.bits(3) + 2
                    t.width = xsize
                    let bw = (xsize + (1 << t.bits) - 1) >> t.bits, bh = (height + (1 << t.bits) - 1) >> t.bits
                    t.data = try decodeEntropyImage(width: bw, height: bh, isMain: false)
                    transforms.append(t)
                case 2:
                    var t = Transform(kind: .subtractGreen)
                    t.width = xsize
                    transforms.append(t)
                default:
                    var t = Transform(kind: .colorIndexing)
                    let size = reader.bits(8) + 1
                    var table = try decodeEntropyImage(width: size, height: 1, isMain: false)
                    for i in 1..<max(1, table.count) { table[i] = Self.addPixels(table[i], table[i - 1]) }
                    let bits = size <= 2 ? 3 : size <= 4 ? 2 : size <= 16 ? 1 : 0
                    t.bits = bits
                    t.width = xsize
                    // Pad the palette so out-of-range indices decode to transparent black.
                    table += [UInt32](repeating: 0, count: max(0, (1 << (8 >> bits)) - size))
                    t.data = table
                    transforms.append(t)
                    xsize = (xsize + (1 << bits) - 1) >> bits
                }
                if reader.overrun { throw Failure.malformed }
            }
            var pixels = try decodeEntropyImage(width: xsize, height: height, isMain: true)
            for transform in transforms.reversed() {
                pixels = try Self.inverse(transform, pixels: pixels, height: height)
            }
            guard pixels.count == width * height else { throw Failure.malformed }
            return pixels
        }

        mutating func decodeEntropyImage(width: Int, height: Int, isMain: Bool) throws -> [UInt32] {
            guard width > 0, height > 0, width <= 16384, height <= 16384 else { throw Failure.malformed }
            var cacheBits = 0
            if reader.bits(1) == 1 {
                cacheBits = reader.bits(4)
                guard (1...11).contains(cacheBits) else { throw Failure.malformed }
            }
            var metaBits = 0
            var meta: [UInt32] = []
            var groupCount = 1
            if isMain, reader.bits(1) == 1 {
                metaBits = reader.bits(3) + 2
                let mw = (width + (1 << metaBits) - 1) >> metaBits, mh = (height + (1 << metaBits) - 1) >> metaBits
                meta = try decodeEntropyImage(width: mw, height: mh, isMain: false)
                groupCount = Int(meta.map { ($0 >> 8) & 0xFFFF }.max() ?? 0) + 1
                guard groupCount <= 1 << 12 else { throw Failure.malformed }
            }
            let cacheSize = cacheBits > 0 ? 1 << cacheBits : 0
            var groups: [PrefixGroup] = []
            groups.reserveCapacity(groupCount)
            for _ in 0..<groupCount {
                let green = try readPrefixCode(alphabet: 256 + 24 + cacheSize)
                let red = try readPrefixCode(alphabet: 256)
                let blue = try readPrefixCode(alphabet: 256)
                let alpha = try readPrefixCode(alphabet: 256)
                let distance = try readPrefixCode(alphabet: 40)
                groups.append(PrefixGroup(green: green, red: red, blue: blue, alpha: alpha, distance: distance))
            }

            let total = width * height
            var out = [UInt32](repeating: 0, count: total)
            var cache = [UInt32](repeating: 0, count: cacheSize)
            let cacheShift = UInt32(32 - cacheBits)
            var position = 0
            var group = groups[0]
            let metaWidth = metaBits > 0 ? (width + (1 << metaBits) - 1) >> metaBits : 0

            func insert(_ p: UInt32) {
                if cacheBits > 0 { cache[Int((p &* 0x1E35A7BD) >> cacheShift)] = p }
            }

            while position < total {
                if metaBits > 0 {
                    let x = position % width, y = position / width
                    group = groups[Int((meta[(y >> metaBits) * metaWidth + (x >> metaBits)] >> 8) & 0xFFFF)]
                }
                guard let symbol = group.green.read(&reader), !reader.overrun else { throw Failure.malformed }
                if symbol < 256 {
                    guard let r = group.red.read(&reader), let b = group.blue.read(&reader),
                          let a = group.alpha.read(&reader), !reader.overrun else { throw Failure.malformed }
                    let p = UInt32(a) << 24 | UInt32(r) << 16 | UInt32(symbol) << 8 | UInt32(b)
                    out[position] = p
                    insert(p)
                    position += 1
                } else if symbol < 280 {
                    let length = try prefixValue(symbol - 256)
                    guard let distanceSymbol = group.distance.read(&reader), !reader.overrun else { throw Failure.malformed }
                    let code = try prefixValue(distanceSymbol)
                    var distance: Int
                    if code > 120 { distance = code - 120 } else {
                        let (dx, dy) = Self.distanceMap[code - 1]
                        distance = dx + dy * width
                    }
                    if distance < 1 { distance = 1 }
                    guard distance <= position, position + length <= total else { throw Failure.malformed }
                    for i in 0..<length {
                        let p = out[position + i - distance]
                        out[position + i] = p
                        insert(p)
                    }
                    position += length
                } else {
                    let index = symbol - 280
                    guard index < cacheSize else { throw Failure.malformed }
                    let p = cache[index]
                    out[position] = p
                    insert(p)
                    position += 1
                }
            }
            return out
        }

        mutating func prefixValue(_ prefix: Int) throws -> Int {
            if prefix < 4 { return prefix + 1 }
            let extra = (prefix - 2) >> 1
            let offset = (2 + (prefix & 1)) << extra
            let value = offset + reader.bits(extra) + 1
            if reader.overrun { throw Failure.malformed }
            return value
        }

        mutating func readPrefixCode(alphabet: Int) throws -> PrefixCode {
            if reader.bits(1) == 1 {
                // Simple code: one or two symbols.
                let count = reader.bits(1) + 1
                let first = reader.bits(reader.bits(1) == 1 ? 8 : 1)
                var lengths = [Int](repeating: 0, count: alphabet)
                guard first < alphabet else { throw Failure.malformed }
                if count == 1 { return PrefixCode(single: first) }
                let second = reader.bits(8)
                guard second < alphabet, second != first else { throw Failure.malformed }
                lengths[first] = 1
                lengths[second] = 1
                guard let code = PrefixCode(lengths: lengths) else { throw Failure.malformed }
                return code
            }
            var codeLengthLengths = [Int](repeating: 0, count: 19)
            let numCodes = reader.bits(4) + 4
            guard numCodes <= 19 else { throw Failure.malformed }
            for i in 0..<numCodes { codeLengthLengths[Self.codeLengthOrder[i]] = reader.bits(3) }
            guard let lengthCode = PrefixCode(lengths: codeLengthLengths) else { throw Failure.malformed }
            var maxSymbol = alphabet
            if reader.bits(1) == 1 {
                let lengthBits = 2 + 2 * reader.bits(3)
                maxSymbol = 2 + reader.bits(lengthBits)
                guard maxSymbol <= alphabet else { throw Failure.malformed }
            }
            var lengths = [Int](repeating: 0, count: alphabet)
            var symbol = 0, previous = 8
            while symbol < alphabet {
                if maxSymbol == 0 { break }
                maxSymbol -= 1
                guard let value = lengthCode.read(&reader), !reader.overrun else { throw Failure.malformed }
                if value < 16 {
                    lengths[symbol] = value
                    symbol += 1
                    if value != 0 { previous = value }
                } else {
                    let repeatCount: Int, fill: Int
                    switch value {
                    case 16: repeatCount = 3 + reader.bits(2); fill = previous
                    case 17: repeatCount = 3 + reader.bits(3); fill = 0
                    default: repeatCount = 11 + reader.bits(7); fill = 0
                    }
                    guard symbol + repeatCount <= alphabet else { throw Failure.malformed }
                    for _ in 0..<repeatCount { lengths[symbol] = fill; symbol += 1 }
                }
            }
            guard let code = PrefixCode(lengths: lengths) else { throw Failure.malformed }
            return code
        }

        // MARK: Inverse transforms

        static func addPixels(_ a: UInt32, _ b: UInt32) -> UInt32 {
            let ag = (a & 0xFF00FF00) &+ (b & 0xFF00FF00)
            let rb = (a & 0x00FF00FF) &+ (b & 0x00FF00FF)
            return (ag & 0xFF00FF00) | (rb & 0x00FF00FF)
        }

        private static func average2(_ a: UInt32, _ b: UInt32) -> UInt32 {
            (((a ^ b) & 0xFEFEFEFE) >> 1) &+ (a & b)
        }

        private static func channel(_ p: UInt32, _ shift: UInt32) -> Int { Int((p >> shift) & 0xFF) }

        private static func select(_ left: UInt32, _ top: UInt32, _ topLeft: UInt32) -> UInt32 {
            var sumTop = 0, sumLeft = 0
            for shift in [UInt32(0), 8, 16, 24] {
                let l = channel(left, shift), t = channel(top, shift), tl = channel(topLeft, shift)
                sumTop += abs(t - tl)   // distance if predicting with left
                sumLeft += abs(l - tl)
            }
            return sumTop < sumLeft ? left : top
        }

        private static func clamp(_ v: Int) -> Int { min(255, max(0, v)) }

        private static func clampAddSubtractFull(_ a: UInt32, _ b: UInt32, _ c: UInt32) -> UInt32 {
            var result: UInt32 = 0
            for shift in [UInt32(0), 8, 16, 24] {
                result |= UInt32(clamp(channel(a, shift) + channel(b, shift) - channel(c, shift))) << shift
            }
            return result
        }

        private static func clampAddSubtractHalf(_ a: UInt32, _ b: UInt32) -> UInt32 {
            var result: UInt32 = 0
            for shift in [UInt32(0), 8, 16, 24] {
                let x = channel(a, shift)
                result |= UInt32(clamp(x + (x - channel(b, shift)) / 2)) << shift
            }
            return result
        }

        private static func predict(mode: Int, left: UInt32, top: UInt32, topRight: UInt32, topLeft: UInt32) -> UInt32 {
            switch mode {
            case 0: return 0xFF000000
            case 1: return left
            case 2: return top
            case 3: return topRight
            case 4: return topLeft
            case 5: return average2(average2(left, topRight), top)
            case 6: return average2(left, topLeft)
            case 7: return average2(left, top)
            case 8: return average2(topLeft, top)
            case 9: return average2(top, topRight)
            case 10: return average2(average2(left, topLeft), average2(top, topRight))
            case 11: return select(left, top, topLeft)
            case 12: return clampAddSubtractFull(left, top, topLeft)
            case 13: return clampAddSubtractHalf(average2(left, top), topLeft)
            default: return 0xFF000000
            }
        }

        private static func colorDelta(_ t: UInt32, _ c: UInt32) -> Int {
            Int(Int8(truncatingIfNeeded: t)) * Int(Int8(truncatingIfNeeded: c)) >> 5
        }

        static func inverse(_ t: Transform, pixels: [UInt32], height: Int) throws -> [UInt32] {
            var pixels = pixels
            let width = t.width
            switch t.kind {
            case .subtractGreen:
                guard pixels.count == width * height else { throw Failure.malformed }
                for i in pixels.indices {
                    let p = pixels[i]
                    let g = (p >> 8) & 0xFF
                    let r = (((p >> 16) & 0xFF) &+ g) & 0xFF
                    let b = ((p & 0xFF) &+ g) & 0xFF
                    pixels[i] = (p & 0xFF00FF00) | r << 16 | b
                }
            case .crossColor:
                guard pixels.count == width * height else { throw Failure.malformed }
                let blockWidth = (width + (1 << t.bits) - 1) >> t.bits
                for y in 0..<height {
                    for x in 0..<width {
                        let element = t.data[(y >> t.bits) * blockWidth + (x >> t.bits)]
                        let greenToRed = element & 0xFF, greenToBlue = (element >> 8) & 0xFF, redToBlue = (element >> 16) & 0xFF
                        let p = pixels[y * width + x]
                        let green = (p >> 8) & 0xFF
                        var red = Int((p >> 16) & 0xFF), blue = Int(p & 0xFF)
                        red = (red + colorDelta(greenToRed, green)) & 0xFF
                        blue = (blue + colorDelta(greenToBlue, green) + colorDelta(redToBlue, UInt32(red))) & 0xFF
                        pixels[y * width + x] = (p & 0xFF00FF00) | UInt32(red) << 16 | UInt32(blue)
                    }
                }
            case .predictor:
                guard pixels.count == width * height else { throw Failure.malformed }
                let blockWidth = (width + (1 << t.bits) - 1) >> t.bits
                pixels[0] = addPixels(pixels[0], 0xFF000000)
                for x in 1..<max(1, width) { pixels[x] = addPixels(pixels[x], pixels[x - 1]) }
                for y in 1..<max(1, height) {
                    pixels[y * width] = addPixels(pixels[y * width], pixels[(y - 1) * width])
                    for x in 1..<max(1, width) {
                        let i = y * width + x
                        let mode = Int((t.data[(y >> t.bits) * blockWidth + (x >> t.bits)] >> 8) & 0xF)
                        let prediction = predict(mode: mode, left: pixels[i - 1], top: pixels[i - width],
                                                 topRight: pixels[i - width + 1], topLeft: pixels[i - width - 1])
                        pixels[i] = addPixels(pixels[i], prediction)
                    }
                }
            case .colorIndexing:
                let packedWidth = (width + (1 << t.bits) - 1) >> t.bits
                guard pixels.count == packedWidth * height else { throw Failure.malformed }
                var out = [UInt32](repeating: 0, count: width * height)
                let bitsPerPixel = 8 >> t.bits
                let mask = (1 << bitsPerPixel) - 1
                for y in 0..<height {
                    for x in 0..<width {
                        let packed = pixels[y * packedWidth + (x >> t.bits)]
                        let index = t.bits == 0 ? Int((packed >> 8) & 0xFF)
                            : (Int((packed >> 8) & 0xFF) >> (bitsPerPixel * (x & ((1 << t.bits) - 1)))) & mask
                        out[y * width + x] = index < t.data.count ? t.data[index] : 0
                    }
                }
                pixels = out
            }
            return pixels
        }
    }
}
