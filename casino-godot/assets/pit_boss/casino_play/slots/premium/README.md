# Premium slot presentation

The supplied raster pack is used by the single shared `slot_presentation.gd` renderer in public play, sponsored events and the Back Room. The five canonical symbols retain their original numeric IDs and paytables; alternate supplied symbols are imported artwork only.

Both cabinet layers use their native aspect ratio (1080/800 landscape, 780/1000 portrait), with a normalized reel window of `(0.10, 0.23, 0.80, 0.48)`. The base supplies the cabinet and result-panel borders. The transparent glass supplies the bezel and reel dividers; its decorative dots are excluded in favor of runtime payline markers. Do not draw a second border over these layers.

Buttons are real Godot controls positioned by the renderer's cabinet/deck rectangles. Portrait and desktop place Spin inside the lower panel and wager/line controls on an attached lower deck; short landscape uses an attached side deck. Each Spin target is at least 44 pixels tall. Result text uses the painted panel rather than stacking a second panel above it.

Some supplied files contain source-atlas remnants. `SYMBOL_REGIONS` excludes neighboring art from BAR/bell and the stray strip above seven, while preserving symbol proportions. Coin/sparkle regions select single complete particles and exclude source rules. The supplied `slot_symbol_glow.png` contains baked heading text and a truncated ring, so the renderer uses a small procedural halo instead. The large jackpot burst is drawn behind symbols and particles are clipped to the reel window so financial text and controls remain clear. The original PNG bytes are preserved.

PNG imports enable mipmaps for clean downsampling. Cached textures and a bounded deterministic particle pool avoid new gambling RNG calls or per-frame image processing. Motion preferences suppress bounce, trails, flashes, particles and animated cabinet lighting. Full exports use `export_web.py`; the package JPEGs are reference composites, not engine screenshots.
