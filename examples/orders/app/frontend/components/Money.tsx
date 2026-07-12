export function Money({ cents }: { cents: number }) {
  return <span>{(cents / 100).toLocaleString(undefined, { style: "currency", currency: "USD" })}</span>;
}
