# Pit Boss — playable 0.5

A Godot/GDScript casino tycoon prototype with craps, slots, roulette, blackjack, and Ultimate Texas Hold’em.
Manage the business, walk its floor, and play at your own tables. The goal is to
find out whether the combination creates enjoyable management decisions.

## Play

Serve the repository root with `python3 -m http.server 8080 --bind 127.0.0.1`,
then open `http://localhost:8080/casino/`. Desktop and touch controls are supported;
a browser supporting WebAssembly and WebGL 2 is required. The first download is
about 39 MB. Use Fullscreen for a larger view.

1. Start with $24,000, a furnished floor, and one craps table.
2. Select the table and hire **two dealers** ($150 onboarding each).
3. Open the casino. Small parties arrive with quiet gaps; some watch the dice
   before deciding whether to buy in. Seated guests share table rolls.
4. Use **Build games…** to add slots ($750), roulette ($1,800), blackjack ($2,500),
   craps ($3,500), or Ultimate Hold’em ($4,200). Slots need no dealer; the new
   table games need one each. Rotation and spacing checks are included.
5. Hire service from **Staff & assignments** to prevent thirst and complaints.
6. Choose **Walk the floor**, tap a table to approach it (or use WASD/arrows), and
   click **Join craps table** or press E.
7. Drag a chip from the tray onto the felt (or select a chip and tap a bet).
   When the dealer pushes the dice to you, hold them and flick toward the
   back wall (right on wide screens, up in portrait). Other seated guests share
   the same rolls. Pass dice to a CPU to bet without shooting.
8. Leave the rail with Escape or **Leave**. CPU play continues, including
   settlement of your outstanding contracts.

You can join a staffed, repaired craps table while the casino is closed. Hire two
dealers, choose **Walk the floor**, approach the rail, and join. Bets and payouts
still affect your wallet and the casino treasury; new guests only arrive after
you open the doors. Unpause the simulation to bet and roll.

Your Owner Bankroll starts at $1,000 and is separate from casino operating cash.
Normal play at your own tables still transfers against house cash; Finance keeps
that result separate from guest business. Optional event wagers use a separate
settlement API: the stake returns to your bankroll and only net winnings enter
casino cash. Losses spend personal funds only. Previous current-version saves
retain their personal wallet balance as the Owner Bankroll. All money is
fictional. No accounts, purchases, payments, or multiplayer are involved.

Joining opens a dedicated table view with players around the rail, chip stacks,
dice that bounce off the back wall, and animated collections/payouts. The view
shows one half-table: crew at the center edge, players around the outer rails.
Shooters must have an active Pass or Don’t Pass line bet, including on each new
come-out. If you join mid-point without a line bet, pass the dice until come-out.
You can move held dice across the felt and use a forward flick to release them;
there is no small movement box around the pickup spot. The felt follows a
traditional layout with number boxes, COME, FIELD, wrapping line bets, and a
separate hardways/proposition area on wide screens.

After settlement and a short betting window, the stick dealer pushes the dice
to the shooter. A tap or backward drag cancels the throw; forward swipe speed
and distance change the animation, never the random dice probabilities. Drag a removable stack back to
the tray to return the entire bet. **More…** opens advanced bets, individual
contracts, working/off, roll history, and pause controls. On short screens the
table scrolls vertically to keep the betting areas readable. Red stacks are
yours; blue stacks belong to guests. Chip labels show the total stack value.

## Controls and management

- Click or tap a table or guest to inspect it; tap empty floor to walk toward it.
- Phones use Floor / Table / Manage / Log tabs, with scrolling panels and touch buttons.
- WASD/arrows: walk; E: join selected nearby table.
- Build: click to place; R: rotate; Escape: cancel.
- Move/sell: available when a table is empty with no outstanding visitor bets.
- Finance: the headline separates lifetime settled gaming P/L from costs.
  Finance breaks out payroll and operations/hiring/net builds, with overall net
  shown separately. Unsettled stakes are excluded from gaming profit.
- Pause/1×/2×/4×: control simulation time. Space toggles pause.
- One real second at 1× is one game minute.
- Close doors: stop arrivals/new wagers, finish outstanding bets, let guests leave.
- Incidents: repair damaged rails or decide how to respond to drink complaints.
- Staff: assign standby dealers and swap a rested dealer for a tired one.
- Save/Load: one local versioned save, including guests, contracts, staff, clock,
  incidents, Owner Bankroll, event queue/cooldowns, layout, and random-generator state. Browser storage must be
  available. Clearing site data removes the save. There is no cloud sync.

