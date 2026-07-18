import { act, renderHook } from "@testing-library/react";
import { afterEach, describe, expect, it, vi } from "vitest";
import { useMutation } from "./mutation.js";
import { FondParamsError } from "./router.js";

const { navigateMock } = vi.hoisted(() => ({ navigateMock: vi.fn() }));

vi.mock("./router.js", async () => {
  const actual = await vi.importActual<typeof import("./router.js")>("./router.js");
  return { ...actual, navigate: navigateMock };
});

function jsonResponse(body: unknown, init: ResponseInit = {}): Response {
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { "content-type": "application/json" },
    ...init,
  });
}

afterEach(() => {
  vi.restoreAllMocks();
  navigateMock.mockReset();
  document.head.innerHTML = "";
});

describe("useMutation", () => {
  it("interpolates snake_case pattern segments, sends full body, and omits a query string", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ props: null }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() =>
      useMutation<{ orderId: number; note: string }>("/orders/:order_id", "patch", ["order_id"]),
    );

    await act(async () => {
      await result.current.mutate({ orderId: 5, note: "hi" });
    });

    expect(fetchMock).toHaveBeenCalledWith(
      "/orders/5",
      expect.objectContaining({
        method: "PATCH",
        credentials: "same-origin",
        body: JSON.stringify({ orderId: 5, note: "hi" }),
      }),
    );
  });

  it("omits the CSRF header when no meta tag is present", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ props: null }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));
    await act(async () => {
      await result.current.mutate({});
    });

    const headers = fetchMock.mock.calls[0]![1]!.headers as Record<string, string>;
    expect(headers["X-CSRF-Token"]).toBeUndefined();
  });

  it("sends the CSRF header from the meta tag when present", async () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "tok123";
    document.head.appendChild(meta);

    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ props: null }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));
    await act(async () => {
      await result.current.mutate({});
    });

    const headers = fetchMock.mock.calls[0]![1]!.headers as Record<string, string>;
    expect(headers["X-CSRF-Token"]).toBe("tok123");
  });

  it("soft-navigates and resolves a redirected outcome on 200 with redirect", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ redirect: "/orders/5" }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    let outcome: unknown;
    await act(async () => {
      outcome = await result.current.mutate({});
    });

    expect(navigateMock).toHaveBeenCalledWith("/orders/5");
    expect(outcome).toEqual({ ok: true, redirected: true, data: null });
  });

  it("propagates a rejected redirect (e.g. a cross-origin target) instead of swallowing it", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ redirect: "https://evil.example/phish" }));
    vi.stubGlobal("fetch", fetchMock);
    navigateMock.mockRejectedValue(new Error("fond: refusing to navigate to cross-origin URL"));

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    await expect(
      act(async () => {
        await result.current.mutate({});
      }),
    ).rejects.toThrow(/cross-origin/);
  });

  it("resolves a props outcome on 200 with props", async () => {
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ props: { id: 7 } }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() =>
      useMutation<Record<string, unknown>, { id: number }>("/orders", "post"),
    );

    let outcome: unknown;
    await act(async () => {
      outcome = await result.current.mutate({});
    });

    expect(outcome).toEqual({ ok: true, redirected: false, data: { id: 7 } });
  });

  it("sets errors state and resolves not-ok on 422", async () => {
    const errors = { base: ["invalid"], fields: { name: ["required"] } };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ errors }, { status: 422 }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    let outcome: unknown;
    await act(async () => {
      outcome = await result.current.mutate({});
    });

    expect(outcome).toEqual({ ok: false, errors });
    expect(result.current.errors).toEqual(errors);
  });

  it("reset clears errors", async () => {
    const errors = { base: [], fields: { name: ["required"] } };
    const fetchMock = vi.fn().mockResolvedValue(jsonResponse({ errors }, { status: 422 }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));
    await act(async () => {
      await result.current.mutate({});
    });
    expect(result.current.errors).toEqual(errors);

    act(() => {
      result.current.reset();
    });
    expect(result.current.errors).toBeNull();
  });

  it("throws FondParamsError on 400 invalid_params", async () => {
    const fetchMock = vi.fn().mockResolvedValue(
      jsonResponse({ error: "invalid_params", errors: { name: "is required" } }, { status: 400 }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    await expect(
      act(async () => {
        await result.current.mutate({});
      }),
    ).rejects.toBeInstanceOf(FondParamsError);
  });

  it("throws a plain error on an unexpected status and leaves errors null", async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(null, { status: 500 }));
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    await expect(
      act(async () => {
        await result.current.mutate({});
      }),
    ).rejects.toThrow();

    expect(result.current.errors).toBeNull();
  });

  it("toggles pending true then false around the request", async () => {
    let resolveFetch: (value: Response) => void = () => {};
    const fetchMock = vi.fn().mockReturnValue(
      new Promise<Response>((resolve) => {
        resolveFetch = resolve;
      }),
    );
    vi.stubGlobal("fetch", fetchMock);

    const { result } = renderHook(() => useMutation<Record<string, unknown>>("/orders", "post"));

    expect(result.current.pending).toBe(false);

    let mutatePromise!: Promise<unknown>;
    act(() => {
      mutatePromise = result.current.mutate({});
    });

    expect(result.current.pending).toBe(true);

    await act(async () => {
      resolveFetch(jsonResponse({ props: null }));
      await mutatePromise;
    });

    expect(result.current.pending).toBe(false);
  });
});
