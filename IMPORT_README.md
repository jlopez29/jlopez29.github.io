# Pit Boss — Premium Slot Artwork (raster pass)

This ZIP contains **real, separate transparent PNG sprites** and two 1080x800 / 780x1000 cabinet presentations, rather than a single pre-rendered slot screenshot. All five core reel symbols have detailed artwork. Alternate symbols and effects are also supplied.

## Install from the repository root

Unzip with paths intact, for example:

```bash
unzip -o pit_boss_premium_slot_art_v1.zip
```

The assets go into `casino-godot/assets/pit_boss/casino_play/slots/premium/` and `symbols/`.

On `feature/slot-visual-overhaul`, commit `b12873d` adds an artwork resolver to `casino-godot/scripts/slot_presentation.gd` that prefers these `.png` files and falls back to existing `.svg` artwork until the PNGs are committed. Therefore, adding the PNGs is a **required step** before the new look appears in a Godot build.

The **paylines, RNG, wager calculation, reel outcomes, and payouts are untouched** by the art pack. Labels and results remain runtime-drawn text. The reel animation continues using Godot's existing logic, not baked frames.

## Contents

- `slot_cabinet_{landscape,portrait}_base.png`: illustrated gold, ruby, and dark-metal cabinet layers
- `slot_cabinet_{landscape,portrait}_glass.png`: transparent mechanical bezel/vertical rails, centered on the live reel window
- `symbols/{cherry,lemon,bell,bar,seven}.png`: core transparent reel icons
- `symbols/{diamond,crown,horseshoe,clover,spade,heart,star}.png`: future tier symbols, currently not used
- `slot_{symbol_glow,stop_flash,jackpot_burst,coin_particle,sparkle_particle}.png`: real effects sprites
- `slot_jackpot_flash.png`: extra art for possible later effect

## Contract and review

- Both cabinet artwork variants have normalized reel aperture x=10%, y=23%, width=80%, height=48%.
- Symbols and FX have transparency; the cabinet frame uses opaque shaded art.
- The preview JPEGs are **static composites, not Godot captures**.
- After copying the PNGs, launch the same shared playable slot UI in the public casino and the Back Room. Validate actual mobile portrait + desktop landscape, icon alignment, clipping, final reel stops, correct payline highlighting and frame-time budget. Ensure there is no distorted cabinet before merging.

The package improves symbol illustration and frame material quality, but does **not** by itself integrate the SPIN control into the artwork or guarantee the exact glamour of the concept image. Those are gameplay UI/layout tasks still needing visual validation.
