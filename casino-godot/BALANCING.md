# V0.4 balance and playtest targets

Authoritative values live in `scripts/tuning.gd`. This is compressed prototype
balancing, not a financial forecast. Real guest wagers and outcomes generate
income; neither waiting nor milestones grant money. Short samples can lose.

## Opening and progression

Normal starts with $2,500, two used slots, no staff and a small floor. Easy starts
with $30,000, chosen games/crews, expanded space and unrestricted catalog access.
Visitor play uses a separate $1,000 wallet. Owner gambling cannot manufacture
business readiness: development cash removes pending stakes and owner transfers.

Reputation is guest perception. Rating is property development plus bounded
settled handle/served-guest contributions. No elapsed-time unlock gates exist.
At 4x the same decisions and economic minutes execute faster in real time.

Blackjack requires **Rating 14, usable development 4, three positions, $12,000
settled guest handle, 40 departing real gamblers and $2,450 development cash**.
Two used reels plus a standard reel supply four development points; used reels
alone cap at three points/Rating 12, preventing cheap-machine unlock spam.
Unlocks persist and never force a purchase. A table costs $1,800 plus $150 dealer
onboarding; at the gate this leaves $500. $650 is its individual base reserve;
Finance advises a larger buffer for the entire existing floor, so saving further
is useful. A standard purchase costs $1,400, leaving $1,100 before operation.

Other Rating access: service 20, roulette 28, expansion 35, craps 45, VIP 55,
high-limit table capability 70, UTH 75. Slot-only development can reach Rating 100;
players can earn table access without purchasing tables. Higher-tier access also
requires settled handle; opening the doors alone cannot develop a two-slot room
past its property ceiling.

## Slots: different earning and risk choices

All listed RTPs derive from the fixed reel weights/paytables. Payouts include
returned stake; no probabilities depend on treasury. Top-symbol triples have
1/1,000 probability; top returns and volatility differ by profile.

| Machine | Purchase | Denominations | RTP / edge | Volatility | Upkeep/hr | Repair | Suggested reserve | Rating / handle access |
| --- | ---: | --- | --- | --- | ---: | ---: | ---: | --- |
| Used Classic Reel | $750 | $2/$5 | 91.35% / 8.65% | Low | $1 | $120 | $650 | Initial |
| Standard Reel | $1,400 | $2/$5/$10 | 93.75% / 6.25% | Low | $1.50 | $150 | $900 | 6 / $500 |
| Video Slot | $3,200 | $5/$10/$20 | 94.425% / 5.575% | Medium | $2.50 | $240 | $2,200 | 12 / $3,000 |
| Premium Video | $7,500 | $10/$25/$50 | 95.7875% / 4.2125% | High | $4 | $400 | $6,500 | 24 / $12,000 |
| High-Limit Slot | $15,000 | $25/$50/$100 | 95.425% / 4.575% | High | $6 | $650 | $15,000 | 45 / $35,000 |

Used reels resolve every two game minutes; other slots every minute. At full
occupancy and $5/spin, used theoretical contribution is $11.975/hr and standard
$17.25/hr after direct upkeep, before repairs/shared service. These are conditional
EV calculations, not guaranteed income. Premium machines need denomination,
attraction and utilization to justify cost; a lower edge alone does not make a
better business. Cheap seats preserve cash, quality develops the property,
slot-heavy floors avoid dealer wages, and tables add capacity/variety at higher
operational burden. Finance exposes actual throughput and contribution per
available asset hour for comparisons across unequal lifetimes.

Used daily failure chance is 10% after three operating days; standard 7% after
four, video 5% after five, premium 3.5% after six, high-limit 2.5% after seven.
Wear checks occur daily, reset after repair and never rig outcomes. Broken assets
stop earning; finance separates repair expense from purchase price.

## Guests, tables, payroll and hospitality

Normal bankroll/wager caps by Rating: $40-$140/$5 initially, $100-$300/$10 at 16,
$250-$700/$25 at 28, $400-$1,500/$50 at 55. VIP bankroll is $5,000 with a $100
wager cap. Once Standard Reel is unlocked, 25% of new non-VIP Normal arrivals
receive an $80-$200 bankroll and a $10 wager cap until the Rating-16 band takes
over. The remaining 75% keep the initial $40-$140/$5 budget. This introduces real
$10 demand without requiring every guest to afford it or forcing machine usage.
Existing guests keep their original budgets; unlocks do not refill wallets.
Machine/game maxima and affordability still apply. UTH affordability
reserves six base wagers; funded doubles, raises and other contracts use real funds.

