# iosClaw Problem Statement

## Problem

Apple does not provide an Android-style, system-wide automation or accessibility API that a normal end-user app can use to control every iPhone app. Existing approaches are either limited to one app, require developer tooling, depend on fragile screen coordinates, or ask an LLM to rediscover every action on every run. They are therefore too slow and unreliable for repeated personal automation and high-volume mobile QA.

iosClaw must provide a reliable way to operate visible iPhone apps from a user's Mac, within Apple's platform constraints.

The user should be able to demonstrate or request a flow once and reuse it later. A repeated run must understand the current screen, locate controls by meaning and surrounding state, execute deterministic local actions, and verify each resulting state. It must not assume that an app, contact, row, button, or text field remains at the same coordinate between runs.

## Product objective

Build a local-first iPhone automation runtime that:

- observes the current iPhone screen through iPhone Mirroring, with Simulator and developer-test adapters available where appropriate;
- exposes every device action through iosClaw rather than allowing an agent to bypass the product;
- converts user demonstrations and successful exploration into reusable semantic flows;
- reuses learned app, screen, control, and transition knowledge instead of invoking an LLM for known states;
- invokes intelligence only when a state is genuinely new, ambiguous, or broken;
- validates the live state before an action and verifies the expected state afterward;
- pauses for user approval before sending messages or performing other external, sensitive, or irreversible actions;
- keeps the iPhone companion optional—the Mac application must be sufficient for the core experience.

## Core invariant

A stored flow records intent and evidence, not screen positions.

For example, it may remember “find the conversation whose current visible label is `Honey` while on the WhatsApp Chats screen,” but it must never remember “tap Honey at `(x, y)`.” Coordinates may be calculated transiently from the current observation and discarded after the action.

## Reference acceptance scenario

Given a connected iPhone and a visible WhatsApp Business installation, the request:

> Open WhatsApp and send Honey: I love you

must be handled as follows:

1. iosClaw opens WhatsApp Business.
2. iosClaw proves that it is on the current Chats screen.
3. iosClaw finds and opens the live `Honey` conversation without a saved row position.
4. iosClaw enters `I love you` into the current message composer.
5. iosClaw shows the exact recipient and message and waits for user approval.
6. After approval, iosClaw sends the message and verifies the result from a fresh observation.

The scenario fails safely if any required state, recipient, composer, permission, connection, or post-action result cannot be verified.

## Out of scope for solving this problem

- Direct agent or desktop automation that clicks inside the mirrored iPhone outside iosClaw.
- Adding a one-off hardcoded path for every app or every changing screen layout.
- Treating OCR text presence alone as proof that an action succeeded.
- Requiring WebDriverAgent, provisioning, or an iPhone companion for the normal end-user path.
- Rebuilding infrastructure during a flow retry unless the failure demonstrates a missing reusable product capability.

## Success criteria

- Known flows run locally without an LLM deciding every step.
- Dynamic UI changes do not require new coordinates or code for each run.
- Every action is attributable to an iosClaw primitive and every transition is verified.
- Retries are bounded and recover from known states rather than triggering unrelated engineering work.
- Sensitive effects occur only after explicit user approval.
- The same semantic runtime can support many apps through shared primitives plus small app-specific state definitions when necessary.
