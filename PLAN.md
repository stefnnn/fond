# Fond - rails + react

A new frontend option for ruby on rails with typed react/preact. Adds a new convention for ruby controllers and sorbet DTO types as backend API contract, generate typescript types and react hook helpers for data fetching and mutation.

## 1. DTOs — the contract layer

Go with Sorbet's `T::Struct`. The decisive property either way: **runtime-introspectable field definitions**, so codegen is just "load the class, walk the props" rather than static parsing.

Three DTO kinds per action:

- `Params` — query/path/body params, with coercion (strings → ints, etc.) happening at the boundary so the controller body sees typed values.
  - **Verified caveat:** `T::Struct.from_hash` neither coerces nor validates — `P.from_hash({"page" => "2"})` happily produces a struct with a String in an Integer field (only `.new` type-checks). So the Params boundary needs an explicit coercion layer: either the `sorbet-coerce` gem (TypeCoerce) or a small hand-rolled walker that reuses the same `type_object` introspection as codegen. Hand-rolled is probably right — it guarantees coercion rules and TS types can never disagree, and it's the same recursive walk anyway.
- `Props` — the page/query payload.
- `Errors` — for mutations; a canonical shape like `{ base: string[], fields: Record<string, string[]> }` generated from `ActiveModel::Errors`, plus optionally typed domain errors as a discriminated union.

Convention sketch:

```ruby
class Orders::IndexPage < AppPage
  class Params < T::Struct
    const :status, T.nilable(OrderStatus)
    const :page, Integer, default: 1
  end

  class Props < T::Struct
    const :orders, T::Array[OrderDTO]
    const :total_count, Integer
  end
end
```

And the controller action becomes a pure-ish function `Params -> Props`:

```ruby
class OrdersController < ApplicationController
  page Orders::IndexPage
  def index(params) # typed Params instance
    Props.new(orders: ..., total_count: ...)
  end
end
```

**Serialization honesty:** the DTO _is_ the serializer. `Props#serialize` (T::Struct gives you this) emits the JSON, and the same prop definitions drive the TS types. One source, no divergence. Nested DTOs (`OrderDTO`) replace ActiveModel serializers entirely; write a small helper for `OrderDTO.from_model(order)` mappers.

**Verified caveat:** `serialize` returns raw `Time`/`Date` objects in the hash — the wire format then depends on whichever JSON encoder runs last (plain `to_json` gives `"2026-07-12 10:30:00 UTC"`, ActiveSupport gives ISO8601). Don't leave this to chance: enforce ISO8601 in one place, either via `T::Props::CustomType` wrappers for temporal types or a post-`serialize` pass. `T::Enum` values serialize cleanly to their string form.

**RBS:** treat it as a _generated output_ alongside `.d.ts`, not a source. If you're all-in on Sorbet you may not even want RBS; decide based on which checker you actually run.

## 2. Codegen

A rake task / dev-server watcher that:

