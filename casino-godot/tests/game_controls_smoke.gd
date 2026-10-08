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
			check(view.art.slot_audio.volume == 0 and view.audio_button.icon != null, "Header audio icon mutes")
		elif kind == "roulette":
			check(view.sim.roulette_bet(view.sim.joined, "Red", 1), "Real roulette wager")
		elif kind == "craps":
			check(view.sim.bet(view.sim.joined, "field", 1), "Real craps wager")
			dice.prepare_roll(view.current_table())
			check(view.sim.shoot_player(view.sim.joined), "Real private roll")
			dice.capture_roll(view.current_table())
			dice._process(dice.ROLL_SECONDS + 0.001)
			check(dice.animation > dice.SETTLE_SECONDS and dice.reference_dice.size() == 2 and dice.previous.table.owner.field == 1, "Settled dice retain pre-roll chips during recognition")
			dice._process(1.49)
			check(dice.animation > dice.SETTLE_SECONDS and dice.busy(), "Craps holds chips for 1.5 seconds")
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
			check(view.result_hold == 1.5 and view.locked(), "Recognition lock " + kind)
			var operations: int = sim.owner_account.next_operation
			view.transact(true)
			check(sim.owner_account.next_operation == operations, "Recognition prevents repeat wager " + kind)
			if kind == "roulette": check(view.felt.bets == {"Red": 1.0}, "Roulette chips stay through result hold")
			view.update_result_hold(1.49)
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
	# Standard machines permit increments above the fixed $5 starter wager.
	public_sim.tables[0].slot_profile = "standard"
	check(public_sim.join_table(int(public_sim.tables[0].id)) and public_sim.start_game(public_sim.joined, 6), "Public slots accept a whole-dollar increment within limits")
	print("GAME_CONTROLS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
