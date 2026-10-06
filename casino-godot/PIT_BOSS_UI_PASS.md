# 0.4.6.5 - Pit Boss Full UI & Art Foundation

The production `main.tscn` still launches `scripts/main.gd`. The Pit Boss
presentation replaces its existing controls in place; there is no alternate
scene, mockup or second HUD. The simulation, save schema, internal project ID,
owner transactions and casino rules remain the existing implementations.

## Ownership and integration

- `pit_boss_theme.gd`: shared palette, Theme factory, reusable skins, SVG
  navigation decoration and cached individual textures.
- `main.gd`: real cash/personal-wallet/guest metrics, responsive inspector,
  management navigation, shared play header and floor-targeting transitions.
- `event_cards.gd`, `milestone_notice.gd`: retained event card and notification
  surfaces, with accomplishments suppressed during placement and play.
- `floor.gd`: batched repeated flooring, footprint-fitted furniture, abstract
  guest dots and a single dominant ring (distress > selection > VIP).
  Existing indexed occupancy/staff/status data and thought/money queues remain.
- `game_art.gd`, `casino_surface.gd`, `game_view.gd`: dynamically mapped deck,
  chips, wheel, slot symbols/cabinet and felt, with retained action controls.
- `roulette_layout.gd`, `craps_layout.gd`: individual felt/dice assets, with
  existing dynamic wager geometry, touch handling and settlement presentation.

Desktop retains navigation, floor, inspector and House Activity. Mobile uses
bottom navigation and a contextual inspector sheet with the floor above it;
full management pages remain scrollable. Placement always prioritizes the floor.
Mobile taps select a persistent preview; Place/Move, Rotate and Cancel occupy a
separate strip below the grid. Drag pans without committing. Orientation retains
placement and selection. Desktop retains click-to-place and R/Esc controls.
Play hides management navigation and presents Pit Boss branding, casino cash,
personal wallet, speed and Return to Floor. Existing game legality determines
which actions and wagers are available.

No reference screenshot is used as a texture. Reference folders are excluded
from web exports. World art uses filtering/mipmaps, fits inside logical occupancy,
and never changes footprint/pathing/click bounds. The full SVG logo contains text
that Godot's SVG importer does not render; card ranks/suits, chip amounts and
BAR/seven lettering are drawn natively over the individual assets. Branding combines
the individual crown mark with a native text label. Fonts remain Godot's existing
font. The pack has no lemon symbol; the original lemon silhouette remains for
that real slot result. Generated furniture needs art-direction cleanup before
release.

## Verification

Temporary checks live outside the repository; no test infrastructure was added.
