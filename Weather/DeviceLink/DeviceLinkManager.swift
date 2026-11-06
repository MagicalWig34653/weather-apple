import Foundation
import Observation

enum DeviceLinkPhase: Equatable, Sendable {
    /// Not offered (App Store, unclear channel, capability missing): the section is not part of the view hierarchy.
    case hidden
    case off
    case requesting
    case codeOpen(code: String, expiresAt: Date)
    /// `expiresAt == nil`: permanent until revoked.
    case linked(since: Date?, expiresAt: Date?)
}

enum DeviceLinkNotice: Equatable, Sendable {
    case linkFull, rateLimited(retryAfter: Int?), needsPush, offline, failed, codeExpired
}

/// Opt-in of the operator device link (TestFlight only). All link routes are called from here and nowhere else;
/// nothing is called unless `BuildChannel` allows it, except the cleanup `DELETE` after a verified switch to the App Store.
/// The `app_transaction` JWS lives only in a local variable of `setEnabled`.
@MainActor @Observable
final class DeviceLinkManager {
    static let markerKey = "deviceLink.mayBeLinked.v1"
    static let pollInterval: Duration = .seconds(3)
    static let maxPolls = 200 // 10 minutes

    private(set) var phase: DeviceLinkPhase = .hidden
    private(set) var notice: DeviceLinkNotice?
    var isAvailable: Bool { phase != .hidden }
    /// Local marker: a code was requested or a link exists here. Only set in sessions where the link was offered.
    var mayBeLinked: Bool { defaults.bool(forKey: Self.markerKey) }

    @ObservationIgnored private let detector: BuildChannelDetector
    @ObservationIgnored private let gateway: DeviceLinkGateway
    @ObservationIgnored private let secrets: PushSecretStore
    @ObservationIgnored private let capabilities: @Sendable () async throws -> Set<String>
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void

    init(detector: BuildChannelDetector, gateway: DeviceLinkGateway, secrets: PushSecretStore,
         capabilities: @escaping @Sendable () async throws -> Set<String>, defaults: UserDefaults = .standard,
         now: @escaping @Sendable () -> Date = { Date() },
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.detector = detector; self.gateway = gateway; self.secrets = secrets; self.capabilities = capabilities
        self.defaults = defaults; self.now = now; self.sleep = sleep
    }

    static func live(secrets: PushSecretStore = KeychainPushSecretStore()) -> DeviceLinkManager {
        let gateway = HTTPPushGateway()
        return DeviceLinkManager(detector: BuildChannelDetector(source: debugSource() ?? StoreKitEvidenceSource()),
                                 gateway: gateway, secrets: secrets, capabilities: { try await gateway.capabilities() })
    }

    /// UI tests only (Debug builds): `-UITestBuildChannel production|testFlight` replaces StoreKit. Does not exist in Release.
    private static func debugSource() -> AppTransactionEvidenceSource? {
        #if DEBUG
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestBuildChannel"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        let environment = CommandLine.arguments[index + 1] == "testFlight" ? "Xcode" : "Production"
        return ClosureEvidenceSource { AppTransactionEvidence(isVerified: true, environment: environment, jws: "ui-test") }
        #else
        return nil
        #endif
    }

    // MARK: Lifecycle

    /// At launch, when the app becomes active and when the info sheet opens.
    func refresh() async {
        let detection = await detector.detect()
        guard detection.channel.allowsDeviceLink else {
            phase = .hidden
            // Only a verified switch to the App Store removes an existing link; unclear results change nothing.
            if detection.channel == .appStore, mayBeLinked { await cleanup() }
            return
        }
        guard let offered = try? await capabilities(), offered.contains(DeviceLinkWire.capability) else {
            phase = .hidden // fail closed
            return
        }
        guard let identity = secrets.load() else { if phase == .hidden { phase = .off }; return }
        do {
            let status = try await gateway.status(identity)
            switch status.state {
            case .linked:
                defaults.set(true, forKey: Self.markerKey)
                phase = .linked(since: status.linkedAt, expiresAt: status.expiresAt)
            case .none, .codeOpen:
                // The code is shown once; a code open on the server without a local one is replaced by the next request.
                if case .codeOpen = phase { break }
                defaults.set(false, forKey: Self.markerKey)
                phase = .off
            }
        } catch DeviceLinkError.disabled { phase = .hidden }
        catch DeviceLinkError.unauthorized { if phase == .hidden { phase = .off } }
        catch { if phase == .hidden { phase = .off } }
    }

