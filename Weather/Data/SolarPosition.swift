import Foundation

/// Sonnenstand nach der NOAA-/Meeus-Näherung (NOAA Solar Calculator, Meeus "Astronomical Algorithms").
/// Rein rechnerisch, ohne UI, ohne Zeitzonenbezug: alle Zeiten sind absolute `Date`-Werte (UTC-Basis).
/// Genauigkeit gegen JPL Horizons: unter 0,5 Grad (siehe `SolarPositionTests`). Winkel in Grad.
/// Höhen sind geometrisch (ohne Refraktion), außer `refraction(forElevation:)` wird ausdrücklich addiert.
enum SolarPosition {
    /// Höhe der Sonnenmitte für Auf-/Untergang: 0,833 Grad (Sonnenradius 0,267 + Refraktion 0,566).
    static let sunriseElevation = -0.833

    struct Horizontal: Equatable {
        /// Azimut in Grad, von Norden im Uhrzeigersinn (0 = N, 90 = O), 0..<360.
        var azimuth: Double
        /// Geometrische Höhe über dem Horizont in Grad.
        var elevation: Double
    }

    enum Phase: Int, Comparable, CaseIterable {
        case night, astronomicalTwilight, nauticalTwilight, civilTwilight, day
        static func < (l: Phase, r: Phase) -> Bool { l.rawValue < r.rawValue }

        init(elevation: Double) {
            if elevation >= SolarPosition.sunriseElevation { self = .day }
            else if elevation >= -6 { self = .civilTwilight }
            else if elevation >= -12 { self = .nauticalTwilight }
            else if elevation >= -18 { self = .astronomicalTwilight }
            else { self = .night }
        }
    }

    struct Crossing: Equatable {
        var date: Date
        var isRising: Bool
    }

    /// Zeitabhängige Größen, einmal je Zeitpunkt berechnet (Rasterabfragen nutzen sie für alle Punkte).
    struct Parameters {
        /// Deklination in Grad.
        var declination: Double
        /// Zeitgleichung in Minuten.
        var equationOfTime: Double
        /// Geografische Länge des Subsolarpunkts in Grad (-180...180, Ost positiv).
        var subsolarLongitude: Double

        init(date: Date) {
            let jd = date.timeIntervalSince1970 / 86400 + 2440587.5
            let t = (jd - 2451545.0) / 36525.0
            let l0 = (280.46646 + t * (36000.76983 + t * 0.0003032)).truncatingRemainder(dividingBy: 360)
            let m = 357.52911 + t * (35999.05029 - 0.0001537 * t)
            let e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
            let mr = m.radians
            let c = sin(mr) * (1.914602 - t * (0.004817 + 0.000014 * t))
                + sin(2 * mr) * (0.019993 - 0.000101 * t)
                + sin(3 * mr) * 0.000289
            let omega = 125.04 - 1934.136 * t
            let lambda = (l0 + c) - 0.00569 - 0.00478 * sin(omega.radians)
            let eps0 = 23 + (26 + (21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60) / 60
            let eps = eps0 + 0.00256 * cos(omega.radians)
            declination = asin(sin(eps.radians) * sin(lambda.radians)).degrees
            let y = pow(tan(eps.radians / 2), 2)
            let l0r = l0.radians
            let eot = y * sin(2 * l0r) - 2 * e * sin(mr) + 4 * e * y * sin(mr) * cos(2 * l0r)
                - 0.5 * y * y * sin(4 * l0r) - 1.25 * e * e * sin(2 * mr)
            equationOfTime = 4 * eot.degrees
            // Minuten seit 00:00 UTC des (UTC-)Tages.
            let secondsOfDay = date.timeIntervalSince1970.truncatingRemainder(dividingBy: 86400)
            let utcMinutes = (secondsOfDay < 0 ? secondsOfDay + 86400 : secondsOfDay) / 60
            let lon = -((utcMinutes + equationOfTime) / 4 - 180)
            subsolarLongitude = SolarPosition.normalizeLongitude(lon)
        }
    }

    // MARK: Einzelpunkt

    static func position(at date: Date, latitude: Double, longitude: Double) -> Horizontal {
        position(parameters: Parameters(date: date), latitude: latitude, longitude: longitude)
    }

    static func position(parameters p: Parameters, latitude: Double, longitude: Double) -> Horizontal {
        let phi = latitude.radians
        let delta = p.declination.radians
        let h = (longitude - p.subsolarLongitude).radians
        let sinElev = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)
        let elevation = asin(min(1, max(-1, sinElev))).degrees
        let az = atan2(sin(h), cos(h) * sin(phi) - tan(delta) * cos(phi)).degrees + 180
        return Horizontal(azimuth: az.truncatingRemainder(dividingBy: 360), elevation: elevation)
    }

    static func elevation(at date: Date, latitude: Double, longitude: Double) -> Double {
        position(at: date, latitude: latitude, longitude: longitude).elevation
    }

    static func phase(at date: Date, latitude: Double, longitude: Double) -> Phase {
        Phase(elevation: elevation(at: date, latitude: latitude, longitude: longitude))
    }

    /// Atmosphärische Refraktion in Grad für eine geometrische Höhe (Sæmundsson, 1010 hPa, 10 Grad C).
    /// Optional zu `elevation` zu addieren; unterhalb von -1 Grad 0.
    static func refraction(forElevation h: Double) -> Double {
        guard h > -1 else { return 0 }
        return 1.02 / tan((h + 10.3 / (h + 5.11)).radians) / 60
    }

