# Slot overhaul implementation and verification

Baseline: `7e3f56333cd83ce71dcd97388b4e5acd4d3c676e` (master, fetched and fast-forward pulled; already current).

## Source and assets

Modified scripts: `casino_games.gd`, `casino_surface.gd`, `game_view.gd`, `tuning.gd`, `simulation.gd`, `optional_events.gd`, `owner_event_play.gd`, `event_cards.gd`, `main.gd`.
New presentation scripts: `slot_presentation.gd`, `slot_line_diagrams.gd`, `slot_audio.gd`, with Godot UID files.
Tests: new `slots_overhaul.gd`; updated owner-event expectations and removed obsolete wallet migration expectations in `run_tests.gd`.
Build metadata: `build_info.gd`. Playable release output: generated `casino/game.html` and `casino/game.pck`; local debug export rebuilt in ignored `casino-debug/`.

Existing cabinet and all five symbol SVGs reused unchanged. Dynamic trim, marquee, symbol highlights, payline traversal, bounce, deterministic sparks and scrolling ghost trails are drawn in Godot. Eight original WAV cues added under `assets/pit_boss/casino_play/slots/audio/`: spin, stop1/2/3, small, big, top, free. `generate.py` reproduces the original synthesized tones without external samples. Central audio node uses one voice, 65ms minimum cue separation, and ON/LOW/OFF controls.

## Authoritative schema and math

Slot rounds contain `kind`, `phase`, `profile`, `stops[3]`, row-major `grid[3][3]`, `active_lines`, `total_wager`, `winning_lines`, `credit`, `message`. Existing settlement adds `staked`/`paid` as appropriate. Each winning line records `index`, `path`, `symbol`, `reason`, `multiplier`, `line_bet`, `returned`.

Exactly three authoritative RNG draws choose uniform stops on the unchanged 20-position reel. Adjacent wrapped positions produce top/center/bottom. Rows indexed 0/1/2; paths, in activation order:

- Center `[1,1,1]`
- Top `[0,0,0]`
- Bottom `[2,2,2]`
- V `[0,1,0]`
- Inverted V `[2,1,2]`

Allowed counts: 1/3/5. Every line receives total wager / count. Three matching symbols take priority over the original cherry special. No payouts, reel weights, or house edges changed. NPCs retain one-line play and the original three-draw RNG order.

Every line's marginal symbols have the original distribution; linearity of expectation preserves total RTP even though lines are correlated. Paytable statistics enumerate all 20^3 = 8,000 joint stop combinations for each profile/count. This supplies exact combined maximum return, actual return standard deviation, any-return probability and any-seven-line probability, rather than pretending lines are independent.

| Profile | RTP for 1/3/5 lines | Maximum return 1 / 3 / 5 (x total wager) |
| --- | --- | --- |
| Starter | 91.3500% | 30 / 27.3333 / 22.4 |
| Standard | 93.7500% | 35 / 31 / 25.6 |
| Video | 94.4250% | 65 / 54 / 45.4 |
| Premium | 95.7875% | 120 / 95 / 81 |
| High limit | 95.4250% | 140 / 108.3333 / 93 |

## Reveal and controls

Scrolling begins on the previously displayed strip position and eases to the committed stop; it never draws RNG. Quintic acceleration/deceleration; reel stops at 0.78, 1.03 and 1.30 seconds, with a 0.10s snap/bounce. A natural matching prefix on an active line extends reel three by 0.22s. Reveal starts after its snap. No-return recovery is 0.12s; winning count-up/highlights last at least 0.55s, extending for multiple lines. Lines traverse individually for 0.22s each, then illuminate together. Most spins finish in 1.5-2.0s; five-line celebrations can reach 2.97s with anticipation.

Presentation tiers use return / total wager: below 1x small, 1-5x win, 5-15x big, 15x+ huge; any three-seven winning line gets top-award treatment. These labels never affect money or odds.

