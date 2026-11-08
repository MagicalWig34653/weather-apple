import ImageIO
import SwiftUI

/// Legend content per layer. Radar keeps its fixed colour scale (`RadarLegendPanel`); the others are
/// notes (pressure, clouds) or the legend image the manifest points to (lightning).
enum RadarLayerLegendText {
    static func hint(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Niederschlag in Millimeter pro Stunde."
        case .pressure, .pressureEU:
            "Linien gleichen Luftdrucks auf Meereshöhe (Isobaren) in Hektopascal, berechnet vom Wettermodell ICON des DWD, stündlich und mit Vorhersage\(layer == .pressureEU ? ", Ausschnitt Europa" : ""). Je enger die Linien beieinander liegen, desto stärker weht in der Regel der Wind."
        case .lightning:
            "Blitzdichte der letzten 15 Minuten (NowCastMIX des DWD). Je kräftiger die Farbe, desto mehr Blitze in dem Gebiet."
        case .clouds:
            "Satellitenbild von Meteosat: Wolken erscheinen weiß bis grau. Es gibt keine Farbskala, und das Bild zeigt Bewölkung, keinen Niederschlag."
        case .cloudmask, .cloudmaskVis:
            "Rückblick, keine Vorhersage: Wolkenmaske von Meteosat (Satellit, 25 bis 40 Minuten alt) kombiniert mit dem berechneten Sonnenstand. Die Maske kennt nur klar oder bewölkt, keine Wolkendicke: dünne Wolken zählen als bewölkt. Tagsüber verfeinert, wenn der Server ihn liefert, der sichtbare Kanal die Bewölkung weich; bei tiefem Sonnenstand und nachts gilt nur die Maske. Kein Schattenwurf, Nebel kann als klar erscheinen."
        case .temperature:
            NSLocalizedString("LAYER_TEMPERATURE_HINT", value: "Lufttemperatur 2 m über Grund in Grad Celsius, stündlich bis 48 Stunden voraus. Modellprognose des DWD, kein Messwert: im Gelände, in Tälern und Städten kann es deutlich abweichen.", comment: "Legend hint")
        case .dewpoint:
            NSLocalizedString("LAYER_DEWPOINT_HINT", value: "Taupunkt 2 m über Grund in Grad Celsius, stündlich bis 48 Stunden voraus. Je höher der Taupunkt, desto mehr Wasserdampf enthält die Luft. Modellprognose des DWD, kein Messwert.", comment: "Legend hint")
        case .humidity:
            NSLocalizedString("LAYER_HUMIDITY_HINT", value: "Relative Feuchte 2 m über Grund in Prozent, stündlich bis 48 Stunden voraus. Sie schwankt stark mit der Tageszeit. Modellprognose des DWD, kein Messwert.", comment: "Legend hint")
        }
    }

    /// Extra note when the manifest names a source or scale this app version cannot show as a legend.
    /// Fail closed: the overlay stays, but no raster is guessed.
    static func sourceNote(for layer: RadarLayer, manifest: RadarLayerManifest?) -> String? {
        guard layer.isAirField, let manifest else { return nil }
        if manifest.nativeScale != nil { return nil }
        switch (manifest.source, manifest.scale) {
        case ("wms", nil), (nil, nil): return nil
        default:
            // A scale (or source) without a native table yet: only the notes, no legend raster.
            return NSLocalizedString("LAYER_SCALE_UNKNOWN", value: "Die Farbskala dieser Datenquelle ist in dieser App-Version noch nicht hinterlegt. Deshalb gibt es hier keine Legende, nur diesen Hinweis. Die Karte zeigt Modellwerte.", comment: "Legend note")
        }
    }

    /// Legend image loaded from the manifest: lightning, and WMS temperature (the DWD colours the image).
    static func usesLegendImage(for layer: RadarLayer, manifest: RadarLayerManifest?) -> Bool {
        switch layer {
        case .lightning: true
        case .temperature: manifest?.source == "wms" && manifest?.scale == nil
        default: false
        }
    }

    static func title(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Niederschlag in mm/h"
        case .pressure: "Luftdruck (Isobaren)"
        case .pressureEU: "Luftdruck Europa (Isobaren)"
        case .lightning: "Blitzdichte"
        case .clouds: "Wolken"
        case .cloudmask, .cloudmaskVis: "Sonne"
        case .temperature: NSLocalizedString("LAYER_TEMPERATURE_LEGEND_TITLE", value: "Temperatur 2 m (Modell)", comment: "Legend title")
        case .dewpoint: NSLocalizedString("LAYER_DEWPOINT_LEGEND_TITLE", value: "Taupunkt 2 m (Modell)", comment: "Legend title")
        case .humidity: NSLocalizedString("LAYER_HUMIDITY_LEGEND_TITLE", value: "Relative Feuchte 2 m (Modell)", comment: "Legend title")
        }
    }

    /// Hint for the legend toggle button.
    static func toggleHint(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Zeigt oder verbirgt die Farbskala in Millimeter pro Stunde"
        case .pressure, .pressureEU: "Zeigt oder verbirgt den Hinweis zu den Isobaren"
        case .lightning: "Zeigt oder verbirgt die Legende der Blitzdichte"
        case .clouds: "Zeigt oder verbirgt den Hinweis zum Satellitenbild"
        case .cloudmask, .cloudmaskVis: "Zeigt oder verbirgt die Legende der Sonnenebene"
        case .temperature, .dewpoint, .humidity:
            NSLocalizedString("LAYER_FIELD_TOGGLE_HINT", value: "Zeigt oder verbirgt die Legende und den Hinweis zum Modellwert", comment: "Legend toggle hint")
        }
    }
}

