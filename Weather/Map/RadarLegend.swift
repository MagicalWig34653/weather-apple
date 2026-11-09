import SwiftUI

/// One class of a map legend. Colour is fixed because it must match the pixels of the map layer.
struct MapLegendEntry: Equatable, Identifiable {
    let id: String
    /// Short visible label, e.g. "0,1 – 0,2".
    let label: String
    /// German VoiceOver text.
    let spokenLabel: String
    let red: UInt8, green: UInt8, blue: UInt8
    var opacity: Double = 1

    var color: Color { Color(.sRGB, red: Double(red) / 255, green: Double(green) / 255, blue: Double(blue) / 255, opacity: opacity) }
    var hex: String { String(format: "#%02X%02X%02X", red, green, blue) }
}

struct MapLegend: Equatable {
    let title: String
    let unit: String
    let entries: [MapLegendEntry]
}

extension MapLegend {
    /// DWD `dwd:Niederschlagsradar` default style. Source: WMS GetLegendGraphic (format application/json)
    /// of https://maps.dwd.de/geoserver/dwd/wms, rule "Niederschlag in mm/h", checked 31 Oct 2026.
    /// Order: weakest to strongest; the first entry is the "no data" class of the style.
    static var precipitationRadar: MapLegend { precipitationRadar(locale: .current) }

    /// Bands (lower bound, upper bound or `nil` for open end) with the DWD colours; numbers follow `locale`.
    static func precipitationRadar(locale: Locale) -> MapLegend {
        let bands: [(id: String, lower: Double, upper: Double?, rgb: UInt32)] = [
            ("0.1", 0.1, 0.2, 0x33FFFF), ("0.2", 0.2, 0.4, 0x1ACC9A), ("0.4", 0.4, 1, 0x019934),
            ("1", 1, 2, 0x4DB31B), ("2", 2, 3, 0x99CC01), ("3", 3, 5, 0xCCE601),
            ("5", 5, 7.5, 0xFFFF01), ("7.5", 7.5, 10, 0xFFC401), ("10", 10, 15, 0xFF8901),
            ("15", 15, 30, 0xFF4501), ("30", 30, 45, 0xFE0000), ("45", 45, 75, 0xE5004C),
            ("75", 75, 100, 0xCC0098), ("100", 100, 150, 0x6600CB), ("150", 150, nil, 0x0000FE)
        ]
        let noData = NSLocalizedString("LEGEND_NO_DATA", value: "Keine Daten", comment: "Radar legend")
        let noDataSpoken = NSLocalizedString("LEGEND_NO_DATA_SPOKEN", value: "Keine Daten", comment: "Radar legend spoken")
        let entries = [MapLegendEntry(id: "none", label: noData, spokenLabel: noDataSpoken,
                                      red: 0x7D, green: 0x7D, blue: 0x7D, opacity: 0.3)]
            + bands.map { band in
                func number(_ value: Double) -> String { LocaleFormat.decimal(value, maxFractionDigits: 1, locale: locale) }
                let label: String, spoken: String
                if let upper = band.upper {
                    label = number(band.lower) + " \u{2013} " + number(upper)
                    spoken = String(format: NSLocalizedString("LEGEND_RAIN_SPOKEN_RANGE", value: "%1$@ bis unter %2$@ Millimeter pro Stunde", comment: "Radar legend spoken"),
                                    number(band.lower), number(upper))
                } else {
                    label = String(format: NSLocalizedString("LEGEND_RAIN_FROM", value: "ab %@", comment: "Radar legend"), number(band.lower))
                    spoken = String(format: NSLocalizedString("LEGEND_RAIN_SPOKEN_FROM", value: "ab %@ Millimeter pro Stunde", comment: "Radar legend spoken"), number(band.lower))
                }
                return MapLegendEntry(id: band.id, label: label, spokenLabel: spoken,
                                      red: UInt8(band.rgb >> 16 & 0xFF), green: UInt8(band.rgb >> 8 & 0xFF), blue: UInt8(band.rgb & 0xFF))
            }
        return MapLegend(title: NSLocalizedString("LEGEND_RAIN_TITLE", value: "Niederschlag", comment: "Radar legend title"),
                         unit: "mm/h", entries: entries)
    }
}

struct RadarLegendPanel: View {
    let legend: MapLegend

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(String(format: NSLocalizedString("LEGEND_TITLE_IN_UNIT", value: "%1$@ in %2$@", comment: "Legend title with unit"), legend.title, legend.unit)).font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .vertical) {
                rows
                ScrollView { rows }.scrollBounceBehavior(.basedOnSize)
            }
        }
        .padding(10)
        .fixedSize(horizontal: true, vertical: false)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: NSLocalizedString("RADAR_LEGEND_LABEL", value: "Legende %@", comment: "Legend"),
                                   NSLocalizedString("LAYER_RADAR_TITLE", value: "Regenradar", comment: "Layer name")))
        .accessibilityIdentifier("radar-legend")
    }

    private var rows: some View {
        VStack(alignment: .leading, spacing: 3) {
            // Strongest rain on top, like a vertical scale.
            ForEach(legend.entries.reversed()) { entry in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 3).fill(entry.color)
                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5) }
                        .frame(width: 20, height: 12)
                    Text(entry.label).font(.caption2.monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(entry.spokenLabel)
            }
        }
    }
}
