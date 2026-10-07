extends SceneTree
# Focused, requested geometry/reachability checks. No economy or RNG changes.
const Placement = preload("res://scripts/asset_placement.gd")
const Catalog = preload("res://presentation/art_catalog.gd")
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func empty_floor() -> CasinoSimulation:
	var sim := CasinoSimulation.new()
	sim.tables.clear()
	sim.floor_chunks = {"left": 1, "right": 1, "bottom": 1}
	sim.reroute()
	return sim

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for kind in ["blackjack", "roulette", "craps", "holdem"]:
		var unrotated := Placement.geometry(kind, Vector2.ZERO, false, 1)
		var rotated_geometry := Placement.geometry(kind, Vector2.ZERO, true, 1)
		var center: Vector2 = unrotated.furniture.get_center()
		var rotated_center: Vector2 = rotated_geometry.furniture.get_center()
		for group in ["seats", "approaches", "dealers", "dealer_approaches"]:
			for index in range(unrotated[group].size()):
				check((rotated_geometry[group][index] - rotated_center).distance_to((unrotated[group][index] - center).rotated(PI / 2)) < 0.001, "%s %s rotates with furniture" % [kind, group])
		check(absf(unrotated.circulation.size.x - rotated_geometry.circulation.size.y) < 0.001 and absf(unrotated.circulation.size.y - rotated_geometry.circulation.size.x) < 0.001, kind + " directional clearance rotates")
		for rotated in [false, true]:
			var sim := empty_floor()
			var walk := sim.walk_area()
			var shape := Placement.geometry(kind, Vector2.ZERO, rotated, sim.next_id)
			var envelope: Rect2 = shape.collision
			var targets := {
				"bottom": Vector2(-150, walk.end.y - envelope.end.y - 0.01),
				"top": Vector2(-240, walk.position.y - envelope.position.y + 0.01),
				"left": Vector2(walk.position.x - envelope.position.x + 0.01, 300),
				"right": Vector2(walk.end.x - envelope.end.x - 0.01, 300),
			}
			for edge in targets:
				var at: Vector2 = targets[edge]
				var report := sim.placement_report(at, rotated, -1, kind)
				check(report.valid, "%s rotated=%s near %s edge: %s" % [kind, rotated, edge, report.errors])
				var outward: Vector2 = {"bottom": Vector2.DOWN, "top": Vector2.UP, "left": Vector2.LEFT, "right": Vector2.RIGHT}[edge]
				check(not sim.can_place(at + outward, rotated, -1, kind), "%s rejects clearance beyond %s edge" % [kind, edge])
				var table := sim.new_table(at, rotated, kind)
				sim.tables.append(table)
				sim.reroute()
				var grid := sim.floor_navigation()
				for seat_index in range(sim.capacity(table)):
					var seat := sim.guest_seat_position(table, seat_index)
					var approach := sim.guest_approach_position(table, seat_index)
					check(walk.has_point(seat) and walk.has_point(approach), "%s all seats/approaches inside floor" % kind)
					check(not grid.get_point_path(Placement.cell_at(CasinoTuning.ENTRY), Placement.cell_at(approach)).is_empty(), "%s guest approach reachable through gameplay AStar" % kind)
					check(seat.distance_to(report.candidate.seats[seat_index]) < 0.001 and approach.distance_to(report.candidate.approaches[seat_index]) < 0.001, "%s placement matches authored seating fix" % kind)
					var local_seat := (seat - sim.bounds(table).get_center()).rotated(-PI / 2 if rotated else 0)
					var local_step := (approach - seat).rotated(-PI / 2 if rotated else 0)
					check(local_step.dot(local_seat) > 0, "%s guest approaches outward from their player chair" % kind)
					if kind == "blackjack": check(local_step.y > 0, "Blackjack never approaches from dealer side")
					if kind in ["roulette", "craps"]: check(local_step.y * local_seat.y > 0, kind + " approach preserves upper/lower player side")
				for dealer_index in range(sim.required_crew(table)):
					var dealer := sim.dealer_position(table, dealer_index)
					var approach: Vector2 = report.candidate.dealer_approaches[dealer_index]
					check(walk.has_point(dealer) and walk.has_point(approach), kind + " dealer interaction stays inside floor")
					check(not grid.get_point_path(Placement.cell_at(CasinoTuning.ENTRY), Placement.cell_at(approach)).is_empty(), kind + " dealer approach reachable")
				if edge == "bottom":
					print("EDGE_RESULT ", JSON.stringify({"game": kind, "rotated": rotated, "furniture_bottom_gap": sim.floor_rect().end.y - sim.bounds(table).end.y, "art_bottom_gap": sim.floor_rect().end.y - report.candidate.art.end.y}))
				sim.tables.clear()
				sim.reroute()

	var sim := empty_floor()
	var first := sim.new_table(Vector2(-100, 300), false, "blackjack")
	sim.tables.append(first)
	sim.reroute()
	var allowed := sim.placement_report(Vector2(130, 300), false, -1, "blackjack")
	check(allowed.valid and allowed.candidate.collision.intersects(Placement.for_table(first).collision), "Neighbors can share a functioning circulation aisle")
	check(not sim.can_place(Vector2(115, 300), false, -1, "blackjack"), "Reject furniture consuming another table's guest approach space")
	check(not sim.can_place(Vector2(267, 82), false, -1, "blackjack"), "Entrance cannot be consumed by furniture")
	check(sim.can_place(Vector2(-200, 510), true, int(first.id)), "Moving a table checks its rotated geometry and ignores only itself")
	var moved := sim.placement_report(Vector2(-200, 510), true, int(first.id))
	check(moved.candidate.kind == "blackjack", "Moving checks the real game rather than default craps")

	# Validate shipped starts, then exercise a near-wall current-version save/load.
	var normal := CasinoSimulation.new()
	var normal_layout: Array = []
	for table in normal.tables: normal_layout.append(Placement.for_table(table))
	check(Placement.validate(normal.floor_chunks, normal_layout).valid, "Two-slot Normal start remains valid")
	for kind in ["blackjack", "roulette", "craps", "holdem"]:
		var easy := CasinoSimulation.new("easy", [kind])
		var layout: Array = []
		for table in easy.tables: layout.append(Placement.for_table(table))
		check(Placement.validate(easy.floor_chunks, layout).valid, kind + " Easy starting placement remains valid")
		var table: Dictionary = easy.tables[0]
		var shape := Placement.geometry(kind, Vector2.ZERO, bool(table.rotated), int(table.id))
		table.y = easy.walk_area().end.y - float(shape.collision.end.y) - 0.01
		easy.reroute()
		var restored := CasinoSimulation.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(easy.snapshot()))), kind + " near-wall current save restores")
		var bad := easy.snapshot()
		bad.tables[0].y += 2
		check(not restored.restore(bad), kind + " save rejects off-floor interaction clearance")
	# Move actual guests through the shared navigation + final seat-entry code.
	for kind in ["blackjack", "roulette", "craps", "holdem"]:
		for rotated in [false, true]:
			var live := CasinoSimulation.new("easy", [kind])
			var table: Dictionary = live.tables[0]
			table.rotated = rotated
			var shape := Placement.geometry(kind, Vector2.ZERO, rotated, int(table.id))
			table.y = floorf((live.walk_area().end.y - shape.collision.end.y) / 10) * 10
			live.reroute()
			live.set_open(true)
			for seat_index in range(live.guest_capacity(table)):
				live.spawn_guest()
				var guest: Dictionary = live.guests.back()
				guest.wallet = 10000
				guest.wager_limit = 100
				guest.preference = kind
				live.choose_table(guest, false)
			var stayed_inside := true
			for frame in range(300):
				live.move_guests(0.1)
				for guest in live.guests:
					if not live.walk_area().has_point(Vector2(guest.x, guest.y)): stayed_inside = false
			check(stayed_inside, "%s rotated=%s whole entry route stays inside walk area" % [kind, rotated])
			check(live.guests.all(func(guest): return guest.state == "Playing" and Vector2(guest.x, guest.y).distance_to(live.guest_seat_position(table, int(guest.seat))) < 0.01), "%s rotated=%s every public guest reaches the correct authored seat" % [kind, rotated])
	print("Asset placement checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
