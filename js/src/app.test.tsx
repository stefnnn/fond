import { act } from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { createFondApp, type ComponentModule } from "./app.js";

function OrdersIndex({ totalCount }: { totalCount: number }) {
  return <div data-testid="page">orders/index:{totalCount}</div>;
}

function OrdersShow({ id }: { id: number }) {
  return <div data-testid="page">orders/show:{id}</div>;
}

function seedDom(payload: unknown): void {
  document.body.innerHTML = `
    <div id="fond-root"></div>
    <script type="application/json" id="fond-page-data">${JSON.stringify(payload)}</script>
  `;
}

beforeEach(() => {
  vi.stubGlobal("fetch", vi.fn());
});

afterEach(() => {
  document.body.innerHTML = "";
  vi.restoreAllMocks();
  vi.unstubAllGlobals();
});

describe("createFondApp", () => {
  it("renders the resolved component with initial props", async () => {
    seedDom({ component: "orders/index", props: { totalCount: 3 }, url: "/orders", version: "v1" });

    const resolve = vi.fn(
      (name: string): ComponentModule =>
        name === "orders/index" ? { default: OrdersIndex } : { default: OrdersShow },
    );

    await act(async () => {
      createFondApp({ resolve });
    });

    const root = document.getElementById("fond-root")!;
    expect(root.textContent).toBe("orders/index:3");
  });

  it("supports resolve returning a component directly (no default wrapper)", async () => {
    seedDom({ component: "orders/index", props: { totalCount: 7 }, url: "/orders", version: "v1" });

    await act(async () => {
      createFondApp({ resolve: () => OrdersIndex });
    });

    expect(document.getElementById("fond-root")!.textContent).toBe("orders/index:7");
  });

  it("swaps to the new component after navigation resolves, keeping old page until then", async () => {
    seedDom({ component: "orders/index", props: { totalCount: 3 }, url: "/orders", version: "v1" });

    const modules: Record<string, ComponentModule> = {
      "orders/index": { default: OrdersIndex },
      "orders/show": { default: OrdersShow },
    };

    let releaseShow!: () => void;
    const showPromise = new Promise<ComponentModule>((resolve) => {
      releaseShow = () => resolve(modules["orders/show"]!);
    });

    const resolve = vi.fn((name: string) => {
      if (name === "orders/show") return showPromise;
      return modules[name]!;
    });

    await act(async () => {
      createFondApp({ resolve });
    });
    expect(document.getElementById("fond-root")!.textContent).toBe("orders/index:3");

    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({ component: "orders/show", props: { id: 9 }, url: "/orders/9", version: "v1" }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );

    const { navigate } = await import("./router.js");
    let navigated!: Promise<void>;
    await act(async () => {
      navigated = navigate("/orders/9");
      await navigated;
    });

    expect(document.getElementById("fond-root")!.textContent).toBe("orders/index:3");

    await act(async () => {
      releaseShow();
      await showPromise;
    });

    expect(document.getElementById("fond-root")!.textContent).toBe("orders/show:9");
  });

  it("caches resolved modules and does not re-resolve on repeat visits", async () => {
    seedDom({ component: "orders/index", props: { totalCount: 1 }, url: "/orders", version: "v1" });

    const resolve = vi.fn((name: string): ComponentModule =>
      name === "orders/index" ? { default: OrdersIndex } : { default: OrdersShow },
    );

    await act(async () => {
      createFondApp({ resolve });
    });
    expect(resolve).toHaveBeenCalledTimes(1);

    vi.mocked(fetch).mockResolvedValue(
      new Response(
        JSON.stringify({ component: "orders/index", props: { totalCount: 2 }, url: "/orders?page=2", version: "v1" }),
        { status: 200, headers: { "content-type": "application/json" } },
      ),
    );

    const { navigate } = await import("./router.js");
    await act(async () => {
      await navigate("/orders?page=2");
    });

    expect(resolve).toHaveBeenCalledTimes(1);
    expect(document.getElementById("fond-root")!.textContent).toBe("orders/index:2");
  });
});
