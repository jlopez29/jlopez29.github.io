# Tiny Deity progress — playable 0.1

## Implemented

- Main-page launcher and GitHub Pages static build, isolated from the existing applications.
- Original 2D circular cross-section, 512 seeded terrain samples, concentric soil layers, mineral details, 155 potential decoration placements, varied trees, sun/clouds, follower and 12 distinct building illustrations.
- Shared invertible camera transform, full-circle drag/inertia and button/key rotation, wheel/pinch zoom, overview, home, object focus, and PNG snapshot.
- Rain, sunshine, level-gated lightning, raise/lower/smooth (with undo), fire, resurrection, and enhanced terraforming from level 13. Powers validate unlocks, mana, and relevant targets before charging.
- Local moisture, temperature, fertility, vegetation growth, rock clearing, fire spread/extinguishing, shallow basin water and evaporation; lake-dependent fishing; rain/sun building charges.
- Named inhabitants, faith/conversion, needs, thought cues, job state machine, animated work/worship, picking up and safely dropping followers, inspector and drag assignments, construction, exhaustion, recovery, automatic rest and return.
- All 12 requested building types with level locks, placement validation, construction, worker capacities, production, collectable income, upgrades, condition/repair, moving, and reclaiming.
- Gold, mana, Awe boosts, XP, 10 rewarding goals, three discoverable wonders, meaningful unlocks through level 15, numeric progression to level 50, and four expansion milestones. Levels after 15 repeat mana/follower rewards rather than introducing unique content.
- Journal/log, optional warm/cool seasonal cycle, occasional treasure/drought/rain/hostile events, hostile banishment by lightning, modest follower traits.
- Responsive desktop/mobile controls, keyboard shortcuts, classic and modern weather gestures, pause, settings, sound chimes, reduced effects, debug view, rename, speed, and developed-world demo.
- Versioned IndexedDB autosave, explicit save, validated JSON export/import, conservative capped offline production.

## Deliberately unfinished / simplified

This release is a playable vertical slice, not the complete five-phase master specification.

- Neighboring/galaxy planets, multiplayer, multiple follower selection, themes/shrine customization, full encyclopedia/achievement catalogue, and before/after snapshot comparison are not implemented.
- Water uses local one-dimensional basin capacities; it does not conserve or redistribute water between connected basins, simulate overflow, or render physical reflections. Visible strips follow the sampled surface. Rain can fill local depressions; there is no fluid solver.
- Environmental values drive vegetation tint/growth and production; the full named biome taxonomy, species succession, snow, wildlife, meteor events, reputation system, hunger economy, and deep ecosystem feedback loops remain unfinished. Seasons currently influence temperature only.
- No advanced charged weather intensity, zoom-to-pointer camera anchoring, configurable key bindings, large terrain tool preview mesh, terrain-resolution migration, or touch long-press delay is implemented. Follower pickup starts on drag; classic weather requires a hold. Terrain preview marks the affected spot; building preview marks validity rather than rendering a ghost building.
- Most character animations use bobbing, tilting, and alternate arm poses, with rest represented by state/energy rather than a unique lying-down sprite. Flinging uses a safe immediate landing without ballistic physics. Audio is synthesized feedback chimes, without a music or ambient audio track.
- Construction always requires an assigned believer or an explicit Awe completion. Decorations are generated, not individually purchasable; cosmetic appearance choices and decorative placement are unfinished.
- The settings gear and journal are accessible HTML; canvas characters are also accessible via the directory. This is not a complete screen-reader rendition of the simulation. Modal focus trapping and an independent high-contrast mode are unfinished.
- Core testing uses Chromium with software WebGL in this environment. Firefox, Safari, Edge, physical mobile devices, and the 50-follower/100-structure performance target still need dedicated verification. Software renderers are capped at 20 FPS; hardware rendering targets 60 FPS.

## Verification

Verified on November 1, 2026: production build, strict TypeScript and Prettier checks, all 19 Vitest tests, and all 3 production Playwright scenarios pass. Desktop, overview, mobile world, and mobile store screenshots were inspected. The browser scenarios include a complete construction → rain → production → collection → save → reload loop and real touch rotation/pinch input. Unit tests cover geometry, inverse camera transforms, wrap-boundary terrain edits, deterministic generation, basin capacity, miracle validation, conversion, mana, worship, follower needs, placement, construction/production/collection, levels, goals, save validation, and offline rewards. Production Playwright checks cover the launcher, HUD, direct rain, camera controls, follower assignments, building purchase, harvest, reload persistence, and mobile controls. Browser screenshots are generated under the ignored `test-results/` directory.
