import Foundation
import Security

enum PeerKeychain {
    private static let service = "com.flowbridge.app.peer-key.v2"
    private static var usesFallbackStore: Bool {
        Bundle.main.object(forInfoDictionaryKey: "FlowBridgeAdHocBuild") as? Bool == true
    }

    static func load(peerID: String) -> Data? {
        guard isValid(peerID) else { return nil }
        if usesFallbackStore { return loadFallback(peerID: peerID) }
        if let fallback = loadFallback(peerID: peerID) {
            if saveToKeychain(fallback, peerID: peerID) {
                removeFallback(peerID: peerID)
            }
            return fallback
        }
        return loadFromKeychain(peerID: peerID)
    }

    private static func loadFromKeychain(peerID: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
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
        if usesFallbackStore {
            saveFallback(key, peerID: peerID)
            return
        }
        saveToKeychain(key, peerID: peerID)
    }

    @discardableResult
    private static func saveToKeychain(_ key: Data, peerID: String) -> Bool {
        removeFromKeychain(peerID: peerID)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: peerID,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: key,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    static func remove(peerID: String) {
        guard isValid(peerID) else { return }
        removeFallback(peerID: peerID)
        if !usesFallbackStore { removeFromKeychain(peerID: peerID) }
    }

    private static func removeFromKeychain(peerID: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: peerID,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func loadFallback(peerID: String) -> Data? {
        guard let data = try? Data(contentsOf: fallbackURL(peerID: peerID)), data.count == 32 else {
            return nil
        }
        return data
    }

    private static func saveFallback(_ key: Data, peerID: String) {
        let directory = fallbackDirectory
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
            let destination = fallbackURL(peerID: peerID)
            try key.write(to: destination, options: .atomic)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
        } catch {
            return
        }
    }

    private static func removeFallback(peerID: String) {
        try? FileManager.default.removeItem(at: fallbackURL(peerID: peerID))
    }

    private static var fallbackDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("FlowBridge/peer-keys", isDirectory: true)
    }

    private static func fallbackURL(peerID: String) -> URL {
        fallbackDirectory.appendingPathComponent("\(peerID).key", isDirectory: false)
    }

    private static func isValid(_ peerID: String) -> Bool {
        peerID.count == 32 && peerID.allSatisfy(\.isHexDigit)
    }
}
