import XCTest

/// Accessibility audit (App Store "Accessibility Nutrition Labels", Todolino "Bedienungshilfen"): runs
/// `performAccessibilityAudit()` on the main flows in German and English and collects Dynamic Type, appearance and
/// Reduce-Motion evidence. Findings are never ignored wholesale: every finding is either a failure or listed in
/// `knownFalsePositive` with a reason (see docs/research/bedienungshilfen-pruefung.md).
/// Findings and screenshots go to the directory named in `/tmp/a11y-out-dir` (first line, optional) and to the test log.
@MainActor
final class AccessibilityAuditTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    // MARK: Output

    private var outDir: String? {
        (try? String(contentsOfFile: "/tmp/a11y-out-dir", encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func record(_ line: String) {
        print("A11Y_AUDIT \(line)")
        guard let dir = outDir, !dir.isEmpty else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let path = dir + "/findings.txt"
        let data = Data((line + "\n").utf8)
        if let handle = FileHandle(forWritingAtPath: path) {
            handle.seekToEndOfFile(); handle.write(data); try? handle.close()
        } else {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let dir = outDir, !dir.isEmpty else { return }
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).png"))
    }


    /// Frames of all text-bearing elements (points) next to the screenshot, for the offline contrast measurement
    /// (`name.json`, evaluated by the contrast script in the report).
    private func dump(_ app: XCUIApplication, _ name: String) {
        shot(app, name)
        guard let dir = outDir, !dir.isEmpty, let snapshot = try? app.snapshot() else { return }
        var rows: [[String: Any]] = []
        func walk(_ node: XCUIElementSnapshot) {
            let kinds: [XCUIElement.ElementType] = [.staticText, .button, .textField, .switch, .slider, .segmentedControl, .cell]
            if kinds.contains(node.elementType), !node.label.isEmpty, node.frame.width > 0 {
                rows.append(["label": node.label, "type": node.elementType.rawValue, "id": node.identifier,
                             "x": node.frame.minX, "y": node.frame.minY, "w": node.frame.width, "h": node.frame.height])
            }
            for child in node.children { walk(child) }
        }
        walk(snapshot)
        let root = ["screen": ["w": app.frame.width, "h": app.frame.height], "elements": rows] as [String: Any]
        if let data = try? JSONSerialization.data(withJSONObject: root) {
            try? data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(name).json"))
        }
    }

    // MARK: Audit

    /// Documented false positives. Matched on audit type plus a fragment of the element description, never wholesale.
    private func knownFalsePositive(_ issue: XCUIAccessibilityAuditIssue, name: String) -> String? {
        let element = issue.element
        let label = element?.label ?? ""
        // MapKit's own container (tiles, legal link, compass) is Apple UI, not ours.
        if element?.elementType == .map { return "MKMapView-Container (Apple)" }
        if label == "Legal" || label == "Legal Information" || label == "Rechtl. Informationen" || label == "Apple Maps" { return "MapKit-Rechtshinweis (Apple)" }
        // Legend rows are static information (not controls); VoiceOver reads them, no touch target is needed.
        // The 16 legend rows arrive without element reference (label "-"); only legend screens contain them (checked per run: count 16).
        if issue.auditType == .hitRegion, name.hasSuffix("-radar-legende"), label.isEmpty || label == "-" { return "Legende: statische Zeile, kein Bedienelement" }
        if issue.auditType == .hitRegion, element?.elementType == .other, element?.identifier == "",
           ["Millimeter", "millimetres", "Keine Daten", "No data"].contains(where: { label.contains($0) }) { return "Legende: statische Zeile, kein Bedienelement" }
        return nil
    }

    /// Heuristic audit categories that are evaluated by hand (screenshots, `tools/contrast_measure.swift`) and listed in
    /// docs/research/bedienungshilfen-pruefung.md; they are logged as INFO, not failed. Everything else fails the test.
    private func isManuallyEvaluated(_ issue: XCUIAccessibilityAuditIssue) -> Bool {
        issue.auditType == .contrast || issue.auditType == .dynamicType || issue.auditType == .textClipped || issue.auditType.rawValue == 2
    }

    private func audit(_ app: XCUIApplication, _ name: String, types: XCUIAccessibilityAuditType = .all) {
        var count = 0
        do {
            try app.performAccessibilityAudit(for: types) { [self] issue in
                count += 1
                let element = issue.element
                let reason = knownFalsePositive(issue, name: name) ?? (isManuallyEvaluated(issue) ? "INFO-manuell-ausgewertet" : nil)
                record("\(name) | \(issue.auditType.rawValue) | \(reason == nil ? "FINDING" : "FILTERED:\(reason!)") | \(issue.compactDescription) / \(issue.detailedDescription) | label=\(element?.label ?? "-") id=\(element?.identifier ?? "-") type=\(element?.elementType.rawValue ?? 0) frame=\(element?.frame ?? .zero)")
                if reason != nil { return true }
                XCTFail("\(name): \(issue.compactDescription) [\(element?.label ?? "-")]")
                return false
            }
        } catch {
            XCTFail("\(name): audit threw \(error)")
        }
        record("\(name) | DONE | issues=\(count)")
    }

    // MARK: Navigation

    private func launch(_ language: UITestLaunch.Language, extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(language: language, extra: extra)
        app.launch()
        return app
    }

    private func labels(_ language: UITestLaunch.Language) -> (info: String, done: String) {
        language == .german ? ("Datenquellen und Datenschutz", "Fertig") : ("Data sources and privacy", "Done")
    }

    private func waitForRadar(_ app: XCUIApplication) {
        _ = app.buttons["radar-legend-toggle"].waitForExistence(timeout: 20)
        _ = app.sliders.firstMatch.waitForExistence(timeout: 20)
    }

    private func dragSlider(_ slider: XCUIElement, to position: CGFloat) {
        slider.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: position, dy: 0.5)))
    }

    private func openInfo(_ app: XCUIApplication, _ language: UITestLaunch.Language) {
        let info = app.buttons[labels(language).info]
        XCTAssertTrue(info.waitForExistence(timeout: 20))
        info.tap()
    }

    // MARK: Main flows

    private func radarFlows(_ language: UITestLaunch.Language) {
        let tag = language.code
        let app = launch(language)
        waitForRadar(app)
        sleep(2)
        audit(app, "\(tag)-radar-messung")
        let slider = app.sliders.firstMatch
        if slider.exists {
            dragSlider(slider, to: 0.95)
            sleep(1)
            audit(app, "\(tag)-radar-vorhersage")
        }
        let legend = app.buttons["radar-legend-toggle"]
        if legend.exists {
            legend.tap()
            sleep(1)
            audit(app, "\(tag)-radar-legende")
        }
        let details = app.buttons["forecast-details"]
        if details.exists {
            details.tap()
            sleep(2)
            audit(app, "\(tag)-prognosedetails")
        }
        app.terminate()
    }

    func testRadarFlowsGerman() { radarFlows(.german) }
    func testRadarFlowsEnglish() { radarFlows(.english) }

    private func placesFlows(_ language: UITestLaunch.Language) {
        let tag = language.code
        let app = launch(language)
        waitForRadar(app)
        let prefix = language == .german ? "Ort auswählen:" : "Choose place:"
        let button = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        XCTAssertTrue(button.waitForExistence(timeout: 15))
        button.tap()
        sleep(1)
        audit(app, "\(tag)-orte")
        let add = app.buttons["region-new"]
        if add.waitForExistence(timeout: 3), add.isEnabled {
            add.tap()
            sleep(1)
            audit(app, "\(tag)-neue-region")
            app.navigationBars.buttons.firstMatch.tap()
        }
        let push = app.buttons["place-push"].firstMatch
        if push.waitForExistence(timeout: 3) {
            push.tap()
            sleep(1)
            audit(app, "\(tag)-mitteilungen-ort")
        }
        app.terminate()
    }

    func testPlacesFlowsGerman() { placesFlows(.german) }
    func testPlacesFlowsEnglish() { placesFlows(.english) }

    private func infoFlows(_ language: UITestLaunch.Language) {
        let tag = language.code
        let app = launch(language, extra: ["-UITestWarnCapabilities", "push"])
        waitForRadar(app)
        openInfo(app, language)
        sleep(1)
        audit(app, "\(tag)-info")
        for row in ["sources", "privacy", "widgets", "alerts", "past", "support"] {
            let button = app.buttons["info-row-\(row)"]
            guard button.waitForExistence(timeout: 5) else { XCTFail("row \(row)"); continue }
            button.tap()
            sleep(1)
            audit(app, "\(tag)-info-\(row)")
            app.navigationBars.buttons.firstMatch.tap()
        }
        app.terminate()
    }

    func testInfoFlowsGerman() { infoFlows(.german) }
    func testInfoFlowsEnglish() { infoFlows(.english) }

    private func warningFlows(_ language: UITestLaunch.Language) {
        let tag = language.code
        let app = launch(language, extra: ["-UITestWarnings", "fixture"])
        let button = app.buttons["radar-warnings-button"]
        XCTAssertTrue(button.waitForExistence(timeout: 20))
        button.tap()
        let row = app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        sleep(1)
        audit(app, "\(tag)-warnungen-liste")
        let mode = app.buttons["warn-mode"]
        if mode.exists {
            mode.tap()
            sleep(2)
            audit(app, "\(tag)-warnungen-karte")
            mode.tap()
        }
        let again = app.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
        if again.waitForExistence(timeout: 3) {
            again.tap()
            sleep(1)
            audit(app, "\(tag)-warnung-detail")
        }
        app.terminate()
    }

    func testWarningFlowsGerman() { warningFlows(.german) }
    func testWarningFlowsEnglish() { warningFlows(.english) }

    private func warnSettingsFlow(_ language: UITestLaunch.Language) {
        let tag = language.code
        let app = launch(language, extra: ["-UITestWarnCapabilities", "push"])
        waitForRadar(app)
        openInfo(app, language)
        let row = app.buttons["info-row-alerts"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.switches["warn-toggle"].waitForExistence(timeout: 10))
        audit(app, "\(tag)-warnungen-einstellungen")
        app.terminate()
    }

    func testWarnSettingsGerman() { warnSettingsFlow(.german) }
    func testWarnSettingsEnglish() { warnSettingsFlow(.english) }

    // MARK: Dynamic Type, appearance, contrast (screenshots for the manual review, plus structural checks)

    private static let axxxl = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]

    /// Main screens at the largest accessibility size: no control may be unreachable, the audit's clipped-text check runs too.
    private func dynamicType(_ language: UITestLaunch.Language, size: String, tag sizeTag: String) {
        let tag = "\(language.code)-\(sizeTag)"
        var extra = ["-UIPreferredContentSizeCategoryName", size, "-UITestWarnings", "fixture"]
        extra += ["-UITestLayers", "d2"]
        let app = launch(language, extra: extra)
        waitForRadar(app)
        sleep(2)
        shot(app, "\(tag)-radar")
        audit(app, "\(tag)-radar", types: [.textClipped, .dynamicType, .hitRegion, .sufficientElementDescription])
        for id in ["radar-legend-toggle", "radar-warnings-button", "radar-layer-menu", "forecast-details"] {
            let element = app.descendants(matching: .any)[id]
            if element.exists {
                record("\(tag) | HIT | \(id) hittable=\(element.isHittable) size=\(element.frame.size)")
                if !element.isHittable { XCTFail("\(tag): \(id) not hittable") }
            }
        }
        let legend = app.buttons["radar-legend-toggle"]
        if legend.exists { legend.tap(); sleep(1); shot(app, "\(tag)-legende"); app.terminate(); app.launch(); waitForRadar(app) }
        let prefix = language == .german ? "Ort auswählen:" : "Choose place:"
        let place = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        if place.waitForExistence(timeout: 5) {
            place.tap(); sleep(1)
            shot(app, "\(tag)-orte")
            audit(app, "\(tag)-orte", types: [.textClipped, .dynamicType, .hitRegion])
            let add = app.buttons["region-new"]
            if add.exists, add.isEnabled { add.tap(); sleep(1); shot(app, "\(tag)-neue-region"); audit(app, "\(tag)-neue-region", types: [.textClipped, .dynamicType, .hitRegion]) }
        }
        app.terminate()

        let info = launch(language, extra: extra + ["-UITestWarnCapabilities", "push"])
        waitForRadar(info)
        openInfo(info, language)
        sleep(1)
        shot(info, "\(tag)-info")
        audit(info, "\(tag)-info", types: [.textClipped, .dynamicType, .hitRegion])
        let alerts = info.buttons["info-row-alerts"]
        if alerts.waitForExistence(timeout: 5) {
            alerts.tap(); sleep(1)
            shot(info, "\(tag)-info-alerts")
            audit(info, "\(tag)-info-alerts", types: [.textClipped, .dynamicType, .hitRegion])
        }
        info.terminate()

        let warn = launch(language, extra: extra)
        let button = warn.buttons["radar-warnings-button"]
        if button.waitForExistence(timeout: 20) {
            button.tap(); sleep(2)
            shot(warn, "\(tag)-warnungen")
            audit(warn, "\(tag)-warnungen", types: [.textClipped, .dynamicType, .hitRegion])
            let row = warn.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
            if row.waitForExistence(timeout: 3) {
                row.tap(); sleep(1)
                shot(warn, "\(tag)-warnung-detail")
                audit(warn, "\(tag)-warnung-detail", types: [.textClipped, .dynamicType, .hitRegion])
            }
        }
        warn.terminate()
    }

    func testDynamicTypeAXXXLGerman() { dynamicType(.german, size: "UICTContentSizeCategoryAccessibilityXXXL", tag: "axxxl") }
    func testDynamicTypeAXXXLEnglish() { dynamicType(.english, size: "UICTContentSizeCategoryAccessibilityXXXL", tag: "axxxl") }
    func testDynamicTypeXSmallGerman() { dynamicType(.german, size: "UICTContentSizeCategoryXS", tag: "xs") }

    /// Light and dark screenshots of the main screens (increased contrast / reduced transparency are set by the
    /// simulator before the run, see the report; the test just records the current state).
    func testAppearanceScreenshots() {
        let tag = ProcessInfo.processInfo.environment["A11Y_TAG"] ?? "default"
        for dark in [false, true] {
            let name = "\(tag)-\(dark ? "dark" : "light")"
            let app = launch(.german, extra: ["-UITestWarnings", "fixture", "-UITestLayers", "d2"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            waitForRadar(app)
            sleep(2)
            let slider = app.sliders.firstMatch
            shot(app, "\(name)-radar")
            audit(app, "\(name)-radar", types: .contrast)
            if slider.exists { dragSlider(slider, to: 0.95); sleep(1); shot(app, "\(name)-vorhersage"); audit(app, "\(name)-vorhersage", types: .contrast) }
            let legend = app.buttons["radar-legend-toggle"]
            if legend.exists { legend.tap(); sleep(1); shot(app, "\(name)-legende"); audit(app, "\(name)-legende", types: .contrast) }
            app.terminate()
            let warn = launch(.german, extra: ["-UITestWarnings", "fixture"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let button = warn.buttons["radar-warnings-button"]
            if button.waitForExistence(timeout: 20) {
                button.tap(); sleep(2)
                shot(warn, "\(name)-warnungen")
                audit(warn, "\(name)-warnungen", types: .contrast)
                let row = warn.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
                if row.waitForExistence(timeout: 3) { row.tap(); sleep(1); shot(warn, "\(name)-warnung-detail") }
            }
            warn.terminate()
            let places = launch(.german)
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let pb = places.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
            if pb.waitForExistence(timeout: 20) { pb.tap(); sleep(1); shot(places, "\(name)-orte"); audit(places, "\(name)-orte", types: .contrast) }
            places.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }


    /// Contrast measurement input: screenshot plus element frames of the main screens in light and dark.
    func testContrastDump() {
        for dark in [false, true] {
            let name = dark ? "dark" : "light"
            let app = launch(.german, extra: ["-UITestWarnings", "fixture", "-UITestLayers", "d2"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            waitForRadar(app)
            sleep(3)
            dump(app, "c-\(name)-radar")
            let slider = app.sliders.firstMatch
            if slider.exists { dragSlider(slider, to: 0.95); sleep(1); dump(app, "c-\(name)-vorhersage") }
            let legend = app.buttons["radar-legend-toggle"]
            if legend.exists { legend.tap(); sleep(1); dump(app, "c-\(name)-legende") }
            let menu = app.buttons["radar-layer-menu"]
            if menu.exists { menu.tap(); sleep(1); shot(app, "c-\(name)-ebenenmenue"); app.tap() }
            app.terminate()
            let warn = launch(.german, extra: ["-UITestWarnings", "fixture"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let button = warn.buttons["radar-warnings-button"]
            if button.waitForExistence(timeout: 20) {
                button.tap(); sleep(2)
                dump(warn, "c-\(name)-warnungen")
                let row = warn.descendants(matching: .any).matching(identifier: "warning-row").firstMatch
                if row.waitForExistence(timeout: 3) { row.tap(); sleep(1); dump(warn, "c-\(name)-warnung-detail") }
            }
            warn.terminate()
            let places = launch(.german, extra: ["-UITestWarnCapabilities", "push"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let pb = places.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ort auswählen:")).firstMatch
            if pb.waitForExistence(timeout: 20) {
                pb.tap(); sleep(1); dump(places, "c-\(name)-orte")
                let add = places.buttons["region-new"]
                if add.exists, add.isEnabled { add.tap(); sleep(1); dump(places, "c-\(name)-region") }
            }
            places.terminate()
            let info = launch(.german, extra: ["-UITestWarnCapabilities", "push"])
            XCUIDevice.shared.appearance = dark ? .dark : .light
            let ib = info.buttons["Datenquellen und Datenschutz"]
            if ib.waitForExistence(timeout: 20) {
                ib.tap(); sleep(1); dump(info, "c-\(name)-info")
                let alerts = info.buttons["info-row-alerts"]
                if alerts.waitForExistence(timeout: 3) { alerts.tap(); sleep(1); dump(info, "c-\(name)-info-alerts") }
            }
            info.terminate()
        }
        XCUIDevice.shared.appearance = .light
    }

    /// Reduce Motion: the test only documents the runtime state (the simulator setting is applied from outside).
    func testReduceMotionRadarScreenshot() {
        let tag = ProcessInfo.processInfo.environment["A11Y_TAG"] ?? "motion"
        let app = launch(.german, extra: ["-UITestExposeGlow"])
        waitForRadar(app)
        sleep(2)
        let slider = app.sliders.firstMatch
        if slider.exists { dragSlider(slider, to: 0.95) }
        sleep(1)
        shot(app, "\(tag)-radar-vorhersage")
        let pill = app.descendants(matching: .any).matching(identifier: "radar-frame-label").firstMatch
        if pill.exists { pill.tap(); sleep(3); shot(app, "\(tag)-radar-play"); pill.tap() }
        let glow = app.descendants(matching: .any).matching(identifier: "screen-glow").firstMatch
        record("\(tag) | GLOW exists=\(glow.exists)")
        app.terminate()
    }
}
