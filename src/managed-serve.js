import { realpath } from "node:fs/promises";
import { isAbsolute, resolve } from "node:path";
import { pathToFileURL } from "node:url";
import { loadRouterConfig, UUID } from "./config.js";
import { createProxy } from "./proxy.js";
import { RouterError, safeError } from "./errors.js";

const maxFrameBytes = 16384;
const maxRetainedBytes = 32768;

function commandFrom(frame, sessionId) {
  const command = JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(frame));
  if (
    !command || typeof command !== "object" || Array.isArray(command) ||
    command.schemaVersion !== 1 || command.sessionId !== sessionId ||
    typeof command.requestId !== "string" || !UUID.test(command.requestId) ||
    !["get_mode", "set_mode"].includes(command.action)
  ) throw new RouterError("CONFIG_INVALID");
  const keys = command.action === "get_mode"
    ? ["schemaVersion", "sessionId", "requestId", "action"]
    : ["schemaVersion", "sessionId", "requestId", "action", "mode"];
  if (
    Object.keys(command).length !== keys.length ||
    Object.keys(command).some(key => !keys.includes(key)) ||
    (command.action === "set_mode" && !["on", "off"].includes(command.mode))
  ) throw new RouterError("CONFIG_INVALID");
  return command;
}

export async function startManagedRouter({
  configPath, sessionId, input = process.stdin, output = process.stdout,
  diagnostics = process.stderr,
}) {
  let mode = "off", ready = false, enabled = true, blocked = false,
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
    if (
      !enabled || output.destroyed || output.writableEnded ||
      output.writableLength + Buffer.byteLength(frame) > maxRetainedBytes
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
  const overflow = () => retained + input.readableLength > maxRetainedBytes;
  function pump() {
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
          const command = commandFrom(buffer.subarray(0, newline), sessionId);
          buffer.copy(buffer, 0, newline + 1, retained);
          retained -= newline + 1;
          if (command.action === "set_mode") mode = command.mode;
          write({ schemaVersion: 1, type: "mode", sessionId,
            requestId: command.requestId, mode });
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
    const config = await loadRouterConfig(actualPath);
    server = createProxy(config, { diagnostics: managedDiagnostics, getProjectRoutingMode: () => mode });
    await new Promise((resolveListen, reject) => {
      const onError = () => reject(new RouterError("PROXY_NOT_READY"));
      server.once("error", onError);
      server.listen(config.listenPort, "127.0.0.1", () => {
        server.removeListener("error", onError);
        resolveListen();
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
        context: { configPath: actualPath, codexHome: config.codexHome,
          providerId: config.providerId, listenPort: config.listenPort }, mode });
    }
    return { server, closeControl };
  } catch (error) {
    closeControl();
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
