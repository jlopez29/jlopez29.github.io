# Tiny Deity

A playable, original browser god simulation inspired by the circular-world presentation and gentle economic loop of GodFinger. Built with React, strict TypeScript, PixiJS 8, Zustand, and Dexie. No account, API key, purchases, or backend is needed.

## Run and build

From `tiny-deity-src/`, using Node 22.12+ (Node 24 recommended):

```sh
npm install
npm run dev
npm test
npm run lint
npm run build
npx playwright install chromium
npm run test:e2e
```

The dev server listens on `0.0.0.0:5173`. `npm run build` emits the static application into `../tiny-deity/`, with relative asset URLs. The portfolio card opens `/tiny-deity/`. Commit the generated directory along with source changes so the repository's existing GitHub Pages deployment serves the game without a Node server. To inspect the complete production site locally: `python3 -m http.server 4173` from the repository root, then open `http://localhost:4173/tiny-deity/`.

Build and deploy the entire generated directory together. Keep Vite's hashed entry and chunk filenames: renderer chunks import the entry, so renaming or replacing only the entry can load two copies of Pixi and break pointer events and text rendering. The production browser tests check this module graph.

Version 0.4.4 (`surface-crossing` in Settings) lets followers pass through one another on the same surface path without collision delays, lane offsets, or depth scaling. Existing save files remain compatible.

## Play

Start with a compact planet, two inhabitants, 255 gold, and a small material inventory. Rain near Pip to earn their faith, watch believers find the shrine: they walk to reserved positions and worship. Rain on the nearby forest, gather wood in Resources, build a logging camp, and let autonomous followers construct and operate it. Use logs for a farm and tent. Farms turn water into food and collectible gold; collectors catch local rain or draw from ponds. Hungry followers eat, tired workers rest, and productive work supports new arrivals. Real activity completes goals; sacred runes expand the planet at levels 3, 6, 10, and 15.

- Drag empty space, use arrow keys, or use the rotation buttons to explore all 360 degrees.
- Wheel, pinch, or use +/− to zoom. The globe button frames the whole planet; H restores home view.
- Select inhabitants and structures on the canvas, or use the followers directory. Dragging a follower onto a structure reserves an individual slot and starts their walk to work. Inspectors also provide accessible assignment selects.
- R: rain. S: sunshine. T: raise terrain. F: fire. 1–8: powers. Space: pause. Escape: cancel.
- Open Terrain to raise or lower land from level 1; Smooth unlocks at level 2. Choose Small, Medium, or Large and drag across the surface. A live brush follows the stroke; Undo restores the whole stroke. Sculpting costs one mana per two seconds of active editing, with one XP per stroke. Lower a basin, then apply rain to create lake water.
- Open Resources for saved inventories, storage capacity, recent rates, gathering, and free replanting. Use explicit Gather actions; tapping empty terrain dismisses selection. Recipes require materials alongside gold; reclaiming returns part of both.
- Settings includes classic hold-and-swipe weather, optional seasons/events, autonomy, reduced effects, speed, sound, and diagnostics.
- New world / developed demo replaces the active save after an explicit in-game confirmation. Export first to retain your old world.

## V3 world-first controls

The same five-action dock stays below 460 CSS pixels on phones, tablets, and desktops: Explore, Terrain, Weather, Build, More. More opens followers, resources, objectives, the journal, help, and advanced miracles. Gold, mana, and level/XP stay in the compact top HUD. Panels start as short scrollable bottom sheets; use the expand/collapse arrow to read more. Tap the world or press Escape to dismiss. Dragging followers closes panels and preserves their old work reservation until a valid drop succeeds; cancellation returns them to that job. Only short stationary taps open details. Tap floating gold indicators to collect without opening an inspector.

Autonomy is enabled by default. Believers reserve jobs, walk to work, prioritize unfinished construction, seek food, and rest before returning to work. Manual assignments retain priority, including after food/rest detours. Automatic job changes have an 18-second cooldown; repositioning a follower gives them a quiet period before seeking work again. Disable autonomy in Settings for manual play.

See [OVERHAUL-V3.md](OVERHAUL-V3.md) for implementation, validation, screenshots, and limits.

## Saves

One active world lives in IndexedDB on this browser origin. Autosave runs every 10 seconds and on visibility changes. Save now and JSON export/import are in Settings. Version-one saves migrate to version two and retain their original planet size as legacy worlds. Invalid or unsupported saves are rejected; a failed load pauses the game and blocks automatic writes, preserving the original record for export. Effects and terrain undo history are transient. Closing immediately after an action may lose up to 10 seconds; the browser does not guarantee asynchronous writes during final page teardown. Storage status and failures are shown in Settings; JSON export remains usable.

Offline income is capped at four hours and further limited by worker energy and remaining miracle charge, terrain stocks, water, and storage. Only arrived workers generate offline production. It goes into a building's collectible store. No offline disasters or deaths occur. Offline calculation is intentionally conservative and does not run the full simulation.

## Architecture

- `src/game`: seeded world generation, data-driven building/power/quest balance, shared transforms, and independent mutable simulation.
- `src/render`: PixiJS scene, original Canvas-generated sprite textures, dirty terrain geometry, pooled labels, pointer input, and camera.
- `src/App.tsx`: React HUD, store, inspectors, journal, settings, and 20 Hz fixed-step driver. UI snapshots refresh at 5 Hz, separately from rendering.
- `src/persistence`: versioned JSON validation and Dexie database.
- `tests`: deterministic Vitest unit/integration checks and Playwright tests against the production output.

Art is procedural and original. DM Sans and Fraunces are locally hosted under the included SIL Open Font Licenses. The game has no external runtime requests. Soft synthesized chimes use Web Audio after enabling sound.

See [OVERHAUL-V2.md](OVERHAUL-V2.md) for milestone behavior, save migration, balancing, validation, and remaining limitations; [PROGRESS.md](PROGRESS.md) records the earlier release history.
