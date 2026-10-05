extends SceneTree

var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.00001

func bettor(kind: String, amount: float) -> Dictionary:
	var bets := CrapsRules.empty_bets()
	bets[kind] = amount
	return bets

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for dice in [[3, 4], [5, 6]]:
		var result := CrapsRules.resolve(0, bettor("pass", 25), dice[0], dice[1])
		check(near(result.credit, 50) and result.bets.pass == 0 and result.point == 0, "Natural pays even money")
	for dice in [[1, 1], [1, 2], [6, 6]]:
		var result := CrapsRules.resolve(0, bettor("pass", 25), dice[0], dice[1])
		check(result.credit == 0 and result.bets.pass == 0, "Come-out craps loses line")
	for point in [4, 5, 6, 8, 9, 10]:
		var a: int = maxi(1, point - 6)
		var b: int = point - a
		var bets := bettor("pass", 25)
		bets.odds = 30.0
		var result := CrapsRules.resolve(point, bets, a, b)
		var ratio := 2.0 if point in [4, 10] else (1.5 if point in [5, 9] else 1.2)
		check(near(result.credit, 50 + 30 * (1 + ratio)) and result.point == 0, "True odds payout for point %d" % point)
		result = CrapsRules.resolve(point, bets, 3, 4)
		check(result.credit == 0 and result.bets.pass == 0 and result.bets.odds == 0, "Seven-out clears contracts")
	var place_bets := bettor("six", 30)
	place_bets.eight = 30
	var result := CrapsRules.resolve(5, place_bets, 2, 4)
	check(near(result.credit, 35) and result.bets.six == 30, "Place 6 pays 7:6, keeps stake")
	result = CrapsRules.resolve(0, place_bets, 2, 4)
	check(result.credit == 0 and result.bets.six == 30, "Place bets off on come-out point")
	result = CrapsRules.resolve(0, place_bets, 3, 4)
	check(result.credit == 0 and result.bets.six == 30, "Come-out seven preserves off bets")
	result = CrapsRules.resolve(6, place_bets, 3, 4)
	check(result.bets.six == 0 and result.bets.eight == 0, "Seven-out removes place bets")
	for a in range(1, 7):
		for b in range(1, 7):
			result = CrapsRules.resolve(0, bettor("field", 25), a, b)
			var expected := 75 if a + b == 2 else (100 if a + b == 12 else (50 if a + b in [3, 4, 9, 10, 11] else 0))
			check(result.credit == expected and result.bets.field == 0, "Field settles correctly for all 36 outcomes")
	var sim := CasinoSimulation.new()
	sim.rng.seed = 12345
	check(not sim.operating(sim.tables[0]), "Unstaffed closed table cannot operate")
	sim.hire("Dealer", 1)
	sim.set_open(true)
	check(not sim.operating(sim.tables[0]), "One dealer is insufficient")
	sim.hire("Dealer", 1)
	check(sim.operating(sim.tables[0]), "Two-dealer crew opens table")
	sim.joined = 1
	var total_before := sim.cash + sim.wallet
	check(sim.bet(1, "pass"), "Owner can place Pass Line")
	check(near(sim.cash + sim.wallet, total_before), "Bet transfers conserve casino + wallet money")
	check(not sim.bet(1, "pass"), "Cannot double existing Pass Line")
	sim.roll(1, [2, 4])
	check(sim.tables[0].point == 6 and sim.tables[0].owner.pass == 25, "Six establishes point and locks line")
	check(not sim.bet(1, "pass"), "Cannot place line after point")
	check(sim.bet(1, "odds"), "Odds accepted after point")
	sim.reclaim(1)
	check(sim.tables[0].owner.pass == 25 and sim.tables[0].owner.odds == 0, "Taking down bets preserves locked line")
	sim.bet(1, "odds")
	sim.roll(1, [3, 3])
	check(near(sim.wallet, 1061), "Pass + odds win returns stake and correct profit")
	check(near(sim.cash + sim.wallet, total_before), "Payout transfers conserve money")
	check(near(sim.revenue - sim.payouts, -61), "House result matches opposite visitor profit")
	var saved := JSON.parse_string(JSON.stringify(sim.snapshot())) as Dictionary
	var restored := CasinoSimulation.new()
	check(restored.restore(saved), "Versioned JSON save restores")
	check(near(restored.cash, sim.cash) and near(restored.wallet, sim.wallet), "Restore preserves money")
	check(restored.rng.state == sim.rng.state, "Save preserves random-generator state exactly")
	check(JSON.parse_string(JSON.stringify(restored.snapshot())) == saved, "Save round-trip preserves full simulation")
	var bad := saved.duplicate(true)
	bad.version = 999
	check(not restored.restore(bad), "Unknown save version rejected")
	bad = saved.duplicate(true)
	bad.erase("cash")
	check(not restored.restore(bad), "Incomplete save rejected")
	bad = saved.duplicate(true)
	bad.tables[0].owner = {"pass": -100}
	var before_invalid := JSON.stringify(restored.snapshot())
	check(not restored.restore(bad), "Malformed bet dictionary rejected")
	check(JSON.stringify(restored.snapshot()) == before_invalid, "Invalid save leaves state unchanged")
	bad = saved.duplicate(true)
	bad.staff[0].erase("energy")
	check(not restored.restore(bad), "Incomplete employee rejected")
	check(not sim.can_place(Vector2(320, 240), false), "Overlaps rejected")
	check(not sim.can_place(Vector2(0, 0), false), "Outside-floor placement rejected")
	check(sim.can_place(Vector2(70, 110), false), "Clear floor accepts table")
	check(not sim.sell(1), "Occupied table cannot be sold")
	var construction := CasinoSimulation.new()
	var new_id := construction.place(Vector2(70, 110), true)
	check(new_id > 0 and construction.tables.size() == 2, "Can purchase and rotate a new table")
	check(near(construction.cash, CasinoTuning.STARTING_CASH - 3500), "Construction debits treasury once")
	check(construction.sell(new_id), "Can sell an empty table")
	check(near(construction.cash, CasinoTuning.STARTING_CASH - 1750), "Resale credits half cost")
	check(near(construction.cash, CasinoTuning.STARTING_CASH + construction.net_profit()), "Construction and resale ledger reconciles")
	sim.joined = -1
	sim.spawn_guest()
	for i in range(1200):
		sim.move_guests(1.0)
		sim.step()
		for index in range(sim.incidents.size() - 1, -1, -1):
			sim.resolve_incident(index, true)
		for guest in sim.guests:
			check(guest.wallet >= 0 and is_finite(guest.wallet), "Guest wallet nonnegative and finite")
	check(sim.tables[0].rolls > 30, "Guests reach tables and generate real rounds")
	check(sim.guests.size() <= 40, "Guest population bounded")
	var seats: Array = []
	for guest in sim.guests:
		if int(guest.table) == 1 and int(guest.seat) >= 0:
			check(int(guest.seat) not in seats, "Reserved guest seats are unique")
			seats.append(int(guest.seat))
	check(seats.size() <= 7, "Owner rail position stays available")
	check(sim.payroll > 0 and sim.overhead > 0, "Simulation charges payroll and operations")
	check(near(sim.cash, CasinoTuning.STARTING_CASH + sim.net_profit()), "Treasury reconciles with complete ledger")
	# Exact probability enumeration over every ordered dice pair.
	var win_probability := 8.0 / 36.0
	for point in [4, 5, 6, 8, 9, 10]:
		var ways := 0.0
		for a in range(1, 7):
			for b in range(1, 7):
				if a + b == point: ways += 1
		win_probability += ways / 36.0 * ways / (ways + 6)
	check(near(1 - 2 * win_probability, 0.014141414141414), "Pass Line house edge is 1.414%")
	# Closing does not strand outstanding contracts.
	var closing := CasinoSimulation.new()
	closing.rng.seed = 99
	closing.hire("Dealer", 1)
	closing.hire("Dealer", 1)
	closing.opened = true
	closing.joined = 1
	closing.bet(1, "pass")
	closing.roll(1, [2, 4])
	closing.joined = -1
	closing.set_open(false)
	for i in range(500): closing.step()
	check(closing.tables[0].owner.pass == 0, "Closed casino finishes locked visitor bets")
	expanded_craps_tests()
	shooter_tests()
	migration_and_wear_tests()
	crowd_tests()
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func expanded_craps_tests() -> void:
	var bets := bettor("dont_pass", 25)
	var r := CrapsRules.resolve(0, bets, 6, 6)
	check(r.credit == 0 and r.bets.dont_pass == 25, "Don't Pass bar 12 pushes and stays")
	for dice in [[1, 1], [1, 2]]:
		r = CrapsRules.resolve(0, bets, dice[0], dice[1])
		check(r.credit == 50 and r.bets.dont_pass == 0, "Don't Pass wins 2/3")
	for n in CrapsRules.NUMBERS:
		bets = bettor("dont_pass", 25)
		bets.lay_odds = 30
		r = CrapsRules.resolve(n, bets, 3, 4)
		var profit := 15.0 if n in [4, 10] else (20.0 if n in [5, 9] else 25.0)
		check(near(r.credit, 80 + profit) and r.bets.lay_odds == 0, "Don't Pass true lay odds %d" % n)
		bets = bettor(CrapsRules.PLACE_KEYS[n], 30 if n in [6, 8] else 25)
		r = CrapsRules.resolve(5, bets, maxi(1, n - 6), mini(6, n - 1))
		check(near(r.credit, 45 if n in [4, 10] else 35), "Place payout %d" % n)
	bets = bettor("come", 25)
	r = CrapsRules.resolve(4, bets, 3, 3)
	check(r.bets.come == 0 and r.bets.come_6 == 25 and r.point == 4, "Come travels independently of table point")
	bets = r.bets
	bets.come = 25
	bets.come_odds_6 = 25
	r = CrapsRules.resolve(4, bets, 2, 4)
	check(near(r.credit, 105) and r.bets.come_6 == 25 and r.bets.come == 0, "Existing Come wins before replacement contract travels")
	bets = bettor("come_6", 25)
	bets.come_odds_6 = 25
	r = CrapsRules.resolve(0, bets, 3, 4)
	check(r.credit == 25 and r.bets.come_6 == 0 and r.bets.come_odds_6 == 0, "Come-out seven loses Come contract, returns off odds")
	r = CrapsRules.resolve(0, bets, 3, 3)
	check(r.credit == 75, "Come-out number wins Come, returns off odds without profit")
	r = CrapsRules.resolve(0, bets, 3, 3, true)
	check(r.credit == 105, "Called-working Come odds win on come-out")
	bets = bettor("dont_come", 25)
	r = CrapsRules.resolve(4, bets, 6, 6)
	check(r.bets.dont_come == 25, "Don't Come bar 12 pushes")
	r = CrapsRules.resolve(4, bets, 2, 3)
	check(r.bets.dont_come_5 == 25 and r.bets.dont_come == 0, "Don't Come travels")
	bets = r.bets
	bets.dont_come_odds_5 = 30
	r = CrapsRules.resolve(0, bets, 3, 4)
	check(r.credit == 100 and r.bets.dont_come_5 == 0, "Don't Come and lay odds work on come-out")
	for n in CrapsRules.HARD_NUMBERS:
		var kind := "hard_" + str(n)
		bets = bettor(kind, 5)
		r = CrapsRules.resolve(5, bets, n / 2, n / 2)
		check(r.credit == (35 if n in [4, 10] else 45) and r.bets[kind] == 5, "Hardway pays and stays")
		r = CrapsRules.resolve(5, bets, n / 2 - 1, n / 2 + 1)
		check(r.credit == 0 and r.bets[kind] == 0, "Easy way loses hardway")
		r = CrapsRules.resolve(0, bets, 3, 4)
		check(r.bets[kind] == 5, "Hardways off on come-out")
		r = CrapsRules.resolve(0, bets, 3, 4, true)
		check(r.bets[kind] == 0, "Working hardways lose come-out seven")
	var examples := [["any_craps", 1, 2, 40], ["any_seven", 3, 4, 25], ["yo", 5, 6, 80], ["aces", 1, 1, 155], ["ace_deuce", 1, 2, 80], ["boxcars", 6, 6, 155]]
	for example in examples:
		r = CrapsRules.resolve(0, bettor(example[0], 5), example[1], example[2])
		check(r.credit == example[3] and r.bets[example[0]] == 0, "One-roll proposition settles")

