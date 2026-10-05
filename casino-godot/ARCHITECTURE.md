# Architecture

The game is built with Godot 4 and GDScript to support a browser test and desktop
runs from one project. This adapts the supplied concept's C# preference to the
user's priority of playtesting on their existing GitHub Pages site. It is a game
project, separate from the portfolio's HTML apps.

- `scripts/craps.gd`: pure deterministic resolution of an ordered dice pair and
  a bettor's contracts. No rendering, input, files, or scene-tree dependencies.
- `scripts/casino_games.gd`: slot, roulette, blackjack, and dealer hold’em rules,
  card evaluation, legal actions, and saved-round validation.
- `scripts/game_view.gd` and `scripts/game_art.gd`: scrolling game controls and
  procedural reel, wheel, and card presentation.
- `scripts/tuning.gd`: starting funds, capacity, timing, costs, wages, floor bounds.
- `scripts/simulation.gd`: simulation state, treasury/wallet transfers, guests,
  staffing, table rounds, incidents, placement, clock, versioned snapshots.
- `scripts/floor.gd`: procedural floor rendering, visitor movement/collision,
  zoom/follow view, selection, build previews. Emits selection/placement signals.
- `scripts/craps_layout.gd`: clickable desktop felt, dice, and recent rolls.
- `scripts/main.gd`: responsive game UI, fixed simulation ticks, persistence, mode switches,
  dice animation, onboarding. Simulation continues while playing.
- `tests/run_tests.gd`: headless rule/economy/persistence/navigation scenarios.
- `tests/browser_smoke.mjs`: browser lifecycle and control integration tests.

A table owns its point/dice and every seated bettor shares the same roll. Guest
bets and the visitor's separate contracts all settle against casino cash. Placed
stakes are held by the casino, and cash-result metrics include unsettled stakes;
finance also subtracts live liabilities to show settled result. Visitor results
are visible separately because owner play can otherwise distort business results.

Simulation advances once per game minute, not once per rendering frame. Guest
movement interpolates between grid-navigation waypoints. AStarGrid2D routes around
placed tables; placement reserves an aisle. Visitor movement has collision checks
and manual keyboard steering; touch paths route around furniture.

Craps cannot operate without two assigned dealers. Closing admits no new guests
or bets but finishes contracts. Tables retain a shooter and seat rotation. A
visitor joins the queue behind the active shooter; CPU rolls continue until the
visitor’s turn, unless Hold betting is enabled. Making a point retains the dice;
seven-out advances to the next seat. Leaving releases any manual turn to the CPU.
Sell/move
is blocked for occupied tables and unresolved visitor bets. New tables can reuse
standby crews. Paused time disables manual rolls, so guests/finance remain in sync.

The current v4 save format contains domain state and a version, not serialized nodes.
It includes difficulty, starting-game selections, earned Rating, onboarding counters,
expansion/VIP/high-limit purchases, extended bets, shooter/queue state, roll history
and repair wear. Difficulty configuration and ordered access thresholds live in
`tuning.gd`; `simulation.gd` enforces purchases, staffing access and table limits,
while `main.gd` presents setup, revealed/locked content and the next milestone.

During pre-alpha, clean architecture takes priority over disposable development
saves. Support only the current schema; reject incompatible versions without
migration. Remove obsolete compatibility code when encountered, while retaining
corruption checks and defensive handling for current optional/runtime data.
Historical save compatibility requires an explicit future policy change.
The save path is `user://neon-house.json`. RNG
state is a decimal string to preserve all 64 bits through JSON. Saves use Godot's
`user://` path, backed by browser storage in web builds. UI mode/speed settings
are session-only. The single save slot is deliberately small in scope.

Art is generated through drawing primitives and is replaceable independently of
craps resolution. A later 3D view can consume the same domain state, but rendering
and navigation would need significant work. A C# port is possible but is not
necessary for native Godot/Steam builds.

## Phase 02 financial feedback

The simulation emits `financial_event(Dictionary)` after actual gambling settlement.
Consumers must treat events as read-only. Fields include sequence, house-perspective
`amount`, category, game, asset ID, slot profile, guest ID (0 visitor, -1 aggregate),
actor, importance, elapsed minute, position, round, settled stake, returned credit,
and cumulative asset wager/payout snapshots. Craps aggregates guest results per
roll while preserving participant IDs, settled stakes, credits and net amounts.
Visitor results remain separate. The category string leaves room for later bar,
comp, payroll, repair, construction, hiring, sale and service events; Phase 03 also emits actual construction, repair and sale cash changes. Audio or milestone listeners can subscribe to the
same signal without reading UI or inferring treasury movement.

House net is settled stake minus total returned credit, including returned stake.
For craps, settled stake is exposure before resolution minus exposure afterward.
Standing-bet wins therefore emit negative house profit without charging their
still-live stake again; unresolved contracts emit nothing. Stake refunds and cage
summaries never emit another gaming result. Existing per-asset wager, payout and
round counters continue to persist. Recent events are bounded transient feedback,
not a complete finance ledger, and are cleared on Load without replay.

`floor.gd` consumes the signal for asset-anchored, fixed-pixel popup labels. Small
same-asset/same-sign bursts may combine with a result count; guest and visitor
money never mix, and losses never cancel gains for display. Caps, priority and
collision placement limit spam while keeping large results readable. Lifetimes
are 1.3-1.9 real seconds, independent of simulation speed. Cash-out summaries are
explicitly marked SESSION. `financial_text.gd` formats monetary presentation;
`main.gd` smoothly follows authoritative treasury cash and shows its exact target
in a tooltip. Cash motion includes wagers, payouts, liabilities and expenses, so
it deliberately differs from completed gambling net events. Game views and the
floor report show compact recent settled house activity from the same events.
New Casino/Load reset transient visuals; no save schema changes or migrations.

## Phase 03 slot profiles

`tuning.gd` owns five fixed machine profiles. `slot_profile()` derives/caches exact
RTP, edge, return variance and top-award probability from configured reel weights
and total-return payouts. There is no arbitrary RTP slider. Simulation placement,
limits, guest wagers, repair cost and resale use the specific asset profile.
Profile access uses earned Rating plus settled guest handle, retained in saves;
per-profile development caps prevent cheap-unit spam, while an overall 30-point
slot cap permits a slot-only casino to reach the highest development Rating.

Every asset persists available/occupied/open-broken minutes, operating/repair
expense and repair/breakdown counts alongside wagers/payouts/rounds. These are
bounded scalar accumulators, not transaction-ledger UI. Gaming events retain
profile and asset IDs and carry expense/utilization snapshots; sale carries final
counters for subscribers before the asset disappears. Recent events remain
transient. Current schema is 6; old disposable saves are rejected without migration.
Dev Advance and Force Unlock recognize tier targets and use real purchase paths
when preparing development, with the existing debug-build guards.
