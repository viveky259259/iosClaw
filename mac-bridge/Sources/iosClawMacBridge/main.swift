import Foundation
import MultipeerConnectivity

struct AuditStep: Codable, Identifiable, Hashable {
    let id: UUID
    let runID: UUID
    let occurredAt: Date
    let appName: String
    let action: String
    let summary: String
    let effect: Effect

    enum Effect: String, Codable { case observe, navigate, draft, approvalRequired, blocked }
}

struct BridgeMessage: Codable {
    enum Kind: String, Codable { case pairRequest, paired, rejected, auditStep, acknowledgement }
    let kind: Kind
    let pairingCode: String?
    let step: AuditStep?
    let stepID: UUID?
}

enum BridgeCodec {
    static func encode(_ message: BridgeMessage) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(message)
    }

    static func decode(_ data: Data) throws -> BridgeMessage {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BridgeMessage.self, from: data)
    }
}

final class MacBridge: NSObject, MCSessionDelegate, MCNearbyServiceAdvertiserDelegate {
    private let peer = MCPeerID(displayName: Host.current().localizedName ?? "iosclaw-mac")
    private lazy var session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
    private lazy var advertiser = MCNearbyServiceAdvertiser(peer: peer, discoveryInfo: ["version": "1"], serviceType: "iosclaw-v1")
    private let pairingCode: String
    private let stepsURL: URL
    private var pairedPeers = Set<MCPeerID>()
    private var acknowledgedStepIDs = [MCPeerID: Set<UUID>]()
    private var timer: Timer?

    init(pairingCode: String, stepsURL: URL) {
        self.pairingCode = pairingCode
        self.stepsURL = stepsURL
        super.init()
        session.delegate = self
        advertiser.delegate = self
    }

    func start() {
        advertiser.startAdvertisingPeer()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.publishNewSteps()
        }
        print("iosClaw Mac Bridge is advertising as \(peer.displayName).")
        print("Pairing code: \(pairingCode)")
        print("Watching \(stepsURL.path)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // The encrypted transport is established first. The short-lived code below
        // controls whether this peer may receive any audit events.
        invitationHandler(true, session)
    }

    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        if state == .notConnected {
            pairedPeers.remove(peerID)
            acknowledgedStepIDs.removeValue(forKey: peerID)
            print("Disconnected: \(peerID.displayName)")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        DispatchQueue.main.async { [weak self] in
            self?.handle(data, from: peerID)
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    private func handle(_ data: Data, from peer: MCPeerID) {
        guard let message = try? BridgeCodec.decode(data) else { return }

        switch message.kind {
        case .pairRequest:
            guard message.pairingCode == pairingCode else {
                send(BridgeMessage(kind: .rejected, pairingCode: nil, step: nil, stepID: nil), to: [peer])
                print("Rejected pairing from \(peer.displayName).")
                return
            }
            pairedPeers.insert(peer)
            acknowledgedStepIDs[peer] = []
            send(BridgeMessage(kind: .paired, pairingCode: nil, step: nil, stepID: nil), to: [peer])
            print("Paired: \(peer.displayName)")
        case .acknowledgement:
            if let stepID = message.stepID {
                acknowledgedStepIDs[peer, default: []].insert(stepID)
                print("Companion acknowledged \(stepID.uuidString)")
            }
        case .paired, .rejected, .auditStep:
            break
        }
    }

    private func publishNewSteps() {
        guard !pairedPeers.isEmpty,
              let data = try? Data(contentsOf: stepsURL),
              let contents = String(data: data, encoding: .utf8)
        else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for line in contents.split(whereSeparator: \.isNewline) {
            guard let step = try? decoder.decode(AuditStep.self, from: Data(line.utf8)) else { continue }
            let recipients = pairedPeers.filter { !acknowledgedStepIDs[$0, default: []].contains(step.id) }
            send(BridgeMessage(kind: .auditStep, pairingCode: nil, step: step, stepID: nil), to: Array(recipients))
        }
    }

    private func send(_ message: BridgeMessage, to peers: [MCPeerID]) {
        guard !peers.isEmpty, let data = try? BridgeCodec.encode(message) else { return }
        do {
            try session.send(data, toPeers: peers, with: .reliable)
        } catch {
            print("Send failed: \(error.localizedDescription)")
        }
    }
}

let arguments = CommandLine.arguments
let codeIndex = arguments.firstIndex(of: "--pair-code")
let pathIndex = arguments.firstIndex(of: "--steps")
let pairingCode = codeIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    ?? String(format: "%06d", Int.random(in: 0...999_999))
let stepsPath = pathIndex.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
    ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".iosclaw/steps.jsonl").path

let bridge = MacBridge(pairingCode: pairingCode, stepsURL: URL(fileURLWithPath: stepsPath))
bridge.start()
RunLoop.main.run()
