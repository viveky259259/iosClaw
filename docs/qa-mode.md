# QA Mode

QA Mode is a developer-only execution path for physical iPhone UI testing. It
does not use iPhone Mirroring input and is not part of the consumer product.

## Execution model

1. A paired iPhone runs the development-signed `WebDriverAgentRunner` test app.
2. WebDriverAgent is forwarded to `http://127.0.0.1:8100` on the Mac.
3. iosClaw creates one WDA session, replays a versioned `QAFlow`, verifies every
   selector/postcondition, then always deletes the session.
4. A process-wide file lease prevents two local runs from sharing one device.

Flows use accessibility ID, predicate, class chain, or XPath selectors. Vision
may recover a changed flow later, but it is not the normal execution path.

## Device preflight

The QA owner must perform these explicit device-security steps before any WDA
installation:

- Pair and trust the iPhone with the Mac.
- Enable Developer Mode on the iPhone.
- Enable **Settings > Developer > Enable UI Automation**.
- Build WDA with a provisioning profile owned by the QA team.

Do not use a consumer Apple ID, production personal data, or accounts with
payment authority for QA runs.

## Flow invariants

- One device lease permits one active flow only.
- Every mutating gesture has a stable selector or a verified postcondition.
- WDA is loopback-only; it is never exposed to the LAN.
- Screenshots are captured only on explicit steps, configured capture points, or
  failure; they are encrypted at rest on the Mac.
- Passwords, OTPs, Face ID, payments, and destructive actions require a manual
  checkpoint and are not represented as automatic default steps.

## Validation

Run:

```sh
xcodebuild -project iosClawMac/iosClawMac.xcodeproj -scheme iosClawMac -destination 'platform=macOS' test
```

The tests validate WDA HTTP route translation and an end-to-end deterministic
replay against a mock WDA controller. The final acceptance gate is a physical
device flow covering tap, scroll, long press, drag, pinch, and a failure
screenshot.
