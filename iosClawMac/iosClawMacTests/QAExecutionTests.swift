import Foundation
import AppKit
import CoreGraphics
import CryptoKit
import XCTest
@testable import iosClawMac

final class QAExecutionTests: XCTestCase {
    func testSemanticIconVocabularyUsesAvailableSymbolsAndDistinctNavigationIcons() {
        for symbol in Set(AppIcon.allSymbols) {
            XCTAssertNotNil(
                NSImage(systemSymbolName: symbol, accessibilityDescription: nil),
                "Missing SF Symbol: \(symbol)"
            )
        }

        let navigationSymbols = WorkspaceDestination.allCases.map(\.symbol)
        XCTAssertEqual(Set(navigationSymbols).count, navigationSymbols.count)
    }

    func testSimulatorApplicationCatalogParsesAndSortsApplications() throws {
        let plist: [String: Any] = [
            "com.example.zency": [
                "CFBundleIdentifier": "com.example.zency",
                "CFBundleDisplayName": "Zency",
                "ApplicationType": "User"
            ],
            "com.apple.MobileAddressBook": [
                "CFBundleName": "Contacts",
                "ApplicationType": "System"
            ]
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )

        XCTAssertEqual(
            try SimulatorApplicationCatalog.parse(data),
            [
                SimulatorApplication(
                    bundleID: "com.apple.MobileAddressBook",
                    displayName: "Contacts",
                    applicationType: "System"
                ),
                SimulatorApplication(
                    bundleID: "com.example.zency",
                    displayName: "Zency",
                    applicationType: "User"
                )
            ]
        )
    }

    func testSimulatorApplicationCatalogResolvesExactNameOrBundleID() throws {
        let applications = [
            SimulatorApplication(bundleID: "com.example.zency", displayName: "Zency", applicationType: "User")
        ]

        XCTAssertEqual(try SimulatorApplicationCatalog.resolve("zency", in: applications), applications[0])
        XCTAssertEqual(try SimulatorApplicationCatalog.resolve("COM.EXAMPLE.ZENCY", in: applications), applications[0])
        XCTAssertThrowsError(try SimulatorApplicationCatalog.resolve("Zen", in: applications))
    }

    func testSimulatorApplicationCatalogFailsClosedOnAmbiguousName() {
        let applications = [
            SimulatorApplication(bundleID: "com.example.one", displayName: "Demo", applicationType: "User"),
            SimulatorApplication(bundleID: "com.example.two", displayName: "Demo", applicationType: "User")
        ]

        XCTAssertThrowsError(try SimulatorApplicationCatalog.resolve("Demo", in: applications))
    }

    func testCaptureGenerationRejectsExpiredOrMovedWindowEvidence() {
        let capturedAt = Date(timeIntervalSince1970: 100)
        let window = MirrorWindow(
            id: 9,
            ownerPID: 10,
            ownerName: "iPhone Mirroring",
            title: "iPhone Mirroring",
            bounds: CGRect(x: 0, y: 71, width: 318, height: 701),
            source: .iPhoneMirroring
        )
        let generation = CaptureGeneration(
            capturedAt: capturedAt,
            windowID: window.id,
            windowBounds: window.bounds,
            source: window.source,
            screenSignature: "home"
        )

        XCTAssertTrue(generation.authorizes(window: window, now: capturedAt.addingTimeInterval(14.9)))
        XCTAssertFalse(generation.authorizes(window: window, now: capturedAt.addingTimeInterval(15.1)))

        let movedWindow = MirrorWindow(
            id: window.id,
            ownerPID: window.ownerPID,
            ownerName: window.ownerName,
            title: window.title,
            bounds: window.bounds.offsetBy(dx: 40, dy: 0),
            source: window.source
        )
        XCTAssertFalse(generation.authorizes(window: movedWindow, now: capturedAt.addingTimeInterval(1)))
    }

    func testActionPostconditionRequiresANewGenerationFromTheSameWindow() {
        let before = CaptureGeneration(
            id: UUID(),
            capturedAt: .now,
            windowID: 7,
            windowBounds: CGRect(x: 0, y: 0, width: 300, height: 700),
            source: .iPhoneMirroring,
            screenSignature: "before"
        )
        let after = CaptureGeneration(
            id: UUID(),
            capturedAt: .now,
            windowID: 7,
            windowBounds: CGRect(x: 0, y: 0, width: 300, height: 700),
            source: .iPhoneMirroring,
            screenSignature: "after"
        )

        XCTAssertTrue(ActionPostcondition.freshObservation.isSatisfied(before: before, after: after))
        XCTAssertTrue(ActionPostcondition.screenChanged.isSatisfied(before: before, after: after))
        XCTAssertFalse(ActionPostcondition.freshObservation.isSatisfied(before: before, after: before))

        let unchanged = CaptureGeneration(
            id: UUID(),
            capturedAt: .now,
            windowID: 7,
            windowBounds: before.windowBounds,
            source: .iPhoneMirroring,
            screenSignature: "before"
        )
        XCTAssertFalse(ActionPostcondition.screenChanged.isSatisfied(before: before, after: unchanged))
        XCTAssertTrue(ActionPostcondition.textPresent("wa business").isSatisfied(
            before: before,
            after: after,
            afterTargets: [TextTarget(text: "Search wa business", normalizedBounds: .zero)]
        ))
        XCTAssertFalse(ActionPostcondition.textPresent("wa business").isSatisfied(
            before: before,
            after: after,
            afterTargets: [TextTarget(text: "Search", normalizedBounds: .zero)]
        ))
    }

    func testTextInputPostconditionRequiresExpectedPlacement() {
        let before = captureGeneration(signature: "before")
        let after = captureGeneration(signature: "after")
        let topSuggestion = TextTarget(
            text: "WA Business",
            normalizedBounds: CGRect(x: 0.1, y: 0.7, width: 0.3, height: 0.05)
        )
        let bottomQuery = TextTarget(
            text: "WA Business",
            normalizedBounds: CGRect(x: 0.1, y: 0.05, width: 0.3, height: 0.05)
        )

        XCTAssertFalse(ActionPostcondition.textPresentAtPlacement(
            "WA Business",
            .bottom
        ).isSatisfied(before: before, after: after, afterTargets: [topSuggestion]))
        XCTAssertTrue(ActionPostcondition.textPresentAtPlacement(
            "WA Business",
            .bottom
        ).isSatisfied(before: before, after: after, afterTargets: [topSuggestion, bottomQuery]))
    }

