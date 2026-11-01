import { test, expect } from "@playwright/test";
import { createWorld, addFollower } from "../src/game/world";
import { assign } from "../src/game/simulation";
test("three shrine inhabitants travel, worship separately, and retain reservations on reload", async ({
  page,
}) => {
  const w = createWorld();
  w.settings.events = false;
  w.settings.speed = 4;
  while (w.followers.length < 3)
    addFollower(w, -0.05 + w.followers.length * 0.04, 80);
  w.followers.forEach((f) => {
    f.faith = 80;
    assign(w, f.id, w.buildings[0].id);
  });
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.locator("input[type=file]").setInputFiles({
    name: "shrine-world.json",
    mimeType: "application/json",
    buffer: Buffer.from(JSON.stringify(w)),
  });
  await expect(page.getByRole("status")).toContainText("returned");
  await page.getByRole("button", { name: "Close panel" }).click();
  await expect
    .poll(
      async () =>
        page.evaluate(
          async () =>
            new Promise<number>((resolve) => {
              const r = indexedDB.open("tiny-deity");
              r.onsuccess = () => {
                const db = r.result;
                const g = db
                  .transaction("saves")
                  .objectStore("saves")
                  .get("current");
                g.onsuccess = () => {
                  resolve(
                    g.result.world.followers.filter(
                      (f: any) => f.task === "worshipping",
                    ).length,
                  );
                  db.close();
                };
              };
            }),
        ),
      { timeout: 90000 },
    )
    .toBe(3);

  await page.screenshot({ path: "test-results/shrine-slots.png" });
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("button", { name: "Save now", exact: true }).click();
  await expect(page.getByText("Saved on this device").first()).toBeVisible();
  const followers = await page.evaluate(
    async () =>
      new Promise<any[]>((resolve) => {
        const r = indexedDB.open("tiny-deity");
        r.onsuccess = () => {
          const db = r.result;
          const get = db
            .transaction("saves")
            .objectStore("saves")
            .get("current");
          get.onsuccess = () => {
            resolve(get.result.world.followers);
            db.close();
          };
        };
      }),
  );
  expect(new Set(followers.map((f) => f.slot)).size).toBe(3);
  expect(followers.every((f) => f.task === "worshipping")).toBe(true);
  await page.reload();
  await expect(page.locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: /followers.*curious souls/ }).click();
  await expect(
    page.getByRole("button", { name: "Pip worshipping" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Clover worshipping" }),
  ).toBeVisible();
  await expect(
    page.getByRole("button", { name: "Bramble worshipping" }),
  ).toBeVisible();
  expect(new Set(followers.map((f) => Math.round(f.angle * 10000))).size).toBe(
    3,
  );
});

test("resources gather from the landscape and persist across reload", async ({
  page,
}) => {
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: "Open resources" }).click();
  await expect(page.getByTestId("resource-wood")).toContainText("8.0");
  await page.getByRole("button", { name: "Gather wood", exact: true }).click();
  await expect(page.getByTestId("resource-wood")).toContainText("9.0");
  await page.screenshot({ path: "test-results/resources-desktop.png" });
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await page.getByRole("button", { name: "Save now", exact: true }).click();
  await expect(page.getByText("Saved on this device").first()).toBeVisible();
  await page.reload();
  await expect(page.locator("canvas")).toBeVisible();
  await page.getByRole("button", { name: "Open resources" }).click();
  await expect(page.getByTestId("resource-wood")).toContainText("9.0");
});

test("an invalid stored world is preserved instead of being overwritten by autosave", async ({
  page,
}) => {
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  // Leave the running application before changing storage so its final save can settle.
  await page.goto("/tiny-deity/fonts/DM-Sans-LICENSE.txt");
  await page.waitForTimeout(1000);
  await page.evaluate(
    async () =>
      new Promise<void>((resolve, reject) => {
        const r = indexedDB.open("tiny-deity");
        r.onsuccess = () => {
          const db = r.result;
          const t = db.transaction("saves", "readwrite");
          t.objectStore("saves").put({
            id: "current",
            world: { version: 99, original: "preserve-me" },
          });
          t.oncomplete = () => {
            db.close();
            resolve();
          };
          t.onerror = () => reject(t.error);
        };
      }),
  );
  await page.goto("/tiny-deity/");
  await expect(page.locator("canvas")).toBeVisible();
  await expect(page.getByText("Your little world is resting.")).toBeVisible();
  await page.getByRole("button", { name: "Settings", exact: true }).click();
  await expect(
    page
      .getByText(
        "Existing save could not be loaded. Autosave stopped to preserve it.",
      )
      .first(),
  ).toBeVisible();
  await page.getByRole("button", { name: "Save now", exact: true }).click();
  await page.waitForTimeout(11000);
  const value = await page.evaluate(
    async () =>
      new Promise<string>((resolve) => {
        const r = indexedDB.open("tiny-deity");
        r.onsuccess = () => {
          const db = r.result;
          const get = db
            .transaction("saves")
            .objectStore("saves")
            .get("current");
          get.onsuccess = () => {
            resolve(get.result.world.original);
            db.close();
          };
        };
      }),
  );
  expect(value).toBe("preserve-me");
});
