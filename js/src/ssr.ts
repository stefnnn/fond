import { renderToString } from "react-dom/server";
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import type { ComponentModule } from "./app.js";
import { renderPageElement } from "./element.js";
import { setPage, type PagePayload } from "./store.js";

export interface SsrServerOptions {
  resolve: (component: string) => Promise<ComponentModule> | ComponentModule;
  port?: number;
  host?: string;
}

interface RenderRequest {
  component: string;
  props: unknown;
  url: string;
  version?: string;
  shared?: unknown;
}

const MAX_BODY_BYTES = 10 * 1024 * 1024;

function sendJson(res: ServerResponse, status: number, body: unknown): void {
  const payload = JSON.stringify(body);
  res.writeHead(status, { "content-type": "application/json" });
  res.end(payload);
}

function readBody(req: IncomingMessage): Promise<string> {
  return new Promise((resolve, reject) => {
    let bytes = 0;
    const chunks: Buffer[] = [];
    req.on("data", (chunk: Buffer) => {
      bytes += chunk.length;
      if (bytes > MAX_BODY_BYTES) {
        reject(new Error("body too large"));
        req.destroy();
        return;
      }
      chunks.push(chunk);
    });
    req.on("end", () => resolve(Buffer.concat(chunks).toString("utf8")));
    req.on("error", reject);
  });
}

function isRenderRequest(value: unknown): value is RenderRequest {
  if (typeof value !== "object" || value === null) return false;
  const record = value as Record<string, unknown>;
  return typeof record.component === "string" && typeof record.url === "string";
}

async function handleRender(
  req: IncomingMessage,
  res: ServerResponse,
  resolve: SsrServerOptions["resolve"],
): Promise<void> {
  let raw: string;
  try {
    raw = await readBody(req);
  } catch {
    sendJson(res, 400, { error: "request body too large" });
    return;
  }

  let parsed: unknown;
  try {
    parsed = JSON.parse(raw);
  } catch {
    sendJson(res, 400, { error: "malformed JSON body" });
    return;
  }

  if (!isRenderRequest(parsed)) {
    sendJson(res, 400, { error: "expected { component, props, url }" });
    return;
  }

  try {
    const mod = await resolve(parsed.component);
    const page: PagePayload = {
      component: parsed.component,
      props: parsed.props,
      url: parsed.url,
      version: parsed.version ?? "",
      shared: parsed.shared,
    };
    // Pages read via the pinned PageContext (see element.ts), with the live
    // store as a fallback — seed both. renderToString is synchronous, so
    // there's no concurrency hazard in setting the store here.
    setPage(page);
    const html = renderToString(renderPageElement(mod, page));
    sendJson(res, 200, { html });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    sendJson(res, 500, { error: message });
  }
}

export function createSsrServer(options: SsrServerOptions): import("node:http").Server {
  const { resolve, port = 13714, host = "127.0.0.1" } = options;

  const server = createServer((req, res) => {
    if (req.method === "GET" && req.url === "/health") {
      sendJson(res, 200, { ok: true });
      return;
    }

    if (req.method === "POST" && req.url === "/render") {
      handleRender(req, res, resolve).catch((err) => {
        const message = err instanceof Error ? err.message : String(err);
        sendJson(res, 500, { error: message });
      });
      return;
    }

    sendJson(res, 404, { error: "not found" });
  });

  server.listen(port, host, () => {
    const address = server.address();
    const actualPort = typeof address === "object" && address ? address.port : port;
    console.log(`fond ssr listening on ${host}:${actualPort}`);
  });

  return server;
}
