# V0.4 architecture

One Godot/GDScript source project produces public release `casino/` and local
`casino-debug/`. `export_web.py --both` regenerates both; generated JS/WASM/PCK
are never hand-edited. Developer tools/actions and extreme speeds require
`OS.is_debug_build()` in both UI and simulation entry paths.

## Ownership

- `simulation.gd`: cash and separate Owner Bankroll, guests, staff, assets,
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
- `optional_objectives.gd`: bounded opt-in goal lifecycle, recent capability samples,
  authoritative progress, persisted cooldowns and scarce personal rewards.
  Claims use the existing owner account and durable checkpoint with rollback.
- `objective_cards.gd`: retained, collapsible goal content in the existing Log pane.
- `casino_momentum.gd`: deterministic slow operating momentum and bounded attraction.
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

## 0.4.2.1 / 0.4.2.2 foundation

`owner_bankroll.gd` holds the personal account, monotonic operation sequence,
escrow and 64-entry history. Simulation exposes a read-only `owner_bankroll`;
all game debits/credits use account transactions. Existing floor games retain
house-counterparty accounting and their existing once-only round/contract guards.
`visitor_net` remains the internal floor-play ledger, excluded from guest profit.

For event callers, capture `owner_account.next_operation` once per action and
call `owner_wager_debit(id, stake)`. Repeated IDs are rejected. Settle exactly once
with `owner_wager_settle(id, total_return)` (stake included), or
`owner_wager_win(id, net_profit)`, `owner_wager_loss(id)` or
`owner_wager_refund(id)`. A $100 stake returning $200 restores $100 personally
and transfers $100 to casino cash. Partial returns lose only the missing stake.
These transfers are tracked separately from guest gaming revenue and included
in recorded net cash flow. `reward_owner_bankroll(id, amount, reason)` is bounded
by tuning and rejects repeated IDs; there is no normal-play replenishment button.

Save version 16 gets additive `owner_bankroll` and `optional_events` fields.
A previous version-16 `wallet` initializes the account without touching treasury;
a missing personal balance defaults to $1,000. Other historical schemas remain
unsupported. Both components validate into temporary objects before the casino
applies any state. Pending escrow, operation sequence and result history survive
JSON saves, preventing replayed settlements after reload.

`optional_events.gd` owns definitions, runtime queue, cooldowns, outcomes and a
separate saved RNG. One check per configured open game-minute interval uses
weighted eligible definitions; no independent timers, gambling RNG consumption,
wall-time catch-up or production emergencies. Closed time defers scheduling;
loading preserves future checks and delays overdue checks by one interval.
Opportunity dismiss/failure/expiry cannot apply consequences. Management and
Emergency effects are explicit definition data; current examples are debug-only.
Debug-only active definitions are discarded without consequences in release.
The queue is capped at four and prioritizes emergencies, then management.

`engage(sim, id)` changes state before emitting `action_requested` with ID,
action and target. A controller may focus an asset/open a pane immediately or
launch an asynchronous game later. Completion calls `resolve(sim, id, outcome)`;
success/failure require engagement and every terminal outcome removes the ID
before effects. Async consumers can inspect persisted engaged entries to resume;
loading does not re-emit actions or rewards. No gambling-event catalog is added.

`event_cards.gd` retains a single visible card and expandable details inside the
existing activity scroll area. Desktop layout reserves more activity height when
a card is active, reflowing the floor and actions without overlap. Mobile keeps
the floor unobstructed and shows a category-colored Log count; opening Log uses
the shared pane transition. Queued events count down even while hidden.
F10 sample controls exercise each category and one clearly marked simulated win;
all artificial triggers require debug builds.

## 0.4.2.3 / 0.4.2.4 owner games and contextual catalog

`owner_event_play.gd` reuses `CasinoGames.spin_slots`, `blackjack`, `actions` and
`act`, plus the existing `game_view.gd` / casino canvas. A separate simulation-owned
`owner_play` session holds event ID, operation ID, target, fixed/bounded stake,
round count, action sequence, committed game data and result. The real asset stays
in the normal NPC loop; events do not set `joined`, change odds, collect NPC stakes
or write owner wagers into guest handle/revenue/payouts. Presentation gets a copy
of the target with the event round. Targets cannot be sold/moved while in use.

Lucky Machine escrows all three spins and generates their actual paytable results
at commitment using the persisted event RNG. Spins reveal those results, and the
whole batch settles net once. Owner's Hand saves the six-deck shoe and all hands;
insurance, splitting and doubling add real stakes to the same personal escrow.
UI actions carry the rendered sequence, preventing replayed clicks. Exiting
reveals remaining committed spins or declines insurance/stands remaining hands.
A funded event stops expiring, cannot be dismissed into a refund, and finishes
with one settlement; uncommitted offers still expire without a penalty.

Owner results show the outcome, total stake, personal bankroll change and casino
profit change. Only aggregate positive net winnings enter casino cash; losses
stay personal and pushes restore the stake. `bonus_profit` metadata defaults to
zero and is credited only with a net win. `reward_hooks` exposes zero/inert
momentum, reputation and mystery metadata; no Momentum or VIP system is added.
`owner_event_completed` publishes only after a successful persistence checkpoint.

The controller supplies a checkpoint callable. Accepted owner commitments/actions/
exits atomically replace a complete local snapshot using a temporary file and
rename. Preflight storage failure prevents funding; post-action failure restores
the previous simulation snapshot before publishing results. Game data, escrow,
sequence and event linkage validate together on restore. Missing `owner_play`
defaults to an empty session for previous version-16 saves. Tests supply an
isolated `/tmp` checkpoint path and never overwrite the developer's save.

All contextual scheduling stays in `optional_events.gd`. Eligibility/engagement
uses live operational tables, real guest players/watchers and recent funded hot
activity; a celebration requires an already settled large guest slot payout.
Drink events require a staffed available counter, a nonempty player-selected
menu and actual outstanding orders. Fatigue targets an existing active tired
dealer; repair and complaint events reference actual incidents. Invalid contexts
withdraw without an event penalty. Management ignores preserve the organic
fatigue, halted-play and thirst behavior already in the simulation.

Cards expose the source and up to two contextual responses. Focus uses the shared
pane transition and normal asset selection; dealer focus expands/highlights
employee details. Repair and complaint comp responses call `resolve_incident`
once, with its actual cost/effect and funds check. No fabricated cleanliness,
promotions, demand boosts or extra timers are introduced. Production frequency,
weights and cooldowns remain conservative and centralized. Debug catalog controls
require actual eligible contexts and bypass only cooldowns, not progression.

Mobile stake review stays in Log, while a committed event uses the existing
scrollable game view with notifications hidden. The result offers an explicit
return to management. All money-only result labels stay atomic; all existing
standalone games keep their original accounting and controls.
