import Foundation
import Security

enum PeerKeychain {
    private static let service = "com.flowbridge.app.peer-key"

    static func load(peerID: String) -> Data? {
        guard isValid(peerID) else { return nil }
        return load(peerID: peerID, service: service)
    }

    private static func load(peerID: String, service requestedService: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: requestedService,
            kSecAttrAccount as String: peerID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              data.count == 32
        else { return nil }
        return data
    }

    static func save(_ key: Data, peerID: String) {
        guard isValid(peerID), key.count == 32 else { return }
        remove(peerID: peerID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: peerID,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func remove(peerID: String) {
        guard isValid(peerID) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: peerID,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func isValid(_ peerID: String) -> Bool {
        peerID.count == 32 && peerID.allSatisfy(\.isHexDigit)
    }
}
