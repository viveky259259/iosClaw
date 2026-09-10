import AppKit
import CoreGraphics
import Network
import ScreenCaptureKit
import Vision

@MainActor
final class MirrorSession: ObservableObject {
    @Published private(set) var screenCaptureAllowed = false
    @Published private(set) var accessibilityAllowed = false
    @Published private(set) var mirrorWindow: MirrorWindow?
    @Published private(set) var preview: NSImage?
    @Published private(set) var textTargets: [TextTarget] = []
    @Published private(set) var status = "Ready to inspect iPhone Mirroring or iOS Simulator."
    @Published private(set) var auditEvents: [AuditEvent] = []
    @Published private(set) var learnedFacts: [LearnedFact] = []
    @Published private(set) var currentScreenSignature: String?
    @Published private(set) var captureGeneration: CaptureGeneration?
    @Published private(set) var reusableFacts: [LearnedFact] = []
    @Published var captureSource: ScreenSource = .automatic {
        didSet {
            UserDefaults.standard.set(
                captureSource.rawValue,
                forKey: Self.captureSourcePreferenceKey
            )
        }
    }
    @Published private(set) var activeSource: ScreenSource?
    @Published private(set) var currentSemanticState: SemanticScreenState = .unknown
    @Published private(set) var recordedFlows: [RecordedActionFlow] = []
    @Published private(set) var recordingName: String?
    @Published private(set) var recordingSteps: [RecordedActionStep] = []
    @Published private(set) var replayingFlowID: UUID?
    @Published private(set) var replayStepIndex = 0
    @Published private(set) var isInputInFlight = false
    @Published private(set) var pendingApproval: PendingActionApproval?
    @Published private(set) var sourceHealth: SourceHealth = .idle
    @Published private(set) var latestCompiledRun: CompiledFlowRun?
    @Published private(set) var isCompiledFlowRunning = false
    @Published private(set) var userCompiledDrafts: [CompiledFlowPackage] = []

    private let auditStore: SecureAuditStore?
    private let learningStore: SecureLearningStore?
    private let actionFlowStore: SecureActionFlowStore?
    private let compiledFlowStore: SecureCompiledFlowStore?
    private let inputBackend = MirrorInputBackend()
    private var agentBridge: AgentBridge?
    private var recordingSource: ScreenSource?
    private var replayContext: ReplayContext?
    private var oneTimeApproval: OneTimeActionApproval?
    private let compiledFlowRegistry: CompiledFlowRegistry
    private static let captureSourcePreferenceKey = "iosclaw.captureSource"

    var isRecording: Bool { recordingName != nil }
    var compiledFlowCatalog: [CompiledFlowPackage] {
        CompiledFlowCatalog.merge(
            bundled: compiledFlowRegistry.packages,
            userDrafts: userCompiledDrafts
        )
    }

    init() {
        compiledFlowRegistry = try! CompiledFlowRegistry(packages: BundledCompiledFlowCatalog.packages)
        auditStore = try? SecureAuditStore()
        auditEvents = (try? auditStore?.load()) ?? []
        learningStore = try? SecureLearningStore()
        learnedFacts = (try? learningStore?.load()) ?? []
        actionFlowStore = try? SecureActionFlowStore()
        recordedFlows = (try? actionFlowStore?.load()) ?? []
        compiledFlowStore = try? SecureCompiledFlowStore()
        userCompiledDrafts = ((try? compiledFlowStore?.load()) ?? []).filter {
            $0.status == .draft && CompiledFlowValidator.validate($0).isEmpty
        }
        captureSource = UserDefaults.standard.string(forKey: Self.captureSourcePreferenceKey)
            .flatMap(ScreenSource.init(rawValue:)) ?? .automatic
        refreshPermissions()
        do {
            agentBridge = try AgentBridge(session: self)
        } catch {
            status = "Local agent bridge unavailable: \(error.localizedDescription)"
            NSLog("iosClaw agent bridge failed to start: %@", error.localizedDescription)
        }
    }

    func refreshPermissions() {
        screenCaptureAllowed = CGPreflightScreenCaptureAccess()
        accessibilityAllowed = AXIsProcessTrusted()
    }

    func requestScreenRecording() {
        let promptWasPresented = CGRequestScreenCaptureAccess()
        refreshPermissions()
        if screenCaptureAllowed {
            status = "Screen Recording is enabled. Ready to inspect iPhone Mirroring or iOS Simulator."
        } else if promptWasPresented {
            status = "Approve Screen Recording in macOS, then return here. Access will refresh automatically."
        } else {
            status = "Screen Recording is still unavailable. Check its switch in System Settings, then return here."
        }
        append(kind: .permission, "Requested Screen Recording permission.")
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
        append(kind: .permission, "Opened Accessibility settings.")
    }

