# Example app: Orders

`examples/orders` is a small coffee-gear order tracker, kept in the same
monorepo as the gem and npm package, exercising the whole stack end to
end. It's the source for every code excerpt in this guide.

## What's where

| Concern | Path |
| --- | --- |
| Pages | `app/pages/orders/{index,new,show}_page.rb` |
| Controller (pages + mutations) | `app/controllers/orders_controller.rb` |
| Mutations | `app/mutations/orders/{create,destroy,add_note,update_status}_mutation.rb` |
| DTOs | `app/dtos/{order,line_item,order_event}_dto.rb`, `app/dtos/shared_props.rb` |
| Enum | `app/types/order_status.rb` (`T::Enum`, backs the `OrderStatus` filter/select) |
| Page components | `app/frontend/pages/orders/{index,new,show}.tsx` |
| Client entrypoint | `app/frontend/entrypoints/application.tsx` |
| SSR entrypoint | `app/frontend/ssr/ssr.tsx` |
| Generated output | `app/frontend/generated/{types,pages,hooks,paths}.ts` (committed) |
| Fond config | `config/initializers/fond.rb` |
| Vite config | `vite.config.ts` (client), `vite.ssr.config.ts` (sidecar) |
| Controller/mutation tests | `test/controllers/orders_controller_test.rb`, `test/controllers/mutations_test.rb` |

What it demonstrates:

- Three pages (`index`/paginated + filtered list, `new`/a form, `show`/
  detail with nested mutations) and four mutations, covering both
  `redirect_page` and `invalid(...)` return paths.
- A `T::Array[LineItemInput]` nested-struct param on `CreateMutation`
  (array coercion, per-index error paths).
- A discriminated union (`OrderEventDTO = T.any(StatusChangeEventDTO,
  NoteEventDTO)`) rendered as a mixed activity feed.
- Shared props (`SharedProps`, `app_name`/`flash`/`open_order_count`)
  read by every page via `useShared()`.
- Real client-side navigation and typed path helpers
  (`paths.ordersIndex({ status, query })`) driving filters without a full
  reload.
- `usePage().url` used to read the current filter state instead of
  `window.location` (see [SSR](/guide/ssr#the-window-is-not-defined-pitfall)).

## Running it

From the repo root, install both the JS workspace and the app's Ruby
dependencies:

```bash
pnpm install
cd examples/orders
bundle install
```

Prepare and seed the database:

```bash
bin/rails db:prepare
bin/rails db:seed
```

Run codegen once (it's committed, but re-run after pulling if the Ruby
side changed and you want to confirm nothing drifted):

```bash
bin/rails fond:codegen
```

Start the server:

```bash
bin/dev   # exec's `bin/rails server`
```

`config/vite.json` sets `autoBuild: true` for development, so `vite_rails`
spawns the Vite dev server on demand — a separate Vite process isn't
required. `Procfile.dev` (`vite: bin/vite dev`, `web: bin/rails s`) is
there if you'd rather run them explicitly (e.g. `foreman start -f
Procfile.dev`) for HMR log visibility. Visit `http://localhost:3000/orders`.

::: tip
`bin/setup` does dependency install + `db:prepare` + log/tmp cleanup +
`exec bin/dev` in one shot, if you'd rather not run each step by hand.
:::

SSR is optional and off by default in this example
(`config.ssr_url` is only set from `ENV["FOND_SSR_URL"]`). To try it:

```bash
cd examples/orders
vite build --config vite.ssr.config.ts
FOND_SSR_PORT=13714 node tmp/ssr/ssr.js &
FOND_SSR_URL=http://127.0.0.1:13714 bin/rails s
```

## Tests

```bash
cd examples/orders
bin/rails test
```

`test/controllers/mutations_test.rb` is a good tour of the mutation
protocol from the outside — asserts the exact `{ redirect: ... }` /
`{ errors: { base, fields } }` / `400` bodies for each mutation outcome,
and confirms mutations skip the `X-Fond-Version` check.