Header balances hold their pre-spin snapshot until reveal, then interpolate toward authoritative balances. Full currency precision makes small promotional returns visible rather than hiding them in abbreviated thousands. Financial settlement is synchronous and never repeated by animation. Spin and Floor exit (including Escape) are locked through reveal. Space/Enter spin only without GUI focus or an open paytable. One-denomination machines omit redundant bet controls. Other machines cycle legal denominations and offer Max Bet. Desktop uses a bounded large cabinet and side controls; portrait uses a taller cabinet and bottom controls; landscape uses side controls. Paytable includes visual patterns and per-line math.

## Manufacturer Demo

Production OPPORTUNITY, five sponsored $5 virtual wagers, five active lines. Offered once after five elapsed game minutes when an open early casino has an eligible working slot; thereafter normal weighted scheduling with a 10,080-game-minute cooldown and rating band 0-12. It is not treasury-triggered. Pending offers expire after 180 game minutes; ignoring/expiration have no penalty.

Funding is explicitly `sponsor`; normal owner events use `owner`. All five outcomes commit at engagement/start using persisted event RNG. Starting checkpoints them. Each revealed promotional return credits Casino Cash and `sponsored_income` once; neither wallet funds stakes. Financial events use `sponsored_promotion` with sponsor/event/virtual-stake details. Finance exposes the promotion total when relevant. No guest handle, gaming revenue, owner profit ledger, or owner-win Momentum is fabricated. Leaving resolves remaining committed spins; reloading or replaying a sequence cannot collect them again. Existing three-spin owner events still escrow personal stakes and transfer only positive net profit.

Save version deliberately bumped 18 -> 19. Old disposable saves are rejected without migration. Current rounds are validated against reconstructed strips and payouts; JSON numeric types, event funding/profile/wager/count, and current revealed-round consistency are checked. The obsolete historical wallet alias was removed; a missing current account still defaults defensively.

## Verification

Godot 4.7.2 with matching installed export templates.

- Full `tests/slots_overhaul.gd`: 154 checks, zero failures. Includes all five patterns, multi-line wins, cherries, sevens, losses, total exposure, malformed rounds, personal/NPC accounting, replay locks, sponsor transactions, expiry/ignore/cooldown, current save/load and six viewport geometries.
- Independent payout enumeration verifies all 15 profile/count combinations.
- 900,000 seeded spins: 150,000 each for starter/high-limit at each line count. All within six standard errors of exact RTP; the exact enumeration is the decisive expectation check.
- `tests/owner_events_smoke.gd`: 129 checks, zero failures, including existing owner slots/blackjack and event UI.
- Final focused rerun (`slots_overhaul.gd -- --quick`): 118 checks, zero failures; checks updated presentation and validation without repeating unchanged statistical runs.
- `git diff --check` clean.
- `export_web.py --both --godot /home/codespace/.cache/neon-house-tools/Godot_v4.7.2-stable_linux.x86_64`: release and debug exports regenerated successfully.

Browser screenshots reviewed at 1440x810, 2560x1080, 800x600, 390x844, 844x390 and 320x568. Spin and Paytable remain accessible; portrait cabinet height was increased after reviewing excess empty space. Actual new Normal starter play and early production offer exercised in Chromium. Sponsored spins showed the new reveal, winning paylines and Casino Cash credit while Personal Wallet stayed at $1,000. Headless checks verify outcome invariance on resize; browser fullscreen gestures and subjective audio quality still need human checks.

Manual gameplay checks: start a new Normal casino, play 1/3/5 lines with the same $5 total, watch left-to-right stops and balance reveal, open Paytable, try Space/Enter without focus, rotate/resize, and try Floor/Escape/double taps during reveal. Open the casino and engage Manufacturer Demo; confirm five free spins, unchanged Personal Wallet, Casino Cash credit after a real win, persistence after a mid-demo reload, and harmless Ignore. Listen to ON/LOW/OFF audio and assess pacing on an actual touch device.

No known mechanical failures remain. Audio cues are intentionally original temporary tones pending future professional assets; real-device audio/pacing and browser fullscreen remain human acceptance checks.
