# Direct macOS release

iosClaw is distributed directly as a Developer ID-signed and Apple-notarized
DMG. The Mac App Store is intentionally out of scope because the core product
requires Accessibility-based cross-process input, which is incompatible with
the App Sandbox required by the store.

## Release contract

A distributable artifact must pass every gate below:

1. All automated safety tests pass.
2. Xcode creates a universal `arm64` and `x86_64` archive.
3. The app uses the stable `com.iosclaw.mac` bundle identifier.
4. The app is signed with Developer ID Application, hardened runtime, and a
   secure timestamp.
5. The generated icon and privacy manifest are bundled.
6. The DMG is signed, accepted by Apple's notary service, and stapled.
7. Gatekeeper accepts the stapled DMG.
8. A SHA-256 checksum is published beside the DMG.

`scripts/release-macos.sh` enforces these gates and does not produce a normally
named public artifact when notarization is skipped.

Release signing is intentionally configured outside the public project files.
Set `IOSCLAW_TEAM_ID` to the Apple Developer Team ID and optionally set
`IOSCLAW_SIGNING_IDENTITY` to the Developer ID Application certificate SHA-1.
When the identity is omitted, the script selects the first installed Developer
ID Application identity. Signing material and team identifiers are never
committed to the repository.

## One-time notarization setup

Create a dedicated Keychain credential profile on the trusted release Mac:

```sh
xcrun notarytool store-credentials iosclaw-notary
```

Use either an App Store Connect API key or the Apple Account, team ID, and an
app-specific password requested by `notarytool`. Credentials remain in the
login Keychain and must not be committed to the repository.

## Create a release

Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`, then run:

```sh
export IOSCLAW_TEAM_ID="YOUR_TEAM_ID"
export IOSCLAW_SIGNING_IDENTITY="YOUR_DEVELOPER_ID_CERTIFICATE_SHA1" # optional
bash scripts/release-macos.sh
```

Artifacts and validation logs are written beneath `.build/releases/`. Upload
only the DMG that has a matching notarization result and no `UNNOTARIZED`
suffix.

For a local packaging rehearsal that never submits to Apple:

```sh
bash scripts/release-macos.sh --prepare-only
```

## Permission continuity

Public beta builds must use the same bundle identifier, team, and Developer ID
identity from the first tester build onward. The migration from existing
Apple Development builds can require one final Screen Recording and
Accessibility approval. Before distribution, test that approval survives an
upgrade between two consecutive Developer ID builds.

## Initial beta scope

- macOS 15 or later.
- Mac app only; the iPhone companion remains optional and unpublished.
- QA Mode is a developer preview.
- The public description must state that the initial WhatsApp Business flow
  opens the app and prepares a draft, stopping before Send.
