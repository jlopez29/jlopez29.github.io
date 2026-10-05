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
| Dice interval | NPC 0.30-0.47 game minutes with fatigue; visitor rail retains 15 minutes + fatigue |
| Guest arrival | Parties of 1–2; 18–32 game minutes evening, otherwise 28–48 |
| Observation | 65% consider watching first; watch 12–24 game minutes, then decide |
| Crowd control | Arrivals ease off with waiting/browsing guests; actual usable positions plus 25% overflow (at least one); slots have one position |
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
Ultimate Hold’em $8,000. Slots require no dealer; new table games require one. NPC Blackjack/roulette/UTH now resolve every two game minutes.
New roulette/UTH tables open at $25; Blackjack remains $10. Their selectable
$10/$25/$50 limits remain available subject to existing high-limit access.
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
maintenance, reliability and appeal. Phase 03 profiles add greater development value without requiring extra cheap units.
RTP, edge, top-award probability and return standard deviation are derived from
the fixed reel weights and total-return paytable; presentation does not supply odds.
Game rules for table payouts remain in `casino_games.gd` and `craps.gd`.

## V0.3 Step 01.5 progression

Normal starts closed with two slots, no staff and a small placement area.
Easy retains unrestricted game access, chosen games/crews and $30,000.

Reputation measures guest perception. Development Rating measures owned gaming
value and upgrades, supported by settled guest handle and actual gamblers served.
Activity contributions are capped by property development. Two starter slots
start at Rating 4 and top out at 8 even with excellent reputation or endless play.
Used-slot development contribution caps at three points, so cheap-machine spam
cannot satisfy Blackjack's four-point usable floor requirement. Other profiles
have separate caps and the developed slot floor caps at 30 points; an established
slot-only property can reach Rating 100 without buying table games. Table-game categories count
once; service and purchased property upgrades add development value.

Blackjack access requires all of:

- Rating 16, at least four usable gaming development points and three usable seats.
- $12,000 settled guest handle and 80 departing guests who actually gambled.
- $2,450 available operating cash, excluding pending stakes and net owner gambling
  losses transferred to the casino.

Two original used machines plus one standard reel supply four development points
and three seats. Four used machines only supply three points. A standard purchase
costs $1,400, leaving $1,100 before operations; earning back a reserve remains part
of the climb. Video access can be earned before Blackjack; neither purchase is
forced. The existing guest handle, served, Rating and reserve requirements remain.

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
Schema 7 saves include separate expense categories and payroll allocations, machine profiles,
retained tier access, asset payroll and settled visitor-house results, as well as asset operating/
occupied/downtime minutes, upkeep/repair spending and repair/breakdown counts,
settled handle, served gamblers and earned Blackjack access; development saves have no migration path.

Manual playtest at both 1× and 4×: start fresh Normal, compare two-slot idling
with staged capacity purchases, watch wins and treasury swings, record all
Blackjack accomplishments and cash on unlock, then buy/onboard only when ready.
Check paused/closed behavior, owner play exclusion, non-gambler exits, payout vs
cash-out reconciliation and current-schema save/load. Timing and sustainable
throughput still need manual validation. Phase 02 asset-linked net feedback continues unchanged.

## V0.3 Phase 03 machine economy

| Machine | Price | Selectable stakes | RTP / house edge | Volatility | Development / tier cap | Upkeep/hr | Repair | Daily failure chance after operating grace |
| --- | ---: | --- | --- | --- | --- | ---: | ---: | --- |
| Used Classic Reel | $750 | $2 / $5 (opens at $5) | 91.35% / 8.65% | Low | 1 / 3 | $1 | $120 | 10% after 3 days |
| Standard Reel | $1,400 | $2 / $5 / $10 (opens at $5) | 93.75% / 6.25% | Low | 2 / 6 | $1.50 | $150 | 7% after 4 days |
| Video Slot | $3,200 | $5 / $10 / $20 (opens at $5) | 94.425% / 5.575% | Medium | 4 / 12 | $2.50 | $240 | 5% after 5 days |
| Premium Video Slot | $7,500 | $10 / $25 / $50 | 95.7875% / 4.2125% | High | 6 / 20 | $4 | $400 | 3.5% after 6 days |
| High-Limit Slot | $15,000 | $25 / $50 / $100 | 95.425% / 4.575% | High | 8 / 30 | $6 | $650 | 2.5% after 7 days |

