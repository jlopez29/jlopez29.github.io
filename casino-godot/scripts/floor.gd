extends Control

signal table_clicked(id: int)
signal floor_clicked(at: Vector2)
signal guest_clicked(id: int)

const FinancialText = preload("res://scripts/financial_text.gd")
var sim: CasinoSimulation:
	set(value):
		if sim == value: return
		if sim != null and sim.financial_event.is_connected(_on_financial_event): sim.financial_event.disconnect(_on_financial_event)
		sim = value
		clear_financial_feedback()
		if sim != null: sim.financial_event.connect(_on_financial_event)
var floating_results: Array = []
var visitor_mode := false
var building := false
var build_kind := "slots"
var build_slot_profile := "starter"
var moving_id := -1
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
	for effect in floating_results: effect.age += delta
	floating_results = floating_results.filter(func(effect): return float(effect.age) < float(effect.lifetime))
	var floor_width := 850.0 if sim.expanded or visitor_mode else 535.0
	var fit := minf(size.x / floor_width, size.y / 610.0)
	zoom = lerpf(zoom, fit * (1.32 if visitor_mode else 1.0), minf(1, delta * 8))
	var desired := size / 2 - sim.player * zoom if visitor_mode else (size - Vector2(floor_width, 610) * zoom) / 2
	for axis in [0, 1]:
		var extent: float = Vector2(floor_width, 610)[axis] * zoom
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
	var room_width := 850 if sim.expanded else 535
	draw_rect(Rect2(0, 0, room_width, 610), Color("172432"))
	for x in range(0, room_width - 20, 40):
		for y in range(100, 610, 40):
			draw_rect(Rect2(x + 2, y + 2, 36, 36), Color("1b2a39") if (x + y) % 80 == 0 else Color("192736"))
	# Brass border, lit back wall, bar and lounge: all procedural, no asset dependency.
	draw_rect(Rect2(12, 82, room_width - 24, 510), Color("9a8053"), false, 2)
	draw_rect(Rect2(14, 12, room_width - 28, 62), Color("101b26"))
	draw_line(Vector2(24, 75), Vector2(room_width - 24, 75), GOLD, 2)
	text_at(Vector2(330 if sim.expanded else 245, 47), "NEON HOUSE", GOLD, 19)
	if sim.expanded: text_at(Vector2(360, 65), "GOOD COMPANY", Color("9bafc2"), 11)
	# Back-of-house furniture lives outside the editable floor rectangle.
	draw_rect(Rect2(35, 19, 160, 38), Color("344055"))
	text_at(Vector2(65, 43), "THE CAGE", GOLD, 12)
	for x in [65, 100, 135, 170]:
		draw_circle(Vector2(x, 65), 5, Color("536379"))
	if sim.expanded:
		draw_rect(Rect2(650, 18, 150, 39), Color("384353"))
		text_at(Vector2(685, 43), "COCKTAILS" if sim.unlocked("service") else "SERVICE LOCKED", GOLD, 12)
		for x in [670, 700, 730, 760, 790]:
			draw_circle(Vector2(x, 67), 6, Color("985b60"))
	for at in [Vector2(26, 105), Vector2(room_width - 26, 105), Vector2(26, 580), Vector2(room_width - 26, 580)]:
		draw_circle(at, 18, Color(0.9, 0.73, 0.43, 0.06))
		draw_circle(at, 8, Color("ac8c4f"))
		draw_circle(at, 5, Color("ead398"))
	draw_rect(Rect2(338, 546, 174, 44), Color("283b4d"))
	text_at(Vector2(362, 574), "ENTRANCE", GOLD, 16)
	for table in sim.tables:
		draw_table(table)
	if building:
		var valid: bool = sim.can_place(preview, rotated, moving_id, build_kind) and (moving_id >= 0 or (sim.unlocked(build_kind) and (build_kind != "slots" or sim.slot_unlocked(build_slot_profile)) and sim.cash >= sim.purchase_cost(build_kind, build_slot_profile)))
		var rect := Rect2(preview, sim.furniture_size(build_kind, rotated))
		draw_rect(rect.grow(22), Color(0.3, 0.8, 0.6, 0.07) if valid else Color(1, 0.3, 0.3, 0.08))
		draw_rect(rect, Color(0.3, 0.85, 0.6, 0.3) if valid else Color(1, 0.3, 0.3, 0.3))
		draw_rect(rect, TEAL if valid else Color("f08484"), false, 2)
		text_at(preview + Vector2(8, 26), "$%d | %s" % [sim.purchase_cost(build_kind, build_slot_profile), CasinoTuning.SLOT_PROFILES[build_slot_profile].short_name if build_kind == "slots" else CasinoGames.NAMES[build_kind]], INK, 13)
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
		if guest.state in ["Browsing", "Watching"]:
			text_at(at + Vector2(-14, -23), "WATCH", Color("83c9c1"), 8)
		if guest.state in ["To cage", "Cashing out"]:
			text_at(at + Vector2(-15, -15), "CASH OUT", GOLD, 8)
		if guest.vip:
			text_at(at + Vector2(-8, -13), "VIP", GOLD, 8)
	for employee in sim.staff:
		if employee.role != "Service": continue
		var at := Vector2(float(employee.get("x", 730)), float(employee.get("y", 90)))
		draw_circle(at + Vector2(0, 3), 10, Color(0, 0, 0, 0.3))
		draw_circle(at, 8, Color("66d5c3"))
		draw_circle(at + Vector2(0, -4), 3, Color("f0cfb5"))
		text_at(at + Vector2(-16, -15), "SERVICE", TEAL, 8)
		if employee.get("service_state", "At bar") == "Delivering":
			draw_line(at + Vector2(7, 1), at + Vector2(17, 1), INK, 2)
			draw_rect(Rect2(at + Vector2(10, -5), Vector2(4, 6)), GOLD)
	for i in range(sim.cashout_effects.size()):
		var effect: Dictionary = sim.cashout_effects[i]
		var at := Vector2(42, 113 + i * 36)
		var color := TEAL if effect.net >= 0 else Color("f08484")
		draw_rect(Rect2(at - Vector2(5, 17), Vector2(220, 34)), Color("101b26"))
		text_at(at, "SESSION %s$%d | %s" % ["+" if effect.net >= 0 else "-", absf(effect.net), effect.name], color, 13)
		text_at(at + Vector2(0, 13), "Cashed out $%d" % effect.cash, INK, 10)
	if visitor_mode:
		draw_circle(sim.player, 16 + sin(pulse * 4) * 1.5, Color(0.89, 0.74, 0.44, 0.17))
		draw_circle(sim.player, 11, GOLD)
		draw_circle(sim.player, 8, Color("192936"))
		draw_circle(sim.player + Vector2(0, -2), 4, Color("f1d4bb"))
		text_at(sim.player + Vector2(-14, -21), "YOU", GOLD, 11)
		if move_target.x >= 0:
			draw_arc(move_target, 8, 0, TAU, 20, GOLD, 1)
	draw_set_transform(Vector2.ZERO)
	draw_financial_feedback()