    // MARK: Raster

    /// Höhe der Sonne für ein regelmäßiges Gitter (Zeilen von `north` nach `south`, Spalten von `west` nach `east`,
    /// Punktmitten, zeilenweise). Zeit-Parameter einmal berechnet; je Spalte/Zeile nur trigonometrische Vorarbeit.
    /// `rows`/`columns` >= 1. Über die Datumsgrenze: `east` darf kleiner als `west` sein (z. B. 170 bis -170).
    static func elevationGrid(
        at date: Date,
        north: Double, south: Double, west: Double, east: Double,
        rows: Int, columns: Int
    ) -> [Double] {
        precondition(rows >= 1 && columns >= 1)
        let p = Parameters(date: date)
        let sinD = sin(p.declination.radians), cosD = cos(p.declination.radians)
        var span = east - west
        if span < 0 { span += 360 }
        var cosH = [Double](repeating: 0, count: columns)
        for c in 0..<columns {
            let lon = west + span * (Double(c) + 0.5) / Double(columns)
            cosH[c] = cos((lon - p.subsolarLongitude).radians)
        }
        var out = [Double](repeating: 0, count: rows * columns)
        for r in 0..<rows {
            let lat = north + (south - north) * (Double(r) + 0.5) / Double(rows)
            let a = sin(lat.radians) * sinD
            let b = cos(lat.radians) * cosD
            for c in 0..<columns {
                out[r * columns + c] = asin(min(1, max(-1, a + b * cosH[c]))).degrees
            }
        }
        return out
    }

    /// Dämmerungsklassen für ein Gitter (siehe `elevationGrid`), z. B. für Terminator/Nachtschattierung.
    static func phaseGrid(
        at date: Date,
        north: Double, south: Double, west: Double, east: Double,
        rows: Int, columns: Int
    ) -> [Phase] {
        elevationGrid(at: date, north: north, south: south, west: west, east: east, rows: rows, columns: columns)
            .map(Phase.init(elevation:))
    }

    // MARK: Auf-/Untergang

    /// Alle Durchgänge der Sonnenmitte durch `elevation` (Standard: Auf-/Untergang) im Intervall `[start, end]`,
    /// aufsteigend. Leer bei Polartag/-nacht. Suche im 10-Minuten-Raster mit Bisektion (Genauigkeit unter 1 s).
    /// Hinweis: Kulminationen, die den Schwellwert nur streifen (Dauer < 10 min), können übersehen werden.
    static func crossings(
        from start: Date, to end: Date,
        latitude: Double, longitude: Double,
        elevation threshold: Double = sunriseElevation
    ) -> [Crossing] {
        guard end > start else { return [] }
        let step: TimeInterval = 600
        func f(_ d: Date) -> Double { elevation(at: d, latitude: latitude, longitude: longitude) - threshold }
        var result: [Crossing] = []
        var t0 = start
        var f0 = f(t0)
        while t0 < end {
            let t1 = min(t0.addingTimeInterval(step), end)
            let f1 = f(t1)
            if (f0 < 0) != (f1 < 0) {
                var lo = t0, hi = t1
                for _ in 0..<20 {
                    let mid = Date(timeIntervalSince1970: (lo.timeIntervalSince1970 + hi.timeIntervalSince1970) / 2)
                    if (f(mid) < 0) == (f0 < 0) { lo = mid } else { hi = mid }
                }
                result.append(Crossing(date: hi, isRising: f0 < 0))
            }
            t0 = t1
            f0 = f1
        }
        return result
    }

    /// Nächster Sonnenuntergang nach `date` innerhalb von 36 h (nil bei Polartag oder wenn die Sonne bereits unten steht
    /// und kein Untergang folgt).
    static func nextSunset(after date: Date, latitude: Double, longitude: Double) -> Date? {
        crossings(from: date, to: date.addingTimeInterval(36 * 3600), latitude: latitude, longitude: longitude)
            .first { !$0.isRising }?.date
    }

    /// Nächster Sonnenaufgang nach `date` innerhalb von 36 h.
    static func nextSunrise(after date: Date, latitude: Double, longitude: Double) -> Date? {
        crossings(from: date, to: date.addingTimeInterval(36 * 3600), latitude: latitude, longitude: longitude)
            .first { $0.isRising }?.date
    }

    /// Text "Sonne bis HH:mm" (Sonne oben) bzw. "Sonne ab HH:mm" (Sonne unten, Aufgang folgt) in `timeZone`.
    /// Polartag: "Sonne den ganzen Tag", Polarnacht: "Sonne geht nicht auf".
    static func sunLabel(at date: Date, latitude: Double, longitude: Double, timeZone: TimeZone) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = timeZone
        f.dateFormat = "HH:mm"
        let isUp = elevation(at: date, latitude: latitude, longitude: longitude) >= sunriseElevation
        if isUp {
            guard let set = nextSunset(after: date, latitude: latitude, longitude: longitude) else {
                return "Sonne den ganzen Tag"
            }
            return "Sonne bis \(f.string(from: set))"
        }
        guard let rise = nextSunrise(after: date, latitude: latitude, longitude: longitude) else {
            return "Sonne geht nicht auf"
        }
        return "Sonne ab \(f.string(from: rise))"
    }

    static func normalizeLongitude(_ lon: Double) -> Double {
        var v = (lon + 180).truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v - 180
    }
}

private extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
