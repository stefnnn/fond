---
layout: home
hero:
  name: Fond
  text: Typed React frontends for Rails
  tagline: Sorbet DTOs as the API contract. Generated TypeScript types, hooks, and routes. No divergence.
  actions:
    - theme: brand
      text: Get Started
      link: /guide/getting-started
features:
  - title: One source of truth
    details: Your T::Struct props are the serializer, the validator, and the TypeScript types.
  - title: Inertia-style navigation
    details: Server-driven pages with client-side routing, without building an API.
  - title: Typed mutations
    details: Forms with generated hooks, typed params, and structured validation errors.
  - title: Optional SSR
    details: A sidecar renders pages server-side and degrades to client rendering if it's unavailable.
  - title: Layouts & shared props
    details: Persistent layout components across navigations, plus a shared props struct on every payload.
  - title: Codegen with a drift check
    details: types.ts, hooks.ts, and paths.ts are generated from your Ruby definitions; CI fails if they're stale.
---
