import Foundation
import Observation

enum DeviceLinkPhase: Equatable, Sendable {
    /// Not offered (no open operator pairing window and not linked, feature off): the section is not part of the view hierarchy.
    case hidden
    case off
    case requesting
    case codeOpen(code: String, expiresAt: Date)
    /// `expiresAt == nil`: permanent until revoked.
    case linked(since: Date?, expiresAt: Date?)
}

enum DeviceLinkNotice: Equatable, Sendable {
    case linkFull, rateLimited(retryAfter: Int?), needsPush, offline, failed, codeExpired, pairingClosed
}

/// Opt-in of the operator device link, independent of the installation source. The section is offered only while the operator
/// has an open pairing window (`device_link_window` of `GET /v1/status`, `ends_at` in the future) or the device is already linked.
/// All link routes are called from here and nowhere else. Errors and offline never reveal the section (fail closed) and change nothing.
@MainActor @Observable
final class DeviceLinkManager {
    static let pollInterval: Duration = .seconds(3)
    static let maxPolls = 200 // 10 minutes
    /// While the info sheet is open and a window runs.
    static let windowPollInterval: Duration = .seconds(15)
    static let maxWindowPolls = 80 // windows last at most 15 minutes

    private(set) var phase: DeviceLinkPhase = .hidden
    private(set) var notice: DeviceLinkNotice?
    /// End of the operator window as last reported by the server; `nil` = none known.
    private(set) var windowEndsAt: Date?
    var isAvailable: Bool { phase != .hidden }

    @ObservationIgnored private let gateway: DeviceLinkGateway
    @ObservationIgnored private let secrets: PushSecretStore
    @ObservationIgnored private let serverStatus: @Sendable () async throws -> PushServerStatus
    @ObservationIgnored private let now: @Sendable () -> Date
    @ObservationIgnored private let sleep: @Sendable (Duration) async throws -> Void
    @ObservationIgnored private var inflight: Task<Void, Never>?

    init(gateway: DeviceLinkGateway, secrets: PushSecretStore,
         serverStatus: @escaping @Sendable () async throws -> PushServerStatus,
         now: @escaping @Sendable () -> Date = { Date() },
         sleep: @escaping @Sendable (Duration) async throws -> Void = { try await Task.sleep(for: $0) }) {
        self.gateway = gateway; self.secrets = secrets; self.serverStatus = serverStatus; self.now = now; self.sleep = sleep
    }

    static func live(secrets: PushSecretStore = KeychainPushSecretStore()) -> DeviceLinkManager {
        let gateway = HTTPPushGateway()
        #if DEBUG
        if let window = debugWindow() {
            return DeviceLinkManager(gateway: DebugLinkGateway(), secrets: secrets, serverStatus: {
                PushServerStatus(capabilities: [DeviceLinkWire.capability], deviceLinkWindowEndsAt: window ? Date().addingTimeInterval(600) : nil)
            })
        }
        #endif
        return DeviceLinkManager(gateway: gateway, secrets: secrets, serverStatus: { try await gateway.serverStatus() })
    }

    #if DEBUG
    /// UI tests only (Debug builds): `-UITestDeviceLinkWindow open|closed` simulates the server window without network.
    private static func debugWindow() -> Bool? {
        guard let index = CommandLine.arguments.firstIndex(of: "-UITestDeviceLinkWindow"),
              CommandLine.arguments.indices.contains(index + 1) else { return nil }
        return CommandLine.arguments[index + 1] == "open"
    }
    #endif

    // MARK: Lifecycle

    /// At launch, when the app becomes active and when the info sheet opens. Concurrent calls share one run.
    func refresh() async {
        if let running = inflight { await running.value; return }
        let task = Task { await performRefresh() }
        inflight = task
        await task.value
        inflight = nil
    }

    /// While the info sheet is open and a window runs: asks again every 15 s until `ends_at`. No polling otherwise.
    func runWindowPolling() async {
        var polls = 0
        while !Task.isCancelled, let end = windowEndsAt, now() < end, polls < Self.maxWindowPolls {
            do { try await sleep(Self.windowPollInterval) } catch { return }
            polls += 1
            await refresh()
        }
    }