Tables cost blackjack $1,800, roulette $2,500, craps $6,000, UTH $8,000.
Dealer onboarding is $150; wages $20/hr/dealer and $16/hr/service for Active,
Relief and Break time, including assigned idle and closed on-shift time. Off Duty
is unpaid. Table upkeep is $12/hr. Craps requires two dealers;
other tables one; slots none. Tables have seven public positions plus the owner
rail; slots one position. Public tables resolve per occupied hand/spin every two
game minutes; craps retains its shared roll/contract cadence. Operating sample,
utilization, guest strategy and wage commitments determine viability.

Staff fatigue is 0.20 energy/game minute while Active on an open floor. Automatic
relief swaps begin at 30 energy, using Relief workers with at least 85 energy.
Without cover, workers continue until 15, then take a mandatory break. Breaks
last at least 45 minutes and recover 1 energy/minute; workers return only at 85.
Relief recovers 0.04/minute; assigned closed-time idle recovers only 0.02/minute.
Paid shifts last at most 480 minutes, followed by at least 360 minutes Off Duty
recovering 0.20/minute. Closing never resets energy, shift deadlines or rest gates.
Rested off-duty roster employees stagger handovers in the final 90 minutes of a
shift, at most once per 20 minutes. Extra employees beyond the coverage/relief
target wait unpaid for later shifts. This is a rolling-shift abstraction, not a
calendar. Both roles default to one Relief target. Hiring immediately fills
Active and Relief positions even while paused or closed; extra hires wait unpaid.
Continuous operation needs both break cover and a rested shift roster. One bar
position with one relief recommends four employed through the existing shift/rest
calculation (480-minute shifts / 360-minute rest), rather than a hardcoded three.

Coverage allocates complete crews by High/Normal/Low priority, retaining existing
assignments within a priority. Committed games retain their real crew until bets
settle; a mandatory rest or paused table accepts no new play. Deferred handover
time remains paid. Routine rotations do not enter House Activity; shortages and
exhausted relief generate bounded notices. Relief/break wages are shared dealer
costs; assigned Active wages remain attributable to individual tables. Service
uses the same lifecycle, with a separate target for active floor positions.

The drink catalog keeps the original soda at $5 / $1 cost. Water is $3 / $0.60,
coffee $4 / $1, lager $7 / $2, highball $10 / $3, old fashioned $16 / $5 and
reserve nightcap $26 / $9. Default paid unit margins are $2.40-$17 before labor.
All prices have bounded $1 steps; every minimum price exceeds product cost.
Service wages remain $16/game hour. Preparation takes 1-6 game minutes per
product plus real walking/return time; low-price products trade smaller margins
for broader appeal and shorter prep. No payroll or gaming edge was reduced to
make drinks profitable. Low utilization, excessive comps or overstaffing can lose.

Recent real wagers (within 12 game minutes) plus active play qualify soda, water
and coffee for basic comps at their actual product cost, with no sale revenue.
Lager/cocktails/premium products always remain paid. Waiting/watching/bar-break
guests pay on physical delivery. No costs/revenue/units are booked at order time.
Service access (Rating 20, after Blackjack access) unlocks a $1,000 bar purchase
using Casino Cash. Easy makes purchase immediately available, without free ownership.
Purchase activates the bar and adds House Soda and Sparkling Water to the menu.
Later unlocks never add menu entries automatically. Normal basics require bar ownership; later options require Rating
24/32/45/65 and 20/60/150/300 actual deliveries; reserve also needs existing VIP
access. Easy exposes every product as an option, still requiring explicit addition.

Choice weights combine product demand, archetype preference, prestige taste and
paid-price elasticity (1.5). Every archetype can choose every available product.
Above reference price, willingness also falls; wallet affordability is enforced.
Guests first choose from unlocked options, can reveal an off-menu request and
then choose a menu substitute. Only unlocked demand is voiced. Retries are
bounded to once per 12 game minutes. Signals count attempts, not unique guests
or a guaranteed lost sale. Prestige adds at most 3 satisfaction per delivery to
the existing 6-point recovery; menu identity follows composition without fake
passive attraction income. These are initial balance assumptions for manual play.