    func testTextAbsentPostconditionRejectsCosmeticOCRChanges() {
        let before = CaptureGeneration(
            capturedAt: .now,
            windowID: 7,
            windowBounds: CGRect(x: 0, y: 0, width: 300, height: 700),
            source: .iPhoneMirroring,
            screenSignature: "spotlight-a"
        )
        let after = CaptureGeneration(
            capturedAt: .now,
            windowID: 7,
            windowBounds: before.windowBounds,
            source: .iPhoneMirroring,
            screenSignature: "spotlight-b"
        )

        XCTAssertFalse(ActionPostcondition.textAbsent("Top Hit").isSatisfied(
            before: before,
            after: after,
            afterTargets: [TextTarget(text: "Top Hit", normalizedBounds: .zero)]
        ))
        XCTAssertTrue(ActionPostcondition.textAbsent("Top Hit").isSatisfied(
            before: before,
            after: after,
            afterTargets: [TextTarget(text: "Chats", normalizedBounds: .zero)]
        ))
    }

    func testExactTextPostconditionRequiresEveryConversationLandmark() {
        let before = CaptureGeneration(
            capturedAt: .now,
            windowID: 7,
            windowBounds: CGRect(x: 0, y: 0, width: 300, height: 700),
            source: .iPhoneMirroring,
            screenSignature: "chats"
        )
        let after = CaptureGeneration(
            capturedAt: .now,
            windowID: 7,
            windowBounds: before.windowBounds,
            source: .iPhoneMirroring,
            screenSignature: "conversation"
        )

        XCTAssertTrue(ActionPostcondition.exactTextsPresent(["Honey", "Message"]).isSatisfied(
            before: before,
            after: after,
            afterTargets: [
                TextTarget(text: "Honey", normalizedBounds: .zero),
                TextTarget(text: "Message", normalizedBounds: .zero)
            ]
        ))
        XCTAssertFalse(ActionPostcondition.exactTextsPresent(["Honey", "Message"]).isSatisfied(
            before: before,
            after: after,
            afterTargets: [TextTarget(text: "Message multiple contacts", normalizedBounds: .zero)]
        ))
    }

    func testActionPolicyRequiresApprovalForExternalEffectsAndBlocksSecrets() {
        XCTAssertEqual(
            ActionPolicy.evaluate(kind: .tap, targetName: "Send"),
            .requireApproval(.externalCommunication)
        )
        XCTAssertEqual(
            ActionPolicy.evaluate(kind: .tap, targetName: "Delete chat"),
            .requireApproval(.destructive)
        )
        XCTAssertEqual(
            ActionPolicy.evaluate(kind: .input, targetName: "One-time verification code"),
            .block("iosClaw does not enter credentials, one-time codes, passcodes, or payment-card secrets.")
        )
        XCTAssertEqual(ActionPolicy.evaluate(kind: .tap, targetName: "Honey"), .allow)
        XCTAssertEqual(ActionPolicy.evaluate(kind: .input, targetName: "Message"), .allow)
    }

    func testOneTimeApprovalIsBoundToFingerprintAndExpiry() {
        let now = Date(timeIntervalSince1970: 100)
        let approval = OneTimeActionApproval(fingerprint: "tap|send", expiresAt: now.addingTimeInterval(30))

        XCTAssertTrue(approval.authorizes("tap|send", now: now.addingTimeInterval(29)))
        XCTAssertFalse(approval.authorizes("tap|delete", now: now.addingTimeInterval(1)))
        XCTAssertFalse(approval.authorizes("tap|send", now: now.addingTimeInterval(31)))
    }

    func testMirroringInterruptionScreensAreNotActionable() {
        XCTAssertEqual(
            SourceInterruptionDetector.reason(in: [
                TextTarget(text: "Connection Interrupted", normalizedBounds: .zero),
                TextTarget(text: "Try Again", normalizedBounds: .zero)
            ]),
            "iPhone Mirroring reported that its connection was interrupted."
        )
        XCTAssertEqual(
            SourceInterruptionDetector.reason(in: [
                TextTarget(text: "iPhone Microphone in Use", normalizedBounds: .zero)
            ]),
            "iPhone Mirroring is paused because the iPhone is currently in use."
        )
        XCTAssertNil(SourceInterruptionDetector.reason(in: [
            TextTarget(text: "Chats", normalizedBounds: .zero),
            TextTarget(text: "Search", normalizedBounds: .zero)
        ]))
        XCTAssertFalse(SourceHealth.interrupted.allowsInput)
        XCTAssertTrue(SourceHealth.ready.allowsInput)
    }

    func testCoordinateMapperUsesQuartzGlobalTopLeftCoordinates() {
        let point = MirrorCoordinateMapper.screenPoint(
            for: NormalizedBounds(CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)),
            in: CGRect(x: 0, y: 71, width: 318, height: 701)
        )

