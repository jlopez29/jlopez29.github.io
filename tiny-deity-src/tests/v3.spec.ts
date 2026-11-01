import { test, expect, type Page } from "@playwright/test";
import { createWorld } from "../src/game/world";
import { ground, radial, toScreen } from "../src/game/geometry";
import { assign } from "../src/game/simulation";
const sizes = [
  [360, 740],
  [390, 844],
  [768, 1024],
  [1366, 768],
  [1440, 900],
  [1920, 1080],
];
async function start(page: Page) {
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  await expect(page.locator(".loading")).toHaveCount(0);
  await page.waitForTimeout(600);
}
async function fixture(page: Page, stored = 0) {
  const w = createWorld();
  w.buildings[0].stored = stored;
  w.settings.autonomy = false;
  w.settings.events = false;
  w.settings.reduced = true;
  w.followers.forEach((f) => (f.speed = 0));
  w.followers[0].faith = 80;
  w.followers[0].angle = 0.35;
  w.followers[1].angle = 2;
  assign(w, w.followers[0].id, w.buildings[0].id);
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.locator("input[type=file]").setInputFiles({
    name: "v2.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(w)),
  });
  await expect(page.getByRole("status")).toContainText("returned");
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.getByRole("button", { name: "Dismiss notification" }).click();
  const box = (await page.locator("canvas").boundingBox())!;
  const z =
    Math.min(box.width * (box.width < 600 ? 0.47 : 0.4), box.height * 0.34) /
    w.radius;
  const camera = {
    x: box.width / 2,
    y: box.height * 0.51,
    zoom: z,
    rotation: 0,
  };
  const p = radial(w.followers[0].angle, ground(w, w.followers[0].angle) + 17);
  const position = toScreen(p.x, p.y, camera);
  return { w, x: box.x + position.x, y: box.y + position.y, box, camera };
}
for (const [width, height] of sizes)
  test(`world-first layout ${width}x${height}`, async ({ page }) => {
    await page.setViewportSize({ width, height });
    const errors: string[] = [];
    page.on("pageerror", (e) => errors.push(e.message));
    await start(page);
    const dock = page.getByRole("navigation", { name: "Primary actions" });
    expect((await dock.boundingBox())!.width).toBeLessThanOrEqual(480);
    for (const name of [
      "Hand tool",
      "Terrain",
      "Weather",
      "Build something",
      "More",
    ]) {
      const control = page.getByRole("button", { name, exact: true });
      await expect(control).toBeInViewport();
      const b = (await control.boundingBox())!;
      expect(b.width).toBeGreaterThanOrEqual(44);
      expect(b.height).toBeGreaterThanOrEqual(44);
    }
    expect(
      await page.evaluate(
        () => document.documentElement.scrollWidth <= innerWidth,
      ),
    ).toBe(true);
    await page.screenshot({
      path: `docs/screenshots/v3-${width}x${height}.png`,
    });
    await page.getByRole("button", { name: "Build something" }).click();
    const sheet = page.locator(".side-panel");
    expect((await sheet.boundingBox())!.height).toBeLessThan(height * 0.34);
    await expect(
      page.getByRole("button", { name: "Close panel" }),
    ).toBeInViewport();
    await page.getByRole("button", { name: "Expand panel" }).click();
    await expect(sheet).toBeInViewport();
    expect((await sheet.boundingBox())!.y).toBeGreaterThanOrEqual(60);
    await page.getByRole("button", { name: "Close panel" }).click();
    await page.getByRole("button", { name: "Terrain", exact: true }).click();
    await expect(
      page.getByRole("group", { name: "Brush size" }),
    ).toBeInViewport();
    await expect(
      page.getByRole("button", { name: "Raise land", exact: true }),
    ).toBeInViewport();
    await page.screenshot({
      path: `docs/screenshots/v3-terrain-${width}x${height}.png`,
    });
    expect(errors).toEqual([]);
  });
