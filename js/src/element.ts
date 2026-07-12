import { createElement, type ComponentType, type ReactElement, type ReactNode } from "react";
import type { ComponentModule } from "./app.js";

export interface ResolvedComponent {
  Component: ComponentType<any>;
  Layout?: ComponentType<{ children: ReactNode }>;
}

export function resolveComponentModule(mod: ComponentModule): ResolvedComponent {
  if (typeof mod === "function") return { Component: mod };
  return { Component: mod.default, Layout: mod.layout };
}

export function renderPageElement(mod: ComponentModule, props: unknown): ReactElement {
  const { Component, Layout } = resolveComponentModule(mod);
  return renderResolvedElement(Component, Layout, props);
}

export function renderResolvedElement(
  Component: ComponentType<any>,
  Layout: ComponentType<{ children: ReactNode }> | undefined,
  props: unknown,
): ReactElement {
  const page = createElement(Component, props as object);
  return Layout ? createElement(Layout, null, page) : page;
}
