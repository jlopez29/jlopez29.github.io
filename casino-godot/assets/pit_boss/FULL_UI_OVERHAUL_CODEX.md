# PIT BOSS — FULL UI + PLAY MODE OVERHAUL
## Codex implementation brief — v2

A complete Pit Boss UI/art package now exists at:

`res://assets/pit_boss/`

This task is a MAJOR VISUAL PASS across the existing Godot project.

The pack contains both management-mode assets and dedicated playable casino-game assets.
The goal is to make the existing game feel like a polished commercial casino-management title
while preserving the simulation, economy, game logic, saves, and current feature set.

---

## HIGHEST PRIORITY — REPLACE THE CURRENT UI FIRST

The FIRST objective of this task is to replace the existing visible/prototype UI with the new
Pit Boss UI system.

Do not build the new interface as:
- an optional alternate HUD
- a demo scene
- a prototype scene
- a disconnected overlay
- a second UI layered on top of the current one

The existing game must launch directly into the new Pit Boss presentation.

Before spending significant time on world-art replacement or direct-play table polish, complete
the primary management UI replacement.

## Milestone 1 — UI Replacement Acceptance Criteria

When the game launches, the player should immediately see the new Pit Boss interface instead of
the old prototype UI.

Replace or migrate the current:
- main HUD
- money/revenue display
- time/speed controls
- navigation
- build controls
- selected-object UI
- alerts/notifications
- desktop panels
- mobile navigation
- mobile object controls
- mobile build/move interface

with reusable Pit Boss components.

Every existing gameplay action exposed through the old UI must still be accessible and functional
through the replacement UI.

Do not leave duplicate old controls underneath, behind, or alongside the replacement interface.

Only remove/deactivate obsolete prototype controls after confirming the replacement preserves
their functionality.

## Required implementation priority

Work in this order:

1. Replace the existing desktop UI
2. Replace the existing mobile UI
3. Verify all existing UI functions still work
4. Fix mobile build/move usability
5. Upgrade guest-dot presentation
6. Integrate new casino-floor/world artwork
7. Upgrade direct-play blackjack/roulette/craps/slots
8. Final responsive polish, performance work, and regression testing

The UI replacement is the foundation of the entire visual overhaul.

Do not spend significant time polishing play-mode artwork while the management game is still using
the old prototype UI.

At the end of Milestone 1, the existing game should already feel visually transformed even if
some world artwork and direct-play screens are still awaiting their final pass.

## Migration rule

Prefer replacing the existing UI scenes/components in place or routing the existing game into the
new reusable components.

Do not create a parallel "Pit Boss mode" that must be manually opened.

Existing signals, callbacks, actions, and data bindings should be migrated to the new components
rather than duplicated.

The goal is one production UI, not old UI + new UI.

---

# CURRENT ROADMAP PLACEMENT

This overhaul is intended to be implemented after the underlying 0.4.6 Loyalty & Rewards mechanics
are functional and before beginning 0.4.7 Promotions / Raffles / Events.

Do not redesign or expand 0.4.6 gameplay as part of this visual pass.

Use the completed 0.4.6 systems as real data sources for the new UI.

The reason for placing the overhaul here is that 0.4.7 and later systems will depend heavily on
alerts, event cards, guest status presentation, mobile interaction, and reusable UI components.
Building those features on top of the old prototype UI would create avoidable rework.

Treat this UI overhaul as an inserted milestone:

**0.4.6.5 — Pit Boss Full UI & Art Foundation**

After it passes regression testing, resume the gameplay roadmap at 0.4.7.

---

# 0. READ FIRST

Before changing code or scenes, read:

- `res://assets/pit_boss/README.md`
- `res://assets/pit_boss/STYLE_GUIDE.md`
- `res://assets/pit_boss/CODEX_IMPLEMENTATION.md`
- `res://assets/pit_boss/FULL_UI_OVERHAUL_CODEX.md`
- `res://assets/pit_boss/palette.json`
- `res://assets/pit_boss/ASSET_INVENTORY.txt`

Inspect:

- `res://assets/pit_boss/reference/`
- `res://assets/pit_boss/casino_play/reference/`

Those screenshots are STYLE/COMPOSITION REFERENCES ONLY.
Do not use screenshots as runtime backgrounds.

Use the individual SVG/PNG assets.

---

# 1. FIRST INSPECT THE EXISTING GAME

Identify and document before modifying:

- main gameplay scene
- management HUD
- desktop UI
- mobile UI
- build/move mode
- object-selection flow
- guest rendering
- guest thought/status system
- table/slot scenes
- playable blackjack implementation
- playable roulette implementation
- playable craps implementation
- playable slot implementation
- wallet/bankroll systems
- casino cash/profit systems
- pause/time speed controls
- event/notification system
- staff UI
- finance UI
- save/load dependencies

DO NOT assume a concept-screen system exists just because it exists in the reference art.

Use the game's real systems and real values.

---

# 2. CORE VISUAL IDENTITY

Brand visible UI as:

PIT BOSS

Visual language:

- near-black charcoal UI surfaces
- warm brass/gold borders and selected states
- deep burgundy accents
- emerald casino felt
- ivory text
- green positive/economy indicators
- red danger/security indicators
- purple high-roller/jackpot accents
- restrained machine neon

This must feel like a premium management/tycoon game, not a generic mobile gambling app.

Gold indicates importance. Do not make every border bright gold.

---

# 3. GLOBAL GODOT THEME

Create/extend reusable Theme resources.

Prefer reusable:
- Theme
- StyleBoxFlat
- StyleBoxTexture
- SVG icons
- Containers
- reusable scenes/components

Avoid a giant single scene and avoid duplicating styles inline across dozens of controls.

Suggested components:

- PitBossMetricCard
- PitBossNavButton
- PitBossStatusBadge
- PitBossAlertCard
- PitBossInspector
- PitBossBottomSheet
- PitBossModal
- PitBossTooltip
- PitBossGuestMarker
- PitBossPlayHUD
- PitBossBetControls
- PitBossChipSelector
- PitBossCardView

Match the existing project's conventions if equivalent reusable components already exist.

---

# 4. MANAGEMENT VIEW

Upgrade the existing top-down casino management view.

Desktop target:
- top status/metric HUD
- navigation
- casino floor remains dominant
- alert/event surface
- selected-object inspector
- build/furnish selection
- minimap only if current architecture supports it cleanly

Mobile target:
- compact top metrics
- bottom primary navigation
- collapsible inspector bottom sheet
- edge/floating contextual controls
- readable alerts without permanently covering the floor

All values must bind to REAL game state.

Never hardcode concept-art values.

---

# 5. BUILD / MOVE MODE — CRITICAL MOBILE FIX

The current mobile build/move experience must be treated as a regression priority.

Do not allow menus to obscure the grid area needed to place or move objects.

When entering build/move mode:
- collapse nonessential inspector UI
- expose as much floor as possible
- show placement ghost
- show valid/invalid placement clearly
- confirm and cancel must remain reachable
- rotate must remain reachable if supported
- user must be able to pan/zoom/choose cells without the control surface blocking them

Use supplied placement styling where useful.

Desktop and mobile placement behavior must remain logically identical.

---

# 6. GUESTS — KEEP THE DOTS

Do NOT replace world guests with full people.

The dots are part of the intended art direction because hundreds of guests must remain readable.

Compose markers using:
- base dot
- selection/status ring
- role/state
- optional thought/need
- optional special VIP/high-roller marker

Use:
`res://assets/pit_boss/guests/`

Important:
Do not show every status simultaneously.
Priority should determine the visible overlay.

Example priority:
critical event > selected > VIP/high roller > strong mood > current intent

Prepare the rendering architecture for future cosmetic guest customization:
- colors
- accessories
- loyalty tiers
- wealth tiers
- VIP states
- staff roles

Do not tie cosmetic rendering into pathfinding or core AI.

---

# 7. SELECTED OBJECT INSPECTOR

Selecting a table, machine, guest, employee, amenity, etc. should open the new inspector style.

Show only values actually supported by the selected object.

