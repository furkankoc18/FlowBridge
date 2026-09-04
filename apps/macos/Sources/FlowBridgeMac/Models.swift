import CryptoKit
import Foundation

enum TransferEdge: String {
    case left
    case right

    var opposite: TransferEdge { self == .left ? .right : .left }
}

enum TransferPolicy {
    static func exitEdge(
        localID: String,
        localPlatform: String,
        peerID: String,
        peerPlatform: String
    ) -> TransferEdge {
        let localIsMac = localPlatform.localizedCaseInsensitiveContains("mac")
        let peerIsMac = peerPlatform.localizedCaseInsensitiveContains("mac")
        let localIsWindows = localPlatform.localizedCaseInsensitiveContains("windows")
        let peerIsWindows = peerPlatform.localizedCaseInsensitiveContains("windows")
        if localIsMac && peerIsWindows { return .right }
        if localIsWindows && peerIsMac { return .left }
        return localID < peerID ? .right : .left
    }
}

struct PeerDevice: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let platform: String
    let endpointDescription: String
    var isTrusted: Bool
    var isPairingPending = false
}

struct PairingRequest: Identifiable, Equatable {
    let peer: PeerDevice
    let code: String
    let requestID: String
    let isIncoming: Bool
    let peerKey: Data

    var id: String { requestID }
}

enum DiscoveryStatus: Equatable {
    case stopped
    case starting
    case ready
    case failed(String)

    var title: String {
        switch self {
        case .stopped: "Kapalı"
        case .starting: "Başlatılıyor"
        case .ready: "Ağ taranıyor"
        case .failed: "Bağlantı sorunu"
        }
    }

    var detail: String? {
        if case let .failed(message) = self { message } else { nil }
    }
}

enum PermissionState: Equatable {
    case granted
    case missing

    var title: String {
        self == .granted ? "Hazır" : "İzin gerekli"
    }
}

enum SidebarSection: String, CaseIterable, Identifiable {
    case overview
    case devices
    case privacy
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Genel Bakış"
        case .devices: "Cihazlar"
        case .privacy: "Gizlilik"
        case .diagnostics: "Teşhis"
        }
    }

    var icon: String {
        switch self {
        case .overview: "rectangle.2.swap"
        case .devices: "laptopcomputer.and.desktop"
        case .privacy: "hand.raised.fill"
        case .diagnostics: "stethoscope"
        }
    }
}

enum PairingCode {
    static func make(localID: String, remoteID: String) -> String {
        let transcript = [localID, remoteID].sorted().joined(separator: "|")
        let digest = SHA256.hash(data: Data(transcript.utf8))
        let value = digest.prefix(4).reduce(UInt32.zero) { partial, byte in
            (partial << 8) | UInt32(byte)
        } % 1_000_000
        return String(format: "%06u", value)
    }
}
