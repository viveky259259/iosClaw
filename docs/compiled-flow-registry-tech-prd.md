# Technical PRD: Compiled Flow Registry and Deterministic Runtime

**Product:** iosClaw  
**Status:** Phase 0–1 vertical slice implemented  
**Owner:** iosClaw  
**Last updated:** 2026-09-05  
**Target:** Mac-hosted iPhone automation through iPhone Mirroring, Simulator, and optional developer adapters

### Implementation note

The current implementation provides the versioned linear IR subset, static
validator, in-memory bundled registry, recorded-flow-to-draft lowering,
per-step timings, and one coarse-grained local/MCP execution path. The active
catalog is intentionally limited to WhatsApp Business `app.open` and
`messaging.draft` on iPhone Mirroring. Package persistence, promotion,
quarantine automation, persistent capture/ROI recognition, enforced runtime
timeouts, interactive compiled-effect approval/resume, and broader app packs
remain later phases in this PRD.

## 1. Decision summary

Build a local **Compiled Flow Registry** that converts common tasks and user-taught demonstrations into versioned, declarative execution plans. A known request is resolved once, bound to runtime inputs, and executed locally as a deterministic state machine. The LLM is not involved in normal step-by-step execution.

Flows are data, not generated Swift or TypeScript. The product ships one runtime and three reusable layers:

1. **Universal primitives** — observe, resolve, tap, input, launch, scroll, wait, extract, assert, request approval.
2. **App capability packs** — semantic states, evidence, locators, transitions, and compatibility rules for an app or app family.
3. **Compiled flows** — parameterized graphs built from those capabilities, including built-in common flows and encrypted user-defined flows.

The governing rule is:

> Intelligence discovers once; the compiler generalizes once; the deterministic runtime reuses repeatedly.

## 2. Problem statement

iosClaw currently exposes safe semantic actions and can record/replay individual actions, but a task still tends to require one agent decision and one remote procedure call per primitive. Each primitive may independently recapture the screen, run full-frame OCR, dispatch input, wait, and recapture for verification. This creates avoidable latency and makes a repeated known task behave like a new exploration.

The system needs to transform one user request—for example, “Open WhatsApp and draft a message to Honey”—into one local flow execution that:

- recognizes the current live state;
- executes all known transitions without repeated LLM calls;
- derives coordinates only from the current observation;
- validates each effect before continuing;
- requests approval at the actual sensitive-effect boundary;
- records enough evidence to diagnose and repair failures;
- learns a reusable flow when the user teaches a new task.

The success metric is not raw click throughput. It is verified task completion with low tail latency and zero wrong-target actions.

## 3. Goals

### 3.1 Product goals

- Run common, previously compiled tasks without per-step intelligence.
- Let a user teach a task once through iosClaw and invoke it later using natural language or a saved-flow control.
- Parameterize variable values such as app, recipient, query, message, form values, or list item.
- Reuse common capability templates across multiple applications.
- Degrade safely when the UI, app version, language, source, or permissions change.
- Keep the iPhone companion optional and the default execution path local to the Mac.
- Provide enough trace and performance data to distinguish product latency from UI/device latency.

### 3.2 Engineering goals

- Use a versioned, declarative intermediate representation rather than generating application code per flow.
- Preserve existing semantic-target, fresh-state, postcondition, device-lease, and approval invariants.
- Perform at most one active run per device.
- Reuse a valid observation until input or a new frame invalidates it.
- Prefer condition-driven waits over fixed sleeps.
- Support signed bundled packs and encrypted local user flows using the same runtime.
- Quarantine failing versions instead of repeatedly executing a suspect plan.

## 4. Non-goals

- Guarantee automation of every iOS application or every screen.
- Bypass iOS, iPhone Mirroring, macOS privacy, Face ID, passcodes, CAPTCHA, DRM, or application security controls.
- Persist tap coordinates or replay raw pointer macros.
- Let an LLM directly dispatch device input or approve its own sensitive action.
- Require WebDriverAgent, provisioning, or an iPhone companion for consumer use.
- Build a multi-tenant cloud control plane in the first release.
- Compile flows into native machine code. UI observation and device response dominate runtime cost; native code generation would add complexity without removing the bottleneck.

