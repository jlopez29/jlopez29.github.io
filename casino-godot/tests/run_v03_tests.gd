extends SceneTree
# Current V0.3 regression; disposable current-schema saves only.
const Games = preload("res://scripts/casino_games.gd")
const Text = preload("res://scripts/financial_text.gd")
const Actions = preload("res://scripts/developer_actions.gd")
var checks := 0
var failures := 0
var events: Array = []
var milestones: Array = []
var results: Array = []

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
		results.append(message)

func near(a: float, b: float) -> bool:
	return absf(a - b) < 0.001

func _initialize() -> void:
	call_deferred("run")

func observe(sim: CasinoSimulation) -> void:
	events.clear()
	milestones.clear()
	sim.financial_event.connect(func(e): events.append(e.duplicate(true)))
	sim.milestone_reached.connect(func(e): milestones.append(e.duplicate(true)))

func json_save(sim: CasinoSimulation) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim.snapshot()))

func seat(sim: CasinoSimulation, table: Dictionary, index: int = 0) -> Dictionary:
	sim.spawn_guest()
	var guest: Dictionary = sim.guests.back()
	guest.table = table.id
	guest.seat = index
	guest.state = "Playing"
	guest.x = 425.0
	guest.y = 450.0
	guest.session_left = 500
	guest.wallet = 1000.0
	guest.start = 1000.0
	guest.wager_limit = 50.0
	return guest

