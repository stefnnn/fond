# Transport Protocol

This page is the normative reference for the Fond wire protocol. The Ruby gem and the JS runtime both implement exactly what is described here.

## Overview

Every Fond page has one canonical URL served by Rails. The same URL serves two representations:

- **HTML** — the initial full-page load. Rails renders a shell layout containing the serialized page payload; the client hydrates from it.
- **JSON** — client-side navigations. The router re-requests the URL with the `X-Fond` header and receives the payload only.

Caching correctness: every response to a Fond-routed action carries `Vary: X-Fond`.

## Page payload

```json
{
  "component": "orders/index",
  "props": { "orders": ["..."], "totalCount": 40 },
  "url": "/orders?page=2",
  "version": "a1b2c3"
}
```

- `component` — page identifier derived from the Ruby class (`Orders::IndexPage` → `"orders/index"`). The client resolves it to a React component via the generated manifest.
- `props` — the page's `Props` struct serialized to camelCase JSON. Temporal values are ISO8601 strings (UTC, millisecond precision for times).
- `url` — the canonical URL (path + query) of this payload, used for history state.
- `version` — the current asset version. See [Version mismatch](#version-mismatch).
- `shared` — optional; present when the app defines shared props (`fond_shared_props`). Serialized like `props` and carried on every page payload.

## Initial request (HTML)

The action runs, producing `Props`. Rails responds `200 text/html` with a standard layout containing:

```html
<div id="fond-root"></div>
<script type="application/json" id="fond-page-data">{payload}</script>
```

The JSON is escaped for safe embedding (`<` → `\u003c`). The client runtime parses the script tag, resolves the component, and renders into `#fond-root`.

## Client navigation (JSON)

The router intercepts same-origin link clicks and `navigate()` calls and requests the target URL with:

| Header | Value |
| --- | --- |
| `X-Fond` | `true` |
| `X-Fond-Version` | the version received at hydration |

Rails responds `200 application/json` with the page payload. The router swaps the component, updates `history` state, and scrolls to top (or restores scroll on `popstate`).

## Version mismatch

If a JSON navigation arrives with an `X-Fond-Version` that differs from the server's current version, Rails responds:

```
409 Conflict
X-Fond-Location: <requested url>
```

The client performs a hard `location.assign(X-Fond-Location)` — a full page load picks up the new assets. (Adopted verbatim from Inertia.)

## Invalid params

If coercing request params into the page's `Params` struct fails, Rails responds `400` with:

```json
{
  "error": "invalid_params",
  "errors": { "page": "must be an integer", "lineItems.0.unitPriceCents": "is required" }
}
```

Error keys are dotted camelCase paths into the params structure. The client runtime surfaces this as a rejected navigation.

## Params on the wire

Incoming params are gathered from path params, then query params, then JSON body (later sources win), and coerced into the page's `Params` struct: `"2"` → `2` for `Integer` fields, `""` → `nil` for nilables, ISO8601 strings → `Time`/`Date`, enum strings → `T::Enum` values. camelCase and snake_case keys are both accepted; camelCase wins when both are present.

## Mutations

Mutations are `POST`/`PATCH`/`PUT`/`DELETE` actions declared with a `Fond::Mutation` class. They are fetch-only (no HTML representation) and exempt from the version check.

**Request:**

```
POST /orders
Content-Type: application/json
X-Fond: true
X-CSRF-Token: <from the csrf-token meta tag>

{ "customerName": "Nora", "lineItems": [...] }
```

The body is coerced into the mutation's `Params` struct with the same rules as page params. Path params (`/orders/:id`) are merged into the same struct — the client runtime splits them out of the params object it is given.

**Responses:**

| Status | Body | Client behavior |
| --- | --- | --- |
| `200` | `{ "redirect": "/orders/5" }` | Soft-navigate to the URL (the common success case) |
| `200` | `{ "props": { ... } }` | Resolve `mutate()` with the typed payload (`props` is `null` for `Fond::Done`) |
| `422` | `{ "errors": { "base": ["..."], "fields": { "customerName": ["can't be blank"] } } }` | Populate the hook's `errors` state; `mutate()` resolves unsuccessfully |
| `400` | `{ "error": "invalid_params", "errors": { ... } }` | Throw — a coercion failure means client and server types diverge (a bug, not user error) |

Validation errors use one canonical shape everywhere: `base` for record-level messages, `fields` keyed by camelCase attribute name. Rails-side, returning an `ActiveModel::Errors` (or a saved-record failure via `Fond::Invalid`) converts automatically.

Redirects are encoded in the JSON body rather than HTTP redirects, so `fetch` never transparently follows them and the client router stays in control.

`redirect` must be a relative, same-origin path (`Fond::Redirect.new` raises if it isn't, e.g. an absolute URL or a protocol-relative `//host/...` value). This matters because the URL is round-tripped through server-supplied JSON: without that constraint, a controller that builds a redirect target from user input (a `return_to` param, say) could turn a mutation into an open redirect. The client router enforces the same constraint independently before navigating — `navigate()` refuses any URL that doesn't resolve to the current origin, whether it came from a mutation's `redirect` field or any other caller.

## CSRF

Fond does not implement CSRF protection itself — mutation requests carry `X-CSRF-Token` (read from the `csrf-token` meta tag) purely as a courtesy to whatever protection the host app has configured. Enforcement is entirely Rails' own `protect_from_forgery`/`verify_authenticity_token` on the controller. An app that disables forgery protection, or that mounts Fond mutation routes on a controller with `protect_from_forgery with: :null_session` (or no forgery protection at all, as is common on API-only base controllers), has no CSRF protection on its mutations — Fond will not add one.
