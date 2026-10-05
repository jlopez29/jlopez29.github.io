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

The current v10 save format contains domain state and a version, not serialized nodes.
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

## Phase 04 hospitality

The simulation owns delivery-time drink transactions, eligibility, thirst relief,
and bar counters. Both card/wheel/slot game debits and craps bets stamp the last
successful real guest wager. Basic comp eligibility combines recent wagering with
Playing state, independently of seat reservation; spectators pay. Profiles and
the small comp policy live in tuning.gd. Existing walking staff remain the delivery
mechanism. Preparation and movement use simulated seconds; eligibility, thirst and
wager recency use executed game minutes, preserving the existing speed mechanism.

A delivery emits a bar/comp net event with price and product-cost components,
guest position, associated game asset and service staff name. Floor feedback follows
hospitality guests and separates categories when combining popups. Paid drinks
never enter gaming revenue or progression handle. Drink spending is removed from
cage gaming summaries. Finance separates hospitality margin, service payroll and
complaint comps; operating and total cash-flow accounting include each amount once.
Schema 8 persists bar totals and guest wager recency/spending with current-version
validation and no migrations. Abandoned routes never settle a drink.

## Step 01.8 responsive presentation

main.gd reflows the shared UI using width, height and aspect: persistent desktop
panels at >=1180px wide and >=650px high, compact tabbed layouts below either
threshold, and landscape floor behavior when width exceeds height and height is
below 600px. Portrait fits the room; short landscape starts width-filling and
allows drag-to-pan vertically, with Fit / Closer controls. The same floor world
coordinates, simulation and save schema are used on every layout. Mobile asset
badges show fixed-pixel ID/state instead of overlapping names/status paragraphs;
full information remains in Inspect. Management and Log occupy the mobile content
area on demand. Save/Load/Help move into Menu; normal speed remains accessible in
the header, and the same debug-only tools have a guarded DEV touch button.

Viewport size changes reflow panels, modal bounds and the debug panel without a
reload. Playable views retain their shared scrollable presentation; mobile uses
smaller outer margins, without shrinking action-button touch heights. Detailed
roulette/craps betting layouts may still need a focused touch ergonomics pass.

The public launcher source is web/index.html. export_web.py regenerates casino/
index.html from it along with the Godot export, preserving the public URL and
iframe/fullscreen behavior. The launcher uses dynamic viewport height, safe-area
padding and a shorter landscape header. Debug game.html remains directly usable
on the local debug server; the built-in Godot shell uses canvas resize policy 2.

## Finance progressive disclosure

Finance presentation in main.gd uses reusable metric, amount-row and expandable
card components. Cash is current; operating/category totals are explicitly lifetime.
One category expands at a time, with drill-down state retained across normal UI
refreshes and reset on entry. Gaming groups current assets' guest gaming results
using existing asset accounting; disposed assets' unallocated historical results
appear as Sold assets rather than an invented game breakdown. Investment uses the
existing combined equipment/upgrades ledger and separate hiring, without inventing
purchase-type history. Categories render their own details and relevant actions.

Bar appears for service staffing or recorded drink/payroll activity. Its card is
margin before labor, so Gaming + Bar - Payroll - Operations matches operating
profit without double-counting costs. Expanded Bar shows service payroll and net
contribution; Payroll includes all employees. Aggregate drink detail is isolated in
its own renderer so later tracked recipe performance/menu actions can be added
there. No recipe statistics, menu mechanics or reporting periods are introduced.
Zero detail rows are suppressed except meaningful owned-game totals and requested
subtotal results. Reconciliation and labor-state diagnostics are behind Advanced
accounting. Button-child labels participate in existing UI patching so card values
stay live without replacing controls during ordinary financial updates.

## Phase 05 floor communication

simulation.gd owns archetype choices, intent and guest_thought events. Centralized
profiles influence existing game selection/watching/patience/service expectations;
arrival capacity, rules and core finance are shared. think() updates inspectable
intent and emits bounded, prioritized event notifications. Real guest wagering
records transient social attention per gaming asset, consumed by choice/watch
logic and a subtle floor ring. Neither thoughts nor table_hot() feed game rules.

floor.gd owns real-time thought queues, cooldowns, expiry and fixed-pixel bubble
layout. Bubbles follow live guests, avoid drawn financial labels and other guest
positions, and suppress events that cannot be placed. Nearby Walk mode can surface
current simulation thoughts through the same throttle. Money remains signed net
numeric feedback; thought bubbles are soft rounded natural-language panels.
The shared guest inspector shows archetype/current intent, and playable views
surface one real companion thought. Current schema 9 saves archetypes; transient
presentation cooldowns and hot-table wager history clear on restore.

## Phase 05 multi-activity lifecycle

simulation.gd owns per-guest session clocks and continuation decisions through
guest_lifecycle_step(), finish_guest_session(), affordable_game() and the shared
game_choice_score(). Exploring, Seeking drink and Getting drink are legitimate
bounded non-gambling activities, using existing routing and physical delivery.
Contracts/hand liabilities block seat release. Watching and local wait/travel
patience use activity start times. Newly opened games are discovered during
session-boundary selection, not by a global traffic boost or duplicated AI.

Schema 10 persists lifecycle fields with current-version validation. The same
minute-step lifecycle runs at every speed. Presentation consumes existing guest
thought events for the resulting decisions. Aggregate arrivals/demand retain their
existing rules and remain Phase 07; their capacity check recognizes the new
activity states rather than treating them as nonexistent people.

## Phase 06: management intelligence

Simulation owns read-only `asset_performance`, `reserve_report` and purchase
planning. Settled asset handle subtracts live stakes; payouts include returned
stake. Gaming win is settled handle minus payouts. Guest contribution additionally
excludes visitor results, direct upkeep, repairs and assigned dealer payroll;
capital and shared service costs remain separate. Asset activity includes all
participants, and utilization means minutes with any participant divided by
available operating minutes, not occupied seat percentage. Comparisons group
owned slots by profile and tables by game, with available asset-hour samples and
normalized throughput/contribution. Finance reveals comparisons and reserve
breakdowns on expansion, then links to individual inspectors and Build.

Reserve advice uses free cash after pending stakes, a large-asset payout buffer,
a partial buffer for remaining assets, four hours of wages/upkeep and known
repair bills. Transient severity-change notifications are rate-limited. Purchase
plans include new equipment, hires after available standby dealers, incremental
payroll/upkeep and the enlarged floor buffer. These estimates never affect
outcomes, purchase permissions or progression. No schema changes or migrations.
