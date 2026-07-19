# SSR

Server-side rendering is an optional sidecar, not a hard dependency. If
it's not configured, or it's down, or it times out, Fond degrades to
client-side rendering — the request never fails because of SSR.

## The sidecar

A small Node HTTP server built from your page components, run alongside
Rails (long-running, not per-request):

```ts
// app/frontend/ssr/ssr.tsx
import { createSsrServer } from "fond/ssr";

const pages = import.meta.glob("../pages/**/*.tsx");

createSsrServer({
  resolve: (name) => {
    const loader = pages[`../pages/${name}.tsx`];
    if (!loader) throw new Error(`Unknown page component: ${name}`);
    return loader() as Promise<{ default: React.ComponentType }>;
  },
  port: Number(process.env.FOND_SSR_PORT ?? 13714),
});
```

`createSsrServer` exposes two endpoints:

- `GET /health` → `{ ok: true }`
- `POST /render` → `{ component, props, url, version?, shared? }` →
  `{ html }` (or a `4xx`/`500` with `{ error }`)

Internally it seeds the page store (`setPage(...)`) with the request body
before calling `renderToString` — synchronous, so there's no concurrency
hazard sharing that module-level store across requests. It resolves the
component through the same `element.ts` machinery the client uses
(`renderPageElement`), which means **layouts are applied during SSR too**
— a page's `export const layout = AppLayout` wraps the SSR output exactly
as it would client-side.

Build it as a Vite SSR bundle:

```ts
// vite.ssr.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    ssr: "app/frontend/ssr/ssr.tsx",
    outDir: "tmp/ssr",
    emptyOutDir: true,
  },
});
```

## Development: `config.ssr = true`

```ruby
# config/initializers/fond.rb
Fond.configure do |config|
  config.ssr = true       # development only: builds tmp/ssr/ssr.js if stale,
                           # spawns/kills the Node sidecar around bin/rails s
  config.ssr_port = 13_714 # default
  config.ssr_timeout = 1.0 # default; applies to both open and read timeouts
end
```

With `config.ssr = true`, Fond hooks `bin/rails server`/`bin/rails s`
(including via `bin/dev`) and, before it starts accepting connections:

- builds the bundle above with `vite build --config vite.ssr.config.ts` if
  `tmp/ssr/ssr.js` is missing or older than anything under `app/frontend`
  (logging `fond: building SSR bundle...` when it does; build output goes to
  `log/fond_ssr.log`)
- spawns `node tmp/ssr/ssr.js` on `ssr_port`, and points `ssr_url` at it
- polls `GET /health` for up to 2s to confirm the sidecar actually came up,
  logging `fond: SSR sidecar running at http://127.0.0.1:13714 (pid ...)` on
  success or a warning pointing at `log/fond_ssr.log` if it never answers —
  check for this line at boot if you're not sure SSR is really running
- kills that process when the Rails server stops

If a healthy sidecar is already listening on `ssr_port` (e.g. left running
from a previous boot), Fond reuses it instead of spawning another, logging
`fond: reusing existing SSR sidecar at http://127.0.0.1:13714`.

Each successful render also logs `fond: SSR rendered in <ms>ms`, so slow
renders or degraded SSR are visible in the Rails log without instrumenting
anything yourself.

This only fires for the actual `server` command — `rails console`, `rails
runner`, rake tasks, and the test suite are unaffected, so nothing spawns a
Node process outside of running the app in dev.

## Production

`config.ssr` is a development convenience and doesn't apply here. Build the
bundle during deploy, run `node tmp/ssr/ssr.js` under your own process
manager (systemd, a `Procfile`, whatever), and point Fond at it explicitly:

```ruby
# config/initializers/fond.rb
Fond.configure do |config|
  config.ssr_url = ENV["FOND_SSR_URL"] if ENV["FOND_SSR_URL"].present?
end
```

`FOND_SSR_URL` (or `ssr_url` set directly) always takes precedence over
`config.ssr`'s auto-management — setting it is how staging/production
opt out of the dev-only build/spawn behavior entirely.

If `ssr_url` is `nil` (the default — e.g. unset in development without
`config.ssr`), Fond never calls out to a sidecar at all; every page is
CSR-only.

## Degradation to CSR

`Fond::Ssr.render(payload)` (called from `render_page` for HTML requests):

- returns `nil` immediately if `ssr_url` isn't configured
- returns `nil` on any `StandardError` — connection refused, timeout,
  non-200 response — logging a warning **once per error class per
  process** (not per request, to avoid flooding logs when the sidecar is
  down)
- otherwise returns the sidecar's `html`

When it's `nil`, `render_fond_html` still embeds `<div id="fond-root">`
(empty) and the page-data script tag — same HTML shell either way. The
sidecar being down changes nothing about the response's success or
shape, just whether there's markup inside `#fond-root`.

## Hydration vs. plain CSR

The client (`createFondApp`) decides how to mount based on whether
`#fond-root` already has children:

```ts
if (rootEl.hasChildNodes()) {
  // SSR succeeded — hydrateRoot
} else {
  // no SSR markup — createRoot + render (plain CSR)
}
```

This is exactly the degradation guarantee from the other side: no SSR
markup means an empty `#fond-root`, which means `hasChildNodes()` is
false, which means the client falls back to a normal client render
instead of attempting (and failing) to hydrate empty content.

## The window-is-not-defined pitfall

The SSR sidecar is a Node process — there is no `window`, `document`, or
`location`. Anything in a page component that reaches for a browser
global breaks under SSR (and only under SSR, which makes it an easy bug
to miss in dev if you never run the sidecar).

The fix is almost always: read from `usePage()` instead of the browser.

```tsx
// wrong — breaks in SSR
const params = new URLSearchParams(window.location.search);

// right — works in SSR and CSR, since it comes from the payload
const { url } = usePage();
const params = new URLSearchParams(url.split("?")[1] ?? "");
```

`usePage().url` is part of the payload (`Fond::Controller#render_page`
sets it to `request.fullpath`), so it's available identically whether the
component is rendering server-side or client-side. This is exactly what
`examples/orders/app/frontend/pages/orders/index.tsx` does to read the
`status`/`query` filters out of the current URL.
