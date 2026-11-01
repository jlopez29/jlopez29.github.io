import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
export default defineConfig({
  plugins: [react()],
  base: "./",
  build: {
    outDir: "../tiny-deity",
    emptyOutDir: true,
    chunkSizeWarningLimit: 1200,
  },
  server: { host: "0.0.0.0" },
});
