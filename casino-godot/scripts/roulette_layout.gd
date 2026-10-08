extends Control
# Geometry is shared by rendering and hit testing, including inside-bet seams.
signal wager_requested(name: String, amount: float)
signal denomination_changed(amount: float)
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const Games = preload("res://scripts/casino_games.gd")
const Chips = preload("res://presentation/play/chip_stack.gd")
const GUEST_STACK_POSITIONS := [Vector2(0,0), Vector2(0.5,0), Vector2(1,0), Vector2(1,0.5), Vector2(1,1), Vector2(0.5,1), Vector2(0,1)]
var context: PitBossGameContext
var pressed_on_felt := false
var seated_players: Array = []
var guest_wagers: Array = []
var settled := false
var bets := {}
var selected := 10.0
var minimum := 10.0
var locked := false
var cells := {}
var spots := {}
var tray := {}
var dragging := false
var pointer := Vector2.ZERO
var hover := ""
var font: Font
var portrait := false
var vertical_layout := true
var wallet := 0.0
var winning_number := -1
var hide_tray := false
var factor := 1.0
var stretch := Vector2.ONE
var available_height := 0.0
var press_origin := Vector2.ZERO
var rack_drag := false

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(rebuild)
	rebuild()

func mapped(r: Rect2) -> Rect2:
	if portrait: return Rect2(Vector2(r.position.y, r.position.x) * stretch + Vector2(12,40), Vector2(r.size.y, r.size.x) * stretch)
	return Rect2(r.position * stretch + Vector2(12,40), r.size * stretch)

func rebuild() -> void:
	portrait = vertical_layout
	stretch.x = maxf(0.1, (size.x - 24) / (296.0 if portrait else 700.0))
	stretch.y = maxf(0.1, (available_height - 92) / (700.0 if portrait else 296.0)) if available_height > 0 else stretch.x
	factor = minf(stretch.x, stretch.y)
	custom_minimum_size.x = 0
	var seat_columns := maxi(1, int(size.x / 140))
	var seat_rows := ceili(seated_players.size() / float(seat_columns))
	custom_minimum_size.y = available_height if available_height > 0 else (700 if portrait else 296) * stretch.y + 92 + (0 if hide_tray else 86)
	cells.clear(); spots.clear(); tray.clear()
	cells["0"] = mapped(Rect2(0,0,50,156))
	for n in range(1,37):
		cells[str(n)] = mapped(Rect2(50 + int((n-1)/3)*50, (2-(n-1)%3)*52, 50,52))
	for i in range(3):
		cells["Column %d" % (3-i)] = mapped(Rect2(650,i*52,50,52))
		cells[["1st dozen","2nd dozen","3rd dozen"][i]] = mapped(Rect2(50+i*200,176,200,40))
	for i in range(6): cells[["1–18","Even","Red","Black","Odd","19–36"][i]] = mapped(Rect2(50+i*100,216,100,80))
	var options := Games.roulette_bets()
	for name in options:
		if cells.has(name): continue
		var numbers: Array = options[name].numbers
		var at := Vector2.ZERO
		for n in numbers: at += (cells[str(n)] as Rect2).get_center()
		at /= numbers.size()
		if name.begins_with("Street") or name.begins_with("Six line"):
			if portrait: at.x = 12 + 166 * stretch.x
			else: at.y = 40 + 166 * stretch.y
		elif numbers.has(0):
			var logical_y := 156.0 if name == "First four" else 0.0
			if name != "First four":
				for n in numbers:
					if n != 0: logical_y += (2-(int(n)-1)%3)*52+26
				logical_y /= numbers.size()-1
			at = mapped(Rect2(50, logical_y, 0, 0)).position
		spots[name] = at
	var y := custom_minimum_size.y - 48
	if not hide_tray:
		for i in range(4): tray[[5,10,25,100][i]] = Vector2(size.x * (i+0.5)/4, y)
	queue_redraw()

func target(at: Vector2) -> String:
	var nearest := ""
	var distance := minf(13, minf(stretch.x * (52 if portrait else 50), stretch.y * (50 if portrait else 52)) * 0.23)
	for name in spots:
		var d := at.distance_to(spots[name])
		if d < distance: nearest = name; distance = d
	if nearest != "": return nearest
	for name in cells:
		if (cells[name] as Rect2).has_point(at): return name
	return ""

func feedback_for(key: String) -> Dictionary:
	if key.is_empty() or context == null: return {}
	var rect: Rect2 = cells[key] if cells.has(key) else Rect2(spots[key] - Vector2(13, 13), Vector2(26, 26))
	return preload("res://presentation/play/wager_feedback.gd").resolve(context, key, selected, rect, locked)

func preview_caption() -> String:
	var preview := feedback_for(hover)
	if preview.is_empty(): return ""
	var text := hover.replace("–", "-") + " | " + Chips.Money.cash(preview.amount, 2)
	return text + " | " + (preview.detail if preview.valid else preview.reason)

func begin_chip_drag() -> void:
	if locked: return
	pressed_on_felt = true
	rack_drag = true
	dragging = true

