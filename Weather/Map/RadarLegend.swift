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
    static let precipitationRadar = MapLegend(
        title: "Niederschlag", unit: "mm/h",
        entries: [
            .init(id: "none", label: "Keine Daten", spokenLabel: "Keine Daten", red: 0x7D, green: 0x7D, blue: 0x7D, opacity: 0.3),
            .rain("0.1", "0,1 – 0,2", "0,1 bis unter 0,2", 0x33FFFF),
            .rain("0.2", "0,2 – 0,4", "0,2 bis unter 0,4", 0x1ACC9A),
            .rain("0.4", "0,4 – 1", "0,4 bis unter 1", 0x019934),
            .rain("1", "1 – 2", "1 bis unter 2", 0x4DB31B),
            .rain("2", "2 – 3", "2 bis unter 3", 0x99CC01),
            .rain("3", "3 – 5", "3 bis unter 5", 0xCCE601),
            .rain("5", "5 – 7,5", "5 bis unter 7,5", 0xFFFF01),
            .rain("7.5", "7,5 – 10", "7,5 bis unter 10", 0xFFC401),
            .rain("10", "10 – 15", "10 bis unter 15", 0xFF8901),
            .rain("15", "15 – 30", "15 bis unter 30", 0xFF4501),
            .rain("30", "30 – 45", "30 bis unter 45", 0xFE0000),
            .rain("45", "45 – 75", "45 bis unter 75", 0xE5004C),
            .rain("75", "75 – 100", "75 bis unter 100", 0xCC0098),
            .rain("100", "100 – 150", "100 bis unter 150", 0x6600CB),
            .rain("150", "ab 150", "ab 150", 0x0000FE)
        ])
}

private extension MapLegendEntry {
    static func rain(_ id: String, _ label: String, _ spoken: String, _ rgb: UInt32) -> MapLegendEntry {
        MapLegendEntry(id: id, label: label, spokenLabel: spoken + " Millimeter pro Stunde",
                       red: UInt8(rgb >> 16 & 0xFF), green: UInt8(rgb >> 8 & 0xFF), blue: UInt8(rgb & 0xFF))
    }
}

/// Collapsible legend panel; the toggle button lives next to the other map controls.
struct RadarLegendPanel: View {
    let legend: MapLegend

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(legend.title) in \(legend.unit)").font(.caption.weight(.semibold))
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
        .accessibilityLabel("Legende Regenradar")
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
