# Directional asset placement clearance

Table placement no longer uses `FLOOR_TABLE_INSETS = (65, 100, 30, 110)`.
The property supplies walkable bounds; each game's configured geometry determines
its minimum placement clearance, including rotation.

## Shared geometry

`scripts/asset_placement.gd` separates:

- **Furniture:** existing logical physical footprint, still used for navigation
  obstacles. Asset sizes, gambling and seating capacity are unchanged.
- **Art:** cropped artwork bounds, fitted with the same scalar/rotation as the
  retained asset and placement preview. Art cannot clip another asset or entrance.
- **Interactions:** the existing authored guest seats and their outward approaches,
  plus separate dealer anchors at chip rails / the black dealer chair. All eight
  configured table positions, including the owner rail, are checked.
- **Circulation:** directional bounds of the actual seat/approach geometry. Public
  approaches reserve 18 pixels around the point; dealer approaches reserve nine.
  Unused sides have a four-pixel edge margin. The final collision envelope includes
  circulation and art. These are independent of the property's walking inset.

Blackjack seats face its curved player rail; roulette uses upper/lower player
chairs beside the wheel; craps uses its upper/lower rails; Ultimate Texas Hold'em
preserves the seven red chair anchors and eighth player-rail anchor, excluding the
black dealer chair. The existing guest approach calculation is preserved. Dealer
approaches use only the distance needed to get beyond the physical navigation
obstacle, so a back-side worker does not require a full public circulation aisle.

Placement preserves the 22-pixel minimum furniture-to-furniture aisle. Neither
asset may consume the other's required seat/approach clearance. Two circulation
envelopes may overlap when the resulting shared aisle serves both tables.

The circulation envelope, guest/dealer coordinates and art rotate together.
Dealer markers use these same rotated anchors instead of a fixed right-side
position that could extend beyond the floor.

## Navigation and persistence

A proposed layout must keep its complete collision envelope inside the walkable
floor. Every seat and approach is also checked explicitly. A single flood fill
from the entrance verifies every configured guest/dealer approach in the proposed
and existing layout, plus existing cage/bar interaction points. It uses the same
nine-pixel physical obstacles, rounded cells and four-way connectivity as runtime
`AStarGrid2D`. Seats inside their own table footprint remain intentional: gameplay
walks to the reachable approach, then performs the existing controlled final entry.
The entry segment and actor radius fit inside reserved circulation bounds.

Runtime placement, moving/rotation, navigation and current-version save validation
share the geometry. No legacy save migration is added. Geometry indexes and the
last proposal report are read-only, transient caches invalidated by furniture /
property changes; normal guest/staff movement does not rebuild them. Placement
checks and debug drawing never serialize the simulation or consume gambling RNG.

## Debug visualization

In debug builds, Build/Move automatically shows:

- Blue furniture bounds and player seat dots/approach boxes.
- Purple art bounds and dealer seat dots/approach boxes.
- Gold required circulation area, with faded neighbor outlines for conflicts.
- Green/red final placement collision bounds.
- Gray walkable floor boundary; red X markers and a reason for failed checks.

Lines join approaches to their authored seats. The legend distinguishes valid
geometry from a purchase blocked by cash, unlocks or a busy asset. Detailed
placement diagnostics are absent from release builds.

## Focused verification

```
godot --headless --path casino-godot --script res://tests/test_asset_placement.gd
```

The checks independently cover blackjack, roulette, craps and UTH in both
orientations at all four edges; one-pixel clearance violations; actual runtime
AStar paths for every guest/dealer; preservation of authored player-facing entry;
shared/blocked aisles; entrance exclusion; moving; default Normal/Easy starts; and
current save/load rejection of off-floor clearance. Actual guests also traverse
the runtime movement/final-entry code to every public seat without leaving the
walkable floor, for all four games in both orientations.

Minimum bottom-edge distances measured against the shared geometry (before the
normal 10-pixel placement snap) are:

| Game | Furniture: normal / rotated | Art: normal / rotated |
| --- | ---: | ---: |
| Blackjack | 60.2 / 58.0 | 56.2 / 62.1 |
| Roulette | 59.2 / 58.0 | 56.9 / 50.4 |
| Craps | 58.0 / 58.0 | 66.6 / 48.8 |
| Ultimate Texas Hold'em | 62.5 / 58.0 | 58.5 / 73.8 |

These replace the former blanket 110-pixel furniture restriction while preserving
real interaction room. Native rendered previews were inspected for all games and
rotations. Mobile presentation remains a manual gameplay check.

Manual gameplay checks: in the debug build, use Build/Move near each edge, rotate
each game, and watch the clearance and rejection markers. Place a valid near-wall
table, provide its normal crew, then confirm guests reach the correct chairs and
dealers remain on their designated side. Try a neighbor that consumes the player
approach aisle; it must be rejected. Check desktop, mobile landscape and portrait,
then save/load a valid near-edge layout.
