# Architecture

The game is built with Godot 4 and GDScript to support a browser test and desktop
runs from one project. This adapts the supplied concept's C# preference to the
user's priority of playtesting on their existing GitHub Pages site. It is a game
project, separate from the portfolio's HTML apps.

- `scripts/craps.gd`: pure deterministic resolution of an ordered dice pair and
  a bettor's contracts. No rendering, input, files, or scene-tree dependencies.
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

The v2 save format contains domain state and a version, not serialized nodes.
It migrates v1 saves and includes extended bets, shooter/queue state, roll history,
and repair wear. The existing save filename is retained for migration. RNG
state is a decimal string to preserve all 64 bits through JSON. Saves use Godot's
`user://` path, backed by browser storage in web builds. UI mode/speed settings
are session-only. The single save slot is deliberately small in scope.

Art is generated through drawing primitives and is replaceable independently of
craps resolution. A later 3D view can consume the same domain state, but rendering
and navigation would need significant work. A C# port is possible but is not
necessary for native Godot/Steam builds.
