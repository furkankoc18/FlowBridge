import Foundation
import Security

enum DeviceIdentityStore {
    private static let defaultsKey = "deviceID.v2"

    static func loadOrCreate() -> String {
        if let existing = UserDefaults.standard.string(forKey: defaultsKey), isValid(existing) {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        let identifier: String
        if SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess {
            identifier = bytes.map { String(format: "%02x", $0) }.joined()
        } else {
            identifier = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        UserDefaults.standard.set(identifier, forKey: defaultsKey)
        return identifier
    }

    private static func isValid(_ identifier: String) -> Bool {
        identifier.count == 32 && identifier.allSatisfy(\.isHexDigit)
    }
}
