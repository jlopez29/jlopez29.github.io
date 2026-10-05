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

## Code and workflow

Prefer clear system ownership, small focused functions, signals/events between simulation and presentation when appropriate, centralized tuning, data-driven progression where practical, and reusable systems. Avoid giant conditional chains, UI-owned simulation rules, duplicated economy logic, scattered magic numbers, compatibility spaghetti, and premature abstraction for hypothetical systems.

Read the task, inspect relevant source, implement the smallest clean solution, avoid unrelated scope, and provide concise manual verification steps. Briefly plan complex architectural changes before editing. Related cleanup can remove dead code or obsolete compatibility branches, consolidate duplication, rename misleading fields, or move tuning into `tuning.gd`.

Keep completion summaries brief: what changed, important design decisions, files changed, and what the developer should manually verify. Avoid large implementation essays or restating the task; stop when the requested work is complete.