        XCTAssertEqual(point.x, 159, accuracy: 0.001)
        XCTAssertEqual(point.y, 421.5, accuracy: 0.001)
    }

    func testCoordinateMapperPreservesOffsetSecondaryDisplayCoordinates() {
        let point = MirrorCoordinateMapper.screenPoint(
            for: NormalizedBounds(CGRect(x: 0, y: 0, width: 0.2, height: 0.2)),
            in: CGRect(x: 1600, y: 200, width: 400, height: 800)
        )

        XCTAssertEqual(point.x, 1640, accuracy: 0.001)
        XCTAssertEqual(point.y, 920, accuracy: 0.001)
    }

    func testWindowMatcherPrefersTheNamedPhoneShapedMirroringWindow() {
        let staleSurface = windowInfo(id: 1, owner: "iPhone Mirroring", title: "iPhone Mirroring", width: 640, height: 640)
        let deviceWindow = windowInfo(id: 2, owner: "iPhone Mirroring", title: "iPhone Mirroring", width: 390, height: 844)

        XCTAssertEqual(
            MirrorWindowMatcher.match(in: [staleSurface, deviceWindow], source: .iPhoneMirroring)?.id,
            2
        )
    }

    func testDisplayCropRequiresSourceProcessToBeTopmostAtWindowCenter() {
        let source = MirrorWindow(
            id: 7,
            ownerPID: 70,
            ownerName: "iPhone Mirroring",
            title: "iPhone Mirroring",
            bounds: CGRect(x: 0, y: 70, width: 320, height: 700),
            source: .iPhoneMirroring
        )
        let occluder = windowInfo(id: 8, owner: "Codex", title: "Task", width: 500, height: 800, pid: 80)
        let mirror = windowInfo(id: 7, owner: "iPhone Mirroring", title: "iPhone Mirroring", width: 320, height: 700, pid: 70, x: 0, y: 70)

        XCTAssertFalse(WindowOcclusionPolicy.sourceIsTopmostAtCenter(
            source,
            orderedWindowInfo: [occluder, mirror]
        ))
        XCTAssertTrue(WindowOcclusionPolicy.sourceIsTopmostAtCenter(
            source,
            orderedWindowInfo: [mirror, occluder]
        ))
    }

    func testSemanticResolverUsesFreshTargetBoundsRatherThanLearnedBounds() {
        let fact = LearnedFact(
            name: "Honey",
            kind: .control,
            evidence: .visualInference,
            normalizedBounds: NormalizedBounds(CGRect(x: 0.9, y: 0.9, width: 0.1, height: 0.1)),
            screenSignature: "legacy-signature",
            screenSource: .iPhoneMirroring,
            requiredState: .chatList,
            confidence: 0.9
        )
        let liveBounds = CGRect(x: 0.14, y: 0.22, width: 0.22, height: 0.06)
        let targets = [
            TextTarget(text: "Chats", normalizedBounds: CGRect(x: 0.1, y: 0.9, width: 0.2, height: 0.05)),
            TextTarget(text: "Search", normalizedBounds: CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.05)),
            TextTarget(text: "Honey", normalizedBounds: liveBounds)
        ]

        let resolved = SemanticTargetResolver.resolve(fact: fact, targets: targets, currentState: .chatList)
        XCTAssertEqual(resolved?.textTarget.normalizedBounds, liveBounds)
        XCTAssertNotEqual(resolved?.textTarget.normalizedBounds, CGRect(x: 0.9, y: 0.9, width: 0.1, height: 0.1))
    }

    func testSemanticResolverFailsClosedForAmbiguousOrWrongStateTargets() {
        let fact = LearnedFact(
            name: "Honey",
            kind: .control,
            evidence: .visualInference,
            normalizedBounds: nil,
            screenSignature: "chat-list",
            screenSource: .iPhoneMirroring,
            requiredState: .chatList,
            confidence: 0.9
        )
        let duplicateTargets = [
            TextTarget(text: "Honey", normalizedBounds: CGRect(x: 0.1, y: 0.2, width: 0.1, height: 0.1)),
            TextTarget(text: "Honey", normalizedBounds: CGRect(x: 0.1, y: 0.4, width: 0.1, height: 0.1))
        ]

        XCTAssertNil(SemanticTargetResolver.resolve(fact: fact, targets: duplicateTargets, currentState: .chatList))
        XCTAssertNil(SemanticTargetResolver.resolve(fact: fact, targets: [duplicateTargets[0]], currentState: .conversation))
    }

    func testSemanticPlacementDisambiguatesDuplicateLabelsWithoutCoordinates() {
        let fact = LearnedFact(
            name: "gp",
            kind: .control,
            evidence: .visualInference,
            normalizedBounds: nil,
            screenSignature: "spotlight",
            screenSource: .iPhoneMirroring,
            requiredState: .generic,
            contextAnchors: ["top hit", "suggestions"],
            placement: .bottom,
            confidence: 0.99
        )
        let suggestion = TextTarget(
            text: "gp",
            normalizedBounds: CGRect(x: 0.1, y: 0.55, width: 0.1, height: 0.05)
        )
        let searchField = TextTarget(
            text: "gp",
            normalizedBounds: CGRect(x: 0.1, y: 0.05, width: 0.1, height: 0.05)
        )
        let anchors = [
            TextTarget(text: "Top Hit", normalizedBounds: .zero),
            TextTarget(text: "Suggestions", normalizedBounds: .zero)
        ]

        let resolved = SemanticTargetResolver.resolve(
            fact: fact,
            targets: [suggestion, searchField] + anchors,
            currentState: .generic
        )
        XCTAssertEqual(resolved?.textTarget.id, searchField.id)
        XCTAssertNil(resolved?.textTarget.id == suggestion.id ? resolved : nil)
    }

    func testLegacyCoordinateOnlyFactIsNotActionable() {
        let legacyFact = LearnedFact(
            name: "Honey",
            kind: .control,
            evidence: .visualInference,
            normalizedBounds: NormalizedBounds(CGRect(x: 0.5, y: 0.5, width: 0.1, height: 0.1)),
            screenSignature: "old",
            screenSource: .iPhoneMirroring,
            confidence: 0.9
        )
        let target = TextTarget(text: "Honey", normalizedBounds: CGRect(x: 0.1, y: 0.2, width: 0.1, height: 0.1))

        XCTAssertNil(SemanticTargetResolver.resolve(fact: legacyFact, targets: [target], currentState: .chatList))
    }

    func testRecordedActionResolverUsesFreshBounds() throws {
        let recordedTarget = RecordedActionTarget(
            name: "Honey",
            kind: .control,
            requiredState: .chatList
        )
        let freshTarget = TextTarget(
            text: "Honey",
            normalizedBounds: CGRect(x: 0.12, y: 0.71, width: 0.22, height: 0.05)
        )

        let resolved = try XCTUnwrap(
            RecordedActionResolver.resolve(
                target: recordedTarget,
                flowSource: .iPhoneMirroring,
                activeSource: .iPhoneMirroring,
                targets: [freshTarget],
                currentState: .chatList
            )
        )

        XCTAssertEqual(resolved.textTarget.normalizedBounds, freshTarget.normalizedBounds)
    }

    func testRecordedActionResolverFailsClosedOnWrongSourceStateOrDuplicate() {
        let recordedTarget = RecordedActionTarget(
            name: "Honey",
            kind: .control,
            requiredState: .chatList
        )
        let first = TextTarget(text: "Honey", normalizedBounds: CGRect(x: 0.1, y: 0.7, width: 0.2, height: 0.05))
        let second = TextTarget(text: "honey", normalizedBounds: CGRect(x: 0.1, y: 0.4, width: 0.2, height: 0.05))

        XCTAssertNil(RecordedActionResolver.resolve(
            target: recordedTarget,
            flowSource: .iPhoneMirroring,
            activeSource: .simulator,
            targets: [first],
            currentState: .chatList
        ))
        XCTAssertNil(RecordedActionResolver.resolve(
            target: recordedTarget,
            flowSource: .iPhoneMirroring,
            activeSource: .iPhoneMirroring,
            targets: [first],
            currentState: .conversation
        ))
        XCTAssertNil(RecordedActionResolver.resolve(
            target: recordedTarget,
            flowSource: .iPhoneMirroring,
            activeSource: .iPhoneMirroring,
            targets: [first, second],
            currentState: .chatList
        ))
    }

    func testGenericRecordedActionRequiresStableScreenLandmarks() {
        let recordedTarget = RecordedActionTarget(
            name: "Continue",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "phone number", "privacy policy"]
        )
        let target = TextTarget(text: "Continue", normalizedBounds: CGRect(x: 0.2, y: 0.1, width: 0.3, height: 0.06))
        let correctScreen = [
            target,
            TextTarget(text: "Create account", normalizedBounds: .zero),
            TextTarget(text: "Phone number", normalizedBounds: .zero)
        ]
        let wrongScreen = [
            target,
            TextTarget(text: "Checkout", normalizedBounds: .zero),
            TextTarget(text: "Payment method", normalizedBounds: .zero)
        ]

        XCTAssertNotNil(RecordedActionResolver.resolve(
            target: recordedTarget,
            flowSource: .simulator,
            activeSource: .simulator,
            targets: correctScreen,
            currentState: .generic
        ))
        XCTAssertNil(RecordedActionResolver.resolve(
            target: recordedTarget,
            flowSource: .simulator,
            activeSource: .simulator,
            targets: wrongScreen,
            currentState: .generic
        ))
    }

    func testRecordedFlowRoundTripRetainsEncryptedReplayPayloadModel() throws {
        let target = RecordedActionTarget(name: "Phone", kind: .control, requiredState: .conversation)
        let postcondition = RecordedScreenPostcondition(
            requiredState: .conversation,
            contextAnchors: ["message", "send"]
        )
        let flow = RecordedActionFlow(
            name: "Fill phone",
            source: .simulator,
            steps: [RecordedActionStep(
                kind: .input,
                target: target,
                inputText: "9988998887",
                postcondition: postcondition
            )]
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(RecordedActionFlow.self, from: encoder.encode(flow))

        XCTAssertEqual(decoded.id, flow.id)
        XCTAssertEqual(decoded.name, flow.name)
        XCTAssertEqual(decoded.source, flow.source)
        XCTAssertEqual(decoded.steps.map(\.id), flow.steps.map(\.id))
        XCTAssertEqual(decoded.steps.first?.inputText, flow.steps.first?.inputText)
        XCTAssertEqual(decoded.steps.first?.postcondition, postcondition)
        XCTAssertEqual(decoded.steps.first?.summary, "Set value in Phone")
        XCTAssertFalse(decoded.steps.first?.summary.contains("9988998887") ?? true)
    }

    func testRecordedPostconditionRequiresStateAndStableAnchors() {
        let postcondition = RecordedScreenPostcondition(
            requiredState: .conversation,
            contextAnchors: ["honey", "message", "send"]
        )
        let matching = [
            TextTarget(text: "Honey", normalizedBounds: .zero),
            TextTarget(text: "Message", normalizedBounds: .zero)
        ]

        XCTAssertTrue(postcondition.matches(targets: matching, state: .conversation))
        XCTAssertFalse(postcondition.matches(targets: matching, state: .chatList))
        XCTAssertFalse(postcondition.matches(
            targets: [TextTarget(text: "Unrelated", normalizedBounds: .zero)],
            state: .conversation
        ))
    }

    func testVisibleTextResolverRequiresUniqueExactLabel() {
        let honey = TextTarget(text: "Honey", normalizedBounds: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.05))
        let honeyMom = TextTarget(text: "Honey Mom", normalizedBounds: CGRect(x: 0.1, y: 0.5, width: 0.3, height: 0.05))

        XCTAssertEqual(
            SemanticTargetResolver.resolveVisibleText(
                "honey",
                targets: [honey, honeyMom],
                currentState: .chatList
            )?.textTarget.id,
            honey.id
        )
        XCTAssertNil(SemanticTargetResolver.resolveVisibleText(
            "Honey",
            targets: [honey, TextTarget(text: "honey", normalizedBounds: .zero)],
            currentState: .chatList
        ))
    }

    func testSemanticStateRecognizesChatListFromStableLandmarkQuorum() {
        let targets = ["Chats", "All", "Unread 258", "Archived"].map {
            TextTarget(text: $0, normalizedBounds: .zero)
        }

        XCTAssertEqual(SemanticScreenState.classify(targets), .chatList)
        XCTAssertEqual(SemanticScreenState.classify([
            TextTarget(text: "Chats", normalizedBounds: .zero),
            TextTarget(text: "Unrelated", normalizedBounds: .zero)
        ]), .generic)
    }

    func testSemanticStateRecognizesConversationFromSeparateComposerControls() {
        XCTAssertEqual(SemanticScreenState.classify([
            TextTarget(text: "Message", normalizedBounds: .zero),
            TextTarget(text: "Send", normalizedBounds: .zero)
        ]), .conversation)
    }

    func testVisibleTextResolverCanDisambiguateUsingCoarsePlacement() {
        let top = TextTarget(text: "Search", normalizedBounds: CGRect(x: 0.1, y: 0.8, width: 0.3, height: 0.05))
        let bottom = TextTarget(text: "Search", normalizedBounds: CGRect(x: 0.1, y: 0.1, width: 0.3, height: 0.05))

        XCTAssertEqual(
            SemanticTargetResolver.resolveVisibleText(
                "Search",
                placement: .bottom,
                targets: [top, bottom],
                currentState: .generic
            )?.textTarget.id,
            bottom.id
        )
    }

    func testVisibleTextResolverCanConsumeCurrentOpaqueTargetID() {
        let query = TextTarget(text: "WA Business", normalizedBounds: CGRect(x: 0.1, y: 0.55, width: 0.3, height: 0.05))
        let result = TextTarget(text: "WA Business", normalizedBounds: CGRect(x: 0.1, y: 0.45, width: 0.3, height: 0.05))

        XCTAssertEqual(
            SemanticTargetResolver.resolveVisibleText(
                "WA Business",
                targetID: result.id,
                targets: [query, result],
                currentState: .generic
            )?.textTarget.id,
            result.id
        )
        XCTAssertNil(SemanticTargetResolver.resolveVisibleText(
            "Different label",
            targetID: result.id,
            targets: [query, result],
            currentState: .generic
        ))
    }

    func testSearchControlResolverAcceptsUniqueOCRDecoration() {
        let decorated = TextTarget(text: "Q search", normalizedBounds: .zero)

        XCTAssertEqual(
            SemanticTargetResolver.resolveSearchControl(
                targets: [decorated],
                currentState: .generic
            )?.textTarget.id,
            decorated.id
        )
        XCTAssertNil(SemanticTargetResolver.resolveSearchControl(
            targets: [decorated, TextTarget(text: "Search", normalizedBounds: .zero)],
            currentState: .generic
        ))
    }

    func testSpotlightSearchControlResolverUsesCurrentBottomQuery() {
        let result = TextTarget(
            text: "WA Business",
            normalizedBounds: CGRect(x: 0.2, y: 0.5, width: 0.3, height: 0.03)
        )
        let searchQuery = TextTarget(
            text: "WA Business",
            normalizedBounds: CGRect(x: 0.2, y: 0.05, width: 0.3, height: 0.03)
        )

        XCTAssertEqual(
            SemanticTargetResolver.resolveSpotlightSearchControl(
                currentQuery: "WA Business",
                targets: [result, searchQuery],
                currentState: .generic
            )?.textTarget.id,
            searchQuery.id
        )

        let differentQuery = TextTarget(
            text: "git",
            normalizedBounds: CGRect(x: 0.19, y: 0.05, width: 0.08, height: 0.03)
        )
        let wideResult = TextTarget(
            text: "GitHub result detail",
            normalizedBounds: CGRect(x: 0.25, y: 0.08, width: 0.65, height: 0.03)
        )
        XCTAssertEqual(
            SemanticTargetResolver.resolveSpotlightSearchControl(
                currentQuery: "WA Business",
                targets: [differentQuery, wideResult],
                currentState: .generic
            )?.textTarget.id,
            differentQuery.id
        )
    }

    func testSpotlightSearchDetectionAcceptsSplitGlyphAndPersistedQuery() {
        let glyph = TextTarget(
            text: "Q",
            normalizedBounds: CGRect(x: 0.1, y: 0.05, width: 0.05, height: 0.03)
        )
        let query = TextTarget(
            text: "WA Business",
            normalizedBounds: CGRect(x: 0.2, y: 0.05, width: 0.3, height: 0.03)
        )

        XCTAssertTrue(SemanticTargetResolver.spotlightSearchIsVisible(in: [glyph, query]))
        XCTAssertTrue(SemanticTargetResolver.spotlightSearchIsVisible(in: [
            TextTarget(text: "Q search", normalizedBounds: .zero)
        ]))
        XCTAssertTrue(SemanticTargetResolver.spotlightSearchIsVisible(in: [
            TextTarget(text: "Top Hit", normalizedBounds: .zero),
            query
        ]))
        XCTAssertFalse(SemanticTargetResolver.spotlightSearchIsVisible(in: [query]))
    }

    func testSpotlightResultMatcherAcceptsTrailingResultMetadataOnly() {
        XCTAssertTrue(SemanticTargetResolver.spotlightResultMatches(
            expectedName: "WA Business",
            recognizedText: "WA Business Open Meta"
        ))
        XCTAssertFalse(SemanticTargetResolver.spotlightResultMatches(
            expectedName: "WA Business",
            recognizedText: "Install WA Business"
        ))
        XCTAssertFalse(SemanticTargetResolver.spotlightResultMatches(
            expectedName: "WA Business",
            recognizedText: "WA Business Tools"
        ))
    }

    func testWhatsAppAppIdentityRequiresDistinctiveLandmarkQuorum() {
        let whatsapp = ["Chats", "Updates", "Calls", "Tools", "Settings"].map {
            TextTarget(text: $0, normalizedBounds: .zero)
        }

        XCTAssertTrue(SemanticTargetResolver.appIsVisible(
            named: "WhatsApp Business",
            state: .chatList,
            targets: whatsapp
        ))
        XCTAssertFalse(SemanticTargetResolver.appIsVisible(
            named: "WhatsApp Business",
            state: .chatList,
            targets: [TextTarget(text: "Chats", normalizedBounds: .zero)]
        ))
        XCTAssertFalse(SemanticTargetResolver.appIsVisible(
            named: "Another App",
            state: .chatList,
            targets: whatsapp
        ))
    }

    func testWindowMatcherSelectsSimulatorAndAutomaticFallsBackToIt() {
        let simulator = windowInfo(id: 41, owner: "Simulator", title: "iPhone 16", width: 390, height: 844)

        XCTAssertEqual(MirrorWindowMatcher.match(in: [simulator], source: .simulator)?.source, .simulator)
        XCTAssertEqual(MirrorWindowMatcher.match(in: [simulator])?.source, .simulator)
    }

    func testLearnedFactsAreScopedToTheirCaptureSource() {
        let simulatorFact = LearnedFact(
            name: "Settings",
            kind: .appIcon,
            evidence: .userConfirmed,
            normalizedBounds: nil,
            screenSignature: "same-screen",
            screenSource: .simulator,
            confidence: 1
        )
        let legacyFact = LearnedFact(
            name: "Legacy",
            kind: .appIcon,
            evidence: .userConfirmed,
            normalizedBounds: nil,
            screenSignature: "same-screen",
            confidence: 1
        )

        XCTAssertTrue(simulatorFact.isRelevant(to: "same-screen", source: .simulator))
        XCTAssertFalse(simulatorFact.isRelevant(to: "same-screen", source: .iPhoneMirroring))
        XCTAssertTrue(legacyFact.isRelevant(to: "same-screen", source: .iPhoneMirroring))
        XCTAssertFalse(legacyFact.isRelevant(to: "same-screen", source: .simulator))
    }
    func testVerifiedMessageFlowRequiresAFullDeterministicSelectorChain() throws {
        let selector = QASelector(strategy: .accessibilityID, value: "stable")
        let flow = try QAFlow.verifiedMessage(
            recipient: "Honey",
            message: "I love you",
            appBundleID: "net.whatsapp.WhatsAppSMB",
            recipientSelector: selector,
            conversationSelector: selector,
            composerSelector: selector,
            sendSelector: selector,
            deliveredMessageSelector: selector
        )

        XCTAssertEqual(flow.steps.map(\.action), [.assertVisible, .tap, .assertVisible, .typeText, .assertVisible, .tap])
        XCTAssertEqual(flow.steps[1].postcondition, selector)
        XCTAssertEqual(flow.steps[5].postcondition, selector)
        XCTAssertEqual(flow.steps[3].parameters["text"], .string("I love you"))
    }

    func testVerifiedMessageFlowRejectsMissingConfirmationSelector() {
        let selector = QASelector(strategy: .accessibilityID, value: "stable")
        XCTAssertThrowsError(
            try QAFlow.verifiedMessage(
                recipient: "Honey",
                message: "I love you",
                appBundleID: "net.whatsapp.WhatsAppSMB",
                recipientSelector: selector,
                conversationSelector: selector,
                composerSelector: selector,
                sendSelector: selector,
                deliveredMessageSelector: QASelector(strategy: .accessibilityID, value: "")
            )
        )
    }

    func testBundledCompiledFlowsPassStaticValidation() {
        for flow in BundledCompiledFlowCatalog.packages {
            XCTAssertEqual(CompiledFlowValidator.validate(flow), [], flow.id)
        }
    }

    func testCompiledFlowValidatorRejectsGeometryAndMissingSensitiveApproval() {
        let unsafe = CompiledFlowPackage(
            id: "unsafe.send",
            version: 1,
            status: .draft,
            intentID: "messaging.send",
            displayName: "Unsafe send",
            inputSpecs: [:],
            supportedSources: [.iPhoneMirroring],
            steps: [
                CompiledFlowStep(
                    id: "send",
                    primitive: .tapVisibleText,
                    arguments: [
                        "target": .literal("Send"),
                        "x": .literal("0.5")
                    ],
                    precondition: CompiledScreenPredicate(allowedStates: [.conversation]),
                    postcondition: CompiledScreenPredicate(allowedStates: [.conversation]),
                    effect: .externalCommunication
                )
            ],
            provenance: "test"
        )

        let issues = CompiledFlowValidator.validate(unsafe)
        XCTAssertTrue(issues.contains(.forbiddenArgument(step: "send", argument: "x")))
        XCTAssertTrue(issues.contains(.missingApproval("send")))
    }

    func testCompiledRegistrySelectsOneCompatibleAppPack() throws {
        let registry = try CompiledFlowRegistry(packages: BundledCompiledFlowCatalog.packages)
        let inputs = [
            "app": "WhatsApp Business",
            "recipient": "Honey",
            "message": "I love you"
        ]

        let flow = try registry.resolve(
            intentID: "messaging.draft",
            inputs: inputs,
            source: .iPhoneMirroring
        )

        XCTAssertEqual(flow.id, "whatsapp-business.messaging.draft")
        XCTAssertThrowsError(try registry.resolve(
            intentID: "messaging.draft",
            inputs: inputs.merging(["app": "Unknown Chat"]) { _, new in new },
            source: .iPhoneMirroring
        )) { error in
            XCTAssertEqual(error as? CompiledFlowRegistryError, .unsupportedApp("Unknown Chat"))
        }
    }

    func testRecordedFlowCompilerParameterizesSecretValues() throws {
        let secret = "9988998887"
        let target = RecordedActionTarget(
            name: "Phone",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "continue"]
        )
        let recorded = RecordedActionFlow(
            name: "Enter phone",
            source: .simulator,
            steps: [
                RecordedActionStep(
                    kind: .input,
                    target: target,
                    inputText: secret,
                    postcondition: RecordedScreenPostcondition(
                        requiredState: .generic,
                        contextAnchors: ["phone", "continue"]
                    )
                )
            ]
        )

        let compiled = try RecordedFlowCompiler.compile(recorded)
        let encoded = try JSONEncoder().encode(compiled)
        let serialized = String(decoding: encoded, as: UTF8.self)

        XCTAssertEqual(compiled.status, .draft)
        XCTAssertEqual(compiled.inputSpecs["step_1_value"]?.retention, .runOnly)
        XCTAssertFalse(serialized.contains(secret))
        XCTAssertEqual(CompiledFlowValidator.validate(compiled), [])
    }

    func testSemanticTraceAdapterDropsRecordedValueAndCompilesRecordedFlow() throws {
        let secret = "9988998887"
        let target = RecordedActionTarget(
            name: "Phone",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "continue"]
        )
        let recorded = RecordedActionFlow(
            name: "Enter phone",
            source: .simulator,
            steps: [
                RecordedActionStep(
                    kind: .input,
                    target: target,
                    inputText: secret,
                    postcondition: RecordedScreenPostcondition(
                        requiredState: .generic,
                        contextAnchors: ["phone", "continue"]
                    )
                )
            ]
        )

        let trace = SemanticTrace(recordedFlow: recorded)
        let encodedTrace = try JSONEncoder().encode(trace)
        let serializedTrace = String(decoding: encodedTrace, as: UTF8.self)
        let compiledFromTrace = try SemanticTraceCompiler.compile(trace)

        XCTAssertFalse(serializedTrace.contains(secret))
        XCTAssertEqual(trace.source, .simulator)
        XCTAssertEqual(trace.steps.first?.operation, .replaceText)
        XCTAssertEqual(trace.steps.first?.target?.name, "Phone")
        XCTAssertEqual(trace.steps.first?.input?.name, "step_1_value")
        XCTAssertEqual(trace.steps.first?.input?.retention, .runOnly)
        XCTAssertEqual(compiledFromTrace, try RecordedFlowCompiler.compile(recorded))
        XCTAssertEqual(compiledFromTrace.provenance, "iosclaw.recorded.\(recorded.id.uuidString.lowercased())")
    }

    func testSemanticTraceCompilerRejectsUnverifiedPostcondition() {
        let target = SemanticTargetSpec(
            name: "Continue",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "phone number"]
        )
        let trace = SemanticTrace(
            displayName: "Invalid trace",
            source: .simulator,
            steps: [
                SemanticTraceStep(
                    operation: .tap,
                    target: target,
                    precondition: SemanticStateEvidence(target: target),
                    postcondition: SemanticStateEvidence(allowedStates: [.unknown])
                )
            ],
            provenance: "test"
        )

        XCTAssertThrowsError(try SemanticTraceCompiler.compile(trace)) { error in
            XCTAssertEqual(
                error as? SemanticTraceCompilerError,
                .invalidTrace([.missingPostcondition("trace-1")])
            )
        }
    }

    func testSemanticTraceValidatorRejectsUnsafeGenericInputEvidence() {
        let target = SemanticTargetSpec(
            name: "Phone",
            kind: .control,
            requiredState: .generic,
            contextAnchors: []
        )
        let trace = SemanticTrace(
            displayName: "Unsafe trace",
            source: .simulator,
            steps: [
                SemanticTraceStep(
                    operation: .replaceText,
                    target: target,
                    input: SemanticTraceInput(
                        name: "phone_number",
                        type: .secretString,
                        retention: .package
                    ),
                    precondition: SemanticStateEvidence(allowedStates: [.generic]),
                    postcondition: SemanticStateEvidence(
                        allowedStates: [.generic],
                        exactTexts: ["Continue"]
                    )
                )
            ],
            provenance: "test"
        )

        let issues = SemanticTraceValidator.validate(trace)
        XCTAssertEqual(
            issues.filter { $0 == .insufficientGenericEvidence("trace-1") }.count,
            2
        )
        XCTAssertTrue(issues.contains(.invalidInput("trace-1")))
    }

    func testSemanticTraceRequiresRunOnlyInputsForEveryTypedValue() {
        let target = SemanticTargetSpec(
            name: "Phone",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "continue"]
        )
        let trace = SemanticTrace(
            displayName: "Persistent value safety",
            source: .simulator,
            steps: [
                SemanticTraceStep(
                    operation: .replaceText,
                    target: target,
                    input: SemanticTraceInput(
                        name: "phone_number",
                        type: .string,
                        retention: .package
                    ),
                    precondition: SemanticStateEvidence(target: target),
                    postcondition: SemanticStateEvidence(
                        allowedStates: [.generic],
                        exactTexts: ["phone", "continue"]
                    )
                )
            ],
            provenance: "test.agent"
        )

        XCTAssertTrue(SemanticTraceValidator.validate(trace).contains(.invalidInput("trace-1")))
    }

    func testCompiledDraftCatalogVersionsRecompilesAndProtectsBundledPackages() throws {
        let target = SemanticTargetSpec(
            name: "Phone",
            kind: .control,
            requiredState: .generic,
            contextAnchors: ["create account", "continue"]
        )
        let trace = SemanticTrace(
            id: UUID(uuidString: "2D48B8E6-18B6-4BA4-9877-110BA9865B32")!,
            displayName: "Enter phone",
            source: .simulator,
            steps: [
                SemanticTraceStep(
                    operation: .replaceText,
                    target: target,
                    input: SemanticTraceInput(
                        name: "phone_number",
                        type: .secretString,
                        retention: .runOnly
                    ),
                    precondition: SemanticStateEvidence(target: target),
                    postcondition: SemanticStateEvidence(
                        allowedStates: [.generic],
                        exactTexts: ["phone", "continue"]
                    )
                )
            ],
            provenance: "test.agent"
        )
        let draft = try SemanticTraceCompiler.compile(trace)
        let recompiled = CompiledFlowCatalog.upserting(draft, into: [draft])

        XCTAssertEqual(recompiled.count, 1)
        XCTAssertEqual(recompiled.first?.version, 2)

        let bundled = BundledCompiledFlowCatalog.openApp
        let attemptedOverride = CompiledFlowPackage(
            id: bundled.id,
            version: 1,
            status: .draft,
            intentID: "user.override",
            displayName: "Override",
            inputSpecs: [:],
            supportedSources: [.simulator],
            steps: [
                CompiledFlowStep(
                    id: "home",
                    primitive: .home,
                    precondition: CompiledScreenPredicate(allowedStates: [.generic]),
                    postcondition: CompiledScreenPredicate(allowedStates: [.chatList]),
                    effect: .navigate
                )
            ],
            provenance: "test.agent"
        )
        let merged = CompiledFlowCatalog.merge(
            bundled: [bundled],
            userDrafts: recompiled + [attemptedOverride]
        )

        XCTAssertEqual(merged.filter { $0.id == bundled.id }.count, 1)
        XCTAssertEqual(merged.first(where: { $0.id == bundled.id }), bundled)
        XCTAssertEqual(merged.last?.id, draft.id)
    }

    func testCompiledDraftStoreEncryptsAndRestoresValueFreePackage() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iosclaw-compiled-flow-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        let trace = SemanticTrace(
            displayName: "Return home",
            source: .simulator,
            steps: [
                SemanticTraceStep(
                    operation: .home,
                    precondition: .anyActionable,
                    postcondition: SemanticStateEvidence(allowedStates: [.chatList])
                )
            ],
            provenance: "test.agent"
        )
        let draft = try SemanticTraceCompiler.compile(trace)
        let store = try SecureCompiledFlowStore(
            directoryURL: directory,
            encryptionKey: SymmetricKey(size: .bits256)
        )

        try store.save([draft])

        XCTAssertEqual(try store.load(), [draft])
        let ciphertext = try Data(contentsOf: directory.appendingPathComponent("compiled-flow-packages.bin"))
        XCTAssertFalse(String(decoding: ciphertext, as: UTF8.self).contains(draft.displayName))
    }

    @MainActor
    func testCompiledExecutorRunsReferenceFlowWithoutPerStepPlanning() async {
        let observations = [
            compiledObservation(state: .generic, texts: ["Calendar", "Settings"]),
            compiledObservation(state: .conversation, texts: ["Honey", "Message"]),
            compiledObservation(state: .chatList, texts: ["Chats", "Search"]),
            compiledObservation(state: .conversation, texts: ["Honey", "Message"]),
            compiledObservation(state: .conversation, texts: ["Honey", "I love you"])
        ]
        let driver = RecordingCompiledFlowDriver(observations: observations)

        let run = await CompiledFlowExecutor(driver: driver).run(
            flow: BundledCompiledFlowCatalog.whatsappBusinessDraft,
            inputs: [
                "app": "WhatsApp",
                "recipient": "Honey",
                "message": "I love you"
            ],
            initialObservation: observations[0]
        )

        XCTAssertEqual(run.outcome, .succeeded)
        XCTAssertEqual(driver.primitives, [
            .launchAppViaSpotlight,
            .ensureChatList,
            .keyboardFindAndActivate,
            .replaceVisibleText
        ])
        XCTAssertEqual(driver.arguments[2]["query"], "Honey")
        XCTAssertEqual(driver.arguments[3]["value"], "I love you")
    }

    @MainActor
    func testCompiledExecutorStopsBeforeInputOnWrongState() async {
        let observation = compiledObservation(state: .generic, texts: ["Other screen"])
        let driver = RecordingCompiledFlowDriver(observations: [observation])
        let flow = CompiledFlowPackage(
            id: "test.chat-list-only",
            version: 1,
            status: .active,
            intentID: "test.open",
            displayName: "Chat list only",
            inputSpecs: [:],
            supportedSources: [.iPhoneMirroring],
            steps: [
                CompiledFlowStep(
                    id: "requires-chat-list",
                    primitive: .home,
                    precondition: CompiledScreenPredicate(allowedStates: [.chatList]),
                    postcondition: CompiledScreenPredicate(allowedStates: [.generic]),
                    effect: .navigate
                )
            ],
            provenance: "test"
        )

        let run = await CompiledFlowExecutor(driver: driver).run(
            flow: flow,
            inputs: [:],
            initialObservation: observation
        )

        XCTAssertEqual(run.outcome, .failed)
        XCTAssertTrue(driver.primitives.isEmpty)
        XCTAssertTrue(run.failureReason?.contains("required live state") == true)
    }

    func testWDAClientStartsSessionResolvesAndClicksElement() async throws {
        MockWDAURLProtocol.reset(responses: [
            #"{"sessionId":"session-1","value":{"capabilities":{}}}"#,
            #"{"value":{"element-6066-11e4-a52e-4f735466cecf":"element-1"}}"#,
            #"{"value":null}"#,
            #"{"value":null}"#
        ])
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockWDAURLProtocol.self]
        let client = try WDAClient(
            endpoint: URL(string: "http://127.0.0.1:8100")!,
            session: URLSession(configuration: configuration)
        )

        let sessionID = try await client.createSession(bundleID: "com.example.qa")
        try await client.perform(
            QAFlowStep(
                name: "Tap primary action",
                action: .tap,
                selector: QASelector(strategy: .accessibilityID, value: "primary-action")
            ),
            sessionID: sessionID
        )
        await client.deleteSession(sessionID)

        XCTAssertEqual(MockWDAURLProtocol.paths, [
            "/session",
            "/session/session-1/element",
            "/session/session-1/element/element-1/click",
            "/session/session-1"
        ])
        XCTAssertEqual(MockWDAURLProtocol.methods, ["POST", "POST", "POST", "DELETE"])
    }

    func testExecutionEngineRecordsVerifiedReplay() async throws {
        let client = RecordingWDA()
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("iosclaw-qa-store-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try SecureQAStore(
            directoryURL: directory,
            encryptionKey: SymmetricKey(size: .bits256)
        )
        let flow = QAFlow(
            name: "Replay",
            appBundleID: "com.example.qa",
            steps: [
                QAFlowStep(
                    name: "Verify landing screen",
                    action: .assertVisible,
                    selector: QASelector(strategy: .accessibilityID, value: "landing")
                )
            ]
        )

        let run = await QAExecutionEngine(client: client, store: store).run(
            flow: flow,
            deviceKey: "mock-device"
        )

        XCTAssertEqual(run.outcome, .passed)
        XCTAssertEqual(run.events.count, 1)
        XCTAssertEqual(run.events.first?.outcome, .passed)
        let createdBundleID = await client.createdBundleID
        let deletedSessionID = await client.deletedSessionID
        XCTAssertEqual(createdBundleID, "com.example.qa")
        XCTAssertEqual(deletedSessionID, "mock-session")
    }
}

