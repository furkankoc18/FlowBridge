import Foundation
import Network

final class BonjourDiscovery {
    var onPeersChanged: (([PeerDevice]) -> Void)?
    var onStatusChanged: ((DiscoveryStatus) -> Void)?

    private let queue = DispatchQueue(label: "com.flowbridge.app.discovery")
    private let localID: String
    private let serviceName: String
    private var browser: NWBrowser?
    private var listener: NWListener?

    init(localID: String, deviceName: String) {
        self.localID = localID
        let safeName = deviceName
            .replacingOccurrences(of: ".", with: "-")
            .replacingOccurrences(of: "|", with: "-")
            .prefix(20)
        serviceName = "FB-\(localID)-\(safeName)"
    }

    func start() {
        guard browser == nil, listener == nil else { return }
        onStatusChanged?(.starting)

        do {
            let listener = try NWListener(using: .tcp, on: .any)
            listener.service = NWListener.Service(
                name: serviceName,
                type: "_flowbridge._tcp"
            )
            listener.newConnectionHandler = { connection in
                // The production listener will hand this socket to the Rust TLS core.
                // Until FFI lands, rejecting it is safer than accepting plaintext.
                connection.cancel()
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard let self else { return }
                switch state {
                case .ready:
                    self.onStatusChanged?(.ready)
                case let .failed(error):
                    self.onStatusChanged?(.failed(error.localizedDescription))
                case .cancelled:
                    self.onStatusChanged?(.stopped)
                default:
                    break
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            onStatusChanged?(.failed(error.localizedDescription))
        }

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjour(type: "_flowbridge._tcp", domain: nil),
            using: parameters
        )
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            self?.publish(results)
        }
        browser.stateUpdateHandler = { [weak self] state in
            if case let .failed(error) = state {
                self?.onStatusChanged?(.failed(error.localizedDescription))
            }
        }
        browser.start(queue: queue)
        self.browser = browser
    }

    func stop() {
        browser?.cancel()
        listener?.cancel()
        browser = nil
        listener = nil
        onPeersChanged?([])
        onStatusChanged?(.stopped)
    }

    private func publish(_ results: Set<NWBrowser.Result>) {
        let peers = results.compactMap { result -> PeerDevice? in
            guard case let .service(name, _, domain, interface) = result.endpoint,
                  name != serviceName
            else { return nil }

            let parts = name.split(separator: "-", maxSplits: 2).map(String.init)
            let identifier = parts.count > 1 ? parts[1] : name
            guard identifier != localID else { return nil }
            let displayName = parts.count > 2 ? parts[2] : "Yakındaki bilgisayar"
            let endpoint = [domain, interface?.name].compactMap { $0 }.joined(separator: " · ")
            return PeerDevice(
                id: identifier,
                name: displayName,
                platform: "Mac veya Windows",
                endpointDescription: endpoint,
                isTrusted: false,
                isPairingPending: false
            )
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        onPeersChanged?(peers)
    }
}
