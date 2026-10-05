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

## House Activity vs money feedback

Routine individual gambling settlements belong in floating/toast money feedback, not House Activity. House Activity is a filtered management feed for cage cash-outs, major wins/losses, unlocks, rating changes, VIP events, breakdowns, staffing/service issues, reserve warnings and other important operational events. Do not turn it into a transaction ledger. Preserve detailed internal financial events for analytics even when the feed hides them.

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