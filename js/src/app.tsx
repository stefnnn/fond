import { createElement, useEffect, useState, type ComponentType, type ReactNode } from "react";
import { createRoot, hydrateRoot } from "react-dom/client";
import { setPage, type PagePayload } from "./store.js";
import { usePage } from "./hooks.js";
import { installClickInterceptor, installPopStateListener } from "./router.js";
import { resolveComponentModule, renderResolvedElement, type ResolvedComponent } from "./element.js";

export type ComponentModule =
  | { default: ComponentType<any>; layout?: ComponentType<{ children: ReactNode }> }
  | ComponentType<any>;

export interface CreateFondAppOptions {
  resolve: (component: string) => Promise<ComponentModule> | ComponentModule;
  rootId?: string;
}

function readInitialPage(): PagePayload {
  const el = document.getElementById("fond-page-data");
  if (!el || !el.textContent) {
    throw new Error("fond: missing #fond-page-data script tag");
  }
  return JSON.parse(el.textContent) as PagePayload;
}

interface Rendered {
  Component: ComponentType<any>;
  Layout?: ComponentType<{ children: ReactNode }>;
  page: PagePayload;
}

function createFondAppComponent(
  resolve: CreateFondAppOptions["resolve"],
  cache: Map<string, ResolvedComponent>,
) {
  return function FondApp(): React.ReactElement | null {
    const page = usePage();
    const [rendered, setRendered] = useState<Rendered | null>(() => {
      const cached = cache.get(page.component);
      return cached ? { ...cached, page } : null;
    });

    useEffect(() => {
      let cancelled = false;

      const cached = cache.get(page.component);
      if (cached) {
        setRendered({ ...cached, page });
        return;
      }

      Promise.resolve(resolve(page.component)).then((mod) => {
        const resolvedComponent = resolveComponentModule(mod);
        cache.set(page.component, resolvedComponent);
        if (cancelled) return;
        setRendered({ ...resolvedComponent, page });
      });

      return () => {
        cancelled = true;
      };
    }, [page.component, page.props]);

    if (!rendered) return null;
    return renderResolvedElement(rendered.Component, rendered.Layout, rendered.page);
  };
}

export function createFondApp(options: CreateFondAppOptions): void {
  const { resolve, rootId = "fond-root" } = options;

  const initialPage = readInitialPage();
  setPage(initialPage);

  installClickInterceptor();
  installPopStateListener();

  const rootEl = document.getElementById(rootId);
  if (!rootEl) {
    throw new Error(`fond: missing root element #${rootId}`);
  }

  const cache = new Map<string, ResolvedComponent>();
  const FondApp = createFondAppComponent(resolve, cache);

  if (rootEl.hasChildNodes()) {
    Promise.resolve(resolve(initialPage.component))
      .then((mod) => {
        cache.set(initialPage.component, resolveComponentModule(mod));
        hydrateRoot(rootEl, createElement(FondApp));
      })
      .catch((err) => {
        console.error("fond: hydration failed", err);
      });
    return;
  }

  const root = createRoot(rootEl);
  root.render(createElement(FondApp));
}
