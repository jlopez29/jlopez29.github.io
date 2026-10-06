# V0.4 architecture

One Godot/GDScript source project produces public release `casino/` and local
`casino-debug/`. `export_web.py --both` regenerates both; generated JS/WASM/PCK
are never hand-edited. Developer tools/actions and extreme speeds require
`OS.is_debug_build()` in both UI and simulation entry paths.

## Ownership

- `simulation.gd`: cash and separate visitor wallet, guests, staff, assets,
  progression, service, demand, incidents, financial events and milestones.
- `tuning.gd`: fixed profile payout math, prices, limits, wages, progression,
  traffic, patience, maintenance, reserve and presentation tuning.
- `staffing.gd`: shared employee lifecycle, rolling shifts/rest, relief handovers,
  compatible dealer allocation by table priority and compact coverage summaries.
  Stateless helpers receive the simulation; they do not own a second staff roster.
- `drink_economy.gd`: product access, explicit menu membership, bounded prices,
  weighted guest choices and reconciled product analytics. Stateless helpers use
  simulation-owned state; preparation/walking/delivery and treasury stay in simulation.
- `casino_games.gd` / `craps.gd`: actual cards/reels/wheel/dice and settlements;
  neither consumes reserve advice to alter outcomes.
- `main.gd`: responsive controller/HUD, inspectors, Finance, saves, state controls.
- `floor.gd`: rendering, camera/input, placement and financial/thought feedback.
- `floor_property.gd`: rectangular chunk geometry, placement/walk/navigation bounds,
  directional quotes, area upkeep and current-schema property validation.
- `game_view.gd`, `game_art.gd`, `craps_layout.gd`: individual game presentation.
- `finance_layout.gd`: content-measured horizontal/vertical reflow with atomic money.
- `milestone_notice.gd`: bounded, spaced real-time accomplishment presentation.

## Transactions and analytics

Wagers fund real liabilities and settlements return total credits, including
returned stake. Financial events carry signed net house amount, category,
game, asset ID, guest/actor, position and importance. Craps aggregates guest net
per roll with participant details; owner contracts emit separately. Physical
drink delivery records sale revenue and product/comp expense exactly once.
Payroll, upkeep, repair, construction, hiring and sale ledgers preserve their
classification without a second cash charge. Cage departures summarize already
settled play; never-gambled guests leave directly. Visitor activity is excluded
from guest business readiness/contribution and remains separately inspectable.

Asset performance subtracts pending stakes from handle/win; guest operating
contribution further excludes visitor results, direct upkeep/repairs and assigned
dealer payroll. Activity/handle/payout counts include all participants. Busy-time
utilization means any occupied asset minute divided by available operating minutes,
not seat percentage. Finance groups owned profiles/games and normalizes per
available asset hour; purchases and shared service costs remain explicit.

## Progression, demand and service

Rating comes from developed property plus bounded legitimate handle/served
activity; reputation measures perception. Capacity/quality/profile caps prevent
cheap-count unlock spam. Blackjack uses multiple accomplishments and cash
readiness, with no elapsed-time gate. Other access follows development. Slot-only
strategy can reach the full Rating range; catalog access never forces purchases.

Traffic derives actual operating public positions and reservations, modulates
arrival opportunities by attraction/period and permits proportional overflow.
Individual guests use archetypes, real bankrolls, session decisions, watching,
exploring, waiting, alternatives and physical drink breaks. Their cumulative
blocked-demand budget survives activity switches; mild waits are neutral and
repeated severe departures receive bounded reputation effects. One absence-of-
service incident is outstanding at a time; genuine delivery resolves it.

Read-only reserve plans use free cash, payout exposure, wages/upkeep and known
repairs. Proposed purchases account for standby dealers and incremental costs.
These estimates never change payouts, permissions or progression requirements.

Employees have explicit Active/Relief/Break/Off Duty states and game-minute
deadlines. Payroll charges each elapsed minute once in its actual paid state;
Off Duty is unpaid. Adequate relief swaps tired workers atomically, while rested
off-duty employees provide staggered upcoming-shift handovers. Short coverage
allocates complete table crews in priority order. Funded contracts pin their
actual crew through settlement; new play stops when a worker has mandatory rest
pending or table staffing is paused. This preserves craps contracts and manual
hands without refunds, free settlements, or changes to game probabilities.
Staff room movement, certifications, calendar schedules and a Pit Boss are deferred.

## Presentation and performance

