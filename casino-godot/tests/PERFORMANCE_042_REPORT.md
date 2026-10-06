# Neon House 0.4.2 performance and stability

## Scope and measurement limits

Measured on the supplied Linux Codespaces host with Godot 4.7.2, Chromium headless
and SwiftShader. Web builds remain single-threaded. Scoped Godot timings measure
CPU work; browser RAF intervals are frame-time proxies. Neither is a physical
mobile-device benchmark. Native timing varies with competing browser/export work.
No guest/asset/staff caps, economic constants, game rules, game speed or RNG draws
were changed. No rendering detail was removed.

The original baseline was captured before source edits using seeded small
(2 assets/2 guests), medium (24 assets/32 guests/14 staff), and large
(80 assets/80 guests/28 staff) fixtures. Fixtures fund a disposable casino and
prepare placed assets; they do not change production progression. Medium/large
fixtures explicitly enable the basic drink menu. Stress placement and starting
occupancy are synthetic; guests subsequently use the normal lifecycle.

## Reproduction and evidence

The baseline release browser fixture showed long frames immediately on this
software-rendering host: mean RAF intervals were 230 ms (small/1x), 282 ms
(small/4x), 1,060 ms (medium/1x), 469 ms (medium/4x), and 803 ms (large/4x).
Worst samples were 500, 833, 2,367, 967 and 2,867 ms respectively. These short
runs reproduce heavy-floor pressure, not an independently established original
30-minute degradation curve. Browser tests and native checks sometimes ran
concurrently; browser FPS numbers must not be treated as controlled hardware
speedup measurements.

A baseline Chromium CPU profile sampled 11.18 seconds; 9.03 seconds (81%) were
attributed to synchronous WebGL `getParameter` calls. This strongly suggests the
software graphics backend dominates this host's browser frame time. Native
measurements separately confirmed population scans, inspector allocation and
full-state serialization as avoidable source costs.

Original scoped CPU means, in milliseconds:

| Scenario | Floor population queries | Inspector refresh | Full snapshot + JSON | Simulation step |
| --- | ---: | ---: | ---: | ---: |
| Small | 0.018 | 3.405 | 0.348 | 0.977 |
| Medium | 1.131 | 4.770 | 4.185 | 13.878 |
| Large | 6.903 | 4.296 | 10.623 | 48.521 |

A later before/after timing pair measured inspector refresh at 3.159 -> 0.476 ms
(small), 3.170 -> 0.707 ms (medium), and 3.351 -> 0.858 ms (large). Replacement
floor-index construction measured 0.014 / 0.186 / 1.434 ms. These indexes are
reused between simulation/status/guest-membership changes rather than built on
every draw. Dictionary reads then replace per-asset population filtering.
Whole-step timings remain noisy under browser/export contention; no whole-step
speedup is claimed from those samples.

Game-view steady-state change detection, microseconds per call:

| Game | JSON baseline | Native comparison |
| --- | ---: | ---: |
| Slots | 22.65 | 11.95 |
| Blackjack | 14.53 | 7.84 |
| Roulette | 23.59 | 8.33 |
| Holdem | 20.49 | 7.40 |

An idle floor at 60 process frames/second redrew 180 times in 180 measured frames
before the change and 3 times afterward, following camera warmup.

## Changes and ownership

- `simulation.gd`: one-pass, read-only floor presentation indexes; explicit
  presentation revisions on simulation steps and movement state transitions;
  dealer-free slots bypass crew scans. Table/crew indexes are scoped to the part
  of `step()` after staffing has completed and are cleared at its end. Seated and
  reserved gameplay queries remain live because guests can change tables within
  a step. Staffing ordering/sorting and RNG call order remain unchanged.
- `floor.gd`: revision/dirty invalidation, smooth animation/movement redraws and a
  one-second idle safety refresh. Financial feedback is globally netted over
  `5 * speed` economic ticks; one prioritized thought is presented per window.
  Economic/thought signals remain immediate. Pause/speed changes discard stale
  presentation-only pending data; developer acceleration suppresses routine
  floor feedback. A global signed batch stays visible even if its last asset is
  outside the current camera.