## 5. Users and primary use cases

### 5.1 End user

The user wants repeated tasks to be fast and predictable:

- open an app;
- find and open an item or conversation;
- draft a message or post;
- fill a form;
- search and select a result;
- extract visible information;
- change a low-risk setting;
- replay a personally taught workflow.

### 5.2 QA engineer

The engineer wants reusable flows across Simulator and owned test devices:

- launch or reset an app;
- enter test data;
- navigate to a state;
- exercise gestures;
- assert text, controls, and state transitions;
- run a compatibility matrix across versions and device configurations.

### 5.3 Operations user

The user wants repeatable internal-app workflows with an App Intent or API preferred where available, and semantic UI automation used only for unsupported steps.

## 6. User experience

### 6.1 Known request

1. The user asks for a task.
2. iosClaw matches one compatible flow and displays the interpreted intent and bound inputs.
3. The local runtime acquires the device lease and classifies the current state.
4. It executes known transitions and shows progress by outcome, not by raw click.
5. If a sensitive effect is reached, iosClaw shows the exact effect and pauses for approval.
6. The runtime performs the approved effect, verifies its postcondition, and reports completion.

An LLM may help map natural language to a registered intent, but it does not choose each device action.

### 6.2 User-taught request

1. The user starts **Teach flow** and names the intended result.
2. Every device action is performed through iosClaw and recorded with before/after observations.
3. The compiler proposes parameters, states, locators, branches, postconditions, and effect policy.
4. The user reviews variable inputs and sensitive effects.
5. iosClaw replays the draft against fixtures or the live test source.
6. A validated version becomes active. An unvalidated version remains a draft and cannot run unattended.

### 6.3 Unknown or changed state

The runtime first tries declared recovery transitions. If none apply, it stops before input and offers one of:

- user-guided continuation;
- an explicitly authorized intelligence-assisted repair;
- cancellation.

A successful repair creates a candidate new flow version. It does not silently mutate the active version.

## 7. System architecture

```text
Natural-language request / saved-flow button / MCP call
                         |
                         v
              Intent Resolver + Binder
                         |
                         v
              Compiled Flow Registry
            /          |             \
 bundled flow     app capability    encrypted user
    packs              packs            flows
                         |
                         v
              Deterministic Runtime
     lease -> observe -> classify -> resolve -> act
               ^                         |
               |---- verify / recover ---|
                         |
                  Policy + Approval
                         |
                         v
               Device Adapter Interface
        Mirroring | Simulator/WDA | API/App Intent
```

### 7.1 Mechanism versus policy

**Mechanism** defines what the runtime can do: observe, classify, resolve, dispatch, wait, verify, and record.

**Policy** defines whether it may do it: allowed effect class, approval requirement, credential boundary, source capability, confidence floor, retry budget, and data-retention rule.

The runtime must never embed policy exceptions inside app-specific action code. App packs declare effects; the central policy engine decides whether execution may proceed.

### 7.2 Module boundaries

- **Intent Resolver:** maps an invocation to an intent ID and typed inputs. It has no device-input capability.
- **Registry:** selects a compatible active flow version. It is read-only during a run.
- **Compiler:** produces immutable candidate packages from templates or traces. It has no direct input capability.
- **Static Validator:** rejects unsafe, malformed, unbounded, or incompatible graphs.
- **Runtime:** executes one immutable plan against one leased device.
- **Semantic State Engine:** classifies observations and returns confidence plus evidence.
- **Target Resolver:** turns semantic locators into ephemeral targets scoped to one observation generation.
- **Policy Engine:** authorizes transitions and creates effect-bound approval requests.
- **Device Worker:** owns capture and input serialization for one device.
- **Trace Store:** records timings, decisions, redacted evidence, and outcomes.

## 8. Flow intermediate representation

The flow IR is a portable data contract interpreted by the local runtime. The initial encoding may be JSON or a Swift `Codable` representation persisted as encrypted data. A human-readable YAML form is useful for development and review but is not the canonical signed encoding.

