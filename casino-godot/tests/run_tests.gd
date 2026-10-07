extends "res://tests/run_v03_tests.gd"
# Current regression entry point plus owner bankroll/optional framework checks.

func startup_and_progression() -> void:
	super.startup_and_progression()
	objective_checks()
	momentum_checks()
	owner_foundation()
	optional_framework()
	owner_gambling_events()
	floor_event_catalog()
	floor_crowds_and_payouts()

func owner_foundation() -> void:
	var sim := CasinoSimulation.new()
	var initial_cash := sim.cash
	check(sim.owner_bankroll == 1000 and initial_cash == CasinoTuning.STARTING_CASH, "Owner initialization separate from treasury")
	for amount in [-1.0, 0.0, 1001.0, NAN, INF]:
		check(not sim.owner_wager_debit(1, amount), "Reject invalid owner wager " + str(amount))
	check(sim.owner_wager_debit(1, 100), "Owner stake enters escrow")
	check(sim.owner_bankroll == 900 and sim.cash == initial_cash, "Escrow never funds own house")
	check(not sim.owner_wager_debit(1, 100), "Double submit debit rejected")
	check(not sim.owner_wager_settle(1, NAN) and not sim.owner_wager_settle(1, -1), "Invalid owner return leaves escrow intact")
	var restored := CasinoSimulation.new()
	check(restored.restore(json_save(sim)), "Pending owner wager survives JSON save")
	check(restored.owner_wager_settle(1, 200), "Even money owner win settles")
	check(restored.owner_bankroll == 1000 and restored.cash == initial_cash + 100 and restored.net_profit() == 100, "Original stake preserved; only net winnings are casino profit")
	check(not restored.owner_wager_settle(1, 200), "Double settlement rejected")
	check(restored.restore(json_save(restored)) and not restored.owner_wager_settle(1, 200), "Settled ID remains rejected after load")
	check(restored.owner_wager_debit(2, 100) and restored.owner_wager_loss(2), "Owner loss path")
	check(restored.owner_bankroll == 900 and restored.cash == initial_cash + 100, "Owner loss affects personal bankroll only")
	check(restored.owner_wager_debit(3, 100) and restored.owner_wager_refund(3), "Owner push/refund")
	check(restored.owner_bankroll == 900 and not restored.owner_wager_refund(3), "Push preserves stake exactly once")
	check(restored.reward_owner_bankroll(4, 50, "objective") and not restored.reward_owner_bankroll(4, 50, "objective"), "Controlled reward is idempotent")
	check(restored.owner_bankroll == 950 and restored.cash == initial_cash + 100, "Reward funds personal balance only")
	check(not restored.reward_owner_bankroll(5, INF, "bad") and not restored.reward_owner_bankroll(5, CasinoTuning.OWNER_MAX_REWARD + 1, "bad"), "Reward limits enforced")
	check(restored.owner_wager_debit(5, 100) and restored.owner_wager_win(5, 50), "Net profit API restores stake and transfers winnings")
	check(restored.owner_bankroll == 950 and restored.cash == initial_cash + 150, "Net profit API accounting")
	check(restored.owner_wager_debit(6, 100) and restored.owner_wager_settle(6, 60), "Partial loss accepts a total return")
	check(restored.owner_bankroll == 910 and restored.cash == initial_cash + 150, "Partial loss stays personal")
	var legacy := json_save(sim)
	legacy.erase("owner_bankroll")
	legacy.erase("optional_events")
	legacy.wallet = 735.0
	check(restored.restore(legacy) and restored.owner_bankroll == 735 and restored.cash == initial_cash, "Previous wallet migrated without resetting casino cash")
	legacy.erase("wallet")
	check(restored.restore(legacy) and restored.owner_bankroll == 1000, "Missing personal balance defaults safely")
	var bad := json_save(restored)
	bad.owner_bankroll.balance = -10
	var before := JSON.stringify(restored.snapshot())
	check(not restored.restore(bad) and JSON.stringify(restored.snapshot()) == before, "Invalid account load is atomic")
	var game: Dictionary = sim.tables[0]
	check(sim.game_debit(game, 5) and sim.owner_bankroll == 895 and sim.cash == initial_cash + 5, "Normal games use unified owner bankroll with existing accounting")
	sim.game_credit(game, 10)
	check(sim.owner_bankroll == 905 and sim.cash == initial_cash - 5, "Normal floor winnings stay personal and conserve money")

