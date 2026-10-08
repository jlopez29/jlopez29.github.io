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
var repair_needed := false
var repair_pulse := 0.0
var selection_skin: StyleBoxFlat
@onready var sprite: Sprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var outline: Panel = $Outline

func _ready() -> void:
	selection_skin = Art.box(Color(0.83, 0.69, 0.22, 0.025), Art.GOLD, 0)
	selection_skin.set_corner_radius_all(8)
	selection_skin.shadow_color = Color(0.83, 0.69, 0.22, 0.17)
	selection_skin.shadow_size = 10
	outline.add_theme_stylebox_override("panel", selection_skin)
	set_process(false)

func update_view(sim, table: Dictionary, index: Dictionary, selected_id: int, compact: bool) -> void:
	simulation_bounds = sim.bounds(table)
	clickable_bounds = simulation_bounds.grow(12)
	position = simulation_bounds.get_center()
	var operating: bool = index.operating.get(int(table.id), false)
	var hot: bool = index.hot.get(int(table.id), false)
	var next := [table.kind, simulation_bounds, table.rotated, table.broken, selected_id == int(table.id), operating, hot, compact, table.slot_profile]
	if signature == next: return
	signature = next
	repair_needed = bool(table.broken)
	set_process(repair_needed)
	queue_redraw()
	last_zoom = -1.0
	var kind: String = sim.table_kind(table)
	var path := Catalog.path_for(kind, int(table.id))
	if path != asset_path:
		asset_path = path
		sprite.texture = Catalog.texture_for(kind, int(table.id))
		shadow.texture = sprite.texture
	var extent := Vector2(simulation_bounds.size.y, simulation_bounds.size.x) if table.rotated else simulation_bounds.size
	var ratio := Catalog.visual_scale(sprite.texture, extent)
	visual_size = sprite.texture.get_size() * ratio
	sprite.scale = Vector2.ONE * ratio
	sprite.rotation = PI / 2 if table.rotated else 0.0
	seat_anchors.clear()
	approach_anchors.clear()
	for i in range(Catalog.SEAT_ANCHORS.get(kind, []).size()):
		seat_anchors.append(Catalog.seat_position_for(kind, i, simulation_bounds, table.rotated, int(table.id)) - position)
		approach_anchors.append(Catalog.approach_position_for(kind, i, simulation_bounds, table.rotated, int(table.id)) - position)
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
	$MachineLight.visible = kind == "slots" and operating and not table.broken
	$MachineLight.position = Vector2(0, -visual_size.y * 0.28).rotated(sprite.rotation)
	$MachineLight.rotation = sprite.rotation

func set_view_zoom(value: float) -> void:
	if is_equal_approx(last_zoom, value): return
	last_zoom = value
	if repair_needed: queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	repair_pulse += delta
	queue_redraw()

func _draw() -> void:
	if not repair_needed: return
	var pulse := (sin(repair_pulse * 3.5) + 1) / 2
	var radius := simulation_bounds.size.length() / 2 + 5 + pulse * 3
	var red := Color("ef4444")
	draw_circle(Vector2.ZERO, radius, Color(red, 0.025 + pulse * 0.035))
	draw_arc(Vector2.ZERO, radius, 0, TAU, 64, Color(red, 0.4 + pulse * 0.5), 2.5 / maxf(0.1, last_zoom), true)
