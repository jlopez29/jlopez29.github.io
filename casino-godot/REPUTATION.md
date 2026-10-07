# Early-game reputation investigation

Reputation measures the delivered experience. Rating measures development,
variety and sophistication. A small advertised offering is not bad service.

## Original cause

The reproduction has two independent demand-accounting defects, not an absent-bar
penalty:

- `choose_table()` called `mark_unmet_demand()` when no game was affordable,
  including after a real gambler exhausted their bankroll. `finish_guest_session()`
  could send that guest exploring, then back into this queue instead of finishing
  the visit. Repeated retries counted as severe affordability departures.
- `leave()` classified any blocked capacity/affordability departure with enough
  waiting and retries as severe, regardless of satisfaction, development or the
  player's practical ability to expand. Three such departures caused a -0.3
  Normal reputation review. Securing a seat cleared `demand_blocked`, but retained
  cumulative wait/attempt counters for later sessions.

A recorded loss occurred with two working occupied slots, desired game `slots`,
27 completed guest rounds, satisfaction 78.35 and no affordable game left for
that guest. The loss came from `traffic.long_wait_review`, not drink service.
Other guests lost reputation for waiting behind a healthy tiny offering.

Instrumented original logic, three seeds, five game days each, with the same
0.1-second movement slices/minute steps used by developer 1000x:

| Seed | Final reputation (started at 60) | Negative demand reviews |
| --- | ---: | ---: |
| 321 | 60.35 | 14 |
| 17 | 58.42 | 17 |
| 2026 | 59.56 | 14 |

Positive visits sometimes offset the bleed. Seeds 17 and 2026 also developed
unrepaired breakdowns later in these unattended runs; those are legitimate
operational problems. False losses already occurred before breakdowns.

## Corrected behavior

- Separate a guest's ability to fund an owned game from whether it is operating.
  Bankroll exhaustion/budget mismatch ends the visit normally, without creating
  unmet-demand retries. Only guests with a fundable owned game enter the queue.
- Current game interest follows owned games. Latent preferences remain intact;
  missing/unlocked-but-unpurchased games do not become service failures. Existing
  Rating-based archetype/budget selection still scales arrivals with development.
- Successful seat reservation resets the current queue's wait and retry budgets.
  A separate visit flag keeps unmet-visit analytics from counting retries twice.
- Ordinary crowding has a finite patience budget but does not reduce satisfaction.
  Separately count consecutive minutes of actionable game-access failure. Only
  sustained failures reduce satisfaction or contribute severe demand reviews.
- Broken equipment or inadequate coverage of an owned, fundable game is actionable
  when another suitable free seat cannot meet the demand.
- Capacity becomes actionable on a developed floor (at least four usable gaming
  development points), with enough development cash to buy another used slot and
  preserve the reserve report's operating/payout buffer, and room to place it.
  Two starter reels stay below this development threshold. These checks use real
  capability and finances, never casino age. Brief crowding remains tolerated.
- Negative visit reviews require an actual operational/drink-service failure.
  Happy completed gambling visits retain the existing gradual positive review.
  Unplayed arrivals and neutral browsing/queue exits cannot manufacture bonuses.

Gambling probabilities, paytables, settlement and bankroll accounting are unchanged.
Guest lifecycle fixes change later guest decisions and therefore subsequent RNG
consumption; identical seed histories are not expected across the behavior change.

## Diagnostics

All gameplay reputation changes go through `change_reputation()`, including guest
reviews, demand reviews, incident decisions and optional-event outcomes. Every
negative request emits `reputation_loss`, retains the latest 128 records in
`recent_reputation_losses`, and prints `REPUTATION_LOSS` JSON in debug builds.
Snapshots are taken before departure releases the guest/seat and contain source,
guest ID/satisfaction/state, departure classification and text, current desired
game, available and affordable games, occupied/available capacity, per-asset
condition/minimum/occupancy, reputation before/requested delta/applied delta/after,
bankroll, queue counters, operational/drink failure, Rating, cash and game minute.
Non-guest decisions use ID -1 and N/A/null for guest-only fields. Diagnostics are
transient, bounded and outside House Activity; they do not consume RNG.

## Focused verification

Run the Godot binary with matching project version:

```
godot --headless --path casino-godot --script res://tests/test_reputation.gd
```

The fresh-Normal runs purchase no assets/bar, hire nobody and use no owner play.
Routine repairs use the normal paid repair action if needed. After five game days:

| Seed | Reputation | Negative reviews | Guest rounds |
| --- | ---: | ---: | ---: |
| 321 | 66.66 | 0 | 5,825 |
| 17 | 68.10 | 0 | 5,627 |
| 2026 | 67.92 | 0 | 5,700 |

Additional focused checks cover bounded neutral starter queues, bankroll exits,
current save/load, broken machines (the initial correction measured 60 to 59.1 in one game day), preventable
capacity on a developed funded floor, thin reserves, disabled owned-table
coverage, actual service failure with a dissatisfied guest, and incident/event
loss instrumentation. Capacity and coverage fixtures prepare specific operating
states; the three fresh-game runs use the real minute/movement/settlement loop.

Manual checks: start fresh Normal in the debug build, open and select F10/1000x;
run several days without purchases, resolving real breakdowns. Confirm stable or
gradually improving reputation and finite neutral queue exits. Then leave machines
unrepaired; later with a developed floor and adequate reserves, leave repeated
capacity/coverage problems unresolved. Inspect `REPUTATION_LOSS` console records.
Confirm genuine happy visits improve perception and that save/load still works.

## Repair demand follow-up

An unresolved repair now has immediate, demand-backed reputation consequences.
A guest who can fund the broken game, but cannot get another suitable working
seat, waits near that asset. After eight consecutive blocked minutes, each actual
frustrated guest-minute costs 0.02 reputation on Normal (Easy uses its existing
reputation-loss multiplier) and 0.5 satisfaction. `repair.waiting_guest` diagnostics
identify the guest and `repair_wait_table`. Healthy visit gains are withheld only
while real repair-blocked frustration is active, so they cannot mask the warning.
Repair frustration uses this ongoing penalty rather than also charging the
aggregate bad-demand departure review. Separate service failures remain accountable.

Repairing the asset or providing a suitable free working seat stops the pressure.
An unattended broken asset without blocked guest demand is neutral. Ordinary
starter crowding remains neutral. The broken asset pulses a red circle, its
waiting guests show frustrated moods, and floor asset names/status captions have
been removed; inspectors retain the useful identity and repair action.

Manual follow-up: leave one of the two starter machines broken and the other
working. Observe real waiting guests around the broken machine, repair-specific
thoughts/moods and declining reputation once waiting persists. Repair it and
confirm the ring clears, guests return to play and happy visits can improve
reputation again. Check desktop and both mobile orientations, including selecting
a broken asset to repair through its inspector.

The one-broken/one-working reproduction was run for one game day, then the
normal paid repair was applied and operation continued for another game day:

| Seed | Before | After one day broken | After another day repaired |
| --- | ---: | ---: | ---: |
| 321 | 60 | 53.16 | 54.67 |
| 17 | 60 | 55.10 | 56.54 |
| 2026 | 60 | 58.20 | 60.18 |

The existing 55 focused reputation checks passed after the repair-demand change.
