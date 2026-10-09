extends RefCounted
const Property = preload("res://scripts/floor_property.gd")
const Art = preload("res://scripts/pit_boss_theme.gd")
static var furniture := {}

# Coordinates are normalized within the cropped artwork, before rotation.
# Seat order follows guest.seat; simulation and presentation share this geometry.
# Transparent extraction margins are excluded; the canonical PNGs remain untouched.
const CONTENT_REGIONS := {
	"casino/slots/slot_01.png": Rect2(1, 3, 78, 286),
	"casino/slots/slot_02.png": Rect2(1, 3, 78, 286),
	"casino/slots/slot_03.png": Rect2(1, 3, 76, 286),
	"casino/slots/slot_04.png": Rect2(1, 3, 74, 284),
	"casino/slots/slot_05.png": Rect2(1, 3, 74, 282),
	"casino/tables/blackjack.png": Rect2(20, 126, 1409, 837),
	"casino/tables/roulette.png": Rect2(16, 170, 1419, 723),
	"casino/tables/craps.png": Rect2(20, 109, 1631, 741),
	"casino/tables/ultimate_texas.png": Rect2(26, 59, 1395, 951),
	"casino/amenities/bar.png": Rect2(24, 108, 1625, 677),
	"casino/amenities/cashier_cage.png": Rect2(0, 53, 1670, 816),
}
const SEAT_ANCHORS := {
	"slots": [Vector2(0.50, 0.72)],
	# Five chairs plus three positions along the player rail; never the dealer side.
	"blackjack": [Vector2(0.08, 0.69), Vector2(0.17, 0.70), Vector2(0.275, 0.83), Vector2(0.39, 0.79), Vector2(0.508, 0.90), Vector2(0.62, 0.79), Vector2(0.746, 0.83), Vector2(0.936, 0.69)],
	"roulette": [Vector2(0.437, 0.086), Vector2(0.581, 0.086), Vector2(0.726, 0.086), Vector2(0.872, 0.086), Vector2(0.872, 0.913), Vector2(0.726, 0.913), Vector2(0.581, 0.913), Vector2(0.437, 0.913)],
	"craps": [Vector2(0.16, 0.095), Vector2(0.29, 0.055), Vector2(0.71, 0.055), Vector2(0.87, 0.095), Vector2(0.83, 0.93), Vector2(0.65, 0.95), Vector2(0.43, 0.95), Vector2(0.22, 0.93)],
	# Seven red player chairs; the black dealer chair is deliberately excluded.
	"holdem": [Vector2(0.195, 0.148), Vector2(0.803, 0.148), Vector2(0.956, 0.516), Vector2(0.763, 0.84), Vector2(0.505, 0.921), Vector2(0.211, 0.84), Vector2(0.049, 0.516), Vector2(0.37, 0.87)],
}
# Dealer positions match the chip rail / black dealer chair, separate from players.
const DEALER_ANCHORS := {
	"blackjack": [Vector2(0.50, 0.03)],
	"roulette": [Vector2(0.20, 0.18)],
	"craps": [Vector2(0.45, 0.05), Vector2(0.60, 0.05)],
	"holdem": [Vector2(0.50, 0.07)],
}

# Art anchors describe the public/customer side, not additional gameplay locations.
const AMENITY_WIDTHS := {"bar": Property.BAR_WIDTH, "cashier_cage": Property.CAGE_WIDTH}
const AMENITY_CUSTOMER_ANCHORS := {"bar": Property.BAR_ANCHOR, "cashier_cage": Property.CAGE_ANCHOR}

