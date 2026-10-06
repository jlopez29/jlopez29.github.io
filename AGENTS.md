# Neon House — Agent Instructions

## Project and scope

Neon House is an extremely early pre-alpha Godot casino management/tycoon game combining management, walking the floor, and personally playing casino games.

Priority loop: **Build → Attract → Operate → Earn → Reinvest → Unlock → Expand**.
Management explains **what** is happening; walking the floor helps explain **why**. The floor should feel alive and financially active.

Optimize for fast iteration, clean architecture, and engaging gameplay. Implement only the requested phase/task; do not add future roadmap features or perform unrelated large refactors. Small, directly related cleanup is encouraged.

## Source and architecture

Primary editable source: `casino-godot/`. Generated web export: `casino/`.
Do not inspect or manually modify generated artifacts such as `casino/game.js`, `casino/game.wasm`, or `casino/game.pck` unless the task specifically concerns export/runtime behavior. Do not spend context reading generated artifacts.

Paths below are relative to `casino-godot/scripts/`:

| File | Responsibility |
| --- | --- |
| `simulation.gd` | Treasury, guests, staff, tables, service, economy, progression, incidents, and simulation state. |
| `tuning.gd` | Centralized balance/economy constants; prefer tunable values here over scattered magic numbers. |
| `casino_games.gd` | Slots, roulette, blackjack, and Ultimate Texas Hold'em rules. |
| `craps.gd` | Craps rules and settlement; keep core resolution deterministic where practical. |
| `main.gd` | UI/controller; keep core simulation/business rules out of it. |
| `floor.gd` | Floor rendering, navigation, movement, and placement. |
| `floor_property.gd` | Shared chunk geometry, directional purchase quotes, property upkeep, build/walk bounds and property validation. |
| `game_view.gd` | Casino-game presentation. |
| `game_art.gd` | Game visual presentation/art helpers. |

## Context and documentation

Start with files explicitly named in the request, relevant files from the architecture map, and direct dependencies. Expand only as needed. Do not scan the entire repository or repeatedly read unrelated documentation.

Read these documents in `casino-godot/` only when relevant:

- `BALANCING.md`: economy, prices, wages, game minimums, guest bankrolls, and progression pacing.
- `ARCHITECTURE.md`: major subsystem changes, persistence architecture, and significant refactoring.
- `ROADMAP.md`: major gameplay systems, progression direction, and product scope.
- `STEAM.md`: Steam, packaging, release, and Steam integration only.

## Testing

The developer performs most testing manually during rapid pre-alpha development. Unless explicitly requested, do not write tests, expand coverage, inspect the entire test suite, run broad suites, investigate test infrastructure, or perform extensive automated verification. For normal feature tasks, do not run or write tests unless requested. Implement cleanly and provide concise manual verification steps; tests can be requested separately.

## Saves and persistence

Development saves are disposable. Do not maintain backward compatibility: no migrations, legacy schema branches, obsolete field aliases, compatibility adapters, historical-format investigations, or historical migration tests. Change schemas cleanly; old development saves may break. Prefer a clean implementation over complexity preserving old saves. Compatibility becomes required only when the developer explicitly declares a future baseline.

Keep current-version save/load working when practical. While working in relevant persistence code, safely remove clearly obsolete compatibility helpers, branches, conversions, and fields maintained solely for historical saves. Do not search the repository for legacy cleanup. Preserve defensive handling for corrupt files, invalid data, missing current-version values, and runtime errors.

## Economy and game design

Unlocked drink products are options, not automatic menu entries. Players explicitly add/drop products; bar menu and pricing decisions must have observable guest demand and margin consequences.

Financial visual feedback must represent real simulation transactions and actual casino financial changes; never display fake profit for excitement. Keep casino treasury, guest bankroll, and owner/visitor gambling wallet distinct. Prevent owner-wallet exploits that manufacture casino money.

