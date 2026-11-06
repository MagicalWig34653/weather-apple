import XCTest
@testable import Weather

final class AppIconOptionTests: XCTestCase {
    func testIdsAreUniqueAndOptionCountIsSeventeen() {
        let ids = AppIconOption.all.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count)
        XCTAssertEqual(ids.count, 21)
    }

    func testStandardIsFirstAndOnlyOptionWithoutAlternateName() {
        XCTAssertEqual(AppIconOption.all.first, .standard)
        XCTAssertNil(AppIconOption.standard.alternateIconName)
        XCTAssertEqual(AppIconOption.all.filter { $0.alternateIconName == nil }.count, 1)
    }

    func testAlternateNamesAreUniqueAndFollowPackageNaming() {
        let names = AppIconOption.all.compactMap(\.alternateIconName)
        XCTAssertEqual(Set(names).count, names.count)
        for option in AppIconOption.all.dropFirst() {
            XCTAssertEqual(option.alternateIconName, "Alt" + option.id)
            XCTAssertNil(option.alternateIconName?.rangeOfCharacter(from: CharacterSet.alphanumerics.inverted))
        }
    }

    func testTextsExistInBothLanguages() {
        for option in AppIconOption.all {
            XCTAssertFalse(option.name(languageCode: "de").isEmpty)
            XCTAssertFalse(option.name(languageCode: "en").isEmpty)
            XCTAssertFalse(option.detail(languageCode: "de").isEmpty)
            XCTAssertFalse(option.detail(languageCode: "en").isEmpty)
        }
        XCTAssertEqual(AppIconOption.standard.name(languageCode: "de"), "Radar und Wolke, Sektor 90° (Standard)")
        XCTAssertEqual(AppIconOption.standard.name(languageCode: "en"), "Radar and cloud, 90° sector (default)")
    }

    func testLookupFallsBackToStandard() {
        XCTAssertEqual(AppIconOption.option(forAlternateIconName: nil), .standard)
        XCTAssertEqual(AppIconOption.option(forAlternateIconName: "AltV4D").id, "V4D")
        XCTAssertEqual(AppIconOption.option(forAlternateIconName: "Unbekannt"), .standard)
    }

    func testPreviewImagesExistInBundle() {
        for option in AppIconOption.all {
            XCTAssertNotNil(UIImage(named: option.previewAssetName), option.previewAssetName)
        }
    }
}
