import http from "node:http";
import https from "node:https";
import { randomUUID } from "node:crypto";
import { configFingerprint } from "./config.js";
import { admitRequest } from "./admission.js";
import { identifyProject } from "./identity.js";
import { emitDiagnostic } from "./diagnostics.js";
import { RouterError, safeError } from "./errors.js";
const hop = new Set([
  "connection",
  "keep-alive",
  "proxy-authenticate",
  "proxy-authorization",
  "te",
  "trailer",
  "transfer-encoding",
  "upgrade",
]);
function endToEnd(headers) {
  const excluded = new Set([
    ...hop,
    ...String(headers.connection ?? "")
      .split(",")
      .map((s) => s.trim().toLowerCase()),
  ]);
  return Object.fromEntries(
    Object.entries(headers).filter(([key]) => !excluded.has(key.toLowerCase())),
  );
}
export function createProxy(
  config,
  {
    diagnostics = process.stderr,
    upstreamAgent,
    inactivityTimeoutMs = 300000,
  } = {},
) {
  const server = http.createServer(
    { maxHeaderSize: 65536 },
    async (req, res) => {
      const requestId = randomUUID(),
        started = performance.now(),
        controller = new AbortController();
      let outgoing,
        incoming,
        resolution,
        completed = false;
      const record = (event, status, errorCode) => {
        try {
          emitDiagnostic(diagnostics, {
            event,
            requestId,
            ...resolution,
            status,
            errorCode,
            elapsedMs: performance.now() - started,
          });
        } catch {
          outgoing?.destroy();
          incoming?.destroy();
          res.destroy(new RouterError("INTERNAL_ERROR"));
        }
      };
      const finish = (status, errorCode) => {
        if (completed) return;
        completed = true;
        record("completed", status, errorCode);
      };
      const fail = (error) => {
        if (completed) return;
        const safe = safeError(error);
        finish(safe.status, safe.code);
        outgoing?.destroy();
        incoming?.destroy();
        if (res.headersSent) {
          res.destroy();
          return;
        }
        if (!res.destroyed) {
          res.writeHead(safe.status, {
            "content-type": "application/json",
            connection: "close",
          });
          res.end(
            JSON.stringify({
              error: { code: safe.code, message: safe.message },
              requestId,
            }),
          );
        }
      };
      req.once("aborted", () => controller.abort());
      req.once("error", () => fail(new RouterError("CANCELLED")));
      res.once("error", () => {
        finish(499, "CANCELLED");
        controller.abort();
        outgoing?.destroy();
        incoming?.destroy();
      });
      res.once("finish", () => finish(res.statusCode));
      res.once("close", () => {
        if (!res.writableFinished) {
          // Destroying the upstream emits aborted synchronously. Record the
          // initiating client cancellation before teardown can misclassify it.
          finish(499, "CANCELLED");
          controller.abort();
          outgoing?.destroy();
          incoming?.destroy();
        }
      });
      try {
        const admission = admitRequest(req.method, req.url, req.rawHeaders);
        if (admission.kind === "health") {
          res.writeHead(200, { "content-type": "application/json" });
          res.end(
            JSON.stringify({
              service: "codex-project-router",
              schemaVersion: 1,
              configFingerprint: configFingerprint(config),
            }),
          );
          return;
        }
        resolution =
          admission.kind === "model"
            ? await identifyProject(req.rawHeaders, config, {
                signal: controller.signal,
              })
            : { source: "catalog" };
        if (controller.signal.aborted || res.destroyed) return;
        record("started");
        if (res.destroyed) return;
        const url = new URL(
          config.upstreamBaseUrl.replace(/\/$/, "") + admission.upstreamPath,
        );
        const headers = endToEnd(req.headers);
        headers.host = url.host;
        outgoing = https.request(
          url,
          { method: req.method, headers, agent: upstreamAgent },
          (reply) => {
            incoming = reply;
            reply.once("error", () => fail(new RouterError("UPSTREAM_FAILED")));
            reply.once("aborted", () =>
              fail(new RouterError("UPSTREAM_FAILED")),
            );
            if (res.destroyed) {
              reply.destroy();
              return;
            }
            res.writeHead(reply.statusCode, endToEnd(reply.headers));
            reply.pipe(res);
          },
        );
        outgoing.once("error", () => fail(new RouterError("UPSTREAM_FAILED")));
        outgoing.setTimeout(inactivityTimeoutMs, () =>
          fail(new RouterError("UPSTREAM_FAILED")),
        );
        req.pipe(outgoing);
      } catch (e) {
        if (!resolution && e instanceof RouterError)
          resolution = { threadId: e.threadId };
        fail(e);
      }
    },
  );
  server.on("clientError", (_error, socket) => {
    if (socket.writable)
      socket.end(
        "HTTP/1.1 400 Bad Request\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
      );
    else socket.destroy();
  });
  server.on("upgrade", (_req, socket) =>
    socket.end(
      "HTTP/1.1 426 Upgrade Required\r\nConnection: close\r\nContent-Length: 0\r\n\r\n",
    ),
  );
  return server;
}