### 8.1 Required top-level fields

```yaml
schema_version: 1
flow_id: messaging.draft
flow_version: 3
intent:
  name: messaging.draft
  examples:
    - "draft {{message}} to {{recipient}} in {{app}}"
inputs:
  app:       { type: app_ref, required: true }
  recipient: { type: string, required: true, privacy: private }
  message:   { type: secret_string, required: true, retention: run_only }
compatibility:
  adapters: [mirroring, wda]
  capabilities: [app.launch, collection.search, messaging.compose]
  locales: [en]
entry_states: [home, app_chat_list, app_conversation]
effect_summary: [navigate, draft]
states: {}
recovery: {}
validation: {}
provenance: {}
```

### 8.2 State contract

Every state must contain:

- a stable state ID unrelated to visible copy;
- positive evidence and, when needed, negative evidence;
- a minimum confidence and uniqueness rule;
- allowed transitions;
- an observation scope or region of interest where safe;
- compatible app-pack and schema versions.

State confidence is advisory. Safety-critical transitions still require their explicit evidence predicates to pass.

### 8.3 Transition contract

```yaml
states:
  chat_list:
    evidence:
      all: [role:chat_list, role:search_entry]
      app_identity: "{{app}}"
    transitions:
      - id: open_recipient
        primitive: search_and_select
        arguments:
          query: "{{recipient}}"
          target: { role: conversation_result, text: "{{recipient}}" }
        preconditions:
          - state_is: chat_list
          - unique_target: "{{recipient}}"
        postcondition:
          all:
            - role: message_composer
            - title_equals: "{{recipient}}"
        timeout_ms: 2500
        retry: { count: 1, only_if: observation_changed }
        effect: navigate
        next: conversation
```

Each transition must declare:

- one primitive or compound primitive;
- typed arguments;
- preconditions;
- one bounded timeout;
- one verifiable postcondition;
- an effect class;
- retry behavior;
- next state or terminal outcome.

Unbounded loops, implicit coordinate literals, and transitions without a postcondition are invalid.

### 8.4 Semantic locator cascade

Locators are evaluated in this order when supported by the active adapter:

1. stable accessibility identifier or App Intent/API identity;
2. accessibility role, label, value, and hierarchy;
3. exact normalized OCR text plus structural anchors;
4. approved local visual signature plus structural anchors;
5. user handoff or repair.

App packs may narrow this sequence but may not add a persistent-coordinate fallback. A resolved target contains an observation generation, source fingerprint, and bounds; it expires after any input, frame change, source change, or timeout.

## 9. Compiler

### 9.1 Inputs

The compiler accepts either:

- a built-in capability template plus app-pack bindings;
- a user-recorded semantic trace;
- a successful intelligence-assisted trace explicitly selected for learning;
- an existing flow plus a repair trace.

### 9.2 Compilation stages

1. **Trace normalization** — remove operational actions and retain only iosClaw device actions with before/after evidence.
2. **State canonicalization** — merge observations only when their required semantic evidence is compatible.
3. **Parameter inference** — replace demonstrated values with typed inputs where the values vary by invocation.
4. **Locator synthesis** — replace transient targets with semantic roles, labels, hierarchy, and stable landmarks.
5. **Transition synthesis** — choose the smallest shared primitive or compound primitive that expresses the outcome.
6. **Postcondition synthesis** — derive evidence for the intended state change, not just disappearance of the tapped label.
7. **Effect classification** — label navigation, read, draft, send, post, purchase, delete, authentication, and security effects.
8. **Recovery synthesis** — add only known, bounded branches such as dismissing a declared popup or returning to an entry state.
9. **Static validation** — apply the checks below.
10. **Fixture/live validation** — replay with representative variations.
11. **Packaging** — assign immutable version and provenance, encrypt user data, and sign bundled distributions.

### 9.3 Static validation rules

Compilation fails if:

- any device action bypasses an iosClaw primitive;
- a locator contains persistent actionable coordinates;
- a transition lacks a precondition, postcondition, effect class, timeout, or bounded retry policy;
- a graph has an unbounded cycle;
- an input type or retention policy is missing;
- a sensitive effect lacks an approval boundary;
- a credential, OTP, biometric, CAPTCHA, or payment secret is recorded;
- an adapter requirement is undeclared;
- an app-pack or primitive version cannot be resolved;
- a terminal success state has no task-level assertion.

### 9.4 No per-flow source-code generation

The compiler emits compact IR interpreted by a fixed runtime. New app support should usually require declarative evidence and capability bindings, not a new code path. Native runtime code is justified only for a genuinely new primitive, adapter capability, or performance-critical observation algorithm.

## 10. Registry

### 10.1 Package classes

| Class | Source | Storage | Trust | Update path |
| --- | --- | --- | --- | --- |
| Core primitive set | iosClaw release | app bundle | signed, read-only | application update |
| Bundled capability/flow pack | iosClaw release | app bundle/cache | signed | verified pack update |
| User flow | local teaching | encrypted Application Support | user-owned | new validated version |
| Candidate repair | local repair | encrypted quarantine | inactive | review and validation |

### 10.2 Selection key

The registry resolves a flow using:

- intent ID;
- typed input compatibility;
- app identity;
- active adapter capabilities;
- source type;
- locale and relevant accessibility/display configuration;
- flow and app-pack compatibility range;
- validation status;
- recent success and quarantine status.

There must be exactly one winning version. Ambiguous selection stops before device input.

### 10.3 Lifecycle

```text
Draft -> Statically valid -> Tested -> Validated -> Active
  |             |             |           |          |
  +---------- failure --------+-----------+------> Quarantined
                                                   |
                                                   +-> Repaired candidate
```

- **Draft:** editable; cannot execute effects outside teach mode.
- **Tested:** passed deterministic fixture checks.
- **Validated:** passed required live/configuration matrix.
- **Active:** selectable for normal execution.
- **Quarantined:** excluded from selection after a safety failure or failure-rate threshold.

Promotion always creates an immutable version. Rollback switches the active pointer; it does not rewrite history.

### 10.4 Local data model

Use SQLite metadata plus encrypted package blobs. Initial tables:

- `flow_definitions(flow_id, intent_id, owner, created_at)`
- `flow_versions(flow_id, version, status, ir_hash, package_ref, created_at)`
- `flow_compatibility(flow_id, version, adapter, app_id, locale, capability, constraint)`
- `app_packs(app_id, pack_version, status, signature, package_ref)`
- `validation_runs(flow_id, version, matrix_key, outcome, trace_id, duration_ms)`
- `runtime_stats(flow_id, version, window_start, attempts, completions, safety_stops, latency_histogram)`
- `quarantine_events(flow_id, version, reason, trace_id, created_at)`
- `active_versions(flow_id, selection_scope, version)`

Secrets and raw message/form values must not appear in indexable columns, logs, intent examples, or audit summaries.

## 11. Runtime execution

### 11.1 Run protocol

1. Resolve intent and bind typed inputs.
2. Select exactly one active compatible flow version.
3. Create a run snapshot containing the immutable IR hash and redacted input hash.
4. Acquire the exclusive device lease.
5. Validate permissions, source identity, adapter health, and manual-takeover state.
6. Obtain one observation and classify the entry state.
7. Execute transitions locally until terminal, approval, repair, cancellation, or failure.
8. Release the lease and commit the final trace.

### 11.2 Observation lease

An observation may be reused only while all are true:

- source and capture generation are unchanged;
- no device input has been dispatched;
- no frame-change signal has invalidated it;
- its age is below the state-specific limit;
- the next transition does not require stronger evidence.

Any input invalidates resolved targets immediately. Postcondition checking always uses an observation newer than the action.

### 11.3 Condition-driven wait

After input, the worker watches frame hashes or adapter events. OCR or accessibility parsing runs only when the frame changes or the timeout requires a final check. It first evaluates the expected region and fast recognition mode, then widens to full-frame accurate recognition only if needed.

Fixed sleeps are prohibited in compiled flows. A device adapter may use a minimal internal debounce only when required by the platform, and that delay must be measured and surfaced separately.

