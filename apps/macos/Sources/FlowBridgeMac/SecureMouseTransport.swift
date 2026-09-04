import CryptoKit
import Darwin
import Foundation
import Security

struct RemoteMouseEvent: Codable {
    let kind: String
    var dx: Double = 0
    var dy: Double = 0
    var button: Int = 0
    var scrollY: Double = 0
    var normalizedY: Double = 0.5
    var edge: String? = nil
}

private struct SecureMouseEnvelope: Codable {
    let version: Int
    let fromID: String
    let toID: String
    let sessionID: String
    let sequence: UInt64
    let sealed: String

    enum CodingKeys: String, CodingKey {
        case version, sequence, sealed
        case fromID = "fromId"
        case toID = "toId"
        case sessionID = "sessionId"
    }
}

final class SecureMouseTransport {
    private static let multicastAddress = "239.255.42.99"
    private static let port: UInt16 = 45_875
    private let localID: String
    private let sessionID: String
    private let queue = DispatchQueue(label: "com.flowbridge.app.secure-mouse-transport")
    private var socketFD: Int32 = -1
    private var sequences: [String: UInt64] = [:]
    private var cachedKeys: [String: Data] = [:]
    private var peerAddresses: [String: String] = [:]

    init(localID: String) {
        self.localID = localID
        self.sessionID = Self.randomSessionID()
        queue.sync {
            socketFD = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        }
    }

    deinit {
        if socketFD >= 0 { Darwin.close(socketFD) }
    }

    func send(_ event: RemoteMouseEvent, to peerID: String) {
        queue.async { [weak self] in self?.sendOnQueue(event, to: peerID) }
    }

    func sendMovement(dx: Double, dy: Double, to peerID: String) {
        let event = RemoteMouseEvent(kind: "move", dx: dx, dy: dy)
        queue.async { [weak self] in self?.sendOnQueue(event, to: peerID) }
    }

    func sendReliable(_ event: RemoteMouseEvent, to peerID: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.sendOnQueue(event, to: peerID)
            self.queue.asyncAfter(deadline: .now() + .milliseconds(30)) { [weak self] in
                self?.sendOnQueue(event, to: peerID)
            }
        }
    }

    func invalidateKey(for peerID: String) {
        queue.async { [weak self] in self?.cachedKeys.removeValue(forKey: peerID) }
    }

    func setAddress(_ address: String, for peerID: String) {
        queue.async { [weak self] in
            var binaryAddress = in_addr()
            guard inet_pton(AF_INET, address, &binaryAddress) == 1 else { return }
            self?.peerAddresses[peerID] = address
        }
    }

    private func sendOnQueue(_ event: RemoteMouseEvent, to peerID: String) {
        guard socketFD >= 0 else { return }
        let peerKey: Data
        if let cached = cachedKeys[peerID] {
            peerKey = cached
        } else if let loaded = PeerKeychain.load(peerID: peerID) {
            cachedKeys[peerID] = loaded
            peerKey = loaded
        } else {
            return
        }
        let sequence = (sequences[peerID] ?? 0) &+ 1
        sequences[peerID] = sequence
        guard let plain = try? JSONEncoder().encode(event) else { return }
        let aad = Self.aad(fromID: localID, toID: peerID, sessionID: sessionID, sequence: sequence)
        let key = SymmetricKey(data: peerKey)
        guard let sealedBox = try? AES.GCM.seal(plain, using: key, authenticating: aad),
              let combined = sealedBox.combined
        else { return }
        let envelope = SecureMouseEnvelope(
            version: 2,
            fromID: localID,
            toID: peerID,
            sessionID: sessionID,
            sequence: sequence,
            sealed: combined.base64EncodedString()
        )
        guard let packet = try? JSONEncoder().encode(envelope), packet.count <= 2_048 else { return }

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = Self.port.bigEndian
        let targetAddress = peerAddresses[peerID] ?? Self.multicastAddress
        var binaryAddress = in_addr()
        guard inet_pton(AF_INET, targetAddress, &binaryAddress) == 1 else { return }
        destination.sin_addr = binaryAddress
        packet.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = Darwin.sendto(
                        socketFD,
                        baseAddress,
                        packet.count,
                        0,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
    }

    static func aad(fromID: String, toID: String, sessionID: String, sequence: UInt64) -> Data {
        Data("FlowBridge/mouse/v2|\(fromID)|\(toID)|\(sessionID)|\(sequence)".utf8)
    }

    private static func randomSessionID() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
            return UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        }
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