Normal difficulty starts with a small slot operation and progresses toward table games, service, VIPs, and larger casino systems. Avoid giving everything immediately. Easy offers more freedom to start with preferred casino games without the full Normal progression grind. Progression should provide anticipation, meaningful purchases, financial tradeoffs, visible growth, and increasing operational complexity.

## Economy validation

Balance around long-run expected operating performance, with losses possible from variance, overstaffing, poor utilization and excessive overhead. Distinguish recurring expenses from capital investment and onboarding when diagnosing profitability. Do not use higher house edge as the default fix for unrelated cost or throughput problems. Development acceleration must preserve game-time economics; never tune production balance around extreme-speed artifacts.

## UI text / character safety

- Prefer ASCII-safe UI text; use non-ASCII only when intentionally required and confirmed to render in the current Godot fonts and web export.
- Avoid decorative Unicode, emoji, uncommon bullets, separators and icon-like glyphs without rendering confirmation. Prefer `|`, `-`, `/`, `+` and `>`.
- Treat replacement characters, boxes, mojibake and corrupted glyphs as bugs; clean up obvious instances in nearby UI text being modified.
- Do not change the project font system to fix a decorative character unless explicitly requested.
- Keep source files correctly UTF-8 encoded, including when visible UI text is ASCII-safe.

## Player-facing UI

Prioritize hierarchy, clarity, contextual information and progressive disclosure. Persistent UI answers immediate management questions; detailed asset statistics belong in inspectors and deeper financial analysis in Finance. Use readable components instead of raw counters or pipe-separated telemetry. Routine floating results show only the signed net house amount (for example `+$25`), without redundant HOUSE/game prefixes. Keep meaningful operational events in House Activity. Preserve simulation depth without placing every new system's internal state on the main screen.

## Progressive disclosure / system relevance

Use Summary -> Expand -> Detail -> Action. Reveal management detail when its system is operational or relevant; avoid inactive-system accounting and irrelevant zero rows in default views. Early casinos should have simpler screens than mature properties. Keep Finance and inspectors compact, with internal reconciliation and diagnostics behind advanced/detail views. Information should support decisions rather than form a scrolling report.

## Responsive / mobile UI

Keep desktop, mobile landscape and mobile portrait usable. Reflow by viewport width, height and orientation; do not uniformly shrink the desktop UI. Give the floor the largest practical mobile area, and move details into contextual inspectors, tabs or full-screen management views rather than shrinking typography. Prefer viewport/aspect breakpoints over device detection, share gameplay logic, and consider all three layouts when adding UI.

Any mode requiring direct floor targeting on mobile must automatically prioritize the floor and contextual controls. Full-screen inspectors and management panes must not obscure the target surface. Enforce interaction visibility invariants centrally on refresh and resize; route explicit pane navigation through the shared transition helper rather than adding per-button pane fixes. Orientation changes must preserve interaction and selection state.

Financial values and other short high-value metrics must remain atomic and readable in responsive layouts. Never allow currency to wrap character-by-character. When a label and value cannot fit horizontally, reflow vertically instead of crushing the value column.

## House Activity vs money feedback

Routine individual gambling settlements belong in floating/toast money feedback, not House Activity. House Activity is a filtered management feed for cage cash-outs, major wins/losses, unlocks, rating changes, VIP events, breakdowns, staffing/service issues, reserve warnings and other important operational events. Do not turn it into a transaction ledger. Preserve detailed internal financial events for analytics even when the feed hides them.

## Guest thoughts / floor communication

Guest-facing demand must respect progression and current casino context. NPCs may have latent preferences for future content, but should not normally complain about or explicitly request systems the player cannot meaningfully provide yet. Reveal demand progressively as systems become relevant. Player-facing complaints should be understandable and actionable.

