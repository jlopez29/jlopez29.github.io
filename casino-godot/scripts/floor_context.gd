class_name PitBossFloorContext
extends RefCounted
## The same world renderer and movement controller read either location dataset.
const Placement = preload("res://scripts/asset_placement.gd")
const Catalog = preload("res://presentation/art_catalog.gd")
const Property = preload("res://scripts/floor_property.gd")
const ROOM := Rect2(0, 0, 900, 760)
const EXIT := Rect2(788, 702, 84, 32)
const KIOSK := Rect2(45, 530, 110, 65)
var source: CasinoSimulation
var is_private := false
var stations: Array = []
var navigation: AStarGrid2D
var tables: Array:
	get: return stations if is_private else source.tables
var guests: Array:
	get: return [] if is_private else source.guests
var staff: Array:
	get: return [] if is_private else source.staff
var player: Vector2:
	get: return Vector2(source.location.private_position[0], source.location.private_position[1]) if is_private else source.player
	set(value):
		if is_private: source.location.private_position = [value.x, value.y]
		else: source.player = value
var joined: int:
	get: return -1 if is_private else source.joined
var presentation_revision: int:
	get: return 0 if is_private else source.presentation_revision
var elapsed: float:
	get: return source.elapsed
var opened: bool:
	get: return source.opened
var cash: float:
	get: return source.cash
var next_id: int:
	get: return source.next_id
var cashout_effects: Array:
	get: return [] if is_private else source.cashout_effects

func _init(simulation: CasinoSimulation, private_room: bool = false) -> void:
	source = simulation
	is_private = private_room
	if is_private:
		var definitions := [["slots", Vector2(80, 170)], ["slots", Vector2(170, 170)], ["slots", Vector2(260, 170)],
			["blackjack", Vector2(435, 170)], ["roulette", Vector2(80, 350)],
			["craps", Vector2(435, 385)], ["holdem", Vector2(435, 590)]]
		for i in range(definitions.size()):
			stations.append({"id": i + 1, "kind": definitions[i][0], "x": definitions[i][1].x,
				"y": definitions[i][1].y, "rotated": false, "broken": false, "slot_profile": "starter"})
		var geometry := placement_geometry()
		geometry.append({"furniture": KIOSK})
		navigation = Placement.navigation_in(walk_area(), geometry)

func floor_rect() -> Rect2:
	return ROOM if is_private else source.floor_rect()
func walk_area() -> Rect2:
	return ROOM.grow(-22) if is_private else source.walk_area()
func bounds(table: Dictionary) -> Rect2:
	return Rect2(Vector2(table.x, table.y), Placement.furniture_size(table.kind, table.rotated))
func table_kind(table: Dictionary) -> String:
	return source.table_kind(table)
func slot_profile(table: Dictionary) -> Dictionary:
	return source.slot_profile(table)
func get_table(id: int) -> Dictionary:
	for station in tables:
		if int(station.id) == id: return station
	return {}
func approach_position(table: Dictionary) -> Vector2:
	return Catalog.approach_position_for(table.kind, 0, bounds(table), table.rotated, table.id)
func dealer_position(table: Dictionary, index: int) -> Vector2:
	return Catalog.dealer_position_for(table.kind, index, bounds(table), table.rotated, table.id)
func guest_seat_position(table: Dictionary, index: int) -> Vector2:
	return source.guest_seat_position(table, index)
func floor_presentation() -> Dictionary:
	if not is_private: return source.floor_presentation()
	var index := {"tables": {}, "guests": {}, "crew": {}, "operating": {}, "hot": {}, "seated": {}}
	for station in stations:
		index.tables[station.id] = station
		index.operating[station.id] = true
		index.crew[station.id] = []
		for i in range(Catalog.DEALER_ANCHORS.get(station.kind, []).size()):
			index.crew[station.id].append({"id": station.id * 10 + i, "role": "Dealer", "duty": "Active"})
	return index
func placement_geometry() -> Array:
	if not is_private: return source.placement_geometry()
	var result: Array = []
	for station in stations: result.append(Placement.for_table(station))
	return result
func route(request: Dictionary) -> void:
	if is_private: Placement.route_grid(request, navigation)
	else: source.route(request)
func bar_available() -> bool:
	return false if is_private else source.bar_available()
func cage_pickup() -> Vector2:
	return source.cage_pickup()
func bar_bounds() -> Rect2:
	return source.bar_bounds()
func bar_guest_position(index: int) -> Vector2:
	return source.bar_guest_position(index)
func furniture_size(kind: String, rotated: bool) -> Vector2:
	return source.furniture_size(kind, rotated)
func placement_report(at: Vector2, rotated: bool, ignore: int = -1, kind: String = "craps") -> Dictionary:
	return source.placement_report(at, rotated, ignore, kind)
func can_place(at: Vector2, rotated: bool, ignore: int = -1, kind: String = "craps") -> bool:
	return not is_private and source.can_place(at, rotated, ignore, kind)
func purchase_cost(kind: String, profile: String = "starter") -> float:
	return source.purchase_cost(kind, profile)
func unlocked(kind: String) -> bool:
	return source.unlocked(kind)
func slot_unlocked(profile: String) -> bool:
	return source.slot_unlocked(profile)
func door_bounds() -> Rect2:
	return EXIT if is_private else Property.private_door(source.floor_chunks)
func door_approach() -> Vector2:
	return EXIT.get_center() - Vector2(0, 36) if is_private else Property.private_approach(source.floor_chunks)

func safe_public_threshold() -> Vector2:
	var anchor := Property.private_approach(source.floor_chunks)
	var grid := source.floor_navigation()
	var connected := Placement.connected_cells(grid, source.entry_position())
	if Placement.reachable(grid, connected, anchor) and public_threshold_free(anchor): return anchor
	var best := source.player
	var distance := INF
	for x in range(grid.region.position.x, grid.region.end.x):
		for y in range(grid.region.position.y, grid.region.end.y):
			var at := Vector2(x, y) * CasinoTuning.FLOOR_NAV_CELL
			if Placement.reachable(grid, connected, at) and public_threshold_free(at) and at.distance_squared_to(anchor) < distance:
				best = at
				distance = at.distance_squared_to(anchor)
	return best

func public_threshold_free(at: Vector2) -> bool:
	# Return beside the doorway without landing on current lobby traffic.
	var radius := CasinoTuning.ASSET_NAV_RADIUS
	for actor in source.guests + source.staff:
		if at.distance_to(Vector2(actor.get("x", -1000), actor.get("y", -1000))) < radius * 2: return false
	for amenity in [Catalog.amenity_visual_bounds("cashier_cage", source.cage_pickup()), Catalog.amenity_visual_bounds("bar", source.bar_guest_position(2))]:
		if amenity.grow(radius).has_point(at): return false
	return true