All machines have one position and fixed approved three-reel/single-line rules.
Video machines use a screen presentation of those rules, not a new multi-line game.
Used machines spin every two game minutes; the rest every minute while occupied.
A cheaper used machine has better theoretical return per purchase dollar early,
but standard machines improve throughput/reliability/development. Video slots are
more generous and need developed guest budgets to exploit their higher stakes.
Premium/high-limit machines concentrate more earning potential and payout risk
in one position. None creates income while empty, guarantees profit or changes
outcomes when cash is low. Appeal/prestige affect existing affordable-game choice,
not a new traffic system or a guaranteed utilization multiplier.

Tier access is earned and retained. Normal requirements (Rating / settled guest
handle) are standard 6 / $500; video 12 / $3,000; premium 24 / $12,000;
high-limit 45 / $35,000. These do not require buying Blackjack, VIP or a high-limit
room. Easy offers all profiles. Closed idling cannot generate guest handle.
Existing ordinary guest wager budgets increase at Ratings 16 / 28 / 55; slot
players select the highest supported stake within their existing budget and the
machine's current minimum/maximum. At a tiny property they remain capped at $5.
Raising the minimum above guest affordability can leave an expensive machine idle.

Top returns are 30x / 35x / 65x / 120x / 140x at 0.1% probability. Maximum total
returns are $150 / $350 / $1,300 / $6,000 / $14,000. Recommended reserves are
$650 / $900 / $2,200 / $6,500 / $15,000; these are guidance, not purchase gates.
Purchase is charged at the selected profile's cost; resale returns half that cost.
Repairs reset operating wear and debit actual profile-specific repair cost.
Broken machines cannot settle new spins, and their guests leave via the real
session flow. Overhead continues while closed/broken. Lifetime expense counters
include this burden; sale emits a final asset snapshot before removal.

Asset IDs and profile IDs remain on financial events. Wagers, total returns and
spin counts retain their existing ownership. Occupied/available minutes measure
seat occupancy during usable operation, not a fabricated profitability metric.
Downtime measures open minutes while broken. Per-asset upkeep, repair spending,
repairs and breakdown counts persist; no full finance dashboard is implemented.
Construction, repair and sale also emit their real cash changes; floor money
popups remain gaming-only and House Activity remains filtered management news.

Manual checks at 1x/4x: compare cheap capacity, standard and video purchases;
confirm tier gates, profile-specific preview/price/resale/repair cost and visuals;
check guest affordability after minimum changes, owner max wagers and net result
popups; compare income with upkeep and payout swings; verify used-machine spam
cannot reach Blackjack, and a developed slot-only floor can reach later Ratings.
Use debug Advance / Force Unlock for tier checks, preserve reserves before risky
purchases, and save/load a fresh schema-7 casino. Long-run viability and exact
prices/exposure still require playtesting; these are theoretical settings.

## Step 03.5 sustainability audit

Source-level audit and analytical calculations only; no automated tests or
long-run gambling samples were run for this step. The reported $30k+ non-payroll
aggregate cannot be attributed precisely without the actual elapsed hours,
asset/staff history and repairs/comps. Previously it combined upkeep, repair,
comp, hiring, construction and negative sale spending. Investment therefore
could make the lifetime net negative even while operations were profitable.