- `main.gd`: retained ordered render nodes replace temporary inspector trees and
  recursive patching. Only changed child kinds/counts create/free structure;
  actions replace old signal callbacks. Layout runs on resize/pane changes;
  shared visibility rules still refresh for walk/target interaction. Paused,
  unchanged timer refreshes update only the header. Responsive containers sort
  naturally on real content/minimum-size changes; forced patch sorting is gone.
- `main.gd` / `tuning.gd`: frequent debug diagnostics every 0.5 seconds; full
  state and inspector-label geometry every 2 seconds. Browser checks can
  explicitly request full polling with `window.neonHouseRequestFullState = true`.
  Timer publication is the only regular publication path. Release exports
  expose no production debug controls/telemetry.
- `game_view.gd`: native array/scalar comparison instead of per-frame JSON;
  previous mutable state is copied only when it changes.
- `AGENTS.md`: durable cache/UI/diagnostics/RNG ownership rules only.

## Exact feedback replay

200 seeded simulation ticks, with normal movement, staffing and service. Both
versions emitted **3,639 individual economic events** at both presentation speeds.

| Speed | Equivalent real seconds | Money labels before -> after | Money labels/sec before -> after | Thoughts before -> after |
| --- | ---: | ---: | ---: | ---: |
| 1x | 200 | 1,999 -> 40 | 10.00 -> 0.20 | 98 -> 39 |
| 4x | 50 | 1,575 -> 10 | 31.50 -> 0.20 | 33 -> 10 |

These are actual visible label creations after the original merging/limit rules,
not an assumption that every financial signal previously made a label. Thought
AI still updates immediately; repeat/cooldown limits can suppress a visual window.

## Verification

- Full current suite: **142,503 checks, zero failures**, including six seeded
  48-game-hour runs, progression, accounting/RTP, all five games, saves,
  construction/navigation, debug acceleration and five Finance viewport sizes.
- Final quick rerun: **1,660 checks, zero failures**.
- New deterministic performance suite: **97 checks, zero failures**. Covers
  1x/2x/4x cadence, exact batch sum, immediate economic events/thought updates,
  unchanged balances, pause/speed rebasing, developer suppression, 500-tick
  state/RNG equivalence, retained nodes and cache/authoritative agreement.
- Before/after full save snapshots and RNG state match for small, medium and
  large 300-tick replays. The service-enabled replay also matches exactly: medium sold 6 drinks / comped
  38; large sold 3 / comped 21.
- Startup, roulette input geometry, and updated game/service/cage smoke checks
  pass. Obsolete test fixtures were updated for current property geometry,
  explicit drink menus/orders/duty state and current save version. No historical
  save compatibility was added.
- Browser management/save-load/release-exclusion check passes. Desktop and touch
  portrait/landscape move/build/cancel/resize/walk/manage/navigation smoke passes.
  Debug 100x/1000x checks pass using live button geometry rather than obsolete
  coordinates. Physical device touch feel remains a manual check.
- The real-time release soak and short browser timing results are recorded below.

## Retention audit

Visible histories already have caps: financial events, house activity, alerts,
incidents, table interest, cage effects, thought histories and pending thoughts.
Pending thoughts retain lightweight IDs/text/positions, not guest dictionaries;
they are bounded, expire and are cleared on pause/speed changes/flush. Routes are
removed on arrival; departed guest dictionaries leave the authoritative guest
array. Presentation references are replaced on the next invalidated draw; a hidden
floor may retain its previous bounded presentation until displayed again.
Simulation step indexes are explicitly cleared. Retained-node cursors are cleared
after each refresh. Structural removal detaches and queues controls for deletion;
reused buttons disconnect their previous callback before replacement. The game
view retains one prior signature/round rather than accumulating rounds. Browser
snapshots overwrite globals; full save snapshots are scoped to a write/request.
No timer or signal is added on refresh.

Browser native Godot `MEMORY_STATIC` reports zero in this release environment,
so JS heap, object/node counts and Linux summed browser-process RSS are recorded.
RSS includes shared pages more than once; use its trend, not its absolute total.
A 60-minute heap measurement was not run; the release soak was stopped at the user's request before 30 minutes.

## Reproduction commands