/// Classes of the sun layer legend. Only what the overlay really draws (`SunOverlay`) and the cloud mask supports:
/// no "heiter" class, because the mask has no cloud thickness.
enum SunLegend {
    static let entries: [MapLegendEntry] = [
        .init(id: "sunny", label: "Sonnig (Tag, klar)", spokenLabel: "Sonnig: Sonne über dem Horizont und laut Satellit klar",
              red: UInt8(SunOverlay.sunny.r), green: UInt8(SunOverlay.sunny.g), blue: UInt8(SunOverlay.sunny.b), opacity: SunOverlay.sunny.a + 0.2),
        .init(id: "cloudy", label: "Bewölkt (Tag)", spokenLabel: "Bewölkt: Sonne über dem Horizont, laut Satellit bedeckt",
              red: UInt8(SunOverlay.cloudy.r), green: UInt8(SunOverlay.cloudy.g), blue: UInt8(SunOverlay.cloudy.b), opacity: SunOverlay.cloudy.a + 0.3),
        .init(id: "civil", label: "Dämmerung", spokenLabel: "Dämmerung: Sonne bis 18 Grad unter dem Horizont, zunehmend dunkler",
              red: 8, green: 14, blue: 42, opacity: 0.3),
        .init(id: "night", label: "Nacht", spokenLabel: "Nacht: Sonne mehr als 18 Grad unter dem Horizont",
              red: 8, green: 14, blue: 42, opacity: 0.68),
        .init(id: "terminator", label: "Grenze Tag/Nacht", spokenLabel: "Dünne helle Linie: Grenze zwischen Tag und Nacht",
              red: 255, green: 236, blue: 190)
    ]
}

/// Loads a legend image the manifest points to. https and the known map hosts only, size-limited,
/// no cookies, memory only. Called when the user opens the legend.
enum RadarLegendImageLoader {
    static let maximumBytes = 300_000
    nonisolated(unsafe) private static let cache = NSCache<NSURL, CGImageBox>()
    private final class CGImageBox { let image: CGImage; init(_ image: CGImage) { self.image = image } }

    static func decode(_ data: Data, reference: RadarLayerLegendRef) -> CGImage? {
        guard !data.isEmpty, data.count <= maximumBytes,
              let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) == 1,
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
              (1...2000).contains(image.width), (1...2000).contains(image.height) else { return nil }
        return image
    }

    static func load(_ reference: RadarLayerLegendRef) async -> CGImage? {
        guard reference.url.scheme == "https", let host = reference.url.host,
              RadarLayerLegendRef.allowedHosts.contains(host) else { return nil }
        if let cached = cache.object(forKey: reference.url as NSURL) { return cached.image }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpCookieStorage = nil
        configuration.httpShouldSetCookies = false
        configuration.urlCredentialStorage = nil
        configuration.timeoutIntervalForRequest = 8
        configuration.timeoutIntervalForResource = 12
        var request = URLRequest(url: reference.url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpShouldHandleCookies = false
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let image = decode(data, reference: reference) else { return nil }
        cache.setObject(CGImageBox(image), forKey: reference.url as NSURL)
        return image
    }
}

