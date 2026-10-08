# Physical Back Room correction

Public and private play share `scripts/game_view.gd`, `scripts/casino_surface.gd`,
`scripts/roulette_layout.gd`, `scripts/craps_layout.gd` and
`presentation/play/craps_surface.gd`. `scripts/game_context.gd` changes only the
state/actions/constraints provider. Slots inherit `slot_presentation.gd`,
`slot_presentation_state.gd` and `slot_audio.gd` through the same surface; an animation
change there automatically appears in both rooms. Rules remain CasinoGames/Craps.
Private actions keep BackRoomSession RNG and existing atomic escrow checkpoints.

The shared CasinoFloorV2 scene/components and floor movement read
`floor_context.gd`. Its private fixtures/decorative dealer index never enters
public tables, staff, guest capacity, payroll or maintenance. `back_room_floor.gd`
opens interactions only after walking. Public doorway geometry comes from
`floor_property.gd`; occupied older doorways retain assets and ask for relocation.
Physical location is optional in existing 0.4.2.6 saves; money/wagers are preserved.

Cleanup:

- KEPT: `run_regression.py`, `run_tests.gd`, `run_v03_tests.gd`, startup guards,
  focused game/placement/service/marker/event/objective checks and their bases.
- REPLACED: `back_room_smoke.gd` with a bounded physical/accounting/save smoke;
  `back_room_view.gd` with the shared world and recovery-only `recovery_view.gd`.
  Updated context bindings in `slots_overhaul.gd`, `slot_juice_checks.gd`,
  `objectives_smoke.gd`; refreshed `tests/README.md`.
- REMOVED: old top plaque/`back_room_clicked`, Menu ID 5, Overview Back Room button,
  lobby/form handlers, `back_room_view.gd` + UID, `back_room_capture.gd` + UID,
  `back_room_browser.cjs`, `slot_juice_capture.gd` + UID, `BACK_ROOM_REPORT.md`.
- REMOVED: `export_performance.py`, `performance_browser.mjs`,
  `performance_checks.gd`, `performance_idle.gd`, `performance_equivalence.gd`,
  `performance_feedback_rate.gd`, `performance_fixture.gd`, `performance_profile.gd`,
  `performance_profile_games.gd`, `performance_web.gd`, `performance_process_memory.py`,
  `performance_soak_check.py`, deleted scripts' UIDs and `performance_results/`.
- ARCHIVED: `PERFORMANCE_042_REPORT.md`, `V03_REGRESSION_REPORT.md`,
  `SLOTS_OVERHAUL_REPORT.md`, `SLOT_JUICE_REPORT.md`, `BAR_SERVICE_REPORT.md`.
  These are historical records, not current build verification.

Commands (Godot on PATH, or supply `--godot /path/to/godot`):

```sh
python3 casino-godot/tests/startup_smoke.py
# Optional full regression, only when explicitly requested:
python3 casino-godot/tests/run_regression.py
```
