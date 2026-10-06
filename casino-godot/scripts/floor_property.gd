extends RefCounted
# A rectangular property represented by counts of full-edge columns/rows.
# Shared by runtime geometry, previews and strict current-schema validation.

static func rectangle(chunks: Dictionary) -> Rect2:
	var base: Rect2 = CasinoTuning.STARTER_PROPERTY
	return Rect2(base.position - Vector2(int(chunks.left) * CasinoTuning.FLOOR_CHUNK_WIDTH, 0),
		base.size + Vector2((int(chunks.left) + int(chunks.right)) * CasinoTuning.FLOOR_CHUNK_WIDTH, int(chunks.bottom) * CasinoTuning.FLOOR_CHUNK_HEIGHT))

static func count(chunks: Dictionary) -> int:
	return int(chunks.left) + int(chunks.right) + int(chunks.bottom)

static func placement(kind: String, chunks: Dictionary) -> Rect2:
	var room := rectangle(chunks)
	var inset: Vector4 = CasinoTuning.FLOOR_SLOT_INSETS if kind == "slots" else CasinoTuning.FLOOR_TABLE_INSETS
	return Rect2(room.position + Vector2(inset.x, inset.y), room.size - Vector2(inset.x + inset.z, inset.y + inset.w))

static func walking(chunks: Dictionary) -> Rect2:
	var room := rectangle(chunks)
	var inset: Vector4 = CasinoTuning.FLOOR_WALK_INSETS
	return Rect2(room.position + Vector2(inset.x, inset.y), room.size - Vector2(inset.x + inset.z, inset.y + inset.w))

static func nav_region(chunks: Dictionary) -> Rect2i:
	var area := walking(chunks)
	var cell: float = CasinoTuning.FLOOR_NAV_CELL
	var first := Vector2i(ceili(area.position.x / cell), ceili(area.position.y / cell))
	var last := Vector2i(floori(area.end.x / cell), floori(area.end.y / cell))
	return Rect2i(first, last - first + Vector2i.ONE)

static func valid(chunks) -> bool:
	if not chunks is Dictionary or chunks.size() != 3: return false
	for direction in ["left", "right", "bottom"]:
		var value = chunks.get(direction)
		if not (value is int or value is float) or not is_finite(float(value)) or value != int(value) or value < 0 or value > CasinoTuning.FLOOR_MAX_DIRECTION_CHUNKS: return false
	var region := nav_region(chunks)
	return region.size.x * region.size.y <= CasinoTuning.FLOOR_MAX_NAV_CELLS

static func quote(chunks: Dictionary, direction: String) -> Dictionary:
	if direction not in ["left", "right", "bottom"]: return {}
	var next := chunks.duplicate()
	next[direction] += 1
	var original := rectangle(chunks)
	var result := rectangle(next)
	var added := result.get_area() - original.get_area()
	var base_area: float = CasinoTuning.STARTER_PROPERTY.get_area()
	var growth := 1.0 + count(chunks) * CasinoTuning.EXPANSION_PURCHASE_GROWTH + (original.get_area() / base_area - 1.0) * CasinoTuning.EXPANSION_AREA_GROWTH
	var price := ceilf(CasinoTuning.EXPANSION_COST * added / CasinoTuning.EXPANSION_REFERENCE_AREA * growth / CasinoTuning.EXPANSION_PRICE_STEP) * CasinoTuning.EXPANSION_PRICE_STEP
	return {"chunks": next, "rectangle": result, "added_area": added,
		"cost": price, "upkeep_added": added / 10000.0 * CasinoTuning.PROPERTY_UPKEEP_PER_10000, "allowed": valid(next)}

static func upkeep(chunks: Dictionary) -> float:
	return (rectangle(chunks).get_area() - CasinoTuning.STARTER_PROPERTY.get_area()) / 10000.0 * CasinoTuning.PROPERTY_UPKEEP_PER_10000
