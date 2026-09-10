import Foundation
import CoreGraphics

enum ScreenSource: String, Codable, CaseIterable, Identifiable {
    case automatic
    case iPhoneMirroring
    case simulator

    var id: String { rawValue }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .iPhoneMirroring: "iPhone Mirroring"
        case .simulator: "iOS Simulator"
        }
    }
}

enum SourceHealth: String, Equatable {
    case idle
    case missing
    case permissionRequired
    case capturing
    case ready
    case interrupted
    case failed

    var allowsInput: Bool { self == .ready }
}

enum SourceInterruptionDetector {
    static func reason(in targets: [TextTarget]) -> String? {
        let screenText = targets
            .map { SemanticTargetResolver.normalized($0.text) }
            .joined(separator: " ")

        if screenText.contains("connection interrupted") {
            return "iPhone Mirroring reported that its connection was interrupted."
        }
        if screenText.contains("iphone microphone in use") || screenText.contains("iphone in use") {
            return "iPhone Mirroring is paused because the iPhone is currently in use."
        }
        if screenText.contains("ensure")
            && screenText.contains("iphone")
            && screenText.contains("bluetooth")
            && screenText.contains("wi fi")
        {
            return "iPhone Mirroring is waiting for the nearby paired iPhone."
        }
        return nil
    }
}

struct MirrorWindow: Identifiable, Equatable {
    let id: CGWindowID
    let ownerPID: pid_t
    let ownerName: String
    let title: String
    let bounds: CGRect
    let source: ScreenSource
}

/// Identifies the exact captured source state from which semantic targets were
/// produced. An input action may consume this evidence only while it remains
/// fresh and the source window identity and geometry are unchanged.
struct CaptureGeneration: Equatable {
    // Long enough for an agent/MCP round-trip, while remaining a short-lived
    // lease bound to the exact source window and its captured geometry.
    static let defaultMaximumAge: TimeInterval = 15

    let id: UUID
    let capturedAt: Date
    let windowID: CGWindowID
    let windowBounds: CGRect
    let source: ScreenSource
    let screenSignature: String

    init(
        id: UUID = UUID(),
        capturedAt: Date = .now,
        windowID: CGWindowID,
        windowBounds: CGRect,
        source: ScreenSource,
        screenSignature: String
    ) {
        self.id = id
        self.capturedAt = capturedAt
        self.windowID = windowID
        self.windowBounds = windowBounds
        self.source = source
        self.screenSignature = screenSignature
    }

    func authorizes(
        window: MirrorWindow,
        now: Date = .now,
        maximumAge: TimeInterval = CaptureGeneration.defaultMaximumAge
    ) -> Bool {
        guard maximumAge >= 0,
              now.timeIntervalSince(capturedAt) >= 0,
              now.timeIntervalSince(capturedAt) <= maximumAge
        else { return false }

        return windowID == window.id
            && source == window.source
            && windowBounds.equalTo(window.bounds)
    }
}

enum ActionPostcondition: Equatable {
    case freshObservation
    case screenChanged
    case textPresent(String)
    case textPresentAtPlacement(String, SemanticPlacement)
    case textAbsent(String)
    case exactTextsPresent([String])

    func isSatisfied(
        before: CaptureGeneration,
        after: CaptureGeneration,
        afterTargets: [TextTarget] = []
    ) -> Bool {
        guard before.id != after.id,
              before.windowID == after.windowID,
              before.source == after.source
        else { return false }

        switch self {
        case .freshObservation:
            return true
        case .screenChanged:
            return before.screenSignature != after.screenSignature
        case .textPresent(let expected):
            let normalizedExpected = SemanticTargetResolver.normalized(expected)
            return afterTargets.contains {
                SemanticTargetResolver.normalized($0.text).contains(normalizedExpected)
            }
        case .textPresentAtPlacement(let expected, let placement):
            let normalizedExpected = SemanticTargetResolver.normalized(expected)
            return afterTargets.contains {
                SemanticTargetResolver.normalized($0.text).contains(normalizedExpected)
                    && SemanticPlacement(bounds: $0.normalizedBounds) == placement
            }
        case .textAbsent(let expected):
            let normalizedExpected = SemanticTargetResolver.normalized(expected)
            return !afterTargets.contains {
                SemanticTargetResolver.normalized($0.text).contains(normalizedExpected)
            }
        case .exactTextsPresent(let expected):
            let visible = Set(afterTargets.map { SemanticTargetResolver.normalized($0.text) })
            return expected
                .map(SemanticTargetResolver.normalized)
                .allSatisfy(visible.contains)
        }
    }
}

