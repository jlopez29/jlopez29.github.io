extends RefCounted
const Art = preload("res://scripts/pit_boss_theme.gd")
static var furniture := {}

# Coordinates are normalized within the cropped artwork, before rotation.
# Seat order follows guest.seat; approach points are presentation metadata only.
const SEAT_ANCHORS := {
	"slots": [Vector2(0.50, 0.72)],
	"blackjack": [Vector2(0.25, 0.19), Vector2(0.50, 0.15), Vector2(0.75, 0.19), Vector2(0.94, 0.46), Vector2(0.85, 0.72), Vector2(0.50, 0.90), Vector2(0.15, 0.72), Vector2(0.06, 0.46)],
	"roulette": [Vector2(0.23, 0.20), Vector2(0.43, 0.10), Vector2(0.65, 0.10), Vector2(0.87, 0.19), Vector2(0.94, 0.57), Vector2(0.77, 0.89), Vector2(0.47, 0.96), Vector2(0.12, 0.72)],
	"craps": [Vector2(0.24, 0.06), Vector2(0.77, 0.06), Vector2(0.96, 0.32), Vector2(0.96, 0.68), Vector2(0.77, 0.90), Vector2(0.49, 0.90), Vector2(0.20, 0.90), Vector2(0.04, 0.50)],
	"holdem": [Vector2(0.20, 0.18), Vector2(0.46, 0.08), Vector2(0.74, 0.17), Vector2(0.94, 0.43), Vector2(0.85, 0.73), Vector2(0.60, 0.92), Vector2(0.31, 0.92), Vector2(0.09, 0.68)],
}

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
	var path := path_for(kind, id)
	if not furniture.has(path):
		var source := Art.texture(path)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		# Ignore extraction-edge lettering/stray pixels, retaining the supplied art.
		var inset := Vector2(2, 8) if kind != "slots" else Vector2(1, 3)
		atlas.region = Rect2(inset, source.get_size() - inset * 2 - Vector2(0, 8 if kind == "slots" else 0))
		atlas.filter_clip = true
		furniture[path] = atlas
	return furniture[path]