/// Legend panel of an optional layer: loaded legend image (if the manifest has one), the explanatory note
/// and the layer's source line with the modification notice.
struct RadarLayerLegendPanel: View {
    let layer: RadarLayer
    let manifest: RadarLayerManifest?
    /// 2 m fields: dew point / relative humidity layers the server offers (switch only with both) and the action.
    var humidityChoices: [RadarLayer] = []
    var onSelectLayer: (RadarLayer) -> Void = { _ in }
    @AppStorage(ForestPreference.key) private var showForest = false
    @State private var image: CGImage?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Panel content. At the largest Dynamic Type sizes the long notes would make the glass panel taller than the
    /// GPU's texture limit (the app crashed in MapKit's renderer), so there it scrolls within a bounded height.
    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RadarLayerLegendText.title(for: layer)).font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                    if RadarLayerLegendText.usesLegendImage(for: layer, manifest: manifest), let image {
                        Image(decorative: image, scale: 1)
                            .resizable().scaledToFit()
                            .frame(maxWidth: 150, maxHeight: layer == .lightning ? 220 : 300)
                            .padding(4)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                    }
                    if humidityChoices.count > 1, humidityChoices.contains(layer) { humiditySwitch }
                    if layer.isAirField { forestSwitch }
                    if let scale = manifest?.nativeScale { scaleRows(scale) }
                    if layer == .cloudmask {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(SunLegend.entries) { entry in
                                HStack(spacing: 8) {
                                    RoundedRectangle(cornerRadius: 3).fill(entry.color)
                                        .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5) }
                                        .frame(width: 20, height: 12)
                                    Text(entry.label).font(.caption2)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(entry.spokenLabel)
                            }
                        }
                    }
                    Text(RadarLayerLegendText.hint(for: layer)).font(.caption2)
                    if let note = RadarLayerLegendText.sourceNote(for: layer, manifest: manifest) {
                        Text(note).font(.caption2)
                    }
                    if layer.isAirField, manifest?.nativeScale != nil {
                        Text(NSLocalizedString("TEMP_READOUT_HINT", value: "Antippen der Karte nennt den Modellwert an dieser Stelle. Die Abfrage läuft auf dem Gerät, ohne Netz und ohne Standort.", comment: "Readout hint"))
                            .font(.caption2)
                    }
                    if let manifest {
                        Text("\(manifest.attribution). \(manifest.modificationNotice).")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                    if ForestPreference.isShown(layer: layer, visible: showForest, info: ForestInfo.bundled), let info = ForestInfo.bundled {
                        Text(info.sourceLine).font(.caption2).foregroundStyle(.secondary)
                            .accessibilityIdentifier("forest-attribution")
                    }
            }
        }
    }

    /// Dew point / relative humidity: only the layers the server really offers.
    @ViewBuilder private var humiditySwitch: some View {
        let picker = Picker(NSLocalizedString("TEMP_HUMIDITY_SWITCH", value: "Feuchte", comment: "Switch label"),
                            selection: Binding(get: { layer }, set: { onSelectLayer($0) })) {
            ForEach(humidityChoices) { choice in
                Text(choice == .dewpoint ? NSLocalizedString("TEMP_SWITCH_DEWPOINT", value: "Taupunkt", comment: "Switch")
                                         : NSLocalizedString("TEMP_SWITCH_HUMIDITY", value: "Rel. Feuchte", comment: "Switch")).tag(choice)
            }
        }
        if dynamicTypeSize.isAccessibilitySize {
            picker.pickerStyle(.menu).accessibilityIdentifier("humidity-switch")
        } else {
            picker.pickerStyle(.segmented).accessibilityIdentifier("humidity-switch")
        }
    }

    /// Numerical scale: one row per label step (highest on top), swatches plus text, never colour alone.
    private func scaleRows(_ scale: TemperatureScale) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            ForEach(scale.legendRows.reversed()) { row in
                HStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ForEach(Array(row.bands.enumerated()), id: \.offset) { _, band in
                            Rectangle().fill(Color(.sRGB, red: Double(band.red) / 255, green: Double(band.green) / 255, blue: Double(band.blue) / 255))
                        }
                    }
                    .frame(width: 30, height: 12)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .overlay { RoundedRectangle(cornerRadius: 3).strokeBorder(.secondary.opacity(0.5), lineWidth: 0.5) }
                    Text(row.label).font(.caption2.monospacedDigit())
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(row.spokenLabel)
            }
            Text(scale.unit == "%" ? "%" : "°C").font(.caption2.weight(.semibold)).accessibilityHidden(true)
        }
        .accessibilityIdentifier("temperature-scale")
    }

    private var forestSwitch: some View {
        VStack(alignment: .leading, spacing: 2) {
            Toggle(NSLocalizedString("FOREST_TOGGLE", value: "Wald", comment: "Forest switch"), isOn: $showForest)
                .font(.caption.weight(.semibold))
                .accessibilityIdentifier("forest-toggle")
            Text(NSLocalizedString("FOREST_CAPTION", value: "Waldfläche zur Orientierung, ohne Einfluss auf die Werte", comment: "Forest caption"))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize || layer.isAirField {
                ScrollView { content }.scrollBounceBehavior(.basedOnSize)
                    .frame(maxHeight: dynamicTypeSize.isAccessibilitySize ? 360 : 300)
            } else {
                content
            }
        }
        .padding(10)
        .frame(width: dynamicTypeSize.isAccessibilitySize ? 260 : (layer == .cloudmask ? 220 : 190), alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Legende \(layer.title)")
        .accessibilityIdentifier("radar-legend")
        .task(id: manifest?.legend?.url) {
            guard RadarLayerLegendText.usesLegendImage(for: layer, manifest: manifest), let reference = manifest?.legend else { image = nil; return }
            image = await RadarLegendImageLoader.load(reference)
        }
    }
}
