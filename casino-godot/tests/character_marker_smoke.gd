extends SceneTree
const Marker = preload("res://presentation/components/guest_marker.gd")
const GuestScene = preload("res://presentation/components/guest_marker.tscn")
const StaffScene = preload("res://presentation/components/staff_marker.tscn")
var failures := 0
var checks := 0
func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(15): await process_frame
func run() -> void:
	var guest := GuestScene.instantiate()
	root.add_child(guest)
	var data := {"id": 1, "x": 10, "y": 20, "vip": false, "satisfaction": 90, "state": "Playing", "wager_limit": 100}
	guest.update_guest(data, -1, false, false)
	check(guest.body.visible and guest.high_roller, "Guest exists, wager-derived high roller")
	check(not guest.has_node("Mood") and not guest.accent.visible, "No detached mood face")
	for value in [0.05, 0.25, 1.0, 4.0, 10.0]:
		guest.set_view_zoom(value)
		var screen_size: float = guest.scale.x * value * CasinoTuning.GUEST_BASE_SCREEN_SIZE
		check(screen_size >= CasinoTuning.GUEST_MIN_SCREEN_SIZE - 0.01 and screen_size <= CasinoTuning.GUEST_MAX_SCREEN_SIZE + 0.01, "Screen clamp " + str(value))
	for entry in [[90, 4], [75, 3], [55, 2], [40, 1], [20, 0]]:
		data.satisfaction = entry[0]
		guest.update_guest(data, 1, false, false)
		check(guest.mood_state == entry[1] and guest.selected, "Mood and selection " + str(entry))
	data.vip = true
	guest.update_guest(data, 1, true, false)
	check(guest.vip and guest.high_roller and guest.rank.visible and guest.ring.visible, "VIP retains secondary high roller and selection")
	for entry in [[20, Marker.Reaction.LOSS], [-20, Marker.Reaction.WIN], [300, Marker.Reaction.BIG_LOSS], [-300, Marker.Reaction.BIG_WIN], [0, Marker.Reaction.NONE]]:
		check(Marker.financial_reaction({"category": "gaming", "amount": entry[0]}) == entry[1], "Correct house sign/magnitude " + str(entry[0]))
	check(Marker.financial_reaction({"category": "gaming", "amount": -145, "settled_stake": 5, "returned": 150, "slot_profile": "starter"}) == Marker.Reaction.JACKPOT, "Actual slot top award")
	check(Marker.financial_reaction({"category": "comp", "source": "drink", "amount": -2}) == Marker.Reaction.DRINK_DELIVERED, "Drink event including comps")
	guest.react(Marker.Reaction.JACKPOT)
	guest.react(Marker.Reaction.LOSS)
	check(guest.reaction == Marker.Reaction.JACKPOT, "Lower priority cannot interrupt")
	guest._process(2)
	check(guest.reaction == Marker.Reaction.NONE and not guest.is_processing() and guest.visual.position == Vector2.ZERO and guest.visual.scale == Vector2.ONE, "Reaction expires and transform resets")
	guest.react(Marker.Reaction.WIN)
	check(guest.reaction == Marker.Reaction.NONE, "Ordinary reaction cooldown")
	guest.react(Marker.Reaction.BIG_WIN)
	check(guest.reaction == Marker.Reaction.BIG_WIN, "Major event bypasses small cooldown")
	for type in range(1, Marker.Reaction.size()):
		guest.reaction = Marker.Reaction.NONE
		guest.cooldown_until = 0
		guest.need_until = 0
		guest.react(type)
		check(guest.reaction == type and guest.reaction_duration > 0, "Reaction starts " + str(type))
		guest._process(guest.reaction_duration * 0.4)
		guest._process(guest.reaction_duration)
		check(guest.reaction == Marker.Reaction.NONE and not guest.accent.visible and not guest.is_processing(), "Reaction expires " + str(type))
	var staff := StaffScene.instantiate()
	root.add_child(staff)
	staff.update_view({"role": "Dealer"}, Vector2.ZERO, 0.25)
	check(staff.body.texture.resource_path.ends_with("guest_green.svg") and staff.icon.texture.resource_path.ends_with("spade.svg"), "Emerald dealer with spade")
	staff.update_view({"role": "Service"}, Vector2.ZERO, 1)
	check(staff.body.texture.resource_path.ends_with("guest_cyan.svg") and staff.icon.texture.resource_path.ends_with("drink.svg"), "Cyan service with drink")
	staff.update_view({"role": "Service", "service_state": "Delivering", "tx": 40, "ty": 0}, Vector2.ZERO, 1)
	check(staff.delivering and staff.icon.position.x > 0 and staff.is_processing(), "Delivery carries drink and animates")
	staff.update_view({"role": "Owner"}, Vector2.ZERO, 1)
	check(staff.body.texture.resource_path.ends_with("guest_purple.svg") and staff.icon.texture.resource_path.ends_with("vip.svg") and not staff.delivering, "Distinct purple crowned player")
	guest.queue_free()
	staff.queue_free()
	# Exercise live zoom refresh, anchored selection and event routing on the real floor.
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.close_modal()
	ui.set_process(false)
	ui.start_casino("easy", ["blackjack", "roulette", "craps", "holdem"])
	ui.speed = 0
	ui.inspector_open = false
	for table in ui.sim.tables:
		for seat in range(5):
			ui.sim.spawn_guest()
			var person: Dictionary = ui.sim.guests[-1]
			person.table = int(table.id)
			person.seat = seat
			person.state = "Playing"
			person.satisfaction = [90, 75, 55, 40, 20][seat]
			person.vip = seat == 0
			person.wager_limit = 100 if seat == 1 else 25
	ui.sim.purchase_bar()
	check(ui.sim.hire("Service", -1), "Hire existing service role")
	var server: Dictionary = ui.sim.staff.filter(func(e): return e.role == "Service")[0]
	ui.sim.service_position(server)
	server.duty = "Active"
	server.service_state = "Delivering"
	server.x = 210.0
	server.y = 180.0
	server.tx = 280.0
	server.ty = 240.0
	ui.sim.player = Vector2(300, 200)
	ui.sim.presentation_revision += 1
	ui.refresh()
	await settle()
	var floor = ui.floor_view
	var id := int(ui.sim.guests[0].id)
	var live = floor.guest_views[id]
	var cash_before: float = ui.sim.cash
	var rng_before: int = ui.sim.rng.state
	floor.set_presentation_speed(1)
	floor._on_financial_event({"category": "gaming", "guest_id": -1, "amount": 0, "position": Vector2.ZERO, "participants": [{"guest_id": id, "amount": -20}, {"guest_id": int(ui.sim.guests[1].id), "amount": 20}]})
	check(live.reaction == Marker.Reaction.WIN and floor.guest_views[int(ui.sim.guests[1].id)].reaction == Marker.Reaction.LOSS, "Aggregate maps individual outcomes even at net zero")
	check(ui.sim.cash == cash_before and ui.sim.rng.state == rng_before, "Reactions preserve economy and RNG")
	for dims in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dims
		ui.refresh()
		await settle()
		floor.visitor_mode = true
		for value in [0.1, 4.0]:
			floor.zoom = value
			floor.world.scale = Vector2.ONE * value
			floor.sync_world()
			check(is_equal_approx(live.last_zoom, value), "Live guest receives zoom " + str(dims))
			floor.select_at(floor.screen_at(live.position + live.visual.position * live.scale.x))
			check(ui.selected_guest == id, "Anchored guest selection " + str(dims))
			check(live.position.is_equal_approx(floor.guest_visual_position(ui.sim.guests[0])), "Seated anchor remains aligned")
			check(is_equal_approx(floor.get_node("World/Player").scale.x, CasinoTuning.character_scale(value, CasinoTuning.PLAYER_BASE_SCREEN_SIZE)), "Player receives zoom")
		floor.selected_guest = id
		floor.visitor_mode = false
		floor.close_view = true
		floor.view_scale = 1.0
		ui.refresh()
		await settle()
		if "--screenshots" in OS.get_cmdline_user_args():
			ui.inspector_open = false
			ui.refresh()
			await settle()
			# Keep camera framing stable while exposing the real owner marker.
			floor.set_process(false)
			floor.visitor_mode = true
			floor.sync_world()
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/character-markers-%dx%d.png" % [dims.x, dims.y])
		floor.set_process(true)
	print("Character marker smoke: ", checks, " checks; ", failures, " failed")
	quit(1 if failures else 0)
