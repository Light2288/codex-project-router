import { realpath } from "node:fs/promises";
import { isAbsolute, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { isDeepStrictEqual } from "node:util";
import { UUID, readRouterConfigurationSource } from "./config.js";
import { createProxy } from "./proxy.js";
import { RouterError, safeError } from "./errors.js";
import { withConfigurationLock } from "./configuration-lock.js";
import { commitProjectAssignment, readProjectAssignmentState } from "./project-assignments.js";
export { withConfigurationLock as withRouterStartupLock } from "./configuration-lock.js";

const maxFrameBytes = 16384;
const maxRetainedBytes = 32768;
const token = value => typeof value === "string" && /^[a-f0-9]{64}$/.test(value);
const uuid = value => typeof value === "string" && UUID.test(value);
const exact = (value, keys) => value && typeof value === "object" && !Array.isArray(value) &&
  Object.keys(value).length === keys.length && keys.every(key => Object.hasOwn(value, key));
const contextValid = value => exact(value, ["configPath", "codexHome", "providerId", "listenPort"]) &&
  typeof value.configPath === "string" && isAbsolute(value.configPath) &&
  typeof value.codexHome === "string" && isAbsolute(value.codexHome) &&
  typeof value.providerId === "string" && /^[a-zA-Z0-9_-]+$/.test(value.providerId) &&
  Number.isInteger(value.listenPort) && value.listenPort >= 1 && value.listenPort <= 65535;

function commandFrom(frame, sessionId, assignmentsEnabled) {
  const command = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(frame));
  if (
    !command || typeof command !== "object" || Array.isArray(command) ||
    command.schemaVersion !== 1 || command.sessionId !== sessionId ||
    !uuid(command.requestId) ||
    !["get_mode", "set_mode", ...(assignmentsEnabled ? ["get_assignment", "set_assignment"] : [])].includes(command.action)
  ) throw new RouterError("CONFIG_INVALID");
  const keys = ["schemaVersion", "sessionId", "requestId", "action", ...({
    get_mode: [], set_mode: ["mode"],
    get_assignment: ["expectedContext", "projectId", "operationId"],
    set_assignment: ["expectedContext", "expectedSavedRevision", "expectedConfigurationIdentity",
      "expectedRunningRevision", "expectedCatalogRevision", "projectId", "accountId"],
  }[command.action])];
  if (
    !exact(command, keys) ||
    (command.action === "set_mode" && !["on", "off"].includes(command.mode)) ||
    (command.action.endsWith("assignment") && !contextValid(command.expectedContext)) ||
    (command.action === "get_assignment" &&
      (command.projectId !== null && !uuid(command.projectId) || command.operationId !== null && !uuid(command.operationId))) ||
    (command.action === "set_assignment" && (!uuid(command.projectId) ||
      command.accountId !== null && !uuid(command.accountId) ||
      ![command.expectedSavedRevision, command.expectedConfigurationIdentity,
        command.expectedRunningRevision, command.expectedCatalogRevision].every(token)))
  ) throw new RouterError("CONFIG_INVALID");
  return command;
}

