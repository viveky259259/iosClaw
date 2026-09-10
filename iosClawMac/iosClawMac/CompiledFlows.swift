import Dispatch
import Foundation

enum CompiledFlowStatus: String, Codable, Equatable {
    case draft
    case validated
    case active
    case quarantined
}

enum CompiledFlowInputType: String, Codable, Equatable {
    case appReference
    case string
    case secretString
}

enum CompiledFlowInputRetention: String, Codable, Equatable {
    case package
    case runOnly
}

struct CompiledFlowInputSpec: Codable, Equatable {
    let type: CompiledFlowInputType
    let required: Bool
    let retention: CompiledFlowInputRetention
}

enum CompiledFlowValue: Codable, Equatable {
    case literal(String)
    case input(String)

    var inputReference: String? {
        guard case .input(let name) = self else { return nil }
        return name
    }

    func resolve(using inputs: [String: String]) -> String? {
        switch self {
        case .literal(let value): value
        case .input(let name): inputs[name]
        }
    }
}

struct CompiledScreenPredicate: Codable, Equatable {
    let allowedStates: [SemanticScreenState]
    let exactTexts: [CompiledFlowValue]

    init(
        allowedStates: [SemanticScreenState],
        exactTexts: [CompiledFlowValue] = []
    ) {
        self.allowedStates = allowedStates
        self.exactTexts = exactTexts
    }

    func matches(_ observation: CompiledFlowObservation, inputs: [String: String]) -> Bool {
        guard allowedStates.contains(observation.state) else { return false }
        let visible = Set(observation.visibleTexts.map(SemanticTargetResolver.normalized))
        return exactTexts.allSatisfy { value in
            guard let resolved = value.resolve(using: inputs) else { return false }
            return visible.contains(SemanticTargetResolver.normalized(resolved))
        }
    }

    static let anyActionable = CompiledScreenPredicate(
        allowedStates: [.generic, .chatList, .conversation]
    )
}

enum CompiledFlowPrimitive: String, Codable, Equatable {
    case home
    case launchAppViaSpotlight
    case ensureChatList
    case keyboardFindAndActivate
    case replaceVisibleText
    case tapVisibleText
}

enum CompiledFlowEffect: String, Codable, Equatable {
    case navigate
    case draft
    case externalCommunication
    case destructive
    case financial
    case accountOrSecurity

    var isSensitive: Bool {
        switch self {
        case .navigate, .draft: false
        case .externalCommunication, .destructive, .financial, .accountOrSecurity: true
        }
    }
}

struct CompiledFlowStep: Codable, Equatable, Identifiable {
    let id: String
    let primitive: CompiledFlowPrimitive
    let arguments: [String: CompiledFlowValue]
    let precondition: CompiledScreenPredicate
    let postcondition: CompiledScreenPredicate
    let timeoutMilliseconds: Int
    let retryLimit: Int
    let effect: CompiledFlowEffect
    let requiresApproval: Bool

    init(
        id: String,
        primitive: CompiledFlowPrimitive,
        arguments: [String: CompiledFlowValue] = [:],
        precondition: CompiledScreenPredicate,
        postcondition: CompiledScreenPredicate,
        timeoutMilliseconds: Int = 3_000,
        retryLimit: Int = 0,
        effect: CompiledFlowEffect,
        requiresApproval: Bool = false
    ) {
        self.id = id
        self.primitive = primitive
        self.arguments = arguments
        self.precondition = precondition
        self.postcondition = postcondition
        self.timeoutMilliseconds = timeoutMilliseconds
        self.retryLimit = retryLimit
        self.effect = effect
        self.requiresApproval = requiresApproval
    }
}

struct CompiledFlowPackage: Codable, Equatable, Identifiable {
    let schemaVersion: Int
    let id: String
    let version: Int
    let status: CompiledFlowStatus
    let intentID: String
    let displayName: String
    let inputSpecs: [String: CompiledFlowInputSpec]
    let supportedSources: [ScreenSource]
    /// Empty means the flow is app-agnostic. Values are semantic aliases, not
    /// bundle IDs inferred from an untrusted screen.
    let appAliases: [String]
    let steps: [CompiledFlowStep]
    let provenance: String

    init(
        schemaVersion: Int = 1,
        id: String,
        version: Int,
        status: CompiledFlowStatus,
        intentID: String,
        displayName: String,
        inputSpecs: [String: CompiledFlowInputSpec],
        supportedSources: [ScreenSource],
        appAliases: [String] = [],
        steps: [CompiledFlowStep],
        provenance: String
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.version = version
        self.status = status
        self.intentID = intentID
        self.displayName = displayName
        self.inputSpecs = inputSpecs
        self.supportedSources = supportedSources
        self.appAliases = appAliases
        self.steps = steps
        self.provenance = provenance
    }

    func replacing(version: Int) -> CompiledFlowPackage {
        CompiledFlowPackage(
            schemaVersion: schemaVersion,
            id: id,
            version: version,
            status: status,
            intentID: intentID,
            displayName: displayName,
            inputSpecs: inputSpecs,
            supportedSources: supportedSources,
            appAliases: appAliases,
            steps: steps,
            provenance: provenance
        )
    }
}