    func openScreenRecordingSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") else { return }
        NSWorkspace.shared.open(url)
        append(kind: .permission, "Opened Screen Recording settings.")
    }

    func openIPhoneMirroring() {
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: "/System/Applications/iPhone Mirroring.app"), configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.status = "Could not open iPhone Mirroring: \(error.localizedDescription)"
                } else {
                    self.status = "Opened iPhone Mirroring. Connect a locked iPhone, then inspect it here."
                }
            }
        }
    }

    func openSimulator() {
        guard let simulatorURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iphonesimulator") else {
            status = "iOS Simulator is not installed. Install Xcode, then try again."
            append(kind: .safety, "iOS Simulator could not be found on this Mac.")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: simulatorURL, configuration: configuration) { _, error in
            Task { @MainActor in
                if let error {
                    self.status = "Could not open iOS Simulator: \(error.localizedDescription)"
                } else {
                    self.status = "Opened iOS Simulator. Boot a device, then inspect its visible screen."
                }
            }
        }
    }

    func bootDefaultSimulator() {
        status = "Selecting an available iOS Simulator…"
        Task {
            do {
                let deviceName = try await Task.detached(priority: .userInitiated) {
                    try SimulatorRuntime.bootDefaultDevice()
                }.value
                status = "Booted iOS Simulator: \(deviceName). Open Simulator, then inspect its visible screen."
                append(kind: .observation, "Booted local iOS Simulator: \(deviceName).")
            } catch {
                status = "Could not boot an iOS Simulator: \(error.localizedDescription)"
                append(kind: .safety, "iOS Simulator boot failed: \(error.localizedDescription)")
            }
        }
    }

    func inspect() {
        inspect(completion: nil)
    }

    func runCompiledFlowFromUI(intentID: String, inputs: [String: String]) {
        Task {
            do {
                _ = try await runCompiledFlow(intentID: intentID, inputs: inputs)
            } catch {
                status = error.localizedDescription
                append(kind: .safety, "Compiled flow could not start: \(error.localizedDescription)")
            }
        }
    }

    private func inspect(completion: ((Bool) -> Void)?) {
        refreshPermissions()
        // iosClaw becomes frontmost when its own Inspect button is pressed.  A
        // simulator or Mirroring window can then be occluded, but remains a
        // shareable window.  Do not mistake that normal app focus transition
        // for a disconnected source.
        let info = (CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]) ?? []
        guard let foundWindow = MirrorWindowMatcher.match(in: info, source: captureSource) else {
            mirrorWindow = nil
            activeSource = nil
            preview = nil
            textTargets = []
            captureGeneration = nil
            currentSemanticState = .unknown
            sourceHealth = .missing
            status = missingSourceMessage
            append(kind: .observation, "No \(captureSource.title) window was found.")
            completion?(false)
            return
        }

        mirrorWindow = foundWindow
        activeSource = foundWindow.source
        // A failed fresh inspection must never leave a previous source's image
        // on screen. It is both misleading and unsafe for learned actions.
        preview = nil
        textTargets = []
        currentScreenSignature = nil
        captureGeneration = nil
        reusableFacts = []
        currentSemanticState = .unknown
        guard screenCaptureAllowed else {
            sourceHealth = .permissionRequired
            status = "\(foundWindow.source.title) found. Grant Screen Recording to inspect its visible screen."
            append(kind: .permission, "Screen capture is required to inspect \(foundWindow.source.title).")
            completion?(false)
            return
        }

        sourceHealth = .capturing
        status = "Capturing the visible \(foundWindow.source.title) window…"
        Task { [weak self] in
            guard let self else { return }
            let outcome = await self.capture(foundWindow)
            guard let image = outcome.image else {
                self.sourceHealth = .failed
                self.status = "Could not capture \(foundWindow.source.title): \(outcome.failureReason ?? "an unknown capture error")"
                self.append(kind: .safety, "Capture failed: \(outcome.failureReason ?? "unknown reason"). No automation action was attempted.")
                completion?(false)
                return
            }

            // ScreenCaptureKit can return the content region of a window rather
            // than its AppKit/WindowServer frame (notably for iPhone Mirroring).
            // Giving NSImage the outer window size distorts that portrait frame
            // and makes the preview look like only a small part was captured.
            // Preserve the captured image's own aspect ratio for every viewer.
            self.preview = NSImage(
                cgImage: image,
                size: CGSize(width: image.width, height: image.height)
            )
            self.status = "Captured the visible \(foundWindow.source.title) window. Recognizing text locally…"
            self.append(kind: .observation, "Captured \(foundWindow.source.title) for local inspection.")
            self.recognizeText(in: image, window: foundWindow, completion: completion)
        }
    }

    func goHome(completion: ((Bool) -> Void)? = nil) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        guard let mirrorWindow else {
            status = "Open and inspect a screen source before sending navigation input."
            completion?(false)
            return
        }
        guard recordingAccepts(source: mirrorWindow.source) else {
            completion?(false)
            return
        }
        performInput("Opened the \(mirrorWindow.source.title) Home Screen.", onSuccess: { [weak self] in
            self?.recordVerified(kind: .home)
        }, completion: completion) {
            try inputBackend.press(.homeScreen, in: mirrorWindow)
        }
    }

    func openSpotlight(completion: ((Bool) -> Void)? = nil) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        guard let mirrorWindow else {
            status = "Open and inspect iPhone Mirroring before opening Spotlight."
            completion?(false)
            return
        }
        guard mirrorWindow.source == .iPhoneMirroring else {
            status = "Spotlight navigation is available for iPhone Mirroring."
            completion?(false)
            return
        }
        performInput(
            "Opened Spotlight in iPhone Mirroring.",
            verification: .screenChanged,
            completion: completion
        ) {
            try inputBackend.press(.spotlight, in: mirrorWindow)
        }
    }

    func openSpotlightTopHit(expectedName: String, completion: ((Bool) -> Void)? = nil) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        guard let mirrorWindow, mirrorWindow.source == .iPhoneMirroring else {
            status = "Open and inspect iPhone Mirroring before opening a Spotlight result."
            completion?(false)
            return
        }

        let expected = SemanticTargetResolver.normalized(expectedName)
        let topHitHeadings = textTargets.filter {
            let label = SemanticTargetResolver.normalized($0.text)
            return label == "top hit"
        }
        let appHeadings = textTargets.filter {
            SemanticTargetResolver.normalized($0.text) == "apps"
        }
        let heading: TextTarget?
        let usesTopHit: Bool
        if topHitHeadings.count == 1 {
            heading = topHitHeadings.first
            usesTopHit = true
        } else if topHitHeadings.isEmpty, appHeadings.count == 1 {
            heading = appHeadings.first
            usesTopHit = false
        } else {
            heading = nil
            usesTopHit = false
        }
        guard let heading else {
            status = "Spotlight's app result section is not uniquely visible. Inspect again before opening a result."
            completion?(false)
            return
        }
        let candidates = textTargets.filter { target in
            SemanticTargetResolver.spotlightResultMatches(
                expectedName: expected,
                recognizedText: target.text
            )
                && abs(heading.normalizedBounds.midY - target.normalizedBounds.midY) < 0.25
        }
        guard candidates.count == 1, let candidate = candidates.first else {
            status = "The expected app is not the verified Spotlight app result. No action was sent."
            completion?(false)
            return
        }

        performInput(
            "Opened verified Spotlight app result: \(expectedName).",
            verification: .screenChanged,
            completion: completion
        ) {
            if usesTopHit {
                try inputBackend.press(.moveSelectionDown, in: mirrorWindow)
                Thread.sleep(forTimeInterval: 0.12)
                try inputBackend.press(.activateSelection, in: mirrorWindow)
            } else {
                try inputBackend.tap(
                    target: ResolvedSemanticTarget(
                        textTarget: candidate,
                        state: self.currentSemanticState
                    ),
                    in: mirrorWindow
                )
            }
        }
    }

    /// A tap is permitted only for a fact whose label still verifies on the
    /// currently captured screen. This supports chat rows and buttons as well
    /// as app icons without reintroducing blind coordinate actions.
    func tapLearnedFact(_ fact: LearnedFact, completion: ((Bool) -> Void)? = nil) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        guard fact.confidence >= 0.8,
              let activeSource,
              let target = resolveLiveTarget(fact, in: activeSource),
              let mirrorWindow
        else {
            status = "That learned target is not uniquely valid for the current screen. Inspect again before tapping."
            completion?(false)
            return
        }
        guard recordingAccepts(source: activeSource),
              let recordedTarget = RecordedActionTarget(fact: fact)
        else {
            completion?(false)
            return
        }
        guard authorizeAction(kind: .tap, targetName: fact.name, source: activeSource) else {
            completion?(false)
            return
        }
        performInput("Sent one tap to learned \(fact.kind.title.lowercased()): \(fact.name).", onSuccess: { [weak self] in
            self?.recordVerified(kind: .tap, target: recordedTarget)
        }, completion: completion) {
            try inputBackend.tap(target: target, in: mirrorWindow)
        }
    }

    func input(_ text: String, into control: LearnedFact, completion: ((Bool) -> Void)? = nil) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              control.kind == .control,
              control.confidence >= 0.8,
              let activeSource,
              let target = resolveLiveTarget(control, in: activeSource),
              let mirrorWindow
        else {
            status = "That learned control is not valid for the current screen. Inspect and confirm it again before entering text."
            completion?(false)
            return
        }
        guard recordingAccepts(source: activeSource),
              let recordedTarget = RecordedActionTarget(fact: control)
        else {
            completion?(false)
            return
        }
        guard authorizeAction(kind: .input, targetName: control.name, source: activeSource) else {
            completion?(false)
            return
        }

        performInput(
            "Entered text into learned control: \(control.name).",
            verification: .textPresent(trimmed),
            onSuccess: { [weak self] in
            self?.recordVerified(kind: .input, target: recordedTarget, inputText: trimmed)
        }, completion: completion) {
            try inputBackend.tap(target: target, in: mirrorWindow)
            Thread.sleep(forTimeInterval: 0.12)
            try inputBackend.clearText(in: mirrorWindow)
            try inputBackend.type(trimmed, in: mirrorWindow)
        }
    }

    /// Acts on a uniquely visible label using only the current capture. This is
    /// intentionally transient so private, frequently changing labels (for
    /// example a conversation name) do not need to enter learned context.
    func tapVisibleText(
        _ name: String,
        targetID: UUID? = nil,
        placement: SemanticPlacement? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        guard let activeSource,
              let mirrorWindow,
              let target = SemanticTargetResolver.resolveVisibleText(
                name,
                targetID: targetID,
                placement: placement,
                targets: textTargets,
                currentState: currentSemanticState
              )
        else {
            status = "The visible label ‘\(name)’ is missing or ambiguous. No action was sent."
            completion?(false)
            return
        }
        guard authorizeAction(kind: .tap, targetName: name, source: activeSource) else {
            completion?(false)
            return
        }
        performInput(
            "Tapped the uniquely visible label: \(name).",
            verification: .screenChanged,
            completion: completion
        ) {
            try inputBackend.tap(target: target, in: mirrorWindow)
        }
    }

    func inputVisibleText(
        _ text: String,
        into name: String,
        targetID: UUID? = nil,
        placement: SemanticPlacement? = nil,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let activeSource,
              let mirrorWindow,
              let target = SemanticTargetResolver.resolveVisibleText(
                name,
                targetID: targetID,
                placement: placement,
                targets: textTargets,
                currentState: currentSemanticState
              )
        else {
            status = "The visible input label ‘\(name)’ is missing or ambiguous. No text was entered."
            completion?(false)
            return
        }
        guard authorizeAction(kind: .input, targetName: name, source: activeSource) else {
            completion?(false)
            return
        }
        performInput(
            "Entered text into the uniquely visible control: \(name).",
            verification: .textPresentAtPlacement(
                trimmed,
                SemanticPlacement(bounds: target.textTarget.normalizedBounds)
            ),
            completion: completion
        ) {
            try inputBackend.tap(target: target, in: mirrorWindow)
            Thread.sleep(forTimeInterval: 0.12)
            try inputBackend.clearText(in: mirrorWindow)
            try inputBackend.type(trimmed, in: mirrorWindow)
        }
    }

    /// WhatsApp's hardware-keyboard path avoids iPhone Mirroring's filtered
    /// pointer stream: Find focuses chat search, typing narrows to a recipient,
    /// and Return opens the selected result. The final conversation must expose
    /// both the exact recipient title and exact composer label.
    func openWhatsAppChatViaKeyboard(
        _ contactName: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        findAndActivateViaKeyboard(
            contactName,
            confirmationTexts: ["Message"],
            successSummary: "Opened the verified requested WhatsApp conversation.",
            completion: completion
        )
    }

    /// A shared compound primitive for apps whose hardware-keyboard Find
    /// command focuses a collection search and Return activates its selected
    /// result. App packs supply the semantic confirmation labels.
    func findAndActivateViaKeyboard(
        _ query: String,
        confirmationTexts: [String],
        successSummary: String,
        completion: ((Bool) -> Void)? = nil
    ) {
        guard replayContext == nil, !isInputInFlight else {
            status = "Wait for the current action or replay to finish."
            completion?(false)
            return
        }
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedQuery.isEmpty,
              !confirmationTexts.isEmpty,
              currentSemanticState == .chatList,
              let activeSource,
              let mirrorWindow
        else {
            status = "Open a verified Chats screen before using keyboard collection search."
            completion?(false)
            return
        }
        guard authorizeAction(kind: .tap, targetName: normalizedQuery, source: activeSource) else {
            completion?(false)
            return
        }
        performInput(
            successSummary,
            verification: .exactTextsPresent([normalizedQuery] + confirmationTexts),
            completion: completion
        ) {
            try inputBackend.press(.find, in: mirrorWindow)
            Thread.sleep(forTimeInterval: 0.20)
            try inputBackend.clearText(in: mirrorWindow)
            try inputBackend.type(normalizedQuery, in: mirrorWindow)
            Thread.sleep(forTimeInterval: 0.45)
            try inputBackend.press(.activateSelection, in: mirrorWindow)
            Thread.sleep(forTimeInterval: 0.35)
        }
    }

    func isFactLive(_ fact: LearnedFact) -> Bool {
        guard !isInputInFlight,
              replayContext == nil,
              let activeSource,
              let mirrorWindow,
              captureGeneration?.authorizes(window: mirrorWindow) == true
        else { return false }
        return resolveLiveTarget(fact, in: activeSource) != nil
    }

    func approvePendingAction() {
        guard let pendingApproval else { return }
        guard pendingApproval.expiresAt >= .now else {
            self.pendingApproval = nil
            status = "That approval request expired. Re-run the action to validate the current screen again."
            append(kind: .safety, "An action approval expired before it was granted.")
            return
        }

        oneTimeApproval = OneTimeActionApproval(
            fingerprint: pendingApproval.fingerprint,
            expiresAt: Date.now.addingTimeInterval(30)
        )
        self.pendingApproval = nil
        status = "Approved once: \(pendingApproval.actionDescription). Revalidating before execution."
        append(kind: .permission, "User approved one \(pendingApproval.effect.title.lowercased()) action.")

        if replayContext != nil {
            inspectForReplay()
        }
    }

    func denyPendingAction() {
        guard let pendingApproval else { return }
        self.pendingApproval = nil
        oneTimeApproval = nil
        append(kind: .safety, "User denied one \(pendingApproval.effect.title.lowercased()) action.")
        if replayContext != nil {
            failReplay("The required action approval was denied.")
        } else {
            status = "Cancelled: \(pendingApproval.actionDescription)."
        }
    }

    private func authorizeAction(
        kind: SemanticActionKind,
        targetName: String,
        source: ScreenSource
    ) -> Bool {
        switch ActionPolicy.evaluate(kind: kind, targetName: targetName) {
        case .allow:
            return true
        case .block(let reason):
            status = reason
            append(kind: .safety, "Blocked sensitive input into \(targetName).")
            return false
        case .requireApproval(let effect):
            let fingerprint = approvalFingerprint(
                kind: kind,
                targetName: targetName,
                source: source,
                state: currentSemanticState
            )
            if oneTimeApproval?.authorizes(fingerprint) == true {
                oneTimeApproval = nil
                return true
            }

            oneTimeApproval = nil
            pendingApproval = PendingActionApproval(
                fingerprint: fingerprint,
                effect: effect,
                actionDescription: "\(kind.rawValue.capitalized) ‘\(targetName)’ in \(source.title)"
            )
            status = "Approval required in iosClaw before \(kind.rawValue) ‘\(targetName)’ can run."
            append(kind: .permission, "Requested approval for one \(effect.title.lowercased()) action.")
            return false
        }
    }

    private func approvalFingerprint(
        kind: SemanticActionKind,
        targetName: String,
        source: ScreenSource,
        state: SemanticScreenState
    ) -> String {
        [kind.rawValue, source.rawValue, state.rawValue, SemanticTargetResolver.normalized(targetName)]
            .joined(separator: "|")
    }

    /// Resolves fresh geometry from the active capture. Persisted coordinates
    /// are intentionally excluded so reordering cannot replay a stale tap.
    private func resolveLiveTarget(_ fact: LearnedFact, in source: ScreenSource) -> ResolvedSemanticTarget? {
        guard (fact.screenSource ?? .iPhoneMirroring) == source else { return nil }
        return SemanticTargetResolver.resolve(
            fact: fact,
            targets: textTargets,
            currentState: currentSemanticState
        )
    }

    private struct CaptureOutcome {
        let image: CGImage?
        let failureReason: String?
    }

    private func capture(_ window: MirrorWindow) async -> CaptureOutcome {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
            guard let shareableWindow = content.windows.first(where: { $0.windowID == window.id }) else {
                return CaptureOutcome(
                    image: nil,
                    failureReason: "iPhone Mirroring did not expose a shareable ScreenCaptureKit window."
                )
            }

            let filter = SCContentFilter(desktopIndependentWindow: shareableWindow)
            do {
                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: screenshotConfiguration(for: filter)
                )
                if hasVisibleContent(image), matchesAspectRatio(image, expectedFrame: shareableWindow.frame) {
                    return CaptureOutcome(image: image, failureReason: nil)
                }
                return await captureViaDisplay(
                    window: window,
                    shareableWindow: shareableWindow,
                    displays: content.displays,
                    precedingFailure: "ScreenCaptureKit returned an empty window frame."
                )
            } catch {
                return await captureViaDisplay(
                    window: window,
                    shareableWindow: shareableWindow,
                    displays: content.displays,
                    precedingFailure: "ScreenCaptureKit window capture failed (\(error.localizedDescription))."
                )
            }
        } catch {
            return CaptureOutcome(
                image: nil,
                failureReason: "ScreenCaptureKit could not enumerate shareable content (\(error.localizedDescription))."
            )
        }
    }

    private func captureViaDisplay(
        window: MirrorWindow,
        shareableWindow: SCWindow,
        displays: [SCDisplay],
        precedingFailure: String
    ) async -> CaptureOutcome {
        guard let display = displays.first(where: { $0.frame.intersects(shareableWindow.frame) }) else {
            return CaptureOutcome(
                image: nil,
                failureReason: "\(precedingFailure) No matching display was available for retry."
            )
        }

        await prepareSourceForDisplayCapture(window)
        let visibleWindows = (CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]) ?? []
        if WindowOcclusionPolicy.sourceIsTopmostAtCenter(window, orderedWindowInfo: visibleWindows),
           let cropped = try? await displayCrop(shareableWindow, from: display),
           hasVisibleContent(cropped) {
            return CaptureOutcome(image: cropped, failureReason: nil)
        }

        do {
            // Include only the selected source window. Capturing the complete
            // display and cropping by geometry is unsafe when another Mac app
            // occludes the mirror: the crop would contain the occluding app and
            // could be mistaken for live iPhone state.
            let displayFilter = SCContentFilter(display: display, including: [shareableWindow])
            let image = try await SCScreenshotManager.captureImage(
                contentFilter: displayFilter,
                configuration: screenshotConfiguration(for: displayFilter)
            )
            if hasVisibleContent(image), matchesAspectRatio(image, expectedFrame: shareableWindow.frame) {
                return CaptureOutcome(image: image, failureReason: nil)
            }
        } catch {}

        return CaptureOutcome(
            image: nil,
            failureReason: "\(precedingFailure) The selected source returned an empty frame on every capture path."
        )
    }

    private func prepareSourceForDisplayCapture(_ window: MirrorWindow) async {
        NSRunningApplication(processIdentifier: window.ownerPID)?.activate(options: [.activateAllWindows])
        if AXIsProcessTrusted() {
            let applicationElement = AXUIElementCreateApplication(window.ownerPID)
            var windowsValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(
                applicationElement,
                kAXWindowsAttribute as CFString,
                &windowsValue
            ) == .success,
               let windows = windowsValue as? [AXUIElement],
               let sourceWindow = windows.first
            {
                AXUIElementPerformAction(sourceWindow, kAXRaiseAction as CFString)
            }
        }
        try? await Task.sleep(nanoseconds: 200_000_000)
    }

    private func screenshotConfiguration(for filter: SCContentFilter) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let scale = max(1, CGFloat(filter.pointPixelScale))
        configuration.width = max(1, Int((filter.contentRect.width * scale).rounded(.up)))
        configuration.height = max(1, Int((filter.contentRect.height * scale).rounded(.up)))
        return configuration
    }

    private func displayCrop(_ window: SCWindow, from display: SCDisplay) async throws -> CGImage? {
        let filter = SCContentFilter(display: display, excludingWindows: [])
        let displayImage = try await SCScreenshotManager.captureImage(
            contentFilter: filter,
            configuration: screenshotConfiguration(for: filter)
        )
        let displayFrame = display.frame
        guard displayFrame.width > 0, displayFrame.height > 0 else { return nil }

        let scaleX = CGFloat(displayImage.width) / displayFrame.width
        let scaleY = CGFloat(displayImage.height) / displayFrame.height
        let availablePixels = CGRect(x: 0, y: 0, width: displayImage.width, height: displayImage.height)
        let globalFrame = CGRect(
            x: (window.frame.minX - displayFrame.minX) * scaleX,
            y: (window.frame.minY - displayFrame.minY) * scaleY,
            width: window.frame.width * scaleX,
            height: window.frame.height * scaleY
        )
        return displayImage.cropping(to: globalFrame.integral.intersection(availablePixels))
    }

    /// Mirroring can expose a black or transparent protected frame to a
    /// window-only capture even while its display stream contains real pixels.
    /// Sample a small grid so that an empty frame never reaches OCR or the UI.
    private func hasVisibleContent(_ image: CGImage) -> Bool {
        let sampleWidth = 32
        let sampleHeight = 32
        var pixels = Array(repeating: UInt8(0), count: sampleWidth * sampleHeight * 4)
        guard let context = CGContext(
            data: &pixels,
            width: sampleWidth,
            height: sampleHeight,
            bitsPerComponent: 8,
            bytesPerRow: sampleWidth * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else { return true }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight))

        var opaquePixels = 0
        var minimumLuminance: UInt8 = .max
        var maximumLuminance: UInt8 = .min
        var luminanceTotal = 0
        for index in stride(from: 0, to: pixels.count, by: 4) {
            let alpha = pixels[index + 3]
            guard alpha > 16 else { continue }
            opaquePixels += 1
            let luminance = UInt8((UInt16(pixels[index]) * 54 + UInt16(pixels[index + 1]) * 183 + UInt16(pixels[index + 2]) * 19) / 256)
            minimumLuminance = min(minimumLuminance, luminance)
            maximumLuminance = max(maximumLuminance, luminance)
            luminanceTotal += Int(luminance)
        }
        guard opaquePixels > 64, maximumLuminance - minimumLuminance > 20 else { return false }

        let mean = luminanceTotal / opaquePixels
        let visiblyDifferentPixels = stride(from: 0, to: pixels.count, by: 4).reduce(into: 0) { count, index in
            guard pixels[index + 3] > 16 else { return }
            let luminance = Int((UInt16(pixels[index]) * 54 + UInt16(pixels[index + 1]) * 183 + UInt16(pixels[index + 2]) * 19) / 256)
            if abs(luminance - mean) > 12 { count += 1 }
        }
        return visiblyDifferentPixels >= max(16, opaquePixels / 20)
    }

    private func matchesAspectRatio(_ image: CGImage, expectedFrame: CGRect) -> Bool {
        guard image.height > 0, expectedFrame.height > 0, expectedFrame.width > 0 else { return false }
        let capturedAspect = CGFloat(image.width) / CGFloat(image.height)
        let expectedAspect = expectedFrame.width / expectedFrame.height
        return abs(capturedAspect - expectedAspect) / expectedAspect < 0.2
    }

    private func recognizeText(
        in image: CGImage,
        window: MirrorWindow,
        completion: ((Bool) -> Void)? = nil
    ) {
        Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image)

            do {
                try handler.perform([request])
                let targets = (request.results ?? []).compactMap { observation -> TextTarget? in
                    guard let text = observation.topCandidates(1).first?.string, !text.isEmpty else { return nil }
                    return TextTarget(text: text, normalizedBounds: observation.boundingBox)
                }
                await MainActor.run {
                    self.textTargets = targets
                    let signature = ScreenSignature.make(from: targets)
                    self.currentScreenSignature = signature
                    if let interruption = SourceInterruptionDetector.reason(in: targets) {
                        self.captureGeneration = nil
                        self.currentSemanticState = .unknown
                        self.reusableFacts = []
                        self.sourceHealth = .interrupted
                        self.status = interruption
                        self.append(kind: .safety, "Blocked automation because the selected source is interrupted.")
                        completion?(false)
                        return
                    }
                    self.captureGeneration = CaptureGeneration(
                        windowID: window.id,
                        windowBounds: window.bounds,
                        source: window.source,
                        screenSignature: signature
                    )
                    let semanticState = SemanticScreenState.classify(targets)
                    self.currentSemanticState = semanticState
                    self.sourceHealth = .ready
                    let previousFacts = self.learnedFacts.filter {
                        SemanticTargetResolver.resolve(
                            fact: $0,
                            targets: targets,
                            currentState: semanticState
                        ) != nil && ($0.screenSource ?? .iPhoneMirroring) == window.source
                    }
                    self.reusableFacts = previousFacts
                    self.status = targets.isEmpty
                        ? "Capture complete. No readable text was detected."
                        : "Capture complete. Found \(targets.count) visible text target(s) in \(semanticState.rawValue); reused \(previousFacts.count) verified local fact(s)."
                    self.append(kind: .observation, "Recognized \(targets.count) visible text target(s) in \(semanticState.rawValue); reused \(previousFacts.count) local fact(s).")
                    completion?(!targets.isEmpty)
                }
            } catch {
                await MainActor.run {
                    self.sourceHealth = .failed
                    self.captureGeneration = nil
                    self.status = "Capture succeeded, but local text recognition failed."
                    self.append(kind: .safety, "OCR failed; no automation action was attempted.")
                    completion?(false)
                }
            }
        }
    }

    private func append(kind: AuditEvent.Kind, _ summary: String) {
        auditEvents.insert(AuditEvent(kind: kind, summary: summary), at: 0)
        try? auditStore?.save(auditEvents)
    }

    private func performInput(
        _ summary: String,
        reInspect: Bool = true,
        verification: ActionPostcondition = .freshObservation,
        onSuccess: (() -> Void)? = nil,
        completion: ((Bool) -> Void)? = nil,
        action: () throws -> Void
    ) {
        refreshPermissions()
        guard !isInputInFlight else {
            status = "Wait for the current action to finish."
            completion?(false)
            return
        }
        guard accessibilityAllowed else {
            status = "Grant Accessibility before sending input to the selected screen source."
            append(kind: .permission, "Accessibility is required before input can be sent.")
            completion?(false)
            return
        }
        guard sourceHealth.allowsInput else {
            status = "The selected screen source is not ready for input. Inspect it again after reconnecting."
            append(kind: .safety, "Blocked input because the selected source health was \(sourceHealth.rawValue).")
            completion?(false)
            return
        }
        guard let mirrorWindow,
              let beforeGeneration = captureGeneration,
              beforeGeneration.authorizes(window: mirrorWindow)
        else {
            status = "The inspected screen is stale or its window moved. Inspect again before sending input."
            append(kind: .safety, "Blocked input because its capture generation was stale or no longer matched the source window.")
            completion?(false)
            return
        }

        do {
            isInputInFlight = true
            try action()
            status = reInspect ? "\(summary) Re-inspecting to verify the visible result…" : summary
            if reInspect {
                Task { [weak self] in
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    self?.inspect { [weak self] success in
                        guard let self else { return }
                        guard success,
                              let afterGeneration = self.captureGeneration,
                              verification.isSatisfied(
                                before: beforeGeneration,
                                after: afterGeneration,
                                afterTargets: self.textTargets
                              )
                        else {
                            self.isInputInFlight = false
                            self.status = "The input was dispatched, but iosClaw could not verify its visible result. Automation stopped."
                            self.append(kind: .safety, "Input result could not be verified after dispatch; no success was recorded.")
                            completion?(false)
                            return
                        }
                        self.isInputInFlight = false
                        self.status = "Verified: \(summary)"
                        self.append(kind: .observation, "Verified: \(summary)")
                        onSuccess?()
                        completion?(true)
                    }
                }
            } else {
                isInputInFlight = false
                append(kind: .observation, summary)
                onSuccess?()
                completion?(true)
            }
        } catch {
            isInputInFlight = false
            status = error.localizedDescription
            append(kind: .safety, "Input was not sent: \(error.localizedDescription)")
            completion?(false)
        }
    }

    func startRecording(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            status = "Give this recording a name before starting."
            return
        }
        guard replayContext == nil else {
            status = "Wait for the current replay to finish before recording a new flow."
            return
        }
        guard let activeSource else {
            status = "Inspect iPhone Mirroring or Simulator before starting a recording."
            return
        }
        recordingName = trimmed
        recordingSource = activeSource
        recordingSteps = []
        status = "Recording ‘\(trimmed)’. Use iosClaw actions normally; verified taps, input, and Home are captured."
        append(kind: .observation, "Started manual action recording: \(trimmed).")
    }

    func stopRecording() {
        guard let name = recordingName, let source = recordingSource else {
            status = "No manual action recording is active."
            return
        }
        guard !recordingSteps.isEmpty else {
            status = "No actions were recorded. Perform at least one iosClaw action or cancel the recording."
            return
        }

        let flow = RecordedActionFlow(name: name, source: source, steps: recordingSteps)
        recordedFlows.insert(flow, at: 0)
        recordedFlows = Array(recordedFlows.prefix(500))
        try? actionFlowStore?.save(recordedFlows)
        recordingName = nil
        recordingSource = nil
        recordingSteps = []
        status = "Saved ‘\(name)’ with \(flow.steps.count) semantic action(s)."
        append(kind: .observation, "Saved manual action flow: \(name), \(flow.steps.count) step(s).")
    }

    func cancelRecording() {
        guard let name = recordingName else { return }
        recordingName = nil
        recordingSource = nil
        recordingSteps = []
        status = "Discarded the unsaved recording ‘\(name)’."
        append(kind: .observation, "Discarded manual action recording: \(name).")
    }

    func deleteRecordedFlow(_ flow: RecordedActionFlow) {
        guard replayingFlowID != flow.id else {
            status = "Wait for this replay to finish before deleting it."
            return
        }
        recordedFlows.removeAll { $0.id == flow.id }
        try? actionFlowStore?.save(recordedFlows)
        status = "Deleted the recorded flow ‘\(flow.name)’."
        append(kind: .observation, "Deleted manual action flow: \(flow.name).")
    }

    func replay(_ flow: RecordedActionFlow) {
        guard !isRecording else {
            status = "Stop or cancel the current recording before replaying a flow."
            return
        }
        guard replayContext == nil else {
            status = "Another replay is already running."
            return
        }
        guard !flow.steps.isEmpty else {
            status = "This recorded flow has no actions to replay."
            return
        }
        guard flow.steps.allSatisfy({ $0.postcondition != nil }) else {
            status = "This flow predates verified postconditions. Record it again before replaying it."
            append(kind: .safety, "Blocked replay of a legacy flow without post-action assertions: \(flow.name).")
            return
        }

        captureSource = flow.source
        replayContext = ReplayContext(flow: flow, stepIndex: 0)
        replayingFlowID = flow.id
        replayStepIndex = 0
        status = "Replaying ‘\(flow.name)’: validating step 1 of \(flow.steps.count)…"
        append(kind: .observation, "Started confirmed replay: \(flow.name).")
        inspectForReplay()
    }

    func cancelReplay() {
        guard let context = replayContext else { return }
        replayContext = nil
        replayingFlowID = nil
        replayStepIndex = 0
        status = "Stopped replaying ‘\(context.flow.name)’."
        append(kind: .safety, "User stopped replay: \(context.flow.name).")
    }

    private func recordingAccepts(source: ScreenSource) -> Bool {
        guard let recordingSource else { return true }
        guard recordingSource == source else {
            status = "This recording is scoped to \(recordingSource.title). Stop it before acting on \(source.title)."
            append(kind: .safety, "Blocked a cross-source action during manual recording.")
            return false
        }
        return true
    }

    private func recordVerified(
        kind: RecordedActionStep.Kind,
        target: RecordedActionTarget? = nil,
        inputText: String? = nil
    ) {
        guard isRecording, replayContext == nil else { return }
        let anchors = ScreenContextAnchors.make(from: textTargets)
        let postcondition = RecordedScreenPostcondition(
            requiredState: currentSemanticState,
            contextAnchors: anchors.count >= 2 ? anchors : []
        )
        let step = RecordedActionStep(
            kind: kind,
            target: target,
            inputText: inputText,
            postcondition: postcondition
        )
        recordingSteps.append(step)
        status = "Recorded step \(recordingSteps.count): \(step.summary). Re-inspecting the result…"
    }

    private func inspectForReplay() {
        inspect { [weak self] success in
            guard let self else { return }
            guard success else {
                self.failReplay("A fresh screen could not be inspected.")
                return
            }
            self.executeReplayStep()
        }
    }

    private func executeReplayStep() {
        guard let context = replayContext,
              context.stepIndex < context.flow.steps.count,
              let mirrorWindow,
              let activeSource,
              activeSource == context.flow.source
        else {
            failReplay("The selected screen source changed or became unavailable.")
            return
        }

        let step = context.flow.steps[context.stepIndex]
        replayStepIndex = context.stepIndex
        switch step.kind {
        case .home:
            performReplayInput(step: step) {
                try inputBackend.press(.homeScreen, in: mirrorWindow)
            }
        case .tap, .input:
            guard let recordedTarget = step.target,
                  let liveTarget = RecordedActionResolver.resolve(
                    target: recordedTarget,
                    flowSource: context.flow.source,
                    activeSource: activeSource,
                    targets: textTargets,
                    currentState: currentSemanticState
                  )
            else {
                failReplay("Step \(context.stepIndex + 1) could not uniquely verify ‘\(step.target?.name ?? "target")’ in the expected screen state.")
                return
            }

            let semanticKind: SemanticActionKind = step.kind == .tap ? .tap : .input
            guard authorizeAction(
                kind: semanticKind,
                targetName: recordedTarget.name,
                source: activeSource
            ) else { return }

            if step.kind == .tap {
                performReplayInput(step: step) {
                    try inputBackend.tap(target: liveTarget, in: mirrorWindow)
                }
            } else {
                guard recordedTarget.kind == .control,
                      let inputText = step.inputText,
                      !inputText.isEmpty
                else {
                    failReplay("Step \(context.stepIndex + 1) does not contain a valid encrypted input value.")
                    return
                }
                performReplayInput(step: step) {
                    try inputBackend.tap(target: liveTarget, in: mirrorWindow)
                    Thread.sleep(forTimeInterval: 0.12)
                    try inputBackend.clearText(in: mirrorWindow)
                    try inputBackend.type(inputText, in: mirrorWindow)
                }
            }
        }
    }

    private func performReplayInput(step: RecordedActionStep, action: () throws -> Void) {
        performInput("Replayed: \(step.summary).", onSuccess: { [weak self] in
            self?.finishReplayStep()
        }, action: action)
    }

    private func finishReplayStep() {
        guard var context = replayContext else { return }
        let completedStep = context.flow.steps[context.stepIndex]
        guard let postcondition = completedStep.postcondition,
              postcondition.matches(targets: textTargets, state: currentSemanticState)
        else {
            failReplay("Step \(context.stepIndex + 1) did not reach its recorded semantic postcondition.")
            return
        }
        context.stepIndex += 1
        replayContext = context
        if context.stepIndex >= context.flow.steps.count {
            replayContext = nil
            replayingFlowID = nil
            replayStepIndex = context.flow.steps.count
            status = "Replay complete: ‘\(context.flow.name)’ ran \(context.flow.steps.count) verified action(s)."
            append(kind: .observation, "Completed verified replay: \(context.flow.name).")
            return
        }

        status = "Replaying ‘\(context.flow.name)’: validating step \(context.stepIndex + 1) of \(context.flow.steps.count)…"
        executeReplayStep()
    }

    private func failReplay(_ reason: String) {
        guard let context = replayContext else { return }
        let failedStep = context.stepIndex + 1
        replayContext = nil
        replayingFlowID = nil
        status = "Replay stopped at step \(failedStep): \(reason)"
        append(kind: .safety, "Replay \(context.flow.name) stopped at step \(failedStep): \(reason)")
    }

    private struct ReplayContext {
        let flow: RecordedActionFlow
        var stepIndex: Int
    }

    /// Stores semantic identity and required state. Legacy geometry may be
    /// supplied by an older caller but is discarded before persistence.
    func remember(
        name: String,
        kind: LearnedFact.Kind,
        evidence: LearnedFact.Evidence,
        normalizedBounds: NormalizedBounds?,
        confidence: Double,
        screenSignature: String? = nil,
        liveTargetID: UUID? = nil
    ) {
        guard let signature = screenSignature ?? currentScreenSignature else {
            status = "Capture a screen before saving learned context."
            return
        }
        guard let activeSource else {
            status = "Capture a screen source before saving learned context."
            return
        }
        guard currentSemanticState != .unknown else {
            status = "iosClaw could not identify a stable screen state. Inspect a screen with readable labels before saving an actionable fact."
            return
        }
        guard let mirrorWindow,
              captureGeneration?.authorizes(
                window: mirrorWindow,
                maximumAge: 30
              ) == true
        else {
            status = "The current screen evidence expired. Inspect again before saving learned context."
            return
        }
        let normalizedName = SemanticTargetResolver.normalized(name)
        let labelMatches = textTargets.filter {
            SemanticTargetResolver.normalized($0.text) == normalizedName
        }
        let selectedTarget: TextTarget?
        if let liveTargetID {
            selectedTarget = labelMatches.first { $0.id == liveTargetID }
        } else {
            selectedTarget = labelMatches.count == 1 ? labelMatches[0] : nil
        }
        guard let selectedTarget else {
            status = labelMatches.isEmpty
                ? "No live OCR target exactly matches ‘\(name)’."
                : "More than one live target matches ‘\(name)’. Choose its current target ID before saving it."
            return
        }
        let anchors = ScreenContextAnchors.make(from: textTargets, excluding: name)
        guard currentSemanticState != .generic || anchors.count >= 2 else {
            status = "This screen does not have enough stable text landmarks to save a safe reusable action."
            return
        }

        let fact = LearnedFact(
            name: name,
            kind: kind,
            evidence: evidence,
            normalizedBounds: nil,
            screenSignature: signature,
            screenSource: activeSource,
            requiredState: currentSemanticState,
            contextAnchors: anchors,
            placement: SemanticPlacement(bounds: selectedTarget.normalizedBounds),
            confidence: confidence
        )
        upsert(fact)
        reusableFacts = learnedFacts.filter { isFactLive($0) }
        append(kind: .observation, "Saved semantic \(kind.title.lowercased()): \(name) for \(currentSemanticState.rawValue).")
    }

    private func upsert(_ fact: LearnedFact) {
        let key = factKey(for: fact)
        if let index = learnedFacts.firstIndex(where: { factKey(for: $0) == key }) {
            let existing = learnedFacts[index]
            learnedFacts[index] = LearnedFact(
                id: existing.id,
                name: fact.name,
                kind: fact.kind,
                evidence: fact.evidence,
                normalizedBounds: nil,
                screenSignature: fact.screenSignature,
                screenSource: fact.screenSource,
                requiredState: fact.requiredState,
                contextAnchors: fact.contextAnchors,
                placement: fact.placement,
                confidence: fact.confidence,
                createdAt: existing.createdAt,
                lastConfirmedAt: .now,
                confirmationCount: existing.confirmationCount + 1
            )
        } else {
            learnedFacts.insert(fact, at: 0)
        }
        learnedFacts = Array(learnedFacts.prefix(2_000))
        try? learningStore?.save(learnedFacts)
    }

    private func factKey(for fact: LearnedFact) -> String {
        "\(fact.screenSource?.rawValue ?? "legacy")|\(fact.requiredState?.rawValue ?? "legacy")|\(fact.kind.rawValue)|\(SemanticTargetResolver.normalized(fact.name))"
    }

    private var missingSourceMessage: String {
        switch captureSource {
        case .automatic:
            "No iPhone Mirroring or booted iOS Simulator window found. Open one, then inspect again."
        case .iPhoneMirroring:
            "No iPhone Mirroring window found. Open it and connect your iPhone first."
        case .simulator:
            "No booted iOS Simulator device window found. Open Simulator and boot a device first."
        }
    }

    /// Local MCP commands may call only the same actions exposed in iosClaw's
    /// UI. They never receive raw screen captures or bypass source checks.
    func executeAgentCommand(_ method: String, parameters: [String: String]) async -> [String: String] {
        if isCompiledFlowRunning && method != "status" && method != "flow_run_status" {
            return ["error": "A compiled flow owns the device lease. Wait for it to finish before issuing another action."]
        }
        switch method {
        case "status":
            return [
                "status": status,
                "screen_recording": String(screenCaptureAllowed),
                "accessibility": String(accessibilityAllowed),
                "active_source": activeSource?.rawValue ?? "none",
                "source_health": sourceHealth.rawValue,
                "screen_signature": currentScreenSignature ?? "none",
                "capture_generation": captureGeneration?.id.uuidString ?? "none",
                "pending_approval": pendingApproval?.actionDescription ?? "none",
                "recording": recordingName ?? "none",
                "replaying_flow_id": replayingFlowID?.uuidString ?? "none",
                "compiled_flow_running": String(isCompiledFlowRunning),
                "latest_compiled_run_id": latestCompiledRun?.id.uuidString ?? "none",
                "latest_compiled_run_outcome": latestCompiledRun?.outcome.rawValue ?? "none"
            ]
        case "simulator_boot":
            bootDefaultSimulator()
            return ["status": status]
        case "simulator_open":
            openSimulator()
            return ["status": status]
        case "simulator_app_list":
            do {
                let applications = try await Task.detached(priority: .userInitiated) {
                    try SimulatorRuntime.installedApplications()
                }.value
                let encoder = JSONEncoder()
                encoder.outputFormatting = [.sortedKeys]
                let data = try encoder.encode(applications)
                return [
                    "applications": String(decoding: data, as: UTF8.self),
                    "count": String(applications.count)
                ]
            } catch {
                return ["error": "Could not list simulator applications: \(error.localizedDescription)"]
            }
        case "simulator_app_launch":
            guard let query = parameters["name"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !query.isEmpty
            else { return ["error": "Simulator app launch requires name."] }
            do {
                let application = try await Task.detached(priority: .userInitiated) {
                    try SimulatorRuntime.launchApplication(matching: query)
                }.value
                // simctl reports process launch before SpringBoard finishes the
                // foreground transition. Let the transition settle so the
                // capture belongs to the requested app instead of the prior UI.
                try? await Task.sleep(nanoseconds: 350_000_000)
                let captured = await inspectForAgentAction()
                return [
                    "status": "Launched \(application.displayName) in iOS Simulator.",
                    "launched": "true",
                    "captured": String(captured),
                    "bundle_id": application.bundleID,
                    "display_name": application.displayName,
                    "application_type": application.applicationType
                ]
            } catch {
                return [
                    "error": "Could not launch simulator application: \(error.localizedDescription)",
                    "launched": "false"
                ]
            }
        case "home":
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in goHome(completion: completion) }
            return ["status": status, "verified": String(verified)]
        case "spotlight":
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in openSpotlight(completion: completion) }
            return ["status": status, "verified": String(verified)]
        case "spotlight_open_top_hit":
            guard let expectedName = parameters["expected_name"], !expectedName.isEmpty else {
                return ["error": "Spotlight top hit requires expected_name."]
            }
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in
                openSpotlightTopHit(expectedName: expectedName, completion: completion)
            }
            return ["status": status, "verified": String(verified)]
        case "inspect":
            let verified = await inspectForAgentAction()
            return ["status": status, "verified": String(verified)]
        case "text_targets":
            var targets: [[String: String]] = []
            for target in textTargets {
                let bounds = target.normalizedBounds
                targets.append([
                    "target_id": target.id.uuidString,
                    "text": target.text,
                    "x": "\(bounds.minX)",
                    "y": "\(bounds.minY)",
                    "width": "\(bounds.width)",
                    "height": "\(bounds.height)"
                ])
            }
            let encoded = (try? JSONSerialization.data(withJSONObject: targets, options: [.sortedKeys])) ?? Data("[]".utf8)
            return ["targets": String(decoding: encoded, as: UTF8.self)]
        case "learned_list":
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let encoded = (try? encoder.encode(learnedFacts)) ?? Data("[]".utf8)
            return ["facts": String(decoding: encoded, as: UTF8.self)]
        case "learned_add":
            guard let name = parameters["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                  let kind = LearnedFact.Kind(rawValue: parameters["kind"] ?? "")
            else { return ["error": "A learned fact requires name and kind."] }
            let confidence = Double(parameters["confidence"] ?? "0.9") ?? 0.9
            let liveTargetID = parameters["target_id"].flatMap(UUID.init(uuidString:))
            remember(
                name: name,
                kind: kind,
                evidence: .visualInference,
                normalizedBounds: nil,
                confidence: confidence,
                liveTargetID: liveTargetID
            )
            return ["status": status]
        case "learned_tap":
            guard let idText = parameters["fact_id"], let id = UUID(uuidString: idText),
                  let fact = learnedFacts.first(where: { $0.id == id })
            else { return ["error": "No learned fact matched fact_id."] }
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in tapLearnedFact(fact, completion: completion) }
            return ["status": status, "verified": String(verified)]
        case "tap_visible_text":
            guard let name = parameters["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                return ["error": "A visible-text tap requires name."]
            }
            let targetID = parameters["target_id"].flatMap(UUID.init(uuidString:))
            let placement = parameters["placement"].flatMap(SemanticPlacement.init(rawValue:))
            if targetID == nil {
                guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            }
            let verified = await awaitAgentAction { completion in
                tapVisibleText(name, targetID: targetID, placement: placement, completion: completion)
            }
            return ["status": status, "verified": String(verified)]
        case "input":
            guard let idText = parameters["control_id"], let id = UUID(uuidString: idText),
                  let fact = learnedFacts.first(where: { $0.id == id }), let text = parameters["text"]
            else { return ["error": "Input requires control_id and text."] }
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in input(text, into: fact, completion: completion) }
            return ["status": status, "verified": String(verified)]
        case "input_visible_text":
            guard let name = parameters["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty,
                  let text = parameters["text"]
            else { return ["error": "Visible-text input requires name and text."] }
            let targetID = parameters["target_id"].flatMap(UUID.init(uuidString:))
            let placement = parameters["placement"].flatMap(SemanticPlacement.init(rawValue:))
            if targetID == nil {
                guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            }
            let verified = await awaitAgentAction { completion in
                inputVisibleText(text, into: name, targetID: targetID, placement: placement, completion: completion)
            }
            return ["status": status, "verified": String(verified)]
        case "whatsapp_open_chat":
            guard let contact = parameters["contact_name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !contact.isEmpty else {
                return ["error": "WhatsApp chat search requires contact_name."]
            }
            guard await inspectForAgentAction() else { return ["status": status, "verified": "false"] }
            let verified = await awaitAgentAction { completion in
                openWhatsAppChatViaKeyboard(contact, completion: completion)
            }
            return ["status": status, "verified": String(verified)]
        case "compiled_flow_list":
            let metadata = compiledFlowCatalog.map { flow in
                [
                    "flow_id": flow.id,
                    "version": String(flow.version),
                    "status": flow.status.rawValue,
                    "intent": flow.intentID,
                    "name": flow.displayName,
                    "sources": flow.supportedSources.map(\.rawValue).joined(separator: ","),
                    "required_inputs": flow.inputSpecs.filter(\.value.required).keys.sorted().joined(separator: ","),
                    "step_count": String(flow.steps.count),
                    "provenance": flow.provenance
                ]
            }
            return ["flows": encodeAgentJSON(metadata)]
        case "flow_resolve":
            guard let intent = parameters["intent"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !intent.isEmpty
            else { return ["error": "Compiled-flow resolution requires intent."] }
            let source = parameters["source"].flatMap(ScreenSource.init(rawValue:))
                ?? activeSource
                ?? .iPhoneMirroring
            guard source != .automatic else {
                return ["error": "Resolve a concrete iPhone Mirroring or Simulator source."]
            }
            do {
                let inputs = compiledFlowInputs(from: parameters)
                let flow = try currentCompiledFlowRegistry().resolve(intentID: intent, inputs: inputs, source: source)
                return ["flow": encodeAgentJSON(compiledFlowMetadata(flow))]
            } catch {
                return ["error": error.localizedDescription]
            }
        case "flow_run":
            guard let intent = parameters["intent"]?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !intent.isEmpty
            else { return ["error": "Compiled-flow execution requires intent."] }
            do {
                let run = try await runCompiledFlow(
                    intentID: intent,
                    inputs: compiledFlowInputs(from: parameters)
                )
                return [
                    "run": encodeAgentJSON(run),
                    "run_id": run.id.uuidString,
                    "outcome": run.outcome.rawValue,
                    "duration_ms": String(run.durationMilliseconds),
                    "status": status
                ]
            } catch {
                return ["error": error.localizedDescription]
            }
        case "flow_run_status":
            guard let run = latestCompiledRun else {
                return ["error": "No compiled flow has run in this app session."]
            }
            if let requested = parameters["run_id"], requested != run.id.uuidString {
                return ["error": "The requested compiled run is not available in this app session."]
            }
            return [
                "run": encodeAgentJSON(run),
                "run_id": run.id.uuidString,
                "outcome": run.outcome.rawValue,
                "duration_ms": String(run.durationMilliseconds)
            ]
        case "flow_compile_recorded":
            let requestedID = parameters["flow_id"].flatMap(UUID.init(uuidString:))
            let requestedName = parameters["name"].map(SemanticTargetResolver.normalized)
            let matches = recordedFlows.filter { flow in
                (requestedID != nil && flow.id == requestedID)
                    || (requestedName != nil && SemanticTargetResolver.normalized(flow.name) == requestedName)
            }
            guard matches.count == 1, let recorded = matches.first else {
                return ["error": "Exactly one recorded flow must match flow_id or name."]
            }
            do {
                let compiled = try compileAndPersist(SemanticTrace(recordedFlow: recorded))
                return [
                    "flow": encodeAgentJSON(compiledFlowMetadata(compiled)),
                    "persisted": "true"
                ]
            } catch {
                return ["error": error.localizedDescription]
            }
        case "flow_compile_trace":
            do {
                let trace = try decodeSubmittedTrace(parameters["trace_json"])
                let compiled = try compileAndPersist(trace)
                return [
                    "flow": encodeAgentJSON(compiledFlowMetadata(compiled)),
                    "trace_id": trace.id.uuidString,
                    "persisted": "true"
                ]
            } catch {
                return ["error": error.localizedDescription]
            }
        case "flow_validate_trace":
            do {
                let trace = try decodeSubmittedTrace(parameters["trace_json"])
                let issues = SemanticTraceValidator.validate(trace)
                guard issues.isEmpty else {
                    return [
                        "trace_id": trace.id.uuidString,
                        "validation_issues": encodeAgentJSON(issues.map(\.description)),
                        "ready_to_compile": "false"
                    ]
                }
                let compiled = try SemanticTraceCompiler.compile(trace)
                return [
                    "trace_id": trace.id.uuidString,
                    "validation_issues": "[]",
                    "ready_to_compile": "true",
                    "flow_preview": encodeAgentJSON(compiledFlowMetadata(compiled))
                ]
            } catch {
                return ["error": error.localizedDescription]
            }
        case "flow_trace_recorded":
            let requestedID = parameters["flow_id"].flatMap(UUID.init(uuidString:))
            let requestedName = parameters["name"].map(SemanticTargetResolver.normalized)
            let matches = recordedFlows.filter { flow in
                (requestedID != nil && flow.id == requestedID)
                    || (requestedName != nil && SemanticTargetResolver.normalized(flow.name) == requestedName)
            }
            guard matches.count == 1, let recorded = matches.first else {
                return ["error": "Exactly one recorded flow must match flow_id or name."]
            }
            let trace = SemanticTrace(recordedFlow: recorded)
            let issues = SemanticTraceValidator.validate(trace)
            return [
                "trace": encodeAgentJSON(trace),
                "trace_id": trace.id.uuidString,
                "schema_version": String(trace.schemaVersion),
                "validation_issues": encodeAgentJSON(issues.map(\.description)),
                "ready_to_compile": String(issues.isEmpty)
            ]
        case "flow_list":
            let metadata = recordedFlows.map { flow in
                [
                    "id": flow.id.uuidString,
                    "name": flow.name,
                    "source": flow.source.rawValue,
                    "step_count": String(flow.steps.count),
                    "steps": flow.steps.map(\.summary).joined(separator: " | ")
                ]
            }
            let encoded = (try? JSONSerialization.data(withJSONObject: metadata, options: [.sortedKeys])) ?? Data("[]".utf8)
            return ["flows": String(decoding: encoded, as: UTF8.self)]
        case "flow_record_start":
            guard let name = parameters["name"] else {
                return ["error": "A recording name is required."]
            }
            startRecording(name: name)
            return ["status": status]
        case "flow_record_stop":
            stopRecording()
            return ["status": status]
        case "flow_record_cancel":
            cancelRecording()
            return ["status": status]
        case "flow_replay":
            guard parameters["confirmed"]?.lowercased() == "true" else {
                return [
                    "error": "Replay requires confirmed=true only after the user explicitly asks iosClaw to run this flow."
                ]
            }
            let requestedID = parameters["flow_id"].flatMap(UUID.init(uuidString:))
            let requestedName = parameters["name"].map(SemanticTargetResolver.normalized)
            let matches = recordedFlows.filter { flow in
                (requestedID != nil && flow.id == requestedID)
                    || (requestedName != nil && SemanticTargetResolver.normalized(flow.name) == requestedName)
            }
            guard matches.count == 1, let flow = matches.first else {
                return ["error": "Exactly one recorded flow must match flow_id or name."]
            }
            replay(flow)
            return ["status": status, "flow_id": flow.id.uuidString]
        case "flow_replay_cancel":
            cancelReplay()
            return ["status": status]
        default:
            return ["error": "Unsupported iosClaw agent command: \(method)"]
        }
    }

    private func inspectForAgentAction() async -> Bool {
        await withCheckedContinuation { continuation in
            inspect { success in continuation.resume(returning: success) }
        }
    }

    private func awaitAgentAction(
        _ action: (@escaping (Bool) -> Void) -> Void
    ) async -> Bool {
        await withCheckedContinuation { continuation in
            action { success in continuation.resume(returning: success) }
        }
    }

    private func runCompiledFlow(
        intentID: String,
        inputs: [String: String]
    ) async throws -> CompiledFlowRun {
        guard !isCompiledFlowRunning else { throw CompiledFlowSessionError.anotherRunActive }
        guard !isRecording, replayContext == nil else {
            throw CompiledFlowSessionError.recordingOrReplayActive
        }

        isCompiledFlowRunning = true
        defer { isCompiledFlowRunning = false }
        guard let observation = await compiledObserve() else {
            throw CompiledFlowSessionError.observationUnavailable
        }
        let flow = try currentCompiledFlowRegistry().resolve(
            intentID: intentID,
            inputs: inputs,
            source: observation.source
        )

        status = "Running compiled flow ‘\(flow.displayName)’ locally…"
        append(kind: .observation, "Started compiled flow \(flow.id) version \(flow.version).")
        let run = await CompiledFlowExecutor(driver: self).run(
            flow: flow,
            inputs: inputs,
            initialObservation: observation
        )
        latestCompiledRun = run
        switch run.outcome {
        case .succeeded:
            status = "Compiled flow complete: ‘\(flow.displayName)’ in \(run.durationMilliseconds) ms."
            append(kind: .observation, "Completed compiled flow \(flow.id) version \(flow.version) in \(run.durationMilliseconds) ms.")
        case .failed, .cancelled:
            status = "Compiled flow stopped: \(run.failureReason ?? run.outcome.rawValue)."
            append(kind: .safety, "Compiled flow \(flow.id) stopped: \(run.failureReason ?? run.outcome.rawValue).")
        }
        return run
    }

    private func compiledFlowInputs(from parameters: [String: String]) -> [String: String] {
        let reserved = Set(["intent", "source", "run_id", "flow_id", "name", "trace_json"])
        return parameters.filter { !reserved.contains($0.key) }
    }

    private func currentCompiledFlowRegistry() throws -> CompiledFlowRegistry {
        try CompiledFlowRegistry(packages: compiledFlowCatalog)
    }

    private func decodeSubmittedTrace(_ encodedTrace: String?) throws -> SemanticTrace {
        guard let encodedTrace, encodedTrace.utf8.count <= 48_000 else {
            throw SemanticTraceSubmissionError.missingOrTooLarge
        }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(SemanticTrace.self, from: Data(encodedTrace.utf8))
        } catch {
            throw SemanticTraceSubmissionError.malformed(error.localizedDescription)
        }
    }

    private func compileAndPersist(_ trace: SemanticTrace) throws -> CompiledFlowPackage {
        let compiled = try SemanticTraceCompiler.compile(trace)
        guard let compiledFlowStore else {
            throw CompiledFlowPersistenceError.unavailable
        }
        let updated = CompiledFlowCatalog.upserting(compiled, into: userCompiledDrafts)
        try compiledFlowStore.save(updated)
        userCompiledDrafts = updated
        let saved = updated.first(where: { $0.id == compiled.id }) ?? compiled
        append(kind: .observation, "Saved compiled draft \(saved.id) version \(saved.version).")
        return saved
    }

    private func compiledFlowMetadata(_ flow: CompiledFlowPackage) -> [String: String] {
        [
            "flow_id": flow.id,
            "version": String(flow.version),
            "status": flow.status.rawValue,
            "intent": flow.intentID,
            "name": flow.displayName,
            "sources": flow.supportedSources.map(\.rawValue).joined(separator: ","),
            "required_inputs": flow.inputSpecs.filter(\.value.required).keys.sorted().joined(separator: ","),
            "step_count": String(flow.steps.count),
            "provenance": flow.provenance
        ]
    }

    private func encodeAgentJSON<T: Encodable>(_ value: T) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else { return "{}" }
        return String(decoding: data, as: UTF8.self)
    }

}

