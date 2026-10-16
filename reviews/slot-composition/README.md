# Premium slot composition review

Actual Godot 4.7.2 Compatibility renderer captures (Mesa llvmpipe), taken from the shared public slot view using the supplied PNG artwork:

- `desktop.png`: 1440 × 900
- `portrait.png`: 390 × 844
- `portrait-small.png`: 320 × 568
- `landscape.png`: 844 × 390

The cabinet now contains three interactive controls: cycling BET, circular SPIN/SKIP, and cycling LINES. Results occupy the full plaque below the reels. Illustrated details keep their original proportions; neutral cabinet material extends around the deck.

Focused validation: `slot_juice_checks.gd` passed 108 checks; `slots_overhaul.gd -- --quick` passed 118 checks. The latter retains its existing resource cleanup diagnostics on exit. Pointer-input checks covered cycling controls, spin, repeated input, rotation, and the Rules overlay. A focused Back Room check covered settlement and presentation independence from RNG.

Visual limits: the short-landscape control wing has simpler material than the illustrated central cabinet. These software OpenGL captures do not establish browser WebGL performance or physical-device touch behavior. Confirm those on the CI export; no exports were rebuilt locally.
