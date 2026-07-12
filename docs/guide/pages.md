# Pages & DTOs

## Defining a page

A page is a subclass of `Fond::Page` with up to two nested `T::Struct`
classes:

```ruby
module Orders
  class ShowPage < Fond::Page
    class Params < T::Struct
      const :id, Integer
    end

    class Props < T::Struct
      const :order, OrderDTO
      const :line_items, T::Array[LineItemDTO]
      const :activity, T::Array[OrderEventDTO]
    end
  end
end
```

- **`Params`** — optional. Query/path/body params, coerced (see below)
  before your action ever sees them. Pages with no inputs (e.g. a static
  `NewPage`) omit it.
- **`Props`** — required. `Fond::Page.props_class` raises if it's missing.
  This struct *is* the page payload's serializer — `Fond::Serialize.to_wire`
  walks its props and camelizes the keys, it doesn't go through
  ActiveModel or a separate serializer layer.

Both classes are looked up via `const_defined?(:Params, false)` /
`const_get(:Props, false)` — `false` means "don't search ancestors", so
each page's structs are genuinely its own.

## `component_name`

The client identifies a page by a string derived from the class name:

```
Orders::IndexPage → "orders/index"
```

Implementation (`Fond::Page.component_name`): strip the trailing `Page`,
replace `::` with `/`, then snake_case each segment. This is the value
sent as `component` in the wire payload and the key codegen uses in
`pages.ts` and the `use<Name>` hooks.

## Controller integration

```ruby
class OrdersController < ApplicationController
  page Orders::ShowPage
  def show(params) # typed Params instance, arity 1
    Orders::ShowPage::Props.new(order: OrderDTO.from_model(Order.find(params.id)), ...)
  end
end
```

`page Orders::ShowPage` registers the page for the `:show` action (inferred
from `component_name.split("/").last`; pass `action:` to override). At
request time (`Fond::Controller#send_action`):

1. Path params, then query params, then JSON body params are merged
   (later sources win) and coerced into `Params` via `Fond::Coerce.struct`.
2. If your action method has arity 0, it's called with no arguments
   (params-less pages); otherwise it's called with the typed `Params`
   instance.
3. If the action returns a `T::Struct` (i.e. a `Props` instance) and
   hasn't already rendered, `render_page` is called automatically.

So the common case is a pure function `Params -> Props` — you don't call
`render_page` yourself.

## `render_page` escape hatch

For anything conditional — rendering a different page, falling back to a
plain Rails render, redirecting from a GET — call `render_page` (or a
regular `render`/`redirect_to`) explicitly and don't rely on the return
value:

```ruby
def show(params)
  order = Order.find_by(id: params.id)
  return redirect_to root_path unless order
  render_page Orders::ShowPage::Props.new(order: OrderDTO.from_model(order), ...)
end
```

`render_page(props, page: nil)` looks up the declared page for the current
action if `page:` isn't given, serializes `props`, and renders either the
JSON payload (client navigation, `X-Fond: true`) or the full HTML shell.

## Coercion rules

`T::Struct.from_hash` neither coerces nor validates, so Fond walks
`Params.props[name][:type_object]` (the full `T::Types::Base` tree, not
the flattened `:type` key) and coerces by hand. Keys are matched
camelCase-first, snake_case as fallback (`Fond::Naming.camelize`).

| Ruby type | Accepts | Notes |
| --- | --- | --- |
| `Integer` | `Integer`, or `String` matching `-?\d+` | `.to_i` |
| `Float` | `Numeric`, or a parseable `String` | `Float()` |
| `String` | `String` only | |
| `Symbol` | `String` or `Symbol` | `.to_sym` |
| `T::Boolean` (`T.any(TrueClass, FalseClass)`) | `true`/`false`, `"true"`/`"1"`, `"false"`/`"0"` | |
| `Date` | `Date`, or ISO8601 `String` | `Date.iso8601` |
| `Time` | `Time`, or ISO8601 `String` | `Time.iso8601` |
| `DateTime` | `DateTime`, or ISO8601 `String` | `DateTime.iso8601` |
| `T::Enum` subclass | the enum instance, or its serialized `String` | `klass.deserialize` |
| `T::Struct` subclass (nested) | a `Hash` | recurses |
| `T::Array[X]` | an `Array` | each element coerced as `X`, path `field.0`, `field.1`, ... |
| `T::Hash[K, V]` | a `Hash` | keys and values coerced independently |
| `T.nilable(X)` | `nil` or `""` → `nil`; anything else coerced as `X` | `""` → `nil` **only** applies to nilable fields |
| `T.any(A, B, ...)` of structs | a `Hash` | see discriminated unions below |
| missing key | — | `nil` if nilable, the struct's `default:` if present, otherwise a `"is required"` error |

Discriminated unions (`T.any(StatusChangeEventDTO, NoteEventDTO)`): if the
input hash has a `"type"` key, Fond looks for a member struct whose `type`
prop has a `default:` matching that string and coerces against it
directly. Otherwise it tries each member struct in order and returns the
first one that coerces cleanly. This is why discriminated-union DTOs
declare `const :type, String, default: "note"` — see
[Codegen](/guide/codegen#discriminated-unions) for how that becomes a TS
literal union.

## 400 on bad params

If coercion fails, `Fond::Coerce::Error#errors` is a `{ "dotted.path" =>
"message" }` hash and the controller responds:

```json
{ "error": "invalid_params", "errors": { "page": "must be an integer" } }
```

with status `400`, **before your action method runs**. This is the same
shape used for mutation param coercion failures — see the protocol
reference's [Invalid params](/protocol/#invalid-params) section, which is
normative for the wire format.
