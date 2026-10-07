extends SceneTree
# Scoped uiPass acceptance: real controller, presentation nodes, routing and saves.
const Catalog = preload("res://presentation/art_catalog.gd")
var ui: Control
var checks := 0
var failures := 0
func check(value: bool, message: String) -> void:
	if value: checks += 1
	else:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(15): await process_frame
func start(games: Array) -> void:
	ui.start_casino("easy", games)
	ui.speed = 0
	ui.inspector_open = false
	ui.floor_view.close_view = false
	ui.refresh()
func capture(label: String) -> void:
	if "--screenshots" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/floor-art-" + label + ".png")
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.close_modal()
	ui.set_process(false)
	# Exercise the real selection, Move, Rotate and Build controller paths per kind.
	for kind in ["blackjack", "roulette", "craps", "holdem"]:
		start([kind])
		await settle()
		var table: Dictionary = ui.sim.tables[0]
		var view: Node2D = ui.floor_view.asset_views[int(table.id)]
		check(view.asset_path == Catalog.path_for(kind), "Canonical art " + kind)
		check(view.sprite.scale.x == view.sprite.scale.y, "Aspect preserved " + kind)
		check(not view.has_node("TableRug") and not view.has_node("RugEdge"), "No oval rug")
		check(view.simulation_bounds == ui.sim.bounds(table), "Unchanged logical bounds")
		ui.floor_view.select_at(ui.floor_view.screen_at(ui.sim.bounds(table).get_center()))
		check(ui.selected == int(table.id) and ui.inspector_open, "Select " + kind)
		var moved := Vector2(120, 160)
		var old_rotation: bool = table.rotated
		ui.begin_move()
		ui.floor_view.rotated = not old_rotation
		check(ui.sim.can_place(moved, ui.floor_view.rotated, int(table.id)), "Clear rotated placement")
		ui.commit_placement(moved)
		check(Vector2(table.x, table.y) == moved and table.rotated != old_rotation, "Move/rotate " + kind)
		await settle()
		view = ui.floor_view.asset_views[int(table.id)]
		var local := Catalog.local_seat_anchors(kind, view.visual_size)
		for i in range(local.size()):
			check(view.seat_anchors[i].is_equal_approx(local[i].rotated(view.sprite.rotation)), "Rotated seat " + kind)
		ui.building = true
		ui.moving = -1
		ui.build_kind = kind
		ui.floor_view.rotated = false
		ui.commit_placement(Vector2(370, 370))
		check(ui.sim.tables.size() == 2, "Build " + kind)
	# Populate all new artwork with existing seat semantics for visual verification.
	start(["blackjack", "roulette", "craps", "holdem"])
	for table in ui.sim.tables:
		for seat in range(7):
			ui.sim.spawn_guest()
			var guest: Dictionary = ui.sim.guests[-1]
			guest.table = int(table.id)
			guest.seat = seat
			guest.state = "Playing"
			guest.x = ui.sim.bounds(table).get_center().x
			guest.y = ui.sim.bounds(table).end.y + 24
	for slot in range(5):
		ui.sim.spawn_guest()
		var guest: Dictionary = ui.sim.guests[-1]
		var at: Vector2 = ui.sim.bar_guest_position(slot)
		guest.x = at.x
		guest.y = at.y
		guest.state = "At bar"
		guest.bar_slot = slot
	ui.sim.presentation_revision += 1
	var rng_before: int = ui.sim.rng.state
	var cash_before: float = ui.sim.cash
	await settle()
	for guest in ui.sim.guests:
		if guest.state != "Playing": continue
		var view: Node2D = ui.floor_view.asset_views[int(guest.table)]
		check(ui.floor_view.guest_visual_position(guest).is_equal_approx(view.position + view.seat_anchors[int(guest.seat)]), "Visible guest on chair/rail")
	check(ui.sim.rng.state == rng_before and ui.sim.cash == cash_before, "Presentation leaves RNG/economy unchanged")
	var floor: Control = ui.floor_view
	check(not floor.has_node("World/Lounge") and not floor.has_node("World/Entrance"), "Prototype decor removed")
	check(floor.get_node("World/Cage") is TextureRect, "Cage uses artwork")
	var cage: TextureRect = floor.get_node("World/Cage")
	check(is_equal_approx(cage.position.y + cage.size.y, CasinoSimulation.CAGE_PICKUP.y), "Cage public side at pickup")
	var bar: TextureRect = floor.get_node("World/Bar")
	check(bar.size.x > ui.sim.bar_bounds().size.x and bar.size.y > ui.sim.bar_bounds().size.y, "Substantial independent bar art")
	check((bar.position + bar.size * Catalog.AMENITY_CUSTOMER_ANCHORS.bar).is_equal_approx(ui.sim.bar_guest_position(2)), "Bar customer row aligned")
	for dims in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dims
		ui.inspector_open = false
		ui.floor_view.close_view = false
		ui.refresh()
		await settle()
		check(ui.floor_view.visible, "Floor visible " + str(dims))
		await capture("%dx%d" % [dims.x, dims.y])
	# A played guest follows the authoritative cage route and cashes out once.
	var craps: Dictionary = ui.sim.tables[2]
	var gambler: Dictionary = ui.sim.guests[14]
	check(ui.sim.take_bet(craps, gambler, "pass", 10, false), "Real guest wager")
	ui.sim.roll(int(craps.id), [1, 6])
	check(gambler.rounds > 0, "Actual settled guest round")
	ui.sim.leave(gambler, "Acceptance cash-out")
	check(Vector2(gambler.tx, gambler.ty) == CasinoSimulation.CAGE_PICKUP, "Authoritative cage target")
	var cash: float = ui.sim.cash
	for i in range(250):
		ui.sim.move_guests(0.25)
		if gambler.state == "Leaving": break
	check(gambler.state == "Leaving" and not ui.sim.cashout_effects.is_empty(), "Cage cash-out completes")
	check(ui.sim.cash == cash, "Cash-out does not settle money twice")
	# Save a real simulated session; the visual seating fixture above is intentionally synthetic.
	start(["blackjack", "roulette", "craps", "holdem"])
	# Existing four-game Easy setup places rotated Hold'em 20 units beyond the build area.
	# Use the real Move controller to make a valid session; do not change gameplay defaults.
	ui.selected = int(ui.sim.tables[3].id)
	ui.begin_move()
	ui.commit_placement(Vector2(370, 300))
	check(ui.sim.placement_area("holdem").encloses(ui.sim.bounds(ui.sim.tables[3])), "Valid save fixture placement")
	ui.sim.set_open(true)
	for minute in range(50):
		ui.sim.step()
		ui.sim.move_guests(1.0)
	var data: Dictionary = JSON.parse_string(JSON.stringify(ui.sim.snapshot()))
	var restored := CasinoSimulation.new()
	check(restored.restore(data), "Current save/load")
	check(restored.tables.size() == 4 and is_equal_approx(restored.cash, ui.sim.cash), "Saved table/economy retained")
	# Existing service crew collects at the unchanged bar pickup and delivers an order.
	start(["slots"])
	ui.sim.set_open(true)
	check(ui.sim.hire("Service", -1), "Hire existing service role")
	for product in ui.sim.drink_access: ui.sim.set_drink_menu(product, true)
	ui.sim.spawn_guest()
	var thirsty: Dictionary = ui.sim.guests[-1]
	var bar_at: Vector2 = ui.sim.bar_guest_position(2)
	thirsty.x = bar_at.x
	thirsty.y = bar_at.y
	thirsty.state = "At bar"
	thirsty.bar_slot = 2
	thirsty.thirst = 100.0
	thirsty.wallet = 1000.0
	ui.sim.Bar.request(ui.sim, thirsty)
	check(thirsty.drink_order != "", "Existing bar order")
	var server: Dictionary = ui.sim.staff.filter(func(e): return e.role == "Service")[0]
	ui.sim.service_position(server)
	check(Vector2(server.x, server.y) == ui.sim.bar_pickup(), "Unchanged reachable staff pickup")
	for i in range(250):
		ui.sim.move_service(0.25)
		if ui.sim.bar_totals.sold + ui.sim.bar_totals.comped > 0: break
	check(ui.sim.bar_totals.sold + ui.sim.bar_totals.comped == 1 and thirsty.thirst == 0, "Pickup/delivery completes")
	print("Floor asset acceptance: ", checks, " passed; ", failures, " failed")
	quit(1 if failures > 0 else 0)