private enum CompiledFlowPersistenceError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable: "iosClaw could not initialize encrypted storage for compiled drafts."
        }
    }
}

private enum SemanticTraceSubmissionError: LocalizedError {
    case missingOrTooLarge
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case .missingOrTooLarge:
            "Trace validation requires a value-free trace_json no larger than 48 KiB."
        case .malformed(let detail):
            "Trace JSON must be a valid schema-v1 SemanticTrace: \(detail)"
        }
    }
}

extension MirrorSession: CompiledFlowDriving {
    func compiledObserve() async -> CompiledFlowObservation? {
        guard await inspectForAgentAction() else { return nil }
        return compiledCurrentObservation()
    }

    func compiledCurrentObservation() -> CompiledFlowObservation? {
        guard sourceHealth.allowsInput,
              let source = activeSource,
              let generation = captureGeneration
        else { return nil }
        return CompiledFlowObservation(
            source: source,
            state: currentSemanticState,
            visibleTexts: textTargets.map(\.text),
            generationID: generation.id
        )
    }

    func compiledPerform(
        primitive: CompiledFlowPrimitive,
        arguments: [String: String],
        timeoutMilliseconds: Int
    ) async -> Bool {
        // The Phase 1 lowering format carries a bounded timeout even though the
        // current ScreenCaptureKit action path owns its condition wait. Keeping
        // the value at this boundary prevents the ABI from changing when the
        // persistent capture worker takes over timeout enforcement.
        _ = timeoutMilliseconds
        switch primitive {
        case .home:
            return await awaitAgentAction { completion in goHome(completion: completion) }
        case .launchAppViaSpotlight:
            guard let app = arguments["app"], !app.isEmpty else { return false }
            return await launchAppViaSpotlight(app)
        case .ensureChatList:
            if currentSemanticState == .chatList { return true }
            guard SemanticTargetResolver.resolveVisibleText(
                "Chats",
                targets: textTargets,
                currentState: currentSemanticState
            ) != nil else { return false }
            return await awaitAgentAction { completion in
                tapVisibleText("Chats", completion: completion)
            }
        case .keyboardFindAndActivate:
            guard let query = arguments["query"],
                  let confirmation = arguments["confirmation"],
                  !query.isEmpty,
                  !confirmation.isEmpty
            else { return false }
            return await awaitAgentAction { completion in
                findAndActivateViaKeyboard(
                    query,
                    confirmationTexts: [confirmation],
                    successSummary: "Opened the verified requested collection item.",
                    completion: completion
                )
            }
        case .replaceVisibleText:
            guard let target = arguments["target"],
                  let value = arguments["value"],
                  !target.isEmpty,
                  !value.isEmpty
            else { return false }
            return await awaitAgentAction { completion in
                inputVisibleText(value, into: target, completion: completion)
            }
        case .tapVisibleText:
            guard let target = arguments["target"], !target.isEmpty else { return false }
            return await awaitAgentAction { completion in
                tapVisibleText(target, completion: completion)
            }
        }
    }

