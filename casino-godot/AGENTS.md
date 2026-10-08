# Pit Boss - Agent Instructions

## Purpose and operating principles

Pit Boss is an early pre-alpha **Godot** casino management/tycoon game that combines business management, a living top-down casino floor, walking as the owner, and playing casino games. Its business loop is **Build -> Attract -> Operate -> Earn -> Reinvest -> Unlock -> Expand**. The player should also have meaningful, optional active ways to participate; the game must not become a forced idle/clicker experience.

Implement **only the requested task or phase**. Prefer fast, maintainable iteration and the smallest clean solution. Preserve existing working features and do not implement speculative roadmap phases. Refactor narrowly when necessary to achieve actual shared behavior, not merely cosmetic similarity.

## Git and execution workflow

- **Stay on the currently checked-out branch.** Do not create, checkout, or switch branches unless explicitly requested.
- **Do not commit, push, open pull requests, merge into master, or reset/rebase branches** unless explicitly requested. Do not assume a feature task authorizes Git publication.
- Inspect the task's named source files and direct dependencies first. Do not scan the whole repository, generated artifacts, or historical test reports by default.
- Briefly identify the implementation approach for substantial architecture changes, then execute the requested work. Avoid spending tokens on lengthy planning essays or repeated audits.
- Preserve useful existing code and assets. When replacing a system, remove the **superseded UI, dead references, duplicate paths and provably unused code/assets** in the touched area. Check references before deletion. Do not leave old and new versions running in parallel or carry obsolete compatibility scaffolding forward.
- Do not perform an unrelated repository-wide cleanup unless the user requests one. If a cleanup is explicitly requested, check dependencies before removing anything.

## Source of truth and architecture

Primary editable game source: `casino-godot/`. Web builds (`casino/`, `casino-debug/`) are **generated artifacts**. Do not manually modify or read generated `.wasm`, `.pck`, or `.js` files unless the task specifically requires export/runtime debugging. Use the Godot source as the authority.

Key existing areas (check the current code; filenames may evolve after refactoring):

| Path relative to `casino-godot/` | Responsibility |
| --- | --- |
| `scripts/simulation.gd` | Authoritative casino simulation, economy, public tables, guests, staff, persistence and events |
| `scripts/tuning.gd` | Centralized game balance, constants, costs and limits |
| `scripts/casino_games.gd`, `scripts/craps.gd` | Canonical gambling rules, RNG-driven outcomes and settlement logic |
| `scripts/owner_bankroll.gd`, `scripts/back_room_session.gd` | Personal wallet, private wager escrow and private game actions |
| `scripts/recovery_system.gd` and related files | Owner-wallet recovery challenges, eligibility and rewards |
| `scripts/main.gd` | Application/controller and state transitions, not game-rule duplication |
| `scripts/floor.gd`, `scripts/floor_property.gd` | Shared navigation concepts, property geometry and placement boundaries |
| `presentation/casino_floor_v2.gd` / `.tscn` | Current top-down floor world, camera, asset/character presentation |
| `scripts/game_view.gd`, `scripts/casino_surface.gd` | Existing playable game HUD and game presentation |
| `presentation/play/craps_surface.gd`, `scripts/roulette_layout.gd` | Existing detailed casino-game interaction/presentation |
| `presentation/components/` and `assets/pit_boss/` | Shared character markers and visuals |

Use `casino-godot/ARCHITECTURE.md`, `BALANCING.md`, `ROADMAP.md`, or `STEAM.md` only when the current task requires them. Avoid rereading documents that do not affect the task.

## One implementation per casino game - mandatory

- **Public floor and Back Room must use the same game implementations**, including the playable UI, underlying game rules, input controls, RNG, paytables, cards/dice/reels, visual effects, audio and presentation assets. Do not write separate private versions that merely resemble their public counterparts.
- A modification to a regular floor slot, craps, roulette, blackjack or Ultimate Texas Hold'em game must be reflected in that same game in the Back Room without manually copying the change. This applies to future game additions and shared feature improvements too, unless the task explicitly specifies an exception.
- Separate **context** from **implementation**: public and private games can have different wallet/house accounting, operating restrictions and room location, but must call into shared gameplay and visual components. Use a narrow data/action adapter or shared context abstraction if needed.
- Never insert pretend Back Room fixtures into the public `sim.tables`, public staff/payroll, placement or guest-traffic collections merely to reuse a UI. Do not fork authoritative rules or invent a second RNG/payout mechanism.
- Public casino assets retain their normal progression, minimums, capital costs, repairs, payroll and operational constraints. Private equipment must not bypass those rules on the public floor.

