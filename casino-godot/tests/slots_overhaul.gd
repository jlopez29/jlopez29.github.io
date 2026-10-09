extends SceneTree
const Games = preload("res://scripts/casino_games.gd")
var View: GDScript
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("SLOTS FAIL: " + description)

func save(sim: CasinoSimulation) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim.snapshot()))

func close(a: float, b: float) -> bool:
	return absf(a-b) < 0.00001

func run() -> void:
	View = load("res://scripts/game_view.gd")
	model_checks()
	if "--quick" not in OS.get_cmdline_user_args(): math_checks()
	accounting_checks()
	event_checks()
	await presentation_checks()
	await create_timer(0.2).timeout
	print("SLOTS OVERHAUL: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func model_checks() -> void:
	var profile := CasinoTuning.slot_profile("starter")
	var rng := RandomNumberGenerator.new()
	var reference := RandomNumberGenerator.new()
	rng.seed = 429
	reference.seed = 429
	var stops := []
	for i in range(3): stops.append(reference.randi_range(0,19))
	var round := Games.spin_slots(5,rng,profile,5)
	check(round.stops == stops and rng.state == reference.state,"Exactly three committed seeded stops")
	for row in range(3):
		for col in range(3): check(round.grid[row][col] == profile.reel[posmod(stops[col]+row-1,20)],"Adjacent strip position")
	var wrap := Games.slots_at_stops(5,[0,19,0],profile,5)
	check(wrap.grid == [[4,4,4],[0,4,0],[0,0,0]],"Strip wraps both ends")
	for lines in [1,3,5]:
		var all_cherry := Games.slots_at_stops(5,[3,3,3],profile,lines)
		check(all_cherry.winning_lines.size() == lines and close(all_cherry.credit,35),"Simultaneous lines share fixed total wager " + str(lines))
		for index in range(lines):
			check(all_cherry.winning_lines[index].path == CasinoTuning.SLOT_LINES[index] and close(all_cherry.winning_lines[index].returned,35.0/lines),"Payline structure " + str(index))
	check(Games.slots_at_stops(5,[6,5,6],profile,5).winning_lines.any(func(line): return line.index == 3 and line.multiplier == 7),"V line uses top/center/top")
	check(Games.slots_at_stops(5,[4,5,4],profile,5).winning_lines.any(func(line): return line.index == 4 and line.multiplier == 7),"Inverted V uses bottom/center/bottom")
	check(Games.slots_at_stops(5,[7,12,16],profile).credit == 0,"Losing spin")
	check(Games.slots_at_stops(5,[2,7,12],profile).credit == 5,"First-reel single cherry special")
	check(Games.slots_at_stops(5,[2,7,3],profile).credit == 5,"Two-cherry special")
	check(Games.slots_at_stops(5,[7,2,12],profile).credit == 0,"Single cherry on middle reel does not pay")
	check(Games.slots_at_stops(5,[18,18,18],profile).credit == 150,"Seven top award")
	check(Games.valid_round(round,"slots") and Games.valid_round(JSON.parse_string(JSON.stringify(round)),"slots"),"Current round and JSON round validate")
	for bad in ["stop_count","stop_range","stop_fraction","grid_shape","symbol","line_count","win_path","win_money","credit_nan","credit_negative","credit_wrong","profile"]:
		var broken := Games.slots_at_stops(5,[3,3,3],profile,5)
		match bad:
			"stop_count": broken.stops.pop_back()
			"stop_range": broken.stops[0] = 20
			"stop_fraction": broken.stops[0] = 1.5
			"grid_shape": broken.grid[0].pop_back()
			"symbol": broken.grid[0][0] = 5
			"line_count": broken.active_lines = 2
			"win_path": broken.winning_lines[0].path = [0,0,0]
			"win_money": broken.winning_lines[0].returned = 999
			"credit_nan": broken.credit = NAN
			"credit_negative": broken.credit = -1
			"credit_wrong": broken.credit = 90
			"profile": broken.profile = "unknown"
		check(not Games.valid_round(broken,"slots"),"Reject malformed " + bad)

func math_checks() -> void:
	# Exhaustive joint stop distribution, not independent paylines.
	for id in CasinoTuning.SLOT_PROFILES:
		var profile := CasinoTuning.slot_profile(id)
		for lines in [1,3,5]:
			var metrics := CasinoTuning.slot_line_metrics(id,lines)
			check(close(metrics.rtp,profile.rtp),"Exact RTP invariant " + id + "/" + str(lines))
			var total := 0.0
			var largest := 0.0
			for a in range(20):
				for b in range(20):
					for c in range(20):
						var round := Games.slots_at_stops(1,[a,b,c],profile,lines)
						total += float(round.credit)
						largest = maxf(largest,float(round.credit))
			check(close(total/8000,metrics.rtp) and close(largest,metrics.top_return),"Independent full outcome enumeration " + id + "/" + str(lines))
			print("EXACT %s %d lines RTP %.6f max %.3fx sigma %.5f" % [id,lines,metrics.rtp,metrics.top_return,metrics.stddev])
	# High-volume seeded regression for each line count and low/high volatility.
	for id in ["starter","high_limit"]:
		for lines in [1,3,5]:
			var rng := RandomNumberGenerator.new()
			rng.seed = 830491
			var sum := 0.0
			var count := 150000
			var profile := CasinoTuning.slot_profile(id)
			for i in range(count): sum += float(Games.spin_slots(1,rng,profile,lines).credit)
			var metrics := CasinoTuning.slot_line_metrics(id,lines)
			var tolerance := 6 * float(metrics.stddev)/sqrt(count)
			check(absf(sum/count - metrics.rtp) < tolerance,"Seeded 150k RTP within six standard errors " + id + "/" + str(lines))
			print("SEEDED %s %d lines RTP %.6f tolerance %.6f" % [id,lines,sum/count,tolerance])

func accounting_checks() -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	var table: Dictionary = sim.tables[0]
	check(sim.join_table(int(table.id)),"Join starter slot")
	var cash := sim.cash
	var wallet := sim.owner_bankroll
	sim.rng.seed = 567
	check(sim.start_game(int(table.id),5,0,5),"Personal five-line spin")
	var round: Dictionary = table.round.duplicate(true)
	check(close(sim.cash,cash + 5 - float(round.credit)) and close(sim.owner_bankroll,wallet - 5 + float(round.credit)),"Personal stake charged once, real returned amount")
	var settled := sim.cash
	sim.settle_game(table)
	check(sim.cash == settled,"Paid personal round cannot settle twice")
	var copy := CasinoSimulation.new()
	check(copy.restore(save(sim)),"Personal completed round loads")
	copy.settle_game(copy.tables[0])
	check(copy.cash == settled,"Reload cannot replay personal payout")
	var poor := CasinoSimulation.new()
	poor.cash = 1
	poor.rng.seed = 888
	var rich := CasinoSimulation.new()
	rich.cash = 1.0e6
	rich.rng.seed = 888
	check(Games.spin_slots(5,poor.rng,poor.slot_profile(poor.tables[0]),5) == Games.spin_slots(5,rich.rng,rich.slot_profile(rich.tables[0]),5),"No treasury-dependent RNG")
	var npc := CasinoSimulation.new()
	npc.opened = true
	npc.spawn_guest()
	var guest: Dictionary = npc.guests[0]
	guest.state = "Playing"
	guest.table = npc.tables[0].id
	guest.wallet = 100
	var original := npc.cash + float(guest.wallet)
	npc.npc_games(npc.tables[0])
	check(npc.tables[0].rolls == 1 and Games.valid_round(npc.tables[0].round,"slots") and npc.tables[0].round.paid,"NPC produces real paid slot round")
	check(close(npc.cash + float(guest.wallet),original) and npc.owner_bankroll == 1000,"NPC settlement conserves casino + guest money")

func event_checks() -> void:
	for type in ["owner_slots","manufacturer_demo"]:
		var sim := CasinoSimulation.new()
		sim.opened = true
		var rng_state := sim.rng.state
		check(sim.optional_events.spawn(sim,type),"Production eligible " + type)
		var id: int = sim.optional_events.active[0].id
		check(sim.optional_events.engage(sim,id),"Engage " + type)
		var cash := sim.cash
		var wallet := sim.owner_bankroll
		sim.optional_events.rng.seed = 93
		check(sim.start_owner_event(id,5),"Commit " + type)
		var sponsored: bool = type == "manufacturer_demo"
		check(sim.cash == cash and sim.owner_bankroll == wallet - (0 if sponsored else 15),"Funding mode charges only correct source " + type)
		var financial: Array = []
		sim.financial_event.connect(func(event): financial.append(event.duplicate(true)))
		var spins: Array = sim.owner_play.spins.duplicate(true)
		var returned := 0.0
		for round in spins: returned += float(round.credit)
		var total: int = sim.owner_play.rounds
		check(sim.owner_event_action("Spin",0) and not sim.owner_event_action("Spin",0),"Double-click sequence rejected " + type)
		if sponsored:
			check(close(sim.cash,cash + float(spins[0].credit)) and sim.owner_bankroll == wallet,"Sponsor credits each revealed spin without a stake")
			check(financial.size() == (1 if float(spins[0].credit) > 0 else 0) and financial.all(func(event): return event.category == "sponsored_promotion"),"Promotion transaction explicitly classified once")
		var bad := save(sim)
		bad.owner_play.spins[0].credit += 1
		var invalid := CasinoSimulation.new()
		check(not invalid.restore(bad),"Corrupt committed event spin rejected")
		var copy := CasinoSimulation.new()
		check(copy.restore(save(sim)),"Mid-event load " + type)
		check(copy.owner_play.spins == JSON.parse_string(JSON.stringify(spins)),"All committed outcomes survive load " + type)
		for i in range(1,total): check(copy.owner_event_action("Spin",i),"Reveal next committed spin")
		check(copy.owner_play.status == "done" and close(copy.cash,cash + (returned if sponsored else maxf(0,returned-15))),"Exactly one event transfer " + type)
		check(close(copy.owner_bankroll,wallet if sponsored else wallet + minf(0,returned-15)),"Wallet accounting " + type)
		check(copy.rng.state == rng_state and copy.revenue == 0 and copy.payouts == 0 and copy.guest_handle == 0,"Event avoids gaming RNG and revenue " + type)
		check(close(copy.sponsored_income,returned if sponsored else 0),"Explicit sponsor income " + type)
		var settled_cash := copy.cash
		check(copy.exit_owner_event() and copy.cash == settled_cash and not copy.owner_event_action("Spin",total-1),"Exit cannot replay event payout")
		check(copy.restore(save(copy)) and copy.exit_owner_event() and copy.cash == settled_cash,"Completed reload cannot replay payout")
		var early := CasinoSimulation.new()
		early.opened = true
		early.optional_events.spawn(early,type)
		var event_id: int = early.optional_events.active[0].id
		early.optional_events.engage(early,event_id)
		early.start_owner_event(event_id,5)
		check(early.exit_owner_event() and early.owner_play.status == "done","Exiting committed session resolves once " + type)
	var sim := CasinoSimulation.new()
	sim.opened = true
	sim.elapsed = 5
	var state := sim.rng.state
	sim.optional_events.tick(sim)
	check(sim.optional_events.active.any(func(event): return event.type == "manufacturer_demo") and sim.rng.state == state,"Early introductory demo uses event RNG")
	var cash := sim.cash
	var wallet := sim.owner_bankroll
	var rep := sim.reputation
	check(sim.optional_events.resolve(sim,int(sim.optional_events.active[0].id),"dismissed") and sim.cash == cash and sim.owner_bankroll == wallet and sim.reputation == rep,"Ignore has no penalty")
	check(not sim.optional_events.spawn(sim,"manufacturer_demo"),"Meaningful demo cooldown persists")
	var expired := CasinoSimulation.new()
	expired.opened = true
	expired.optional_events.spawn(expired,"manufacturer_demo")
	expired.elapsed = 180
	expired.opened = false
	var expiry_cash := expired.cash
	expired.optional_events.tick(expired)
	check(expired.optional_events.active.is_empty() and expired.cash == expiry_cash and expired.owner_bankroll == 1000,"Expired unengaged demo has no penalty")
	check(sim.restore(save(sim)) and not sim.optional_events.spawn(sim,"manufacturer_demo"),"Reload does not reset cooldown")

func presentation_checks() -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	sim.join_table(int(sim.tables[0].id))
	var view = View.new()
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.sim = PitBossGameContext.new(sim)
	view.paused = false
	view.render_current()
	var before := Vector2(sim.owner_bankroll,sim.cash)
	view.transact(true)
	var round: Dictionary = view.art.round.duplicate(true)
	var cash := sim.cash
	view.transact(true)
	check(view.art.round == round and sim.cash == cash,"Repeat spin is locked before reveal")
	view.render_current()
	check(view.wallet_value.text == preload("res://scripts/financial_text.gd").cash(before.x,2),"Header balance held until reveal")
	check(view.return_button.disabled,"Floor locked during reveal")
	for dimensions in [Vector2i(1440,810),Vector2i(2560,1080),Vector2i(800,600),Vector2i(390,844),Vector2i(844,390),Vector2i(320,568)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		view.layout_play()
		view.render_current()
		await process_frame
		check(view.art.round == round and sim.tables[0].round == round,"Resize preserves committed outcome " + str(dimensions))
		var spin_rect: Rect2 = view.slot_spin.get_global_rect()
		check(spin_rect.end.y <= dimensions.y and spin_rect.end.x <= dimensions.x and spin_rect.position.y >= 0,"Spin remains inside viewport " + str(dimensions))
		check(view.art.size.x > 170 and view.art.size.y > 100,"Reel area retained " + str(dimensions))
	view.art._process(view.art.duration)
	view.render_current()
	check(not view.locked() and not view.return_button.disabled,"Reveal unlocks controls")
	view.open_rules("slots")
	check(view.rules.visible and view.line_diagrams.visible and view.rules_text.text.contains("Total wager is divided equally"),"Paytable with visual paylines")
	view.queue_free()
	await process_frame
