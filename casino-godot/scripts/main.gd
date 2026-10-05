extends Control

const FinancialText = preload("res://scripts/financial_text.gd")
const DeveloperPanel = preload("res://scripts/developer_panel.gd")
const BuildInfo = preload("res://scripts/build_info.gd")
const FloorScript = preload("res://scripts/floor.gd")
const Games = preload("res://scripts/casino_games.gd")
const GameView = preload("res://scripts/game_view.gd")
const FeltScript = preload("res://scripts/craps_layout.gd")
const GOLD := Color("e3bb70")
const TEAL := Color("57d6b1")
const MUTED := Color("9bafc2")
const TEXT := Color("dbe5ed")

var displayed_cash := 0.0
var treasury_target := 0.0
var treasury_flash := 0.0
var treasury_direction := 0.0
var developer_panel: PanelContainer
var sim := CasinoSimulation.new()
var floor_view: Control
var selected := 1
var selected_guest := -1
var visitor := false
var building := false
var build_kind := "slots"
var build_slot_profile := "starter"
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
var rolling := 0.0
var page := "table"
var stats: Label
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
var brand: Label
var subtitle: Label
var header_actions: HBoxContainer
var side_panel: PanelContainer
var inspector_panel: PanelContainer
var inspector_scroll: ScrollContainer
var events_panel: PanelContainer
var bottom_nav: HBoxContainer
var floor_actions: HBoxContainer
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
var table_scroll: ScrollContainer
var table_options := false
var chip_value := 25.0
var craps_category := "Line"
var active_roll_table := -1

func _ready() -> void:
	displayed_cash = sim.cash
	treasury_target = sim.cash
	var theme := Theme.new()
	theme.default_font_size = 14
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("233747")
		if state == "hover": bg = Color("325365")
		if state == "pressed": bg = Color("41625e")
		if state == "disabled": bg = Color("162433")
		var box := style(bg, Color("3c5360") if state != "focus" else GOLD)
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_disabled_color", "Button", Color("5e7184"))
	self.theme = theme
	backdrop = ColorRect.new()
	backdrop.color = Color("0b121d")
	backdrop.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(backdrop)
	brand = label_at(Vector2.ZERO, "N E O N   H O U S E", 24, GOLD)
	subtitle = label_at(Vector2.ZERO, "CASINO TYCOON  /  " + BuildInfo.VERSION, 11, MUTED)
	stats = label_at(Vector2.ZERO, "", 30, TEXT)
	hud_summary = label_at(Vector2.ZERO, "", 13, MUTED)
	status = label_at(Vector2.ZERO, "", 12, MUTED)
	header_actions = HBoxContainer.new()
	header_actions.add_theme_constant_override("separation", 6)
	add_child(header_actions)
	add_button(header_actions, "Save", save_game)
	add_button(header_actions, "Load", load_game)
	add_button(header_actions, "Help", show_help)
	mobile_menu = MenuButton.new()
	mobile_menu.text = "Menu"
	mobile_menu.custom_minimum_size = Vector2(64, 44)
	add_child(mobile_menu)
	var global_menu := mobile_menu.get_popup()
	global_menu.add_theme_constant_override("v_separation", 18)
	global_menu.add_theme_font_size_override("font_size", 16)
	for title in ["Save", "Load", "Help"]: global_menu.add_item(title)
	global_menu.id_pressed.connect(global_action)
	mobile_speed = add_button(self, "1x", func():
		if speed == 0: speed = 1
		elif speed == 1: speed = 2
		elif speed == 2: speed = 4
		else: speed = 0
		if speed > 0: previous_speed = speed
		refresh())
	if OS.is_debug_build(): mobile_dev = add_button(self, "DEV", toggle_dev_panel)
	mode_hint = label_at(Vector2.ZERO, "", 13, MUTED)
	mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side_panel = panel_at(Vector2.ZERO, Vector2.ZERO)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	side_panel.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left)
	add_label(left, "YOUR CASINO", 13, GOLD)
	doors_button = add_button(left, "Open casino", toggle_doors)
	button_tone(doors_button, "primary")
	build_button = add_button(left, "+ Build games...", func():
		if building: toggle_build()
		else: open_page("build"))
	walk_button = add_button(left, "Walk the floor", toggle_walk)
	add_gap(left, 6)
	objective = VBoxContainer.new()
	objective.add_theme_constant_override("separation", 6)
	left.add_child(objective)
	add_gap(left, 8)
	add_label(left, "MANAGEMENT", 11, MUTED)
	add_button(left, "Casino development", func(): open_page("development"))
	add_button(left, "Staff & assignments", func(): open_page("staff"))
	add_button(left, "Finance", func(): open_page("finance"))
	add_button(left, "Incidents & decisions", func(): open_page("incidents"))
	add_gap(left, 10)
	add_label(left, "TIME CONTROLS", 11, MUTED)
	var speeds := HBoxContainer.new()
	left.add_child(speeds)
	pause_button = add_button(speeds, "Pause", toggle_pause)
	pause_button.size_flags_stretch_ratio = 1.8
	for multiplier in [1, 2, 4]:
		add_button(speeds, "%dx" % multiplier, func(): speed = multiplier; previous_speed = multiplier; refresh())
	for control in speeds.get_children():
		control.add_theme_font_size_override("font_size", 13)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var skin: StyleBoxFlat = control.get_theme_stylebox(state).duplicate()
			skin.content_margin_left = 6
			skin.content_margin_right = 6
			control.add_theme_stylebox_override(state, skin)
	add_label(left, "Space to pause. R to rotate while building.", 12, MUTED)
	button_tone(add_button(left, "New casino...", confirm_reset), "danger")
	floor_view = FloorScript.new()
	floor_view.sim = sim
	floor_view.table_clicked.connect(select_table)
	floor_view.floor_clicked.connect(click_floor)
	floor_view.guest_clicked.connect(select_guest)
	add_child(floor_view)
	felt = FeltScript.new()
	felt.sim = sim
	felt.bet_clicked.connect(place_chip)
	felt.action_requested.connect(table_action)
	table_scroll = ScrollContainer.new()
	table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	table_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(table_scroll)
	table_scroll.add_child(felt)
	felt.size_flags_horizontal = SIZE_EXPAND_FILL
	floor_actions = HBoxContainer.new()
	floor_actions.add_theme_constant_override("separation", 6)
	add_child(floor_actions)
	add_button(floor_actions, "Walk / Manage", toggle_walk)
	floor_join_button = add_button(floor_actions, "Inspect table", func():
		if visitor and can_join(): join_table()
		else: open_page("table"))
	rotate_button = add_button(floor_actions, "Rotate", func(): floor_view.rotated = not floor_view.rotated; refresh())
	floor_fit = add_button(floor_actions, "Fit", func(): floor_view.toggle_fit(); refresh())
	game_view = GameView.new()
	game_view.sim = sim
	game_view.leave_requested.connect(leave_table)
	game_view.changed.connect(refresh)
	game_view.pause_requested.connect(toggle_pause)
	add_child(game_view)
	game_view.hide()
	inspector_panel = panel_at(Vector2.ZERO, Vector2.ZERO)
	inspector_scroll = ScrollContainer.new()
	inspector_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	inspector_panel.add_child(inspector_scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 8)
	inspector_scroll.add_child(inspector)
	events_panel = panel_at(Vector2.ZERO, Vector2.ZERO)
	var log_scroll := ScrollContainer.new()
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	events_panel.add_child(log_scroll)
	feed = VBoxContainer.new()
	feed.size_flags_horizontal = SIZE_EXPAND_FILL
	feed.add_theme_constant_override("separation", 6)
	log_scroll.add_child(feed)
	bottom_nav = HBoxContainer.new()
	bottom_nav.add_theme_constant_override("separation", 6)
	add_child(bottom_nav)
	for tab in ["Floor", "Table", "Manage", "Log"]:
		add_button(bottom_nav, tab, func(): switch_mobile(tab.to_lower()))
	get_viewport().size_changed.connect(func(): call_deferred("layout_ui"))
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

