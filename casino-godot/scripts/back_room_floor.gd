extends "res://presentation/casino_floor_v2.gd"
signal station_reached(station: Dictionary)
signal recovery_reached
var destination := -1

func _ready() -> void:
	super._ready()
	visitor_mode = true
	table_clicked.connect(approach_station)

func select_at(screen: Vector2) -> void:
	# The larger decorative nook routes to the same original kiosk approach.
	if recovery_art_bounds().has_point(world_at(screen)) or PitBossFloorContext.KIOSK.grow(10).has_point(world_at(screen)):
		destination = 0
		walk_to(PitBossFloorContext.KIOSK.get_center() + Vector2(0, 60))
		return
	destination = -1
	super.select_at(screen)

func approach_station(id: int) -> void:
	destination = id
	walk_to_table(id)

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	super._process(delta)
	if destination < 0: return
	var anchor := PitBossFloorContext.KIOSK.get_center() + Vector2(0, 60) if destination == 0 else sim.approach_position(sim.get_table(destination))
	if not move_target.is_finite() and sim.player.distance_to(anchor) >= 6:
		destination = -1
		return
	if sim.player.distance_to(anchor) < 6:
		var id := destination
		destination = -1
		walk_path.clear()
		move_target = Vector2(INF, INF)
		if id == 0: recovery_reached.emit()
		else: station_reached.emit(sim.get_table(id))