enum CompiledFlowValidationIssue: Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case invalidIdentity
    case invalidVersion
    case missingSource
    case automaticSource
    case missingSteps
    case duplicateStepID(String)
    case invalidTimeout(String)
    case invalidRetryLimit(String)
    case missingEvidence(String)
    case insufficientGenericEvidence(String)
    case unknownInput(String)
    case missingRequiredArgument(step: String, argument: String)
    case forbiddenArgument(step: String, argument: String)
    case unsafeSecretRetention(String)
    case missingApproval(String)
    case unnecessaryApproval(String)

    var description: String {
        switch self {
        case .unsupportedSchema(let version): "Unsupported compiled-flow schema version \(version)."
        case .invalidIdentity: "Flow and intent identifiers must be non-empty."
        case .invalidVersion: "Flow version must be positive."
        case .missingSource: "At least one concrete screen source is required."
        case .automaticSource: "The automatic source selector cannot be persisted in a compiled flow."
        case .missingSteps: "A compiled flow requires at least one step."
        case .duplicateStepID(let id): "Step id '\(id)' is duplicated."
        case .invalidTimeout(let id): "Step '\(id)' has an invalid timeout."
        case .invalidRetryLimit(let id): "Step '\(id)' has an invalid retry limit."
        case .missingEvidence(let id): "Step '\(id)' requires explicit precondition and postcondition states."
        case .insufficientGenericEvidence(let id): "Step '\(id)' requires at least two stable anchors for a generic screen."
        case .unknownInput(let name): "Flow value references undefined input '\(name)'."
        case .missingRequiredArgument(let step, let argument): "Step '\(step)' requires argument '\(argument)'."
        case .forbiddenArgument(let step, let argument): "Step '\(step)' contains forbidden geometry argument '\(argument)'."
        case .unsafeSecretRetention(let name): "Secret input '\(name)' must have run-only retention."
        case .missingApproval(let id): "Sensitive step '\(id)' requires approval."
        case .unnecessaryApproval(let id): "Non-sensitive step '\(id)' may not request effect approval."
        }
    }
}

enum CompiledFlowValidator {
    static func validate(_ flow: CompiledFlowPackage) -> [CompiledFlowValidationIssue] {
        var issues: [CompiledFlowValidationIssue] = []
        if flow.schemaVersion != 1 { issues.append(.unsupportedSchema(flow.schemaVersion)) }
        if flow.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || flow.intentID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.invalidIdentity)
        }
        if flow.version < 1 { issues.append(.invalidVersion) }
        if flow.supportedSources.isEmpty { issues.append(.missingSource) }
        if flow.supportedSources.contains(.automatic) { issues.append(.automaticSource) }
        if flow.steps.isEmpty { issues.append(.missingSteps) }

        for (name, spec) in flow.inputSpecs where spec.type == .secretString && spec.retention != .runOnly {
            issues.append(.unsafeSecretRetention(name))
        }

        var stepIDs: Set<String> = []
        for step in flow.steps {
            if !stepIDs.insert(step.id).inserted { issues.append(.duplicateStepID(step.id)) }
            if !(50...15_000).contains(step.timeoutMilliseconds) { issues.append(.invalidTimeout(step.id)) }
            if !(0...2).contains(step.retryLimit) { issues.append(.invalidRetryLimit(step.id)) }
            if step.precondition.allowedStates.isEmpty
                || step.postcondition.allowedStates.isEmpty
                || step.precondition.allowedStates.contains(.unknown)
                || step.postcondition.allowedStates.contains(.unknown) {
                issues.append(.missingEvidence(step.id))
            }
            let targetBased = step.primitive == .tapVisibleText || step.primitive == .replaceVisibleText
            if targetBased
                && step.precondition.allowedStates.contains(.generic)
                && step.precondition.exactTexts.count < 2 {
                issues.append(.insufficientGenericEvidence(step.id))
            }
            if step.postcondition.allowedStates == [.generic]
                && step.postcondition.exactTexts.count < 2 {
                issues.append(.insufficientGenericEvidence(step.id))
            }
            if step.effect.isSensitive && !step.requiresApproval { issues.append(.missingApproval(step.id)) }
            if !step.effect.isSensitive && step.requiresApproval { issues.append(.unnecessaryApproval(step.id)) }

            let forbiddenFragments = ["coordinate", "bounds", "position", "point"]
            let forbiddenExact = ["x", "y", "width", "height"]
            for key in step.arguments.keys {
                let normalized = SemanticTargetResolver.normalized(key)
                if forbiddenExact.contains(normalized)
                    || forbiddenFragments.contains(where: normalized.contains) {
                    issues.append(.forbiddenArgument(step: step.id, argument: key))
                }
            }

            for value in Array(step.arguments.values)
                + step.precondition.exactTexts
                + step.postcondition.exactTexts {
                if let reference = value.inputReference, flow.inputSpecs[reference] == nil {
                    issues.append(.unknownInput(reference))
                }
            }

            for required in requiredArguments(for: step.primitive) where step.arguments[required] == nil {
                issues.append(.missingRequiredArgument(step: step.id, argument: required))
            }
        }
        return issues
    }

    private static func requiredArguments(for primitive: CompiledFlowPrimitive) -> [String] {
        switch primitive {
        case .home, .ensureChatList: []
        case .launchAppViaSpotlight: ["app"]
        case .keyboardFindAndActivate: ["query", "confirmation"]
        case .replaceVisibleText: ["target", "value"]
        case .tapVisibleText: ["target"]
        }
    }
}

