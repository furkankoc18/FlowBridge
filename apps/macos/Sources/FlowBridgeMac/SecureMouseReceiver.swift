import CoreGraphics
import CryptoKit
import Darwin
import Foundation

private struct IncomingSecureMouseEnvelope: Codable {
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

final class SecureMouseReceiver {
    static let injectedEventMarker: Int64 = 0x4642_4D53

    var onReturnRequested: ((String) -> Void)?
    var onReturnReceived: ((String) -> Void)?
    var onHeartbeatRequested: ((String) -> Void)?
    var onHeartbeatReceived: ((String) -> Void)?

    private static let port: UInt16 = 45_875
    private let localID: String
    private let queue = DispatchQueue(label: "com.flowbridge.app.secure-mouse-receiver")
    private var socketFD: Int32 = -1
    private var readSource: DispatchSourceRead?
    private var failsafeTimer: DispatchSourceTimer?
    private var cachedKeys: [String: Data] = [:]
    private var lastSequences: [String: UInt64] = [:]
    private var lastAuthenticatedEvent = Date.distantPast
    private var pressedButtons: Set<Int> = []
    private var activePeerID: String?
    private var activeEntryEdge: TransferEdge = .right
    private var returnOvershoot: Double = 0
    private var enabled = false

    private let returnResistance: Double = 45

    init(localID: String) {
        self.localID = localID
    }

    func start() {
        queue.async { [weak self] in self?.startOnQueue() }
    }

    func stop() {
        queue.async { [weak self] in self?.stopOnQueue() }
    }

    func invalidateKey(for peerID: String) {
        queue.async { [weak self] in
            self?.cachedKeys.removeValue(forKey: peerID)
            self?.lastSequences = self?.lastSequences.filter { !$0.key.hasPrefix("\(peerID)|") } ?? [:]
        }
    }

    func setEnabled(_ enabled: Bool) {
        queue.async { [weak self] in
            guard let self else { return }
            self.enabled = enabled
            if !enabled {
                DispatchQueue.main.async { [weak self] in
                    self?.activePeerID = nil
                    self?.returnOvershoot = 0
                    self?.releaseAllButtons()
                }
            }
        }
    }

    private func startOnQueue() {
        guard socketFD < 0 else { return }
        let descriptor = Darwin.socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard descriptor >= 0 else { return }
        var enabled: Int32 = 1
        _ = setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_REUSEADDR,
            &enabled,
            socklen_t(MemoryLayout.size(ofValue: enabled))
        )
        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = Self.port.bigEndian
        address.sin_addr = in_addr(s_addr: INADDR_ANY)
        let result = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard result == 0 else { Darwin.close(descriptor); return }

        var membership = ip_mreq(
            imr_multiaddr: in_addr(s_addr: inet_addr("239.255.42.99")),
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
        timer.schedule(deadline: .now() + .milliseconds(100), repeating: .milliseconds(100))
        timer.setEventHandler { [weak self] in self?.checkFailsafe() }
        timer.resume()
        failsafeTimer = timer
    }

    private func stopOnQueue() {
        releaseAllButtons()
        failsafeTimer?.cancel()
        failsafeTimer = nil
        readSource?.cancel()
        readSource = nil
        socketFD = -1
    }

    private func receiveAvailableDatagrams() {
        guard socketFD >= 0 else { return }
        var buffer = [UInt8](repeating: 0, count: 2_049)
        while true {
            let count = recv(socketFD, &buffer, buffer.count, MSG_DONTWAIT)
            guard count > 0 else { return }
            guard count <= 2_048,
                  let envelope = try? JSONDecoder().decode(
                    IncomingSecureMouseEnvelope.self,
                    from: Data(buffer.prefix(Int(count)))
                  ),
                  envelope.version == 2,
                  envelope.toID == localID,
                  envelope.fromID.count == 32,
                  envelope.fromID.allSatisfy(\.isHexDigit),
                  envelope.sessionID.count == 32,
                  envelope.sessionID.allSatisfy(\.isHexDigit),
                  envelope.sequence > (lastSequences[sequenceKey(for: envelope)] ?? 0),
                  let event = decrypt(envelope)
            else { continue }
            lastSequences[sequenceKey(for: envelope)] = envelope.sequence
            lastAuthenticatedEvent = Date()
            guard enabled else { continue }
            if event.kind == "return" {
                DispatchQueue.main.async { [weak self] in self?.onReturnReceived?(envelope.fromID) }
            } else if event.kind == "heartbeat" {
                DispatchQueue.main.async { [weak self] in self?.onHeartbeatRequested?(envelope.fromID) }
            } else if event.kind == "heartbeatAck" {
                DispatchQueue.main.async { [weak self] in self?.onHeartbeatReceived?(envelope.fromID) }
            } else {
                apply(event, from: envelope.fromID)
            }
        }
    }

