extends "res://scripts/floor.gd"
# Migration adapter: inherit proven input/camera/feedback, never call the legacy
# world renderer. All visible furniture and people are retained asset nodes.
const AssetScene = preload("res://presentation/components/casino_asset_view.tscn")
const GuestScene = preload("res://presentation/components/guest_marker.tscn")
const Catalog = preload("res://presentation/art_catalog.gd")
const StaffScene = preload("res://presentation/components/staff_marker.tscn")
var management_top := 72.0
var mobile_viewport := Rect2()
var touch_points := {}
var touch_origin := Vector2.ZERO
var touch_moved := false
var pinch_distance := 0.0
var inspector_occlusion := Rect2()
var framing_signature: Array = []
var room_signature := Rect2()
var asset_views := {}
var guest_views := {}
var staff_views := {}
@onready var world: Node2D = $World

func _ready() -> void:
	super._ready()
	world.show_behind_parent = true # Existing feedback draws above world nodes.
	$World/Player.texture = PitBoss.texture("guests/base/guest_gold.svg")
	$World/Player.scale = Vector2.ONE * 28 / $World/Player.texture.get_width()

func configure_view(compact: bool, landscape: bool) -> void:
	if not view_configured:
		# Desktop starts with the property filling the viewport; Fit remains an overview.
		view_configured = true
		close_view = not compact
		pan_center = sim.floor_rect().get_center()
		if not compact and not sim.tables.is_empty():
			pan_center.y = sim.bounds(sim.tables[0]).get_center().y
		view_scale = 1.0
	landscape_view = landscape
	compact_labels = compact

func update_camera(delta: float) -> void:
	if visitor_mode:
		super.update_camera(delta)
		return
	if compact_labels:
		update_mobile_camera(delta)
		return
	var room := sim.floor_rect()
	# HUD overlays the world. Frame the useful area below it without reserving
	# side columns. A single scalar preserves artwork proportions/world geometry.
	var viewport := Rect2(Vector2(0, management_top), Vector2(size.x, maxf(1, size.y - management_top)))
	var overview := minf(viewport.size.x / room.size.x, viewport.size.y / room.size.y)
	var fill := maxf(viewport.size.x / room.size.x, viewport.size.y / room.size.y)
	var target_zoom := fill * view_scale if close_view else overview
	var selected_bounds := Rect2()
	if inspector_occlusion.size.y > 0 and selected > 0 and presentation.get("tables", {}).has(selected):
		selected_bounds = sim.bounds(presentation.tables[selected])
		var free_height := inspector_occlusion.position.y - management_top - 50
		target_zoom = minf(target_zoom, maxf(1, free_height) / (selected_bounds.size.y * 1.08))
	zoom = lerpf(zoom, target_zoom, minf(1, delta * 8))
	var framing := [selected, selected_bounds, inspector_occlusion, size, view_scale, close_view]
	if selected_bounds.size.y > 0 and framing != framing_signature:
		# Reframe presentation only, so the selected object's art clears the sheet.
		var usable_center := (management_top + inspector_occlusion.position.y) / 2
		pan_center.y = selected_bounds.get_center().y + (viewport.get_center().y - usable_center) / target_zoom
	framing_signature = framing
	var pan_end := room.end
	if selected_bounds.size.y > 0: pan_end.y += inspector_occlusion.size.y / zoom
	pan_center = pan_center.clamp(room.position, pan_end)
	var focus := pan_center if close_view else room.get_center()
	var desired := viewport.get_center() - focus * zoom
	for axis in [0, 1]:
		var extent: float = room.size[axis] * zoom
		var lower: float = viewport.end[axis] - room.end[axis] * zoom
		if axis == 1 and selected_bounds.size.y > 0:
			# Allow only the extra pan needed for artwork at the property's edge;
			# otherwise the carpet continues behind the inspector to the viewport edge.
			var art_bottom := selected_bounds.get_center().y + selected_bounds.size.y * 0.54
			lower = minf(lower, inspector_occlusion.position.y - 12 - art_bottom * zoom)
		desired[axis] = clampf(desired[axis], lower, viewport.position[axis] - room.position[axis] * zoom) if extent > viewport.size[axis] else viewport.get_center()[axis] - room.get_center()[axis] * zoom
	camera = camera.lerp(desired, minf(1, delta * 8))

