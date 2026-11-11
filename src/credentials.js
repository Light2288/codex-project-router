import { spawn } from "node:child_process";
import { RouterError } from "./errors.js";

export async function readKeychainCredential(
  reference,
  { signal, spawnProcess = spawn } = {},
) {
  if (signal?.aborted) throw new RouterError("CANCELLED");

  return new Promise((resolve, reject) => {
    let child;
    try {
      child = spawnProcess(
        "/usr/bin/security",
        [
          "find-generic-password",
          "-a", reference.account,
          "-s", reference.service,
          "-w", reference.keychainPath,
        ],
        { shell: false, stdio: ["ignore", "pipe", "pipe"] },
      );
    } catch {
      reject(new RouterError("CREDENTIAL_UNAVAILABLE"));
      return;
    }

    let stdoutBytes = 0;
    let stderrBytes = 0;
    const stdoutChunks = [];
    let failureCode;
    let settled = false;
    let timer;

    function stop(code) {
      if (settled || failureCode) return;
      failureCode = code;
      stdoutChunks.length = 0;
      clearTimeout(timer);
      try {
        // A hard stop keeps denied or stalled lookups from outliving cancellation.
        child.kill("SIGKILL");
      } catch {
        // A failed kill is not proof of cleanup; retain the fixed error until close.
      }
    }
    const onAbort = () => stop("CANCELLED");
    const onError = () => stop("CREDENTIAL_UNAVAILABLE");
    function onStdout(chunk) {
      if (failureCode) return;
      stdoutBytes += chunk.length;
      if (stdoutBytes > 16384) {
        stop("CREDENTIAL_UNAVAILABLE");
        return;
      }
      stdoutChunks.push(chunk);
    }
    function onStderr(chunk) {
      if (failureCode) return;
      stderrBytes += chunk.length;
      if (stderrBytes > 16384) stop("CREDENTIAL_UNAVAILABLE");
    }
    function onClose(code, terminationSignal) {
      settled = true;
      clearTimeout(timer);
      signal?.removeEventListener("abort", onAbort);
      child.removeListener("error", onError);
      child.removeListener("close", onClose);
      child.stdout.removeListener("data", onStdout);
      child.stdout.removeListener("error", onError);
      child.stderr.removeListener("data", onStderr);
      child.stderr.removeListener("error", onError);

      if (failureCode || code !== 0 || terminationSignal != null) {
        stdoutChunks.length = 0;
        reject(new RouterError(failureCode ?? "CREDENTIAL_UNAVAILABLE"));
        return;
      }

      const output = Buffer.concat(stdoutChunks, stdoutBytes);
      stdoutChunks.length = 0;
      const tokenLength = output.at(-1) === 10 ? output.length - 1 : output.length;
      if (
        tokenLength < 1 || tokenLength > 8192 ||
        output.subarray(0, tokenLength).some((byte) => byte < 33 || byte > 126)
      ) {
        reject(new RouterError("CREDENTIAL_UNAVAILABLE"));
        return;
      }
      resolve(output.toString("ascii", 0, tokenLength));
    }

    child.on("error", onError);
    child.once("close", onClose);
    child.stdout.on("data", onStdout);
    child.stdout.on("error", onError);
    child.stderr.on("data", onStderr);
    child.stderr.on("error", onError);
    timer = setTimeout(onError, 5000);
    signal?.addEventListener("abort", onAbort, { once: true });
    // An abort can happen inside the injected spawn call before listeners exist.
    if (signal?.aborted) onAbort();
  });
}
