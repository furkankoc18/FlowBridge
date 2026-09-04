import Darwin
import Foundation

final class PeerControlService {
    var onHello: ((ControlEnvelope) -> Void)?
    var onPairRequest: ((ControlEnvelope) -> Void)?
    var onPairChallenge: ((ControlEnvelope) -> Void)?
    var onPairAccepted: ((ControlEnvelope) -> Void)?
    var onUnpair: ((ControlEnvelope) -> Void)?
    var onPeerAddress: ((String, String) -> Void)?

    private static let multicastAddress = "239.255.42.99"
    private static let port: UInt16 = 45_874
    private let queue = DispatchQueue(label: "com.flowbridge.app.peer-control")
    private let localID: String
    private let localName: String
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var helloTimer: DispatchSourceTimer?
    private var handledRequestIDs: Set<String> = []

    init(localID: String, localName: String) {
        self.localID = localID
        self.localName = String(localName.prefix(80))
    }

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    func stop() {
        queue.async { [weak self] in self?.stopOnQueue() }
    }

    func sendPairRequest(to peerID: String, requestID: String, publicKey: String) {
        sendRepeated(.pairRequest(fromID: localID, fromName: localName, toID: peerID, requestID: requestID, publicKey: publicKey))
    }

    func sendPairChallenge(to peerID: String, requestID: String, publicKey: String) {
        sendRepeated(.pairChallenge(fromID: localID, fromName: localName, toID: peerID, requestID: requestID, publicKey: publicKey))
    }

    func sendPairAccepted(to peerID: String, requestID: String, authentication: String) {
        sendRepeated(.pairAccepted(fromID: localID, fromName: localName, toID: peerID, requestID: requestID, authentication: authentication))
    }

    func sendUnpair(to peerID: String, authentication: String) {
        sendRepeated(.unpair(fromID: localID, fromName: localName, toID: peerID, authentication: authentication))
    }

    private func startOnQueue() {
        guard socketFD < 0 else { return }
        let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { return }

        var enabled: Int32 = 1
        guard setsockopt(descriptor, SOL_SOCKET, SO_REUSEADDR, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0,
              setsockopt(descriptor, SOL_SOCKET, SO_REUSEPORT, &enabled, socklen_t(MemoryLayout.size(ofValue: enabled))) == 0
        else {
            Darwin.close(descriptor)
            return
        }

        var localAddress = sockaddr_in()
        localAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        localAddress.sin_family = sa_family_t(AF_INET)
        localAddress.sin_port = Self.port.bigEndian
        localAddress.sin_addr = in_addr(s_addr: INADDR_ANY)
        let bindResult = withUnsafePointer(to: &localAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            Darwin.close(descriptor)
            return
        }

        var membership = ip_mreq(
            imr_multiaddr: in_addr(s_addr: inet_addr(Self.multicastAddress)),
            imr_interface: in_addr(s_addr: INADDR_ANY)
        )
        guard setsockopt(
            descriptor,
            IPPROTO_IP,
            IP_ADD_MEMBERSHIP,
            &membership,
            socklen_t(MemoryLayout<ip_mreq>.size)
        ) == 0 else {
            Darwin.close(descriptor)
            return
        }

        socketFD = descriptor
        let source = DispatchSource.makeReadSource(fileDescriptor: descriptor, queue: queue)
        source.setEventHandler { [weak self] in self?.receiveAvailableDatagrams() }
        source.setCancelHandler { Darwin.close(descriptor) }
        source.resume()
        readSource = source

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: 2)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            self.sendOnQueue(.hello(fromID: self.localID, fromName: self.localName))
        }
        timer.resume()
        helloTimer = timer
    }

    private func stopOnQueue() {
        helloTimer?.cancel()
        helloTimer = nil
        readSource?.cancel()
        readSource = nil
        socketFD = -1
        handledRequestIDs.removeAll()
    }

    private func receiveAvailableDatagrams() {
        guard socketFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 2_049)
        while true {
            var sourceAddress = sockaddr_in()
            var sourceLength = socklen_t(MemoryLayout<sockaddr_in>.size)
            let byteCount = withUnsafeMutablePointer(to: &sourceAddress) { pointer in
                pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    recvfrom(socketFD, &buffer, 2_049, MSG_DONTWAIT, $0, &sourceLength)
                }
            }
            guard byteCount > 0 else { return }
            guard byteCount <= 2_048 else { continue }
            let data = Data(buffer.prefix(Int(byteCount)))
            guard let envelope = try? JSONDecoder().decode(ControlEnvelope.self, from: data),
                  envelope.isValid,
                  envelope.fromID != localID,
                  envelope.toID == nil || envelope.toID == localID
            else { continue }

            var addressCharacters = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
            let sourceHost = withUnsafePointer(to: &sourceAddress.sin_addr) { addressPointer in
                inet_ntop(AF_INET, addressPointer, &addressCharacters, socklen_t(INET_ADDRSTRLEN))
            }.map { _ in String(cString: addressCharacters) }
            if let sourceHost { onPeerAddress?(envelope.fromID, sourceHost) }

            switch envelope.type {
            case .hello:
                onHello?(envelope)
            case .pairRequest:
                guard let requestID = envelope.requestID,
                      handledRequestIDs.insert(requestID).inserted
                else { continue }
                if handledRequestIDs.count > 256 { handledRequestIDs.removeAll(keepingCapacity: true) }
                onPairRequest?(envelope)
            case .pairChallenge:
                guard let requestID = envelope.requestID,
                      handledRequestIDs.insert(requestID).inserted
                else { continue }
                onPairChallenge?(envelope)
            case .pairAccepted:
                onPairAccepted?(envelope)
            case .unpair:
                onUnpair?(envelope)
            }
        }
    }

    private func sendRepeated(_ envelope: ControlEnvelope) {
        queue.async { [weak self] in
            self?.sendOnQueue(envelope)
            self?.queue.asyncAfter(deadline: .now() + .milliseconds(200)) { [weak self] in
                self?.sendOnQueue(envelope)
            }
            self?.queue.asyncAfter(deadline: .now() + .milliseconds(700)) { [weak self] in
                self?.sendOnQueue(envelope)
            }
        }
    }

    private func sendOnQueue(_ envelope: ControlEnvelope) {
        guard socketFD >= 0,
              let data = try? JSONEncoder().encode(envelope),
              data.count <= 2_048
        else { return }

        var destination = sockaddr_in()
        destination.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        destination.sin_family = sa_family_t(AF_INET)
        destination.sin_port = Self.port.bigEndian
        destination.sin_addr = in_addr(s_addr: inet_addr(Self.multicastAddress))
        data.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else { return }
            withUnsafePointer(to: &destination) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    _ = Darwin.sendto(
                        socketFD,
                        baseAddress,
                        data.count,
                        0,
                        $0,
                        socklen_t(MemoryLayout<sockaddr_in>.size)
                    )
                }
            }
        }
    }
}

