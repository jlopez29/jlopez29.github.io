# V0.3 architecture

One Godot/GDScript source project produces public release `casino/` and local
`casino-debug/`. `export_web.py --both` regenerates both; generated JS/WASM/PCK
are never hand-edited. Developer tools/actions and extreme speeds require
`OS.is_debug_build()` in both UI and simulation entry paths.

## Ownership

- `simulation.gd`: cash and separate visitor wallet, guests, staff, assets,
  progression, service, demand, incidents, financial events and milestones.
- `tuning.gd`: fixed profile payout math, prices, limits, wages, progression,
  traffic, patience, maintenance, reserve and presentation tuning.
- `casino_games.gd` / `craps.gd`: actual cards/reels/wheel/dice and settlements;
  neither consumes reserve advice to alter outcomes.
- `main.gd`: responsive controller/HUD, inspectors, Finance, saves, state controls.
- `floor.gd`: rendering, placement, navigation/movement, financial/thought feedback.
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

Schema 12 snapshots include guest activity/demand budgets, traffic classifications,
ledger/asset counters and earned milestone IDs. Strict type, finite-number,
current-field, ID/reference, capacity and path defenses remain. Runtime safety
bounds match save validation (20 assets, 16 staff, 40 guests); invalid guest seats
are checked against the actual asset type. RNG state is a decimal string to
preserve all 64 bits through JSON. Navigation caches, presentation queues,
financial/thought history and forced developer access are transient. Restore
recalculates progression silently, resets caches/dev speed and never resettles
or replays old events. No migrations, legacy schemas or aliases are supported.