Communicate actionable demand, preferences, service needs, satisfaction, frustration and reasons for behavior through concise, temporary world-space bubbles. Rate-limit repeats and keep thoughts visually distinct from financial feedback. Walking offers qualitative insight while management remains usable independently. Hot-table attention must arise from real activity and never change probabilities or fabricate outcomes.

## Living guest behavior

Visits may include gambling, browsing, waiting, watching, switching games and seeking service before departure. Finishing a session should offer another decision, not automatically end the visit. Departure should reflect bankroll, satisfaction, entertainment, patience and stay tendency rather than a single age cutoff. Reconsider periodically without constant bouncing. Let retention and turnover produce population organically; never force a target headcount. Keep aggregate arrival and capacity pressure separate from individual guest decisions.

## Staffing

Staff fatigue should create staffing-capacity decisions rather than repetitive micromanagement. Employees may be Active, Relief, on Break or Off Duty. Adequate relief staffing should automatically rotate tired workers while preserving table coverage. Closing the casino must not function as a short-term universal energy recharge exploit. Staffing depth trades higher payroll for operational continuity.

## Developer testing tools

Prefer development-only state controls when progression makes repeated manual testing cumbersome; do not weaken Normal progression, temporarily rebalance production, or use extreme simulation speeds as a substitute for progression controls. Debug-only extreme speeds may be provided for stress and long-duration checks.

- Use real gameplay systems where practical and avoid duplicating major gameplay logic.
- Keep tools separate from normal progression and unavailable in production release builds.
- Extend the panel only for an actual testing need; consider a small control when adding progression-heavy features.
- Keep developer actions visibly marked and distinguish prerequisite preparation from forced access.
- Build release `casino/` and local debug `casino-debug/` from the same `casino-godot/` source. Guard tools with `OS.is_debug_build()`; use `export_web.py --both` when both exports are needed.

## Code and workflow

Prefer clear system ownership, small focused functions, signals/events between simulation and presentation when appropriate, centralized tuning, data-driven progression where practical, and reusable systems. Avoid giant conditional chains, UI-owned simulation rules, duplicated economy logic, scattered magic numbers, compatibility spaghetti, and premature abstraction for hypothetical systems.

Read the task, inspect relevant source, implement the smallest clean solution, avoid unrelated scope, and provide concise manual verification steps. Briefly plan complex architectural changes before editing. Related cleanup can remove dead code or obsolete compatibility branches, consolidate duplication, rename misleading fields, or move tuning into `tuning.gd`.

After each V0.3 update step, rebuild the playable web export with `casino-godot/export_web.py` so the developer can manually test it. Use the installed Godot binary with matching export templates; resolve any build errors before reporting completion. This does not authorize automated tests.

Keep completion summaries brief: what changed, important design decisions, files changed, and what the developer should manually verify. Avoid large implementation essays or restating the task; stop when the requested work is complete.

## BUILD / EXPORT REQUIREMENT

After completing the requested source changes, produce the current playable build using the repository’s existing Godot build/export workflow.
Do not manually edit generated files in casino/.
Source changes belong in casino-godot/; generated web output should only change as a result of the normal export/build process.
If the environment cannot perform the export, explicitly say so in the final response and provide the exact build/export command or action the developer must run.
Do not report the phase as ready for manual gameplay verification without stating whether the playable build was successfully regenerated.
Final report must include:
- Source changes completed
- Build/export: SUCCESS / NOT RUN / FAILED
- Generated playable build updated: YES / NO
- Manual gameplay checks

## Performance architecture

- Floor rendering must use presentation indexes rather than repeatedly filtering guests/staff per asset. Keep caches read-only and invalidate them on relevant state changes.
- Retain UI nodes for value updates; change structure when content changes and run responsive layout on viewport or pane transitions.
- Frequent diagnostics must remain lightweight; full simulation serialization belongs on a slower cadence or explicit testing request.
- Performance changes must preserve simulation timing, accounting and RNG call order. Batch visual feedback independently of economic settlement and guest decisions.