Finance now separates recurring guest operating performance (guest gaming win
minus payroll/upkeep/repairs/comps) from net capital spending and one-time hiring.
All settled gaming and visitor transfers remain visible for reconciliation;
visitor gambling is not business development revenue. Original lifetime cost
and cash-flow aggregates are preserved. Expense categories only classify each
existing cash charge; they do not charge twice. Asset operating contribution
includes its assigned dealer payroll, upkeep and repairs, excludes purchase price
and visitor play, and does not allocate shared service/comp costs. Sold assets'
expenses remain in lifetime categories. Schema 7 has no migrations.

Payroll is $20/dealer/hour and $16/service employee/hour, deducted once per game
minute as rate/60. All employed staff are paid during work, idle, standby, closed
or broken-game time. There are no unpaid shifts or automatic staffing changes.
The same step() runs at all speeds. Working/idle/standby/closed allocations and
role totals classify the same wages; they are not extra debits. One dealer plus
one service employee costs $36 per game hour even when the floor is empty.

### Slot findings (unchanged balance)

Expected win = actual handle x profile edge. At 50% occupancy, ordinary developed
guest stakes yield these approximate hourly operating contributions:

| Profile | Assumed wager | Gaming win at 100% occupancy/hr | Net at 50% occupancy/hr | Full-use purchase payback hours |
| --- | ---: | ---: | ---: | ---: |
| Used | $5 | $12.975 | $5.07 | 64.9 |
| Standard | $10 | $37.50 | $16.89 | 39.3 |
| Video | $20 | $66.90 | $30.53 | 50.0 |
| Premium | $50 | $126.375 | $58.69 | 61.5 |
| High-limit | $50 | $137.25 | $62.04 | 114.8 |

Net includes full hourly upkeep and an approximate long-run repair provision
assuming prompt repairs: repair_cost / (24 * (grace_days + 1/chance - 1)). It
excludes capital and shared service. Occupancy here means fraction of game time
occupied and usable; downtime/closed periods reduce actual yield. The figures
are conditional earning potential, not promised utilization or measured returns.
At starter budgets, standard/video guests wager $5, lowering their yields;
high-limit $100 stakes require an appropriately funded guest such as an existing
VIP. Used machines are useful early, standard is capital-efficient, and later
profiles increase yield per occupied position and development with larger risk.
No slot price, wager budget, RTP, reliability, upkeep or development value changed.

### Staffed-game findings and targeted changes

All three NPC card/wheel games previously resolved once per six game minutes
(10 hands/spins per occupied seat per hour). This was too little handle for
$20 dealer payroll + $12 table upkeep. Cadence is now per-game configuration at
two game minutes (30/hour); empty tables still earn nothing. Blackjack opens at
$10; roulette and UTH now open at $25, appropriate to their existing developed
market budgets. Limits can still be lowered to $10, with lower earning potential.
Rules, payouts, wager maximums, guest bankrolls and progression are unchanged.

For the existing Blackjack NPC strategy (hit until 17, decline insurance,
no doubles/splits), an independent infinite-shoe analytical model estimates
5.6746% house win per original stake. This is NOT optimal-play edge, not an
advertised rule change, and not a measured six-deck result. Finite-shoe card
correlation and actual guest bankroll exits are not modeled.

| Example | Before gross EV/hr | After gross EV/hr | Recurring table expense/hr |
| --- | ---: | ---: | ---: |
| Blackjack, 3 occupied $10 seats | $17.02 | $51.07 | $32 + roughly $0.34 repair provision |
| Roulette, 3 occupied seats at opening minimum | $8.11 ($10) | $60.81 ($25) | $32 + roughly $0.34 repairs |
| Craps, 5 occupied $25 seats, fully fatigued crew | $3.34 | $66.85 | $52 + roughly $0.34 repairs |

Roulette's red/black guest bets have exact 1/37 house edge. UTH with three $25
players at the new cadence makes 90 guest hands/hour and needs about $0.36 net
house win per hand to cover the same labor/upkeep/repair provision. The exact EV
of the implemented river-only guest strategy has not been measured/solved here;
verify its contribution separately during manual long runs. Do not infer a
measured UTH house edge from this break-even calculation.