Potential values:
- status
- level
- utilization
- players
- bet size
- revenue
- profit
- condition
- maintenance
- assigned employee
- satisfaction

Potential actions:
- upgrade
- move
- configure
- assign staff
- open/close
- disable

Do not add dead buttons.

Mobile uses bottom sheet.
Desktop may use bottom/right inspector depending on available space.

---

# 8. ALERTS AND EVENTS

Apply the new alert-card visual language to existing events.

Examples:
- VIP arrival
- jackpot
- maintenance
- security
- staffing shortage
- review/complaint
- random event

If event data points to a world object/guest and the game already supports camera focus,
make the card actionable.

Do not invent fake simulation events just to fill UI.

---

# 9. PLAY MODE — THIS IS REQUIRED

The management overhaul is NOT complete unless the first-person/direct gambling views are also
visually overhauled.

When the player chooses to personally play a supported casino game, transition into a focused
PLAY MODE.

Play mode should visually feel like the same product but must NOT keep the full management HUD
covering the game.

At minimum play mode contains:

Top:
- small Pit Boss branding
- Personal Wallet / available player bankroll
- Casino Cash when relevant
- Return to Floor

Center:
- actual game surface

Bottom/edges:
- game-specific wager/action controls

Use:
`res://assets/pit_boss/casino_play/`

---

# 10. BLACKJACK PLAY MODE

Assets:
`res://assets/pit_boss/casino_play/blackjack/`
`res://assets/pit_boss/casino_play/shared/cards/`
`res://assets/pit_boss/casino_play/shared/chips/`

Use the existing blackjack logic.

Create a premium felt-table presentation with:

- dealer hand
- player hand
- chip/bet representation
- wallet/bankroll
- current bet
- Hit
- Stand
- Double
- Split only when existing rules allow it
- Insurance only when the existing rules allow it
- clear win/loss/push feedback
- Return to Floor

Never fake game state to match reference screenshots.

Cards must be dynamically spawned from the provided deck assets.

---

# 11. ROULETTE PLAY MODE

Assets:
`res://assets/pit_boss/casino_play/roulette/`

Preserve existing roulette logic.

Create:
- roulette betting board
- roulette wheel visual
- chip placement
- current bet total
- spin
- clear/remove bets
- winning number/result feedback
- previous-number history if current logic exposes it

Do not bake bet values into the felt.

Bet markers/chips are runtime controls.

---

# 12. CRAPS PLAY MODE

Assets:
`res://assets/pit_boss/casino_play/craps/`

Preserve existing craps rules and dice behavior.

Create:
- dedicated craps felt
- dynamically rendered dice
- betting chips/markers
- roll button
- current point indicator
- current bet display
- result/status messaging
- Return to Floor

Only enable wager regions that correspond to wagers the existing game actually implements.

The provided craps felt is a visual foundation; map click/touch regions in code rather than relying
on pixels as game logic.

---

# 13. SLOT PLAY MODE

Assets:
`res://assets/pit_boss/casino_play/slots/`

Preserve existing slot RNG/payout logic.

Create:
- full slot cabinet/reel presentation
- 3 visible reel windows
- supplied symbol assets
- current bet
- bet +/- controls
- spin
- payout result
- wallet
- win animation

The visual reels must reflect actual RNG results from game logic.
Do not introduce client-side visual RNG separate from the existing result.

---

# 14. PERSONAL WALLET VS CASINO ECONOMY

The player-gambling system must make the distinction visually obvious.

When playing personally, show:

Personal Wallet

separately from:

Casino Cash / House Funds

Never make a player loss look like casino operating loss unless that is actually how the current
economy logic works.

Do not redesign the economy in this UI task unless required to display already-existing values.

---

# 15. RESPONSIVE PLAY MODE

Desktop:
- wide felt/game surface
- compact top HUD
- controls around/below game
- optional right-side context if space allows

Mobile portrait:
- game surface consumes most screen
- compact wallet/header
- touch actions at bottom
- no management navigation while actively gambling except clear Return to Floor
- minimum ~44 logical pixel touch targets

