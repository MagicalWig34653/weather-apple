import XCTest
@testable import Weather

private func ev(_ env: String, verified: Bool = true) -> AppTransactionEvidence {
    AppTransactionEvidence(isVerified: verified, environment: env, jws: "jws")
}

final class BuildChannelTests: XCTestCase {
    private func detector(_ evidence: @escaping @Sendable () async throws -> AppTransactionEvidence,
                          debug: Bool = false, sandboxReceipt: Bool = true,
                          timeout: Duration = .milliseconds(300)) -> BuildChannelDetector {
        BuildChannelDetector(source: ClosureEvidenceSource(evidence), isDebugBuild: debug,
                             hasSandboxReceipt: { sandboxReceipt }, timeout: timeout)
    }

    func testVerifiedSandboxWithReceiptIsTestFlight() async {
        let channel = await detector { ev("Sandbox") }.detect().channel
        XCTAssertEqual(channel, .testFlight)
        XCTAssertTrue(channel.allowsDeviceLink)
    }
    func testSandboxWithoutReceiptIsUnknown() async {
        let channel = await detector({ ev("Sandbox") }, sandboxReceipt: false).detect().channel
        XCTAssertEqual(channel, .unknown)
        XCTAssertFalse(channel.allowsDeviceLink)
    }
    func testProductionIsAppStore() async {
        let channel = await detector { ev("Production") }.detect().channel
        XCTAssertEqual(channel, .appStore)
        XCTAssertFalse(channel.allowsDeviceLink)
    }
    func testProductionWithSandboxReceiptStillAppStore() async {
        let channel = await detector({ ev("Production") }, debug: true).detect().channel
        XCTAssertEqual(channel, .appStore)
    }
    func testUnverifiedIsUnknown() async {
        let channel = await detector { ev("Sandbox", verified: false) }.detect().channel
        XCTAssertEqual(channel, .unknown)
    }
    func testOfflineErrorIsUnknown() async {
        let channel = await detector { throw URLError(.notConnectedToInternet) }.detect().channel
        XCTAssertEqual(channel, .unknown)
    }
    func testTimeoutIsUnknown() async {
        let started = ContinuousClock.now
        let channel = await detector({ try await Task.sleep(for: .seconds(30)); return ev("Sandbox") },
                                     timeout: .milliseconds(80)).detect().channel
        XCTAssertEqual(channel, .unknown)
        XCTAssertLessThan(started.duration(to: .now), .seconds(5))
    }
    func testNonCancellableSourceStillTimesOut() async {
        let channel = await detector({
            await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in } // never resumes
            return ev("Sandbox")
        }, timeout: .milliseconds(80)).detect().channel
        XCTAssertEqual(channel, .unknown)
    }
    func testUnknownEnvironmentValueIsUnknown() async {
        let channel = await detector { ev("LocalTesting") }.detect().channel
        XCTAssertEqual(channel, .unknown)
    }
    func testXcodeInReleaseIsUnknown() async {
        let channel = await detector({ ev("Xcode") }, debug: false).detect().channel
        XCTAssertEqual(channel, .unknown)
        XCTAssertFalse(channel.allowsDeviceLink)
    }
    func testXcodeInDebugIsAllowed() async {
        let channel = await detector({ ev("Xcode") }, debug: true).detect().channel
        XCTAssertEqual(channel, .xcode)
        XCTAssertTrue(channel.allowsDeviceLink)
    }
    func testUnverifiedXcodeInDebugIsUnknown() async {
        let channel = await detector({ ev("Xcode", verified: false) }, debug: true).detect().channel
        XCTAssertEqual(channel, .unknown)
    }
    func testAttestationOnlyForAllowedChannel() async {
        let ok = await detector { ev("Sandbox") }.detect()
        XCTAssertEqual(ok.attestation, "jws")
        let prod = await detector { ev("Production") }.detect()
        XCTAssertNil(prod.attestation)
    }
    func testSandboxReceiptName() {
        XCTAssertTrue(BuildChannelDetector.isSandboxReceipt(URL(fileURLWithPath: "/x/StoreKit/sandboxReceipt")))
        XCTAssertFalse(BuildChannelDetector.isSandboxReceipt(URL(fileURLWithPath: "/x/StoreKit/receipt")))
        XCTAssertFalse(BuildChannelDetector.isSandboxReceipt(nil))
    }
}
