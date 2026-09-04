import AppKit
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: SidebarSection = .overview
    @Published private(set) var peers: [PeerDevice] = []
    @Published private(set) var discoveryStatus: DiscoveryStatus = .stopped
    @Published private(set) var accessibility: PermissionState = .missing
    @Published private(set) var inputMonitoring: PermissionState = .missing
    @Published private(set) var isRunning = true
    @Published var pairingRequest: PairingRequest?
    @Published private(set) var mouseSharingEnabled = true
    @Published private(set) var mouseSharingActive = false
    @Published private(set) var pairingError: String?

    let deviceID: String
    let deviceName: String

    private let discovery: BonjourDiscovery
    private let peerControl: PeerControlService
    private let mouseController: MouseSharingController
    private let mouseReceiver: SecureMouseReceiver
    private var trustedPeerIDs: Set<String>
    private var outgoingExchanges: [String: PairingKeyExchange] = [:]
    private var pairingSessions: [String: PendingMacPairingSession] = [:]
    private var bonjourPeerIDs: Set<String> = []
    private var controlLastSeen: [String: Date] = [:]
    private var permissionTimer: Timer?

    init() {
        deviceID = KeychainIdentity.loadOrCreate()
        deviceName = Host.current().localizedName ?? "Bu Mac"
        trustedPeerIDs = Set(UserDefaults.standard.stringArray(forKey: "trustedPeerIDs") ?? [])
        trustedPeerIDs = trustedPeerIDs.filter { PeerKeychain.load(peerID: $0) != nil }
        UserDefaults.standard.set(Array(trustedPeerIDs).sorted(), forKey: "trustedPeerIDs")
        discovery = BonjourDiscovery(localID: deviceID, deviceName: deviceName)
        peerControl = PeerControlService(localID: deviceID, localName: deviceName)
        mouseController = MouseSharingController(localID: deviceID)
        mouseReceiver = SecureMouseReceiver(localID: deviceID)

        discovery.onPeersChanged = { [weak self] peers in
            DispatchQueue.main.async {
                guard let self else { return }
                self.bonjourPeerIDs = Set(peers.map(\.id))
                peers.forEach { self.upsertPeer($0) }
                self.pruneUnavailablePeers()
            }
        }
        discovery.onStatusChanged = { [weak self] status in
            DispatchQueue.main.async { self?.discoveryStatus = status }
        }
        peerControl.onHello = { [weak self] envelope in
            Task { @MainActor in self?.receivedHello(envelope) }
        }
        peerControl.onPairRequest = { [weak self] envelope in
            Task { @MainActor in self?.receivedPairRequest(envelope) }
        }
        peerControl.onPairChallenge = { [weak self] envelope in
            Task { @MainActor in self?.receivedPairChallenge(envelope) }
        }
        peerControl.onPairAccepted = { [weak self] envelope in
            Task { @MainActor in self?.receivedPairAccepted(envelope) }
        }
        peerControl.onUnpair = { [weak self] envelope in
            Task { @MainActor in self?.receivedUnpair(envelope) }
        }
        peerControl.onPeerAddress = { [weak self] peerID, address in
            Task { @MainActor in self?.mouseController.updatePeerAddress(address, peerID: peerID) }
        }
        mouseController.onActiveChanged = { [weak self] active in
            Task { @MainActor in self?.mouseSharingActive = active }
        }
        mouseReceiver.onReturnRequested = { [weak self] peerID in
            Task { @MainActor in self?.mouseController.sendReturn(to: peerID) }
        }
        mouseReceiver.onReturnReceived = { [weak self] peerID in
            Task { @MainActor in self?.mouseController.returnFromRemote(peerID: peerID) }
        }
        mouseReceiver.onHeartbeatRequested = { [weak self] peerID in
            Task { @MainActor in self?.mouseController.sendHeartbeatAcknowledgement(to: peerID) }
        }
        mouseReceiver.onHeartbeatReceived = { [weak self] peerID in
            Task { @MainActor in self?.mouseController.acknowledgeHeartbeat(from: peerID) }
        }

        refreshPermissions()
        start()
        permissionTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.pruneUnavailablePeers()
            }
        }
    }

    deinit {
        permissionTimer?.invalidate()
    }

    func start() {
        isRunning = true
        discovery.start()
        peerControl.start()
        mouseReceiver.start()
        refreshMouseConfiguration()
    }

    func stop() {
        isRunning = false
        discovery.stop()
        peerControl.stop()
        mouseReceiver.stop()
        bonjourPeerIDs.removeAll()
        controlLastSeen.removeAll()
        peers.removeAll()
        refreshMouseConfiguration()
    }

    func toggleRunning() {
        isRunning ? stop() : start()
    }

    func refreshPermissions() {
        accessibility = SecurityPermissions.accessibility
        inputMonitoring = SecurityPermissions.inputMonitoring
        refreshMouseConfiguration()
    }

    func requestAccessibility() {
        SecurityPermissions.requestAccessibility()
        SecurityPermissions.openAccessibilitySettings()
    }

    func requestInputMonitoring() {
        SecurityPermissions.requestInputMonitoring()
        SecurityPermissions.openInputMonitoringSettings()
    }

    func beginPairing(with peer: PeerDevice) {
        guard !peer.isPairingPending else { return }
        let requestID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        let exchange = PairingKeyExchange()
        outgoingExchanges[requestID] = exchange
        updatePeer(peer.id) { $0.isPairingPending = true }
        peerControl.sendPairRequest(
            to: peer.id,
            requestID: requestID,
            publicKey: exchange.publicKey
        )
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, self.outgoingExchanges.removeValue(forKey: requestID) != nil else { return }
            self.updatePeer(peer.id) { $0.isPairingPending = false }
            self.pairingError = "Karşı cihaz güvenli eşleştirme isteğine yanıt vermedi. FlowBridge 0.4.0 veya daha yeni sürümünü kullanıp güvenlik duvarı iznini denetle."
            self.bringDashboardToFront()
        }
    }

    func approvePairing() {
        guard let request = pairingRequest,
              let session = pairingSessions[request.requestID]
        else { return }
        session.localApproved = true
        let authentication = ControlAuthentication.make(
            type: ControlMessageType.pairAccepted.rawValue,
            fromID: deviceID,
            toID: request.peer.id,
            requestID: request.requestID,
            key: session.peerKey
        )
        peerControl.sendPairAccepted(
            to: request.peer.id,
            requestID: request.requestID,
            authentication: authentication
        )
        tryCompletePairing(session)
        pairingRequest = nil
    }

    func cancelPairing(_ request: PairingRequest) {
        pairingSessions.removeValue(forKey: request.requestID)
        outgoingExchanges.removeValue(forKey: request.requestID)
        updatePeer(request.peer.id) { $0.isPairingPending = false }
        pairingRequest = nil
    }

    func clearPairingError() {
        pairingError = nil
    }

    func removeTrust(from peer: PeerDevice) {
        guard let key = PeerKeychain.load(peerID: peer.id) else {
            removeTrustLocally(peerID: peer.id)
            return
        }
        let authentication = ControlAuthentication.make(
            type: ControlMessageType.unpair.rawValue,
            fromID: deviceID,
            toID: peer.id,
            requestID: nil,
            key: key
        )
        peerControl.sendUnpair(to: peer.id, authentication: authentication)
        removeTrustLocally(peerID: peer.id)
    }

    func toggleMouseSharing() {
        mouseSharingEnabled.toggle()
        refreshMouseConfiguration()
    }

    var mouseTargetName: String? {
        trustedMousePeer?.name
    }

    var mouseExitEdgeTitle: String? {
        guard let peer = trustedMousePeer else { return nil }
        return exitEdge(for: peer) == .right ? "sağ" : "sol"
    }

    var readyPermissionCount: Int {
        [accessibility, inputMonitoring].filter { $0 == .granted }.count
    }

    var shortDeviceID: String {
        String(deviceID.prefix(8)).uppercased()
    }

    private func persistTrustedPeers() {
        UserDefaults.standard.set(Array(trustedPeerIDs).sorted(), forKey: "trustedPeerIDs")
    }

    private func updateTrustState() {
        peers = peers.map { peer in
            var peer = peer
            peer.isTrusted = trustedPeerIDs.contains(peer.id)
            if peer.isTrusted { peer.isPairingPending = false }
            return peer
        }
    }

    private func receivedHello(_ envelope: ControlEnvelope) {
        controlLastSeen[envelope.fromID] = Date()
        upsertPeer(PeerDevice(
            id: envelope.fromID,
            name: envelope.fromName,
            platform: envelope.platform,
            endpointDescription: "FlowBridge denetim kanalı",
            isTrusted: false
        ))
    }

    private func receivedPairRequest(_ envelope: ControlEnvelope) {
        guard !trustedPeerIDs.contains(envelope.fromID) else { return }
        receivedHello(envelope)
        guard pairingRequest == nil else { return }
        guard envelope.version == 3,
              let requestID = envelope.requestID,
              let publicKey = envelope.publicKey
        else {
            pairingError = "Karşı cihaz eski eşleştirme protokolünü kullanıyor. FlowBridge'i iki cihazda da 0.4.0 veya daha yeni sürüme güncelle."
            bringDashboardToFront()
            return
        }
        guard let peer = peers.first(where: { $0.id == envelope.fromID }) else { return }
        let exchange = PairingKeyExchange()
        guard let peerKey = try? exchange.derivePeerKey(
            remotePublicKey: publicKey,
            localID: deviceID,
            remoteID: peer.id
        ) else {
            pairingError = "Windows'tan gelen güvenli eşleştirme anahtarı doğrulanamadı. İki uygulamayı da yeniden başlatıp tekrar dene."
            bringDashboardToFront()
            return
        }
        pairingSessions[requestID] = PendingMacPairingSession(
            requestID: requestID,
            peer: peer,
            peerKey: peerKey
        )
        expirePairingSession(requestID, peerID: peer.id)
        peerControl.sendPairChallenge(
            to: peer.id,
            requestID: requestID,
            publicKey: exchange.publicKey
        )
        pairingRequest = PairingRequest(
            peer: peer,
            code: PairingKeyExchange.verificationCode(peerKey: peerKey),
            requestID: requestID,
            isIncoming: true,
            peerKey: peerKey
        )
        bringDashboardToFront()
    }

    private func receivedPairChallenge(_ envelope: ControlEnvelope) {
        guard pairingRequest == nil else { return }
        guard envelope.version == 3,
              let requestID = envelope.requestID,
              let publicKey = envelope.publicKey,
              let exchange = outgoingExchanges.removeValue(forKey: requestID),
              let peer = peers.first(where: { $0.id == envelope.fromID })
        else { return }
        guard let peerKey = try? exchange.derivePeerKey(
                remotePublicKey: publicKey,
                localID: deviceID,
                remoteID: peer.id
              )
        else {
            updatePeer(peer.id) { $0.isPairingPending = false }
            pairingError = "Karşı cihazın eşleştirme yanıtı doğrulanamadı. İki uygulamayı da yeniden başlatıp tekrar dene."
            bringDashboardToFront()
            return
        }
        pairingSessions[requestID] = PendingMacPairingSession(
            requestID: requestID,
            peer: peer,
            peerKey: peerKey
        )
        expirePairingSession(requestID, peerID: peer.id)
        pairingRequest = PairingRequest(
            peer: peer,
            code: PairingKeyExchange.verificationCode(peerKey: peerKey),
            requestID: requestID,
            isIncoming: false,
            peerKey: peerKey
        )
        bringDashboardToFront()
    }

    private func receivedPairAccepted(_ envelope: ControlEnvelope) {
        guard let requestID = envelope.requestID,
              let session = pairingSessions[requestID],
              session.peer.id == envelope.fromID
        else { return }
        guard ControlAuthentication.verify(
            envelope.authentication,
            type: ControlMessageType.pairAccepted.rawValue,
            fromID: envelope.fromID,
            toID: deviceID,
            requestID: requestID,
            key: session.peerKey
        ) else { return }
        session.remoteApproved = true
        tryCompletePairing(session)
    }

    private func expirePairingSession(_ requestID: String, peerID: String) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 30_000_000_000)
            guard let self, self.pairingSessions.removeValue(forKey: requestID) != nil else { return }
            self.updatePeer(peerID) { $0.isPairingPending = false }
            if self.pairingRequest?.requestID == requestID { self.pairingRequest = nil }
        }
    }

    private func receivedUnpair(_ envelope: ControlEnvelope) {
        guard let key = PeerKeychain.load(peerID: envelope.fromID),
              ControlAuthentication.verify(
                envelope.authentication,
                type: ControlMessageType.unpair.rawValue,
                fromID: envelope.fromID,
                toID: deviceID,
                requestID: nil,
                key: key
              )
        else { return }
        removeTrustLocally(peerID: envelope.fromID)
    }

    private func tryCompletePairing(_ session: PendingMacPairingSession) {
        guard session.localApproved, session.remoteApproved else { return }
        pairingSessions.removeValue(forKey: session.requestID)
        PeerKeychain.save(session.peerKey, peerID: session.peer.id)
        mouseController.invalidatePeerKey(session.peer.id)
        mouseReceiver.invalidateKey(for: session.peer.id)
        trustedPeerIDs.insert(session.peer.id)
        persistTrustedPeers()
        updatePeer(session.peer.id) {
            $0.isTrusted = true
            $0.isPairingPending = false
        }
        refreshMouseConfiguration()
    }

    private func removeTrustLocally(peerID: String) {
        trustedPeerIDs.remove(peerID)
        PeerKeychain.remove(peerID: peerID)
        mouseController.invalidatePeerKey(peerID)
        mouseReceiver.invalidateKey(for: peerID)
        pairingSessions = pairingSessions.filter { $0.value.peer.id != peerID }
        persistTrustedPeers()
        updatePeer(peerID) {
            $0.isTrusted = false
            $0.isPairingPending = false
        }
        refreshMouseConfiguration()
    }

    private func upsertPeer(_ candidate: PeerDevice) {
        if let index = peers.firstIndex(where: { $0.id == candidate.id }) {
            let trusted = peers[index].isTrusted || trustedPeerIDs.contains(candidate.id)
            let pending = peers[index].isPairingPending
            peers[index] = candidate
            peers[index].isTrusted = trusted
            peers[index].isPairingPending = pending && !trusted
        } else {
            var peer = candidate
            peer.isTrusted = trustedPeerIDs.contains(candidate.id)
            peers.append(peer)
        }
        peers.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func updatePeer(_ peerID: String, update: (inout PeerDevice) -> Void) {
        guard let index = peers.firstIndex(where: { $0.id == peerID }) else { return }
        update(&peers[index])
    }

    private func pruneUnavailablePeers() {
        let cutoff = Date().addingTimeInterval(-7)
        peers.removeAll { peer in
            !bonjourPeerIDs.contains(peer.id) && (controlLastSeen[peer.id] ?? .distantPast) < cutoff
        }
    }

    private var trustedMousePeer: PeerDevice? {
        peers.first { $0.isTrusted }
    }

    private func exitEdge(for peer: PeerDevice) -> TransferEdge {
        TransferPolicy.exitEdge(
            localID: deviceID,
            localPlatform: "macOS",
            peerID: peer.id,
            peerPlatform: peer.platform
        )
    }

    private func refreshMouseConfiguration() {
        let target = trustedMousePeer
        let shouldEnable = isRunning
            && mouseSharingEnabled
            && accessibility == .granted
            && inputMonitoring == .granted
            && target != nil
        mouseController.configure(
            enabled: shouldEnable,
            targetPeerID: target?.id,
            exitEdge: target.map(exitEdge(for:)) ?? .right
        )
        mouseReceiver.setEnabled(shouldEnable)
        if !shouldEnable { mouseSharingActive = false }
    }

    private func bringDashboardToFront() {
        NSApp.activate(ignoringOtherApps: true)
        let dashboard = NSApp.windows.first {
            $0.canBecomeKey && !String(describing: type(of: $0)).contains("StatusBar")
        }
        dashboard?.makeKeyAndOrderFront(nil)
    }
}

private final class PendingMacPairingSession {
    let requestID: String
    let peer: PeerDevice
    let peerKey: Data
    var localApproved = false
    var remoteApproved = false

    init(requestID: String, peer: PeerDevice, peerKey: Data) {
        self.requestID = requestID
        self.peer = peer
        self.peerKey = peerKey
    }
}
