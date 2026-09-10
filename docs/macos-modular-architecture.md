# macOS modular architecture

## Boundary

The macOS app owns local screen inspection and approved local input to iPhone
Mirroring or iOS Simulator. It does not own an iOS app's data model or bypass
Apple's permissions.

## Modules

```text
AppCore/AppCoordinator
        │ owns long-lived sessions and app-wide presentation state
        ▼
AppShell
        │ navigation and permission/source controls
        ├── Features/Inspection
        ├── Features/Learning
        ├── Features/Audit
        └── QA mode
        ▼
Domain services
        MirrorSession · QASession · QAExecutionEngine
        ▼
Infrastructure
        ScreenCaptureKit · Vision · CoreGraphics · Keychain-backed stores · MCP bridge
```

## Invariants

- Feature views render state and call named session intents; they do not access
  CoreGraphics, ScreenCaptureKit, Keychain, or filesystems.
- `MirrorSession` remains the authority for permission checks, live-screen
  validation, audit records, and local input.
- Learned facts are encrypted and source-scoped. UI visibility is not an
  authorization grant.
- The local MCP bridge invokes the same session intents as the UI.

## Dependency direction

`AppShell → Features → Domain → Infrastructure` only. A feature may share
presentational primitives with another feature, but it may not reach into that
feature's state. New device backends belong behind `MirrorSession` or a narrow
protocol, not in SwiftUI views.

## Validation contract

Every module change must retain these checks:

1. Signed Release build succeeds.
2. Screen Recording and Accessibility checks still block input safely.
3. Simulator inspection can capture an occluded window.
4. A learned fact is live-validated before input.
5. MCP actions exercise the same domain path as the UI.
