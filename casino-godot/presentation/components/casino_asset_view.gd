extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
# Geometry, hit testing and artwork dimensions have separate ownership.
var simulation_bounds := Rect2()
var clickable_bounds := Rect2()
var visual_size := Vector2.ZERO
var asset_path := ""
@onready var sprite: Sprite2D = $Sprite
@onready var outline: ReferenceRect = $Outline
@onready var caption: Label = $Caption
@onready var state_label: Label = $State

func update_view(sim: CasinoSimulation, table: Dictionary, index: Dictionary, selected_id: int, compact: bool) -> void:
	simulation_bounds = sim.bounds(table)
	clickable_bounds = simulation_bounds.grow(12)
	position = simulation_bounds.get_center()
	var kind := sim.table_kind(table)
	var path := "casino/slots/slot_%02d.png" % (1 + int(table.id) % 5) if kind == "slots" else "casino/tables/" + ("ultimate_texas" if kind == "holdem" else kind) + ".png"
	if path != asset_path:
		asset_path = path
		sprite.texture = Art.texture(path)
	var extent := Vector2(simulation_bounds.size.y, simulation_bounds.size.x) if table.rotated else simulation_bounds.size
	var ratio := minf(extent.x / sprite.texture.get_width(), extent.y / sprite.texture.get_height())
	visual_size = sprite.texture.get_size() * ratio
	sprite.scale = Vector2.ONE * ratio
	sprite.rotation = PI / 2 if table.rotated else 0.0
	sprite.modulate = Color("b97979") if table.broken else Color.WHITE
	outline.position = -simulation_bounds.size / 2 - Vector2.ONE * 3
	outline.size = simulation_bounds.size + Vector2.ONE * 6
	outline.visible = selected_id == int(table.id) or bool(index.hot.get(int(table.id), false))
	outline.border_color = Art.GOLD if selected_id == int(table.id) else Color("8b5cf6")
	caption.position = -simulation_bounds.size / 2 + Vector2(0, -21)
	caption.size = Vector2(simulation_bounds.size.x, 20)
	caption.text = str(table.id) if compact else "%s %02d" % [sim.slot_profile(table).short_name if kind == "slots" else CasinoGames.NAMES[kind], table.id]
	state_label.position = Vector2(-simulation_bounds.size.x / 2, simulation_bounds.size.y / 2 + 2)
	state_label.text = "REPAIR" if table.broken else str(index.status.get(int(table.id), ""))
	state_label.visible = not compact or table.broken
