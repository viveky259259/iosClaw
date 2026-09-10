import Foundation

/// Portable, versioned flow schema. A future remote control plane can enqueue
/// this exact payload without knowing anything about the local SwiftUI app.
struct QAFlow: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 1

    let id: UUID
    var schemaVersion: Int
    var name: String
    var appBundleID: String
    var steps: [QAFlowStep]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        schemaVersion: Int = QAFlow.currentSchemaVersion,
        name: String,
        appBundleID: String,
        steps: [QAFlowStep],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.schemaVersion = schemaVersion
        self.name = name
        self.appBundleID = appBundleID
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let example = QAFlow(
        name: "Example visible-element check",
        appBundleID: "com.apple.mobilesafari",
        steps: [
            QAFlowStep(
                name: "Capture initial state",
                action: .screenshot,
                captureAfterStep: true
            ),
            QAFlowStep(
                name: "Confirm an element is visible",
                action: .assertVisible,
                selector: QASelector(strategy: .accessibilityID, value: "Replace with a stable accessibility identifier")
            )
        ]
    )

    /// Builds a narrowly-scoped, deterministic message flow. The caller must
    /// supply selectors captured from the target app; this factory never
    /// substitutes a visual guess or coordinate tap for a selector.
    static func verifiedMessage(
        recipient: String,
        message: String,
        appBundleID: String,
        recipientSelector: QASelector,
        conversationSelector: QASelector,
        composerSelector: QASelector,
        sendSelector: QASelector,
        deliveredMessageSelector: QASelector
    ) throws -> QAFlow {
        let fields = [
            recipient,
            message,
            appBundleID,
            recipientSelector.value,
            conversationSelector.value,
            composerSelector.value,
            sendSelector.value,
            deliveredMessageSelector.value
        ]
        guard fields.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            throw MessageFlowError.missingRequiredValue
        }

        return QAFlow(
            name: "Verified message to \(recipient)",
            appBundleID: appBundleID,
            steps: [
                QAFlowStep(
                    name: "Verify recipient \(recipient)",
                    action: .assertVisible,
                    selector: recipientSelector,
                    captureAfterStep: true
                ),
                QAFlowStep(
                    name: "Open verified conversation",
                    action: .tap,
                    selector: recipientSelector,
                    postcondition: conversationSelector,
                    captureAfterStep: true
                ),
                QAFlowStep(
                    name: "Verify message composer",
                    action: .assertVisible,
                    selector: composerSelector
                ),
                QAFlowStep(
                    name: "Enter approved message",
                    action: .typeText,
                    selector: composerSelector,
                    parameters: ["text": .string(message)]
                ),
                QAFlowStep(
                    name: "Verify send control",
                    action: .assertVisible,
                    selector: sendSelector
                ),
                QAFlowStep(
                    name: "Send approved message",
                    action: .tap,
                    selector: sendSelector,
                    postcondition: deliveredMessageSelector,
                    captureAfterStep: true
                )
            ]
        )
    }
}

enum MessageFlowError: LocalizedError {
    case missingRequiredValue

    var errorDescription: String? {
        switch self {
        case .missingRequiredValue:
            "A verified message flow needs all selectors, the recipient, and the exact message."
        }
    }
}

struct QAFlowStep: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var action: QAActionKind
    var selector: QASelector?
    var parameters: [String: JSONValue]
    var postcondition: QASelector?
    var captureAfterStep: Bool

    init(
        id: UUID = UUID(),
        name: String,
        action: QAActionKind,
        selector: QASelector? = nil,
        parameters: [String: JSONValue] = [:],
        postcondition: QASelector? = nil,
        captureAfterStep: Bool = false
    ) {
        self.id = id
        self.name = name
        self.action = action
        self.selector = selector
        self.parameters = parameters
        self.postcondition = postcondition
        self.captureAfterStep = captureAfterStep
    }
}

enum QAActionKind: String, Codable, CaseIterable, Equatable {
    case tap
    case doubleTap
    case longPress
    case swipe
    case scroll
    case drag
    case pinch
    case rotate
    case typeText
    case assertVisible
    case screenshot

    var title: String {
        switch self {
        case .tap: "Tap"
        case .doubleTap: "Double tap"
        case .longPress: "Long press"
        case .swipe: "Swipe"
        case .scroll: "Scroll"
        case .drag: "Drag"
        case .pinch: "Pinch"
        case .rotate: "Rotate"
        case .typeText: "Type text"
        case .assertVisible: "Assert visible"
        case .screenshot: "Screenshot"
        }
    }
}

struct QASelector: Codable, Equatable {
    enum Strategy: String, Codable, CaseIterable {
        case accessibilityID
        case predicate
        case classChain
        case xpath

        var wdaUsing: String {
            switch self {
            case .accessibilityID: "accessibility id"
            case .predicate: "-ios predicate string"
            case .classChain: "-ios class chain"
            case .xpath: "xpath"
            }
        }
    }

    var strategy: Strategy
    var value: String
}

struct QARunRecord: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable, Equatable {
        case running
        case passed
        case failed
        case cancelled
    }

    let id: UUID
    let flowID: UUID
    let flowName: String
    let deviceKey: String
    let startedAt: Date
    var finishedAt: Date?
    var outcome: Outcome
    var events: [QAStepEvent]
    var artifacts: [QAArtifact]
    var failureSummary: String?

    init(flow: QAFlow, deviceKey: String) {
        id = UUID()
        flowID = flow.id
        flowName = flow.name
        self.deviceKey = deviceKey
        startedAt = .now
        finishedAt = nil
        outcome = .running
        events = []
        artifacts = []
        failureSummary = nil
    }
}

struct QAStepEvent: Codable, Identifiable, Equatable {
    enum Outcome: String, Codable, Equatable {
        case passed
        case failed
    }

    let id: UUID
    let stepID: UUID
    let stepName: String
    let action: QAActionKind
    let outcome: Outcome
    let durationMilliseconds: Int
    let detail: String

    init(step: QAFlowStep, outcome: Outcome, durationMilliseconds: Int, detail: String) {
        id = UUID()
        stepID = step.id
        stepName = step.name
        action = step.action
        self.outcome = outcome
        self.durationMilliseconds = durationMilliseconds
        self.detail = detail
    }
}

struct QAArtifact: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, Equatable {
        case screenshot
    }

    let id: UUID
    let kind: Kind
    let relativePath: String
    let sha256: String
    let createdAt: Date
}

/// Codable JSON values keep the flow protocol open for WDA gesture parameters
/// without forcing a schema migration whenever an endpoint adds an option.
indirect enum JSONValue: Codable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var stringValue: String? {
        if case .string(let value) = self { return value }
        return nil
    }

    var numberValue: Double? {
        if case .number(let value) = self { return value }
        return nil
    }

    var boolValue: Bool? {
        if case .bool(let value) = self { return value }
        return nil
    }

    var objectValue: [String: JSONValue]? {
        if case .object(let value) = self { return value }
        return nil
    }
}