func ready_casino() -> CasinoSimulation:
	var sim := CasinoSimulation.new()
	sim.rng.seed = 281
	sim.hire("Dealer", 1)
	sim.hire("Dealer", 1)
	sim.hire("Service", -1)
	sim.opened = true
	return sim

func shooter_tests() -> void:
	var sim := ready_casino()
	check(sim.join_table(1), "Join staffed table through domain API")
	var table: Dictionary = sim.tables[0]
	check(table.shooter == 0, "Visitor may shoot first at an empty table")
	sim.shoot_player(1, [3, 4])
	check(table.shooter == 0 and table.point == 0, "Come-out natural retains shooter")
	sim.shoot_player(1, [1, 1])
	check(table.shooter == 0, "Come-out craps retains shooter")
	sim.shoot_player(1, [2, 4])
	sim.shoot_player(1, [3, 3])
	check(table.shooter == 0 and table.point == 0, "Making point retains shooter")
	sim.shoot_player(1, [2, 4])
	sim.bet(1, "come", 25)
	sim.shoot_player(1, [3, 4])
	check(table.shooter == -2 and table.point == 0, "Seven-out passes dice to CPU")
	check(not sim.shoot_player(1, [3, 4]), "Visitor cannot throw during CPU turn")
	sim.roll(1, [2, 4])
	sim.roll(1, [3, 4])
	check(table.shooter == 0, "CPU seven-out returns dice to next queued visitor")
	sim.bet(1, "pass", 25)
	sim.shoot_player(1, [2, 4])
	sim.pass_dice(1)
	check(table.shooter == -2 and table.point == 6 and table.owner.pass == 25, "Voluntary pass preserves point and contract")
	var rolls := int(table.rolls)
	for i in range(40): sim.step()
	check(table.rolls > rolls and table.shooter != 0, "CPU rolls automatically while visitor remains at rail betting only")
	table.betting_hold = true
	rolls = table.rolls
	var elapsed_before := sim.elapsed
	for i in range(40): sim.step()
	check(table.rolls == rolls and sim.elapsed == elapsed_before + 40, "Hold freezes one table, not casino clock")
	table.betting_hold = false
	sim.queue_for_dice(1)
	var shooter_before := int(table.shooter)
	check(table.shooter == shooter_before and table.owner_queued, "Joining rotation does not take over current hand")
	var saved := sim.snapshot()
	var copy := CasinoSimulation.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(saved))), "Shooter/history snapshot loads")
	check(copy.tables[0].shooter == table.shooter and copy.tables[0].owner_queued == table.owner_queued and copy.tables[0].history == JSON.parse_string(JSON.stringify(table.history)), "Shooter identity, queue and roll history survive load")
	sim.set_open(false)
	check(sim.joined == -1 and table.shooter != 0 and not table.betting_hold, "Closing releases visitor dice and betting hold to CPU")
	sim.set_open(true)
	rolls = table.rolls
	# Pending contracts keep an otherwise empty table operating after departure.
	table.point = 6
	table.owner.pass = 25
	for i in range(12): sim.step()
	check(table.rolls > rolls, "CPU continues settling contracts after visitor leaves")
	# Real guests take successive turns rather than an anonymous timer.
	sim = ready_casino()
	for i in range(2):
		sim.spawn_guest()
		var guest: Dictionary = sim.guests[i]
		guest.table = 1
		guest.seat = i
		guest.state = "Playing"
	table = sim.tables[0]
	sim.ensure_shooter(table)
	var first: int = sim.guests[0].id
	var second: int = sim.guests[1].id
	check(table.shooter == first, "First seated CPU guest takes dice")
	sim.join_table(1)
	check(table.shooter == first, "Joining live table preserves CPU shooter")
	sim.roll(1, [2, 4]); sim.roll(1, [3, 4])
	check(table.shooter == second, "Seven-out moves to second seated CPU guest")
	sim.roll(1, [2, 4]); sim.roll(1, [3, 4])
	check(table.shooter == 0, "Visitor gets turn after seated CPU guests")

