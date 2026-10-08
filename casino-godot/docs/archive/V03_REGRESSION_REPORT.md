# V0.3 regression - 2026-10-06 UTC

Final current-source run: **250,411 assertions, 0 failures, no Godot runtime/script
errors**. Six seeded 48-hour runs completed. Expanded focused rerun: 1,660
assertions, 0 failures. Rebuilt browser smoke: 15 checks, 0 failures, no console
or page errors. Both extreme-speed smoke cases continued advancing.

Build/export: **SUCCESS** for release and debug. Generated playable builds:
**updated**. Source fixes and regression tools are local; no commit/push was made.

Two production defects found and fixed:

- A cage countdown could become negative while a guest was leaving. The current
  save validator correctly rejected that value, making some legitimate saves
  unloadable. The countdown is now clamped at zero; no migration was added.
- A game surface could draw its default slot cabinet before GameView assigned
  the machine profile. Drawing now waits for a configured profile.

The established test entry point now uses current V0.3 setup and save contracts.
Legacy starter-craps/migration assumptions were removed; applicable craps rules
and shooter coverage were retained. The wrapper treats Godot runtime errors,
missing completion summaries, nonzero failure counts and timeouts as failures.

Coverage: all games and real net financial events, exact profile expectations,
visitor/guest money conservation, duplicate settlement, asset finance, paid and
comped drinks, cage/direct departure, capacity and reputation pressure, milestones,
construction/repair/navigation, current saves and corrupt-load rejection,
accomplishment-based progression, 1x/4x and bounded development acceleration,
all game views, and every Finance summary/detail section at five viewport sizes.

Browser smoke: desktop management navigation and browser save/load pass. Debug
Finance screenshots reviewed at 1440x900, 800x900, 844x390, 390x844 and 320x568.
Amounts stayed atomic; the narrow reserve header reflowed vertically. Release
started successfully, exposed no debug telemetry, and F10 showed no developer
panel. No browser console/runtime errors were recorded.

Extreme-speed smoke: 100x and 1000x continued advancing, settling real games and
showing guests in six successive samples each, without a freeze. Both were much
slower than their requested multipliers under concurrent load/software-rendered
Chromium. These are best-effort controls, not validated 100x/1000x throughput.

Bounds: six seeded runs cover 48 game hours each (288 combined hours), not all
possible random outcomes or player strategies. Normal runs keep the two starter
slots; Easy runs use all five games. The runs do not purchase later tiers or
establish first-hour fun/strategy dominance. Repairs are checked separately;
the 48-hour runs precede the earliest repair grace. Real mobile touch, audio,
Safari/Firefox, hardware FPS and rare payout tails still need manual validation.
No balance changes, fake financial activity, or probability changes were made.

Reproduction commands are in [README.md](README.md). Detailed run logs, browser
JSON results and screenshots are retained in `/tmp/v03-*` in this workspace.
Both release `casino/` and debug `casino-debug/` were rebuilt from the same source.

| Mode | Seed | Hours | Peak guests | Settled guest handle | Operating P/L | Payroll |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Normal | 101 | 48 | 3 | $10,085 | +$39 | $0 |
| Normal | 202 | 48 | 3 | $9,560 | +$559 | $0 |
| Normal | 303 | 48 | 3 | $10,135 | +$204 | $0 |
| Easy, five games | 101 | 48 | 35 | $617,735 | +$39,150.50 | $4,800 |
| Easy, five games | 202 | 48 | 36 | $638,180 | +$29,278 | $4,800 |
| Easy, five games | 303 | 48 | 35 | $681,255 | +$40,938 | $4,800 |

These are fixed-policy diagnostic samples, not profitability guarantees or a
comparison of optimized strategies. No service staff or reinvestment policy was
used in these six runs; hospitality and construction were checked separately.