func layout_ui() -> void:
	if not is_instance_valid(bottom_nav): return
	var dimensions := Vector2(get_window().size)
	if OS.has_feature("web"):
		dimensions = Vector2(float(JavaScriptBridge.eval("window.innerWidth", true)), float(JavaScriptBridge.eval("window.innerHeight", true)))
	dimensions.x = maxf(320, dimensions.x)
	dimensions.y = maxf(300, dimensions.y)
	if get_window().content_scale_size != Vector2i(dimensions):
		get_window().content_scale_size = Vector2i(dimensions)
	var w := dimensions.x
	var h := dimensions.y
	var landscape := w > h and h < 600
	mobile = w < 1180 or h < 650
	responsive_state = "desktop" if not mobile else "mobile landscape" if landscape else "mobile portrait" if w < h else "compact"
	floor_view.configure_view(mobile, landscape)
	backdrop.size = dimensions
	brand.text = "NEON HOUSE" if mobile else "N E O N   H O U S E"
	brand.add_theme_font_size_override("font_size", 16 if mobile else 24)
	brand.position = Vector2(12 if mobile else 20, 8 if mobile else 18)
	subtitle.visible = not mobile
	subtitle.position = Vector2(20, 50)
	header_actions.position = Vector2(w - 198, 34) if mobile else Vector2(w - 260, 16)
	header_actions.size = Vector2(186 if mobile else 240, 44)
	header_actions.visible = not mobile
	mobile_menu.visible = mobile
	mobile_speed.visible = mobile
	mobile_menu.position = Vector2(w - 72, 4)
	mobile_menu.size = Vector2(64, 44)
	mobile_speed.position = Vector2(w - 138, 4)
	mobile_speed.size = Vector2(60, 44)
	if is_instance_valid(mobile_dev):
		mobile_dev.visible = mobile
		mobile_dev.position = Vector2(w - 204, 4)
		mobile_dev.size = Vector2(60, 44)
	brand.visible = not mobile

	stats.position = Vector2(8, 5) if mobile else Vector2(280, 10)
	stats.add_theme_font_size_override("font_size", 22 if mobile else 30)
	stats.clip_text = true
	stats.size = Vector2(maxf(96, w - (212 if OS.is_debug_build() else 146)) if mobile else 330, 32)
	hud_summary.position = Vector2(8, 48) if mobile else Vector2(280, 48)
	hud_summary.add_theme_font_size_override("font_size", 14 if mobile else 13)
	hud_summary.size = Vector2(w * 0.55 if mobile else 340, 22)
	status.position = Vector2(w * 0.55, 48) if mobile else Vector2(620, 24)
	status.size = Vector2(w * 0.45 - 8 if mobile else maxf(120, w - 905), 24 if mobile else 40)
	status.autowrap_mode = TextServer.AUTOWRAP_OFF if mobile else TextServer.AUTOWRAP_WORD_SMART
	status.add_theme_font_size_override("font_size", 14 if mobile else 12)
	mode_hint.visible = not mobile
	bottom_nav.visible = mobile
	if mobile:
		var top := 74.0
		var area := Rect2(4, top, w - 8, maxf(80, h - top - 54))
		for panel in [side_panel, inspector_panel, events_panel]:
			panel.position = area.position
			panel.size = area.size
		bottom_nav.position = Vector2(4, h - 50)
		bottom_nav.size = Vector2(w - 8, 46)
		floor_view.position = area.position
		floor_view.size = Vector2(area.size.x, maxf(40, area.size.y - (0 if landscape else 50)))
		# Landscape actions overlay the floor instead of taking another permanent row.
		floor_actions.position = Vector2(8, h - 100)
		floor_actions.size = Vector2(w - 16, 44)
	else:
		var side_width := 225.0
		var right_width := clampf(w * 0.25, 290, 350)
		var middle_x := side_width + 36
		var middle_width := w - middle_x - right_width - 36
		side_panel.position = Vector2(16, 100)
		side_panel.size = Vector2(side_width, h - 116)
		inspector_panel.position = Vector2(w - right_width - 16, 100)
		inspector_panel.size = Vector2(right_width, h - 116)
		floor_view.position = Vector2(middle_x, 126)
		floor_view.size = Vector2(middle_width, h - 312)
		mode_hint.position = Vector2(middle_x, 96)
		mode_hint.size = Vector2(middle_width, 26)
		floor_actions.position = Vector2(middle_x, h - 180)
		floor_actions.size = Vector2(middle_width, 44)
		events_panel.position = Vector2(middle_x, h - 124)
		events_panel.size = Vector2(middle_width, 108)
	apply_visibility()
	if is_instance_valid(developer_panel): developer_panel._layout()
	if modal != null:
		modal.position = Vector2(maxf(12, (w - 660) / 2), 12)
		modal.size = Vector2(minf(660, w - 24), h - 24)
		for child in get_children():
			if child.has_meta("modal_shade"): child.size = dimensions