## Back Room - permanent design contract

The Back Room is a **physical, second, top-down, walkable casino floor**, not a menu, game-selection list, or separate form-driven gambling application.

- The owner walks through an **owner-only door at the bottom-right edge of the current expandable public property**. The door position follows floor expansion and remains accessible. Clicking it from far away initiates walking, not instant teleportation. Staff and public guests cannot enter.
- The owner enters a furnished private room with preinstalled, always-available slots, blackjack, roulette, craps and Ultimate Texas Hold'em tables (and any future supported games). Use existing floor/table/slot/character assets, proportions and the same owner walking/approach interaction conventions.
- Private table dealers/fixtures are room decoration or non-operational actors. They have **no salaries, fatigue, maintenance, purchase price, capacity, public guest traffic or casino expense entries**. The public casino's real simulation and operating expenses remain independent and can continue normally.
- Walk to each fixture to interact; open its **actual shared playable game interface**, then return to the same private location. Keep accurate table/slot approach directions. Exit through the room's physical door back to the public-floor threshold.
- The starting personal wallet is **$1,000**, separate from casino cash. Back Room wagers use the personal wallet, with no public table minimums or progression locks; still enforce affordability, exact cents, game rules, escrow and idempotent settlement.
- Preserve established private settlement: for stake `S` and total return `R`, return `min(S, R)` to the personal wallet and add `max(0, R - S)` to Casino Cash. Losses reduce only the personal wallet; do not debit casino cash for private losses. Never fabricate wins or allow repeat settlement.
- Wallet replenishment/recovery is an **optional physical room interaction**, preserving actual effort/time requirements, challenges, and RNG-based scratch-card/raffle rewards. Do not replace it with effortless idle income.
- Remove superseded lobby/teleport/forms/duplicate game controls after migrating useful state and recovery functions. Preserve current private wagers, wallet integrity and save/load semantics, subject to the development-save policy below.

## Testing policy - smoke first, regressions only on request

The developer performs most gameplay verification manually. **Token efficiency matters.**

- For normal implementation work, favor build/startup validation plus **the smallest existing feature-specific smoke check** directly relevant to changed behavior. Keep verification brief; do not automatically run broad suites, cross-device browser matrices, long seeded simulations, screenshot-capture runs or performance soaks.
- **Do not write or expand automated test suites by default.** Add a focused smoke test only when explicitly requested or essential to validate the task; prefer updating a directly obsolete smoke check over creating duplicate test infrastructure.
- **Full regressions are opt-in only**. Never run `run_regression.py`, `run_tests.gd`, `run_v03_tests.gd`, broad browser regression or long performance benchmark unless the user explicitly asks for a full regression. Do not quietly trigger them through another wrapper.
- Performance profiling and soak tests are **opt-in**. Never rerun the historical one-time 0.4.2 performance investigation as part of normal development.
- Maintain a lean `tests/` folder: keep essential startup and focused smoke checks; retain a **manual-only** full-regression capability if useful; remove or archive demonstrably unused one-time benchmark scripts, captures, result JSONs and stale reports when test cleanup is requested.
- Check script imports, inheritance and test-runner references before deleting or reorganizing tests. In particular, some newer tests inherit helpers from older `run_v03_tests.gd` / `run_tests.gd`; refactor dependencies before removing those files.
- If the user says **no tests**, do not run them. Always mention what was and was not verified without presenting unrun tests as passing.

## Saves and state

