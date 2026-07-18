import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { setPage } from "./store.js";
import {
  FondParamsError,
  handlePopState,
  installClickInterceptor,
  installPopStateListener,
  navigate,
} from "./router.js";

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
    ...init,
  });
}

beforeEach(() => {
  setPage({ component: "orders/index", props: {}, url: "/orders", version: "v1" });
  vi.spyOn(history, "pushState");
  vi.spyOn(history, "replaceState");
  vi.spyOn(window, "scrollTo").mockImplementation(() => {});
  vi.spyOn(console, "error").mockImplementation(() => {});
});

afterEach(() => {
  vi.restoreAllMocks();
});

describe("navigate", () => {
  it("sends fond headers and updates the store on 200", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse({ component: "orders/show", props: { id: 1 }, url: "/orders/1", version: "v1" }),
    );
    vi.stubGlobal("fetch", fetchMock);

    await navigate("/orders/1");

    expect(fetchMock).toHaveBeenCalledWith(
      "/orders/1",
      expect.objectContaining({
        credentials: "same-origin",
        headers: expect.objectContaining({
          "X-Fond": "true",
          "X-Fond-Version": "v1",
          Accept: "application/json",
        }),
      }),
    );

    const { getPage } = await import("./store.js");
    expect(getPage()).toEqual({
      component: "orders/show",
      props: { id: 1 },
      url: "/orders/1",
      version: "v1",
    });
    expect(history.pushState).toHaveBeenCalledWith({ fond: true }, "", "/orders/1");
    expect(window.scrollTo).toHaveBeenCalledWith(0, 0);
  });

  it("replaces history state when replace option is set", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({ component: "orders/show", props: {}, url: "/orders/1", version: "v1" }),
      ),
    );

    await navigate("/orders/1", { replace: true });

    expect(history.replaceState).toHaveBeenCalledWith({ fond: true }, "", "/orders/1");
    expect(history.pushState).not.toHaveBeenCalled();
  });

  it("hard-visits X-Fond-Location on 409", async () => {
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        new Response(null, {
          status: 409,
          headers: { "X-Fond-Location": "/orders?page=3" },
        }),
      ),
    );

    await navigate("/orders?page=3");

    expect(assignSpy).toHaveBeenCalledWith("/orders?page=3");
    expect(history.pushState).not.toHaveBeenCalled();
  });

  it("falls back to the requested url on 409 without a location header", async () => {
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 409 })));

    await navigate("/orders");

    expect(assignSpy).toHaveBeenCalledWith("/orders");
  });

  it("throws FondParamsError on 400 invalid_params", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse(
          { error: "invalid_params", errors: { page: "must be an integer" } },
          { status: 400 },
        ),
      ),
    );

    await expect(navigate("/orders?page=x")).rejects.toBeInstanceOf(FondParamsError);

    try {
      await navigate("/orders?page=x");
    } catch (err) {
      expect((err as FondParamsError).errors).toEqual({ page: "must be an integer" });
    }
  });

  it("hard-loads on network failure", async () => {
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockRejectedValue(new Error("network down")));

    await navigate("/orders");

    expect(assignSpy).toHaveBeenCalledWith("/orders");
  });

  it("hard-loads on unexpected status codes", async () => {
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal("fetch", vi.fn().mockResolvedValue(new Response(null, { status: 500 })));

    await navigate("/orders");

    expect(assignSpy).toHaveBeenCalledWith("/orders");
  });

  it("refuses to navigate to a cross-origin URL", async () => {
    const fetchMock = vi.fn();
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal("fetch", fetchMock);

    await expect(navigate("https://evil.example/phish")).rejects.toThrow(/cross-origin/);

    expect(fetchMock).not.toHaveBeenCalled();
    expect(assignSpy).not.toHaveBeenCalled();
  });

  it("refuses to navigate to a protocol-relative URL", async () => {
    const fetchMock = vi.fn();
    const assignSpy = vi.spyOn(location, "assign").mockImplementation(() => {});
    vi.stubGlobal("fetch", fetchMock);

    await expect(navigate("//evil.example/phish")).rejects.toThrow(/cross-origin/);

    expect(fetchMock).not.toHaveBeenCalled();
    expect(assignSpy).not.toHaveBeenCalled();
  });
});

describe("handlePopState", () => {
  it("re-fetches without pushing history state", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({ component: "orders/show", props: {}, url: "/orders/2", version: "v1" }),
      ),
    );

    await handlePopState("/orders/2");

    const { getPage } = await import("./store.js");
    expect(getPage().url).toBe("/orders/2");
    expect(history.pushState).not.toHaveBeenCalled();
    expect(history.replaceState).not.toHaveBeenCalled();
  });
});

describe("installPopStateListener", () => {
  it("triggers a refetch based on the current location", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({ component: "orders/index", props: {}, url: location.pathname, version: "v1" }),
      ),
    );

    const uninstall = installPopStateListener();
    window.dispatchEvent(new PopStateEvent("popstate"));
    await Promise.resolve();
    await Promise.resolve();

    expect(fetch).toHaveBeenCalled();
    uninstall();
  });
});

describe("installClickInterceptor", () => {
  let uninstall: () => void;

  beforeEach(() => {
    uninstall = installClickInterceptor();
  });

  afterEach(() => {
    uninstall();
    document.body.innerHTML = "";
  });

  function click(anchor: HTMLAnchorElement, opts: MouseEventInit = {}): MouseEvent {
    const event = new MouseEvent("click", { bubbles: true, cancelable: true, button: 0, ...opts });
    anchor.dispatchEvent(event);
    return event;
  }

  it("intercepts a plain same-origin anchor click", async () => {
    vi.stubGlobal(
      "fetch",
      vi.fn().mockResolvedValue(
        jsonResponse({ component: "orders/index", props: {}, url: "/orders", version: "v1" }),
      ),
    );

    const a = document.createElement("a");
    a.href = "/orders";
    document.body.appendChild(a);

    const event = click(a);

    expect(event.defaultPrevented).toBe(true);
    await Promise.resolve();
    await Promise.resolve();
    expect(fetch).toHaveBeenCalledWith("/orders", expect.anything());
  });

  it("ignores clicks with modifier keys", () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const a = document.createElement("a");
    a.href = "/orders";
    document.body.appendChild(a);

    const event = click(a, { metaKey: true });

    expect(event.defaultPrevented).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("ignores external links", () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const a = document.createElement("a");
    a.href = "https://example.com/foo";
    document.body.appendChild(a);

    const event = click(a);

    expect(event.defaultPrevented).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("ignores anchors with target=_blank", () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const a = document.createElement("a");
    a.href = "/orders";
    a.target = "_blank";
    document.body.appendChild(a);

    const event = click(a);

    expect(event.defaultPrevented).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });

  it('ignores anchors with data-fond="false"', () => {
    const fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);

    const a = document.createElement("a");
    a.href = "/orders";
    a.dataset.fond = "false";
    document.body.appendChild(a);

    const event = click(a);

    expect(event.defaultPrevented).toBe(false);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