func optional_framework() -> void:
	var sim := CasinoSimulation.new()
	var events = sim.optional_events
	check(not events.spawn(sim, "floor_tip"), "Closed casino cannot spawn floor opportunity")
	sim.opened = true
	var rng_before := sim.rng.state
	var cash_before := sim.cash
	var rep_before := sim.reputation
	check(events.spawn(sim, "floor_tip"), "Eligible opportunity spawns")
	check(not events.spawn(sim, "floor_tip", true), "Duplicate event type blocked")
	var id: int = events.active[0].id
	check(events.resolve(sim, id, "dismissed"), "Opportunity can be ignored")
	check(sim.cash == cash_before and sim.reputation == rep_before and sim.owner_bankroll == 1000 and sim.rng.state == rng_before, "Opportunity ignore has no penalty or gambling RNG effect")
	check(not events.resolve(sim, id, "dismissed") and not events.spawn(sim, "floor_tip"), "Resolved ID and cooldown cannot be bypassed")
	check(events.spawn(sim, "floor_tip", true), "Developer can trigger opportunity without changing production tuning")
	id = int(events.active[0].id)
	check(not events.resolve(sim, id, "success"), "Success requires engagement")
	var requests: Array = []
	events.action_requested.connect(func(event): requests.append(event))
	check(events.engage(sim, id) and not events.engage(sim, id) and requests.size() == 1, "Async action emits exactly once")
	var copy := CasinoSimulation.new()
	check(copy.restore(json_save(sim)) and copy.optional_events.active[0].state == "engaged", "Engaged event saved without duplicate requests")
	check(copy.optional_events.resolve(copy, id, "success") and not copy.optional_events.resolve(copy, id, "success"), "Async completion idempotent after reload")
	sim.elapsed = int(events.active[0].expires)
	events.tick(sim)
	check(events.active.is_empty() and sim.cash == cash_before and sim.reputation == rep_before, "Opportunity expiration has no penalty")
	check(events.spawn(sim, "management_sample", true), "Management sample spawn")
	id = int(events.active[0].id)
	check(events.resolve(sim, id, "dismissed") and sim.reputation == rep_before - 0.25, "Explicit management dismissal consequence")
	check(events.spawn(sim, "emergency_sample", true), "Emergency sample spawn")
	id = int(events.active[0].id)
	sim.elapsed = int(events.active[0].expires)
	events.tick(sim)
	check(sim.reputation == rep_before - 1.25 and not events.resolve(sim, id, "expired"), "Explicit emergency expiry consequence exactly once")
	events.spawn(sim, "floor_tip", true)
	events.spawn(sim, "management_sample", true)
	events.spawn(sim, "emergency_sample", true)
	check(events.active.size() == 3 and events.active[0].type == "emergency_sample", "Urgent events lead the bounded notification queue")
	var save := json_save(sim)
	check(copy.restore(save) and copy.optional_events.history.size() == events.history.size(), "Event cooldowns/history preserved")
	var overdue := save.duplicate(true)
	overdue.optional_events.next_check = 0
	check(copy.restore(overdue) and copy.optional_events.next_check == copy.elapsed + CasinoTuning.EVENT_INTERVAL_MINUTES, "Load defers overdue check without event storm")
	var once_loaded := json_save(copy)
	var next_check_at: int = copy.optional_events.next_check
	check(copy.restore(once_loaded) and copy.optional_events.next_check == next_check_at and copy.optional_events.active.size() == 3, "Repeated reload preserves check time and does not duplicate queued events")
	var before := JSON.stringify(copy.snapshot())
	save.optional_events.next_id = NAN
	check(not copy.restore(save) and JSON.stringify(copy.snapshot()) == before, "Invalid event save rejected atomically")

func ui_checks() -> void:
	await super.ui_checks()
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.start_casino("normal", ["slots"])
	ui.close_modal()
	ui.set_process(false)
	ui.sim.opened = true
	ui.sim.optional_events.spawn(ui.sim, "floor_tip", true)
	for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.transition_pane("floor")
		ui.refresh()
		await process_frame
		check(ui.hud_summary.get_line_count() == 1 and ui.hud_summary.get_minimum_size().x <= ui.hud_summary.size.x, "Owner HUD remains atomic " + str(dimensions))
		if ui.mobile:
			check(not ui.events_panel.visible and ui.floor_view.visible and ui.event_nav.text == "More" and ui.sim.optional_events.active.size() == 1, "Mobile event stays off targeting surface " + str(dimensions))
		ui.transition_pane("log")
		ui.refresh()
		await process_frame
		check(ui.event_cards.visible and ui.event_cards.engage.custom_minimum_size.y >= 44, "Touch-friendly event card in activity area " + str(dimensions))
	check(ui.sim.optional_events.action_requested.get_connections().size() == 1, "New game binds a single event action subscription")
	ui.event_cards.engage.pressed.emit()
	check(ui.sim.optional_events.active.is_empty() and ui.page == "table", "UI engagement resolves focus action")
	ui.owner_checkpoint_path = "/tmp/neon-owner-event-checkpoint.json"
	check(ui.sim.optional_events.spawn(ui.sim, "owner_slots", true), "Owner opportunity enters existing notification surface")
	ui.transition_pane("log")
	ui.refresh()
	ui.event_cards.engage.pressed.emit()
	check(ui.event_cards.commit.visible and ui.sim.owner_play.is_empty() and ui.sim.owner_bankroll == 1000, "Review stake is not a funded wager or a modal")
	ui.event_cards.commit.pressed.emit()
	await process_frame
	check(not ui.sim.owner_play.is_empty() and ui.game_view.visible and not ui.events_panel.visible and ui.sim.joined == -1, "Owner game launches existing view without joining NPC table")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(ui.owner_checkpoint_path))
	var copy := CasinoSimulation.new()
	check(copy.restore(saved) and copy.owner_play.spins.size() == 3 and copy.owner_bankroll == 985, "Commitment creates a real local save checkpoint")
	for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.layout_ui()
		ui.game_view.render_current()
		await process_frame
		check(ui.game_view.visible and not ui.events_panel.visible and not ui.inspector_panel.visible, "Event notifications do not overlay playable controls " + str(dimensions))
		check(find_button(ui.game_view.actions, "Spin") != null, "Existing slot play control retained " + str(dimensions))
	ui.leave_table()
	check(ui.sim.owner_play.is_empty() and ui.floor_view.visible, "Owner result returns cleanly to casino management")
	saved = JSON.parse_string(FileAccess.get_file_as_string(ui.owner_checkpoint_path))
	check(copy.restore(saved) and copy.owner_play.is_empty() and copy.owner_account.pending.is_empty(), "Exit writes a settled checkpoint without duplicate escrow")
	ui.start_casino("easy", ["blackjack"])
	ui.close_modal()
	ui.set_process(false)
	ui.sim.opened = true
	check(ui.sim.optional_events.spawn(ui.sim, "owner_blackjack", true), "Blackjack opportunity enters activity UI")
	ui.transition_pane("log")
	ui.refresh()
	ui.event_cards.engage.pressed.emit()
	ui.sim.optional_events.rng.seed = 15
	ui.event_cards.commit.pressed.emit()
	await process_frame
	for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.layout_ui()
		ui.game_view.render_current()
		await process_frame
		check(ui.game_view.visible and not ui.events_panel.visible and not ui.inspector_panel.visible, "Blackjack event keeps controls visible " + str(dimensions))
		if ui.sim.owner_play.status == "playing":
			var legal_actions := Games.actions(ui.sim.owner_event_table().round, ui.sim.owner_bankroll)
			check(not legal_actions.is_empty(), "Actual blackjack actions available " + str(dimensions))
			for action in legal_actions:
				check(find_button(ui.game_view.actions, action) != null, "Legal blackjack action rendered " + action + str(dimensions))
	ui.leave_table()
	check(ui.sim.owner_play.is_empty() and ui.floor_view.visible, "Blackjack event exit returns to management")
	ui.queue_free()
	await process_frame

