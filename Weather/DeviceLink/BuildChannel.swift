import Foundation
import StoreKit
import Synchronization

/// Where this installation comes from. Only `.testFlight` (and `.xcode` in Debug builds) may offer the operator device link.
/// Everything unclear is `.unknown` and treated like the App Store: nothing is shown (fail closed).
enum BuildChannel: Equatable, Sendable {
    case testFlight, xcode, appStore, unknown
    var allowsDeviceLink: Bool { self == .testFlight || self == .xcode }
}

/// What StoreKit's `AppTransaction.shared` delivered, reduced to what the decision needs.
struct AppTransactionEvidence: Equatable, Sendable {
    let isVerified: Bool
    /// `AppStore.Environment.rawValue` ("Sandbox", "Production", "Xcode").
    let environment: String
    /// `VerificationResult.jwsRepresentation`; memory only, sent solely with `link-code`.
    let jws: String
}

protocol AppTransactionEvidenceSource: Sendable {
    func evidence() async throws -> AppTransactionEvidence
}

struct ClosureEvidenceSource: AppTransactionEvidenceSource {
    let body: @Sendable () async throws -> AppTransactionEvidence
    init(_ body: @escaping @Sendable () async throws -> AppTransactionEvidence) { self.body = body }
    func evidence() async throws -> AppTransactionEvidence { try await body() }
}

/// StoreKit 2 `AppTransaction.shared` (never `refresh()`, which could show a sign-in prompt).
struct StoreKitEvidenceSource: AppTransactionEvidenceSource {
    func evidence() async throws -> AppTransactionEvidence {
        let result = try await AppTransaction.shared
        switch result {
        case .verified(let transaction):
            return AppTransactionEvidence(isVerified: true, environment: transaction.environment.rawValue,
                                          jws: result.jwsRepresentation)
        case .unverified(let transaction, _):
            return AppTransactionEvidence(isVerified: false, environment: transaction.environment.rawValue,
                                          jws: result.jwsRepresentation)
        }
    }
}

struct BuildChannelDetection: Equatable, Sendable {
    let channel: BuildChannel
    /// Only set when the channel allows the device link.
    let attestation: String?
}

/// Injectable detector. Rules: verified and `Sandbox` and a `sandboxReceipt` receipt file = TestFlight;
/// verified `Xcode` = Xcode only in Debug; verified `Production` = App Store; everything else (unverified, offline,
/// timeout, unknown value, Xcode in Release) = unknown.
struct BuildChannelDetector: Sendable {
    let source: AppTransactionEvidenceSource
    let isDebugBuild: Bool
    let hasSandboxReceipt: @Sendable () -> Bool
    let timeout: Duration

    init(source: AppTransactionEvidenceSource = StoreKitEvidenceSource(), isDebugBuild: Bool = BuildChannelDetector.debugBuild,
         hasSandboxReceipt: @escaping @Sendable () -> Bool = { BuildChannelDetector.isSandboxReceipt(Bundle.main.appStoreReceiptURL) },
         timeout: Duration = .seconds(3)) {
        self.source = source; self.isDebugBuild = isDebugBuild; self.hasSandboxReceipt = hasSandboxReceipt; self.timeout = timeout
    }

    static var debugBuild: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    static func isSandboxReceipt(_ url: URL?) -> Bool { url?.lastPathComponent == "sandboxReceipt" }

    func detect() async -> BuildChannelDetection {
        guard let evidence = await fetchWithTimeout(), evidence.isVerified else { return .init(channel: .unknown, attestation: nil) }
        let channel: BuildChannel
        switch evidence.environment {
        case "Sandbox": channel = hasSandboxReceipt() ? .testFlight : .unknown
        case "Production": channel = .appStore
        case "Xcode": channel = isDebugBuild ? .xcode : .unknown
        default: channel = .unknown
        }
        return .init(channel: channel, attestation: channel.allowsDeviceLink ? evidence.jws : nil)
    }

    /// Races the source against the timeout with unstructured tasks, so a non-cancellable StoreKit call cannot hold the result back.
    private func fetchWithTimeout() async -> AppTransactionEvidence? {
        let gate = Mutex(false)
        let source = self.source, timeout = self.timeout
        return await withCheckedContinuation { (continuation: CheckedContinuation<AppTransactionEvidence?, Never>) in
            @Sendable func finish(_ value: AppTransactionEvidence?) {
                let first = gate.withLock { done -> Bool in if done { return false }; done = true; return true }
                if first { continuation.resume(returning: value) }
            }
            Task { finish(try? await source.evidence()) }
            Task { try? await Task.sleep(for: timeout); finish(nil) }
        }
    }
}
