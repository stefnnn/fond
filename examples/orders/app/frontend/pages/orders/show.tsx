import { useOrdersShow } from "../../generated/hooks";
import { paths } from "../../generated/paths";
import { Money } from "../../components/Money";
import { StatusBadge } from "../../components/StatusBadge";

export default function OrdersShow() {
  const { order, lineItems, activity } = useOrdersShow();

  return (
    <main className="container">
      <p><a href={paths.ordersIndex()}>‹ All orders</a></p>
      <header className="page-header">
        <h1>Order #{order.id}</h1>
        <StatusBadge status={order.status} />
      </header>

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