func owner_offer(kind: String) -> CasinoSimulation:
	var sim := CasinoSimulation.new("easy", [kind])
	sim.opened = true
	check(sim.optional_events.spawn(sim, "owner_" + kind, true), "Existing game event spawns: " + kind)
	var event: Dictionary = sim.optional_events.active[0]
	check(sim.optional_events.engage(sim, int(event.id)), "Owner game can be reviewed without funding: " + kind)
	return sim

func owner_gambling_events() -> void:
	for desired in ["Loss", "Push", "Win"]:
		var sim := owner_offer("slots")
		var control := RandomNumberGenerator.new()
		var seed_value := 1
		var returned := 0.0
		while seed_value < 2000:
			control.seed = seed_value
			returned = 0
			for i in range(3): returned += float(Games.spin_slots(5, control, sim.slot_profile(sim.tables[0])).credit)
			if (desired == "Loss" and returned < 15) or (desired == "Push" and returned == 15) or (desired == "Win" and returned > 15): break
			seed_value += 1
		check(seed_value < 2000, "Find actual seeded slot outcome " + desired)
		sim.optional_events.rng.seed = seed_value
		var rng_before := sim.rng.state
		var cash_before := sim.cash
		var event_id: int = sim.optional_events.active[0].id
		check(not sim.start_owner_event(event_id, NAN) and not sim.start_owner_event(event_id, 10), "Invalid/unavailable event stakes rejected")
		check(sim.start_owner_event(event_id, 5), "Slot event commits 3 spins")
		check(sim.owner_bankroll == 985 and sim.cash == cash_before and sim.owner_play.spins.size() == 3, "Slot batch funds escrow without house revenue")
		check(not sim.start_owner_event(event_id, 5) and not sim.optional_events.resolve(sim, event_id, "dismissed"), "Funded event cannot be funded twice or dismissed into a refund")
		check(sim.owner_event_action("Spin", 0) and not sim.owner_event_action("Spin", 0), "Repeated spin action rejected")
		var copy := CasinoSimulation.new()
		check(copy.restore(json_save(sim)), "Mid-batch slot event reload")
		check(copy.owner_play.spins == JSON.parse_string(JSON.stringify(sim.owner_play.spins)), "Reload preserves committed slot outcomes")
		check(copy.exit_owner_event(), "Leaving settles remaining committed spins")
		check(copy.owner_play.result.outcome == desired and near(copy.owner_bankroll, 1000 + minf(0, returned - 15)) and near(copy.cash, cash_before + maxf(0, returned - 15)), "Actual slot event net accounting: " + desired)
		check(copy.rng.state == rng_before and copy.revenue == 0 and copy.payouts == 0 and copy.guest_handle == 0, "Event never double counts NPC or consumes casino RNG")
		var settled_cash := copy.cash
		check(copy.exit_owner_event() and copy.cash == settled_cash and not copy.owner_event_action("Spin", 1), "Exit/settlement cannot pay twice")
		check(copy.restore(json_save(copy)) and copy.cash == settled_cash, "Completed event reload keeps one payout")
	var sim := owner_offer("blackjack")
	var id: int = sim.optional_events.active[0].id
	sim.optional_events.rng.seed = 15
	check(sim.start_owner_event(id, 10), "Blackjack event uses real deal")
	if sim.owner_play.status == "playing":
		var copy := CasinoSimulation.new()
		check(copy.restore(json_save(sim)), "Live blackjack cards and escrow reload")
		check(copy.owner_play.round.deck == JSON.parse_string(JSON.stringify(sim.owner_play.round.deck)), "Blackjack shoe cannot reroll on load")
		check(copy.exit_owner_event(), "Leaving live blackjack stands remaining hands")
		check(copy.owner_play.status == "done" and copy.owner_account.pending.is_empty(), "Blackjack exit settles escrow")
	# Search genuine deals for extra-stake and split tests, never substitute outcomes.
	for wanted in ["Double", "Split", "Insurance"]:
		var played := false
		for seed_value in range(1, 500):
			var trial := owner_offer_unchecked("blackjack", seed_value)
			if trial.owner_play.status == "done" or not Games.actions(trial.owner_play.round, trial.owner_bankroll).has(wanted): continue
			var sequence: int = trial.owner_play.sequence
			var additional: float = Games.actions(trial.owner_play.round, trial.owner_bankroll)[wanted]
			check(trial.owner_event_action(wanted, sequence), "Real event action: " + wanted)
			check(not trial.owner_event_action(wanted, sequence), "Duplicate extra stake rejected: " + wanted)
			check(near(trial.owner_play.staked, 10 + additional) and trial.revenue == 0, "Extra stakes escrowed outside casino revenue: " + wanted)
			var saved := json_save(trial)
			var copy := CasinoSimulation.new()
			check(copy.restore(saved) and copy.exit_owner_event(), "Extra-stake hand save/exit: " + wanted)
			played = true
			break
		check(played, "Eligible actual deal available for " + wanted)
	var blocked := owner_offer("slots")
	var blocked_id: int = blocked.optional_events.active[0].id
	blocked.owner_checkpoint = func(): return false
	check(not blocked.start_owner_event(blocked_id, 5) and blocked.owner_bankroll == 1000 and blocked.owner_play.is_empty(), "Unavailable storage prevents funded commitment")
	var checkpoints := [0]
	blocked.owner_checkpoint = func():
		checkpoints[0] += 1
		return checkpoints[0] % 2 == 1
	check(not blocked.start_owner_event(blocked_id, 5) and blocked.owner_bankroll == 1000 and blocked.owner_play.is_empty(), "Post-commit storage failure rolls back personal escrow and session")

