import XCTest
@testable import Weather

@MainActor
final class WarnFeedTests: XCTestCase {
    private func fixture() throws -> Data {
        try Data(contentsOf: try XCTUnwrap(Bundle(for: Self.self).url(forResource: "active.200", withExtension: "json", subdirectory: "Fixtures/warn")
            ?? Bundle(for: Self.self).url(forResource: "active.200", withExtension: "json")))
    }

    private func iso(_ s: String) -> Date { ISO8601DateFormatter().date(from: s)! }

    private func warning(_ id: String, severity: Int, onset: Date, expires: Date, cells: [String]) -> ActiveWarning {
        ActiveWarning(id: id, kind: .frost, severity: severity, event: "FROST", sent: onset, onset: onset, expires: expires,
                      headline: "h", text: "t", instruction: "", lang: "de", warncellIDs: cells)
    }

    func testDecodesFixture() throws {
        let response = try ActiveWarningsResponse.decode(try fixture())
        XCTAssertEqual(response.fetchedAt, iso("2026-11-07T11:34:05Z"))
        let w = try XCTUnwrap(response.warnings.first)
        XCTAssertEqual(w.kind, .frost); XCTAssertEqual(w.severity, 1)
        XCTAssertEqual(w.expires, iso("2026-11-08T08:00:00Z"))
        XCTAssertEqual(w.warncellIDs, ["913073001", "913073002"])
        XCTAssertEqual(w.instruction, "Hinweis auf: mögliche Frostschäden.\nHandlungsempfehlungen:\nggf. Frostschutzmaßnahmen ergreifen")
    }

    func testRelevantFiltersCellsAndExpiryAndSorts() {
        let now = iso("2026-11-07T12:00:00Z")
        let later = now.addingTimeInterval(3600), earlier = now.addingTimeInterval(-3600)
        let all = [warning("a3", severity: 3, onset: later, expires: now.addingTimeInterval(7200), cells: ["1"]),
                   warning("a4", severity: 4, onset: later, expires: now.addingTimeInterval(7200), cells: ["1"]),
                   warning("b", severity: 4, onset: later, expires: now.addingTimeInterval(7200), cells: ["2"]),
                   warning("old", severity: 4, onset: earlier, expires: now, cells: ["1"]),
                   warning("a3early", severity: 3, onset: earlier, expires: now.addingTimeInterval(60), cells: ["1"])]
        XCTAssertEqual(WarnFilter.relevant(all, cells: ["1"], now: now).map(\.id), ["a4", "a3early", "a3"])
        XCTAssertEqual(WarnFilter.active(all, now: now).map(\.id), ["a4", "b", "a3early", "a3"])
        XCTAssertEqual(WarnFilter.relevant(all, cells: [], now: now), [])
    }

    func testStalenessBoundary() {
        let base = iso("2026-11-07T12:00:00Z")
        XCTAssertEqual(WarnFilter.staleness(fetchedAt: base, now: base.addingTimeInterval(1800)), .fresh)
        XCTAssertEqual(WarnFilter.staleness(fetchedAt: base, now: base.addingTimeInterval(1801)), .stale)
    }

    // MARK: Store

    private final class Recorder: @unchecked Sendable {
        var requests: [URLRequest] = []
        var fail = false
        var status = 200
        var data = Data()
    }

    private func store(_ rec: Recorder, enabled: Bool = true, language: String = "de", clock: @escaping () -> Date = Date.init,
                       cache: URL? = nil) -> WarnFeedStore {
        WarnFeedStore(isEnabled: { enabled }, url: URL(string: "https://example.test/v1/warnings/active")!, cacheURL: cache,
                      transport: { request in
                          rec.requests.append(request)
                          if rec.fail { throw URLError(.notConnectedToInternet) }
                          return (rec.data, HTTPURLResponse(url: request.url!, statusCode: rec.status, httpVersion: nil, headerFields: nil)!)
                      }, languageCode: { language }, clock: clock)
    }

    func testRefreshRequestCarriesNoLocationOrIdentifier() async throws {
        let rec = Recorder(); rec.data = try fixture()
        let feed = store(rec, language: "en")
        await feed.refresh()
        let request = try XCTUnwrap(rec.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.url?.query)
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(Set((request.allHTTPHeaderFields ?? [:]).keys), ["Accept-Language", "Accept"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "en")
        XCTAssertEqual(feed.state, .loaded)
        XCTAssertEqual(feed.warnings.count, 1)
    }

    func testNoRequestWithoutCapability() async throws {
        let rec = Recorder(); rec.data = try fixture()
        let feed = store(rec, enabled: false)
        await feed.refresh(force: true)
        XCTAssertTrue(rec.requests.isEmpty)
        XCTAssertEqual(feed.state, .idle)
    }

    func testNetworkErrorKeepsListAndSetsFailedWithCachedAt() async throws {
        let rec = Recorder(); rec.data = try fixture()
        let feed = store(rec)
        await feed.refresh()
        rec.fail = true
        await feed.refresh(force: true)
        XCTAssertEqual(feed.warnings.count, 1)
        XCTAssertEqual(feed.state, .failed(cachedAt: iso("2026-11-07T11:34:05Z")))
    }

    func testServerErrorWithoutCacheIsFailedNil() async {
        let rec = Recorder(); rec.status = 503
        let feed = store(rec)
        await feed.refresh()
        XCTAssertEqual(feed.state, .failed(cachedAt: nil))
        XCTAssertTrue(feed.warnings.isEmpty)
    }

    func testMinimumIntervalAndForce() async throws {
        let rec = Recorder(); rec.data = try fixture()
        var now = iso("2026-11-07T12:00:00Z")
        let feed = store(rec, clock: { now })
        await feed.refresh(); await feed.refresh()
        XCTAssertEqual(rec.requests.count, 1)
        await feed.refresh(force: true)
        XCTAssertEqual(rec.requests.count, 2)
        now = now.addingTimeInterval(31)
        await feed.refresh()
        XCTAssertEqual(rec.requests.count, 3)
    }

    func testCacheSurvivesRestart() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("warn-cache-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let rec = Recorder(); rec.data = try fixture()
        await store(rec, cache: url).refresh()
        let second = store(Recorder(), cache: url)
        XCTAssertEqual(second.warnings.count, 1)
        XCTAssertEqual(second.fetchedAt, iso("2026-11-07T11:34:05Z"))
    }

    func testPlaceNamesAndRelevantViaPlaceCells() async throws {
        let rec = Recorder(); rec.data = try fixture()
        let feed = WarnFeedStore(isEnabled: { true }, cacheURL: nil,
                                 transport: { r in (rec.data, HTTPURLResponse(url: r.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!) },
                                 placesProvider: { [WarnPlaceCells(name: "Anklam", cells: ["913073001"]), WarnPlaceCells(name: "Bonn", cells: ["1"])] })
        await feed.refresh()
        let now = iso("2026-11-07T12:00:00Z")
        let relevant = feed.relevantWarnings(now: now)
        XCTAssertEqual(relevant.count, 1)
        XCTAssertEqual(feed.placeNames(for: relevant[0]), ["Anklam"])
    }
}
