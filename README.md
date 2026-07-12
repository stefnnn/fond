# Fond

Typed React frontends for Ruby on Rails. Sorbet `T::Struct` DTOs are the API contract; Fond generates TypeScript types, data-fetching hooks, mutation hooks, and route helpers from them — one source of truth, no divergence.

```ruby
class Orders::IndexPage < Fond::Page
  class Params < T::Struct
    const :status, T.nilable(OrderStatus)
    const :page, Integer, default: 1
  end

  class Props < T::Struct
    const :orders, T::Array[OrderDTO]
    const :total_count, Integer
  end
end

class OrdersController < ApplicationController
  page Orders::IndexPage
  def index(params)                # typed Params instance
    Orders::IndexPage::Props.new(orders: ..., total_count: ...)
  end
end
```

```tsx
export default function OrdersIndex() {
  const { orders, totalCount } = useOrdersIndex(); // generated, fully typed
  ...
}
```

## What's in the box

- **Pages** — `Params -> Props` controller actions with coercion at the boundary (`"2"` → `2`, `""` → `nil`, ISO8601 → `Time`, enum strings → `T::Enum`), 400 with a typed error map on bad input.
- **Codegen** — `types.ts` (interfaces, literal-union enums, discriminated unions), `hooks.ts`, `paths.ts`, `pages.ts`; deterministic output plus a CI drift check (`fond:codegen:check`).
- **Transport** — Inertia-style: HTML shell + hydration payload on first load, JSON payloads for soft navigations, asset-version conflict handling, `Vary: X-Fond`.
- **Mutations** — JSON-body actions returning `redirect_page(...)`, `Props`, or `invalid(...)`; canonical `{ base, fields }` validation errors; generated `useMutation` hooks with `pending`/`errors` state and automatic CSRF.
- **SSR (optional)** — a small Node sidecar (`fond/ssr`); if it's down or slow, pages degrade to client rendering.
- **Layouts & shared props** — persistent layout components that don't remount across navigations; a `SharedProps` struct merged into every payload (`useShared()`).

## Documentation

The docs site lives in [`docs/`](docs/) (VitePress) and deploys to GitHub Pages on push to `main`. Start with the [getting-started guide](docs/guide/getting-started.md); the [transport protocol reference](docs/protocol/index.md) is normative.

## Layout

- `ruby/` — the `fond` gem (page/mutation conventions, coercion, serialization, codegen, transport, SSR client)
- `js/` — the `fond` npm package (router, hooks, mutation runtime, SSR server)
- `examples/orders/` — example app exercising the full feature surface (see [the tour](docs/guide/example-app.md))
- `docs/` — documentation site

## Development

```bash
pnpm install
(cd ruby && bundle install && bundle exec rake test)   # gem tests
pnpm --filter fond test                                # runtime tests
(cd examples/orders && bundle install && bin/rails db:prepare db:seed && bin/rails test)
```

CI runs all three suites plus the codegen drift check; docs deploy from `main`.

## Status

Early development — built as a design study. See [PLAN.md](PLAN.md) for the design rationale.

## License

MIT
