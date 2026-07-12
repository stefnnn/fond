import type { OrderStatus } from "../generated/types";

export const STATUSES: OrderStatus[] = ["pending", "paid", "shipped", "cancelled"];

export function StatusBadge({ status }: { status: OrderStatus }) {
  return <span className={`badge badge-${status}`}>{status}</span>;
}
