import XCTest
@testable import Weather

final class SharedDeepLinkTests: XCTestCase {
    func testPlaceRoundTrip() {
        let id = UUID()
        let url = WidgetDeepLink.url(for: id)
        XCTAssertEqual(url.scheme, "showernow")
        XCTAssertEqual(url.host, "place")
        XCTAssertEqual(WidgetDeepLink.placeID(from: url), id)
    }

    func testForeignAndMalformedLinksAreRejected() {
        let id = UUID().uuidString
        let links = [
            "https://place/\(id)", "showernow://other/\(id)", "showernow://place/not-a-uuid",
            "showernow://place/", "showernow://place/\(id)/extra", "showernow://place/\(id)/",
            "showernow://user@place/\(id)", "showernow://place:80/\(id)",
            "showernow://place/\(id)?other=1", "showernow://place/\(id)#fragment"
        ]
        for link in links {
            XCTAssertNil(WidgetDeepLink.placeID(from: URL(string: link)!), link)
        }
    }
}
