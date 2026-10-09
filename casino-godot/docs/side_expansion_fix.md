# Side expansion fix: reproduction and verification

Verified against master `f131f325538f9fd1e03232c62762d2ff5007a209`, which matched
origin/master at task start. Runtime: Godot 4.7.2 stable, headless.

## Original rejection

Normal casino; slots #3 and #4 at (80,100) and (400,100), blackjack #5 at
(80,330). The existing layout passed `Placement.validate()` with no errors.
Expansion unlocked (blackjack unlocked, Rating 50); casino cash $1,000,000.
Each purchase below used an independent copy of the starting fixture.
Current property: Rect2(0,0,535,610); entry: (267.5,90).

| Direction | Price | Proposed rectangle | Proposed entry | Property.valid | Full placement errors | Purchase |
| --- | ---: | --- | --- | --- | --- | --- |
| Left | $3,000 | Rect2(-320,0,855,610) | (107.5,90) | true | message: Furniture/art blocks the entrance; position: (110,135); asset_id: 3 | false |
| Right | $3,000 | Rect2(0,0,855,610) | (427.5,90) | true | message: Furniture/art blocks the entrance; position: (430,135); asset_id: 4 | false |
| Bottom | $2,000 | Rect2(0,0,535,850) | (267.5,90) | true | [] | true |

Rejected side purchases kept $1,000,000 cash and the original property rectangle,
but changed saved alerts by logging a generic failure. Bottom deducted $2,000.
The side rejection happened inside the validator before pathfinding: relocating
entrance clearance consumed existing legal slot furniture/art. Eligibility,
property size and affordability all passed. The UI callback discarded the false
return and refreshed, hiding the actual validator errors from the purchase panel.

## Implementation

- Anchor entrance, clearance, public/private doors, cashier and bar to one saved
  frontage footprint. Property geometry, prices and upkeep formulas are unchanged.
- New casinos keep the starter frontage. Existing valid current-version saves
  without `frontage_chunks` retain their former expanded frontage; subsequent
  purchases preserve it. Validate anchor metadata before applying restored state.
- Keep collision and navigation validation. Return actual errors through a
  session-only `expansion_errors` array, with asset IDs and named service points.
  Validate only on purchase, never on panel refresh. Rejections no longer change
  saved state, cash, geometry or RNG.
- Successful UI purchases refresh retained carpet/trim/lobby/architecture and
  frame the entire property. The simulation invalidates/reroutes navigation.
  Fit ignores selected-asset close-up framing; normal gameplay preserves pan/zoom.
- No automatic furniture moves, balance changes, RNG changes, or gameplay/economy
  tuning changes. Saved anchor metadata also preserves service actor destinations.

## Runtime results

Commands use `godot` as shorthand for the installed Godot binary.

| Command (`godot --headless --path casino-godot`) | Result |
| --- | --- |
| `--script tests/property_expansion_smoke.gd` | 258 checks, 0 failures |
| `--script tests/test_asset_placement.gd` | 1,472 checks, 0 failures |
| `--script tests/back_room_smoke.gd` | 77 checks, 0 failures; physical entry/play/exit after left, right and bottom purchases |
| `--script tests/startup_smoke.gd` | STARTUP_SMOKE_OK |
| `--script tests/test_floor_asset_presentation.gd` | 111 passed, 2 failed: Rotated seat blackjack; Pickup/delivery completes |

The last suite produced the identical two assertion failures on an isolated
unchanged-master copy. Those unrelated assertions remain intact. Existing test
shutdown ObjectDB/resource warnings also persist; no gameplay script errors were
reported by passing checks. Full regression/soak was not run.

The new focused regression covers independent default/populated left/right/bottom
purchases, consecutive side purchases with bar/cage, exact single charges,
unchanged furniture/RNG/owner wallet, guest seat/cage/exit travel, dealer approach
connectivity, bartender pickup and technician travel, real table build/move
commands into wings, anchored and pre-fix save loads, corrupt anchor rejection,
all eligibility failures, specific validator errors in the actual panel, retained
carpet/lobby geometry, Fit and mouse pan/zoom at 1440x900, 390x844 and 844x390,
and mobile touch pan/pinch. Viewports and gestures are simulated in Godot headless;
physical desktop/mobile browser gameplay was not verified.

`python3 casino-godot/export_web.py --godot <installed-binary> --both` succeeded:
release `casino/` and development `casino-debug/` regenerated from the same source.
Git diff reviewed; `git diff --check` passed. No commit or push performed.

Manual follow-up: purchase either side on a populated floor and inspect the fixed
lobby; walk into/exit the Back Room; use Fit, drag and zoom in desktop and mobile
browsers and confirm the added wings are discoverable.