enum CompiledFlowRegistryError: LocalizedError, Equatable {
    case invalidPackages([CompiledFlowValidationIssue])
    case noMatch
    case ambiguousMatch
    case missingInput(String)
    case unexpectedInput(String)
    case unsupportedApp(String)

    var errorDescription: String? {
        switch self {
        case .invalidPackages(let issues): issues.map(\.description).joined(separator: " ")
        case .noMatch: "No active compiled flow matches this intent and screen source."
        case .ambiguousMatch: "More than one active compiled flow matches; iosClaw will not choose ambiguously."
        case .missingInput(let name): "The compiled flow requires input '\(name)'."
        case .unexpectedInput(let name): "The compiled flow does not accept input '\(name)'."
        case .unsupportedApp(let name): "The compiled flow is not validated for app '\(name)'."
        }
    }
}

struct CompiledFlowRegistry {
    let packages: [CompiledFlowPackage]

    init(packages: [CompiledFlowPackage]) throws {
        let issues = packages.flatMap(CompiledFlowValidator.validate)
        guard issues.isEmpty else { throw CompiledFlowRegistryError.invalidPackages(issues) }
        self.packages = packages
    }

    func resolve(
        intentID: String,
        inputs: [String: String],
        source: ScreenSource
    ) throws -> CompiledFlowPackage {
        let requestedIntent = SemanticTargetResolver.normalized(intentID)
        var candidates = packages.filter {
            $0.status == .active
                && SemanticTargetResolver.normalized($0.intentID) == requestedIntent
                && $0.supportedSources.contains(source)
        }
        guard !candidates.isEmpty else { throw CompiledFlowRegistryError.noMatch }

        if let requestedApp = inputs["app"] {
            let normalizedApp = SemanticTargetResolver.normalized(requestedApp)
            candidates = candidates.filter { flow in
                flow.appAliases.isEmpty
                    || flow.appAliases.map(SemanticTargetResolver.normalized).contains(normalizedApp)
            }
            guard !candidates.isEmpty else { throw CompiledFlowRegistryError.unsupportedApp(requestedApp) }
        }
        guard candidates.count == 1, let selected = candidates.first else {
            throw CompiledFlowRegistryError.ambiguousMatch
        }

        for (name, spec) in selected.inputSpecs where spec.required {
            guard let value = inputs[name], !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw CompiledFlowRegistryError.missingInput(name)
            }
        }
        if let unexpected = inputs.keys.first(where: { selected.inputSpecs[$0] == nil }) {
            throw CompiledFlowRegistryError.unexpectedInput(unexpected)
        }
        return selected
    }
}

/// One deterministic place to compose the immutable product catalog with
/// encrypted user drafts. User content may never overwrite a bundled package;
/// a recompile of the same user trace receives the next package version.
enum CompiledFlowCatalog {
    static func merge(
        bundled: [CompiledFlowPackage],
        userDrafts: [CompiledFlowPackage]
    ) -> [CompiledFlowPackage] {
        let bundledIDs = Set(bundled.map(\.id))
        let safeDrafts = userDrafts.filter {
            !bundledIDs.contains($0.id)
                && $0.status == .draft
                && CompiledFlowValidator.validate($0).isEmpty
        }
        return bundled + safeDrafts
    }

    static func upserting(
        _ draft: CompiledFlowPackage,
        into userDrafts: [CompiledFlowPackage]
    ) -> [CompiledFlowPackage] {
        guard let existing = userDrafts.first(where: { $0.id == draft.id }) else {
            return userDrafts + [draft]
        }
        let next = draft.replacing(version: max(draft.version, existing.version + 1))
        return userDrafts.map { $0.id == draft.id ? next : $0 }
    }
}

enum BundledCompiledFlowCatalog {
    static let packages: [CompiledFlowPackage] = [openApp, whatsappBusinessDraft]

    static let openApp = CompiledFlowPackage(
        id: "whatsapp-business.app.open",
        version: 1,
        status: .active,
        intentID: "app.open",
        displayName: "Open WhatsApp Business",
        inputSpecs: [
            "app": CompiledFlowInputSpec(type: .appReference, required: true, retention: .runOnly)
        ],
        supportedSources: [.iPhoneMirroring],
        appAliases: ["WhatsApp", "WhatsApp Business", "WA Business"],
        steps: [
            CompiledFlowStep(
                id: "launch-app",
                primitive: .launchAppViaSpotlight,
                arguments: ["app": .literal("WA Business")],
                precondition: .anyActionable,
                postcondition: CompiledScreenPredicate(allowedStates: [.chatList, .conversation]),
                timeoutMilliseconds: 8_000,
                effect: .navigate
            )
        ],
        provenance: "iosclaw.bundled"
    )

