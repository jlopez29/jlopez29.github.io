# Slot presentation pass

Remote master fetched/pulled; baseline `7e3f56333cd83ce71dcd97388b4e5acd4d3c676e`. The existing uncommitted 3x3 overhaul was preserved. SHA-256 checks confirm this pass did not change `casino_games.gd`, `simulation.gd`, `tuning.gd`, `owner_event_play.gd`, or `optional_events.gd`. RNG, payouts, probabilities, paylines, RTP and sponsor accounting are unchanged. No save schema changes in this pass.

## Changes

`slot_result.gd` centralizes economically truthful presentation categories. Paid $5 / returned $5 is BREAK EVEN; $2 returned is PARTIAL RETURN, NET -$3. Sponsored returns are positive Casino Cash results. Positive tiers use 2x/5x/10x return thresholds and the existing three-seven top-award condition.

`slot_presentation_state.gd` owns animation phases and one-shot cue transitions. `slot_particles.gd` provides a deterministic 48-particle maximum pool without gambling RNG. `slot_presentation.gd` now draws separate reel wells, internal shadows, edge-only idle markers, layered neon paths behind symbol artwork, 280ms tracers, reacting symbols, marquee states, cabinet chase and restrained impact/shake. Winning symbols overshoot to 1.15 and settle at 1.04; non-highlighted cells dim during line presentation. Browser reduced-motion preference suppresses shake, particles and overshoot.

Each winning line gets 320ms, followed by a 350ms combined highlight. Amount counts last 300ms for small/partial/break-even, 650ms for wins, 1.15s for big, 1.35s for huge and 1.8s for top awards. Losses recover after a short 180ms result hold. Reel sounds fire once at their impact boundaries. Partial/break-even use a quiet acknowledgment, never a win sting or particles.

`game_view.gd` displays returned amount and signed net separately, keeps short financial values on their own lines, dims surrounding UI for strong results and offers SKIP only after the outcome is revealed. The first tap skips presentation without staking another round. `slot_audio.gd` reuses existing original assets for a quiet acknowledgment; no new art or WAV assets were needed.

## Checks and screenshots

- `tests/slot_juice_checks.gd`: 75 checks, zero failures. Critical result semantics, sponsored semantics, tier thresholds, tracer/symbol sequencing, cue boundaries, safe skip without a second wager, no outcome mutation, reduced motion and six viewport sizes.
- Existing `tests/slots_overhaul.gd -- --quick`: 118 checks, zero failures. Its completion check now uses actual presentation duration.
- `tests/slot_juice_capture.gd`: actual stop-model presentation fixtures captured with Godot/GL Compatibility under Xvfb, audio muted. Desktop 1440x810, portrait 390x844, landscape 844x390; break-even, partial return, big win and top award. Screenshot review resolved landscape caption overlap and currency wrapping.
- `git diff --check` clean. Mechanics source fingerprints unchanged.

Before/after files in `slot-juice-review/` outside the Godot project avoid adding review images to the playable asset pack:

| Fixture | Before | After |
| --- | --- | --- |
| Desktop, $5 break-even | [Before](../../slot-juice-review/desktop-before.png) | [After](../../slot-juice-review/desktop-after.png) |
| Portrait, $35 big return | [Before](../../slot-juice-review/portrait-before.png) | [After](../../slot-juice-review/portrait-after.png) |
| Landscape, $2 partial return | [Before](../../slot-juice-review/landscape-before.png) | [After](../../slot-juice-review/landscape-after.png) |

These are isolated presentation fixtures, not live financial settlements. Native desktop/mobile layouts and muted visual readability were checked; listening on actual hardware and subjective touch-device pacing remain human checks.

Build command: `python casino-godot/export_web.py --both --godot /home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64`.

Manual gameplay: play paid and sponsored spins with sound muted, confirm net-result wording and distinct line/symbol reactions, tap SKIP after reveal and verify it does not charge another stake, rotate the viewport, then assess audio timing and reduced-motion behavior in the browser.
