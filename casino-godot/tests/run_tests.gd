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
		if int(guest.table) == 1:
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
	print("%d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
