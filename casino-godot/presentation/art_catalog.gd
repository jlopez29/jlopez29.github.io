extends RefCounted
const Art = preload("res://scripts/pit_boss_theme.gd")
static var furniture := {}

# Coordinates are normalized within the cropped artwork, before rotation.
# Seat order follows guest.seat; approach points are presentation metadata only.
# Transparent extraction margins are excluded; the canonical PNGs remain untouched.
const CONTENT_REGIONS := {
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
# Art anchors describe the public/customer side, not additional gameplay locations.
const AMENITY_WIDTHS := {"bar": 220.0, "cashier_cage": 170.0}
const AMENITY_CUSTOMER_ANCHORS := {"bar": Vector2(0.53, 0.87), "cashier_cage": Vector2(0.5, 1.0)}

static func local_seat_anchors(kind: String, artwork_size: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for anchor in SEAT_ANCHORS.get(kind, []):
		result.append((anchor - Vector2(0.5, 0.5)) * artwork_size)
	return result

static func local_approach_anchors(kind: String, seats: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for seat in seats:
		# Stand beyond the chair/rail, away from the artwork center.
		var direction := Vector2.DOWN if kind == "slots" else seat.normalized()
		result.append(seat + direction * 24)
	return result

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
	return minf(footprint.x / texture.get_width(), footprint.y / texture.get_height()) * 1.08

static func amenity_texture(kind: String) -> Texture2D:
	return cropped_texture("casino/amenities/" + kind + ".png")

static func amenity_visual_bounds(kind: String, customer_point: Vector2) -> Rect2:
	var texture := amenity_texture(kind)
	var extent := texture.get_size() * (float(AMENITY_WIDTHS[kind]) / texture.get_width())
	return Rect2(customer_point - AMENITY_CUSTOMER_ANCHORS[kind] * extent, extent)