    private func launchAppViaSpotlight(_ appName: String) async -> Bool {
        if SemanticTargetResolver.appIsVisible(
            named: appName,
            state: currentSemanticState,
            targets: textTargets
        ) {
            return true
        }
        guard await awaitAgentAction({ completion in goHome(completion: completion) }) else { return false }
        guard await awaitAgentAction({ completion in openSpotlight(completion: completion) }) else { return false }
        guard await waitForCompiledObservation(timeoutMilliseconds: 2_000, predicate: { targets in
            SemanticTargetResolver.resolveSpotlightSearchControl(
                currentQuery: appName,
                targets: targets,
                currentState: self.currentSemanticState
            ) != nil
        }),
              let mirrorWindow,
              mirrorWindow.source == .iPhoneMirroring,
              let searchControl = SemanticTargetResolver.resolveSpotlightSearchControl(
                currentQuery: appName,
                targets: textTargets,
                currentState: currentSemanticState
              )
        else { return false }
        var activeSearchControl = searchControl
        if SemanticTargetResolver.normalized(searchControl.textTarget.text)
            == SemanticTargetResolver.normalized(appName)
        {
            let probe = String(appName.dropLast())
            guard !probe.isEmpty,
                  await awaitAgentAction({ completion in
                    inputVisibleText(
                        probe,
                        into: searchControl.textTarget.text,
                        targetID: searchControl.textTarget.id,
                        completion: completion
                    )
                  }),
                  await waitForCompiledObservation(timeoutMilliseconds: 2_000, predicate: { targets in
                    SemanticTargetResolver.resolveSpotlightSearchControl(
                        currentQuery: probe,
                        targets: targets,
                        currentState: self.currentSemanticState
                    ) != nil
                  }),
                  let probedControl = SemanticTargetResolver.resolveSpotlightSearchControl(
                    currentQuery: probe,
                    targets: textTargets,
                    currentState: currentSemanticState
                  )
            else { return false }
            activeSearchControl = probedControl
        }
        guard await awaitAgentAction({ completion in
            inputVisibleText(
                appName,
                into: activeSearchControl.textTarget.text,
                targetID: activeSearchControl.textTarget.id,
                completion: completion
            )
        }) else { return false }
        guard await waitForCompiledObservation(timeoutMilliseconds: 3_000, predicate: { targets in
            let hasTopHit = targets.contains {
                SemanticTargetResolver.normalized($0.text) == "top hit"
            }
            let hasApps = targets.contains {
                SemanticTargetResolver.normalized($0.text) == "apps"
            }
            let hasExpectedResult = targets.contains {
                SemanticTargetResolver.spotlightResultMatches(
                    expectedName: appName,
                    recognizedText: $0.text
                )
            }
            return (hasTopHit || hasApps) && hasExpectedResult
        }) else { return false }
        return await awaitAgentAction { completion in
            openSpotlightTopHit(expectedName: appName, completion: completion)
        }
    }

