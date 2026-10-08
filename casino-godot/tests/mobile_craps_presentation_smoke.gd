extends SceneTree
# Bounded shell, geometry and native input checks for the felt-first pass.
var ui: Control
var checks := 0
var failures := 0
func check(value: bool, description: String) -> void:
	checks += 1
	if not value:
		failures += 1
		printerr("FELT FAIL: " + description)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func screen_at(source: Vector2) -> Vector2:
	return ui.felt.get_global_transform_with_canvas() * (ui.felt.offset + source * ui.felt.factor)
func touch(at: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	await process_frame
func tap(key: String) -> void:
	var at := screen_at(ui.felt.spots[key])
	await touch(at, true)
	await touch(at, false)
	await settle()
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.close_modal()
	ui.set_process(false)
	ui.owner_checkpoint_path = "user://felt_smoke.save"
	for dimensions in [Vector2i(1494, 934)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		ui.start_casino("easy", ["craps"])
		ui.speed = 1
		ui.selected = int(ui.sim.tables[0].id)
		ui.visitor = true
		ui.sim.player = ui.sim.bounds(ui.sim.tables[0]).get_center()
		ui.join_table()
		ui.game_view.paused = false
		ui.game_view.render_current()
		await settle()
		var surface = ui.felt
		var view = ui.game_view
		var table: Dictionary = ui.sim.get_table(ui.sim.joined)
		surface.fit_view()
		await settle()
		check(surface.custom_minimum_size == Vector2.ZERO, "No oversized minimum")
		check(view.rack_scroll.is_visible_in_tree(), "Shared viewport rack")
		check(not surface.get_global_rect().intersects(view.rack_scroll.get_global_rect()), "Rack outside felt")
		check(surface.size.y >= dimensions.y - 240, "Felt real estate " + str(dimensions))
		check(surface.target_at(surface.spots.odds) == "odds" and surface.target_at(surface.spots.pass) == "pass", "Parent interior and actual border separate")
		for key in CrapsRules.empty_bets():
			check(surface.spots.has(key), "Shared chip anchor " + key)
			if not surface.is_contract(key): check(surface.target_at(surface.spots[key]) == key, "Printed/border key " + key)
			else: check(key not in surface.printed_keys and not surface.target_at(surface.spots[key]).begins_with("come_") and not surface.target_at(surface.spots[key]).begins_with("dont_come_"), "No empty contract targets " + key)
		check(surface.printed_keys.size() == 21, "Exactly 21 printed cells; no odds rows")
		for pair in [["pass", "odds"], ["dont_pass", "lay_odds"]]:
			var parent: Rect2 = surface.layouts[pair[0]]
			var border: Rect2 = surface.layouts[pair[1]]
			check(border.size.y == 0 and border.position.y == parent.end.y, "Odds is parent bottom stroke " + pair[1])
			check(surface.endpoint(pair[1], -1).y == parent.end.y and surface.endpoint(pair[1], 3).y == parent.end.y, "Owned and NPC chips straddle border " + pair[1])
			check(surface.target_at(parent.get_center()) == pair[0], "Parent center remains parent " + pair[0])
			check(surface.target_at(Vector2(parent.get_center().x, parent.end.y - 2 / surface.factor)) == pair[1], "Narrow border wins " + pair[1])
		var initial_band: float = surface.border_band("odds").size.y * surface.factor
		surface.zoom_view(2)
		check(is_equal_approx(surface.border_band("odds").size.y * surface.factor, initial_band), "Screen-sized odds band survives zoom")
		surface.fit_view()
		view.select_chip(25)
		for key in ["field", "four", "hard_4", "hard_6", "hard_8", "hard_10", "any_seven", "any_craps", "aces", "ace_deuce", "yo", "boxcars"]:
			var wallet: float = ui.sim.owner_bankroll
			var expected: float = view.sim.bet_amount(table, key, view.bet)
			await tap(key)
			check(table.owner[key] == expected and is_equal_approx(ui.sim.owner_bankroll, wallet - expected), "Exactly one native wager " + key)
			view.sim.remove_bet(view.sim.joined, key)
			check(is_equal_approx(ui.sim.owner_bankroll, wallet), "Legal refund " + key)
		check(not surface.feedback_for("come").valid, "Come rejects before point")
		check(not surface.feedback_for("odds").valid, "Odds rejects without parent")
		var before: float = ui.sim.owner_bankroll
		await tap("come")
		await tap("odds")
		await tap("lay_odds")
		check(table.owner.pass == 0 and table.owner.dont_pass == 0, "Ineligible border never falls back to parent")
		check(ui.sim.owner_bankroll == before, "Invalid touch does not debit")
		await tap("dont_pass")
		await tap("pass")
		check(table.owner.pass == view.bet, "Pass tap")
		check(ui.sim.shoot_player(int(table.id), [2, 3]), "Existing authoritative roll")
		surface.capture_roll(table)
		surface.animation = 0
		ui.rolling = 0
		surface.dice_ready = true
		check(not CrapsRules.removable("pass", table.point) and ui.sim.remove_bet(int(table.id), "pass") == 0, "Established line cannot be removed")
		await tap("odds")
		await tap("lay_odds")
		check(table.owner.odds > 0 and table.owner.lay_odds > 0, "Established border odds native tap")
		check(ui.sim.bet(int(table.id), "dont_come", 25) and ui.sim.bet(int(table.id), "come", 25) and ui.sim.shoot_player(int(table.id), [4, 4]), "Travel Come through real rolls")
		surface.animation = 0
		ui.rolling = 0
		check(table.owner.come_8 == 25 and surface.feedback_for("come_odds_8").valid, "Traveled contract odds valid")
		surface.capture_roll(table)
		surface.animation = 0
		check(surface.target_at(surface.spots.eight) == "eight", "Empty number remains Place 8 after travel")
		await tap("come_8")
		check(surface.context_menu.visible and surface.context_odds == "come_odds_8", "Contract tap exposes exact odds")
		var remove_index: int = surface.context_menu.get_item_index(0)
		check(surface.context_menu.is_item_disabled(remove_index), "Locked Come removal disabled")
		surface.context_menu.hide()
		surface.context_menu.id_pressed.emit(2)
		await settle()
		check(table.owner.come_odds_8 > 0, "Traveled odds touch")
		await tap("dont_come_8")
		check(surface.context_odds == "dont_come_odds_8", "DC stack exposes exact lay odds")
		surface.context_menu.hide()
		surface.context_menu.id_pressed.emit(2)
		await settle()
		check(table.owner.dont_come_odds_8 > 0, "DC contextual odds")
		# Selected rack chip, desktop pointer hover and release share the same key.
		var drop: Vector2 = surface.layouts.six.position + surface.layouts.six.size * Vector2(0.7, 0.25)
		surface.begin_chip_drag(25)
		var motion := InputEventMouseMotion.new()
		motion.position = surface.offset + drop * surface.factor
		motion.relative = Vector2(40, 0)
		surface._gui_input(motion)
		check(surface.hover == "six" and surface.target_at(drop) == "six", "Desktop drag hover resolves Place 6")
		var release := InputEventMouseButton.new()
		release.position = motion.position
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		surface._gui_input(release)
		check(table.owner.six > 0, "Desktop drop submits previewed Place 6")
		surface.delivery = 0
		surface.dice_ready = true
		surface.hover = ""
		view.signature.clear()
		view.render_current()
		await settle()
		if DisplayServer.get_name() != "headless":
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/felt-craps-%dx%d.png" % [dimensions.x, dimensions.y])
			surface.pointer = surface.spots.odds
			surface.hover = surface.target_at(surface.pointer)
			surface.queue_redraw()
			RenderingServer.force_draw()
			root.get_texture().get_image().save_png("/tmp/felt-craps-desktop-odds-hover.png")
	# Private minimum uses this same shell and geometry.
	ui.felt.animation = 0
	ui.rolling = 0
	ui.leave_table()
	ui.in_back_room = true
	for station in ui.back_room_floor.sim.stations:
		if station.kind == "craps": ui.open_private_station(station); break
	await settle()
	var view = ui.game_view
	view.select_chip(1.0)
	ui.game_view.paused = false
	ui.speed = 1
	ui.felt.animation = 0
	ui.rolling = 0
	ui.felt.locked = false
	var wallet: float = ui.sim.owner_bankroll
	await tap("field")
	check(is_equal_approx(view.sim.get_table(view.sim.joined).owner.field, 1.0) and is_equal_approx(ui.sim.owner_bankroll, wallet - 1.0), "Private dollar wager")
	view.sim.remove_bet(view.sim.joined, "field")
	check(is_equal_approx(ui.sim.owner_bankroll, wallet), "Dollar refund")
	check(view.rack.denominations.all(func(value): return value >= 1), "Private rack has no sub-dollar chips")
	view.select_chip(0.25)
	check(view.bet == 1.0, "Private sub-dollar chip selection rejected")
	root.size = Vector2i(390, 844)
	root.content_scale_size = root.size
	await settle()
	view.layout_play()
	await settle()
	var surface = ui.felt
	surface.animation = 0
	surface.delivery = 0
	surface.update_view_transform()
	check(surface.side_button.visible and not surface.side_open, "Portrait starts on regular board")
	for expected in [true, false, true, false]:
		var at: Vector2 = surface.side_button.get_global_rect().get_center()
		await touch(at, true)
		var mouse := InputEventMouseButton.new()
		mouse.device = -1
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.position = at
		mouse.pressed = true
		Input.parse_input_event(mouse)
		await touch(at, false)
		mouse.pressed = false
		Input.parse_input_event(mouse)
		await settle()
		check(surface.side_open == expected and not surface.mouse_down, "One tap toggles and persists " + str(expected))
		if expected:
			var before: float = ui.sim.owner_bankroll
			await tap("hard_6")
			check(surface.side_open and is_equal_approx(view.sim.get_table(view.sim.joined).owner.hard_6, 1.0), "Overlay stays open after hardway tap")
			view.sim.remove_bet(view.sim.joined, "hard_6")
			check(is_equal_approx(ui.sim.owner_bankroll, before), "Hardway refund")
	if DisplayServer.get_name() != "headless":
		RenderingServer.force_draw()
		root.get_texture().get_image().save_png("/tmp/craps-portrait.png")
	check(surface.last_roll_caption() == "Last roll: --", "No fabricated last roll")
	check(ui.sim.back_room.add(ui.sim, "pass", 1.0) and ui.sim.back_room.roll(ui.sim), "Private real dice roll")
	surface.capture_roll(view.sim.get_table(view.sim.joined))
	surface._process(surface.ROLL_SECONDS + 0.01)
	var dice: Array = ui.sim.back_room.state.round.dice
	check(surface.last_roll_caption() == "Last roll: %d + %d = %d" % [dice[0], dice[1], int(dice[0]) + int(dice[1])], "Last roll shows settled dice and total")
	ui.leave_table()
	ui.queue_free()
	await process_frame
	DirAccess.remove_absolute("user://felt_smoke.save")
	print("FELT_SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
