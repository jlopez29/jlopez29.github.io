extends Control
# Geometry is shared by rendering and hit testing, including inside-bet seams.
signal wager_requested(name: String, amount: float)
signal denomination_changed(amount: float)
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const Games = preload("res://scripts/casino_games.gd")
const Chips = preload("res://presentation/play/chip_stack.gd")
const GUEST_STACK_POSITIONS := [Vector2(0,0), Vector2(0.5,0), Vector2(1,0), Vector2(1,0.5), Vector2(1,1), Vector2(0.5,1), Vector2(0,1)]
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

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(rebuild)
	rebuild()

func mapped(r: Rect2) -> Rect2:
	if portrait: return Rect2(Vector2(r.position.y, r.position.x) * factor + Vector2(12,12), Vector2(r.size.y, r.size.x) * factor)
	return Rect2(r.position * factor + Vector2(12,12), r.size * factor)

func rebuild() -> void:
	portrait = vertical_layout
	factor = maxf(0.88, (size.x - 24) / (296.0 if portrait else 700.0))
	custom_minimum_size.x = 320 if portrait else 640
	var seat_columns := maxi(1, int(size.x / 140))
	var seat_rows := ceili(seated_players.size() / float(seat_columns))
	custom_minimum_size.y = (700 if portrait else 296) * factor + 24 + seat_rows * 100 + (0 if hide_tray else 86)
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
			if portrait: at.x = 12 + 166 * factor
			else: at.y = 12 + 166 * factor
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
	var distance := clampf(9 * factor, 6, 13)
	for name in spots:
		var d := at.distance_to(spots[name])
		if d < distance: nearest = name; distance = d
	if nearest != "": return nearest
	for name in cells:
		if (cells[name] as Rect2).has_point(at): return name
	return ""

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pointer = event.position; hover = target(pointer); queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.position
		if event.pressed:
			if locked: return
			for amount in tray:
				if pointer.distance_to(tray[amount]) <= 25 and amount >= minimum and amount <= wallet:
					selected = amount; dragging = true; denomination_changed.emit(selected); accept_event(); queue_redraw(); return
		else:
			var name := target(pointer)
			if not locked and name != "": wager_requested.emit(name, selected)
			dragging = false
		accept_event(); queue_redraw()

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
			# Asset cropping is presentation metadata; cells/spots above own bet geometry.
			var n := int(name)
			var source := Rect2(201, 230, 120, 356) if n == 0 else Rect2(320 + int((n - 1) / 3) * 120, 230 + (2 - (n - 1) % 3) * 118, 120, 118)
			draw_texture_rect_region(PitBoss.texture("casino_play/roulette/roulette_betting_layout.png"), rect, source)
		else:
			draw_rect(rect, Color(0.06, 0.24, 0.16, 0.65))
			draw_rect(rect, Color("c6a649"), false, 1.5)
			var title: String = "2:1" if name.begins_with("Column") else name.replace("–", "-")
			caption(rect.get_center(), title, int(clampf(rect.size.x / maxf(2, title.length()) * 1.4, 12, 24)))
		if name == str(winning_number): draw_rect(rect.grow(-2), Color("ffe397"), false, 3)
	# Small seam marks make streets and six-line bets discoverable.
	for name in spots:
		if name.begins_with("Street") or name.begins_with("Six line"): draw_circle(spots[name],2,Color("e8c778"))
	if hover != "" and not locked:
		var at: Vector2 = (cells[hover] as Rect2).get_center() if cells.has(hover) else spots[hover]
		draw_arc(at,23,0,TAU,40,Color("ffe397"),2)
	# Committed snapshots exist only after the shared simulation spin.
	for wager in guest_wagers:
		if not cells.has(wager.key): continue
		var cell: Rect2 = cells[wager.key]
		var seat := int(wager.seat)
		var inset := cell.grow(-9)
		var position_on_rail: Vector2 = GUEST_STACK_POSITIONS[clampi(seat, 0, 6)]
		var at := inset.position + position_on_rail * inset.size
		Chips.draw_stack(self, at, float(wager.stake), 8, Chips.seat_color(seat), false)
	for name in bets:
		if cells.has(name): chip((cells[name] as Rect2).get_center(),bets[name])
		elif spots.has(name): chip(spots[name],bets[name])
	var columns := maxi(1, int(size.x / 140))
	var base_y := (700 if portrait else 296) * factor + 48
	for i in range(seated_players.size()):
		var player: Dictionary = seated_players[i]
		var at := Vector2((i % columns + 0.5) * size.x / columns, base_y + int(i / columns) * 100)
		Chips.avatar(self, at, int(player.seat), 16)
		caption(at + Vector2(0, 30), "S%d %s" % [int(player.seat) + 1, str(player.name).get_slice(" |", 0).left(10)], 12, Chips.seat_color(int(player.seat)))
		for wager in guest_wagers:
			if int(wager.id) != int(player.id): continue
			caption(at + Vector2(0, 48), "%s %s" % [wager.key, Chips.Money.cash(float(wager.stake), 2)], 12)
			if settled: caption(at + Vector2(0, 65), "Back " + Chips.Money.cash(float(wager.returned), 2), 12)
	for amount in tray:
		chip(tray[amount],amount,selected == amount)
		if amount < minimum or amount > wallet or locked: draw_circle(tray[amount],23,Color(0,0,0,0.55))
	if not hide_tray: caption(Vector2(size.x/2,custom_minimum_size.y-83), hover.replace("–", "-") if hover != "" else "Drag a chip or tap the felt",12,Color("ffe397"))
	if dragging: chip(pointer,selected,true)
