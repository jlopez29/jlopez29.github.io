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
| Guest bankroll | Normal starter $40–$140; developed property $100–$300 / $250–$700 / $400–$1,500; VIP $5,000 |
| Guest wager | Minimum, capped by guest budget and machine/game maximum; starter max $5 |
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

Purchase costs: starter slots $750, blackjack $1,800, roulette $2,500, craps $6,000,
Ultimate Hold’em $8,000. Slots require no dealer; new table games require one.
Starter slots open at $5, can be set to $2, and accept at most $5, including owner
and VIP play. Table base wagers are capped at $100 (roulette: total layout;
craps: per bet, subject to its existing odds limit). Blackjack double/split and
Hold’em raises remain additional funded stakes under their rules.

Starter reels retain weights 6/5/4/3/2 out of 20. Triple returns are 7/10/16/22/30×,
including stake. Two cherries, or exactly one cherry on reel one, return 1×.
The exact return is `(216*7 + 125*10 + 64*16 + 27*22 + 8*30 + 2688) / 8000`
= **91.35% RTP / 8.65% theoretical house edge**. A 30× top award has probability
1/1,000 and returns at most $150. Standard deviation of the return is about
2.64 wagers; variance remains real, with no treasury-dependent outcomes.
At a $5 wager, expected gaming win is $0.4325 per spin before overhead.
Starting cash remains $2,500. Wins and losing sessions are legitimate.

Slot economics live in a per-machine profile: cost, denominations, payout math,
RTP/edge, volatility, top-award probability, development value, throughput,
maintenance, reliability and appeal. Only the starter profile exists. Future
profiles can have greater development value without requiring extra cheap units.
Game rules for table payouts remain in `casino_games.gd` and `craps.gd`.

## V0.3 Step 01.5 progression

Normal starts closed with two slots, no staff and a small placement area.
Easy retains unrestricted game access, chosen games/crews and $30,000.

Reputation measures guest perception. Development Rating measures owned gaming
value and upgrades, supported by settled guest handle and actual gamblers served.
Activity contributions are capped by property development. Two starter slots
start at Rating 4 and top out at 8 even with excellent reputation or endless play.
Starter slot development contribution caps at four points, so cheap-machine spam
cannot substitute for later property improvements. Table-game categories count
once; service and purchased property upgrades add development value.

Blackjack access requires all of:

- Rating 16, at least four usable gaming development points and three usable seats.
- $12,000 settled guest handle and 80 departing guests who actually gambled.
- $2,450 available operating cash, excluding pending stakes and net owner gambling
  losses transferred to the casino.

Today, four starter slots satisfy the floor requirement; a future higher-value
profile could satisfy it with three machines. No tier is implemented. Buying the
two additional starter machines costs $1,500, leaving $1,000 before operations;
this makes earning back a reserve part of the climb. There is no time gate.
At the $12,000 handle minimum, theoretical gaming win is $1,038 before overhead,
so cash readiness will commonly require further operation. This is a balance
expectation, not guaranteed income or a measured playtest result.

Unlock is retained once earned and never forces a purchase. At the $2,450 cash
threshold, a $1,800 table and $150 dealer leave $500. The suggested reserve is
$650 (full setup target $2,600), covering several payroll/overhead hours plus
payout exposure. Unlock therefore approaches readiness; saving further is useful.
The next-unlock display shows floor, seats, settled handle, served gamblers,
Rating and operating funds without displaying the Rating formula.

4× advances the same operations faster in real-world time; it never changes
requirements, wager limits or outcome probabilities. Idling the original two
slots cannot unlock Blackjack. Closed time earns no guest accomplishments and
still incurs overhead/payroll. Ordinary guest bankroll/wager budgets increase
at development Ratings 16 / 28 / 55; starter exposure stays capped even then.

Access Ratings: Blackjack 16 plus requirements, service 20, roulette 28,
expansion 35, craps 45, VIP 55, high limit 70, UTH 75. Later Normal access also
requires the Blackjack accomplishment. Stars start at 0 / 16 / 28 / 75 / 100.
Service thirst/complaints start only once service is accessible.

Settlement records total debited stakes and returns including stake, exactly
once. Cash-out presentation reports previously settled results and never moves
house money again. Non-gamblers leave directly without a cage profit display or
served credit. Unresolved craps rolls do not count as settled gaming activity.
Schema 5 saves include machine profiles, settled handle, served gamblers and
earned Blackjack access; development saves have no migration path.

Manual playtest at both 1× and 4×: start fresh Normal, compare two-slot idling
with staged capacity purchases, watch wins and treasury swings, record all
Blackjack accomplishments and cash on unlock, then buy/onboard only when ready.
Check paused/closed behavior, owner play exclusion, non-gambler exits, payout vs
cash-out reconciliation and current-schema save/load. Timing and sustainable
throughput still need manual validation. Step 02 and slot tiers remain deferred.
