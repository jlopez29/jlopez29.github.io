extends Control

signal bet_clicked(kind: String)
var sim: CasinoSimulation
var chip := 25.0
var locked := false
var targets: Array = []
var font: Font
const GOLD := Color("e3bb70")
const INK := Color("f0ead8")

func _ready() -> void:
	font = ThemeDB.fallback_font
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP

func label(at: Vector2, value: String, font_size: int = 16, color: Color = INK) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func cell(rect: Rect2, kind: String, title: String, table: Dictionary) -> void:
	var enabled := not locked and sim.bet_error(sim.joined, kind, chip) == ""
	draw_rect(rect, Color("155e50") if enabled else Color("244c45"))
	draw_rect(rect, GOLD if table.owner[kind] > 0 else Color("87aaa0"), false, 1.5)
	label(rect.position + Vector2(10, 23), title, 16)
	label(rect.position + Vector2(10, 45), "$%d on" % table.owner[kind] if table.owner[kind] > 0 else "+$%d" % sim.bet_amount(table, kind, chip), 12, GOLD)
	if enabled: targets.append({"rect": rect, "kind": kind})

func _draw() -> void:
	targets.clear()
	if sim == null or font == null or sim.joined < 0: return
	var table := sim.get_table(sim.joined)
	if table.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO, size), Color("113a34"))
	draw_rect(Rect2(6, 6, size.x - 12, size.y - 12), GOLD, false, 2)
	label(Vector2(22, 34), "AT THE RAIL  /  CRAPS %02d" % sim.joined, 19, GOLD)
	label(Vector2(22, 62), "Shooter: %s" % sim.shooter_name(table), 17)
	label(Vector2(22, 88), "COME-OUT · PUCK OFF" if int(table.point) == 0 else "POINT %d · PUCK ON" % table.point, 14, GOLD)
	var width := (size.x - 52) / 6
	for i in range(6):
		var n: int = CrapsRules.NUMBERS[i]
		cell(Rect2(16 + i * (width + 4), 109, width, 57), CrapsRules.PLACE_KEYS[n], str(n), table)
		if int(table.point) == n:
			draw_circle(Vector2(16 + i * (width + 4) + width - 12, 120), 7, Color("f2ede2"))
	var half := (size.x - 36) / 2
	cell(Rect2(16, 176, half, 56), "come", "COME", table)
	cell(Rect2(20 + half, 176, half, 56), "dont_come", "DON'T COME", table)
	cell(Rect2(16, 241, size.x - 32, 56), "field", "FIELD   2 · 3 · 4 · 9 · 10 · 11 · 12", table)
	cell(Rect2(16, 307, half, 56), "pass", "PASS LINE", table)
	cell(Rect2(20 + half, 307, half, 56), "dont_pass", "DON'T PASS · BAR 12", table)
	if size.y > 440:
		for i in range(2):
			die(Vector2(24 + i * 66, 380), int(table.dice[i]))
		label(Vector2(165, 400), "Last roll: %d" % (int(table.dice[0]) + int(table.dice[1])), 18, GOLD)
		label(Vector2(165, 424), "Tap the felt to add $%d chips." % int(chip), 13)
	if size.y > 480:
		var history := "Recent: "
		for i in range(mini(8, table.history.size())): history += "%d%s  " % [table.history[i].total, "!" if table.history[i].seven_out else ""]
		label(Vector2(24, 468), history, 14)

func die(at: Vector2, value: int) -> void:
	draw_rect(Rect2(at, Vector2(50, 50)), Color("eee9dd"))
	var pips := {1: [Vector2(25, 25)], 2: [Vector2(12, 12), Vector2(38, 38)], 3: [Vector2(12, 12), Vector2(25, 25), Vector2(38, 38)], 4: [Vector2(12, 12), Vector2(38, 12), Vector2(12, 38), Vector2(38, 38)], 5: [Vector2(12, 12), Vector2(38, 12), Vector2(25, 25), Vector2(12, 38), Vector2(38, 38)], 6: [Vector2(12, 12), Vector2(38, 12), Vector2(12, 25), Vector2(38, 25), Vector2(12, 38), Vector2(38, 38)]}
	for pip in pips[value]: draw_circle(at + pip, 4, Color("163b34"))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for target in targets:
			if target.rect.has_point(event.position):
				bet_clicked.emit(target.kind)
				return
