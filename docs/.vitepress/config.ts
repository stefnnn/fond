import { defineConfig } from "vitepress";

export default defineConfig({
  title: "Fond",
  description:
    "Typed React frontends for Rails — Sorbet DTOs as the contract, generated TypeScript types and hooks",
  base: "/fond/",
  themeConfig: {
    nav: [
      { text: "Guide", link: "/guide/getting-started" },
      { text: "Protocol", link: "/protocol/" },
      { text: "GitHub", link: "https://github.com/stefnnn/fond" },
    ],
    sidebar: [
      {
        text: "Guide",
        items: [
          { text: "Getting Started", link: "/guide/getting-started" },
          { text: "Pages & DTOs", link: "/guide/pages" },
          { text: "Codegen", link: "/guide/codegen" },
        ],
      },
      {
        text: "Reference",
        items: [{ text: "Transport Protocol", link: "/protocol/" }],
      },
    ],
  },
});