func run() -> void:
	startup_and_progression()
	game_rules()
	expanded_craps_tests()
	shooter_tests()
	milestones_and_wear()
	settlements()
	hospitality_and_departure()
	traffic_and_saves()
	construction_and_navigation()
	if "--quick" not in OS.get_cmdline_user_args(): long_runs()
	await ui_checks()
	print("V0.3 REGRESSION: %d checks, %d failures" % [checks, failures])
	var report := {"checks": checks, "failures": failures, "failed_checks": results}
	var output := FileAccess.open("/tmp/v03-regression-result.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "  "))
	quit(1 if failures else 0)

func startup_and_progression() -> void:
	var sim := CasinoSimulation.new()
	check(sim.tables.size() == 2 and sim.staff.is_empty() and near(sim.cash, 2500), "Normal starter setup")
	check(sim.tables.all(func(t): return t.kind == "slots" and t.slot_profile == "starter"), "Normal starts at bottom tier")
	check(not sim.unlocked("blackjack"), "No immediate Blackjack")
	var initial := sim.casino_rating
	for i in range(10000): sim.step()
	check(near(initial, sim.casino_rating) and not sim.unlocked("blackjack"), "Idle time cannot unlock development")
	sim.reputation = 100
	sim.refresh_progression()
	check(near(initial, sim.casino_rating), "Reputation distinct from Rating")
	sim.guest_handle = 1000000
	sim.guests_served = 10000
	sim.cash = 100000
	for i in range(10): sim.tables.append(sim.new_table(Vector2(300, 300), false, "slots"))
	sim.refresh_progression()
	check(sim.gaming_development() == 3 and sim.casino_rating == 12 and not sim.unlocked("blackjack"), "Cheap spam cannot earn Blackjack")
	sim = CasinoSimulation.new()
	sim.tables.append(sim.new_table(Vector2(350, 180), false, "slots", "standard"))
	sim.guest_handle = 12000
	sim.guests_served = 40
	sim.cash = 2450
	sim.refresh_progression()
	check(sim.blackjack_ready() and sim.blackjack_unlocked, "Multi-factor Blackjack readiness")
	check(sim.cash - CasinoTuning.GAME_COSTS.blackjack - CasinoTuning.HIRING_COST == 500, "Unlock purchase/onboarding liquidity")
	for field in ["guest_handle", "guests_served", "cash"]:
		var copy := CasinoSimulation.new()
		check(copy.restore(json_save(sim)), "Ready save roundtrip")
		copy.set(field, 0)
		check(not copy.blackjack_ready(), "Readiness requires " + field)
	var easy := CasinoSimulation.new("easy", ["blackjack", "craps", "roulette", "holdem"])
	check(easy.tables.size() == 4 and easy.staff.size() == 5 and near(easy.cash, 30000) and easy.floor_chunks == CasinoTuning.DIFFICULTIES.easy.floor_chunks, "Easy preferred games and crews")
	check(easy.unlocked("holdem") and easy.slot_unlocked("high_limit"), "Easy unrestricted access")

func game_rules() -> void:
	var random := RandomNumberGenerator.new()
	for id in CasinoTuning.SLOT_PROFILES:
		var p := CasinoTuning.slot_profile(id)
		var counts := [0, 0, 0, 0, 0]
		for symbol in p.reel: counts[symbol] += 1
		var total_return := 0.0
		for a in range(5):
			for b in range(5):
				for c in range(5):
					var award := 0.0
					if a == b and b == c: award = p.pays[a]
					elif [a,b,c].count(0) == 2 or (a == 0 and [a,b,c].count(0) == 1): award = p.cherry_return
					total_return += counts[a] * counts[b] * counts[c] * award / 8000.0
		check(near(total_return, p.rtp) and p.house_edge > 0, "Exact RTP and positive house EV: " + id)
		check(near(p.jackpot_probability, 0.001), "Jackpot probability: " + id)
	check(near(CasinoTuning.slot_profile("starter").rtp, 0.9135), "Starter 91.35% RTP")
	var options := Games.roulette_bets()
	for name in options:
		var returns := 0.0
		for n in range(37): returns += Games.spin_roulette({name: 5.0}, random, n).credit
		check(near(returns / 37.0 / 5.0, 36.0 / 37.0), "Roulette exact EV: " + name)
	for a in range(1, 7):
		for b in range(1, 7):
			var bets := CrapsRules.empty_bets()
			bets.field = 5
			var result := CrapsRules.resolve(0, bets, a, b)
			var expected := 15 if a+b == 2 else 20 if a+b == 12 else 10 if a+b in [3,4,9,10,11] else 0
			check(result.credit == expected and result.bets.field == 0, "Craps field pair %d/%d" % [a,b])
	for point in [4,5,6,8,9,10]:
		var bets := CrapsRules.empty_bets()
		bets.pass = 25
		bets.odds = 30
		var result := CrapsRules.resolve(point, bets, maxi(1, point-6), mini(6, point-1))
		var odds := 2.0 if point in [4,10] else 1.5 if point in [5,9] else 1.2
		check(near(result.credit, 50 + 30 * (1+odds)), "Craps pass/true odds return %d" % point)
	var bj := {"dealer": [8,7], "deck": [], "hands": [{"cards": [12,8], "bet": 10.0, "split": false, "surrender": false}], "insurance": 0.0}
	Games.finish_blackjack(bj)
	check(bj.credit == 25, "Blackjack natural total return 2.5x")
	bj = {"dealer": [8,7], "deck": [], "hands": [{"cards": [7,6], "bet": 10.0, "split": false, "surrender": true}], "insurance": 0.0}
	Games.finish_blackjack(bj)
	check(bj.credit == 5, "Blackjack surrender half stake")
	check(Games.rank_five([12,0,1,2,3]) == [8,5], "Ace-low straight flush")
	check(Games.rank_score(Games.poker_rank([8,9,10,11,12,13,14])) > Games.rank_score([7,14,13]), "Royal flush rank")

func settlements() -> void:
	for kind in ["slots", "blackjack", "roulette", "craps", "holdem"]:
		var sim := CasinoSimulation.new("easy", [kind])
		sim.rng.seed = 333
		var t: Dictionary = sim.tables[0]
		observe(sim)
		sim.opened = true
		var g := seat(sim, t)
		var treasury := sim.cash
		var guest_wallet: float = g.wallet
		if kind == "craps": sim.roll(t.id, [3,4])
		else: sim.npc_games(t)
		check(not events.is_empty(), "Real guest financial feedback: " + kind)
		var net := 0.0
		for event in events:
			if event.category != "gaming": continue
			net += event.amount
			check(near(event.amount, event.settled_stake - event.returned) and event.asset_id == t.id and event.game == kind, "Net/asset event: " + kind)
		check(near(sim.cash-treasury, net) and near(guest_wallet-g.wallet, net), "Guest/treasury/event conservation: " + kind)
		check(near(sim.asset_performance(t).gaming_win, net), "Asset finance reconciliation: " + kind)
		check(g.rounds > 0 and sim.guest_handle > 0, "Real guest progression: " + kind)
		sim.guests.clear()
		sim.joined = t.id
		sim.cash = -10000 # Exposure warnings must never rig outcomes or block credit.
		var sum_before := sim.cash + sim.wallet
		if kind == "craps":
			sim.bet(t.id, "pass", 25)
			sim.roll(t.id, [3,4])
		else:
			if kind == "roulette": sim.roulette_bet(t.id, "Red", t.minimum)
			check(sim.start_game(t.id, t.minimum), "Visitor starts game despite low house cash: " + kind)
			var restored_hand := CasinoSimulation.new()
			check(restored_hand.restore(json_save(sim)), "Current hand save: " + kind)
			while sim.game_pending(t):
				var action := "Decline insurance" if kind == "blackjack" and t.round.phase == "insurance" else "Stand" if kind == "blackjack" else "Check" if t.round.phase != "river" else "Fold"
				check(sim.game_action(t.id, action), "Visitor game action: " + kind)
			var before_duplicate := sim.cash
			var count := events.size()
			sim.settle_game(t)
			check(near(before_duplicate, sim.cash) and count == events.size(), "No duplicate settlement: " + kind)
		check(near(sum_before, sim.cash+sim.wallet), "Owner/treasury conservation: " + kind)
		check(sim.development_cash() <= sim.cash - sim.live_stakes() + 0.001, "Visitor losses cannot inflate readiness: " + kind)

func hospitality_and_departure() -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	observe(sim)
	var guest := seat(sim, sim.tables[0])
	guest.thirst = 20
	guest.last_wager_minute = -1
	sim.drink_access.append("basic")
	sim.drink_menu.append("basic")
	guest.drink_order = "basic"
	guest.drink_quote = 5.0
	var before := sim.cash
	sim.deliver_drink(guest, {"name": "Service", "duty": "Active", "service_product": "basic"})
	check(sim.bar_totals.sold == 1 and sim.bar_totals.comped == 0 and near(sim.cash-before, 4), "Seat without wagers pays $5 drink, $1 product")
	guest.thirst = 20
	guest.last_wager_minute = sim.elapsed
	guest.drink_order = "basic"
	guest.drink_quote = 5.0
	before = sim.cash
	sim.deliver_drink(guest, {"name": "Service", "duty": "Active", "service_product": "basic"})
	check(sim.bar_totals.comped == 1 and near(sim.cash-before, -1), "Recent real wagering comp cost")
	guest.thirst = 20
	guest.state = "Watching"
	check(not sim.gambling_comp_eligible(guest, CasinoTuning.DRINK_PROFILES.basic), "Watching is not comp eligible")
	check(near(sim.bar_margin(), 3) and near(sim.cash, CasinoTuning.STARTING_CASH+sim.net_profit()), "Bar/treasury ledger")
	guest.rounds = 0
	sim.leave(guest, "All machines are taken.", "capacity")
	check(guest.state == "Leaving" and Vector2(guest.tx, guest.ty) == CasinoTuning.ENTRY and sim.guests_served == 0, "Never-gambled direct exit")
	before = sim.cash
	for i in range(200): sim.move_guests(0.1)
	check(sim.cashout_effects.is_empty() and near(before, sim.cash), "Never-gambled no cage transaction")
	guest = seat(sim, sim.tables[0])
	guest.rounds = 1
	sim.leave(guest, "Heading home.")
	check(guest.state == "To cage" and sim.guests_served == 1, "Real gambler cage departure")
	before = sim.cash
	for i in range(300):
		sim.move_guests(0.1)
		if not sim.cashout_effects.is_empty(): break
	check(sim.cashout_effects.size() == 1 and near(before, sim.cash), "Real cage does not double settle")

func traffic_and_saves() -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	check(sim.traffic_snapshot().positions == 2 and sim.traffic_snapshot().limit == 3, "Two slots capacity plus modest demand")
	for i in range(2): seat(sim, sim.tables[i])
	check(sim.traffic_snapshot().occupied == 2, "Actual slot occupancy")
	var rep := sim.reputation
	sim.spawn_guest()
	var waiting: Dictionary = sim.guests.back()
	sim.choose_table(waiting, false)
	check(waiting.seat == -1 and waiting.demand_blocked and waiting.state not in ["To cage", "Cashing out"], "Full floor communicates unmet demand")
	sim.leave(waiting, "Come back later.", "capacity")
	check(near(rep, sim.reputation), "Mild unmet demand reputation-neutral")
	var save := json_save(sim)
	var copy := CasinoSimulation.new()
	check(copy.restore(save), "Current occupied/departing save restores")
	check(JSON.stringify(json_save(copy)) == JSON.stringify(save), "Full current snapshot roundtrip")
	var before := JSON.stringify(copy.snapshot())
	for corrupt in ["version", "cash", "seat", "rng", "milestones", "traffic"]:
		var bad := save.duplicate(true)
		match corrupt:
			"version": bad.version = 1
			"cash": bad.erase("cash")
			"seat": bad.guests[0].seat = 6
			"rng": bad.rng_state = "garbage"
			"milestones": bad.earned_milestones = ["duplicate", "duplicate"]
			"traffic": bad.traffic_totals.occupied_minutes = bad.traffic_totals.position_minutes + 1
		check(not copy.restore(bad), "Invalid current save rejected: " + corrupt)
		check(before == JSON.stringify(copy.snapshot()), "Failed load atomic: " + corrupt)
	for i in range(30):
		sim.move_guests(1)
		sim.step()
		copy.move_guests(1)
		copy.step()
	check(JSON.stringify(json_save(copy)) == JSON.stringify(json_save(sim)), "Seeded continuation after load")
	check(copy.recent_financial_events.size() <= CasinoTuning.MONEY_HISTORY_LIMIT and copy.house_activity.size() <= CasinoTuning.HOUSE_ACTIVITY_LIMIT, "Feedback histories bounded")

func construction_and_navigation() -> void:
	var sim := CasinoSimulation.new()
	observe(sim)
	var nav := sim.floor_navigation()
	check(nav == sim.floor_navigation(), "Navigation reused between geometry changes")
	var before := sim.cash
	var id := sim.place(Vector2(340,180), false, "slots")
	check(id > 0 and sim.tables.size() == 3 and near(before-sim.cash, 750), "Real asset purchase once")
	check(nav != sim.floor_navigation(), "Placement invalidates navigation")
	nav = sim.floor_navigation()
	check(sim.sell(id) and near(sim.cash, before-375), "Half-cost sale")
	check(nav != sim.floor_navigation(), "Sale invalidates navigation")
	check(near(sim.cash, CasinoTuning.STARTING_CASH + sim.net_profit()), "Capital ledger reconciliation")
	var t: Dictionary = sim.tables[0]
	t.broken = true
	sim.incidents.append({"type": "repair", "table": t.id, "title": "Repair", "detail": "Repair"})
	check(not sim.ready_for_play(t), "Broken machine stops earning")
	before = sim.cash
	sim.resolve_incident(0, true)
	check(not t.broken and near(before-sim.cash,120) and t.repair_expense == 120 and t.service_minutes == 0, "Repair debit/analytics/grace")
	for i in range(CasinoTuning.MAX_ASSETS - sim.tables.size()): sim.tables.append(sim.new_table(Vector2(350,350),false,"slots"))
	check(not sim.can_place(Vector2(440,420),false,-1,"slots") and sim.place(Vector2(440,420),false,"slots") == -1, "Runtime asset cap agrees with save bounds")

func long_runs() -> void:
	for mode in ["normal", "easy"]:
		for seed_value in [101,202,303]:
			var sim := CasinoSimulation.new(mode, ["slots", "blackjack", "roulette", "craps", "holdem"])
			sim.rng.seed = seed_value
			sim.opened = true
			var start_cash := sim.cash
			var event_net := [0.0]
			sim.financial_event.connect(func(e):
				if e.category == "gaming":
					event_net[0] += e.amount
					check(near(e.amount, e.settled_stake-e.returned), "Long-run event net")
			)
			var peak := 0
			var started := Time.get_ticks_msec()
			for minute_index in range(2880):
				for motion in range(10): sim.move_guests(0.1)
				sim.step()
				peak = maxi(peak, sim.guests.size())
				check(is_finite(sim.cash) and near(sim.cash, start_cash+sim.net_profit()), "Long-run treasury ledger")
				check(sim.guests.size() <= CasinoTuning.MAX_GUESTS and sim.guests.all(func(g): return g.wallet >= 0 and is_finite(g.wallet)), "Long-run guests bounded and solvent")
				for t in sim.tables:
					var seats := {}
					for g in sim.guests:
						if g.table != t.id or g.seat < 0: continue
						check(not seats.has(int(g.seat)) and int(g.seat) < sim.guest_capacity(t), "Unique usable guest seats")
						seats[int(g.seat)] = true
				if minute_index % 240 == 0:
					var copy := CasinoSimulation.new()
					var saved_ok := copy.restore(json_save(sim))
					if not saved_ok:
						var file := FileAccess.open("/tmp/v03-failed-save.json", FileAccess.WRITE)
						file.store_string(JSON.stringify(sim.snapshot(), "  "))
					check(saved_ok, "Long-run current save")
			check(sim.guest_rounds > 0 and sim.guest_handle > 0, "Long-run real gaming")
			check(near(event_net[0], sim.guest_gaming_profit()), "Long-run settled events reconcile finance")
			print("RUN %s seed=%d minutes=2880 peak=%d handle=%.2f profit=%.2f payroll=%.2f repairs=%.2f ms=%d" % [mode,seed_value,peak,sim.guest_handle,sim.operating_profit(),sim.payroll,sim.expense_totals.repairs,Time.get_ticks_msec()-started])

func ui_checks() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.set_process(false)
	ui.start_casino("easy", ["slots", "blackjack", "roulette", "craps", "holdem"])
	ui.close_modal()
	ui.set_process(false)
	ui.set_dev_speed(100)
	check(ui.speed == 100, "Debug 100x speed")
	ui.set_dev_speed(1000)
	check(ui.speed == 1000, "Debug 1000x speed")
	ui.start_casino("normal", ["slots"])
	ui.close_modal()
	ui.set_process(false)
	check(ui.speed == 1 and ui.previous_speed == 1, "New casino resets extreme speed")
	var elapsed_at_speed := []
	for production_speed in [1,4]:
		ui.start_casino("normal", ["slots"])
		ui.close_modal()
		ui.set_process(false)
		ui.speed = production_speed
		for i in range(48 / production_speed): ui._process(0.25)
		elapsed_at_speed.append(ui.sim.elapsed)
		check(not ui.sim.blackjack_unlocked, "Production speed cannot bypass accomplishments")
	check(elapsed_at_speed == [12,12], "1x/4x advance equal simulated time for proportional wall time")
	ui.start_casino("easy", ["slots", "blackjack", "roulette", "craps", "holdem"])
	ui.close_modal()
	ui.set_process(false)
	ui.sim.opened = true
	for multiplier in [100,1000]:
		ui.set_dev_speed(multiplier)
		var before_elapsed: int = ui.sim.elapsed
		for i in range(30): ui.advance_dev_time(0.1)
		check(ui.sim.elapsed > before_elapsed and ui.dev_time_pending <= ui.DEV_MAX_PENDING_SECONDS, "Extreme speed bounded catch-up %dx" % multiplier)
	check(not ui.sim.snapshot().has("speed"), "Extreme speed never persisted")
	ui.reset_dev_speed()
	ui.start_casino("easy", ["slots", "blackjack", "roulette", "craps", "holdem"])
	ui.close_modal()
	ui.set_process(false)
	for table in ui.sim.tables:
		ui.selected = table.id
		check(ui.sim.join_table(table.id), "Join game UI: " + str(table.kind))
		ui.visitor = true
		ui.refresh()
		await process_frame
		check(ui.game_view.visible if table.kind != "craps" else ui.felt.visible, "Game presentation: " + str(table.kind))
		ui.sim.leave_table()
		ui.visitor = false
	ui.sim.hire("Service", -1)
	# Presentation fixture exercises every money section at realistic multi-digit widths.
	ui.sim.cash = 24934
	ui.sim.revenue = 4348
	ui.sim.payroll = 2056
	ui.sim.expense_totals.dealer_payroll = 2056
	ui.sim.expense_totals.repairs = 140
	ui.sim.expense_totals.construction = 67235
	ui.sim.bar_totals.sold = 10
	ui.sim.bar_totals.revenue = 50
	ui.sim.bar_totals.product_cost = 10
	for dimensions in [Vector2i(1440,900),Vector2i(800,900),Vector2i(844,390),Vector2i(390,844),Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.page = "finance"
		ui.mobile_pane = "table"
		for section in ["", "gaming", "bar", "payroll", "operations", "investment", "assets", "reserve"]:
			ui.finance_section = section
			ui.finance_advanced = section == ""
			ui.refresh()
			await process_frame
			await process_frame
			inspect_money(ui.inspector, dimensions)
	check(Text.house_result(4348) == "+$4,348" and Text.house_result(-2056) == "-$2,056", "Atomic currency formatting")
	ui.queue_free()
	await process_frame

func inspect_money(node: Node, dimensions: Vector2i) -> void:
	if node is Label and "\n" not in node.text and (node.text.begins_with("$") or node.text.begins_with("+$") or node.text.begins_with("-$")):
		check(node.autowrap_mode == TextServer.AUTOWRAP_OFF, "Finance amount nowrap at " + str(dimensions))
		check(node.get_line_count() == 1 and node.size.x >= node.get_minimum_size().x - 1, "Finance amount protected width at " + str(dimensions))
	for child in node.get_children(): inspect_money(child, dimensions)

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


func shooter_tests() -> void:
	var sim := ready_casino()
	check(sim.join_table(1), "Join staffed table through domain API")
	var table: Dictionary = sim.tables[0]
	check(table.shooter == 0, "Visitor may shoot first at an empty table")
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [3, 4]), "Funded visitor dice roll")
	check(table.shooter == 0 and table.point == 0, "Come-out natural retains shooter")
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [1, 1]), "Funded visitor dice roll")
	check(table.shooter == 0, "Come-out craps retains shooter")
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [2, 4]), "Funded visitor dice roll")
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [3, 3]), "Funded visitor dice roll")
	check(table.shooter == 0 and table.point == 0, "Making point retains shooter")
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [2, 4]), "Funded visitor dice roll")
	sim.bet(1, "come", 25)
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [3, 4]), "Funded visitor dice roll")
	check(table.shooter == -2 and table.point == 0, "Seven-out passes dice to CPU")
	check(not sim.shoot_player(1, [3, 4]), "Visitor cannot throw during CPU turn")
	sim.roll(1, [2, 4])
	sim.roll(1, [3, 4])
	check(table.shooter == 0, "CPU seven-out returns dice to next queued visitor")
	sim.bet(1, "pass", 25)
	if sim.tables[0].point == 0 and not sim.shooter_has_line(sim.tables[0]): sim.bet(1, "pass", 25)
	check(sim.shoot_player(1, [2, 4]), "Funded visitor dice roll")
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


