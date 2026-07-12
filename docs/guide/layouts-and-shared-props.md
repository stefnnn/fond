# Layouts & Shared Props

Two independent conventions that both exist to avoid re-fetching/re-typing
things every page needs: **layouts** keep persistent chrome (nav, sidebar)
mounted across navigations; **shared props** put data every page needs
(current user, flash) on every payload without every `Props` struct
repeating it.

## Persistent layouts

A page module exports a named `layout` next to its default export —
either `export const layout = AppLayout` or a re-export:

```tsx
// app/frontend/pages/orders/index.tsx
export default function OrdersIndex() {
  // ...
}

export { AppLayout as layout } from "../../components/AppLayout";
```

`AppLayout` is plain app code — a component taking `{ children }`, reading
shared props via `useShared()` (`examples/orders/app/frontend/components/AppLayout.tsx`):

```tsx
// app/frontend/components/AppLayout.tsx
import { type ReactNode } from "react";
import { useShared } from "../generated/hooks";
import { paths } from "../generated/paths";

export function AppLayout({ children }: { children: ReactNode }) {
  const { appName, flash, openOrderCount } = useShared();

  return (
    <>
      <header className="app-header">
        <a href={paths.ordersIndex()} className="brand">{appName}</a>
        <nav>
          <a href={paths.ordersIndex()}>
            Orders{openOrderCount > 0 && <span className="count-badge">{openOrderCount}</span>}
          </a>
          <a href={paths.ordersNew()}>New order</a>
        </nav>
      </header>
      {/* flash.notice / flash.alert rendered as a toast here */}
      {children}
    </>
  );
}
```

Every page in `examples/orders` re-exports the same `AppLayout`, so it
stays mounted (and its flash-toast timer keeps running) across every
`orders/*` navigation.

The client resolves both the page component and its `layout` export when
it loads a page module (`resolveComponentModule` in `js/src/element.ts`),
caches them together per `component_name`, and renders
`<Layout><Page {...props} /></Layout>` (or just `<Page />` if there's no
`layout` export).

**Why it doesn't remount:** the app's React root (`FondApp`, mounted once
by `createFondApp`) never unmounts across navigations — only the page
payload in the store changes, which re-renders `FondApp`. If two
consecutive pages export the *same* `Layout` reference (which they will,
if it's the same imported module), React's reconciliation sees the same
component type at the same position in the tree and keeps that instance
mounted — its state (scroll position of a sidebar, a collapsed nav
group, whatever) survives the navigation. Only `children` — the actual
page — gets swapped and remounted. Navigating to a page with a
*different* `layout` (or none) unmounts the old layout and mounts the new
one, as expected.

SSR applies the same resolution (`renderPageElement` in `element.ts`, used
by both `app.tsx` and the SSR sidecar's `handleRender`), so server-rendered
HTML already has the layout wrapping the page — no layout flash on
first load.

## Shared props

Declare a `T::Struct` for whatever should ride along on every page
payload, register it, and override `fond_shared_props`:

```ruby
# app/dtos/shared_props.rb
class SharedProps < T::Struct
  class Flash < T::Struct
    const :notice, T.nilable(String)
    const :alert, T.nilable(String)
  end

  const :app_name, String
  const :flash, Flash
  const :open_order_count, Integer
end
```

```ruby
# config/initializers/fond.rb
Fond.configure do |config|
  config.shared_props_class_name = "SharedProps"
end
```

```ruby
# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  include Fond::Controller

  def fond_shared_props
    SharedProps.new(
      app_name: "Fond Orders",
      flash: SharedProps::Flash.new(notice: flash[:notice], alert: flash[:alert]),
      open_order_count: Order.where(status: "pending").count,
    )
  end
end
```

`fond_shared_props` defaults to returning `nil` (opt-in — no shared props
by default). `render_page` calls it on every page render; if it returns
non-`nil`, the serialized result is attached to the payload under a
`shared` key (see the protocol's [page payload](/protocol/#page-payload)
reference), alongside `component`/`props`/`url`/`version`.

`shared_props_class_name` is what tells codegen which struct to walk for
`shared`. It emits a `useShared()` hook in `hooks.ts`:

```ts
export function useShared(): SharedProps {
  return useSharedProps<SharedProps>();
}
```

`useSharedProps` (from the `fond` package) reads `page.shared` off the
store and throws if it's `undefined` — i.e. if you call `useShared()` but
never configured `shared_props_class_name`/never overrode
`fond_shared_props`, you get a clear error instead of `undefined` leaking
into a component.

Because `fond_shared_props` runs per-request (it's a controller method,
not a static value), it's the natural place for things like flash
messages or a live "open order count" badge — every navigation
recomputes it, including client-side JSON navigations.