    private func cleanup() async {
        guard let identity = secrets.load() else { defaults.set(false, forKey: Self.markerKey); return }
        do { try await gateway.unlink(identity); defaults.set(false, forKey: Self.markerKey) }
        catch DeviceLinkError.unauthorized { defaults.set(false, forKey: Self.markerKey) }
        catch DeviceLinkError.disabled { defaults.set(false, forKey: Self.markerKey) }
        catch {} // marker stays; next start tries again
    }

    // MARK: Switch

    func setEnabled(_ on: Bool) async {
        notice = nil
        if on { await enable() } else { await disable() }
    }

    private func enable() async {
        switch phase {
        case .off: break
        default: return
        }
        guard let identity = secrets.load() else { notice = .needsPush; return }
        phase = .requesting
        let detection = await detector.detect() // fresh evidence; the JWS never leaves this scope
        guard detection.channel.allowsDeviceLink, let attestation = detection.attestation else { phase = .hidden; return }
        do {
            let code = try await gateway.requestCode(identity, appTransaction: attestation)
            defaults.set(true, forKey: Self.markerKey)
            phase = .codeOpen(code: code.code, expiresAt: code.expiresAt)
        } catch let error as DeviceLinkError {
            switch error {
            case .notTestFlight, .disabled: phase = .hidden
            case .alreadyLinked:
                phase = .off
                await refresh()
            case .linkFull: phase = .off; notice = .linkFull
            case .rateLimited(let after): phase = .off; notice = .rateLimited(retryAfter: after)
            case .unauthorized: phase = .off; notice = .needsPush
            case .offline: phase = .off; notice = .offline
            default: phase = .off; notice = .failed
            }
        } catch { phase = .off; notice = .failed }
    }

    private func disable() async {
        switch phase {
        case .codeOpen, .linked, .off: break
        default: return
        }
        guard let identity = secrets.load() else { phase = .off; defaults.set(false, forKey: Self.markerKey); return }
        do {
            try await gateway.unlink(identity)
            defaults.set(false, forKey: Self.markerKey)
            phase = .off
        } catch DeviceLinkError.unauthorized {
            defaults.set(false, forKey: Self.markerKey); phase = .off
        } catch DeviceLinkError.offline { notice = .offline }
        catch { notice = .failed }
    }

    // MARK: Code screen

    /// Polls `GET .../link` every 3 s while a code is shown, at most 10 minutes.
    func runPolling() async {
        var polls = 0
        while case .codeOpen = phase, !Task.isCancelled {
            guard polls < Self.maxPolls else { phase = .off; notice = .codeExpired; return }
            do { try await sleep(Self.pollInterval) } catch { return }
            polls += 1
            expireIfNeeded()
            guard case .codeOpen = phase, let identity = secrets.load() else { return }
            guard let status = try? await gateway.status(identity) else { continue }
            if status.state == .linked {
                defaults.set(true, forKey: Self.markerKey)
                phase = .linked(since: status.linkedAt, expiresAt: status.expiresAt)
                return
            }
        }
    }

    func expireIfNeeded(now: Date? = nil) {
        if case .codeOpen(_, let expiresAt) = phase, (now ?? self.now()) >= expiresAt {
            phase = .off
            notice = .codeExpired
        }
    }
}
