import { defineConfig } from "vite";

// Página única; base relativa para funcionar no Lovable e no GitHub Pages.
export default defineConfig({
  base: "./",
  server: { host: "::", port: 8080 },
});