enum SemanticActionKind: String, Equatable {
    case tap
    case input
}

enum ActionEffect: String, Equatable {
    case externalCommunication
    case destructive
    case financial
    case accountOrSecurity

    var title: String {
        switch self {
        case .externalCommunication: "External communication"
        case .destructive: "Destructive action"
        case .financial: "Financial action"
        case .accountOrSecurity: "Account or security action"
        }
    }
}

enum ActionPolicyDecision: Equatable {
    case allow
    case requireApproval(ActionEffect)
    case block(String)
}

enum ActionPolicy {
    static func evaluate(kind: SemanticActionKind, targetName: String) -> ActionPolicyDecision {
        let label = SemanticTargetResolver.normalized(targetName)
        let words = Set(label.split(separator: " ").map(String.init))

        if kind == .input {
            let blockedInputs = [
                "password", "passcode", "pin", "otp", "one time code",
                "verification code", "security code", "cvv", "card number"
            ]
            if blockedInputs.contains(where: { label.contains($0) }) {
                return .block("iosClaw does not enter credentials, one-time codes, passcodes, or payment-card secrets.")
            }
            return .allow
        }

        if words.contains("send") || words.contains("post") || words.contains("publish") || words.contains("call") {
            return .requireApproval(.externalCommunication)
        }
        if words.contains("delete") || words.contains("remove") || words.contains("erase") {
            return .requireApproval(.destructive)
        }
        if words.contains("pay") || words.contains("buy") || words.contains("purchase") || words.contains("transfer") {
            return .requireApproval(.financial)
        }
        if label.contains("sign out") || label.contains("log out") || label.contains("change password") || label.contains("disable") {
            return .requireApproval(.accountOrSecurity)
        }
        return .allow
    }
}

struct PendingActionApproval: Identifiable, Equatable {
    let id: UUID
    let fingerprint: String
    let effect: ActionEffect
    let actionDescription: String
    let requestedAt: Date
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        fingerprint: String,
        effect: ActionEffect,
        actionDescription: String,
        requestedAt: Date = .now,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.fingerprint = fingerprint
        self.effect = effect
        self.actionDescription = actionDescription
        self.requestedAt = requestedAt
        self.expiresAt = expiresAt ?? requestedAt.addingTimeInterval(60)
    }
}

struct OneTimeActionApproval: Equatable {
    let fingerprint: String
    let expiresAt: Date

    func authorizes(_ candidate: String, now: Date = .now) -> Bool {
        fingerprint == candidate && now <= expiresAt
    }
}

enum MirrorCoordinateMapper {
    static func screenPoint(
        for bounds: NormalizedBounds,
        in windowBounds: CGRect
    ) -> CGPoint {
        // CGWindow bounds and CGEvent mouse locations both use the Quartz
        // global top-left coordinate space. AppKit's bottom-left coordinates
        // must not be introduced here.
        return CGPoint(
            x: windowBounds.minX + (bounds.x + bounds.width / 2) * windowBounds.width,
            y: windowBounds.minY + (1 - bounds.y - bounds.height / 2) * windowBounds.height
        )
    }
}

enum MirrorWindowMatcher {
    static func match(in windowInfo: [[String: Any]], source: ScreenSource = .automatic) -> MirrorWindow? {
        let windows = windowInfo.compactMap(MirrorWindow.init(windowInfo:))
        switch source {
        case .automatic:
            return preferredMirroringWindow(in: windows.filter(isMirroringWindow))
                ?? largestWindow(in: windows.filter(isSimulatorWindow))
        case .iPhoneMirroring:
            return preferredMirroringWindow(in: windows.filter(isMirroringWindow))
        case .simulator:
            return largestWindow(in: windows.filter(isSimulatorWindow))
        }
    }

