extends RefCounted
# Shared furniture, art, interaction, circulation and navigation geometry.
# Placement and saves use the same rules; no simulation/RNG mutation here.
const Property = preload("res://scripts/floor_property.gd")
const Catalog = preload("res://presentation/art_catalog.gd")
const DIRECTIONS := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func furniture_size(kind: String, rotated: bool) -> Vector2:
	var size := Vector2(60, 70) if kind == "slots" else CasinoTuning.CRAPS_SIZE if kind == "craps" else CasinoTuning.TABLE_SIZE
	return Vector2(size.y, size.x) if rotated else size

static func geometry(kind: String, at: Vector2, rotated: bool, id: int) -> Dictionary:
	var furniture := Rect2(at, furniture_size(kind, rotated))
	var art := Catalog.art_bounds_for(kind, furniture, rotated, id)
	var seats := PackedVector2Array()
	var approaches := PackedVector2Array()
	var dealers := PackedVector2Array()
	var dealer_approaches := PackedVector2Array()
	var circulation := furniture.grow(CasinoTuning.ASSET_UNUSED_EDGE_MARGIN)
	for i in range(Catalog.SEAT_ANCHORS[kind].size()):
		var seat := Catalog.seat_position_for(kind, i, furniture, rotated, id)
		var approach := Catalog.approach_position_for(kind, i, furniture, rotated, id)
		seats.append(seat)
		approaches.append(approach)
		circulation = circulation.merge(Rect2(seat, Vector2.ZERO).grow(CasinoTuning.ASSET_NAV_RADIUS))
		circulation = circulation.merge(Rect2(approach, Vector2.ZERO).grow(CasinoTuning.ASSET_PLAYER_AISLE_RADIUS))
	for i in range(Catalog.DEALER_ANCHORS.get(kind, []).size()):
		var dealer := Catalog.dealer_position_for(kind, i, furniture, rotated, id)
		var approach := Catalog.dealer_approach_for(kind, i, furniture, rotated, id)
		dealers.append(dealer)
		dealer_approaches.append(approach)
		circulation = circulation.merge(Rect2(dealer, Vector2.ZERO).grow(CasinoTuning.ASSET_NAV_RADIUS))
		circulation = circulation.merge(Rect2(approach, Vector2.ZERO).grow(CasinoTuning.ASSET_DEALER_AISLE_RADIUS))
	var collision := circulation.merge(art)
	return {"id": id, "kind": kind, "rotated": rotated, "furniture": furniture, "art": art, "seats": seats, "approaches": approaches, "dealers": dealers, "dealer_approaches": dealer_approaches, "circulation": circulation, "collision": collision}

static func for_table(table: Dictionary) -> Dictionary:
	return geometry(str(table.kind), Vector2(table.x, table.y), bool(table.rotated), int(table.id))

static func navigation(chunks: Dictionary, assets: Array) -> AStarGrid2D:
	return navigation_in(Property.walking(chunks), assets)

static func navigation_in(area: Rect2, assets: Array) -> AStarGrid2D:
	var grid := AStarGrid2D.new()
	var area_first := Vector2i(ceili(area.position.x / CasinoTuning.FLOOR_NAV_CELL), ceili(area.position.y / CasinoTuning.FLOOR_NAV_CELL))
	var area_last := Vector2i(floori(area.end.x / CasinoTuning.FLOOR_NAV_CELL), floori(area.end.y / CasinoTuning.FLOOR_NAV_CELL))
	grid.region = Rect2i(area_first, area_last - area_first + Vector2i.ONE)
	grid.cell_size = Vector2.ONE * CasinoTuning.FLOOR_NAV_CELL
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_MANHATTAN
	grid.jumping_enabled = true
	grid.update()
	for asset in assets:
		var rect: Rect2 = asset.furniture.grow(CasinoTuning.ASSET_NAV_RADIUS)
		var cell: float = CasinoTuning.FLOOR_NAV_CELL
		var first := Vector2i(ceili(rect.position.x / cell), ceili(rect.position.y / cell))
		var last := Vector2i(floori(rect.end.x / cell), floori(rect.end.y / cell))
		for x in range(first.x, last.x + 1):
			for y in range(first.y, last.y + 1):
				var point := Vector2i(x, y)
				if grid.is_in_boundsv(point): grid.set_point_solid(point)
	return grid

