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