func update_mobile_camera(delta: float) -> void:
	var room := sim.floor_rect()
	var viewport := mobile_viewport
	if viewport.size.x <= 0 or viewport.size.y <= 0: viewport = Rect2(Vector2.ZERO, size)
	var fit := minf(viewport.size.x / room.size.x, viewport.size.y / room.size.y)
	var focus_zoom := minf(viewport.size.x / CasinoTuning.STARTER_PROPERTY.size.x, viewport.size.y / CasinoTuning.STARTER_PROPERTY.size.y)
	if landscape_view: focus_zoom = viewport.size.x / CasinoTuning.STARTER_PROPERTY.size.x
	var target_zoom := focus_zoom * view_scale if close_view else fit
	zoom = lerpf(zoom, target_zoom, minf(1, delta * 8))
	pan_center = pan_center.clamp(room.position, room.end)
	var desired := viewport.get_center() - (pan_center if close_view else room.get_center()) * zoom
	for axis in [0, 1]:
		var extent: float = room.size[axis] * zoom
		desired[axis] = clampf(desired[axis], viewport.end[axis] - room.end[axis] * zoom, viewport.position[axis] - room.position[axis] * zoom) if extent > viewport.size[axis] else viewport.get_center()[axis] - room.get_center()[axis] * zoom
	camera = camera.lerp(desired, minf(1, delta * 8))

# Touches start on the floor. Track their continuation globally so dragging into
# a sheet cannot leave a stuck pointer or turn a pinch into a placement tap.
func _input(event: InputEvent) -> void:
	if not compact_labels or not is_visible_in_tree():
		touch_points.clear()
		return
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and touch_points.has(event.index):
		var local_event := make_input_local(event)
		handle_touch(local_event)
		get_viewport().set_input_as_handled()

func handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if touch_points.is_empty():
				touch_origin = event.position
				touch_moved = false
			touch_points[event.index] = event.position
			if touch_points.size() > 1:
				touch_moved = true
				var points := touch_points.values()
				pinch_distance = points[0].distance_to(points[1])
		else:
			if touch_points.size() == 1 and not touch_moved and not event.canceled:
				select_at(event.position)
			touch_points.erase(event.index)
			pinch_distance = 0
	elif event is InputEventScreenDrag and touch_points.has(event.index):
		touch_points[event.index] = event.position
		if touch_points.size() > 1:
			var points := touch_points.values()
			var distance: float = points[0].distance_to(points[1])
			if pinch_distance > 1 and not visitor_mode:
				begin_mobile_pan()
				view_scale = clampf(view_scale * distance / pinch_distance, 0.25, 4.0)
			pinch_distance = distance
		elif not visitor_mode:
			if event.position.distance_to(touch_origin) > 8: touch_moved = true
			if touch_moved:
				begin_mobile_pan()
				pan_center -= event.relative / maxf(zoom, 0.01)

func begin_mobile_pan() -> void:
	if close_view: return
	var focus_zoom := minf(mobile_viewport.size.x / CasinoTuning.STARTER_PROPERTY.size.x, mobile_viewport.size.y / CasinoTuning.STARTER_PROPERTY.size.y)
	if landscape_view: focus_zoom = mobile_viewport.size.x / CasinoTuning.STARTER_PROPERTY.size.x
	view_scale = zoom / maxf(0.01, focus_zoom)
	pan_center = world_at(mobile_viewport.get_center())
	close_view = true

func _gui_input(event: InputEvent) -> void:
	if compact_labels:
		if event is InputEventScreenTouch and event.pressed and touch_points.is_empty() and not mobile_viewport.has_point(event.position): return
		if event is InputEventMouseButton and event.pressed and not mobile_viewport.has_point(event.position): return
		if event is InputEventScreenTouch or event is InputEventScreenDrag:
			handle_touch(event)
			accept_event()
			return
		# Project emulates a mouse for touch. Handle each gesture only once.
		if event is InputEventMouse and event.device == -1: return
		if event is InputEventMouseMotion and pointer_down and event.position.distance_to(pointer_start) > 8:
			begin_mobile_pan()
	if building and not compact_labels and event is InputEventMouseMotion and not pointer_down:
		placement_target = (world_at(event.position) / 10).floor() * 10
	if not compact_labels and not visitor_mode and not close_view:
		var wheel: bool = event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		var pan: bool = event is InputEventMouseMotion and pointer_down and event.position.distance_to(pointer_start) > 8
		if wheel or pan:
			# Switching out of overview must preserve the current scale before
			# applying the existing wheel step or drag, rather than jumping to Fill.
			var room := sim.floor_rect()
			var fill := maxf(size.x / room.size.x, maxf(1, size.y - management_top) / room.size.y)
			view_scale = zoom / fill
			if pan: pan_center = world_at(Vector2(size.x / 2, (size.y + management_top) / 2))
	super._gui_input(event)

