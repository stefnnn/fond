import { useState } from "react";
import {
  useOrdersShow,
  useOrdersUpdateStatus,
  useOrdersAddNote,
  useOrdersDestroy,
} from "../../generated/hooks";
import { paths } from "../../generated/paths";
import type { OrderStatus } from "../../generated/types";
import { Money } from "../../components/Money";
import { StatusBadge, STATUSES } from "../../components/StatusBadge";
import { BaseErrors, FieldErrors } from "../../components/FormErrors";

export default function OrdersShow() {
  const { order, lineItems, activity } = useOrdersShow();
  const updateStatus = useOrdersUpdateStatus();
  const addNote = useOrdersAddNote();
  const destroy = useOrdersDestroy();
  const [note, setNote] = useState("");

  return (
    <main className="container">
      <p><a href={paths.ordersIndex()}>‹ All orders</a></p>
      <header className="page-header">
        <h1>Order #{order.id}</h1>
        <span>
          <StatusBadge status={order.status} />{" "}
          <select
            value={order.status}
            disabled={updateStatus.pending}
            onChange={(e) =>
              void updateStatus.mutate({ id: order.id, status: e.target.value as OrderStatus })
            }
          >
            {STATUSES.map((s) => <option key={s} value={s}>{s}</option>)}
          </select>{" "}
          <button
            className="danger"
            disabled={destroy.pending}
            onClick={() => confirm("Delete this order?") && void destroy.mutate({ id: order.id })}
          >
            Delete
          </button>
        </span>
      </header>
      <BaseErrors errors={updateStatus.errors} />

      <dl className="order-meta">
        <dt>Customer</dt>
        <dd>{order.customerName} ({order.customerEmail})</dd>
        <dt>Placed</dt>
        <dd>{new Date(order.placedAt).toLocaleString()}</dd>
        {order.notes && (
          <>
            <dt>Notes</dt>
            <dd>{order.notes}</dd>
          </>
        )}
      </dl>

      <h2>Items</h2>
      <table className="orders-table">
        <thead>
          <tr><th>Product</th><th className="num">Qty</th><th className="num">Unit</th><th className="num">Total</th></tr>
        </thead>
        <tbody>
          {lineItems.map((li) => (
            <tr key={li.id}>
              <td>{li.productName}</td>
              <td className="num">{li.quantity}</td>
              <td className="num"><Money cents={li.unitPriceCents} /></td>
              <td className="num"><Money cents={li.quantity * li.unitPriceCents} /></td>
            </tr>
          ))}
        </tbody>
        <tfoot>
          <tr>
            <td colSpan={3}>Total</td>
            <td className="num"><Money cents={order.totalCents} /></td>
          </tr>
        </tfoot>
      </table>

      <h2>Activity</h2>
      <form
        className="note-form"
        onSubmit={(e) => {
          e.preventDefault();
          void addNote.mutate({ id: order.id, body: note }).then((r) => r.ok && setNote(""));
        }}
      >
        <input
          value={note}
          onChange={(e) => setNote(e.target.value)}
          placeholder="Add a note…"
        />
        <button type="submit" disabled={addNote.pending}>Add</button>
        <FieldErrors errors={addNote.errors} field="body" />
      </form>
      <ul className="activity">
        {activity.map((event) => (
          <li key={`${event.type}-${event.id}`}>
            <span className="muted">{new Date(event.createdAt).toLocaleString()} · {event.author} — </span>
            {event.type === "note" ? (
              <span>{event.body}</span>
            ) : (
              <span>
                status <StatusBadge status={event.fromStatus} /> → <StatusBadge status={event.toStatus} />
              </span>
            )}
          </li>
        ))}
      </ul>
    </main>
  );
}
