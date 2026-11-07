import XCTest
@testable import Weather

final class RainActivityContractTests: XCTestCase {
    func testBackendStartPayloadDecodesWithDefaultDateStrategy() throws {
        // Exact P2 field names and reference-date epoch, with APS using its separate UNIX epoch.
        let payload = Data(#"{"aps":{"timestamp":815356800,"event":"start","attributes-type":"RainActivityAttributes","attributes":{"displayName":"","subscriptionID":"00000000-0000-0000-0000-000000000001"},"content-state":{"phase":"startsIn","eventDate":300,"intensityClass":2,"referenceTime":0,"staleDate":1200}}}"#.utf8)
        struct Envelope: Decodable {
            let aps: APS
            struct APS: Decodable {
                let attributes: RainActivityAttributes
                let content: RainActivityAttributes.ContentState
                enum CodingKeys: String, CodingKey { case attributes; case content = "content-state" }
            }
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: payload).aps
        XCTAssertEqual(decoded.attributes.displayName, "")
        XCTAssertEqual(decoded.content.phase, .startsIn)
        XCTAssertEqual(decoded.content.referenceTime.timeIntervalSince1970, 978_307_200)
        XCTAssertEqual(decoded.content.eventDate?.timeIntervalSinceReferenceDate, 300)
        XCTAssertFalse(decoded.content.isStale(at: Date(timeIntervalSinceReferenceDate: 1199)))
        XCTAssertTrue(decoded.content.isStale(at: Date(timeIntervalSinceReferenceDate: 1200)))
    }

    func testAllPhasesRoundTripAndRemainUnderPayloadLimit() throws {
        for phase in [RainActivityAttributes.Phase.startsIn, .raining, .endsIn, .dry] {
            let state = RainActivityAttributes.ContentState(phase: phase, intensityClass: 3, referenceTime: Date())
            let data = try JSONEncoder().encode(state)
            XCTAssertEqual(try JSONDecoder().decode(RainActivityAttributes.ContentState.self, from: data), state)
            XCTAssertLessThanOrEqual(data.count, 4096)
        }
    }

    func testNullEventAndMissingStaleDateStayCompatibleAndFreshnessIsBounded() throws {
        let state = try JSONDecoder().decode(RainActivityAttributes.ContentState.self,
            from: Data(#"{"phase":"dry","eventDate":null,"intensityClass":0,"referenceTime":0}"#.utf8))
        XCTAssertNil(state.eventDate)
        XCTAssertNil(state.staleDate)
        XCTAssertTrue(state.isStale(at: Date(timeIntervalSinceReferenceDate: 1200)))
        var extended = state
        extended.staleDate = Date(timeIntervalSinceReferenceDate: 99999)
        XCTAssertEqual(extended.effectiveStaleDate, Date(timeIntervalSinceReferenceDate: 1200))
    }

    func testRainingWithoutEndDateDecodesFromNullAndMissingKey() throws {
        // Backend: unsicheres Regenende -> phase raining ohne eventDate (null oder Feld fehlt).
        for json in [#"{"phase":"raining","eventDate":null,"intensityClass":2,"referenceTime":0,"staleDate":1200}"#,
                     #"{"phase":"raining","intensityClass":2,"referenceTime":0,"staleDate":1200}"#] {
            let state = try JSONDecoder().decode(RainActivityAttributes.ContentState.self, from: Data(json.utf8))
            XCTAssertEqual(state.phase, .raining)
            XCTAssertNil(state.eventDate)
            XCTAssertFalse(state.isStale(at: Date(timeIntervalSinceReferenceDate: 600)))
        }
    }

    func testUnknownPhaseFailsDecoding() {
        XCTAssertThrowsError(try JSONDecoder().decode(RainActivityAttributes.ContentState.self,
            from: Data(#"{"phase":"unknown","intensityClass":0,"referenceTime":0}"#.utf8)))
    }

    func testLocalMappingContainsOnlyIDsAndCanDisappear() throws {
        let suite = "rain-activity-contract-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let id = UUID(), attributes = RainActivityAttributes(displayName: "", subscriptionID: "sub")
        XCTAssertNil(attributes.placeID(in: defaults))
        defaults.set(["sub": id.uuidString], forKey: RainActivityAttributes.placeMappingDefaultsKey)
        XCTAssertEqual(attributes.placeID(in: defaults), id)
    }

    func testTokenBoundsAndLowercaseHex() {
        XCTAssertEqual(PushActivityWire.hex(Data([0x00, 0xAB, 0xFF])), "00abff")
        for count in [32, 64, 200] { XCTAssertTrue(PushActivityWire.isValidToken(String(repeating: "a", count: count))) }
        for count in [0, 30, 33, 202] { XCTAssertFalse(PushActivityWire.isValidToken(String(repeating: "a", count: count))) }
        XCTAssertFalse(PushActivityWire.isValidToken(String(repeating: "A", count: 32)))
        XCTAssertFalse(PushActivityWire.isValidToken(String(repeating: "g", count: 32)))
    }

    // MARK: Region payloads (Live Activity for areas)

    func testBackendRegionStartPayloadDecodesWithNewOptionalFields() throws {
        let payload = Data(#"{"aps":{"event":"start","attributes-type":"RainActivityAttributes","attributes":{"displayName":"","subscriptionID":"sub-1"},"content-state":{"eventDate":815142900.0,"intensityClass":4,"peakSharePercent":34,"phase":"startsIn","referenceTime":815142300.0,"regionRadiusKm":10,"staleDate":815143500.0,"wetSharePercent":0}}}"#.utf8)
        struct Envelope: Decodable {
            let aps: APS
            struct APS: Decodable {
                let attributes: RainActivityAttributes
                let content: RainActivityAttributes.ContentState
                enum CodingKeys: String, CodingKey { case attributes; case content = "content-state" }
            }
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: payload).aps
        XCTAssertEqual(decoded.attributes.subscriptionID, "sub-1")
        XCTAssertEqual(decoded.content.phase, .startsIn)
        XCTAssertEqual(decoded.content.intensityClass, 4)
        XCTAssertEqual(decoded.content.wetSharePercent, 0)
        XCTAssertEqual(decoded.content.peakSharePercent, 34)
        XCTAssertEqual(decoded.content.regionRadiusKm, 10)
        XCTAssertTrue(decoded.content.isRegion)
        XCTAssertEqual(decoded.content.eventDate?.timeIntervalSinceReferenceDate, 815142900)
        XCTAssertEqual(decoded.content.effectiveStaleDate.timeIntervalSinceReferenceDate, 815143500)
    }

    func testPointPayloadsWithoutRegionFieldsStillDecodeAndEncodeUnchanged() throws {
        let json = #"{"phase":"raining","eventDate":null,"intensityClass":2,"referenceTime":0,"staleDate":1200}"#
        let state = try JSONDecoder().decode(RainActivityAttributes.ContentState.self, from: Data(json.utf8))
        XCTAssertNil(state.wetSharePercent); XCTAssertNil(state.peakSharePercent); XCTAssertNil(state.regionRadiusKm)
        XCTAssertFalse(state.isRegion)
        let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as! [String: Any]
        XCTAssertEqual(Set(encoded.keys), ["phase", "intensityClass", "referenceTime", "staleDate"],
                       "point states do not gain keys (eventDate nil is omitted as before)")
        // Optional fields can be missing one by one (radius may be absent) and null is tolerated.
        for extra in [#","peakSharePercent":12"#, #","wetSharePercent":5,"regionRadiusKm":null"#] {
            let s = try JSONDecoder().decode(RainActivityAttributes.ContentState.self,
                from: Data((String(json.dropLast()) + extra + "}").utf8))
            XCTAssertTrue(s.isRegion || extra.contains("null"))
        }
    }

    func testRegionStateRoundTripsAndStaysUnderPayloadLimit() throws {
        let state = RainActivityAttributes.ContentState(phase: .endsIn, eventDate: Date(), intensityClass: 8, referenceTime: Date(),
                                                         staleDate: Date(), wetSharePercent: 100, peakSharePercent: 100, regionRadiusKm: 25)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(RainActivityAttributes.ContentState.self, from: data), state)
        XCTAssertLessThan(data.count, 400)
    }

    func testRegionCapabilityNameAndStalenessOfRegionStates() {
        XCTAssertEqual(PushActivityWire.regionCapability, "live_activity_regions")
        let state = RainActivityAttributes.ContentState(phase: .raining, intensityClass: 3, referenceTime: Date(timeIntervalSinceReferenceDate: 0),
                                                         wetSharePercent: 40)
        XCTAssertTrue(state.isStale(at: Date(timeIntervalSinceReferenceDate: 1200)), "the 20 minute bound applies to regions too")
    }
}
