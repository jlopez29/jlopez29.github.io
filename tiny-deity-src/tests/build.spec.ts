import { test, expect } from "@playwright/test";
import { readFileSync } from "node:fs";
import { resolve, dirname } from "node:path";

test("production chunks share the HTML entry instead of importing an older game", () => {
  const root = resolve("../tiny-deity");
  const html = readFileSync(resolve(root, "index.html"), "utf8");
  const entry = html.match(/<script[^>]+src="([^"]+)"/)![1];
  const visited = new Set<string>();
  function visit(file: string) {
    if (visited.has(file)) return;
    visited.add(file);
    const source = readFileSync(file, "utf8");
    for (const match of source.matchAll(
      /\b(?:from\s*|import\s*(?:\(\s*)?)["'](\.[^"']+\.js)["']/g,
    )) {
      visit(resolve(dirname(file), match[1]));
    }
  }
  const main = resolve(root, entry);
  visit(main);
  expect(visited.size).toBeGreaterThan(5);
  expect(
    [...visited].filter((file) => /\/index-[^/]+\.js$/.test(file)),
  ).toEqual([main]);
});

test("production canvas handles pointer events and text without renderer errors", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  page.on("console", (message) => {
    if (
      message.type() === "error" ||
      /GL_INVALID_OPERATION|Insufficient buffer/.test(message.text())
    )
      errors.push(message.text());
  });
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  await expect(page.locator(".loading")).toHaveCount(0);
  const canvas = (await page.locator("canvas").boundingBox())!;
  await page.mouse.move(
    canvas.x + canvas.width / 2,
    canvas.y + canvas.height / 2,
    { steps: 10 },
  );
  await page.mouse.down();
  await page.mouse.move(
    canvas.x + canvas.width / 2 + 40,
    canvas.y + canvas.height / 2,
    { steps: 5 },
  );
  await page.mouse.up();
  await page.getByRole("button", { name: "Build something" }).click();
  await page.getByRole("button", { name: /Sunpatch farm/ }).click();
  await page.mouse.move(
    canvas.x + canvas.width / 2,
    canvas.y + canvas.height * 0.17,
  );
  // Building previews, inhabitant bubbles and placement labels exercise Pixi text.
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "test-results/production-renderer.png" });
  expect(errors).toEqual([]);
  const scripts = await page.evaluate(() =>
    performance
      .getEntriesByType("resource")
      .map((entry) => entry.name)
      .filter((url) => /\/index-[^/]+\.js$/.test(url)),
  );
  expect(scripts).toHaveLength(1);
});
