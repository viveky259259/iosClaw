# iosClaw Architecture Plan

## Purpose

iosClaw is a Mac-hosted automation system for real iPhones. It runs reliable, reusable flows against visible iPhone apps, while using an LLM only to select flows, explore unfamiliar UI, and repair failures.

The core product is not an LLM clicker. It is a semantic state engine plus a safe deterministic flow runtime.

## Scope and constraints

- Initial audience: a single user or small team with a paired Mac and one or a few iPhones.
- iOS has no Android-style, public cross-app accessibility service. iPhone control must remain Mac-hosted through iPhone Mirroring or developer-test automation such as WebDriverAgent.
- The MVP is local-first. Cloud orchestration is optional and must not be required to run a flow.
- The iPhone companion is optional. The Mac-only path is the complete default MVP.
- The system must pause for sensitive or irreversible actions.

## Architecture

```text
Console: goals, teach/record, approvals, flow editor, run traces
                                |
                 Local API / optional remote command
                                v
Orchestrator: flow selection, flow runtime, policy engine, LLM fallback
                                |
                                v
Semantic state engine: observations -> UI roles -> canonical screen state
                                |
                                v
macOS device worker: device lease, capture, OCR/tree, input, waits
                |                    |                    |
        Mirroring adapter       WDA adapter       API/Shortcut adapter
                \____________________|____________________/
                                      v
                               Real iPhone apps
```

### Local runtime

- `iosclawd` is a local daemon with a TypeScript/Bun orchestration layer.
- A small Swift native bridge owns ScreenCaptureKit, Vision OCR, macOS input events, window control, and Keychain access.
- The bridge and orchestrator communicate over a local Unix socket using a typed action protocol.
- A device worker owns an exclusive action lease for one phone; no two runs may interact with the same phone concurrently.

### Optional iPhone companion audit channel

- The installable companion is an optional audit/pairing client, not a cross-app controller.
- It must never be a prerequisite for Mac-hosted execution, approvals, or local audit storage.
- It receives redacted, immutable `AuditStep` records from the Mac worker and persists a deduplicated local timeline on the iPhone.
- The first implementation uses encrypted `MultipeerConnectivity` with an explicit six-digit pairing code. This avoids an insecure local HTTP endpoint.
- Audit records exclude biometric data, passcodes, one-time codes, screenshots, and raw message content.
- The Mac bridge retries an audit event until the paired companion acknowledges it.

### Device adapters

All adapters implement `observe`, `tap`, `type`, `swipe`, `launch`, `wait`, `clipboard`, and capability reporting.

1. **iPhone Mirroring adapter** is the default consumer-safe adapter. It uses captured pixels, OCR, and macOS user-like input.
2. **WebDriverAgent adapter** is an optional developer/test adapter. It can expose accessibility elements and is preferred when available.
3. **API/Shortcut adapter** is preferred over UI automation whenever an official integration, App Intent, deep link, or Shortcut can safely complete the task.

## Semantic flow model

Flows are versioned declarative state graphs. They never store a sequence of absolute coordinates as their primary definition.

```yaml
flow: whatsapp.draft_message
inputs: [contact, message]

states:
  chat_list:
    evidence:
      app: WhatsApp
      required_roles: [chat_search, chat_list]
    transition:
      intent: find_contact
      action: { focus: chat_search, type: "{{contact}}" }
      expect: search_results

  search_results:
    evidence:
      required_roles: [result_list]
      contains_text: "{{contact}}"
    transition:
      intent: open_conversation
      action: { select_text: "{{contact}}" }
      expect: conversation
```

Each state defines:

- **Evidence:** app identity, required UI roles, text/structural cues, and a confidence threshold.
- **Intent:** desired semantic outcome rather than a physical action.
- **Resolver cascade:** accessibility element, then OCR/text and layout, then vision fallback.
- **Success assertion:** evidence of the intended next state.
- **Recovery policy:** known popup handling, retry once, then LLM or user handoff.

The executor may chain known transitions without an LLM round trip. It checks local state after each transition and stops whenever confidence is low.

## Teach and record mode

The recorder captures a semantic trace:

```text
observation before -> user or agent action -> observation after
       |                      |                       |
  canonical state        action intent            success state
```

The flow compiler:

1. Groups observations into canonical states.
2. Generalizes literal data into inputs, for example `Akash` to `{{contact}}`.
3. Replaces coordinates with UI roles and locator fallbacks.
4. Adds expected-state assertions and known branches.
5. Generates a draft flow package.
6. Replays it on a test account/device before promotion.

Successful LLM-led exploration can use the same pipeline. Failed flow versions are quarantined rather than retried blindly.

The first local implementation is documented in
[`manual-record-replay.md`](manual-record-replay.md). It records only actions
successfully dispatched through iosClaw and re-resolves every target from a
fresh capture plus stable screen landmarks before replay.

## Safety and privacy

- Allow read, navigation, and drafting by default.
- Require explicit approval for send, post, purchase, delete, account/security changes, or other externally visible effects.
- Stop for passwords, one-time codes, Face ID, CAPTCHA, banking, and DRM-protected content.
- Pause if the user manually takes over the phone.
- Store artifacts locally and encrypted; keep secrets in Keychain.
- Do not upload screens, OCR, or flows to a cloud model/service without explicit opt-in and redaction.

## Data model

Use SQLite for the local MVP.

- `devices`: capabilities, connection health, ownership lease.
- `flows`, `flow_versions`: signed/declarative workflow packages.
- `screen_states`: canonical states and evidence rules.
- `runs`, `steps`: immutable audit trail.
- `artifacts`: encrypted screenshots, OCR, and UI-tree snapshots.
- `approvals`: requested effect, decision, approver, expiration.

No graph database is required initially; the flow graph is stored as JSON/YAML with a relational index.

## Performance targets

- Action dispatch P50: under 200 ms.
- No fixed sleeps; use an expected-state wait with a timeout.
- Keep device connections and WDA sessions warm.
- Cache current OCR/UI-tree results while the screen is stable.
- Prefer compound local primitives such as `search_and_select`, `fill_form`, and `scroll_until_found`.
- Call an LLM only for flow selection, teaching, or uncertain/failed states.

## Delivery phases

### MVP

- Local Mac daemon and basic console.
- iPhone Mirroring adapter, screen capture, OCR, typed input, and condition waits.
- Flow DSL/runtime, approvals, trace logging, and teach mode.
- A small set of low-risk flows: open app, search, copy visible text, draft a message, save a note.
- No iPhone companion installation or pairing requirement.

### Current implementation status

- Implemented: a Mac SwiftUI observation app that discovers the iPhone Mirroring window, gates capture on Screen Recording permission, performs local OCR, and writes an AES-GCM-encrypted local audit log using a Keychain-held key.
- Intentionally deferred: input injection, LLM planning, deterministic flow execution, and background scheduling. These require a separately validated action policy after the observation path is dependable.

### V1

- WebDriverAgent adapter.
- Semantic locator resolver and replay validator.
- Versioned flow packages, test fixtures, and trace review UI.

### V2

- Optional encrypted control plane for schedules, signed flow sharing, and remote task submission to user-owned Mac workers.
- Multi-device queueing; one device worker still owns one phone at a time.

## Success metrics

- Completion rate for verified flows.
- Median task duration and actions per task.
- Recovery success rate after unexpected UI changes.
- Percentage of runs completed without an LLM action decision.
- False-positive state match rate.
- Approval denial rate and policy-stop correctness.

## Key risks

- UI churn and missing accessibility labels: use semantic evidence, multiple resolver strategies, validation, and quarantine.
- Sensitive actions: enforce effect-level approval independently of the LLM.
- iPhone/Mac platform restrictions: treat Mirroring as the baseline and WDA as an optional test/developer backend.
- Privacy leakage: local-first artifacts, encrypted storage, opt-in model sharing, and redaction.
- Premature cloud complexity: defer multi-tenant/cloud control-plane work until local execution is dependable.

## Related decision records

- [Technical use-case validation](technical-use-case-validation.md)
- [Compiled Flow Registry technical PRD](compiled-flow-registry-tech-prd.md)
- [Agent-Generated Automations technical PRD](agent-generated-automations-tech-prd.md)