    private var windowIsOpen: Bool { windowEndsAt.map { $0 > now() } ?? false }

    private func performRefresh() async {
        let status: PushServerStatus
        do { status = try await serverStatus() }
        catch {
            // Offline or error: change nothing, except that the window cannot outlive its own end.
            hideIfWindowOver()
            return
        }
        guard status.capabilities.contains(DeviceLinkWire.capability) else {
            windowEndsAt = nil
            if case .codeOpen = phase {} else { phase = .hidden }
            return
        }
        windowEndsAt = status.deviceLinkWindowEndsAt
        var linked: DeviceLinkPhase?
        if let identity = secrets.load() {
            do {
                let link = try await gateway.status(identity)
                if link.state == .linked { linked = .linked(since: link.linkedAt, expiresAt: link.expiresAt) }
            } catch DeviceLinkError.disabled {
                windowEndsAt = nil; phase = .hidden; return
            } catch {
                // Unknown link state: keep what is shown if it is a link or code.
                switch phase {
                case .linked, .codeOpen, .requesting: hideIfWindowOver(); return
                default: break
                }
            }
        }
        if let linked { phase = linked; return }
        switch phase {
        case .codeOpen, .requesting: return // an open code stays redeemable until it expires, also after the window ends
        case .linked: phase = windowIsOpen ? .off : .hidden // revoked elsewhere
        default: phase = windowIsOpen ? .off : .hidden
        }
    }

    private func hideIfWindowOver() {
        if phase == .off, !windowIsOpen { phase = .hidden }
    }

    // MARK: Switch

    func setEnabled(_ on: Bool) async {
        notice = nil
        if on { await enable() } else { await disable() }
    }

    private func enable() async {
        guard phase == .off else { return }
        guard let identity = secrets.load() else { notice = .needsPush; return }
        phase = .requesting
        do {
            let code = try await gateway.requestCode(identity)
            phase = .codeOpen(code: code.code, expiresAt: code.expiresAt)
        } catch let error as DeviceLinkError {
            switch error {
            case .pairingClosed: phase = .off; notice = .pairingClosed; windowEndsAt = nil
            case .disabled: phase = .hidden
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
        guard let identity = secrets.load() else { phase = windowIsOpen ? .off : .hidden; return }
        do {
            try await gateway.unlink(identity)
            phase = windowIsOpen ? .off : .hidden
        } catch DeviceLinkError.unauthorized {
            phase = windowIsOpen ? .off : .hidden
        } catch DeviceLinkError.offline { notice = .offline }
        catch { notice = .failed }
    }

    // MARK: Code screen

    /// Polls `GET .../link` every 3 s while a code is shown, at most 10 minutes.
    func runPolling() async {
        var polls = 0
        while case .codeOpen = phase, !Task.isCancelled {
            guard polls < Self.maxPolls else { phase = windowIsOpen ? .off : .hidden; notice = .codeExpired; return }
            do { try await sleep(Self.pollInterval) } catch { return }
            polls += 1
            expireIfNeeded()
            guard case .codeOpen = phase, let identity = secrets.load() else { return }
            guard let status = try? await gateway.status(identity) else { continue }
            if status.state == .linked {
                phase = .linked(since: status.linkedAt, expiresAt: status.expiresAt)
                return
            }
        }
    }

    func expireIfNeeded(now: Date? = nil) {
        if case .codeOpen(_, let expiresAt) = phase, (now ?? self.now()) >= expiresAt {
            phase = windowIsOpen ? .off : .hidden
            notice = .codeExpired
        }
    }
}

#if DEBUG
/// UI tests only: no network, nothing linked, codes are issued locally.
struct DebugLinkGateway: DeviceLinkGateway {
    func requestCode(_ identity: PushIdentity) async throws -> DeviceLinkCode {
        DeviceLinkCode(code: "TEST-CODE", expiresAt: Date().addingTimeInterval(600))
    }
    func status(_ identity: PushIdentity) async throws -> DeviceLinkStatus {
        DeviceLinkStatus(state: .none, codeExpiresAt: nil, linkedAt: nil, expiresAt: nil)
    }
    func unlink(_ identity: PushIdentity) async throws {}
}
#endif
