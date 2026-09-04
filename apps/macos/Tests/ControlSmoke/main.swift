import Foundation

let pairingCompleted = DispatchSemaphore(value: 0)
let requestID = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
let reverseRequestID = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
let windowsID = "11111111111111111111111111111111"
let macID = "22222222222222222222222222222222"
let exchange = PairingKeyExchange()
var derivedKey: Data?
var reverseDerivedKey: Data?
var requestSent = false
var windowsAddress: String?
let service = PeerControlService(
    localID: macID,
    localName: "Mac-Control-Smoke"
)
service.onHello = { envelope in
    guard envelope.fromID == windowsID, !requestSent else { return }
    requestSent = true
    service.sendPairRequest(to: windowsID, requestID: requestID, publicKey: exchange.publicKey)
}
service.onPeerAddress = { peerID, address in
    if peerID == windowsID { windowsAddress = address }
}
service.onPairChallenge = { envelope in
    guard envelope.fromID == windowsID,
          envelope.requestID == requestID,
          let publicKey = envelope.publicKey,
          let key = try? exchange.derivePeerKey(
            remotePublicKey: publicKey,
            localID: macID,
            remoteID: windowsID
          )
    else { return }
    derivedKey = key
    let authentication = ControlAuthentication.make(
        type: ControlMessageType.pairAccepted.rawValue,
        fromID: macID,
        toID: windowsID,
        requestID: requestID,
        key: key
    )
    service.sendPairAccepted(to: windowsID, requestID: requestID, authentication: authentication)
}
service.onPairRequest = { envelope in
    guard envelope.fromID == windowsID,
          envelope.requestID == reverseRequestID,
          let publicKey = envelope.publicKey
    else { return }
    let reverseExchange = PairingKeyExchange()
    guard let key = try? reverseExchange.derivePeerKey(
        remotePublicKey: publicKey,
        localID: macID,
        remoteID: windowsID
    ) else { return }
    reverseDerivedKey = key
    service.sendPairChallenge(
        to: windowsID,
        requestID: reverseRequestID,
        publicKey: reverseExchange.publicKey
    )
}
service.onPairAccepted = { envelope in
    guard envelope.fromID == windowsID else { return }
    if envelope.requestID == requestID, let derivedKey {
        print("Mac initiated pairing passed: \(PairingKeyExchange.verificationCode(peerKey: derivedKey))")
    } else if envelope.requestID == reverseRequestID, let reverseDerivedKey {
        guard let windowsAddress, !windowsAddress.isEmpty else { return }
        let authentication = ControlAuthentication.make(
            type: ControlMessageType.pairAccepted.rawValue,
            fromID: macID,
            toID: windowsID,
            requestID: reverseRequestID,
            key: reverseDerivedKey
        )
        service.sendPairAccepted(to: windowsID, requestID: reverseRequestID, authentication: authentication)
        print("Windows initiated pairing passed via \(windowsAddress): \(PairingKeyExchange.verificationCode(peerKey: reverseDerivedKey))")
        pairingCompleted.signal()
    }
}
service.start()

guard pairingCompleted.wait(timeout: .now() + 8) == .success else {
    FileHandle.standardError.write(Data("Mac/Windows pairing control handshake timed out.\n".utf8))
    exit(1)
}
service.stop()