Craps NPC guests only fund Pass bets. Their contracts take 3.37576 dice rolls on
average, with 7/495 house edge, so the previous 6-9.4 game-minute dice cadence
could not support two dealers even at a full ordinary table. NPC cadence is now
0.30 minutes + (100 - crew_energy)*0.002, reaching 0.47 at minimum energy.
Fractional timer remainder is preserved, allowing two to four rolls per economic
minute. Empty/manual backlogs are discarded; owner-controlled rail timing remains
15 minutes plus its original fatigue adjustment. Rolls remain real wagers and
settlements, with no altered dice probabilities or artificial income. Fatigue
still slows NPC craps and a lightly occupied table can still lose money.

### Representative configurations

These are conditional expected scenarios, not test results. Recurring provisions
assume prompt repairs and no complaint comps; capital is shown separately.

- A: Two used slots at $5 and 50% occupancy, no staff: roughly +$10.14/hour.
- B: Two used slots plus standard ($10) and video ($20), all 50% occupied:
  roughly +$57.56/hour before any shared service. Development and market budgets
  must support those stakes; adding empty assets only increases expenses.
- C: Two used slots plus standard ($10), all 50% occupied, Blackjack with three
  $10 players, one dealer and one service employee: approximately -$4.29/hour
  before, +$29.76/hour after the cadence change. Added standard/table/two hires
  cost $3,500; that investment is not an hourly operating loss.
- D: C plus two unnecessary dealers and another service employee: roughly
  -$26.24/hour after. Standby payroll remains a real management cost.
- E: C plus an empty staffed Blackjack table: roughly -$2.24/hour before its
  purchase cost. Empty-machine overhead and capital also erode efficiency.

### Acceleration and intentionally deferred issues

Economic ticks, payroll, upkeep, ages, wagering cadence and wear use game time,
not requested speed. Guest/service movement now consumes unused distance across
navigation waypoints; the previous one-waypoint update lost travel time at larger
0.1-second dev substeps and could depress accelerated throughput. Exact arrival
transition timing still has frame/substep quantization. 1000x remains best effort
under its frame budget/backlog cap; excess requested time is discarded, not
replaced by extra economic ticks. Compare actual elapsed game hours, not wall time.

Leave manually played games before long-run comparisons: their NPC round clock
is intentionally suspended while the owner controls play, whereas payroll and
upkeep keep running. Human decisions and visual game animations stay on real time.
Unattended broken machines stop earning but keep costs, so pause to handle repairs.
These are operating/test conditions, not reasons to reduce production wages.

Service still has no sales revenue. One employee reduces thirst growth from 0.35
to 0.07/minute and preserves satisfaction/reputation; ordinary visits still end
around 180 minutes, often before a no-service guest reaches the dissatisfaction
exit threshold. It does not currently guarantee extra traffic or extend that age
limit. Its weak direct financial return is intentionally documented for Step 04,
not hidden by cheap labor or fake bar income. Full period finance, shared-cost
allocation, richer service value, traffic/archetypes and staff shift/dismissal
systems remain out of scope. No guarantees of daily or long-run realized profit.

Manual validation: use a fresh schema-7 casino, leave visitor games, pause to
handle repairs, and compare equal executed game hours at 1x/100x/1000x. For fixed
staff, 60 ticks should add exactly the configured hourly payroll and per-asset
upkeep (subject to floating-point rounding); changing speed must not change rates.
Record role/state payroll, upkeep, repairs, comps, hiring, net investment, guest
operating result, utilization and each table's operating contribution. Compare
lean starter/developed/Blackjack floors with idle tables and excess standby staff.
Validate roulette/UTH at both $10 and $25, craps at normal/full fatigue, service
costs separately, owner-transfer exclusion and save/load. Gambling variance and
actual market utilization still require the developer's long-run playtesting.