Pre-alpha **development saves are disposable**: do not add migrations, legacy schema adapters or historical compatibility work unless explicitly asked. Current-version saves and authoritative state should remain internally consistent. Preserve defensive handling of corrupt data, invalid money, double actions, outstanding wagers and runtime errors. Never silently erase or double-credit in-progress private bets in the current build. When modifying schema, cleanly replace obsolete current code instead of adding historical branches.

## Casino gameplay and economy

- **Normal** starts with a small slot operation and earns public-floor game/service/VIP/property progression. **Easy** can offer broader starting choices. Private Back Room access does not unlock or subsidize public machines.
- Casino cash, guest money and owner bankroll must remain distinct. Finance and transaction feedback must reflect real state changes, never fake excitement numbers. Separate payroll and operating expenses from purchase and onboarding costs.
- Balance for long-run performance while allowing meaningful variance, poor utilization, overstaffing and overhead to cause losses. Do not inflate house edge to conceal unrelated cost/throughput problems. Game speed must not alter expected economics or RNG order.
- Active decisions, optional events and skill/effortful recovery should complement idle management. Keep optional event participation skippable without making busy players unable to continue operating their casino.
- Unlocked drinks are menu options; the player selects products/prices and faces real demand, margin and service consequences.
- Staff fatigue should drive meaningful coverage and relief decisions. Active/Relief/Break/Off Duty staff and automatic rotation should support continuity. Closing the property should not be an instant universal stamina reset.

## UI, responsiveness and living floor

- Favor hierarchy, concise context and progressive disclosure: **Summary -> Expand -> Detail -> Action**. Keep the primary floor visible and usable; send asset specifics to inspectors and analytics to Finance. Do not crowd the main viewport with raw state tables.
- Preserve mobile portrait, mobile landscape and desktop use. Reflow for width/height/orientation; do not simply shrink everything. Modes requiring floor targeting must keep the target unobscured and preserve state across rotation.
- Keep currency/short key metrics intact: never wrap monetary values character by character. Prefer vertical reflow if width is constrained.
- Routine gaming outcomes appear as concise signed financial feedback (for example `+$25`), not a high-volume House Activity ledger. Reserve House Activity for meaningful management events. Detailed internal financial events remain available for analytics.
- Guest preferences/complaints should be actionable and appropriate to unlocked systems. Thoughts/reactions belong on world-space guest markers where possible; rate-limit bubbles/visual feedback to avoid excessive redraws. Do not change gambling RNG or fabricate outcomes to create visible drama.
- Guest visits can include gambling, watching, browsing, changing games, service and departure. Let behavior and population emerge from bankroll, satisfaction, stay tendency, capacity and traffic rather than artificially fixing headcount.
- Prefer ASCII-safe **player-facing** text if the current font cannot reliably render special glyphs; keep source UTF-8. Treat visible replacement glyphs/mojibake as bugs, but do not rebuild the font system to accommodate decoration unless requested.

## Performance and developer tooling

- Prefer cached/indexed presentation lookups over repeatedly filtering every guest/staff member per object; invalidate caches only when underlying state changes. Retain UI nodes for content updates instead of rebuilding entire panels every tick.
- Keep diagnostics and telemetry cheap, with full-state serialization only on an explicit slower/debug cadence. Batch visual feedback independently of economic settlements. Preserve sim time, money and RNG behavior while optimizing presentation.
- Debug-only progression/state tools are fine when genuinely needed for manual development. Keep them out of production (`OS.is_debug_build()`), do not weaken Normal balance for testing, and do not use extreme speeds as a replacement for proper progression controls.

## Build and completion reporting

- After finishing game-source changes, **regenerate the playable web export** with the established `casino-godot/export_web.py` workflow and appropriate installed Godot binary/export templates. Generate release `casino/` and debug `casino-debug/` from the same source when required for manual testing. Do not manually edit exported output.
- Export/build is **not permission to run full regression tests**. Fix source/build errors in scope before declaring the task complete.
- If export cannot be run, say so plainly and provide the command needed; never imply an unbuilt version is playable.
- Keep the final response short and factual: what changed, key files, **build/export SUCCESS / NOT RUN / FAILED**, **playable output updated YES / NO**, what was actually smoke-checked (if anything), and 2-3 concise manual gameplay checks. No lengthy test report unless requested.
