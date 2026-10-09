extends SceneTree
# Focused expansion regression, including the actual UI callback and camera inputs.
const Property = preload("res://scripts/floor_property.gd")
const Placement = preload("res://scripts/asset_placement.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("PROPERTY EXPANSION FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func funded(populated: bool = false) -> CasinoSimulation:
	var sim := CasinoSimulation.new()
	sim.cash = 1000000
	sim.blackjack_unlocked = true
	sim.casino_rating = 50
	if populated:
		sim.tables.clear()
		for at in [Vector2(80, 100), Vector2(400, 100)]:
			sim.tables.append(sim.new_table(at, false, "slots"))
		sim.tables.append(sim.new_table(Vector2(80, 330), false, "blackjack"))
	sim.reroute()
	return sim

func validate(sim: CasinoSimulation) -> Dictionary:
	return Placement.validate(sim.floor_chunks, sim.placement_geometry(), sim.placement_access_points(sim.bar_owned), sim.frontage_chunks, sim.placement_access_names(sim.bar_owned))

func buy(sim: CasinoSimulation, direction: String) -> void:
	# Re-enable the fixture's earned eligibility; purchase refreshes real progression.
	sim.casino_rating = 50
	var before := sim.snapshot()
	var entry := sim.entry_position()
	var cage := sim.cage_pickup()
	var counter := sim.bar_bounds()
	var door := Property.private_door(sim.floor_chunks, sim.frontage_chunks)
	var nav := sim.floor_navigation().region
	var quote := sim.expansion_quote(direction)
	check(validate(sim).valid, "Legal layout before " + direction)
	check(sim.purchase_expansion(direction), "Purchase " + direction + ": " + str(sim.expansion_errors))
	check(sim.floor_rect() == quote.rectangle and sim.floor_rect().encloses(Property.rectangle(before.floor_chunks)), direction + " grows the rectangle")
	check(sim.cash == float(before.cash) - float(quote.cost), direction + " charged exactly once")
	check(sim.expense_totals.construction == float(before.expense_totals.construction) + float(quote.cost), direction + " construction charged once")
	check(sim.entry_position() == entry and sim.cage_pickup() == cage and sim.bar_bounds() == counter, direction + " keeps lobby interactions fixed")
	check(Property.private_door(sim.floor_chunks, sim.frontage_chunks) == door, direction + " keeps Back Room door fixed")
	check(sim.tables == before.tables, direction + " leaves every furniture position/state fixed")
	check(str(sim.rng.state) == before.rng_state and sim.owner_account.snapshot() == before.owner_bankroll, direction + " preserves RNG and owner wallet")
	check(sim.floor_navigation().region != nav, direction + " rebuilds navigation region")
	check(validate(sim).valid, direction + " all guest/dealer/service approaches reachable")
	var restored := CasinoSimulation.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), direction + " expanded save restores")
	check(restored.floor_chunks == sim.floor_chunks and restored.frontage_chunks == sim.frontage_chunks and JSON.parse_string(JSON.stringify(restored.tables)) == JSON.parse_string(JSON.stringify(sim.tables)) and restored.cash == sim.cash and str(restored.rng.state) == str(sim.rng.state), direction + " load preserves geometry/furniture/cash/RNG")

func rejected(sim: CasinoSimulation, direction: String, reason: String) -> void:
	var before := sim.snapshot()
	check(not sim.purchase_expansion(direction), "Reject " + reason)
	check(sim.snapshot() == before, reason + " leaves entire saved state unchanged")
	check(not sim.expansion_errors.is_empty() and str(sim.expansion_errors[0].message).contains(reason), "Specific error: " + reason)

func find_button(node: Node, title: String) -> Button:
	if node is Button and node.text == title: return node
	for child in node.get_children():
		var button := find_button(child, title)
		if button != null: return button
	return null

func has_label(node: Node, fragment: String) -> bool:
	if node is Label and node.text.contains(fragment): return true
	for child in node.get_children():
		if has_label(child, fragment): return true
	return false