    static let whatsappBusinessDraft = CompiledFlowPackage(
        id: "whatsapp-business.messaging.draft",
        version: 1,
        status: .active,
        intentID: "messaging.draft",
        displayName: "Draft WhatsApp Business message",
        inputSpecs: [
            "app": CompiledFlowInputSpec(type: .appReference, required: true, retention: .runOnly),
            "recipient": CompiledFlowInputSpec(type: .string, required: true, retention: .runOnly),
            "message": CompiledFlowInputSpec(type: .secretString, required: true, retention: .runOnly)
        ],
        supportedSources: [.iPhoneMirroring],
        appAliases: ["WhatsApp", "WhatsApp Business", "WA Business"],
        steps: [
            CompiledFlowStep(
                id: "launch-whatsapp-business",
                primitive: .launchAppViaSpotlight,
                arguments: ["app": .literal("WA Business")],
                precondition: .anyActionable,
                postcondition: CompiledScreenPredicate(allowedStates: [.chatList, .conversation]),
                timeoutMilliseconds: 8_000,
                effect: .navigate
            ),
            CompiledFlowStep(
                id: "return-to-chat-list",
                primitive: .ensureChatList,
                precondition: CompiledScreenPredicate(allowedStates: [.chatList, .conversation]),
                postcondition: CompiledScreenPredicate(allowedStates: [.chatList]),
                effect: .navigate
            ),
            CompiledFlowStep(
                id: "open-recipient",
                primitive: .keyboardFindAndActivate,
                arguments: [
                    "query": .input("recipient"),
                    "confirmation": .literal("Message")
                ],
                precondition: CompiledScreenPredicate(allowedStates: [.chatList]),
                postcondition: CompiledScreenPredicate(
                    allowedStates: [.conversation],
                    exactTexts: [.input("recipient"), .literal("Message")]
                ),
                timeoutMilliseconds: 5_000,
                effect: .navigate
            ),
            CompiledFlowStep(
                id: "draft-message",
                primitive: .replaceVisibleText,
                arguments: [
                    "target": .literal("Message"),
                    "value": .input("message")
                ],
                precondition: CompiledScreenPredicate(
                    allowedStates: [.conversation],
                    exactTexts: [.input("recipient"), .literal("Message")]
                ),
                postcondition: CompiledScreenPredicate(
                    allowedStates: [.conversation],
                    exactTexts: [.input("recipient"), .input("message")]
                ),
                timeoutMilliseconds: 5_000,
                effect: .draft
            )
        ],
        provenance: "iosclaw.bundled.whatsapp-business"
    )
}

enum RecordedFlowCompilerError: LocalizedError {
    case blockedAction(String)
    case invalidCompiledFlow([CompiledFlowValidationIssue])

    var errorDescription: String? {
        switch self {
        case .blockedAction(let name): "The recorded action '\(name)' is blocked by policy."
        case .invalidCompiledFlow(let issues): issues.map(\.description).joined(separator: " ")
        }
    }
}

/// A reusable target declaration. It captures semantic identity and evidence,
/// never the geometry that happened to resolve it during one capture.
struct SemanticTargetSpec: Codable, Equatable {
    let name: String
    let kind: LearnedFact.Kind
    let requiredState: SemanticScreenState
    let contextAnchors: [String]
    let placement: SemanticPlacement?

    init(
        name: String,
        kind: LearnedFact.Kind,
        requiredState: SemanticScreenState,
        contextAnchors: [String] = [],
        placement: SemanticPlacement? = nil
    ) {
        self.name = name
        self.kind = kind
        self.requiredState = requiredState
        self.contextAnchors = contextAnchors
        self.placement = placement
    }

    init(recordedTarget: RecordedActionTarget) {
        self.init(
            name: recordedTarget.name,
            kind: recordedTarget.kind,
            requiredState: recordedTarget.requiredState,
            contextAnchors: recordedTarget.contextAnchors,
            placement: recordedTarget.placement
        )
    }
}

/// State evidence shared by manual recordings, agent exploration, validation,
/// and deterministic execution. The runtime converts it to the current flow
/// predicate ABI only after the trace has passed validation.
struct SemanticStateEvidence: Codable, Equatable {
    let allowedStates: [SemanticScreenState]
    let exactTexts: [String]

    init(
        allowedStates: [SemanticScreenState],
        exactTexts: [String] = []
    ) {
        self.allowedStates = allowedStates
        self.exactTexts = exactTexts
    }

    init(target: SemanticTargetSpec) {
        self.init(
            allowedStates: [target.requiredState],
            exactTexts: target.contextAnchors
        )
    }

    init(postcondition: RecordedScreenPostcondition?) {
        self.init(
            allowedStates: [postcondition?.requiredState ?? .unknown],
            exactTexts: postcondition?.contextAnchors ?? []
        )
    }

    static let anyActionable = SemanticStateEvidence(
        allowedStates: [.generic, .chatList, .conversation]
    )

    func compiledPredicate() -> CompiledScreenPredicate {
        CompiledScreenPredicate(
            allowedStates: allowedStates,
            exactTexts: exactTexts.map(CompiledFlowValue.literal)
        )
    }
}

enum SemanticTraceOperation: String, Codable, Equatable {
    case home
    case tap
    case replaceText
}

/// Input metadata is deliberately value-free. The encrypted recording may
/// retain an example for legacy replay, but a trace is safe to hand to the
/// compiler, validator, and an authorized agent.
struct SemanticTraceInput: Codable, Equatable {
    let name: String
    let type: CompiledFlowInputType
    let retention: CompiledFlowInputRetention
}

