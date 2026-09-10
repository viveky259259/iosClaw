# Semantic Runtime Edge Cases

## Decision

Persistent learned context stores semantic identity and required screen state.
It never stores actionable coordinates. A coordinate exists only in a resolved
target from the current capture and expires when the capture changes.

## Execution invariants

1. A source must be selected and freshly captured before an action.
2. The capture must classify into the fact's required semantic state.
3. The requested label must have exactly one normalized live match.
4. Input uses that live match's bounds only.
5. Every input is followed by a new capture and post-action verification.

Any failed invariant stops the action. There is no coordinate fallback.

## Current generic states

| State | Evidence | Supported semantic action |
| --- | --- | --- |
| `chatList` | `Chats` and `Search` are visible | Open one uniquely named conversation |
| `conversation` | Composer/send evidence is visible | Focus a uniquely named control |
| `unknown` | No recognized stable state | Observation only; no learned action |

Declarative app packs extend this state vocabulary for forms, commerce,
settings, maps, and custom enterprise flows. They define state evidence and
postconditions; they do not add coordinate scripts.

## Failure handling

| Edge case | Required behavior |
| --- | --- |
| Row reorders, new messages, scrolling | Re-resolve live label; prior position is ignored |
| Duplicate contact/control labels | Stop and request disambiguation |
| OCR has no exact label match | Stop; never use fuzzy-coordinate fallback |
| State changed from chat list to conversation | Invalidate the old action token |
| Mirroring exposes internal/square surfaces | Prefer the named, phone-shaped candidate; require a fresh semantic match before input |
| Legacy coordinate fact | Keep encrypted for audit, but mark non-actionable until re-learned |
| Credentials, OTP, biometrics, payments | User handoff; never resolve an input action |

## Validation plan

The unit suite covers source selection, dynamic bound resolution, ambiguous
labels, wrong-state rejection, and legacy-coordinate rejection. Add fixture
runs for each app pack across list reordering, dark mode, Dynamic Type, ads,
scrolling, and version changes. The rollout gate is target-selection precision
and stale-action rejection, not raw task completion.
