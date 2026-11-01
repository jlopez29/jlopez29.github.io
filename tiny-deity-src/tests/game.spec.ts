import { test, expect, type Page } from "@playwright/test";
async function start(page: Page) {
  await page.goto("/tiny-deity/");
  await page.addLocatorHandler(
    page.getByRole("dialog", { name: "Level up" }),
    async () => {
      await page.getByRole("button", { name: "Keep growing" }).click();
    },
  );
  await expect(page.locator("canvas")).toBeVisible();
  await expect(page.getByText("Growing your little world…")).toHaveCount(0);
  await page.waitForTimeout(1500);
}
async function closeLevel(page: Page) {
  await page.waitForTimeout(450);
  const keep = page.getByRole("button", { name: "Keep growing" });
  if (await keep.isVisible()) await keep.click();
}
test("main page launches the playable game; planet, navigation, and direct rain work", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await page.goto("/");
  await page.getByRole("link", { name: "Make a little wonder" }).click();
  await expect(page.locator("canvas")).toBeVisible();
  await page.waitForTimeout(1700);
  await expect(
    page.getByRole("heading", { name: "Clover · tiny deity", exact: true }),
  ).toBeVisible();
  await expect(page.getByTestId("mana")).toContainText("10.0");
  await page.getByRole("button", { name: "Weather", exact: true }).click();
  await page.getByRole("button", { name: "Rain", exact: true }).click();
  const canvas = page.locator("canvas"),
    box = (await canvas.boundingBox())!;
  await page.mouse.click(
    box.x + box.width * 0.5,
    box.y + box.height * 0.17 - 4,
  );
  await expect(page.getByTestId("mana")).toContainText("9.");
  await page.getByRole("button", { name: "Rotate planet left" }).click();
  await page.getByRole("button", { name: "Zoom out", exact: true }).click();
  await page.getByRole("button", { name: "Full planet overview" }).click();
  await page.waitForTimeout(1200);
  await page.screenshot({ path: "test-results/planet-overview.png" });
  await page.getByRole("button", { name: "Return to home view" }).click();
  await page.waitForTimeout(1000);
  await page.screenshot({ path: "test-results/desktop-world.png" });
  expect(errors).toEqual([]);
});
test("a follower builds and operates a farm, collects gold, and survives save/reload", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (e) => errors.push(e.message));
  await start(page);
  await page.getByRole("button", { name: "More", exact: true }).click();
  await page.getByRole("button", { name: /followers.*curious souls/ }).click();
  await page.getByRole("button", { name: "Pip Curious inhabitant" }).click();
  await page.getByRole("button", { name: "Rain on Pip" }).click();
  await closeLevel(page);
  await expect(page.getByText("A DEVOTED LITTLE SOUL")).toBeVisible();
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page
    .getByText("Simulation speed")
    .locator("..")
    .locator("select")
    .selectOption("4");
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.getByRole("button", { name: "Build something" }).click();
  await page.getByRole("button", { name: /Sunpatch farm/ }).click();
  await page.getByRole("button", { name: "Return to home view" }).click();
  await page.waitForTimeout(1200);
  await closeLevel(page);
  const box = (await page.locator("canvas").boundingBox())!;
  await page.mouse.click(
    box.x + box.width / 2 + Math.sin(0.6) * box.height * 0.34,
    box.y + box.height * 0.51 - Math.cos(0.6) * box.height * 0.34,
  );
  await expect(
    page.getByRole("heading", { name: "Sunpatch farm", exact: true }),
  ).toBeVisible();
  const assignment = page.getByLabel("Assign available follower");
  if (await assignment.isVisible()) await assignment.selectOption({ index: 1 });
  await expect(
    page.getByText("UNDER CONSTRUCTION", { exact: false }),
  ).toHaveCount(0, { timeout: 35000 });
  await closeLevel(page);
  await page.getByRole("button", { name: "Water this building" }).click();
  await closeLevel(page);
  await expect(
    page.getByRole("button", { name: /Collect \d+ gold/ }),
  ).toBeEnabled({ timeout: 60000 });
  await page.getByRole("button", { name: /Collect \d+ gold/ }).click();
  await closeLevel(page);
  await expect(page.getByRole("status")).toContainText("harvest");
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("button", { name: "Save now", exact: true }).click();
  await expect(page.getByText("Saved on this device").first()).toBeVisible();
  await page.reload();
  await expect(page.locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: "More", exact: true }).click();
  await page.getByRole("button", { name: /followers.*curious souls/ }).click();
  await page.getByRole("button", { name: /Pip/ }).click();
  await expect(page.getByLabel("Assign follower to building")).toHaveValue(/b/);
  expect(errors).toEqual([]);
});
test("mobile keeps primary controls visible and supports touch rotation and pinch", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await start(page);
  await expect(
    page.getByRole("button", { name: "Build something" }),
  ).toBeInViewport();
  await expect(
    page.getByRole("button", { name: "Weather", exact: true }),
  ).toBeInViewport();
  await expect(page.getByTestId("gold")).toBeInViewport();
  await expect(
    page.getByRole("button", { name: "Settings", exact: true }),
  ).toBeInViewport();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByLabel("Show simulation details").check();
  await page.getByRole("button", { name: "Close panel" }).click();
  const debug = page.locator(".debug");
  const before = Number(
    (await debug.innerText()).match(/Rotation ([\d.-]+)/)?.[1],
  );
  const session = await page.context().newCDPSession(page);
  await session.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [{ x: 175, y: 440 }],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [{ x: 265, y: 440 }],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect
    .poll(async () =>
      Number((await debug.innerText()).match(/Rotation ([\d.-]+)/)?.[1]),
    )
    .not.toBe(before);
  const zoomBefore = Number(
    (await debug.innerText()).match(/Zoom ([\d.]+)/)?.[1],
  );
  await session.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [
      { x: 130, y: 440 },
      { x: 260, y: 440 },
    ],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [
      { x: 90, y: 440 },
      { x: 300, y: 440 },
    ],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect
    .poll(async () =>
      Number((await debug.innerText()).match(/Zoom ([\d.]+)/)?.[1]),
    )
    .toBeGreaterThan(zoomBefore);
  await page.waitForTimeout(700);
  await page.screenshot({ path: "test-results/mobile-world.png" });
  await page.getByRole("button", { name: "Build something" }).click();
  await expect(
    page.getByRole("heading", { name: "Make room for wonder." }),
  ).toBeVisible();
  await page.screenshot({ path: "test-results/mobile-store.png" });
  const dimensions = await page.evaluate(() => ({
    width: document.documentElement.scrollWidth,
    view: innerWidth,
  }));
  expect(dimensions.width).toBeLessThanOrEqual(dimensions.view);
});