private func windowInfo(
    id: UInt32,
    owner: String,
    title: String,
    width: Double,
    height: Double,
    pid: Int = 123,
    x: Double = 0,
    y: Double = 0
) -> [String: Any] {
    [
        kCGWindowNumber as String: NSNumber(value: id),
        kCGWindowOwnerPID as String: NSNumber(value: pid),
        kCGWindowOwnerName as String: owner,
        kCGWindowName as String: title,
        kCGWindowLayer as String: NSNumber(value: 0),
        kCGWindowAlpha as String: NSNumber(value: 1),
        kCGWindowBounds as String: [
            "X": NSNumber(value: x),
            "Y": NSNumber(value: y),
            "Width": NSNumber(value: width),
            "Height": NSNumber(value: height)
        ]
    ]
}

private final class MockWDAURLProtocol: URLProtocol {
    private static var queuedBodies: [Data] = []
    static var paths: [String] = []
    static var methods: [String] = []

    static func reset(responses: [String]) {
        queuedBodies = responses.map { Data($0.utf8) }
        paths = []
        methods = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.paths.append(request.url?.path ?? "")
        Self.methods.append(request.httpMethod ?? "")
        let body = Self.queuedBodies.removeFirst()
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private actor RecordingWDA: WDAControlling {
    var createdBundleID: String?
    var deletedSessionID: String?

    func status() async throws -> String { "ready" }

    func createSession(bundleID: String) async throws -> String {
        createdBundleID = bundleID
        return "mock-session"
    }

    func deleteSession(_ sessionID: String) async {
        deletedSessionID = sessionID
    }

    func perform(_ step: QAFlowStep, sessionID: String) async throws {
        XCTAssertEqual(sessionID, "mock-session")
        XCTAssertEqual(step.action, .assertVisible)
    }

    func screenshot(sessionID: String) async throws -> Data {
        Data()
    }
}

private func compiledObservation(
    state: SemanticScreenState,
    texts: [String]
) -> CompiledFlowObservation {
    CompiledFlowObservation(
        source: .iPhoneMirroring,
        state: state,
        visibleTexts: texts,
        generationID: UUID()
    )
}

private func captureGeneration(signature: String) -> CaptureGeneration {
    CaptureGeneration(
        id: UUID(),
        capturedAt: .now,
        windowID: 7,
        windowBounds: CGRect(x: 0, y: 0, width: 300, height: 700),
        source: .iPhoneMirroring,
        screenSignature: signature
    )
}

@MainActor
private final class RecordingCompiledFlowDriver: CompiledFlowDriving {
    private let observations: [CompiledFlowObservation]
    private var observationIndex = 0
    private(set) var primitives: [CompiledFlowPrimitive] = []
    private(set) var arguments: [[String: String]] = []

    init(observations: [CompiledFlowObservation]) {
        self.observations = observations
    }

    func compiledObserve() async -> CompiledFlowObservation? {
        observations.first
    }

    func compiledCurrentObservation() -> CompiledFlowObservation? {
        guard observations.indices.contains(observationIndex) else { return nil }
        return observations[observationIndex]
    }

    func compiledPerform(
        primitive: CompiledFlowPrimitive,
        arguments: [String: String],
        timeoutMilliseconds: Int
    ) async -> Bool {
        primitives.append(primitive)
        self.arguments.append(arguments)
        observationIndex += 1
        return observations.indices.contains(observationIndex)
            && timeoutMilliseconds > 0
    }
}
