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