Product gross contribution subtracts paid/comp ingredients. Product net further
subtracts real preparation/delivery/return payroll attributed to that product;
idle/relief/break payroll stays shared. Sum of product net minus shared service
payroll reconciles to bar net. Accounting/price quotes/menu/queues persist in
schema 17, including explicit bar ownership; older development saves are rejected
and deleted on load.

Slot players can attract bounded spectators like table players; observers
do not reserve a gambling position or qualify for comps, and move on when play
ends. Watching never changes payouts or odds.
Before bar ownership, thirst does not accumulate or reduce satisfaction; no
missing-service complaints or drink-service reputation penalties apply. After
purchase it grows normally, with discomfort at 25. Waiting guests and session
breaks can reserve one of five bar spots, walk there, buy a drink through existing
physical service staff and linger for 4-8 game minutes after delivery. Visits
without a delivery last 8-16 minutes; bar waiting preserves the demand budget.
Bar breaks release gambling seats and never qualify as active play for comps.
Only one missing-service complaint stays open, and actual drink delivery resolves
that complaint. Hiring does not itself fabricate a completed service.

Latent guest preferences stay intact. Visible interests, arrival thoughts and
inspectors use owned/available games or the next revealed progression opportunity;
Blackjack demand begins at earned access. Service is foreshadowed only when it
is the next revealed opportunity, with complaints/penalties beginning at access.
Machine-quality comments compare machines actually on the floor.

## Demand and reserve pressure

Natural traffic uses operating public positions, quality, variety, development,
bounded perception and occupancy. Normal overflow is 25% (35% evening peaks),
rounded up with one extra visitor minimum: two slots admit at most three physical
guests. Broken/uncrewed assets do not inflate arrivals. Departing guests still
occupy physical admission space. Parties have one or two guests. Evening peak
intervals start at 18-32 game minutes, steady 28-48, overnight 50% longer; attraction
scales these within a 4x frequency cap. Full-floor opportunities have a 45%
acceptance chance within overflow limits. MAX_GUESTS=40 is safety, never a quota.

Unserved guests retry, browse/watch, seek drinks or leave. Cumulative waiting
survives activity switches; satisfaction loss starts after 75% of patience and
exit occurs by 150%. Mild waiting is reputation-neutral. Three repeated severe
wait departures can cost 0.3 reputation, at most once per 120 game minutes. Easy
uses 85% pressure, 1.5x patience, 20%/25% overflow and 35% negative reputation
impact. Bounded attraction prevents bad perception from shutting off all demand.

Reserve advice uses free cash after pending stakes, the largest asset buffer
plus 25% of other buffers, four hours of payroll/upkeep and known repair bills.
Slots use the greater of profile reserve and maximum total return. Table estimates
include denomination, plausible payout multiples, partial extra-seat allowance
and current exposure. Purchase plans add equipment, necessary hires after available
standby dealers and incremental costs. Estimates are advisory, not worst-case
solvency guarantees; actual wins can exceed them. Outcomes are never capped.

Runtime/current-save safety bounds agree: 20 assets, 16 employees, 40 guests.
Current disposable schema is 14; no migrations or historical compatibility.

## Feedback and manual acceptance

Routine popups show signed net house result, never gross wagers as profit.
Treasury follows actual cash; gaming excludes unresolved stakes, operating profit
excludes capital/visitor play, net cash flow includes transfers and pending stakes.
Shared service costs remain separate from individual guest asset contribution.

First profit needs $100 operating contribution and $1,000 settled guest handle.
Real milestones cover property levels, machine/game access, first purchased table,
VIP arrival, expansion and first large guest net win/loss ($500; $1,000+ major).
Craps aggregate guest results qualify; owner results do not. IDs persist to avoid
repeat/rebuild/load rewards. There are no monetary milestone grants. Routine
results stay on the floor; milestones and operational issues use stronger feedback.

Manual acceptance checklist:

- Fresh Normal: compare a cheap seat, standard development and preserving reserve;
  approach Blackjack through real handle, served gamblers and usable development.
- Compare equal accomplishments at 1x/4x; a tiny unchanged room must not unlock
  Blackjack merely by waiting. Easy should offer preferred games immediately.
- Run slot-heavy, balanced/table and later premium/high-limit floors; compare
  normalized contribution, repairs, utilization, payroll and payout swings.
- Verify paid drinks/comps on walking delivery, service recovery, gradual demand
  pressure and never-gambled direct exits versus legitimate cage departures.
