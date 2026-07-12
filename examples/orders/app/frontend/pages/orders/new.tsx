import { useState } from "react";
import { useOrdersNew, useOrdersCreate } from "../../generated/hooks";
import { paths } from "../../generated/paths";
import { FieldErrors, BaseErrors } from "../../components/FormErrors";

interface ItemRow {
  productName: string;
  quantity: string;
  unitPriceCents: string;
}

const emptyRow: ItemRow = { productName: "", quantity: "1", unitPriceCents: "" };

export default function OrdersNew() {
  const { suggestedProducts } = useOrdersNew();
  const { mutate, errors, pending } = useOrdersCreate();

  const [customerName, setCustomerName] = useState("");
  const [customerEmail, setCustomerEmail] = useState("");
  const [notes, setNotes] = useState("");
  const [rows, setRows] = useState<ItemRow[]>([emptyRow]);

  const updateRow = (i: number, patch: Partial<ItemRow>) =>
    setRows(rows.map((r, j) => (j === i ? { ...r, ...patch } : r)));

  const submit = (e: React.FormEvent) => {
    e.preventDefault();
    void mutate({
      customerName,
      customerEmail,
      notes: notes || null,
      lineItems: rows
        .filter((r) => r.productName)
        .map((r) => ({
          productName: r.productName,
          quantity: Number(r.quantity),
          unitPriceCents: Math.round(Number(r.unitPriceCents) * 100),
        })),
    });
  };

  return (
    <main className="container">
      <p><a href={paths.ordersIndex()}>‹ All orders</a></p>
      <h1>New order</h1>

      <form onSubmit={submit} className="order-form">
        <BaseErrors errors={errors} />

        <label>
          Customer name
          <input value={customerName} onChange={(e) => setCustomerName(e.target.value)} />
          <FieldErrors errors={errors} field="customerName" />
        </label>

        <label>
          Email
          <input value={customerEmail} onChange={(e) => setCustomerEmail(e.target.value)} />
          <FieldErrors errors={errors} field="customerEmail" />
        </label>

        <label>
          Notes
          <textarea value={notes} onChange={(e) => setNotes(e.target.value)} rows={2} />
        </label>

        <h2>Items</h2>
        <datalist id="products">
          {suggestedProducts.map((p) => <option key={p} value={p} />)}
        </datalist>
        {rows.map((row, i) => (
          <div className="item-row" key={i}>
            <input
              list="products"
              placeholder="Product"
              value={row.productName}
              onChange={(e) => updateRow(i, { productName: e.target.value })}
            />
            <input
              type="number"
              min={1}
              value={row.quantity}
              onChange={(e) => updateRow(i, { quantity: e.target.value })}
            />
            <input
              type="number"
              step="0.01"
              min={0}
              placeholder="Price"
              value={row.unitPriceCents}
              onChange={(e) => updateRow(i, { unitPriceCents: e.target.value })}
            />
            <button type="button" onClick={() => setRows(rows.filter((_, j) => j !== i))}>✕</button>
          </div>
        ))}
        <button type="button" className="secondary" onClick={() => setRows([...rows, emptyRow])}>
          + Add item
        </button>

        <footer>
          <button type="submit" disabled={pending}>
            {pending ? "Creating…" : "Create order"}
          </button>
        </footer>
      </form>
    </main>
  );
}
