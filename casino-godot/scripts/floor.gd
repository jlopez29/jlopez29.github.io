extends Control

signal table_clicked(id: int)
signal floor_clicked(at: Vector2)
signal guest_clicked(id: int)
signal bar_clicked()
signal private_door_requested
signal private_door_reached
var approaching_private_door := false

const PitBoss = preload("res://scripts/pit_boss_theme.gd")
var selected_guest := -1
const FinancialText = preload("res://scripts/financial_text.gd")
var sim: PitBossFloorContext:
	set(value):
		if sim == value: return
		if sim != null and sim.source.financial_event.is_connected(_on_financial_event): sim.source.financial_event.disconnect(_on_financial_event)
		if sim != null and sim.source.guest_thought.is_connected(_on_guest_thought): sim.source.guest_thought.disconnect(_on_guest_thought)
		sim = value
		clear_financial_feedback()
		if sim != null and not sim.is_private:
			sim.source.financial_event.connect(_on_financial_event)
			sim.source.guest_thought.connect(_on_guest_thought)
var presentation := {}
var redraw_count := 0
var feedback_batch_count := 0
var thought_presentation_count := 0
var presentation_speed := 1
var presentation_tick := 0
var presentation_amount := 0.0
var presentation_anchor := Vector2.ZERO
var presentation_revision := -1
var thought_flush := false
var idle_refresh := 0.0
var visible_signature: Array = []
var floating_results: Array = []
var thought_bubbles: Array = []
var pending_thoughts := {}
var thought_seen := {}
var thought_guest_seen := {}
var thought_clock := 0.0
var thought_next := 0.0
var money_rects: Array[Rect2] = []
var visitor_mode := false
var building := false
var build_kind := "slots"
var build_slot_profile := "starter"
var moving_id := -1
var rotated := false
var selected := 1
var placement_target := Vector2(INF, INF)
var preview := Vector2(-100, -100)
var move_target := Vector2(INF, INF)
var view_scale := 1.0
var walk_path: Array = []
var zoom := 1.0
var camera := Vector2.ZERO
var pulse := 0.0
var compact_labels := false
var close_view := false
var landscape_view := false
var pan_center := Vector2(267, 250)
var view_configured := false
var pointer_down := false
var dragging := false
var pointer_start := Vector2.ZERO

func configure_view(compact: bool, landscape: bool) -> void:
	if not view_configured:
		close_view = true
		pan_center.y = 180
		view_scale = 1.0 if landscape else 1.35 if compact else 1.65
		view_configured = true
	landscape_view = landscape
	compact_labels = compact

func toggle_fit() -> void:
	close_view = not close_view
	var table := sim.get_table(selected)
	if not table.is_empty(): pan_center = sim.bounds(table).get_center()

func frame_walk_mode(walking: bool) -> void:
	close_view = walking
	pan_center = sim.player if walking else sim.floor_rect().get_center()
	if walking:
		# Walk uses a starter-property scale, unlike the management camera.
		# Convert the visible zoom so entering Walk always moves a little closer.
		var focus_zoom := minf(size.x / CasinoTuning.STARTER_PROPERTY.size.x, size.y / CasinoTuning.STARTER_PROPERTY.size.y)
		if landscape_view: focus_zoom = size.x / CasinoTuning.STARTER_PROPERTY.size.x
		view_scale = zoom * 1.2 / maxf(0.01, focus_zoom)
	else:
		view_scale = 1.0

var font: Font

const INK := Color("d5e5e7")
const GOLD := Color("e3bb70")
const TEAL := Color("52d9b1")

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	font = ThemeDB.fallback_font

func world_at(screen: Vector2) -> Vector2:
	return (screen - camera) / zoom

func screen_at(world: Vector2) -> Vector2:
	return world * zoom + camera

func blocked(at: Vector2) -> bool:
	if sim.is_private and PitBossFloorContext.KIOSK.grow(CasinoTuning.ASSET_NAV_RADIUS).has_point(at): return true
	if not sim.walk_area().has_point(at):
		return true
	for table in sim.tables:
		if sim.bounds(table).grow(CasinoTuning.ASSET_NAV_RADIUS).has_point(at):
			return true
	return false

