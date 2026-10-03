// Run against the DEBUG export. No test bridge exists in the release build.
import assert from 'node:assert/strict';
const { chromium } = await import(process.env.PLAYWRIGHT_MODULE || 'playwright');
const browser = await chromium.launch({
  headless: true,
  ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
  args: ['--no-sandbox', '--enable-webgl', '--use-gl=angle', '--use-angle=swiftshader'],
});
const context = await browser.newContext({ viewport: { width: 1440, height: 900 } });
const page = await context.newPage();
const errors = [];
page.on('pageerror', error => errors.push(error.message));
page.on('console', message => {
  if (message.type() === 'error' && !message.text().includes('404')) errors.push(message.text());
});
const state = () => page.evaluate(() => window.neonHouseSnapshot);
const click = async (x, y) => { await page.mouse.click(x, y); await page.waitForTimeout(250); };
const button = async prefix => {
  await page.waitForTimeout(300);
  const target = await page.evaluate(prefix => window.neonHouseUI.find(b => b.text.startsWith(prefix) && !b.disabled), prefix);
  assert.ok(target, `Enabled button exists: ${prefix}`);
  await click(target.x + target.w / 2, target.y + target.h / 2);
};
try {
  await page.goto(process.env.CASINO_TEST_URL || 'http://127.0.0.1:8090/game.html');
  await page.waitForFunction(() => window.neonHouseSnapshot && window.neonHouseUI, null, { timeout: 60000 });
  await page.waitForTimeout(1000);
  assert.equal((await state()).cash, 24000);
  await button("Let's open the house"); // dismiss onboarding
  await button('Hire dealer'); // hire two dealers
  await button('Hire dealer');
  assert.equal((await state()).staff.length, 2);
  await button('Open casino'); // open
  await button('4×'); // 4x
  await page.waitForFunction(() => window.neonHouseSnapshot.tables[0].rolls > 0, null, { timeout: 60000 });
  assert.ok((await state()).guests.length > 0);
  await button('Walk the floor'); // visitor mode
  await page.keyboard.down('w');
  await page.waitForFunction(() => window.neonHouseSnapshot.player[1] < 440, null, { timeout: 15000 });
  await page.keyboard.up('w');
  await page.keyboard.press('e');
  await page.waitForFunction(() => window.neonHouseSnapshot.joined === 1);
  // Manual table may have a point already. Field is always valid and clears after one roll.
  await button('Field'); // field
  const betState = await state();
  assert.ok(betState.tables[0].owner.field > 0);
  assert.equal(betState.wallet, 1000 - betState.tables[0].minimum);
  const previousRolls = betState.tables[0].rolls;
  await button('SHOOT THE DICE'); // shoot
  await page.waitForFunction(count => window.neonHouseSnapshot.tables[0].rolls > count, previousRolls);
  assert.equal((await state()).tables[0].owner.field, 0);
  // Build an unsettled Place contract, pause, and persist it across browser reload.
  await button('Place 6');
  assert.equal((await state()).tables[0].owner.six, 30);
  await button('Pause'); // pause
  await button('Save'); // save
  const saved = await state();
  await page.waitForTimeout(2500); // allow IndexedDB sync
  await page.reload();
  await page.waitForFunction(() => window.neonHouseSnapshot && window.neonHouseUI, null, { timeout: 60000 });
  await page.waitForTimeout(1000);
  await button("Let's open the house");
  await button('Pause'); // pause fresh session before restore
  await button('Load'); // load
  const loaded = await state();
  assert.equal(loaded.joined, 1);
  assert.equal(loaded.staff.length, 2);
  assert.equal(loaded.tables[0].owner.six, 30);
  assert.equal(loaded.wallet, saved.wallet);
  assert.equal(loaded.cash, saved.cash);
  assert.equal(loaded.rng_state, saved.rng_state);
  // Leaving the table resumes management; build another empty table.
  await page.keyboard.press('Escape');
  await button('+ Build craps'); // build; automatically returns to management
  await click(350, 250); // floor (70,110), clear of starter table
  assert.equal((await state()).tables.length, 2);
  assert.ok((await state()).tables[1].x >= 65, 'New table is within buildable bounds');
  // Save a populated simulation with route waypoints and verify it, too.
  await button('Save');
  const expanded = await state();
  await button('Load');
  assert.equal((await state()).tables.length, 2);
  assert.equal((await state()).guests.length, expanded.guests.length);
  await page.screenshot({ path: '/tmp/neon-house-browser.png' });
  assert.deepEqual(errors, [], 'No Godot/browser runtime errors');
  console.log('Browser smoke passed: staffing, guest rounds, walk/join, betting, dice, IndexedDB reload, expansion, populated restore.');
} catch (error) {
  console.error(JSON.stringify(await state()));
  await page.screenshot({ path: "/tmp/neon-house-failure.png" });
  throw error;
} finally {
  await browser.close();
}
