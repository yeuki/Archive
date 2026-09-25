import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  base: process.env.ARCHIVE_WEB_BASE || "./",
  plugins: [react()],
});
