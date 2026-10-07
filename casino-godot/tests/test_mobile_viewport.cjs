// Run against exports served from the repository root. PLAYWRIGHT_MODULE may
// point to an existing Playwright install; no physical-device claims implied.
const { chromium } = require(process.env.PLAYWRIGHT_MODULE || 'playwright');
const assert = require('node:assert/strict');
const base = process.env.PIT_BOSS_TEST_URL || 'http://127.0.0.1:8765';
let checks = 0;
function check(value, message) { assert.ok(value, message); checks++; }

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  try {
    for (const portrait of [true, false]) {
      const size = portrait ? { width: 390, height: 844 } : { width: 844, height: 390 };
      const visible = { width: size.width, height: size.height - 90 };
      const context = await browser.newContext({ viewport: size, isMobile: true, hasTouch: true, deviceScaleFactor: 3 });
      await context.addInitScript(({ visible }) => {
        if (window !== window.top) return;
        const viewport = new EventTarget();
        Object.assign(viewport, visible, { offsetLeft: 0, offsetTop: 0, scale: 1 });
        Object.defineProperty(window, 'visualViewport', { value: viewport });
        window.setVisibleViewport = (width, height, event = 'resize') => {
          Object.assign(viewport, { width, height });
          viewport.dispatchEvent(new Event(event));
        };
      }, { visible });
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      // Exercise the actual production wrapper with the debug game for geometry.
      await page.route('**/casino/index.html', async route => {
        const response = await route.fetch();
        await route.fulfill({ response, body: (await response.text()).replace('src="game.html"', 'src="/casino-debug/game.html"') });
      });
      async function load() {
        await page.goto(`${base}/casino/index.html`);
        const frame = await page.locator('iframe').contentFrame();
        await frame.locator('canvas').waitFor();
        const game = page.frames().find(frame => frame.url().includes('casino-debug/game.html'));
        await game.waitForFunction(() => window.pitBossLayout && window.pitBossUI, { timeout: 60000 });
        const start = await game.evaluate(() => pitBossUI.find(button => button.text === 'Start casino'));
        if (start) await game.locator('canvas').click({ position: { x: start.x + start.w / 2, y: start.y + start.h / 2 } });
        return game;
      }
      let game = await load();
      async function verify(label) {
        console.log(portrait ? "portrait" : "landscape", label);
        await game.waitForFunction(() => {
          const value = JSON.parse(PitBossViewport.getSnapshot());
          return pitBossLayout.viewport[0] === value.width && pitBossLayout.viewport[1] === value.height;
        });
        // Diagnostics are deliberately slower than rendering/layout.
        await page.waitForTimeout(1200);
        const layout = await game.evaluate(() => pitBossLayout);
        const viewport = await page.evaluate(() => JSON.parse(PitBossViewport.getSnapshot()));
        const canvas = await game.locator('canvas').boundingBox();
        check(canvas.y + canvas.height <= viewport.y + viewport.height - (game.parentFrame() ? viewport.bottom : 0) + 1, `${label}: canvas fits browser-visible viewport ${JSON.stringify({canvas, viewport})}`);
        const [width, height] = layout.viewport;
        const [left, top, right, bottom] = layout.safe_area;
        for (const [name, element] of Object.entries(layout.mobile_rects)) {
          if (!element.visible) continue;
          const [x, y, w, h] = element.rect;
          check(y >= top - 1 && y + h <= height - bottom + 1, `${label}: ${name} fits usable height`);
          check(x >= left - 1 && x + w <= width - right + 1, `${label}: ${name} fits usable width`);
        }
        const nav = layout.mobile_rects.bottom_nav.rect;
        check(nav[3] === 52 && nav[1] + nav[3] <= height - bottom, `${label}: full 52px navigation invariant`);
        const floor = layout.mobile_floor;
        check(floor[2] > 0 && floor[3] > 0 && floor[1] + floor[3] <= nav[1], `${label}: usable floor remains above navigation`);
        check(errors.length === 0, `${label}: no browser script errors`);
        return layout;
      }
      const initial = await verify('fresh load / browser chrome visible');
      await page.evaluate(size => setVisibleViewport(size.width, size.height), size);
      await verify('browser chrome collapsed');
      await page.evaluate(visible => setVisibleViewport(visible.width, visible.height), visible);
      await page.locator('#fullscreen').click();
      await page.waitForFunction(() => document.fullscreenElement);
      await verify('fullscreen');
      await page.evaluate(() => document.exitFullscreen());
      await page.waitForFunction(() => !document.fullscreenElement);
      const afterFullscreen = await verify('exit fullscreen');
      check(JSON.stringify(initial.mobile_rects) === JSON.stringify(afterFullscreen.mobile_rects), 'Fresh layout equals fullscreen/exit layout');
      const rotated = { width: size.height, height: size.width };
      await page.setViewportSize(rotated);
      await page.evaluate(size => { setVisibleViewport(size.width, size.height - 60); dispatchEvent(new Event('orientationchange')); }, rotated);
      await verify('orientation change');
      await page.setViewportSize(size);
      game = await load();
      await verify('page reload');
      async function tap(text) {
        const button = await game.evaluate(text => pitBossUI.find(button => button.text === text), text);
        check(Boolean(button), `Button ${text} is available`);
        await game.locator('canvas').click({ position: { x: button.x + button.w / 2, y: button.y + button.h / 2 } });
        await page.waitForTimeout(1200);
      }
      await tap('Build');
      const build = await verify('build palette');
      check(build.mobile_rects.palette.visible, 'Build palette is visible');
      await tap('Staff');
      const staff = await verify('management inspector');
      check(staff.mobile_rects.inspector.visible, 'Management inspector is visible');
      await tap('Floor');
      const count = await game.evaluate(() => pitBossLayout.layout_count);
      await page.evaluate(() => {
        for (let i = 0; i < 20; i++) visualViewport.dispatchEvent(new Event('resize'));
      });
      await page.waitForTimeout(1400);
      check((await game.evaluate(() => pitBossLayout.layout_count)) === count, 'Unchanged viewport events do not relayout');
      // Safe-area CSS emulation: this Chromium build cannot override env()
      // through CDP. Supply equivalent computed padding to the measurement probe
      // and wrapper, retaining the actual browser/Godot synchronization path.
      const padding = portrait ? '44px 0px 34px 0px' : '0px 44px 21px 44px';
      const safeCSS = `[data-pit-boss-safe-area] { padding: ${padding} !important; } body:has(#game-container) { padding: ${padding}; }`;
      await page.addInitScript(css => {
        document.addEventListener('DOMContentLoaded', () => {
          const style = document.createElement('style'); style.textContent = css;
          document.head.appendChild(style);
        }, { once: true });
      }, safeCSS);
      await page.addStyleTag({ content: safeCSS });
      await page.evaluate(() => PitBossViewport.schedule());
      await verify('iOS-style safe areas in wrapper');
      const padded = await page.evaluate(() => JSON.parse(PitBossViewport.getSnapshot()));
      check(padded.bottom > 0, 'Safe-area computed CSS padding is measured');
      await page.goto(`${base}/casino-debug/game.html`);
      game = page.mainFrame();
      await game.waitForFunction(() => window.pitBossLayout, { timeout: 60000 });
      const standalone = await verify('standalone game safe areas');
      check(standalone.safe_area[3] > 0, 'Standalone game receives bottom safe area');
      await context.close();
    }
    // VisualViewport API unavailable: use inner dimensions and normal resize.
    const context = await browser.newContext({ viewport: { width: 390, height: 700 }, isMobile: true });
    await context.addInitScript(() => Object.defineProperty(window, 'visualViewport', { value: null }));
    const page = await context.newPage();
    await page.goto(`${base}/casino-debug/game.html`);
    await page.waitForFunction(() => window.pitBossLayout, { timeout: 60000 });
    check((await page.evaluate(() => pitBossLayout.viewport.join(','))) === '390,700', 'innerWidth/innerHeight fallback');
    await context.close();
    console.log(`Mobile viewport: ${checks} checks passed (Chromium mobile emulation).`);
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
