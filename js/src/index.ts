export const VERSION = "0.1.0";

export { createFondApp } from "./app.js";
export type { CreateFondAppOptions, ComponentModule } from "./app.js";
export { navigate, FondParamsError } from "./router.js";
export { usePage, usePageProps } from "./hooks.js";
export { buildPath } from "./path.js";
export type { PagePayload } from "./store.js";
