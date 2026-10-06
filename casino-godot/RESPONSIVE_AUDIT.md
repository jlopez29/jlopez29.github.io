# Neon House 0.4 — Phase 04.2.5 responsive audit

Source changes completed. This pass changes presentation, navigation, and pointer handling. Simulation rules, economy, progression requirements, property dimensions, and asset footprints are unchanged. Phase 04.3 is not implemented.

## State and transition rules

| State | Primary surface | Transition behavior |
| --- | --- | --- |
| Normal management | Floor, contextual inspector, or explicitly opened management/log pane | Floor preserves selection; Table restores the selected asset/guest inspector. |
| Build / Move | Floor with contextual placement hint, Rotate, and Cancel | Move implies Build; refresh and resize prioritize Floor. Explicit navigation to another pane cancels placement. Floor navigation preserves placement. |
| Walk | Floor on entry | Explicit management navigation remains available and preserves visitor state. The contextual Manage action ends walking. |
| Joined game | Game surface; craps options may overlay it | Join/Leave retain their existing gameplay checks. Orientation preserves the joined table. |
| Management page | Inspector viewport | Page and disclosure state survive viewport changes. Opening an asset page clears stale guest context. |

`requires_floor_targeting()`, `normalize_interaction_ui()`, and `transition_pane()` own the shared policy. Future floor-targeting modes can extend this policy without changing every button. Responsive rows and grids measure their content instead of assuming desktop columns fit.

## Completion report

1. **UI issues discovered:** Move left the inspector over the mobile floor; placement lacked a floor-level Cancel; pointer-down placement could commit during a drag; orientation reset camera focus; fixed action/category rows could crush controls; narrow game surfaces scaled wager controls and totals.
2. **Root causes:** Independent pane and interaction flags, per-action visibility assignments, pointer handling that distinguished drag only in normal close view, orientation-specific camera resets, and fixed container columns.
3. **Architecture:** Shared pane transition and visibility invariants; reusable content-driven action rows and grids. Existing Finance reflow remains in place.
4. **Placement / Move:** Build and Move expose the floor, Rotate, Cancel, and a short hint. Invalid placement retains the mode. Valid placement completes it. Explicit navigation away cancels it. Selling clears asset/guest selection and returns to Floor. Move is disabled while walking.
5. **Floor interaction:** Tap commits on release; drag suppresses selection/placement and permits panning during placement. Existing furniture/guest touch priority is retained. Expanded left, right, and bottom targets were checked after camera settling. Fit/Closer remains available in normal floor mode.
6. **Navigation:** Inspector, Finance, Log, and Manage return predictably to Floor. Floor preserves an active placement; other panes end it. Guest context is retained for the Table tab and cleared when explicitly opening an asset or completing a new build.
7. **Finance:** Existing atomic value labels and Finance reflow passed runtime width checks, including signed values +$4,405, -$2,056, and $24,934. Categories, reserve, asset comparison, bar product detail, and advanced accounting were exercised in native UI checks. Browser Finance screenshots were visually inspected at portrait and landscape widths.
8. **Drink menu:** Active/available tabs, expanded products, add/drop, pricing, and product-performance presentation were exercised through native controllers and simulation actions. Shared row reflow applies to the menu. Drink economics are unchanged.
9. **Expansion:** Dimensions, cost, and upkeep use the existing atomic metric rows. All three directional purchases and access to their new property were exercised. The limit-state branch was source-inspected; purchases were tested below the limit.
10. **Staffing:** Role summaries, coverage metrics, hiring, and employee disclosure fit the viewport matrix. Shared row reflow covers relief and service-position controls. Active/Relief/Break/Off Duty text and staffing priority/pause/resume handlers were source-inspected; a complete live fatigue cycle was not run.
11. **Game interfaces:** Native checks exercised joining, wagering, settlement, and leaving slots, blackjack, roulette, craps, and Hold'em, plus craps options/categories. Narrow blackjack/Hold'em now have full-size wager buttons; narrow game totals remain readable. Game rules are unchanged. Full game gesture sequences were not browser-automated.
12. **Portrait:** Checked 360x780, 390x844, and 480x900; placement, navigation, Finance, and debug controls are usable in the tested flows.
13. **Landscape:** Checked 844x390. Management uses a scrollable primary viewport; placement controls remain accessible. Closer and Walk camera zoom use available width.
14. **Orientation:** Native and browser checks covered state retention across portrait/landscape changes, including Move, Walk, inspectors, management, and joined games. Camera focus is no longer reset by orientation.
15. **Desktop / compact:** Checked 1024x768 and 1440x900, including inspectors, placement, management, and game layouts. Desktop retains its separate floor and inspector arrangement.
16. **Files changed:** `scripts/main.gd`, `floor.gd`, `game_view.gd`, `developer_panel.gd`, new `responsive_row.gd` and `responsive_grid.gd` plus their Godot UID files, generated `build_info.gd`, root `AGENTS.md`, this report, and normally generated web exports. `finance_layout.gd` and `craps_layout.gd` were audited without source changes.
17. **Tooling:** Temporary native Godot scripts: 2,038 responsive checks, 204 action checks, and 87 final checks passed. Temporary Playwright browser scripts: 114 matrix interaction checks and 22 final checks passed with no browser errors. Browser clicks used touch emulation; floor drag checks also used mouse input. Source and screenshots were visually inspected. No permanent test framework was added. Existing debug browser observations were extended with UI state, geometry, and label widths; developer buttons participate in the existing debug button snapshot.
18. **AGENTS.md:** Added one rule requiring floor-targeting priority, centralized visibility/transition invariants, and orientation state preservation. No duplicate rule was added.
19. **Build/export: SUCCESS.** Used Godot 4.7.2 and matching templates with `export_web.py --both`; final export log contained no script/build errors.
20. **casino/ updated: YES.** Regenerated through the normal release export.
21. **casino-debug/ updated: YES.** Regenerated through the normal debug export. This directory remains gitignored. Final browser release check confirmed debug observations were absent; release/debug UI was visually inspected.
22. **Remaining known issues / verification limits:** No unresolved defect reproduced in the completed checks. Physical-device touch, browser chrome/safe-area behavior, a full staffing fatigue cycle, maximum-property limit presentation, and every casino-game gesture combination still need manual confirmation. These are limits of the audit, not claims of verified behavior.

## Manual gameplay checks

- On a phone, move a slot and a table: rotate, drag/pan, attempt invalid placement, place successfully, and cancel. Rotate the device mid-move.
- Expand left/right/bottom, use Closer and pan to each new edge, then place equipment there.
- Scroll expanded Finance, drink product/performance, staffing details, and incidents; check bottom actions and signed money values.
- Play each game, especially craps chip dragging/flicking and roulette seams; rotate mid-hand and leave after settlement.
- In debug, try DEV funding, spawning, Rating, Advance/Force Unlock, and extreme speeds; close the panel and return to normal play. Confirm the release has no DEV control.