    private static func largestWindow(in windows: [MirrorWindow]) -> MirrorWindow? {
        windows.max { lhs, rhs in
            lhs.bounds.width * lhs.bounds.height < rhs.bounds.width * rhs.bounds.height
        }
    }

    private static func preferredMirroringWindow(in windows: [MirrorWindow]) -> MirrorWindow? {
        // iPhone Mirroring also owns transient image and compositor surfaces.
        // The interactive device window is phone-shaped; prefer it over the
        // square compositor surfaces even when the latter share the app title.
        let deviceShaped = windows.filter { window in
            guard window.bounds.width > 0, window.bounds.height > 0 else { return false }
            let shortEdge = min(window.bounds.width, window.bounds.height)
            let longEdge = max(window.bounds.width, window.bounds.height)
            return longEdge / shortEdge >= 1.25
        }
        let namedWindow = windows.filter {
            $0.title.localizedCaseInsensitiveContains("iPhone Mirroring")
        }
        let namedDeviceWindow = deviceShaped.filter {
            $0.title.localizedCaseInsensitiveContains("iPhone Mirroring")
        }
        return largestWindow(in: namedDeviceWindow)
            ?? largestWindow(in: deviceShaped)
            ?? largestWindow(in: namedWindow)
            ?? largestWindow(in: windows)
    }

    static func isMirroringWindow(_ window: MirrorWindow) -> Bool {
        let owner = window.ownerName.localizedCaseInsensitiveContains("iPhone Mirroring")
        let title = window.title.localizedCaseInsensitiveContains("iPhone Mirroring")
        return owner || title
    }

    static func isSimulatorWindow(_ window: MirrorWindow) -> Bool {
        window.ownerName.caseInsensitiveCompare("Simulator") == .orderedSame
            && window.bounds.width >= 100
            && window.bounds.height >= 100
    }
}

enum WindowOcclusionPolicy {
    /// CGWindowListCopyWindowInfo returns windows in front-to-back order. A
    /// display crop is safe only when the first normal, visible window covering
    /// the target centre belongs to the selected source process.
    static func sourceIsTopmostAtCenter(
        _ source: MirrorWindow,
        orderedWindowInfo: [[String: Any]]
    ) -> Bool {
        let center = CGPoint(x: source.bounds.midX, y: source.bounds.midY)
        for info in orderedWindowInfo {
            guard let layer = (info[kCGWindowLayer as String] as? NSNumber)?.intValue,
                  layer == 0,
                  let alpha = (info[kCGWindowAlpha as String] as? NSNumber)?.doubleValue,
                  alpha > 0,
                  let boundsDictionary = info[kCGWindowBounds as String] as? [String: Any],
                  let x = (boundsDictionary["X"] as? NSNumber)?.doubleValue,
                  let y = (boundsDictionary["Y"] as? NSNumber)?.doubleValue,
                  let width = (boundsDictionary["Width"] as? NSNumber)?.doubleValue,
                  let height = (boundsDictionary["Height"] as? NSNumber)?.doubleValue,
                  CGRect(x: x, y: y, width: width, height: height).contains(center),
                  let ownerPID = (info[kCGWindowOwnerPID as String] as? NSNumber)?.intValue
            else { continue }

            return pid_t(ownerPID) == source.ownerPID
        }
        return false
    }
}

private extension MirrorWindow {
    init?(windowInfo: [String: Any]) {
        guard let number = windowInfo[kCGWindowNumber as String] as? NSNumber,
              let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? NSNumber,
              let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
              let boundsDictionary = windowInfo[kCGWindowBounds as String] as? [String: Any],
              let x = (boundsDictionary["X"] as? NSNumber)?.doubleValue,
              let y = (boundsDictionary["Y"] as? NSNumber)?.doubleValue,
              let width = (boundsDictionary["Width"] as? NSNumber)?.doubleValue,
              let height = (boundsDictionary["Height"] as? NSNumber)?.doubleValue
        else { return nil }

        let title = (windowInfo[kCGWindowName as String] as? String) ?? ""
        let source: ScreenSource
        if ownerName.localizedCaseInsensitiveContains("iPhone Mirroring") || title.localizedCaseInsensitiveContains("iPhone Mirroring") {
            source = .iPhoneMirroring
        } else if ownerName.caseInsensitiveCompare("Simulator") == .orderedSame {
            source = .simulator
        } else {
            return nil
        }

        self.id = CGWindowID(number.uint32Value)
        self.ownerPID = pid_t(ownerPID.intValue)
        self.ownerName = ownerName
        self.title = title
        self.bounds = CGRect(x: x, y: y, width: width, height: height)
        self.source = source
    }
}

