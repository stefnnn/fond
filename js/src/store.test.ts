import { describe, expect, it, vi, beforeEach } from "vitest";

describe("store", () => {
  beforeEach(() => {
    vi.resetModules();
  });

  it("throws before initialization", async () => {
    const { getPage } = await import("./store.js");
    expect(() => getPage()).toThrow();
  });

  it("set updates the current page and notifies subscribers", async () => {
    const { getPage, setPage, subscribe } = await import("./store.js");
    const listener = vi.fn();
    const unsubscribe = subscribe(listener);

    const payload = { component: "orders/index", props: {}, url: "/orders", version: "v1" };
    setPage(payload);

    expect(getPage()).toEqual(payload);
    expect(listener).toHaveBeenCalledTimes(1);

    unsubscribe();
    setPage({ ...payload, url: "/orders?page=2" });
    expect(listener).toHaveBeenCalledTimes(1);
  });
});
