import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    ssr: "app/frontend/ssr/ssr.tsx",
    outDir: "tmp/ssr",
    emptyOutDir: true,
  },
});