test("intentional follower clicks open details; fast repeated drags never open an inspector", async ({
  page,
}) => {
  await start(page);
  const { x, y, box } = await fixture(page);
  await page.mouse.move(x, y);
  await page.mouse.down();
  await expect(
    page.getByRole("complementary", { name: "Follower details" }),
  ).toHaveCount(0);
  await page.mouse.up();
  await expect(
    page.getByRole("complementary", { name: "Follower details" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.evaluate(() => {
    (window as any).inspectorOpened = false;
    new MutationObserver(() => {
      if (document.querySelector('[aria-label="Follower details"]'))
        (window as any).inspectorOpened = true;
    }).observe(document.body, { childList: true, subtree: true });
  });
  // Invalid sky drops cancel pickup and leave its original location/reservation intact.
  for (let i = 0; i < 4; i++) {
    await page.mouse.move(x, y);
    await page.mouse.down();
    await page.mouse.move(box.x + 30, box.y + 30, { steps: 4 });
    await expect(
      page.getByRole("complementary", { name: "Follower details" }),
    ).toHaveCount(0);
    await page.mouse.up();
  }
  expect(await page.evaluate(() => (window as any).inspectorOpened)).toBe(
    false,
  );
  // A pointer cancellation after pickup also keeps the old assignment.
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(x + 40, y - 30);
  await page
    .locator("canvas")
    .dispatchEvent("pointercancel", { pointerId: 1, pointerType: "mouse" });
  await page.mouse.up();
  await page.mouse.click(x, y);
  await expect(page.getByLabel("Assign follower to building")).toHaveValue(/b/);
});
test("continuous level-one sculpting changes terrain before release and groups the stroke for undo", async ({
  page,
}) => {
  await start(page);
  const { box } = await fixture(page);
  await page.getByRole("button", { name: "Terrain", exact: true }).click();
  const x = box.x + box.width / 2,
    y = box.y + box.height * 0.17;
  const mana = Number(await page.getByTestId("mana").innerText());
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.waitForTimeout(500);
  await expect(
    page.getByRole("button", { name: "Undo terrain change" }),
  ).toBeVisible();
  await expect(page.getByTestId("mana")).toContainText(
    (mana - 1).toFixed(0) + ".",
  );
  await page.mouse.move(x + 70, y, { steps: 10 });
  await page.waitForTimeout(200);
  await page.mouse.up();
  await page.getByRole("button", { name: "Undo terrain change" }).click();
  await expect(
    page.getByRole("button", { name: "Undo terrain change" }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("button", { name: "Save now", exact: true }).click();
  await expect(page.getByText("Saved on this device").first()).toBeVisible();
  const saved = await page.evaluate(
    async () =>
      new Promise<any>((resolve) => {
        const r = indexedDB.open("tiny-deity");
        r.onsuccess = () => {
          const db = r.result,
            g = db.transaction("saves").objectStore("saves").get("current");
          g.onsuccess = () => {
            resolve(g.result.world);
            db.close();
          };
        };
      }),
  );
  expect(saved.stats.terraforms).toBe(1);
  expect(saved.terrain.map((t: any) => t.height)).toEqual(
    createWorld().terrain.map((t) => t.height),
  );
});

test("touch taps tolerate jitter, cancellation restores work, and pinch never sculpts", async ({
  page,
}) => {
  await page.setViewportSize({ width: 390, height: 844 });
  await start(page);
  const { x, y } = await fixture(page);
  const session = await page.context().newCDPSession(page);
  const tapAt = Date.now() / 1000;
  await session.send("Input.dispatchTouchEvent", {
    timestamp: tapAt,
    type: "touchStart",
    touchPoints: [{ x, y }],
  });
  await session.send("Input.dispatchTouchEvent", {
    timestamp: tapAt + 0.03,
    type: "touchMove",
    touchPoints: [{ x: x + 5, y: y + 2 }],
  });
  await session.send("Input.dispatchTouchEvent", {
    timestamp: tapAt + 0.07,
    type: "touchEnd",
    touchPoints: [],
  });
  await expect(
    page.getByRole("complementary", { name: "Follower details" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Close panel" }).click();
  await session.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [{ x, y }],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [{ x: x + 50, y: y - 40 }],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchCancel",
    touchPoints: [],
  });
  await expect(
    page.getByRole("complementary", { name: "Follower details" }),
  ).toHaveCount(0);
  await page.getByRole("button", { name: "Terrain", exact: true }).click();
  const mana = Number(await page.getByTestId("mana").innerText());
  await session.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [
      { x: 160, y: 245 },
      { x: 230, y: 245 },
    ],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchMove",
    touchPoints: [
      { x: 120, y: 245 },
      { x: 270, y: 245 },
    ],
  });
  await session.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect(
    page.getByRole("button", { name: "Undo terrain change" }),
  ).toHaveCount(0);
  expect(
    Number(await page.getByTestId("mana").innerText()),
  ).toBeGreaterThanOrEqual(mana);
});

test("building taps inspect, floating gold collects directly, and follower drops stay unobstructed", async ({
  page,
}) => {
  await start(page);
  const { w, x, y, box, camera } = await fixture(page, 24);
  const b = w.buildings[0];
  const screen = (offset: number) => {
    const p = radial(b.angle, ground(w, b.angle) + offset);
    const s = toScreen(p.x, p.y, camera);
    return { x: box.x + s.x, y: box.y + s.y };
  };
  const body = screen(37),
    coin = screen(95);
  await page.mouse.click(body.x, body.y);
  await expect(
    page.getByRole("complementary", { name: "Building details" }),
  ).toBeVisible();
  await expect(page.getByTestId("gold")).toContainText("255");
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.mouse.click(coin.x, coin.y);
  // The 24-gold collection also completes the original +35 gold goal.
  await expect(page.getByTestId("gold")).toContainText("314");
  await expect(page.getByRole("complementary")).toHaveCount(0);
  await page.getByRole("button", { name: "Dismiss notification" }).click();
  await page.mouse.move(x, y);
  await page.mouse.down();
  await page.mouse.move(body.x, body.y, { steps: 6 });
  await page.mouse.up();
  await expect(page.getByRole("complementary")).toHaveCount(0);
  await page.mouse.click(x, y);
  await expect(page.getByLabel("Assign follower to building")).toHaveValue(
    b.id,
  );
  await page.getByRole("button", { name: "Close panel" }).click();
  await page.mouse.move(x, y);
  await page.mouse.down();
  const land = radial(0.85, ground(w, 0.85));
  const drop = toScreen(land.x, land.y, camera);
  await page.mouse.move(box.x + drop.x, box.y + drop.y, { steps: 6 });
  await page.mouse.up();
  await expect(page.getByRole("complementary")).toHaveCount(0);
  const f = radial(0.85, ground(w, 0.85) + 17),
    landed = toScreen(f.x, f.y, camera);
  await page.mouse.click(box.x + landed.x, box.y + landed.y);
  await expect(page.getByLabel("Assign follower to building")).toHaveValue("");
});
