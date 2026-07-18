import { getPage, setPage, type PagePayload } from "./store.js";

export class FondParamsError extends Error {
  errors: Record<string, string>;

  constructor(errors: Record<string, string>) {
    super("fond: invalid params");
    this.name = "FondParamsError";
    this.errors = errors;
  }
}

export function hardVisit(url: string): void {
  location.assign(url);
}

interface NavigateOptions {
  replace?: boolean;
}

async function fetchPage(url: string): Promise<PagePayload | "conflict"> {
  const version = pageVersionOrUndefined();

  const headers: Record<string, string> = {
    "X-Fond": "true",
    Accept: "application/json",
  };
  if (version !== undefined) headers["X-Fond-Version"] = version;

  const response = await fetch(url, {
    headers,
    credentials: "same-origin",
  });

  if (response.status === 200) {
    return (await response.json()) as PagePayload;
  }

  if (response.status === 409) {
    const location_ = response.headers.get("X-Fond-Location") ?? url;
    hardVisit(location_);
    return "conflict";
  }

  if (response.status === 400) {
    const body = (await response.json()) as {
      error?: string;
      errors?: Record<string, string>;
    };
    if (body.error === "invalid_params") {
      throw new FondParamsError(body.errors ?? {});
    }
  }

  hardVisit(url);
  return "conflict";
}

function pageVersionOrUndefined(): string | undefined {
  try {
    return getPage().version;
  } catch {
    return undefined;
  }
}

function assertSameOrigin(url: string): string {
  const resolved = new URL(url, location.href);
  if (resolved.origin !== location.origin) {
    throw new Error(`fond: refusing to navigate to cross-origin URL: ${url}`);
  }
  return resolved.pathname + resolved.search + resolved.hash;
}

export async function navigate(
  url: string,
  opts: NavigateOptions = {},
): Promise<void> {
  const target = assertSameOrigin(url);

  let payload: PagePayload | "conflict";
  try {
    payload = await fetchPage(target);
  } catch (err) {
    if (err instanceof FondParamsError) throw err;
    console.error("fond: navigation failed", err);
    hardVisit(url);
    return;
  }

  if (payload === "conflict") return;

  setPage(payload);
  if (opts.replace) {
    history.replaceState({ fond: true }, "", payload.url);
  } else {
    history.pushState({ fond: true }, "", payload.url);
  }
  window.scrollTo(0, 0);
}

export async function handlePopState(url: string): Promise<void> {
  let payload: PagePayload | "conflict";
  try {
    payload = await fetchPage(url);
  } catch (err) {
    if (!(err instanceof FondParamsError)) {
      hardVisit(url);
    }
    return;
  }

  if (payload === "conflict") return;
  setPage(payload);
}

function isModifiedClick(event: MouseEvent): boolean {
  return (
    event.defaultPrevented ||
    event.button !== 0 ||
    event.metaKey ||
    event.ctrlKey ||
    event.shiftKey ||
    event.altKey
  );
}

function findAnchor(target: EventTarget | null): HTMLAnchorElement | null {
  let el = target as HTMLElement | null;
  while (el) {
    if (el.tagName === "A") return el as HTMLAnchorElement;
    el = el.parentElement;
  }
  return null;
}

export function installClickInterceptor(): () => void {
  const handler = (event: MouseEvent): void => {
    if (isModifiedClick(event)) return;

    const anchor = findAnchor(event.target);
    if (!anchor) return;
    if (anchor.target) return;
    if (anchor.hasAttribute("download")) return;
    if (anchor.dataset.fond === "false") return;

    const href = anchor.getAttribute("href");
    if (!href) return;

    let url: URL;
    try {
      url = new URL(anchor.href, location.href);
    } catch {
      return;
    }
    if (url.origin !== location.origin) return;

    event.preventDefault();
    void navigate(url.pathname + url.search + url.hash);
  };

  document.addEventListener("click", handler);
  return () => document.removeEventListener("click", handler);
}

export function installPopStateListener(): () => void {
  const handler = (): void => {
    void handlePopState(location.pathname + location.search + location.hash);
  };
  window.addEventListener("popstate", handler);
  return () => window.removeEventListener("popstate", handler);
}
