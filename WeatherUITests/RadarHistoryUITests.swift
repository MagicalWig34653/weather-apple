import XCTest

/// 48/72 hours of past on the time slider: oldest slot reachable with its own day and time, holes named and marked,
/// way back to "now". Debug stubs only (no network): `-UITestRadarHistoryHours 72` (radar Deutschland, `history.json` like the
/// backend of PR #4) and `-UITestLayers all -UITestHistoryHours 72` (layers with `history` block and `past_slots`).
/// Appearance comes from outside (`xcrun simctl ui <udid> appearance light|dark` plus `TEST_RUNNER_SHOT_SUFFIX`), screenshots go to
/// `/private/tmp/claude-501/hist-shots` for the visual check.
@MainActor
final class RadarHistoryUITests: XCTestCase {
    private var suffix: String {
        ProcessInfo.processInfo.environment["SHOT_SUFFIX"] ?? (XCUIDevice.shared.appearance == .dark ? "dark" : "light")
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    /// Layers whose DATA image colours (almost) the whole map with light colours (measured in `LayerImageLuminanceTests`: coverage 1.0,
    /// mean colour luminance 0.62 to 0.78, opacity 0.80 to 0.85): over a dark map the screen stays far above 0.45 although the
    /// appearance IS dark (measured 0.47 to 0.65). For them the 0.45 limit is not applied to the whole screen but to the SURFACE (map and
    /// app chrome without a data layer, check "OBERFLAECHE" in `brightnessShot`), and the screen gets the regression bound
    /// `brightDataLimit`. Decision to confirm; 0.45 itself is unchanged for the surface and for every other layer.
    private static let brightDataPrefixes = ["wolken", "temperatur", "taupunkt", "feuchte"]
    private static let brightDataLimit = 0.70
    private static func isBrightData(_ name: String) -> Bool { brightDataPrefixes.contains { name.lowercased().contains($0) } }

    private func shot(_ app: XCUIApplication, _ name: String, enforceDark: Bool = true) {
        sleep(1)
        let dir = "/private/tmp/claude-501/hist-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA hist-\(name)-\(suffix)=\(luminance)")
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("hist-\(name)-\(suffix).png"))
        if suffix == "dark", enforceDark {
            let limit = Self.isBrightData(name) ? Self.brightDataLimit : 0.45
            XCTAssertLessThan(luminance, limit, "dark screenshot expected, luminance \(luminance) (limit \(limit))")
        }
    }

    /// `hours`: what the stubbed `history.json` delivers; `setting`: the chosen "Maximale Vergangenheit" (default: the same).
    /// `fresh`: no stored choice at all (a fresh install): neither the launch argument nor a value from an earlier launch.
    private func launchRadar(hours: Int, setting: Int? = nil, fresh: Bool = false, extra: [String] = []) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestRadarHistoryHours", "\(hours)"]
            + (fresh ? ["-UITestResetPastChoice"] : ["-radarPastHours", "\(setting ?? hours)"]) + extra))
        app.launch()
        return app
    }

    /// `setting`: the user's "Maximale Vergangenheit" (shared by every layer); `server`: what the stubbed backend delivers
    /// (`-UITestHistoryHours`). Time is frozen (now 08:50 UTC = 09:50 Berlin on Wednesday 18 Nov 2026).
    private func launchLayers(setting: Int?, server: Int = 72, keepStored: Bool = false) -> XCUIApplication {
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-UITestForecast", "current", "-UITestLayers", "all", "-UITestHistoryHours", "\(server)"]
            + (setting.map { ["-radarPastHours", "\($0)"] } ?? (keepStored ? [] : ["-UITestResetPastChoice"]))))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(2)
        menu.tap()   // the stubbed layers are reported after the first probe
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        return app
    }

    private func slider(_ app: XCUIApplication) -> XCUIElement {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 40), "time slider")
        return slider
    }

    private func value(_ slider: XCUIElement) -> String { (slider.value as? String) ?? "" }

    /// Waits until the slider value satisfies `predicate` (the map and labels follow with a short delay).
    private func waitValue(_ slider: XCUIElement, _ predicate: (String) -> Bool, timeout: TimeInterval = 15) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if predicate(value(slider)) { return true }
            usleep(300_000)
        }
        return predicate(value(slider))
    }


    /// The slider is an accessibility representation over a custom drag control, so `adjust(toNormalizedSliderPosition:)` does not
    /// work. A touch on the track jumps there (like a normal slider): `fraction` 0 = oldest slot, 1 = newest (clamped at the ends).
    private func jump(_ slider: XCUIElement, fraction: Double) {
        let width = Double(slider.frame.width)
        let x = min(max((20 + fraction * (width - 40)) / width, 0.004), 0.996)
        slider.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0.5)).press(forDuration: 0.05)
        usleep(500_000)
    }

    /// Touches around `fraction` in steps of a fraction of a slot until `found` is true (a hole sits between two single slots).
    @discardableResult
    private func seek(_ slider: XCUIElement, near fraction: Double, slots: Int, found: () -> Bool) -> Bool {
        let step = 0.4 / Double(max(slots - 1, 1))
        for k in 0..<24 {
            let offset = Double((k + 1) / 2) * step * (k % 2 == 0 ? 1 : -1)
            // A touch within 22 pt of the thumb keeps the current slot (grab radius): go to the far end first, then to the target.
            slider.coordinate(withNormalizedOffset: CGVector(dx: fraction < 0.5 ? 0.99 : 0.01, dy: 0.5)).press(forDuration: 0.05)
            jump(slider, fraction: fraction + offset)
            if found() { return true }
        }
        return false
    }

    /// Entry of the nested "Regen" submenu (exact group label: "Regen am ausgewählten Ort" is another button).
    private func chooseRain(_ app: XCUIApplication, _ prefix: String) throws {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", "Regen")).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
            if rain.waitForExistence(timeout: 3) { rain.tap() }
            if entry.waitForExistence(timeout: 3), entry.isEnabled {
                entry.tap()
                if entry.waitForNonExistence(timeout: 3) { sleep(2); return }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(2)
        }
        XCTFail("\(prefix) ließ sich nicht wählen")
    }

    private func gapNote(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "radar-gap-note").firstMatch }

    private func gapLegend(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "radar-gap-legend").firstMatch }

    // MARK: Radar Deutschland, 72 hours

    func testRadarSeventyTwoHoursOldestSlotHoleAndWayBack() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasSuffix("Messung") || $0.contains("Messung") }, "starts at now: \(value(slider))")
        let nowValue = value(slider)
        XCTAssertFalse(gapNote(app).exists, "no hole next to now")
        shot(app, "radar72-1-jetzt")
        // The timeline carries a red mark for the hole far back: with no note next to now, a legend says what it is.
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "legend for the red mark at now")
        XCTAssertTrue(gapLegend(app).label.contains("Roter Strich"), "legend text: \(gapLegend(app).label)")

        // Oldest slot: reference 2026-11-18 08:40 UTC minus 72 h = Sunday 15 Nov, 09:40 in Berlin.
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("So. 15. Nov., 09:40, Messung") }, "oldest slot: \(value(slider))")
        XCTAssertFalse(gapNote(app).exists, "the source reaches back the full 72 h: no note at the oldest slot")
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "legend at the oldest slot (no hole next to it)")
        shot(app, "radar72-2-aeltester-slot")

        // The hole of 6 times: slot before (index 424) or after (index 425) it names it. 882 slots in total (845 + 37).
        // 72 h: history 845 slots (hole 6 + 1 missing) + 37 latest = 876 positions; the 6-hole lies in the middle of history.
        XCTAssertTrue(seek(slider, near: 0.48, slots: 876) { value(slider).contains("fehlen Daten") }, "a slot next to a hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "note next to the hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.contains("fehlen Daten"), "note text: \(gapNote(app).label)")
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "next to the hole the note replaces the legend")
        XCTAssertTrue(value(slider).contains("fehlen Daten"), "VoiceOver value names the hole: \(value(slider))")
        shot(app, "radar72-3-luecke")

        // Back to now: the pill's long press jumps there.
        app.buttons["radar-frame-label"].press(forDuration: 0.8)
        XCTAssertTrue(waitValue(slider) { $0 == nowValue }, "back at now: \(value(slider)) vs \(nowValue)")
        XCTAssertTrue(gapNote(app).waitForNonExistence(timeout: 10))
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "legend is back at now")
        shot(app, "radar72-4-zurueck")

        // While playing no notes stand above the map; the legend goes too and returns when playing stops.
        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "no legend while playing")
        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "legend after playing")
        app.terminate()
    }

    /// Frame origins of the round button column on the right (palette toggle, info). The hints that come and go with playing
    /// (legend, hole note) must never move it: it starts at the same y whether they stand above the map or not.
    private func columnOrigins(_ app: XCUIApplication) -> [CGPoint] {
        [app.buttons["radar-legend-toggle"], app.buttons["Datenquellen und Datenschutz"]].map { $0.frame.origin }
    }

    private func assertColumnStays(_ app: XCUIApplication, _ expected: [CGPoint], _ context: String) {
        let now = columnOrigins(app)
        print("COLUMN_Y \(suffix) \(context): toggle y=\(now[0].y) x=\(now[0].x), info y=\(now[1].y) x=\(now[1].x)")
        for (index, name) in ["toggle", "info"].enumerated() {
            XCTAssertEqual(now[index].y, expected[index].y, accuracy: 0.5, "\(context): \(name) moved vertically: \(now[index].y) vs \(expected[index].y)")
            XCTAssertEqual(now[index].x, expected[index].x, accuracy: 0.5, "\(context): \(name) moved horizontally: \(now[index].x) vs \(expected[index].x)")
        }
    }

    /// The button column stays where it is while the hints above the map come and go: legend at now (i), none while playing
    /// (ii), back after playing (iii), hole note next to the hole instead of the legend (iv), legend at now again (v).
    func testRadarButtonColumnStaysPutWhenTheHintsComeAndGo() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") }, "starts at now: \(value(slider))")
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "(i) legend at now")
        let reference = columnOrigins(app)
        print("COLUMN_Y \(suffix) i-now-with-legend: toggle y=\(reference[0].y) x=\(reference[0].x), info y=\(reference[1].y) x=\(reference[1].x)")
        shot(app, "strich2-1-vorher")

        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "(ii) no legend while playing")
        XCTAssertFalse(gapNote(app).exists)
        sleep(1)
        assertColumnStays(app, reference, "ii-playing")
        shot(app, "strich2-2-waehrend-abspielen")

        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "(iii) legend after playing")
        assertColumnStays(app, reference, "iii-after-playing")
        shot(app, "strich2-3-nachher")

        XCTAssertTrue(seek(slider, near: 0.48, slots: 876) { value(slider).contains("fehlen Daten") }, "(iv) a slot next to a hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "(iv) note next to the hole")
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "(iv) the note replaces the legend")
        sleep(1)
        assertColumnStays(app, reference, "iv-next-to-hole")
        shot(app, "strich2-4-an-der-luecke")

        app.buttons["radar-frame-label"].press(forDuration: 0.8)
        XCTAssertTrue(gapNote(app).waitForNonExistence(timeout: 10))
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "(v) legend at now again")
        assertColumnStays(app, reference, "v-now-again")
        app.terminate()
    }

    /// The legend goes away when it must: while playing, next to the hole (its note takes over) and when no hole is left in the
    /// chosen past (24 h: the hole lies 36 h back, so the timeline has no red mark and nothing needs explaining).
    func testRadarLegendDisappearsWhilePlayingNextToTheHoleAndWhenNoHoleIsLeft() throws {
        var app = launchRadar(hours: 72)
        var slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "legend at now (hole inside 72 h)")
        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "gone while playing")
        app.buttons["radar-frame-label"].tap()
        XCTAssertTrue(gapLegend(app).waitForExistence(timeout: 10), "back after playing")
        XCTAssertTrue(seek(slider, near: 0.48, slots: 876) { value(slider).contains("fehlen Daten") })
        XCTAssertTrue(gapLegend(app).waitForNonExistence(timeout: 10), "gone next to the hole")
        app.terminate()

        app = launchRadar(hours: 72, setting: 24)
        slider = self.slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") }, "24 h: starts at now: \(value(slider))")
        sleep(3)
        XCTAssertFalse(gapLegend(app).exists, "no hole inside 24 h: no legend at now")
        XCTAssertFalse(gapNote(app).exists)
        shot(app, "strich2-5-ohne-luecke")
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        XCTAssertFalse(gapLegend(app).exists, "no hole inside 24 h: no legend at the oldest slot")
        app.buttons["radar-frame-label"].tap()
        sleep(1)
        XCTAssertFalse(gapLegend(app).exists, "no legend while playing either")
        app.terminate()
    }

    func testRadarFortyEightHoursOfASeventyTwoHourHistoryStopsAtFortyEight() throws {
        let app = launchRadar(hours: 72, setting: 48)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        shot(app, "radar48-1-jetzt")
        jump(slider, fraction: 0)
        // Reference 2026-11-18 08:40 UTC minus 48 h = Monday 16 Nov, 09:40 in Berlin (72 h would be Sunday 15 Nov).
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("Mo. 16. Nov., 09:40, Messung") }, "oldest slot at 48 h: \(value(slider))")
        XCTAssertFalse(gapNote(app).exists, "the source reaches back the full 48 h: no note")
        shot(app, "radar48-2-aeltester-slot")
        jump(slider, fraction: 1)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") || $0.localizedCaseInsensitiveContains("vorhersage") })
        shot(app, "radar48-4-ende")
        app.terminate()
    }

    // MARK: Setting "Maximale Vergangenheit": 72 hours

    private func openInfoSheet(_ app: XCUIApplication) {
        let info = app.buttons["Datenquellen und Datenschutz"]
        XCTAssertTrue(info.waitForExistence(timeout: 30))
        info.tap()
    }

    /// The step 72 is offered; it is selectable when the server reports 72 hours (history.json) and greyed out when it reports 48.
    func testSeventyTwoHoursSelectableOnlyWhereTheServerDeliversThem() throws {
        for (serverHours, selectable) in [(72, true), (48, false)] {
            let app = launchRadar(hours: serverHours)
            XCTAssertTrue(waitValue(slider(app)) { $0.contains("Messung") })
            openInfoSheet(app)
            let entry = app.buttons["Maximale Vergangenheit"]
            XCTAssertTrue(entry.waitForExistence(timeout: 10), "entry Maximale Vergangenheit")
            entry.tap()
            let row = app.descendants(matching: .any).matching(identifier: "past-hours-72").firstMatch
            _ = row.waitForExistence(timeout: 5)
            if !row.exists { shot(app, "einstellung-fehlt-server\(serverHours)") }
            XCTAssertTrue(row.waitForExistence(timeout: 10), "72 h row exists: \(app.debugDescription.prefix(1500))")
            XCTAssertEqual(row.isEnabled, selectable, "server delivers \(serverHours) h: 72 selectable = \(selectable)")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "past-hours-48").firstMatch.isEnabled)
            shot(app, "einstellung-server\(serverHours)")
            app.terminate()
        }
    }

    // MARK: A source that reaches back less far

    func testRadarShorterSourceShowsTheOldestRealSlotAndNamesWhatIsMissing() throws {
        let app = launchRadar(hours: 72, extra: ["-UITestRadarOldest", "30"])
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "leading hole named at the oldest slot: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.hasPrefix("Davor fehlen Daten"), gapNote(app).label)
        // Oldest slot = reference minus 30 h = Tuesday 17 Nov, 03:40 in Berlin.
        XCTAssertTrue(value(slider).hasPrefix("Di. 17. Nov., 03:40, Messung"), value(slider))
        shot(app, "radar-quelle-kurz-aeltester-slot")
        app.terminate()
    }

    /// Same source (30 h) at 48 h chosen: the oldest slot is the same, the missing part before it starts at 48 h back.
    func testRadarShorterSourceAtFortyEightHoursNamesAnotherShortfall() throws {
        let app = launchRadar(hours: 72, setting: 48, extra: ["-UITestRadarOldest", "30"])
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "leading hole named: \(value(slider))")
        XCTAssertTrue(gapNote(app).label.hasPrefix("Davor fehlen Daten: Mo"), "from Monday 09:40 (48 h back): \(gapNote(app).label)")
        XCTAssertTrue(value(slider).hasPrefix("Di. 17. Nov., 03:40, Messung"), value(slider))
        print("HISTNOTE radar-kurz48 \(gapNote(app).label)")
        shot(app, "radar-quelle-kurz48-aeltester-slot")
        app.terminate()
    }

    // MARK: Layers: one shared setting, every group, 48 and 72 hours

    private enum Pick {
        case rain(String), entry(group: String?, String)
        @MainActor func select(_ app: XCUIApplication, _ test: RadarHistoryUITests) throws {
            switch self {
            case .rain(let prefix): try test.chooseRain(app, prefix)
            case .entry(let group, let prefix):
                let entry = try XCTUnwrap(test.openLayerEntry(app, group: group, entry: prefix), "\(prefix) wählbar")
                entry.tap()
            }
        }
    }

    /// One layer at one setting: starts at now, the slider's left end is the oldest slot that exists inside the chosen past
    /// (`oldest` is its VoiceOver value prefix), the "Davor fehlen Daten" note is there exactly when the source gives less
    /// than chosen (`note` = start of its text), and 48 and 72 produce different oldest slots or texts (checked by the callers).
    private func layerCase(_ name: String, pick: Pick, setting: Int, now: String, oldest: String, note: String?,
                           midHole: Bool = false) throws {   // the stub's hole of 6 times lies 36 h back
        let app = launchLayers(setting: setting)
        try pick.select(app, self)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(now) }, "starts at now (\(now)): \(value(slider))")
        shot(app, "\(name)\(setting)-1-jetzt")
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(oldest) }, "\(setting) h: oldest slot \(oldest): \(value(slider))")
        if let note {
            XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "\(setting) h: shortfall named: \(value(slider))")
            XCTAssertTrue(gapNote(app).label.hasPrefix(note), "\(setting) h: note \(note) vs \(gapNote(app).label)")
            XCTAssertTrue(value(slider).contains(note), "VoiceOver value names it: \(value(slider))")
            print("HISTNOTE \(name)\(setting) \(gapNote(app).label) | \(value(slider))")
        } else {
            XCTAssertFalse(gapNote(app).exists, "\(setting) h: the source gives all that was chosen, no note: \(gapNote(app).label)")
        }
        shot(app, "\(name)\(setting)-2-aeltester-slot")
        if midHole {
            XCTAssertTrue(seek(slider, near: 1 - 36.0 / Double(setting), slots: setting * 12 + 1) { value(slider).contains("fehlen Daten") }, "a slot next to the hole: \(value(slider))")
            XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "hole named: \(value(slider))")
            shot(app, "\(name)\(setting)-3-luecke")
        }
        jump(slider, fraction: 1)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(now) || $0.localizedCaseInsensitiveContains("vorhersage") }, "way back to the end: \(value(slider))")
        shot(app, "\(name)\(setting)-4-ende")
        app.terminate()
    }

    // Europa (OPERA): server and source deliver 72 h; the chosen past decides the oldest slot. Now = Wed 18 Nov 09:50.
    func testEuropeFortyEightHours() throws {
        try layerCase("europa", pick: .rain("Europa (OPERA)"), setting: 48, now: "09:50, Messung",
                      oldest: "Mo. 16. Nov., 09:50, Messung", note: nil)
    }
    /// The hole of 6 times (36 h back) lies inside 48 h and is named there (own test: the large Europe images are slow).
    func testEuropeHoleIsNamedAtFortyEightHours() throws {
        let app = launchLayers(setting: 48)
        try Pick.rain("Europa (OPERA)").select(app, self)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("09:50, Messung") })
        XCTAssertTrue(seek(slider, near: 1 - 36.0 / 48, slots: 577) { value(slider).contains("fehlen Daten") }, "a slot next to the hole: \(value(slider))")
        XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "hole named: \(value(slider))")
        shot(app, "europa48-3-luecke")
        app.terminate()
    }
    func testEuropeSeventyTwoHours() throws {
        try layerCase("europa", pick: .rain("Europa (OPERA)"), setting: 72, now: "09:50, Messung",
                      oldest: "So. 15. Nov., 09:50, Messung", note: nil, midHole: true)
    }

    // Blitze: the source keeps about 24 h: the oldest slot is the same, the missing part before it depends on the choice.
    func testLightningFortyEightHours() throws {
        try layerCase("blitze", pick: .entry(group: nil, "Blitze"), setting: 48, now: "09:50, Messung",
                      oldest: "Di. 17. Nov., 09:50", note: "Davor fehlen Daten: Mo")
    }
    func testLightningSeventyTwoHours() throws {
        try layerCase("blitze", pick: .entry(group: nil, "Blitze"), setting: 72, now: "09:50, Messung",
                      oldest: "Di. 17. Nov., 09:50", note: "Davor fehlen Daten: So")
    }

    // Wolken (satellite): full 72 h, 10 minute grid.
    func testCloudsFortyEightHours() throws {
        try layerCase("wolken", pick: .entry(group: nil, "Wolken"), setting: 48, now: "09:50, Messung",
                      oldest: "Mo. 16. Nov., 09:50", note: nil)
    }
    func testCloudsSeventyTwoHours() throws {
        try layerCase("wolken", pick: .entry(group: nil, "Wolken"), setting: 72, now: "09:50, Messung",
                      oldest: "So. 15. Nov., 09:50", note: nil)
    }

    // Luftdruck Deutschland (model layer, built up for 10 h since the deploy): oldest = first past slot, the rest is named.
    func testPressureFortyEightHours() throws {
        try layerCase("luftdruck", pick: .entry(group: "Luftdruck", "Deutschland"), setting: 48, now: "09:00, Modell",
                      oldest: "Di. 17. Nov., 22:00, Modell", note: "Davor fehlen Daten: Mo")
    }
    func testPressureSeventyTwoHours() throws {
        try layerCase("luftdruck", pick: .entry(group: "Luftdruck", "Deutschland"), setting: 72, now: "09:00, Modell",
                      oldest: "Di. 17. Nov., 22:00, Modell", note: "Davor fehlen Daten: So")
    }

    // Temperatur (model, 60 h built up): 48 h are all there, 72 h end 12 hours short.
    func testTemperatureFortyEightHours() throws {
        try layerCase("temperatur", pick: .entry(group: nil, "Temperatur"), setting: 48, now: "09:00, Modell",
                      oldest: "Mo. 16. Nov., 09:00, Modell", note: nil)
    }
    func testTemperatureSeventyTwoHours() throws {
        try layerCase("temperatur", pick: .entry(group: nil, "Temperatur"), setting: 72, now: "09:00, Modell",
                      oldest: "So. 15. Nov., 20:00, Modell", note: "Davor fehlen Daten: 09:00")
    }

    /// The forecast stays separate from the past of a model layer; the way to the end of the forecast works at 72 h.
    func testModelLayerPastIsModelNotForecast() throws {
        let app = launchLayers(setting: 72)
        try Pick.entry(group: "Luftdruck", "Deutschland").select(app, self)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Modell") }, value(slider))
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.contains(", Modell.") || $0.contains(", Modell") }, "the past is a model value: \(value(slider))")
        XCTAssertFalse(value(slider).localizedCaseInsensitiveContains("vorhersage"), value(slider))
        jump(slider, fraction: 1)
        XCTAssertTrue(waitValue(slider) { $0.localizedCaseInsensitiveContains("vorhersage") }, "the forecast stays separate: \(value(slider))")
        app.terminate()
    }

    /// 48 / 72 greyed per layer: the active map's own offer decides (server reports 48 h: 72 greyed; 72 h: selectable).
    private func greyedCase(_ name: String, _ pick: Pick) throws {
        for (server, selectable) in [(48, false), (72, true)] {
            let app = launchLayers(setting: 24, server: server)
            try pick.select(app, self)
            XCTAssertTrue(waitValue(slider(app)) { !$0.isEmpty })
            openInfoSheet(app)
            let entry = app.buttons["Maximale Vergangenheit"]
            if !entry.waitForExistence(timeout: 10) { shot(app, "einstellung-\(name.lowercased())-server\(server)-fehlt", enforceDark: false) }
            XCTAssertTrue(entry.exists, "entry Maximale Vergangenheit")
            entry.tap()
            let row72 = app.descendants(matching: .any).matching(identifier: "past-hours-72").firstMatch
            XCTAssertTrue(row72.waitForExistence(timeout: 10), "72 h row")
            XCTAssertEqual(row72.isEnabled, selectable, "\(name): server reports \(server) h, 72 selectable = \(selectable)")
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "past-hours-48").firstMatch.isEnabled == (server >= 48))
            print("HISTGREY layer=\(name) server=\(server) 72selectable=\(row72.isEnabled)")
            shot(app, "einstellung-\(name.lowercased())-server\(server)")
            app.terminate()
        }
    }
    func testStepsGreyedForLightning() throws { try greyedCase("Blitze", .entry(group: nil, "Blitze")) }
    func testStepsGreyedForPressure() throws { try greyedCase("Luftdruck", .entry(group: "Luftdruck", "Deutschland")) }
    func testStepsGreyedForEurope() throws { try greyedCase("Europa", .rain("Europa (OPERA)")) }

    // MARK: Measurement: scrubbing across a full 72 h timeline

    /// Default state (no stored choice): the 72 h of the backend are the window, the slider covers all of them.
    func testScrubbingAcrossFullSeventyTwoHourTimelineIsMeasured() throws {
        let app = launchRadar(hours: 72, fresh: true)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        let options = XCTMeasureOptions(); options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)))
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
        }
        XCTAssertTrue(app.state == .runningForeground, "the app is still running after scrubbing 10 full passes")
        app.terminate()
    }

    /// Same measurement with an explicit stored 72 h (the way of the previous review): isolates the default logic from the simulator state.
    func testScrubbingAcrossFullSeventyTwoHourTimelineWithStoredChoiceIsMeasured() throws {
        let app = launchRadar(hours: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        let options = XCTMeasureOptions(); options.iterationCount = 5
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app), XCTMemoryMetric(application: app)], options: options) {
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5)))
            slider.coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: 0.5))
                .press(forDuration: 0.05, thenDragTo: slider.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
        }
        XCTAssertTrue(app.state == .runningForeground, "the app is still running after scrubbing 10 full passes")
        app.terminate()
    }

    // MARK: Integration against a LOCAL backend on the state of PR #4 (skipped unless the host script gives the URL)

    /// Runs only with `TEST_RUNNER_HIST_BACKEND_URL=http://127.0.0.1:<port>/v1/radar/` (and `TEST_RUNNER_HIST_HOURS=48|72`):
    /// the app talks to a local backend built from `feature/history-hours-all` (fecb9c9), NOT the production backend.
    /// Per layer: value at "now", at the oldest slot (slider left end) and the gap note there; lines `HISTINT ...` go to the log.
    func testIntegrationAgainstLocalBackendOnPR4() throws {
        let environment = ProcessInfo.processInfo.environment
        guard let url = environment["HIST_BACKEND_URL"] else { throw XCTSkip("Nur mit lokalem Backend (HIST_BACKEND_URL)") }
        executionTimeAllowance = 600
        let hours = environment["HIST_HOURS"] ?? "48"
        let layers = (environment["HIST_LAYERS"] ?? "Regen|Deutschland (DWD),Regen|Europa (OPERA),Regen|Welt (NOAA),|Blitze,Luftdruck|Deutschland").split(separator: ",").map(String.init)
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: [
            "-radar-backend-url", url, "-radarPastHours", hours]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(4)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        for item in layers {
            let parts = item.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            let group = parts[0].isEmpty ? nil : parts[0]
            if group == "Regen" {
                try chooseRain(app, parts[1])
            } else {
                guard let entry = openLayerEntry(app, group: group, entry: parts[1]) else { print("HISTINT layer=\(parts[1]) nicht angeboten"); continue }
                entry.tap()
            }
            // Dark check per layer. REAL rain data colours a variable share of the map (measured 0.49 for Deutschland at a rainy
            // slot), so for the rain layers the luminance is recorded and saved but not enforced here; their 0.45 check runs on the fixed
            // data of `testBrightness*`. The sparse overlays (lightning, pressure lines) leave the surface visible: 0.45 is enforced.
            let enforce = parts[1].hasPrefix("Blitze") || group == "Luftdruck"
            let slider = slider(app)
            sleep(3)
            let now = value(slider)
            jump(slider, fraction: 0)
            sleep(8)   // large images (Europe 2048 px) are drawn progressively: wait for the full overlay before the screenshot
            let oldest = value(slider)
            let note = gapNote(app).exists ? gapNote(app).label : "-"
            print("HISTINT hours=\(hours) layer=\(parts[1]) jetzt=\(now) | aeltester=\(oldest) | hinweis=\(note)")
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-aeltester", enforceDark: enforce)
            jump(slider, fraction: 1)
            sleep(2)
            shot(app, "integration\(hours)-\(parts[1].filter { $0.isLetter })-ende", enforceDark: enforce)
        }
        app.terminate()
    }

    // MARK: Default window from the backend (a fresh install has no stored choice)

    /// Fresh install: nothing stored. The first open reaches the oldest slot the backend window offers, without touching the setting.
    private func freshCase(_ name: String, layers: Pick?, server: Int, now: String, oldest: String, note: String?) throws {
        let app = layers == nil ? launchRadar(hours: server, fresh: true) : launchLayers(setting: nil, server: server)
        try layers?.select(app, self)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(now) }, "starts at now (\(now)): \(value(slider))")
        shot(app, "frisch-\(name)\(server)-1-jetzt")
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(oldest) }, "fresh install, \(server) h backend: oldest slot \(oldest): \(value(slider))")
        if let note {
            XCTAssertTrue(gapNote(app).waitForExistence(timeout: 10), "shortfall named: \(value(slider))")
            XCTAssertTrue(gapNote(app).label.hasPrefix(note), gapNote(app).label)
        } else { XCTAssertFalse(gapNote(app).exists, "no hint: \(gapNote(app).label)") }
        shot(app, "frisch-\(name)\(server)-2-aeltester-slot")
        jump(slider, fraction: 1)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix(now) || $0.localizedCaseInsensitiveContains("vorhersage") }, "way back: \(value(slider))")
        shot(app, "frisch-\(name)\(server)-3-zurueck")
        app.terminate()
    }

    func testFreshInstallEurope48() throws {
        try freshCase("europa", layers: .rain("Europa (OPERA)"), server: 48, now: "09:50, Messung", oldest: "Mo. 16. Nov., 09:50, Messung", note: nil)
    }
    func testFreshInstallEurope72() throws {
        try freshCase("europa", layers: .rain("Europa (OPERA)"), server: 72, now: "09:50, Messung", oldest: "So. 15. Nov., 09:50, Messung", note: nil)
    }
    func testFreshInstallTemperature72() throws {
        try freshCase("temperatur", layers: .entry(group: nil, "Temperatur"), server: 72, now: "09:00, Modell", oldest: "So. 15. Nov., 20:00, Modell", note: "Davor fehlen Daten: 08:00")
    }
    func testFreshInstallRadarGermany48() throws {
        try freshCase("radar", layers: nil, server: 48, now: "09:40, Messung", oldest: "Mo. 16. Nov., 09:40, Messung", note: nil)
    }
    func testFreshInstallRadarGermany72() throws {
        try freshCase("radar", layers: nil, server: 72, now: "09:40, Messung", oldest: "So. 15. Nov., 09:40, Messung", note: nil)
    }

    private func pickStep(_ app: XCUIApplication, _ identifier: String) {
        openInfoSheet(app)
        let entry = app.buttons["Maximale Vergangenheit"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        let row = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), identifier)
        row.tap()
        sleep(1)
    }

    // MARK: "Standard" mark of the setting (TestFlight build 57/58: it hung on the chosen value, plus a doubled row)

    private func openPastSetting(_ app: XCUIApplication) {
        openInfoSheet(app)
        let entry = app.buttons["Maximale Vergangenheit"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        XCTAssertTrue(pastRow(app, 72).waitForExistence(timeout: 10), "rows of the setting")
    }

    private func pastRow(_ app: XCUIApplication, _ hours: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "past-hours-\(hours)").firstMatch
    }

    /// Rows are in the normal order, only the `standard` row carries "(Standard)" (and no extra "Standard" row exists), only the
    /// `checked` row is selected.
    private func assertPastRows(_ app: XCUIApplication, standard: Int, checked: Int, _ context: String) {
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "past-hours-default").firstMatch.exists, "no doubled Standard row: \(context)")
        var marked: [Int] = [], selected: [Int] = []
        for hours in [1, 2, 6, 12, 24, 48, 72] {
            let row = pastRow(app, hours)
            XCTAssertTrue(row.exists, "row \(hours) h: \(context)")
            if row.label.contains("(Standard)") { marked.append(hours) }
            if row.isSelected { selected.append(hours) }
            XCTAssertTrue(row.label.hasPrefix(hours == 1 ? "1 Stunde" : "\(hours) Stunden"), "\(row.label): \(context)")
        }
        XCTAssertEqual(marked, [standard], "the Standard mark hangs on the fixed standard step only: \(context)")
        XCTAssertEqual(selected, [checked], "the check mark follows the choice: \(context)")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Standard'")).count, 0, "no row starts with Standard: \(context)")
    }

    /// Radar Germany, the backend window is 72 h: Standard sits on "72 Stunden (Standard)" whichever step is chosen (also the standard itself).
    func testStandardMarkStaysOnTheStandardStepWhateverIsChosenRadar() throws {
        let app = launchRadar(hours: 72, setting: 6)
        XCTAssertTrue(waitValue(slider(app)) { $0.contains("Messung") })
        openPastSetting(app)
        assertPastRows(app, standard: 72, checked: 6, "stored choice 6 h")
        shot(app, "standard-radar-1-gewaehlt-6h", enforceDark: false)
        pastRow(app, 24).tap(); sleep(1)
        assertPastRows(app, standard: 72, checked: 24, "24 h picked")
        pastRow(app, 1).tap(); sleep(1)
        assertPastRows(app, standard: 72, checked: 1, "1 h picked")
        pastRow(app, 72).tap(); sleep(1)
        assertPastRows(app, standard: 72, checked: 72, "the standard step itself picked")
        shot(app, "standard-radar-2-standardwert-72h", enforceDark: false)
        pastRow(app, 12).tap(); sleep(1)
        assertPastRows(app, standard: 72, checked: 12, "12 h picked after the standard")
        app.terminate()
    }

    /// A layer with 48 h of past: Standard sits on "48 Stunden (Standard)" (its own window), the choice moves the check mark only.
    func testStandardMarkStaysOnTheStandardStepWhateverIsChosenEurope() throws {
        let app = launchLayers(setting: 6, server: 48)
        try Pick.rain("Europa (OPERA)").select(app, self)
        XCTAssertTrue(waitValue(slider(app)) { $0.hasPrefix("09:50, Messung") })
        openPastSetting(app)
        assertPastRows(app, standard: 48, checked: 6, "Europe, stored choice 6 h")
        shot(app, "standard-europa-1-gewaehlt-6h", enforceDark: false)
        pastRow(app, 2).tap(); sleep(1)
        assertPastRows(app, standard: 48, checked: 2, "Europe, 2 h picked")
        pastRow(app, 48).tap(); sleep(1)
        assertPastRows(app, standard: 48, checked: 48, "Europe, the standard step picked")
        shot(app, "standard-europa-2-standardwert-48h", enforceDark: false)
        app.terminate()
    }

    /// Restart: a chosen "2 h" survives the restart and wins over the 72 h window; "Standard" clears it again (the 72 h are back).
    func testStoredTwoHoursWinsAfterRestartAndStandardBringsTheBackendWindowBack() throws {
        var app = launchLayers(setting: nil, server: 72)
        try Pick.rain("Europa (OPERA)").select(app, self)
        var slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("09:50, Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("So. 15. Nov., 09:50") }, "fresh: 72 h: \(value(slider))")
        shot(app, "neustart-1-frisch-72")
        pickStep(app, "past-hours-2")
        app.terminate()

        // Restart without any argument for the setting: the stored 2 h (an explicit choice) decide.
        app = launchLayers(setting: nil, server: 72, keepStored: true)
        try Pick.rain("Europa (OPERA)").select(app, self)
        slider = self.slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("09:50, Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("07:50, Messung") }, "stored 2 h wins over the 72 h window: \(value(slider))")
        shot(app, "neustart-2-gespeichert-2h")
        pickStep(app, "past-hours-default")
        app.terminate()

        app = launchLayers(setting: nil, server: 72, keepStored: true)
        try Pick.rain("Europa (OPERA)").select(app, self)
        slider = self.slider(app)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("09:50, Messung") })
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("So. 15. Nov., 09:50") }, "Standard: the backend's 72 h are back: \(value(slider))")
        shot(app, "neustart-3-standard-72")
        app.terminate()
    }

    // MARK: Against PRODUCTION (read-only view), only with TEST_RUNNER_HIST_PROD=1

    /// The app against `https://showers.linolaske.de/v1` (production default): only viewing and the slider, no write access, no login,
    /// no stub. Fresh install (no stored choice): the first open shows the backend's 72 h window limited to what exists. Prints the oldest
    /// slot, the hint and the end per layer (`HISTPROD ...`); not part of the regular suite (needs the network and moves with the data).
    func testProductionReadOnlyOldestSlotAndHint() throws {
        guard ProcessInfo.processInfo.environment["HIST_PROD"] != nil else { throw XCTSkip("Nur mit TEST_RUNNER_HIST_PROD=1 (liest die Produktion, nur Ansicht)") }
        let layer = ProcessInfo.processInfo.environment["HIST_PROD_LAYER"] ?? "welt"
        let pick: Pick = layer == "welt" ? .rain("Welt (NOAA)") : layer == "europa" ? .rain("Europa (OPERA)") : .entry(group: nil, "Temperatur")
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-UITestResetPastChoice"]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 40))
        sleep(6)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        try pick.select(app, self)
        let slider = slider(app)
        sleep(4)
        let now = value(slider)
        shot(app, "prod-\(layer)-1-jetzt", enforceDark: false)
        jump(slider, fraction: 0)
        sleep(8)
        let oldest = value(slider)
        let note = gapNote(app).exists ? gapNote(app).label : "-"
        print("HISTPROD layer=\(layer) jetzt=\(now) | aeltester=\(oldest) | hinweis=\(note)")
        XCTAssertNotEqual(oldest, now, "the slider reaches back")
        shot(app, "prod-\(layer)-2-aeltester-slot", enforceDark: false)
        jump(slider, fraction: 1)
        sleep(3)
        shot(app, "prod-\(layer)-3-zurueck", enforceDark: false)
        print("HISTPROD layer=\(layer) zurueck=\(value(slider)) hinweis_am_ende=\(gapNote(app).exists)")
        app.terminate()
    }

    // MARK: Brightness per layer (dark mode check, fixed data: stubs and one real Europe image, no network)

    /// Mean luminance of the app surface WITHOUT any data layer: the German radar fixture (a few rain cells) before a layer is chosen.
    /// Named check "OBERFLAECHE": stays below 0.45 in dark mode, in every brightness test.
    private func brightnessShot(_ app: XCUIApplication, _ name: String, surface: Bool = false) {
        sleep(1)
        let dir = "/private/tmp/claude-501/hist-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let screenshot = app.screenshot()
        let luminance = UITestLaunch.meanLuminance(screenshot.image)
        print("LUMA bright-\(name)-\(suffix)=\(luminance)")
        try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("bright-\(name)-\(suffix).png"))
        guard suffix == "dark", ProcessInfo.processInfo.environment["BRIGHT_MEASURE"] == nil else { return }
        if surface {
            XCTAssertLessThan(luminance, 0.45, "OBERFLAECHE (map and app chrome without data layer) in dark mode: \(luminance)")
        } else if Self.isBrightData(name) {
            XCTAssertLessThan(luminance, Self.brightDataLimit, "layer \(name) (bright data colours) in dark mode: \(luminance)")
        } else {
            XCTAssertLessThan(luminance, 0.45, "layer \(name) in dark mode: \(luminance)")
        }
    }

    private func launchBrightness(realEurope: Bool = false) -> XCUIApplication {
        var extra = ["-UITestForecast", "current", "-UITestRadar", "fixture", "-UITestLayers", "all", "-UITestFrozenLayers"]
        if realEurope {
            let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Fixtures/radar_eu-real-20261120T0455Z.webp").path
            extra += ["-UITestRealImage", "radar_eu=\(file)"]
        }
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: extra))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 30))
        sleep(2)
        menu.tap()   // the stubbed layers are reported after the first probe
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(2)
        return app
    }

    private func brightnessLayer(_ app: XCUIApplication, _ name: String, _ pick: Pick) throws {
        try pick.select(app, self)
        _ = slider(app)
        sleep(6)   // the overlay is drawn progressively
        brightnessShot(app, name)
    }

    /// One layer per test (a test has 180 s): surface first (radar fixture alone), then the layer.
    private func brightnessCase(_ name: String, _ pick: Pick, realEurope: Bool = false) throws {
        let app = launchBrightness(realEurope: realEurope)
        _ = slider(app)
        sleep(3)
        brightnessShot(app, "oberflaeche-radar-de", surface: true)
        try brightnessLayer(app, name, pick)
        app.terminate()
    }

    func testBrightnessEuropeStub() throws { try brightnessCase("europa-stub", .rain("Europa (OPERA)")) }
    func testBrightnessEuropeRealData() throws { try brightnessCase("europa-real", .rain("Europa (OPERA)"), realEurope: true) }
    func testBrightnessWorld() throws { try brightnessCase("welt", .rain("Welt (NOAA)")) }
    func testBrightnessLightning() throws { try brightnessCase("blitze", .entry(group: nil, "Blitze")) }
    func testBrightnessClouds() throws { try brightnessCase("wolken", .entry(group: nil, "Wolken")) }
    func testBrightnessSun() throws { try brightnessCase("sonne", .entry(group: nil, "Sonne")) }
    func testBrightnessPressure() throws { try brightnessCase("luftdruck-de", .entry(group: "Luftdruck", "Deutschland")) }
    func testBrightnessTemperature() throws { try brightnessCase("temperatur", .entry(group: nil, "Temperatur")) }
    func testBrightnessDewpoint() throws { try brightnessCase("taupunkt", .entry(group: "Feuchtigkeit", "Taupunkt")) }
    func testBrightnessHumidity() throws { try brightnessCase("feuchte-relativ", .entry(group: "Feuchtigkeit", "Relativ")) }
}

