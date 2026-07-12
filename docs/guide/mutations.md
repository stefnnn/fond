# Mutations

Mutations are the write side: `POST`/`PATCH`/`PUT`/`DELETE` actions with no
HTML representation, declared with a `Fond::Mutation` subclass instead of
`Fond::Page`.

```ruby
module Orders
  class CreateMutation < Fond::Mutation
    class LineItemInput < T::Struct
      const :product_name, String
      const :quantity, Integer
      const :unit_price_cents, Integer
    end

    class Params < T::Struct
      const :customer_name, String
      const :customer_email, String
      const :notes, T.nilable(String)
      const :line_items, T::Array[LineItemInput]
    end
  end
end
```

- **`Params`** — required (`Fond::Codegen::Generator` raises if missing).
  Coerced with the same rules as page params — see
  [Pages & DTOs](/guide/pages#coercion-rules). Path params (e.g. `:id` in
  `PATCH /orders/:id`) are merged into the same struct; the generated
  `useMutation` hook splits them back out when building the request.
- **`Props`** — optional. Most mutations redirect instead of returning
  data; include a `Props` struct only if the caller needs something back
  without navigating (`useMutation` then returns
  `Mutation<Params, YourProps>` instead of `Mutation<Params, null>`).

## Controller DSL

```ruby
class OrdersController < ApplicationController
  mutation Orders::CreateMutation
  def create(params)
    if params.line_items.empty?
      return invalid(base: [ "Add at least one line item" ])
    end

    order = Order.new(customer_name: params.customer_name, ...)
    Order.transaction do
      order.save!
      params.line_items.each { |li| order.line_items.create!(...) }
    end

    redirect_page order_path(order)
  rescue ActiveRecord::RecordInvalid => e
    invalid(e.record.errors)
  end
end
```

Same `send_action` machinery as pages: params are coerced before your
method runs, and the action's return value decides the response.

## Return-value protocol

| Return | Response | Client (`mutate()` resolves to) |
| --- | --- | --- |
| `redirect_page(url)` → `Fond::Redirect` | `200 { redirect: url }` | `{ ok: true, redirected: true, data: null }`, then soft-navigates to `url` |
| a `Props` instance | `200 { props: ... }` | `{ ok: true, redirected: false, data: <Props> }` |
| `Fond::Done` | `200 { props: null }` | `{ ok: true, redirected: false, data: null }` |
| `invalid(...)` / `ActiveModel::Errors` | `422 { errors: { base, fields } }` | `{ ok: false, errors }`; the hook's `errors` state is set |

`invalid(source = nil, base: [], fields: {})` builds a `Fond::Invalid`:
pass an `ActiveModel::Errors` object (`invalid(e.record.errors)`) to
convert it automatically, or pass `base:`/`fields:` directly for
hand-rolled validation. `render_mutation_result` also accepts a bare
`ActiveModel::Errors` return value without wrapping it yourself.

A `400 { error: "invalid_params", errors: {...} }` is also possible, but
only for a **coercion** failure (the request body didn't match `Params`'
types at all) — the client treats this as a bug, not a user error, and
throws (`FondParamsError`) rather than populating form errors.

## Canonical error shape

```ts
interface FormErrors {
  base: string[];
  fields: Record<string, string[]>;
}
```

`base` is record-level messages (`"Add at least one line item"`); `fields`
is keyed by camelCase attribute name. `Fond::Invalid#to_wire` builds this
from an `ActiveModel::Errors` via `full_messages_for` per attribute, or
from explicit `base:`/`fields:` kwargs (field keys camelized).

## `useMutation` in a form

Real example, `examples/orders/app/frontend/pages/orders/new.tsx`:

```tsx
import { useOrdersNew, useOrdersCreate } from "../../generated/hooks";
import { FieldErrors, BaseErrors } from "../../components/FormErrors";

export default function OrdersNew() {
  const { suggestedProducts } = useOrdersNew();
  const { mutate, errors, pending } = useOrdersCreate();

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    void mutate({
      customerName,
      customerEmail,
      notes: notes || null,
      lineItems: rows.map((r) => ({
        productName: r.productName,
        quantity: Number(r.quantity),
        unitPriceCents: Math.round(Number(r.unitPriceCents) * 100),
      })),
    });
  };

  return (
    <form onSubmit={submit}>
      <BaseErrors errors={errors} />
      <input value={customerName} onChange={(e) => setCustomerName(e.target.value)} />
      <FieldErrors errors={errors} field="customerName" />
      {/* ... */}
      <button type="submit" disabled={pending}>{pending ? "Creating…" : "Create order"}</button>
    </form>
  );
}
```

`FormErrors.tsx` is plain app code built on the generated `FormErrors`
type, not generated itself:

```tsx
export function BaseErrors({ errors }: { errors: FormErrors | null }) {
  if (!errors || errors.base.length === 0) return null;
  return <div className="error-box">{errors.base.map((m) => <p key={m}>{m}</p>)}</div>;
}

export function FieldErrors({ errors, field }: { errors: FormErrors | null; field: string }) {
  const messages = errors?.fields[field];
  if (!messages?.length) return null;
  return <span className="field-error">{messages.join(", ")}</span>;
}
```

`useMutation` returns `{ mutate, pending, errors, reset }`. On a redirect
response it calls `navigate()` itself — you don't need to handle that
case. `mutate()`'s resolved value is a discriminated union
(`MutationOutcome<R>`), useful when you need to branch on success without
relying on the redirect, e.g. the "add a note" form clears its input only
`.then((r) => r.ok && setNote(""))`.

## CSRF

The hook reads the token from `<meta name="csrf-token">` (emitted by
Rails' `csrf_meta_tags`, required in your layout — see
[Getting Started](/guide/getting-started)) and sends it as
`X-CSRF-Token` on every mutation request. This is invisible to app code;
there's nothing to configure.