    private func waitForCompiledObservation(
        timeoutMilliseconds: Int,
        predicate: ([TextTarget]) -> Bool
    ) async -> Bool {
        let deadline = DispatchTime.now().uptimeNanoseconds
            + UInt64(timeoutMilliseconds) * 1_000_000
        while DispatchTime.now().uptimeNanoseconds < deadline {
            if predicate(textTargets) { return true }
            try? await Task.sleep(nanoseconds: 150_000_000)
            _ = await inspectForAgentAction()
        }
        return predicate(textTargets)
    }
}

private final class AgentBridge {
    private static let protocolVersion = 2
    private static let maximumRequestBytes = 65_536
    private let session: MirrorSession
    private let queue = DispatchQueue(label: "com.iosclaw.mac.agent-bridge")
    private let token = "\(UUID().uuidString)\(UUID().uuidString)"
    private let listener: NWListener
    private let configurationURL: URL
    private var recentRequestIDs: [String] = []
    private var recentRequestIDSet: Set<String> = []

    init(session: MirrorSession) throws {
        self.session = session
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("iosClaw", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: support.path)
        configurationURL = support.appendingPathComponent("agent-bridge.json")
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
        listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
        listener.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            switch state {
            case .ready:
                guard let port = self.listener.port else { return }
                self.writeConfiguration(port: port)
            case .failed(let error):
                NSLog("iosClaw agent bridge listener failed: %@", error.localizedDescription)
            default:
                break
            }
        }
        listener.start(queue: queue)
    }

    private func writeConfiguration(port: NWEndpoint.Port) {
        let configuration = [
            "host": "127.0.0.1",
            "port": "\(port)",
            "token": token,
            "protocolVersion": "\(Self.protocolVersion)"
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: configuration, options: [.sortedKeys]) else { return }
        try? data.write(to: configurationURL, options: .atomic)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: configurationURL.path)
    }

    private func accept(_ connection: NWConnection) {
        connection.start(queue: queue)
        receiveRequest(over: connection, accumulated: Data())
    }

    private func receiveRequest(over connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, isComplete, error in
            guard let self, error == nil else { connection.cancel(); return }
            var requestData = accumulated
            if let data { requestData.append(data) }
            guard requestData.count <= Self.maximumRequestBytes else {
                self.reply(Response(id: "", ok: false, result: nil, error: "iosClaw bridge request exceeded 64 KiB."), over: connection)
                return
            }
            guard isComplete else {
                self.receiveRequest(over: connection, accumulated: requestData)
                return
            }
            guard let request = try? JSONDecoder().decode(Request.self, from: requestData),
                  request.protocolVersion == Self.protocolVersion,
                  request.token == self.token
            else {
                self.reply(Response(id: "", ok: false, result: nil, error: "Unauthorized iosClaw bridge request."), over: connection)
                return
            }
            guard self.register(requestID: request.id) else {
                self.reply(Response(id: request.id, ok: false, result: nil, error: "Duplicate iosClaw bridge request id."), over: connection)
                return
            }
            Task { @MainActor [weak self] in
                guard let self else { return }
                let result = await self.session.executeAgentCommand(request.method, parameters: request.parameters ?? [:])
                if let error = result["error"] {
                    self.reply(Response(id: request.id, ok: false, result: nil, error: error), over: connection)
                } else {
                    self.reply(Response(id: request.id, ok: true, result: result, error: nil), over: connection)
                }
            }
        }
    }

    private func register(requestID: String) -> Bool {
        guard !requestID.isEmpty, !recentRequestIDSet.contains(requestID) else { return false }
        recentRequestIDs.append(requestID)
        recentRequestIDSet.insert(requestID)
        if recentRequestIDs.count > 256 {
            let expired = recentRequestIDs.removeFirst()
            recentRequestIDSet.remove(expired)
        }
        return true
    }

    private func reply(_ response: Response, over connection: NWConnection) {
        guard let data = try? JSONEncoder().encode(response) else { connection.cancel(); return }
        connection.send(content: data, completion: .contentProcessed { _ in connection.cancel() })
    }

    private struct Request: Decodable {
        let protocolVersion: Int
        let token: String
        let id: String
        let method: String
        let parameters: [String: String]?
    }

    private struct Response: Encodable {
        let id: String
        let ok: Bool
        let result: [String: String]?
        let error: String?
    }
}

