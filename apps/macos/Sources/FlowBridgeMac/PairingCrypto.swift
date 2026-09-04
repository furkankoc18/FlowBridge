import CryptoKit
import Foundation

final class PairingKeyExchange {
    private let privateKey = P256.KeyAgreement.PrivateKey()

    var publicKey: String {
        privateKey.publicKey.x963Representation.base64EncodedString()
    }

    func derivePeerKey(remotePublicKey: String, localID: String, remoteID: String) throws -> Data {
        guard let point = Data(base64Encoded: remotePublicKey) else {
            throw PairingCryptoError.invalidPublicKey
        }
        let remote = try P256.KeyAgreement.PublicKey(x963Representation: point)
        let secret = try privateKey.sharedSecretFromKeyAgreement(with: remote)
        let transcript = Data(
            ("FlowBridge/pairing/v1|" + [localID, remoteID].sorted().joined(separator: "|")).utf8
        )
        return secret.withUnsafeBytes { secretBytes in
            var material = Data(secretBytes)
            material.append(transcript)
            return Data(SHA256.hash(data: material))
        }
    }

    static func verificationCode(peerKey: Data) -> String {
        let digest = SHA256.hash(data: peerKey)
        let bytes = Array(digest.prefix(4))
        let value = (
            UInt32(bytes[0]) << 24
                | UInt32(bytes[1]) << 16
                | UInt32(bytes[2]) << 8
                | UInt32(bytes[3])
        ) % 1_000_000
        return String(format: "%06u", value)
    }
}

enum PairingCryptoError: Error {
    case invalidPublicKey
}

enum ControlAuthentication {
    static func make(
        type: String,
        fromID: String,
        toID: String,
        requestID: String?,
        key: Data
    ) -> String {
        let message = Data("FlowBridge/control/v3|\(type)|\(fromID)|\(toID)|\(requestID ?? "")".utf8)
        let code = HMAC<SHA256>.authenticationCode(for: message, using: SymmetricKey(data: key))
        return Data(code).base64EncodedString()
    }

    static func verify(
        _ authentication: String?,
        type: String,
        fromID: String,
        toID: String,
        requestID: String?,
        key: Data
    ) -> Bool {
        guard let authentication, let received = Data(base64Encoded: authentication) else { return false }
        let message = Data("FlowBridge/control/v3|\(type)|\(fromID)|\(toID)|\(requestID ?? "")".utf8)
        return HMAC<SHA256>.isValidAuthenticationCode(
            received,
            authenticating: message,
            using: SymmetricKey(data: key)
        )
    }
}
