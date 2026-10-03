# Neon House — playable 0.1

A Godot/GDScript casino tycoon prototype with a shared craps simulation.
Manage the business, walk its floor, and play at your own tables. The goal is to
find out whether the combination creates enjoyable management decisions.

## Play

Serve the repository root with `python3 -m http.server 8080 --bind 127.0.0.1`,
then open `http://localhost:8080/casino/`. Desktop keyboard and mouse recommended;
a browser supporting WebAssembly and WebGL 2 is required. The first download is
about 39 MB. Use Fullscreen for a larger view.

1. Start with $24,000, a furnished floor, and one craps table.
2. Select the table and hire **two dealers** ($150 onboarding each).
3. Open the casino. Guests find seats, place bets, and share table rolls.
4. Build another craps table ($3,500). Rotation and spacing checks are included.
5. Hire service from **Staff & assignments** to prevent thirst and complaints.
6. Click **Walk the floor**, move beside a table with WASD/arrows, select it, and
   click **Join craps table** or press E.
7. Place bets and **Shoot the dice**. Other seated guests share your outcomes.
8. Leave the rail with Escape. The table resumes automatic rolling, including
   settlement of your outstanding contracts.

Your visitor wallet starts at $1,000 and is separate from the casino treasury.
This is an owner playtesting account: visitor bets still transfer against the
same house cash, and finance displays the visitor's net separately. All money is
fictional. No accounts, purchases, payments, or multiplayer are involved.

## Controls and management

- Click a table or guest to inspect it; click empty floor to walk toward it.
- WASD/arrows: walk; E: join selected nearby table.
- Build: click to place; R: rotate; Escape: cancel.
- Move/sell: available when a table is empty with no outstanding visitor bets.
- Pause/1×/2×/4×: control simulation time. Space toggles pause.
- One real second at 1× is one game minute.
- Close doors: stop arrivals/new wagers, finish outstanding bets, let guests leave.
- Incidents: repair damaged rails or decide how to respond to drink complaints.
- Staff: assign standby dealers and swap a rested dealer for a tired one.
- Save/Load: one local versioned save, including guests, contracts, staff, clock,
  incidents, wallet, layout, and random-generator state. Browser storage must be
  available. Clearing site data removes the save. There is no cloud sync.

## Craps rules implemented

- Pass Line: even-money win on come-out 7/11, loss on 2/3/12; otherwise establish
  4/5/6/8/9/10 as point. Make point before seven to win.
- One Pass Line bet per player, placed only before come-out; locked after a point.
- Pass odds: true odds (2:1 on 4/10, 3:2 on 5/9, 6:5 on 6/8), up to 3× the line.
- Place 6/8: $30 increments, pays 7:6, stays up after a hit, loses on seven-out.
  Place bets are OFF on come-out, including come-out seven.
- Field: single roll, even money on 3/4/9/10/11, double on 2, triple on 12.
- Take down removable bets: return Place/Field/odds; return Pass only before point.
- One of eight rail positions is reserved for owner playtesting, so guests do not
  fill your place while you walk to a table.
- Automatic guests currently use Pass Line. An abstract two-dealer crew replaces
  the larger crew used by a real craps casino.

Rules reference: [Hollywood Casino's craps guide](https://www.hollywoodpnrc.com/-/media/png/east/hollywood-pnrc/pdfs/table-games-tutorials/craps-gaming-guide.pdf).

## Edit, run, test, export

Use **Godot 4.7.2 standard edition**, with matching export templates. C#/.NET is not
required. Open `project.godot`, then press F6/F5 to play.

From the repository root (replace `godot` with your binary's path if necessary):

```sh
godot --headless --path casino-godot --editor --import --quit
godot --path casino-godot
godot --headless --path casino-godot --script tests/run_tests.gd
godot --headless --path casino-godot --export-release Web
```

The export writes `casino/game.html`, `.js`, `.wasm`, `.pck`, splash, and audio
worklets. Keep the generated files together and retain their names. Commit the
source and rebuilt game files. `casino/index.html` is the hand-maintained wrapper;
the export does not replace it. Compatibility rendering and **single-threaded**
web export avoid special hosting headers. There are no backend services.

Browser smoke test (requires Playwright/Chromium installed outside or inside your
normal development environment):

```sh
mkdir -p /tmp/neon-house-preview
godot --headless --path casino-godot --export-debug Web /tmp/neon-house-preview/game.html
python3 -m http.server 8090 --bind 127.0.0.1 --directory /tmp/neon-house-preview
# In another terminal:
node casino-godot/tests/browser_smoke.mjs
```

`PLAYWRIGHT_MODULE` can point to Playwright's `index.mjs`; `CHROMIUM_PATH` can select
an installed Chromium executable. `CASINO_TEST_URL` overrides the URL.
The debug export exposes a read-only JS snapshot for test assertions. That hook
is excluded by `OS.is_debug_build()` from the release game.

## Limits of 0.1

This is a 2D overhead playable test, including a zoomed visitor view, not a
first-person 3D casino. It has craps only, simple service and repair incidents,
40 guests maximum, and a compact floor. NPCs visibly navigate around tables.
Guests share one preference and wager type; VIPs have larger bankrolls. Fatigue,
service needs, reputation, and financial variance create early management pressure.

Progression unlocks, room expansion, other casino games, sophisticated security,
first-person 3D, audio, Steam integration, and production balancing remain future
work. Reputation currently reflects customer experiences rather than unlocking
content. Cash can go negative; a complete bankruptcy/recovery system is deferred.
The app does not prove commercial viability: watch real playtesters and use
[the playtest questions](ROADMAP.md#playtest-questions) to decide the next step.

See [architecture](ARCHITECTURE.md), [balance](BALANCING.md),
[roadmap](ROADMAP.md), [assets](ASSETS.md), and [Steam notes](STEAM.md).
