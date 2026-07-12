import { createFondApp } from "fond";
import "../styles/app.css";

const pages = import.meta.glob("../pages/**/*.tsx");

createFondApp({
  resolve: (name) => {
    const loader = pages[`../pages/${name}.tsx`];
    if (!loader) throw new Error(`Unknown page component: ${name}`);
    return loader() as Promise<{ default: React.ComponentType }>;
  },
});
