# Fond

Typed React frontends for Ruby on Rails. Sorbet `T::Struct` DTOs are the API contract; Fond generates TypeScript types, data-fetching hooks, mutation hooks, and route helpers from them — one source of truth, no divergence.

**Status: early development.** See [PLAN.md](PLAN.md) for the design.

## Layout

- `ruby/` — the `fond` gem (page conventions, param coercion, codegen, transport)
- `js/` — the `fond` npm package (client router, hook runtime)
- `examples/orders/` — example Rails app exercising the full feature surface
- `docs/` — VitePress documentation site

## Development

```bash
pnpm install
(cd ruby && bundle install && bundle exec rake test)
pnpm --filter fond test
```

## License

MIT
