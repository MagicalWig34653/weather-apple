import Foundation
#if os(iOS) && canImport(WatchConnectivity)
import WatchConnectivity
#endif

/// Wire contract for P5: applicationContext["places"] is JSON Data for [SavedPlace].
/// Each context replaces the complete list, including an empty list after deletion.
enum WatchPlacesPayload {
    static let key = "places"

    static func context(for places: [SavedPlace]) throws -> [String: Any] {
        [key: try JSONEncoder().encode(places)]
    }
}

@MainActor
protocol PhoneSessionTransport: AnyObject {
    var canSendContext: Bool { get }
    var onStateChange: (() -> Void)? { get set }
    func activate()
    func updateApplicationContext(_ context: [String: Any]) throws
}

/// Retains only the latest saved-place list. No current location, history or backend transfer.
@MainActor
final class PhoneSession {
    private let transport: (any PhoneSessionTransport)?
    private var latestPlaces: [SavedPlace]?
    private(set) var hasPendingUpdate = false

    init(transport: (any PhoneSessionTransport)?) {
        self.transport = transport
        transport?.onStateChange = { [weak self] in
            // Also resend to the newly active watch after a watch switch or installation.
            guard let self, self.latestPlaces != nil else { return }
            self.hasPendingUpdate = true
            self.flush()
        }
    }

    static func live() -> PhoneSession {
        #if os(iOS) && canImport(WatchConnectivity)
        return PhoneSession(transport: WCSession.isSupported() ? WatchSessionTransport() : nil)
        #else
        return PhoneSession(transport: nil)
        #endif
    }

    /// Called on foreground entry as well, so failed updates can be retried without polling.
    func start() {
        transport?.activate()
        flush()
    }

    func update(places: [SavedPlace]) {
        latestPlaces = places
        hasPendingUpdate = true
        flush()
    }

    private func flush() {
        guard hasPendingUpdate, let latestPlaces, let transport, transport.canSendContext else { return }
        do {
            try transport.updateApplicationContext(WatchPlacesPayload.context(for: latestPlaces))
            hasPendingUpdate = false
        } catch {
            // Keep the newest list for activation/state-change/foreground retry; no personal logs.
        }
    }
}

#if os(iOS) && canImport(WatchConnectivity)
@MainActor
private final class WatchSessionTransport: NSObject, PhoneSessionTransport, WCSessionDelegate {
    private let session = WCSession.default
    var onStateChange: (() -> Void)?

    var canSendContext: Bool {
        session.activationState == .activated && session.isPaired && session.isWatchAppInstalled
    }

    override init() {
        super.init()
        session.delegate = self
    }

    func activate() {
        if session.activationState == .notActivated { session.activate() }
    }

    func updateApplicationContext(_ context: [String: Any]) throws {
        try session.updateApplicationContext(context)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        Task { @MainActor [weak self] in self?.onStateChange?() }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.onStateChange?() }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.activate() }
    }
}
#endif
