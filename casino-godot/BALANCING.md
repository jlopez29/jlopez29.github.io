# V0.3 balance and playtest targets

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
wager cap. Machine/game maxima and affordability still apply. UTH affordability
reserves six base wagers; funded doubles, raises and other contracts use real funds.

Tables cost blackjack $1,800, roulette $2,500, craps $6,000, UTH $8,000.
Dealer onboarding is $150; wages $20/hr/dealer and $16/hr/service, including idle,
standby and closed time. Table upkeep is $12/hr. Craps requires two dealers;
other tables one; slots none. Tables have seven public positions plus the owner
rail; slots one position. Public tables resolve per occupied hand/spin every two
game minutes; craps retains its shared roll/contract cadence. Operating sample,
utilization, guest strategy and wage commitments determine viability.

Basic drinks cost guests $5 and the house $1. Recent real wagers (within 12 game
minutes) plus active play qualify for basic comps: $1 house cost, no fake sale.
Waiting/watching/drinking guests pay on physical delivery. Paid product margin
is $4 before service payroll; free drinks support retention but require gaming
income. Without service access, thirst discomfort starts at 40 and loss is 25%
of the developed-casino rate; after access it starts at 25 with normal pressure.
Only one missing-service complaint stays open, and actual drink delivery resolves
that complaint. Hiring does not itself fabricate a completed service.

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
Current disposable schema is 12; no migrations or historical compatibility.

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