func migration_and_wear_tests() -> void:
	var sim := ready_casino()
	sim.join_table(1)
	sim.bet(1, "pass")
	sim.shoot_player(1, [2, 4])
	var legacy := sim.snapshot()
	legacy.version = 1
	for table in legacy.tables:
		for key in ["shooter", "shooter_seat", "hand_rolls", "owner_queued", "betting_hold", "owner_working", "history", "service_minutes"]: table.erase(key)
		for kind in table.owner.keys():
			if kind not in ["pass", "odds", "six", "eight", "field"]: table.owner.erase(kind)
	var migrated := CasinoSimulation.new()
	check(migrated.restore(JSON.parse_string(JSON.stringify(legacy))), "v0.1 save migrates")
	check(migrated.cash == sim.cash and migrated.wallet == sim.wallet and migrated.tables[0].owner.pass == 25 and migrated.tables[0].point == 6, "Migration preserves funds and unresolved point")
	check(migrated.tables[0].shooter == 0 and migrated.tables[0].owner.has("dont_come_10"), "Migration installs shooter and extended bets")
	var resumed := CasinoSimulation.new()
	resumed.hire("Dealer", 1)
	resumed.hire("Dealer", 1)
	resumed.set_open(true)
	resumed.spawn_guest()
	resumed.guests[0].state = "Waiting"
	resumed.guests[0].age = 2
	check(resumed.restore(JSON.parse_string(JSON.stringify(resumed.snapshot()))), "Waiting guest loads from JSON")
	resumed.step()
	check(resumed.guests[0].state in ["Walking", "Browsing"] and resumed.tables[0].timer == 1, "Loaded guest assignment and CPU timer advance after JSON roundtrip")
	var handoff := CasinoSimulation.new()
	handoff.hire("Dealer", 1)
	handoff.hire("Dealer", 1)
	handoff.set_open(true)
	handoff.join_table(1)
	handoff.pass_dice(1)
	handoff.queue_for_dice(1)
	handoff.spawn_guest()
	handoff.guests[0].table = 1
	handoff.guests[0].seat = 0
	handoff.guests[0].state = "Playing"
	handoff.ensure_shooter(handoff.tables[0])
	check(handoff.tables[0].shooter == -2, "New guest cannot interrupt a CPU handoff before its first roll")
	# Exact minimum operating-time guarantee, independent of random repair chance.
	var table: Dictionary = sim.tables[0]
	table.service_minutes = CasinoTuning.REPAIR_GRACE_MINUTES - 2
	sim.step()
	check(not table.broken, "No repairs before three days of operating wear")
	check(CasinoTuning.REPAIR_CHANCE <= 0.1 and CasinoTuning.REPAIR_CHECK_MINUTES >= 1440, "Repair checks are rare daily opportunities")
	# Simulate repair of a persisted incident and check grace resets.
	table.broken = true
	sim.incidents.append({"type": "repair", "table": 1, "title": "Worn rail", "detail": "Repair"})
	sim.resolve_incident(sim.incidents.size() - 1, true)
	check(not table.broken and table.service_minutes == 0, "Repair resets operating wear and grace")

