#!/usr/bin/env node
import fs from "node:fs";
import net from "node:net";
import readline from "node:readline";
import path from "node:path";
import os from "node:os";

const configPath = process.env.IOSCLAW_BRIDGE_CONFIG
  ?? path.join(os.homedir(), "Library", "Application Support", "iosClaw", "agent-bridge.json");

const protocolVersion = 2;

function bridgeConfig() {
  try {
    const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
    if (Number(config.protocolVersion) !== protocolVersion) {
      throw new Error(`iosClaw bridge protocol mismatch. Expected ${protocolVersion}; restart the installed app and MCP server.`);
    }
    return config;
  } catch {
    throw new Error("iosClaw is not running or uses an incompatible bridge. Open the current /Applications/iosClaw.app first.");
  }
}

function bridgeCall(method, parameters = {}) {
  const config = bridgeConfig();
  const request = JSON.stringify({ protocolVersion, token: config.token, id: crypto.randomUUID(), method, parameters });
  return new Promise((resolve, reject) => {
    const socket = net.createConnection({ host: config.host, port: Number(config.port) });
    const chunks = [];
    socket.setTimeout(30_000);
    socket.on("connect", () => socket.end(request));
    socket.on("data", chunk => chunks.push(chunk));
    socket.on("end", () => {
      try {
        const response = JSON.parse(Buffer.concat(chunks).toString("utf8"));
        response.ok ? resolve(response.result) : reject(new Error(response.error));
      } catch (error) { reject(error); }
    });
    socket.on("timeout", () => socket.destroy(new Error("iosClaw bridge timed out")));
    socket.on("error", reject);
  });
}

