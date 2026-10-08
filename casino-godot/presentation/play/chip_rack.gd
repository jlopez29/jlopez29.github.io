extends Control
## One viewport rack; selecting a chip never submits a wager.
signal selected(amount: float)
signal drag_requested
var press_origin := Vector2.ZERO
var held := false
var dragging := false
const Chips = preload("res://presentation/play/chip_stack.gd")
var denominations: Array = [1, 5, 25, 100, 500, 1000]
var amount := 25.0
var wallet := 0.0
var locked := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(denominations.size() * 60, 64)

func configure(fine: bool) -> void:
	denominations = [0.01, 0.05, 0.10, 0.25, 0.50, 1, 5, 25, 100, 500, 1000] if fine else [1, 5, 25, 100, 500, 1000]
	custom_minimum_size = Vector2(denominations.size() * 60, 64)
	queue_redraw()

func choose(at: Vector2) -> void:
	var index := int(at.x / 60)
	if index < 0 or index >= denominations.size() or locked: return
	var value := float(denominations[index])
	if value > wallet: return
	amount = value
	held = true
	dragging = false
	press_origin = get_global_transform_with_canvas() * at
	selected.emit(value)
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		choose(event.position)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): held = false; return
	if event is InputEventScreenTouch and event.index == 0:
		if event.pressed and get_global_rect().has_point(event.position):
			choose(get_global_transform_with_canvas().affine_inverse() * event.position)
			get_viewport().set_input_as_handled()
		elif not event.pressed: held = false
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		held = false
	elif (event is InputEventMouseMotion or (event is InputEventScreenDrag and event.index == 0)) and held and not dragging:
		# Horizontal motion remains rack scrolling; leaving the rack drags a chip.
		if absf(event.position.y - press_origin.y) > 18:
			dragging = true
			drag_requested.emit()

func _draw() -> void:
	for i in range(denominations.size()):
		var value := float(denominations[i])
		var at := Vector2(i * 60 + 30, 25)
		Chips.draw_stack(self, at, value, 19, Color.TRANSPARENT, false)
		if is_equal_approx(value, amount): draw_arc(at, 23, 0, TAU, 40, Color("ffe397"), 2)
		if locked or value > wallet: draw_circle(at, 22, Color(0, 0, 0, 0.6))
		var label := Chips.Money.cash(value, 2 if value < 1 else 0)
		var font := ThemeDB.fallback_font
		var width := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
		draw_string(font, Vector2(at.x - width / 2, 61), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("fff3d1"))