// MARK: Hint: the chosen past is longer than what the map really delivers
//
// Card C2AC381D. The hint ("Diese Karte reicht nur N Stunden zurück – gewählt sind M Stunden.") shows exactly when the user's choice
// is larger than the span the shown timeline has; the choice and the data stay as they are. Stub tests (no network) plus one
// read-only production test (`TEST_RUNNER_HIST_PROD=1`, `TEST_RUNNER_HIST_PROD_LAYER=radar|europa|temperatur|taupunkt|feuchte|luftdruck`).
// Screenshots: `/private/tmp/claude-501/hist-hint-shots/<HINT_PHASE>-<name>-<light|dark>.png` (`TEST_RUNNER_HINT_PHASE=vorher|nachher`).
extension RadarHistoryUITests {
    private func hintNote(_ app: XCUIApplication) -> XCUIElement { app.descendants(matching: .any).matching(identifier: "radar-history-short-note").firstMatch }

    private func hintShot(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let phase = ProcessInfo.processInfo.environment["HINT_PHASE"] ?? "nachher"
        let dir = "/private/tmp/claude-501/hist-hint-shots"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(phase)-\(name)-\(suffix).png"))
    }

    /// What the screen says (no assertion): the hint, the hole note and the slider value. For the "before" reproduction.
    private func hintReport(_ app: XCUIApplication, _ name: String, _ slider: XCUIElement) {
        let hint = hintNote(app), gap = gapNote(app)
        print("HINTREPRO \(name) hinweis=[\(hint.exists ? hint.label : "-")] luecke=[\(gap.exists ? gap.label : "-")] regler=[\(value(slider))]")
    }