struct AuditEvent: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case observation
        case permission
        case safety
    }

    let id: UUID
    let occurredAt: Date
    let kind: Kind
    let summary: String

    init(kind: Kind, summary: String) {
        id = UUID()
        occurredAt = Date()
        self.kind = kind
        self.summary = summary
    }
}

/// A visible text region detected in the captured Mirroring image. Its bounds are
/// normalized Vision coordinates (origin at the lower-left), not a confirmed UI
/// accessibility element or an action permission.
struct TextTarget: Identifiable, Equatable {
    let id: UUID
    let text: String
    let normalizedBounds: CGRect

    init(text: String, normalizedBounds: CGRect) {
        id = UUID()
        self.text = text
        self.normalizedBounds = normalizedBounds
    }

    func displayRect(in imageSize: CGSize, minimumHitSize: CGFloat = 28) -> CGRect {
        let rawRect = CGRect(
            x: normalizedBounds.minX * imageSize.width,
            y: (1 - normalizedBounds.maxY) * imageSize.height,
            width: normalizedBounds.width * imageSize.width,
            height: normalizedBounds.height * imageSize.height
        )
        let widthPadding = max(0, (minimumHitSize - rawRect.width) / 2)
        let heightPadding = max(0, (minimumHitSize - rawRect.height) / 2)
        return rawRect.insetBy(dx: -widthPadding, dy: -heightPadding)
    }
}

enum SemanticPlacement: String, Codable, Equatable {
    case top
    case middle
    case bottom

    init(bounds: CGRect) {
        switch bounds.midY {
        case 0.66...: self = .top
        case 0.33..<0.66: self = .middle
        default: self = .bottom
        }
    }
}

/// A coarse, privacy-preserving state required before a semantic fact may be
/// resolved. Declarative app packs can extend this vocabulary without changing
/// the capture or input backend.
enum SemanticScreenState: String, Codable, Equatable {
    case chatList
    case conversation
    case generic
    case unknown

    static func classify(_ targets: [TextTarget]) -> SemanticScreenState {
        let labels = Set(targets.map { SemanticTargetResolver.normalized($0.text) })
        if labels.contains("chats") {
            let filterAnchorCount = labels.reduce(into: 0) { count, label in
                if label == "all"
                    || label.hasPrefix("unread")
                    || label == "favorites"
                    || label.hasPrefix("groups")
                    || label == "archived"
                {
                    count += 1
                }
            }
            let tabAnchorCount = ["updates", "calls", "tools", "settings"].reduce(into: 0) {
                count, anchor in
                if labels.contains(anchor) { count += 1 }
            }
            if labels.contains("search") || filterAnchorCount >= 2 || tabAnchorCount >= 3 {
                return .chatList
            }
        }
        let hasMessageComposer = labels.contains(where: {
            $0 == "message" || $0.contains("type a message")
        })
        let hasSendControl = labels.contains(where: {
            $0 == "send" || $0.hasPrefix("send ")
        })
        if hasMessageComposer && hasSendControl {
            return .conversation
        }
        return targets.isEmpty ? .unknown : .generic
    }
}

enum ScreenContextAnchors {
    static func make(from targets: [TextTarget], excluding targetName: String? = nil) -> [String] {
        let excluded = targetName.map(SemanticTargetResolver.normalized)
        let labels = Array(Set(targets.compactMap { target -> String? in
            let label = SemanticTargetResolver.normalized(target.text)
            guard label != excluded,
                  label.count >= 2,
                  label.count <= 60,
                  label.range(of: "^[0-9:.,%+ -]+$", options: .regularExpression) == nil
            else { return nil }
            return label
        })).sorted()
        return Array(labels.prefix(12))
    }