### 11.4 Approval binding

An approval request contains:

- flow ID and immutable version/hash;
- effect class;
- redacted source and target identity;
- exact user-visible effect summary, including recipient and content for a message send;
- current state fingerprint;
- expiration;
- single-use nonce.

Approval authorizes only that effect. Any state, target, content, flow version, source, or expiry change invalidates it.

### 11.5 Recovery

Recovery follows this order:

1. re-observe after a changed frame;
2. take one declared idempotent recovery transition;
3. return to a declared safe entry state, if allowed;
4. stop and request repair or user handoff.

The runtime does not improvise undeclared device actions. Total retries and elapsed time are bounded per run.

## 12. Initial reusable capabilities and flows

### 12.1 Universal primitives

- `app.launch`
- `screen.observe`
- `state.assert`
- `target.resolve`
- `target.tap`
- `text.replace`
- `keyboard.submit`
- `collection.search_and_select`
- `collection.scroll_until`
- `gesture.swipe`, `gesture.drag`, `gesture.long_press`, `gesture.pinch`
- `content.extract_visible`
- `condition.wait`
- `navigation.home`, `navigation.back`
- `approval.request`

### 12.2 Capability templates

- `app.open`
- `item.search_and_open`
- `form.fill`
- `messaging.open_conversation`
- `messaging.draft`
- `messaging.send`
- `content.find_and_extract`
- `settings.read`
- `settings.toggle`
- `commerce.find_item`
- `commerce.add_to_cart`
- `qa.enter_and_assert`

`messaging.send`, destructive settings, purchases, deletes, posts, and externally visible submissions always include a policy-controlled approval transition.

### 12.3 First vertical slice

Implement `app.open`, `messaging.open_conversation`, and `messaging.draft` first, then compose them into the reference WhatsApp task. Add `messaging.send` only after approval binding and post-send verification pass the safety test matrix.

## 13. App-type compatibility

| App/screen type | Expected support | Primary evidence | Required extension |
| --- | --- | --- | --- |
| Standard native lists and forms | High | accessibility tree or OCR + structure | generic capabilities |
| Messaging/social UI | Medium-high | app pack + text/role evidence | approval for send/post |
| Web views | Medium | accessibility where exposed; OCR fallback | web-view state definitions |
| Custom-drawn/icon-only UI | Limited | local visual signatures + anchors | validated app pack |
| Maps/canvases/games | Low for generic flows | visual model and domain-specific state | specialized primitive or handoff |
| Banking/authentication | Navigation/read only by default | strict app/state evidence | handoff for secrets, biometrics, transactions |
| Camera/DRM/protected surfaces | Unsupported when capture is unavailable | none | safe stop |
| Customer-owned QA builds | High with WDA | accessibility identifiers/tree | developer adapter and test entitlements |

The registry reports capabilities explicitly. It must never imply full-app support because one flow works.

## 14. Performance requirements

### 14.1 Dominant cost model

The hot-path cost is screen acquisition, image movement, OCR/accessibility parsing, device/UI response, and redundant round trips—not execution of the flow graph. Optimization must reduce captures, recognition scope, fixed waiting, and agent/runtime boundaries.

### 14.2 Budgets

Measured on a supported Apple Silicon Mac with a warm iosClaw process and connected source:

| Operation | Target |
| --- | --- |
| Registry resolve + input bind | P95 <= 50 ms |
| Local bridge command overhead | P95 <= 20 ms |
| Reuse stable observation | P95 <= 75 ms |
| Changed-frame ROI observation | P50 <= 350 ms, P95 <= 900 ms |
| Input dispatch after target resolution | P95 <= 150 ms |
| Known local transition, excluding app animation | P50 <= 500 ms |
| Five-transition warm flow, excluding human approval time | P50 <= 5 s, P95 <= 10 s |

The runtime must report device animation/wait time separately from capture, recognition, resolution, dispatch, bridge, and persistence time. A target is not accepted from averages alone; P50, P95, P99, failure rate, and sample count are required.

### 14.3 Performance controls

