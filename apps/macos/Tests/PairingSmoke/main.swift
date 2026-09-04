import Foundation
import CryptoKit

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else {
        FileHandle.standardError.write(Data("FAILED: \(message)\n".utf8))
        exit(1)
    }
}

require(
    PairingCode.make(localID: "device-a", remoteID: "device-b")
        == PairingCode.make(localID: "device-b", remoteID: "device-a"),
    "pairing code must be independent of device order"
)
require(
    PairingCode.make(localID: "device-a", remoteID: "device-b")
        != PairingCode.make(localID: "device-a", remoteID: "attacker"),
    "a changed identity must change the pairing code"
)
let code = PairingCode.make(localID: "left", remoteID: "right")
require(code.count == 6, "pairing code must contain six characters")
require(Int(code) != nil, "pairing code must contain only digits")
require(code == "616188", "pairing code must match the cross-platform test vector")
require(
    TransferPolicy.exitEdge(localID: "a", localPlatform: "macOS", peerID: "b", peerPlatform: "windows") == .right,
    "Mac to Windows must use the established right edge"
)
require(
    TransferPolicy.exitEdge(localID: "b", localPlatform: "windows", peerID: "a", peerPlatform: "macOS") == .left,
    "Windows to Mac must use the established left edge"
)
let firstSamePlatformEdge = TransferPolicy.exitEdge(
    localID: "a", localPlatform: "macOS", peerID: "b", peerPlatform: "macOS"
)
let secondSamePlatformEdge = TransferPolicy.exitEdge(
    localID: "b", localPlatform: "macOS", peerID: "a", peerPlatform: "macOS"
)
require(firstSamePlatformEdge == .right && secondSamePlatformEdge == .left, "same-platform peers must use complementary edges")

let leftExchange = PairingKeyExchange()
let rightExchange = PairingKeyExchange()
let leftID = "0123456789abcdef0123456789abcdef"
let rightID = "fedcba9876543210fedcba9876543210"
let leftPeerKey = try leftExchange.derivePeerKey(
    remotePublicKey: rightExchange.publicKey,
    localID: leftID,
    remoteID: rightID
)
let rightPeerKey = try rightExchange.derivePeerKey(
    remotePublicKey: leftExchange.publicKey,
    localID: rightID,
    remoteID: leftID
)
require(leftPeerKey == rightPeerKey, "P-256 peers must derive the same key")
require(
    PairingKeyExchange.verificationCode(peerKey: leftPeerKey)
        == PairingKeyExchange.verificationCode(peerKey: rightPeerKey),
    "P-256 peers must show the same verification code"
)
let controlAuthentication = ControlAuthentication.make(
    type: "pairAccepted",
    fromID: leftID,
    toID: rightID,
    requestID: "request-1",
    key: leftPeerKey
)
require(
    ControlAuthentication.verify(
        controlAuthentication,
        type: "pairAccepted",
        fromID: leftID,
        toID: rightID,
        requestID: "request-1",
        key: rightPeerKey
    ),
    "authenticated control message must verify on the peer"
)
require(
    !ControlAuthentication.verify(
        controlAuthentication,
        type: "unpair",
        fromID: leftID,
        toID: rightID,
        requestID: nil,
        key: rightPeerKey
    ),
    "authentication must be bound to the control message"
)
let knownControlKey = Data((0...31).map(UInt8.init))
require(
    ControlAuthentication.make(
        type: "pairAccepted",
        fromID: leftID,
        toID: rightID,
        requestID: "request-1",
        key: knownControlKey
    ) == "e/3bi7qNcEhHaSkjOCvrheMqqSUQj7n48WG3PNi/nc8=",
    "control HMAC must match the cross-platform test vector"
)
let mouseNonce = try AES.GCM.Nonce(data: Data((0...11).map(UInt8.init)))
let mousePlaintext = Data("{\"kind\":\"move\",\"dx\":1.5}".utf8)
let mouseAAD = Data(
    "FlowBridge/mouse/v2|\(leftID)|\(rightID)|00112233445566778899aabbccddeeff|42".utf8
)
let mouseBox = try AES.GCM.seal(
    mousePlaintext,
    using: SymmetricKey(data: knownControlKey),
    nonce: mouseNonce,
    authenticating: mouseAAD
)
require(
    mouseBox.combined?.base64EncodedString()
        == "AAECAwQFBgcICQoLPCC9cquB4CGvLPj91MtUT+eupQ7BVWoB0Oyoc05zVjS18kbdos1bPA==",
    "mouse AES-GCM envelope must match the cross-platform test vector"
)

print("Pairing smoke tests passed")
