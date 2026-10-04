extends Control

signal table_clicked(id: int)
signal floor_clicked(at: Vector2)
signal guest_clicked(id: int)

var sim: CasinoSimulation
var visitor_mode := false
var building := false
var rotated := false
var selected := 1
var preview := Vector2(-100, -100)
var move_target := Vector2(-1, -1)
var walk_path: Array = []
var zoom := 1.0
var camera := Vector2.ZERO
var pulse := 0.0
var font: Font

const INK := Color("d5e5e7")
const GOLD := Color("e3bb70")
const TEAL := Color("52d9b1")

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font

func world_at(screen: Vector2) -> Vector2:
	return (screen - camera) / zoom

func screen_at(world: Vector2) -> Vector2:
	return world * zoom + camera

func blocked(at: Vector2) -> bool:
	if not Rect2(22, 92, 806, 493).has_point(at):
		return true
	for table in sim.tables:
		if sim.bounds(table).grow(12).has_point(at):
			return true
	return false

func _process(delta: float) -> void:
	if sim == null:
		return
	pulse += delta
	var fit := minf(size.x / 850.0, size.y / 610.0)
	zoom = lerpf(zoom, fit * (1.32 if visitor_mode else 1.0), minf(1, delta * 8))
	var desired := size / 2 - sim.player * zoom if visitor_mode else (size - Vector2(850, 610) * zoom) / 2
	for axis in [0, 1]:
		var extent: float = Vector2(850, 610)[axis] * zoom
		desired[axis] = clampf(desired[axis], size[axis] - extent, 0) if extent > size[axis] else (size[axis] - extent) / 2
	camera = camera.lerp(desired, minf(1, delta * 8))
	if visitor_mode and sim.joined < 0:
		var dir := Vector2.ZERO
		if not get_viewport().gui_get_focus_owner() is LineEdit:
			dir.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			dir.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		if dir.length() > 0:
			move_target = Vector2(-1, -1)
			walk_path.clear()
		elif move_target.x >= 0:
			var target := Vector2(walk_path[0][0], walk_path[0][1]) if not walk_path.is_empty() else move_target
			dir = target - sim.player
			if dir.length() < 4:
				if not walk_path.is_empty(): walk_path.pop_front()
				elif sim.player.distance_to(move_target) < 5: move_target = Vector2(-1, -1)
			dir = dir.normalized() * minf(1.0, dir.length() / maxf(0.001, delta * 150))

		var motion := dir.limit_length(1.0) * delta * 150
		if not blocked(sim.player + Vector2(motion.x, 0)):
			sim.player.x += motion.x
		if not blocked(sim.player + Vector2(0, motion.y)):
			sim.player.y += motion.y
	preview = (world_at(get_local_mouse_position()) / 10).floor() * 10
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var at := world_at(event.position)
		if building:
			floor_clicked.emit((at / 10).floor() * 10)
			return
		for table in sim.tables:
			if sim.bounds(table).grow(12).has_point(at):
				table_clicked.emit(int(table.id))
				return
		for guest in sim.guests:
			if at.distance_to(Vector2(guest.x, guest.y)) < 14:
				guest_clicked.emit(int(guest.id))
				return
		if visitor_mode and not blocked(at):
			walk_to(at)
		floor_clicked.emit(at)

