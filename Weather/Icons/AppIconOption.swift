import Foundation

/// A selectable app icon. `alternateIconName` is the name of the `.icon` package in
/// `Weather/Resources/Icon/Alternates` (without extension) and must be listed in
/// `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (project.yml); `nil` is the primary icon `AppIcon`.
struct AppIconOption: Identifiable, Hashable, Sendable {
    let id: String
    let alternateIconName: String?
    let nameDE: String
    let nameEN: String
    let detailDE: String
    let detailEN: String

    /// Name of the preview image in `IconPreviews.xcassets`.
    var previewAssetName: String { "Preview" + id }

    func name(languageCode: String? = Locale.current.language.languageCode?.identifier) -> String {
        languageCode == "de" ? nameDE : nameEN
    }

    func detail(languageCode: String? = Locale.current.language.languageCode?.identifier) -> String {
        languageCode == "de" ? detailDE : detailEN
    }

    static let standard = AppIconOption(
        id: "Standard", alternateIconName: nil,
        nameDE: "Nachtradar", nameEN: "Night radar",
        detailDE: "Standard · Eigenentwurf mit Dark-Variante", detailEN: "Default · own design with dark variant")

    static let all: [AppIconOption] = [
        standard,
        .alt("Karte", "Karte", "Map", "Früheres Symbol (Build 15)", "Earlier icon (build 15)"),
        .alt("Eigenentwurf", "Eigenentwurf", "Own design", "Mit hellem Dark-Modus", "With light dark mode"),
        .alt("V2A", "Scheiben", "Discs", "Konzentrische Kreise", "Concentric circles"),
        .alt("V2B", "Wolke", "Cloud", "Wolke mit gelbem Tropfen", "Cloud with yellow drop"),
        .alt("V2C", "Tropfen", "Drop", "Tropfen im Ring", "Drop in a ring"),
        .alt("V3A", "Zeitring", "Time ring", "Ring mit Radar-Sektor", "Ring with radar sector"),
        .alt("V3B", "Regenstriche", "Rain streaks", "Drei schräge Kapseln", "Three slanted capsules"),
        .alt("V3C", "Sonne und Zelle", "Sun and cell", "Zwei überlappende Kreise", "Two overlapping circles"),
        .alt("V3D", "Schirm", "Umbrella", "Gelber Schirm", "Yellow umbrella"),
        .alt("V4A", "Schirm 2", "Umbrella 2", "Gewölbter Schirm mit Tropfen", "Domed umbrella with drops"),
        .alt("V4B", "Radar und Wolke", "Radar and cloud", "Radarscope mit Regenecho", "Radar scope with rain echo"),
        .alt("V4BEigen", "Radar und Wolke (eigene Fassung)", "Radar and cloud (own version)", "Große Wolke, grüner Radarausschnitt", "Large cloud, green radar sector"),
        .alt("V4BS90", "Radar und Wolke, Sektor 90°", "Radar and cloud, 90° sector", "Radarausschnitt von 12 bis 3 Uhr", "Radar sector from 12 to 3 o'clock"),
        .alt("V4BS90V", "Radar und Wolke, Sektor 90° mit Verlauf", "Radar and cloud, 90° sector with gradient", "Viertelkreis mit Blau-Grün-Übergang", "Quarter circle with blue-green transition"),
        .alt("V4C", "Regenwolke", "Rain cloud", "Zwei Wolken, drei Tropfen", "Two clouds, three drops"),
        .alt("V4D", "Tropfen-Pin", "Drop pin", "Tropfen mit Ortsloch", "Drop with location hole"),
        .alt("V5A", "Schirm bereit", "Umbrella ready", "Bernsteinfarbene Schirmhaube", "Amber umbrella canopy"),
        .alt("V5B", "Regenfront", "Rain front", "Drei Glasflächen auf Nachtblau", "Three glass shapes on night blue"),
        .alt("V5C", "Schauer", "Shower", "Drei Regenbahnen auf Violett", "Three rain streaks on violet"),
    ]

    private static func alt(_ key: String, _ de: String, _ en: String, _ detailDE: String, _ detailEN: String) -> AppIconOption {
        AppIconOption(id: key, alternateIconName: "Alt" + key, nameDE: de, nameEN: en, detailDE: detailDE, detailEN: detailEN)
    }

    /// Option for the name reported by `UIApplication.alternateIconName`; unknown names fall back to the primary icon.
    static func option(forAlternateIconName name: String?) -> AppIconOption {
        all.first { $0.alternateIconName == name } ?? standard
    }
}
