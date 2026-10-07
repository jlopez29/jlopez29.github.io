extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
var role := ""
@onready var body: Sprite2D = $Body
@onready var ring: Sprite2D = $Ring
@onready var icon: Sprite2D = $Role
func _draw() -> void:
	draw_circle(Vector2(0, 1), 7, Color(0.025, 0.03, 0.03, 0.9))
func update_view(employee: Dictionary, at: Vector2, zoom: float) -> void:
	position = at
	scale = Vector2.ONE / maxf(0.01, zoom)
	if role == str(employee.role): return
	role = str(employee.role)
	body.texture = Art.texture("guests/base/guest_cyan.svg")
	body.scale = Vector2.ONE * 20 / body.texture.get_width()
	ring.texture = Art.texture("guests/rings/ring_staff.svg")
	ring.scale = Vector2.ONE * 21 / ring.texture.get_width()
	icon.texture = Art.texture("icons/gameplay/drink.svg" if role == "Service" else "icons/gameplay/spade.svg")
	icon.scale = Vector2.ONE * 8 / icon.texture.get_width()
