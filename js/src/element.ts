import { createElement, type ComponentType, type ReactElement, type ReactNode } from "react";
import type { ComponentModule } from "./app.js";
import { PageContext, type PagePayload } from "./store.js";

export interface ResolvedComponent {
  Component: ComponentType<any>;
  Layout?: ComponentType<{ children: ReactNode }>;
}

export function resolveComponentModule(mod: ComponentModule): ResolvedComponent {
  if (typeof mod === "function") return { Component: mod };
  return { Component: mod.default, Layout: mod.layout };
}

export function renderPageElement(mod: ComponentModule, page: PagePayload): ReactElement {
  const { Component, Layout } = resolveComponentModule(mod);
  return renderResolvedElement(Component, Layout, page);
}

export function renderResolvedElement(
  Component: ComponentType<any>,
  Layout: ComponentType<{ children: ReactNode }> | undefined,
  page: PagePayload,
): ReactElement {
  const element = createElement(Component, page.props as object);
  const tree = Layout ? createElement(Layout, null, element) : element;
  return createElement(PageContext.Provider, { value: page }, tree);
}
