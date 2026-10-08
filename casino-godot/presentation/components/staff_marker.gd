extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
var role := ""
var delivering := false
var walk_time := 0.0
var moving := false
@onready var body: Sprite2D = $Body
@onready var ring: Sprite2D = $Ring
@onready var icon: Sprite2D = $Role

func _ready() -> void:
	set_process(false)

func _draw() -> void:
	var owner := role == "Owner"
	draw_circle(Vector2(0, 1), 15 if owner else 14, Color(0.025, 0.03, 0.03, 0.9))
	if owner:
		draw_circle(Vector2.ZERO, 18, Color(0.63, 0.43, 0.84, 0.12))
		draw_arc(Vector2.ZERO, 15.5, 0, TAU, 32, Color("f4d06f"), 2, true)

func update_view(employee: Dictionary, at: Vector2, zoom: float) -> void:
	moving = position.distance_squared_to(at) > 0.001
	position = at
	var next_role := str(employee.role)
	var next_delivery := next_role == "Service" and str(employee.get("service_state", "")) == "Delivering"
	if next_delivery:
		moving = at.distance_squared_to(Vector2(float(employee.get("tx", at.x)), float(employee.get("ty", at.y)))) > 4
	var base_size := CasinoTuning.PLAYER_BASE_SCREEN_SIZE if next_role == "Owner" else CasinoTuning.STAFF_BASE_SCREEN_SIZE
	scale = Vector2.ONE * CasinoTuning.character_scale(zoom, base_size)
	var role_changed := role != next_role
	if role_changed:
		role = next_role
		body.texture = Art.texture("guests/base/guest_" + ("purple" if role == "Owner" else "cyan" if role == "Service" else "green") + ".svg")
		body.scale = Vector2.ONE * base_size / CasinoTuning.CHARACTER_TEXTURE_DIAMETER / body.texture.get_width()
		body.modulate = Color("7b53af") if role == "Owner" else Color("e8ad58") if role == "Tech" else Color.WHITE if role == "Service" else Color("37805c")
		ring.texture = Art.texture("guests/rings/ring_staff.svg")
		ring.scale = Vector2.ONE * (base_size + 6) / ring.texture.get_width()
		icon.texture = Art.texture("icons/status/vip.svg" if role == "Owner" else "icons/gameplay/drink.svg" if role == "Service" else "icons/gameplay/wrench.svg" if role == "Tech" else "icons/gameplay/spade.svg")
		queue_redraw()
	if role_changed or delivering != next_delivery:
		delivering = next_delivery
		icon.scale = Vector2.ONE * (12 if delivering or role == "Owner" else 10) / icon.texture.get_width()
		icon.modulate.a = 1.0 if delivering or role != "Service" else 0.75
		icon.position = Vector2(12, -4) if delivering else Vector2(0, -14)
	set_process(delivering and moving)
	if not delivering or not moving:
		body.position.y = 0
		icon.position = Vector2(12, -4) if delivering else Vector2(0, -14)

func _process(delta: float) -> void:
	walk_time += delta
	var bob := sin(walk_time * 9) * 1.2
	body.position.y = bob
	icon.position = Vector2(12, -4 + bob)
