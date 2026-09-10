# Manual semantic record and replay

## Goal

Let a user start a recording, perform actions through iosClaw, save the flow,
and later ask iosClaw to perform the same flow without an LLM choosing every
action.

## What is recorded

Only successful device-input actions dispatched by iosClaw are recorded:

- tap a live learned target;
- replace text in a live learned control;
- go to the Home Screen.

Each step stores the action intent, semantic target name and type, required
screen state, stable surrounding text landmarks, and screen source. It never
stores tap coordinates. Text values required for deterministic replay are kept
only in the encrypted flow store and are excluded from audit events and agent
list responses.

Operational actions such as opening Simulator, changing permissions, inspecting
a screen, or opening iPhone Mirroring are not part of a device flow.

## Replay invariant

Before every replayed action, iosClaw must obtain a fresh capture and prove:

1. the active source is the source used during recording;
2. the expected semantic state is visible;
3. generic app screens contain at least 60% of the recorded stable landmarks;
4. exactly one current OCR label matches the target name;
5. Accessibility permission is still active.

The tap point comes only from that fresh OCR result. A failed proof stops the
flow before input is sent. There is no coordinate, partial-label, or LLM
fallback.

## User flow

1. Open iPhone Mirroring or Simulator and inspect the visible screen.
2. Open **Record & Replay** and choose **Start recording**.
3. Give the flow a clear name.
4. Keep recording active. Use **Tap** or **Input** from Learned Context, or use
   **Go to Home Screen** in the sidebar.
5. Return to **Record & Replay** and choose **Stop & save**.
6. Later, choose **Replay**, review the warning, and confirm.

An agent can use the local iosClaw bridge to start/stop recording and list
redacted flows. Replay requires `confirmed=true`, which clients may provide only
after an explicit user request naming the flow.

## Failure handling

- Changed source: stop.
- Capture or OCR failure: stop.
- Wrong state or insufficient landmarks: stop.
- Missing or duplicate target label: stop.
- Missing encrypted input value: stop.
- Permission loss: stop.
- User chooses Stop: cancel the remaining steps.

Every stop is written to the local audit without screenshots or input values.

## Current boundary

The generic understanding layer works on screens with readable text and at
least two stable surrounding labels. Icon-only canvases, games, camera views,
and controls without visible text require an app pack, accessibility-tree
integration, or a locally stored visual embedding before they can be safely
recorded.
