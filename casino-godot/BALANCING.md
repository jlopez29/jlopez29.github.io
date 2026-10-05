# Prototype balance

Defaults live in `scripts/tuning.gd`; the table's $25/$50 limit is configurable in
its inspector while empty. This is compressed test-session balancing, not a
forecast of real casino finances.

| Value | Initial setting |
|---|---|
| Starting casino cash | Normal $2,500 + two slots; Easy $30,000 + chosen games and crews |
| Visitor wallet | $1,000, independent from house funds |
| Craps / resale | $6,000 / $3,000; two dealers required |
| Staff onboarding | $150 per employee |
| Dealer / service wage | $20 / $16 per game hour |
| Table / slot overhead | $12 / $1 per game hour, including closed games |
| Required crew / seats | 2 dealers / 7 public players + owner rail position |
| Game time | 1 minute per real second at 1× |
| Dice interval | 6 game minutes; 15 while visitor is seated, plus fatigue |
| Guest arrival | Parties of 1–2; 18–32 game minutes evening, otherwise 28–48 |
| Observation | 65% consider watching first; watch 12–24 game minutes, then decide |
| Crowd control | Arrivals ease off with waiting/browsing guests; floor target 7 per operating table + 3 |
| Guest bankroll | $400–$1,500; VIP $5,000 |
| Guest wager | Table minimum; VIP 4× minimum |
| Guest cap | 40 |
| VIP arrival | 5% of ordinary arrivals; no separate stream |
| Rail incident / repair | 3 operating days grace, then 8% daily chance per operating table / $120 |
| Service complaint / comp | Every 70 minutes with no service staff / $60 |

Pass Line has a 1.414% theoretical house edge. Short-term actual cash can swing
substantially. Odds pay true odds; Place 6/8 pay 7:6; Field pays double 2/triple 12.
No fixed timer grants income: revenue comes from bets and payouts from dice.
Staff/overhead accrue while the game clock runs. Build and training costs are
charged as cash expenses. Treasury should equal starting cash plus lifetime cash
result; settled profit also removes outstanding bet liabilities.

Service drains thirst, improving satisfaction; ignored complaints damage
reputation. Dealer energy falls while working, slowing table throughput. Standby
staff recover and can relieve tired dealers. Early playtests should watch whether
these pressures are understandable and whether variance makes expansion feel
interesting rather than arbitrary. Normal V0.3 access uses earned Casino Rating; Easy has unrestricted access.

Repair wear resets after repair. The grace period and daily chance are playtest
settings, not measured real-world failure rates.

The first party arrives after 10 open game minutes. Arrival gaps pause while
closed and persist in saves. Spectators do not reserve seats or place bets; up to
three watch each table. Some favor a long hand, others a new shooter, and some
are casual. These preferences change joining decisions only, never dice odds.
Observers decide even when no dice are rolling, so an empty table can get started.

Service employees automatically cover all guests. They lose 0.13 energy per game
minute while guests are present and recover 0.5 per minute on an empty floor,
within the existing 15–100 energy bounds. Their drink-service effect remains
headcount-based; service energy does not yet change delivery effectiveness.

## Additional games

Purchase costs: slots $750, blackjack $1,800, roulette $2,500, craps $6,000, Ultimate Hold’em
$8,000. Slots require no dealer; each new table game requires one. Slots have a
$5 minimum and other new games $10. Reel weights are 6/5/4/3/2 out of 20 stops;
the current one-line slot returns 91.725% theoretically. These prices and guest
strategies are initial playtest tuning. Cage labels show individual gaming
profit, not profit after operating expenses.

## V0.3 progression

Normal starts closed, with two $5 slots, no employees and a smaller placement
area. Easy includes one of each selected game, required crews, the expanded
floor and VIP/high-limit access; equipment is included in its $30,000 start.
Casino Rating earns 0.08 per played guest round with satisfaction at least 65.
Visitor play earns no Rating. Rating never changes game probabilities or payouts.
Slot rounds take two game minutes to support the starter business with low upkeep.
Other non-craps guest games take six minutes per round to support staffed progression.

Normal access thresholds: blackjack 8, drink service 14, roulette 28, expansion
35, craps 45, VIP 55, high-limit 70, UTH 75. Content reveals six Rating points
before access. Stars begin at 0 / 8 / 28 / 75 / 100; five-star content is deferred.
Expansion costs $3,000, VIP access $2,500 and high-limit capability $3,500.
Craps uses a 230×130 footprint; other tables use 190×100.
High-limit access allows $50 table minimums; ordinary new table games use
$10/$25 and craps $25. Only the current save schema is supported during pre-alpha.
Service complaints and thirst dissatisfaction begin when service unlocks.
The opening revenue objective is $100 in guest wagers, distinct from profit.
These are initial progression settings awaiting playtesting, with Normal the
primary balance target. Full bar economics remain deferred.