export async function startManagedRouter({
  configPath, sessionId, input = process.stdin, output = process.stdout,
  diagnostics = process.stderr,
  commitAssignment = commitProjectAssignment, readAssignmentState = readProjectAssignmentState,
}) {
  let current, context, lastAttempt = null, assignmentsEnabled = false;
  let ready = false, enabled = true, blocked = false,
    pumping = false, retained = 0;
  const buffer = Buffer.alloc(maxFrameBytes);
  const discard = () => {};
  const closeControl = () => {
    if (!enabled) return;
    enabled = false;
    retained = 0;
    input.removeListener("readable", onReadable);
    output.removeListener("drain", onDrain);
    // Keep consuming an abandoned pipe so its writer cannot stall HTTP service.
    input.on("data", discard);
    input.resume();
  };
  const write = value => {
    const frame = JSON.stringify(value) + "\n";
    const frameBytes = Buffer.byteLength(frame);
    if (
      !enabled || output.destroyed || output.writableEnded ||
      frameBytes > maxFrameBytes || output.writableLength + frameBytes > maxRetainedBytes
    ) {
      closeControl();
      return;
    }
    try {
      if (!output.write(frame)) {
        blocked = true;
        input.pause();
      }
    } catch {
      closeControl();
    }
  };
  const readState = async (projectId, operationId) => {
    const state = await readAssignmentState({ configPath: context.configPath,
      expectedContext: context, projectId, operationId }, current);
    if (operationId !== null && lastAttempt?.operationId === operationId &&
      (projectId === null || lastAttempt.projectId === projectId)) {
      // An immutable intent establishes the attempted candidate, never its application.
      if (state.intent && lastAttempt.candidateRevision === null) {
        lastAttempt = { ...lastAttempt, beforeRevision: state.intent.beforeRevision,
          beforeIdentity: state.intent.beforeIdentity, candidateRevision: state.intent.candidateRevision,
          candidateIdentity: state.intent.candidateIdentity };
      }
      state.lastAttempt = { ...lastAttempt };
    }
    return state;
  };
  const execute = async command => {
    const envelope = { schemaVersion: 1, sessionId, requestId: command.requestId };
    if (command.action === "get_mode" || command.action === "set_mode") {
      if (command.action === "set_mode") current = Object.freeze({ ...current, mode: command.mode });
      write({ ...envelope, type: "mode", mode: current.mode });
      return;
    }
    if (command.action === "get_assignment") {
      if (!isDeepStrictEqual(command.expectedContext, context)) {
        write({ ...envelope, type: "assignment_result", outcome: "rejected",
          code: "ASSIGNMENT_CONFLICT", commit: null, state: null });
      } else {
        write({ ...envelope, type: "assignment_state",
          state: await readState(command.projectId, command.operationId) });
      }
      return;
    }
    let commit = null, outcome = "applied", code = null;
    try {
      // Saved tokens cannot authorize finishing a divergent runtime snapshot.
      // The writer independently binds these same tokens to fresh source under its lease.
      if (!isDeepStrictEqual(command.expectedContext, context) ||
        command.expectedSavedRevision !== current.configurationRevision ||
        command.expectedRunningRevision !== current.configurationRevision ||
        command.expectedConfigurationIdentity !== current.configurationIdentity ||
        lastAttempt?.operationId.toLowerCase() === command.requestId.toLowerCase())
        throw new RouterError("ASSIGNMENT_CONFLICT");
      const { schemaVersion: _schema, sessionId: _session, requestId, action: _action, ...change } = command;
      commit = await commitAssignment({ ...change, configPath: context.configPath, operationId: requestId }, {
        running: current, publish(next) { current = next; },
      });
    } catch (error) {
      code = error instanceof RouterError && ["ASSIGNMENT_INVALID", "ASSIGNMENT_CONFLICT",
        "ASSIGNMENT_UNAVAILABLE", "ASSIGNMENT_UNCERTAIN"].includes(error.code)
        ? error.code : "ASSIGNMENT_UNCERTAIN";
      outcome = code === "ASSIGNMENT_UNCERTAIN" ? "uncertain" : "rejected";
    }
    lastAttempt = { operationId: command.requestId, projectId: command.projectId, outcome, code,
      beforeRevision: commit?.beforeRevision ?? null, beforeIdentity: commit?.beforeIdentity ?? null,
      candidateRevision: commit?.candidateRevision ?? null, candidateIdentity: commit?.candidateIdentity ?? null };
    let state = null;
    try { state = await readState(command.projectId, command.requestId); }
    catch { /* Persistence outcome is established independently of optional state delivery. */ }
    write({ ...envelope, type: "assignment_result", outcome, code, commit, state });
  };
  const overflow = () => retained + input.readableLength > maxRetainedBytes;
  async function pump() {
    if (!enabled || !ready || blocked || pumping) return;
    pumping = true;
    try {
      while (enabled && !blocked) {
        if (overflow()) {
          closeControl();
          break;
        }
        const newline = buffer.subarray(0, retained).indexOf(0x0a);
        if (newline >= 0) {
          const command = commandFrom(buffer.subarray(0, newline), sessionId, assignmentsEnabled);
          buffer.copy(buffer, 0, newline + 1, retained);
          retained -= newline + 1;
          // Keep parsing paused until durability, publication and lock cleanup settle.
          await execute(command);
          continue;
        }
        if (retained === maxFrameBytes) {
          closeControl();
          break;
        }
        const size = Math.min(4096, maxFrameBytes - retained, input.readableLength);
        if (size === 0) break;
        const chunk = input.read(size);
        if (chunk === null) break;
        if (!Buffer.isBuffer(chunk) || chunk.length > size) {
          closeControl();
          break;
        }
        chunk.copy(buffer, retained);
        retained += chunk.length;
      }
    } catch {
      // Input is untrusted; neither payloads nor decoder/parser exceptions leave the channel.
      closeControl();
    } finally {
      pumping = false;
    }
  }
  function onReadable() {
    if (!ready || overflow()) closeControl();
    else pump();
  }
  function onDrain() {
    blocked = false;
    pump();
  }
  input.on("readable", onReadable);
  input.on("error", closeControl);
  input.on("end", closeControl);
  input.on("close", closeControl);
  output.on("error", closeControl);
  output.on("close", closeControl);
  output.on("drain", onDrain);
  if (input.readableLength > 0 || input.readableEnded || input.destroyed)
    closeControl();

  let diagnosticsAvailable = !diagnostics.destroyed && !diagnostics.writableEnded;
  const disableDiagnostics = () => { diagnosticsAvailable = false; };
  diagnostics.on("error", disableDiagnostics);
  diagnostics.on("close", disableDiagnostics);
  const managedDiagnostics = {
    write(record) {
      if (!diagnosticsAvailable) return false;
      try {
        return diagnostics.write(record);
      } catch {
        // Diagnostic delivery is optional; a lost sink must not stop forwarding.
        disableDiagnostics();
        return false;
      }
    },
  };

  let server;
  try {
    if (
      typeof configPath !== "string" || !isAbsolute(configPath) ||
      typeof sessionId !== "string" || !UUID.test(sessionId)
    ) throw new RouterError("CONFIG_INVALID");
    let actualPath;
    try { actualPath = await realpath(configPath); }
    catch { throw new RouterError("CONFIG_UNAVAILABLE"); }
    if (actualPath !== configPath) throw new RouterError("CONFIG_INVALID");
    await withConfigurationLock(actualPath, async (_config, lease) => {
      const source = await readRouterConfigurationSource(actualPath);
      if (source.setupState === "required") throw new RouterError("ACCOUNT_SETUP_REQUIRED");
      const config = source.config;
      current = Object.freeze({ config, configurationRevision: source.configurationRevision,
        configurationIdentity: source.configurationIdentity, mode: "off" });
      context = Object.freeze({ configPath: actualPath, codexHome: config.codexHome,
        providerId: config.providerId, listenPort: config.listenPort });
      assignmentsEnabled = config.schemaVersion === 2;
      await lease.assertUnchanged();
      server = createProxy(config, { diagnostics: managedDiagnostics, getRequestRoutingSnapshot: () => current });
      await new Promise((resolveListen, reject) => {
        const onError = () => reject(new RouterError("PROXY_NOT_READY"));
        server.once("error", onError);
        server.listen(config.listenPort, "127.0.0.1", () => {
          server.removeListener("error", onError);
          resolveListen();
        });
      });
    });
    const shutdown = () => {
      closeControl();
      input.unref?.();
      server.closeAllConnections();
      server.close();
    };
    process.once("SIGTERM", shutdown);
    process.once("SIGINT", shutdown);
    server.once("close", () => {
      closeControl();
      process.removeListener("SIGTERM", shutdown);
      process.removeListener("SIGINT", shutdown);
    });
    if (enabled) {
      ready = true;
      write({ schemaVersion: 1, type: "ready", sessionId,
        context, mode: current.mode,
        ...(assignmentsEnabled ? { capabilities: ["project_assignments_v1"] } : {}) });
    }
    return { server, closeControl };
  } catch (error) {
    closeControl();
    server?.closeAllConnections();
    server?.close();
    throw safeError(error);
  }
}

async function main(args) {
  if (
    process.versions.node.split(".")[0] !== "24" || args.length !== 4 ||
    args[0] !== "--config" || args[2] !== "--session"
  ) throw new RouterError("CONFIG_INVALID");
  await startManagedRouter({ configPath: args[1], sessionId: args[3] });
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url)
  main(process.argv.slice(2)).catch(error => {
    const safe = safeError(error);
    process.stderr.write(JSON.stringify({ error: { code: safe.code, message: safe.message } }) + "\n");
    process.stdin.unref?.();
    process.exitCode = 1;
  });
