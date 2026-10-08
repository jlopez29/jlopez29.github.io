# Purchased bar and service roster validation

Source changes completed against the latest `origin/master` (7906c7c).

## Gameplay

Before: earning service access activated the counter, drink access and thirst;
Service ownership was inferred from employees. The default Service relief target
was zero, so additional immediate hires waited Off Duty.

After: Rating 20 (with the existing Blackjack access prerequisite) unlocks a
purchase opportunity. Normal and Easy both start without a bar. A deliberate
$1,000 Casino Cash purchase records construction expense, creates the visible,
interactable counter, grants basic product access and enables House Soda and
Sparkling Water. It hires nobody and leaves Owner Bankroll untouched. Later
product unlocks remain optional menu choices.

Before ownership, thirst does not accumulate and missing drink service produces
no satisfaction loss, service complaints or service-related reputation loss.
After purchase, existing thirst, dissatisfaction and departure consequences apply.
Service hiring requires ownership. Three hires without advancing time produce
one Active, one Relief and one unpaid Off Duty employee. Existing automatic
break/shift rotation remains responsible for subsequent coverage.

Build exposes the bar through Amenities on desktop and the Bar tab on mobile.
Purchase review explains onboarding/payroll costs. Staffing shows all duty counts,
required positions, relief target, continuous recommendation and coverage warnings
without opening employee details. Mobile landscape tabs reserve readable widths.

## Constants and saves

- Added `BAR_PURCHASE_COST = 1000.0`.
- Changed default Service relief target from 0 to 1.
- Rating milestone remains 20; hiring remains $150 and Service wages $16/hour.
- Continuous roster uses the existing 480-minute shift / 360-minute rest formula:
  one Active plus one Relief recommends **four** total employees.
- `SAVE_VERSION` increases from 16 to 17. Snapshots explicitly store `bar_owned`.
  Invalid ownership/state combinations are rejected atomically. Per the updated
  instruction, there is no old-save migration. Load deletes invalid/incompatible
  development save files; current valid saves round-trip normally.

## Validation

| Check | Result |
| --- | --- |
| Full `run_tests.gd`, including six seeded 48-game-hour runs | 179,573 checks, 0 failures |
| Full standalone `run_v03_tests.gd` | 179,284 checks, 0 failures |
| New `bar_service_smoke.gd` | 100 checks, 0 failures |
| `startup_smoke.py` | Passed |
| `performance_checks.gd` | 98 checks, 0 failures |
| `performance_idle.gd` | Passed; 3 redraws / 180 idle frames |
| `test_floor_asset_presentation.gd` | 113 passed, 0 failed |
| `expansion_smoke.gd` | Passed |
| `git diff --check` | Passed |

New regression checks cover access without purchase, intentional understaffing
consequences, single capital debit, starter menu, hiring gate, immediate closed
roster planning, fatigue relief, recovered relief, next-shift takeover, unpaid
Off Duty employees, Easy access, valid/invalid saves, floor visibility, purchase
button availability and responsive management at 1440x900, 844x390, 390x844 and
320x568. The focused checks also run through both full regression entry points.

Existing service fixtures now explicitly purchase a bar. Stale presentation
fixtures were updated to verify the current scene, navigation, real action buttons
and visible floor Walk control. The performance comparison copies complete initial
state, including optional-event RNG, before checking exact state/RNG equality.
No existing assertions were removed to bypass failures.

Godot: installed 4.7.2 with matching export templates. Build command:

```sh
python3 casino-godot/export_web.py --both --godot /home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64
```

Build/export: **SUCCESS**. Generated playable build updated: **YES**.
Both release `casino/` and local debug `casino-debug/` were regenerated.
Final logs are in `/tmp/bar-regression-complete.log`, `/tmp/bar-v03-complete.log`,
`/tmp/bar-smoke.log`, `/tmp/bar-performance.log` and `/tmp/bar-export-ready.log`.

## Files changed

Paths below are relative to `casino-godot/` unless otherwise stated.

- Gameplay: `scripts/simulation.gd`, `scripts/tuning.gd`, `scripts/staffing.gd`,
  `scripts/drink_economy.gd`, `scripts/main.gd`, `scripts/floor.gd`.
- Presentation: `presentation/casino_floor_v2.gd`,
  `presentation/mobile_management.gd`, `presentation/pit_boss_shell.gd`.
- Tests: `tests/run_tests.gd`, `tests/run_v03_tests.gd`,
  `tests/bar_service_smoke.gd` and its `.uid`, `tests/performance_checks.gd`,
  `tests/performance_fixture.gd`, `tests/startup_smoke.gd`,
  `tests/expansion_smoke.gd`, `tests/test_floor_asset_presentation.gd`.
- Documentation: `BALANCING.md`, `tests/README.md`, this report.
- Export-generated tracked files: `scripts/build_info.gd`, repository-root
  `casino/game.html`, `casino/game.pck`. Local debug outputs are ignored by Git.

## Manual gameplay checks / remaining follow-up

1. Earn Normal bar access and delay buying: no counter or drink complaints should
   appear. In Easy, purchase should be available immediately without free ownership.
2. Buy through Build, confirm the $1,000 treasury debit and two starter products;
   click the counter to manage drinks. Leave it unstaffed to observe real consequences.
3. Pause/close, hire three Service employees and inspect Active/Relief/Off Duty.
   Open and watch breaks/shift handovers; add a fourth for the recommended depth.
4. Check purchase/menu/staff views with real mobile touch and orientation changes,
   then save/load an owned bar. Old development saves should be deleted on Load.

No known implementation blockers remain. Real touch interaction and long-term
capital/payroll decisions still need the developer's manual gameplay review.