struct SemanticTraceStep: Codable, Equatable, Identifiable {
    let id: UUID
    let operation: SemanticTraceOperation
    let target: SemanticTargetSpec?
    let input: SemanticTraceInput?
    let precondition: SemanticStateEvidence
    let postcondition: SemanticStateEvidence
    let recordedAt: Date

    init(
        id: UUID = UUID(),
        operation: SemanticTraceOperation,
        target: SemanticTargetSpec? = nil,
        input: SemanticTraceInput? = nil,
        precondition: SemanticStateEvidence,
        postcondition: SemanticStateEvidence,
        recordedAt: Date = .now
    ) {
        self.id = id
        self.operation = operation
        self.target = target
        self.input = input
        self.precondition = precondition
        self.postcondition = postcondition
        self.recordedAt = recordedAt
    }
}

/// The common authoring boundary for manual record/replay, agent exploration,
/// and future app-pack tooling. It contains semantic evidence only; it cannot
/// carry a recorded input value or an actionable coordinate.
struct SemanticTrace: Codable, Equatable, Identifiable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let displayName: String
    let source: ScreenSource
    let steps: [SemanticTraceStep]
    let createdAt: Date
    let updatedAt: Date
    let provenance: String

    init(
        schemaVersion: Int = SemanticTrace.schemaVersion,
        id: UUID = UUID(),
        displayName: String,
        source: ScreenSource,
        steps: [SemanticTraceStep],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        provenance: String
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.displayName = displayName
        self.source = source
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.provenance = provenance
    }

    init(recordedFlow: RecordedActionFlow) {
        self.init(
            id: recordedFlow.id,
            displayName: recordedFlow.name,
            source: recordedFlow.source,
            steps: recordedFlow.steps.enumerated().map { index, recordedStep in
                let target = recordedStep.target.map(SemanticTargetSpec.init(recordedTarget:))
                let operation: SemanticTraceOperation
                switch recordedStep.kind {
                case .home: operation = .home
                case .tap: operation = .tap
                case .input: operation = .replaceText
                }
                let input = recordedStep.kind == .input
                    ? SemanticTraceInput(
                        name: "step_\(index + 1)_value",
                        type: .secretString,
                        retention: .runOnly
                    )
                    : nil
                return SemanticTraceStep(
                    id: recordedStep.id,
                    operation: operation,
                    target: target,
                    input: input,
                    precondition: target.map(SemanticStateEvidence.init(target:)) ?? .anyActionable,
                    postcondition: SemanticStateEvidence(postcondition: recordedStep.postcondition),
                    recordedAt: recordedStep.recordedAt
                )
            },
            createdAt: recordedFlow.createdAt,
            updatedAt: recordedFlow.updatedAt,
            provenance: "iosclaw.recorded.\(recordedFlow.id.uuidString.lowercased())"
        )
    }
}

enum SemanticTraceValidationIssue: Equatable, CustomStringConvertible {
    case unsupportedSchema(Int)
    case invalidIdentity
    case automaticSource
    case missingSteps
    case tooManySteps(Int)
    case duplicateStepID(UUID)
    case missingPrecondition(String)
    case missingPostcondition(String)
    case insufficientGenericEvidence(String)
    case missingTarget(String)
    case unexpectedTarget(String)
    case targetIsNotControl(String)
    case targetIsNotActionable(String)
    case targetStateMismatch(String)
    case missingInput(String)
    case unexpectedInput(String)
    case invalidInput(String)
    case duplicateInput(String)

    var description: String {
        switch self {
        case .unsupportedSchema(let version): "Unsupported semantic-trace schema version \(version)."
        case .invalidIdentity: "Semantic trace display name and provenance must be non-empty."
        case .automaticSource: "A semantic trace requires a concrete iPhone Mirroring or Simulator source."
        case .missingSteps: "A semantic trace requires at least one step."
        case .tooManySteps(let count): "A semantic trace may contain at most 100 steps; received \(count)."
        case .duplicateStepID(let id): "Semantic trace step '\(id.uuidString)' is duplicated."
        case .missingPrecondition(let id): "Trace step '\(id)' requires explicit entry-state evidence."
        case .missingPostcondition(let id): "Trace step '\(id)' requires a verified postcondition."
        case .insufficientGenericEvidence(let id): "Generic trace step '\(id)' requires at least two stable anchors."
        case .missingTarget(let id): "Trace step '\(id)' requires a semantic target."
        case .unexpectedTarget(let id): "Trace step '\(id)' may not declare a target."
        case .targetIsNotControl(let id): "Text-replacement trace step '\(id)' requires a control target."
        case .targetIsNotActionable(let id): "Tap trace step '\(id)' requires an app icon or control target."
        case .targetStateMismatch(let id): "Trace step '\(id)' target state is not allowed by its entry-state evidence."
        case .missingInput(let id): "Trace step '\(id)' requires a run-only input declaration."
        case .unexpectedInput(let id): "Trace step '\(id)' may not declare an input."
        case .invalidInput(let id): "Trace step '\(id)' has an invalid input declaration."
        case .duplicateInput(let name): "Trace input '\(name)' has conflicting declarations."
        }
    }
}

