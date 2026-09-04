import AppKit
import CoreGraphics
import Foundation

final class MouseSharingController {
    var onActiveChanged: ((Bool) -> Void)?

    private let transport: SecureMouseTransport
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var targetPeerID: String?
    private var exitEdge: TransferEdge = .right
    private var enabled = false
    private var remoteActive = false
    private var estimatedRemoteX: Double = 0
    private var returnOvershoot: Double = 0
    private var lastLocation = CGPoint.zero
    private var heartbeatTimer: Timer?
    private var movementTimer: DispatchSourceTimer?
    private var pendingMovementDX: Double = 0
    private var pendingMovementDY: Double = 0
    private var localCursorHidden = false
    private var lastHeartbeatAcknowledgement = Date.distantPast

    private let pointerSensitivity = 1.8
    private let returnResistance: Double = 45

    init(localID: String) {
        transport = SecureMouseTransport(localID: localID)
    }

    func configure(enabled: Bool, targetPeerID: String?, exitEdge: TransferEdge = .right) {
        self.enabled = enabled
        self.targetPeerID = targetPeerID
        self.exitEdge = exitEdge
        if enabled, targetPeerID != nil {
            installTapIfNeeded()
        } else {
            deactivateRemote()
            removeTap()
        }
    }

    func invalidatePeerKey(_ peerID: String) {
        transport.invalidateKey(for: peerID)
    }

    func updatePeerAddress(_ address: String, peerID: String) {
        transport.setAddress(address, for: peerID)
    }

    func sendReturn(to peerID: String) {
        transport.sendReliable(RemoteMouseEvent(kind: "return"), to: peerID)
    }

    func sendHeartbeatAcknowledgement(to peerID: String) {
        transport.send(RemoteMouseEvent(kind: "heartbeatAck"), to: peerID)
    }

    func returnFromRemote(peerID: String) {
        guard remoteActive, targetPeerID == peerID else { return }
        deactivateRemote()
    }

    func acknowledgeHeartbeat(from peerID: String) {
        guard remoteActive, targetPeerID == peerID else { return }
        lastHeartbeatAcknowledgement = Date()
    }

    private func installTapIfNeeded() {
        guard eventTap == nil else { return }
        let mask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.leftMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.rightMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
            | CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
            | CGEventMask(1 << CGEventType.scrollWheel.rawValue)
            | CGEventMask(1 << CGEventType.keyDown.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let controller = Unmanaged<MouseSharingController>.fromOpaque(refcon).takeUnretainedValue()
            return controller.handle(type: type, event: event)
        }
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: refcon
        ) else { return }
        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func removeTap() {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let eventTap { CFMachPortInvalidate(eventTap) }
        runLoopSource = nil
        eventTap = nil
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
            deactivateRemote()
            return Unmanaged.passUnretained(event)
        }
        if event.getIntegerValueField(.eventSourceUserData) == SecureMouseReceiver.injectedEventMarker {
            return Unmanaged.passUnretained(event)
        }
        guard enabled, let targetPeerID else { return Unmanaged.passUnretained(event) }

