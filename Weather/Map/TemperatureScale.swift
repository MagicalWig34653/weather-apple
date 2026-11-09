import Foundation

/// Colour scale of a server-coloured 2 m field (temperature, dew point, relative humidity). The table comes from
/// the backend contract `scales-v1.json` (bundled copy); the server paints the lossless image with exactly these
/// band colours, so the legend, the local value readout and VoiceOver all use the same table.
/// Unknown ids give `nil`: no raster is guessed (fail closed).
struct TemperatureScale: Equatable, Sendable {
    struct Band: Equatable, Sendable {
        let from: Double
        let red: UInt8, green: UInt8, blue: UInt8
    }

    let id: String
    let unit: String
    let min: Double
    let max: Double
    let step: Double
    let labelEvery: Double
    let bands: [Band]

    /// Scale ids this app version knows, with the layer each one belongs to.
    static let layerForID: [String: RadarLayer] = ["t2m-d2-v1": .temperature, "td-d2-v1": .dewpoint, "rh-d2-v1": .humidity]

    /// The bundled table (`nil` entries are dropped: a damaged scale is simply unknown).
    static let bundled: [String: TemperatureScale] = {
        guard let url = Bundle.main.url(forResource: "scales-v1", withExtension: "json"),
              let data = try? Data(contentsOf: url), let scales = try? parse(data) else { return [:] }
        return Dictionary(uniqueKeysWithValues: scales.map { ($0.id, $0) })
    }()

    /// Scale for a manifest, only when the id is known, the table is intact and it belongs to this layer.
    static func scale(for id: String?, layer: RadarLayer) -> TemperatureScale? {
        guard let id, layerForID[id] == layer else { return nil }
        return bundled[id]
    }

    // MARK: Parsing and validation

    private struct Raw: Decodable {
        struct RawBand: Decodable { let from: Double; let hex: String }
        struct RawScale: Decodable {
            let id: String, unit: String
            let min: Double, max: Double, step: Double, labelEvery: Double
            let bands: [RawBand]
        }
        let schema: Int
        let scales: [RawScale]
    }

    /// Schema 1 only. Every scale must be gap-free (bands start at `min`, advance by `step`, none beyond `max`),
    /// colours valid hex, ids unique; otherwise the whole file is rejected.
    static func parse(_ data: Data) throws -> [TemperatureScale] {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        guard data.count <= 200_000, let raw = try? decoder.decode(Raw.self, from: data), raw.schema == 1,
              !raw.scales.isEmpty else { throw RadarBackendError.invalid }
        var seen = Set<String>()
        return try raw.scales.map { item in
            guard seen.insert(item.id).inserted, item.step > 0, item.min < item.max, item.labelEvery >= item.step,
                  (item.labelEvery / item.step).rounded() == item.labelEvery / item.step,
                  !item.bands.isEmpty, item.bands.count <= 200,
                  abs(Double(item.bands.count) * item.step - (item.max - item.min)) < 1e-9 else { throw RadarBackendError.invalid }
            var bands: [Band] = []
            for (index, band) in item.bands.enumerated() {
                guard abs(band.from - (item.min + Double(index) * item.step)) < 1e-9, let rgb = rgb(hex: band.hex) else {
                    throw RadarBackendError.invalid
                }
                bands.append(Band(from: band.from, red: rgb.0, green: rgb.1, blue: rgb.2))
            }
            return TemperatureScale(id: item.id, unit: item.unit, min: item.min, max: item.max, step: item.step,
                                    labelEvery: item.labelEvery, bands: bands)
        }
    }

