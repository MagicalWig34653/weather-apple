import Foundation
import Security

/// Storage of the installation identity (ID and secret). The device token is never stored.
protocol PushSecretStore: Sendable {
    func load() -> PushIdentity?
    func save(_ identity: PushIdentity) -> Bool
    func delete()
}

struct KeychainPushSecretStore: PushSecretStore {
    var service = "de.linolaske.showernow.push"
    private let account = "installation"

    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: account]
    }

    func load() -> PushIdentity? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        guard SecItemCopyMatching(request as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(PushIdentity.self, from: data)
    }

    func save(_ identity: PushIdentity) -> Bool {
        guard let data = try? JSONEncoder().encode(identity) else { return false }
        SecItemDelete(query as CFDictionary)
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    func delete() { SecItemDelete(query as CFDictionary) }
}
