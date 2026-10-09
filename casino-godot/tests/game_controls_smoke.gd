extends SceneTree
# Bounded shared controls, wager stepping and result-recognition checks.
var checks := 0
var failures := 0

func _initialize() -> void: call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("CONTROL FAIL: " + label)
func settle() -> void:
	for i in range(8): await process_frame

func run() -> void:
	var audio = root.get_node("AudioManager")
	var previous_mute: bool = audio.is_game_muted("slots")
	audio.set_game_muted("slots", false)
	for kind in ["slots", "roulette", "blackjack", "holdem", "craps"]:
		var sim := CasinoSimulation.new()
		sim.back_room.rng.seed = 3
		sim.back_room.choose(kind)
		var view = load("res://scripts/game_view.gd").new()
		view.sim = PitBossGameContext.new(sim, {"id": 9001, "kind": kind})
		root.add_child(view)
		view.set_process(false)
		var dice = load("res://presentation/play/craps_surface.gd").new()
		dice.sim = view.sim
		root.add_child(dice)
		view.attach_craps(dice)
		dice.set_process(false)
		root.size = Vector2i(1440, 900)
		root.content_scale_size = root.size
		view.size = root.size
		view.render_current()
		await settle()
		if kind == "slots":
			check(view.slot_steps() == [1, 5, 10, 25, 50, 100, 1000], "Affordable slot units")
			view.cycle_slot_step()
			view.bet = 10
			view.change_slot_bet(1)
			check(view.bet == 15 and view.slot_step == 5, "Plus adds selected unit")
			view.change_slot_bet(-1)
			check(view.bet == 10, "Minus subtracts selected unit")
			check(not view.actions.get_children().any(func(node): return node is SpinBox), "No slot wager text editor")
			view.toggle_audio()
			check(root.get_node("AudioManager").is_game_muted("slots") and view.audio_button.icon != null, "Header audio icon mutes")
		elif kind == "roulette":
			check(view.sim.roulette_bet(view.sim.joined, "Red", 1), "Real roulette wager")
		elif kind == "craps":
			check(view.sim.bet(view.sim.joined, "field", 1), "Real craps wager")
			dice.prepare_roll(view.current_table())
			check(view.sim.shoot_player(view.sim.joined), "Real private roll")
			dice.capture_roll(view.current_table())
			dice._process(dice.ROLL_SECONDS + 0.001)
			check(dice.animation > dice.SETTLE_SECONDS and dice.reference_dice.size() == 2 and dice.active_wagers(view.current_table())[0].bets.field == 0, "Settled dice show canonical chips during recognition")
			dice._process(1.24)
			check(dice.animation > dice.SETTLE_SECONDS and dice.busy(), "Craps retains result recognition for 1.25 seconds")
			dice.animation = 0
			dice.hover = "come"
			view.update_bet_indicator()
			check(view.bet_indicator.text.contains("Wait for a point") or view.bet_indicator.text.contains("Come"), "Bet preview reaches header")
		if kind != "craps":
			if kind in ["blackjack", "holdem"]: view.bet = 1
			view.transact(true)
			for turn in range(12):
				if not view.sim.game_pending(view.current_table()): break
				view.art._process(1)
				var actions: Dictionary = view.Games.actions(view.current_table().round, sim.owner_bankroll)
				var action: String = "Stand" if actions.has("Stand") else "Check" if actions.has("Check") else "Fold" if actions.has("Fold") else str(actions.keys()[0])
				view.transact(false, action)
			check(view.current_table().round.get("phase") == "done", "Real settled round " + kind)
			view.art._process(view.art.timeline.reveal_at + 0.01 if kind == "slots" else 10)
			view.update_result_hold(0)
			view.render_current()
			check(view.result_hold == 1.25 and view.locked(), "Recognition lock " + kind)
			var operations: int = sim.owner_account.next_operation
			view.transact(true)
			check(sim.owner_account.next_operation == operations, "Recognition prevents repeat wager " + kind)
			if kind == "roulette": check(view.felt.bets == {"Red": 1.0}, "Roulette chips stay through result hold")
			view.update_result_hold(1.24)
			check(view.result_hold > 0, "Hold cannot finish early " + kind)
			view.update_result_hold(0.02)
			view.art._process(20)
			check(not view.locked(), "Next round available after recognition " + kind)
		for dimensions in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
			root.size = dimensions
			root.content_scale_size = dimensions
			view.size = dimensions
			view.layout_play()
			view.signature.clear()
			view.render_current()
			await settle()
			check(not view.bet_indicator.get_global_rect().intersects(view.wallet.get_global_rect()), "Header preview above wallet " + str(dimensions))
			if kind != "slots": check(view.rack.CHIP_RADIUS == 23 and view.rack_scroll.size.y >= view.rack.RACK_HEIGHT, "Larger shared rack fits")
			if kind == "craps":
				for zoom in [1.0, 3.0]:
					dice.view_zoom = zoom
					dice.update_view_transform()
					for at in [Vector2(-100, -100), dice.PLAY_SIZE + Vector2(100, 100)]:
						var screen: Vector2 = dice.offset + dice.visible_die_position(at) * dice.factor
						var radius: float = 37 * dice.factor
						check(screen.x - radius >= 0 and screen.y - radius >= 0 and screen.x + radius <= dice.size.x and screen.y + radius <= dice.size.y, "Rotated dice stay visible " + str(dimensions))
			if kind == "craps": dice.view_zoom = 1; dice.update_view_transform()
			if DisplayServer.get_name() != "headless":
				RenderingServer.force_draw()
				root.get_texture().get_image().save_png("/tmp/controls-%s-%dx%d.png" % [kind, dimensions.x, dimensions.y])
		view.queue_free()
		await process_frame
	var public_sim := CasinoSimulation.new()
	public_sim.opened = true
	# Standard machines step by $2 above their configured $5 minimum.
	public_sim.tables[0].slot_profile = "standard"
	check(public_sim.join_table(int(public_sim.tables[0].id)) and public_sim.start_game(public_sim.joined, 7), "Public slots accept the tier's wager increment within limits")
	await check_play_sessions()
	audio.set_game_muted("slots", previous_mute)
	audio.shutdown()
	await create_timer(0.12).timeout
	print("GAME_CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check_play_sessions() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.close_modal()
	ui.set_process(false)
	ui.owner_checkpoint_path = "user://speed_smoke.save"
	for kind in ["slots", "blackjack", "roulette", "holdem", "craps"]:
		for multiplier in [8, 4, 2, 1, 0]:
			ui.start_casino("easy", [kind])
			ui.speed = multiplier
			ui.previous_speed = 8 if multiplier == 0 else multiplier
			ui.refresh()
			check(not ui.play_speed_active and ui.speed == multiplier, "Management does not override " + kind)
			ui.selected = int(ui.sim.tables[0].id)
			ui.visitor = true
			ui.sim.player = ui.sim.bounds(ui.sim.tables[0]).get_center()
			ui.join_table()
			check(ui.play_speed_active and ui.speed == (0 if multiplier == 0 else 1), "Public entry speed " + kind + str(multiplier))
			ui.refresh()
			ui.toggle_pause()
			check(ui.speed == (1 if multiplier == 0 else 0), "Session pause/resume " + kind)
			ui.leave_table()
			check(not ui.play_speed_active and ui.speed == multiplier and ui.previous_speed == (8 if multiplier == 0 else multiplier), "Public exit restores " + kind + str(multiplier))
		for multiplier in [8, 0]:
			ui.start_casino("easy", [kind])
			ui.speed = multiplier
			ui.previous_speed = 8
			ui.in_back_room = true
			ui.open_private_station({"id": 9001, "kind": kind})
			check(ui.play_speed_active and ui.speed == (0 if multiplier == 0 else 1), "Private entry " + kind)
			ui.leave_table()
			check(ui.speed == multiplier and not ui.play_speed_active and ui.in_back_room, "Private exit restores " + kind)
	ui.start_casino("easy", ["blackjack"])
	ui.speed = 8
	ui.selected = int(ui.sim.tables[0].id)
	ui.visitor = true
	ui.sim.player = ui.sim.bounds(ui.sim.tables[0]).get_center()
	ui.join_table()
	ui.sim.tables[0].round = {"phase": "player"}
	ui.leave_table()
	check(ui.sim.joined >= 0 and ui.play_speed_active and ui.speed == 1, "Unresolved exit retains override")
	ui.sim.tables[0].round = {}
	ui.speed = 4
	ui.refresh()
	check(ui.speed == 4, "Explicit temporary speed allowed")
	ui.leave_table()
	check(ui.speed == 8, "Temporary change does not replace original")
	ui.start_casino("easy", ["craps"])
	ui.speed = 8
	ui.selected = int(ui.sim.tables[0].id)
	ui.visitor = true
	ui.sim.player = ui.sim.bounds(ui.sim.tables[0]).get_center()
	ui.join_table()
	ui.sim.opened = true
	ui.sim.pass_dice(ui.sim.joined)
	ui.felt.initialize_table(ui.sim.tables[0])
	ui.felt.set_process(false)
	ui.game_view.set_process(false)
	var view = ui.game_view
	for dimensions in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		view.size = dimensions
		view.layout_play()
		view.signature.clear()
		view.render_current()
		await settle()
		check(view.header.size.y == (92 if dimensions.x < 760 else 48), "Existing header height " + str(dimensions))
		check(not view.roll_countdown.get_global_rect().intersects(view.bet_indicator.get_global_rect()) and not view.roll_progress.get_global_rect().intersects(view.wallet.get_global_rect()) and not view.roll_countdown.get_global_rect().intersects(view.return_button.get_global_rect()), "Timer shares header without overlap " + str(dimensions))
		var hold: Button = view.actions.get_child(0)
		check(view.ready_button.get_parent() == view.actions and is_equal_approx(hold.position.y, view.ready_button.position.y) and view.ready_button.size.y >= 44, "Ready beside Hold in existing row " + str(dimensions))
	var table: Dictionary = ui.sim.tables[0]
	view.countdown_interval = 8
	table.timer = 2
	view.effective_speed = 1
	view.simulation_fraction = 0.5
	view.update_craps_countdown()
	check(view.roll_countdown.text.contains("06") and is_equal_approx(view.roll_progress.value, 31.25), "Timer uses authoritative fractional tick")
	view.effective_speed = 2
	view.update_craps_countdown()
	check(view.roll_countdown.text.contains("03"), "Timer converts current speed")
	view.paused = true
	view.simulation_fraction = 0.9
	view.update_craps_countdown()
	check(view.roll_countdown.text == "PAUSED" and view.roll_progress.value == 31.25 and view.ready_button.disabled, "Paused timer and Ready freeze")
	view.paused = false
	table.betting_hold = true
	view.update_craps_countdown()
	check(view.roll_countdown.text == "BETTING HELD" and view.ready_button.disabled and view.roll_progress.value == 31.25, "Held timer and Ready freeze")
	table.betting_hold = false
	table.timer = 0
	view.simulation_fraction = 0
	view.update_craps_countdown()
	check(view.roll_progress.value == 0, "Timer reset follows simulation")
	table.shooter = 0
	view.signature.clear()
	view.render_current()
	view.update_craps_countdown()
	check(not view.roll_progress.visible and view.roll_countdown.text == "PLACE LINE BET" and not view.actions.get_children().any(func(n): return n.visible and n is Button and n.text.begins_with("Ready")), "Manual turn has no CPU action or countdown")
	check(view.roll_progress.size.y >= 4 and view.roll_progress.size.y <= 6, "Slim progress bar")
	check(ui.sim.bet(int(table.id), "pass", 25), "Manual line funded")
	view.update_craps_countdown()
	check(view.roll_countdown.text == "YOUR TURN / READY", "Manual ready status")
	ui.felt.animation = ui.felt.animation_duration
	view.update_craps_countdown()
	check(view.roll_countdown.text == "ROLLING...", "Throw status")
	ui.felt.animation = ui.felt.SETTLE_SECONDS
	view.update_craps_countdown()
	check(view.roll_countdown.text == "SETTLING...", "Settlement status")
	ui.felt.animation = 0
	# Save contains no speed override; load establishes a fresh transient session.
	var had_save := FileAccess.file_exists(CasinoTuning.SAVE_PATH)
	var original_save := FileAccess.get_file_as_string(CasinoTuning.SAVE_PATH) if had_save else ""
	ui.save_game()
	check(ui.load_game() and ui.play_speed_active and ui.play_speed_original == 1 and ui.speed == 1 and ui.sim.craps_roll_blocked == -1, "Load clears old override and establishes resumed session")
	ui.felt.initialize_table(ui.sim.tables[0])
	ui.leave_table()
	check(ui.speed == 1 and not ui.play_speed_active, "Loaded exit has no orphaned original speed")
	if had_save:
		var restore_save := FileAccess.open(CasinoTuning.SAVE_PATH, FileAccess.WRITE)
		restore_save.store_string(original_save)
		restore_save.close()
	else: DirAccess.remove_absolute(CasinoTuning.SAVE_PATH)
	for kind in ["slots", "blackjack"]:
		ui.start_casino("easy", [kind])
		ui.speed = 8
		ui.sim.opened = true
		check(ui.sim.optional_events.spawn(ui.sim, "owner_" + kind, true), "Speed owner event available " + kind)
		ui.refresh()
		ui.event_cards.engage.pressed.emit()
		ui.event_cards.commit.pressed.emit()
		check(ui.play_speed_active and ui.speed == 1, "Owner event entry speed " + kind)
		ui.leave_table()
		check(ui.sim.owner_play.is_empty() and ui.speed == 8 and not ui.play_speed_active, "Owner event exit speed " + kind)
	ui.start_casino("easy", ["slots"])
	check(not ui.play_speed_active and ui.speed == 1, "New casino clears session override")
	ui.queue_free()
	await settle()
