extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
const Catalog = preload("res://presentation/art_catalog.gd")
var simulation_bounds := Rect2()
var clickable_bounds := Rect2()
var visual_size := Vector2.ZERO
var seat_anchors := PackedVector2Array()
var approach_anchors := PackedVector2Array()
var asset_path := ""
var signature: Array = []
var last_zoom := -1.0
var selection_skin: StyleBoxFlat
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var outline: Panel = $Outline
@onready var caption: Label = $Caption
@onready var state_label: Label = $State

func _ready() -> void:
	selection_skin = Art.box(Color(0.83, 0.69, 0.22, 0.025), Art.GOLD, 0)
	selection_skin.set_corner_radius_all(8)
	selection_skin.shadow_color = Color(0.83, 0.69, 0.22, 0.17)
	selection_skin.shadow_size = 10
	outline.add_theme_stylebox_override("panel", selection_skin)

func update_view(sim: CasinoSimulation, table: Dictionary, index: Dictionary, selected_id: int, compact: bool) -> void:
	simulation_bounds = sim.bounds(table)
	clickable_bounds = simulation_bounds.grow(12)
	position = simulation_bounds.get_center()
	var operating: bool = index.operating.get(int(table.id), false)
	var hot: bool = index.hot.get(int(table.id), false)
	var next := [table.kind, simulation_bounds, table.rotated, table.broken, selected_id == int(table.id), operating, hot, compact, table.slot_profile]
	if signature == next: return
	signature = next
	last_zoom = -1.0
	var kind := sim.table_kind(table)
	var path := Catalog.path_for(kind, int(table.id))
	if path != asset_path:
		asset_path = path
		sprite.texture = Catalog.texture_for(kind, int(table.id))
		shadow.texture = sprite.texture
	var extent := Vector2(simulation_bounds.size.y, simulation_bounds.size.x) if table.rotated else simulation_bounds.size
	var ratio := minf(extent.x / sprite.texture.get_width(), extent.y / sprite.texture.get_height()) * 1.08
	visual_size = sprite.texture.get_size() * ratio
	sprite.scale = Vector2.ONE * ratio
	sprite.rotation = PI / 2 if table.rotated else 0.0
	seat_anchors = Catalog.local_seat_anchors(kind, visual_size)
	approach_anchors = Catalog.local_approach_anchors(kind, seat_anchors)
	for i in range(seat_anchors.size()):
		seat_anchors[i] = seat_anchors[i].rotated(sprite.rotation)
		approach_anchors[i] = approach_anchors[i].rotated(sprite.rotation)
	sprite.modulate = Color("b97979") if table.broken else Color.WHITE
	shadow.scale = sprite.scale
	shadow.rotation = sprite.rotation
	outline.position = -simulation_bounds.size / 2 - Vector2.ONE * 3
	outline.size = simulation_bounds.size + Vector2.ONE * 6
	outline.visible = selected_id == int(table.id) or hot
	var is_selected := selected_id == int(table.id)
	selection_skin.border_color = Color(Art.GOLD, 0.75) if is_selected else Color.TRANSPARENT
	selection_skin.bg_color = Color(0.83, 0.69, 0.22, 0.025 if is_selected else 0)
	selection_skin.shadow_color = Color(0.83, 0.69, 0.22, 0.13 if is_selected else 0.055)
	var premium: bool = kind == "slots" and int(sim.slot_profile(table).prestige) >= 4
	$Rug.visible = premium
	$Rug.texture = Art.texture("flooring/vip_carpet.png" if premium else "flooring/emerald_carpet.png")
	$Rug.modulate = Color(0.40, 0.38, 0.35, 1) if premium else Color(0.30, 0.32, 0.29, 1)
	$Rug.position = -simulation_bounds.size / 2 - Vector2.ONE * 8
	$Rug.scale = Vector2.ONE * 0.25
	$Rug.size = (simulation_bounds.size + Vector2.ONE * 16) / 0.25
	$TableRug.visible = kind != "slots"
	$RugEdge.visible = kind != "slots"
	if kind != "slots":
		var points := PackedVector2Array()
		for i in range(40):
			var angle := TAU * i / 40
			points.append((Vector2(cos(angle), sin(angle)) * (visual_size / 2 + Vector2(9, 9))).rotated(sprite.rotation))
		$TableRug.polygon = points
		points.append(points[0])
		$RugEdge.points = points
	caption.text = "%s %02d" % [sim.slot_profile(table).short_name if kind == "slots" else str(CasinoGames.NAMES[kind]).replace("’", "'"), table.id]
	caption.visible = is_selected or table.broken
	state_label.text = "Repair needed" if table.broken else "Open" if operating else "Closed" if not sim.opened else "Staffing paused" if not table.staff_enabled else "Needs coverage"
	state_label.visible = table.broken or selected_id == int(table.id)
	state_label.modulate = Color("ff9486") if table.broken else Color("a6c9a6") if operating else Art.MUTED
	$MachineLight.visible = kind == "slots" and operating and not table.broken
	$MachineLight.position = Vector2(0, -visual_size.y * 0.28).rotated(sprite.rotation)
	$MachineLight.rotation = sprite.rotation

func set_view_zoom(value: float) -> void:
	if is_equal_approx(last_zoom, value): return
	last_zoom = value
	# Names/status use fixed screen pixels; furniture remains in world units.
	caption.scale = Vector2.ONE / value
	state_label.scale = Vector2.ONE / value
	caption.position = Vector2(-simulation_bounds.size.x / 2, -simulation_bounds.size.y / 2 - 22 / value)
	state_label.position = Vector2(-simulation_bounds.size.x / 2, simulation_bounds.size.y / 2 + 4 / value)
	caption.size = Vector2(maxf(75, simulation_bounds.size.x * value), 20)
	caption.clip_text = true
