# Pit Boss Starter Asset Pack

This ZIP contains individually named assets intended for a Godot UI/art overhaul.

Included:
- vector logo + crown mark
- navigation/status/gameplay SVG icons
- modular guest-dot bases, rings, and mood overlays
- scalable UI panels, buttons, and status badges
- repeatable starter floor textures
- individually cropped top-down casino table/slot/amenity sprites
- desktop/mobile/top-down reference concepts
- Godot color tokens + guest-marker example
- implementation and style guides

Important:
The SVG/UI/guest assets are clean, modular starter production assets.
The top-down casino-object PNGs are AI-generated starter art extracted from the approved style
reference. Use them as working game assets, but visually QA them in-engine before final release;
small generated details may need hand cleanup.

Fonts are intentionally NOT bundled. The style guide recommends Cinzel + Inter, but obtain those
from their official distribution source and follow their licenses.

Start with CODEX_IMPLEMENTATION.md when handing this pack to Codex.


## v2 additions — Play Mode
This revision adds production-oriented assets for direct player gambling mode:
- full 52-card vector deck + Pit Boss card back
- six chip denominations
- blackjack felt and betting overlay
- roulette felt/betting grid and wheel
- craps felt/layout and six dice faces
- slot cabinet frame and eight slot symbols
- shared play-mode buttons/chrome
- mobile play-mode chrome
- new play-mode references
- `FULL_UI_OVERHAUL_CODEX.md`

For the large integration pass, give Codex `FULL_UI_OVERHAUL_CODEX.md` as the controlling brief.


## v2.1 — UI replacement priority
This revision makes the integration order explicit.

Recommended roadmap placement:
**0.4.6 Loyalty & Rewards -> 0.4.6.5 Pit Boss Full UI & Art Foundation -> 0.4.7 Promotions/Raffles/Events**

`FULL_UI_OVERHAUL_CODEX.md` now requires Codex to replace the current visible UI first rather than
creating a parallel/mockup interface.

See `ROADMAP_0.4.6.5_UI_PASS.md`.