    static func matches(_ required: [String], targets: [TextTarget]) -> Bool {
        guard required.count >= 2 else { return false }
        let visible = Set(targets.map { SemanticTargetResolver.normalized($0.text) })
        let matched = required.reduce(into: 0) { count, anchor in
            if visible.contains(anchor) { count += 1 }
        }
        return Double(matched) / Double(required.count) >= 0.6
    }
}

/// A target resolved from the current capture. Its geometry expires with that
/// capture and is deliberately never persisted as learned context.
struct ResolvedSemanticTarget {
    let textTarget: TextTarget
    let state: SemanticScreenState
}

enum SemanticTargetResolver {
    static func resolveSearchControl(
        targets: [TextTarget],
        currentState: SemanticScreenState
    ) -> ResolvedSemanticTarget? {
        let matches = targets.filter {
            let label = normalized($0.text)
            return label == "search" || label.hasSuffix(" search")
        }
        guard matches.count == 1, let match = matches.first else { return nil }
        return ResolvedSemanticTarget(textTarget: match, state: currentState)
    }

    static func resolveSpotlightSearchControl(
        currentQuery: String,
        targets: [TextTarget],
        currentState: SemanticScreenState
    ) -> ResolvedSemanticTarget? {
        if let labeledSearch = resolveSearchControl(
            targets: targets,
            currentState: currentState
        ) {
            return labeledSearch
        }
        let query = normalized(currentQuery)
        let matches = targets.filter {
            normalized($0.text) == query && $0.normalizedBounds.midY < 0.12
        }
        if matches.count == 1, let match = matches.first {
            return ResolvedSemanticTarget(textTarget: match, state: currentState)
        }
        let bottomQueryCandidates = targets.filter { target in
            let label = normalized(target.text)
            let bounds = target.normalizedBounds
            return label.count >= 2
                && label.range(of: "^[0-9:.,%+ -]+$", options: .regularExpression) == nil
                && bounds.midY >= 0.04
                && bounds.midY < 0.12
                && bounds.minX < 0.25
                && bounds.maxX < 0.60
        }
        guard bottomQueryCandidates.count == 1,
              let match = bottomQueryCandidates.first
        else { return nil }
        return ResolvedSemanticTarget(textTarget: match, state: currentState)
    }

    static func spotlightSearchIsVisible(in targets: [TextTarget]) -> Bool {
        let normalizedTargets = targets.map { (normalized($0.text), $0.normalizedBounds) }
        if normalizedTargets.contains(where: {
            $0.0 == "search" || $0.0.hasSuffix(" search")
        }) {
            return true
        }
        if normalizedTargets.contains(where: { $0.0 == "top hit" }) {
            return true
        }
        let hasBottomSearchGlyph = normalizedTargets.contains {
            $0.0 == "q" && $0.1.midY < 0.15
        }
        let hasBottomQuery = normalizedTargets.contains {
            $0.0 != "q" && $0.1.midY < 0.15
        }
        return hasBottomSearchGlyph && hasBottomQuery
    }

    static func spotlightResultMatches(expectedName: String, recognizedText: String) -> Bool {
        let expected = normalized(expectedName)
        let recognized = normalized(recognizedText)
        guard !expected.isEmpty else { return false }
        if recognized == expected { return true }
        guard recognized.hasPrefix(expected + " ") else { return false }
        let suffix = recognized.dropFirst(expected.count + 1)
        return suffix == "open" || suffix.hasPrefix("open ")
    }

    static func appIsVisible(
        named appName: String,
        state: SemanticScreenState,
        targets: [TextTarget]
    ) -> Bool {
        let app = normalized(appName)
        guard ["whatsapp", "whatsapp business", "wa business"].contains(app) else {
            return false
        }
        let labels = Set(targets.map { normalized($0.text) })
        if state == .chatList {
            let tabCount = ["updates", "calls", "tools", "settings"].reduce(into: 0) {
                count, anchor in
                if labels.contains(anchor) { count += 1 }
            }
            return labels.contains("chats") && tabCount >= 3
        }
        if state == .conversation {
            return labels.contains("message")
        }
        return false
    }