func _process(delta: float) -> void:
	if sim == null or not is_visible_in_tree(): return
	super._process(delta)
	if building and compact_labels and not placement_target.is_finite():
		preview = (world_at(mobile_viewport.get_center()) / 10).floor() * 10
	if not is_visible_in_tree(): return
	if presentation_revision != sim.presentation_revision:
		presentation = sim.floor_presentation()
		presentation_revision = sim.presentation_revision
	world.position = camera
	world.scale = Vector2.ONE * zoom
	sync_world()

func prune(views: Dictionary, live: Dictionary) -> void:
	for id in views.keys():
		if not live.has(id):
			views[id].queue_free()
			views.erase(id)

func sync_world() -> void:
	var room := sim.floor_rect()
	if room_signature != room:
		room_signature = room
		$World/Carpet.position = room.position
		$World/Carpet.scale = Vector2.ONE * 0.16
		$World/Carpet.size = room.size / 0.16
		$World/Lobby.position = room.position
		$World/Lobby.scale = Vector2.ONE * 0.35
		$World/Lobby.size = Vector2(room.size.x, 112) / 0.35
		$World/Walkway.position = room.position + Vector2(12, 112)
		$World/Walkway.scale = Vector2.ONE * 0.3
		$World/Walkway.size = Vector2(room.size.x - 24, 18) / 0.3
		$World/RoomTrim.points = PackedVector2Array([room.position + Vector2(3, 112), Vector2(room.end.x - 3, room.position.y + 112), room.end - Vector2(3, 3), Vector2(room.position.x + 3, room.end.y - 3), room.position + Vector2(3, 112)])
		$World/LobbyTrim.points = PackedVector2Array([room.position + Vector2(0, 110), Vector2(room.end.x, room.position.y + 110)])
		$World/Lounge.position = Vector2(room.end.x - 150, room.position.y + 53)
		$World/LoungeShadow.position = $World/Lounge.position + Vector2(3, 5)
		$World/LoungeFloor.position = Vector2(room.end.x - 209, room.position.y + 6)
		$World/LoungeFloor.size = Vector2(118, 98) / 0.25
		$World/PlantLeft.position = room.position + Vector2(18, 53)
		$World/PlantRight.position = Vector2(room.end.x - 22, room.position.y + 53)
	$World/Entrance.position = CasinoTuning.ENTRY + Vector2(-42, -11)
	$World/Bar.visible = sim.guest_feature_relevant("service")
	$World/Bar.position = sim.bar_bounds().position
	$World/Bar.size = sim.bar_bounds().size
	$World/BarLabel.visible = $World/Bar.visible and not sim.bar_available()
	$World/BarLabel.position = sim.bar_bounds().position + Vector2(6, -13)
	$World/BarLabel.text = "COCKTAIL BAR" if sim.bar_available() else "BAR / NO SERVICE"
	prune(asset_views, presentation.tables)
	for id in presentation.tables:
		if not asset_views.has(id):
			var view := AssetScene.instantiate()
			$World/Assets.add_child(view)
			asset_views[id] = view
		asset_views[id].update_view(sim, presentation.tables[id], presentation, selected, compact_labels)
		asset_views[id].set_view_zoom(zoom)
	var thoughts := {}
	for bubble in thought_bubbles: thoughts[int(bubble.guest_id)] = true
	prune(guest_views, presentation.guests)
	for id in presentation.guests:
		if not guest_views.has(id):
			var marker := GuestScene.instantiate()
			$World/Guests.add_child(marker)
			guest_views[id] = marker
		guest_views[id].update_guest(presentation.guests[id], selected_guest, thoughts.has(id), compact_labels)
		guest_views[id].position = guest_visual_position(presentation.guests[id])
		guest_views[id].set_view_zoom(zoom)
	# Crew lookup is built once by the existing read-only presentation index.
	var staff_positions := {}
	var employees := {}
	for table_id in presentation.crew:
		var bounds := sim.bounds(presentation.tables.get(table_id, {})) if presentation.tables.has(table_id) else Rect2()
		var crew: Array = presentation.crew[table_id]
		for i in range(crew.size()):
			employees[int(crew[i].id)] = crew[i]
			staff_positions[int(crew[i].id)] = bounds.position + Vector2(bounds.size.x + 15, 28 + i * 27)
	for employee in sim.staff:
		if employee.role == "Service" and employee.duty == "Active":
			employees[int(employee.id)] = employee
			staff_positions[int(employee.id)] = Vector2(float(employee.get("x", 730)), float(employee.get("y", 90)))
	prune(staff_views, staff_positions)
	for id in staff_positions:
		if not staff_views.has(id):
			var marker := StaffScene.instantiate()
			$World/Staff.add_child(marker)
			staff_views[id] = marker
		staff_views[id].update_view(employees[id], staff_positions[id], zoom)
	$World/Player.visible = visitor_mode
	$World/Player.position = sim.player

