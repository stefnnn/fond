// @vitest-environment node
import type { AddressInfo } from "node:net";
import { createElement } from "react";
import { afterEach, describe, expect, it } from "vitest";
import { createSsrServer } from "./ssr.js";
import type { ComponentModule } from "./app.js";
import { usePageProps } from "./hooks.js";

function OrdersIndex({ totalCount }: { totalCount: number }) {
  return createElement("div", null, `orders:${totalCount}`);
}

function StorePage() {
  const { label } = usePageProps<{ label: string }>("store/page");
  return createElement("span", null, `from-store:${label}`);
}

let server: ReturnType<typeof createSsrServer>;
let baseUrl: string;

async function start(
  resolve: (component: string) => Promise<ComponentModule> | ComponentModule,
): Promise<void> {
  server = createSsrServer({ resolve, port: 0, host: "127.0.0.1" });
  await new Promise<void>((res) => server.once("listening", () => res()));
  const address = server.address() as AddressInfo;
  baseUrl = `http://127.0.0.1:${address.port}`;
}

afterEach(async () => {
  if (server) {
    await new Promise((resolve) => server.close(resolve));
  }
});

describe("createSsrServer", () => {
  it("renders the resolved component with props via POST /render", async () => {
    await start(() => ({ default: OrdersIndex }));

    const res = await fetch(`${baseUrl}/render`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ component: "orders/index", props: { totalCount: 5 }, url: "/orders" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { html: string };
    expect(body.html).toContain("orders:5");
  });

  it("seeds the page store so components using usePageProps render", async () => {
    await start(() => ({ default: StorePage }));

    const res = await fetch(`${baseUrl}/render`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ component: "store/page", props: { label: "hi" }, url: "/x", version: "v1" }),
    });

    expect(res.status).toBe(200);
    const body = (await res.json()) as { html: string };
    expect(body.html).toContain("from-store:hi");
  });

  it("responds to GET /health", async () => {
    await start(() => ({ default: OrdersIndex }));

    const res = await fetch(`${baseUrl}/health`);
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ ok: true });
  });

  it("returns 500 with an error message when the component cannot be resolved, and keeps serving", async () => {
    await start((component: string) => {
      throw new Error(`unknown component: ${component}`);
    });

    const res = await fetch(`${baseUrl}/render`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ component: "missing/page", props: {}, url: "/missing" }),
    });

    expect(res.status).toBe(500);
    const body = (await res.json()) as { error: string };
    expect(body.error).toContain("unknown component");
    expect(body.error).not.toContain("    at ");

    const health = await fetch(`${baseUrl}/health`);
    expect(health.status).toBe(200);
  });

  it("returns 400 for malformed JSON", async () => {
    await start(() => ({ default: OrdersIndex }));

    const res = await fetch(`${baseUrl}/render`, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: "{not json",
    });

    expect(res.status).toBe(400);
  });

  it("returns 404/405 for GET /render", async () => {
    await start(() => ({ default: OrdersIndex }));

    const res = await fetch(`${baseUrl}/render`);
    expect([404, 405]).toContain(res.status);
  });
});