func apply_visibility() -> void:
	var at_table := sim.joined >= 0
	game_view.hide()
	if at_table:
		var dimensions := Vector2(get_window().content_scale_size)
		table_scroll.position = Vector2(4, 80 if not mobile else 78)
		table_scroll.size = dimensions - table_scroll.position - Vector2(4, 4)
		felt.custom_minimum_size = Vector2(0, maxf(table_scroll.size.y, 580 if dimensions.x > dimensions.y else 900))
		table_scroll.show()
		inspector_panel.position = Vector2(maxf(4, dimensions.x - 378), 82)
		inspector_panel.size = Vector2(minf(370, dimensions.x - 8), dimensions.y - 90)
		side_panel.hide()
		events_panel.hide()
		floor_view.hide()
		floor_actions.hide()
		bottom_nav.hide()
		mode_hint.hide()
		hud_summary.visible = not mobile
		stats.visible = not mobile
		status.visible = not mobile
		var is_craps := sim.table_kind(sim.get_table(sim.joined)) == "craps"
		felt.visible = is_craps
		table_scroll.visible = is_craps
		game_view.visible = not is_craps
		game_view.position = Vector2(4 if mobile else 16, 52 if mobile else 82)
		game_view.size = dimensions - Vector2(8 if mobile else 32, 56 if mobile else 92)
		inspector_panel.visible = is_craps and table_options
		return
	table_scroll.hide()
	stats.show()
	hud_summary.show()
	status.show()
	bottom_nav.visible = mobile
	mode_hint.visible = not mobile
	side_panel.visible = not mobile or mobile_pane == "manage"
	inspector_panel.visible = not mobile or mobile_pane == "table"
	events_panel.visible = not mobile or mobile_pane == "log"
	felt.visible = not mobile and sim.joined >= 0
	floor_view.visible = (not mobile and sim.joined < 0) or (mobile and mobile_pane == "floor")
	floor_actions.visible = floor_view.visible
	floor_fit.visible = mobile and not visitor and not building
	floor_fit.text = "Fit" if floor_view.close_view else "Closer"
	rotate_button.visible = building
	floor_join_button.text = "Join" if visitor and can_join() else "Inspect" if mobile else "Inspect table"

func open_page(value: String) -> void:
	if value == "finance" and page != "finance":
		finance_section = ""
		finance_advanced = false
	page = value
	mobile_pane = "table"
	inspector_scroll.scroll_vertical = 0
	refresh()

func switch_mobile(value: String) -> void:
	if rolling > 0: return
	if value == "floor" and sim.joined >= 0: leave_table()
	mobile_pane = value
	if value == "table": page = "table"
	refresh()

func can_join() -> bool:
	var table := sim.get_table(selected)
	return not table.is_empty() and sim.ready_for_play(table) and sim.player.distance_to(sim.bounds(table).get_center()) <= 165


func style(bg: Color, border: Color = Color("2a3d4e")) -> StyleBoxFlat:
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
	panel.add_theme_stylebox_override("panel", style(Color("111e2c")))
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

