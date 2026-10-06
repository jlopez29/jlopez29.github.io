extends "res://scripts/floor.gd"
# Migration adapter: inherit proven input/camera/feedback, never call the legacy
# world renderer. All visible furniture and people are retained asset nodes.
const AssetScene = preload("res://presentation/components/casino_asset_view.tscn")
const GuestScene = preload("res://presentation/components/guest_marker.tscn")
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
	if compact_labels or visitor_mode:
		super.update_camera(delta)
		return
	var room := sim.floor_rect()
	# HUD overlays the world. Frame the useful area below it without reserving
	# side columns. A single scalar preserves artwork proportions/world geometry.
	var viewport := Rect2(Vector2(0, 88), Vector2(size.x, maxf(1, size.y - 88)))
	var overview := minf(viewport.size.x / room.size.x, viewport.size.y / room.size.y)
	var fill := maxf(viewport.size.x / room.size.x, viewport.size.y / room.size.y)
	var target_zoom := fill * view_scale if close_view else overview
	zoom = lerpf(zoom, target_zoom, minf(1, delta * 8))
	pan_center = pan_center.clamp(room.position, room.end)
	var focus := pan_center if close_view else room.get_center()
	var desired := viewport.get_center() - focus * zoom
	for axis in [0, 1]:
		var extent: float = room.size[axis] * zoom
		desired[axis] = clampf(desired[axis], viewport.end[axis] - room.end[axis] * zoom, viewport.position[axis] - room.position[axis] * zoom) if extent > viewport.size[axis] else viewport.get_center()[axis] - room.get_center()[axis] * zoom
	camera = camera.lerp(desired, minf(1, delta * 8))

func _gui_input(event: InputEvent) -> void:
	if not compact_labels and not visitor_mode and not close_view:
		var wheel: bool = event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]
		var pan: bool = event is InputEventMouseMotion and pointer_down and event.position.distance_to(pointer_start) > 8
		if wheel or pan:
			# Switching out of overview must preserve the current scale before
			# applying the existing wheel step or drag, rather than jumping to Fill.
			var room := sim.floor_rect()
			var fill := maxf(size.x / room.size.x, maxf(1, size.y - 88) / room.size.y)
			view_scale = zoom / fill
			if pan: pan_center = world_at(Vector2(size.x / 2, (size.y + 88) / 2))
	super._gui_input(event)

func _process(delta: float) -> void:
	if sim == null: return
	super._process(delta)
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
	$World/Carpet.position = room.position
	$World/Carpet.size = room.size
	$World/Lobby.position = room.position
	$World/Lobby.size = Vector2(room.size.x, 76)
	$World/Entrance.position = CasinoTuning.ENTRY + Vector2(-42, -11)
	$World/Bar.visible = sim.guest_feature_relevant("service")
	$World/Bar.position = sim.bar_bounds().position
	$World/Bar.size = sim.bar_bounds().size
	prune(asset_views, presentation.tables)
	for id in presentation.tables:
		if not asset_views.has(id):
			var view := AssetScene.instantiate()
			$World/Assets.add_child(view)
			asset_views[id] = view
		asset_views[id].update_view(sim, presentation.tables[id], presentation, selected, compact_labels)
	var thoughts := {}
	for bubble in thought_bubbles: thoughts[int(bubble.guest_id)] = true
	prune(guest_views, presentation.guests)
	for id in presentation.guests:
		if not guest_views.has(id):
			var marker := GuestScene.instantiate()
			$World/Guests.add_child(marker)
			guest_views[id] = marker
		guest_views[id].update_guest(presentation.guests[id], selected_guest, thoughts.has(id), compact_labels)
	# Crew lookup is built once by the existing read-only presentation index.
	var staff_positions := {}
	for table_id in presentation.crew:
		var bounds := sim.bounds(presentation.tables.get(table_id, {})) if presentation.tables.has(table_id) else Rect2()
		var crew: Array = presentation.crew[table_id]
		for i in range(crew.size()):
			staff_positions[int(crew[i].id)] = bounds.position + Vector2(bounds.size.x + 15, 28 + i * 27)
	for employee in sim.staff:
		if employee.role == "Service" and employee.duty == "Active":
			staff_positions[int(employee.id)] = Vector2(float(employee.get("x", 730)), float(employee.get("y", 90)))
	prune(staff_views, staff_positions)
	for id in staff_positions:
		if not staff_views.has(id):
			var marker := Sprite2D.new()
			marker.texture = PitBoss.texture("guests/rings/ring_staff.svg")
			marker.scale = Vector2.ONE * 20 / marker.texture.get_width()
			$World/Staff.add_child(marker)
			staff_views[id] = marker
		staff_views[id].position = staff_positions[id]
	$World/Player.visible = visitor_mode
	$World/Player.position = sim.player

func _draw() -> void:
	if sim == null or font == null: return
	redraw_count += 1
	# Procedural commands are reserved for transient interaction overlays.
	if building:
		draw_set_transform(camera, 0, Vector2.ONE * zoom)
		var valid: bool = sim.can_place(preview, rotated, moving_id, build_kind) and (moving_id >= 0 or (sim.unlocked(build_kind) and (build_kind != "slots" or sim.slot_unlocked(build_slot_profile)) and sim.cash >= sim.purchase_cost(build_kind, build_slot_profile)))
		var rect := Rect2(preview, sim.furniture_size(build_kind, rotated))
		var color := TEAL if valid else Color("f08484")
		draw_rect(rect.grow(CasinoTuning.ASSET_AISLE_CLEARANCE), Color(color, 0.08))
		draw_rect(rect, Color(color, 0.3))
		draw_rect(rect, color, false, 2)
		text_at(preview + Vector2(8, 26), "$%d" % sim.purchase_cost(build_kind, build_slot_profile), INK, 13)
		draw_set_transform(Vector2.ZERO)
	draw_financial_feedback()
	draw_thoughts()
