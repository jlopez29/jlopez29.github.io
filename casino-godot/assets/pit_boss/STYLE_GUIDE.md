# PIT BOSS Visual Style Guide

## Direction
Luxury casino management, not cyberpunk. Neon is an accent, not the main identity.

## Core palette
- Background: #0E0F10
- Surface: #1B1F24
- Secondary surface: #242E36
- Gold: #D4AF37
- Burgundy: #72202A
- Casino felt: #0F5132
- Success: #22C55E
- Warning: #F59E0B
- Danger: #EF4444
- High roller accent: #8B5CF6
- Primary text: #EAE4D6

## Typography
Recommended free fonts:
- Logo / major headings: Cinzel
- UI / body copy: Inter

Do not bake text into production UI artwork. Let Godot render all labels, values, counters,
button captions, and alert text.

## UI language
- Near-black surfaces
- Thin warm-gold outlines
- 8–18 px radii
- Green for profit/open/success
- Burgundy/red for danger/disable/security incidents
- Purple only for high rollers / jackpot / exceptional states
- Gold for VIP, upgrade, primary actions, selected major tabs

## Guest language
Keep guests abstract and readable. Compose:
1. base dot
2. optional role/ring
3. mood/status overlay
4. small intent/thought icon
5. only one dominant special marker at a time

This preserves readability with hundreds of guests.