    private static func rgb(hex: String) -> (UInt8, UInt8, UInt8)? {
        guard hex.count == 7, hex.hasPrefix("#"), let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        return (UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    // MARK: Lookup

    /// Index of the band a value belongs to; values below `min` / above `max` belong to the first / last band.
    func bandIndex(forValue value: Double) -> Int {
        guard value.isFinite else { return 0 }
        return Swift.min(bands.count - 1, Swift.max(0, Int(((value - min) / step).rounded(.down))))
    }

    /// Band with exactly this colour; a colour at most `tolerance` per channel away counts if it is unambiguous.
    func bandIndex(red: UInt8, green: UInt8, blue: UInt8, tolerance: Int = 1) -> Int? {
        func distance(_ band: Band) -> Int {
            Swift.max(abs(Int(band.red) - Int(red)), abs(Int(band.green) - Int(green)), abs(Int(band.blue) - Int(blue)))
        }
        let near = bands.indices.filter { distance(bands[$0]) <= tolerance }
        if near.count == 1 { return near[0] }
        if let exact = near.first(where: { distance(bands[$0]) == 0 }) { return exact }
        return nil
    }

    // MARK: Text

    /// Locale number (decimal separator from `locale`), typographic minus U+2212. No language special cases.
    static func number(_ value: Double, locale: Locale = .current) -> String {
        LocaleFormat.decimal(value, maxFractionDigits: 2, useTypographicMinus: true, locale: locale)
    }

    private var isPercent: Bool { unit == "%" }
    private var shortUnit: String { isPercent ? "%" : "°C" }
    private var spokenUnit: String {
        isPercent ? NSLocalizedString("TEMP_UNIT_PERCENT_SPOKEN", value: "Prozent", comment: "Spoken unit")
                  : NSLocalizedString("TEMP_UNIT_CELSIUS_SPOKEN", value: "Grad Celsius", comment: "Spoken unit")
    }

    /// Lower and upper edge of a band; the first band is open downwards, the last upwards.
    private func edges(_ index: Int) -> (lower: Double?, upper: Double?) {
        (index == 0 ? nil : bands[index].from, index == bands.count - 1 ? nil : bands[index].from + step)
    }

    /// Text of one band, e.g. "7 bis 8 °C", "unter −29 °C", "ab 39 °C".
    func rangeText(_ index: Int, spoken: Bool = false) -> String {
        let unit = spoken ? spokenUnit : shortUnit
        let sep = spoken ? " " : (isPercent ? "" : " ")
        let (lower, upper) = edges(index)
        switch (lower, upper) {
        case (nil, let upper?): return String(format: NSLocalizedString("TEMP_RANGE_BELOW", value: "unter %@%@%@", comment: "Band below"), Self.number(upper), sep, unit)
        case (let lower?, nil): return String(format: NSLocalizedString("TEMP_RANGE_FROM", value: "ab %@%@%@", comment: "Band from"), Self.number(lower), sep, unit)
        case (let lower?, let upper?):
            return String(format: NSLocalizedString("TEMP_RANGE_BETWEEN", value: "%@ bis %@%@%@", comment: "Band range"), Self.number(lower), Self.number(upper), sep, unit)
        default: return ""
        }
    }

    /// Value readout, always flagged as model value.
    func readoutText(bandIndex index: Int, spoken: Bool) -> String {
        let format = spoken
            ? NSLocalizedString("TEMP_READOUT_SPOKEN", value: "Etwa %@, Modellwert", comment: "VoiceOver readout")
            : NSLocalizedString("TEMP_READOUT", value: "Etwa %@ (Modell)", comment: "Readout")
        return String(format: format, rangeText(index, spoken: spoken))
    }

    /// Legend rows: one per `labelEvery` step, bands grouped (swatches), spoken text per row.
    var legendRows: [LegendRow] {
        let size = Swift.max(1, Int((labelEvery / step).rounded()))
        return stride(from: 0, to: bands.count, by: size).map { start in
            let end = Swift.min(bands.count, start + size)
            let lower: Double? = start == 0 ? nil : bands[start].from
            let upper: Double? = end == bands.count ? nil : bands[end].from
            let label: String, spoken: String
            switch (lower, upper) {
            case (nil, let upper?):
                label = String(format: NSLocalizedString("TEMP_ROW_BELOW", value: "unter %@", comment: "Legend row"), Self.number(upper))
                spoken = String(format: NSLocalizedString("TEMP_ROW_BELOW_SPOKEN", value: "unter %@ %@", comment: "Legend row spoken"), Self.number(upper), spokenUnit)
            case (let lower?, nil):
                label = String(format: NSLocalizedString("TEMP_ROW_FROM", value: "ab %@", comment: "Legend row"), Self.number(lower))
                spoken = String(format: NSLocalizedString("TEMP_ROW_FROM_SPOKEN", value: "ab %@ %@", comment: "Legend row spoken"), Self.number(lower), spokenUnit)
            case (let lower?, let upper?):
                label = String(format: NSLocalizedString("TEMP_ROW_BETWEEN", value: "%@ bis %@", comment: "Legend row"), Self.number(lower), Self.number(upper))
                spoken = String(format: NSLocalizedString("TEMP_ROW_BETWEEN_SPOKEN", value: "%@ bis unter %@ %@", comment: "Legend row spoken"), Self.number(lower), Self.number(upper), spokenUnit)
            default: label = ""; spoken = ""
            }
            return LegendRow(id: "\(id)-\(start)", label: label, spokenLabel: spoken, bands: Array(bands[start..<end]))
        }
    }

    struct LegendRow: Equatable, Identifiable {
        let id: String
        let label: String
        let spokenLabel: String
        let bands: [Band]
    }
}

extension RadarLayerManifest {
    /// Native colour scale of this manifest: only for ICON-D2 images the server coloured itself, only when the id
    /// is known and belongs to this layer. `nil` = fail closed (legend image or note only, no value readout).
    var nativeScale: TemperatureScale? { source == "icon_d2" ? TemperatureScale.scale(for: scale, layer: layer) : nil }
}
