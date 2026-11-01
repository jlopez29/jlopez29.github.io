# Tiny Deity

A playable, original browser god simulation inspired by the circular-world presentation and gentle economic loop of GodFinger. Built with React, strict TypeScript, PixiJS 8, Zustand, and Dexie. No account, API key, purchases, or backend is needed.

## Run and build

From the repository root, using Node 22.12+ (Node 24 recommended):

```sh
npm install
npm run dev
npm test
npm run lint
npm run build
npx --prefix tiny-deity-src playwright install chromium
npm run test:e2e
```

The dev server listens on `0.0.0.0:5173`. `npm run build` emits the static application into `../tiny-deity/`, with relative asset URLs. The portfolio card opens `/tiny-deity/`. Commit the generated directory along with source changes so the repository's existing GitHub Pages deployment serves the game without a Node server. To inspect the complete production site locally: `python3 -m http.server 4173` from the repository root, then open `http://localhost:4173/tiny-deity/`.

## Play

Start with a compact planet, two inhabitants, 255 gold, and a small material inventory. Rain near Pip to earn their faith, then assign a follower to the shrine: they walk to a reserved position and worship. Rain on the nearby forest, gather wood in Resources, build a logging camp, and assign a worker. Use logs for a farm and tent. Farms turn water into food and collectible gold; collectors catch local rain or draw from ponds. Hungry followers eat, tired workers rest, and productive work supports new arrivals. Real activity completes goals; sacred runes expand the planet at levels 3, 6, 10, and 15.

- Drag empty space, use arrow keys, or use the rotation buttons to explore all 360 degrees.
- Wheel, pinch, or use +/− to zoom. The globe button frames the whole planet; H restores home view.
- Select inhabitants and structures on the canvas, or use the followers directory. Dragging a follower onto a structure reserves an individual slot and starts their walk to work. Inspectors also provide accessible assignment selects.
- R: rain. S: sunshine. T: raise terrain. F: fire. 1–8: powers. Space: pause. Escape: cancel.
- At level 2, choose raise/lower/smooth and click or drag on the surface. Undo restores the last terrain operation. Lower a basin, then apply rain to create lake water.
- Open Resources for saved inventories, storage capacity, recent rates, gathering, and free replanting. Tap trees or rocks to gather at that location. Recipes require materials alongside gold; reclaiming returns part of both.
- Settings includes classic hold-and-swipe weather, optional seasons/events, autonomy, reduced effects, speed, sound, and diagnostics.
- New world / developed demo replaces the active save after an explicit in-game confirmation. Export first to retain your old world.

## Saves

One active world lives in IndexedDB on this browser origin. Autosave runs every 10 seconds and on visibility changes. Save now and JSON export/import are in Settings. Version-one saves migrate to version two and retain their original planet size as legacy worlds. Invalid or unsupported saves are rejected; a failed load pauses the game and blocks automatic writes, preserving the original record for export. Effects and terrain undo history are transient. Closing immediately after an action may lose up to 10 seconds; the browser does not guarantee asynchronous writes during final page teardown. Storage failure is shown in the HUD; JSON export remains usable.

Offline income is capped at four hours and further limited by worker energy and remaining miracle charge, terrain stocks, water, and storage. Only arrived workers generate offline production. It goes into a building's collectible store. No offline disasters or deaths occur. Offline calculation is intentionally conservative and does not run the full simulation.

## Architecture

- `src/game`: seeded world generation, data-driven building/power/quest balance, shared transforms, and independent mutable simulation.
- `src/render`: PixiJS scene, original Canvas-generated sprite textures, dirty terrain geometry, pooled labels, pointer input, and camera.
- `src/App.tsx`: React HUD, store, inspectors, journal, settings, and 20 Hz fixed-step driver. UI snapshots refresh at 5 Hz, separately from rendering.
- `src/persistence`: versioned JSON validation and Dexie database.
- `tests`: deterministic Vitest unit/integration checks and Playwright tests against the production output.

Art is procedural and original. DM Sans and Fraunces are locally hosted under the included SIL Open Font Licenses. The game has no external runtime requests. Soft synthesized chimes use Web Audio after enabling sound.

See [OVERHAUL-V2.md](OVERHAUL-V2.md) for milestone behavior, save migration, balancing, validation, and remaining limitations; [PROGRESS.md](PROGRESS.md) records the earlier release history.
