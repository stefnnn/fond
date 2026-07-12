import { createSsrServer } from "fond/ssr";

const pages = import.meta.glob("../pages/**/*.tsx");

createSsrServer({
  resolve: (name) => {
    const loader = pages[`../pages/${name}.tsx`];
    if (!loader) throw new Error(`Unknown page component: ${name}`);
    return loader() as Promise<{ default: React.ComponentType }>;
  },
  port: Number(process.env.FOND_SSR_PORT ?? 13714),
});
