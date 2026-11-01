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

Choose Rain and click the grass near Pip, or drag a cloud down toward the surface. Once Pip believes, select them and assign them to the shrine for faster mana, or buy a Sunpatch farm and assign them to its construction. Water the finished farm, let Pip work, and click the gold above it to harvest. Build a tent so tired workers can rest. Goals give extra gold and XP; levels bring new inhabitants, buildings, powers, mana capacity, and expansion runes.

- Drag empty space, use arrow keys, or use the rotation buttons to explore all 360 degrees.
- Wheel, pinch, or use +/− to zoom. The globe button frames the whole planet; H restores home view.
- Select inhabitants and structures on the canvas, or use the followers directory. Dragging a follower onto a structure assigns them immediately. Inspectors also provide accessible assignment selects.
- R: rain. S: sunshine. T: raise terrain. F: fire. 1–8: powers. Space: pause. Escape: cancel.
- At level 2, choose raise/lower/smooth and click or drag on the surface. Undo restores the last terrain operation. Lower a basin, then apply rain to create lake water.
- Settings includes classic hold-and-swipe weather, optional seasons/events, autonomy, reduced effects, speed, sound, and diagnostics.
- New world / developed demo replaces the active save after an explicit in-game confirmation. Export first to retain your old world.

## Saves

One active world lives in IndexedDB on this browser origin. Autosave runs every 10 seconds and on visibility changes. Save now and JSON export/import are in Settings. Invalid or unsupported saves are rejected. Effects and terrain undo history are transient. Closing immediately after an action may lose up to 10 seconds; the browser does not guarantee asynchronous writes during final page teardown. Storage failure is shown in the HUD; JSON export remains usable.

Offline income is capped at four hours and further limited by worker energy and remaining miracle charge. It goes into a building's collectible store. No offline disasters or deaths occur. Offline calculation is intentionally conservative and does not run the full simulation.

## Architecture

- `src/game`: seeded world generation, data-driven building/power/quest balance, shared transforms, and independent mutable simulation.
- `src/render`: PixiJS scene, original Canvas-generated sprite textures, dirty terrain geometry, pooled labels, pointer input, and camera.
- `src/App.tsx`: React HUD, store, inspectors, journal, settings, and 20 Hz fixed-step driver. UI snapshots refresh at 5 Hz, separately from rendering.
- `src/persistence`: versioned JSON validation and Dexie database.
- `tests`: deterministic Vitest unit/integration checks and Playwright tests against the production output.

Art is procedural and original. DM Sans and Fraunces are locally hosted under the included SIL Open Font Licenses. The game has no external runtime requests. Soft synthesized chimes use Web Audio after enabling sound.

See [PROGRESS.md](PROGRESS.md) for the exact release scope and unfinished parts of the larger brief.
