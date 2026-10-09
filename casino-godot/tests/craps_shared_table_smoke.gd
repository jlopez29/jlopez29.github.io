extends SceneTree
# Deterministic public-table settlement and bounded accelerated presentation regression.
var checks := 0
var failures := 0
var felt: Control

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CRAPS SHARED FAIL: " + description)

func guest_at(sim: CasinoSimulation, table: Dictionary, seat: int, state: String = "Playing") -> Dictionary:
	sim.spawn_guest()
	var guest: Dictionary = sim.guests[-1]
	guest.table = table.id
	guest.seat = seat
	guest.state = state
	guest.wallet = 1000.0
	guest.wager_limit = 100.0
	guest.session_left = 1000
	var at := sim.guest_seat_position(table, seat)
	guest.x = at.x
	guest.y = at.y
	return guest

func attach(sim: CasinoSimulation) -> void:
	felt.sim = PitBossGameContext.new(sim)
	felt.initialize_table(sim.get_table(sim.joined))
	felt.locked = false

func saved_copy(sim: CasinoSimulation, label: String) -> CasinoSimulation:
	var restored := CasinoSimulation.new("easy", ["craps"])
	# JSON round trip exercises actual save types, not shared dictionary references.
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), label + " loads")
	check(restored.owner_bankroll == sim.owner_bankroll and restored.cash == sim.cash, label + " money")
	var table := restored.get_table(sim.joined)
	check(table.owner == sim.get_table(sim.joined).owner and table.point == sim.get_table(sim.joined).point and table.shooter == sim.get_table(sim.joined).shooter, label + " contracts/point/shooter")
	return restored