static func cell_at(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / CasinoTuning.FLOOR_NAV_CELL), roundi(point.y / CasinoTuning.FLOOR_NAV_CELL))

static func connected_cells(grid: AStarGrid2D, entry_point: Vector2 = CasinoTuning.ENTRY) -> PackedByteArray:
	# One flood fill verifies all guest/dealer approaches, including existing assets.
	# Exact same solids, cell rounding and four-way movement as gameplay navigation.
	var region := grid.region
	var connected := PackedByteArray()
	connected.resize(region.size.x * region.size.y)
	var entry := cell_at(entry_point)
	if not grid.is_in_boundsv(entry) or grid.is_point_solid(entry): return connected
	var width := region.size.x
	var first := (entry.y - region.position.y) * width + entry.x - region.position.x
	var queue := PackedInt32Array([first])
	connected[first] = 1
	var cursor := 0
	while cursor < queue.size():
		var offset := queue[cursor]
		cursor += 1
		var local := Vector2i(offset % width, offset / width)
		for direction in DIRECTIONS:
			var next: Vector2i = local + direction
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= region.size.y: continue
			var index := next.y * width + next.x
			if connected[index] or grid.is_point_solid(next + region.position): continue
			connected[index] = 1
			queue.append(index)
	return connected

static func error(errors: Array, message: String, position: Vector2, id: int = -1) -> void:
	errors.append({"message": message, "position": position, "asset_id": id})

static func validate(chunks: Dictionary, assets: Array, extra_access: PackedVector2Array = PackedVector2Array()) -> Dictionary:
	var errors: Array = []
	var walk := Property.walking(chunks)
	for asset in assets:
		if not Property.placement(str(asset.kind), chunks).encloses(asset.furniture):
			error(errors, "Furniture outside build area", asset.furniture.get_center(), asset.id)
		if not walk.encloses(asset.collision):
			error(errors, "Required clearance crosses walkable edge", asset.collision.get_center(), asset.id)
		if asset.furniture.merge(asset.art).intersects(Property.entrance_clearance(chunks)):
			error(errors, "Furniture/art blocks the entrance", asset.furniture.get_center(), asset.id)
		for group in ["seats", "approaches", "dealers", "dealer_approaches"]:
			for point in asset[group]:
				if not walk.has_point(point): error(errors, "%s outside walkable floor" % group, point, asset.id)
	for i in range(assets.size()):
		var a: Dictionary = assets[i]
		for j in range(i):
			var b: Dictionary = assets[j]
			# Shared aisles are allowed. Furniture/art cannot consume either asset's
			# required interaction clearance, and the minimum physical aisle stays.
			if a.furniture.grow(CasinoTuning.ASSET_AISLE_CLEARANCE).intersects(b.furniture) or a.collision.intersects(b.furniture.merge(b.art)) or b.collision.intersects(a.furniture.merge(a.art)):
				error(errors, "Asset #%d blocks clearance for #%d" % [b.id, a.id], a.furniture.get_center(), a.id)
	if errors.is_empty():
		var grid := navigation(chunks, assets)
		var connected := connected_cells(grid, Property.entry(chunks))
		for asset in assets:
			for group in ["approaches", "dealer_approaches"]:
				for i in range(asset[group].size()):
					var point: Vector2 = asset[group][i]
					if not reachable(grid, connected, point):
						error(errors, "Asset #%d %s %d cannot reach entrance" % [asset.id, group, i + 1], point, asset.id)
		for point in extra_access:
			if not walk.has_point(point) or not reachable(grid, connected, point):
				error(errors, "Required floor interaction is blocked", point)
	return {"valid": errors.is_empty(), "errors": errors, "walk": walk}

static func reachable(grid: AStarGrid2D, connected: PackedByteArray, point: Vector2) -> bool:
	var at := cell_at(point)
	if not grid.is_in_boundsv(at) or grid.is_point_solid(at): return false
	var local := at - grid.region.position
	return connected[local.y * grid.region.size.x + local.x] != 0

static func route_grid(request: Dictionary, grid: AStarGrid2D) -> void:
	var origin := cell_at(Vector2(request.x, request.y)).clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	var destination := cell_at(Vector2(request.tx, request.ty)).clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	var path: Array = []
	if not grid.is_point_solid(origin) and not grid.is_point_solid(destination):
		for at in grid.get_point_path(origin, destination): path.append([at.x, at.y])
	if not path.is_empty(): path.append([request.tx, request.ty])
	request.path = path
