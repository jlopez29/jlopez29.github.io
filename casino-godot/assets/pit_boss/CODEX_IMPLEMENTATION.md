# CODEX_IMPLEMENTATION.md

## Goal
Use this pack to move the existing Godot casino project toward the Pit Boss visual target
without rewriting gameplay systems.

## Rules
1. Preserve existing simulation logic, save data, economy, pathing, and casino rules.
2. Do not use the reference screenshots as runtime textures.
3. Use `/ui`, `/icons`, `/guests`, `/flooring`, and `/casino` as source assets.
4. Render text/numbers dynamically with Godot Controls. Never bake current values into images.
5. Prefer Theme resources, Containers, StyleBoxFlat/StyleBoxTexture, and SVG icons.
6. Use NinePatchRect or StyleBoxTexture for scalable framed panels if needed.
7. Maintain touch targets of at least 44 logical pixels on mobile.
8. Never let mobile build controls cover the placement grid. Use a bottom sheet or edge controls.
9. Desktop and mobile should reuse shared components, not duplicate game logic.
10. Keep guest dots as the primary world representation.

## Recommended implementation order
### 1. Theme foundation
Create a global PitBossTheme.tres from `palette.json`, with shared typography, button states,
panels, tabs, badges, tooltips, and spacing.

### 2. Responsive HUD
Desktop:
- top metric bar
- side navigation
- right alert rail
- bottom inspector

Mobile:
- compact top metrics
- collapsible alerts
- bottom navigation
- draggable/collapsible bottom inspector
- floating build/move controls

### 3. Guest marker compositor
Construct each visible guest from:
- base body color
- ring by state/role
- optional mood icon
- optional thought/intent icon
- VIP/high-roller crown badge

Do not create a unique texture for every guest combination.

### 4. World art
Integrate top-down table and slot sprites from `/casino`.
Treat the generated raster casino sprites as starter art: verify silhouettes, scale, and readability
in the real game before replacing current assets globally.

### 5. Performance
Pool transient status icons/thought bubbles.
Throttle non-critical UI number refreshes.
Avoid rebuilding whole Containers every tick.
Animate only selected/high-priority guest markers when practical.

## Mobile breakpoints
Suggested:
- Compact: width < 700
- Standard: 700–1199
- Desktop: >= 1200

Use anchors/containers first. Avoid hardcoded absolute layouts except for tiny overlay badges.

## Asset import suggestions
SVG icons:
- keep as vector where supported
- no filter for pixel-snapped tiny icons if they blur
PNG casino sprites:
- use filtering for smooth top-down art
- enable mipmaps only if world zoom requires it
Floor tiles:
- repeat enabled
- test seams at multiple zoom levels