enum SemanticTraceValidator {
    static func validate(_ trace: SemanticTrace) -> [SemanticTraceValidationIssue] {
        var issues: [SemanticTraceValidationIssue] = []
        if trace.schemaVersion != SemanticTrace.schemaVersion {
            issues.append(.unsupportedSchema(trace.schemaVersion))
        }
        if trace.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || trace.provenance.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append(.invalidIdentity)
        }
        if trace.source == .automatic { issues.append(.automaticSource) }
        if trace.steps.isEmpty { issues.append(.missingSteps) }
        if trace.steps.count > 100 { issues.append(.tooManySteps(trace.steps.count)) }

        var stepIDs: Set<UUID> = []
        var inputs: [String: SemanticTraceInput] = [:]
        for (index, step) in trace.steps.enumerated() {
            let id = "trace-\(index + 1)"
            if !stepIDs.insert(step.id).inserted { issues.append(.duplicateStepID(step.id)) }
            if invalidEvidence(step.precondition) { issues.append(.missingPrecondition(id)) }
            if invalidEvidence(step.postcondition) { issues.append(.missingPostcondition(id)) }
            if step.precondition.allowedStates.contains(.generic)
                && step.precondition.exactTexts.count < 2
                && step.operation != .home {
                issues.append(.insufficientGenericEvidence(id))
            }
            if step.postcondition.allowedStates == [.generic]
                && step.postcondition.exactTexts.count < 2 {
                issues.append(.insufficientGenericEvidence(id))
            }

            switch step.operation {
            case .home:
                if step.target != nil { issues.append(.unexpectedTarget(id)) }
                if step.input != nil { issues.append(.unexpectedInput(id)) }
            case .tap:
                if step.target == nil {
                    issues.append(.missingTarget(id))
                } else if let target = step.target {
                    if target.kind == .screenLandmark { issues.append(.targetIsNotActionable(id)) }
                    if !step.precondition.allowedStates.contains(target.requiredState) {
                        issues.append(.targetStateMismatch(id))
                    }
                }
                if step.input != nil { issues.append(.unexpectedInput(id)) }
            case .replaceText:
                guard let target = step.target else {
                    issues.append(.missingTarget(id))
                    if step.input == nil { issues.append(.missingInput(id)) }
                    continue
                }
                if target.kind != .control { issues.append(.targetIsNotControl(id)) }
                if !step.precondition.allowedStates.contains(target.requiredState) {
                    issues.append(.targetStateMismatch(id))
                }
                guard let input = step.input else {
                    issues.append(.missingInput(id))
                    continue
                }
                if input.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || input.type == .appReference
                    || input.retention != .runOnly {
                    issues.append(.invalidInput(id))
                }
                if let existing = inputs[input.name], existing != input {
                    issues.append(.duplicateInput(input.name))
                } else {
                    inputs[input.name] = input
                }
            }
        }
        return issues
    }

    private static func invalidEvidence(_ evidence: SemanticStateEvidence) -> Bool {
        evidence.allowedStates.isEmpty || evidence.allowedStates.contains(.unknown)
    }
}

enum SemanticTraceCompilerError: LocalizedError, Equatable {
    case invalidTrace([SemanticTraceValidationIssue])
    case unsupportedSchema(Int)
    case emptyTrace
    case invalidSource
    case missingTarget(String)
    case unexpectedTarget(String)
    case missingInput(String)
    case unexpectedInput(String)
    case duplicateInput(String)
    case missingPostcondition(String)
    case blockedAction(String)
    case invalidCompiledFlow([CompiledFlowValidationIssue])

    var errorDescription: String? {
        switch self {
        case .invalidTrace(let issues): issues.map(\.description).joined(separator: " ")
        case .unsupportedSchema(let version): "Unsupported semantic-trace schema version \(version)."
        case .emptyTrace: "A semantic trace requires at least one step."
        case .invalidSource: "A semantic trace requires a concrete iPhone Mirroring or Simulator source."
        case .missingTarget(let id): "Trace step '\(id)' requires a semantic target."
        case .unexpectedTarget(let id): "Trace step '\(id)' may not declare a target."
        case .missingInput(let id): "Trace step '\(id)' requires a run-only input declaration."
        case .unexpectedInput(let id): "Trace step '\(id)' may not declare an input."
        case .duplicateInput(let name): "Trace input '\(name)' has conflicting declarations."
        case .missingPostcondition(let id): "Trace step '\(id)' requires a verified postcondition."
        case .blockedAction(let name): "The semantic action '\(name)' is blocked by policy."
        case .invalidCompiledFlow(let issues): issues.map(\.description).joined(separator: " ")
        }
    }
}

