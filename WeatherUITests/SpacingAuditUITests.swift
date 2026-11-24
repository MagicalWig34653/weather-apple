import XCTest

/// Spacing measurement (card D5875BAA, "Abstandsprobleme" after Build 56): screens at several Dynamic Type sizes, light and dark.
/// Every scene writes a screenshot and a JSON dump of the accessibility tree (frames in points, parent index) next to it, so the
/// distances, overlaps, hit areas and clipped elements are MEASURED offline (`tools/spacing_check.py`), not judged by eye.
///
/// Environment (pass with `TEST_RUNNER_` prefix): `SPACING_OUT` (directory, default `/private/tmp/claude-501/spacing-shots`),
/// `SPACING_SIZES` (comma separated: `XS,L,XXL,XXXL,AXM,AXXXL`, default `L,AXXXL`), `SPACING_APPEARANCE` (`light`|`dark`).
@MainActor
final class SpacingAuditUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Setup

    private static let categories: [String: String] = [
        "XS": "UICTContentSizeCategoryXS", "L": "UICTContentSizeCategoryL", "XXL": "UICTContentSizeCategoryXXL",
        "XXXL": "UICTContentSizeCategoryXXXL", "AXM": "UICTContentSizeCategoryAccessibilityM",
        "AXL": "UICTContentSizeCategoryAccessibilityL", "AXXXL": "UICTContentSizeCategoryAccessibilityXXXL"]

    private var env: [String: String] { ProcessInfo.processInfo.environment }
    private var outDir: String { env["SPACING_OUT"] ?? "/private/tmp/claude-501/spacing-shots" }
    private var dark: Bool { env["SPACING_APPEARANCE"] == "dark" }
    private var sizes: [String] { (env["SPACING_SIZES"] ?? "L,AXXXL").split(separator: ",").map(String.init) }

    private func launch(size: String, extra: [String]) -> XCUIApplication {
        let args = ["-UIPreferredContentSizeCategoryName", Self.categories[size] ?? Self.categories["L"]!] + extra
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(dark ? .dark : .light, extra: args))
        app.launch()
        return app
    }

    private func waitForRadar(_ app: XCUIApplication) {
        _ = app.buttons["radar-legend-toggle"].waitForExistence(timeout: 30)
        _ = app.sliders.firstMatch.waitForExistence(timeout: 30)
        sleep(3)
    }

    private func name(_ scene: String, _ size: String) -> String { "\(scene)-\(size.lowercased())-\(dark ? "dark" : "light")" }

    /// Screenshot plus the accessibility tree: type, identifier, label, frame, parent index.
    private func measure(_ app: XCUIApplication, _ name: String) {
        try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)
        let url = URL(fileURLWithPath: outDir)
        let screenshot = app.screenshot()
        try? screenshot.pngRepresentation.write(to: url.appendingPathComponent("\(name).png"))
        guard let snapshot = try? app.snapshot() else { return }
        var rows: [[String: Any]] = []
        func walk(_ node: XCUIElementSnapshot, parent: Int) {
            let index = rows.count
            rows.append(["i": index, "p": parent, "t": node.elementType.rawValue, "id": node.identifier, "label": node.label,
                         "value": (node.value as? String) ?? "", "enabled": node.isEnabled,
                         "x": node.frame.minX, "y": node.frame.minY, "w": node.frame.width, "h": node.frame.height])
            for child in node.children { walk(child, parent: index) }
        }
        walk(snapshot, parent: -1)
        let root: [String: Any] = ["name": name, "screen": ["w": app.frame.width, "h": app.frame.height], "elements": rows]
        if let data = try? JSONSerialization.data(withJSONObject: root) { try? data.write(to: url.appendingPathComponent("\(name).json")) }
        print("SPACING_SHOT \(name) elements=\(rows.count)")
    }

    // MARK: Scenes

    /// Map with the forecast card in its normal state and the controls column.
    func testSceneRadar() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestWarnings", "fixture"])
            waitForRadar(app)
            measure(app, name("radar", size))
            if app.buttons["radar-legend-toggle"].exists {
                app.buttons["radar-legend-toggle"].tap(); sleep(2)
                measure(app, name("radar-legende", size))
            }
            app.terminate()
        }
    }

    /// Forecast card states: server behind (warning), update failed, refreshing.
    func testSceneForecastStates() {
        for size in sizes {
            for (tag, mode) in [("behind", "behind"), ("failed", "failed"), ("refreshing", "delayed")] {
                let app = launch(size: size, extra: ["-UITestForecast", mode, "-UITestRadar", "fixture", "-UITestResetForecast"])
                waitForRadar(app)
                if mode == "failed" { sleep(10) }
                measure(app, name("prognose-\(tag)", size))
                app.terminate()
            }
        }
    }

    /// Hint stack: gap note and the "map reaches back only N hours" note (Temperature, choice 72 h, 61 h delivered), at the oldest slot.
    func testSceneHintStack() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestLayers", "all", "-UITestHistoryHours", "72", "-radarPastHours", "72"])
            let menu = app.buttons["radar-layer-menu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 30))
            sleep(2)
            menu.tap()
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(1)
            if let entry = openLayerEntry(app, group: nil, entry: "Temperatur") { entry.tap() } else { XCTFail("Temperatur not offered at \(size)") }
            sleep(3)
            measure(app, name("hinweise-jetzt", size))
            let slider = app.sliders.firstMatch
            if slider.waitForExistence(timeout: 20) {
                let width = Double(slider.frame.width)
                slider.coordinate(withNormalizedOffset: CGVector(dx: 20 / width, dy: 0.5)).press(forDuration: 0.05)
                sleep(3)
                measure(app, name("hinweise-aeltester", size))
            }
            app.terminate()
        }
    }

    /// Layer menu open.
    func testSceneLayerMenu() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestLayers", "all"])
            let menu = app.buttons["radar-layer-menu"]
            XCTAssertTrue(menu.waitForExistence(timeout: 30))
            sleep(3)
            menu.tap(); sleep(2)
            measure(app, name("ebenenmenue", size))
            app.terminate()
        }
    }

    /// Places sheet.
    func testScenePlaces() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture"])
            waitForRadar(app)
            let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
            if place.waitForExistence(timeout: 10) {
                place.tap(); sleep(2)
                measure(app, name("orte", size))
            } else { XCTFail("place button missing at \(size)") }
            app.terminate()
        }
    }

    /// Information sheet, and its sub page (maximum past).
    func testSceneInfo() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestWarnCapabilities", "push", "-UITestWarnings", "fixture"])
            waitForRadar(app)
            let info = app.buttons["Datenquellen und Datenschutz"]
            guard info.waitForExistence(timeout: 10) else { XCTFail("info button missing at \(size)"); continue }
            info.tap(); sleep(2)
            measure(app, name("info", size))
            let past = app.buttons["Maximale Vergangenheit"]
            if past.exists { past.tap(); sleep(2); measure(app, name("info-vergangenheit", size)) }
            app.terminate()
        }
    }

    /// Warnings sheet with fixture warnings (card E6FF22E4 covers the sheet header; recorded here for the measurement).
    func testSceneWarnings() {
        for size in sizes {
            let app = launch(size: size, extra: ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestWarnings", "fixture"])
            waitForRadar(app)
            let button = app.buttons["radar-warnings-button"]
            guard button.waitForExistence(timeout: 20) else { XCTFail("warnings button missing at \(size)"); continue }
            button.tap(); sleep(3)
            measure(app, name("warnungen", size))
            app.terminate()
        }
    }
}