func run() -> void:
	# This regression inspects game state, not audio playback.
	root.get_node("AudioManager").shutdown()
	felt = load("res://presentation/play/craps_surface.gd").new()
	felt.size = Vector2(1200, 760)
	root.add_child(felt)
	felt.set_process(false)
	var sim := CasinoSimulation.new("easy", ["craps"])
	var table: Dictionary = sim.tables[0]
	check(sim.join_table(int(table.id)), "Owner joins")
	attach(sim)
	check(sim.bet(int(table.id), "pass", 25), "$25 Pass")
	check(sim.shoot_player(int(table.id), [2, 3]) and table.point == 5, "Point 5")
	felt.capture_roll(table)
	felt._process(4)
	for pair in [["odds", 50], ["six", 30], ["eight", 30]]:
		check(sim.bet(int(table.id), pair[0], pair[1]), "Legal owner " + pair[0])
	check(sim.remove_bet(int(table.id), "pass") == 0, "Pass locked at point")
	var guest := guest_at(sim, table, 0)
	var other := guest_at(sim, table, 1)
	for bettor in [guest, other]:
		check(sim.take_bet(table, bettor, "pass", 25, false), "Funded guest Pass")
		check(sim.take_bet(table, bettor, "odds", 50, false), "Funded guest odds")
		check(sim.take_bet(table, bettor, "six", 30, false), "Funded guest Place")
	var active := saved_copy(sim, "Active point")
	check(active.guests[0].bets == guest.bets, "Guest contracts restored")
	felt.prepare_roll(table)
	var wallet := sim.owner_bankroll
	var cash := sim.cash
	var paid := sim.payouts
	check(sim.shoot_player(int(table.id), [4, 3]), "Forced seven-out")
	check(table.point == 0 and table.owner.pass == 0 and table.owner.odds == 0 and table.owner.six == 0 and table.owner.eight == 0, "All four owner wagers clear immediately")
	check(sim.owner_bankroll == wallet and sim.cash == cash and sim.payouts == paid, "No second debit or duplicate payout")
	check(CrapsRules.exposure(guest.bets) == 0 and CrapsRules.exposure(other.bets) == 0, "All guests settle same owner dice")
	check(table.shooter == guest.id, "Next seated shooter immediately")
	felt.capture_roll(table)
	check(felt.animation == felt.SETTLE_SECONDS and felt.flights.size() == 10, "Seven-out collection separate from live chips")
	for player in felt.active_wagers(table): check(CrapsRules.exposure(player.bets) == 0, "No stale active chips during collection")
	var flights: Array = felt.flights.duplicate(true)
	felt.capture_roll(table)
	check(felt.flights == flights and sim.owner_bankroll == wallet and sim.payouts == paid, "Duplicate capture inert")
	var seven_saved := saved_copy(sim, "After seven-out")
	attach(seven_saved)
	check(felt.animation == 0 and felt.flights.is_empty(), "Load never replays settlement")
	attach(sim)
	felt._process(1)
	check(felt.delivery > 0 and felt.return_to == felt.shooter_pocket(), "Handoff to next shooter")
	var rotation := saved_copy(sim, "During handoff")
	check(rotation.get_table(int(table.id)).shooter == guest.id, "Shooter rotation survives load")
	# Owner wagers remain live through CPU point establishment and non-settling rolls.
	check(sim.bet(int(table.id), "pass", 25), "Owner bets on CPU come-out")
	sim.roll(int(table.id), [2, 3])
	check(table.shooter == guest.id and table.owner.pass == 25 and table.point == 5, "CPU establishes shared point")
	check(sim.bet(int(table.id), "odds", 50), "Owner CPU-hand odds")
	wallet = sim.owner_bankroll
	sim.roll(int(table.id), [3, 3])
	check(table.owner.pass == 25 and table.owner.odds == 50 and sim.owner_bankroll == wallet, "Owner contracts live on CPU roll")
	sim.roll(int(table.id), [4, 3])
	check(CrapsRules.exposure(table.owner) == 0 and table.shooter == other.id and sim.owner_bankroll == wallet, "CPU seven-out settles owner and rotates")
	# NPC betting happens before roll, once per window, from real wallets.
	sim.opened = true
	sim.rng.seed = 123
	table.shooter = guest.id
	sim.npc_craps_betting(table)
	check(guest.bets.pass > 0, "CPU shooter funded before roll")
	check(guest.wallet == 1000 - 105 - float(guest.bets.pass), "Pre-roll guest wallet debited once")
	var guest_wallet: float = guest.wallet
	var wagered: float = table.wagers
	var rng_state: int = sim.rng.state
	for i in range(20): sim.npc_craps_betting(table)
	check(guest.wallet == guest_wallet and table.wagers == wagered and sim.rng.state == rng_state, "No frame-repeat wagers or RNG")
	attach(sim)
	check(felt.chips_at(felt.endpoint("pass", int(guest.seat))).any(func(c): return c.seat == guest.seat and c.amount == guest.bets.pass), "Funded NPC chips visible before roll")
	var betting_saved := saved_copy(sim, "Pre-roll NPC betting")
	betting_saved.npc_craps_betting(betting_saved.get_table(int(table.id)))
	check(betting_saved.guests[0].wallet == guest.wallet and betting_saved.rng.state == sim.rng.state, "Load does not repeat betting decisions")
	sim.roll(int(table.id), [2, 3])
	var late := guest_at(sim, table, 2)
	var watcher := guest_at(sim, table, 3, "Watching")
	# Bounded seeded decisions over windows exercise optional odds and mid-point Place.
	for i in range(8):
		sim.npc_craps_betting(table)
		if late.bets.six > 0 or late.bets.eight > 0: break
		sim.roll(int(table.id), [2, 2])
	check(late.bets.pass == 0 and (late.bets.six > 0 or late.bets.eight > 0), "Mid-point arrival places legal funded wagers")
	check(guest.bets.odds > 0, "NPC attaches funded Pass odds")
	check(CrapsRules.exposure(watcher.bets) == 0 and watcher.wallet == 1000, "Spectators remain unfunded spectators")
	check(not sim.npc_craps_bet(table, late, "pass", 25), "NPC line rejects mid-point")
	check(not sim.npc_craps_bet(table, late, "odds", 25), "NPC odds need contract")
	late.wallet = 1
	check(not sim.npc_craps_bet(table, late, "eight", 25), "NPC cannot overdraw")
	# The retained chip targets work in desktop and both mobile orientations.
	for dimensions in [Vector2(1200, 760), Vector2(390, 844), Vector2(844, 390)]:
		felt.size = dimensions
		felt.update_view_transform()
		for key in ["pass", "odds", "six", "eight"]:
			check(felt.target_at(felt.spots[key], false) == key, "Target " + key + " at " + str(dimensions))
	felt.size = Vector2(1200, 760)
	# Forced rapid hands: a frame may observe zero, one, or several rolls.
	for speed in [1, 2, 4, 8]:
		var fast := CasinoSimulation.new("easy", ["craps"])
		var t: Dictionary = fast.tables[0]
		fast.join_table(int(t.id))
		fast.bet(int(t.id), "pass", 25)
		fast.shoot_player(int(t.id), [2, 3])
		fast.bet(int(t.id), "odds", 50)
		fast.bet(int(t.id), "six", 30)
		fast.bet(int(t.id), "eight", 30)
		attach(fast)
		var fast_wallet := fast.owner_bankroll
		for hand in range(6):
			fast.roll(int(t.id), [4, 3])
			felt.capture_roll(t)
			check(CrapsRules.exposure(felt.active_wagers(t)[0].bets) == 0, "Immediate visual seven-out at %dx" % speed)
			felt._process(0.4 / speed)
			fast.roll(int(t.id), [2, 3])
			felt.capture_roll(t)
			felt._process(0.4 / speed)
		check(fast.owner_bankroll == fast_wallet, "Accelerated captures never debit/pay at %dx" % speed)
		# Deliberately miss three complete rolls before observing the latest.
		for dice in [[4, 3], [2, 3], [4, 3]]: fast.roll(int(t.id), dice)
		felt.capture_roll(t)
		check(felt.animation == 0 and felt.flights.is_empty() and felt.previous.table.owner == t.owner and felt.reference_dice == t.dice and felt.shooter_seen == t.shooter, "Skipped rolls reconcile at %dx" % speed)
		felt._process(4)
		check(felt.previous.table.rolls == t.rolls, "Presentation catches up at %dx" % speed)
	# Ready completes funded/declined decisions once, then uses canonical settlement.
	var ready_sim := CasinoSimulation.new("easy", ["craps"])
	var ready_table: Dictionary = ready_sim.tables[0]
	ready_sim.opened = true
	ready_sim.join_table(int(ready_table.id))
	var shooter := guest_at(ready_sim, ready_table, 0)
	var declined := guest_at(ready_sim, ready_table, 1)
	declined.wallet = 1
	ready_sim.pass_dice(int(ready_table.id))
	check(ready_sim.roll_interval(ready_table, 100) == 8 and ready_sim.roll_interval(ready_table, 50) == 10, "Attended interval plus fatigue")
	check(ready_sim.bet(int(ready_table.id), "pass", 25), "Ready owner funded Pass")
	var ready_id := int(ready_table.id)
	var reference := saved_copy(ready_sim, "Ready reference")
	reference.npc_craps_betting(reference.get_table(ready_id))
	reference.roll(ready_id, [2, 3])
	attach(ready_sim)
	check(ready_sim.ready_craps_roll(ready_id, 0, false, [2, 3]).is_empty(), "Ready rolls immediately after decisions")
	check(ready_table.rolls == 1 and ready_table.point == 5 and ready_table.dice == [2, 3], "Exactly one shared outcome")
	check(ready_sim.cash == reference.cash and ready_sim.owner_bankroll == reference.owner_bankroll and ready_sim.rng.state == reference.rng.state and shooter.bets == reference.guests[0].bets and shooter.wallet == reference.guests[0].wallet, "Ready matches normal funded accounting and RNG")
	check(declined.craps_betting_window == [ready_id, 0, 0] and declined.wallet == 1, "Declined decision completes without blocking")
	felt.capture_roll(ready_table)
	check(felt.animation > felt.ROLL_END, "Ready displays actual throw")
	var state := ready_sim.rng.state
	check(ready_sim.ready_craps_roll(ready_id, 1) == "Dice settling" and ready_sim.ready_craps_roll(ready_id, 0) == "Dice settling" and ready_table.rolls == 1 and ready_sim.rng.state == state, "Double click cannot bet or roll again")
	ready_sim.craps_roll_blocked = -1
	check(ready_sim.ready_craps_roll(ready_id, 1, true) == "Resume time first", "Paused Ready rejected")
	ready_table.betting_hold = true
	check(ready_sim.ready_craps_roll(ready_id, 1) == "Resume rolls first", "Held Ready rejected")
	ready_table.betting_hold = false
	ready_sim.opened = false
	check(ready_sim.ready_craps_roll(ready_id, 1) == "Waiting for table", "Closed Ready rejected")
	ready_sim.opened = true
	var crew_member: Dictionary = ready_sim.crew(ready_id)[0]
	crew_member.duty = "Break"
	check(ready_sim.ready_craps_roll(ready_id, 1) == "Table not staffed", "Unstaffed Ready rejected")
	crew_member.duty = "Active"
	check(ready_sim.bet(ready_id, "odds", 50), "Ready funded owner odds")
	var arrival := guest_at(ready_sim, ready_table, 2)
	var winning := saved_copy(ready_sim, "Ready payout reference")
	winning.npc_craps_betting(winning.get_table(ready_id))
	winning.roll(ready_id, [2, 3])
	check(ready_sim.ready_craps_roll(ready_id, 1, false, [2, 3]).is_empty(), "Ready revalidates arrival and changed wager")
	check(arrival.craps_betting_window == [ready_id, 1, 5] and ready_sim.owner_bankroll == winning.owner_bankroll and ready_sim.cash == winning.cash and shooter.wallet == winning.guests[0].wallet, "Ready canonical owner and NPC payouts")
	ready_sim.craps_roll_blocked = -1
	check(ready_sim.bet(ready_id, "pass", 25), "New CPU hand line")
	check(ready_sim.ready_craps_roll(ready_id, 2, false, [2, 3]).is_empty(), "CPU establishes next point")
	ready_sim.craps_roll_blocked = -1
	check(ready_sim.ready_craps_roll(ready_id, 3, false, [4, 3]).is_empty(), "Ready seven-out")
	check(ready_table.point == 0 and ready_table.owner.pass == 0 and shooter.bets.pass == 0 and ready_table.shooter == declined.id, "Ready seven-out clears and rotates")
	felt._process(10)
	felt.initialize_table(ready_table)
	declined.wallet = 1000 # Keep this seated participant through the scheduling check.
	ready_table.timer = 7
	ready_sim.step()
	check(ready_table.timer == 7 and ready_table.rolls == 4, "Animation lock freezes automatic schedule")
	ready_sim.craps_roll_blocked = -1
	ready_table.timer = ceilf(ready_sim.roll_interval(ready_table, ready_sim.craps_dealer_energy(ready_table)))
	ready_sim.step()
	check(ready_table.rolls == 5, "CPU still rolls automatically without Ready")
	# Forty extra guests must not become Ready participants or receive wager attempts.
	var bystanders: Array = []
	for i in range(40):
		ready_sim.spawn_guest()
		var bystander: Dictionary = ready_sim.guests[-1]
		bystander.state = "Watching"
		bystander.table = -1
		bystander.wallet = 1000
		bystanders.append(bystander)
	ready_sim.craps_roll_blocked = -1
	var ready_started := Time.get_ticks_usec()
	check(ready_sim.ready_craps_roll(ready_id, 5, false, [2, 3]).is_empty(), "Ready with forty extra guests")
	check(bystanders.all(func(g): return g.wallet == 1000 and not g.has("craps_betting_window")), "Only seated participating guests decide")
	print("Ready with 40 extra guests: %.2f ms" % ((Time.get_ticks_usec() - ready_started) / 1000.0))
	ready_sim.leave_table()
	check(ready_sim.roll_interval(ready_table, 100) == CasinoTuning.ROLL_SECONDS, "Background cadence unchanged")
	# Real step cadence at all supported speeds, with identical seeded economics.
	var economy: Array = []
	var started := Time.get_ticks_usec()
	for speed in [1, 2, 4, 8]:
		var timed := CasinoSimulation.new("easy", ["craps"])
		timed.rng.seed = 771
		var t: Dictionary = timed.tables[0]
		timed.join_table(int(t.id))
		timed.pass_dice(int(t.id))
		timed.opened = true
		guest_at(timed, t, 0)
		guest_at(timed, t, 1)
		attach(timed)
		var tick := 0.0
		var reconciled := true
		for frame in range(2400 / speed):
			tick += 0.05 * speed
			while tick >= 1.0 - 0.00001:
				tick -= 1
				timed.step()
			felt._process(0.05)
			if felt.last_roll != t.rolls or felt.active_wagers(t)[0].bets != t.owner: reconciled = false
		check(reconciled and t.rolls > 3, "Actual sim.step and display at %dx" % speed)
		var outcome := [timed.cash, timed.revenue, timed.payouts, timed.owner_bankroll, timed.rng.state, t.rolls, t.point, t.owner, timed.guests.map(func(g): return [g.id, g.wallet, g.bets])]
		if economy.is_empty(): economy = outcome.duplicate(true)
		else: check(economy == outcome, "Speed preserves funded wagers/economy/RNG at %dx" % speed)
	print("Four speed cohorts (480 simulation steps): %.1f ms" % ((Time.get_ticks_usec() - started) / 1000.0))
	# Preserve payouts and come-out off/working rules across every dice pair.
	for point in [0, 5]:
		for working in [false, true]:
			for a in range(1, 7):
				for b in range(1, 7):
					var rules := CasinoSimulation.new("easy", ["craps"])
					var t: Dictionary = rules.tables[0]
					var bets := CrapsRules.empty_bets()
					for key in ["pass", "odds", "dont_pass", "lay_odds", "six", "eight", "come", "come_5", "come_odds_5", "dont_come", "dont_come_6", "dont_come_odds_6", "field", "hard_6", "any_seven", "yo"]: bets[key] = 30.0
					t.owner = bets
					t.point = point
					t.owner_working = working
					var expected := CrapsRules.resolve(point, bets, a, b, working)
					var before_wallet := rules.owner_bankroll
					rules.roll(int(t.id), [a, b])
					check(t.owner == expected.bets and t.point == expected.point and rules.owner_bankroll == before_wallet + float(expected.credit), "Canonical common rules/payouts")
	print("CRAPS_SHARED_TABLE: %d checks, %d failures" % [checks, failures])
	felt.queue_free()
	root.get_node("AudioManager").shutdown()
	await create_timer(0.12).timeout
	call_deferred("quit", 1 if failures else 0)
