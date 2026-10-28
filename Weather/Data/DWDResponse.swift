import Foundation
import ImageIO
import zlib

enum DWDRunIndex {
    static func dates(from data: Data, now: Date) throws -> [Date] {
        guard let html = String(data: data, encoding: .utf8) else { throw DWDDataError.invalidResponse }
        let regex = try NSRegularExpression(pattern: #"composite_rv_(\d{8})_(\d{4})\.tar"#)
        let ns = html as NSString
        let dates = regex.matches(in: html, range: NSRange(location: 0, length: ns.length)).compactMap { match -> Date? in
            let day = ns.substring(with: match.range(at: 1))
            let time = ns.substring(with: match.range(at: 2))
            let text = "\(day.prefix(4))-\(day.dropFirst(4).prefix(2))-\(day.suffix(2))T\(time.prefix(2)):\(time.suffix(2)):00Z"
            return DWDRequest.date(text)
        }
        let sorted = Array(Set(dates)).sorted()
        guard let latest = sorted.last else { throw DWDDataError.invalidResponse }
        guard latest.timeIntervalSince(now) <= 60,
              now.timeIntervalSince(latest) <= RainForecast.maximumAge else {
            throw DWDDataError.staleData
        }
        return sorted
    }
}

enum DWDResponse {
    /// WMS may return a ServiceException report with HTTP 200. Inspect only a bounded
    /// prefix, never log the body (point queries can contain coordinate metadata).
    static func serviceError(in data: Data) -> DWDDataError? {
        guard let text = String(data: data.prefix(16_384), encoding: .utf8),
              text.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<"),
              text.contains("ServiceException") || text.contains("ExceptionReport") else { return nil }
        if text.contains("InvalidDimensionValue") || text.contains("MissingDimensionValue") {
            return .runUnavailable
        }
        return .invalidResponse
    }

    static func radarImage(from data: Data) throws -> Data {
        if let error = serviceError(in: data) { throw error }
        guard data.count <= 2 * 1_024 * 1_024,
              data.starts(with: [137, 80, 78, 71, 13, 10, 26, 10]),
              hasCompletePNGChunks(data),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(source) == 1,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int,
              (1...1024).contains(width), (1...1024).contains(height),
              let image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldCacheImmediately: true] as CFDictionary),
              image.width == width, image.height == height,
              CGImageSourceGetStatusAtIndex(source, 0) == .statusComplete else {
            throw DWDDataError.invalidResponse
        }
        return data
    }

    // ImageIO can recover truncated/corrupt PNGs with substitute pixels. Require
    // complete chunks and their CRCs as well as an actual bounded image decode.
    private static func hasCompletePNGChunks(_ data: Data) -> Bool {
        data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            func integer(at offset: Int) -> UInt32 {
                (0..<4).reduce(UInt32(0)) { ($0 << 8) | UInt32(bytes[offset + $1]) }
            }
            var offset = 8
            while offset + 12 <= bytes.count {
                let count = Int(integer(at: offset))
                guard count <= bytes.count - offset - 12 else { return false }
                let actual = crc32(0, bytes.baseAddress!.advanced(by: offset + 4).assumingMemoryBound(to: Bytef.self), uInt(count + 4))
                guard UInt32(actual) == integer(at: offset + 8 + count) else { return false }
                if integer(at: offset + 4) == 0x49454E44 { // IEND
                    return count == 0 && offset + 12 == bytes.count
                }
                offset += count + 12
            }
            return false
        }
    }

    private struct Collection: Decodable {
        let type: String
        let features: [Feature]
        let numberReturned: Int?
    }

    private struct Feature: Decodable {
        let properties: Properties
    }

    private struct Properties: Decodable {
        let value: Double?
        let time: String
        let reference: String
        enum CodingKeys: String, CodingKey {
            case value = "RV_ANALYSIS", time = "TIME", reference = "REFERENCE_TIME"
        }
    }

    static func forecast(from data: Data, expectedReference: Date, now: Date) throws -> RainForecast {
        if let error = serviceError(in: data) { throw error }
        let collection: Collection
        do { collection = try JSONDecoder().decode(Collection.self, from: data) }
        catch { throw DWDDataError.invalidResponse }
        guard collection.type == "FeatureCollection",
              collection.numberReturned == nil || collection.numberReturned == collection.features.count else {
            throw DWDDataError.invalidResponse
        }
        guard collection.features.count == 25 else { throw DWDDataError.incompleteForecast }
        var samples: [RainSample] = []
        for feature in collection.features {
            guard let reference = DWDRequest.date(feature.properties.reference),
                  let date = DWDRequest.date(feature.properties.time) else { throw DWDDataError.invalidResponse }
            guard reference == expectedReference else { throw DWDDataError.mismatchedRun }
            samples.append(RainSample(date: date, amountMM: amount(from: feature.properties.value)))
        }
        samples.sort { $0.date < $1.date }
        for (index, sample) in samples.enumerated() {
            guard abs(sample.date.timeIntervalSince(expectedReference) - Double(index * 300)) < 0.1 else {
                throw DWDDataError.incompleteForecast
            }
        }
        let result = RainForecast(referenceTime: expectedReference, samples: samples)
        guard !result.isStale(at: now) else { throw DWDDataError.staleData }
        guard samples.contains(where: { $0.amountMM != nil }) else { throw DWDDataError.incompleteForecast }
        return result
    }

    static func amount(from value: Double?) -> Double? {
        guard let value, value.isFinite else { return nil }
        // Confirmed against the raw undetect=0 value in the archived RV/WMS control point.
        if abs(value - (-0.001)) < 1e-8 { return 0 }
        // Values above this deliberately conservative physical bound include scaled uint32 NoData.
        guard value >= 0, value <= 100 else { return nil }
        return value
    }
}
