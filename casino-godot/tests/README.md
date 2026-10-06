# V0.3 regression

Use the current Godot binary and project source. `run_tests.gd` is the entry point;
obsolete starter-craps and legacy-save-migration assumptions have been removed.
The wrapper fails on runtime/script errors as well as assertions and timeouts.

```sh
python3 casino-godot/tests/run_regression.py --godot /home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64
```

`--quick` skips the six seeded 48-game-hour simulation runs. The full suite covers
Normal/Easy starts, idle/cheap-spam progression gates, all five games, exact slot
and roulette expectations, craps contracts/shooters, visitor and guest money
conservation, duplicate settlements, asset analytics, paid/comped drinks, real
cage departures, traffic pressure, current JSON saves and atomic invalid loads,
construction/repair/navigation, milestones, 1x/4x and bounded debug acceleration,
all game views, and Finance summary/detail layouts at 1440x900, 800x900, 844x390,
390x844 and 320x568. Presentation fixtures are confined to tests. Tests use memory
snapshots, not the developer's game save file. Reports/logs go to `/tmp`.

Browser smoke checks use Playwright/Chromium and the normal web exports:

```sh
python3 -m venv /tmp/neon-regression-venv
/tmp/neon-regression-venv/bin/pip install playwright
/tmp/neon-regression-venv/bin/playwright install chromium
python3 -m http.server 8093 --bind 127.0.0.1
```

From another terminal at the repository root:

```sh
/tmp/neon-regression-venv/bin/python casino-godot/tests/web_regression.py
/tmp/neon-regression-venv/bin/python casino-godot/tests/web_speed_check.py
```

The browser checks retain screenshots and JSON reports in `/tmp`, use a fresh
browser context (no existing saves), and fail on checked assertions or runtime
errors. The speed smoke locates debug speed buttons through the UI bridge. It checks continued activity,
not achievement of the requested multiplier. Release F10 behavior and screenshot
readability also require reviewing the retained screenshots. Software rendering
in CI/codespaces is not a hardware performance benchmark.

These checks do not establish first-hour fun, strategy dominance, every poker
branch, rare-tail safety, audio/touch feel, or compatibility across browsers and
real mobile devices. Development saves deliberately have no migration contract.

## 0.4.2 performance

See [PERFORMANCE_042_REPORT.md](PERFORMANCE_042_REPORT.md) for the measured baseline,
limits, fixture exporter and 30-minute release-soak commands.

`performance_checks.gd` covers deterministic feedback cadence and retained UI.
`performance_idle.gd` checks paused redraw frequency. `performance_profile.gd` and
`performance_profile_games.gd` measure scoped CPU work; `performance_feedback_rate.gd`
counts actual visible feedback creations. `performance_equivalence.gd` emits seeded
full state/RNG transcripts for comparison with a baseline checkout.

`performance_browser.mjs` supports `PERF_SCENARIOS` (JSON pairs of scenario/speed),
`PERF_WIDTH` / `PERF_HEIGHT`, `PERF_TRACE=1` (Chromium CPU profile), and `PERF_REPORT`.
The fixture export is isolated in `/tmp`, including for release; production does
not expose test state hooks. Browser smoke uses the current starter game and
checks desktop/mobile move/build/cancel, orientation, walk/manage and navigation.
Full-state debug polling is explicitly enabled by browser tests.

## Owner bankroll / optional events foundation

The current `run_tests.gd` entry point also checks initialization, previous
version-16 wallet defaults, current JSON round trips, pending/settled operation
IDs, invalid money, duplicate debit/settlement/rewards, normal-game conservation,
net-only event profit, optional ignore/expiry neutrality, asynchronous engagement,
explicit sample consequences, cooldowns and overdue-load deferral. UI checks at
desktop, landscape, portrait and 320px verify event cards remain in the activity
pane, touch controls and personal currency stays on one line. Headless layout
checks do not replace real touch/browser gameplay verification.

## Focused owner/floor event smoke checks (0.4.2.3 / 0.4.2.4)

Run only the new event/game checks, without the broad regression or long runs:

```sh
/home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path casino-godot --script tests/owner_events_smoke.gd
```

This uses actual seeded rules for losses/pushes/wins, blackjack extra stakes,
committed slots/cards across load/exit, duplicate guards, unavailable storage and
checkpoint rollback. Floor checks cover actual eligibility, repair/comp costs,
staff/bar context, guests watching real play and already settled guest payouts.
The UI smoke uses `/tmp` saves and desktop/landscape/portrait/320px viewports.
Use `tests/startup_smoke.py` for normal startup, and `export_web.py --both` for
source parsing and playable release/debug output. Browser/touch feel still needs
manual gameplay checks; no new broad regression run is required for this step.

## Casino Momentum (0.4.2.5)

```sh
/home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path casino-godot --script tests/momentum_smoke.gd
```

Focused checks cover gradual idle/active behavior, real operating conditions,
all bands, bounded effects, neutral ignored/expired Opportunities, real seeded
owner wins/losses, repairs, duplicate guards, persisted cooldowns, additive save
defaults, atomic invalid loads and closed-session freezing. Desktop, landscape,
portrait and 320px checks cover retained controls and touch-accessible details.
Core momentum checks also run through the existing regression entry point.

## Dynamic optional objectives (0.4.2.6)

```sh
/home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64 --headless --path casino-godot --script tests/objectives_smoke.gd
```

Covers achievable context/scaling, opt-in progress, actual net settlements,
happy departures, paid deliveries, seeded owner wins, sustained operation,
neutral ignore/expiry, close-toggle guards, small active limits, JSON progress,
atomic invalid loads, duplicate rewards, committed-stake caps, partial budgets,
checkpoint rollback/retry and retained desktop/mobile Log controls. Core checks
also run through the normal regression entry point. Browser save/load checks
pause while sampling saved state so telemetry timing cannot masquerade as a
failed load, then advance past it before verifying restoration.
