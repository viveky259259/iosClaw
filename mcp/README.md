# iosClaw MCP bridge

Open `/Applications/iosClaw.app` first. It starts an authenticated local
bridge and writes a user-private connection file at
`~/Library/Application Support/iosClaw/agent-bridge.json`.

Learned facts retain semantic identity and required screen state only. The bridge
does not accept or return action coordinates; each tap resolves its geometry
from a current, uniquely matching capture.

Register this MCP server with an agent:

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

The versioned, loopback-only server exposes only iosClaw-owned actions: boot/open Simulator, go Home, search and open a verified Spotlight top hit, inspect,
save a learned fact, tap a currently valid learned fact, and input text into a
currently valid learned control. It never returns screenshots and records input
control names rather than entered values in the app audit.

It also exposes manual semantic recording and replay:

1. Inspect a source and call `iosclaw_flow_record_start` with a name.
2. Perform normal `iosclaw_learned_tap`, `iosclaw_input`, or Home actions in
   iosClaw. Successful actions are appended to the recording.
3. Call `iosclaw_flow_record_stop` to encrypt and save the flow locally.
4. Use `iosclaw_flow_list` to find it later. Step summaries are redacted.
5. After the user explicitly asks to run it, call `iosclaw_flow_replay` with
   its id or unique name and `confirmed: true`.

Replay captures and validates a fresh semantic state before every action. It
stops on a missing source, changed state, missing label, or duplicate label.
Mutating agent calls perform a fresh inspection and do not return success until
iosClaw captures and verifies the visible result. Recorded coordinates are never stored. Input values are stored only inside the
encrypted flow file and are never returned by the list tool or written to audit.

## Compiled flows

Compiled flows execute a complete known task inside iosClaw without returning
to an agent between transitions:

1. Use `iosclaw_compiled_flow_list` to inspect bundled active flows and draft
   candidates derived from saved recordings.
2. Use `iosclaw_flow_resolve` to check that one flow matches the intent, app,
   required inputs, and source without sending input.
3. Use `iosclaw_flow_run` once. The local runtime captures, validates, executes,
   and verifies every declared transition before returning one run result.
4. Use `iosclaw_flow_run_status` to retrieve the latest redacted run and its
   per-step timings.

The initial active catalog includes `app.open` and
`messaging.draft` for WhatsApp Business on iPhone Mirroring. Drafting stops
before Send. Sensitive compiled effects are statically required to declare an
approval gate, and the agent bridge refuses to execute such a step; approval
can only come from iosClaw's interactive UI.

`iosclaw_flow_compile_recorded` lowers a saved semantic recording into a draft
compiled package. Recorded input values are replaced by required run-only input
slots. The encrypted draft persists across app restarts, but remains inactive
until the validation and promotion lifecycle is implemented.

`iosclaw_flow_trace_recorded` returns the same value-free semantic trace used
by the compiler. It may include semantic state evidence, target names, and
stable landmarks, but never input values or coordinates. Agents should use this
trace as the authoring boundary for automation generation rather than treating
the recording as a pointer macro.

`iosclaw_flow_compile_trace` accepts that same schema-v1, value-free trace from
an agent (or a revised version of a recorded trace), validates it locally, and
persists the resulting draft with a dedicated encryption key. It accepts no
coordinates and no input values, is bounded to 48 KiB, and cannot execute or
promote the draft.

Agents should call `iosclaw_flow_validate_trace` first. It never changes local
state: it returns a structured validation result and, when valid, a redacted
compiled preview. That makes repair a bounded compile/validate loop rather than
a series of unverified device actions.