func text_at(at: Vector2, text: String, color: Color = INK, font_size: int = 14) -> void:
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _draw() -> void:
	if sim == null or font == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color("111c29"))
	draw_set_transform(camera, 0, Vector2(zoom, zoom))
	draw_rect(Rect2(0, 0, 850, 610), Color("172432"))
	for x in range(0, 850, 40):
		for y in range(100, 610, 40):
			draw_rect(Rect2(x + 2, y + 2, 36, 36), Color("1b2a39") if (x + y) % 80 == 0 else Color("192736"))
	# Brass border, lit back wall, bar and lounge: all procedural, no asset dependency.
	draw_rect(Rect2(12, 82, 826, 510), Color("9a8053"), false, 2)
	draw_rect(Rect2(14, 12, 822, 62), Color("101b26"))
	draw_line(Vector2(24, 75), Vector2(826, 75), GOLD, 2)
	text_at(Vector2(330, 47), "N E O N   H O U S E", GOLD, 19)
	text_at(Vector2(360, 65), "DICE  /  DRINKS  /  GOOD COMPANY", Color("8293a5"), 9)
	# Back-of-house furniture lives outside the editable floor rectangle.
	draw_rect(Rect2(35, 19, 160, 38), Color("344055"))
	text_at(Vector2(65, 43), "THE CAGE", GOLD, 12)
	for x in [65, 100, 135, 170]:
		draw_circle(Vector2(x, 65), 5, Color("536379"))
	draw_rect(Rect2(650, 18, 150, 39), Color("384353"))
	text_at(Vector2(685, 43), "COCKTAILS", GOLD, 12)
	for x in [670, 700, 730, 760, 790]:
		draw_circle(Vector2(x, 67), 6, Color("985b60"))
	for at in [Vector2(26, 105), Vector2(824, 105), Vector2(26, 580), Vector2(824, 580)]:
		draw_circle(at, 18, Color(0.9, 0.73, 0.43, 0.06))
		draw_circle(at, 8, Color("ac8c4f"))
		draw_circle(at, 5, Color("ead398"))
	draw_rect(Rect2(338, 546, 174, 44), Color("283b4d"))
	text_at(Vector2(362, 574), "ENTRANCE", GOLD, 16)
	for table in sim.tables:
		draw_table(table)
	if building:
		var valid := sim.can_place(preview, rotated) and sim.cash >= 3500
		var rect := Rect2(preview, Vector2(100, 190) if rotated else Vector2(190, 100))
		draw_rect(rect.grow(22), Color(0.3, 0.8, 0.6, 0.07) if valid else Color(1, 0.3, 0.3, 0.08))
		draw_rect(rect, Color(0.3, 0.85, 0.6, 0.3) if valid else Color(1, 0.3, 0.3, 0.3))
		draw_rect(rect, TEAL if valid else Color("f08484"), false, 2)
		text_at(preview + Vector2(8, 26), "$3,500 · CRAPS", INK, 13)
	for guest in sim.guests:
		var at := Vector2(guest.x, guest.y)
		var color := GOLD if guest.vip else Color.from_hsv(fmod(float(guest.id) * 0.17, 1.0), 0.25, 0.8)
		draw_circle(at + Vector2(0, 3), 9, Color(0, 0, 0, 0.25))
		draw_circle(at, 7, color)
		draw_circle(at + Vector2(0, -3), 3, Color("f0cfb5"))
		if guest.satisfaction < 50:
			text_at(at + Vector2(8, -9), "!", Color("f08484"), 14)
		var table := sim.get_table(int(guest.table))
		if not table.is_empty() and int(table.shooter) == int(guest.id):
			draw_arc(at, 12, 0, TAU, 20, GOLD, 2)
			text_at(at + Vector2(-11, -14), "DICE", GOLD, 8)
		if guest.vip:
			text_at(at + Vector2(-8, -13), "VIP", GOLD, 8)
	if visitor_mode:
		draw_circle(sim.player, 16 + sin(pulse * 4) * 1.5, Color(0.89, 0.74, 0.44, 0.17))
		draw_circle(sim.player, 11, GOLD)
		draw_circle(sim.player, 8, Color("192936"))
		draw_circle(sim.player + Vector2(0, -2), 4, Color("f1d4bb"))
		text_at(sim.player + Vector2(-14, -21), "YOU", GOLD, 11)
		if move_target.x >= 0:
			draw_arc(move_target, 8, 0, TAU, 20, GOLD, 1)
	draw_set_transform(Vector2.ZERO)

func draw_table(table: Dictionary) -> void:
	var rect := sim.bounds(table)
	var active := sim.operating(table)
	var border := GOLD if selected == int(table.id) else Color("617078")
	draw_style_box(box(Color("080f18"), Color("080f18"), 14), Rect2(rect.position + Vector2(4, 8), rect.size))
	draw_style_box(box(Color("554330"), border, 14), rect)
	draw_style_box(box(Color("175f55") if active else Color("284347"), Color("beaa75"), 9), rect.grow(-9))
	var center := rect.get_center()
	if not table.rotated:
		draw_rect(Rect2(rect.position + Vector2(17, 20), Vector2(155, 35)), Color("d6d3a0"), false, 1)
		for i in range(6):
			var x := rect.position.x + 17 + i * 26
			draw_line(Vector2(x, rect.position.y + 20), Vector2(x, rect.position.y + 55), Color("c4c29b"), 1)
			text_at(Vector2(x + 7, rect.position.y + 42), str([4, 5, 6, 8, 9, 10][i]), Color("ede0ba"), 13)
		text_at(rect.position + Vector2(48, 75), "P A S S   L I N E", Color("d9d2aa"), 11)
	else:
		text_at(rect.position + Vector2(19, 75), "CRAPS", Color("e9ddaf"), 14)
		text_at(rect.position + Vector2(15, 130), "PASS LINE", Color("d9d2aa"), 10)
	var marker := "OFF" if int(table.point) == 0 else str(int(table.point))
	draw_circle(center + Vector2(0, 2), 12, Color("17202b"))
	text_at(center + Vector2(-10, 6), marker, INK, 10)
	var label_pos := rect.position + Vector2(0, -39)
	text_at(label_pos, "CRAPS %02d" % int(table.id), GOLD if selected == int(table.id) else INK, 13)
	var players := sim.seated(int(table.id)).size() + (1 if sim.joined == int(table.id) else 0)
	text_at(rect.position + Vector2(0, rect.size.y + 44), "%s · %d/8" % [sim.table_status(table), players], TEAL if active else Color("899aaa"), 11)
	for i in range(sim.crew(int(table.id)).size()):
		var pos := rect.position + Vector2(rect.size.x + 15, 28 + i * 27)
		draw_circle(pos, 7, Color("e0e5df"))
		draw_rect(Rect2(pos + Vector2(-2, -4), Vector2(4, 9)), Color("26384d"))
	if table.broken:
		text_at(center + Vector2(-22, -16), "REPAIR", Color("ffa294"), 12)

func box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(radius)
	return style

func walk_to(at: Vector2) -> void:
	if blocked(at): return
	move_target = at
	var request := {"x": sim.player.x, "y": sim.player.y, "tx": at.x, "ty": at.y}
	sim.route(request)
	walk_path = request.path

func walk_to_table(id: int) -> void:
	var table := sim.get_table(id)
	if table.is_empty(): return
	var rect := sim.bounds(table)
	walk_to(Vector2(rect.get_center().x, rect.end.y + 24))