    static func resolveVisibleText(
        _ name: String,
        targetID: UUID? = nil,
        placement: SemanticPlacement? = nil,
        targets: [TextTarget],
        currentState: SemanticScreenState
    ) -> ResolvedSemanticTarget? {
        let query = normalized(name)
        guard !query.isEmpty else { return nil }
        let exactMatches = targets.filter {
            normalized($0.text) == query
                && (targetID == nil || $0.id == targetID)
                && (placement == nil || SemanticPlacement(bounds: $0.normalizedBounds) == placement)
        }
        guard exactMatches.count == 1, let match = exactMatches.first else { return nil }
        return ResolvedSemanticTarget(textTarget: match, state: currentState)
    }

    static func resolve(
        fact: LearnedFact,
        targets: [TextTarget],
        currentState: SemanticScreenState
    ) -> ResolvedSemanticTarget? {
        guard let requiredState = fact.requiredState,
              requiredState == currentState
        else { return nil }

        if requiredState == .generic {
            guard let anchors = fact.contextAnchors,
                  ScreenContextAnchors.matches(anchors, targets: targets)
            else { return nil }
        }

        // "Honey" versus "Honey Mom" is an ambiguity, not a fallback.
        return resolveVisibleText(
            fact.name,
            placement: fact.placement,
            targets: targets,
            currentState: currentState
        )
    }

    static func normalized(_ text: String) -> String {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// A stable action target copied into a recorded flow. It stores semantic
/// identity and the required state, never geometry from the recording run.
struct RecordedActionTarget: Codable, Equatable {
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

    init?(fact: LearnedFact) {
        guard let requiredState = fact.requiredState else { return nil }
        self.init(
            name: fact.name,
            kind: fact.kind,
            requiredState: requiredState,
            contextAnchors: fact.contextAnchors ?? [],
            placement: fact.placement
        )
    }
}

struct RecordedActionStep: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case tap
        case input
        case home
    }

    let id: UUID
    let kind: Kind
    let target: RecordedActionTarget?
    /// Stored only inside the encrypted flow store. Summaries, audit events,
    /// and the agent bridge never expose this value.
    let inputText: String?
    /// Expected screen evidence captured only after the original action was
    /// visibly observed. Missing on legacy flows, which are not replayable.
    let postcondition: RecordedScreenPostcondition?
    let recordedAt: Date

    init(
        kind: Kind,
        target: RecordedActionTarget? = nil,
        inputText: String? = nil,
        postcondition: RecordedScreenPostcondition? = nil,
        recordedAt: Date = .now
    ) {
        id = UUID()
        self.kind = kind
        self.target = target
        self.inputText = inputText
        self.postcondition = postcondition
        self.recordedAt = recordedAt
    }

    var summary: String {
        switch kind {
        case .tap: "Tap \(target?.name ?? "verified target")"
        case .input: "Set value in \(target?.name ?? "verified control")"
        case .home: "Go to Home Screen"
        }
    }
}

struct RecordedScreenPostcondition: Codable, Equatable {
    let requiredState: SemanticScreenState
    let contextAnchors: [String]

    func matches(targets: [TextTarget], state: SemanticScreenState) -> Bool {
        guard state == requiredState else { return false }
        guard !contextAnchors.isEmpty else { return true }
        return ScreenContextAnchors.matches(contextAnchors, targets: targets)
    }
}

struct RecordedActionFlow: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    let source: ScreenSource
    var steps: [RecordedActionStep]
    let createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        source: ScreenSource,
        steps: [RecordedActionStep],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.source = source
        self.steps = steps
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Pure resolver used by replay and unit tests. A recorded step can act only
/// when its source, state, and unique live label all agree.
enum RecordedActionResolver {
    static func resolve(
        target: RecordedActionTarget,
        flowSource: ScreenSource,
        activeSource: ScreenSource,
        targets: [TextTarget],
        currentState: SemanticScreenState
    ) -> ResolvedSemanticTarget? {
        guard flowSource == activeSource,
              target.requiredState == currentState
        else { return nil }
        if target.requiredState == .generic || !target.contextAnchors.isEmpty {
            guard ScreenContextAnchors.matches(target.contextAnchors, targets: targets) else { return nil }
        }

        let query = SemanticTargetResolver.normalized(target.name)
        guard !query.isEmpty else { return nil }
        let matches = targets.filter {
            SemanticTargetResolver.normalized($0.text) == query
                && (target.placement == nil || SemanticPlacement(bounds: $0.normalizedBounds) == target.placement)
        }
        guard matches.count == 1, let match = matches.first else { return nil }
        return ResolvedSemanticTarget(textTarget: match, state: currentState)
    }
}

