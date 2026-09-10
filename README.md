# iosClaw

iosClaw is an open-source, local-first automation runtime for iPhone workflows from a Mac. It combines live screen understanding with deterministic, verified execution so a flow can be learned once and replayed without asking an agent to rediscover every tap.

> **Status:** early alpha. The project is useful for experimentation, simulator testing, and developer-owned devices. APIs and UI may change.

[Website](https://iosclaw.netlify.app/) · [Architecture](docs/iosclaw-architecture-plan.md) · [MCP bridge](mcp/README.md) · [Release notes](docs/releases/0.1.0.md)

## What it does

- Captures iPhone Mirroring and iOS Simulator windows locally.
- Combines OCR, accessibility evidence, app identity, and current screen state.
- Resolves semantic targets from the live screen instead of replaying hard-coded coordinates.
- Records manual semantic actions and lowers them into parameterized flows.
- Runs compiled flows locally with postcondition checks and bounded recovery.
- Stores audit history, learned context, and compiled flow data encrypted on the Mac.
- Exposes a loopback-only MCP bridge for agent-generated inspection and automation.
- Includes an optional WebDriverAgent/Appium QA adapter for developer-owned test devices.

The initial bundled catalog includes `app.open` and `messaging.draft` for WhatsApp Business through iPhone Mirroring. Drafting stops before **Send**. The catalog is intentionally small while the semantic runtime and app-pack model are hardened.

## Why the runtime is split this way

General computer-use agents are good at discovering unfamiliar surfaces. iosClaw is the focused execution layer for the iPhone boundary: it resolves live state, reuses compiled transitions, verifies each result, and fails closed when the screen is ambiguous.

```text
User intent / agent planner
          |
          v
  semantic compiler + policy
          |
          v
  iosClaw local runtime
    |               |
    v               v
Mirroring       Simulator / WDA
    |
    v
fresh evidence + audit trail
```

## Requirements

- macOS 15 or later.
- Xcode with the macOS and iOS Simulator SDKs installed.
- An iPhone connected through iPhone Mirroring, or a booted iOS Simulator.
- Screen Recording permission for visible-screen capture.
- Accessibility permission only when iosClaw needs to send input.

No iPhone companion app or WebDriverAgent is required for the normal Mac-only path. Xcode may still ask you to select your own Apple development team to sign a local build; the project files do not contain a maintainer team ID.

## Quick start

1. Clone this repository and open `iosClawMac/iosClawMac.xcodeproj` in Xcode.
2. Select the `iosClawMac` scheme and run it on **My Mac**.
3. In iosClaw, choose **Automatic** screen source, then open iPhone Mirroring or boot the default Simulator.
4. Approve Screen Recording in macOS when prompted. Approve Accessibility only before an action that sends input.
5. Start with **Inspect visible screen**. Use the app UI or the MCP bridge to record and replay a semantic flow.

Build and install from a terminal:

```sh
bash scripts/install-macos.sh --debug     # Local contributor build
bash scripts/install-macos.sh             # Release build (requires signing setup)
```

The installer places the app at `/Applications/iosClaw.app` and keeps a timestamped backup of a replaced installation. To remove the app and iosClaw-owned local data:

```sh
bash scripts/uninstall-macos.sh
```

## MCP bridge

Open `/Applications/iosClaw.app` first. The app starts an authenticated, loopback-only bridge and writes a private connection file under `~/Library/Application Support/iosClaw/`.

Register the server with an MCP-capable agent using a path appropriate to your checkout:

```json
{
  "mcpServers": {
    "iosclaw": {
      "command": "node",
      "args": ["/absolute/path/to/iosClaw/mcp/iosclaw-mcp.mjs"]
    }
  }
}
```

The bridge can inspect a source, open a verified app, save learned semantic facts, record/replay flows, and run compiled flows. It never accepts coordinates, returns screenshots, or writes entered values to ordinary audit output. See [`mcp/README.md`](mcp/README.md) for the full tool contract.

## Optional developer QA mode

QA Mode is separate from the consumer Mac-only path. It uses a development-signed WebDriverAgent session for a device owned by the QA team.

Before using it, the QA owner must pair and trust the device, enable Developer Mode and **Settings → Developer → Enable UI Automation**, and sign WebDriverAgent with an appropriate team profile. WDA is accepted only over loopback and every run is leased to one device. Passwords, OTPs, Face ID, payment secrets, and destructive actions require a human checkpoint.

Read [`docs/qa-mode.md`](docs/qa-mode.md) before enabling the adapter.

## Optional iPhone companion

`iosClawCompanion/` is an experiment for viewing a redacted audit timeline on an iPhone. It does not control other apps and is not required for automation, pairing, approvals, or Mac logs. It receives only redacted `AuditStep` records over an encrypted, six-digit-paired MultipeerConnectivity session.

## Security and privacy boundaries

iosClaw is designed to keep execution context on the user’s Mac:

- Captures and OCR stay local; there is no hosted screen relay.
- Audit history, learned context, and flow packages are encrypted at rest.
- Secrets and run-only values are not stored in normal flow summaries or audit output.
- The runtime fails closed on missing sources, duplicate matches, changed state, or failed postconditions.
- It does not unlock devices, enter passwords or one-time codes, bypass Face ID/CAPTCHA, or silently perform purchases.

This is a safety boundary, not a guarantee that every third-party app will expose stable accessibility semantics. Review the threat model and policy details in [`docs/compiled-flow-registry-tech-prd.md`](docs/compiled-flow-registry-tech-prd.md).

## Development and tests

Run the Mac test suite from the repository root:

```sh
xcodebuild -project iosClawMac/iosClawMac.xcodeproj \
  -scheme iosClawMac \
  -destination 'platform=macOS' test
```

The tests cover policy gates, semantic flow compilation, redaction, learned-context persistence, WDA route translation, and deterministic replay against a mock controller. Hardware-dependent tests still require a connected device and explicit permissions.

Useful project documents:

- [`docs/problem-statement.md`](docs/problem-statement.md) — product boundary and non-goals.
- [`docs/iosclaw-architecture-plan.md`](docs/iosclaw-architecture-plan.md) — system architecture and adapters.
- [`docs/manual-record-replay.md`](docs/manual-record-replay.md) — recording model.
- [`docs/compiled-flow-registry-tech-prd.md`](docs/compiled-flow-registry-tech-prd.md) — compiler, policy, and persistence contract.
- [`docs/macos-modular-architecture.md`](docs/macos-modular-architecture.md) — Mac app module boundaries.

## Direct macOS releases

The project distributes macOS builds directly as universal, Developer ID-signed, Apple-notarized DMGs; the Mac App Store is out of scope because Accessibility-based cross-process input is not compatible with its sandbox requirements.

On a trusted release Mac, create the notary credential once and keep it in the login Keychain:

```sh
xcrun notarytool store-credentials iosclaw-notary
export IOSCLAW_TEAM_ID="YOUR_TEAM_ID"
bash scripts/release-macos.sh
```

Never commit signing certificates, private keys, provisioning profiles, notary credentials, or app-specific passwords. See [`docs/direct-release.md`](docs/direct-release.md).

## Contributing

Contributions are welcome, especially app adapters, semantic selector improvements, simulator coverage, policy tests, and documentation. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before opening a pull request. Please do not include real personal messages, credentials, screenshots, device identifiers, or provisioning material in issues, fixtures, or commits.

For security reports, follow [`SECURITY.md`](SECURITY.md) and avoid posting exploitable details publicly.

## License

Original iosClaw code is released under the [Apache License 2.0](LICENSE). The `qa-vendor/` directory contains optional upstream Appium/WebDriverAgent material with its own notices and licenses; see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md). Apple platform names, SDKs, and trademarks remain the property of Apple.