Routine financial feedback merges only real same-sign/category/actor bursts;
results/history/overlap and thoughts are bounded. House Activity is operational,
not a spin ledger. Milestone IDs ensure once-only real accomplishment signals;
aggregate guest craps results qualify, owner gambling and initial free setup do
not. A major event is stronger; a guest win is caution, never a fake celebration.
Amounts remain unwrapped while explanatory labels reflow. Queues/fades use real
time, independent of speed, and reset on load/new casino without replay.

Economic minutes and movement use the existing time-scale mechanism. Debug
100x/1000x use stable substeps with frame budget/backlog limits; actual speed is
best effort. The simulation reuses a transient AStar grid between geometry
changes instead of rebuilding obstacles for every guest/service route. Placement,
movement, sale and load invalidate it. Debug browser snapshots publish at most
four times per second during steady frames, with immediate refresh publication
for controls. No measured FPS guarantee accompanies this source optimization.

## Current persistence

Schema 16 snapshots include directional floor chunk counts and property upkeep, product access/menu/prices/statistics, guest quoted
drink orders/retry deadlines, staff preparation/product assignment,
guest/bar activity and demand budgets, staffing states,
rest/shift deadlines, relief/service targets, table staffing priorities, traffic
classifications, ledger/asset counters and earned milestone IDs. Strict type, finite-number,
current-field, ID/reference, capacity and path defenses remain. Runtime safety
bounds match save validation (128 assets, 64 staff, 80 guests); invalid guest seats
are checked against the actual asset type. RNG state is a decimal string to
preserve all 64 bits through JSON. Navigation caches, presentation queues,
financial/thought history and forced developer access are transient. Restore
recalculates progression silently, resets caches/dev speed and never resettles
or replays old events. No migrations, legacy schemas or aliases are supported.

## V0.4 modular property

The complete Normal starter is 535 x 610 world units; Easy has one starting right
column. Counts `{left, right, bottom}` describe full-edge 320-wide columns and
240-deep rows. Purchasing extends the relevant rectangle edge, preserving every
existing asset/world coordinate. A bottom row spans the current width; a side
column spans the current height. This is rectangular growth, not holes or zones.
The old one-time expanded flag and fixed starter/full geometry are removed.

Entrance is now anchored to the original TOP lobby at (267, 90), between cage
and bar; guests enter and leave there. This intentionally replaces the prototype's
bottom doorway, which would have become internal during bottom growth. Cage,
bar and starter facilities stay anchored, so expansion does not teleport service
or move existing assets. Walking/placement insets reserve boundary circulation.
Guest exploring/observation, player collision, service routing, camera bounds,
rendering and strict save validation derive from the same property geometry.
Negative world X is valid; missing destinations use infinity rather than sign tests.

Navigation uses cached 10-unit AStarGrid2D with Manhattan heuristics and jump
point search. Asset solids mark only local footprints. Geometry changes invalidate
and reroute; unreachable paths never fall back to walking through furniture.
Rendering culls floor tiles to the viewport and increases tile stride in overview.
Camera Fit covers all edges, Closer/pan/wheel retain a usable view at large sizes;
visitor camera follows the player. Camera transforms support negative origins.

Purchases are bounded by 32 chunks per direction AND 131,072 navigation cells,
not literal infinity. Both are tuning values. Asset/guest/staff caps are 128/80/64;
more space does not itself create arrivals or bypass those practical caps.
Focused headless stress checks live outside the repo, not a permanent test suite.
Eight increasing/wide/tall footprints passed routing and JSON save/load; directional
purchases preserved asset positions and charged capital/upkeep once. Table choice
computes reservation counts and guest interest once per decision, avoiding repeated
crowd/property scans for every candidate asset.

Final focused headless run: 5015 x 2290 with 128 assets uses 108,843 navigation
cells and about 40 MB tracked static memory (not RSS/browser memory). Grid creation
was about 3 ms and batches of 80 long routes took tens of milliseconds. Maximum-width
21,015 x 610 used 106,947 cells: grid about 3.4 ms, 80 routes 76.6 ms. A 535 x
8,290 tall case used 40,131 cells: grid 4.3 ms, 80 routes 39.8 ms. The seeded
128-asset/80-guest/16-service-staff case took 7.19 seconds for 120 economic ticks,
peaking at 295 ms/tick. Synchronized decisions can hitch at the cap; this is a
practical limit observation, not an FPS guarantee. Desktop/landscape/portrait
camera transforms, negative click-to-walk and left-side observations passed.
All Easy starter game selections and busy saves passed current-schema roundtrips.
Browser/mobile visual, touch, responsiveness and crowd behavior remain manual
acceptance checks. Results vary by layout, machine and crowd decisions.