func owner_offer_unchecked(kind: String, seed_value: int) -> CasinoSimulation:
	var sim := CasinoSimulation.new("easy", [kind])
	sim.opened = true
	sim.optional_events.spawn(sim, "owner_" + kind, true)
	var id: int = sim.optional_events.active[0].id
	sim.optional_events.engage(sim, id)
	sim.optional_events.rng.seed = seed_value
	sim.start_owner_event(id, 10)
	return sim

func floor_event_catalog() -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	for type in ["owner_blackjack", "busy_table", "slot_crowd", "jackpot_celebration", "drink_demand", "service_rush", "staff_fatigue", "machine_repair", "guest_complaint"]:
		check(not sim.optional_events.eligible(sim, type), "No impossible starter context: " + type)
	var table: Dictionary = sim.tables[0]
	table.broken = true
	sim.incidents.append({"type": "repair", "table": int(table.id), "title": "Fixture real repair", "detail": "Broken"})
	check(sim.optional_events.spawn(sim, "machine_repair", true) and int(sim.optional_events.active[0].target) == int(table.id), "Repair event references real breakdown")
	var id: int = sim.optional_events.active[0].id
	var cash_before := sim.cash
	var cost := sim.repair_cost(table)
	check(sim.optional_events.respond(sim, id, "repair") and not table.broken and sim.cash == cash_before - cost, "Repair response uses actual incident transaction once")
	check(not sim.optional_events.respond(sim, id, "repair") and sim.cash == cash_before - cost, "Repeated repair response cannot spend twice")
	sim = CasinoSimulation.new("easy", ["blackjack"])
	sim.opened = true
	table = sim.tables[0]
	sim.staff[0].energy = CasinoTuning.STAFF_BREAK_ENERGY
	check(sim.optional_events.spawn(sim, "staff_fatigue", true) and int(sim.optional_events.active[0].target) == int(sim.staff[0].id), "Fatigue event targets existing tired dealer")
	id = int(sim.optional_events.active[0].id)
	var rep_before := sim.reputation
	check(sim.optional_events.resolve(sim, id, "dismissed") and sim.reputation == rep_before, "Production fatigue event adds no artificial penalty")
	sim.staff[0].energy = 100
	check(not sim.optional_events.eligible(sim, "staff_fatigue"), "Rested staff do not request fatigue relief")
	sim.purchase_bar()
	sim.hire("Service", -1)
	sim.set_drink_menu("basic", true)
	for i in range(3):
		sim.spawn_guest()
		sim.guests.back().drink_order = "basic"
		sim.guests.back().drink_quote = 5
	check(sim.optional_events.eligible(sim, "service_rush") and sim.optional_events.eligible(sim, "drink_demand"), "Real staffed/menu bar and outstanding orders permit demand events")
	for guest in sim.guests: guest.drink_order = ""
	check(not sim.optional_events.eligible(sim, "service_rush"), "No service rush after actual orders clear")
	sim.incidents.append({"type": "service", "table": -1, "title": "Fixture complaint", "detail": "Needs service"})
	check(sim.optional_events.spawn(sim, "guest_complaint", true), "Real service complaint permits floor event")
	id = int(sim.optional_events.active[0].id)
	cash_before = sim.cash
	check(sim.optional_events.respond(sim, id, "comp") and sim.cash == cash_before - 60 and sim.incidents.is_empty(), "Complaint comp reuses existing settlement")
	check(not sim.optional_events.respond(sim, id, "comp"), "Complaint comp cannot replay")