/// Legacy migration data. New learned facts must never persist this geometry:
/// action bounds are resolved from the active capture immediately before input.
struct NormalizedBounds: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(_ rect: CGRect) {
        x = rect.minX
        y = rect.minY
        width = rect.width
        height = rect.height
    }
}

/// A confirmed piece of local semantic context. Facts are encrypted and actions
/// resolve from the current capture rather than persisted geometry.
struct LearnedFact: Codable, Identifiable, Equatable {
    enum Kind: String, Codable, CaseIterable, Hashable {
        case appIcon
        case control
        case screenLandmark

        var title: String {
            switch self {
            case .appIcon: "App icon"
            case .control: "Control"
            case .screenLandmark: "Screen landmark"
            }
        }
    }

    enum Evidence: String, Codable, CaseIterable, Hashable {
        case visionOCR
        case visualInference
        case userConfirmed

        var title: String {
            switch self {
            case .visionOCR: "Local OCR"
            case .visualInference: "Visual inference"
            case .userConfirmed: "User confirmed"
            }
        }
    }

    let id: UUID
    let name: String
    let kind: Kind
    let evidence: Evidence
    /// Retained only to decode pre-semantic records. It is never eligible for
    /// action dispatch; re-learn the fact to make it actionable.
    let normalizedBounds: NormalizedBounds?
    let screenSignature: String
    /// Nil denotes a legacy fact created before capture sources were isolated;
    /// such facts came only from iPhone Mirroring and stay scoped to it.
    let screenSource: ScreenSource?
    /// Missing on legacy facts. Those facts remain readable but are not
    /// eligible for action until saved again with a recognized live state.
    let requiredState: SemanticScreenState?
    /// Stable normalized labels from the same screen, excluding this target.
    /// Generic app screens require these landmarks before an action is valid.
    let contextAnchors: [String]?
    /// Coarse structural position used only to disambiguate equal labels. This
    /// is semantic context, not an actionable coordinate.
    let placement: SemanticPlacement?
    let confidence: Double
    let createdAt: Date
    var lastConfirmedAt: Date
    var confirmationCount: Int

    init(
        id: UUID = UUID(),
        name: String,
        kind: Kind,
        evidence: Evidence,
        normalizedBounds: NormalizedBounds?,
        screenSignature: String,
        screenSource: ScreenSource? = nil,
        requiredState: SemanticScreenState? = nil,
        contextAnchors: [String]? = nil,
        placement: SemanticPlacement? = nil,
        confidence: Double,
        createdAt: Date = .now,
        lastConfirmedAt: Date = .now,
        confirmationCount: Int = 1
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.evidence = evidence
        self.normalizedBounds = normalizedBounds
        self.screenSignature = screenSignature
        self.screenSource = screenSource
        self.requiredState = requiredState
        self.contextAnchors = contextAnchors
        self.placement = placement
        self.confidence = confidence
        self.createdAt = createdAt
        self.lastConfirmedAt = lastConfirmedAt
        self.confirmationCount = confirmationCount
    }

    func isRelevant(to signature: String, source: ScreenSource) -> Bool {
        screenSignature == signature && (screenSource ?? .iPhoneMirroring) == source
    }
}

enum ScreenSignature {
    /// Normalizes transient numbers such as time, counters, and notification
    /// badges while retaining textual layout and approximate positions.
    static func make(from targets: [TextTarget]) -> String {
        targets
            .map { target in
                let normalizedText = target.text
                    .lowercased()
                    .replacingOccurrences(of: "[0-9]+", with: "#", options: .regularExpression)
                    .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let x = Int((target.normalizedBounds.midX * 8).rounded())
                let y = Int((target.normalizedBounds.midY * 12).rounded())
                return "\(normalizedText)@\(x),\(y)"
            }
            .sorted()
            .joined(separator: "|")
    }
}
