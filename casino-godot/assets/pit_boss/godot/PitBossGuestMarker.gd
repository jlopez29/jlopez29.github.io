extends Control
class_name PitBossGuestMarker

@export var body_color: Color = Color("#F4E7C8")
@export var ring_color: Color = Color.TRANSPARENT
@export var marker_radius := 10.0
@export var ring_width := 2.0

func _ready() -> void:
    custom_minimum_size = Vector2(marker_radius * 3.0, marker_radius * 3.0)
    queue_redraw()

func _draw() -> void:
    var c := size * 0.5
    if ring_color.a > 0.0:
        draw_arc(c, marker_radius + 4.0, 0.0, TAU, 48, ring_color, ring_width, true)
    draw_circle(c, marker_radius, body_color)
    draw_arc(c, marker_radius, 0.0, TAU, 48, Color(1,1,1,0.75), 1.5, true)
