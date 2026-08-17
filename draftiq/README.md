# Draft IQ v3

Vanilla HTML/CSS/JavaScript League of Legends learning mini-games.

## What's new in v3: League Academy

League Academy is a guided quiz mode with 32 starter lessons across:

- League terminology
- Items and build-order decisions
- Champion abilities and counterplay
- Macro, waves, vision, and objectives

The mode includes category filters, difficulty-based lesson pools, detailed answer explanations, topic mastery, a focused “Review missed” deck, and progress saved in `localStorage`.

Item questions intentionally teach decision frameworks rather than claiming one fixed six-item build is correct in every patch and matchup. New lessons can be added to the `quizQuestions` array in `app.js` using the same data shape as the existing questions.

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

The app currently points at Data Dragon version:

`16.16.1`

The portrait URL pattern is:

`https://ddragon.leagueoflegends.com/cdn/16.16.1/img/champion/{ChampionId}.png`

If a future patch removes that version or you want newer art, update `DDRAGON_VERSION` at the top of `app.js`.

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

`http://localhost:8080`

## Suggested next ideas

- Pull the entire champion roster automatically from Data Dragon.
- Add Riot role icons.
- Add champion search / "my champion pool."
- Add a "What is our win condition?" game.
- Add "Who is the biggest threat?" rounds.
- Add "Build the last two picks" multi-step draft puzzles.
- Add a full ban phase.
- Extend settings persistence to the selected mode and difficulty.
- Add adaptive difficulty that automatically changes based on weak concepts.
- Optionally ingest a live-patch matchup data source for a separate **Meta Counter** mode.
- Split the Academy question library into its own data file as it grows.
- Add champion and role-specific learning paths.
- Add current-patch item and rune lessons generated from Riot's static data.
