import { defineConfig } from "@playwright/test";
export default defineConfig({
  workers: 1,
  testDir: "./tests",
  testMatch: "*.spec.ts",
  timeout: 180000,
  expect: { timeout: 10000 },
  use: {
    baseURL: "http://127.0.0.1:4173",
    headless: true,
    viewport: { width: 1200, height: 900 },
    launchOptions: {
      args: [
        "--use-gl=angle",
        "--use-angle=swiftshader",
        "--enable-webgl",
        "--no-sandbox",
      ],
    },
  },
  webServer: {
    command: "python3 -m http.server 4173 --bind 127.0.0.1 --directory ..",
    url: "http://127.0.0.1:4173/tiny-deity/",
    reuseExistingServer: !process.env.CI,
  },
  reporter: "list",
});