func _process(delta: float) -> void:
	if sim == null or not is_visible_in_tree():
		return
	var old_camera := camera
	var old_zoom := zoom
	var old_player := sim.player
	var old_preview := preview
	var had_animation := not floating_results.is_empty() or not thought_bubbles.is_empty()
	pulse += delta
	update_thoughts(delta)
	for effect in floating_results: effect.age += delta
	floating_results = floating_results.filter(func(effect): return float(effect.age) < float(effect.lifetime))
	update_camera(delta)
	if visitor_mode and sim.joined < 0 and is_visible_in_tree():
		var dir := Vector2.ZERO
		if not get_viewport().gui_get_focus_owner() is LineEdit:
			dir.x = float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
			dir.y = float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
		if dir.length() > 0:
			approaching_private_door = false
			move_target = Vector2(INF, INF)
			walk_path.clear()
		elif move_target.is_finite():
			var target := Vector2(walk_path[0][0], walk_path[0][1]) if not walk_path.is_empty() else move_target
			dir = target - sim.player
			if dir.length() < 4:
				if not walk_path.is_empty(): walk_path.pop_front()
				elif sim.player.distance_to(move_target) < 5: move_target = Vector2(INF, INF)
			dir = dir.normalized() * minf(1.0, dir.length() / maxf(0.001, delta * 150))

		var motion := dir.limit_length(1.0) * delta * 150
		if not blocked(sim.player + Vector2(motion.x, 0)):
			sim.player.x += motion.x
		if not blocked(sim.player + Vector2(0, motion.y)):
			sim.player.y += motion.y
	if approaching_private_door:
		var anchor := sim.door_approach()
		if move_target.is_finite() and move_target.distance_to(anchor) > 1: walk_to(anchor)
		if sim.player.distance_to(anchor) < 6:
			approaching_private_door = false
			walk_path.clear()
			move_target = Vector2(INF, INF)
			private_door_reached.emit()
	preview = placement_target if placement_target.is_finite() else (world_at(get_local_mouse_position()) / 10).floor() * 10
	idle_refresh += delta
	var state := [selected, selected_guest, building, moving_id, rotated, build_kind, build_slot_profile, visitor_mode, compact_labels, size, sim.elapsed, sim.opened, sim.tables.size(), sim.guests.size()]
	var moving := presentation_speed > 0 and (sim.guests.any(func(g): return g.state in ["Arriving", "Walking", "To cage", "Leaving", "Browsing", "Exploring", "To bar"]) or sim.staff.any(func(e): return e.role == "Service" and e.duty == "Active"))
	var hot_animation: bool = presentation.get("hot", {}).values().has(true)
	if state != visible_signature or camera.distance_to(old_camera) > 0.01 or absf(zoom - old_zoom) > 0.0001 or sim.player != old_player or (building and preview != old_preview) or had_animation or not floating_results.is_empty() or not thought_bubbles.is_empty() or moving or visitor_mode or hot_animation or idle_refresh >= 1:
		visible_signature = state
		idle_refresh = 0
		queue_redraw()

# Shared interaction code delegates framing to the active presentation.
func update_camera(delta: float) -> void:
	var room := sim.floor_rect()
	var fit := minf(size.x / room.size.x, size.y / room.size.y)
	var focus_zoom := minf(size.x / CasinoTuning.STARTER_PROPERTY.size.x, size.y / CasinoTuning.STARTER_PROPERTY.size.y)
	if landscape_view: focus_zoom = size.x / CasinoTuning.STARTER_PROPERTY.size.x
	var target_zoom := focus_zoom * view_scale if close_view or visitor_mode else fit
	zoom = lerpf(zoom, target_zoom, minf(1, delta * 8))
	pan_center = pan_center.clamp(room.position, room.end)
	var focus := sim.player if visitor_mode else pan_center if close_view else room.get_center()
	var desired := size / 2 - focus * zoom
	for axis in [0, 1]:
		var extent: float = room.size[axis] * zoom
		desired[axis] = clampf(desired[axis], size[axis] - room.end[axis] * zoom, -room.position[axis] * zoom) if extent > size[axis] else (size[axis] - extent) / 2 - room.position[axis] * zoom
	camera = camera.lerp(desired, minf(1, delta * 8))

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		pan_center = world_at(event.position)
		close_view = true
		view_scale = clampf(view_scale * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.25, 4.0)
		accept_event()
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			pointer_down = true
			dragging = false
			pointer_start = event.position
		else:
			if pointer_down and not dragging: select_at(event.position)
			pointer_down = false
		accept_event()
	elif event is InputEventMouseMotion and pointer_down:
		if event.position.distance_to(pointer_start) > 8: dragging = true
		if dragging and not visitor_mode:
			close_view = true
			pan_center -= event.relative / maxf(zoom, 0.01)
			pan_center = pan_center.clamp(sim.floor_rect().position, sim.floor_rect().end)
			accept_event()