func floor_crowds_and_payouts() -> void:
	var sim := CasinoSimulation.new("easy", ["blackjack"])
	sim.opened = true
	var table: Dictionary = sim.tables[0]
	var first := seat(sim, table, 0)
	var second := seat(sim, table, 1)
	for i in range(CasinoTuning.HOT_WAGER_COUNT):
		check(sim.game_debit(table, 10, first if i % 2 == 0 else second), "Fund real hot-table guest wager")
	check(sim.optional_events.eligible(sim, "busy_table"), "Real players and recent wagers produce busy-table event")
	sim.opened = false
	check(not sim.optional_events.eligible(sim, "busy_table"), "Closed hot table cannot produce crowd opportunity")
	sim = CasinoSimulation.new("easy", ["slots"])
	sim.opened = true
	table = sim.tables[0]
	first = seat(sim, table)
	sim.spawn_guest()
	var watcher: Dictionary = sim.guests.back()
	watcher.table = int(table.id)
	watcher.seat = -1
	watcher.state = "Watching"
	check(sim.optional_events.spawn(sim, "slot_crowd", true), "Actual slot player and observer produce crowd opportunity")
	var rep := sim.reputation
	var cash := sim.cash
	var id: int = sim.optional_events.active[0].id
	check(sim.optional_events.resolve(sim, id, "dismissed") and sim.reputation == rep and sim.cash == cash, "Crowd opportunity ignores without consequences")
	watcher.table = -1
	check(not sim.optional_events.eligible(sim, "slot_crowd"), "No crowd opportunity when observer leaves")
	# Use a genuine standard-machine top award, with the same paytable and RNG.
	table.slot_profile = "standard"
	table.minimum = 10.0
	var control := RandomNumberGenerator.new()
	var winning_seed := 0
	var round: Dictionary = {}
	for seed_value in range(1, 10000):
		control.seed = seed_value
		round = Games.spin_slots(10, control, sim.slot_profile(table))
		if float(round.credit) - 10 >= CasinoTuning.EVENT_GUEST_BIG_WIN:
			winning_seed = seed_value
			break
	check(winning_seed > 0, "Find an actual big guest payout")
	check(sim.game_debit(table, 10, first), "Fund genuine guest payout stake")
	sim.game_credit(table, float(round.credit), first)
	sim.emit_gaming_result(table, 10, float(round.credit), int(first.id))
	check(sim.optional_events.spawn(sim, "jackpot_celebration", true), "Already settled real guest slot payout enables celebration")
	cash = sim.cash
	id = int(sim.optional_events.active[0].id)
	check(sim.optional_events.resolve(sim, id, "dismissed") and sim.cash == cash, "Jackpot celebration never pays a second award")
	sim.elapsed += CasinoTuning.HOT_ACTIVITY_MINUTES + 1
	check(not sim.optional_events.eligible(sim, "jackpot_celebration"), "Stale payout cannot trigger a new celebration")