/// Lowers a value-free semantic trace into the existing deterministic flow IR.
/// This is the only compiler path for new manual recordings and future agent
/// exploration traces.
enum SemanticTraceCompiler {
    static func compile(_ trace: SemanticTrace) throws -> CompiledFlowPackage {
        let traceIssues = SemanticTraceValidator.validate(trace)
        guard traceIssues.isEmpty else {
            throw SemanticTraceCompilerError.invalidTrace(traceIssues)
        }

        var inputs: [String: CompiledFlowInputSpec] = [:]
        var steps: [CompiledFlowStep] = []

        for (index, traceStep) in trace.steps.enumerated() {
            let stepID = "trace-\(index + 1)"
            guard !traceStep.postcondition.allowedStates.isEmpty,
                  !traceStep.postcondition.allowedStates.contains(.unknown)
            else { throw SemanticTraceCompilerError.missingPostcondition(stepID) }
            let postcondition = traceStep.postcondition.compiledPredicate()
            switch traceStep.operation {
            case .home:
                guard traceStep.target == nil else {
                    throw SemanticTraceCompilerError.unexpectedTarget(stepID)
                }
                guard traceStep.input == nil else {
                    throw SemanticTraceCompilerError.unexpectedInput(stepID)
                }
                steps.append(CompiledFlowStep(
                    id: stepID,
                    primitive: .home,
                    precondition: traceStep.precondition.compiledPredicate(),
                    postcondition: postcondition,
                    effect: .navigate
                ))
            case .tap:
                guard let target = traceStep.target else {
                    throw SemanticTraceCompilerError.missingTarget(stepID)
                }
                guard traceStep.input == nil else {
                    throw SemanticTraceCompilerError.unexpectedInput(stepID)
                }
                let policy = ActionPolicy.evaluate(kind: .tap, targetName: target.name)
                let effect: CompiledFlowEffect
                let approval: Bool
                switch policy {
                case .allow:
                    effect = .navigate
                    approval = false
                case .requireApproval(let actionEffect):
                    effect = compiledEffect(actionEffect)
                    approval = true
                case .block:
                    throw SemanticTraceCompilerError.blockedAction(target.name)
                }
                steps.append(CompiledFlowStep(
                    id: stepID,
                    primitive: .tapVisibleText,
                    arguments: ["target": .literal(target.name)],
                    precondition: traceStep.precondition.compiledPredicate(),
                    postcondition: postcondition,
                    effect: effect,
                    requiresApproval: approval
                ))
            case .replaceText:
                guard let target = traceStep.target else {
                    throw SemanticTraceCompilerError.missingTarget(stepID)
                }
                guard let input = traceStep.input else {
                    throw SemanticTraceCompilerError.missingInput(stepID)
                }
                if case .block = ActionPolicy.evaluate(kind: .input, targetName: target.name) {
                    throw SemanticTraceCompilerError.blockedAction(target.name)
                }
                let inputSpec = CompiledFlowInputSpec(
                    type: input.type,
                    required: true,
                    retention: input.retention
                )
                if let existing = inputs[input.name], existing != inputSpec {
                    throw SemanticTraceCompilerError.duplicateInput(input.name)
                }
                inputs[input.name] = inputSpec
                steps.append(CompiledFlowStep(
                    id: stepID,
                    primitive: .replaceVisibleText,
                    arguments: [
                        "target": .literal(target.name),
                        "value": .input(input.name)
                    ],
                    precondition: traceStep.precondition.compiledPredicate(),
                    postcondition: postcondition,
                    effect: .draft
                ))
            }
        }

        let flow = CompiledFlowPackage(
            id: "user.\(trace.id.uuidString.lowercased())",
            version: 1,
            status: .draft,
            intentID: "user.\(slug(trace.displayName))",
            displayName: trace.displayName,
            inputSpecs: inputs,
            supportedSources: [trace.source],
            steps: steps,
            provenance: trace.provenance
        )
        let issues = CompiledFlowValidator.validate(flow)
        guard issues.isEmpty else { throw SemanticTraceCompilerError.invalidCompiledFlow(issues) }
        return flow
    }

    private static func compiledEffect(_ effect: ActionEffect) -> CompiledFlowEffect {
        switch effect {
        case .externalCommunication: .externalCommunication
        case .destructive: .destructive
        case .financial: .financial
        case .accountOrSecurity: .accountOrSecurity
        }
    }

    private static func slug(_ name: String) -> String {
        let normalized = SemanticTargetResolver.normalized(name)
        let slug = normalized.replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? "flow" : slug
    }
}

/// Compatibility adapter for the existing encrypted manual recorder. The
/// recorder remains replay-compatible while all new compilation flows through
/// the common value-free semantic-trace boundary.
enum RecordedFlowCompiler {
    static func compile(_ recorded: RecordedActionFlow) throws -> CompiledFlowPackage {
        try SemanticTraceCompiler.compile(SemanticTrace(recordedFlow: recorded))
    }
}

struct CompiledFlowObservation: Equatable {
    let source: ScreenSource
    let state: SemanticScreenState
    let visibleTexts: [String]
    let generationID: UUID
}

@MainActor
protocol CompiledFlowDriving: AnyObject {
    func compiledObserve() async -> CompiledFlowObservation?
    func compiledCurrentObservation() -> CompiledFlowObservation?
    func compiledPerform(
        primitive: CompiledFlowPrimitive,
        arguments: [String: String],
        timeoutMilliseconds: Int
    ) async -> Bool
}

enum CompiledFlowRunOutcome: String, Codable, Equatable {
    case succeeded
    case failed
    case cancelled
}

enum CompiledFlowSessionError: LocalizedError, Equatable {
    case anotherRunActive
    case recordingOrReplayActive
    case observationUnavailable

    var errorDescription: String? {
        switch self {
        case .anotherRunActive: "Another compiled flow is already running on this device."
        case .recordingOrReplayActive: "Stop the current recording or replay before starting a compiled flow."
        case .observationUnavailable: "iosClaw could not obtain a fresh actionable observation."
        }
    }
}

