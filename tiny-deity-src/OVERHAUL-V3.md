# Tiny Deity V3 — World first

V3 keeps the original React, TypeScript, PixiJS, Zustand, Dexie, circular 512-sample terrain, procedural sprite art, economy, buildings, and saves. Source lives in `tiny-deity-src/`; the checked-in `tiny-deity/` build is the GitHub Pages release.

## Interaction and HUD

Pointer-down records intent and dismisses existing panels. Hidden locked sky objects are excluded from hit testing, and Explore prioritizes follower/building hits over passing clouds. Pointer-event timestamps distinguish short taps from holds despite delayed rendering. A stationary release within 500 ms opens follower details; movement past 8 CSS pixels for mouse/pen or 14 for touch picks up the follower. Crossing the threshold remains a drag even after returning to its starting position. Pickup keeps the previous work reservation. Invalid drops, cancellation, capture loss, blur, and a second touch release carried state without discarding the old assignment. Land drops release the job and briefly delay autonomous reassignment. Building drops validate faith, capacity, and physical work slots, then show an in-world confirmation. Collection indicators and buildings have separate hit targets. Empty-world clicks never gather automatically; explicit resource actions remain available.

A compact gold/mana/XP HUD replaces the header and resource dashboard. Explore, Terrain, Weather, Build, and More form a 460px maximum floating dock at every viewport size. Contextual trays expose brush modes, sizes, weather, directories, journal, objectives, and advanced powers. Existing buildings and systems remain available; the store previews only unlocked buildings and the next level. Sheets occupy at most 32% of viewport height initially and deliberately expand on request. Controls use safe-area offsets, `100dvh`, pointer capture, and 44px targets. Keyboard controls, assignment selects, sound settings, save import/export, and original directories remain available.

## Terrain and ecology

Raise/Lower unlock at level 1 and Smooth at level 2. A held brush edits at up to 20 Hz, interpolates between samples along the circular seam, and uses cosine falloff. Terrain graphics rebuild at most once per rendered frame. Small/Medium/Large brush widths are 0.09/0.14/0.22 radians. The stroke captures one height snapshot; Undo restores all of it. One mana buys 40 editing updates (two seconds), and XP is awarded once per stroke rather than per pointer event. Touch waits 120 ms before editing to allow a second finger to initiate pinch. Explore rotates empty space, including during building placement. Clouds/sun remain directly draggable; wheel and pinch retain zoom.

A vivid blue-to-cyan sky, saturated foliage, warm sun rays, colorful followers, brighter clouds, blue water with moving highlights, meadow flowers, and blended biome outlines use original procedural art. Trees respond to moisture, vegetation, wood stocks, fire, and buildings. Deposits thin with extraction. Rain supports regrowth; replanting remains free through Resources. New worlds start with a small pond; existing terrain is never regenerated. Seeded generation and decoration remain deterministic. Reduced effects follows the system preference for new worlds and freezes decorative motion when enabled.

## Autonomy and save safety

Idle believers choose useful available work with construction priority, then production and worship. Assignments reserve unique positions and use the existing walking/traffic paths. Automatic workers can leave worship for useful construction after an 18-second cooldown. Manual jobs remain preferred through food and rest trips. A land drop gives an 8-second pause before walking, followed by job seeking. Existing hunger, production, terrain extraction, food consumption, regrowth, storage, offline rewards, and expansion rules remain intact.

Version stays **2**, with optional `manual`, `jobCooldown`, and `returnManual` follower fields. Imports default old assigned jobs to manual and normalize cooldowns; no IndexedDB schema change is required. Existing radii, terrain, buildings, inventory, and progress are preserved. Carried saves restore the reserved job. Invalid-save protection, ordered autosaves, export/import, and legacy world migration remain in place.

## Validation

Validation completed: `npm test` passed 46 tests; `npm run lint` and `npm run build` passed; the full `npm run test:e2e` production suite passed all 16 cases. Final small UI follow-ups (Awe visibility, the Settings return link, advanced-power cost labels, and dismissing More from the world) were formatted, linted, and rebuilt after that browser run; their additional browser testing is left to the user at handoff. Automated checks run against generated production assets served by the Playwright static server. Vitest covers terrain/undo, capacity, reservations, physical travel, autonomous construction, assignment stability, food, rest/return, cancellation, ecology, and saves. Playwright covers repeated click-versus-drag, touch jitter/cancel/pinch, live terrain before release, stroke undo, production, import/reload, and all requested viewport sizes.

Screenshots are stored in [docs/screenshots/](docs/screenshots/), including world and terrain-tray views for 360×740, 390×844, 768×1024, 1366×768, 1440×900, and 1920×1080.

## Scope and remaining limits

The planet remains a stylized circular cross section with one-dimensional basin water. Automatic work selection is a deterministic priority heuristic, not a settlement planner; players still place suitable buildings and provide weather/materials. Only the latest terrain stroke can be undone, and undo history remains transient. Zoom is useful for precise follower handling on the full-globe view. Long presses on followers intentionally do not open details; classic weather retains its hold-and-swipe behavior. Automated touch runs in Chromium; physical iOS Safari and pen hardware require device testing. Offline simulation remains conservative and does not choose new jobs. The short level-up celebration still requires dismissal.
