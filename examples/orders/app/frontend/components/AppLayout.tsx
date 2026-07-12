import { useEffect, useState, type ReactNode } from "react";
import { useShared } from "../generated/hooks";
import { paths } from "../generated/paths";

export function AppLayout({ children }: { children: ReactNode }) {
  const { appName, flash, openOrderCount } = useShared();

  return (
    <>
      <header className="app-header">
        <a href={paths.ordersIndex()} className="brand">{appName}</a>
        <nav>
          <a href={paths.ordersIndex()}>
            Orders{openOrderCount > 0 && <span className="count-badge">{openOrderCount}</span>}
          </a>
          <a href={paths.ordersNew()}>New order</a>
        </nav>
      </header>
      <div className="toasts">
        <FlashToast kind="notice" message={flash.notice} />
        <FlashToast kind="alert" message={flash.alert} />
      </div>
      {children}
    </>
  );
}

function FlashToast({ kind, message }: { kind: "notice" | "alert"; message: string | null }) {
  const [visible, setVisible] = useState(message !== null);

  useEffect(() => {
    setVisible(message !== null);
    if (message === null) return;
    const timer = setTimeout(() => setVisible(false), 4000);
    return () => clearTimeout(timer);
  }, [message]);

  if (!visible || message === null) return null;
  return <div className={`toast toast-${kind}`}>{message}</div>;
}
