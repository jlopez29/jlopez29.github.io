# Pit Boss audio provenance

All new recordings are CC0 1.0, verified on the source pages and (for Kenney / Vehicle) the downloaded license/readme. Only the recordings used by the catalog are installed. The original slot WAV files remain at their existing paths and retain their existing provenance.

| Title / creator | Source / license | Installed files (relative to this directory) |
| --- | --- | --- |
| Jazz — Spring Spring / Julie Damsgaard | [opengameart.org](https://opengameart.org/content/jazz-1) · [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `music/casino_jazz.ogg` |
| Casino Audio 1.1 — Kenney Vleugels | [kenney.nl](https://kenney.nl/assets/casino-audio) · [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `games/craps/dice-grab-1.ogg`, `games/craps/dice-shake-1.ogg`, `games/craps/die-throw-1.ogg`, `games/shared/card-place-1.ogg`, `games/shared/card-place-2.ogg`, `games/shared/card-shove-1.ogg`, `games/shared/card-slide-1.ogg`, `games/shared/card-slide-2.ogg`, `games/shared/chip-lay-1.ogg`, `games/shared/chip-lay-2.ogg`, `games/shared/chips-stack-1.ogg` |
| Interface Sounds 1.0 — Kenney | [kenney.nl](https://kenney.nl/assets/interface-sounds) · [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `ui/back_001.ogg`, `ui/confirmation_001.ogg`, `ui/error_001.ogg`, `ui/open_001.ogg`, `ui/select_001.ogg` |
| Fantasy Accessory SFX Library — Jan Schupke / Vehicle | [opengameart.org](https://opengameart.org/content/fantasy-accessory-sfx-library) · [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `games/craps/dice-two-roll-01.wav`, `games/craps/dice-two-roll-02.wav`, `games/craps/wood-bowl-hit-wood-spoon-01.wav`, `games/roulette/ball-land.wav`, `games/roulette/coin-spin-fall-01.wav`, `games/roulette/wood-bowl-drop-nuts-01.wav`, `world/bar/vials-glass-rattle-01.wav`, `world/bar/vials-glass-rattle-02.wav`, `world/doors/keyhole-lockbox-unlock-01.wav` |
| Casino Floor, Phoenix AZ (Audio Field Recording) [mono] — mhtaylor67 | [freesound.org](https://freesound.org/people/mhtaylor67/sounds/277444/) · [CC0](https://creativecommons.org/publicdomain/zero/1.0/) | `ambience/casino_floor.ogg` |

## Processing and selection

- Jazz: source page labels the download `jazz.ogg`; the actual download URL is `https://opengameart.org/sites/default/files/jazz_2.ogg`. The full track is retained, peak limited to 0.7, with an 80 ms overlap blended at the loop seam. Final duration: 71.92 seconds.
- Casino ambience: derived from the user's authenticated original `277444__mhtaylor67__casino-floor-phoenix-az-audio-field-recording-mono.wav`, **not** the public preview. The original WAV required login. A 45-second excerpt has a 1.5-second blended loop seam and is encoded as OGG (43.5 seconds). Original download preserved at `/tmp/277444__mhtaylor67__casino-floor-phoenix-az-audio-field-recording-mono.wav` in the development workspace, outside the export. No original archive is included.
- Roulette uses physical foley from the accessory library: spinning coin for the wheel start, hollow rolling nuts in a wooden bowl for the ball orbit. These are substitutes, not recordings of an actual roulette wheel. A quiet loop of the wooden-bowl recording ends with the visible spin.
- Dice bounce recordings are shortened to 380 ms with a 60 ms tail fade; `ball-land.wav` is an 180 ms excerpt from `wood-bowl-drop-nuts-01.wav`, also faded at its tail. Both derivatives are used at their corresponding presentation boundaries.
- Craps uses real dice grab/shake/roll/settle recordings and a wooden impact for the cushion. The cushion cue follows the actual presentation path's impact time. Card slide/place/shove recordings are shared by blackjack and Holdem.
- Repeated physical effects use round-robin sample selection and at most 1.5% pitch variation; cosmetic variation consumes no simulation randomness.