        if !remoteActive {
            guard type == .mouseMoved else { return Unmanaged.passUnretained(event) }
            let location = event.location
            defer { lastLocation = location }
            let screenBounds = CGDisplayBounds(CGMainDisplayID())
            let reachedExitEdge = exitEdge == .right
                ? location.x >= screenBounds.maxX - 2 && location.x >= lastLocation.x
                : location.x <= screenBounds.minX + 1 && location.x <= lastLocation.x
            guard reachedExitEdge else { return Unmanaged.passUnretained(event) }
            remoteActive = true
            lastHeartbeatAcknowledgement = Date()
            estimatedRemoteX = 8
            returnOvershoot = 0
            CGAssociateMouseAndMouseCursorPosition(0)
            if CGDisplayHideCursor(CGMainDisplayID()) == .success {
                localCursorHidden = true
            }
            let normalizedY = min(1, max(0, location.y / max(1, screenBounds.height)))
            transport.send(
                RemoteMouseEvent(
                    kind: "enter",
                    normalizedY: normalizedY,
                    edge: exitEdge.opposite.rawValue
                ),
                to: targetPeerID
            )
            startMovementTimer()
            heartbeatTimer?.invalidate()
            heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, self.remoteActive, let peerID = self.targetPeerID else { return }
                if Date().timeIntervalSince(self.lastHeartbeatAcknowledgement) > 0.5 {
                    self.deactivateRemote()
                    return
                }
                self.transport.send(RemoteMouseEvent(kind: "heartbeat"), to: peerID)
            }
            onActiveChanged?(true)
            return nil
        }

        if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 53 {
            deactivateRemote()
            return nil
        }

        switch type {
        case .mouseMoved:
            let dx = Double(event.getIntegerValueField(.mouseEventDeltaX)) * pointerSensitivity
            let dy = Double(event.getIntegerValueField(.mouseEventDeltaY)) * pointerSensitivity
            let movementTowardReturn = exitEdge == .right ? dx < 0 : dx > 0
            let returnDelta = exitEdge == .right ? dx : -dx
            let proposedX = estimatedRemoteX + returnDelta
            if movementTowardReturn, proposedX <= 0 {
                estimatedRemoteX = 0
                returnOvershoot += abs(dx)
                if returnOvershoot >= returnResistance {
                    deactivateRemote()
                    return nil
                }
            } else {
                estimatedRemoteX = min(10_000, max(0, proposedX))
                if !movementTowardReturn { returnOvershoot = 0 }
            }
            pendingMovementDX += dx
            pendingMovementDY += dy
        case .leftMouseDown:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "down", button: 0), to: targetPeerID)
        case .leftMouseUp:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "up", button: 0), to: targetPeerID)
        case .rightMouseDown:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "down", button: 1), to: targetPeerID)
        case .rightMouseUp:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "up", button: 1), to: targetPeerID)
        case .otherMouseDown:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "down", button: 2), to: targetPeerID)
        case .otherMouseUp:
            flushPendingMovement()
            transport.sendReliable(RemoteMouseEvent(kind: "up", button: 2), to: targetPeerID)
        case .scrollWheel:
            flushPendingMovement()
            let scroll = Double(event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            transport.send(RemoteMouseEvent(kind: "scroll", scrollY: scroll), to: targetPeerID)
        default:
            return Unmanaged.passUnretained(event)
        }
        return nil
    }

    private func deactivateRemote() {
        guard remoteActive else { return }
        flushPendingMovement()
        remoteActive = false
        movementTimer?.cancel()
        movementTimer = nil
        pendingMovementDX = 0
        pendingMovementDY = 0
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        CGAssociateMouseAndMouseCursorPosition(1)
        if localCursorHidden {
            _ = CGDisplayShowCursor(CGMainDisplayID())
            localCursorHidden = false
        }
        if let targetPeerID {
            transport.sendReliable(RemoteMouseEvent(kind: "leave"), to: targetPeerID)
        }
        let bounds = CGDisplayBounds(CGMainDisplayID())
        let returnX = exitEdge == .right ? bounds.maxX - 4 : bounds.minX + 4
        CGWarpMouseCursorPosition(CGPoint(x: returnX, y: min(bounds.maxY - 1, max(1, lastLocation.y))))
        onActiveChanged?(false)
    }

    private func startMovementTimer() {
        movementTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(
            deadline: .now() + .milliseconds(8),
            repeating: .milliseconds(8),
            leeway: .milliseconds(1)
        )
        timer.setEventHandler { [weak self] in self?.flushPendingMovement() }
        timer.resume()
        movementTimer = timer
    }

    private func flushPendingMovement() {
        guard remoteActive,
              let targetPeerID,
              pendingMovementDX != 0 || pendingMovementDY != 0
        else { return }
        let dx = pendingMovementDX
        let dy = pendingMovementDY
        pendingMovementDX = 0
        pendingMovementDY = 0
        transport.sendMovement(dx: dx, dy: dy, to: targetPeerID)
    }
}
