extends SceneTree
## Bounded physical flow + accounting/persistence. No sampling or browser matrix.
const Sim = preload("res://scripts/simulation.gd")
const Context = preload("res://scripts/game_context.gd")
const Property = preload("res://scripts/floor_property.gd")
var failures := 0
var checks := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, description: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(description)

func walk(view: Control, seconds: float = 15) -> void:
	# Advance the actual movement controller, with a strict bound.
	for i in range(int(seconds * 30)):
		if not view.is_visible_in_tree(): break
		view._process(1.0 / 30)

func run() -> void:
	var audio = root.get_node("AudioManager")
	var previous_mute: bool = audio.is_game_muted("slots")
	root.size = Vector2i(1440, 900)
	var scene := load("res://main.tscn") as PackedScene
	var ui := scene.instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.owner_checkpoint_path = "user://back_room_smoke.save"
	ui.set_process(false)
	ui.floor_view.set_process(false)
	ui.back_room_floor.set_process(false)
	check(Property.entrance_clearance(ui.sim.floor_chunks).has_point(ui.floor_view.sim.door_approach()), "Private approach uses existing entrance clearance")
	check(not Property.public_door(ui.sim.floor_chunks).intersects(ui.floor_view.sim.door_bounds()), "Front door targets are separate")
	check(ui.sim.can_place(Vector2(420, 480), false, -1, "slots"), "Old south doorway reservation accepts ordinary slot placement")
	ui.sim.player = CasinoTuning.ENTRY + Vector2(0, 300)
	var public_counts := [ui.sim.tables.size(), ui.sim.staff.size()]
	ui.floor_view.select_at(ui.floor_view.screen_at(ui.floor_view.sim.door_bounds().get_center()))
	check(not ui.in_back_room and ui.floor_view.move_target.is_finite(), "Door routes owner without teleport")
	walk(ui.floor_view)
	check(ui.in_back_room and ui.back_room_floor.visible, "Owner arrival loads physical room")
	check(ui.sim.player.distance_to(ui.floor_view.sim.door_approach()) < 8, "Public door reached normally")
	check(public_counts == [ui.sim.tables.size(), ui.sim.staff.size()], "Private furniture/dealers absent from public operations")
	var kinds := {}
	for station in ui.back_room_floor.sim.stations:
		kinds[station.kind] = true
		check(not ui.back_room_floor.blocked(ui.back_room_floor.sim.approach_position(station)), "Fixture approach clear")
	check(kinds.size() == 5, "All five games configured")
	var station: Dictionary = ui.back_room_floor.sim.stations[0]
	ui.back_room_floor.select_at(ui.back_room_floor.screen_at(ui.back_room_floor.sim.bounds(station).get_center()))
	check(not ui.private_play, "Fixture selection routes before opening")
	walk(ui.back_room_floor)
	check(ui.private_play and ui.game_view.visible and ui.game_view.sim.is_private, "Fixture opens authoritative shared play view")
	check(ui.game_view.art.get_script() == load("res://scripts/casino_surface.gd") and ui.felt.get_script() == load("res://presentation/play/craps_surface.gd"), "Shared public game components")
	audio.set_game_muted("slots", true)
	ui.game_view.bet = 1.0
	var wallet: float = ui.sim.owner_bankroll
	var cash: float = ui.sim.cash
	ui.game_view.transact(true)
	var round_data: Dictionary = ui.sim.back_room.state.round
	check(not round_data.is_empty(), "Shared spin executes private wager")
	if not round_data.is_empty():
		check(is_equal_approx(ui.sim.owner_bankroll, wallet - 1.0 + round_data.credit) and is_equal_approx(ui.sim.cash, cash), "Private total return stays in personal wallet")
		check(not ui.sim.back_room.settle(ui.sim, int(ui.sim.back_room.state.operation), round_data.credit), "Duplicate settlement rejected")
	var restored := Sim.new()
	var data: Dictionary = JSON.parse_string(JSON.stringify(ui.sim.snapshot()))
	var loaded := restored.restore(data)
	check(loaded and restored.location == data.location and restored.back_room.rng.state == ui.sim.back_room.rng.state and restored.owner_bankroll == ui.sim.owner_bankroll and restored.owner_account.next_operation == ui.sim.owner_account.next_operation and restored.owner_account.pending == ui.sim.owner_account.pending and restored.owner_account.history == data.owner_bankroll.history, "Save/load preserves area/wallet/RNG/operations")
	data.erase("location")
	check(not restored.restore(data), "Save missing current physical location rejected")
	ui.game_view.art._process(20)
	ui.game_view.update_result_hold(0)
	ui.game_view.update_result_hold(1.26)
	ui.leave_table()
	check(ui.in_back_room and ui.back_room_floor.visible and not ui.private_play, "Game exit returns beside fixture")
	ui.back_room_floor.select_at(ui.back_room_floor.screen_at(PitBossFloorContext.KIOSK.get_center()))
	walk(ui.back_room_floor)
	check(ui.recovery_view.visible and not ui.back_room_floor.visible, "Physical recovery desk interaction")
	ui.recovery_view.leave_requested.emit()
	ui.back_room_floor.select_at(ui.back_room_floor.screen_at(ui.back_room_floor.sim.door_bounds().get_center()))
	check(ui.in_back_room, "Exit selection does not teleport")
	walk(ui.back_room_floor)
	check(not ui.in_back_room and ui.floor_view.visible and not ui.floor_view.blocked(ui.sim.player), "Physical exit returns safely")
	var original := Property.private_door(ui.sim.floor_chunks)
	check(Property.private_door({"left": 1, "right": 0, "bottom": 0}).get_center().x < original.get_center().x, "Left expansion recenters frontage")
	check(Property.private_door({"left": 0, "right": 1, "bottom": 1}).get_center().x > original.get_center().x, "Right expansion recenters frontage; bottom expansion leaves its height unchanged")
	# One deterministic money example supplements the random shared spin above.
	var money_sim := Sim.new()
	var initial_cash: float = money_sim.cash
	var operation: int = money_sim.back_room.debit(money_sim, 250)
	check(operation > 0 and money_sim.back_room.settle(money_sim, operation, 750) and money_sim.owner_bankroll == 1500 and money_sim.cash == initial_cash, "Full private return enters personal wallet")
	check(not money_sim.back_room.settle(money_sim, operation, 750), "Profit cannot be credited twice")
	money_sim.back_room.choose("roulette")
	check(not money_sim.back_room.add(money_sim, "Red", 0.99), "Sub-dollar layout wager rejected")
	for kind in ["slots", "blackjack", "holdem", "roulette", "craps"]:
		var minimum_sim := Sim.new()
		minimum_sim.back_room.choose(kind)
		for amount in [0.01, 0.50, 0.99]:
			var accepted: bool = minimum_sim.back_room.add(minimum_sim, "Red" if kind == "roulette" else "field", amount) if kind in ["roulette", "craps"] else minimum_sim.back_room.start(minimum_sim, amount)
			check(not accepted and minimum_sim.owner_bankroll == 1000 and minimum_sim.owner_account.pending.is_empty(), "Sub-dollar wager rejected without debit " + kind)
		var accepted: bool = minimum_sim.back_room.add(minimum_sim, "Red" if kind == "roulette" else "field", 1.0) if kind in ["roulette", "craps"] else minimum_sim.back_room.start(minimum_sim, 1.0)
		check(accepted, "Dollar minimum accepted " + kind)
	check(money_sim.back_room.add(money_sim, "Red", 1.0), "One dollar wager accepted")
	var pending_save: Dictionary = JSON.parse_string(JSON.stringify(money_sim.snapshot()))
	check(restored.restore(pending_save) and restored.owner_account.pending == pending_save.owner_bankroll.pending and restored.back_room.busy(), "Unfinished private escrow survives save/load")
	check(not restored.recovery.can_refill(restored), "Recovery blocked by pending wagers")
	# Focused recovery invariants and adapters; no random outcome sampling.
	var recovery_sim := Sim.new()
	var recovery_cash: float = recovery_sim.cash
	recovery_sim.owner_account.balance = 1400
	recovery_sim.recovery.issue("scratch")
	var earned_id: String = recovery_sim.recovery.state.tickets[0].id
	check(not recovery_sim.recovery.claim_ticket(recovery_sim, earned_id) and not recovery_sim.recovery.state.tickets[0].claimed, "Full wallet preserves unclaimed ticket even for zero prize")
	for c in recovery_sim.recovery.state.contracts: c.done = true
	check(not recovery_sim.recovery.claim(recovery_sim, "contracts") and not recovery_sim.recovery.claim(recovery_sim, "timer"), "Full wallet blocks both refill paths at 3/3")
	recovery_sim.owner_account.balance = 125
	recovery_sim.recovery.state.last_full_utc = recovery_sim.recovery.now()-CasinoTuning.RECOVERY_WORK_MIN_SECONDS
	check(recovery_sim.private_transaction(func(): return recovery_sim.recovery.claim(recovery_sim,"contracts")) and recovery_sim.owner_bankroll==1000 and recovery_sim.cash==recovery_cash and recovery_sim.recovery.state.cycle_id==1, "Work credits only gap, advances once and leaves casino cash unchanged")
	check(not recovery_sim.recovery.claim(recovery_sim,"contracts"), "Completed work cannot double claim")
	var promo_sim := Sim.new()
	promo_sim.owner_account.balance=100
	promo_sim.recovery.issue("scratch")
	promo_sim.recovery.state.scratch_issued=true
	promo_sim.recovery.state.tickets[0].award=0
	var promo_id: String=promo_sim.recovery.state.tickets[0].id
	check(promo_sim.private_transaction(func(): return promo_sim.recovery.claim_ticket(promo_sim,promo_id)) and promo_sim.recovery.state.tickets[0].claimed and promo_sim.owner_bankroll==100, "Eligible zero prize is honestly revealed without credit")
	check(not promo_sim.recovery.claim_ticket(promo_sim,promo_id), "Promotion cannot be claimed twice")
	promo_sim.recovery.issue("raffle")
	promo_sim.recovery.state.raffle_issued=true
	var promo_save: Dictionary=promo_sim.recovery.snapshot()
	var restored_promo=preload("res://scripts/recovery_system.gd").new()
	check(restored_promo.restore(promo_save) and restored_promo.state.tickets==promo_sim.recovery.state.tickets and restored_promo.rng.state==promo_sim.recovery.rng.state, "Promotion outcomes and independent RNG survive reload")
	var checkpoint_calls := [0]
	promo_sim.owner_checkpoint=func(): checkpoint_calls[0]+=1; return checkpoint_calls[0]!=2
	var attempt_before: Dictionary=promo_sim.recovery.snapshot()
	var attempt_id: String=promo_sim.recovery.state.contracts[0].id
	check(not promo_sim.private_transaction(func(): return promo_sim.recovery.submit(promo_sim,attempt_id,{})) and promo_sim.recovery.state.contracts==attempt_before.state.contracts, "Failed save rolls back durable incorrect attempt")
	promo_sim.owner_checkpoint=Callable()
	var desk = ui.recovery_view
	desk.sim = recovery_sim
	desk.open()
	for category in range(4):
		var c: Dictionary = recovery_sim.recovery.state.contracts[0]
		c.category=category
		c.variant=1
		c.tier=0
		desk.open_job(c.id)
		var p: Dictionary = recovery_sim.recovery.puzzle(c)
		var response := {"choice":p.get("answer",-1),"reason":p.get("reason",-1),"number":p.get("number",0),"mask":p.get("mask",3),"aisle":true}
		for key in response: desk.drafts[c.id][key]=response[key]
		check(recovery_sim.recovery.solved(c,desk.game.response()), "Visual adapter retains canonical response category %d" % category)
		if category==1: check(p.records[1].dispatch.time=="11:10" and p.records[1].receipt.time=="11:05", "Structured security chronology matches curated Runner B case")
		if category==0: check(p.number<0, "Cage negative signed discrepancy retained")
		if category==3:
			desk.drafts[c.id].aisle=false
			check(not recovery_sim.recovery.solved(c,desk.game.response()), "Blocked physical aisle fails staffing verification")
	var failed: Dictionary=recovery_sim.recovery.state.contracts[0]
	failed.category=0
	failed.done=false
	desk.open_job(failed.id)
	desk.drafts[failed.id].choice=-1
	desk.submit()
	check(not failed.done and failed.failures==1 and desk.feedback.text.begins_with("[INCORRECT]"), "Durably saved wrong answer never shows VERIFIED")
	check(desk.verify.disabled and failed.retry_utc>recovery_sim.recovery.now(), "Failed verification applies authoritative retry gate")
	var draft_before: Dictionary=desk.game.response()
	desk.size=Vector2(390,844)
	desk.layout()
	check(desk.game.response()==draft_before, "Relayout preserves active draft")
	desk.hide()
	check(not desk.is_processing(), "Hidden workshop stops polling")
	desk.sim=ui.sim
	DirAccess.remove_absolute("user://back_room_smoke.save")
	ui.queue_free()
	await process_frame
	audio.set_game_muted("slots", previous_mute)
	audio.shutdown()
	await create_timer(0.12).timeout
	print("BACK_ROOM_SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
