# Prototype balance

Defaults live in `scripts/tuning.gd`; the table's $25/$50 limit is configurable in
its inspector while empty. This is compressed test-session balancing, not a
forecast of real casino finances.

| Value | Initial setting |
|---|---|
| Starting casino cash | $24,000; one table included |
| Visitor wallet | $1,000, independent from house funds |
| New table / resale | $3,500 / $1,750 |
| Staff onboarding | $150 per employee |
| Dealer / service wage | $20 / $16 per game hour |
| Table overhead | $12 per game hour, including closed tables |
| Required crew / seats | 2 dealers / 7 public players + owner rail position |
| Game time | 1 minute per real second at 1× |
| Dice interval | 6 game minutes; 15 while visitor is seated, plus fatigue |
| Guest arrival | Every 3 game minutes evening, otherwise every 5 |
| Guest bankroll | $400–$1,500; VIP $5,000 |
| Guest wager | Table minimum; VIP 4× minimum |
| Guest cap | 40 |
| VIP arrival | Every 100 simulated minutes while open |
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
interesting rather than arbitrary. There are no unlock requirements in 0.2.

Repair wear resets after repair. The grace period and daily chance are playtest
settings, not measured real-world failure rates.