enum ControlMessageType: String, Codable {
    case hello
    case pairRequest
    case pairChallenge
    case pairAccepted
    case unpair
}

struct ControlEnvelope: Codable {
    let type: ControlMessageType
    let version: Int
    let fromID: String
    let fromName: String
    let platform: String
    let toID: String?
    let requestID: String?
    let publicKey: String?
    let authentication: String?

    enum CodingKeys: String, CodingKey {
        case type, version, fromName, platform, publicKey, authentication
        case fromID = "fromId"
        case toID = "toId"
        case requestID = "requestId"
    }

    var isValid: Bool {
        (version == 2 || version == 3)
            && fromID.count == 32
            && fromID.allSatisfy(\.isHexDigit)
            && !fromName.isEmpty
            && fromName.count <= 80
            && (toID == nil || (toID?.count == 32 && toID?.allSatisfy(\.isHexDigit) == true))
    }

    static func hello(fromID: String, fromName: String) -> Self {
        .init(type: .hello, version: 3, fromID: fromID, fromName: fromName, platform: "macOS", toID: nil, requestID: nil, publicKey: nil, authentication: nil)
    }

    static func pairRequest(fromID: String, fromName: String, toID: String, requestID: String, publicKey: String) -> Self {
        .init(type: .pairRequest, version: 3, fromID: fromID, fromName: fromName, platform: "macOS", toID: toID, requestID: requestID, publicKey: publicKey, authentication: nil)
    }

    static func pairChallenge(fromID: String, fromName: String, toID: String, requestID: String, publicKey: String) -> Self {
        .init(type: .pairChallenge, version: 3, fromID: fromID, fromName: fromName, platform: "macOS", toID: toID, requestID: requestID, publicKey: publicKey, authentication: nil)
    }

    static func pairAccepted(fromID: String, fromName: String, toID: String, requestID: String, authentication: String) -> Self {
        .init(type: .pairAccepted, version: 3, fromID: fromID, fromName: fromName, platform: "macOS", toID: toID, requestID: requestID, publicKey: nil, authentication: authentication)
    }

    static func unpair(fromID: String, fromName: String, toID: String, authentication: String) -> Self {
        .init(type: .unpair, version: 3, fromID: fromID, fromName: fromName, platform: "macOS", toID: toID, requestID: nil, publicKey: nil, authentication: authentication)
    }
}