- persistent capture stream or change notification rather than repeated source enumeration;
- frame hash and observation cache;
- region-of-interest recognition for expected evidence;
- fast recognition first, accurate full-frame fallback;
- compound primitives executed in the worker;
- one preflight per input transaction;
- asynchronous, batched audit persistence off the interaction-critical path;
- no LLM or MCP round trip between known transitions.

## 15. Reliability and safety invariants

These are release-blocking:

1. No stored flow contains actionable coordinates.
2. A target is used only in the observation generation that produced it.
3. Each action has a proven precondition and a newer post-action observation.
4. Ambiguous state, flow, or target resolution stops before input.
5. One device has at most one active action lease.
6. Retries and cycles are statically and dynamically bounded.
7. Sensitive effects require a valid, effect-bound, single-use approval.
8. The LLM cannot call a device adapter or mint an approval.
9. Manual takeover, permission loss, source loss, or adapter health loss stops the run.
10. User secrets and entered content do not appear in normal logs, indexes, or tool responses.
11. Failed or suspect flow versions can be quarantined without an application release.
12. Built-in packages are signature-verified; user packages remain encrypted and device-local by default.

## 16. Observability

Each run records a redacted trace with:

- run, flow, version, app-pack, adapter, device class, and configuration IDs;
- state and transition IDs;
- confidence and evidence predicate outcomes, without raw sensitive content;
- time spent in capture, recognition, classification, resolution, input preflight, dispatch, wait, verification, bridge, and persistence;
- cache hit/miss and recognition mode;
- recovery attempts and stop reason;
- approval requested/approved/denied/expired without secret content;
- final task assertion and outcome.

Raw screenshots remain opt-in, encrypted artifacts with bounded retention. They are not required for the normal audit trail.

## 17. APIs

Extend the authenticated local bridge with coarse-grained operations:

- `flow.resolve(intent, inputs, source)` — dry-run selection and compatibility result; no input.
- `flow.run(flow_id | intent, inputs)` — start one deterministic run.
- `flow.status(run_id)` — state, progress, approval, or terminal result.
- `flow.cancel(run_id)` — bounded cancellation and lease release.
- `flow.list(filters)` — redacted metadata.
- `flow.teach.start(name, intent_schema?)`
- `flow.teach.stop()` — produce draft candidate.
- `flow.validate(flow_id, version, matrix)`
- `flow.promote(flow_id, version)` — explicit user/admin operation.
- `flow.quarantine(flow_id, version, reason)`

Approval responses are accepted only from the trusted interactive iosClaw UI
and are not exposed as an MCP operation. An agent may start a run and observe
that it is awaiting approval, but it cannot approve the effect on the user's
behalf.

Primitive APIs remain for teaching, diagnostics, and app-pack development. Normal agents should prefer `flow.run` for known tasks.

## 18. Failure handling

| Failure | Behavior |
| --- | --- |
| No compatible flow | Offer teach or explicitly authorized exploration; no input yet |
| More than one matching flow | Ask for disambiguation; no input |
| Entry state unknown | Try declared entry recovery, then stop |
| Missing/duplicate target | Stop or take one declared disambiguation branch |
| UI changes during action | Invalidate target and approval; re-observe within budget |
| Postcondition fails | Do not assume success; quarantine on safety-significant mismatch |
| Adapter/capture failure | Stop, release lease, preserve diagnostic timing |
| Permission revoked | Stop and point to permission remediation |
| Manual user input | Pause/cancel according to takeover policy; never race the user |
| App pack incompatible | Exclude flow during registry selection |
| Audit persistence slow | Buffer within a bounded queue; backpressure or safe stop before losing mandatory audit |

## 19. Technical alternatives

### Option A: LLM plans every step

- **Benefit:** lowest initial authoring effort and flexible on novel UI.
- **Cost:** repeated inference and capture round trips, nondeterministic behavior, higher privacy exposure, and weak latency tails.
- **Verdict:** retain only for opt-in discovery and repair.

### Option B: raw coordinate macro recorder

- **Benefit:** simple implementation and fast replay on an unchanged screen.
- **Cost:** fails after row reordering, banners, Dynamic Type, window resizing, localization, and app updates; can act on the wrong target.
- **Verdict:** reject because it violates the core safety invariant.