struct SimulatorApplication: Codable, Equatable {
    let bundleID: String
    let displayName: String
    let applicationType: String
}

enum SimulatorApplicationCatalog {
    static func parse(_ data: Data) throws -> [SimulatorApplication] {
        guard let payload = try PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
        ) as? [String: Any]
        else { throw SimulatorRuntime.SimulatorRuntimeError.invalidApplicationList }

        return payload.compactMap { bundleID, value in
            guard let attributes = value as? [String: Any] else { return nil }
            let resolvedBundleID = attributes["CFBundleIdentifier"] as? String ?? bundleID
            guard !resolvedBundleID.isEmpty else { return nil }
            let displayName = attributes["CFBundleDisplayName"] as? String
                ?? attributes["CFBundleName"] as? String
                ?? resolvedBundleID
            let applicationType = attributes["ApplicationType"] as? String ?? "Unknown"
            return SimulatorApplication(
                bundleID: resolvedBundleID,
                displayName: displayName,
                applicationType: applicationType
            )
        }.sorted {
            let nameOrder = $0.displayName.localizedStandardCompare($1.displayName)
            return nameOrder == .orderedSame
                ? $0.bundleID.localizedStandardCompare($1.bundleID) == .orderedAscending
                : nameOrder == .orderedAscending
        }
    }

    static func resolve(
        _ query: String,
        in applications: [SimulatorApplication]
    ) throws -> SimulatorApplication {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let matches = applications.filter {
            $0.displayName.caseInsensitiveCompare(normalizedQuery) == .orderedSame
                || $0.bundleID.caseInsensitiveCompare(normalizedQuery) == .orderedSame
        }
        guard !matches.isEmpty else {
            throw SimulatorRuntime.SimulatorRuntimeError.applicationNotFound(normalizedQuery)
        }
        guard matches.count == 1, let application = matches.first else {
            throw SimulatorRuntime.SimulatorRuntimeError.ambiguousApplication(
                normalizedQuery,
                matches.map(\.bundleID).sorted()
            )
        }
        return application
    }
}

