# iosClaw Technical Use-Case Validation

## Decision

Build the first product around **AI-maintained real-iPhone QA workflows** using XCTest/WebDriverAgent. Keep the same semantic-flow engine compatible with iPhone Mirroring for lower-risk personal and operations flows.

The proposed use cases are feasible, but they use different iOS control mechanisms and should not be presented as one universal automation capability.

## Validation matrix

| Use case | Verdict | Execution path | Material constraint |
| --- | --- | --- | --- |
| AI-maintained mobile QA | Strong fit | XCTest/WebDriverAgent on simulators and real devices | Customer owns the app and test-device setup |
| Internal-app operations | Strong fit | App Intents/API first; WDA for legacy UI | Best on managed/company-owned devices |
| Read, summarize, and draft across apps | Viable | iPhone Mirroring plus OCR/vision | Foreground, paired Mac/iPhone workflow |
| Personal research, capture, and admin | Viable | Mirroring plus semantic flows; APIs where exposed | Visible, low-risk tasks only |
| Message/social drafting | Viable with guardrails | Mirroring plus approval gate | Never default to autonomous send/post |
| Finance, banking, security, and login | Unsupported | User handoff | OTP, Face ID, CAPTCHA, payment, and policy risk |
| Unattended consumer iPhone fleet | Unsupported through Mirroring | Dedicated managed-device/WDA workers only | Mirroring is not a fleet control plane |

## Technical evidence and implications

### QA is the primary technical wedge

Apple's Xcode tooling records UI interactions and replays them as UI tests, with final-state assertions. XCTest-based automation therefore provides a supported conceptual base for recorder-to-flow conversion.

WebDriverAgent is the real-device adapter. It requires a trusted device, Developer Mode for iOS/iPadOS 16+, UI Automation enabled, and a valid signing/provisioning profile. This setup is appropriate for developer and managed-device environments, but it is not a consumer zero-setup path.

References:

- [Apple: adding tests to an Xcode project](https://developer.apple.com/documentation/xcode/adding-tests-to-your-xcode-project)
- [Apple: recording UI automation](https://developer.apple.com/documentation/xcuiautomation/recording-ui-automation-for-testing)
- [Appium: real-device configuration](https://appium.github.io/appium-xcuitest-driver/9.10/preparation/real-device-config/)

### Mirroring is a viable user-assistance adapter, not a fleet primitive

iPhone Mirroring allows a Mac to tap, swipe, and type on a locked iPhone. It requires a nearby paired phone, the same Apple Account, Bluetooth/Wi-Fi, and one iPhone connected to one Mac at a time. It is currently unavailable in the European Union. The connection pauses when the phone is unlocked or inactive.

Therefore, use Mirroring for user-owned low-risk flows such as research, reading, drafting, and capture; do not make promises about unattended remote operation or multi-device throughput.

Reference: [Apple: iPhone Mirroring](https://support.apple.com/en-us/120421)

### Prefer permitted structured interfaces over GUI control

An app owner can expose App Intents and App Shortcuts to Siri, Shortcuts, Spotlight, and Apple Intelligence. iosClaw should always use this path before GUI automation. Third-party apps only expose these capabilities when their developer chooses to do so.

Reference: [Apple: App Intents](https://developer.apple.com/documentation/appintents)

### Performance constraints are manageable with the correct locators

WDA/XCTest does not make all UI queries equally cheap. Full accessibility-tree snapshots and XPath are expensive; large UI hierarchies, animations, and an app that fails to reach idle can also slow or destabilize a run. Flow packs should prefer application accessibility identifiers and native predicates, use bounded tree depth, retain warm WDA sessions, and avoid fixed waits.

Reference: [Appium: diagnosing WebDriverAgent slowness](https://appium.github.io/appium-xcuitest-driver/9.10/guides/wda-slowness/)

## Required flow capability contract

Every flow must declare where and how it can run:

```yaml
requires:
  driver: [wda, mirroring, app_intent]
  interaction: [read, draft]
  may_run_unattended: false
  needs_approval_for: [send, purchase, delete]
  blocks_on: [login, otp, face_id, captcha]
```

The runtime selects an allowed channel in this order:

```text
App Intent/API -> owned app plus WDA -> Mirroring -> unsupported
```

It must never silently fall back to a less-safe channel for an irreversible action.

## Proof plan before product commitment

1. **QA proof:** Record and replay five critical workflows in a sample app across three real-device configurations. Target at least 95% completion over 30 consecutive runs per flow.
2. **Semantic-flow proof:** Replay a recorded workflow after harmless UI variations: a banner, shifted control, and different list order. It must resolve the conceptual state without a wrong action.
3. **Mirroring proof:** Validate open app, search, copy visible text, draft message, and save note; test lock state, reconnect, manual takeover, and approval handling.
4. **Safety proof:** Force OTP, Face ID, payment, Send, unexpected-popup, and wrong-contact states. The only acceptable outcome is a safe pause. False successful completion is a release blocker.

## Product consequence

V1 should be positioned as AI-maintained mobile QA for apps the customer owns. The Mirroring adapter remains valuable for a later private assistant/operations product, but should not define initial reliability, scale, or compliance claims.