## Craps rules implemented

- Pass Line: even-money win on come-out 7/11, loss on 2/3/12; otherwise establish
  4/5/6/8/9/10 as point. Make point before seven to win.
- One Pass Line bet per player, placed only before come-out; locked after a point.
- Pass odds: true odds (2:1 on 4/10, 3:2 on 5/9, 6:5 on 6/8), up to 3× the line.
- Don't Pass and Don't Come: bar 12, with lay odds capped to win 3× the base.
- Come bets travel to their own number, with up to 3× odds.
- Place all six numbers: 4/10 pay 9:5, 5/9 pay 7:5, 6/8 pay 7:6.
- Hardways and one-roll propositions, plus Field (double 2 / triple 12).
- Chip selectors, bet categories, individual removals, and the last 20 rolls.
- Place, hardways, and Come odds are OFF on come-out unless called working.
  Numbered Come bases and lay odds always work.
- Established Pass/Come bases remain locked; removable bets can be taken down.
- The shooter keeps the dice after making a point. Seven-out advances the rotation.
  Join an active table to queue; pass voluntarily to bet only. Hold betting pauses
  that table's CPU rolls while the rest of the casino continues.
- One of eight rail positions is reserved for owner playtesting, so guests do not
  fill your place while you walk to a table.
- Automatic guests currently use Pass Line. An abstract two-dealer crew replaces
  the larger crew used by a real craps casino.

