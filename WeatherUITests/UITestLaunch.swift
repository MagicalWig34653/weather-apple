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

extension UITestLaunch {
    /// Sets dark mode reliably: the device appearance AND the launch argument (the simulator setting alone did not reach the app, screenshots stayed light).
    @MainActor
    static func setAppearance(_ appearance: XCUIDevice.Appearance, extra: [String]) -> [String] {
        XCUIDevice.shared.appearance = appearance
        return appearance == .dark ? extra + ["-AppleInterfaceStyle", "Dark"] : extra
    }

    /// Mean luminance (0...1) of a screenshot, to prove light/dark in tests.
    static func meanLuminance(_ image: UIImage) -> Double {
        guard let cg = image.cgImage else { return -1 }
        var px = [UInt8](repeating: 0, count: 4)
        let ctx = CGContext(data: &px, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        ctx?.interpolationQuality = .medium
        ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return (0.2126 * Double(px[0]) + 0.7152 * Double(px[1]) + 0.0722 * Double(px[2])) / 255
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