func add_label(parent: Node, text: String, font_size: int = 14, color: Color = TEXT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func add_button(parent: Node, title: String, callback: Callable, disabled: bool = false) -> Button:
	var button := Button.new()
	button.text = title
	button.disabled = disabled
	button.pressed.connect(callback)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size.y = 44
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.clip_text = true
	if OS.is_debug_build():
		button.add_to_group("debug_buttons")
	parent.add_child(button)
	return button

func button_tone(button: Button, tone: String) -> void:
	var color := Color("254e48") if tone == "primary" else Color("30232e")
	for state in ["normal", "hover", "pressed"]:
		var skin := style(color.lightened(0.1) if state == "hover" else color, TEAL.darkened(0.5) if tone == "primary" else Color("72424b"))
		skin.content_margin_top = 10
		skin.content_margin_bottom = 10
		button.add_theme_stylebox_override(state, skin)

func button_at(at: Vector2, dimensions: Vector2, title: String, callback: Callable) -> Button:
	var button := add_button(self, title, callback)
	button.position = at
	button.size = dimensions
	return button

func add_gap(parent: Node, height: float) -> void:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	parent.add_child(gap)

func clear(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _process(delta: float) -> void:
	animate_treasury(delta)
	if OS.has_feature("web") and OS.is_debug_build():
		publish_debug()
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
	if rolling > 0:
		rolling -= delta
		if rolling <= 0:
			active_roll_table = -1
			refresh()
	refresh_timer += delta
	if refresh_timer >= 1:
		refresh_timer = 0
		refresh()

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
			building = false
			moving = -1
			floor_view.building = false
		elif sim.joined >= 0:
			leave_table()
		refresh()
	if event.keycode == KEY_E and visitor and sim.joined < 0:
		join_table()

func money(amount: float) -> String:
	return FinancialText.cash(amount, 0)

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
	stats.text = FinancialText.cash(displayed_cash, 0)
	if mobile and absf(displayed_cash) >= 10000:
		var divisor := 1000000.0 if absf(displayed_cash) >= 1000000 else 1000.0
		stats.text = "%s$%.1f%s" % ["-" if displayed_cash < 0 else "", absf(displayed_cash) / divisor, "M" if divisor == 1000000 else "K"]
	hud_summary.text = ("Guests %d   Rating %.0f" if mobile else "%d guests    Casino Rating %.0f") % [sim.guests.size(), sim.casino_rating]
	hud_summary.tooltip_text = "Casino Rating measures property development: %.1f / 100. Development level %d: %s. Reputation measures guest perception: %.0f%%." % [sim.casino_rating, sim.stars(), CasinoTuning.STAR_NAMES[sim.stars() - 1], sim.reputation]
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

func refresh() -> void:
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
	status.tooltip_text = "Financial performance and operating costs are available in Finance."
	clear(objective)
	render_progression(objective, true)
	doors_button.text = "Close to new arrivals" if sim.opened else "Open casino"
	build_button.text = "Cancel placement" if building else "+ Build games..."
	walk_button.text = "Manage casino" if visitor else "Walk the floor"
	pause_button.text = "Play" if speed == 0 else "Pause"
	floor_view.visitor_mode = visitor
	floor_view.building = building
	floor_view.build_kind = build_kind
	floor_view.build_slot_profile = build_slot_profile
	floor_view.moving_id = moving
	game_view.paused = speed == 0
	floor_view.selected = selected
	mode_hint.text = "Click to place | R to rotate | Esc to cancel" if building else ("Tap to walk | tap a table to approach | E or Join to play" if visitor else "Select a table or guest to inspect | build and staff to expand")
	layout_ui()
	felt.chip = chip_value
	felt.locked = rolling > 0 or speed == 0 or table_options or modal != null
	felt.queue_redraw()
	clear(feed)
	add_label(feed, "HOUSE ACTIVITY", 12, MUTED)
	if sim.house_activity.is_empty(): add_label(feed, "Your next important casino event will appear here.", 13, MUTED)
	for i in range(mini(6 if mobile else 2, sim.house_activity.size())):
		render_activity_row(feed, str(sim.house_activity[i]), i == 0)
	var scroll: ScrollContainer = inspector.get_parent()
	var scroll_position := scroll.scroll_vertical
	var live_inspector := inspector
	inspector = VBoxContainer.new()
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
	elif page == "incidents":
		render_incidents()
	elif page == "guest":
		render_guest()
	else:
		render_table()
	var new_inspector := inspector
	inspector = live_inspector
	patch_inspector(new_inspector)
	new_inspector.free()
	scroll.set_deferred("scroll_vertical", scroll_position)
	if OS.has_feature("web") and OS.is_debug_build():
		call_deferred("publish_debug")

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
			var bar := ProgressBar.new()
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
			parent.add_child(bar)
	add_label(parent, "Earn access through your property and guest business. Unlocking never forces a purchase.", 12, MUTED)

func render_development() -> void:
	add_label(inspector, "CASINO DEVELOPMENT", 12, MUTED)
	add_label(inspector, "Casino Rating %.1f" % sim.casino_rating, 25, TEXT)
	add_label(inspector, "Level %d - %s" % [sim.stars(), CasinoTuning.STAR_NAMES[sim.stars() - 1]], 14, GOLD)
	add_label(inspector, "Property quality and real guest business develop your casino. Reputation measures how guests feel.", 13, MUTED)
	add_label(inspector, "Guest reputation  %.0f%%" % sim.reputation, 15, TEAL)
	add_gap(inspector, 12)
	render_progression(inspector)
	add_gap(inspector, 12)
	add_label(inspector, "FLOOR EXPANSION", 12, MUTED)
	if sim.expanded:
		add_label(inspector, "Expanded floor", 17, TEAL)
	elif sim.unlocked("expansion"):
		add_label(inspector, "More room to grow", 19, GOLD)
		add_label(inspector, "Adds usable casino floor space. Purchase when your reserve can support the next stage.", 13, MUTED)
		button_tone(add_button(inspector, "Purchase expansion - " + money(CasinoTuning.EXPANSION_COST), func(): sim.purchase_upgrade("expansion"); refresh(), sim.cash < CasinoTuning.EXPANSION_COST), "primary")
	else:
		add_label(inspector, "Available at Casino Rating 35", 14, MUTED)
		add_label(inspector, "Earn Blackjack access first. Expansion adds space; it is a separate purchase.", 12, MUTED)

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
	var line := row(parent)
	line.add_theme_constant_override("separation", 10)
	var category := add_label(line, event.category, 11, GOLD if latest else MUTED)
	category.custom_minimum_size.x = 84
	category.size_flags_horizontal = SIZE_FILL
	add_label(line, event.body, 13, TEXT if latest else MUTED)

func render_build() -> void:
	add_label(inspector, "GROW YOUR CASINO", 21, GOLD)
	add_label(inspector, "Cash buys equipment; developed capacity and settled guest business earn access. Slots need no dealer, table games need one, and craps needs two plus a larger footprint.", 14)
	add_label(inspector, "Tier access and game unlocks are shown in Casino development.", 12, MUTED)
	render_slot_catalog()
	for milestone in CasinoTuning.MILESTONES:
		var feature: String = milestone.id
		if feature == "slots": continue
		if not sim.revealed(feature):
			add_button(inspector, "LOCKED: ??? | Increase Casino Rating", func(): pass, true)
			continue
		if not sim.unlocked(feature):
			add_button(inspector, "LOCKED: Blackjack | Develop the slot floor" if feature == "blackjack" else "LOCKED: %s | Rating %.0f" % [milestone.name, milestone.rating], func(): pass, true)
			continue
		if Games.COSTS.has(feature):
			add_button(inspector, "%s | $%d" % [milestone.name, sim.feature_cost(feature)], func(): build_kind = feature; toggle_build(), sim.cash < sim.feature_cost(feature))
		elif feature == "service":
			add_button(inspector, "Drink service | Staff & coverage", func(): open_page("staff"))
		else:
			add_button(inspector, "%s | %s" % [milestone.name, "Purchased" if sim.feature_owned(feature) else "$%d" % sim.feature_cost(feature)], func(): sim.purchase_upgrade(feature); refresh(), sim.feature_owned(feature) or sim.cash < sim.feature_cost(feature))
	if not sim.expanded:
		add_label(inspector, "The shaded wing opens after you purchase Floor expansion.", 12, MUTED)
	if sim.unlocked("craps"):
		add_label(inspector, "Craps: $%d + two dealers ($%d each), $%d/hr crew wages and $%d/hr operations. Keep cash for payout swings." % [Games.COSTS.craps, CasinoTuning.HIRING_COST, 2 * CasinoTuning.DEALER_WAGE, CasinoTuning.TABLE_OVERHEAD], 12, MUTED)

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
			add_label(inspector, "RTP %.2f%%   House edge %.2f%%
Appeal %.2fx   Development %.0f
Upkeep %s per hour
Repair %s
Daily failure chance %.1f%% after %d operating days
Suggested reserve %s
Maximum total return %s" % [profile.rtp * 100, profile.house_edge * 100, profile.appeal, profile.development, FinancialText.cash(profile.overhead), money(profile.repair_cost), profile.repair_chance * 100, int(profile.repair_grace) / 1440, money(profile.reserve), money(profile.top_return * profile.maximum)], 13, MUTED)

func render_table() -> void:
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
	var gaming_win := float(table.wagers) - float(table.payouts)
	var win_label := add_label(inspector, FinancialText.cash(gaming_win, 0), 30, TEAL if gaming_win >= 0 else Color("ff9486"))
	win_label.tooltip_text = "Settled gaming win before expenses: " + FinancialText.cash(gaming_win)
	add_label(inspector, "Before operating expenses", 12, MUTED)
	add_gap(inspector, 8)
	if guests.is_empty(): add_label(inspector, "Occupied by you" if sim.joined == selected else "Waiting for guests" if sim.ready_for_play(table) and sim.opened else "Not accepting play", 15, TEXT)
	else: add_label(inspector, "Playing now
" + ", ".join(guests.map(func(guest): return str(guest.name).replace(" · ", " - "))), 15, TEXT)
	if kind != "slots": add_label(inspector, "Dealers %d of %d" % [sim.crew(selected).size(), sim.required_crew(table)], 14, MUTED)
	add_label(inspector, "Minimum wager " + money(table.minimum), 14, MUTED)
	add_button(inspector, ("Hide " if asset_details else "Show ") + ("machine details" if kind == "slots" else "game details"), func(): asset_details = not asset_details; refresh())
	if asset_details:
		add_label(inspector, "PERFORMANCE", 12, MUTED)
		add_label(inspector, "Operating contribution " + FinancialText.cash(sim.asset_operating_profit(table)) + "\nDealer payroll " + FinancialText.cash(table.payroll_expense), 14, TEAL if sim.asset_operating_profit(table) >= 0 else GOLD)
		add_label(inspector, "Excludes visitor play and purchase price. Shared service payroll and comps are shown in Finance.", 12, MUTED)
		add_label(inspector, "Wagers %s
Payouts %s
%s %d" % [FinancialText.cash(table.wagers), FinancialText.cash(table.payouts), "Spins" if kind == "slots" else "Rounds", table.rolls], 14)
		if kind == "slots":
			var profile := sim.slot_profile(table)
			add_label(inspector, "RTP %.2f%%   House edge %.2f%%
%s volatility   Maximum %s" % [profile.rtp * 100, profile.house_edge * 100, profile.volatility, money(profile.maximum)], 13, MUTED)
			add_label(inspector, "Development %.0f (tier cap %.0f)
Appeal %.2fx   Prestige %d" % [profile.development, profile.development_cap, profile.appeal, profile.prestige], 13, MUTED)
			add_label(inspector, "Maximum total return %s
Suggested reserve %s" % [money(profile.top_return * profile.maximum), money(profile.reserve)], 13, GOLD)
			var utilization := float(table.occupied_minutes) / maxf(1, float(table.available_minutes)) * 100
			add_label(inspector, "Utilization %.0f%%
Downtime %d min
Repairs %d (%s)
Upkeep %s" % [utilization, table.downtime_minutes, table.repairs, FinancialText.cash(table.repair_expense), FinancialText.cash(table.operating_expense)], 13, MUTED)
		add_label(inspector, table.result.replace(" · ", " - "), 13, MUTED)
	if sim.table_kind(table) == "craps": add_label(inspector, "POINT: %s" % ("OFF / COME-OUT" if int(table.point) == 0 else str(int(table.point))), 12, GOLD)
	add_gap(inspector, 10)
	if kind != "slots": add_button(inspector, "Hire dealer | $%d" % CasinoTuning.HIRING_COST, func(): sim.hire("Dealer", selected); refresh(), sim.crew(selected).size() >= sim.required_crew(table) or not sim.unlocked("blackjack"))
	if kind != "slots": add_button(inspector, "Assign standby dealers", func(): sim.assign_standby(selected); refresh())
	if table.broken:
		add_button(inspector, "Repair | $%d" % sim.repair_cost(table), func():
			for i in range(sim.incidents.size()):
				if sim.incidents[i].type == "repair" and int(sim.incidents[i].table) == selected:
					sim.resolve_incident(i, true)
					break
			refresh())
	if visitor:
		var distance := sim.player.distance_to(sim.bounds(table).get_center())
		add_button(inspector, "Join " + Games.NAMES[sim.table_kind(table)], join_table, not sim.ready_for_play(table) or distance > 165 or (sim.table_kind(table) == "slots" and not sim.seated(selected).is_empty()))
		add_label(inspector, "Approach the rail to join." if distance > 165 else "You're close enough to take a seat.", 12, MUTED)
		if distance > 165:
			add_button(inspector, "Walk to this table", func(): floor_view.walk_to_table(selected); mobile_pane = "floor"; refresh())
	else:
		add_button(inspector, "Experience this table", func(): toggle_walk())
	var limit_labels := PackedStringArray()
	for minimum in sim.wager_limits(table): limit_labels.append(money(float(minimum)))
	var limits := " / ".join(limit_labels)
	add_button(inspector, "Minimum: " + limits, func(): sim.change_minimum(selected); refresh())

	add_button(inspector, "Move table", begin_move, sim.busy(table))
	button_tone(add_button(inspector, "Sell for %s" % money(sim.purchase_cost(sim.table_kind(table), str(table.slot_profile)) / 2), func(): sim.sell(selected); refresh(), sim.busy(table)), "danger")

func render_staff() -> void:
	add_label(inspector, "STAFF & COVERAGE", 11, GOLD)
	add_label(inspector, "%d employees" % sim.staff.size(), 24)
	var commitment := add_label(inspector, "Payroll commitment " + FinancialText.cash(sim.payroll_rate(), 0) + "/hr", 14, GOLD)
	commitment.tooltip_text = "Working, idle, standby and closed-time employees are paid. Craps needs two dealers; other tables need one; slots need none."
	var dealer := add_button(inspector, "Hire dealer | $%d" % CasinoTuning.HIRING_COST if sim.unlocked("blackjack") else "Dealers locked | Unlock blackjack", func(): sim.hire("Dealer", selected); refresh(), not sim.unlocked("blackjack"))
	dealer.tooltip_text = "Assign to a staffed game. $%d per game hour, including standby time." % CasinoTuning.DEALER_WAGE
	var service := add_button(inspector, "Hire service | $%d" % CasinoTuning.HIRING_COST if sim.unlocked("service") else "Drink service locked | Increase Casino Rating", func(): sim.hire("Service", -1); refresh(), not sim.unlocked("service"))
	service.tooltip_text = "Walks the floor delivering paid drinks and recent-gambler basic comps. $%d per game hour. See Finance > Bar for performance." % CasinoTuning.SERVICE_WAGE
	add_gap(inspector, 4)
	for employee in sim.staff:
		add_label(inspector, "%s | %s" % [employee.name, employee.role], 15)
		var assignment := "Table %d" % int(employee.table) if int(employee.table) > 0 else "Standby | recovering"
		if employee.role == "Service":
			assignment = "%s | whole floor" % employee.get("service_state", "At bar") if not sim.guests.is_empty() else "At cocktail bar | recovering"
		add_label(inspector, "%s | %.0f%% energy | $%d/hr" % [assignment, employee.energy, CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE], 12, MUTED)
		if employee.role == "Dealer" and employee.energy < 85:
			add_button(inspector, "Relieve %s" % employee.name, func():
				var standby := sim.staff.filter(func(s): return s.role == "Dealer" and int(s.table) == -1 and s.energy > employee.energy)
				if standby.is_empty():
					sim.log_event("Hire a standby dealer to relieve this employee.")
				else:
					standby[0].table = employee.table
					employee.table = -1
					sim.log_event("Fresh dealer assigned; %s is recovering on standby." % employee.name)
				refresh())

func finance_color(amount: float) -> Color:
	return TEAL if amount > 0.005 else Color("ff9486") if amount < -0.005 else MUTED

func finance_line(parent: Node) -> BoxContainer:
	var line := preload("res://scripts/finance_layout.gd").new()
	parent.add_child(line)
	return line

func finance_value(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var value := add_label(parent, text, font_size, color)
	value.autowrap_mode = TextServer.AUTOWRAP_OFF
	value.size_flags_horizontal = SIZE_FILL
	return value

func finance_metric(parent: Node, title: String, amount: float, signed: bool = true) -> void:
	var card := PanelContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", style(Color("182a38")))
	parent.add_child(card)
	var body := VBoxContainer.new()
	card.add_child(body)
	add_label(body, title, 12, MUTED)
	var summary := FinancialText.cash(amount, 0)
	if signed:
		summary = ("+" if amount > 0 else "-" if amount < 0 else "") + FinancialText.cash(absf(amount), 0)
		if absf(amount) < 1: summary = FinancialText.house_result(amount)
	var value := finance_value(body, summary, 24, finance_color(amount) if signed else TEXT)
	value.tooltip_text = FinancialText.cash(amount)

func finance_row(parent: Node, title: String, amount: float, hide_zero: bool = true) -> void:
	if hide_zero and absf(amount) < 0.005: return
	var line := finance_line(parent)
	add_label(line, title, 14, MUTED)
	var value := finance_value(line, FinancialText.house_result(amount), 15, finance_color(amount))
	value.size_flags_horizontal = SIZE_FILL
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

func finance_card(id: String, title: String, amount: float) -> VBoxContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", style(Color("142331")))
	inspector.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 8)
	card.add_child(stack)
	var header := add_button(stack, "", func():
		finance_section = "" if finance_section == id else id
		refresh())
	header.tooltip_text = "Expand " + title if finance_section != id else "Collapse " + title
	if id == "operations": header.tooltip_text += ". Upkeep, repairs and complaint comps; drink products are in Bar and payroll is separate."
	elif id == "bar": header.tooltip_text += ". Sales minus paid and complimentary product costs, before service payroll."
	elif id == "investment": header.tooltip_text += ". Capital purchases minus sales, plus hiring; excluded from operating profit."
	elif id == "gaming": header.tooltip_text += ". Settled guest gaming win, excluding visitor play and pending stakes."
	header.custom_minimum_size.y = 50
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	margin.mouse_filter = MOUSE_FILTER_IGNORE
	header.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var line := finance_line(margin)
	line.fit_header = true
	line.mouse_filter = MOUSE_FILTER_IGNORE
	var name := add_label(line, title + (" -" if finance_section == id else " >"), 14, TEXT)
	name.mouse_filter = MOUSE_FILTER_IGNORE
	var value := finance_value(line, FinancialText.house_result(amount), 20, finance_color(amount))
	value.mouse_filter = MOUSE_FILTER_IGNORE
	if finance_section != id: return null
	var detail := VBoxContainer.new()
	detail.add_theme_constant_override("separation", 8)
	stack.add_child(detail)
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

func render_finance_bar(parent: Node) -> void:
	var bar: Dictionary = sim.bar_totals
	add_label(parent, "%d sold / %d comped" % [int(bar.sold), int(bar.comped)], 15, TEXT)
	finance_row(parent, "Sales", float(bar.revenue))
	finance_row(parent, "Product cost", -float(bar.product_cost))
	finance_row(parent, "Drink comps", -float(bar.comp_cost))
	finance_row(parent, "Margin before labor", sim.bar_margin(), false)
	finance_row(parent, "Service payroll", -float(sim.expense_totals.service_payroll))
	finance_row(parent, "Net after service labor", sim.bar_contribution(), false)
	# This is the current aggregate drink detail, not invented per-recipe statistics.
	add_button(parent, "Manage service staff", func(): open_page("staff"))

func render_finance_payroll(parent: Node) -> void:
	var costs: Dictionary = sim.expense_totals
	finance_row(parent, "Dealers", -float(costs.dealer_payroll))
	finance_row(parent, "Service staff", -float(costs.service_payroll))
	var commitment := finance_line(parent)
	add_label(commitment, "Current commitment", 14, MUTED)
	finance_value(commitment, "%s/hr" % FinancialText.cash(sim.payroll_rate(), 0), 14, GOLD)
	add_button(parent, "Staff / assignments", func(): open_page("staff"))

func render_finance_operations(parent: Node) -> void:
	var costs: Dictionary = sim.expense_totals
	finance_row(parent, "Equipment upkeep", -float(costs.upkeep))
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
	finance_row(parent, "Visitor's house result", sim.visitor_house_result())
	finance_row(parent, "Drink sales", float(sim.bar_totals.revenue))
	finance_row(parent, "All costs incl. investment", -sim.operating_costs())
	finance_row(parent, "Recorded net cash flow", sim.net_profit(), false)
	finance_row(parent, "Pending stakes", sim.live_stakes())
	var note := add_label(parent, "Cash flow includes visitor transfers and pending stakes.", 12, MUTED)
	note.tooltip_text = "Starting cash and developer funding are outside recorded flow. Operating profit excludes capital, hiring and owner gambling; gaming win excludes unresolved stakes."
	if sim.payroll > 0:
		add_label(parent, "Payroll allocation", 12, GOLD)
		var states: Dictionary = sim.payroll_by_state
		for state in [{"key": "working", "name": "Working"}, {"key": "idle", "name": "Assigned idle"}, {"key": "standby", "name": "Standby"}, {"key": "unavailable", "name": "Closed / unavailable"}]:
			finance_row(parent, state.name, -float(states[state.key]))
	if speed > 4: add_label(parent, "DEV: leave manual games during long-run comparisons.", 12, GOLD)

func render_finance() -> void:
	add_label(inspector, "FINANCE", 12, GOLD)
	add_label(inspector, "Lifetime operations / %.1f game hours" % (float(sim.elapsed) / 60.0), 12, MUTED)
	var metrics := finance_line(inspector)
	metrics.size_flags_horizontal = SIZE_EXPAND_FILL
	finance_metric(metrics, "Cash now", sim.cash, false)
	finance_metric(metrics, "Operating profit", sim.operating_profit())
	var costs_line := finance_line(inspector)
	var cost_label := add_label(costs_line, "Recurring costs", 13, MUTED)
	cost_label.tooltip_text = "Payroll, upkeep, repairs, complaint comps and all drink product costs."
	var costs_value := finance_value(costs_line, FinancialText.house_result(-sim.recurring_costs()), 14, MUTED)
	costs_value.size_flags_horizontal = SIZE_FILL
	costs_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var detail := finance_card("gaming", "Gaming", sim.guest_gaming_profit())
	if detail != null: render_finance_gaming(detail)
	var bar_relevant: bool = sim.staff.any(func(employee): return employee.role == "Service") or int(sim.bar_totals.sold) + int(sim.bar_totals.comped) > 0 or float(sim.expense_totals.service_payroll) > 0
	if bar_relevant:
		detail = finance_card("bar", "Bar before labor", sim.bar_margin())
		if detail != null: render_finance_bar(detail)
	if not sim.staff.is_empty() or sim.payroll > 0:
		detail = finance_card("payroll", "Payroll", -sim.payroll)
		if detail != null: render_finance_payroll(detail)
	var other_costs := float(sim.expense_totals.upkeep) + float(sim.expense_totals.repairs) + float(sim.expense_totals.comps)
	if not sim.tables.is_empty() or other_costs > 0:
		detail = finance_card("operations", "Operations", -other_costs)
		if detail != null: render_finance_operations(detail)
	var investment := sim.net_capital_spending() + float(sim.expense_totals.hiring)
	if absf(float(sim.expense_totals.construction)) + absf(float(sim.expense_totals.sales)) + float(sim.expense_totals.hiring) > 0:
		detail = finance_card("investment", "Investment / setup", -investment)
		if detail != null: render_finance_investment(detail)
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
	add_label(inspector, "GUEST INSPECTOR", 11, GOLD)
	var found := sim.guests.filter(func(g): return int(g.id) == selected_guest)
	if found.is_empty():
		add_label(inspector, "Guest has left the casino.", 18)
		return
	var guest: Dictionary = found[0]
	add_label(inspector, guest.name, 25, GOLD if guest.vip else TEXT)
	add_label(inspector, str(sim.archetype(guest).name) + " / " + str(guest.state), 14, TEAL)
	add_label(inspector, "Wallet %s\nGaming net %s\nDrinks paid %s\nSatisfaction %.0f%%\nThirst %.0f%%\nPreferred game: %s" % [money(guest.wallet), money(guest.wallet + CrapsRules.exposure(guest.bets) + guest.drink_spending - guest.start), money(guest.drink_spending), guest.satisfaction, guest.thirst, Games.NAMES[guest.get("preference", "craps")]], 16)
	add_gap(inspector, 8)
	add_label(inspector, '"%s"' % guest.thought, 18, GOLD)
	add_label(inspector, "Watch your guests for clues about staffing, limits, and service.", 13, MUTED)

func row(parent: Node, columns: int = 0) -> Container:
	var container: Container = GridContainer.new() if columns > 0 else HBoxContainer.new()
	if columns > 0: container.columns = columns
	container.add_theme_constant_override("h_separation", 6)
	container.add_theme_constant_override("v_separation", 6)
	container.add_theme_constant_override("separation", 6)
	parent.add_child(container)
	return container

func table_action(action: String) -> void:
	if action.begins_with("chip:"):
		chip_value = int(action.substr(5))
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
	if rolling > 0 or felt.busy() or speed == 0 or sim.joined < 0: return
	sim.bet(sim.joined, kind, chip_value)
	refresh()

func begin_player_roll() -> void:
	var table := sim.get_table(sim.joined)
	if rolling > 0 or speed == 0 or not felt.can_throw() or table.is_empty() or int(table.shooter) != 0 or not sim.ready_for_play(table): return
	active_roll_table = sim.joined
	if not sim.shoot_player(active_roll_table):
		active_roll_table = -1
		refresh()
		return
	rolling = 2.2
	felt.capture_roll(table)
	refresh()

func render_craps() -> void:
	add_button(inspector, "Close table options", func(): table_options = false; refresh())
	add_button(inspector, "Resume time" if speed == 0 else "Pause time", toggle_pause)
	var table := sim.get_table(sim.joined)
	var locked: bool = rolling > 0 or felt.busy() or speed == 0 or not sim.ready_for_play(table)
	add_label(inspector, "CRAPS %02d  /  WALLET %s" % [sim.joined, money(sim.wallet)], 18, GOLD)
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
			add_label(inspector, "On layout: %s | wallet net: %s" % [money(CrapsRules.exposure(table.owner)), money(sim.visitor_net)], 14, GOLD)
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
	selected_guest = -1
	page = "table"
	if visitor: floor_view.walk_to_table(id)
	elif mobile: mobile_pane = "table"
	refresh()

func select_guest(id: int) -> void:
	if sim.joined >= 0:
		return
	selected_guest = id
	page = "guest"
	mobile_pane = "table"
	refresh()

func click_floor(at: Vector2) -> void:
	if not building:
		return
	if moving > 0:
		var table := sim.get_table(moving)
		if sim.can_place(at, floor_view.rotated, moving) and not sim.busy(table):
			table.x = at.x
			table.y = at.y
			table.rotated = floor_view.rotated
			moving = -1
			building = false
			sim.reroute()
			sim.log_event("Table moved. Clear aisles help guests reach the rail.")
	else:
		var id := sim.place(at, floor_view.rotated, build_kind, build_slot_profile)
		if id > 0:
			selected = id
			page = "table"
			building = false
	refresh()

func begin_move() -> void:
	if visitor:
		return
	moving = selected
	building = true
	build_kind = sim.table_kind(sim.get_table(selected))
	if build_kind == "slots": build_slot_profile = str(sim.get_table(selected).slot_profile)
	floor_view.rotated = bool(sim.get_table(selected).rotated)
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
	mobile_pane = "floor"
	refresh()

func toggle_walk() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
		if sim.joined >= 0: return
	visitor = not visitor
	mobile_pane = "floor"
	building = false
	moving = -1
	page = "table"
	refresh()

func join_table() -> void:
	var table := sim.get_table(selected)
	if table.is_empty() or not visitor or not sim.ready_for_play(table) or sim.player.distance_to(sim.bounds(table).get_center()) > 165:
		return
	if sim.seated(selected).size() >= 8:
		sim.log_event("All eight seats are taken. Try another table.")
		refresh()
		return
	if not sim.join_table(selected): return
	table_options = false
	mobile_pane = "table"
	page = "table"
	inspector_scroll.scroll_vertical = 0
	var rect := sim.bounds(table)
	sim.player = Vector2(rect.get_center().x, rect.end.y + 24)
	floor_view.move_target = Vector2(-1, -1)
	refresh()

func leave_table() -> void:
	if rolling > 0:
		return
	sim.leave_table()
	if sim.joined >= 0:
		refresh()
		return
	table_options = false
	layout_ui()
	mobile_pane = "floor"
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
	var restored: bool = data is Dictionary and sim.restore(data)
	if not restored:
		sim.log_event("Save is invalid or incompatible. Start a new casino.")
	else:
		reset_dev_speed()
		if is_instance_valid(developer_panel): developer_panel.reset_session(sim)
		reset_treasury_display()
		floor_view.clear_financial_feedback()
		visitor = sim.joined >= 0
		page = "table"
		mobile_pane = "table" if visitor else "floor"
		selected = sim.joined if sim.joined >= 0 else (int(sim.tables[0].id) if not sim.tables.is_empty() else -1)
		building = false
		moving = -1
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
	add_label(layout, "N E O N   H O U S E", 13, GOLD)
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
	body += "\n\nTap a game to inspect it. Walk mode: approach a game, then Join. Visitor play uses a separate $1,000 wallet; casino cash pays for construction, staff and payouts."
	if sim.feature_owned("service"): body += "\n\nDrink staff walk the floor. Recent gamblers receive basic comps; waiting and watching guests pay. Deliveries relieve thirst and support longer sessions."
	if sim.feature_owned("craps"):
		body += "\n\nCraps needs two dealers. The shooter keeps the dice until seven-out. Pass dice hands off to a CPU; Hold betting pauses that table's CPU rolls. My bets lists contracts and removable stakes."
	body += "\n\nOn phones use Floor, Table, Manage and Log. Save locally before leaving."
	dialog("Build your house.", body, "Back to casino", func(): pass, false)

func confirm_reset() -> void:
	dialog("Start a new casino?", "Your existing local save is kept until you save again. Choose difficulty and starting games next.", "Choose new-game setup", func(): show_new_game_setup())

func show_new_game_setup(initial: bool = false) -> void:
	var mode := OptionButton.new()
	mode.add_item("Normal | intended progression")
	mode.add_item("Easy / Sandbox-lite | permissive access")
	mode.custom_minimum_size.y = 44
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
				add_label(layout, "Could not load this save. Choose a new setup or check your save file.", 14, GOLD))
	layout_ui()

func start_casino(mode: String, preferred: Array) -> void:
	sim = CasinoSimulation.new(mode, preferred)
	reset_treasury_display()
	floor_view.sim = sim
	felt.sim = sim
	game_view.sim = sim
	if is_instance_valid(developer_panel): developer_panel.reset_session(sim)
	selected = int(sim.tables[0].id)
	selected_guest = -1
	visitor = false
	building = false
	moving = -1
	floor_view.rotated = false
	reset_dev_speed()
	tick = 0
	rolling = 0
	active_roll_table = -1
	page = "table"
	mobile_pane = "floor"
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
	JavaScriptBridge.eval("window.neonHouseSnapshot = " + JSON.stringify(sim.snapshot()) + ";window.neonHouseUI = " + JSON.stringify(buttons), true)

# Preserve live buttons across simulation refreshes: a mouse-down must not lose
# its button before mouse-up just because the clock advanced.
func patch_inspector(proposed: VBoxContainer) -> void:
	patch_children(inspector, proposed)

func patch_children(parent: Control, proposed: Control) -> void:
	var compatible := parent.get_child_count() == proposed.get_child_count()
	if compatible:
		for i in range(parent.get_child_count()):
			if (parent.get_child(i).get_class() != proposed.get_child(i).get_class() or parent.get_child(i).get_script() != proposed.get_child(i).get_script()):
				compatible = false
				break
	if not compatible:
		clear(parent)
		for child in proposed.get_children():
			proposed.remove_child(child)
			parent.add_child(child)
		return
	for i in range(parent.get_child_count()):
		var live: Control = parent.get_child(i)
		var fresh: Control = proposed.get_child(i)
		live.custom_minimum_size = fresh.custom_minimum_size
		live.size_flags_horizontal = fresh.size_flags_horizontal
		if live is Label:
			live.text = fresh.text
			live.tooltip_text = fresh.tooltip_text
			live.horizontal_alignment = fresh.horizontal_alignment
			live.autowrap_mode = fresh.autowrap_mode
			live.add_theme_font_size_override("font_size", fresh.get_theme_font_size("font_size"))
			live.add_theme_color_override("font_color", fresh.get_theme_color("font_color"))
			if dice_label == fresh: dice_label = live
		elif live is Button:
			live.text = fresh.text
			live.disabled = fresh.disabled
			live.tooltip_text = fresh.tooltip_text
			for state in ["normal", "hover", "pressed"]:
				if fresh.has_theme_stylebox_override(state): live.add_theme_stylebox_override(state, fresh.get_theme_stylebox(state))
				else: live.remove_theme_stylebox_override(state)
			live.toggle_mode = fresh.toggle_mode
			live.set_pressed_no_signal(fresh.button_pressed)
			for connection in live.get_signal_connection_list("pressed"):
				live.disconnect("pressed", connection.callable)
			for connection in fresh.get_signal_connection_list("pressed"):
				live.connect("pressed", connection.callable)
			if live.get_child_count() > 0 or fresh.get_child_count() > 0: patch_children(live, fresh)
		elif live is ProgressBar:
			live.value = fresh.value
		elif live is Container:
			if live is GridContainer: live.columns = fresh.columns
			patch_children(live, fresh)
			if live.get_script() == preload("res://scripts/finance_layout.gd"): live.queue_sort()
