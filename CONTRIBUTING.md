# Contributing to iosClaw

Thanks for helping make iPhone automation safer and more dependable. The project is early alpha, so small, focused changes are easiest to review.

## Before you start

- Read the [problem statement](docs/problem-statement.md) and the [architecture plan](docs/iosclaw-architecture-plan.md).
- Check existing issues and documentation before opening a new proposal.
- Keep changes scoped to one behavior, adapter, test, or documentation improvement.

## Local development

Open `iosClawMac/iosClawMac.xcodeproj` in Xcode and run the `iosClawMac` scheme on **My Mac**. The default path uses iPhone Mirroring or an iOS Simulator and does not require the optional companion or QA adapter.

Run the automated Mac tests from the repository root:

```sh
xcodebuild -project iosClawMac/iosClawMac.xcodeproj \
  -scheme iosClawMac \
  -destination 'platform=macOS' test
```

If you change the MCP bridge, validate the Node entry point with a current LTS Node release and update [`mcp/README.md`](mcp/README.md) when the tool contract changes.

## Design and safety expectations

- Prefer semantic selectors and fresh state evidence over coordinates.
- Add a postcondition for every mutating action.
- Keep secrets, entered values, screenshots, and device identifiers out of fixtures, logs, examples, and pull requests.
- Preserve the fail-closed behavior for ambiguity, missing permissions, changed state, and failed verification.
- Do not add flows that enter passwords, one-time codes, Face ID, payment secrets, or destructive actions automatically.
- Keep WebDriverAgent/Appium changes isolated to the optional developer QA path.

## Pull requests

Describe the user-visible behavior, implementation boundary, and tests run. Include screenshots only when they contain synthetic or redacted data. For UI changes, include the affected screen size and confirm keyboard focus and reduced-motion behavior.

Maintainers may request a follow-up test, documentation update, or threat-model note before merging. By contributing, you agree that your contribution is licensed under the Apache License 2.0 in this repository.
