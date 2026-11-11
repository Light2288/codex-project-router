import http from "node:http";
import https from "node:https";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { configFingerprint } from "./config.js";
import { admitRequest } from "./admission.js";
import { identifyProject } from "./identity.js";
import { emitDiagnostic } from "./diagnostics.js";
import { collectRequestMetadata } from "./request-metadata.js";
import { RouterError, safeError } from "./errors.js";
import { readKeychainCredential } from "./credentials.js";
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
    credentialReader = readKeychainCredential,
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
        requestMetadata,
        operation,
        completed = false;
      const record = (event, status, errorCode) => {
        try {
          emitDiagnostic(diagnostics, {
            event,
            requestId,
            ...resolution,
            operation,
            requestMetadata,
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
        controller.abort();
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
      req.once("aborted", () => fail(new RouterError("CANCELLED")));
      req.once("error", () => {
        fail(new RouterError("CANCELLED"));
      });
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
        operation = admission.kind === "model"
          ? admission.upstreamPath.split("?")[0] === "/responses/compact"
            ? "compact"
            : "responses"
          : admission.kind;
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
        let authorization = req.headers.authorization,
          upstreamBaseUrl = config.upstreamBaseUrl;
        if (config.credentialRouting) {
          const globalCredential = await credentialReader(
            config.credentialRouting.globalCredential,
            { signal: controller.signal },
          );
          if (controller.signal.aborted || res.destroyed || completed) return;
          const callerToken = Buffer.from(authorization.slice(7)),
            expectedToken = Buffer.from(globalCredential);
          if (
            callerToken.length !== expectedToken.length ||
            !timingSafeEqual(callerToken, expectedToken)
          ) throw new RouterError("AUTH_INVALID");
        }
        if (admission.kind === "model" && config.observeRequestMetadata === true)
          requestMetadata = collectRequestMetadata(req.rawHeaders);
        resolution =
          admission.kind === "model"
            ? await identifyProject(req.rawHeaders, config, {
                signal: controller.signal,
                allowUnassignedTitle: operation === "responses",
              })
            : { source: "catalog" };
        if (controller.signal.aborted || res.destroyed || completed) return;
        if (config.credentialRouting && resolution.routeAlias !== undefined) {
          const targets = config.credentialRouting.routeTargets;
          if (!Object.hasOwn(targets, resolution.routeAlias))
            throw new RouterError("CREDENTIAL_UNMAPPED");
          const target = targets[resolution.routeAlias];
          upstreamBaseUrl = target.upstreamBaseUrl;
          const projectCredential = await credentialReader(
            target.credential,
            { signal: controller.signal },
          );
          if (controller.signal.aborted || res.destroyed || completed) return;
          authorization = `Bearer ${projectCredential}`;
        }
        const url = new URL(
          upstreamBaseUrl.replace(/\/$/, "") + admission.upstreamPath,
        );
        record("started");
        if (controller.signal.aborted || res.destroyed || completed) return;
        const headers = endToEnd(req.headers);
        if (config.credentialRouting) headers.authorization = authorization;
        headers.host = url.host;
        if (controller.signal.aborted || res.destroyed || completed) return;
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
