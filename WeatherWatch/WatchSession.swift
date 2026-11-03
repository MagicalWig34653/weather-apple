import Foundation
import WatchConnectivity

/// Delegate callbacks only signal the main actor; the untyped context never crosses isolation boundaries.
@MainActor
final class WatchSession: NSObject, WCSessionDelegate {
    private let session: WCSession?
    private let store: WatchStore

    init(store: WatchStore) {
        self.store = store
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        session?.delegate = self
    }

    func start() {
        guard let session else { return }
        if session.activationState == .activated {
            receiveLatestContext()
        } else if session.activationState == .notActivated {
            session.activate()
        }
    }

    private func receiveLatestContext() {
        // receivedApplicationContext is the PHONE's last context; applicationContext is our outbound one.
        guard let session else { return }
        store.receive(placesData: session.receivedApplicationContext["places"] as? Data)
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                             error: (any Error)?) {
        let failed = error != nil || activationState != .activated
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.store.connectionFailed(failed)
            if !failed { self.receiveLatestContext() }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in
            // Read the latest snapshot, so delayed callback tasks cannot reapply an older list.
            self?.receiveLatestContext()
        }
    }
}
