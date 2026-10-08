extends Control
## One retained viewport overlay, outside felt/ScrollContainer clipping.
const Chips = preload("res://presentation/play/chip_stack.gd")
var amount := 0.0
func _init() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	hide()
func update_chip(at: Vector2, value: float) -> void:
	position = at
	if amount != value:
		amount = value
		queue_redraw()
	show()
func _draw() -> void:
	Chips.draw_stack(self, Vector2.ZERO, amount, 24, Chips.seat_color(-1))