func bettor(kind: String, amount: float) -> Dictionary:
	var bets := CrapsRules.empty_bets()
	bets[kind] = amount
	return bets

func ready_casino() -> CasinoSimulation:
	var sim := CasinoSimulation.new("easy", ["craps"])
	sim.rng.seed = 281
	sim.hire("Service", -1)
	sim.opened = true
	return sim

func milestones_and_wear() -> void:
	var sim := CasinoSimulation.new("easy", ["craps"])
	observe(sim)
	sim.opened = true
	var table: Dictionary = sim.tables[0]
	table.minimum = 50.0
	for i in range(7):
		sim.spawn_guest(true)
		var g: Dictionary = sim.guests.back()
		g.table = table.id
		g.seat = i
		g.state = "Playing"
		g.session_left = 1000
	sim.roll(table.id, [3,4])
	check("first_large_loss" in sim.earned_milestones, "Real aggregate craps net triggers major milestone")
	sim.roll(table.id, [6,6])
	check("first_large_win" in sim.earned_milestones, "Real aggregate craps house win milestone")
	var count := milestones.size()
	sim.roll(table.id, [3,4])
	check(milestones.size() == count, "Accomplishments notify once")
	var restored := CasinoSimulation.new()
	check(restored.restore(json_save(sim)), "Milestone/aggregate guest save")
	check(restored.earned_milestones == sim.earned_milestones, "Milestones persist without replay")
	sim = CasinoSimulation.new()
	sim.opened = true
	table = sim.tables[0]
	table.service_minutes = CasinoTuning.slot_profile("starter").repair_grace - 2
	sim.step()
	check(not table.broken, "Starter protected before repair grace")
	sim = CasinoSimulation.new("easy", ["blackjack"])
	var start := sim.cash
	var property_cost := sim.property_upkeep_rate()
	for i in range(60): sim.step()
	check(near(sim.payroll,20) and near(sim.overhead,12 + property_cost) and near(start-sim.cash,32 + property_cost), "One-hour dealer/table/property recurring cost")
	check(near(sim.tables[0].payroll_expense,20) and near(sim.tables[0].operating_expense,12), "Per-asset wages/upkeep")
	var plan := sim.reserve_report("craps")
	check(plan.onboarding == 300 and plan.payroll > 0, "Reserve includes full proposed crew")
	check(sim.asset_payout_buffer("slots", "high_limit") > sim.asset_payout_buffer("slots", "starter"), "Tier exposure scales reserve")