enum SimulatorRuntime {
    private struct DeviceList: Decodable {
        let devices: [String: [Device]]
    }

    private struct Device: Decodable {
        let udid: String
        let name: String
        let state: String
        let isAvailable: Bool?
    }

    static func bootDefaultDevice() throws -> String {
        let data = try run(["simctl", "list", "devices", "available", "--json"])
        let payload = try JSONDecoder().decode(DeviceList.self, from: data)
        let devices = payload.devices.values.flatMap { $0 }.filter { $0.isAvailable != false }
        guard let device = preferredDevice(in: devices) else {
            throw SimulatorRuntimeError.noAvailableDevice
        }

        if device.state.caseInsensitiveCompare("Booted") != .orderedSame {
            _ = try run(["simctl", "boot", device.udid])
            _ = try run(["simctl", "bootstatus", device.udid, "-b"])
        }
        return device.name
    }

    static func installedApplications() throws -> [SimulatorApplication] {
        try SimulatorApplicationCatalog.parse(run(["simctl", "listapps", "booted"]))
    }

    static func launchApplication(matching query: String) throws -> SimulatorApplication {
        let application = try SimulatorApplicationCatalog.resolve(
            query,
            in: installedApplications()
        )
        _ = try run(["simctl", "launch", "booted", application.bundleID])
        return application
    }

