# Back Room delivery

Baseline: `origin/master`, fetched SHA `cdae1894cfecdae8ed3ca5aca488b04879cb2adc`.
Feature branch: `feature/back-room-recovery`. Changes are local and uncommitted;
no pull request or remote publication was made.

Source implementation is complete. Release `casino/` and debug `casino-debug/`
were regenerated successfully with Godot 4.7.2 and matching templates on
October 7, 2026 at 7:48 PM EDT. The maximized public slot presentation remains
shared and unchanged; the private view reuses its art, animations and audio.

## Source files

Added `scripts/back_room_session.gd`, `back_room_view.gd`, `recovery_system.gd`,
`recovery_scratch_card.gd`, `recovery_ticket.gd`, `recovery_clues.gd` and Godot UIDs.
Updated simulation persistence/transaction routing, main navigation/checkpoints,
floor entry/movement visibility, presentation shell, centralized tuning and the
shared blackjack insurance rounding hook. Updated ARCHITECTURE.md and BALANCING.md.
Added focused headless, browser and rendered-capture scripts in tests/.
Build metadata and generated release output changed through export_web.py only.

## Accounting and recovery

For committed stake S and total return R, personal escrow returns min(S,R) and
Casino Cash receives max(0,R-S). Tested examples from a $1,000 personal wallet:

| Stake / return | Final personal wallet | Casino Cash change |
| --- | --- | --- |
| $250 / $0 | $750 | $0 |
| $250 / $250 | $1,000 | $0 |
| $250 / $750 | $1,000 | +$500 |
| $1,000 / $3,000 | $1,000 | +$2,000 |

Roulette settles its combined portfolio; craps preserves separate live contracts,
including standing principal. All five games use existing authoritative rules.
Private monetary boundaries round to cents, nearest with ties up. Slots divide the
total equally across 1/3/5 lines and round the combined return once. Blackjack
insurance stakes round to a cent; additional split/double/insurance stakes are funded.
Hold'em requires full 6x ante + Trips availability before dealing.

The $1,000 recovery target grants only the current gap. Early/Mid/Late offers use
30/45/60 real minutes, respectively. Early requires rating below 16 and fewer than
six full recoveries; Late starts at 55. Offers retain their initial duration.
Three distinct contracts unlock work recovery after ten real minutes; incorrect
attempts impose a persisted thirty-second retry cooldown. Cycle advancement occurs
only on a full top-up, including chance claims that fill the gap. Escrow blocks grants.

Contracts use twelve variants in each of four categories with three tiers: correct
receipt and signed cage discrepancy; provable dispatch/receipt discrepancy plus
reason; controller diagnosis plus a three-switch XOR circuit; actual staffing
coverage/budget/aisle constraints in a virtual training scenario. No owned assets,
random wins, idle milestones or game-speed passage complete them.

Early effort earns one scratch after the first verified contract and one raffle
after the second. Outcomes are committed from a separate persisted recovery RNG.
Raffle draws after ten real minutes. Already issued tickets have no expiration and
survive full refills and stage changes; no new tickets issue in Mid/Late.

| Award ceiling | Scratch odds | Raffle odds |
| --- | --- | --- |
| $0 | 50% | 65% |
| $100 | 25% | 22% |
| $250 | 15% | 10% |
| $500 | 8% | 0% |
| $1,000 | 2% | 3% |

Uncapped expected values are $122.50 and $77.00 per issued ticket. Actual awards
are gap-capped and never enter casino revenue. Maximum face value per issued pair
is $2,000; lifetime Early issuance is bounded to six pairs ($12,000 maximum deferred
face value), which cannot become an endless promotional subsidy. Work/time recovery
continues. Seeded 100,000-trial means were $122.942 and $76.899.

Schema 20 deliberately rejects old development saves. Private game sequences,
escrow, recovery cycles, contract outcomes, tickets and both RNG streams persist.
Failed verified checkpoints roll back private action/account/cash state. No historical
migration was added. Monotonic time drives open sessions; reasonable wall-clock
elapsed time counts offline, with backward/invalid readings guarded. Client device
time, edited saves and browser filesystem persistence are not trusted backend or
cross-device guarantees.

## Verification

Commands below use the installed binary path in place of `godot`:
`/home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64`.

- `godot --headless --path casino-godot --script res://tests/back_room_smoke.gd`:
  PASS, 542 checks, including cent precision, all four settlement examples, game
  funding, persisted state, rollback, stage/cycle bounds, puzzle solutions/rejections,
  promotions and desktop/portrait/landscape/320px UI surfaces.
- `godot --headless --path casino-godot --script res://tests/owner_events_smoke.gd`:
  PASS, 129 checks.
- `godot --headless --path casino-godot --script res://tests/slots_overhaul.gd`:
  PASS, 154 checks; exact starter RTP 91.35% for 1/3/5 lines.
- `godot --headless --path casino-godot --script res://tests/slot_juice_checks.gd`:
  PASS, 75 checks.
- `python3 casino-godot/tests/run_regression.py --godot <binary>`:
  FAIL, 182,234 checks / 13 failures. The same thirteen failures were reproduced
  on the untouched fetched baseline with its quick suite (2,056 checks), including
  stale drink-service fixtures, optional-event assertions, snapshot continuation and
  old slot-button expectations. The failure lists match exactly. No unrelated fixes
  were made. Logs: `/tmp/v03-regression.log`, `/tmp/back-room-baseline-regression.log`.
- `PLAYWRIGHT_MODULE=/home/codespace/.cache/neon-house-tools/node_modules/playwright
  node casino-godot/tests/back_room_browser.cjs`: PASS at 1440x900, 390x844 and
  844x390, entering through the floor plaque, playing a real slot spin, opening
  recovery and returning to Floor, with no detected browser/script errors.
- `xvfb-run -a godot --audio-driver Dummy --path casino-godot --script
  res://tests/back_room_capture.gd`: completed twelve rendered fixtures. Lobby,
  slots, puzzle and scratch/raffle views at all three sizes are in
  `/tmp/back-room-captures/`; real browser images are `/tmp/back-room-browser-*.png`.
- `python3 casino-godot/export_web.py --both --godot <binary>`: SUCCESS.
  Generated playable build updated: YES.

The browser checks preceded final persistence-validation tightening; the final
headless feature checks and exports include that tightening. Visual captures were
reviewed; physical mobile touch feel and audible playback were not manually verified.

## Manual gameplay checks

Start fresh Normal; enter Back Room via the plaque or navigation fallback. Try each
of five games, custom cents, $1,000 slots, roulette refund/mixed bets, blackjack
additional funding, Hold'em funding and multi-throw craps. Return to Floor and resume
an unresolved hand, then save/reload it. Keep the public casino open to observe guest
operation continuing. Lose wallet funds, complete and deliberately fail a contract,
earn/reveal scratch and raffle, and claim only the missing refill amount. Check the
same flows on portrait and landscape, including orientation changes, slot audio and
scratch dragging. Timer/offline readiness should use real time, never simulation speed.