func run() -> void:
	for direction in ["left", "right", "bottom"]:
		buy(funded(), direction)
		buy(funded(true), direction)
	var sim := funded(true)
	sim.bar_owned = true
	for direction in ["left", "right", "left", "right", "bottom"]: buy(sim, direction)
	# Build and move into both side wings using the real placement APIs.
	var table: Dictionary = sim.tables[-1]
	for at in [Vector2(-500, 300), Vector2(900, 300)]:
		check(sim.can_place(at, false, -1, "blackjack"), "Build table in side wing " + str(at))
		check(sim.can_place(at, false, int(table.id), "blackjack"), "Move existing table into side wing " + str(at))
		table.x = at.x
		table.y = at.y
		sim.reroute()
		check(validate(sim).valid, "Moved table has reachable seats/dealer")
	# Walk the runtime route/movement used by guests, service and technicians;
	# dealer approaches use the same AStar solids and connectivity.
	var destinations := sim.placement_access_points(true)
	for asset in sim.placement_geometry():
		destinations.append_array(asset.approaches)
		destinations.append_array(asset.dealer_approaches)
	for target in destinations:
		var actor := {"x": sim.entry_position().x, "y": sim.entry_position().y, "tx": target.x, "ty": target.y}
		sim.route(actor)
		check(not actor.path.is_empty(), "Runtime route to " + str(target))
		for i in range(200): sim.move_entity(actor, 0.5)
		check(Vector2(actor.x, actor.y).distance_to(target) < 1, "Runtime movement reaches " + str(target))
	check(sim.hire("Dealer", int(table.id)), "Dealer can staff table in purchased wing")
	sim.opened = true
	sim.spawn_guest()
	var guest: Dictionary = sim.guests[-1]
	guest.state = "Walking"
	guest.table = table.id
	guest.seat = 0
	var guest_target := sim.guest_approach_position(table, 0)
	guest.tx = guest_target.x
	guest.ty = guest_target.y
	sim.route(guest)
	for i in range(200): sim.move_guests(0.5)
	check(guest.state == "Playing" and Vector2(guest.x, guest.y).distance_to(sim.guest_seat_position(table, 0)) < 1, "Guest enters main entrance and reaches wing seat")
	guest.rounds = 1
	sim.leave(guest, "Expansion regression departure")
	var departure_cash := sim.cash
	for i in range(200): sim.move_guests(0.5)
	check(guest.state == "Leaving" and Vector2(guest.x, guest.y).distance_to(sim.entry_position()) < 3, "Guest visits cage and exits original entrance after expansion")
	check(sim.cash == departure_cash, "Cage departure does not change settled cash")
	check(sim.hire("Service", -1), "Hire bartender on expanded floor")
	for i in range(100): sim.move_service(0.5)
	var bartender: Dictionary = sim.staff[-1]
	check(Vector2(bartender.x, bartender.y).distance_to(sim.bar_pickup()) < 3, "Bartender reaches anchored pickup")
	check(sim.hire("Tech", -1), "Hire technician on expanded floor")
	table.broken = true
	sim.incidents.append({"type": "repair", "table": int(table.id), "title": "Broken table", "detail": "Regression fixture"})
	sim.TechService.tick(sim)
	var tech: Dictionary = sim.staff[-1]
	check(tech.duty == "Repairing" and not tech.path.is_empty(), "Technician routes to equipment in purchased wing")
	sim.TechService.move(sim, 1.0)
	check(Vector2(tech.x, tech.y).distance_to(Vector2(tech.tx, tech.ty)) < 6, "Technician reaches wing repair")
	var legacy := funded()
	legacy.floor_chunks.right = 1
	legacy.frontage_chunks = legacy.floor_chunks.duplicate()
	# This furniture is legal with the former expanded frontage but would block
	# a forced reset to the starter entrance. Keep it in place on restore.
	legacy.tables.clear()
	legacy.tables.append(legacy.new_table(Vector2(245, 100), false, "slots"))
	legacy.bar_owned = true
	legacy.reroute()
	check(validate(legacy).valid, "Existing recentered save fixture legal")
	var old_save := legacy.snapshot()
	old_save.erase("frontage_chunks")
	var restored := CasinoSimulation.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(old_save))), "Existing valid save without anchor loads")
	check(restored.entry_position() == legacy.entry_position() and restored.cage_pickup() == legacy.cage_pickup() and restored.bar_bounds() == legacy.bar_bounds(), "Existing save retains all old frontage positions")
	buy(restored, "left")
	var bad := sim.snapshot()
	bad.frontage_chunks.left = bad.floor_chunks.left + 1
	check(not restored.restore(bad), "Reject anchor outside owned footprint")
	bad = sim.snapshot()
	bad.frontage_chunks.left = -1
	check(not restored.restore(bad), "Reject corrupt frontage metadata")
	var locked := CasinoSimulation.new()
	rejected(locked, "left", "not been unlocked")
	var poor := funded()
	poor.cash = 0
	rejected(poor, "right", "Insufficient casino cash")
	var capped := funded()
	capped.floor_chunks.left = CasinoTuning.FLOOR_MAX_DIRECTION_CHUNKS
	capped.reroute()
	rejected(capped, "left", "Maximum practical property size")
	rejected(funded(), "up", "Unknown expansion direction")
	var obstructed := funded()
	obstructed.tables[0].x = 245
	obstructed.tables[0].y = 100
	obstructed.reroute()
	rejected(obstructed, "right", "Furniture/art blocks the entrance")
	check(int(obstructed.expansion_errors[0].asset_id) == int(obstructed.tables[0].id), "Actual validator identifies obstructing asset")
	var blocked_service := Placement.validate(sim.floor_chunks, sim.placement_geometry(), PackedVector2Array([Vector2(table.x + 30, table.y + 30)]), sim.frontage_chunks, PackedStringArray(["Back Room doorway"]))
	check(not blocked_service.valid and str(blocked_service.errors[0].message).contains("Back Room doorway"), "Validator names unreachable interaction")
	# Actual Purchase callback, retained world geometry and desktop/mobile Fit/pan/zoom.
	root.size = Vector2i(1440, 900)
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.start_casino("normal", [])
	ui.speed = 0
	ui.set_process(false)
	ui.floor_view.set_process(false)
	ui.sim.cash = 1000000
	ui.sim.blackjack_unlocked = true
	ui.sim.casino_rating = 50
	ui.open_page("development")
	ui.refresh()
	var purchase := find_button(ui.inspector, "Purchase left")
	check(purchase != null, "Purchase Left callback available")
	if purchase != null: purchase.pressed.emit()
	check(ui.sim.floor_chunks.left == 1 and not ui.floor_view.close_view, "UI buys and immediately frames expansion")
	var view = ui.floor_view
	check(view.get_node("World/Carpet").position == ui.sim.floor_rect().position and view.get_node("World/Carpet").size * 0.16 == ui.sim.floor_rect().size, "Retained carpet covers purchased space")
	check(view.get_node("World/Lobby").size * 0.35 == Vector2(535, 112), "Starter lobby stays anchored")
	for dimensions in [Vector2(1440, 900), Vector2(390, 844), Vector2(844, 390)]:
		view.size = dimensions
		view.compact_labels = dimensions.x < 900
		view.landscape_view = dimensions.x > dimensions.y
		view.mobile_viewport = Rect2(Vector2(0, 72), dimensions - Vector2(0, 72))
		for direction in ["right", "bottom"]:
			ui.sim.casino_rating = 50
			ui.purchase_floor_expansion(direction)
			view.update_camera(1)
			var viewport: Rect2 = view.mobile_viewport if view.compact_labels else Rect2(Vector2(0, view.management_top), Vector2(view.size.x, view.size.y - view.management_top))
			var visible := Rect2(view.screen_at(ui.sim.floor_rect().position), ui.sim.floor_rect().size * view.zoom)
			check(viewport.grow(0.1).encloses(visible), "Fit contains entire property " + str(dimensions) + " " + direction)
		view.toggle_fit()
		view.pan_center = ui.sim.floor_rect().get_center() + Vector2(100, 30)
		view.view_scale = 1.4
		view.update_camera(1)
		var manual_pan: Vector2 = view.pan_center
		var manual_scale: float = view.view_scale
		view.update_camera(1)
		check(view.close_view and view.pan_center == manual_pan and view.view_scale == manual_scale, "Ordinary gameplay preserves manual camera " + str(dimensions))
		var wheel := InputEventMouseButton.new()
		wheel.button_index = MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		wheel.position = dimensions / 2
		view._gui_input(wheel)
		check(view.view_scale > manual_scale, "Mouse zoom remains usable " + str(dimensions))
		view.pointer_down = true
		view.pointer_start = dimensions / 2
		var drag := InputEventMouseMotion.new()
		drag.position = dimensions / 2 + Vector2(30, 0)
		drag.relative = Vector2(30, 0)
		var pan_before: Vector2 = view.pan_center
		view._gui_input(drag)
		view.pointer_down = false
		check(view.pan_center != pan_before, "Pan remains usable " + str(dimensions))
		if view.compact_labels:
			var finger := InputEventScreenTouch.new()
			finger.index = 0
			finger.pressed = true
			finger.position = dimensions / 2
			view.handle_touch(finger)
			var touch_drag := InputEventScreenDrag.new()
			touch_drag.index = 0
			touch_drag.position = dimensions / 2 + Vector2(30, 0)
			touch_drag.relative = Vector2(30, 0)
			pan_before = view.pan_center
			view.handle_touch(touch_drag)
			check(view.pan_center != pan_before, "Touch pan works after expansion " + str(dimensions))
			var second := InputEventScreenTouch.new()
			second.index = 1
			second.pressed = true
			second.position = touch_drag.position + Vector2(80, 0)
			view.handle_touch(second)
			var pinch := InputEventScreenDrag.new()
			pinch.index = 1
			pinch.position = touch_drag.position + Vector2(120, 0)
			manual_scale = view.view_scale
			view.handle_touch(pinch)
			check(view.view_scale > manual_scale, "Touch pinch zoom works after expansion " + str(dimensions))
			view.touch_points.clear()
	# Exercise the actual controller's build and move commands in purchased space.
	ui.mobile = false
	ui.building = true
	ui.build_kind = "blackjack"
	ui.sim.blackjack_unlocked = true
	ui.moving = -1
	var count_before: int = ui.sim.tables.size()
	ui.commit_placement(Vector2(-200, 300))
	check(ui.sim.tables.size() == count_before + 1, "Actual build command places table in left wing")
	var moved_id: int = ui.sim.tables[-1].id
	ui.building = true
	ui.moving = moved_id
	ui.commit_placement(Vector2(700, 300))
	check(Vector2(ui.sim.get_table(moved_id).x, ui.sim.get_table(moved_id).y) == Vector2(700, 300), "Actual move command moves table into right wing")
	ui.open_page("development")
	ui.sim.casino_rating = 50
	ui.sim.cash = 0
	ui.purchase_floor_expansion("left")
	check(has_label(ui.inspector, "Insufficient casino cash"), "Purchase error appears immediately in expansion panel")
	ui.sim.cash = 1000000
	ui.sim.tables[0].x = 245
	ui.sim.tables[0].y = 100
	ui.sim.reroute()
	ui.purchase_floor_expansion("left")
	check(has_label(ui.inspector, "Asset #") and has_label(ui.inspector, "Furniture/art blocks the entrance"), "Panel displays actual validator error and asset ID")
	ui.queue_free()
	await process_frame
	print("PROPERTY_EXPANSION_SMOKE checks=%d failures=%d" % [checks, failures])
	call_deferred("quit", 1 if failures else 0)
