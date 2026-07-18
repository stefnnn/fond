import { useContext, useSyncExternalStore } from "react";
import { getPage, subscribe, PageContext, type PagePayload } from "./store.js";

export function usePage(): PagePayload {
  const live = useSyncExternalStore(subscribe, getPage, getPage);
  const pinned = useContext(PageContext);
  return pinned ?? live;
}

export function usePageProps<T>(expected?: string): T {
  const page = usePage();
  if (expected !== undefined && page.component !== expected) {
    throw new Error(
      `fond: usePageProps expected component "${expected}" but current page is "${page.component}"`,
    );
  }
  return page.props as T;
}

export function useSharedProps<T>(): T {
  const page = usePage();
  if (page.shared === undefined) {
    throw new Error(
      "fond: useSharedProps called but no shared props were provided by the server",
    );
  }
  return page.shared as T;
}
