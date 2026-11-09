import XCTest

// Watch: oeffnet den Ort SHOT_CITY (Zeile) und wartet SHOT_HOLD Sekunden, waehrend extern `simctl io screenshot` laeuft.
final class WatchShotsUITests: XCTestCase {
    func testOpenPlace() throws {
        let env = ProcessInfo.processInfo.environment
        let app = XCUIApplication(bundleIdentifier: "de.linolaske.showernow.watchkitapp")
        // SHOT_LANG=en (Standard de): Sprache per Startargument, die Watch-App folgt sonst der Geraetesprache.
        let lang = env["SHOT_LANG"] ?? "de"
        app.launchArguments = ["-AppleLanguages", "(\(lang))", "-AppleLocale", lang == "en" ? "en_US" : "de_DE"]
        app.launch()
        let row = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", env["SHOT_CITY"] ?? "Hannover")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 20))
        row.tap()
        sleep(UInt32(env["SHOT_HOLD"] ?? "60") ?? 60)
    }
}
