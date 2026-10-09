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
	# Table limits come from actual rotated interaction geometry, not global insets.
	if kind != "slots": return walking(chunks)
	var inset: Vector4 = CasinoTuning.FLOOR_SLOT_INSETS
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

# Frontage stays in the starter lobby when the property grows. Existing saves
# may supply their previous frontage footprint to preserve legal layouts.
# Widths below are presentation widths.
const FRONTAGE_PADDING := 12.0
const CAGE_WIDTH := 170.0
const BAR_WIDTH := 200.0
const CAGE_ANCHOR := Vector2(0.5, 1.0)
const BAR_ANCHOR := Vector2(0.53, 0.87)

static func entry(_chunks: Dictionary, frontage: Dictionary = {}) -> Vector2:
	return Vector2(frontage_rectangle(frontage).get_center().x, CasinoTuning.ENTRY.y)

static func entrance_clearance(_chunks: Dictionary, frontage: Dictionary = {}) -> Rect2:
	var clearance := CasinoTuning.ENTRANCE_CLEARANCE
	clearance.position.x += entry(_chunks, frontage).x - CasinoTuning.ENTRY.x
	return clearance

static func cage_pickup(_chunks: Dictionary, frontage: Dictionary = {}) -> Vector2:
	return Vector2(frontage_rectangle(frontage).position.x + FRONTAGE_PADDING + CAGE_WIDTH * CAGE_ANCHOR.x, CasinoTuning.ENTRY.y)

static func bar_counter(_chunks: Dictionary, frontage: Dictionary = {}) -> Rect2:
	var counter := CasinoTuning.BAR_COUNTER
	counter.position.x = frontage_rectangle(frontage).end.x - FRONTAGE_PADDING - BAR_WIDTH + BAR_WIDTH * BAR_ANCHOR.x - CasinoTuning.BAR_GUEST_OFFSETS[2].x
	return counter

static func public_door(_chunks: Dictionary, frontage: Dictionary = {}) -> Rect2:
	# The visible 60-unit entrance and 40-unit private door form a centered
	# 108-unit group, with 8 units of empty space between the actual artworks.
	return Rect2(entry(_chunks, frontage) + Vector2(-49, -56), Vector2(50, 42))

static func private_door(_chunks: Dictionary, frontage: Dictionary = {}) -> Rect2:
	return Rect2(entry(_chunks, frontage) + Vector2(14, -56), Vector2(40, 42))

static func private_approach(_chunks: Dictionary, frontage: Dictionary = {}) -> Vector2:
	return ((private_door(_chunks, frontage).get_center() + Vector2(0, 45)) / CasinoTuning.FLOOR_NAV_CELL).round() * CasinoTuning.FLOOR_NAV_CELL

static func frontage_rectangle(frontage: Dictionary) -> Rect2:
	return CasinoTuning.STARTER_PROPERTY if frontage.is_empty() else rectangle(frontage)