struct CompiledFlowStepRun: Codable, Equatable {
    let stepID: String
    let primitive: CompiledFlowPrimitive
    let durationMilliseconds: Int
    let succeeded: Bool
}

struct CompiledFlowRun: Codable, Equatable, Identifiable {
    let id: UUID
    let flowID: String
    let flowVersion: Int
    let outcome: CompiledFlowRunOutcome
    let startedAt: Date
    let completedAt: Date
    let steps: [CompiledFlowStepRun]
    let failureReason: String?

    var durationMilliseconds: Int {
        max(0, Int(completedAt.timeIntervalSince(startedAt) * 1_000))
    }
}

@MainActor
struct CompiledFlowExecutor {
    let driver: CompiledFlowDriving

    func run(
        flow: CompiledFlowPackage,
        inputs: [String: String],
        initialObservation: CompiledFlowObservation? = nil
    ) async -> CompiledFlowRun {
        let runID = UUID()
        let startedAt = Date()
        var stepRuns: [CompiledFlowStepRun] = []
        let firstObservation: CompiledFlowObservation?
        if let initialObservation {
            firstObservation = initialObservation
        } else {
            firstObservation = await driver.compiledObserve()
        }
        guard var observation = firstObservation else {
            return failedRun(
                id: runID,
                flow: flow,
                startedAt: startedAt,
                steps: stepRuns,
                reason: "A fresh screen observation was unavailable."
            )
        }

        for step in flow.steps {
            guard step.precondition.matches(observation, inputs: inputs) else {
                return failedRun(
                    id: runID,
                    flow: flow,
                    startedAt: startedAt,
                    steps: stepRuns,
                    reason: "Step '\(step.id)' did not match its required live state."
                )
            }
            guard !step.requiresApproval else {
                return failedRun(
                    id: runID,
                    flow: flow,
                    startedAt: startedAt,
                    steps: stepRuns,
                    reason: "Step '\(step.id)' requires interactive approval and cannot run through the agent bridge."
                )
            }
            guard let arguments = resolve(step.arguments, using: inputs) else {
                return failedRun(
                    id: runID,
                    flow: flow,
                    startedAt: startedAt,
                    steps: stepRuns,
                    reason: "Step '\(step.id)' could not bind all required inputs."
                )
            }

            let started = DispatchTime.now().uptimeNanoseconds
            let succeeded = await driver.compiledPerform(
                primitive: step.primitive,
                arguments: arguments,
                timeoutMilliseconds: step.timeoutMilliseconds
            )
            guard succeeded, var updated = driver.compiledCurrentObservation() else {
                let elapsed = DispatchTime.now().uptimeNanoseconds - started
                stepRuns.append(CompiledFlowStepRun(
                    stepID: step.id,
                    primitive: step.primitive,
                    durationMilliseconds: Int(elapsed / 1_000_000),
                    succeeded: false
                ))
                return failedRun(
                    id: runID,
                    flow: flow,
                    startedAt: startedAt,
                    steps: stepRuns,
                    reason: "Step '\(step.id)' did not produce a verified observation."
                )
            }

            let deadline = started + UInt64(step.timeoutMilliseconds) * 1_000_000
            while !step.postcondition.matches(updated, inputs: inputs),
                  DispatchTime.now().uptimeNanoseconds < deadline
            {
                try? await Task.sleep(nanoseconds: 200_000_000)
                if let nextObservation = await driver.compiledObserve() {
                    updated = nextObservation
                }
            }
            let elapsed = DispatchTime.now().uptimeNanoseconds - started
            let postconditionSatisfied = step.postcondition.matches(updated, inputs: inputs)
            stepRuns.append(CompiledFlowStepRun(
                stepID: step.id,
                primitive: step.primitive,
                durationMilliseconds: Int(elapsed / 1_000_000),
                succeeded: succeeded
            ))
            guard postconditionSatisfied else {
                return failedRun(
                    id: runID,
                    flow: flow,
                    startedAt: startedAt,
                    steps: stepRuns,
                    reason: "Step '\(step.id)' failed its semantic postcondition."
                )
            }
            observation = updated
        }

        return CompiledFlowRun(
            id: runID,
            flowID: flow.id,
            flowVersion: flow.version,
            outcome: .succeeded,
            startedAt: startedAt,
            completedAt: Date(),
            steps: stepRuns,
            failureReason: nil
        )
    }

    private func resolve(
        _ arguments: [String: CompiledFlowValue],
        using inputs: [String: String]
    ) -> [String: String]? {
        var resolved: [String: String] = [:]
        for (name, value) in arguments {
            guard let bound = value.resolve(using: inputs) else { return nil }
            resolved[name] = bound
        }
        return resolved
    }

    private func failedRun(
        id: UUID,
        flow: CompiledFlowPackage,
        startedAt: Date,
        steps: [CompiledFlowStepRun],
        reason: String
    ) -> CompiledFlowRun {
        CompiledFlowRun(
            id: id,
            flowID: flow.id,
            flowVersion: flow.version,
            outcome: .failed,
            startedAt: startedAt,
            completedAt: Date(),
            steps: steps,
            failureReason: reason
        )
    }
}