    private func closeSheet(_ app: XCUIApplication) {
        for _ in 0..<3 where app.sliders.firstMatch.isHittable == false {
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
    }

    private func expectHint(_ app: XCUIApplication, available: Int, chosen: Int, _ context: String) {
        let hint = hintNote(app)
        let shown = hint.waitForExistence(timeout: 10)
        if !shown {
            // Failure state (Build 57 diagnosis): which layer is really active, what the slider says, and the screen.
            let state = "layer button '\(app.buttons["radar-layer-menu"].value as? String ?? "nil")', slider '\(app.sliders.firstMatch.value as? String ?? "nil")', gap note \(gapNote(app).exists)"
            print("HINTMISSING \(context): \(state)")
            let shot = XCTAttachment(screenshot: app.screenshot()); shot.name = "hint-missing"; shot.lifetime = .keepAlways; add(shot)
            XCTFail("\(context): hint for \(available) of \(chosen) h missing (\(state))")
        }
        guard hint.exists else { return }
        XCTAssertTrue(hint.label.hasPrefix("Diese Karte reicht nur \(available) Stunden zurück – gewählt sind \(chosen) Stunden."), "\(context): \(hint.label)")
    }

    /// Layer case: the setting is `setting`, the stub's map reaches back `available` hours (`nil`: all of it, no hint).
    private func hintLayerCase(_ name: String, pick: Pick, setting: Int, server: Int = 72, available: Int?) throws {
        let app = launchLayers(setting: setting, server: server)
        try pick.select(app, self)
        // The layer switch is verified (Build 57 diagnosis: in a full run the tap on the menu entry once did not switch, the radar stayed
        // active and the test then looked for the hint on the wrong map). Up to three selections; the expectation itself is unchanged.
        let menu = app.buttons["radar-layer-menu"]
        func switched() -> Bool { ((menu.value as? String) ?? "") != "Regenradar" }
        for attempt in 1...3 where !switched() {
            let end = Date().addingTimeInterval(8)
            while Date() < end && !switched() { usleep(300_000) }
            if switched() { break }
            print("LAYERSWITCH \(name): not switched after the tap (attempt \(attempt)), layer button '\(menu.value as? String ?? "nil")'")
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(1)
            try pick.select(app, self)
        }
        XCTAssertTrue(switched(), "\(name): the layer switch did not happen (layer button '\(menu.value as? String ?? "nil")')")
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") || $0.contains("Modell") }, value(slider))
        sleep(2)
        hintShot(app, "\(name)\(setting)-1-jetzt")
        hintReport(app, "\(name)\(setting)-jetzt", slider)
        if let available { expectHint(app, available: available, chosen: setting, "\(name) \(setting) h now") }
        else { XCTAssertFalse(hintNote(app).exists, "\(name) \(setting) h: the map gives all that was chosen: \(hintNote(app).label)") }
        jump(slider, fraction: 0)
        sleep(2)
        hintShot(app, "\(name)\(setting)-2-aeltester-slot")
        hintReport(app, "\(name)\(setting)-aeltester", slider)
        if let available { expectHint(app, available: available, chosen: setting, "\(name) \(setting) h oldest") }
        else { XCTAssertFalse(hintNote(app).exists, "\(name) \(setting) h at the oldest slot: \(hintNote(app).label)") }
        app.terminate()
    }

    // Case (b), stub: saved choice 72 h, the server of `history.json` reports 48 h. The choice stays selected (greyed out), the data stays 48 h.
    func testHintRadarChoiceSeventyTwoServerFortyEight() throws {
        let app = launchRadar(hours: 48, setting: 72)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
        sleep(2)
        hintShot(app, "radar-server48-wahl72-1-jetzt")
        hintReport(app, "radar-server48-wahl72-jetzt", slider)
        expectHint(app, available: 48, chosen: 72, "radar server 48, choice 72")
        jump(slider, fraction: 0)
        XCTAssertTrue(waitValue(slider) { $0.hasPrefix("Mo. 16. Nov.") }, "the data stays 48 h: \(value(slider))")
        hintShot(app, "radar-server48-wahl72-2-aeltester-slot")
        hintReport(app, "radar-server48-wahl72-aeltester", slider)
        expectHint(app, available: 48, chosen: 72, "radar server 48, choice 72, oldest slot")
        // The stored choice is not touched: row 72 stays ticked (and greyed out).
        openInfoSheet(app)
        let entry = app.buttons["Maximale Vergangenheit"]
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()
        let row = app.descendants(matching: .any).matching(identifier: "past-hours-72").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        XCTAssertTrue(row.isSelected, "72 stays the stored choice")
        XCTAssertFalse(row.isEnabled, "72 stays greyed out")
        hintShot(app, "radar-server48-wahl72-3-einstellung")
        app.terminate()
    }

    /// Radar Germany with the full 72 h, and a smaller choice than the server delivers: no hint.
    func testHintRadarNoneWhenHistoryIsFullOrChoiceIsSmaller() throws {
        for (server, setting, name) in [(72, 72, "radar-voll72"), (72, 24, "radar-wahl24"), (48, 48, "radar-voll48")] {
            let app = launchRadar(hours: server, setting: setting)
            let slider = slider(app)
            XCTAssertTrue(waitValue(slider) { $0.contains("Messung") })
            sleep(2)
            hintShot(app, "\(name)-1-jetzt")
            XCTAssertFalse(hintNote(app).exists, "\(name): no hint: \(hintNote(app).label)")
            jump(slider, fraction: 0)
            sleep(2)
            XCTAssertFalse(hintNote(app).exists, "\(name) oldest slot: no hint: \(hintNote(app).label)")
            app.terminate()
        }
    }

    // Layers (stub, now 09:50 Berlin): the hint names what the map really has.
    func testHintTemperatureSeventyTwo() throws { try hintLayerCase("temperatur", pick: .entry(group: nil, "Temperatur"), setting: 72, available: 61) }
    func testHintLightningFortyEight() throws { try hintLayerCase("blitze", pick: .entry(group: nil, "Blitze"), setting: 48, available: 24) }
    func testHintPressureSeventyTwo() throws { try hintLayerCase("luftdruck", pick: .entry(group: "Luftdruck", "Deutschland"), setting: 72, available: 11) }
    func testHintNoneTemperatureFortyEight() throws { try hintLayerCase("temperatur", pick: .entry(group: nil, "Temperatur"), setting: 48, available: nil) }
    func testHintNoneCloudsSeventyTwo() throws { try hintLayerCase("wolken", pick: .entry(group: nil, "Wolken"), setting: 72, available: nil) }
    func testHintNoneEuropeSeventyTwo() throws { try hintLayerCase("europa", pick: .rain("Europa (OPERA)"), setting: 72, available: nil) }

    /// The hint goes away when the choice is reduced to what the map has, and comes back with the larger choice (the data never changes by itself).
    func testHintFollowsTheChoice() throws {
        let app = launchLayers(setting: 72)
        try Pick.entry(group: nil, "Temperatur").select(app, self)
        let slider = slider(app)
        XCTAssertTrue(waitValue(slider) { $0.contains("Modell") })
        expectHint(app, available: 61, chosen: 72, "temperature 72 h")
        pickStep(app, "past-hours-48")
        closeSheet(app)
        XCTAssertTrue(hintNote(app).waitForNonExistence(timeout: 10), "48 h are all there: no hint: \(hintNote(app).label)")
        hintShot(app, "temperatur-wahl-auf-48")
        pickStep(app, "past-hours-72")
        closeSheet(app)
        expectHint(app, available: 61, chosen: 72, "temperature 72 h again")
        hintShot(app, "temperatur-wahl-wieder-72")
        app.terminate()
    }

    // MARK: Production (read-only view), only with TEST_RUNNER_HIST_PROD=1

    /// Case (a): choice 72 h against the real server. Whatever the layer really has (measured by the slider's oldest slot), the hint appears
    /// exactly when it is clearly shorter than 72 h, and its number is that span. Prints `HINTPROD ...`.
    func testHintAgainstProductionSeventyTwo() throws {
        guard ProcessInfo.processInfo.environment["HIST_PROD"] != nil else { throw XCTSkip("Nur mit TEST_RUNNER_HIST_PROD=1 (liest die Produktion, nur Ansicht)") }
        let layer = ProcessInfo.processInfo.environment["HIST_PROD_LAYER"] ?? "temperatur"
        let pick: Pick? = switch layer {
        case "radar": nil
        case "europa": .rain("Europa (OPERA)")
        case "taupunkt": .entry(group: "Feuchtigkeit", "Taupunkt")
        case "feuchte": .entry(group: "Feuchtigkeit", "Relativ")
        case "luftdruck": .entry(group: "Luftdruck", "Deutschland")
        default: .entry(group: nil, "Temperatur")
        }
        let app = UITestLaunch.app(extra: UITestLaunch.setAppearance(suffix == "dark" ? .dark : .light, extra: ["-radarPastHours", "72"]))
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 40))
        sleep(6)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        try pick?.select(app, self)
        let slider = slider(app)
        sleep(6)
        let now = value(slider)
        hintShot(app, "prod-\(layer)72-1-jetzt")
        jump(slider, fraction: 0)
        sleep(8)
        let oldest = value(slider)
        let reference = Date()
        let span = PastWindowLimitUITests.date(of: now, reference: reference).flatMap { newer in
            PastWindowLimitUITests.date(of: oldest, reference: reference).map { newer.timeIntervalSince($0) / 3600 }
        }
        let hint = hintNote(app)
        print("HINTPROD layer=\(layer) jetzt=[\(now)] aeltester=[\(oldest)] stunden=\(span.map { String(format: "%.2f", $0) } ?? "?") hinweis=[\(hint.exists ? hint.label : "-")] luecke=[\(gapNote(app).exists ? gapNote(app).label : "-")]")
        hintShot(app, "prod-\(layer)72-2-aeltester-slot")
        let measured = try XCTUnwrap(span, "slider values not readable: \(now) | \(oldest)")
        if measured <= 69 {
            expectHint(app, available: Int(measured.rounded()), chosen: 72, "production \(layer): \(String(format: "%.2f", measured)) h")
        } else if measured >= 71.5 {
            XCTAssertFalse(hint.exists, "production \(layer): \(String(format: "%.2f", measured)) h are practically 72: no hint: \(hint.label)")
        }
        openInfoSheet(app)
        let entry = app.buttons["Maximale Vergangenheit"]
        if entry.waitForExistence(timeout: 10) {
            entry.tap()
            _ = app.descendants(matching: .any).matching(identifier: "past-hours-72").firstMatch.waitForExistence(timeout: 10)
            hintShot(app, "prod-\(layer)72-3-einstellung")
        }
        app.terminate()
    }
}
