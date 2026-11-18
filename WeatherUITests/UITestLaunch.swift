import XCTest

/// Launch arguments for UI tests with an explicit language. Existing tests keep their literal `(de)` arguments;
/// new (English) tests use `UITestLaunch.arguments(language: .english, ...)`.
enum UITestLaunch {
    enum Language {
        case german, english

        var code: String { self == .german ? "de" : "en" }
        var locale: String { self == .german ? "de_DE" : "en_US" }
    }

    static func arguments(language: Language = .german, extra: [String] = []) -> [String] {
        ["-AppleLanguages", "(\(language.code))", "-AppleLocale", language.locale] + extra
    }

    static func app(language: Language = .german, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments(language: language, extra: extra)
        return app
    }
}

extension XCTestCase {
    /// Opens the nested layer menu (capsule, then submenu `group` if any) and returns the entry whose label starts with
    /// `prefix`. Retries because layers appear only once the server has reported them. Returns `nil` if it never shows.
    @MainActor
    func openLayerEntry(_ app: XCUIApplication, group: String?, entry prefix: String, attempts: Int = 6) -> XCUIElement? {
        let menu = app.buttons["radar-layer-menu"]
        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", prefix)).firstMatch
        for _ in 0..<attempts {
            menu.tap()
            if let group {
                let submenu = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", group)).firstMatch
                if submenu.waitForExistence(timeout: 3) { submenu.tap() }
            }
            if entry.waitForExistence(timeout: 3) { return entry }
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.5)).tap()   // close the menu (outside the menu also at large text sizes)
            sleep(2)
        }
        return nil
    }
}