### Option C: generated source code per app or flow

- **Benefit:** compile-time type checks and arbitrary customization.
- **Cost:** code volume, build/sign/deploy lifecycle, security review surface, binary growth, and fragmentation. It does not materially reduce capture/OCR/UI latency.
- **Verdict:** reject as the default. Add runtime code only for shared primitives or adapters.

### Option D: declarative compiled graph interpreted locally

- **Benefit:** deterministic execution, bounded behavior, reusable primitives, fast selection, safe versioning, and data-only user flows.
- **Cost:** requires a precise IR, validator, app compatibility model, and fixture discipline.
- **Verdict:** recommended.

## 20. Validation plan

### 20.1 Correctness tests

- Parser/schema tests for all IR fields and version upgrades.
- Static rejection tests for coordinates, missing assertions, unbounded cycles, invalid effects, and missing approval gates.
- Property tests: no transition can dispatch after target-generation invalidation.
- Deterministic replay tests from fixed observation fixtures.
- Golden tests for compiler parameterization and state merging.
- Compatibility selection tests with conflicting and quarantined versions.

### 20.2 Safety and fault injection

Inject each fault immediately before dispatch and immediately after dispatch:

- row reorder or duplicate label;
- stale frame or changed source;
- popup/banner insertion;
- app switch or lock;
- permission removal;
- capture failure;
- OCR omission or false candidate;
- manual takeover;
- approval expiry or content mutation;
- audit store delay/failure;
- adapter disconnect;
- process restart during a run.

The required result is safe stop or declared recovery, never an unverified continuation.

### 20.3 Compatibility matrix

For each promoted app pack, test at minimum:

- supported app versions;
- light and dark appearance;
- two Dynamic Type sizes;
- supported locales;
- list reordering and off-screen target;
- notification/banner presence;
- compact and large device classes;
- Mirroring and WDA where both are declared.

### 20.4 Reference end-to-end scenario

For “Open WhatsApp and send Honey: I love you”:

1. Start from Home, WhatsApp Chats, and an existing conversation.
2. Change Honey's row position between runs.
3. Run 30 attempts per starting state without per-step LLM decisions.
4. Confirm the exact recipient and message are bound into one approval.
5. Mutate recipient, message, source, and screen after approval; each must invalidate approval.
6. Require zero wrong-recipient sends and at least 95% verified completion on the declared compatibility matrix before promotion.

### 20.5 Performance benchmark

- Record at least 100 warm runs and 30 cold runs per reference flow.
- Publish P50/P95/P99 per stage and end to end.
- Compare against the current primitive-by-primitive path using the same source and fixture.
- The compiled path must reduce full-frame recognitions and bridge calls by at least 60% for the reference flow.
- Reject an optimization if it improves median latency while materially worsening safety stops, P99, memory use, or capture reliability.

### 20.6 Rollout

1. Shadow mode: resolve and predict transitions without input.
2. Internal read/navigation flows.
3. Draft-only flows.
4. Approval-gated external effects on test accounts.
5. Small opt-in end-user cohort.
6. Broader pack distribution only after version-level telemetry clears the gates.

Automatic quarantine triggers should begin conservatively: any wrong-target indication, any approval-binding violation, or a sustained postcondition-failure increase over the pack's validated baseline.

## 21. Success metrics and release gates

### Product metrics

- percentage of known tasks completed without per-step intelligence;
- verified task completion rate by flow version and compatibility bucket;
- end-to-end P50/P95/P99 excluding human approval time;
- time from user request to first useful device action;
- repair frequency and successful repair promotion rate;
- user cancellations and approval denials.

### Safety metrics

- wrong-target action rate: **zero in validation and release-blocking in production**;
- stale-target rejection rate: 100% in fault injection;
- sensitive effects without valid approval: zero;
- unverified terminal success reports: zero;
- secret values in ordinary logs/tool responses: zero.

### MVP exit gates