- Check simultaneous money/thought/milestone feedback and Finance at desktop,
  tablet, landscape and 320px portrait; observe a developed floor for 30 seconds.
- Move/sell/place assets and load a current save; check navigation, real balances,
  no duplicate settlements and no replayed milestones. Exercise safety boundaries.
- Observe a reasonably busy floor and frame responsiveness; 1000x remains debug
  best effort with bounded substeps/backlog, not a promised sustained throughput.

Final integration used source/economic review and export compilation, with no
automated tests, spin suites or measured first-hour/FPS claims. Runtime balance,
strategy dominance and subjective first-hour satisfaction require manual playtesting.

## Modular expansion capital and carrying cost

Normal starts at 535 x 610; Easy starts with one additional right column. Rating
35 still gates Normal purchases. A side column is 320 x current depth; a bottom
row is current width x 240. Quotes include the full added strip, not just a corner.
Price = round up to $50 of $3,000 * added_area / 195,200 *
(1 + 0.20 * existing_chunk_count + 0.35 * extra_area / starter_area).
The first Normal side is $3,000; bottom is $2,000. A second side after the first
is $4,250. Simultaneous width/depth growth makes later strips larger and pricier.
Easy's starting column counts as existing area/chunks for subsequent quotes.

Extra property costs $0.35/game hour per 10,000 floor units squared, even closed
or empty: first side +$6.832/hour, first bottom +$4.494/hour. The starter's base
property cost remains included in its existing economy; no new starter tax.
Reference audit: a full $5 used reel expects $11.975/hour after its $1 upkeep;
a service worker costs $16/hour and tables $12/hour plus $20/hour per dealer.
Thus a side expansion carries roughly 57% of a fully utilized used reel's expected
contribution, before staffing/repairs. Empty expansion can hurt profitability;
space adds no passive income, attraction or capacity until assets operate.
Initial carrying costs require manual playtesting; house edges are unchanged.

Construction is capital spending; property upkeep has a separate recurring ledger,
flows into operating profit/cash and Finance Operations, and enters reserve advice.
The first purchased expansion retains the prior bounded development credit;
repeated empty land purchases do not farm Rating. Schema 16 saves are current-only.

## Casino Momentum (0.4.2.5)

Momentum starts at 35/100 (Busy). Bands are Quiet below 25, Busy below 50,
Hot below 70, Packed below 85 and Electric above that. Open operation slowly
tracks guest satisfaction, occupancy and usable game coverage. Normal healthy
idle operation supplies its own baseline; player interaction is optional.
Repairs, complaint comps, net-positive owner opportunities and rate-limited real
big guest wins add bounded, slowly fading influence. Opening an event or simply
viewing a table earns no boost. Ignored/expired Opportunities never penalize it.
Real low satisfaction, unavailable games and dismissed complaints can lower it.

Response takes roughly four game hours to halve distance to operating conditions,
with at most 3.6 points/hour movement. Outcome influence has a 12-hour half-life
and caps at +30/-15. Closed and offline sessions freeze it; loading never replays
outcomes or catches up wall-clock time. Values above baseline add at most 10%
to attraction within existing arrival/capacity limits. There are no changes to
odds, payouts, stakes, direct money, dwell time or event frequency in this step.

## Dynamic optional objectives (0.4.2.6)

At most two opt-in goals are offered, checked every three game hours with a
12-hour type cooldown. Targets use the last six game hours of actual guest net
win, happy gambling departures and paid drink deliveries, or currently occupied
operating games/Momentum. Owner-win goals require an available funded opportunity.
Offers last six hours; starting gives a six-hour window, completion gives twelve
hours to claim. Unstarted goals never earn progress or rewards. Ignore/expiration
has no penalty. Closed departures never count; closed or idle games reset the
45-minute sustained-operation streaks. Gaming progress includes losing results,
excludes owner play and represents gaming win before operating expenses.

Rewards replenish Owner Bankroll by $45-$85 according to development, plus two
points of slowly fading Momentum influence. There is no casino cash reward.
Claims cap at $300 per elapsed game day and $2,000 personal funds including
committed stakes. Partial claims consume the goal and only spend actual budget;
full caps leave the reward unclaimed. Ready IDs, cooldowns, recent samples and
budget persist; claims checkpoint the consumed ID and account together. Closed
or offline time never replays outcomes or generates a backlog of rewards.
