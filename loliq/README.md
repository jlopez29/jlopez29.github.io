# LoL IQ v6

Vanilla HTML/CSS/JavaScript League of Legends learning mini-games.

## What's new in v6: Matchup Lab

Matchup Lab is a separate enemy-scouting game covering the complete current champion roster. It loads Riot's versioned champion definitions and generates a deep lesson deck for every champion:

- passive, Q, W, E, and R recognition;
- ability-slot, resource, and base-cooldown recall;
- melee, short-range, and ranged threat expectations;
- crowd-control, mobility, sustain, shielding, and stealth reads;
- counterplay plans based on the opponent's actual kit and archetype;
- adaptive armor, magic resistance, health, anti-heal, tenacity, cleanse, spell-shield, and stasis logic.

Players can rotate through the full roster or focus one opponent, filter by lesson type, and choose guided, applied, or expert difficulty. Every answer unlocks a full scouting report with all five ability cards and a tactical summary. Per-question and per-champion progress is saved locally and Matchup Lab contributes to the shared score, streak, XP, missions, and badges.

Akali's Fleet Footwork lane intent and Nasus's stacking/ultimate windows are included as reviewed spotlight scenarios. Build prompts teach conditional decisions rather than fixed six-item prescriptions, and patch-sensitive strategy is labeled separately from live Riot ability data.

## What's new in v5: Focused game flow

LoL IQ uses a three-step flow: choose a queue, configure the run in a ready-check screen, then play in a distraction-free game view. Difficulty, League Academy path, champion focus, topic selection, and mastery no longer stack above every question.

Once a run starts, its configuration moves into a slide-in settings drawer. The active view keeps only a compact score/streak/round HUD and the game itself. Page transitions, round entrances, choices, correct/wrong feedback, rewards, and the settings drawer now share one responsive motion system with a reduced-motion fallback.

The training grounds also have a redesigned hero, stronger game tiles, and a compact progression display.

## What's new in v5.1: Deeper champion and matchup training

League Academy now contains 78 lessons. Akali has 18 focused lessons, Ahri has a complete 12-lesson path, and a dedicated **Runes & matchups** category teaches how to choose sustain, burst, extended-fight, resistance, penetration, and defensive options for the situation rather than copying one build blindly.

The terminology library now explicitly covers dives, ganks, roams, all-ins, trades, kiting, breaking a freeze, and early stacked-wave recalls. Team Comp has 12 scenarios and Counter Pick has 13.

Patch-sensitive lessons show the patch on which they were last reviewed. Riot's public Data Dragon version list is checked at runtime so champion artwork follows the newest available static-data release. Strategy guidance remains separately review-stamped because Data Dragon contains game definitions and assets, not live matchup recommendations.

Patch-aware additions are kept in `curriculum-expansion.js`, making them easier to audit after balance changes without touching the game engine.

## From v4: Minigame hub and champion paths

LoL IQ opens on a dedicated tile-based hub. Team Comp, Counter Pick, and League Academy each have their own entry card and return-to-hub flow instead of being packed into one mode switcher.

League Academy now supports two learning paths:

- **All questions** mixes the entire knowledge library.
- **Champion main** filters the curriculum to Akali or Ahri, with matchup plans, rune logic, adaptive items, ability interactions, wave control, roams, and teamfight access.

Champion paths are data-driven through the optional `focus` field on a quiz question, so additional mains can be added without creating another quiz system.

## League Academy

League Academy is a guided quiz mode with 78 lessons across:

- League terminology
- Items and build-order decisions
- Champion abilities and counterplay
- Macro, waves, vision, and objectives
- Runes, matchup plans, and adaptive itemization

The mode includes category filters, difficulty-based lesson pools, detailed answer explanations, topic mastery, a focused “Review missed” deck, and progress saved in `localStorage`.

Item questions intentionally teach decision frameworks rather than claiming one fixed six-item build is correct in every patch and matchup. Patch-aware additions can be added to `curriculum-expansion.js` using the same question data shape.

## Shared progression

All three game modes now feed one persistent progression system:

- XP, player levels, and rank titles
- Score multipliers at 3, 5, and 8-answer streaks
- Difficulty-scaled XP rewards
- Repeatable five-round missions that award bonus XP for four correct answers
- Eight persistent badges for streaks, mode mastery, missions, and levels
- Reward summaries, unlock toasts, level-up feedback, and mobile-friendly progress displays

Score, XP, missions, best streak, mode totals, and badges are saved in `localStorage`. Switching modes keeps the active combo so exploring another mini-game does not end a run.

## Also included from v2

### 1. Difficulty levels

**Easy**
- Shows team needs.
- Shows enemy draft threats.
- Shows champion descriptions.
- Counter-pick mode gives a direct conceptual clue.

**Medium**
- Hides explicit team needs and enemy threat labels.
- Hides choice descriptions.
- Gives one general drafting / matchup hint.

**Hard**
- No need labels.
- No threat labels.
- No choice descriptions.
- No counter clue.
- You have to read the draft yourself.

### 2. Riot champion portraits

Champion portraits are loaded directly from Riot Games' Data Dragon CDN.

The app uses this Data Dragon version as an offline fallback:

`16.16.1`

The portrait URL pattern is:

`https://ddragon.leagueoflegends.com/cdn/16.16.1/img/champion/{ChampionId}.png`

At runtime the app checks Riot's public `versions.json` and uses the newest available release. If that request fails, it keeps the fallback version above.

### 3. Counter Pick mode

The app assigns a role, shows:
- five bans for each team,
- the enemy champion lock,
- your role,
- five possible counter picks.

After answering it explains:
- what the enemy champion wants to do,
- why your answer does or doesn't attack that pattern,
- the intended counter pick,
- the broader matchup lesson.

The initial scenarios intentionally focus on **mechanics-based counters** rather than live-patch win-rate data.

Examples:
- Quinn into Darius — range / kiting an immobile juggernaut.
- Malphite into Fiora — armor / attack-speed disruption.
- Rammus into Master Yi — armor + taunt into an auto-attack carry.
- Poppy into Lee Sin — dash denial.
- Galio into Katarina — durable anti-dive + reliable CC.
- Lissandra into Zed — targeted lockdown + self-protection.
- Xayah into Samira — self-peel into committed dive.
- Caitlyn into Draven — range and lane-space control.
- Morgana into Blitzcrank — crowd-control denial.
- Janna into Leona — disengage after a committed engage.

## Running locally

You can simply open `index.html`.

For a local web server:

```bash
python -m http.server 8080
```

Then browse to:

`http://localhost:8080/loliq/`

Each ready-check can also be opened directly:

- `http://localhost:8080/loliq/?game=comp`
- `http://localhost:8080/loliq/?game=counter`
- `http://localhost:8080/loliq/?game=quiz`
- `http://localhost:8080/loliq/?game=matchup`

## Suggested next ideas

- Pull the entire champion roster automatically from Data Dragon.
- Add Riot role icons.
- Expand the champion selector into a searchable "my champion pool."
- Add a "What is our win condition?" game.
- Add "Who is the biggest threat?" rounds.
- Add "Build the last two picks" multi-step draft puzzles.
- Add a full ban phase.
- Extend settings persistence to the selected mode and difficulty.
- Add adaptive difficulty that automatically changes based on weak concepts.
- Optionally ingest a live-patch matchup data source for a separate **Meta Counter** mode.
- Split the Academy question library into its own data file as it grows.
- Add more champion and role-specific learning paths beyond Akali and Ahri.
- Add a small server-side Match-v5 aggregation job for reviewed meta snapshots without exposing a Riot API key in the GitHub Pages frontend.
