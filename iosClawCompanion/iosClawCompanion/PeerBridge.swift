@preconcurrency import MultipeerConnectivity
import Foundation

final class PeerBridge: NSObject, ObservableObject {
    enum Status: Equatable {
        case browsing
        case connecting
        case awaitingConfirmation
        case paired(String)
        case rejected
        case disconnected

        var label: String {
            switch self {
            case .browsing: "Looking for your Mac"
            case .connecting: "Connecting"
            case .awaitingConfirmation: "Confirming pairing code"
            case .paired(let name): "Paired with \(name)"
            case .rejected: "Pairing code was rejected"
            case .disconnected: "Disconnected"
            }
        }
    }

    @Published private(set) var peers: [MCPeerID] = []
    @Published private(set) var status: Status = .browsing

    private let localPeer = MCPeerID(displayName: UIDevice.current.name)
    private let store: AuditStore
    private lazy var session = MCSession(peer: localPeer, securityIdentity: nil, encryptionPreference: .required)
    private lazy var browser = MCNearbyServiceBrowser(peer: localPeer, serviceType: "iosclaw-v1")
    private var targetPeer: MCPeerID?
    private var pairingCode = ""

    init(store: AuditStore) {
        self.store = store
        super.init()
        session.delegate = self
        browser.delegate = self
        browser.startBrowsingForPeers()
    }

    deinit {
        browser.stopBrowsingForPeers()
        session.disconnect()
    }

    func pair(with peer: MCPeerID, code: String) {
        let normalizedCode = code.filter(\.isNumber)
        guard normalizedCode.count == 6 else { return }

        targetPeer = peer
        pairingCode = normalizedCode
        status = .connecting
        browser.invitePeer(peer, to: session, withContext: nil, timeout: 20)
    }

    private func send(_ message: BridgeMessage) {
        guard !session.connectedPeers.isEmpty else { return }
        do {
            try session.send(try BridgeCodec.encode(message), toPeers: session.connectedPeers, with: .reliable)
        } catch {
            status = .disconnected
        }
    }

    private func receive(_ data: Data, from peer: MCPeerID) {
        guard let message = try? BridgeCodec.decode(data) else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch message.kind {
            case .paired:
                self.status = .paired(peer.displayName)
            case .rejected:
                self.status = .rejected
            case .auditStep:
                guard let step = message.step else { return }
                self.store.append(step)
                self.send(.acknowledgement(for: step.id))
            case .pairRequest, .acknowledgement:
                break
            }
        }
    }
}

extension PeerBridge: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch state {
            case .connected:
                self.status = .awaitingConfirmation
                self.send(.pairRequest(code: self.pairingCode))
            case .notConnected:
                if case .rejected = self.status { return }
                self.status = .disconnected
            case .connecting:
                self.status = .connecting
            @unknown default:
                self.status = .disconnected
            }
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        receive(data, from: peerID)
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension PeerBridge: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.peers.contains(peerID) else { return }
            self.peers.append(peerID)
            self.peers.sort { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.peers.removeAll { $0 == peerID }
        }
    }
}