func select_at(screen: Vector2) -> void:
	var at := world_at(screen)
	if not building and sim.door_bounds().has_point(at):
		private_door_requested.emit()
		return
	approaching_private_door = false
	if building:
		floor_clicked.emit((at / 10).floor() * 10)
		return
	if compact_labels:
		# Actual furniture takes precedence; outside it, expanded guest targets
		# must win over padded asset targets so seated guests remain inspectable.
		for table in sim.tables:
			if sim.bounds(table).has_point(at):
				table_clicked.emit(int(table.id))
				return
		var nearest: Dictionary = {}
		var distance := 22.0 / zoom
		for guest in sim.guests:
			var candidate := at.distance_to(Vector2(guest.x, guest.y))
			if candidate < distance:
				distance = candidate
				nearest = guest
		if not nearest.is_empty():
			guest_clicked.emit(int(nearest.id))
			return
	for table in sim.tables:
		if sim.bounds(table).grow(maxf(12, 18 / zoom) if compact_labels else 12).has_point(at):
			table_clicked.emit(int(table.id))
			return
	for guest in sim.guests:
		if at.distance_to(Vector2(guest.x, guest.y)) < (maxf(14, 22 / zoom) if compact_labels else 14):
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
	if presentation_revision != sim.presentation_revision:
		presentation = sim.floor_presentation()
		presentation_revision = sim.presentation_revision
	redraw_count += 1
	draw_rect(Rect2(Vector2.ZERO, size), Color("0e0f10"))
	draw_set_transform(camera, 0, Vector2(zoom, zoom))
	var room := sim.floor_rect()
	draw_rect(room, Color("172432"))
	# One repeated draw command; no per-tile nodes or scans at large properties.
	draw_texture_rect(PitBoss.texture("flooring/burgundy_carpet.png"), room, true)
	draw_rect(Rect2(room.position + Vector2(12, 82), room.size - Vector2(24, 100)), Color("9a8053"), false, 2)
	draw_rect(Rect2(room.position + Vector2(14, 12), Vector2(room.size.x - 28, 62)), Color("101b26"))
	draw_line(Vector2(room.position.x + 24, 75), Vector2(room.end.x - 24, 75), GOLD, 2)
	text_at(Vector2(205, 35), "PIT BOSS", GOLD, 14)
	# Back-of-house furniture lives outside the editable floor rectangle.
	draw_rect(Rect2(35, 19, 160, 38), Color("344055"))
	text_at(Vector2(65, 43), "THE CAGE", GOLD, 12)
	for x in [65, 100, 135, 170]:
		draw_circle(Vector2(x, 65), 5, Color("536379"))
	if sim.bar_available():
		var bar := sim.bar_bounds()
		draw_texture_rect(PitBoss.texture("casino/amenities/bar.png"), bar, false)
		text_at(bar.position + Vector2(15, 25), "COCKTAILS", GOLD, 12)
		for offset in CasinoTuning.BAR_GUEST_OFFSETS:
			draw_circle(bar.position + Vector2(offset.x, 49), 6, Color("985b60"))
			if sim.bar_available(): draw_circle(bar.position + offset, 10, Color(0.6, 0.4, 0.45, 0.15))
	for at in [room.position + Vector2(26, 105), Vector2(room.end.x - 26, 105), Vector2(room.position.x + 26, room.end.y - 30), room.end - Vector2(26, 30)]:
		draw_circle(at, 18, Color(0.9, 0.73, 0.43, 0.06))
		draw_circle(at, 8, Color("ac8c4f"))
		draw_circle(at, 5, Color("ead398"))
	draw_rect(PitBossFloorContext.Property.entrance_clearance(sim.source.floor_chunks), Color("283b4d"))
	draw_front_doors()
	for table in sim.tables:
		draw_table(table)
		if not compact_labels and sim.elapsed < int(table.staff_rotation_until):
			text_at(sim.bounds(table).position + Vector2(0, -27), "DEALER ROTATION", TEAL, 9)
	if building:
		var valid: bool = sim.can_place(preview, rotated, moving_id, build_kind) and (moving_id >= 0 or (sim.unlocked(build_kind) and (build_kind != "slots" or sim.slot_unlocked(build_slot_profile)) and sim.cash >= sim.purchase_cost(build_kind, build_slot_profile)))
		var rect := Rect2(preview, sim.furniture_size(build_kind, rotated))
		draw_rect(sim.placement_report(preview, rotated, moving_id, build_kind).candidate.circulation, Color(0.3, 0.8, 0.6, 0.07) if valid else Color(1, 0.3, 0.3, 0.08))
		draw_rect(rect, Color(0.3, 0.85, 0.6, 0.3) if valid else Color(1, 0.3, 0.3, 0.3))
		draw_rect(rect, TEAL if valid else Color("f08484"), false, 2)
		text_at(preview + Vector2(8, 26), "$%d | %s" % [sim.purchase_cost(build_kind, build_slot_profile), CasinoTuning.SLOT_PROFILES[build_slot_profile].short_name if build_kind == "slots" else CasinoGames.NAMES[build_kind]], INK, 13)
	for guest in sim.guests:
		var at := Vector2(guest.x, guest.y)
		draw_circle(at + Vector2(0, 3), 9, Color(0, 0, 0, 0.25))
		var colors := ["cream", "blue", "green", "cyan", "purple", "orange"]
		var base: String = "gold" if guest.vip else colors[int(guest.id) % colors.size()]
		draw_texture_rect(PitBoss.texture("guests/base/guest_" + base + ".svg"), Rect2(at - Vector2(14, 14), Vector2(28, 28)), false)
		# One dominant overlay. Selection and real distress override VIP styling.
		var ring := "alert" if guest.satisfaction < 35 else "selected" if int(guest.id) == selected_guest else "vip" if guest.vip else ""
		if not ring.is_empty():
			draw_texture_rect(PitBoss.texture("guests/rings/ring_" + ring + ".svg"), Rect2(at - Vector2(17, 17), Vector2(34, 34)), false)
	for employee in sim.staff:
		if employee.role != "Service" or employee.duty != "Active": continue
		var at := Vector2(float(employee.get("x", 730)), float(employee.get("y", 90)))
		draw_circle(at + Vector2(0, 3), 10, Color(0, 0, 0, 0.3))
		draw_circle(at, 8, Color("66d5c3"))
		draw_circle(at + Vector2(0, -4), 3, Color("f0cfb5"))
		if not compact_labels: text_at(at + Vector2(-16, -15), "SERVICE", TEAL, 8)
		if employee.get("service_state", "At bar") == "Delivering":
			draw_line(at + Vector2(7, 1), at + Vector2(17, 1), INK, 2)
			draw_rect(Rect2(at + Vector2(10, -5), Vector2(4, 6)), GOLD)
	for i in range(0 if compact_labels else sim.cashout_effects.size()):
		var effect: Dictionary = sim.cashout_effects[i]
		var at := Vector2(22, 113 + i * 24)
		var color := TEAL if effect.net >= 0 else Color("f08484")
		var message := "%s$%d | %s" % ["+" if effect.net >= 0 else "-", absf(effect.net), effect.name]
		var width := font.get_string_size(message, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_rect(Rect2(at - Vector2(5, 15), Vector2(width + 10, 22)), Color("101b26"))
		text_at(at, message, color, 13)
	if visitor_mode:
		draw_circle(sim.player, 16 + sin(pulse * 4) * 1.5, Color(0.89, 0.74, 0.44, 0.17))
		draw_circle(sim.player, 11, GOLD)
		draw_circle(sim.player, 8, Color("192936"))
		draw_circle(sim.player + Vector2(0, -2), 4, Color("f1d4bb"))
		text_at(sim.player + Vector2(-14, -21), "YOU", GOLD, 11)
		if move_target.is_finite():
			draw_arc(move_target, 8, 0, TAU, 20, GOLD, 1)
	draw_set_transform(Vector2.ZERO)
	if building:
		var report := sim.placement_report(preview, rotated, moving_id, build_kind)
		draw_placement_debug(report, bool(report.valid))
	if compact_labels: draw_asset_badges()
	draw_financial_feedback()
	draw_thoughts()

func placement_debug_origin() -> Vector2:
	return Vector2(10, 86)

func draw_placement_debug(report: Dictionary, can_purchase: bool) -> void:
	if not OS.is_debug_build() or report.get("candidate", {}).is_empty(): return
	var asset: Dictionary = report.candidate
	var blue := Color("68cfff")
	var purple := Color("d8a0ff")
	var gold := Color("ffd478")
	var result := Color("79c99a") if report.valid else Color("ff655f")
	var pixel := 1.0 / maxf(zoom, 0.1)
	draw_set_transform(camera, 0, Vector2.ONE * zoom)
	draw_rect(report.walk, Color(0.75, 0.85, 0.9, 0.5), false, pixel)
	for neighbor in sim.placement_geometry():
		if int(neighbor.id) == moving_id: continue
		draw_rect(neighbor.furniture, Color(blue, 0.35), false, pixel)
		draw_rect(neighbor.circulation, Color(gold, 0.25), false, pixel)
	draw_rect(asset.circulation, Color(gold, 0.09))
	draw_rect(asset.circulation, gold, false, pixel)
	draw_rect(asset.furniture, blue, false, 2 * pixel)
	draw_rect(asset.art, purple, false, 1.5 * pixel)
	draw_rect(asset.collision, result, false, 3 * pixel)
	for groups in [["seats", "approaches", blue], ["dealers", "dealer_approaches", purple]]:
		var seats: PackedVector2Array = asset[groups[0]]
		var approaches: PackedVector2Array = asset[groups[1]]
		for i in range(seats.size()):
			draw_line(seats[i], approaches[i], Color(groups[2], 0.8), pixel)
			draw_circle(seats[i], 3.5 * pixel, groups[2])
			draw_rect(Rect2(approaches[i] - Vector2.ONE * 3 * pixel, Vector2.ONE * 6 * pixel), groups[2], false, 1.5 * pixel)
	for failure in report.errors:
		var point: Vector2 = failure.position
		draw_line(point - Vector2(5, 5) * pixel, point + Vector2(5, 5) * pixel, Color("ff655f"), 2 * pixel)
		draw_line(point - Vector2(5, -5) * pixel, point + Vector2(5, -5) * pixel, Color("ff655f"), 2 * pixel)
	draw_set_transform(Vector2.ZERO)
	var origin := placement_debug_origin()
	var width := minf(420, size.x - origin.x - 10)
	draw_rect(Rect2(origin, Vector2(width, 104)), Color(0.03, 0.07, 0.10, 0.94))
	var reason := "VALID: all interaction paths reachable" if report.valid else "INVALID: " + str(report.errors[0].message)
	if report.valid and not can_purchase: reason = "Geometry valid | check access, cash or busy asset"
	var lines := ["DEV Placement | final bounds: green / red", "Blue: furniture/players | Purple: art/dealers", "Gold: circulation | dots: seats | boxes: approaches", "Red X: failed check | gray: walkable floor", reason]
	for i in range(lines.size()):
		draw_string(font, origin + Vector2(6, 18 + i * 19), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 12, 12, result if i == 4 else INK)

func draw_asset_badges() -> void:
	# Compact, fixed-pixel identity/state inside each asset's screen footprint.
	# Names and multi-line status belong in Inspect, not between adjacent machines.
	var occupied: Array[Rect2] = []
	for table in sim.tables:
		var world_rect := sim.bounds(table)
		var anchor := screen_at(world_rect.position) + Vector2(2, 2)
		var rect := Rect2(anchor, Vector2(38, 20))
		if not Rect2(Vector2.ZERO, size).encloses(rect): continue
		var overlaps := false
		for prior in occupied:
			if prior.intersects(rect): overlaps = true
		if overlaps: continue
		occupied.append(rect)
		draw_rect(rect, Color("101b26"))
		var color := Color("ffa294") if table.broken else TEAL if presentation.operating.get(int(table.id), false) else Color("9bafc2")
		draw_circle(anchor + Vector2(6, 10), 3, color)
		draw_string(font, anchor + Vector2(12, 15), str(table.id), HORIZONTAL_ALIGNMENT_LEFT, 24, 13, GOLD if selected == int(table.id) else INK)
		# Occupancy stays visual: guests are visible; a small dot marks a busy asset.
		if not presentation.seated.get(int(table.id), []).is_empty(): draw_circle(anchor + Vector2(34, 5), 2, GOLD)

func draw_table(table: Dictionary) -> void:
	draw_authored_asset(table)

func draw_authored_asset(table: Dictionary) -> void:
	var rect := sim.bounds(table)
	var kind := sim.table_kind(table)
	var asset := "casino/tables/" + ("ultimate_texas" if kind == "holdem" else kind) + ".png"
	if kind == "slots": asset = "casino/slots/slot_%02d.png" % (1 + int(table.id) % 5)
	var image := PitBoss.texture(asset)
	# Art is fitted inside occupancy. Rotation never changes gameplay geometry.
	var extent := Vector2(rect.size.y, rect.size.x) if table.rotated else rect.size
	var ratio := minf(extent.x / image.get_width(), extent.y / image.get_height())
	var art_size := image.get_size() * ratio
	draw_set_transform(screen_at(rect.get_center()), PI / 2 if table.rotated else 0.0, Vector2.ONE * zoom)
	draw_texture_rect(image, Rect2(-art_size / 2, art_size), false, Color.WHITE if not table.broken else Color("b97979"))
	draw_set_transform(camera, 0, Vector2.ONE * zoom)
	if selected == int(table.id): draw_rect(rect.grow(3), GOLD, false, 2)
	elif presentation.hot.get(int(table.id), false): draw_rect(rect.grow(3), Color("8b5cf6"), false, 2)
	if table.broken:
		var strength := (sin(pulse * 3.5) + 1) / 2
		var radius := rect.size.length() / 2 + 5 + strength * 3
		draw_arc(rect.get_center(), radius, 0, TAU, 64, Color(1, 0.27, 0.27, 0.4 + strength * 0.5), 2.5 / maxf(zoom, 0.1), true)

func walk_to(at: Vector2) -> void:
	if blocked(at): return
	move_target = at
	var request := {"x": sim.player.x, "y": sim.player.y, "tx": at.x, "ty": at.y}
	sim.route(request)
	if request.path.is_empty():
		move_target = Vector2(INF, INF)
		walk_path.clear()
		return
	walk_path = request.path

func walk_to_table(id: int) -> void:
	var table := sim.get_table(id)
	if table.is_empty(): return
	walk_to(sim.approach_position(table))

func clear_financial_feedback() -> void:
	presentation_revision = -1
	presentation.clear()
	presentation_amount = 0
	presentation_tick = 0
	thought_flush = false
	floating_results.clear()
	thought_bubbles.clear()
	pending_thoughts.clear()
	thought_seen.clear()
	thought_guest_seen.clear()
	thought_next = thought_clock

func invalidate_presentation() -> void:
	presentation_revision = -1
	queue_redraw()

func set_presentation_speed(value: int) -> void:
	if value == presentation_speed: return
	presentation_speed = value
	presentation_tick = 0
	presentation_amount = 0
	pending_thoughts.clear()
	thought_flush = false

func presentation_step() -> void:
	if presentation_speed <= 0 or presentation_speed > CasinoTuning.MAX_GAME_SPEED: return
	presentation_tick += 1
	if presentation_tick < CasinoTuning.FLOOR_PRESENTATION_SECONDS * presentation_speed: return
	presentation_tick = 0
	flush_presentation()

func flush_presentation() -> void:
	if absf(presentation_amount) >= 0.005:
		feedback_batch_count += 1
		var importance := CasinoTuning.money_importance(presentation_amount)
		floating_results.append({"amount": presentation_amount, "importance": importance, "position": presentation_anchor, "asset_id": -1, "guest_id": -1, "category": "batch", "age": 0.0, "lifetime": CasinoTuning.MONEY_POPUP_SECONDS + importance * CasinoTuning.MONEY_POPUP_IMPORTANCE_SECONDS})
		if floating_results.size() > CasinoTuning.MONEY_POPUP_LIMIT: floating_results.pop_front()
		queue_redraw()
	presentation_amount = 0
	thought_flush = true

func _on_financial_event(event: Dictionary) -> void:
	if presentation_speed <= 0 or presentation_speed > CasinoTuning.MAX_GAME_SPEED: return
	if event.category not in ["gaming", "bar", "comp"] or absf(float(event.amount)) < 0.005: return
	presentation_amount += float(event.amount)
	presentation_anchor = event.position

func draw_financial_feedback() -> void:
	# Draw after resetting the world transform: fixed pixel size remains legible
	# while walking/zooming, while each anchor continues to follow its asset.
	var occupied: Array[Rect2] = []
	money_rects.clear()
	var ordered := floating_results.duplicate()
	ordered.sort_custom(func(a, b): return int(a.importance) > int(b.importance))
	for effect in ordered:
		var table: Dictionary = presentation.tables.get(int(effect.asset_id), {})
		var anchor: Vector2 = effect.position
		if effect.category == "gaming" and not table.is_empty(): anchor = Vector2(sim.bounds(table).get_center().x, sim.bounds(table).position.y)
		elif effect.category in ["bar", "comp"]:
			for guest in sim.guests:
				if int(guest.id) == int(effect.guest_id):
					anchor = Vector2(guest.x, guest.y - 18)
					break
		var at := Vector2(size.x * 0.5, size.y * 0.25) if effect.category == "batch" else screen_at(anchor)
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
		money_rects.append(rect)
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

func _on_guest_thought(event: Dictionary) -> void:
	if presentation_speed <= 0 or presentation_speed > CasinoTuning.MAX_GAME_SPEED: return
	var previous: Dictionary = pending_thoughts.get(int(event.guest_id), {})
	if previous.is_empty() or int(event.priority) >= int(previous.priority):
		var item := event.duplicate()
		item.queued = thought_clock
		pending_thoughts[int(event.guest_id)] = item
	if pending_thoughts.size() > 32: pending_thoughts.erase(pending_thoughts.keys()[0])

func update_thoughts(delta: float) -> void:
	thought_clock += delta
	thought_bubbles = thought_bubbles.filter(func(item): return thought_clock - float(item.started) < CasinoTuning.THOUGHT_SECONDS)
	if not thought_flush and thought_bubbles.is_empty(): return
	var live := {}
	for guest in sim.guests: live[int(guest.id)] = guest
	thought_bubbles = thought_bubbles.filter(func(item): return live.has(int(item.guest_id)))
	for id in pending_thoughts.keys():
		if not live.has(id) or thought_clock - float(pending_thoughts[id].queued) > CasinoTuning.FLOOR_PRESENTATION_SECONDS + 1: pending_thoughts.erase(id)
	# Walking surfaces current real intent even between simulation thought events.
	if thought_flush and visitor_mode and sim.joined < 0:
		for guest in sim.guests:
			if sim.player.distance_to(Vector2(guest.x, guest.y)) < 130 and not pending_thoughts.has(int(guest.id)):
				_on_guest_thought({"guest_id": int(guest.id), "text": guest.thought, "priority": 1, "position": Vector2(guest.x, guest.y)})
	if not thought_flush: return
	thought_flush = false
	if not is_visible_in_tree() or thought_clock < thought_next or not thought_bubbles.is_empty():
		pending_thoughts.clear()
		return
	var best: Dictionary = {}
	var best_score := -INF
	for event in pending_thoughts.values():
		var id := int(event.guest_id)
		if not live.has(id): continue
		var guest: Dictionary = live[id]
		var at := screen_at(Vector2(guest.x, guest.y))
		if not Rect2(Vector2.ZERO, size).has_point(at): continue
		var key := "%d:%s" % [id, event.text]
		if thought_clock - float(thought_guest_seen.get(id, -1000)) < CasinoTuning.THOUGHT_GUEST_SECONDS or thought_clock - float(thought_seen.get(key, -1000)) < CasinoTuning.THOUGHT_REPEAT_SECONDS: continue
		var score := float(event.priority) * 100 - (sim.player.distance_to(Vector2(guest.x, guest.y)) * 0.1 if visitor_mode else 0.0)
		if score > best_score:
			best_score = score
			best = event
	pending_thoughts.clear()
	if best.is_empty(): return
	var bubble := best.duplicate()
	bubble.started = thought_clock
	thought_bubbles.append(bubble)
	thought_presentation_count += 1
	thought_guest_seen[int(best.guest_id)] = thought_clock
	thought_seen["%d:%s" % [best.guest_id, best.text]] = thought_clock
	for history in [thought_seen, thought_guest_seen]:
		while history.size() > CasinoTuning.THOUGHT_HISTORY_LIMIT: history.erase(history.keys()[0])
	thought_next = thought_clock + CasinoTuning.THOUGHT_GLOBAL_SECONDS

func draw_thoughts() -> void:
	var occupied := money_rects.duplicate()
	for bubble in thought_bubbles:
		var guest: Dictionary = {}
		for candidate in sim.guests:
			if int(candidate.id) == int(bubble.guest_id):
				guest = candidate
				break
		if guest.is_empty(): continue
		var anchor := screen_at(Vector2(guest.x, guest.y))
		var width := minf(220, size.x * 0.7)
		var lines: Array[String] = []
		var line := ""
		for word in str(bubble.text).split(" "):
			var proposed := word if line.is_empty() else line + " " + word
			if font.get_string_size(proposed, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x > width - 20 and not line.is_empty():
				lines.append(line)
				line = word
			else: line = proposed
		if not line.is_empty(): lines.append(line)
		if lines.size() > 3: lines = lines.slice(0, 3)
		var height := lines.size() * 17 + 16
		var at := anchor - Vector2(width / 2, height + 24 + 6 * (thought_clock - float(bubble.started)) / CasinoTuning.THOUGHT_SECONDS)
		at.x = clampf(at.x, 4, maxf(4, size.x - width - 4))
		var rect := Rect2(at, Vector2(width, height))
		var fits := false
		for offset in [Vector2.ZERO, Vector2(0, -height - 8), Vector2(0, height + 42)]:
			var candidate := Rect2(at + offset, rect.size)
			if not Rect2(Vector2(4, 4), size - Vector2(8, 60 if landscape_view else 8)).encloses(candidate): continue
			var blocked := false
			for other in occupied:
				if candidate.grow(4).intersects(other): blocked = true
			# Avoid laying a bubble across another person's screen position.
			for other in sim.guests:
				if int(other.id) != int(bubble.guest_id) and candidate.grow(8).has_point(screen_at(Vector2(other.x, other.y))): blocked = true
			if not blocked:
				rect = candidate
				fits = true
				break
		if not fits: continue
		occupied.append(rect)
		var age := thought_clock - float(bubble.started)
		var alpha := minf(1, age / 0.15) * minf(1, (CasinoTuning.THOUGHT_SECONDS - age) / 0.65)
		var skin := feedback_box(Color(0.14, 0.22, 0.27, alpha * 0.95), Color(0.55, 0.68, 0.7, alpha * 0.7), 9)
		draw_style_box(skin, rect)
		for i in range(lines.size()):
			draw_string(font, rect.position + Vector2(10, 20 + i * 17), lines[i], HORIZONTAL_ALIGNMENT_LEFT, width - 20, 13, Color(0.86, 0.92, 0.92, alpha))
		draw_circle(anchor + Vector2(0, -12), 2, Color(0.55, 0.68, 0.7, alpha))

func feedback_box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var skin := PitBoss.box(bg, border)
	skin.set_corner_radius_all(radius)
	return skin

func approach_private_door() -> bool:
	move_target = Vector2(INF, INF)
	walk_path.clear()
	visitor_mode = true
	walk_to(sim.door_approach())
	approaching_private_door = move_target.is_finite()
	return approaching_private_door

func draw_front_doors() -> void:
	if not sim.is_private:
		var entrance := PitBossFloorContext.Property.public_door(sim.source.floor_chunks)
		draw_rect(entrance, Color("283b4d"))
		draw_rect(entrance, TEAL, false, 2)
		text_at(entrance.position + Vector2(6, 16), "PUBLIC", TEAL, 10)
		text_at(entrance.position + Vector2(2, 30), "ENTRANCE", TEAL, 10)
	var door := sim.door_bounds()
	draw_rect(door, Color("382817"))
	draw_rect(door, GOLD, false, 2)
	if sim.is_private:
		text_at(door.position - Vector2(0, 8), "EXIT", GOLD, 11)
	else:
		text_at(door.position + Vector2(6, 16), "BACK", GOLD, 10)
		text_at(door.position + Vector2(5, 30), "ROOM", GOLD, 10)
	draw_circle(door.end - Vector2(12, 12) if sim.is_private else door.end - Vector2(5, 7), 3 if sim.is_private else 2, GOLD)