    private static func preferredDevice(in devices: [Device]) -> Device? {
        let sorted = devices.sorted { lhs, rhs in lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending }
        return sorted.first { $0.state.caseInsensitiveCompare("Booted") == .orderedSame }
            ?? sorted.first { $0.name.localizedCaseInsensitiveContains("iPhone Air") }
            ?? sorted.first
    }

    @discardableResult
    private static func run(_ arguments: [String]) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/xcrun")
        process.arguments = arguments
        let output = Pipe()
        let errors = Pipe()
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let errorData = errors.fileHandleForReading.readDataToEndOfFile()
            throw SimulatorRuntimeError.commandFailed(String(decoding: errorData, as: UTF8.self))
        }
        return data
    }

    enum SimulatorRuntimeError: LocalizedError {
        case noAvailableDevice
        case invalidApplicationList
        case applicationNotFound(String)
        case ambiguousApplication(String, [String])
        case commandFailed(String)

        var errorDescription: String? {
            switch self {
            case .noAvailableDevice: "No available iOS Simulator device was found."
            case .invalidApplicationList: "The simulator returned an invalid application list."
            case .applicationNotFound(let name): "No installed simulator application exactly matched ‘\(name)’."
            case .ambiguousApplication(let name, let bundleIDs):
                "More than one simulator application matched ‘\(name)’: \(bundleIDs.joined(separator: ", ")). Use a bundle identifier."
            case .commandFailed(let message): message.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }
}
