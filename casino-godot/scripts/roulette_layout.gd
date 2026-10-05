extends Control
# Geometry is shared by rendering and hit testing, including inside-bet seams.
signal wager_requested(name: String, amount: float)
signal denomination_changed(amount: float)
const Games = preload("res://scripts/casino_games.gd")
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
	portrait = size.x < 700
	factor = maxf(0.2, (size.x - 24) / (260.0 if portrait else 700.0))
	custom_minimum_size.y = (700 if portrait else 260) * factor + 110
	cells.clear(); spots.clear(); tray.clear()
	cells["0"] = mapped(Rect2(0,0,50,156))
	for n in range(1,37):
		cells[str(n)] = mapped(Rect2(50 + int((n-1)/3)*50, (2-(n-1)%3)*52, 50,52))
	for i in range(3):
		cells["Column %d" % (3-i)] = mapped(Rect2(650,i*52,50,52))
		cells[["1st dozen","2nd dozen","3rd dozen"][i]] = mapped(Rect2(50+i*200,176,200,40))
	for i in range(6): cells[["1–18","Even","Red","Black","Odd","19–36"][i]] = mapped(Rect2(50+i*100,216,100,44))
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
				if pointer.distance_to(tray[amount]) <= 25 and amount >= minimum:
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
	draw_circle(at, 23 if active else 19, Color("e8c778"))
	draw_circle(at, 20 if active else 16, Color("b83852"))
	for i in range(8):
		var a := Vector2.from_angle(i*TAU/8)
		draw_line(at+a*14,at+a*18,Color.WHITE,2)
	caption(at,"$%d" % amount,12)

func _draw() -> void:
	if font == null: return
	draw_rect(Rect2(Vector2.ZERO,size),Color("17472d"))
	for name in cells:
		var rect: Rect2 = cells[name]
		var color := Color("246039")
		if name.is_valid_int() and name != "0": color = Color("c62c37") if int(name) in Games.RED else Color("111c18")
		if name == "Red": color = Color("c62c37")
		if name == "Black": color = Color("111c18")
		draw_rect(rect,color); draw_rect(rect,Color("ece8ce"),false,1.5)
		var title: String = "2:1" if name.begins_with("Column") else name
		caption(rect.get_center(),title,int(clampf(rect.size.x / maxf(2,title.length())*1.4,10,24)))
	# Small seam marks make streets and six-line bets discoverable.
	for name in spots:
		if name.begins_with("Street") or name.begins_with("Six line"): draw_circle(spots[name],2,Color("e8c778"))
	if hover != "" and not locked:
		var at: Vector2 = (cells[hover] as Rect2).get_center() if cells.has(hover) else spots[hover]
		draw_arc(at,23,0,TAU,40,Color("ffe397"),2)
	for name in bets:
		if cells.has(name): chip((cells[name] as Rect2).get_center()+Vector2(0,8),bets[name])
		elif spots.has(name): chip(spots[name],bets[name])
	for amount in tray:
		chip(tray[amount],amount,selected == amount)
		if amount < minimum or locked: draw_circle(tray[amount],23,Color(0,0,0,0.55))
	caption(Vector2(size.x/2,custom_minimum_size.y-83), hover if hover != "" else "Drag a chip or select one and tap the felt",12,Color("ffe397"))
	if dragging: chip(pointer,selected,true)