func crowd_tests() -> void:
	var sim := CasinoSimulation.new()
	sim.rng.seed = 121
	sim.hire("Dealer", 1)
	sim.hire("Dealer", 1)
	sim.set_open(true)
	for i in range(9): sim.step()
	check(sim.guests.is_empty(), "Opening has a quiet gap before the first party")
	sim.step()
	check(sim.guests.size() in [1, 2], "First arrival is a party of one or two")
	var party_size := sim.guests.size()
	for i in range(17): sim.step()
	check(sim.guests.size() == party_size, "No constant arrivals between parties")
	# No motion leaves the entrance busy; new parties stop rather than pile up.
	for i in range(180): sim.step()
	check(sim.guests.size() <= 5, "Arrivals ease off while visitors are still waiting")
	var count := sim.guests.size()
	sim.set_open(false)
	for i in range(60): sim.step()
	check(sim.guests.size() <= count and sim.guests.all(func(g): return g.state == "Leaving"), "Closing admits nobody and sends observers/arrivals home")
	var observing := CasinoSimulation.new()
	observing.rng.seed = 12
	observing.hire("Dealer", 1)
	observing.hire("Dealer", 1)
	observing.set_open(true)
	observing.spawn_guest()
	var guest: Dictionary = observing.guests[0]
	guest.state = "Watching"
	guest.table = 1
	guest.seat = -1
	guest.watch_left = 12
	guest.x = 415.0
	guest.y = 400.0
	guest.tx = 415.0
	guest.ty = 400.0
	for i in range(11): observing.watching_step(guest)
	check(guest.state == "Watching" and guest.seat == -1 and CrapsRules.exposure(guest.bets) == 0, "Observers watch without taking a seat or wagering")
	var copy := CasinoSimulation.new()
	check(copy.restore(JSON.parse_string(JSON.stringify(observing.snapshot()))), "Observer and arrival timer save loads")
	check(copy.arrival_in == observing.arrival_in and copy.guests[0].watch_left == 1, "Save preserves remaining observation and arrival time")
	observing.watching_step(guest)
	copy.watching_step(copy.guests[0])
	check(guest.state in ["Walking", "Leaving"], "An observer eventually joins or leaves even without a roll")
	check(copy.guests[0].state == guest.state and copy.rng.state == observing.rng.state, "Restored observer makes the same seeded decision")
	# Legacy v2 saves have none of the new optional fields.
	var legacy := observing.snapshot()
	legacy.erase("arrival_in")
	for g in legacy.guests:
		g.erase("watch_left")
		g.erase("watch_style")
	check(copy.restore(JSON.parse_string(JSON.stringify(legacy))), "Existing v2 saves remain compatible")
	var watched := false
	var joined_directly := false
	for i in range(30):
		var visit := CasinoSimulation.new()
		visit.rng.seed = i + 1
		visit.hire("Dealer", 1)
		visit.hire("Dealer", 1)
		visit.set_open(true)
		visit.spawn_guest()
		visit.choose_table(visit.guests[0])
		watched = watched or visit.guests[0].state == "Browsing"
		joined_directly = joined_directly or visit.guests[0].state == "Walking"
	check(watched and joined_directly, "A mixture of spectators and immediate players visits the casino")

	var full := CasinoSimulation.new()
	full.hire("Dealer", 1)
	full.hire("Dealer", 1)
	full.set_open(true)
	for i in range(7):
		full.spawn_guest()
		full.guests[i].table = 1
		full.guests[i].seat = i
		full.guests[i].state = "Playing"
	full.spawn_guest()
	var spectator: Dictionary = full.guests[7]
	full.choose_table(spectator)
	check(spectator.state == "Browsing" and spectator.seat == -1, "A full table allows a spectator without an eighth public seat")
	full.choose_table(spectator, false)
	check(spectator.state == "Waiting" and full.seated(1).size() == 7, "A watching guest must recheck seat availability before buying in")
