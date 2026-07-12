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
