# Next bug-fix session

Two focused source fixes completed; no automated tests were run at the user's request:
- simulation.gd / deliver_drink: incomplete service assignments are rejected safely,
  retaining guest/worker matching. Missing service_target no longer throws.
- simulation.gd / private_transaction and owner_play_transaction: failed actions/save
  checkpoints preserve recovery's monotonic session clock. Rollback does not count a
  changed device wall clock as offline elapsed time.

Manual checks now: order paid and comped drinks with assigned service workers;
check guest wallet, Casino Cash and Finance. Complete/reject Back Room actions and
confirm recovery countdown does not jump or reset. Save/load a pending hand normally.

Start here next time, one issue at a time:
1. SAVE/LOAD (highest priority): inspect simulation.restore's intentional normalization,
   reroute and progression refresh, and optional_events.restore's overdue scheduling.
   Determine which fields change after a real save/load, and whether casino/game RNG
   continuation actually changes. Existing failures are in run_v03_tests.gd /
   hospitality_and_departure, snapshot round-trip and seeded continuation. Recovery's
   real-time timestamp makes whole-snapshot string equality unsuitable by itself.
2. DRINK FIXTURES: run_tests.gd / objective_checks and run_v03_tests.gd /
   hospitality_and_departure supply a synthetic worker without service_target and
   manually insert drink orders without the current request/assignment lifecycle.
   Update fixtures to use real orders and assignments; do not permit unassigned
   production deliveries merely to satisfy these old expectations. Guard accesses
   to active[0] when an objective wasn't offered. Recheck four service/ledger assertions.
3. EVENT FIXTURES: run_tests.gd / optional_framework calls tick while automatic
   manufacturer_demo scheduling is eligible. Separate the sample-event expiration /
   priority checks from unrelated automatic offers before assuming a gameplay bug.
   Recheck expiration, queue ordering and reload behavior against actual event IDs.
4. STALE ASSERTIONS: run_tests.gd / owner_foundation must expect missing wallet data
   to be rejected, preserving the current account (never manufacture a default $1000).
   ui_checks searches for 'Spin' in game_view.actions, while the current dedicated
   control is game_view.slot_spin with 'SPIN'. Update these five assertions only.

Last observed merged-master quick suite: 2056 checks / 14 failures. Do not claim
those failures are cleared by these source fixes; tests were intentionally not rerun.
The drink crash is guarded, but stale fixtures still need proper assignments.
