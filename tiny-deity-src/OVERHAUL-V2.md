# Tiny Deity gameplay overhaul v2

The React, PixiJS, Zustand, Dexie, procedural artwork, circular geometry, and existing manual controls are retained. The production build remains `../tiny-deity/` for this repository's GitHub Pages deployment.

## Milestone A — inhabitants

Buildings reserve unique indexed work slots, with capacities in `game/data.ts`. Standing angles use arc-length offsets divided by local surface radius. Assignment initiates travel; only arrived workers contribute to construction, production, or worship. Walking uses signed shortest angular differences, world-space speed, same-direction spacing, and passing offsets for opposing traffic. Worship alternates arm poses and bow height, consumes energy, generates mana, and displays thought cues.

Dragging takes control and releases reservations; cancellation leaves the follower wandering. Resting workers return to their previous job if autonomy is enabled and space is available. Old duplicate or absent reservations are repaired without changing follower angles.

Validation: 21 simulation tests and a production build passed at the end of A. The browser shrine scenario was subsequently improved to wait for actual saved worship states, and passed during C; its screenshot shows three distinct positions.

## Milestone B — compact worlds

New radius: 460 world units, 54% of the former 850. Two inhabitants start beside a shrine; nearby forest, rocky outcrop, meadow, and pond depression provide a purposeful layout. Seeded terrain and decorations remain deterministic. Trees render in ecological clusters.

Runes unlock at levels 3, 6, 10, and 15. Each adds 95 radius over roughly 5.3 seconds, adding circumference for construction and fresh seeded resource patches. Existing heights, buildings, and follower identities remain intact. The camera follows the changing radius; overview computes framing from actual dimensions. Growth targets survive saves mid-animation.

Validation: 24 simulation tests and production build passed at the end of B. The compact world and resource clusters were inspected in the production browser during C.

## Milestone C — landscape economy

Starter inventory: 255 gold, 8 wood, 3 stone, 5 water, 5 food. Wood, stone, water, and food have saved inventories and capacities. Recipes and upgrades require gold plus materials and validate before deductions. Demolition returns 35% of base gold and 50% of base materials.

The logging camp has two slots; the quarry has three. Each terrain sample records wood, stone, vegetation density, moisture, fertility, regrowth, and extraction intensity. Work consumes actual accessible stocks. Extraction thins tree cover or depletes rocks; rain supports gradual regrowth. Quarry upgrades improve cycle efficiency. New buildings preserve the original procedural art style.

Manual gathering extracts real stocks, grants one gold, and has a six-second shared cooldown. Resources includes free replanting; free passive mana supports rain, so an empty inventory does not prevent recovery. Rain collectors fill only from local rainfall or nearby finite pond water. Moisture alone never becomes stored water.

The compact Resources control opens inventory, capacity, recent per-minute production/consumption, and warnings. Rates use a 60-second exponential activity window; they settle toward sustained throughput rather than predicting idle factories. Placement previews explain site suitability, recipes, worker capacity, and local stocks. Material collection produces floating labels.

Validation: 29 simulation tests and production build passed at the end of C. Production browser scenarios passed for desktop navigation/rain and three simultaneous shrine workers. Screenshots were inspected.

## Milestone D — needs and progression

Farms use fertility, temperature, worker happiness/energy/hunger, and stored water. A watered cycle uses one water and produces five food. A dry farm works at a quarter speed for two food, providing a gentle fallback. Fishing requires pond water and produces food. Both also produce collectible gold. Farm capacity is three; tents provide two rest positions.

Hunger takes over fifteen minutes to trigger the first meal. Autonomous followers release their work slot, walk to a settlement food position, eat one food, then reserve a job again. Shortages gradually reduce happiness and productivity without famine deaths. New level arrivals require two food; visitors wait safely for a surplus when food is low. Construction and harvesting goals make the first level-three rune accessible in a few minutes of purposeful play.

The tutorial uses real conversion, arrived worship time, rainfall on forest, manual wood extraction, completed logging construction, worker wood extraction, farm completion, water collection, farm/fish food production, collected gold, and rune expansion. Existing completed goal IDs remain completed.

## Saves

Save format v2 accepts v1 worlds, preserves their radius and entities, adds resource/need defaults and terrain stocks, repairs reservations, and labels them legacy worlds. Existing worlds are never automatically shrunk. An explicit New world action still requires the existing in-game confirmation; export retains a copy of the old world. A failed load pauses and blocks automatic writes, preserving the original IndexedDB record and making its original JSON available through Export.

Offline production uses finite stocks, water, storage, energy limits, and only workers who actually arrived. It never creates harvestable wood just because a camp exists. No offline disasters or deaths are introduced.

## Verification and limits

Final verification on November 1, 2026: 39 simulation/integration tests pass; all six Chromium browser scenarios pass across the full-suite and targeted final runs. These cover desktop navigation/rain, farm construction → food/gold → collection → reload, mobile touch rotation/pinch, three shrine reservations and worship after reload, material gathering/persistence, and protection of an invalid stored save against manual/autosave writes. Production build, strict TypeScript, Prettier, and whitespace checks pass. The normal-start integration reaches logging, watered food production, collected gold, and first expansion within three simulated minutes using only starter inventory and earned resources.

Run `npm test`, `npm run build`, and `npm run test:e2e` from the repository root. Browser checks use Chromium/software WebGL, one worker to avoid GPU contention. Generated screenshots are in ignored `tiny-deity-src/test-results/`.

Ecology remains a one-dimensional sampled surface, and water uses the existing local basin model. Passing uses a temporary second visual footpath rather than rigid-body collisions. Rain collection currently responds to targeted rain miracles and pond stocks. Long-term economy tuning, physical devices, Safari/Firefox, and maximum population performance require further playtesting.
