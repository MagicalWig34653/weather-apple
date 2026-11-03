// Portable macOS harness (no product Package.swift, no Watch UI dependencies):
// Copy Shared/**/*.swift and these exact files into Sources/WeatherWatchRadar:
// Weather/Data/{RadarBackend,RadarHistory,DWDRadarTimeline+App}.swift,
// WeatherWatch/Radar/{RadarCrop,WatchRadarStore}.swift.
// Copy this file into Tests/WeatherWatchRadarTests and define WATCH_RADAR_TESTS there.
// SwiftPM tools 6.0; macOS >=15; .testTarget depends on WeatherWatchRadar.
// swift test --disable-sandbox --package-path <temporary harness>
// The iOS WeatherTests target deliberately does not run these Watch-only tests.
#if WATCH_RADAR_TESTS
import XCTest
import CoreGraphics
@testable import WeatherWatchRadar

private let radarTestTime = Date(timeIntervalSince1970: 1_800_000_000)
private let radarTestBounds = RadarBounds(minX: 612257, minY: 5942074, maxX: 1736584, maxY: 7381298)

private func radarTestImage(edge: Int = 160) -> CGImage {
    CGContext(data: nil, width: edge, height: edge, bitsPerComponent: 8, bytesPerRow: edge * 4,
              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!.makeImage()!
}

/// A held request intentionally ignores cancellation until released, to test generation checks.
private actor RadarFixture {
    var requests: [URLRequest] = []
    var status = 200
    var payload: Data
    var badImages: Set<Int> = []
    var hold: Int?
    private var held: CheckedContinuation<Void, Never>?
    private var heldWaiter: CheckedContinuation<Void, Never>?

    init(payload: Data) { self.payload = payload }
    func configure(status: Int = 200, badImages: Set<Int> = [], hold: Int? = nil) {
        self.status = status; self.badImages = badImages; self.hold = hold
    }
    func waitForHeld() async {
        if held != nil { return }
        await withCheckedContinuation { heldWaiter = $0 }
    }
    func release() { held?.resume(); held = nil; hold = nil }
    func recorded() -> [URLRequest] { requests }
    func fetch(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        requests.append(request)
        let url = request.url!
        let isManifest = url.lastPathComponent == "latest.json"
        let index = Int(url.deletingPathExtension().lastPathComponent) ?? -1
        let responseStatus = isManifest ? status : (badImages.contains(index) ? 404 : 200)
        if index == hold {
            await withCheckedContinuation { continuation in
                held = continuation
                heldWaiter?.resume(); heldWaiter = nil
            }
        }
        return (isManifest ? payload : Data([UInt8(clamping: index)]),
                HTTPURLResponse(url: url, statusCode: responseStatus, httpVersion: nil,
                                headerFields: ["ETag": "test-run"])!)
    }
}

@MainActor
final class WatchRadarTests: XCTestCase {
    private func place(latitude: Double = 52.52, longitude: Double = 13.405, id: UUID = UUID()) -> SavedPlace {
        SavedPlace(id: id, name: "Fixture", coordinate: .init(latitude: latitude, longitude: longitude))
    }

    private func payload(step: Int = 5, count: Int = 37, width: Int = 1024,
                         reference: Date = radarTestTime) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schema": 1, "run": "20270115T0800Z",
            "reference_time": DWDRequest.timestamp(reference), "generated_at": DWDRequest.timestamp(reference),
            "step_minutes": step,
            "image": ["format": "image/webp", "width": width, "height": 1311, "projection": "EPSG:3857",
                      "bbox": [612257, 5942074, 1736584, 7381298]],
            "slots": (0..<count).map { index in
                ["time": DWDRequest.timestamp(reference.addingTimeInterval(Double(index - 12) * Double(step) * 60)),
                 "kind": index < 12 ? "analysis" : "forecast", "path": "fixture/\(index).webp"]
            },
            "attribution": "DWD", "modification_notice": "Modified"
        ])
    }

    private func model(_ fixture: RadarFixture, budget: Int = 4_000_000,
                       decode: WatchRadarStore.Decode? = nil) -> WatchRadarStore {
        WatchRadarStore(baseURL: URL(string: "https://example.invalid/v1/radar/")!,
                        transport: { try await fixture.fetch($0) },
                        decode: decode ?? { _, _, _, _ in radarTestImage() }, budget: budget,
                        clock: { radarTestTime })
    }

    func testKnownCoordinatesAndNorthDownPixelAxis() throws {
        // Independent EPSG:3857 reference values in the manifest's pixel grid.
        for (latitude, longitude, pixelX, pixelY) in [
            (52.52, 13.405, 801.457505, 443.245970),
            (48.137, 11.575, 615.920895, 1140.110928),
            (53.551, 9.994, 455.629431, 269.375824)
        ] {
            let result = try RadarCrop.layout(coordinate: .init(latitude: latitude, longitude: longitude),
                                             zoom: .local, bounds: radarTestBounds)
            XCTAssertEqual(result.pixelRect.minX + result.marker.x * result.pixelRect.width, pixelX, accuracy: 0.00001)
            XCTAssertEqual(result.pixelRect.minY + result.marker.y * result.pixelRect.height, pixelY, accuracy: 0.00001)
            XCTAssertEqual(result.imagePlacement, CGRect(x: 0, y: 0, width: 1, height: 1))
            XCTAssertEqual(result.pixelRect, result.pixelRect.integral)
        }
    }

    func testZoomAndClippedCoverageKeepViewportAndMarker() throws {
        let coordinate = WeatherCoordinate(latitude: 47.01, longitude: 5.51)
        var previousWidth: CGFloat = 0
        for zoom in RadarCrop.Zoom.allCases {
            let result = try RadarCrop.layout(coordinate: coordinate, zoom: zoom, bounds: radarTestBounds)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 1024, height: 1311).contains(result.pixelRect))
            XCTAssertEqual(result.pixelRect.minX, 0)
            XCTAssertEqual(result.pixelRect.maxY, 1311)
            XCTAssertGreaterThan(result.imagePlacement.minX, 0)
            XCTAssertLessThan(result.imagePlacement.maxY, 1)
            XCTAssertEqual(result.marker.x, 0.5, accuracy: 0.01)
            XCTAssertEqual(result.marker.y, 0.5, accuracy: 0.01)
            let width = result.viewportBounds.maxX - result.viewportBounds.minX
            XCTAssertGreaterThan(width, previousWidth)
            previousWidth = width
        }
    }

    func testOutsideAndInvalidCoordinatesOrGeometry() {
        for coordinate in [WeatherCoordinate(latitude: 40, longitude: 10), .init(latitude: 52, longitude: 20)] {
            XCTAssertThrowsError(try RadarCrop.layout(coordinate: coordinate, zoom: .local, bounds: radarTestBounds)) {
                XCTAssertEqual($0 as? RadarCrop.Failure, .outsideCoverage)
            }
        }
        for coordinate in [WeatherCoordinate(latitude: .nan, longitude: 10), .init(latitude: 90, longitude: 10),
                           .init(latitude: 52, longitude: .infinity)] {
            XCTAssertThrowsError(try RadarCrop.layout(coordinate: coordinate, zoom: .local, bounds: radarTestBounds))
        }
        XCTAssertThrowsError(try RadarCrop.layout(coordinate: .init(latitude: 52, longitude: 10), zoom: .local,
                                                bounds: RadarBounds(minX: 1, minY: 1, maxX: 0, maxY: 0)))
    }

    func testCrownMappingClampsRoundsAndContains37Dates() {
        let dates = WatchRadarSlots.dates(reference: radarTestTime)
        XCTAssertEqual(dates.count, 37)
        XCTAssertEqual(dates.first, radarTestTime.addingTimeInterval(-3600))
        XCTAssertEqual(dates.last, radarTestTime.addingTimeInterval(7200))
        for (index, date) in dates.enumerated() {
            XCTAssertEqual(WatchRadarSlots.index(for: date, reference: radarTestTime), index)
        }
        XCTAssertEqual(WatchRadarSlots.index(for: radarTestTime.addingTimeInterval(151), reference: radarTestTime), 13)
        XCTAssertEqual(WatchRadarSlots.index(for: .distantPast, reference: radarTestTime), 0)
        XCTAssertEqual(WatchRadarSlots.index(for: .distantFuture, reference: radarTestTime), 36)
        XCTAssertEqual(Array(WatchRadarSlots.priority(selected: 12, lowPower: false).prefix(5)), [12, 11, 13, 10, 14])
        XCTAssertEqual(WatchRadarSlots.priority(selected: 36, lowPower: true), [36, 35, 34])
    }

    func testIdleLoadingReadyAllSlotsPrivacyAndRAMBudget() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture)
        XCTAssertEqual(store.state, .idle)
        store.load(place: place(), lowPower: false)
        XCTAssertEqual(store.state, .loading)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        XCTAssertFalse(store.isStale)
        XCTAssertFalse(store.isLoadingSlots)
        XCTAssertEqual(store.loadedSlotIndices.count, 37)
        XCTAssertLessThanOrEqual(store.cachedBytes, 4_000_000)
        XCTAssertEqual(store.selectedTime, radarTestTime)
        let requests = await fixture.recorded()
        XCTAssertEqual(requests.count, 38)
        XCTAssertEqual(requests[0].url?.lastPathComponent, "latest.json")
        XCTAssertEqual(requests[1].url?.lastPathComponent, "12.webp")
        XCTAssertFalse(requests.contains { $0.url?.lastPathComponent == "history.json" })
        for request in requests {
            XCTAssertEqual(request.url?.host, "example.invalid")
            XCTAssertNil(request.url?.query)
            XCTAssertNil(request.httpBody)
            XCTAssertFalse(request.httpShouldHandleCookies)
            XCTAssertEqual(Set(request.allHTTPHeaderFields?.keys.map { $0.lowercased() } ?? []), ["accept"])
        }
        store.select(index: 100)
        XCTAssertEqual(store.selectedIndex, 36)
        XCTAssertEqual(store.state, .ready)
        store.select(time: radarTestTime)
        XCTAssertEqual(store.selectedIndex, 12)
        XCTAssertNotNil(store.selectedImage)
        store.stop()
        XCTAssertEqual(store.state, .idle)
    }

    func testReopenWithinFiveMinutesUsesRAMAndManualRefreshUsesETag() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture), saved = place()
        store.load(place: saved, lowPower: false)
        await store.waitUntilFinished()
        store.stop()
        store.load(place: saved, lowPower: false)
        await store.waitUntilFinished()
        let reused = await fixture.recorded()
        XCTAssertEqual(reused.count, 38)
        store.load(place: saved, forceRefresh: true, lowPower: false)
        await store.waitUntilFinished()
        let refreshed = await fixture.recorded()
        XCTAssertEqual(refreshed.count, 39)
        XCTAssertEqual(refreshed.last?.value(forHTTPHeaderField: "If-None-Match"), "test-run")
    }

    func testLowPowerSelectionLoadsOnlyNeighborhoodAndRetargets() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture)
        store.load(place: place(), lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.loadedSlotIndices, [10, 11, 12, 13, 14])
        store.select(index: 30)
        await store.waitUntilFinished()
        XCTAssertTrue(store.loadedSlotIndices.isSuperset(of: [28, 29, 30, 31, 32]))
        XCTAssertEqual(store.state, .ready)
        let requests = await fixture.recorded()
        XCTAssertEqual(requests.filter { $0.url?.lastPathComponent == "latest.json" }.count, 1)
    }

    func testSelectionWhileCurrentLoadsChangesNextPriority() async throws {
        let fixture = RadarFixture(payload: try payload())
        await fixture.configure(hold: 12)
        let store = model(fixture)
        store.load(place: place(), lowPower: false)
        await fixture.waitForHeld()
        store.select(index: 30)
        await fixture.release()
        await store.waitUntilFinished()
        let images = await fixture.recorded().dropFirst().map { $0.url!.lastPathComponent }
        XCTAssertEqual(images.first, "12.webp")
        XCTAssertEqual(Set(images.dropFirst().prefix(2)), ["30.webp", "29.webp"])
        XCTAssertEqual(store.selectedIndex, 30)
        XCTAssertEqual(store.state, .ready)
    }

    func testLateOldLocationCannotPublishAfterRestart() async throws {
        let fixture = RadarFixture(payload: try payload())
        await fixture.configure(hold: 12)
        let store = model(fixture)
        store.load(place: place(), lowPower: false)
        await fixture.waitForHeld()
        let replacement = place(latitude: 48.137, longitude: 11.575)
        // Outside coverage makes the new generation fail before requesting an image.
        let outside = place(latitude: 40, longitude: 10, id: replacement.id)
        store.load(place: outside, lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .failed(.outsideCoverage))
        await fixture.release()
        // The old task is deliberately uncancellable at transport level. A new load must still win.
        store.load(place: replacement, lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.placeID, replacement.id)
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(store.layout, try RadarCrop.layout(coordinate: replacement.coordinate, zoom: .local, bounds: radarTestBounds))
    }

    func testStopPreventsLateFrameAndNeverStartsPrefetch() async throws {
        let fixture = RadarFixture(payload: try payload())
        await fixture.configure(hold: 12)
        let store = model(fixture)
        store.load(place: place(), lowPower: false)
        await fixture.waitForHeld()
        store.stop()
        await fixture.release()
        // Actor barrier guarantees the held fetch has resumed; the generation guard protects publication.
        _ = await fixture.recorded()
        XCTAssertEqual(store.state, .idle)
        XCTAssertTrue(store.loadedSlotIndices.isEmpty)
    }

    func testBackend404MalformedManifestAndWrongGridFailWithoutFallback() async throws {
        for (data, status, failure) in [
            (try payload(), 404, WatchRadarStore.Failure.backend(.notPublished)),
            (Data("bad-json".utf8), 200, .backend(.invalid)),
            (try payload(step: 10), 200, .invalidManifest),
            (try payload(width: 1000), 200, .invalidManifest),
            (try payload(reference: radarTestTime.addingTimeInterval(-1200)), 200, .backend(.stale))
        ] {
            let fixture = RadarFixture(payload: data)
            await fixture.configure(status: status)
            let store = model(fixture)
            store.load(place: place(), lowPower: false)
            await store.waitUntilFinished()
            XCTAssertEqual(store.state, .failed(failure))
            XCTAssertTrue(store.loadedSlotIndices.isEmpty)
            let requests = await fixture.recorded()
            XCTAssertEqual(requests.count, 1)
        }
    }

    func testGapInBackendSlotsKeepsAxisAndMarksOnlyTheGap() async throws {
        // The live backend omitted one analysis (20:50 for a 21:00 run): 36 slots, fixed 37-slot axis.
        var json = try JSONSerialization.jsonObject(with: payload()) as! [String: Any]
        var slots = json["slots"] as! [[String: Any]]
        slots.remove(at: 10)
        json["slots"] = slots
        let fixture = RadarFixture(payload: try JSONSerialization.data(withJSONObject: json))
        let store = model(fixture), saved = place()
        store.load(place: saved, lowPower: false)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        XCTAssertEqual(store.slots.count, 37)
        XCTAssertNil(store.slots[10])
        XCTAssertNotNil(store.slots[12])
        XCTAssertEqual(store.slotFailures[10], .invalidManifest)
        XCTAssertEqual(store.loadedSlotIndices.count, 36)
        XCTAssertEqual(store.selectedTime, radarTestTime)
    }

    func testReferenceSlotMayBeAnalysisAndFailureSurvivesCrownChanges() async throws {
        var json = try JSONSerialization.jsonObject(with: payload()) as! [String: Any]
        var slots = json["slots"] as! [[String: Any]]
        slots[12]["kind"] = "analysis" // The existing backend fixture uses analysis at reference_time.
        json["slots"] = slots
        let fixture = RadarFixture(payload: try JSONSerialization.data(withJSONObject: json))
        let store = model(fixture), saved = place()
        store.load(place: saved, lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        await fixture.configure(status: 503)
        store.load(place: saved, forceRefresh: true, lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .failed(.backend(.unreachable)))
        store.select(index: 14)
        store.updateFreshness()
        XCTAssertEqual(store.state, .failed(.backend(.unreachable)))
        XCTAssertTrue(store.loadedSlotIndices.isEmpty)
        await fixture.configure()
        store.load(place: saved, lowPower: true)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        let requests = await fixture.recorded()
        XCTAssertEqual(requests.filter { $0.url?.lastPathComponent == "latest.json" }.count, 3)
    }

    func testCurrentImageFailureAndDecodeFailure() async throws {
        let fixture = RadarFixture(payload: try payload())
        await fixture.configure(badImages: [12])
        let store = model(fixture)
        store.load(place: place(), lowPower: false)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .failed(.backend(.notPublished)))
        let decodeFixture = RadarFixture(payload: try payload())
        let badDecode = model(decodeFixture, decode: { _, _, _, _ in throw RadarCrop.Failure.invalidImage })
        badDecode.load(place: place(), lowPower: false)
        await badDecode.waitUntilFinished()
        XCTAssertEqual(badDecode.state, .failed(.invalidImage))
        XCTAssertTrue(badDecode.loadedSlotIndices.isEmpty)
    }

    func testIndividualSlotFailureIsVisibleAndOtherFramesRemainUsable() async throws {
        let fixture = RadarFixture(payload: try payload())
        await fixture.configure(badImages: [14])
        let store = model(fixture)
        store.load(place: place(), lowPower: false)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        store.select(index: 14)
        XCTAssertEqual(store.state, .failed(.backend(.notPublished)))
        XCTAssertNil(store.selectedImage)
        store.select(index: 12)
        XCTAssertEqual(store.state, .ready)
    }

    func testFreshnessInclusiveBoundaryAndFutureRuns() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture)
        store.load(place: place(), lowPower: true)
        await store.waitUntilFinished()
        store.updateFreshness(at: radarTestTime.addingTimeInterval(1199))
        XCTAssertFalse(store.isStale)
        store.updateFreshness(at: radarTestTime.addingTimeInterval(1200))
        XCTAssertTrue(store.isStale)
        XCTAssertEqual(store.state, .failed(.backend(.stale)))
        XCTAssertTrue(WatchRadarSlots.isStale(store.manifest!, at: radarTestTime.addingTimeInterval(-61)))
    }

    func testLRUEvictionProtectsSelectionAndUsesDecodedCost() {
        let image = radarTestImage(), cost = image.bytesPerRow * image.height
        var cache = WatchRadarFrameCache(budget: cost * 2)
        XCTAssertTrue(cache.insert(image, at: 12, protecting: 12))
        XCTAssertTrue(cache.insert(image, at: 11, protecting: 12))
        _ = cache.image(at: 11)
        XCTAssertTrue(cache.insert(image, at: 13, protecting: 12))
        XCTAssertEqual(cache.indices, [12, 13])
        XCTAssertEqual(cache.bytes, cost * 2)
        XCTAssertFalse(cache.insert(radarTestImage(edge: 400), at: 14, protecting: 12))
        XCTAssertEqual(cache.indices, [12, 13])
        var normal = WatchRadarFrameCache()
        for index in 0..<37 { XCTAssertTrue(normal.insert(image, at: index, protecting: 12)) }
        XCTAssertEqual(normal.indices.count, 37)
        XCTAssertLessThanOrEqual(normal.bytes, 4_000_000)
    }

    func testInsufficientBudgetFailsExplicitly() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture, budget: 1)
        store.load(place: place(), lowPower: false)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .failed(.memoryBudget))
        XCTAssertEqual(store.cachedBytes, 0)
    }

    func testRealWebPDecodeCopiesBoundedCropAndPreservesNorthSouth() throws {
        // Synthetic 1024x1311 lossless WebP: northern 655 rows red, southern 656 blue.
        // Generated locally with cwebp, no network/service or real location data required.
        let webp = Data(base64Encoded: "UklGRl4AAABXRUJQVlA4TFIAAAAv/4NHAQ8Q87//8x8OCAQh/D9tBUX0P8t//vOf//znP//5z3/+85///Oc///nPf/7zn/+THP7zn//85z//+c9//vOf//znP//5z3/+85///L8E")!
        for (latitude, longitude, channel) in [(52.52, 13.405, 0), (48.137, 11.575, 2)] {
            let layout = try RadarCrop.layout(coordinate: .init(latitude: latitude, longitude: longitude),
                                              zoom: .local, bounds: radarTestBounds)
            let image = try RadarCrop.decode(webp, layout: layout)
            XCTAssertLessThanOrEqual(image.width, 160)
            XCTAssertLessThanOrEqual(image.height, 160)
            XCTAssertLessThanOrEqual(image.bytesPerRow * image.height, 160 * 160 * 4)
            let bytes = image.dataProvider!.data! as Data
            XCTAssertEqual(bytes[channel], 255)
            XCTAssertEqual(bytes[2 - channel], 0)
        }
        let full = RadarCrop.Layout(pixelRect: CGRect(x: 0, y: 0, width: 1024, height: 1311),
                                    viewportBounds: radarTestBounds, imageBounds: radarTestBounds,
                                    marker: CGPoint(x: 0.5, y: 0.5),
                                    imagePlacement: CGRect(x: 0, y: 0, width: 1, height: 1))
        let image = try RadarCrop.decode(webp, layout: full)
        let bytes = image.dataProvider!.data! as Data
        XCTAssertEqual(bytes[0], 255) // North remains at the top.
        XCTAssertEqual(bytes[(image.height - 1) * image.bytesPerRow + 2], 255)
        XCTAssertThrowsError(try RadarCrop.decode(webp, layout: full, width: 1000))
    }

    func testEvictedSelectionReloadsAndTransportFailureHasNoFallback() async throws {
        let fixture = RadarFixture(payload: try payload())
        let store = model(fixture, budget: 2 * 160 * 160 * 4)
        store.load(place: place(), lowPower: false)
        await store.waitUntilFinished()
        XCTAssertEqual(store.loadedSlotIndices.count, 2)
        let missing = (0..<37).first { !store.loadedSlotIndices.contains($0) }!
        store.select(index: missing)
        await store.waitUntilFinished()
        XCTAssertEqual(store.state, .ready)
        XCTAssertTrue(store.loadedSlotIndices.contains(missing))
        let unavailable = WatchRadarStore(transport: { _ in throw URLError(.notConnectedToInternet) },
                                          clock: { radarTestTime })
        unavailable.load(place: place(), lowPower: false)
        await unavailable.waitUntilFinished()
        XCTAssertEqual(unavailable.state, .failed(.backend(.unreachable)))
        XCTAssertTrue(unavailable.slots.isEmpty)
    }

    func testDecoderRejectsEmptyNonWebPAndOversizedPayload() throws {
        let layout = try RadarCrop.layout(coordinate: .init(latitude: 52.52, longitude: 13.405), zoom: .local, bounds: radarTestBounds)
        for data in [Data(), Data("invalid".utf8), Data(repeating: 0, count: RadarBackendConfig.maximumImageBytes + 1)] {
            XCTAssertThrowsError(try RadarCrop.decode(data, layout: layout)) {
                XCTAssertEqual($0 as? RadarCrop.Failure, .invalidImage)
            }
        }
    }
}

