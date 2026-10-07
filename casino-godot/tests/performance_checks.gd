extends SceneTree
const Floor = preload("res://scripts/floor.gd")
const Main = preload("res://scripts/main.gd")
var failures := 0
var checks := 0
func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for speed in [1, 2, 4]:
		var sim := CasinoSimulation.new()
		var floor := Floor.new()
		floor.sim = sim
		floor.size = Vector2(800, 600)
		root.add_child(floor)
		floor.set_process(false)
		floor.set_presentation_speed(speed)
		sim.spawn_guest()
		var guest: Dictionary = sim.guests[0]
		guest.x = 200
		guest.y = 200
		var before := [sim.cash, sim.revenue, sim.guest_revenue, sim.owner_bankroll]
		var delivered: Array = []
		sim.financial_event.connect(func(event): delivered.append(event.amount))
		var expected := 0.0
		for tick in range(1, 5 * speed + 1):
			sim.elapsed = tick
			var amount := float([25, -10, 40, -5, 15][(tick - 1) % 5])
			expected += amount
			sim.emit_financial_event(amount, "gaming", sim.tables[0], guest.id)
			sim.think(guest, "Thought %d" % tick, 3)
			check(guest.thought == "Thought %d" % tick, "AI thought updated on original tick")
			floor.presentation_step()
			floor.update_thoughts(1.0 / speed)
			if tick < 5 * speed:
				check(floor.floating_results.is_empty() and floor.thought_bubbles.is_empty(), "Hidden pending feedback before cadence")
		check(delivered.size() == 5 * speed, "Immediate individual economic events at %dx" % speed)
		check(floor.floating_results.size() == 1 and absf(floor.floating_results[0].amount - expected) < 0.001, "Single net batch at %dx" % speed)
		check(floor.thought_bubbles.size() == 1 and floor.pending_thoughts.is_empty(), "One thought per window at %dx" % speed)
		check(before == [sim.cash, sim.revenue, sim.guest_revenue, sim.owner_bankroll], "Presentation does not alter balances")
		floor._on_financial_event({"amount": 10, "category": "gaming", "position": Vector2.ZERO})
		floor._on_guest_thought({"guest_id": guest.id, "text": "stale", "priority": 2})
		floor.set_presentation_speed(0)
		floor.set_presentation_speed(1)
		check(floor.presentation_amount == 0 and floor.pending_thoughts.is_empty() and floor.presentation_tick == 0, "Pause rebases without stale backlog")
		floor.set_presentation_speed(4)
		floor.set_presentation_speed(1)
		check(delivered.size() == 5 * speed, "Speed changes do not replay economic events")
		floor.set_presentation_speed(1000)
		for i in range(100):
			floor._on_financial_event({"amount": 10, "category": "gaming", "position": Vector2.ZERO})
			floor.presentation_step()
		check(floor.presentation_amount == 0, "DEV speed suppresses routine feedback")
		floor.queue_free()
		await process_frame
	var plain := CasinoSimulation.new()
	var batched := CasinoSimulation.new()
	plain.rng.seed = 422
	plain.opened = true
	check(batched.restore(plain.snapshot()), "Feedback comparison starts from identical complete state, including optional-event RNG")
	var floor := Floor.new()
	floor.sim = batched
	floor.set_presentation_speed(4)
	for minute in range(500):
		plain.move_guests(1)
		batched.move_guests(1)
		plain.step()
		batched.step()
		floor.presentation_step()
	check(plain.snapshot() == batched.snapshot() and plain.rng.state == batched.rng.state, "500-tick exact state/RNG equivalence with feedback connected")
	floor.free()
	var ui: Main = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.set_process(false)
	ui.speed = 0
	ui.refresh()
	await process_frame
	var labels := ui.inspector.get_children()
	var node_count := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	for i in range(100): ui.refresh()
	await process_frame
	check(labels == ui.inspector.get_children(), "Idle refresh retains inspector nodes")
	check(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) == node_count, "Idle refresh retains node count")
	ui.floor_view.camera = Vector2.ZERO
	ui.floor_view.zoom = 1
	for i in range(180): ui.floor_view._process(1.0 / 60)
	# Cache agrees with authoritative scans, including immediate assignment changes.
	var cache := ui.sim.floor_presentation()
	for table in ui.sim.tables:
		check(cache.seated.get(int(table.id), []) == ui.sim.seated(int(table.id)), "Presentation seated index agrees")
		check(cache.reserved.get(int(table.id), []) == ui.sim.reserved_guests(int(table.id)), "Presentation reservations agree")
		check(cache.status[int(table.id)] == ui.sim.table_status(table), "Presentation status agrees")
	ui.queue_free()
	await process_frame
	print("PERFORMANCE CHECKS: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
