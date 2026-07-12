export interface PagePayload {
  component: string;
  props: unknown;
  url: string;
  version: string;
  shared?: unknown;
}

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