Rules reference: [Hollywood Casino Toledo's table rules](https://www.pennentertainment.com/hollywood-toledo/casino/table-games-rules).

## New games and floor activity

Service employees walk from the cocktail bar to guests and back. Their assignment
shows their current route; existing service coverage controls thirst. Guests visit
the cage before leaving. Floating **HOUSE +$ / -$** shows the house’s gaming result
for that guest, excluding wages and other overhead. Cashing out does not count
already-settled bets a second time.

Approach and join any available game from the floor, including while closed.
Card hands must finish before leaving. The new views include a classic slot cabinet with illustrated reels and credit
meters, plus padded blackjack and hold’em felts with dealer racks, card areas,
and draggable chips. Select a chip and tap a wager circle as an alternative to
dragging. Ante and Blind increase together; Trips matches the Ante and toggles
on its circle. Reset returns wagers to the table minimum. Hand actions appear
along the table edge; rules and paytables expand on demand.

- **Slots:** one payline, three independent weighted reels. Matching cherries,
  lemons, bells, bars, or sevens return 5/8/15/30/100× the stake. Two cherries or
  a lone cherry on the first reel return 1×. These are total returns including
  stake. The configured theoretical return is 91.725%.
- **Roulette:** single zero; straight, split, street, corner, six-line, zero
  combinations, dozens, columns, and even-money bets. Drag chips from the tray
  onto the felt, or select a chip and tap. Seams place splits/corners; gold
  edge marks place streets/six lines. Seated guests share your spin.
- **Blackjack:** six decks shuffled each round, dealer stands on soft 17,
  blackjack pays 3:2, insurance, late surrender, doubling, and up to four split
  hands. Split aces receive one card each. Seated guests share your dealer.
- **Ultimate Texas Hold’em:** play against the dealer, with Ante/Blind, optional
  Trips, 3×/4× preflop, 2× flop, or 1× river raises and folding. Dealer qualifies
  with a pair; Blind and Trips paytables appear in the view. Seated guests use
  the same board and dealer, with automated decisions. This is not peer poker.

Rules references: [blackjack](https://www.venetianlasvegas.com/resort/casino/table-games/how-to-play-blackjack.html),
[roulette](https://www.venetianlasvegas.com/resort/casino/table-games/roulette-basic-rules.html),
and [Ultimate Texas Hold’em](https://www.oxfordcasino.com/table-games-oxford-casino/ultimate-texas-hold-em/).
The chosen house variations and paytables above govern this prototype.

Existing version-2 saves remain supported; absent game fields default to craps.
New saves include active card hands and pending roulette bets.

## Edit, run, test, export

Use **Godot 4.7.2 standard edition**, with matching export templates. C#/.NET is not
required. Open `project.godot`, then press F6/F5 to play.

From the repository root (replace `godot` with your binary's path if necessary):

```sh
godot --headless --path casino-godot --editor --import --quit
godot --path casino-godot
python3 casino-godot/tests/startup_smoke.py --godot godot
python3 casino-godot/export_web.py --godot godot
```

Use `export_web.py` for release exports: it stamps Help with the build date/time
in Eastern time and updates the wrapper version label (`--version` defaults to 0.3).

The export writes `casino/game.html`, `.js`, `.wasm`, `.pck`, splash, and audio
worklets. Keep the generated files together and retain their names. Commit the
source and rebuilt game files. `casino/index.html` is the hand-maintained wrapper;
the export does not replace it. Compatibility rendering and **single-threaded**
web export avoid special hosting headers. There are no backend services.

The lightweight startup smoke check above loads the real main scene, verifies
onboarding and essential UI controls, and exits. It catches script errors even
when Godot returns exit code zero, and times out instead of hanging. Set `GODOT`
or pass `--godot /path/to/godot` if the binary is not on PATH. It uses headless
Godot and Python's standard library; it does not check browser rendering or play
through the game. This is the default quick check for startup/script fixes.

The expansion check is also opt-in: one round per new game, shared guest card
settlement, in-progress save/restore, service delivery, and cage accounting:

```sh
godot --headless --path casino-godot --script tests/expansion_smoke.gd
```

Full simulation regressions remain opt-in:

```sh
godot --headless --path casino-godot --script tests/run_tests.gd
```

The older, extended browser gameplay smoke script below also remains opt-in;
its menu-based interactions need updating for the dedicated table view.
It requires Playwright/Chromium installed in your development environment:

```sh
mkdir -p /tmp/pit-boss-preview
godot --headless --path casino-godot --export-debug Web /tmp/pit-boss-preview/game.html
python3 -m http.server 8090 --bind 127.0.0.1 --directory /tmp/pit-boss-preview
# In another terminal:
node casino-godot/tests/browser_smoke.mjs
```

`PLAYWRIGHT_MODULE` can point to Playwright's `index.mjs`; `CHROMIUM_PATH` can select
an installed Chromium executable. `CASINO_TEST_URL` overrides the URL.
The smoke test covers desktop and emulated touch, portrait/landscape layouts,
shooter handoff, betting, and browser save/reload. The debug export exposes
a read-only JS snapshot and button bounds for test assertions. That hook
is excluded by `OS.is_debug_build()` from the release game.

## Windows executable export

Install the matching Godot 4.7.2 standard export templates, then run from the
repository root:

```sh
python3 casino-godot/export_windows.py --godot godot
```

The release is `casino-windows/PitBoss.exe` for Windows x86-64. Game data is
embedded, so copy the executable to Windows and double-click it; no Godot
installation or separate `.pck` file is needed. The generated directory is
ignored by Git. This uses the current source version/build label and excludes
debug developer tools. Windows gameplay should be checked on a Windows machine.

## Limits of 0.2

This is a 2D overhead playable test, including a zoomed visitor view, not a
first-person 3D casino. It has five playable games, simple service and repair incidents,
40 guests maximum, and a compact floor. NPCs visibly navigate around tables.
Guests have game preferences and automated betting strategies; VIPs have larger bankrolls. Fatigue,
service needs, reputation, and financial variance create early management pressure.

Progression unlocks, room expansion, sophisticated security,
first-person 3D, audio, Steam integration, and production balancing remain future
work. Reputation currently reflects customer experiences rather than unlocking
content. Cash can go negative; a complete bankruptcy/recovery system is deferred.
The app does not prove commercial viability: watch real playtesters and use
[the playtest questions](ROADMAP.md#playtest-questions) to decide the next step.

See [architecture](ARCHITECTURE.md), [balance](BALANCING.md),
[roadmap](ROADMAP.md), [assets](ASSETS.md), and [Steam notes](STEAM.md).

## V0.3 development controls

Godot editor runs and debug builds support **F10** after choosing a casino to
open/close the developer panel. It starts hidden. `DEV MODE` remains visible
after an action even if the panel closes, until starting a new casino.

Controls: add $1,000/$10,000, spawn one/five normal guests, prepare Rating +1,
advance to the next locked milestone, and force access to an implemented feature.
Advance supplies actual placed capacity/crews, prerequisite purchases, supporting
activity counters and funds as needed, then uses normal progression detection.
Rating +1 similarly prepares underlying development/activity instead of setting
a rating that the next simulation tick would erase. Normal costs, placement and
staff limits still apply; if space is insufficient, move equipment and retry.
These actions intentionally produce artificial development state; grants are not
gaming revenue, and activity counters do not simulate wagers or cash-outs.

Force Unlock only changes session access, without purchases or prerequisites.
Forced access clears on successful Load or New Casino and is never saved.
Prepared property, activity and treasury changes use the current save schema.
Release builds do not create the panel and reject developer action handlers and
forced access through `OS.is_debug_build()`.

Build the separate local development export (never overwrites `casino/`):

```sh
python3 casino-godot/export_web.py --godot godot --debug
python3 -m http.server 8081 --bind 0.0.0.0 --directory casino-debug
```

Run those commands from the repository root. The Godot path above is the installed
Codespaces binary; use your own matching binary on other machines.
Open `http://localhost:8081/game.html` (forward port 8081 in Codespaces).
Use the existing export command without `--debug` for the public release.
`--both` builds `casino-debug/game.html` and `casino/game.html` from the exact
same `casino-godot/` source/import/build timestamp. Only Godot's debug/release
export mode differs. `casino-debug/` is ignored by Git so local tools do not get
published through the existing GitHub Pages workflow.
Normal speed controls and balance remain unchanged; automated tests are opt-in.

The F10 panel offers 1x, 4x, 100x and 1000x. Extreme speeds are debug-only
stress tools; use Advance / Force Unlock for progression checks. The HUD shows
DEV 100x or DEV 1000x. Movement is substepped at at most 0.1 seconds, interleaved
with economic ticks; UI animations remain in real time. Work is limited to an
8 ms budget per frame (individual operations can exceed it), with at most 60
seconds of pending simulation time. Busy floors may run below the requested
speed; excess requested time is discarded rather than skipping economic ticks.
Loading a save, starting a casino or resetting the dev session resets speed to
1x. Extreme speed is not saved. Closing the panel does not stop acceleration;
use the normal speed buttons or pause.

## V0.3 Phase 02 money feedback

Floating HOUSE amounts are net casino results, not gross wagers or gross payouts:
$5 staked/$0 returned shows +$5; $5/$20 shows -$15. They rise/fade near the actual
machine/table, remain readable while walking, and prioritize larger swings.
Small same-sign bursts may show an explicitly counted aggregate. Guest and visitor
money stay distinct. Slot spins, blackjack/UTH hands, roulette guest spins and
craps rolls feed the same simulation-owned event signal. Pushes remain in recent
activity but do not create floating $0 labels. SESSION cage summaries repeat a
settled visit total, without another treasury transaction or gaming event.

The treasury number smoothly approaches actual cash with a subtle change pulse;
its tooltip shows the authoritative value. Cash includes expenses and unsettled
stakes, while HOUSE labels report completed gambling results. Compact recent house
activity is available in the floor report and game views. Load/New Casino clear
transient feedback. Balance, probabilities and 1x/4x operation are unchanged.

Manual checks: watch slots at 1x and 4x, walk/zoom during payouts, compare a losing
wager and winning return against HOUSE net, then use Easy/debug tools to observe
blackjack, roulette, craps and UTH. Check blackjack extra stakes/pushes, UTH raises,
roulette multiple guests, and craps unresolved/standing contracts. Confirm cage
visits and removable-bet refunds do not add duplicate net results; observe genuine
large wins/losses, busy-table overlap, purchase/payroll treasury motion, and fresh
visuals after Load/New Casino. No automated tests or spin suites are required.

Optional events appear in House Activity; on mobile, Log shows a colored event
count without covering the floor or game controls. Opportunities are safe to
ignore or let expire. Countdown uses game minutes and pauses with the game.
The starter catalog now includes owner slot/blackjack opportunities, real crowds,
large guest slot payouts, drink demand, service queues, tired dealers, breakdowns
and service complaints. Management cards explain the existing simulation effects
and add no ignored-event penalty. Emergency examples remain developer-only.

Owner opportunities offer a stake review before commitment. Lucky Machine commits
three spins; Owner's Hand plays one blackjack hand, including split hands and
optional extra stakes. Committing autosaves the current casino, and every accepted
action and result updates that checkpoint. Leaving resolves committed spins or
stands the remaining blackjack hands; it never refunds an already dealt loss.
Normal play at your own tables remains available with its existing accounting.
F10 in debug builds can trigger each catalog entry only when its real prerequisites
exist, bypassing cooldowns for manual checks without changing production odds.