Mobile landscape:
- game surface can sit left/center
- controls on side or bottom
- avoid excessive letterboxing

Use:
`res://assets/pit_boss/casino_play/mobile/mobile_play_chrome.svg`
as a layout asset/reference, not a complete hardcoded screen.

---

# 16. CASINO WORLD ART

The pack contains individually separated top-down starter art for:
- blackjack
- roulette
- craps
- poker
- baccarat
- slots
- bar/lounge
- flooring

Integrate incrementally.

Do not change logical grid footprints because an image is larger.

Sprite size/pivot/collision and build footprint must remain decoupled.

Validate:
- scale
- pivot
- collision
- clickable bounds
- grid occupancy
- zoom readability

---

# 17. FLOORING

Use the supplied tileable textures where appropriate.

Do not create one Sprite2D per floor tile if the current implementation can use a tiled texture,
TileMap/TileMapLayer, shader, or other efficient batching approach.

---

# 18. PERFORMANCE

This pass must not regress long-running simulation performance.

Do not:
- rebuild guest UI every tick
- update unchanged labels every frame
- instantiate/destroy bubbles constantly
- create unique shader materials per guest unnecessarily
- animate every visible entity continuously
- rebuild full lists when one row changed

Pool/reuse transient elements where sensible.

Throttle noncritical UI updates.

Keep simulation update frequency independent from cosmetic refresh frequency when practical.

---

# 19. ANIMATION GUIDELINES

Use subtle:
- panel slide/fade
- button hover
- selection pulse
- jackpot emphasis
- VIP arrival emphasis
- money count transitions
- result presentation

Avoid constant blinking/glowing across the whole screen.

Casino floor animation should be lively.
UI should remain calm and readable.

---

# 20. ASSET IMPORT / GODOT

SVG:
- use as scalable icons where suitable

PNG:
- enable filtering for illustrated tables/slots
- verify mipmaps depending on camera zoom
- preserve transparency

Flooring:
- repeat/tile correctly
- verify seams

Do not import concept screenshots as gameplay textures.

---

# 21. BRANDING

Visible product branding is now:

PIT BOSS

Treat "Neon House" as old prototype branding.

Do NOT blindly rename internal classes, scene files, resources, save keys, project IDs, or namespaces
unless required.

Prefer visual rename first.

Prevent save compatibility regressions caused by unnecessary internal renaming.

---

# 22. TEST MATRIX

Run and inspect the game.

Desktop:
- management view
- build mode
- object selection
- guest selection
- alert interaction
- blackjack play mode
- roulette play mode
- craps play mode
- slots play mode
- return to floor
- resizing/windowed resolution

Mobile portrait:
- management
- build/move
- inspector
- alerts
- each supported playable casino game
- Return to Floor

Mobile landscape:
- management
- play mode
- build/move

Functional regression:
- pause/play/speed
- saving
- loading
- money updates
- staff interactions
- guest simulation
- object placement
- object move
- upgrades
- gambling outcomes
- wallet changes
- casino profit changes

Check debugger output and fix new errors.

---

# 23. IMPLEMENT IN STAGES, BUT COMPLETE THE FULL PASS

Use logical commits/steps internally:

1. Theme/components
2. Desktop management HUD
3. Mobile management HUD
4. Guest marker system
5. Object inspector
6. Build UI
7. Alerts/events
8. World art integration
9. Shared play-mode framework
10. Blackjack
11. Roulette
12. Craps
13. Slots
14. Responsive polish
15. performance/regression fixes

Do not stop after creating mockups.

The actual existing game must use the new UI.

---

# 24. FINAL REPORT

When complete, summarize:

- scenes created
- scripts created
- assets integrated
- existing files modified
- desktop behavior
- mobile behavior
- play-mode behavior
- guest-marker architecture
- performance changes
- tests performed
- unresolved issues
- visual assets that still need manual/art-direction cleanup

The desired final result is one cohesive game:

MANAGE THE HOUSE
→ select a game
→ SIT DOWN AND PLAY
→ return immediately to MANAGING THE FLOOR

with one consistent Pit Boss visual identity.
