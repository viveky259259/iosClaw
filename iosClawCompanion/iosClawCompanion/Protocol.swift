import Foundation

/// Deliberately redacted audit data. This protocol must never carry credentials,
/// passcodes, one-time codes, biometric data, screenshots, or raw message bodies.
struct AuditStep: Codable, Identifiable, Hashable {
    let id: UUID
    let runID: UUID
    let occurredAt: Date
    let appName: String
    let action: String
    let summary: String
    let effect: Effect

    enum Effect: String, Codable, CaseIterable {
        case observe
        case navigate
        case draft
        case approvalRequired
        case blocked

        var displayName: String {
            switch self {
            case .observe: "Observed"
            case .navigate: "Navigated"
            case .draft: "Drafted"
            case .approvalRequired: "Approval required"
            case .blocked: "Blocked safely"
            }
        }
    }
}

struct BridgeMessage: Codable {
    enum Kind: String, Codable {
        case pairRequest
        case paired
        case rejected
        case auditStep
        case acknowledgement
    }

    let kind: Kind
    let pairingCode: String?
    let step: AuditStep?
    let stepID: UUID?

    static func pairRequest(code: String) -> BridgeMessage {
        BridgeMessage(kind: .pairRequest, pairingCode: code, step: nil, stepID: nil)
    }

    static func acknowledgement(for stepID: UUID) -> BridgeMessage {
        BridgeMessage(kind: .acknowledgement, pairingCode: nil, step: nil, stepID: stepID)
    }
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