func momentum_checks() -> void:
	var sim := CasinoSimulation.new()
	check(sim.momentum.value == CasinoTuning.MOMENTUM_BASELINE and sim.momentum.band() == "Busy", "Momentum starts at operational baseline")
	var steady := CasinoSimulation.Momentum.new()
	var managed := CasinoSimulation.Momentum.new()
	managed.outcome(CasinoTuning.MOMENTUM_OWNER_WIN_GAIN, "Owner win")
	for minute in range(1440):
		var previous: float = managed.value
		steady.update(true, 80, 0.5, 1)
		managed.update(true, 80, 0.5, 1)
		if absf(managed.value - previous) > CasinoTuning.MOMENTUM_MAX_STEP + 0.00001:
			check(false, "Momentum minute change is bounded")
			break
	check(steady.value > CasinoTuning.MOMENTUM_BASELINE and managed.value > steady.value, "Healthy idle operation builds momentum; active success adds an advantage")
	check(steady.value < 70 and managed.value < 100, "Long-running baseline and boosts remain bounded")
	var healthy: float = steady.value
	for minute in range(720): steady.update(true, 20, 0, 0)
	check(steady.value < healthy and steady.value >= 0, "Genuine poor guest experience and coverage gradually reduce momentum")
	var frozen := managed.snapshot()
	for minute in range(1440): managed.update(false, 0, 0, 0)
	check(managed.snapshot() == frozen, "Closed casino neither loses nor recharges momentum")
	for entry in [{"value": 0.0, "band": "Quiet"}, {"value": 35.0, "band": "Busy"}, {"value": 50.0, "band": "Hot"}, {"value": 70.0, "band": "Packed"}, {"value": 85.0, "band": "Electric"}, {"value": 100.0, "band": "Electric"}]:
		managed.value = entry.value
		check(managed.band() == entry.band and managed.arrival_modifier() >= 1 and managed.arrival_modifier() <= 1.100001, "Readable band and capped attraction: " + entry.band)
	for index in range(50): managed.outcome(8, "Win")
	check(managed.influence == CasinoTuning.MOMENTUM_INFLUENCE_GAIN_CAP, "Repeated boosts saturate")
	for index in range(50): managed.outcome(-3, "Complaint")
	check(managed.influence == -CasinoTuning.MOMENTUM_INFLUENCE_LOSS_CAP, "Repeated failures saturate")
	sim.opened = true
	sim.spawn_guest()
	sim.guests[0].satisfaction = 90
	sim.guests[0].table = sim.tables[0].id
	sim.momentum_step()
	check(sim.momentum.contributors["Guest experience"] > 0 and sim.momentum.contributors["Occupied games"] > 0, "Momentum reads real guest experience and floor occupancy")
	for table in sim.tables: table.broken = true
	sim.momentum_step()
	check(sim.momentum.contributors["Unavailable games"] < 0, "Halted floor contributes real operational loss")
	for table in sim.tables: table.broken = false
	var before := sim.momentum.snapshot()
	check(sim.optional_events.spawn(sim, "floor_tip", true), "Opportunity ready for neutral ignore")
	check(sim.optional_events.resolve(sim, int(sim.optional_events.active[0].id), "dismissed") and sim.momentum.snapshot() == before, "Ignoring Opportunity has no momentum penalty")
	check(sim.optional_events.spawn(sim, "floor_tip", true), "Opportunity ready for expiry")
	sim.elapsed += 90
	sim.optional_events.tick(sim)
	check(sim.momentum.snapshot() == before, "Expired Opportunity has no momentum penalty")
	sim.momentum.guest_win(sim.elapsed)
	var influence: float = sim.momentum.influence
	sim.momentum.guest_win(sim.elapsed)
	check(sim.momentum.influence == influence, "Big guest wins rate limited")
	var copy := CasinoSimulation.new()
	check(copy.restore(json_save(sim)) and copy.momentum.snapshot() == sim.momentum.snapshot(), "Momentum JSON round trip includes outcome decay and cooldown")
	copy.momentum.guest_win(copy.elapsed)
	check(copy.momentum.influence == influence, "Load cannot reset big-win cooldown")
	var saved := json_save(sim)
	saved.erase("momentum")
	check(copy.restore(saved) and copy.momentum.value == CasinoTuning.MOMENTUM_BASELINE, "Existing saves receive safe additive momentum default")
	var pristine := JSON.stringify(copy.snapshot())
	for field in ["value", "influence", "guest_win_at"]:
		var bad := json_save(sim)
		bad.momentum[field] = 1.0e20
		check(not copy.restore(bad) and JSON.stringify(copy.snapshot()) == pristine, "Invalid momentum load is atomic: " + field)
	var initial_influence: float = sim.momentum.influence
	sim.tables[0].broken = true
	sim.incidents.append({"type": "repair", "table": sim.tables[0].id, "title": "Repair", "detail": "Halted"})
	sim.resolve_incident(0, true)
	check(sim.momentum.influence > initial_influence, "Real repair rewards management")
	var repaired: float = sim.momentum.influence
	sim.resolve_incident(0, true)
	check(sim.momentum.influence == repaired, "Removed incident cannot reward twice")
	# Actual committed gambling settlements, not fabricated resolution results.
	var won := false
	var lost := false
	for seed_value in range(1, 100):
		var player := CasinoSimulation.new()
		player.opened = true
		player.optional_events.rng.seed = seed_value
		player.optional_events.spawn(player, "owner_slots", true)
		var event_id: int = player.optional_events.active[0].id
		player.optional_events.engage(player, event_id)
		if not player.start_owner_event(event_id, 5):
			check(false, "Momentum owner event can commit")
			break
		CasinoSimulation.OwnerPlay.exit(player)
		var result: Dictionary = player.optional_events.history[0].result
		if float(result.casino_profit) > 0:
			won = true
			check(player.momentum.influence == CasinoTuning.MOMENTUM_OWNER_WIN_GAIN, "Actual owner win boosts momentum once")
			var win_influence: float = player.momentum.influence
			player.optional_events.resolve(player, event_id, "success", result)
			check(player.momentum.influence == win_influence, "Duplicate event settlement cannot boost momentum")
		else:
			lost = true
			check(player.momentum.influence == 0, "Owner loss/push never penalizes momentum")
		if won and lost: break
	check(won and lost, "Seeded owner win and loss exercised")

func objective_fixture(kind: String = "gaming_profit") -> CasinoSimulation:
	var sim := CasinoSimulation.new()
	sim.opened = true
	sim.spawn_guest()
	var guest: Dictionary = sim.guests[0]
	guest.state = "Playing"
	guest.table = sim.tables[0].id
	guest.seat = 0
	guest.rounds = 1
	guest.last_wager_minute = sim.elapsed
	guest.satisfaction = 85
	sim.optional_objectives.record(sim.elapsed, "gaming_profit", 40, 200)
	sim.optional_objectives.record(sim.elapsed, "happy_visits", 4)
	sim.optional_objectives.cursor = sim.optional_objectives.KINDS.find(kind)
	sim.optional_objectives.offer(sim)
	return sim