func draw_table(table: Dictionary) -> void:
	if sim.table_kind(table) != "craps":
		draw_other_game(table)
		return
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
	text_at(rect.position + Vector2(0, rect.size.y + 44), "%s | %d/8" % [sim.table_status(table), players], TEAL if active else Color("899aaa"), 11)
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

func draw_other_game(table: Dictionary) -> void:
	var rect := sim.bounds(table)
	var kind := sim.table_kind(table)
	var color := Color(str(sim.slot_profile(table).color)) if kind == "slots" else (Color("174c42") if kind == "blackjack" else (Color("3e324f") if kind == "holdem" else Color("395041")))
	draw_style_box(box(color, GOLD if selected == int(table.id) else Color("718b85"), 12), rect)
	var center := rect.get_center()
	if kind == "slots":
		draw_rect(Rect2(rect.position + Vector2(7, 15), Vector2(rect.size.x - 14, 30)), Color("0f1b28"))
		var profile := sim.slot_profile(table)
		if profile.screen == "video":
			for row in range(2):
				for column in range(3):
					draw_rect(Rect2(rect.position + Vector2(10 + column * 14, 19 + row * 10), Vector2(10, 7)), Color(str(profile.color)).lightened(0.3))
			text_at(rect.position + Vector2(9, 59), "$%d" % table.minimum, GOLD, 11)
		else: text_at(rect.position + Vector2(9, 36), "7 7 7", GOLD, 13)
		for mark in range(int(profile.prestige) / 2): draw_circle(rect.position + Vector2(10 + mark * 10, 8), 2, GOLD)
	elif kind == "roulette":
		for i in range(16):
			var at := center + Vector2.from_angle(i * TAU / 16) * 26
			draw_circle(at, 5, Color("bf4257") if i % 2 else Color("152331"))
		draw_circle(center, 13, GOLD)
	else:
		for i in range(3):
			var at := center + Vector2(-34 + i * 25, -15)
			draw_rect(Rect2(at, Vector2(20, 29)), Color("ede6d8"))
			text_at(at + Vector2(3, 19), ["A", "K", "Q"][i], Color("b64354"), 13)
	text_at(rect.position + Vector2(0, -13), "%s %02d" % [sim.slot_profile(table).short_name if kind == "slots" else CasinoGames.NAMES[kind], table.id], GOLD, 12)
	text_at(rect.position + Vector2(0, rect.size.y + 17), "%s | %d/%d" % [sim.table_status(table), sim.seated(int(table.id)).size(), sim.capacity(table)], TEAL, 10)
	for i in range(sim.crew(int(table.id)).size()):
		draw_circle(rect.position + Vector2(rect.size.x + 15, 25 + i * 30), 8, INK)