const tools = [
  { name: "iosclaw_status", description: "Read iosClaw's local agent status and permissions.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_simulator_boot", description: "Boot iosClaw's default local iOS Simulator.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_simulator_open", description: "Open the local iOS Simulator through iosClaw.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_simulator_app_list", description: "List applications installed in the booted iOS Simulator through iosClaw. Returns stable display names and bundle identifiers without screen coordinates.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_simulator_app_launch", description: "Launch one installed app in the booted iOS Simulator through iosClaw using an exact display name or bundle identifier, then capture the resulting simulator screen.", inputSchema: { type: "object", required: ["name"], properties: { name: { type: "string" } } } },
  { name: "iosclaw_home", description: "Go to the Home Screen of the currently inspected iPhone Mirroring or Simulator source through iosClaw.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_spotlight", description: "Open Spotlight on the currently inspected iPhone Mirroring source through iosClaw.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_spotlight_open_top_hit", description: "Open Spotlight's selected app result only after iosClaw verifies the expected app label in a unique Top Hit or Apps section on the fresh capture.", inputSchema: { type: "object", required: ["expected_name"], properties: { expected_name: { type: "string" } } } },
  { name: "iosclaw_inspect", description: "Capture the selected iPhone Mirroring or Simulator screen through iosClaw.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_text_targets", description: "Read locally recognized visible text and normalized bounds from iosClaw's most recent capture. No screenshot bytes are returned.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_learned_list", description: "List encrypted learned facts as metadata only; no screenshots are returned.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_learned_add", description: "Save semantic identity for a live-screen-verified app icon or control. Pass the opaque target_id from iosclaw_text_targets when duplicate labels exist. iosClaw resolves geometry from each new capture; no coordinates are accepted.", inputSchema: { type: "object", required: ["name", "kind"], properties: { name: { type: "string" }, kind: { type: "string", enum: ["appIcon", "control", "screenLandmark"] }, target_id: { type: "string" }, confidence: { type: "number" } } } },
  { name: "iosclaw_learned_tap", description: "Tap a currently valid learned fact through iosClaw.", inputSchema: { type: "object", required: ["fact_id"], properties: { fact_id: { type: "string" } } } },
  { name: "iosclaw_tap_visible_text", description: "Tap one uniquely visible exact text label from a fresh iosClaw capture without persisting it. Use placement or the opaque target_id from iosclaw_text_targets to disambiguate duplicate labels; target IDs expire with the capture.", inputSchema: { type: "object", required: ["name"], properties: { name: { type: "string" }, target_id: { type: "string" }, placement: { type: "string", enum: ["top", "middle", "bottom"] } } } },
  { name: "iosclaw_input", description: "Enter text into a currently valid learned control through iosClaw.", inputSchema: { type: "object", required: ["control_id", "text"], properties: { control_id: { type: "string" }, text: { type: "string" } } } },
  { name: "iosclaw_input_visible_text", description: "Enter text into one uniquely visible exact text label from a fresh iosClaw capture without persisting the label. Use placement or the opaque target_id from iosclaw_text_targets to disambiguate duplicate labels; target IDs expire with the capture.", inputSchema: { type: "object", required: ["name", "text"], properties: { name: { type: "string" }, text: { type: "string" }, target_id: { type: "string" }, placement: { type: "string", enum: ["top", "middle", "bottom"] } } } },
  { name: "iosclaw_whatsapp_open_chat", description: "From WhatsApp's visible Chats screen, use its hardware-keyboard Find flow to open a named contact without persisting the contact or using pointer coordinates. Verifies the conversation title and Message composer afterward.", inputSchema: { type: "object", required: ["contact_name"], properties: { contact_name: { type: "string" } } } },
  { name: "iosclaw_compiled_flow_list", description: "List bundled compiled flows and encrypted persisted user drafts. Returns metadata only; run-time input values are never included.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_flow_resolve", description: "Resolve exactly one active compiled flow for a typed intent, inputs, and concrete source without sending device input.", inputSchema: { type: "object", required: ["intent"], properties: { intent: { type: "string" }, app: { type: "string" }, recipient: { type: "string" }, message: { type: "string" }, source: { type: "string", enum: ["iPhoneMirroring", "simulator"] } } } },
  { name: "iosclaw_flow_run", description: "Execute one known compiled flow locally as a verified state machine. Known transitions do not return to the agent between steps. The initial catalog supports app.open and messaging.draft for WhatsApp Business; it does not send the drafted message.", inputSchema: { type: "object", required: ["intent"], properties: { intent: { type: "string", enum: ["app.open", "messaging.draft"] }, app: { type: "string" }, recipient: { type: "string" }, message: { type: "string" } } } },
  { name: "iosclaw_flow_run_status", description: "Read the latest compiled-flow run result and per-step timings from the current iosClaw app session.", inputSchema: { type: "object", properties: { run_id: { type: "string" } } } },
  { name: "iosclaw_flow_compile_recorded", description: "Compile one saved semantic recording into a parameterized draft package. Entered values become required run-only inputs and are not copied into the compiled package.", inputSchema: { type: "object", properties: { flow_id: { type: "string" }, name: { type: "string" } }, anyOf: [{ required: ["flow_id"] }, { required: ["name"] }] } },
  { name: "iosclaw_flow_trace_recorded", description: "Return the redacted semantic trace for exactly one saved recording. It includes state evidence, targets, and value-free input declarations; entered values and coordinates are never returned.", inputSchema: { type: "object", properties: { flow_id: { type: "string" }, name: { type: "string" } }, anyOf: [{ required: ["flow_id"] }, { required: ["name"] }] } },
  { name: "iosclaw_flow_validate_trace", description: "Dry-run local validation of an agent-generated value-free semantic trace. Returns structured issues and a redacted compiled preview when ready; it never saves or executes a flow.", inputSchema: { type: "object", required: ["trace_json"], properties: { trace_json: { type: "string", maxLength: 48000 } } } },
  { name: "iosclaw_flow_compile_trace", description: "Validate, compile, and encrypt one agent-generated value-free semantic trace as a non-runnable draft. Pass trace_json from iosclaw_flow_trace_recorded or an equivalent schema-v1 trace. Trace JSON is limited to 48 KiB and must not contain values or coordinates.", inputSchema: { type: "object", required: ["trace_json"], properties: { trace_json: { type: "string", maxLength: 48000 } } } },
  { name: "iosclaw_flow_list", description: "List recorded flow metadata and redacted step summaries. Stored input values are never returned.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_flow_record_start", description: "Start recording manual semantic actions performed through iosClaw on the currently inspected source.", inputSchema: { type: "object", required: ["name"], properties: { name: { type: "string" } } } },
  { name: "iosclaw_flow_record_stop", description: "Stop and securely save the active manual action recording.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_flow_record_cancel", description: "Cancel and discard the active unsaved manual action recording.", inputSchema: { type: "object", properties: {} } },
  { name: "iosclaw_flow_replay", description: "Replay one recorded flow with fresh screen validation before every action. Set confirmed=true only after an explicit user request to run the flow.", inputSchema: { type: "object", required: ["confirmed"], properties: { flow_id: { type: "string" }, name: { type: "string" }, confirmed: { type: "boolean" } }, anyOf: [{ required: ["flow_id"] }, { required: ["name"] }] } },
  { name: "iosclaw_flow_replay_cancel", description: "Stop the currently running recorded-flow replay.", inputSchema: { type: "object", properties: {} } }
];

const toolToMethod = Object.fromEntries(tools.map(tool => [tool.name, tool.name.replace(/^iosclaw_/, "")]));
function respond(id, result) { process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id, result })}\n`); }
function fail(id, message) { process.stdout.write(`${JSON.stringify({ jsonrpc: "2.0", id, error: { code: -32000, message } })}\n`); }

const lines = readline.createInterface({ input: process.stdin, crlfDelay: Infinity });
for await (const line of lines) {
  if (!line.trim()) continue;
  let request;
  try { request = JSON.parse(line); } catch { continue; }
  if (request.method === "initialize") {
    respond(request.id, { protocolVersion: "2024-11-05", capabilities: { tools: {} }, serverInfo: { name: "iosclaw", version: "0.3.0" } });
  } else if (request.method === "tools/list") {
    respond(request.id, { tools });
  } else if (request.method === "tools/call") {
    try {
      const result = await bridgeCall(toolToMethod[request.params.name], Object.fromEntries(Object.entries(request.params.arguments ?? {}).map(([key, value]) => [key, String(value)])));
      respond(request.id, { content: [{ type: "text", text: JSON.stringify(result) }] });
    } catch (error) { fail(request.id, error.message); }
  }
}