func objective_checks() -> void:
	var empty := CasinoSimulation.new()
	check(not empty.optional_objectives.offer(empty), "Closed casino never offers objectives")
	empty.opened = true
	check(not empty.optional_objectives.offer(empty), "No impossible goals without observed capability or playing guests")
	check(not empty.optional_objectives.eligible(empty, "paid_drinks") and not empty.optional_objectives.eligible(empty, "owner_win"), "Locked/unbuilt service and unfunded owner opportunities excluded")
	var sim := objective_fixture()
	var goal: Dictionary = sim.optional_objectives.active[0]
	check(goal.kind == "gaming_profit" and goal.target == 20, "Profit goal scales to recent net earning capability")
	var id := int(goal.id)
	sim.optional_objectives.observe(sim, "gaming_profit", 50)
	check(goal.progress == 0 and goal.state == "offered", "Ignored offer never tracks or grants money")
	check(sim.optional_objectives.start(sim, id) and not sim.optional_objectives.start(sim, id), "Start is opt-in and guarded")
	var table: Dictionary = sim.tables[0]
	var guest: Dictionary = sim.guests[0]
	for settlement in [[20.0,40.0],[30.0,5.0]]:
		sim.game_debit(table, settlement[0], guest)
		sim.game_credit(table, settlement[1], guest)
		sim.emit_gaming_result(table, settlement[0], settlement[1], int(guest.id))
	check(goal.progress == 5 and goal.state == "active", "Net profit progress includes real losing settlements")
	var copy := CasinoSimulation.new()
	check(copy.restore(json_save(sim)) and copy.optional_objectives.find_goal(id).progress == 5, "Started progress and recent capability survive JSON save/load")
	sim.emit_financial_event(100, "owner_event_profit")
	check(goal.progress == 5, "Owner transfers never farm guest gaming objectives")
	sim.game_debit(table, 20, guest)
	sim.game_credit(table, 0, guest)
	sim.emit_gaming_result(table, 20, 0, int(guest.id))
	check(goal.state == "ready" and sim.owner_bankroll == 1000, "Completion offers reward without auto-replenishing idle bankroll")
	var cash: float = sim.cash
	var initial: float = sim.owner_bankroll
	check(sim.optional_objectives.claim(sim, id) and sim.owner_bankroll == initial + goal.reward and sim.cash == cash, "Claim replenishes personal balance through existing reward service only")
	check(not sim.optional_objectives.claim(sim, id), "Duplicate claim rejected")
	check(copy.restore(json_save(sim)) and not copy.optional_objectives.claim(copy, id), "Consumed reward cannot replay after load")
	check(sim.optional_objectives.rewarded == goal.reward and sim.momentum.influence == CasinoTuning.OBJECTIVE_MOMENTUM_REWARD, "Reward budget and modest momentum bonus recorded once")
	var offer_sim := objective_fixture("happy_visits")
	var offer: Dictionary = offer_sim.optional_objectives.active[0]
	var before_bankroll: float = offer_sim.owner_bankroll
	var before_cash: float = offer_sim.cash
	var before_momentum := offer_sim.momentum.snapshot()
	check(offer_sim.optional_objectives.dismiss(offer_sim, int(offer.id)), "Offers can be ignored")
	check(offer_sim.owner_bankroll == before_bankroll and offer_sim.cash == before_cash and offer_sim.momentum.snapshot() == before_momentum, "Ignore has no hidden economic or momentum consequence")
	check(not offer_sim.optional_objectives.offer(offer_sim) or offer_sim.optional_objectives.active[0].kind != "happy_visits", "Ignore cannot reset goal-type cooldown")
	var expired_sim := objective_fixture()
	var expired_id: int = expired_sim.optional_objectives.active[0].id
	expired_sim.optional_objectives.start(expired_sim, expired_id)
	expired_sim.elapsed += CasinoTuning.OBJECTIVE_DURATION
	expired_sim.opened = false
	expired_sim.optional_objectives.tick(expired_sim)
	check(expired_sim.optional_objectives.find_goal(expired_id).is_empty() and expired_sim.owner_bankroll == 1000 and expired_sim.momentum.value == CasinoTuning.MOMENTUM_BASELINE, "Active expiration has no penalty")
	var happy := objective_fixture("happy_visits")
	var happy_goal: Dictionary = happy.optional_objectives.active[0]
	happy.optional_objectives.start(happy, int(happy_goal.id))
	happy.leave(happy.guests[0], "Visit finished")
	happy.leave(happy.guests[0], "Repeated departure")
	check(happy_goal.progress == 1, "Real happy departures count once")
	happy.spawn_guest()
	happy.guests[-1].rounds = 1
	happy.guests[-1].satisfaction = 90
	happy.opened = false
	happy.leave(happy.guests[-1], "Closed", "closed")
	check(happy_goal.progress == 1, "Closing/reopening cannot farm happy visits")
	for kind in ["occupied_games", "momentum"]:
		var held := objective_fixture(kind)
		var held_goal: Dictionary = held.optional_objectives.active[0]
		check(held_goal.kind == kind and held.optional_objectives.start(held, int(held_goal.id)), "Achievable sustained-operation objective: " + kind)
		for minute in range(10):
			held.elapsed += 1
			held.guests[0].last_wager_minute = held.elapsed
			held.optional_objectives.tick(held)
		check(held_goal.progress == 10, "Real playing minutes progress: " + kind)
		held.opened = false
		held.elapsed += 1
		held.optional_objectives.tick(held)
		check(held_goal.progress == 0, "Close resets sustained goal instead of farming it: " + kind)
		held.opened = true
		for minute in range(int(held_goal.target)):
			held.elapsed += 1
			held.guests[0].last_wager_minute = held.elapsed
			held.optional_objectives.tick(held)
		check(held_goal.state == "ready", "Sustained operation can complete: " + kind)
	var bounded := objective_fixture()
	for iteration in range(50): bounded.optional_objectives.offer(bounded)
	check(bounded.optional_objectives.active.size() == CasinoTuning.OBJECTIVE_ACTIVE_LIMIT, "Small active limit even under repeated scheduler calls")
	var capped := objective_fixture()
	var capped_goal: Dictionary = capped.optional_objectives.active[0]
	capped.optional_objectives.start(capped, int(capped_goal.id))
	capped.optional_objectives.observe(capped, "gaming_profit", 500)
	capped.optional_objectives.rewarded = CasinoTuning.OBJECTIVE_DAILY_REWARD - 10
	capped.owner_account.balance = CasinoTuning.OBJECTIVE_BANKROLL_CAP - 5
	check(capped.optional_objectives.claimable(capped, capped_goal) == 5 and capped.optional_objectives.claim(capped, int(capped_goal.id)), "Personal cap and daily budget bound reward with partial claim")
	check(capped.owner_bankroll == CasinoTuning.OBJECTIVE_BANKROLL_CAP and capped.optional_objectives.rewarded == CasinoTuning.OBJECTIVE_DAILY_REWARD - 5, "Partial claim consumes exactly actual replenishment budget")
	var escrow := objective_fixture()
	var escrow_goal: Dictionary = escrow.optional_objectives.active[0]
	escrow.owner_account.balance = CasinoTuning.OBJECTIVE_BANKROLL_CAP
	escrow.owner_wager_debit(escrow.owner_account.next_operation, 100)
	check(escrow.optional_objectives.claimable(escrow, escrow_goal) == 0, "Pending personal event stakes cannot bypass bankroll cap")
	var failed := objective_fixture()
	var failed_id: int = failed.optional_objectives.active[0].id
	failed.optional_objectives.start(failed, failed_id)
	failed.optional_objectives.observe(failed, "gaming_profit", 500)
	failed.owner_checkpoint = func(): return false
	check(not failed.optional_objectives.claim(failed, failed_id) and failed.owner_bankroll == 1000 and failed.optional_objectives.find_goal(failed_id).state == "ready" and failed.optional_objectives.rewarded == 0 and failed.momentum.influence == 0, "Unavailable storage rolls back reward, goal ID, budget and momentum")
	failed.owner_checkpoint = func(): return true
	check(failed.optional_objectives.claim(failed, failed_id), "Failed checkpoint leaves reward retryable")
	var saved := json_save(sim)
	saved.erase("optional_objectives")
	check(copy.restore(saved) and copy.optional_objectives.active.is_empty() and copy.optional_objectives.next_check > copy.elapsed, "Existing save defaults safely without catch-up goals/rewards")
	var pristine := JSON.stringify(copy.snapshot())
	for field in ["next_id", "rewarded", "cursor"]:
		var bad := json_save(sim)
		bad.optional_objectives[field] = -1
		check(not copy.restore(bad) and JSON.stringify(copy.snapshot()) == pristine, "Invalid objectives load is atomic: " + field)

	# Paid delivery and owner challenges use existing game/service settlement paths.
	var drinks := CasinoSimulation.new("easy", ["slots"])
	drinks.opened = true
	drinks.purchase_bar()
	drinks.hire("Service", -1)
	drinks.set_drink_menu("basic", true)
	drinks.spawn_guest()
	var drink_guest: Dictionary = drinks.guests[0]
	drink_guest.state = "Watching"
	drink_guest.thirst = CasinoTuning.DRINK_THIRST_TRIGGER
	drink_guest.drink_order = "basic"
	drink_guest.drink_quote = 5
	drinks.deliver_drink(drink_guest, {"name": "Service", "duty": "Active", "service_product": "basic"})
	drinks.optional_objectives.cursor = drinks.optional_objectives.KINDS.find("paid_drinks")
	check(drinks.optional_objectives.offer(drinks) and drinks.optional_objectives.active[0].kind == "paid_drinks", "Actual paid service makes a drink goal eligible")
	var drink_goal: Dictionary = drinks.optional_objectives.active[0]
	drinks.optional_objectives.start(drinks, int(drink_goal.id))
	for delivery in range(2):
		drink_guest.thirst = CasinoTuning.DRINK_THIRST_TRIGGER
		drink_guest.drink_order = "basic"
		drink_guest.drink_quote = 5
		drinks.deliver_drink(drink_guest, {"name": "Service", "duty": "Active", "service_product": "basic"})
	check(drink_goal.state == "ready", "Actual paid deliveries complete service goal")
	var real_win := false
	for seed_value in range(1, 100):
		var player := CasinoSimulation.new()
		player.opened = true
		player.optional_events.rng.seed = seed_value
		player.optional_events.spawn(player, "owner_slots", true)
		player.optional_objectives.cursor = player.optional_objectives.KINDS.find("owner_win")
		check(player.optional_objectives.offer(player) and player.optional_objectives.active[0].kind == "owner_win", "Available funded owner challenge is eligible")
		var win_goal: Dictionary = player.optional_objectives.active[0]
		player.optional_objectives.start(player, int(win_goal.id))
		var event_id: int = player.optional_events.active[0].id
		player.optional_events.engage(player, event_id)
		player.start_owner_event(event_id, 5)
		CasinoSimulation.OwnerPlay.exit(player)
		if float(player.optional_events.history[0].result.casino_profit) > 0:
			real_win = true
			check(win_goal.state == "ready", "Actual committed owner win completes its goal")
			break
		check(win_goal.progress == 0, "Owner loss/push does not advance winning goal")
	check(real_win, "Owner win goal exercised through real seeded game")