func guest_visual_position(guest: Dictionary) -> Vector2:
	var raw := Vector2(float(guest.x), float(guest.y))
	if str(guest.state) != "Playing": return raw
	var view = asset_views.get(int(guest.table))
	var seat := int(guest.get("seat", -1))
	if view == null or seat < 0 or seat >= view.seat_anchors.size(): return raw
	return world.to_local(view.to_global(view.seat_anchors[seat]))

func select_at(screen: Vector2) -> void:
	# Seated markers now sit inside furniture art. Keep their visible targets
	# selectable, while leaving all movement/placement input in the shared floor.
	if not building:
		var at := world_at(screen)
		var distance := maxf(14, 22 / zoom) if compact_labels else 14.0 / zoom
		var nearest := -1
		for id in guest_views:
			var marker = guest_views[id]
			var candidate := at.distance_to(marker.position)
			if candidate < distance:
				distance = candidate
				nearest = int(id)
		if nearest >= 0:
			guest_clicked.emit(nearest)
			return
	super.select_at(screen)

func _draw() -> void:
	if sim == null or font == null: return
	if presentation_revision != sim.presentation_revision:
		presentation = sim.floor_presentation()
		presentation_revision = sim.presentation_revision
	redraw_count += 1
	# Procedural commands are reserved for transient interaction overlays.
	if building:
		draw_set_transform(camera, 0, Vector2.ONE * zoom)
		var valid := placement_is_valid()
		var rect := Rect2(preview, sim.furniture_size(build_kind, rotated))
		var color := Color("79c99a") if valid else Color("f08484")
		draw_rect(rect.grow(CasinoTuning.ASSET_AISLE_CLEARANCE), Color(color, 0.08))
		var image := Catalog.texture_for(build_kind, moving_id if moving_id > 0 else sim.next_id)
		var extent := Vector2(rect.size.y, rect.size.x) if rotated else rect.size
		var ratio := minf(extent.x / image.get_width(), extent.y / image.get_height()) * 1.08
		draw_set_transform(screen_at(rect.get_center()), PI / 2 if rotated else 0.0, Vector2.ONE * zoom)
		draw_texture_rect(image, Rect2(-image.get_size() * ratio / 2, image.get_size() * ratio), false, Color(1, 1, 1, 0.7))
		draw_set_transform(camera, 0, Vector2.ONE * zoom)
		draw_rect(rect, Color(color, 0.14))
		draw_rect(rect, color, false, 2)

		draw_set_transform(Vector2.ZERO)
	draw_financial_feedback()
	draw_thoughts()

func placement_is_valid() -> bool:
	if moving_id > 0 and sim.busy(sim.get_table(moving_id)): return false
	var target := placement_target if placement_target.is_finite() else preview
	return sim.can_place(target, rotated, moving_id, build_kind) and (moving_id >= 0 or (sim.unlocked(build_kind) and (build_kind != "slots" or sim.slot_unlocked(build_slot_profile)) and sim.cash >= sim.purchase_cost(build_kind, build_slot_profile)))
