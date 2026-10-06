extends SceneTree
# Opt-in focused expansion smoke: one round per game, one service/cage trip,
# one in-progress save restore, and construction of the four playable views.
const Games = preload("res://scripts/casino_games.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		printerr("EXPANSION FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var scene := load("res://main.tscn") as PackedScene
	var ui = scene.instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.speed = 0
	ui.start_casino("easy", ["slots", "roulette", "blackjack", "holdem"])
	ui.speed = 0
	var sim: CasinoSimulation = ui.sim
	var initial_cash := sim.cash
	sim.floor_chunks.bottom = 1 # Fixture room for the rotated Holdem starter.
	sim.rng.seed = 7418
	var places := {"slots": Vector2(70,110), "roulette": Vector2(560,110), "blackjack": Vector2(70,350), "holdem": Vector2(560,370)}
	for kind in places:
		var id: int = sim.tables.filter(func(t): return t.kind == kind)[0].id
		var table := sim.get_table(id)
		check(sim.join_table(id), "Join closed, staffed " + kind)
		if kind != "slots":
			sim.spawn_guest()
			var companion: Dictionary = sim.guests[-1]
			companion.state = "Playing"
			companion.table = id
			companion.seat = 1
			companion.wallet = 1000.0
			sim.opened = true
		var wager := float(table.minimum)
		if kind == "roulette":
			check(sim.roulette_bet(id, "Red", wager), "Roulette outside bet")
			check(sim.roulette_bet(id, "Split 0/1", wager), "Roulette inside bet")
		check(sim.start_game(id, wager), "Start " + kind)
		if kind == "holdem":
			check(sim.game_action(id, "Check"), "Hold’em flop")
			var copy := CasinoSimulation.new()
			check(copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "In-progress expansion save loads")
			check(copy.get_table(id).round.phase == "flop" and copy.wallet == sim.wallet and copy.joined == id, "Hold’em state and bankroll preserved")
		var limit := 0
		while sim.game_pending(table) and limit < 20:
			var action := ""
			if kind == "blackjack": action = "Decline insurance" if table.round.phase == "insurance" else ("Hit" if Games.total(table.round.hands[int(table.round.active)].cards) < 17 else "Stand")
			else: action = "Check" if table.round.phase == "flop" else "Raise 1×"
			check(sim.game_action(id, action), "Action " + action)
			limit += 1
		if kind in ["blackjack", "holdem"]:
			check(table.round.npcs.size() == 1, "Guest shares dealer: " + kind)
			var npc: Dictionary = table.round.npcs[0]
			check(absf(sim.guests[-1].wallet - (1000.0 - npc.staked + npc.returned)) < 0.001, "Shared guest settlement: " + kind)
		check(not sim.game_pending(table), "Round completed: " + kind)
		check(absf(sim.cash - (initial_cash + sim.net_profit())) < 0.001, "Treasury reconciles: " + kind)
		var copy := CasinoSimulation.new()
		check(copy.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Completed " + kind + " save loads")
		ui.visitor = true
		ui.selected = id
		ui.refresh()
		ui.game_view.render(table)
		for i in range(3): await process_frame
		check(ui.game_view.is_visible_in_tree(), "Playable view appears: " + kind)
		sim.leave_table()
		sim.opened = false
		sim.guests.clear()
	# Deliver one visual drink, then route the guest through the cage without
	# changing the money that was already settled at their game.
	sim.opened = true
	sim.set_drink_menu("basic", true)
	sim.hire("Service", -1)
	sim.spawn_guest()
	var guest: Dictionary = sim.guests[-1]
	guest.state = "Playing"
	guest.table = sim.tables[0].id
	guest.seat = 0
	guest.wallet = 1000
	sim.npc_games(sim.tables[0])
	guest.state = "Waiting"
	guest.thirst = 20
	guest.drink_order = "basic"
	guest.drink_quote = 5.0
	guest.x = 600.0; guest.y = 240.0; guest.tx = 600.0; guest.ty = 240.0
	for i in range(80): sim.move_service(1.0)
	check(sim.bar_totals.sold + sim.bar_totals.comped > 0, "Service reaches guest")
	var employee: Dictionary = sim.staff[-1]
	check(employee.has("x") and employee.has("service_state"), "Service has a visible floor position")
	var treasury := sim.cash
	var visitor_wallet := sim.wallet
	sim.leave(guest, "Smoke cash-out")
	check(guest.state == "To cage", "Departures visit cage first")
	var appeared := false
	for i in range(80):
		sim.move_guests(0.5)
		if not sim.cashout_effects.is_empty(): appeared = true
	check(appeared and guest.state == "Leaving", "Cage posts house result then sends guest to exit")
	check(sim.cash == treasury and sim.wallet == visitor_wallet, "Cage does not settle money twice")
	print("EXPANSION_SMOKE_OK" if failures == 0 else "EXPANSION_SMOKE_FAILED")
	quit(1 if failures else 0)
