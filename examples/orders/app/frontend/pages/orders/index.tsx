import { navigate, usePage } from "fond";
import { useOrdersIndex } from "../../generated/hooks";
import { paths } from "../../generated/paths";
import type { OrderStatus } from "../../generated/types";
import { Money } from "../../components/Money";
import { StatusBadge, STATUSES } from "../../components/StatusBadge";

export default function OrdersIndex() {
  const { orders, totalCount, page, perPage, statusCounts } = useOrdersIndex();
  const { url } = usePage();
  const params = new URLSearchParams(url.split("?")[1] ?? "");
  const activeStatus = (params.get("status") || null) as OrderStatus | null;
  const query = params.get("query") ?? "";
  const totalPages = Math.max(1, Math.ceil(totalCount / perPage));

  const filter = (status: OrderStatus | null) =>
    navigate(paths.ordersIndex({ status, query: query || null }));

  return (
    <main className="container">
      <header className="page-header">
        <h1>Orders</h1>
        <a className="button-link" href={paths.ordersNew()}>+ New order</a>
        <form
          onSubmit={(e) => {
            e.preventDefault();
            const q = new FormData(e.currentTarget).get("query") as string;
            navigate(paths.ordersIndex({ status: activeStatus, query: q || null }));
          }}
        >
          <input name="query" type="search" defaultValue={query} placeholder="Search customers…" />
        </form>
      </header>

      <nav className="filters">
        <FilterTab label="All" active={activeStatus === null} onClick={() => filter(null)} />
        {STATUSES.map((s) => (
          <FilterTab
            key={s}
            label={`${s} (${statusCounts[s] ?? 0})`}
            active={activeStatus === s}
            onClick={() => filter(s)}
          />
        ))}
      </nav>

      <table className="orders-table">
        <thead>
          <tr>
            <th>#</th><th>Customer</th><th>Status</th><th>Placed</th><th className="num">Total</th>
          </tr>
        </thead>
        <tbody>
          {orders.map((o) => (
            <tr key={o.id}>
              <td><a href={paths.ordersShow({ id: o.id })}>#{o.id}</a></td>
              <td>
                {o.customerName}
                <span className="muted"> · {o.customerEmail}</span>
              </td>
              <td><StatusBadge status={o.status} /></td>
              <td>{new Date(o.placedAt).toLocaleDateString()}</td>
              <td className="num"><Money cents={o.totalCents} /></td>
            </tr>
          ))}
        </tbody>
      </table>
      {orders.length === 0 && <p className="empty">No orders match.</p>}

      <footer className="pagination">
        <span>{totalCount} orders</span>
        <span>
          <PageLink label="‹ Prev" to={page - 1} disabled={page <= 1} status={activeStatus} query={query} />
          {" "}page {page} / {totalPages}{" "}
          <PageLink label="Next ›" to={page + 1} disabled={page >= totalPages} status={activeStatus} query={query} />
        </span>
      </footer>
    </main>
  );
}

function FilterTab({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button className={active ? "tab active" : "tab"} onClick={onClick}>
      {label}
    </button>
  );
}

function PageLink(props: {
  label: string;
  to: number;
  disabled: boolean;
  status: OrderStatus | null;
  query: string;
}) {
  if (props.disabled) return <span className="muted">{props.label}</span>;
  return (
    <a href={paths.ordersIndex({ page: props.to, status: props.status, query: props.query || null })}>
      {props.label}
    </a>
  );
}