func pointer_input(at: Vector2, pressed: bool) -> void:
	pointer = at
	hover = target(at)
	if pressed:
		pressed_on_felt = not locked
		press_origin = at
		for amount in tray:
			if at.distance_to(tray[amount]) <= 25 and amount >= minimum and amount <= wallet:
				selected = amount; dragging = true; rack_drag = true; denomination_changed.emit(selected)
	else:
		if pressed_on_felt and not locked and not hover.is_empty() and (rack_drag or at.distance_to(press_origin) <= 10):
			var preview := feedback_for(hover)
			if preview.is_empty() or preview.valid: wager_requested.emit(hover, selected)
		pressed_on_felt = false
		dragging = false
		rack_drag = false
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position; hover = target(pointer); queue_redraw()
	elif event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT:
		pointer_input(event.position, event.pressed)
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if event is InputEventMouseButton and event.device != -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and pressed_on_felt:
		pointer_input(get_global_transform_with_canvas().affine_inverse() * event.position, false)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.index == 0 and (get_global_rect().has_point(event.position) or pressed_on_felt):
		pointer_input(get_global_transform_with_canvas().affine_inverse() * event.position, event.pressed)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == 0 and pressed_on_felt:
		pointer = get_global_transform_with_canvas().affine_inverse() * event.position
		hover = target(pointer)
		queue_redraw()
		get_viewport().set_input_as_handled()

func caption(at: Vector2, value: String, fs: int, color: Color = Color.WHITE) -> void:
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, at + Vector2(-width/2,fs*0.35),value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,color)

func chip(at: Vector2, amount: float, active: bool = false) -> void:
	Chips.draw_stack(self, at, amount, 23 if active else 19, Chips.seat_color(-1))

func _draw() -> void:
	if font == null: return
	draw_texture_rect(PitBoss.texture("casino_play/roulette/roulette_felt_base.png"), Rect2(Vector2.ZERO, size), false)
	for name in cells:
		var rect: Rect2 = cells[name]
		var color := Color("246039")
		if name.is_valid_int() and name != "0": color = Color("c62c37") if int(name) in Games.RED else Color("111c18")
		if name == "Red": color = Color("c62c37")
		if name == "Black": color = Color("111c18")
		if name.is_valid_int():
			draw_rect(rect, color)
			draw_rect(rect, Color("c6a649"), false, 1.5)
			caption(rect.get_center(), name, int(clampf(minf(rect.size.x, rect.size.y) * 0.60, 10, 28)))
		else:
			draw_rect(rect, Color(0.06, 0.24, 0.16, 0.65))
			draw_rect(rect, Color("c6a649"), false, 1.5)
			var title: String = "C" + name.get_slice(" ", 1) + " 2:1" if name.begins_with("Column") else name.replace("–", "-")
			if portrait and "dozen" in name:
				caption(rect.get_center() - Vector2(0, 14), name.get_slice(" ", 0), 14)
				title = "dozen"
			caption(rect.get_center(), title, int(clampf(minf(rect.size.y * 0.55, rect.size.x / maxf(2, title.length()) * 1.4), 8, 24)))
		if name == str(winning_number): draw_rect(rect.grow(-2), Color("ffe397"), false, 3)
	# Small seam marks make streets and six-line bets discoverable.
	for name in spots:
		if name.begins_with("Street") or name.begins_with("Six line"): draw_circle(spots[name],2,Color("e8c778"))
	var preview := feedback_for(hover)
	if not preview.is_empty():
		var color := Color("ffe397") if preview.valid else Color("d18a76")
		if cells.has(hover):
			draw_rect(preview.region, Color(color, 0.2))
			draw_rect(preview.region, color, false, 2)
		else:
			draw_circle(spots[hover], 6, color)
			draw_arc(spots[hover], 10, 0, TAU, 24, color, 2)
			for number in Games.roulette_bets()[hover].numbers:
				draw_rect(cells[str(number)], Color(color, 0.2))
				draw_rect(cells[str(number)], color, false, 2)
		if preview.valid: chip(pointer, preview.amount, true)
	# Committed snapshots exist only after the shared simulation spin.
	for wager in guest_wagers:
		if not cells.has(wager.key) and not spots.has(wager.key): continue
		var cell: Rect2 = cells[wager.key] if cells.has(wager.key) else Rect2(spots[wager.key] - Vector2(10, 10), Vector2(20, 20))
		var seat := int(wager.seat)
		var inset := cell.grow(-9)
		var position_on_rail: Vector2 = GUEST_STACK_POSITIONS[clampi(seat, 0, 6)]
		var at := inset.position + position_on_rail * inset.size
		Chips.draw_stack(self, at, float(wager.stake), 8, Chips.seat_color(seat), false)
	for name in bets:
		if cells.has(name): chip((cells[name] as Rect2).get_center(),bets[name])
		elif spots.has(name): chip(spots[name],bets[name])
	var columns := maxi(1, seated_players.size())
	for i in range(seated_players.size()):
		var player: Dictionary = seated_players[i]
		var at := Vector2((i + 0.5) * size.x / columns, custom_minimum_size.y - 26)
		Chips.avatar(self, at, int(player.seat), 10)
		caption(at + Vector2(0, 20), "S%d" % (int(player.seat) + 1), 11, Chips.seat_color(int(player.seat)))
	for amount in tray:
		chip(tray[amount],amount,selected == amount)
		if amount < minimum or amount > wallet or locked: draw_circle(tray[amount],23,Color(0,0,0,0.55))
	if not hide_tray: caption(Vector2(size.x/2,custom_minimum_size.y-83), hover.replace("–", "-") if hover != "" else "Drag a chip or tap the felt",12,Color("ffe397"))
	if dragging: chip(pointer,selected,true)
