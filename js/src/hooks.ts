import { useSyncExternalStore } from "react";
import { getPage, subscribe, type PagePayload } from "./store.js";

export function usePage(): PagePayload {
  return useSyncExternalStore(subscribe, getPage, getPage);
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
