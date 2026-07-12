import { createElement, useEffect, useState, type ComponentType } from "react";
import { createRoot } from "react-dom/client";
import { setPage, type PagePayload } from "./store.js";
import { usePage } from "./hooks.js";
import { installClickInterceptor, installPopStateListener } from "./router.js";

export type ComponentModule =
  | { default: ComponentType<any> }
  | ComponentType<any>;

export interface CreateFondAppOptions {
  resolve: (component: string) => Promise<ComponentModule> | ComponentModule;
  rootId?: string;
}

function extractComponent(mod: ComponentModule): ComponentType<any> {
  return typeof mod === "function" ? mod : mod.default;
}

function readInitialPage(): PagePayload {
  const el = document.getElementById("fond-page-data");
  if (!el || !el.textContent) {
    throw new Error("fond: missing #fond-page-data script tag");
  }
  return JSON.parse(el.textContent) as PagePayload;
}

interface Rendered {
  name: string;
  Component: ComponentType<any>;
  props: unknown;
}

function createFondAppComponent(resolve: CreateFondAppOptions["resolve"]) {
  const cache = new Map<string, ComponentType<any>>();

  return function FondApp(): React.ReactElement | null {
    const page = usePage();
    const [rendered, setRendered] = useState<Rendered | null>(() => {
      const cached = cache.get(page.component);
      return cached
        ? { name: page.component, Component: cached, props: page.props }
        : null;
    });

    useEffect(() => {
      let cancelled = false;

      const cached = cache.get(page.component);
      if (cached) {
        setRendered({ name: page.component, Component: cached, props: page.props });
        return;
      }

      Promise.resolve(resolve(page.component)).then((mod) => {
        if (cancelled) return;
        const Component = extractComponent(mod);
        cache.set(page.component, Component);
        setRendered({ name: page.component, Component, props: page.props });
      });

      return () => {
        cancelled = true;
      };
    }, [page.component, page.props]);

    if (!rendered) return null;
    return createElement(rendered.Component, rendered.props as object);
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

  const FondApp = createFondAppComponent(resolve);
  const root = createRoot(rootEl);
  root.render(createElement(FondApp));
}
