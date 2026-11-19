import UIKit
import XCTest

/// Width check of the capsule name "Regenradar Welt" / "Rain radar world" (Lino 19.11.: "Regenradar sollte von der Breite
/// passen"), meant for the smallest iPhone simulator. Prints `WIDTH …` lines (text and capsule frames in points) and attaches
/// a screenshot per configuration; the name must lie fully inside the capsule.
@MainActor
final class RadarWorldWidthUITests: XCTestCase {
    private struct Config {
        let name: String
        let language: UITestLaunch.Language
        let size: String?
        let group: String, world: String, europe: String
        let worldTitle: String, europeTitle: String
        /// XXXL is recorded only: there the place capsule takes most of the row (known limit, also for Europe).
        var checksTruncation: Bool { size != "UICTContentSizeCategoryXXXL" }
    }

    /// Natural width of the capsule title (`.subheadline`, semibold) at the given text size, as the app renders it unscaled.
    static func naturalWidth(_ text: String, category: String?) -> CGFloat {
        let size = category.map { UIContentSizeCategory(rawValue: $0) } ?? .large
        let base = UIFont.preferredFont(forTextStyle: .subheadline, compatibleWith: UITraitCollection(preferredContentSizeCategory: size))
        let font = UIFont.systemFont(ofSize: base.pointSize, weight: .semibold)
        return (text as NSString).size(withAttributes: [.font: font]).width
    }

    override func setUpWithError() throws {
        continueAfterFailure = true
        XCUIDevice.shared.orientation = .portrait
    }

    private func choose(_ app: XCUIApplication, group: String, entry prefix: String) -> Bool {
        let menu = app.buttons["radar-layer-menu"]
        let rain = app.buttons.matching(NSPredicate(format: "label == %@", group)).firstMatch
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<4 {
            menu.tap()
            if rain.waitForExistence(timeout: 3) { rain.tap() }
            if entry.waitForExistence(timeout: 3), entry.isEnabled {
                entry.tap()
                if entry.waitForNonExistence(timeout: 3) { sleep(2); return true }
            }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
            sleep(2)
        }
        return false
    }

    private func measure(_ config: Config) {
        var extra = ["-UITestLayers", "all"]
        if let size = config.size { extra += ["-UIPreferredContentSizeCategoryName", size] }
        let app = UITestLaunch.app(language: config.language, extra: extra)
        app.launch()
        let menu = app.buttons["radar-layer-menu"]
        XCTAssertTrue(menu.waitForExistence(timeout: 20))
        sleep(2)
        menu.tap()
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()
        sleep(1)
        var europeWidth = -1.0
        if choose(app, group: config.group, entry: config.europe) {
            let europe = menu.staticTexts[config.europeTitle]
            if europe.waitForExistence(timeout: 5) { europeWidth = europe.frame.width }
        }
        XCTAssertTrue(choose(app, group: config.group, entry: config.world), "\(config.name): Welt wählbar")
        let world = menu.staticTexts[config.worldTitle]
        XCTAssertTrue(world.waitForExistence(timeout: 5), "\(config.name): Name \(config.worldTitle) in der Kapsel")
        let text = world.frame, capsule = menu.frame
        print("WIDTH \(config.name): screen=\(app.frame.width) capsule=\(capsule.minX)...\(capsule.maxX) (\(capsule.width)) "
              + "world=\(text.minX)...\(text.maxX) (\(text.width) x \(text.height)) europe=\(europeWidth)")
        // Truncation check: the capsule text may shrink to 0.7 of its natural width (`minimumScaleFactor`). A rendered width
        // below that means SwiftUI cut it off with "…" (seen on the iPhone SE 19.11.: "Regenradar W…" at 83.5 pt).
        let natural = Self.naturalWidth(config.worldTitle, category: config.size)
        print("WIDTH \(config.name): natural=\(natural) minimum=\(natural * 0.7)")
        if config.checksTruncation {
            XCTAssertGreaterThanOrEqual(text.width, natural * 0.7, "\(config.name): \(config.worldTitle) nicht abgeschnitten")
        }
        XCTAssertGreaterThanOrEqual(text.minX, capsule.minX, config.name)
        XCTAssertLessThanOrEqual(text.maxX, capsule.maxX, "\(config.name): Name ragt nicht aus der Kapsel")
        XCTAssertLessThanOrEqual(capsule.maxX, app.frame.width, "\(config.name): Kapsel im Bildschirm")
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "breite-\(config.name)"
        shot.lifetime = .keepAlways
        add(shot)
        app.terminate()
    }

    private static let german = (group: "Regen", world: "Welt (NOAA)", europe: "Europa (OPERA)",
                                 worldTitle: "Regenradar Welt", europeTitle: "Regenradar Europa")
    private static let english = (group: "Rain", world: "World (NOAA)", europe: "Europe (OPERA)",
                                  worldTitle: "Rain radar world", europeTitle: "Rain radar Europe")

    private func run(_ name: String, english: Bool, size: String?) {
        let t = english ? Self.english : Self.german
        measure(Config(name: name, language: english ? .english : .german, size: size, group: t.group, world: t.world,
                       europe: t.europe, worldTitle: t.worldTitle, europeTitle: t.europeTitle))
    }

    func testWidthGermanStandard() { run("de-standard", english: false, size: nil) }
    func testWidthGermanXXXL() { run("de-xxxl", english: false, size: "UICTContentSizeCategoryXXXL") }
    func testWidthEnglishStandard() { run("en-standard", english: true, size: nil) }
    func testWidthEnglishXS() { run("en-xs", english: true, size: "UICTContentSizeCategoryXS") }
}