/// watchOS ImageIO cannot decode WebP; the software decoder must match ImageIO (macOS) exactly.
final class WebPLosslessDecoderTests: XCTestCase {
    private let fixture = Data(base64Encoded: "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")!

    func testMatchesImageIOOnRealRadarFrame() throws {
        let crop = CGRect(x: 600, y: 400, width: 160, height: 150)
        let soft = try WebPLosslessDecoder.decodeCropped(fixture, expectedWidth: 1024, expectedHeight: 1311, crop: crop)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(fixture as CFData, nil))
        let reference = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil)?.cropping(to: crop))
        func rgba(_ image: CGImage) -> [UInt8] {
            var out = [UInt8](repeating: 0, count: image.width * image.height * 4)
            out.withUnsafeMutableBytes { raw in
                let context = CGContext(data: raw.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8,
                                        bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return out
        }
        XCTAssertEqual(rgba(soft), rgba(reference))
    }

    func testCorruptAndTruncatedInputFailsWithoutCrash() {
        let crop = CGRect(x: 0, y: 0, width: 1024, height: 1311)
        for length in [0, 12, 25, 40, 500, fixture.count - 1] {
            XCTAssertThrowsError(try WebPLosslessDecoder.decodeCropped(fixture.prefix(length), expectedWidth: 1024,
                                                                       expectedHeight: 1311, crop: crop), "\(length)")
        }
        var flipped = fixture
        for index in stride(from: 60, to: flipped.count, by: 97) { flipped[index] ^= 0x5A }
        _ = try? WebPLosslessDecoder.decodeCropped(flipped, expectedWidth: 1024, expectedHeight: 1311, crop: crop)
        XCTAssertThrowsError(try WebPLosslessDecoder.decodeCropped(fixture, expectedWidth: 512, expectedHeight: 1311, crop: crop))
    }
}
#endif
