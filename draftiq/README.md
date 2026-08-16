# Draft IQ v2

Vanilla HTML/CSS/JavaScript League of Legends learning mini-games.

## What's new in v2

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

## Suggested v3 ideas

- Pull the entire champion roster automatically from Data Dragon.
- Add Riot role icons.
- Add champion search / "my champion pool."
- Add a "What is our win condition?" game.
- Add "Who is the biggest threat?" rounds.
- Add "Build the last two picks" multi-step draft puzzles.
- Add a full ban phase.
- Add localStorage for persistent score, streak, difficulty and mastery.
- Track concepts the player misses (e.g. peel, damage balance, anti-dive).
- Add adaptive difficulty based on weak concepts.
- Optionally ingest a live-patch matchup data source for a separate **Meta Counter** mode.