    private func decrypt(_ envelope: IncomingSecureMouseEnvelope) -> RemoteMouseEvent? {
        let peerKey: Data
        if let cached = cachedKeys[envelope.fromID] {
            peerKey = cached
        } else if let loaded = PeerKeychain.load(peerID: envelope.fromID) {
            cachedKeys[envelope.fromID] = loaded
            peerKey = loaded
        } else { return nil }
        guard let combined = Data(base64Encoded: envelope.sealed),
              let sealedBox = try? AES.GCM.SealedBox(combined: combined)
        else { return nil }
        let aad = SecureMouseTransport.aad(
            fromID: envelope.fromID,
            toID: envelope.toID,
            sessionID: envelope.sessionID,
            sequence: envelope.sequence
        )
        let key = SymmetricKey(data: peerKey)
        guard let clear = try? AES.GCM.open(sealedBox, using: key, authenticating: aad)
        else { return nil }
        return try? JSONDecoder().decode(RemoteMouseEvent.self, from: clear)
    }

    private func sequenceKey(for envelope: IncomingSecureMouseEnvelope) -> String {
        "\(envelope.fromID)|\(envelope.sessionID)"
    }

    private func apply(_ event: RemoteMouseEvent, from peerID: String) {
        DispatchQueue.main.async { [weak self] in self?.applyOnMain(event, from: peerID) }
    }

    private func applyOnMain(_ event: RemoteMouseEvent, from peerID: String) {
        let bounds = CGDisplayBounds(CGMainDisplayID())
        switch event.kind {
        case "enter":
            activePeerID = peerID
            activeEntryEdge = TransferEdge(rawValue: event.edge ?? "right") ?? .right
            returnOvershoot = 0
            let position = CGPoint(
                x: activeEntryEdge == .left ? bounds.minX + 8 : bounds.maxX - 8,
                y: bounds.minY + min(1, max(0, event.normalizedY)) * bounds.height
            )
            postMouse(type: .mouseMoved, button: .left, position: position)
        case "move":
            guard activePeerID == peerID else { return }
            guard let current = CGEvent(source: nil)?.location else { return }
            let proposedX = current.x + event.dx
            let pushingOutside = activeEntryEdge == .left
                ? event.dx < 0 && proposedX <= bounds.minX + 1
                : event.dx > 0 && proposedX >= bounds.maxX - 1
            if pushingOutside {
                returnOvershoot += abs(event.dx)
                if returnOvershoot >= returnResistance {
                    activePeerID = nil
                    returnOvershoot = 0
                    releaseAllButtons()
                    onReturnRequested?(peerID)
                    return
                }
            } else if (activeEntryEdge == .left && event.dx > 0)
                        || (activeEntryEdge == .right && event.dx < 0) {
                returnOvershoot = 0
            }
            let position = CGPoint(
                x: min(bounds.maxX - 1, max(bounds.minX, proposedX)),
                y: min(bounds.maxY - 1, max(bounds.minY, current.y + event.dy))
            )
            postMouse(type: .mouseMoved, button: .left, position: position)
        case "down":
            guard activePeerID == peerID else { return }
            pressedButtons.insert(event.button)
            postButton(event.button, down: true)
        case "up":
            guard activePeerID == peerID else { return }
            pressedButtons.remove(event.button)
            postButton(event.button, down: false)
        case "scroll":
            guard activePeerID == peerID else { return }
            guard let scroll = CGEvent(
                scrollWheelEvent2Source: nil,
                units: .line,
                wheelCount: 1,
                wheel1: Int32(event.scrollY.rounded()),
                wheel2: 0,
                wheel3: 0
            ) else { return }
            markAndPost(scroll)
        case "leave":
            guard activePeerID == peerID else { return }
            activePeerID = nil
            returnOvershoot = 0
            releaseAllButtons()
        default:
            break
        }
    }

    private func postButton(_ button: Int, down: Bool) {
        let type: CGEventType
        let mouseButton: CGMouseButton
        switch button {
        case 1:
            type = down ? .rightMouseDown : .rightMouseUp
            mouseButton = .right
        case 2:
            type = down ? .otherMouseDown : .otherMouseUp
            mouseButton = .center
        default:
            type = down ? .leftMouseDown : .leftMouseUp
            mouseButton = .left
        }
        guard let current = CGEvent(source: nil)?.location else { return }
        postMouse(type: type, button: mouseButton, position: current)
    }

    private func postMouse(type: CGEventType, button: CGMouseButton, position: CGPoint) {
        guard let event = CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: position,
            mouseButton: button
        ) else { return }
        markAndPost(event)
    }

    private func markAndPost(_ event: CGEvent) {
        event.setIntegerValueField(.eventSourceUserData, value: Self.injectedEventMarker)
        event.post(tap: .cghidEventTap)
    }

    private func checkFailsafe() {
        if Date().timeIntervalSince(lastAuthenticatedEvent) > 0.5 { releaseAllButtons() }
    }

    private func releaseAllButtons() {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.pressedButtons.isEmpty else { return }
            let buttons = self.pressedButtons
            self.pressedButtons.removeAll()
            buttons.forEach { self.postButton($0, down: false) }
        }
    }
}
