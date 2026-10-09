extends SceneTree
# Public card tables and roulette must share outcomes in owner and NPC-only play.
const Games = preload("res://scripts/casino_games.gd")
var checks := 0
var failures := 0
func _initialize() -> void: call_deferred("run")
func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("SHARED TABLE FAIL: " + caption)
func seat(sim: CasinoSimulation, table: Dictionary, number: int) -> Dictionary:
	sim.spawn_guest()
	var guest: Dictionary = sim.guests[-1]
	guest.table = table.id
	guest.seat = number
	guest.state = "Playing"
	guest.wallet = 1000.0
	guest.wager_limit = 100.0
	return guest
func run() -> void:
	root.get_node("AudioManager").shutdown()
	await create_timer(0.12).timeout
	for kind in ["blackjack", "holdem", "roulette"]:
		for owner in [false, true]:
			for seed_value in range(12):
				var sim := CasinoSimulation.new("easy", [kind])
				var t: Dictionary = sim.tables[0]
				sim.rng.seed = seed_value
				sim.opened = true
				var guests: Array = [seat(sim, t, 0), seat(sim, t, 1), seat(sim, t, 2)]
				var owner_wallet := sim.owner_bankroll
				var cash := sim.cash
				if owner:
					check(sim.join_table(int(t.id)), "Owner joins " + kind)
					if kind == "roulette": check(sim.roulette_bet(int(t.id), "Red", t.minimum), "Owner roulette stake")
					check(sim.start_game(int(t.id), float(t.minimum)), "Shared owner start " + kind)
					while sim.game_pending(t):
						var action := ""
						if kind == "blackjack": action = "Decline insurance" if t.round.phase == "insurance" else ("Hit" if Games.total(t.round.hands[int(t.round.active)].cards) < 17 else "Stand")
						else: action = "Check" if t.round.phase != "river" else "Raise 1×"
						check(sim.game_action(int(t.id), action), "Shared owner action " + kind)
				else:
					sim.npc_games(t)
					check(sim.owner_bankroll == owner_wallet, "NPC round never changes owner wallet " + kind)
				check(t.rolls == 1 and t.round.paid, "One paid table round " + kind)
				check(guests.all(func(g): return g.rounds == 1), "All seated guests play common round " + kind)
				if kind == "roulette":
					check(sim.roulette_presentation.number == t.round.number and sim.roulette_presentation.wagers.size() == 3, "One shared roulette number")
					for wager in sim.roulette_presentation.wagers:
						var expected := Games.spin_roulette({wager.key: wager.stake}, sim.rng, int(t.round.number))
						check(wager.returned == expected.credit, "Guest paid against same wheel outcome")
				else:
					check(t.round.npcs.size() == (3 if owner else 2), "All guests in common dealer round " + kind)
					for npc in t.round.npcs:
						var g: Dictionary = sim.guests.filter(func(candidate): return candidate.id == npc.id)[0]
						check(g.wallet == 1000 - float(npc.staked) + float(npc.returned), "Funded shared guest payout " + kind)
					if kind == "holdem":
						var used: Array = t.round.player + t.round.dealer + t.round.board
						for npc in t.round.npcs: used.append_array(npc.cards)
						var unique := {}
						for card in used: unique[card] = true
						check(unique.size() == used.size(), "Common Hold'em deck has no duplicated cards")
				var visitor_delta := sim.owner_bankroll - owner_wallet
				var guest_delta := 0.0
				for guest in guests: guest_delta += float(guest.wallet) - 1000
				check(is_equal_approx(sim.cash - cash + visitor_delta + guest_delta, 0), "Shared round conserves money " + kind)
				var credited := sim.cash
				sim.settle_game(t)
				check(sim.cash == credited, "Shared settlement idempotent " + kind)
	root.get_node("AudioManager").shutdown()
	await process_frame
	await create_timer(0.12).timeout
	print("SHARED_TABLES: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