```sh
GODOT=/home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64
python3 casino-godot/export_web.py --both --godot "$GODOT" --version 0.4.2
python3 casino-godot/tests/run_regression.py --godot "$GODOT"
"$GODOT" --headless --path casino-godot --script tests/performance_checks.gd
"$GODOT" --headless --path casino-godot --script tests/performance_idle.gd
"$GODOT" --headless --path casino-godot --script tests/performance_feedback_rate.gd
python3 casino-godot/tests/export_performance.py --godot "$GODOT" --output /tmp/neon-perf-web
python3 -m http.server 8095 --bind 127.0.0.1 --directory /tmp/neon-perf-web
# In another terminal with Playwright installed:
PERF_URL=http://127.0.0.1:8095/game.html PERF_SOAK=1 PERF_SECONDS=1800 \
  node casino-godot/tests/performance_browser.mjs
python3 casino-godot/tests/performance_soak_check.py /tmp/neon-browser-performance.json
```

`PERF_SOAK` unset runs the five small/medium/large speed scenarios; `PERF_SECONDS`
controls each duration. `PLAYWRIGHT_MODULE` can select an installed Playwright
module. `performance_process_memory.py` optionally samples Linux browser RSS/CPU.
The exporter copies to `/tmp` and swaps only that project's test scene; production
`casino/` receives no fixture hooks. Its existing preset excludes `tests/*`.

## Short browser comparison

These release samples use the same viewport and software backend, but different
wall durations (baseline 30 seconds, after 20 seconds), concurrent host work and
service-enabled after fixtures. They show workload pressure, not a reliable
whole-browser speedup. Core-function timing and exact state replay justify the
source changes; smooth 4x on physical hardware remains unproven here.

| Scenario/speed | Mean RAF before / after (ms) | Worst after (ms) | After guests/assets/staff |
| --- | ---: | ---: | --- |
| small / 1x | 230 / 512 | 867 | 2/2/0 |
| small / 4x | 282 / 530 | 917 | 3/2/0 |
| medium / 1x | 1060 / 595 | 1167 | 32/24/14 |
| medium / 4x | 469 / 478 | 1033 | 35/24/14 |
| large / 4x | 803 / 585 | 1400 | 80/80/28 |

Default debug medium/4x (30 seconds): mean RAF 841 ms, worst 1,750 ms,
35 guests/24 assets/14 staff, 173 nodes. Full serialization uses the new two-second
cadence. Release has 134 nodes and no production debug serialization. The graphics
backend dominates both; this is not evidence of a precise debug/release FPS ratio.

Mobile portrait release (390x844, medium/4x, 30 seconds): mean RAF
201 ms, worst 350 ms, 46 guests / 24 assets / 14 staff.
Automated portrait/landscape interaction checks passed; physical-device frame
rate and readability require manual verification.

## Release soak: partial, stopped at user request

Completed 21.1 minutes real time at requested 4x, with doors open,
24 assets, 14 staff, an explicit basic drink menu and normal arrivals/lifecycle.
Simulation advanced to 1327 minutes; 12734 economic events and
66 visible money batches were recorded. Guests ranged from
18 to 58. Godot nodes stayed at 134;
objects ranged from 1780 to 1784. Browser errors: 0.

JS heap samples ranged from 11.6 to
31.6 MB, with GC fluctuations. The last
sample was 31.6 MB. Native release memory telemetry was unavailable
(zero), and separate Linux RSS samples contain temporary overlapping comparison
browsers (process-count changes); those samples must not imply a game leak.
The sampled trend checker found no stopped simulation, node growth or excessive
post-warmup frame/JS-heap degradation over this partial run. This is preliminary
evidence, not a 30- or 60-minute soak pass or a proof of steady-state memory.

The last RAF mean / p99 / worst was 259 /
467 / 650 ms. The software backend prevented
real-time 4x throughput despite the 4x setting; smooth 4x remains unverified.
A fresh 30-60 minute run on hardware graphics is still required.

## Build and commit status

Source changes completed. Build/export: **SUCCESS**. Generated playable build
updated: **YES**. Release `casino/` and ignored local debug `casino-debug/` were
regenerated from the same source using the normal exporter and matching templates.
No generated runtime binaries were manually edited. Changes are uncommitted and
`git diff --check` is clean. The requested full-duration soak is outstanding.

Manually verify a developed casino at 4x on hardware graphics for 30-60 minutes,
1x/2x/4x/pause feedback cadence, mobile move/build/resize, game join/play/leave,
Finance/Staff/drink-menu decisions and save/load. New-game modal readability on
small physical screens also merits inspection; automated clicks are not a
readability guarantee.
