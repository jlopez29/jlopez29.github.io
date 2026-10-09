# Smoke first

Default startup check (Godot on PATH, or pass `--godot /path/to/godot`):

```sh
python3 casino-godot/tests/startup_smoke.py
```

For the physical Back Room only, a bounded entry/play/exit, accounting and save smoke:
`godot --headless --path casino-godot --script tests/back_room_smoke.gd`.
No Monte Carlo, browser matrix, captures or soak work is part of the default workflow.

Full regression is available **only on explicit request**:

```sh
python3 casino-godot/tests/run_regression.py
```

Keep `run_tests.gd` and `run_v03_tests.gd`: service/events/momentum/objectives inherit
these bases. Other focused game, placement, service and marker checks are opt-in.
Historical reports live in `docs/archive/`; they do not certify the current build.

For directional floor purchases, the focused expansion regression is:
`godot --headless --path casino-godot --script tests/property_expansion_smoke.gd`.
It checks populated side wings, unchanged furniture/frontage, navigation, save/load,
non-destructive failures, actual purchase UI feedback, and desktop/mobile camera
framing and gestures. Reproduction and recorded runtime results are in
[`docs/side_expansion_fix.md`](../docs/side_expansion_fix.md).
