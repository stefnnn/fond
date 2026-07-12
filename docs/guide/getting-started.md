# Getting Started

::: warning
Fond is under active development. APIs may change.
:::

## Install

Add the gem, run the installer, and let it wire everything below for you:

```bash
bundle add fond
bin/rails g fond:install        # add --ssr for the sidecar scaffolding
bundle install                  # picks up vite_rails + sorbet-runtime added by the installer
bundle exec vite install        # if config/vite.json doesn't exist yet
```

The installer mounts `Fond::Controller`, creates the initializer and the
`app/frontend` scaffold (entrypoint, `pages/`, `tsconfig.json`,
`vite.config.ts`), injects the Vite tags into your layout, registers the
`DTO` inflection, adds the npm dependencies (pnpm/yarn/npm auto-detected;
`--skip-npm` to opt out), and writes `Procfile.dev` + `bin/dev`. It is
idempotent — re-running skips what's already in place.

Scaffold your first page and mutation with:

```bash
bin/rails g fond:page Orders::Index
bin/rails g fond:mutation Orders::Create
```

Each prints the route and controller snippet to add. The sections below
describe what the installer set up, in case you prefer wiring it manually.

Fond's protocol is built on top of Vite — `vite_rails` gives you the dev
server, HMR, and asset manifest. You need a `vite.config.ts` with
`@vitejs/plugin-react` and `vite-plugin-ruby`:

```ts
// vite.config.ts
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import RubyPlugin from "vite-plugin-ruby";

export default defineConfig({
  plugins: [react(), RubyPlugin()],
});
```

## Mount the controller integration

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Fond::Controller
end
```

This adds the `page`/`mutation` class macros, `render_page`, `redirect_page`,
and `invalid` to every controller.

## Layout

Fond renders `<div id="fond-root">` (with optional SSR markup inside) plus
a `<script type="application/json" id="fond-page-data">` tag into whatever
layout your controller normally uses. Point the layout at your Vite
entrypoint:

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html>
  <head>
    <title><%= content_for(:title) || "My App" %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= vite_client_tag %>
    <%= vite_javascript_tag "application.tsx" %>
  </head>
  <body>
    <%= yield %>
  </body>
</html>
```

`csrf_meta_tags` matters: the generated mutation hooks read the token from
the `csrf-token` meta tag and send it as `X-CSRF-Token` automatically.

## Client entrypoint

```tsx
// app/frontend/entrypoints/application.tsx
import { createFondApp } from "fond";
import "../styles/app.css";

const pages = import.meta.glob("../pages/**/*.tsx");

createFondApp({
  resolve: (name) => {
    const loader = pages[`../pages/${name}.tsx`];
    if (!loader) throw new Error(`Unknown page component: ${name}`);
    return loader() as Promise<{ default: React.ComponentType }>;
  },
});
```

`createFondApp` reads the initial payload from `#fond-page-data`, hydrates
(or renders, if there's nothing to hydrate) into `#fond-root`, and installs
the client-side router (link interception + `popstate`).

`resolve` is your code, not Fond's — `import.meta.glob` is a Vite feature
that gives you a static map of lazy imports for every page module, so
navigating to a page code-splits it automatically. The keys have to line
up with `component_name` (see [Pages & DTOs](/guide/pages)), which is why
the lookup is `../pages/${name}.tsx`.

## Your first page

**1. Define the page** — nested `Params`/`Props` structs:

```ruby
# app/pages/orders/index_page.rb
module Orders
  class IndexPage < Fond::Page
    class Params < T::Struct
      const :status, T.nilable(OrderStatus)
      const :page, Integer, default: 1
    end

    class Props < T::Struct
      const :orders, T::Array[OrderDTO]
      const :total_count, Integer
    end
  end
end
```

**2. Wire the controller action:**

```ruby
# app/controllers/orders_controller.rb
class OrdersController < ApplicationController
  page Orders::IndexPage
  def index(params) # typed Orders::IndexPage::Params instance
    Orders::IndexPage::Props.new(
      orders: Order.page(params.page).map { OrderDTO.from_model(it) },
      total_count: Order.count,
    )
  end
end
```

Returning a `Props` instance is enough — `page` wires up rendering. Rails
routes are untouched: add a normal `resources :orders` (or `get`) route.

**3. Run codegen:**

```bash
bin/rails fond:codegen
```

This writes `app/frontend/generated/{types,pages,hooks,paths}.ts`. See
[Codegen](/guide/codegen) for what each file contains.

**4. Write the page component:**

```tsx
// app/frontend/pages/orders/index.tsx
import { useOrdersIndex } from "../../generated/hooks";

export default function OrdersIndex() {
  const { orders, totalCount } = useOrdersIndex();
  return (
    <main>
      <h1>{totalCount} orders</h1>
      <ul>{orders.map((o) => <li key={o.id}>{o.customerName}</li>)}</ul>
    </main>
  );
}
```

The file path (`app/frontend/pages/orders/index.tsx`) has to match the
page's `component_name` (`"orders/index"`) under `pages_import_prefix`
(default `../pages/`, configurable — see [Codegen](/guide/codegen)).

Visit the route: full page loads render server-side (HTML shell + hydration
payload, and SSR markup if a [sidecar](/guide/ssr) is configured); clicking
an `<a>` to another Fond page soft-navigates via JSON fetch instead.

## Dev workflow

Run Vite and Rails together, e.g. with a `Procfile.dev`:

```
vite: bin/vite dev
web: bin/rails s
```

In development, codegen runs automatically: fond hooks into Rails' code
reloading and regenerates the output whenever a page, mutation, or DTO
changes (on the next request, like any Rails reload). `bin/rails
fond:codegen` remains available for one-shot runs, and
`Fond.config.autogenerate = false` opts out.

In CI, check for drift instead of regenerating:

```bash
bin/rails fond:codegen:check
```

This fails the build if the committed `app/frontend/generated/*.ts` files
don't match what the current Ruby definitions would produce — the classic
"generated output committed, CI enforces it's not stale" pattern.