func clear_financial_feedback() -> void:
	floating_results.clear()

func _on_financial_event(event: Dictionary) -> void:
	if event.category != "gaming" or absf(float(event.amount)) < 0.005: return
	# Same-asset, same-sign small bursts can share a label; never cancel a win
	# against a loss or merge visitor money into guest business.
	for effect in floating_results:
		if int(event.importance) < 2 and int(effect.importance) < 2 and effect.asset_id == event.asset_id and effect.actor == event.actor and signf(float(effect.amount)) == signf(float(event.amount)) and float(effect.age) < CasinoTuning.MONEY_POPUP_MERGE_SECONDS:
			effect.amount += float(event.amount)
			effect.count += 1
			effect.importance = CasinoTuning.money_importance(float(effect.amount))
			effect.lifetime = CasinoTuning.MONEY_POPUP_SECONDS + int(effect.importance) * CasinoTuning.MONEY_POPUP_IMPORTANCE_SECONDS
			return
	var effect := event.duplicate(true)
	effect.age = 0.0
	effect.count = 1
	effect.lifetime = CasinoTuning.MONEY_POPUP_SECONDS + int(effect.importance) * CasinoTuning.MONEY_POPUP_IMPORTANCE_SECONDS
	floating_results.append(effect)
	# Preserve stronger swings when a floor is busy; underlying events remain intact.
	var on_asset := floating_results.filter(func(item): return item.asset_id == event.asset_id)
	if on_asset.size() > CasinoTuning.MONEY_POPUPS_PER_ASSET: _discard_smallest(on_asset)
	if floating_results.size() > CasinoTuning.MONEY_POPUP_LIMIT: _discard_smallest(floating_results.duplicate())

func _discard_smallest(candidates: Array) -> void:
	var discard: Dictionary = candidates[0]
	for effect in candidates:
		if int(effect.importance) < int(discard.importance) or (effect.importance == discard.importance and float(effect.age) > float(discard.age)): discard = effect
	floating_results.erase(discard)

func draw_financial_feedback() -> void:
	# Draw after resetting the world transform: fixed pixel size remains legible
	# while walking/zooming, while each anchor continues to follow its asset.
	var occupied: Array[Rect2] = []
	var ordered := floating_results.duplicate()
	ordered.sort_custom(func(a, b): return int(a.importance) > int(b.importance))
	for effect in ordered:
		var table := sim.get_table(int(effect.asset_id))
		var anchor: Vector2 = effect.position
		if not table.is_empty(): anchor = Vector2(sim.bounds(table).get_center().x, sim.bounds(table).position.y)
		var at := screen_at(anchor)
		if not Rect2(Vector2(-50, -50), size + Vector2(100, 100)).has_point(at): continue
		var age := float(effect.age)
		var lifetime := float(effect.lifetime)
		var importance := int(effect.importance)
		var text := FinancialText.house_result(float(effect.amount))
		var font_size: int = [12, 14, 17, 21][importance]
		var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if width > size.x - 8:
			font_size = maxi(12, floori(font_size * (size.x - 8) / width))
			width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		at += Vector2(-width / 2, -CasinoTuning.MONEY_POPUP_OFFSET - CasinoTuning.MONEY_POPUP_RISE * age / lifetime)
		at.x = clampf(at.x, 4, maxf(4, size.x - width - 4))
		at.y = clampf(at.y, font_size + 6, maxf(font_size + 6, size.y - 6))
		var rect := Rect2(at - Vector2(4, font_size + 2), Vector2(width + 8, font_size + 8))
		var baseline := at.y
		for attempt in range(6):
			if not occupied.any(func(other): return other.intersects(rect)): break
			var offset := (attempt / 2 + 1) * (font_size + 8) * (-1 if attempt % 2 == 0 else 1)
			at.y = clampf(baseline + offset, font_size + 6, maxf(font_size + 6, size.y - 6))
			rect.position.y = at.y - font_size - 2
		if occupied.any(func(other): return other.intersects(rect)): continue
		occupied.append(rect)
		var alpha := 1.0 - smoothstep(lifetime * 0.45, lifetime, age)
		var color := TEAL if float(effect.amount) > 0 else Color("ff9486")
		color.a = alpha * (0.75 if importance == 0 else 1.0)
		draw_style_box(_money_box(importance, alpha), rect)
		draw_string_outline(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 3, Color(0.03, 0.05, 0.07, alpha))
		draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _money_box(importance: int, alpha: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0.04, 0.07, 0.10, alpha * (0.65 if importance < 2 else 0.92))
	box.set_corner_radius_all(4)
	if importance >= 2:
		box.border_color = Color(0.89, 0.74, 0.44, alpha)
		box.set_border_width_all(1 if importance == 2 else 2)
	return box
