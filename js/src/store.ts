import { createContext } from "react";

export interface PagePayload {
  component: string;
  props: unknown;
  url: string;
  version: string;
  shared?: unknown;
}

// Set by FondApp around the currently-rendered page, pinning that subtree to
// the payload it was resolved with. Without this, a still-mounted previous
// page would read the live store below and see the *next* page's identity
// while its dynamic import is still resolving.
export const PageContext = createContext<PagePayload | null>(null);

type Listener = () => void;

let page: PagePayload | null = null;
const listeners = new Set<Listener>();

export function getPage(): PagePayload {
  if (page === null) {
    throw new Error("fond: page store not initialized yet");
  }
  return page;
}

export function setPage(next: PagePayload): void {
  page = next;
  for (const listener of listeners) listener();
}

export function subscribe(listener: Listener): () => void {
  listeners.add(listener);
  return () => listeners.delete(listener);
}