1. Eager-loads the app, enumerates all `AppPage` subclasses and marked mutation actions.
2. Reads Rails routes to bind each page/action to a path + HTTP verb + path params.
3. Walks `T::Struct` props recursively, emitting:
   - `types.d.ts` — interfaces for every Params/Props/Errors/DTO, enums for `T::Enum`.
   - Per-page hooks: `useOrdersIndex(): { data: OrdersIndexProps }` — resolves synchronously from the SSR/navigation payload (it's a page loader, not a fetch).
   - Per-mutation hooks: `useCreateOrder(): { mutate(params: CreateOrderParams): Promise<Result<CreateOrderProps, CreateOrderErrors>>, errors, pending }`.
   - A typed route helper: `path.ordersIndex({ status: "open" })` (steal `js_from_routes`' approach).

Walk `props[:x][:type_object]` (a `T::Types::Base` tree, e.g. `T.nilable(E)`, `T::Array[String]`), not the `:type` shortcut key — verified that `type_object` preserves the full structure including nilability, which `:type` flattens.

Type mapping is mostly mechanical (`T.nilable` → `| null`, `T::Array` → `[]`, `T::Hash` → `Record`, `Date/Time` → branded string types with a documented wire format — decide ISO8601 once, globally). The two things worth extra care: **discriminated unions** (support `T.any` of structs — but note Sorbet has no literal types, so the `type` discriminator can't be expressed in Ruby's type system; use a convention like `const :type, String, default: "shipped"` and have codegen read the default as the literal) and **stable output ordering** so generated files diff cleanly in git.

Run it as part of the dev server with file-watching; CI runs it and fails if output differs from committed files (the classic codegen drift check).

## 3. Transport + navigation (the Inertia-equivalent)

This is the heart of it. The protocol is small:

- **Initial request (HTML):** Rails runs the action, gets `Props`, calls the SSR sidecar with `{ component: "orders/index", props, url, meta }`, receives rendered HTML + head tags, embeds both the HTML and the serialized payload (`<script type="application/json" id="page-data">`) in a minimal layout. Client hydrates.
- **Client navigation:** your router intercepts link clicks / `navigate()` calls, requests the same URL with an `X-App-Request: true` header, Rails skips SSR and returns just `{ component, props, meta, version }` as JSON. Router swaps the page component, updates history. This is where `useOrdersIndex` gets its data on subsequent navigations — same hook, two hydration sources.
- **Mutations:** `POST/PATCH/DELETE` with JSON body (validated against `Params`), respond with either `Props` (200), `Errors` (422), or a redirect instruction `{ redirect: "/orders/5" }` (303-equivalent in JSON) which the client router follows as a navigation. Encoding redirects explicitly in the protocol rather than relying on HTTP redirects avoids a lot of fetch-follows-redirect pain.
- **Asset versioning:** include an asset hash in every response; on mismatch, do a full page load instead of a soft navigation (Inertia's trick, worth copying verbatim — including the server side: on a stale-version request, respond `409` with a location header the client follows as a hard reload).

Two details Inertia learned the hard way, adopt from day one:

- **`Vary: X-App-Request`** on every response, so HTTP caches never serve the JSON payload to a browser expecting HTML (or vice versa) for the same URL.
- **CSRF:** JSON mutations still go through Rails' forgery protection. Emit the token in the initial page payload (or meta tag) and have the generated mutation hooks send `X-CSRF-Token` automatically — this must be invisible to the app developer.

"App-router style" extras, in order of increasing effort: **layouts** (a `layout` field in the page manifest, persistent layout components that don't remount across navigations — this is what makes it feel like Next, do it early), **shared props** (current user, flash — a `SharedProps` DTO merged into every response, typed via a `useShared()` hook), **partial reloads** (client sends `X-Partial-Props: orders` and Rails only computes/sends those fields — nice, defer it), and **streaming/deferred props** (skip for v1; it fights the model).

File conventions: `app/frontend/pages/orders/index.tsx` maps to `Orders::IndexPage` by path convention, with a generated manifest so the client router can code-split via dynamic imports.

## 4. SSR sidecar

A small Node (or Bun) HTTP server, long-running in dev and prod:

- Endpoint: `POST /render` → `{ component, props, url }` → `{ html, head }`.
- Built by your bundler (Vite is the obvious choice — `vite_rails` integration exists, fast HMR, does SSR builds natively) as a server bundle with a page manifest.
- Preact helps here: `preact-render-to-string` is fast and the runtime is tiny, which keeps sidecar memory low.
- Failure mode: if the sidecar is down or times out, Rails serves the empty shell + payload and the client renders on hydrate. SSR degrades to CSR instead of erroring. This makes the sidecar operationally boring.
- Dev mode: Vite dev server does double duty (HMR for client, `ssrLoadModule` for renders), so you don't run a separate build.

Decide early whether SSR output must be crawlable/SEO-relevant. If the app is behind auth, consider shipping v1 as CSR-only with the sidecar as milestone 2 — everything else in the plan is unaffected because the payload protocol is identical.

## 5. Controller convention

For greenfield, the typed-return convention (`def index(params) → Props`) is the cleanest and I'd make it the _only_ way for pages. But keep an explicit escape hatch:

- `render_page Props.new(...)` — for the rare action that needs conditional behavior (render page A or B, or fall back to a non-TSX response).
- Regular Rails rendering remains untouched for admin/ERB-land; the two coexist because the page machinery only engages for controllers that declare `page ...`.

The typed-return version is implemented _as_ sugar over `render_page` anyway (a base controller override of `process_action` that builds `Params`, calls the action, takes the return value), so you get both for free. One subtlety: param validation failures (bad coercion) should have a defined behavior — 400 with a typed error shape, handled generically by the client.

## Documentation

Two layers, both generated and published from CI:

- **Guide site** — VitePress (fits the Vite-centric stack, markdown-in-repo under `docs/`). Structure: getting started (install gem + npm package, mount codegen), the conventions (pages, DTOs, controller signature), transport protocol reference (headers, status codes, redirect/version semantics — this doubles as the spec for anyone reimplementing the client), and a cookbook (forms, layouts, shared props).
- **API reference** — deferred. The public surface is small enough that the guide + protocol reference cover it; YARD/TypeDoc can be added to the same Pages artifact later if the API grows. Generated hooks/types don't need reference docs — they're project-specific output; document the *shape* in the guide instead.

Publishing via GitHub Actions → GitHub Pages (repo is already public, so Pages is free):

```yaml
# .github/workflows/docs.yml — on push to main
- run: npm run docs:build        # vitepress build + typedoc + yard, merged into one dir
- uses: actions/upload-pages-artifact@v3
  with: { path: docs/.vitepress/dist }
- uses: actions/deploy-pages@v4  # needs pages: write + id-token: write permissions
```

Use the "GitHub Actions" Pages source (repo Settings → Pages) rather than a `gh-pages` branch — no orphan branch to maintain, and deploys are atomic. One-time setup: enable Pages with source "GitHub Actions", set VitePress `base` to `/<repo-name>/` unless a custom domain is added. Docs deploy only from `main`; PRs just run the build step as a link-rot/dead-code check.

## Sequencing

1. **DTOs + codegen for types only** (no hooks yet) — this is independently useful and de-risks the type-mapping questions.
2. **Transport protocol + client router + query hooks**, CSR-only. This is the MVP where the DX vision becomes real.
3. **Mutations + error types + redirect protocol.** The hardest design work is here (error shapes, form ergonomics); budget time for iterating on what `useCreateOrder` feels like in a real form.
4. **SSR sidecar.**
5. **Layouts, shared props, partial reloads, code-splitting polish.**

The riskiest unknowns to prototype first: the `T::Struct` → `.d.ts` walker on a gnarly nested union type (partially de-risked — `type_object` introspection verified to expose the full type tree), the Params coercion layer (verified necessary; `from_hash` validates nothing), and the `process_action` override (Rails' controller internals have opinions — `send_action` is an alias of `send`, so passing arguments works, but interaction with callbacks and `ActionController::Parameters` needs the spike). All afternoon-sized.
