extends Control

const VisibleViewport = preload("res://scripts/visible_viewport.gd")
const FinancialText = preload("res://scripts/financial_text.gd")
const DeveloperPanel = preload("res://scripts/developer_panel.gd")
const MilestoneNotice = preload("res://scripts/milestone_notice.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const Games = preload("res://scripts/casino_games.gd")
const GameView = preload("res://scripts/game_view.gd")
const FeltScript = preload("res://presentation/play/craps_surface.gd")
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const GOLD := Color("d4af37")
const TEAL := Color("22c55e")
const MUTED := Color("9ca3af")
const TEXT := Color("eae4d6")

@onready var presentation_shell: Control = $PitBossShell

var visible_viewport := VisibleViewport.new()
var viewport_dimensions := Vector2.ZERO
var viewport_insets := Vector4.ZERO
var viewport_sync_pending := false
var viewport_layout_count := 0

var displayed_cash := 0.0
var treasury_target := 0.0
var treasury_flash := 0.0
var treasury_direction := 0.0
var developer_panel: PanelContainer
var event_focus_staff := -1
var owner_checkpoint_path := CasinoTuning.SAVE_PATH
var event_cards: VBoxContainer
var objective_cards: VBoxContainer
var event_nav: Button
var milestone_notice: PanelContainer
var sim := CasinoSimulation.new()
var floor_view: Control
var selected := 1
var selected_guest := -1
var play_context := {}
var visitor := false
var building := false
var desktop_build_category := "slots"
var build_kind := "slots"
var build_slot_profile := "starter"
var back_room_floor: Control
var recovery_view: Control
var private_play := false
var resume_private: Button
var room_tools: HBoxContainer
var in_back_room := false
var game_view: Control
var moving := -1
var speed := 1
var previous_speed := 1
var dev_time_pending := 0.0
const DEV_TIME_STEP := 0.1 # Movement stays below one navigation-cell distance per update.
const DEV_FRAME_BUDGET_USEC := 8000
const DEV_MAX_PENDING_SECONDS := 60.0
var tick := 0.0
var refresh_timer := 0.0
var refreshed_elapsed := -1
var debug_snapshot_timer := 0.0
var debug_full_timer := 0.0
var retained_render := false
var render_cursors := {}
var inspector_identity: Array = []
var layout_identity: Array = []
var rolling := 0.0
var page := "table"
var stats: Label
var momentum_expanded := false
var hud_summary: Label
var objective: VBoxContainer
var asset_details := false
var expanded_slot_details := ""
var status: Label
var mode_hint: Label
var inspector: VBoxContainer
var feed: VBoxContainer
var doors_button: Button
var build_button: Button
var walk_button: Button
var pause_button: Button
var dice_label: Label
var modal: PanelContainer
var backdrop: ColorRect
var logo: TextureRect
var play_return: Button
var guest_metric: Label
var metric_panels: Array[Panel] = []
var brand: Label
var subtitle: Label
var header_actions: HBoxContainer
var hud_bar: Panel
var nav_rail: VBoxContainer
var alert_button: Button
var reputation_metric: Label
var staff_metric: Label
var inspector_heading: Label
var inspector_expand: Button
var inspector_open := false
var context_expanded := false
var side_panel: PanelContainer
var inspector_panel: PanelContainer
var inspector_scroll: ScrollContainer
var events_panel: PanelContainer
var bottom_nav: HBoxContainer
var floor_actions: HBoxContainer
var floor_walk_button: Button
var cancel_placement_button: Button
var confirm_placement_button: Button
var rotate_button: Button
var floor_join_button: Button
var felt: Control
var mobile := false
var mobile_pane := "floor"
var mobile_menu: MenuButton
var mobile_speed: Button
var mobile_dev: Button
var floor_fit: Button
var responsive_state := "desktop"
var finance_section := ""
var finance_advanced := false
var finance_compare_group := ""
var bar_menu_tab := "active"
var bar_menu_product := ""
var bar_finance_products := false
var bar_finance_product := ""
var traffic_details := false
var staff_details_role := ""
var table_scroll: ScrollContainer
var table_options := false
var chip_value := 25.0
var craps_category := "Line"
var active_roll_table := -1

func _ready() -> void:
	get_window().title = "Pit Boss - Casino Tycoon"
	displayed_cash = sim.cash
	treasury_target = sim.cash
	presentation_shell.mount(self)
	back_room_floor = preload("res://presentation/casino_floor_v2.tscn").instantiate()
	back_room_floor.set_script(preload("res://scripts/back_room_floor.gd"))
	back_room_floor.sim = PitBossFloorContext.new(sim, true)
	back_room_floor.z_index = 30
	add_child(back_room_floor)
	back_room_floor.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_room_floor.hide()
	back_room_floor.private_door_requested.connect(func(): back_room_floor.approach_private_door())
	back_room_floor.private_door_reached.connect(exit_back_room)
	back_room_floor.station_reached.connect(open_private_station)
	back_room_floor.recovery_reached.connect(func(): recovery_view.open(); apply_visibility())
	recovery_view = preload("res://scripts/recovery_view.gd").new()
	recovery_view.sim = sim
	recovery_view.z_index = 32
	add_child(recovery_view)
	recovery_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	recovery_view.hide()
	recovery_view.leave_requested.connect(func(): recovery_view.hide(); apply_visibility())
	recovery_view.changed.connect(refresh)
	resume_private = add_button(self, "Resume active game", resume_private_game)
	resume_private.z_index = 31
	resume_private.hide()
	room_tools = HBoxContainer.new()
	room_tools.z_index = 31
	add_child(room_tools)
	add_button(room_tools, "Pause / Play", toggle_pause)
	var room_menu := MenuButton.new()
	room_menu.text = "Menu"
	room_menu.custom_minimum_size = Vector2(72, 44)
	room_tools.add_child(room_menu)
	room_menu.get_popup().add_item("Save", 0)
	room_menu.get_popup().add_item("Load", 1)
	room_menu.get_popup().add_item("Transfer personal wallet to casino", 5)
	room_menu.get_popup().id_pressed.connect(global_action)
	room_tools.hide()
	floor_view.private_door_requested.connect(walk_to_private_door)
	floor_view.private_door_reached.connect(enter_back_room)
	get_viewport().size_changed.connect(queue_viewport_sync)
	visible_viewport.connect_web(queue_viewport_sync)
	queue_viewport_sync()
	milestone_notice = MilestoneNotice.new()
	add_child(milestone_notice)
	sim.milestone_reached.connect(on_milestone)
	bind_optional_events()
	if OS.is_debug_build():
		developer_panel = DeveloperPanel.new(sim)
		add_child(developer_panel)
		developer_panel.changed.connect(refresh)
		developer_panel.speed_requested.connect(set_dev_speed)
		developer_panel.session_reset.connect(reset_dev_speed)
		developer_panel.visibility_changed.connect(refresh)
		developer_panel.hide()
	layout_ui()
	refresh()
	show_new_game_setup(true)

func _exit_tree() -> void:
	visible_viewport.disconnect_web()

func queue_viewport_sync() -> void:
	if viewport_sync_pending: return
	viewport_sync_pending = true
	call_deferred("sync_visible_viewport")

func sync_visible_viewport() -> void:
	viewport_sync_pending = false
	var measurement := visible_viewport.measure(get_window())
	if measurement.dimensions == viewport_dimensions and measurement.insets == viewport_insets: return
	layout_ui()

func layout_ui() -> void:
	if not is_instance_valid(bottom_nav): return
	viewport_layout_count += 1
	var measurement := visible_viewport.measure(get_window())
	viewport_dimensions = measurement.dimensions
	viewport_insets = measurement.insets
	var dimensions := viewport_dimensions
	if get_window().content_scale_size != Vector2i(dimensions):
		get_window().content_scale_size = Vector2i(dimensions)
	var w := dimensions.x
	var h := dimensions.y
	var landscape := w > h and h < 600
	mobile = w < 1180 or h < 650
	responsive_state = "desktop" if not mobile else "mobile landscape" if landscape else "mobile portrait" if w < h else "compact"
	floor_view.configure_view(mobile, landscape)
	if is_instance_valid(back_room_floor):
		back_room_floor.configure_view(mobile, landscape)
		back_room_floor.mobile_viewport = Rect2(Vector2.ZERO, dimensions)
	presentation_shell.layout(self, dimensions)
	apply_visibility()
	if is_instance_valid(developer_panel): developer_panel._layout()
	layout_dialog()

func layout_dialog() -> void:
	if not is_instance_valid(modal): return
	var dimensions := Vector2(get_window().content_scale_size)
	# Containers may briefly expand before wrapped labels finish measuring.
	# Reapply the viewport width after minimum-size changes, then center actual size.
	var usable := dimensions - Vector2(viewport_insets.x + viewport_insets.z, viewport_insets.y + viewport_insets.w)
	modal.size = Vector2(minf(660, usable.x - 24), usable.y - 24)
	modal.position = Vector2(viewport_insets.x + maxf(12, (usable.x - modal.size.x) / 2), viewport_insets.y + 12)
	for child in get_children():
		if child.has_meta("modal_shade"): child.size = dimensions

# Interaction invariants are applied on every refresh and viewport resize.
# Future floor-targeting modes should participate here, rather than patch panes.
func requires_floor_targeting() -> bool:
	return building or moving > 0

func normalize_interaction_ui() -> void:
	if moving > 0: building = true
	if requires_floor_targeting():
		visitor = false
		mobile_pane = "floor"
		context_expanded = false

func transition_pane(value: String) -> void:
	# Explicit navigation away ends placement; Floor preserves its preview.
	if value != "floor" and requires_floor_targeting():
		building = false
		moving = -1
		floor_view.building = false
	mobile_pane = value
	if value == "floor": table_options = false

func cancel_placement() -> void:
	floor_view.placement_target = Vector2(INF, INF)
	building = false
	moving = -1
	transition_pane("floor")
	refresh()

func apply_visibility() -> void:
	normalize_interaction_ui()
	var at_table := private_play or sim.joined >= 0 or not sim.owner_play.is_empty()
	if is_instance_valid(back_room_floor):
		back_room_floor.visible = in_back_room and not private_play and not recovery_view.visible
		resume_private.visible = back_room_floor.visible and sim.back_room.busy()
		room_tools.visible = back_room_floor.visible
		room_tools.position = Vector2(maxf(12, size.x - 290), 12)
		room_tools.size = Vector2(278, 44)
		resume_private.position = Vector2(12, 64 if size.x < 600 else 12)
		resume_private.size = Vector2(210, 44)
	var management_hidden := at_table or in_back_room
	var is_craps: bool = at_table and game_view.sim.owner_play.is_empty() and game_view.sim.table_kind(game_view.current_table()) == "craps"
	if at_table and play_context.is_empty(): remember_management_context()
	game_view.z_index = 33 if private_play else 0
	game_view.visible = at_table
	table_scroll.visible = false
	felt.visible = is_craps
	play_return.visible = false
	floor_view.visible = not at_table and not in_back_room
	nav_rail.visible = not mobile and not management_hidden
	bottom_nav.visible = mobile and not management_hidden and not requires_floor_targeting()
	side_panel.visible = not management_hidden and mobile_pane == "manage"
	events_panel.visible = not management_hidden and mobile_pane == "log"
	inspector_panel.visible = not management_hidden and inspector_open and mobile_pane == "table"
	floor_actions.visible = not management_hidden and mobile_pane == "floor"
	floor_fit.visible = not visitor and not building
	floor_fit.text = "Fit" if floor_view.close_view else "Closer"
	floor_walk_button.visible = not building
	floor_walk_button.text = "Manage" if visitor else "Walk"
	floor_join_button.visible = not building
	floor_join_button.disabled = sim.get_table(selected).is_empty()
	cancel_placement_button.visible = building
	rotate_button.visible = building
	confirm_placement_button.visible = mobile and building
	confirm_placement_button.disabled = not floor_view.placement_target.is_finite() or not sim.can_place(floor_view.placement_target, floor_view.rotated, moving, build_kind)
	confirm_placement_button.text = "Move" if moving > 0 else "Place"
	floor_join_button.text = "Join" if visitor and can_join() else "Inspect"
	mode_hint.visible = building
	mode_hint.text = ("Choose a cell, then Move" if moving > 0 else "Choose a cell, then Place") + " | Drag to pan" if mobile else "Click to place | R to rotate | Esc to cancel"
	for button in nav_rail.get_children():
		var target: String = button.get_meta("shell_page", "")
		button.button_pressed = (target == mobile_pane) or (mobile_pane == "table" and target == page) or (target == "build" and building)
	inspector_heading.text = "GUEST" if page == "guest" else "SELECTED OBJECT" if page == "table" else page.to_upper()
	inspector_expand.visible = page in ["table", "guest"]
	inspector_expand.text = "Summary" if context_expanded else "Details"
	alert_button.text = "%d" % (sim.incidents.size() + sim.optional_events.active.size()) if mobile else "Alerts %d" % (sim.incidents.size() + sim.optional_events.active.size())
	presentation_shell.update_desktop_state(self)
	if not mobile: floor_view.inspector_occlusion = inspector_panel.get_rect() if inspector_panel.visible and page in ["table", "guest"] and sim.joined < 0 else Rect2()

func close_context() -> void:
	inspector_open = false
	context_expanded = false
	transition_pane("floor")
	refresh()

func navigate_shell(value: String) -> void:
	if value in ["floor", "manage", "log"]:
		inspector_open = false
		transition_pane(value)
		refresh()
	else:
		open_page(value)

func open_page(value: String) -> void:
	if value == "finance" and page != "finance":
		finance_section = ""
		finance_advanced = false
	page = value
	inspector_open = true
	context_expanded = value not in ["table", "guest"]
	if value == "table": selected_guest = -1
	transition_pane("table")
	inspector_scroll.scroll_vertical = 0
	refresh()

func switch_mobile(value: String) -> void:
	if rolling > 0: return
	if value == "floor" and sim.joined >= 0: leave_table()
	transition_pane(value)
	inspector_open = value == "table"
	context_expanded = false
	if value == "table":
		page = "guest" if selected_guest >= 0 else "table"
		inspector_scroll.scroll_vertical = 0
	refresh()

func can_join() -> bool:
	var table := sim.get_table(selected)
	return not table.is_empty() and sim.ready_for_play(table) and sim.player.distance_to(sim.bounds(table).get_center()) <= 165


func style(bg: Color, border: Color = Color("45413a")) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(8)
	box.content_margin_left = 16
	box.content_margin_right = 16
	box.content_margin_top = 16
	box.content_margin_bottom = 16
	return box

func panel_at(at: Vector2, dimensions: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.position = at
	panel.size = dimensions
	panel.add_theme_stylebox_override("panel", PitBoss.box())
	add_child(panel)
	return panel

func label_at(at: Vector2, text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.position = at
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	add_child(label)
	return label

func add_label(parent: Node, text: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var label: Label = render_node(parent, "label", func(): return Label.new())
	label.text = text
	label.tooltip_text = ""
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	if label.get_theme_font_size("font_size") != font_size: label.add_theme_font_size_override("font_size", font_size)
	if label.get_theme_color("font_color") != color: label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	return label

func add_button(parent: Node, title: String, callback: Callable, disabled: bool = false) -> Button:
	var button: Button = render_node(parent, "button", func(): return Button.new())
	button.text = title
	PitBoss.decorate(button, title)
	button.disabled = disabled
	for connection in button.get_signal_connection_list("pressed"):
		button.disconnect("pressed", connection.callable)
	button.pressed.connect(callback)
	button.tooltip_text = ""
	button.set_meta("render_toned", false)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.clip_text = true
	if OS.is_debug_build():
		button.add_to_group("debug_buttons")
	return button

func button_tone(button: Button, tone: String) -> void:
	button.set_meta("render_toned", true)
	if str(button.get_meta("button_tone", "")) == tone: return
	button.set_meta("button_tone", tone)
	var color := Color("544624") if tone == "primary" else Color("72202a")
	for state in ["normal", "hover", "pressed"]:
		var skin := style(color.lightened(0.1) if state == "hover" else color, GOLD.darkened(0.3) if tone == "primary" else Color("72424b"))
		skin.content_margin_top = 10
		skin.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, skin)

func button_at(at: Vector2, dimensions: Vector2, title: String, callback: Callable) -> Button:
	var button := add_button(self, title, callback)
	button.position = at
	button.size = dimensions
	return button

func add_gap(parent: Node, height: float) -> void:
	var gap: Control = render_node(parent, "gap", func(): return Control.new())
	gap.custom_minimum_size.y = height

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func on_milestone(event: Dictionary) -> void:
	var notice := event.duplicate(true)
	notice.dev = OS.is_debug_build() and is_instance_valid(developer_panel) and (developer_panel.actions.used or not sim.debug_forced_unlocks.is_empty())
	milestone_notice.enqueue(notice)

func _process(delta: float) -> void:
	milestone_notice.enabled = modal == null and not requires_floor_targeting() and sim.joined < 0 and sim.owner_play.is_empty() and not (is_instance_valid(developer_panel) and developer_panel.visible)
	animate_treasury(delta)
	if OS.has_feature("web") and OS.is_debug_build():
		debug_snapshot_timer += delta
		if debug_snapshot_timer >= CasinoTuning.DEBUG_SNAPSHOT_SECONDS:
			debug_snapshot_timer = 0
			publish_debug()
	floor_view.set_presentation_speed(speed if modal == null else 0)
	if modal != null:
		return
	if not OS.is_debug_build() and (speed > 4 or previous_speed > 4): reset_dev_speed()
	if speed > 4 and OS.is_debug_build():
		advance_dev_time(delta)
	elif speed > 0:
		dev_time_pending = 0
		sim.move_guests(delta * speed)
		tick += delta * speed
		while tick >= 1:
			tick -= 1
			sim.step()
			floor_view.presentation_step()
	if rolling > 0:
		rolling -= delta
		if rolling <= 0:
			active_roll_table = -1
			refresh()
	refresh_timer += delta
	if refresh_timer >= 1:
		refresh_timer = 0
		refresh(false)

func set_dev_speed(multiplier: int) -> void:
	# Guard the action as well as the controls; release cannot enter this path.
	if not OS.is_debug_build() or not is_instance_valid(developer_panel): return
	if multiplier not in [1, 4, 100, 1000]: return
	speed = multiplier
	previous_speed = multiplier
	dev_time_pending = 0
	refresh()

func reset_dev_speed() -> void:
	speed = 1
	previous_speed = 1
	dev_time_pending = 0

func advance_dev_time(delta: float) -> void:
	if not OS.is_debug_build() or speed not in [100, 1000]: return
	# Bounded catch-up: retain a short backlog but never freeze the UI chasing it.
	dev_time_pending = minf(DEV_MAX_PENDING_SECONDS, dev_time_pending + delta * speed)
	var deadline := Time.get_ticks_usec() + DEV_FRAME_BUDGET_USEC
	while dev_time_pending >= DEV_TIME_STEP and Time.get_ticks_usec() < deadline:
		var amount := minf(DEV_TIME_STEP, 1.0 - tick)
		sim.move_guests(amount)
		tick += amount
		dev_time_pending -= amount
		if tick >= 1.0:
			tick = 0
			sim.step()

func global_action(id: int) -> void:
	match id:
		0: save_game()
		1: load_game()
		2: show_help()
		3: confirm_reset()
		4: toggle_dev_panel()
		5: show_wallet_transfer()

func toggle_dev_panel() -> void:
	if not OS.is_debug_build() or not is_instance_valid(developer_panel) or modal != null: return
	developer_panel.visible = not developer_panel.visible
	refresh()

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build() or not is_instance_valid(developer_panel): return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F10:
		if modal != null: return
		toggle_dev_panel()
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if is_instance_valid(developer_panel) and developer_panel.visible: return
	if not event is InputEventKey or not event.pressed or event.echo or modal != null:
		return
	if event.keycode == KEY_SPACE:
		toggle_pause()
	if event.keycode == KEY_R and building:
		floor_view.rotated = not floor_view.rotated
	if event.keycode == KEY_ESCAPE:
		if building:
			cancel_placement()
		elif private_play or sim.joined >= 0 or not sim.owner_play.is_empty():
			leave_table()
		else: close_context()
		refresh()
	if event.keycode == KEY_E and visitor and sim.joined < 0 and not in_back_room:
		join_table()

func money(amount: float) -> String:
	return FinancialText.cash(amount, 0)

func compact_money(amount: float) -> String:
	if absf(amount) < 10000: return money(amount)
	for unit in [{"scale": 1.0e12, "suffix": "T"}, {"scale": 1.0e9, "suffix": "B"}, {"scale": 1.0e6, "suffix": "M"}, {"scale": 1.0e3, "suffix": "K"}]:
		if absf(amount) >= float(unit.scale):
			return "%s$%.1f%s" % ["-" if amount < 0 else "", absf(amount) / float(unit.scale), unit.suffix]
	return money(amount)

func reset_treasury_display() -> void:
	displayed_cash = sim.cash
	treasury_target = sim.cash
	treasury_flash = 0.0
	treasury_direction = 0.0

func animate_treasury(delta: float) -> void:
	if not is_instance_valid(stats): return
	if treasury_target != sim.cash:
		treasury_direction = signf(sim.cash - treasury_target)
		treasury_target = sim.cash
		treasury_flash = CasinoTuning.TREASURY_FLASH_SECONDS
	displayed_cash = lerpf(displayed_cash, treasury_target, 1.0 - exp(-CasinoTuning.TREASURY_SMOOTHING * delta))
	if absf(displayed_cash - treasury_target) < 0.005: displayed_cash = treasury_target
	treasury_flash = maxf(0, treasury_flash - delta)
	render_treasury()

func render_treasury() -> void:
	stats.text = preload("res://presentation/mobile_management.gd").short_money(displayed_cash) if mobile else compact_money(displayed_cash) if absf(displayed_cash) >= 1000000 else FinancialText.cash(displayed_cash, 0)
	hud_summary.text = preload("res://presentation/mobile_management.gd").short_money(sim.owner_bankroll) if mobile else compact_money(sim.owner_bankroll)
	guest_metric.tooltip_text = "Guests on the floor / ready gaming seats. Visits and waiting are managed by the existing simulation."
	guest_metric.text = "%d" % sim.guests.size() if mobile else "%d / %d" % [sim.guests.size(), presentation_shell.capacity]
	reputation_metric.text = "%.0f%%" % sim.reputation
	hud_summary.tooltip_text = "Personal gambling wallet, separate from casino cash: " + money(sim.owner_bankroll)
	if sim.joined >= 0 or not sim.owner_play.is_empty():
		stats.text = "Casino Cash " + compact_money(displayed_cash)
		hud_summary.text = ("Wallet " if get_window().content_scale_size.x < 360 else "Personal Wallet ") + compact_money(sim.owner_bankroll)
	stats.tooltip_text = "Treasury display animates toward actual cash: %s. Gambling popups show settled net house results." % FinancialText.cash(sim.cash)
	var change_color := TEAL if treasury_direction >= 0 else Color("ff9486")
	stats.add_theme_color_override("font_color", TEXT.lerp(change_color, 0.45 * treasury_flash / CasinoTuning.TREASURY_FLASH_SECONDS))

func render_asset_financial_activity(parent: Node, asset_id: int = -1, limit: int = 2) -> void:
	var shown := 0
	for event in sim.recent_financial_events:
		if asset_id >= 0 and int(event.asset_id) != asset_id: continue
		var game_name := str(Games.NAMES[event.game]).replace("’", "'")
		var text := "HOUSE %s | %s #%d%s" % [FinancialText.house_result(float(event.amount)), game_name, event.asset_id, " | visitor" if event.actor == "visitor" else ""]
		add_label(parent, text, 12, TEAL if float(event.amount) > 0 else (MUTED if float(event.amount) == 0 else Color("ff9486")))
		shown += 1
		if shown >= limit: break

func refresh(structural: bool = true) -> void:
	floor_view.set_presentation_speed(speed if modal == null else 0)
	normalize_interaction_ui()
	if not sim.optional_events.action_requested.is_connected(on_optional_event_action): bind_optional_events()
	event_cards.refresh(sim)
	objective_cards.refresh(sim)
	var optional_count := sim.optional_events.active.size() + sim.optional_objectives.active.size()
	event_nav.text = "More"
	var event_category := "" if sim.optional_events.active.is_empty() else str(sim.optional_events.DEFINITIONS[sim.optional_events.active[0].type].category)
	event_nav.tooltip_text = "Optional goals, events and House Activity" if event_category.is_empty() else event_category + " event available in Log"
	event_nav.add_theme_color_override("font_color", Color("ff9486") if event_category == "EMERGENCY" else GOLD if event_category == "MANAGEMENT" else TEAL if event_category == "OPPORTUNITY" else TEXT)
	var dev_active: bool = OS.is_debug_build() and is_instance_valid(developer_panel) and (developer_panel.visible or developer_panel.actions.used or speed > 4 or previous_speed > 4)
	subtitle.text = ("DEV MODE | " if dev_active else "") + "CASINO TYCOON / " + BuildInfo.VERSION
	render_treasury()
	var time_state := "Paused" if speed == 0 else ("DEV %dx" % speed if speed > 4 else "%dx speed" % speed)
	if dev_active and speed <= 4: time_state = "DEV MODE - " + time_state
	status.text = "Day %d   %02d:%02d
%s" % [sim.day, sim.minute / 60, sim.minute % 60, time_state]
	mobile_speed.text = "Stop" if speed == 0 else "%dx" % speed
	if is_instance_valid(mobile_dev): mobile_dev.add_theme_color_override("font_color", GOLD if speed > 4 else TEXT)
	if mobile: status.text = "DEV %dx" % speed if speed > 4 else "D%d %02d:%02d" % [sim.day, sim.minute / 60, sim.minute % 60]
	else: status.text = "Day %d\n%02d:%02d" % [sim.day, sim.minute / 60, sim.minute % 60]
	status.tooltip_text = "Financial performance and operating costs are available in Finance."
	if not structural and not visitor and refreshed_elapsed == sim.elapsed: return
	refreshed_elapsed = sim.elapsed
	retained_render = true
	render_cursors.clear()
	render_cursors[objective] = 0
	render_cursors[feed] = 0
	render_progression(objective, true)
	doors_button.text = "Close casino" if sim.opened else "Open casino"
	build_button.text = "Cancel placement" if building else "+ Build games..."
	walk_button.text = "Manage casino" if visitor else "Walk the floor"
	pause_button.text = "Play" if speed == 0 else "Pause"
	floor_view.visitor_mode = visitor
	floor_view.building = building
	if not building: floor_view.placement_target = Vector2(INF, INF)
	floor_view.build_kind = build_kind
	floor_view.build_slot_profile = build_slot_profile
	floor_view.moving_id = moving
	game_view.paused = speed == 0
	floor_view.selected = selected
	floor_view.selected_guest = selected_guest
	mode_hint.text = "Click to place | R to rotate | Esc to cancel" if building else ("Tap to walk | tap a table to approach | E or Join to play" if visitor else "Select a table or guest to inspect | build and staff to expand")
	var layout_key := [page, mobile_pane, visitor, building, moving, sim.joined, modal, inspector_open, context_expanded, table_options, not sim.optional_events.active.is_empty(), not sim.owner_play.is_empty(), not sim.staff.is_empty(), in_back_room]
	if layout_key != layout_identity:
		layout_identity = layout_key
		layout_ui()
	else:
		apply_visibility()
	floor_view.invalidate_presentation()
	if not private_play: felt.chip = game_view.bet if game_view.visible else chip_value
	felt.locked = rolling > 0 or speed == 0 or table_options or modal != null
	felt.queue_redraw()
	add_label(feed, "HOUSE ACTIVITY", 12, MUTED)
	if sim.house_activity.is_empty(): add_label(feed, "Your next important casino event will appear here.", 13, MUTED)
	for i in range(mini(6 if mobile else 8, sim.house_activity.size())):
		render_activity_row(feed, str(sim.house_activity[i]), i == 0)
	var scroll: ScrollContainer = inspector.get_parent()
	var scroll_position := scroll.scroll_vertical
	var identity := [page, selected, selected_guest, sim.joined, asset_details, finance_section, responsive_state, context_expanded]
	var inspector_changed := identity != inspector_identity
	if inspector_changed:
		inspector_identity = identity
		clear(inspector)
	render_cursors[inspector] = 0
	if sim.joined >= 0 or not sim.owner_play.is_empty():
		finish_render()
		return
	if sim.joined >= 0 and page == "table":
		if sim.table_kind(sim.get_table(sim.joined)) == "craps": render_craps()
	elif page == "development":
		render_development()
	elif page == "build":
		render_build()
	elif page == "staff":
		render_staff()
	elif page == "finance":
		render_finance()
	elif page == "amenities":
		render_amenities()
	elif page == "bar":
		render_bar_menu()
	elif page == "incidents":
		render_incidents()
	elif page == "guests":
		render_guest_directory()
	elif page == "guest":
		render_guest()
	else:
		render_table()
	finish_render()
	if inspector_changed: call_deferred("layout_ui")
	scroll.set_deferred("scroll_vertical", scroll_position)

func next_unlock() -> Dictionary:
	for target in sim.progression_targets():
		if not sim.unlocked(str(target.id)): return target
	return {}

func unlock_requirements(target: Dictionary) -> Array:
	if target.id == "blackjack":
		var goal: Dictionary = CasinoTuning.BLACKJACK_REQUIREMENTS
		return [
			{"name": "Casino Rating", "value": sim.casino_rating, "goal": goal.rating, "unit": "rating"},
			{"name": "Floor development", "value": sim.gaming_development(true), "goal": goal.development, "unit": "points"},
			{"name": "Gaming seats", "value": sim.usable_gaming_capacity(), "goal": goal.capacity, "unit": "seats"},
			{"name": "Gaming volume", "value": sim.guest_handle, "goal": goal.handle, "unit": "cash"},
			{"name": "Guests served", "value": sim.guests_served, "goal": goal.guests, "unit": "guests"},
			{"name": "Operating reserve", "value": sim.development_cash(), "goal": goal.cash, "unit": "cash"},
		]
	var requirements := [{"name": "Casino Rating", "value": sim.casino_rating, "goal": target.rating, "unit": "rating"}]
	if target.has("handle"): requirements.append({"name": "Gaming volume", "value": sim.guest_handle, "goal": target.handle, "unit": "cash"})
	if not str(target.id).begins_with("slot:") and not sim.blackjack_unlocked:
		requirements.append({"name": "Blackjack readiness", "value": 0, "goal": 1, "unit": "readiness"})
	return requirements

func requirement_text(requirement: Dictionary) -> String:
	if requirement.unit == "cash": return "%s / %s" % [money(requirement.value), money(requirement.goal)]
	if requirement.unit == "readiness": return "Develop your first table-game operation"
	return "%s / %s" % [String.num(float(requirement.value), 1 if requirement.unit == "rating" else 0), String.num(float(requirement.goal), 0)]

func render_progression(parent: Node, compact: bool = false) -> void:
	var target := next_unlock()
	add_label(parent, "NEXT UNLOCK", 11, MUTED)
	if target.is_empty():
		add_label(parent, "Keep growing", 17, GOLD)
		add_label(parent, "All current unlocks earned.", 12, MUTED)
		return
	add_label(parent, str(target.name).replace("’", "'"), 17 if compact else 25, GOLD)
	var requirements := unlock_requirements(target)
	var pending := requirements.filter(func(item): return float(item.value) < float(item.goal))
	if compact:
		add_label(parent, "%d of %d requirements complete" % [requirements.size() - pending.size(), requirements.size()], 12, MUTED)
		for requirement in pending.slice(0, 2):
			var item := add_label(parent, "%s
%s" % [requirement.name, requirement_text(requirement)], 12, TEXT)
			item.tooltip_text = "Remaining requirement for " + str(target.name)
		return
	for requirement in requirements:
		var complete := float(requirement.value) >= float(requirement.goal)
		var line := row(parent)
		var label := add_label(line, str(requirement.name), 14, TEXT)
		label.tooltip_text = requirement_text(requirement)
		var value := add_label(line, "Complete" if complete else requirement_text(requirement), 13, TEAL if complete else GOLD)
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value.tooltip_text = requirement_text(requirement)
		if not complete:
			var bar: ProgressBar = render_node(parent, "progress", func(): return ProgressBar.new())
			bar.value = clampf(float(requirement.value) / maxf(1, float(requirement.goal)) * 100, 0, 100)
			bar.show_percentage = false
			bar.custom_minimum_size.y = 5
			var background := StyleBoxFlat.new()
			background.bg_color = Color("203342")
			background.set_corner_radius_all(2)
			bar.add_theme_stylebox_override("background", background)
			var fill := StyleBoxFlat.new()
			fill.bg_color = GOLD.darkened(0.2)
			fill.set_corner_radius_all(2)
			bar.add_theme_stylebox_override("fill", fill)
			add_label(parent, "Earn access through your property and guest business. Unlocking never forces a purchase.", 12, MUTED)

func render_traffic() -> void:
	var traffic := sim.traffic_snapshot()
	add_label(inspector, "GUEST DEMAND", 12, GOLD)
	finance_short_metric(inspector, "Guest positions reserved", "%d / %d" % [traffic.occupied, traffic.positions])
	finance_short_metric(inspector, "Looking for a game", str(traffic.waiting))
	add_label(inspector, "A waiting guest is demand, not an instruction to spend. Protect your reserve.", 12, MUTED)
	add_button(inspector, "Hide traffic detail" if traffic_details else "Traffic & departure detail", func(): traffic_details = not traffic_details; refresh())
	if not traffic_details: return
	var totals: Dictionary = sim.traffic_totals
	finance_short_metric(inspector, "Traffic period", str(traffic.cycle) if sim.opened else "Closed")
	finance_short_metric(inspector, "Guests on floor", str(traffic.active))
	finance_short_metric(inspector, "Arrivals / visits with unmet demand", "%d / %d" % [totals.arrivals, totals.unmet_visits])
	if int(totals.position_minutes) > 0:
		finance_short_metric(inspector, "Average guest position occupancy", "%.0f%%" % (float(totals.occupied_minutes) / float(totals.position_minutes) * 100))
	finance_short_metric(inspector, "Long-wait departures", str(totals.severe_departures))
	finance_short_metric(inspector, "Arrival opportunities deferred", str(totals.deferred_attempts))
	add_label(inspector, "Deferred opportunities are not spawned guests or lost sales. Mild waiting does not harm reputation.", 12, MUTED)
	var reasons: Dictionary = totals.departures
	for item in [{"key": "capacity", "name": "No room after retrying"}, {"key": "affordability", "name": "No affordable staffed game"}, {"key": "service", "name": "Poor drink service"}, {"key": "closed", "name": "Casino closing"}, {"key": "visit", "name": "Other visit endings"}]:
		if int(reasons[item.key]) > 0: finance_short_metric(inspector, item.name, str(reasons[item.key]))

func render_development() -> void:
	add_label(inspector, "CASINO DEVELOPMENT", 12, MUTED)
	add_label(inspector, "Casino Rating %.1f" % sim.casino_rating, 25, TEXT)
	add_label(inspector, "Level %d - %s" % [sim.stars(), CasinoTuning.STAR_NAMES[sim.stars() - 1]], 14, GOLD)
	add_label(inspector, "Property quality and real guest business develop your casino. Reputation measures how guests feel.", 13, MUTED)
	add_label(inspector, "Guest reputation  %.0f%%" % sim.reputation, 15, TEAL)
	var momentum_row := add_label(inspector, "Momentum: " + sim.momentum.band(), 15, TEAL)
	momentum_row.tooltip_text = sim.momentum.detail()
	add_button(inspector, "Hide momentum details" if momentum_expanded else "Momentum details", func():
		momentum_expanded = not momentum_expanded
		refresh())
	var explanation := add_label(inspector, sim.momentum.detail(), 13, MUTED)
	explanation.visible = momentum_expanded
	render_traffic()
	add_gap(inspector, 12)
	render_progression(inspector)
	add_gap(inspector, 12)
	add_label(inspector, "FLOOR EXPANSION", 12, MUTED)
	render_expansion()

func render_expansion() -> void:
	var room := sim.floor_rect()
	finance_short_metric(inspector, "Floor size", "%.0f x %.0f" % [room.size.x, room.size.y])
	finance_short_metric(inspector, "Property overhead", "%s/hr" % FinancialText.cash(sim.property_upkeep_rate()))
	add_label(inspector, "Full-edge columns add %.0f width; rows add %.0f depth. Assets stay in place. Empty space still costs upkeep, including while closed." % [CasinoTuning.FLOOR_CHUNK_WIDTH, CasinoTuning.FLOOR_CHUNK_HEIGHT], 13, MUTED)
	if not sim.unlocked("expansion"):
		add_label(inspector, "Directional purchases open at Rating 35.", 14, MUTED)
		return
	for direction in ["left", "right", "bottom"]:
		var quote := sim.expansion_quote(direction)
		add_gap(inspector, 8)
		add_label(inspector, direction.capitalize() + (" row" if direction == "bottom" else " column"), 17, GOLD)
		if not quote.allowed:
			add_label(inspector, "Practical navigation / property size limit reached in this direction.", 13, MUTED)
			continue
		finance_short_metric(inspector, "Added area (floor units squared)", "%.0f" % float(quote.added_area))
		finance_short_metric(inspector, "Capital purchase", FinancialText.cash(float(quote.cost), 0))
		finance_short_metric(inspector, "Added property overhead", "%s/hr" % FinancialText.cash(float(quote.upkeep_added)))
		finance_short_metric(inspector, "Resulting property overhead", "%s/hr" % FinancialText.cash(sim.property_upkeep_rate() + float(quote.upkeep_added)))
		add_button(inspector, "Purchase " + direction, func(): sim.purchase_expansion(direction); refresh(), sim.cash < float(quote.cost))

func activity_presentation(message: String) -> Dictionary:
	var category := "CASINO"
	var body := message.replace("’", "'").replace(" · ", " - ")
	if body.begins_with("CAGE - "):
		category = "CAGE"
		body = body.trim_prefix("CAGE - ").replace(" | VIP", " (VIP)")
	elif body.begins_with("Unlocked:"):
		category = "UNLOCK"
		body = body.trim_prefix("Unlocked: ").split(".")[0] + " is now available"
	elif body.begins_with("DEVELOPMENT - "):
		category = "DEVELOPMENT"
		body = body.trim_prefix("DEVELOPMENT - ").replace("stars", "development levels")
	elif body.begins_with("MILESTONE - "):
		category = "MILESTONE"
		body = body.trim_prefix("MILESTONE - ")
	elif body.begins_with("DEMAND - "):
		category = "DEMAND"
		body = body.trim_prefix("DEMAND - ")
	elif body.begins_with("RESERVE - "):
		category = "RESERVE"
		body = body.trim_prefix("RESERVE - ")
	elif "House won" in body or "House lost" in body:
		category = body.split(" #")[0]
		body = body.split(" - ", true, 1)[-1]
	elif "resolved for" in body or "halted:" in body:
		category = "BREAKDOWN" if "halted:" in body else "REPAIR" if "repair" in body.to_lower() or "rail" in body.to_lower() else "SERVICE"
		body = body.replace(" - repair needed resolved for", " repaired for").replace("Table ", "Game ")
	elif "built" in body or "Purchased:" in body or "Sold for" in body: category = "PROPERTY"
	elif "hired" in body or "dealers" in body or "Staff" in body: category = "STAFF"
	elif "VIP" in body: category = "VIP"
	elif "drinks" in body or "Complaint" in body: category = "SERVICE"
	elif body.begins_with("DEV:"): category = "DEV"
	elif body.begins_with("Normal:") or body.begins_with("Easy:"):
		category = "WELCOME"
		body = "Your casino is ready. Open the doors to welcome guests."
	var amounts := RegEx.new()
	amounts.compile("\\$[0-9]+(?:\\.[0-9]+)?")
	var matches := amounts.search_all(body)
	matches.reverse()
	for match in matches:
		body = body.substr(0, match.get_start()) + FinancialText.cash(float(match.get_string().trim_prefix("$")), 0 if is_equal_approx(fmod(float(match.get_string().trim_prefix("$")), 1), 0) else 2) + body.substr(match.get_end())
	return {"category": category, "body": body}

func render_activity_row(parent: Node, message: String, latest: bool) -> void:
	var event := activity_presentation(message)
	if not mobile:
		var card: PanelContainer = render_node(parent, "activity_card", func(): return preload("res://presentation/components/activity_card.tscn").instantiate())
		card.configure(event, latest)
		# Its authored children belong to the component, not the controller cursor.
		render_cursors.erase(card)
		return
	var line := row(parent)
	line.add_theme_constant_override("separation", 10)
	var category := add_label(line, event.category, 11, GOLD if latest else MUTED)
	category.custom_minimum_size.x = 84
	category.size_flags_horizontal = SIZE_FILL
	add_label(line, event.body, 13, TEXT if latest else MUTED)

func render_build() -> void:
	if not mobile:
		render_desktop_build()
		return
	# Mobile catalog is a retained horizontal palette owned by the shell.
	return

func render_slot_catalog() -> void:
	add_label(inspector, "SLOT MACHINES", 16, GOLD)
	add_label(inspector, "Add seats, improve machines, or protect your reserve.", 13, MUTED)
	for id in CasinoTuning.SLOT_PROFILES:
		var profile := CasinoTuning.slot_profile(id)
		var available: bool = sim.slot_unlocked(id)
		add_gap(inspector, 8)
		add_label(inspector, str(profile.name), 18, TEXT)
		add_label(inspector, "%s stakes   %s volatility" % [money(profile.denominations.front()) + "-" + money(profile.maximum), profile.volatility], 13, MUTED)
		if not available:
			add_label(inspector, "Requires Casino Rating %.0f and %s guest gaming volume" % [profile.unlock_rating, money(profile.unlock_handle)], 12, GOLD)
		add_button(inspector, "Place machine - " + money(profile.cost) if available else "Locked", func(): build_kind = "slots"; build_slot_profile = id; toggle_build(), not available or sim.cash < float(profile.cost))
		add_button(inspector, "Hide specifications" if expanded_slot_details == id else "Specifications & running costs", func(): expanded_slot_details = "" if expanded_slot_details == id else id; refresh())
		if expanded_slot_details == id:
			render_purchase_readiness(inspector, "slots", id)
			add_label(inspector, "RTP %.2f%%   House edge %.2f%%
Appeal %.2fx   Development %.0f
Upkeep %s per hour
Repair %s
Daily failure chance %.1f%% after %d operating days
Suggested reserve %s
Maximum total return %s" % [profile.rtp * 100, profile.house_edge * 100, profile.appeal, profile.development, FinancialText.cash(profile.overhead), money(profile.repair_cost), profile.repair_chance * 100, int(profile.repair_grace) / 1440, money(profile.reserve), money(profile.top_return * profile.maximum)], 13, MUTED)

func render_table() -> void:
	if not context_expanded:
		render_context_summary()
		return
	add_label(inspector, "ASSET INSPECTOR", 12, MUTED)
	var table := sim.get_table(selected)
	if table.is_empty():
		add_label(inspector, "Room for your next game", 24)
		add_label(inspector, sim.onboarding_text(), 15, MUTED)
		return
	add_label(inspector, "%s %02d" % [sim.asset_name(table), selected], 26)
	add_label(inspector, sim.table_status(table), 14, TEAL if sim.ready_for_play(table) else GOLD)
	var kind := sim.table_kind(table)
	var guests := sim.seated(selected)
	add_label(inspector, "Gaming Win", 13, MUTED)
	var performance := sim.asset_performance(table)
	var gaming_win := float(performance.gaming_win)
	var win_label := finance_value(inspector, FinancialText.house_result(gaming_win), 30, finance_color(gaming_win))
	win_label.tooltip_text = "All participants; excludes pending stakes. Settled gaming win before expenses: " + FinancialText.cash(gaming_win)
	add_label(inspector, "Before operating expenses", 12, MUTED)
	add_gap(inspector, 8)
	if guests.is_empty():
		var reservations := sim.reserved_guests(selected)
		if sim.joined == selected: add_label(inspector, "Occupied by you", 15, TEXT)
		elif not reservations.is_empty(): add_label(inspector, "Reserved - guest on the way\n" + ", ".join(reservations.map(func(guest): return str(guest.name))), 15, TEXT)
		else: add_label(inspector, "Waiting for guests" if sim.ready_for_play(table) and sim.opened else "Not accepting play", 15, TEXT)
	else: add_label(inspector, "Playing now
" + ", ".join(guests.map(func(guest): return str(guest.name).replace(" · ", " - "))), 15, TEXT)
	if kind != "slots": add_label(inspector, "Dealers %d of %d" % [sim.crew(selected).size(), sim.required_crew(table)], 14, MUTED)
	add_label(inspector, "Minimum wager " + money(table.minimum), 14, MUTED)
	add_button(inspector, ("Hide " if asset_details else "Show ") + ("machine details" if kind == "slots" else "game details"), func(): asset_details = not asset_details; refresh())
	if asset_details:
		add_label(inspector, "PERFORMANCE", 12, MUTED)
		finance_row(inspector, "Guest gaming win", float(performance.guest_win), false)
		finance_row(inspector, "Operating contribution", float(performance.contribution), false)
		finance_short_metric(inspector, "Settled handle", FinancialText.cash(float(performance.handle)))
		finance_short_metric(inspector, "Returned to players", FinancialText.cash(float(performance.payouts)))
		finance_row(inspector, "Dealer payroll", -float(table.payroll_expense))
		finance_row(inspector, "Repairs", -float(table.repair_expense))
		finance_row(inspector, "Upkeep", -float(table.operating_expense))
		add_label(inspector, "Contribution excludes visitor play and purchase price. Handle, payouts and activity include all participants. Shared service costs are in Finance.", 12, MUTED)
		finance_short_metric(inspector, "Spins" if kind == "slots" else "Rolls" if kind == "craps" else "Resolved hands / spins", str(table.rolls))
		finance_short_metric(inspector, "Busy time / available time", "%.0f%%" % float(performance.utilization))
		finance_short_metric(inspector, "Available hours", "%.1f" % float(performance.hours))
		finance_short_metric(inspector, "Repair count / downtime", "%d / %d min" % [table.repairs, table.downtime_minutes])
		if float(performance.hours) > 0:
			finance_short_metric(inspector, "Handle / available hour", FinancialText.cash(float(performance.handle_hour)) + "/hr")
			finance_short_metric(inspector, "Contribution / available hour", FinancialText.house_result(float(performance.contribution_hour)) + "/hr")
		else: add_label(inspector, "No operating sample yet.", 12, MUTED)
		if kind == "slots":
			var profile := sim.slot_profile(table)
			add_label(inspector, "RTP %.2f%%   House edge %.2f%%
%s volatility   Maximum %s" % [profile.rtp * 100, profile.house_edge * 100, profile.volatility, money(profile.maximum)], 13, MUTED)
			add_label(inspector, "Development %.0f (tier cap %.0f)
Appeal %.2fx   Prestige %d" % [profile.development, profile.development_cap, profile.appeal, profile.prestige], 13, MUTED)
			add_label(inspector, "Maximum total return %s
Suggested reserve %s" % [money(profile.top_return * profile.maximum), money(profile.reserve)], 13, GOLD)
		add_label(inspector, table.result.replace(" · ", " - "), 13, MUTED)
	if sim.table_kind(table) == "craps": add_label(inspector, "POINT: %s" % ("OFF / COME-OUT" if int(table.point) == 0 else str(int(table.point))), 12, GOLD)
	add_gap(inspector, 10)
	if kind != "slots": add_button(inspector, "Hire dealer | $%d" % CasinoTuning.HIRING_COST, func(): sim.hire("Dealer", selected); refresh(), sim.crew(selected).size() >= sim.required_crew(table) or not sim.unlocked("blackjack"))
	if kind != "slots":
		add_button(inspector, "Staffing priority: " + ["Low", "Normal", "High"][int(table.staff_priority)], func(): sim.set_staff_priority(selected, (int(table.staff_priority) + 1) % 3); refresh())
		add_button(inspector, "Pause table staffing" if table.staff_enabled else "Resume table staffing", func(): sim.set_table_staffed(selected, not bool(table.staff_enabled)); refresh())
		add_label(inspector, "Priority protects coverage when short staffed. Committed bets finish before a table pauses.", 12, MUTED)
	if table.broken:
		add_button(inspector, "Repair | $%d" % sim.repair_cost(table), func():
			for i in range(sim.incidents.size()):
				if sim.incidents[i].type == "repair" and int(sim.incidents[i].table) == selected:
					sim.resolve_incident(i, true)
					break
			refresh())
	if visitor:
		var distance := sim.player.distance_to(sim.bounds(table).get_center())
		add_button(inspector, "Join " + Games.NAMES[sim.table_kind(table)], join_table, not sim.ready_for_play(table) or distance > 165 or (sim.table_kind(table) == "slots" and not sim.reserved_guests(selected).is_empty()))
		add_label(inspector, "Approach the rail to join." if distance > 165 else "You're close enough to take a seat.", 12, MUTED)
		if distance > 165:
			add_button(inspector, "Walk to this table", func(): floor_view.walk_to_table(selected); transition_pane("floor"); refresh())
	else:
		add_button(inspector, "Experience this table", func(): toggle_walk())
	var limit_labels := PackedStringArray()
	for minimum in sim.wager_limits(table): limit_labels.append(money(float(minimum)))
	var limits := " / ".join(limit_labels)
	add_button(inspector, "Minimum: " + limits, func(): sim.change_minimum(selected); refresh())

	var move_button := add_button(inspector, "Move table", begin_move, visitor or sim.busy(table))
	if visitor: move_button.tooltip_text = "Return to management before moving equipment."
	button_tone(add_button(inspector, "Sell for %s" % money(sim.purchase_cost(sim.table_kind(table), str(table.slot_profile)) / 2), func():
		if not sim.sell(selected): return
		selected = -1
		selected_guest = -1
		transition_pane("floor")
		refresh(), sim.busy(table)), "danger")

func render_staff() -> void:
	add_label(inspector, "STAFF & COVERAGE", 11, GOLD)
	add_label(inspector, "%d employees" % sim.staff.size(), 24)
	finance_short_metric(inspector, "Current paid shift", FinancialText.cash(sim.payroll_rate(), 0) + "/hr")
	add_label(inspector, "Dealers and drink service use paid shifts and breaks. Techs stay on call, with wages charged only during repair calls.", 13, MUTED)
	if sim.unlocked("blackjack") or sim.staff.any(func(e): return e.role == "Dealer"):
		render_staff_role("Dealer", "Dealers")
	else:
		add_label(inspector, "Your slots operate without dealers.", 14, MUTED)
	render_staff_role("Tech", "Repair techs")
	if sim.bar_available():
		render_staff_role("Service", "Drink service")
	elif sim.revealed("service"):
		render_bar_purchase()

func render_staff_role(role: String, title: String) -> void:
	if role == "Tech":
		render_tech_staff()
		return
	var coverage: Dictionary = sim.staffing_summary(role)
	add_gap(inspector, 12)
	add_label(inspector, "%s - %d employed" % [title, int(coverage.employed)], 20, GOLD)
	add_label(inspector, str(coverage.coverage), 16, TEAL if coverage.coverage == "GOOD COVERAGE" else GOLD)
	for metric in [{"name": "ACTIVE", "key": "active"}, {"name": "RELIEF", "key": "relief"}, {"name": "BREAK", "key": "break"}, {"name": "OFF DUTY", "key": "off_duty"}, {"name": "REQUIRED", "key": "required"}]:
		finance_short_metric(inspector, metric.name, str(coverage[metric.key]))
	if int(coverage.required) > 0:
		finance_short_metric(inspector, "Recommended roster for continuous operation", str(coverage.continuous_recommended))
		if coverage.coverage == "SHORT STAFFED":
			add_label(inspector, "Hire %d more employees for current coverage." % maxi(1, int(coverage.required) - int(coverage.active)), 14, GOLD)
		elif coverage.coverage == "LEAN COVERAGE":
			var shortfall := maxi(0, int(coverage.continuous_recommended) - int(coverage.employed))
			add_label(inspector, "Hire %d more employees for reliable continuous shifts." % shortfall if shortfall > 0 else "Rested relief is needed. Review your relief target and roster energy.", 14, GOLD)
	var controls := row(inspector)
	add_button(controls, "-", func(): sim.set_relief_target(role, int(sim.relief_targets[role]) - 1); refresh(), int(sim.relief_targets[role]) == 0)
	add_label(controls, "Relief target: %d" % int(sim.relief_targets[role]), 14, TEXT)
	add_button(controls, "+", func(): sim.set_relief_target(role, int(sim.relief_targets[role]) + 1); refresh(), int(sim.relief_targets[role]) >= CasinoTuning.MAX_STAFF)
	if role == "Service" and sim.bar_available():
		add_button(inspector, "Manage drink menu >", func(): open_page("bar"))
		var positions := row(inspector)
		add_button(positions, "-", func(): sim.set_service_positions(sim.service_positions - 1); refresh(), sim.service_positions <= 1)
		add_label(positions, "Floor positions: %d" % sim.service_positions, 14, TEXT)
		add_button(positions, "+", func(): sim.set_service_positions(sim.service_positions + 1); refresh(), sim.service_positions >= CasinoTuning.MAX_STAFF)
	var accessible: bool = sim.unlocked("blackjack") if role == "Dealer" else sim.bar_owned
	var hire := add_button(inspector, "Hire %s | $%d" % [role.to_lower(), CasinoTuning.HIRING_COST] if accessible else "Service access approaching", func(): sim.hire(role, -1); refresh(), not accessible or sim.cash < CasinoTuning.HIRING_COST or sim.staff.size() >= CasinoTuning.MAX_STAFF)
	hire.tooltip_text = "$%d per game hour on shift. Extra roster employees rest unpaid until coverage is needed. Relief targets use hired staff; they do not create employees." % sim.Staffing.wage(role)
	if int(coverage.employed) == 0: return
	add_button(inspector, "Hide employee details" if staff_details_role == role else "Employee details >", func(): staff_details_role = "" if staff_details_role == role else role; refresh())
	if staff_details_role != role: return
	for employee in sim.staff:
		if employee.role != role: continue
		add_gap(inspector, 8)
		add_label(inspector, ("> " if int(employee.id) == event_focus_staff else "") + str(employee.name) + " - " + str(employee.duty), 16, GOLD if int(employee.id) == event_focus_staff else TEXT)
		finance_short_metric(inspector, "Energy", "%.0f%%" % float(employee.energy))
		if employee.rest_due != "":
			add_label(inspector, "Finishing committed bets, then " + str(employee.rest_due).to_lower(), 13, GOLD)
		elif employee.duty == "Off Duty":
			add_label(inspector, "Ready for the next shift" if sim.Staffing.can_start(sim, employee) else "%d minutes of rest remaining" % maxi(0, int(employee.available_at) - sim.elapsed), 13, MUTED)
		elif employee.duty == "Break":
			add_label(inspector, "Minimum %d more minutes; returns at %.0f%% energy" % [maxi(0, CasinoTuning.STAFF_BREAK_MINUTES - (sim.elapsed - int(employee.state_since))), CasinoTuning.STAFF_RETURN_ENERGY], 13, MUTED)
		else:
			add_label(inspector, ("Table #%d. " % int(employee.table) if int(employee.table) > 0 else "Whole floor. " if employee.duty == "Active" else "Ready to cover. ") + "%d minutes left in shift" % maxi(0, int(employee.shift_end) - sim.elapsed), 13, MUTED)
		if employee.duty in ["Active", "Relief"]:
			add_button(inspector, "Send on break", func(): sim.staff_rest(employee); refresh(), employee.rest_due != "")
		if employee.duty != "Off Duty":
			add_button(inspector, "End shift", func(): sim.staff_rest(employee, true); refresh(), employee.rest_due == "Off Duty")
		else:
			add_label(inspector, "Rested shifts start automatically when coverage is needed.", 12, MUTED)

func render_tech_staff() -> void:
	var coverage: Dictionary = sim.staffing_summary("Tech")
	add_gap(inspector, 12)
	add_label(inspector, "Repair techs - %d employed" % coverage.employed, 20, GOLD)
	add_label(inspector, str(coverage.coverage), 16, TEAL if coverage.coverage == "GOOD COVERAGE" else GOLD)
	finance_short_metric(inspector, "Games / covered capacity", "%d / %d" % [coverage.games, coverage.capacity])
	finance_short_metric(inspector, "Techs needed", str(coverage.required))
	finance_short_metric(inspector, "On call / repairing", "%d / %d" % [coverage.on_call, coverage.repairing])
	add_label(inspector, "One Tech covers three machines or tables. Techs rotate repair calls automatically and return to on-call availability when finished.", 13, MUTED)
	add_label(inspector, "Available from the start. $%d/hr only during repair calls, plus parts from casino cash. Unfunded repairs stay queued." % CasinoTuning.TECH_WAGE, 13, MUTED)
	if int(coverage.employed) < int(coverage.required):
		add_label(inspector, "Hire %d more Techs for full coverage." % (int(coverage.required) - int(coverage.employed)), 14, GOLD)
	add_button(inspector, "Hire tech | $%d" % CasinoTuning.HIRING_COST, func(): sim.hire("Tech", -1); refresh(), sim.cash < CasinoTuning.HIRING_COST or sim.staff.size() >= CasinoTuning.MAX_STAFF)
	if int(coverage.employed) == 0: return
	add_button(inspector, "Hide employee details" if staff_details_role == "Tech" else "Employee details >", func(): staff_details_role = "" if staff_details_role == "Tech" else "Tech"; refresh())
	if staff_details_role != "Tech": return
	for employee in sim.staff:
		if employee.role != "Tech": continue
		add_gap(inspector, 8)
		add_label(inspector, str(employee.name) + " - " + str(employee.duty), 16, TEXT)
		if employee.duty == "Repairing":
			add_label(inspector, "Game #%d | %d/%d min" % [employee.repair_target, employee.repair_minutes, CasinoTuning.TECH_REPAIR_MINUTES], 13, MUTED)

func finance_color(amount: float) -> Color:
	return TEAL if amount > 0.005 else Color("ff9486") if amount < -0.005 else MUTED

func finance_line(parent: Node) -> BoxContainer:
	var line: BoxContainer = render_node(parent, "finance_line", func(): return preload("res://scripts/finance_layout.gd").new())
	return line

func finance_value(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var value := add_label(parent, text, font_size, color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = SIZE_FILL
	return value

func finance_metric(parent: Node, title: String, amount: float, signed: bool = true) -> void:
	var card: PanelContainer = render_node(parent, "finance_metric_card", func(): return PanelContainer.new())
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", style(Color("182a38")))
	var body: VBoxContainer = render_node(card, "finance_metric_body", func(): return VBoxContainer.new())
	add_label(body, title, 12, MUTED)
	var summary := FinancialText.cash(amount, 0)
	if signed:
		summary = ("+" if amount > 0 else "-" if amount < 0 else "") + FinancialText.cash(absf(amount), 0)
		if absf(amount) < 1: summary = FinancialText.house_result(amount)
	var value := finance_value(body, summary, 24, finance_color(amount) if signed else TEXT)
	value.tooltip_text = FinancialText.cash(amount)

func finance_short_metric(parent: Node, title: String, text: String) -> void:
	var line := finance_line(parent)
	add_label(line, title, 13, MUTED)
	finance_value(line, text, 14, TEXT)

func table_purchase_tooltip(kind: String) -> String:
	var plan := sim.reserve_report(kind)
	var crew := sim.required_crew({"kind": kind})
	return "Setup estimate (table purchase only):\n%d dealer(s), %s/hr crew wages + %s/hr equipment upkeep.\nTable + needed dealer hiring: %s.\nCash above / below suggested buffer after purchase: %s.\nBuffer includes the existing floor, payout swings and %.0f hours of payroll/upkeep. Keep it available; it is not charged." % [crew, FinancialText.cash(crew * CasinoTuning.DEALER_WAGE, 0), FinancialText.cash(CasinoTuning.TABLE_OVERHEAD, 0), FinancialText.cash(float(plan.purchase) + float(plan.onboarding), 0), FinancialText.house_result(float(plan.margin)), CasinoTuning.RESERVE_OPERATING_HOURS]

func render_purchase_readiness(parent: Node, kind: String, profile_id: String = "starter") -> void:
	var plan := sim.reserve_report(kind, profile_id)
	add_label(parent, ("Blackjack readiness" if kind == "blackjack" else "After this purchase") + (" - buffer covered" if plan.level == "covered" else " - preserve more cash"), 13, TEAL if plan.level == "covered" else GOLD)
	finance_short_metric(parent, "Purchase + dealer onboarding", FinancialText.cash(float(plan.purchase) + float(plan.onboarding), 0))
	finance_short_metric(parent, "Cash above / below planned buffer", FinancialText.house_result(float(plan.margin)))
	add_label(parent, "Includes the existing floor, payout swings and four hours of payroll/upkeep. Access requirements remain separate; purchase is optional.", 12, MUTED)

func finance_row(parent: Node, title: String, amount: float, hide_zero: bool = true) -> void:
	if hide_zero and absf(amount) < 0.005: return
	var line := finance_line(parent)
	add_label(line, title, 14, MUTED)
	var value := finance_value(line, FinancialText.house_result(amount), 15, finance_color(amount))
	value.size_flags_horizontal = SIZE_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func finance_card(id: String, title: String, amount: float) -> VBoxContainer:
	var card: PanelContainer = render_node(inspector, "finance_card_card", func(): return PanelContainer.new())
	card.add_theme_stylebox_override("panel", style(Color("142331")))
	var stack: VBoxContainer = render_node(card, "finance_card_stack", func(): return VBoxContainer.new())
	stack.add_theme_constant_override("separation", 8)
	var header := add_button(stack, "", func():
		finance_section = "" if finance_section == id else id
		refresh())
	header.tooltip_text = "Expand " + title if finance_section != id else "Collapse " + title
	if id == "reserve": header.tooltip_text = "Free cash minus suggested payout, payroll, upkeep and repair buffer. Advisory, not a guarantee."
	elif id == "assets": header.tooltip_text = "Owned asset guest operating contribution after direct upkeep, repairs and dealer payroll."
	elif id == "operations": header.tooltip_text += ". Upkeep, repairs and complaint comps; drink products are in Bar and payroll is separate."
	elif id == "bar": header.tooltip_text += ". Sales minus paid and complimentary product costs, before service payroll."
	elif id == "investment": header.tooltip_text += ". Capital purchases minus sales, plus hiring; excluded from operating profit."
	elif id == "gaming": header.tooltip_text += ". Settled guest gaming win, excluding visitor play and pending stakes."
	header.custom_minimum_size.y = 50
	var margin: MarginContainer = render_node(header, "finance_card_margin", func(): return MarginContainer.new())
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line := finance_line(margin)
	line.fit_header = true
	line.mouse_filter = MOUSE_FILTER_IGNORE
	var name := add_label(line, title + (" -" if finance_section == id else " >"), 14, TEXT)
	name.mouse_filter = MOUSE_FILTER_IGNORE
	var value := finance_value(line, FinancialText.house_result(amount), 20, finance_color(amount))
	value.mouse_filter = MOUSE_FILTER_IGNORE
	if finance_section != id: return null
	var detail: VBoxContainer = render_node(stack, "finance_card_detail", func(): return VBoxContainer.new())
	detail.add_theme_constant_override("separation", 8)
	return detail

func render_finance_gaming(parent: Node) -> void:
	var by_game := {}
	var owned_total := 0.0
	for asset in sim.tables:
		var kind := sim.table_kind(asset)
		# Existing asset accounting gives guest gaming win after outstanding stakes.
		var win := sim.asset_operating_profit(asset) + float(asset.operating_expense) + float(asset.repair_expense) + float(asset.payroll_expense)
		by_game[kind] = float(by_game.get(kind, 0)) + win
		owned_total += win
	for kind in by_game:
		finance_row(parent, "Slots" if kind == "slots" else str(Games.NAMES[kind]).replace("’", "'"), float(by_game[kind]), false)
	finance_row(parent, "Sold assets", sim.guest_gaming_profit() - owned_total)
	finance_row(parent, "Total guest gaming win", sim.guest_gaming_profit(), false)
	add_button(parent, "Build / improve games", func(): open_page("build"))

func show_bar_product(id: String) -> void:
	bar_menu_product = id
	bar_menu_tab = "active" if id in sim.drink_menu else "available"
	open_page("bar")

func render_amenity_requirements(feature: String) -> void:
	if not sim.restricted():
		add_label(inspector, "Easy mode: access is unrestricted.", 13, MUTED)
		return
	for milestone in CasinoTuning.MILESTONES:
		if str(milestone.id) != feature: continue
		for requirement in unlock_requirements(milestone):
			add_label(inspector, "Normal-mode %s: %s" % [requirement.name, requirement_text(requirement)], 13, MUTED)

func render_amenities() -> void:
	if sim.bar_owned:
		add_label(inspector, "BAR SERVICE - Owned", 20, GOLD)
		add_button(inspector, "Manage drink menu", func(): open_page("bar"))
	else:
		render_bar_purchase()
	for feature in ["vip", "high_limit"]:
		add_gap(inspector, 12)
		var title := "VIP Access" if feature == "vip" else "High-Limit Capability"
		var owned := sim.feature_owned(feature)
		var available := sim.unlocked(feature)
		var cost := sim.feature_cost(feature)
		add_label(inspector, title, 20, GOLD)
		add_label(inspector, "Makes VIP guests eligible to arrive at your casino." if feature == "vip" else "Enables the existing higher table minimum settings. Game wager caps still apply.", 14, MUTED)
		finance_short_metric(inspector, "Purchase with Casino Cash", money(cost))
		render_amenity_requirements(feature)
		if not owned and available and sim.cash < cost:
			add_label(inspector, "Insufficient Casino Cash: " + money(sim.cash) + " available.", 13, GOLD)
		add_button(inspector, "Owned" if owned else "Locked" if not available else "Purchase " + title + " | " + money(cost), func(): sim.purchase_upgrade(feature); refresh(), owned or not available or sim.cash < cost)
	add_gap(inspector, 12)
	add_button(inspector, "Floor Expansion - review directional purchases", func(): open_page("development"))

func render_bar_purchase() -> void:
	add_label(inspector, "BAR SERVICE", 20, GOLD)
	finance_short_metric(inspector, "Purchase with Casino Cash", money(CasinoTuning.BAR_PURCHASE_COST))
	add_label(inspector, "Unlocks drink service and Service staff. House Soda and Sparkling Water start on your menu; you can change them later.", 14, MUTED)
	finance_short_metric(inspector, "Hiring / training per employee", money(CasinoTuning.HIRING_COST))
	finance_short_metric(inspector, "Per employee on shift", money(CasinoTuning.SERVICE_WAGE) + "/game-hour")
	add_label(inspector, "Recommended startup: 1 active + 1 relief. Off Duty staff are unpaid.", 14, TEXT)
	finance_short_metric(inspector, "Recommended continuous roster", str(sim.Staffing.continuous_roster(1, 1)))
	add_label(inspector, "Drink expectations begin after purchase. Delaying purchase has no missing-service penalty.", 13, MUTED)
	render_amenity_requirements("service")
	add_button(inspector, "Bar owned" if sim.bar_owned else "Purchase Bar | " + money(CasinoTuning.BAR_PURCHASE_COST), func(): sim.purchase_bar(); refresh(), not sim.unlocked("service") or sim.bar_owned or sim.cash < CasinoTuning.BAR_PURCHASE_COST)

func render_bar_menu() -> void:
	add_label(inspector, "DRINK MENU", 12, GOLD)
	if not sim.bar_available():
		render_bar_purchase()
		return
	add_label(inspector, sim.Bar.identity(sim), 22, TEXT)
	finance_short_metric(inspector, "On menu / unlocked", "%d / %d" % [sim.drink_menu.size(), sim.drink_access.size()])
	add_label(inspector, "Unlocks offer choices. Add products yourself; service staff prepare and physically deliver every drink.", 13, MUTED)
	if sim.drink_menu.is_empty(): add_label(inspector, "Add your first product from Add drinks to start serving.", 15, GOLD)
	var tabs := row(inspector)
	add_button(tabs, "Active menu", func(): bar_menu_tab = "active"; bar_menu_product = ""; refresh(), bar_menu_tab == "active")
	add_button(tabs, "Add drinks", func(): bar_menu_tab = "available"; bar_menu_product = ""; refresh(), bar_menu_tab == "available")
	var choices: Array = sim.drink_menu if bar_menu_tab == "active" else sim.drink_access.filter(func(id): return id not in sim.drink_menu)
	if choices.is_empty(): add_label(inspector, "No products here yet.", 14, MUTED)
	for id in choices:
		var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
		add_button(inspector, str(profile.name) + (" -" if bar_menu_product == id else " >"), func(): bar_menu_product = "" if bar_menu_product == id else id; refresh())
		finance_short_metric(inspector, "Paid price", FinancialText.cash(float(sim.drink_prices[id]), 0))
		if bar_menu_product != id: continue
		finance_short_metric(inspector, "Product cost", FinancialText.cash(float(profile.cost)))
		finance_short_metric(inspector, "Paid unit margin before labor", FinancialText.cash(float(sim.drink_prices[id]) - float(profile.cost)))
		add_label(inspector, "Prep: %.0f game minutes. Prestige: %d." % [float(profile.prep_minutes), int(profile.prestige)], 13, MUTED)
		var tastes: Array = profile.preferences.keys()
		tastes.sort_custom(func(x, y): return float(profile.preferences[x]) > float(profile.preferences[y]))
		add_label(inspector, "Strongest appeal: %s / %s guests. Preferences vary by guest." % [str(tastes[0]).capitalize(), str(tastes[1]).capitalize()], 13, MUTED)
		add_label(inspector, "Basic comp eligible during recent active wagering; each comp costs the product cost." if profile.comp_eligible else "Paid product, including for active gamblers.", 13, TEAL)
		var prices := row(inspector)
		add_button(prices, "-", func(): sim.set_drink_price(str(id), float(sim.drink_prices[id]) - CasinoTuning.DRINK_PRICE_STEP); refresh(), float(sim.drink_prices[id]) <= float(profile.price_min))
		finance_value(prices, FinancialText.cash(float(sim.drink_prices[id]), 0), 18, GOLD)
		add_button(prices, "+", func(): sim.set_drink_price(str(id), float(sim.drink_prices[id]) + CasinoTuning.DRINK_PRICE_STEP); refresh(), float(sim.drink_prices[id]) >= float(profile.price_max))
		add_label(inspector, "Allowed price: %s to %s. Existing orders keep their quoted paid price." % [FinancialText.cash(float(profile.price_min), 0), FinancialText.cash(float(profile.price_max), 0)], 12, MUTED)
		var active: bool = id in sim.drink_menu
		add_button(inspector, "Drop from menu" if active else "Add to menu", func(): sim.set_drink_menu(str(id), not active); refresh())
		add_button(inspector, "View product performance", func(): bar_finance_product = str(id); open_page("finance"); finance_section = "bar"; bar_finance_products = true; refresh())
	for id in CasinoTuning.DRINK_PROFILES:
		if id in sim.drink_access: continue
		var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
		add_gap(inspector, 8)
		add_label(inspector, "Next option: " + str(profile.name), 16, GOLD)
		finance_short_metric(inspector, "Rating needed", "%.0f / %.0f" % [sim.casino_rating, float(profile.rating)])
		finance_short_metric(inspector, "Drinks delivered", "%d / %d" % [int(sim.bar_totals.sold) + int(sim.bar_totals.comped), int(profile.served)])
		if profile.vip: add_label(inspector, "Also requires existing VIP access.", 13, MUTED)
		break
	add_gap(inspector, 8)
	add_button(inspector, "Service staff", func(): open_page("staff"))
	add_button(inspector, "Bar finances", func(): open_page("finance"); finance_section = "bar"; refresh())

func render_finance_bar(parent: Node) -> void:
	var bar: Dictionary = sim.bar_totals
	add_label(parent, sim.Bar.identity(sim), 16, TEXT)
	add_label(parent, "Basic products are comped only during active play with real wagers in the last %d game minutes. Waiting, watching and bar breaks pay; premium products stay paid." % int(CasinoTuning.COMP_POLICY.recent_wager_minutes), 13, MUTED)
	add_label(parent, "%d sold / %d comped" % [int(bar.sold), int(bar.comped)], 15, TEXT)
	finance_row(parent, "Sales", float(bar.revenue))
	finance_row(parent, "Product cost", -float(bar.product_cost))
	finance_row(parent, "Drink comps", -float(bar.comp_cost))
	finance_row(parent, "Gross contribution", sim.bar_margin(), false)
	finance_row(parent, "Service payroll", -float(sim.expense_totals.service_payroll))
	finance_row(parent, "Net after service labor", sim.bar_contribution(), false)
	add_button(parent, "Manage drink menu >", func(): open_page("bar"))
	add_button(parent, "Product performance -" if bar_finance_products else "Product performance >", func(): bar_finance_products = not bar_finance_products; refresh())
	if bar_finance_products:
		add_label(parent, "Lifetime signals count choice attempts, including repeat visits and substitutes. Queued orders may still be awaiting service.", 12, MUTED)
		finance_row(parent, "Shared / idle service payroll", -sim.Bar.shared_payroll(sim))
		for id in CasinoTuning.DRINK_PROFILES:
			var stats: Dictionary = sim.drink_stats[id]
			if id not in sim.drink_menu and int(stats.requests) + int(stats.orders) + int(stats.price_declines) == 0 and float(stats.service_payroll) == 0: continue
			add_button(parent, str(CasinoTuning.DRINK_PROFILES[id].name) + (" -" if bar_finance_product == id else " >"), func(): bar_finance_product = "" if bar_finance_product == id else id; refresh())
			if bar_finance_product != id: continue
			finance_short_metric(parent, "Sold / comped", "%d / %d" % [int(stats.sold), int(stats.comped)])
			finance_row(parent, "Revenue", float(stats.revenue))
			finance_row(parent, "Paid product cost", -float(stats.product_cost))
			finance_row(parent, "Comp product cost", -float(stats.comp_cost))
			finance_row(parent, "Gross contribution", sim.Bar.contribution(sim, str(id)))
			finance_row(parent, "Order service payroll", -float(stats.service_payroll))
			finance_row(parent, "Net contribution", sim.Bar.contribution(sim, str(id), true), false)
			finance_short_metric(parent, "First-choice requests", str(stats.requests))
			finance_short_metric(parent, "Requests while off menu", str(stats.menu_misses))
			finance_short_metric(parent, "Price / affordability refusals", str(stats.price_declines))
			finance_short_metric(parent, "Orders queued / not served", "%d / %d" % [int(stats.orders), int(stats.unserved)])
			add_label(parent, "Order payroll covers actual preparation, delivery and return time. Shared staff costs are separate.", 12, MUTED)
			add_button(parent, "Adjust this product >", func(): show_bar_product(str(id)))
	add_button(parent, "Manage service staff", func(): open_page("staff"))

func render_finance_payroll(parent: Node) -> void:
	var costs: Dictionary = sim.expense_totals
	finance_row(parent, "Dealers", -float(costs.dealer_payroll))
	finance_row(parent, "Service staff", -float(costs.service_payroll))
	finance_row(parent, "Repair techs", -float(costs.tech_payroll))
	var commitment := finance_line(parent)
	add_label(commitment, "Current commitment", 14, MUTED)
	finance_value(commitment, "%s/hr" % FinancialText.cash(sim.payroll_rate(), 0), 14, GOLD)
	add_button(parent, "Staff / assignments", func(): open_page("staff"))

func render_finance_operations(parent: Node) -> void:
	var costs: Dictionary = sim.expense_totals
	finance_row(parent, "Equipment upkeep", -float(costs.upkeep))
	if float(costs.property_upkeep) > 0: finance_row(parent, "Property upkeep", -float(costs.property_upkeep))
	if sim.property_upkeep_rate() > 0: add_button(parent, "Manage property footprint >", func(): open_page("development"))
	finance_row(parent, "Repairs", -float(costs.repairs))
	finance_row(parent, "Complaint comps", -float(costs.comps))
	if sim.incidents.is_empty():
		add_button(parent, "Inspect equipment", func(): open_page("table"))
	else:
		add_button(parent, "%d incidents / decisions" % sim.incidents.size(), func(): open_page("incidents"))

func render_finance_investment(parent: Node) -> void:
	var costs: Dictionary = sim.expense_totals
	finance_row(parent, "Equipment / upgrades", -float(costs.construction))
	finance_row(parent, "Sale proceeds", -float(costs.sales))
	finance_row(parent, "Net capital spending", -sim.net_capital_spending())
	finance_row(parent, "Hiring / setup", -float(costs.hiring))
	finance_row(parent, "After investment / setup", sim.operating_profit() - sim.net_capital_spending() - float(costs.hiring), false)
	add_button(parent, "Build / expansion", func(): open_page("build"))

func render_finance_advanced(parent: Node) -> void:
	finance_row(parent, "All settled gaming", sim.gaming_profit())
	finance_row(parent, "Owner floor house result", sim.visitor_house_result())
	finance_row(parent, "Drink sales", float(sim.bar_totals.revenue))
	finance_row(parent, "All costs incl. investment", -sim.operating_costs())
	finance_row(parent, "Owner wallet / event transfers", sim.owner_account.profit_transferred)
	if sim.sponsored_income > 0: finance_row(parent, "Sponsored promotions", sim.sponsored_income)
	finance_row(parent, "Owner Bankroll (personal)", sim.owner_bankroll)
	finance_row(parent, "Recorded net cash flow", sim.net_profit(), false)
	finance_row(parent, "Pending stakes", sim.live_stakes())
	var note := add_label(parent, "Cash flow includes owner floor transfers, personal wallet transfers, event net winnings, sponsored promotions and pending floor stakes.", 12, MUTED)
	note.tooltip_text = "Starting cash and developer funding are outside recorded flow. Operating profit excludes capital, hiring and owner gambling; gaming win excludes unresolved stakes."
	if not sim.owner_account.history.is_empty():
		add_label(parent, "Recent owner transactions", 12, GOLD)
		for entry in sim.owner_account.history.slice(0, 6):
			add_label(parent, "%s: %s | casino profit %s" % [entry.kind, money(float(entry.amount)), money(float(entry.profit))], 12, MUTED)
	if sim.payroll > 0:
		add_label(parent, "Payroll allocation", 12, GOLD)
		var states: Dictionary = sim.payroll_by_state
		for state in [{"key": "active", "name": "Active (incl. assigned idle)"}, {"key": "relief", "name": "Relief"}, {"key": "break", "name": "Break"}]:
			finance_row(parent, state.name, -float(states[state.key]))
	if speed > 4: add_label(parent, "DEV: leave manual games during long-run comparisons.", 12, GOLD)

func render_finance_reserve(parent: Node, report: Dictionary) -> void:
	finance_short_metric(parent, "Treasury less pending stakes", FinancialText.cash(float(report.available)))
	finance_short_metric(parent, "Pending stakes held", FinancialText.cash(float(report.pending)))
	finance_short_metric(parent, "Suggested payout buffer", FinancialText.cash(float(report.payouts)))
	finance_short_metric(parent, "Four hours of payroll", FinancialText.cash(float(report.payroll)))
	finance_short_metric(parent, "Four hours of upkeep", FinancialText.cash(float(report.upkeep)))
	finance_short_metric(parent, "Known repair bills", FinancialText.cash(float(report.repairs)))
	finance_short_metric(parent, "Suggested total buffer", FinancialText.cash(float(report.required)))
	add_label(parent, "Largest exposure: " + str(report.largest), 12, GOLD)
	add_label(parent, "Planning estimate: one large payout plus a partial buffer for other assets. Rare simultaneous wins can exceed it. Outcomes are never capped or changed.", 12, MUTED)
	render_purchase_readiness(parent, "blackjack")
	add_button(parent, "Plan purchases", func(): open_page("build"))

func render_finance_assets(parent: Node) -> void:
	var groups := {}
	for asset in sim.tables:
		var key: String = str(asset.slot_profile) if sim.table_kind(asset) == "slots" else sim.table_kind(asset)
		if not groups.has(key): groups[key] = []
		groups[key].append(asset)
	add_label(parent, "Compare actual contribution and throughput; RTP alone does not determine earnings.", 12, MUTED)
	for key in groups:
		var assets: Array = groups[key]
		var contribution := 0.0
		for asset in assets: contribution += sim.asset_operating_profit(asset)
		var handle := 0.0
		var payouts := 0.0
		var win := 0.0
		var hours := 0.0
		var busy := 0.0
		var repairs := 0.0
		for asset in assets:
			var data := sim.asset_performance(asset)
			handle += float(data.handle)
			payouts += float(data.payouts)
			win += float(data.guest_win)
			hours += float(data.hours)
			busy += float(asset.occupied_minutes) / 60.0
			repairs += float(asset.repair_expense)
		finance_row(parent, "%s (%d)" % [sim.asset_name(assets[0]), assets.size()], contribution, false)
		if hours > 0:
			finance_short_metric(parent, "Handle / available asset hour", FinancialText.cash(handle / hours) + "/hr")
			finance_short_metric(parent, "Contribution / available asset hour", FinancialText.house_result(contribution / hours) + "/hr")
		else: add_label(parent, "No operating sample yet.", 12, MUTED)
		add_button(parent, "Hide breakdown" if finance_compare_group == key else "Expand breakdown", func(): finance_compare_group = "" if finance_compare_group == key else key; refresh())
		if finance_compare_group != key: continue
		finance_short_metric(parent, "Settled handle (all players)", FinancialText.cash(handle))
		finance_short_metric(parent, "Returned to players", FinancialText.cash(payouts))
		finance_row(parent, "Guest gaming win", win, false)
		finance_row(parent, "Repair cost", -repairs, false)
		if hours > 0:
			finance_short_metric(parent, "Busy / available asset time", "%.0f%%" % (busy / hours * 100))
			finance_short_metric(parent, "Available asset-hour sample", "%.1f" % hours)
		else: add_label(parent, "No operating sample yet.", 12, MUTED)
		add_label(parent, "Lifetime figures; short samples reflect variance. Contribution excludes purchase price, visitor play and shared service costs. Compare similar operating samples.", 12, MUTED)
		for asset in assets:
			finance_row(parent, "%s #%d" % [sim.asset_name(asset), asset.id], sim.asset_operating_profit(asset), false)
			add_button(parent, "Inspect #%d" % asset.id, func(): selected = int(asset.id); asset_details = true; open_page("table"))

func render_finance() -> void:
	add_label(inspector, "FINANCE", 12, GOLD)
	add_label(inspector, "Lifetime operations / %.1f game hours" % (float(sim.elapsed) / 60.0), 12, MUTED)
	var metrics := finance_line(inspector)
	metrics.size_flags_horizontal = SIZE_EXPAND_FILL
	finance_metric(metrics, "Cash now", sim.cash, false)
	finance_metric(metrics, "Operating profit", sim.operating_profit())
	var costs_line := finance_line(inspector)
	var cost_label := add_label(costs_line, "Recurring costs", 13, MUTED)
	cost_label.tooltip_text = "Payroll, equipment/property upkeep, repairs, complaint comps and all drink product costs."
	var costs_value := finance_value(costs_line, FinancialText.house_result(-sim.recurring_costs()), 14, MUTED)
	costs_value.size_flags_horizontal = SIZE_FILL
	costs_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var report := sim.reserve_report()
	var reserve_title := "Reserve short" if report.level == "short" else "Reserve thin" if report.level == "thin" else "Reserve headroom"
	var reserve_detail := finance_card("reserve", reserve_title, float(report.margin))
	if reserve_detail != null: render_finance_reserve(reserve_detail, report)
	if not sim.tables.is_empty():
		var owned_contribution := 0.0
		for asset in sim.tables: owned_contribution += sim.asset_operating_profit(asset)
		var asset_detail := finance_card("assets", "Asset contribution", owned_contribution)
		if asset_detail != null: render_finance_assets(asset_detail)
	var detail := finance_card("gaming", "Gaming", sim.guest_gaming_profit())
	if detail != null: render_finance_gaming(detail)
	var bar_relevant: bool = sim.bar_available() or sim.staff.any(func(employee): return employee.role == "Service") or int(sim.bar_totals.sold) + int(sim.bar_totals.comped) > 0 or float(sim.expense_totals.service_payroll) > 0
	if bar_relevant:
		detail = finance_card("bar", "Bar before labor", sim.bar_margin())
		if detail != null: render_finance_bar(detail)
	if not sim.staff.is_empty() or sim.payroll > 0:
		detail = finance_card("payroll", "Payroll", -sim.payroll)
		if detail != null: render_finance_payroll(detail)
	var other_costs := float(sim.expense_totals.property_upkeep) + float(sim.expense_totals.upkeep) + float(sim.expense_totals.repairs) + float(sim.expense_totals.comps)
	if not sim.tables.is_empty() or other_costs > 0:
		detail = finance_card("operations", "Operations", -other_costs)
		if detail != null: render_finance_operations(detail)
	var investment := sim.net_capital_spending() + float(sim.expense_totals.hiring)
	if absf(float(sim.expense_totals.construction)) + absf(float(sim.expense_totals.sales)) + float(sim.expense_totals.hiring) > 0:
		detail = finance_card("investment", "Investment / setup", -investment)
		if detail != null: render_finance_investment(detail)
	finance_row(inspector, "Net cash flow", sim.net_profit(), false)
	if not finance_advanced: add_label(inspector, "Cash flow includes owner floor transfers, personal wallet transfers, event net winnings, sponsored promotions and pending floor stakes.", 12, MUTED)
	var advanced := add_button(inspector, "Advanced accounting -" if finance_advanced else "Advanced accounting >", func(): finance_advanced = not finance_advanced; refresh())
	advanced.tooltip_text = "Reconciliation and payroll diagnostics"
	if finance_advanced: render_finance_advanced(inspector)

func render_incidents() -> void:
	add_label(inspector, "MANAGEMENT DECISIONS", 11, GOLD)
	add_label(inspector, "%d open incidents" % sim.incidents.size(), 24)
	if sim.incidents.is_empty():
		add_label(inspector, "A quiet floor. Watch service coverage and crew fatigue as the evening gets busier.", 15, MUTED)
	for i in range(sim.incidents.size()):
		var item: Dictionary = sim.incidents[i]
		add_label(inspector, item.title, 17, GOLD)
		add_label(inspector, item.detail, 14)
		add_button(inspector, "Repair | $%d" % sim.repair_cost(sim.get_table(int(item.table))) if item.type == "repair" else "Offer comp | $60", func(): sim.resolve_incident(i, true); refresh())
		if item.type != "repair":
			add_button(inspector, "Dismiss complaint | -3 rep", func(): sim.resolve_incident(i, false); refresh())
		add_gap(inspector, 8)

func render_guest() -> void:
	if not context_expanded:
		render_context_summary()
		return
	add_label(inspector, "GUEST INSPECTOR", 11, GOLD)
	var found := sim.guests.filter(func(g): return int(g.id) == selected_guest)
	if found.is_empty():
		add_label(inspector, "Guest has left the casino.", 18)
		return
	var guest: Dictionary = found[0]
	add_label(inspector, guest.name, 25, GOLD if guest.vip else TEXT)
	add_label(inspector, sim.guest_profile_name(guest) + " / " + str(guest.state), 14, TEAL)
	var summary := "Wallet %s\nGaming net %s\nSatisfaction %.0f%%\nCurrent interest: %s" % [money(guest.wallet), money(guest.wallet + CrapsRules.exposure(guest.bets) + guest.drink_spending - guest.start), guest.satisfaction, str(Games.NAMES[sim.guest_current_interest(guest)]).replace("’", "'")]
	if sim.bar_available() or float(guest.drink_spending) > 0:
		summary += "\nDrinks paid %s\nThirst %.0f%%" % [money(guest.drink_spending), guest.thirst]
		if guest.drink_order != "": summary += "\nOrdered: " + str(CasinoTuning.DRINK_PROFILES[str(guest.drink_order)].name)
	add_label(inspector, summary, 16)
	add_gap(inspector, 8)
	add_label(inspector, '"%s"' % guest.thought, 18, GOLD)
	add_label(inspector, "Watch your guests for clues about staffing, limits, and service." if sim.bar_available() else "Watch your guests for clues about available games and busy seats.", 13, MUTED)

func row(parent: Node, columns: int = 0) -> Container:
	var container: Container = render_node(parent, "grid" if columns > 0 else "row", func(): return preload("res://scripts/responsive_grid.gd").new() if columns > 0 else preload("res://scripts/responsive_row.gd").new())
	if columns > 0: container.maximum_columns = columns
	container.add_theme_constant_override("h_separation", 6)
	container.add_theme_constant_override("v_separation", 6)
	container.add_theme_constant_override("separation", 6)
	return container

func table_action(action: String) -> void:
	if private_play:
		if action.begins_with("chip:"): felt.chip = float(action.substr(5))
		elif action == "shoot": begin_player_roll()
		elif action == "leave": leave_table()
		refresh()
		return
	if action.begins_with("chip:"):
		chip_value = float(action.substr(5))
	elif action == "more": table_options = not table_options
	elif action == "leave": leave_table()
	elif action == "shoot":
		var table := sim.get_table(sim.joined)
		if table.is_empty() or speed == 0 or felt.busy(): return
		if int(table.shooter) == 0: begin_player_roll()
		else:
			table.betting_hold = not table.betting_hold
			table.timer = 0.0
	elif action == "pass":
		var table := sim.get_table(sim.joined)
		if table.is_empty() or felt.busy(): return
		if int(table.shooter) == 0 or table.owner_queued: sim.pass_dice(sim.joined)
		else: sim.queue_for_dice(sim.joined)
	refresh()

func place_chip(kind: String) -> void:
	if rolling > 0 or felt.busy() or speed == 0 or felt.sim.joined < 0: return
	felt.sim.bet(felt.sim.joined, kind, felt.chip)
	refresh()

func begin_player_roll() -> void:
	var context: PitBossGameContext = felt.sim
	var table := context.get_table(context.joined)
	if rolling > 0 or speed == 0 or not felt.can_throw() or table.is_empty() or int(table.shooter) != 0 or not context.ready_for_play(table): return
	active_roll_table = context.joined
	felt.prepare_roll(table)
	if not context.shoot_player(active_roll_table):
		active_roll_table = -1
		refresh()
		return
	rolling = felt.animation_duration
	felt.capture_roll(table)
	refresh()

func render_craps() -> void:
	add_button(inspector, "Close table options", func(): table_options = false; refresh())
	add_button(inspector, "Resume time" if speed == 0 else "Pause time", toggle_pause)
	var table := sim.get_table(sim.joined)
	var locked: bool = rolling > 0 or felt.busy() or speed == 0 or not sim.ready_for_play(table)
	add_label(inspector, "CRAPS %02d  /  OWNER %s" % [sim.joined, money(sim.owner_bankroll)], 18, GOLD)
	add_label(inspector, "SHOOTER: %s | hand roll %d" % [sim.shooter_name(table), int(table.hand_rolls)], 15, TEAL)
	render_asset_financial_activity(inspector, int(table.id))
	var heading := "COME-OUT" if int(table.point) == 0 else "POINT %d" % int(table.point)
	dice_label = add_label(inspector, "[ %d ] [ %d ]    %s" % [table.dice[0], table.dice[1], heading], 23)
	var roll_controls := row(inspector)
	add_label(roll_controls, "Hold the dice on the felt, then flick toward the back wall.", 13, GOLD)
	add_button(roll_controls, "Pass dice to CPU" if int(table.shooter) == 0 else ("Resume CPU" if table.betting_hold else "Hold betting"), func():
		if int(table.shooter) == 0: sim.pass_dice(sim.joined)
		else:
			table.betting_hold = not table.betting_hold
			table.timer = 0.0
		refresh(), (rolling > 0 or felt.busy()))
	if int(table.shooter) != 0:
		var wait := "Betting held" if table.betting_hold else ("Paused" if speed == 0 else "Next roll ~%ds" % ceili(maxf(0, sim.roll_interval(table) - table.timer) / maxf(1, speed)))
		add_label(inspector, "%s | %s" % [wait, "you're in rotation" if table.owner_queued else "you're betting only"], 12, MUTED)
		add_button(inspector, "Skip my turns" if table.owner_queued else "Join shooter rotation", func():
			if table.owner_queued: sim.pass_dice(sim.joined)
			else: sim.queue_for_dice(sim.joined)
			refresh(), (rolling > 0 or felt.busy()))
	else:
		add_label(inspector, "Your hand continues until seven-out or you pass.", 12, MUTED)
	var chips := row(inspector)
	for value in [5, 25, 100]:
		var chip_button := add_button(chips, "$%d chips" % value, func(): chip_value = value; refresh())
		chip_button.toggle_mode = true
		chip_button.button_pressed = chip_value == value
	var tabs := row(inspector, 4)
	for category in ["Line", "Place", "Come", "Don't", "Hard", "Props", "My bets", "History"]:
		var tab := add_button(tabs, category, func(): craps_category = category; refresh())
		tab.toggle_mode = true
		tab.button_pressed = craps_category == category
	var kinds: Array = []
	var explanation := ""
	match craps_category:
		"Line":
			kinds = ["pass", "odds", "dont_pass", "lay_odds", "field"]
			explanation = "Pass / Don't Pass: even money; Don't pushes on 12. Odds: true odds, 3x limit (lay to win 3x). Field: double 2, triple 12."
		"Place":
			kinds = ["four", "five", "six", "eight", "nine", "ten"]
			explanation = "Place 4/10 pays 9:5, 5/9 pays 7:5, 6/8 pays 7:6. Bets stay up on a hit. Stakes round up to the required multiple."
		"Come":
			kinds = ["come"]
			for n in CrapsRules.NUMBERS:
				if table.owner["come_" + str(n)] > 0: kinds.append("come_odds_" + str(n))
			explanation = "After the table point, a Come bet has its own come-out roll, then travels to its own number. Numbered Come contracts always work, including table come-out."
		"Don't":
			kinds = ["dont_come"]
			for n in CrapsRules.NUMBERS:
				if table.owner["dont_come_" + str(n)] > 0: kinds.append("dont_come_odds_" + str(n))
			explanation = "Don't Come: 2/3 wins, 7/11 loses, 12 pushes. After traveling, seven wins before its number. Lay odds always work."
		"Hard":
			kinds = ["hard_4", "hard_6", "hard_8", "hard_10"]
			explanation = "Doubles win and stay up: hard 4/10 pays 7:1, hard 6/8 pays 9:1. An easy way of that number or seven loses."
		"Props":
			kinds = CrapsRules.PROPS.keys()
			explanation = "One roll only. Any craps 7:1; any seven 4:1; 3/11 pay 15:1; 2/12 pay 30:1."
		"My bets":
			add_label(inspector, "On layout: %s | owner floor net: %s" % [money(CrapsRules.exposure(table.owner)), money(sim.visitor_net)], 14, GOLD)
			for kind in table.owner:
				if table.owner[kind] <= 0: continue
				var removable := CrapsRules.removable(kind, int(table.point))
				add_button(inspector, "%s | %s%s" % [CrapsRules.name_for(kind), money(table.owner[kind]), " | remove" if removable else " | locked"], func(): sim.remove_bet(sim.joined, kind); refresh(), not removable or (rolling > 0 or felt.busy()))
			add_button(inspector, "Take down removable bets", func(): sim.reclaim(sim.joined); refresh(), (rolling > 0 or felt.busy()))
			explanation = "Established Pass and Come contracts stay until resolved. Removing a Don't contract also returns its attached odds."
		"History":
			if table.history.is_empty(): add_label(inspector, "No rolls yet.")
			for entry in table.history:
				add_label(inspector, "%d + %d = %d  |  %s%s" % [entry.a, entry.b, entry.total, entry.shooter, " | SEVEN OUT" if entry.seven_out else ""], 14, GOLD if entry.seven_out else TEXT)
	var bets_grid := row(inspector, 2)
	for kind in kinds:
		var amount := sim.bet_amount(table, kind, chip_value)
		var error := sim.bet_error(sim.joined, kind, chip_value)
		var button := add_button(bets_grid, "%s +%s\nOn: %s" % [CrapsRules.name_for(kind), money(amount), money(table.owner[kind])], func(): place_chip(kind), locked or error != "")
		button.custom_minimum_size.y = 58
		button.tooltip_text = error
	if craps_category in ["Place", "Hard", "Come"]:
		add_button(inspector, "Come-out: WORKING" if table.owner_working else "Come-out: OFF", func(): table.owner_working = not table.owner_working; refresh(), (rolling > 0 or felt.busy()))
		add_label(inspector, "Applies to Place, hardways and Come odds.", 11, MUTED)
	add_label(inspector, explanation, 12, MUTED)
	add_label(inspector, table.result, 13, GOLD)
	add_button(inspector, "Leave table / walk floor", leave_table, (rolling > 0 or felt.busy()))


func select_table(id: int) -> void:
	if sim.joined >= 0:
		return
	selected = id
	inspector_open = true
	context_expanded = false
	selected_guest = -1
	page = "table"
	if visitor: floor_view.walk_to_table(id)
	transition_pane("table")
	inspector_scroll.scroll_vertical = 0
	refresh()

func select_guest(id: int) -> void:
	if sim.joined >= 0:
		return
	selected_guest = id
	inspector_open = true
	context_expanded = false
	page = "guest"
	transition_pane("table")
	refresh()

func click_floor(at: Vector2) -> void:
	if mobile and building:
		floor_view.placement_target = at
		refresh()
		return
	commit_placement(at)

func confirm_placement() -> void:
	if not mobile: commit_placement(floor_view.preview)
	elif floor_view.placement_target.is_finite(): commit_placement(floor_view.placement_target)

func commit_placement(at: Vector2) -> void:
	if not building:
		selected = -1
		selected_guest = -1
		close_context()
		return
	if moving > 0:
		var table := sim.get_table(moving)
		if sim.can_place(at, floor_view.rotated, moving) and not sim.busy(table):
			table.x = at.x
			table.y = at.y
			table.rotated = floor_view.rotated
			moving = -1
			building = false
			transition_pane("floor")
			sim.reroute()
			sim.log_event("Table moved. Clear aisles help guests reach the rail.")
	else:
		var id := sim.place(at, floor_view.rotated, build_kind, build_slot_profile)
		if id > 0:
			selected = id
			selected_guest = -1
			page = "table"
			building = false
	refresh()

func begin_move() -> void:
	if visitor or sim.joined >= 0:
		return
	var table := sim.get_table(selected)
	if table.is_empty() or sim.busy(table): return
	floor_view.placement_target = Vector2(INF, INF)
	moving = selected
	building = true
	build_kind = sim.table_kind(table)
	if build_kind == "slots": build_slot_profile = str(table.slot_profile)
	floor_view.rotated = bool(table.rotated)
	refresh()

func toggle_build() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
		if sim.joined >= 0: return
	visitor = false
	moving = -1
	building = not building
	floor_view.placement_target = Vector2(INF, INF)
	transition_pane("floor")
	refresh()

func toggle_walk() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
		if sim.joined >= 0: return
	visitor = not visitor
	building = false
	moving = -1
	transition_pane("floor")
	page = "table"
	refresh()

func remember_management_context() -> void:
	if not play_context.is_empty(): return
	play_context = {"page": page, "pane": mobile_pane, "selected": selected, "guest": selected_guest, "inspector": inspector_open, "expanded": context_expanded, "visitor": visitor, "pan": floor_view.pan_center, "scale": floor_view.view_scale, "close": floor_view.close_view}

func restore_management_context() -> void:
	if play_context.is_empty(): return
	page = play_context.page
	transition_pane(play_context.pane)
	selected = int(play_context.selected)
	selected_guest = int(play_context.guest)
	inspector_open = bool(play_context.inspector)
	context_expanded = bool(play_context.expanded)
	visitor = bool(play_context.visitor)
	floor_view.pan_center = play_context.pan
	floor_view.view_scale = float(play_context.scale)
	floor_view.close_view = bool(play_context.close)
	play_context.clear()

func join_table() -> void:
	var table := sim.get_table(selected)
	if table.is_empty() or not visitor or not sim.ready_for_play(table) or sim.player.distance_to(sim.bounds(table).get_center()) > 165:
		return
	if sim.seated(selected).size() >= 8:
		sim.log_event("All eight seats are taken. Try another table.")
		refresh()
		return
	remember_management_context()
	if not sim.join_table(selected):
		play_context.clear()
		return
	table_options = false
	transition_pane("table")
	page = "table"
	inspector_scroll.scroll_vertical = 0
	sim.player = sim.approach_position(table)
	floor_view.move_target = Vector2(INF, INF)
	refresh()

func leave_table() -> void:
	if private_play:
		if game_view.locked(): return
		private_play = false
		sim.location.station = -1
		game_view.sim = PitBossGameContext.new(sim)
		felt.sim = game_view.sim
		checkpoint_owner_play()
		refresh()
		return
	if is_instance_valid(game_view) and game_view.visible and game_view.art.spinning > 0: return
	if not sim.owner_play.is_empty():
		if not sim.exit_owner_event(): return
		sim.owner_play.clear()
		checkpoint_owner_play()
		visitor = false
		page = "table"
		transition_pane("floor")
		restore_management_context()
		refresh()
		return
	if rolling > 0:
		return
	sim.leave_table()
	if sim.joined >= 0:
		refresh()
		return
	table_options = false
	transition_pane("floor")
	restore_management_context()
	layout_ui()
	refresh()

func toggle_doors() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
	sim.set_open(not sim.opened)
	refresh()

func toggle_pause() -> void:
	if rolling > 0:
		return
	if speed == 0:
		speed = previous_speed
	else:
		previous_speed = speed
		speed = 0
	refresh()

func save_game() -> void:
	if rolling > 0:
		return
	var file := FileAccess.open(CasinoTuning.SAVE_PATH, FileAccess.WRITE)
	if file == null:
		sim.log_event("Save failed: browser storage is unavailable.")
	else:
		file.store_string(JSON.stringify(sim.snapshot()))
		file.close()
		sim.log_event("Casino saved locally in this browser.")
	refresh()

func load_game() -> bool:
	if rolling > 0:
		return false
	if not FileAccess.file_exists(CasinoTuning.SAVE_PATH):
		sim.log_event("No local save found. Save your casino first.")
		refresh()
		return false
	var data = JSON.parse_string(FileAccess.get_file_as_string(CasinoTuning.SAVE_PATH))
	if data is Dictionary and data.get("version") != CasinoTuning.SAVE_VERSION:
		var removed := DirAccess.remove_absolute(CasinoTuning.SAVE_PATH)
		sim.log_event("Older pre-alpha save cleared. Start a new casino." if removed == OK else "Older pre-alpha save is incompatible. Start a new casino.")
		refresh()
		return false
	var restored: bool = data is Dictionary and sim.restore(data)
	if not restored:
		sim.log_event("Save could not be loaded. The file and current casino were retained.")
	else:
		play_context.clear()
		milestone_notice.reset()
		reset_dev_speed()
		event_focus_staff = -1
		bind_optional_events()
		if is_instance_valid(developer_panel): developer_panel.reset_session(sim)
		reset_treasury_display()
		floor_view.clear_financial_feedback()
		in_back_room = sim.location.area == "private"
		private_play = false
		recovery_view.hide()
		back_room_floor.sim = PitBossFloorContext.new(sim, true)
		game_view.sim = PitBossGameContext.new(sim)
		felt.sim = game_view.sim
		if in_back_room and int(sim.location.station) > 0:
			var station: Dictionary = back_room_floor.sim.get_table(int(sim.location.station))
			if station.get("kind") == sim.back_room.state.kind:
				private_play = true
				game_view.sim = PitBossGameContext.new(sim, station)
				felt.sim = game_view.sim
		visitor = in_back_room or sim.joined >= 0
		page = "table"
		selected = sim.joined if sim.joined >= 0 else (int(sim.tables[0].id) if not sim.tables.is_empty() else -1)
		building = false
		moving = -1
		selected_guest = -1
		transition_pane("table" if visitor else "floor")
		tick = 0
		sim.log_event("Casino restored, including guests, wagers and dice state.")
	refresh()
	return restored

func close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null
		for child in get_children():
			if child.has_meta("modal_shade"):
				child.queue_free()

func dialog(title: String, body: String, confirm: String, action: Callable, cancellable: bool = true) -> VBoxContainer:
	if modal != null:
		return null
	modal = panel_at(Vector2(390, 190), Vector2(660, 500))
	modal.minimum_size_changed.connect(func(): call_deferred("layout_dialog"))
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.position = Vector2(-390, -190)
	shade.size = Vector2(1440, 900)
	shade.set_meta("modal_shade", true)
	add_child(shade)
	move_child(shade, modal.get_index())
	shade.position = Vector2.ZERO
	# Keep the backdrop behind the opaque panel contents.
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 18)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	modal.add_child(scroll)
	layout.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(layout)
	add_label(layout, "P I T   B O S S", 13, GOLD)
	add_label(layout, title, 31)
	add_label(layout, body, 17)
	add_gap(layout, 8)
	add_button(layout, confirm, func(): close_modal(); action.call())
	if cancellable:
		add_button(layout, "Cancel", close_modal)
	layout_ui()
	return layout

func show_help() -> void:
	var body := "Version %s | Last updated %s\n\n" % [BuildInfo.VERSION, BuildInfo.UPDATED_AT]
	body += sim.onboarding_text() + "\n\n" + sim.next_milestone_text()
	body += "\n\nTap a game to inspect it. Walk mode: approach a game, then Join. Owner play uses a separate Owner Bankroll starting at $1,000; casino cash pays for construction, staff and payouts."
	if sim.feature_owned("service"): body += "\n\nDrink staff walk the floor. Recent gamblers receive basic comps; waiting and watching guests pay. Deliveries relieve thirst and support longer sessions."
	if sim.feature_owned("craps"):
		body += "\n\nCraps needs two dealers. The shooter keeps the dice until seven-out. Pass dice hands off to a CPU; Hold betting pauses that table's CPU rolls. My bets lists contracts and removable stakes."
	body += "\n\nOn phones use Floor, Build, Staff and More. Guests, Finance and House Activity are also available in More. Save locally before leaving."
	dialog("Build your house.", body, "Back to casino", func(): pass, false)

func show_wallet_transfer() -> void:
	var amount := SpinBox.new()
	amount.min_value = 0.01
	amount.max_value = maxf(0.01, sim.owner_bankroll)
	amount.step = 0.01
	amount.value = minf(100, sim.owner_bankroll)
	amount.prefix = "$"
	amount.custom_minimum_size.y = 44
	var layout := dialog("Transfer to casino", "Personal wallet: $%.2f\nChoose how much to add to Casino Cash." % sim.owner_bankroll, "Transfer", func():
		if not sim.transfer_personal_to_casino(amount.value):
			sim.log_event("Transfer failed. Check your available personal funds and local storage.")
		refresh())
	if layout == null:
		amount.free()
		return
	modal.z_index = 40
	for child in get_children():
		if child.has_meta("modal_shade"): child.z_index = 39
	layout.add_child(amount)
	layout.move_child(amount, 3)

func confirm_reset() -> void:
	dialog("Start a new casino?", "Your existing local save is kept until you save again. Choose difficulty and starting games next.", "Choose new-game setup", func(): show_new_game_setup())

func show_new_game_setup(initial: bool = false) -> void:
	var mode := OptionButton.new()
	mode.add_item("Normal | intended progression")
	mode.add_item("Easy / Sandbox-lite | permissive access")
	mode.custom_minimum_size.y = 44
	mode.fit_to_longest_item = false
	mode.clip_text = true
	var games_box := VBoxContainer.new()
	var choices: Array = []
	add_label(games_box, "Easy starting games - choose one or more (equipment and required crews included):", 14, MUTED)
	for kind in ["slots", "blackjack", "roulette", "craps", "holdem"]:
		var choice := CheckButton.new()
		choice.text = Games.NAMES[kind]
		choice.button_pressed = kind in ["slots", "blackjack"]
		choice.set_meta("game_kind", kind)
		games_box.add_child(choice)
		choices.append(choice)
	games_box.hide()
	mode.item_selected.connect(func(index: int): games_box.visible = index == 1)
	var body := "Normal is the intended tycoon experience: $%d, two basic slots, no staff. Earn Casino Rating to access new games and services.\n\nEasy starts with $%d and your favorite games, ready crews, the full floor and unrestricted access. Wages, upkeep and real gaming outcomes still apply." % [CasinoTuning.STARTING_CASH, CasinoTuning.DIFFICULTIES.easy.cash]
	var layout := dialog("New casino | choose your start", body, "Start casino", func():
		var preferred: Array = []
		for choice in choices:
			if choice.button_pressed: preferred.append(str(choice.get_meta("game_kind")))
		# An empty Easy selection safely starts with slots.
		start_casino("normal" if mode.selected == 0 else "easy", preferred), not initial)
	if layout == null:
		mode.free()
		games_box.free()
		return
	# Add setup controls before the Start button inside the scrolling modal.
	layout.add_child(mode)
	layout.move_child(mode, 3)
	layout.add_child(games_box)
	layout.move_child(games_box, 4)
	if initial and FileAccess.file_exists(CasinoTuning.SAVE_PATH):
		add_button(layout, "Continue saved casino", func():
			if load_game(): close_modal()
			else:
				add_label(layout, "Could not load this save. Choose a new casino setup.", 14, GOLD))
	layout_ui()

func start_casino(mode: String, preferred: Array) -> void:
	in_back_room = false
	private_play = false
	back_room_floor.hide()
	recovery_view.hide()
	play_context.clear()
	event_focus_staff = -1
	sim = CasinoSimulation.new(mode, preferred)
	sim.milestone_reached.connect(on_milestone)
	milestone_notice.reset()
	reset_treasury_display()
	floor_view.sim = PitBossFloorContext.new(sim)
	back_room_floor.sim = PitBossFloorContext.new(sim, true)
	recovery_view.sim = sim
	game_view.sim = PitBossGameContext.new(sim)
	felt.sim = game_view.sim
	bind_optional_events()
	if is_instance_valid(developer_panel): developer_panel.reset_session(sim)
	selected = int(sim.tables[0].id)
	selected_guest = -1
	inspector_open = false
	context_expanded = false
	visitor = false
	building = false
	moving = -1
	floor_view.rotated = false
	reset_dev_speed()
	tick = 0
	rolling = 0
	active_roll_table = -1
	page = "table"
	transition_pane("floor")
	refresh()

func publish_debug() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		return
	var buttons: Array = []
	for button in get_tree().get_nodes_in_group("debug_buttons"):
		if button.is_visible_in_tree():
			var rect: Rect2 = button.get_global_rect()
			var clip := Rect2(Vector2.ZERO, Vector2(get_window().content_scale_size))
			var ancestor := button.get_parent()
			while ancestor != null:
				if ancestor is ScrollContainer: clip = clip.intersection(ancestor.get_global_rect())
				ancestor = ancestor.get_parent()
			buttons.append({"text": button.text, "disabled": button.disabled, "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y, "clip": [clip.position.x, clip.position.y, clip.size.x, clip.size.y]})
	debug_full_timer += CasinoTuning.DEBUG_SNAPSHOT_SECONDS
	var full := debug_full_timer >= CasinoTuning.DEBUG_FULL_SNAPSHOT_SECONDS or bool(JavaScriptBridge.eval("window.pitBossRequestFullState === true", true))
	if full: debug_full_timer = 0
	var diagnostics := {"elapsed": sim.elapsed, "day": sim.day, "minute": sim.minute, "cash": sim.cash, "speed": speed, "guests": sim.guests.size(), "assets": sim.tables.size(), "staff": sim.staff.size(), "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "redraws": floor_view.redraw_count, "momentum": sim.momentum.value, "momentum_band": sim.momentum.band(), "momentum_contributors": sim.momentum.contributors}
	JavaScriptBridge.eval("window.pitBossDiagnostics = " + JSON.stringify(diagnostics), true)
	var mobile_rects := {}
	for entry in [{"name": "bottom_nav", "control": bottom_nav}, {"name": "floor_actions", "control": floor_actions}, {"name": "mode_hint", "control": mode_hint}, {"name": "palette", "control": presentation_shell.mobile_management.palette}, {"name": "inspector", "control": inspector_panel}, {"name": "events", "control": events_panel}, {"name": "side", "control": side_panel}]:
		var rect: Rect2 = entry.control.get_global_rect()
		mobile_rects[entry.name] = {"rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y], "visible": entry.control.is_visible_in_tree()}
	var layout := {
		"viewport": [viewport_dimensions.x, viewport_dimensions.y],
		"safe_area": [viewport_insets.x, viewport_insets.y, viewport_insets.z, viewport_insets.w],
		"layout_count": viewport_layout_count, "mobile_rects": mobile_rects,
		"mobile_floor": [floor_view.mobile_viewport.position.x, floor_view.mobile_viewport.position.y, floor_view.mobile_viewport.size.x, floor_view.mobile_viewport.size.y],
		"responsive_state": responsive_state, "pane": mobile_pane, "page": page,
		"building": building, "moving": moving, "visitor": visitor,
		"selected": selected, "selected_guest": selected_guest, "joined": sim.joined,
		"floor_visible": floor_view.visible, "inspector_visible": inspector_panel.visible,
		"floor": [floor_view.position.x, floor_view.position.y, floor_view.size.x, floor_view.size.y],
		"camera": [floor_view.camera.x, floor_view.camera.y], "zoom": floor_view.zoom,
		"labels": debug_label_layout(inspector) if full else [],
	}
	JavaScriptBridge.eval("window.pitBossLayout = " + JSON.stringify(layout), true)
	JavaScriptBridge.eval("window.pitBossUI = " + JSON.stringify(buttons), true)
	if full: JavaScriptBridge.eval("window.pitBossSnapshot = " + JSON.stringify(sim.snapshot()), true)

func debug_label_layout(parent: Node) -> Array:
	var labels: Array = []
	for child in parent.get_children():
		if child is Label:
			labels.append({"text": child.text, "width": child.size.x, "minimum": child.get_combined_minimum_size().x, "wrap": child.autowrap_mode})
		labels.append_array(debug_label_layout(child))
	return labels

# Retain presentation nodes. Each parent has an ordered cursor; only a changed
# node kind or child count creates/frees structure. Values update on live nodes.
func render_node(parent: Node, kind: String, create: Callable) -> Control:
	if not retained_render:
		var child: Control = create.call()
		parent.add_child(child)
		return child
	var index := int(render_cursors.get(parent, 0))
	render_cursors[parent] = index + 1
	var child: Control
	if index < parent.get_child_count() and str(parent.get_child(index).get_meta("render_kind", "")) == kind:
		child = parent.get_child(index)
	else:
		while parent.get_child_count() > index:
			var obsolete := parent.get_child(index)
			parent.remove_child(obsolete)
			obsolete.queue_free()
		child = create.call()
		child.set_meta("render_kind", kind)
		parent.add_child(child)
	if child is Container or child is Button: render_cursors[child] = 0
	return child

func finish_render() -> void:
	for parent in render_cursors:
		if parent is Button and not bool(parent.get_meta("render_toned", false)) and parent.has_meta("button_tone"):
			for state in ["normal", "hover", "pressed"]: parent.remove_theme_stylebox_override(state)
			parent.remove_meta("button_tone")
		var count := int(render_cursors[parent])
		while parent.get_child_count() > count:
			var obsolete: Node = parent.get_child(count)
			parent.remove_child(obsolete)
			obsolete.queue_free()
	render_cursors.clear()
	retained_render = false

func bind_optional_events() -> void:
	sim.owner_checkpoint = checkpoint_owner_play
	if not sim.optional_events.action_requested.is_connected(on_optional_event_action):
		sim.optional_events.action_requested.connect(on_optional_event_action)
	if is_instance_valid(event_cards): event_cards.current_id = -1
	if is_instance_valid(objective_cards): objective_cards.reset()

func on_optional_event_action(event: Dictionary) -> void:
	# Game commitment stays in the expandable card; no blocking dialog.
	match str(event.action):
		"focus_asset":
			selected = int(event.target)
			selected_guest = -1
			open_page("table")
			sim.optional_events.resolve(sim, int(event.id), "success")
		"open_staff":
			if sim.optional_events.DEFINITIONS[event.type].target_kind == "staff":
				for employee in sim.staff:
					if int(employee.id) == int(event.target):
						selected = int(employee.table)
						event_focus_staff = int(employee.id)
						staff_details_role = "Dealer"
			else: selected = int(event.target) if int(event.target) >= 0 else selected
			open_page("staff")
			sim.optional_events.resolve(sim, int(event.id), "success")
		"open_bar":
			open_page("bar")
			sim.optional_events.resolve(sim, int(event.id), "success")
		"owner_game":
			event_cards.details.show()
	refresh()

func checkpoint_owner_play() -> bool:
	# Rename a complete snapshot, preserving the last good save on write failure.
	var temporary := owner_checkpoint_path + ".tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		sim.log_event("Owner event unavailable: local save storage cannot be written.")
		return false
	var checkpoint_text := JSON.stringify(sim.snapshot())
	file.store_string(checkpoint_text)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if ok:
		var verified = JSON.parse_string(FileAccess.get_file_as_string(temporary))
		ok = verified is Dictionary and verified == JSON.parse_string(checkpoint_text)
	if ok: ok = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(owner_checkpoint_path)) == OK
	if not ok: sim.log_event("Owner event checkpoint failed. Local storage is unavailable.")
	return ok

func render_context_summary() -> void:
	if mobile:
		if page == "guest":
			var guest: Dictionary = floor_view.presentation.get("guests", {}).get(selected_guest, {})
			if guest.is_empty():
				add_label(inspector, "Guest has left the casino.", 16)
				return
			add_label(inspector, str(guest.name), 18, GOLD if guest.vip else TEXT)
			add_label(inspector, "%s | Satisfaction %.0f%%" % [guest.state, guest.satisfaction], 14, TEAL)
		else:
			var asset := sim.get_table(selected)
			if asset.is_empty():
				add_label(inspector, "Select an object or guest.", 16)
				return
			add_label(inspector, "%s #%d" % [sim.asset_name(asset), selected], 16, TEXT)
			var performance := sim.asset_performance(asset)
			var state := "Repair needed" if asset.broken else "Open" if sim.operating(asset) else "Closed" if not sim.opened or not asset.staff_enabled else "Needs staff"
			add_label(inspector, "%s | %d/%d players | Win %s" % [state, sim.seated(selected).size(), sim.guest_capacity(asset), compact_money(float(performance.guest_win))], 14, TEAL)
		return

	if page == "guest":
		var found := sim.guests.filter(func(guest): return int(guest.id) == selected_guest)
		if found.is_empty():
			add_label(inspector, "Guest has left the casino.", 22)
			return
		var guest: Dictionary = found[0]
		add_label(inspector, guest.name, 28, GOLD if guest.vip else TEXT)
		add_label(inspector, "%s | Satisfaction %.0f%%" % [guest.state, guest.satisfaction], 18, TEAL)
		add_label(inspector, '"%s"' % guest.thought, 18, TEXT)
		return
	var table := sim.get_table(selected)
	if table.is_empty():
		add_label(inspector, "Select a casino object or guest.", 22)
		return
	var summary: Container = render_node(inspector, "summary_mobile" if mobile else "summary_desktop", func(): return VBoxContainer.new() if mobile else HBoxContainer.new())
	summary.size_flags_horizontal = SIZE_EXPAND_FILL
	summary.add_theme_constant_override("separation", 12)
	if not mobile:
		var thumbnail: TextureRect = render_node(summary, "thumbnail", func(): return TextureRect.new())
		var kind := sim.table_kind(table)
		var asset := "casino/slots/slot_%02d.png" % (1 + int(table.id) % 5) if kind == "slots" else "casino/tables/" + ("ultimate_texas" if kind == "holdem" else kind) + ".png"
		thumbnail.texture = preload("res://presentation/art_catalog.gd").texture_for(kind, int(table.id))
		thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		thumbnail.custom_minimum_size = Vector2(100, 100)
	var identity: VBoxContainer = render_node(summary, "identity", func(): return VBoxContainer.new())
	identity.size_flags_horizontal = SIZE_EXPAND_FILL
	add_label(identity, sim.asset_name(table), 28, TEXT)
	add_label(identity, sim.table_status(table) if mobile else "REPAIR NEEDED" if table.broken else "OPEN" if sim.operating(table) else "CASINO CLOSED" if not sim.opened else "STAFFING PAUSED" if not table.staff_enabled else "NEEDS COVERAGE", 15, TEAL if sim.operating(table) else GOLD)
	if not mobile:
		add_label(identity, "Condition: " + ("Needs repair" if table.broken else "Working"), 13, MUTED)
		if sim.required_crew(table) > 0: add_label(identity, "Dealers %d / %d" % [sim.crew(selected).size(), sim.required_crew(table)], 13, MUTED)
	var figures: VBoxContainer = render_node(summary, "figures", func(): return VBoxContainer.new())
	figures.size_flags_horizontal = SIZE_EXPAND_FILL
	var performance := sim.asset_performance(table)
	add_label(figures, "Gaming win " + FinancialText.house_result(float(performance.guest_win)), 22, TEAL if float(performance.guest_win) >= 0 else Color("ef4444"))
	add_label(figures, "%d / %d players | Minimum %s" % [sim.seated(selected).size(), sim.guest_capacity(table), money(table.minimum)], 18, TEXT)
	var actions := row(inspector)
	if visitor:
		add_button(actions, "Join game", join_table, not can_join())
	else:
		add_button(actions, "Walk to play", toggle_walk)
	add_button(actions, "Move", begin_move, visitor or sim.busy(table))
	add_button(actions, "Configure", func(): context_expanded = true; refresh())
	if not mobile:
		add_button(actions, "Set minimum", func(): sim.change_minimum(selected); refresh())
		if sim.required_crew(table) > 0: add_button(actions, "Staff", func(): open_page("staff"))

func render_guest_directory() -> void:
	add_label(inspector, "Guests on the floor", 28, TEXT)
	if sim.guests.is_empty():
		add_label(inspector, "Open the casino to welcome guests.", 18, MUTED)
	for guest in sim.guests:
		var line := row(inspector)
		add_label(line, "%s | %s" % [guest.name, guest.state], 18)
		add_button(line, "Inspect", func(): select_guest(int(guest.id)))

func render_desktop_build() -> void:
	add_label(inspector, "BUILD YOUR FLOOR", 20, GOLD)
	var tabs := row(inspector)
	for category in ["slots", "tables", "amenities"]:
		var tab := add_button(tabs, category.capitalize(), func(): desktop_build_category = category; refresh())
		tab.button_pressed = desktop_build_category == category
		tab.toggle_mode = true
	if desktop_build_category == "slots":
		for id in CasinoTuning.SLOT_PROFILES: render_build_card("slots", id)
	elif desktop_build_category == "amenities":
		render_amenities()
	else:
		for kind in Games.COSTS:
			if kind != "slots": render_build_card(kind)
	add_label(inspector, "Placement preserves clear aisles. Drag the floor to pan; R rotates.", 13, MUTED)
	add_button(inspector, "Casino development", func(): open_page("development"))

func render_build_card(kind: String, profile_id: String = "starter") -> void:
	var available := sim.slot_unlocked(profile_id) if kind == "slots" else sim.unlocked(kind)
	var cost := sim.purchase_cost(kind, profile_id)
	var card: PanelContainer = render_node(inspector, "build_card", func(): return PanelContainer.new())
	var content := row(card)
	content.add_theme_constant_override("separation", 12)
	var thumb: TextureRect = render_node(content, "art", func(): return TextureRect.new())
	thumb.texture = preload("res://presentation/art_catalog.gd").texture_for(kind)
	thumb.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	thumb.custom_minimum_size = Vector2(60, 80)
	var info: VBoxContainer = render_node(content, "info", func(): return VBoxContainer.new())
	info.size_flags_horizontal = SIZE_EXPAND_FILL
	add_label(info, str(CasinoTuning.SLOT_PROFILES[profile_id].name) if kind == "slots" else Games.NAMES[kind], 16, TEXT)
	add_label(info, money(cost), 17, GOLD)
	var button := add_button(info, "Place" if available else "Locked / development required", func(): build_kind = kind; build_slot_profile = profile_id; toggle_build(), not available or sim.cash < cost)
	button.custom_minimum_size.y = 34
	button.add_theme_font_size_override("font_size", 13)
	button.tooltip_text = table_purchase_tooltip(kind) if kind != "slots" else "Purchase this machine profile using casino cash."


func walk_to_private_door() -> void:
	if sim.joined >= 0 or not sim.owner_play.is_empty(): return
	cancel_placement()
	visitor = true
	transition_pane("floor")
	if not floor_view.approach_private_door():
		sim.log_event("No clear route to the Back Room door.")
	refresh()

func enter_back_room() -> void:
	if sim.player.distance_to(floor_view.sim.door_approach()) > 8: return
	if sim.joined >= 0 or not sim.owner_play.is_empty(): return
	in_back_room = true
	sim.location.area = "private"
	back_room_floor.visitor_mode = true
	back_room_floor.close_view = true
	checkpoint_owner_play()
	layout_ui()
	refresh()

func exit_back_room() -> void:
	if back_room_floor.sim.player.distance_to(back_room_floor.sim.door_approach()) > 8: return
	in_back_room = false
	sim.location.area = "public"
	sim.location.station = -1
	sim.player = floor_view.sim.safe_public_threshold()
	visitor = true
	floor_view.walk_path.clear()
	floor_view.move_target = Vector2(INF, INF)
	checkpoint_owner_play()
	transition_pane("floor")
	layout_ui()
	refresh()

func open_private_station(station: Dictionary) -> void:
	if sim.back_room.busy() and sim.back_room.state.kind != station.kind:
		sim.log_event("Finish the active private game before switching. Use Resume active game.")
		refresh()
		return
	if sim.back_room.state.kind != station.kind or not sim.back_room.busy():
		if not sim.private_action(int(sim.back_room.state.sequence), "choose", {"kind": station.kind}): return
	sim.location.station = int(station.id)
	private_play = true
	game_view.sim = PitBossGameContext.new(sim, station)
	felt.sim = game_view.sim
	game_view.render_current()
	checkpoint_owner_play()
	layout_ui()
	refresh()

func resume_private_game() -> void:
	for station in back_room_floor.sim.stations:
		if station.kind == sim.back_room.state.kind:
			back_room_floor.approach_station(station.id)
			return
