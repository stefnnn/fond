import { describe, expect, it } from "vitest";
import { buildPath } from "./path.js";

describe("buildPath", () => {
  it("interpolates path params", () => {
    expect(buildPath("/orders/:id", ["id"], { id: 42 })).toBe("/orders/42");
  });

  it("matches snake_case pattern segments to camelCase params", () => {
    expect(buildPath("/orders/:order_id/items/:item_id", ["order_id", "item_id"], {
      orderId: 1,
      itemId: 2,
    })).toBe("/orders/1/items/2");
  });

  it("appends remaining params as a query string", () => {
    const url = buildPath("/orders", [], { page: 2, active: true });
    expect(url).toBe("/orders?page=2&active=true");
  });

  it("serializes Date params to ISO strings", () => {
    const date = new Date("2026-07-12T00:00:00.000Z");
    const url = buildPath("/orders", [], { since: date });
    expect(url).toBe(`/orders?since=${encodeURIComponent(date.toISOString())}`);
  });

  it("skips null, undefined, and empty string params", () => {
    const url = buildPath("/orders", [], { a: null, b: undefined, c: "", d: 1 });
    expect(url).toBe("/orders?d=1");
  });

  it("throws when a path param is missing", () => {
    expect(() => buildPath("/orders/:id", ["id"], {})).toThrow();
  });

  it("returns the bare path when there are no query params", () => {
    expect(buildPath("/orders/:id", ["id"], { id: 1 })).toBe("/orders/1");
  });
});
