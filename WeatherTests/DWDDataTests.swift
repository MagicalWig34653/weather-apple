import XCTest
@testable import Weather

@MainActor
final class DWDDataTests: XCTestCase {
    private let reference = DWDRequest.date("2026-10-28T15:15:00Z")!

    private func fixture() throws -> Data {
        let bundle = Bundle(for: DWDDataTests.self)
        let url = bundle.url(forResource: "wms-wet-point-response", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "wms-wet-point-response", withExtension: "json")
        return try Data(contentsOf: XCTUnwrap(url))
    }

    private func modifiedFixture(_ change: (inout [[String: Any]]) -> Void) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture()) as? [String: Any])
        var features = try XCTUnwrap(object["features"] as? [[String: Any]])
        change(&features)
        object["features"] = features
        object["numberReturned"] = features.count
        return try JSONSerialization.data(withJSONObject: object)
    }

    func testWMSTimestampsAlwaysIncludeExplicitUTCDesignator() throws {
        XCTAssertEqual(DWDRequest.timestamp(reference), "2026-10-28T15:15:00.000Z")
        let url = try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 53, longitude: 10), referenceTime: reference)
        let query = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value!) })
        XCTAssertEqual(query["TIME"], "2026-10-28T15:15:00.000Z/2026-10-28T17:15:00.000Z/PT5M")
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], "2026-10-28T15:15:00.000Z")
    }

    func testRealWMSFixtureUsesAccumulationAndConvertsToHourlyRate() throws {
        let result = try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference)
        XCTAssertEqual(result.samples.count, 25)
        XCTAssertEqual(try XCTUnwrap(result.samples[0].amountMM), 1.874, accuracy: 0.000001)
        XCTAssertEqual(try XCTUnwrap(result.samples[0].rateMMPerHour), 22.488, accuracy: 0.00001)
        XCTAssertEqual(result.samples[2].amountMM, 0)
        XCTAssertEqual(result.samples.last?.date, reference.addingTimeInterval(7200))
    }

    func testOnlyValidatedUndetectMapsToZero() {
        XCTAssertEqual(DWDResponse.amount(from: -0.0009999999310821295), 0)
        XCTAssertNil(DWDResponse.amount(from: -0.002))
        XCTAssertNil(DWDResponse.amount(from: -0.0001))
        XCTAssertNil(DWDResponse.amount(from: 4_294_967))
        XCTAssertNil(DWDResponse.amount(from: .infinity))
        XCTAssertNil(DWDResponse.amount(from: .nan))
        XCTAssertNil(DWDResponse.amount(from: nil))
        XCTAssertEqual(DWDResponse.amount(from: 0), 0)
    }

    func testDifferentRunIsRejected() throws {
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference.addingTimeInterval(300), now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .mismatchedRun)
        }
    }

    func testDuplicatedTimestampIsRejectedInsteadOfHidingGap() throws {
        let data = try modifiedFixture { features in
            features[1] = features[0]
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
    }

    func testMissingStepIsRejected() throws {
        let data = try modifiedFixture { $0.remove(at: 10) }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
    }

    func testNullValuesRemainUnknownAndDoNotBecomeDryWeather() throws {
        let data = try modifiedFixture { features in
            for index in features.indices {
                var properties = features[index]["properties"] as! [String: Any]
                properties["RV_ANALYSIS"] = NSNull()
                features[index]["properties"] = properties
            }
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: data, expectedReference: reference, now: reference)) {
            XCTAssertEqual($0 as? DWDDataError, .incompleteForecast)
        }
        let partial = RainForecast(referenceTime: reference, samples: [
            RainSample(date: reference, amountMM: nil),
            RainSample(date: reference.addingTimeInterval(300), amountMM: 0)
        ])
        XCTAssertEqual(partial.summary(at: reference), "Keine verlässliche Regenaussage verfügbar")
    }

    func testStaleAndFutureRunsAreRejected() throws {
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference.addingTimeInterval(1201))) {
            XCTAssertEqual($0 as? DWDDataError, .staleData)
        }
        XCTAssertThrowsError(try DWDResponse.forecast(from: fixture(), expectedReference: reference, now: reference.addingTimeInterval(-61))) {
            XCTAssertEqual($0 as? DWDDataError, .staleData)
        }
    }

    func testIndexFindsNewestDatedRunAndIgnoresLATESTAlias() throws {
        let html = "composite_rv_LATEST.tar composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar composite_rv_20261028_1515.tar"
        let dates = try DWDRunIndex.dates(from: Data(html.utf8), now: reference)
        XCTAssertEqual(dates, [reference.addingTimeInterval(-300), reference])
        XCTAssertThrowsError(try DWDRunIndex.dates(from: Data(html.utf8), now: reference.addingTimeInterval(1201)))
        XCTAssertThrowsError(try DWDRunIndex.dates(from: Data("unrelated html".utf8), now: reference))
    }

    func testPointRequestUsesLatitudeLongitudeAxisOrderAndExplicitRun() throws {
        let url = try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 53, longitude: 10), referenceTime: reference)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        let bounds = query["BBOX"]!.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(bounds, [52.995, 9.995, 53.005, 10.005])
        XCTAssertEqual(query["CRS"], "EPSG:4326")
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], DWDRequest.timestamp(reference))
        XCTAssertThrowsError(try DWDRequest.pointURL(at: WeatherCoordinate(latitude: .nan, longitude: 10), referenceTime: reference))
        XCTAssertThrowsError(try DWDRequest.pointURL(at: WeatherCoordinate(latitude: 0, longitude: 0), referenceTime: reference))
    }

    func testTileProjectionUsesNorthWestTileAndExplicitForecastReference() {
        let url = DWDRequest.tileURL(x: 0, y: 0, z: 1, date: reference.addingTimeInterval(300), referenceTime: reference)
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value!) })
        let bounds = query["BBOX"]!.split(separator: ",").compactMap { Double($0) }
        XCTAssertEqual(bounds[0], -20_037_508.342789244, accuracy: 0.0001)
        XCTAssertEqual(bounds[1], 0, accuracy: 0.0001)
        XCTAssertEqual(bounds[2], 0, accuracy: 0.0001)
        XCTAssertEqual(bounds[3], 20_037_508.342789244, accuracy: 0.0001)
        XCTAssertEqual(query["SRS"], "EPSG:3857")
        XCTAssertEqual(query["TIME"], DWDRequest.timestamp(reference.addingTimeInterval(300)))
        XCTAssertEqual(query["DIM_REFERENCE_TIME"], DWDRequest.timestamp(reference))
    }

    func testClientCoalescesIndexAndCachesPointInMemory() async throws {
        let data = try fixture()
        let counter = RequestCounter(fixture: data)
        let fixedNow = reference
        let client = DWDClient(transport: { request in try await counter.respond(to: request) }, clock: { fixedNow })
        let coordinate = WeatherCoordinate(latitude: 53.56, longitude: 6.74)
        async let timeline = client.radarTimeline()
        async let forecast = client.forecast(at: coordinate)
        let (frames, first) = try await (timeline, forecast)
        XCTAssertEqual(frames.dates.first, reference.addingTimeInterval(-300))
        XCTAssertEqual(first.samples.count, 25)
        _ = try await client.forecast(at: coordinate)
        let requests = await counter.count
        XCTAssertEqual(requests, 2)
    }
}

private actor RequestCounter {
    let fixture: Data
    var count = 0
    init(fixture: Data) { self.fixture = fixture }

    func respond(to request: URLRequest) throws -> (Data, HTTPURLResponse) {
        count += 1
        let url = request.url!
        let data = url.host == "opendata.dwd.de"
            ? Data("composite_rv_20261028_1510.tar composite_rv_20261028_1515.tar".utf8)
            : fixture
        return (data, HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}