- one end-to-end compiled flow API drives the reference messaging draft task;
- at least three entry states converge into the same task flow;
- no per-step LLM or MCP round trip;
- runtime and compiler tests cover every invariant in section 15;
- compiled flow meets the latency and 95% completion targets on its declared matrix;
- app update or safety failure can quarantine one version without rebuilding iosClaw.

## 22. Delivery plan

### Phase 0 — measurement and contracts

- Add per-stage monotonic timing and run IDs to the existing path.
- Define versioned IR, primitive ABI, effect taxonomy, and adapter capability contract.
- Add static validator and coordinate-literal rejection.

### Phase 1 — deterministic vertical slice

- Add registry metadata and immutable flow packages.
- Add one `flow.run` bridge call and local run status.
- Implement observation leases, condition waits, and compound primitives.
- Ship `app.open` and `messaging.draft` for the reference app pack.

### Phase 2 — teach and compile

- Compile current semantic recordings into parameterized draft IR.
- Add fixture validation, version promotion, rollback, and quarantine.
- Add user review for inferred parameters and effects.

### Phase 3 — reusable capability packs

- Add forms, list search, visible extraction, settings, and QA templates.
- Validate across representative native, web-view, and custom-drawn apps.
- Add local visual signatures only where text/accessibility evidence is insufficient.

### Phase 4 — repair and distribution

- Add opt-in intelligence-assisted repair producing inactive candidates.
- Sign and distribute bundled packs.
- Add privacy-preserving aggregate quality signals only with explicit opt-in.

## 23. Open questions

- Which exact adapter event can invalidate an observation without polling under iPhone Mirroring?
- What visual-signature representation provides acceptable icon-only precision within the local latency and storage budget?
- Which app/version fields can be reliably observed on the Mirroring path?
- What minimum fixture diversity predicts production compatibility for an app pack?
- Should user-flow intent matching remain fully local, or allow opt-in model selection when deterministic matching is ambiguous?

None of these block the Phase 1 vertical slice. Phase 1 must use conservative compatibility declarations and safe stops where evidence is unavailable.

## 24. Staff-engineering validation

### Problem and cost model

The design addresses the actual bottleneck: repeated capture, recognition, UI waiting, and agent/runtime boundaries. It does not claim that faster graph interpretation or native code generation will fix device latency.

### Invariants and failure domains

The plan preserves fresh semantic resolution, post-action evidence, exclusive device ownership, approval binding, secret handling, and bounded recovery. Capture, adapter, registry, compiler, policy, and persistence failures each have an explicit safe-stop behavior.

### Scalability

- **Across tasks:** parameters and capability templates prevent one flow per literal request.
- **Across apps:** app packs bind shared capabilities instead of forking the runtime.
- **Across devices:** immutable packages and adapter contracts keep device-specific behavior below the runtime; one lease per device avoids unsafe concurrency.
- **Across versions:** compatibility ranges, validation matrices, immutable promotion, rollback, and quarantine bound UI churn.
- **Across users:** encrypted user packages remain local; signed common packs are shareable without mixing private inputs.

The likely scaling limit is pack validation and UI churn, not registry lookup or graph execution. Operational investment should therefore prioritize fixtures, compatibility evidence, quarantine, and repair quality over distributed infrastructure.

### Recommendation

Proceed with Option D: a declarative compiled graph interpreted by one local runtime. Start with a narrow messaging-draft vertical slice, but implement the version, policy, measurement, and quarantine contracts from the beginning. Do not add native code generation, a graph database, or a cloud control plane unless measured requirements invalidate the local design.

### What would falsify this recommendation

Reconsider the architecture if measured trials show any of the following:

- semantic state and locator definitions require app-specific executable code for most supported screens;
- interpreted runtime overhead exceeds 10% of end-to-end latency after capture and wait costs are isolated;
- the reference flow cannot achieve zero wrong-target actions and at least 95% completion within a realistic compatibility bucket;
- local fixture and quarantine operations cannot contain app-version regressions;
- iPhone Mirroring fails to provide sufficiently fresh observations for safe postcondition validation.

Until such evidence exists, compiled declarative flows are the smallest architecture that satisfies speed, safety, reuse, and maintainability together.
