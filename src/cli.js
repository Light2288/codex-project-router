import { loadRouterConfig } from "./config.js";
import { createProxy } from "./proxy.js";
import { activate, rollback, status } from "./activation.js";
import { RouterError, safeError } from "./errors.js";
function printError(error) {
  const e = safeError(error);
  process.stderr.write(
    JSON.stringify({ error: { code: e.code, message: e.message } }) + "\n",
  );
  process.exitCode = 1;
}
async function main(args) {
  if (args.length === 1 && args[0] === "--help") {
    process.stdout.write(
      "Usage: node --use-system-ca src/cli.js <serve|status|activate|rollback> --config <private-json-path>\n",
    );
    return;
  }
  if (
    process.versions.node.split(".")[0] !== "24" ||
    args.length !== 3 ||
    args[1] !== "--config" ||
    !["serve", "status", "activate", "rollback"].includes(args[0])
  )
    throw new RouterError("CONFIG_INVALID");
  const [command, , path] = args;
  if (command !== "serve") {
    const result = await { activate, rollback, status }[command](path);
    process.stdout.write(JSON.stringify(result) + "\n");
    return;
  }
  const config = await loadRouterConfig(path),
    server = createProxy(config);
  await new Promise((resolve, reject) => {
    server.once("error", () => reject(new RouterError("PROXY_NOT_READY")));
    server.listen(config.listenPort, "127.0.0.1", resolve);
  });
  const shutdown = () => {
    server.closeAllConnections();
    server.close();
  };
  process.once("SIGTERM", shutdown);
  process.once("SIGINT", shutdown);
  process.stdout.write(
    JSON.stringify({
      state: "listening",
      host: "127.0.0.1",
      port: config.listenPort,
    }) + "\n",
  );
}
main(process.argv.slice(2)).catch(printError);