static func local_seat_anchors(kind: String, artwork_size: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for anchor in SEAT_ANCHORS.get(kind, []):
		result.append((anchor - Vector2(0.5, 0.5)) * artwork_size)
	return result

static func visual_size_for(kind: String, bounds: Rect2, rotated: bool, id: int = 0) -> Vector2:
	var artwork_size: Vector2 = CONTENT_REGIONS[path_for(kind, id)].size
	var footprint := Vector2(bounds.size.y, bounds.size.x) if rotated else bounds.size
	return artwork_size * visual_scale_for(artwork_size, footprint)

static func seat_position_for(kind: String, seat_index: int, bounds: Rect2, rotated: bool, id: int = 0) -> Vector2:
	var anchors: Array = SEAT_ANCHORS.get(kind, [])
	if seat_index < 0 or seat_index >= anchors.size(): return bounds.get_center()
	var local: Vector2 = (anchors[seat_index] - Vector2(0.5, 0.5)) * visual_size_for(kind, bounds, rotated, id)
	return bounds.get_center() + local.rotated(PI / 2 if rotated else 0.0)

static func art_bounds_for(kind: String, bounds: Rect2, rotated: bool, id: int = 0) -> Rect2:
	var size := visual_size_for(kind, bounds, rotated, id)
	if rotated: size = Vector2(size.y, size.x)
	return Rect2(bounds.get_center() - size / 2, size)

static func dealer_position_for(kind: String, index: int, bounds: Rect2, rotated: bool, id: int = 0) -> Vector2:
	var anchors: Array = DEALER_ANCHORS.get(kind, [])
	if index < 0 or index >= anchors.size(): return bounds.get_center()
	var local: Vector2 = (anchors[index] - Vector2(0.5, 0.5)) * visual_size_for(kind, bounds, rotated, id)
	return bounds.get_center() + local.rotated(PI / 2 if rotated else 0.0)

static func interaction_approach_for(seat: Vector2, bounds: Rect2, direction: Vector2, minimum_distance: float = 24.0) -> Vector2:
	# Only the controlled final entry crosses the footprint to the authored chair.
	var clearance := bounds.grow(CasinoTuning.ASSET_NAV_RADIUS + CasinoTuning.FLOOR_NAV_CELL / 2 + 1)
	var exit_distance := INF
	if not is_zero_approx(direction.x):
		exit_distance = minf(exit_distance, ((clearance.end.x if direction.x > 0 else clearance.position.x) - seat.x) / direction.x)
	if not is_zero_approx(direction.y):
		exit_distance = minf(exit_distance, ((clearance.end.y if direction.y > 0 else clearance.position.y) - seat.y) / direction.y)
	return seat + direction * maxf(minimum_distance, exit_distance)

static func approach_position_for(kind: String, seat_index: int, bounds: Rect2, rotated: bool, id: int = 0) -> Vector2:
	var seat := seat_position_for(kind, seat_index, bounds, rotated, id)
	var direction := Vector2.DOWN.rotated(PI / 2 if rotated else 0.0) if kind == "slots" else (seat - bounds.get_center()).normalized()
	return interaction_approach_for(seat, bounds, direction)

static func dealer_approach_for(kind: String, index: int, bounds: Rect2, rotated: bool, id: int = 0) -> Vector2:
	var seat := dealer_position_for(kind, index, bounds, rotated, id)
	return interaction_approach_for(seat, bounds, (seat - bounds.get_center()).normalized(), CasinoTuning.ASSET_NAV_RADIUS)

static func path_for(kind: String, id: int = 0) -> String:
	return "casino/slots/slot_%02d.png" % (1 + id % 5) if kind == "slots" else "casino/tables/" + ("ultimate_texas" if kind == "holdem" else kind) + ".png"

static func texture_for(kind: String, id: int = 0) -> Texture2D:
	return cropped_texture(path_for(kind, id))

static func cropped_texture(path: String) -> Texture2D:
	if not furniture.has(path):
		var source := Art.texture(path)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		var inset := Vector2(1, 3)
		var fallback := Rect2(inset, source.get_size() - inset * 2 - Vector2(0, 8))
		atlas.region = CONTENT_REGIONS.get(path, fallback)
		atlas.filter_clip = true
		furniture[path] = atlas
	return furniture[path]

static func visual_scale(texture: Texture2D, footprint: Vector2) -> float:
	# One scalar shared by retained furniture and the placement/move preview.
	return visual_scale_for(texture.get_size(), footprint)

static func visual_scale_for(artwork_size: Vector2, footprint: Vector2) -> float:
	return minf(footprint.x / artwork_size.x, footprint.y / artwork_size.y) * 1.08

static func amenity_texture(kind: String) -> Texture2D:
	return cropped_texture("casino/amenities/" + kind + ".png")

static func amenity_visual_bounds(kind: String, customer_point: Vector2) -> Rect2:
	var texture := amenity_texture(kind)
	var extent := texture.get_size() * (float(AMENITY_WIDTHS[kind]) / texture.get_width())
	return Rect2(customer_point - AMENITY_CUSTOMER_ANCHORS[kind] * extent, extent)
