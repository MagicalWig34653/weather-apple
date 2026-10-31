import ImageIO
import SwiftUI

/// Legend content per layer. Radar keeps its fixed colour scale (`RadarLegendPanel`); the others are
/// notes (pressure, clouds) or the legend image the manifest points to (lightning).
enum RadarLayerLegendText {
    static func hint(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Niederschlag in Millimeter pro Stunde."
        case .pressure:
            "Linien gleichen Luftdrucks auf Meereshöhe (Isobaren) in Hektopascal, berechnet vom Wettermodell ICON des DWD, stündlich und mit Vorhersage. Je enger die Linien beieinander liegen, desto stärker weht in der Regel der Wind."
        case .lightning:
            "Blitzdichte der letzten 15 Minuten (NowCastMIX des DWD). Je kräftiger die Farbe, desto mehr Blitze in dem Gebiet."
        case .clouds:
            "Satellitenbild von Meteosat: Wolken erscheinen weiß bis grau. Es gibt keine Farbskala, und das Bild zeigt Bewölkung, keinen Niederschlag."
        case .cloudmask:
            "Wolkenmaske von Meteosat."
        }
    }

    static func title(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Niederschlag in mm/h"
        case .pressure: "Luftdruck (Isobaren)"
        case .lightning: "Blitzdichte"
        case .clouds: "Wolken"
        case .cloudmask: "Wolkenmaske"
        }
    }

    /// Hint for the legend toggle button.
    static func toggleHint(for layer: RadarLayer) -> String {
        switch layer {
        case .radar: "Zeigt oder verbirgt die Farbskala in Millimeter pro Stunde"
        case .pressure: "Zeigt oder verbirgt den Hinweis zu den Isobaren"
        case .lightning: "Zeigt oder verbirgt die Legende der Blitzdichte"
        case .clouds, .cloudmask: "Zeigt oder verbirgt den Hinweis zum Satellitenbild"
        }
    }
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
    @State private var image: CGImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(RadarLayerLegendText.title(for: layer)).font(.caption.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: 6) {
                    if layer == .lightning, let image {
                        Image(decorative: image, scale: 1)
                            .resizable().scaledToFit()
                            .frame(maxWidth: 150, maxHeight: 220)
                            .padding(4)
                            .background(.white, in: RoundedRectangle(cornerRadius: 6))
                            .accessibilityHidden(true)
                    }
                    Text(RadarLayerLegendText.hint(for: layer)).font(.caption2)
                    if let manifest {
                        Text("\(manifest.attribution). \(manifest.modificationNotice).")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
            }
        }
        .padding(10)
        .frame(width: 190, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Legende \(layer.title)")
        .accessibilityIdentifier("radar-legend")
        .task(id: manifest?.legend?.url) {
            guard layer == .lightning, let reference = manifest?.legend else { image = nil; return }
            image = await RadarLegendImageLoader.load(reference)
        }
    }
}
