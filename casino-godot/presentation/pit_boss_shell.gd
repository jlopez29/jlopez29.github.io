extends Control
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const DesktopTheme = preload("res://presentation/theme/desktop_theme.gd")
var controller: Control
var capacity := 0
var active_staff := 0
var placement_caption := ""
var mobile_management: Control

const BuildInfo = preload("res://scripts/build_info.gd")

# The controller supplies one authoritative simulation and existing action callbacks.
func mount(ui: Control) -> void:
	controller = ui
	ui.theme = PitBoss.create()
	theme = DesktopTheme.create()
	ui.backdrop = $Backdrop
	ui.hud_bar = $TopHUD/Bar
	ui.brand = $TopHUD/Brand
	ui.subtitle = $TopHUD/Subtitle
	ui.subtitle.text = "CASINO TYCOON / " + BuildInfo.VERSION
	ui.logo = $TopHUD/Logo
	ui.stats = $TopHUD/Cash/Value
	ui.hud_summary = $TopHUD/Wallet/Value
	ui.guest_metric = $TopHUD/Guests/Value
	ui.reputation_metric = $TopHUD/Reputation/Value
	ui.staff_metric = Label.new() # Legacy play/compact layout binding; not a HUD metric.
	$TopHUD.add_child(ui.staff_metric)
	ui.staff_metric.hide()
	ui.hud_bar.add_theme_stylebox_override("panel", DesktopTheme.luxury_panel())
	ui.metric_panels.assign([$TopHUD/Cash, $TopHUD/Wallet, $TopHUD/Guests, $TopHUD/Reputation])
	for i in range(ui.metric_panels.size()):
		var card: Panel = ui.metric_panels[i]
		card.add_theme_stylebox_override("panel", DesktopTheme.panel(Color("39352b")))
		var icon := Sprite2D.new()
		icon.texture = PitBoss.texture("icons/" + ["gameplay/cash", "gameplay/chip", "navigation/guests", "status/star"][i] + ".svg")
		icon.name = "MetricIcon"
		icon.position = Vector2(19, 13)
		icon.scale = Vector2.ONE * 16 / icon.texture.get_width()
		card.add_child(icon)
	var bar := ProgressBar.new()
	bar.name = "ReputationBar"
	bar.show_percentage = false
	bar.mouse_filter = MOUSE_FILTER_IGNORE
	bar.position = Vector2(12, 48)
	bar.size = Vector2(80, 3)
	var track := PitBoss.box(Color("25241f"), Color.TRANSPARENT, 0)
	var fill := PitBoss.box(Color("b9944e"), Color.TRANSPARENT, 0)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", fill)
	ui.metric_panels[3].add_child(bar)
	ui.play_return = ui.add_button(self, "Return to Floor", ui.leave_table)
	ui.play_return.hide()
	ui.status = $TopHUD/Clock
	ui.header_actions = $TopHUD/Actions
	ui.pause_button = ui.add_button(ui.header_actions, "Pause", ui.toggle_pause)
	ui.mobile_menu = MenuButton.new()
	ui.mobile_menu.text = "Menu"
	ui.mobile_menu.about_to_popup.connect(func(): AudioManager.play_ui("menu"))
	ui.mobile_menu.flat = false
	ui.mobile_menu.custom_minimum_size = Vector2(64, 44)
	ui.add_child(ui.mobile_menu)
	var global_menu: PopupMenu = ui.mobile_menu.get_popup()
	global_menu.add_theme_constant_override("v_separation", 26)
	global_menu.add_theme_font_size_override("font_size", 16)
	for title in ["Save", "Load", "Help", "New casino"]: global_menu.add_item(title)
	if OS.is_debug_build(): global_menu.add_item("Developer tools")
	global_menu.add_item("Transfer personal wallet to casino", 5)
	global_menu.add_item("Audio Settings", 6)
	global_menu.id_pressed.connect(ui.global_action)
	ui.mobile_speed = ui.add_button(self, "1x", func():
		if ui.speed == 0: ui.speed = 1
		elif ui.speed == 1: ui.speed = 2
		elif ui.speed == 2: ui.speed = 4
		elif ui.speed == 4: ui.speed = 8
		else: ui.speed = 0
		if ui.speed > 0: ui.previous_speed = ui.speed
		ui.refresh())
	if OS.is_debug_build():
		ui.mobile_dev = ui.add_button(self, "DEV", ui.toggle_dev_panel)
		ui.mobile_dev.tooltip_text = "Developer tools | F10 | Start or load a casino first"
	ui.mode_hint = ui.label_at(Vector2.ZERO, "", 13, ui.MUTED)
	ui.mode_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ui.side_panel = ui.panel_at(Vector2.ZERO, Vector2.ZERO)
	var left_scroll := ScrollContainer.new()
	left_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.side_panel.add_child(left_scroll)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	left_scroll.add_child(left)
	ui.add_button(left, "Close overview", ui.close_context)
	ui.add_label(left, "CASINO OVERVIEW", 22, ui.GOLD)
	ui.doors_button = ui.add_button(self, "Open casino", ui.toggle_doors)
	ui.button_tone(ui.doors_button, "primary")
	ui.build_button = ui.add_button(left, "+ Build games...", func():
		if ui.building: ui.toggle_build()
		else: ui.open_page("build"))
	ui.walk_button = ui.add_button(left, "Walk the floor", ui.toggle_walk)
	ui.add_gap(left, 6)
	ui.objective = VBoxContainer.new()
	ui.objective.add_theme_constant_override("separation", 6)
	left.add_child(ui.objective)
	ui.add_gap(left, 8)
	ui.add_label(left, "MANAGEMENT", 11, ui.MUTED)
	ui.add_button(left, "Casino development", func(): ui.open_page("development"))
	ui.add_button(left, "Staff & assignments", func(): ui.open_page("staff"))
	ui.add_button(left, "Finance", func(): ui.open_page("finance"))
	ui.add_button(left, "Incidents & decisions", func(): ui.open_page("incidents"))
	ui.add_gap(left, 10)
	ui.button_tone(ui.add_button(left, "New casino...", ui.confirm_reset), "danger")
	ui.floor_view = $CasinoFloorV2
	ui.floor_view.sim = PitBossFloorContext.new(ui.sim)
	ui.floor_view.table_clicked.connect(ui.select_table)
	ui.floor_view.floor_clicked.connect(ui.click_floor)
	ui.floor_view.guest_clicked.connect(ui.select_guest)
	ui.floor_view.bar_clicked.connect(func(): ui.open_page("bar"))

	ui.felt = ui.FeltScript.new()
	ui.felt.sim = PitBossGameContext.new(ui.sim)
	ui.felt.bet_clicked.connect(ui.place_chip)
	ui.felt.action_requested.connect(ui.table_action)
	ui.table_scroll = ScrollContainer.new()
	ui.table_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	ui.table_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	ui.add_child(ui.table_scroll)
	ui.table_scroll.add_child(ui.felt)
	ui.felt.size_flags_horizontal = SIZE_EXPAND_FILL
	ui.floor_actions = $ContextControls
	ui.floor_walk_button = ui.add_button(ui.floor_actions, "Walk", ui.toggle_walk)
	ui.cancel_placement_button = ui.add_button(ui.floor_actions, "Cancel", ui.cancel_placement)
	ui.floor_join_button = ui.add_button(ui.floor_actions, "Inspect table", func():
		if ui.visitor and ui.can_join(): ui.join_table()
		else: ui.open_page("table"))
	ui.confirm_placement_button = ui.add_button(ui.floor_actions, "Place", ui.confirm_placement)
	ui.button_tone(ui.confirm_placement_button, "primary")
	ui.rotate_button = ui.add_button(ui.floor_actions, "Rotate", func(): ui.floor_view.rotated = not ui.floor_view.rotated; ui.refresh())
	ui.floor_fit = ui.add_button(ui.floor_actions, "Fit", func(): ui.floor_view.toggle_fit(); ui.refresh())
	ui.game_view = ui.GameView.new()
	ui.game_view.sim = ui.felt.sim
	ui.game_view.leave_requested.connect(ui.leave_table)
	ui.game_view.changed.connect(ui.refresh)
	ui.game_view.pause_requested.connect(ui.toggle_pause)
	ui.game_view.craps_action_requested.connect(ui.table_action)
	ui.add_child(ui.game_view)
	ui.game_view.attach_craps(ui.felt)
	ui.felt.hide()
	ui.game_view.hide()
	ui.inspector_panel = $ObjectInspector
	ui.inspector_panel.add_theme_stylebox_override("panel", DesktopTheme.luxury_panel())
	ui.inspector_heading = $ObjectInspector/Frame/Toolbar/Heading
	ui.inspector_expand = $ObjectInspector/Frame/Toolbar/Expand
	ui.inspector_expand.pressed.connect(func(): ui.context_expanded = not ui.context_expanded; ui.refresh())
	$ObjectInspector/Frame/Toolbar/Close.pressed.connect(ui.close_context)
	ui.inspector_scroll = $ObjectInspector/Frame/Scroll
	ui.inspector = $ObjectInspector/Frame/Scroll/Content
	ui.events_panel = $AlertDrawer
	ui.events_panel.add_theme_stylebox_override("panel", DesktopTheme.luxury_panel())
	var log_content: VBoxContainer = $AlertDrawer/Scroll/Content
	$AlertDrawer/Scroll/Content/Close.pressed.connect(func(): ui.transition_pane("floor"); ui.refresh())
	ui.event_cards = preload("res://scripts/event_cards.gd").new()
	log_content.add_child(ui.event_cards)
	ui.event_cards.changed.connect(ui.refresh)
	ui.objective_cards = preload("res://scripts/objective_cards.gd").new()
	log_content.add_child(ui.objective_cards)
	ui.objective_cards.changed.connect(ui.refresh)
	ui.feed = VBoxContainer.new()
	ui.feed.size_flags_horizontal = SIZE_EXPAND_FILL
	ui.feed.add_theme_constant_override("separation", 6)
	log_content.add_child(ui.feed)
	ui.bottom_nav = HBoxContainer.new()
	ui.bottom_nav.add_theme_constant_override("separation", 6)
	ui.add_child(ui.bottom_nav)
	for entry in [{"title": "Floor", "icon": "gameplay/spade", "page": "floor"}, {"title": "Build", "icon": "navigation/build", "page": "build"}, {"title": "Staff", "icon": "navigation/staff", "page": "staff"}, {"title": "Guests", "icon": "navigation/guests", "page": "guests"}, {"title": "Finance", "icon": "navigation/finance", "page": "finance"}, {"title": "More", "icon": "navigation/events", "page": "more"}]:
		var nav_button: Button = ui.add_button(ui.bottom_nav, entry.title, func():
			if entry.page == "more": mobile_management.show_more()
			else: ui.navigate_shell(entry.page))
		nav_button.icon = PitBoss.texture("icons/" + entry.icon + ".svg")
		nav_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nav_button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		nav_button.toggle_mode = true
		nav_button.set_meta("shell_page", entry.page)
		if entry.page == "more": ui.event_nav = nav_button
	ui.nav_rail = $NavigationRail
	for entry in [{"title": "Floor", "icon": "gameplay/spade", "page": "floor"}, {"title": "Overview", "icon": "navigation/overview", "page": "manage"}, {"title": "Build", "icon": "navigation/build", "page": "build"}, {"title": "Staff", "icon": "navigation/staff", "page": "staff"}, {"title": "Guests", "icon": "navigation/guests", "page": "guests"}, {"title": "Finance", "icon": "navigation/finance", "page": "finance"}, {"title": "Incidents", "icon": "navigation/security", "page": "incidents"}, {"title": "Events", "icon": "navigation/events", "page": "log"}]:
		var button: Button = preload("res://presentation/components/nav_button.tscn").instantiate()
		ui.nav_rail.add_child(button)
		button.text = entry.title
		button.tooltip_text = entry.title
		button.pressed.connect(func(): ui.navigate_shell(entry.page))
		button.icon = PitBoss.texture("icons/" + entry.icon + ".svg")
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.set_meta("shell_page", entry.page)
		button.toggle_mode = true
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var skin: StyleBoxFlat = button.get_theme_stylebox(state).duplicate()
			skin.content_margin_top = 6
			skin.content_margin_bottom = 6
			button.add_theme_stylebox_override(state, skin)
		button.custom_minimum_size = Vector2(72, 52)
		button.add_theme_font_size_override("font_size", 12)
	ui.alert_button = ui.add_button(self, "Alerts", func(): ui.transition_pane("log" if ui.mobile_pane != "log" else "floor"); ui.refresh())
	ui.alert_button.icon = PitBoss.texture("icons/status/alert.svg")
	for control in [ui.play_return, ui.mobile_menu, ui.mobile_speed, ui.mobile_dev, ui.doors_button, ui.mode_hint, ui.side_panel, ui.alert_button, ui.bottom_nav]:
		if is_instance_valid(control) and control.get_parent() != self: control.reparent(self)

	mobile_management = preload("res://presentation/mobile_management.gd").new()
	add_child(mobile_management)
	mobile_management.mount(ui)
	$ObjectInspector/Frame/Toolbar.gui_input.connect(func(event: InputEvent):
		if not ui.mobile: return
		if event is InputEventScreenDrag and absf(event.relative.y) > 6:
			var expanded: bool = event.relative.y < 0
			if ui.context_expanded != expanded:
				ui.context_expanded = expanded
				ui.refresh())

# The world owns the viewport. Navigation, drawers and inspectors are overlays.
static func place(control: Control, at: Vector2, extent: Vector2) -> void:
	control.position = at
	control.size = extent

func layout(ui: Control, dimensions: Vector2) -> void:
	var w := dimensions.x
	var h := dimensions.y
	var mobile: bool = ui.mobile
	var playing: bool = ui.sim.joined >= 0 or not ui.sim.owner_play.is_empty() or ui.in_back_room
	$TopHUD.visible = not playing
	if playing:
		ui.backdrop.size = dimensions
		for control in [ui.mobile_menu, ui.mobile_speed, ui.mobile_dev, ui.play_return, ui.doors_button, ui.alert_button, ui.mode_hint, ui.nav_rail, ui.bottom_nav, ui.side_panel, ui.events_panel, ui.inspector_panel, ui.floor_actions]:
			if is_instance_valid(control): control.hide()
		mobile_management.palette.hide()
		place(ui.game_view, Vector2.ZERO, dimensions)
		return
	var top := 78.0 if mobile else 88.0
	ui.backdrop.size = dimensions
	place(ui.hud_bar, Vector2.ZERO, Vector2(w, top))
	place(ui.logo, Vector2(16, 12), Vector2(44, 44))
	ui.logo.visible = not mobile and not playing
	ui.brand.text = "PIT BOSS"
	ui.brand.add_theme_font_size_override("font_size", 27 if not mobile else 14)
	place(ui.brand, Vector2(68, 10) if not mobile else Vector2(10, 4), Vector2(150, 36))
	ui.brand.show()
	ui.subtitle.visible = not mobile and not playing
	place(ui.subtitle, Vector2(20, 53), Vector2(165, 20))
	ui.subtitle.add_theme_font_size_override("font_size", 12)
	ui.header_actions.visible = not mobile and not playing
	ui.mobile_menu.visible = not playing
	ui.mobile_speed.show()
	ui.doors_button.visible = not playing
	ui.nav_rail.visible = not mobile and not playing
	ui.bottom_nav.visible = mobile and not playing and not ui.requires_floor_targeting()
	place(ui.nav_rail, Vector2(12, top + 16), Vector2(76, h - top - 32))
	place(ui.bottom_nav, Vector2(6, h - 52), Vector2(w - 12, 46))
	ui.alert_button.visible = not playing and not ui.requires_floor_targeting()
	ui.doors_button.visible = not playing and not ui.requires_floor_targeting()
	if mobile:
		place(ui.stats, Vector2(10, 29), Vector2(w - 176, 32))
		ui.stats.add_theme_font_size_override("font_size", 22)
		place(ui.hud_summary, Vector2(10, 58), Vector2(w - 22, 20))
		ui.hud_summary.add_theme_font_size_override("font_size", 14)
		place(ui.mobile_menu, Vector2(w - 62, 3), Vector2(56, 44))
		place(ui.mobile_speed, Vector2(w - 118, 3), Vector2(50, 44))
		place(ui.doors_button, Vector2(w - 110, 48), Vector2(104, 28))
		ui.doors_button.custom_minimum_size.y = 28
		ui.doors_button.add_theme_font_size_override("font_size", 12)
		place(ui.alert_button, Vector2(w - 68, top + 10), Vector2(60, 44))
		ui.alert_button.add_theme_font_size_override("font_size", 16)
		ui.guest_metric.hide()
		ui.reputation_metric.hide()
		ui.staff_metric.hide()
		ui.status.hide()
	else:
		var x := 190.0
		var metrics: Array = [ui.stats, ui.hud_summary, ui.guest_metric, ui.reputation_metric]
		var widths := [160.0, 142.0, 90.0, 110.0]
		ui.staff_metric.hide()
		for i in range(metrics.size()):
			var metric: Label = metrics[i]
			metric.show()
			metric.add_theme_font_size_override("font_size", 22 if i < 2 else 20)
			place(ui.metric_panels[i], Vector2(x, 8), Vector2(widths[i], 64))
			x += widths[i] + 8
		place(ui.status, Vector2(x + 4, 14), Vector2(100, 58))
		ui.status.add_theme_font_size_override("font_size", 17)
		ui.status.show()
		place(ui.header_actions, Vector2(w - 290, 8), Vector2(98, 44))
		place(ui.mobile_speed, Vector2(w - 184, 8), Vector2(54, 44))
		place(ui.mobile_menu, Vector2(w - 118, 8), Vector2(106, 44))
		place(ui.doors_button, Vector2(w - 274, 58), Vector2(196, 26))
		ui.doors_button.custom_minimum_size.y = 26
		ui.doors_button.add_theme_font_size_override("font_size", 13)
		place(ui.alert_button, Vector2(w - 140, top + 14), Vector2(124, 44))
	if is_instance_valid(ui.mobile_dev):
		ui.mobile_dev.visible = not playing and not mobile
		place(ui.mobile_dev, Vector2(114, 5) if mobile else Vector2(14, h - 58), Vector2(60, 44))
		ui.mobile_dev.add_theme_font_size_override("font_size", 14)
	for card in ui.metric_panels:
		card.visible = not mobile and not playing
		card.get_node("MetricIcon").visible = not mobile and not playing
	# Cash and wallet stay readable in the retained compact/play header.
	if mobile or playing:
		ui.metric_panels[0].show()
		ui.metric_panels[1].show()
		place(ui.metric_panels[0], Vector2(8, 24), Vector2(w - 180, 28))
		place(ui.metric_panels[1], Vector2(8, 52), Vector2(w - 120, 24))
		for i in [0, 1]:
			ui.metric_panels[i].get_node("Caption").hide()
			ui.metric_panels[i].self_modulate.a = 0
			place(ui.metric_panels[i].get_node("Value"), Vector2.ZERO, ui.metric_panels[i].size)
	else:
		for card in ui.metric_panels:
			card.get_node("Caption").show()
			card.self_modulate.a = 1
			place(card.get_node("Value"), Vector2(10, 26), card.size - Vector2(20, 28))
	place(ui.floor_view, Vector2.ZERO, dimensions)
	place(ui.floor_actions, Vector2(12 if mobile else 124, h - 52), Vector2(w - 24 if mobile else 330, 44))
	if mobile and not ui.requires_floor_targeting():
		place(ui.floor_actions, Vector2(8, h - 104), Vector2(minf(w - 16, 330), 44))
	place(ui.mode_hint, Vector2(16 if mobile else 124, top + 8), Vector2(w - (90 if mobile else 310), 28))
	ui.mode_hint.add_theme_font_size_override("font_size", 15)
	# Context panels cover the world temporarily; they never resize the desktop floor.
	var contextual: bool = ui.page in ["table", "guest"] and (not ui.context_expanded or not mobile)
	if contextual:
		var sheet_height := minf(290, h * 0.38) if mobile else minf(480, h * 0.55) if ui.context_expanded else 250.0
		var sheet_width := w - 12 if mobile else minf(920, w - 260)
		place(ui.inspector_panel, Vector2(6 if mobile else (w - sheet_width) / 2, h - sheet_height - (58 if mobile else 14)), Vector2(sheet_width, sheet_height))
	else:
		var width := w - 12 if mobile else minf(920, w - 220)
		place(ui.inspector_panel, Vector2(6 if mobile else (w - width) / 2, top + 12), Vector2(width, h - top - (70 if mobile else 28)))
	var drawer_width := minf(400, w - 16)
	place(ui.events_panel, Vector2(w - drawer_width - 8, top + 64), Vector2(drawer_width, h - top - (124 if mobile else 80)))
	var overview_width := minf(440, w - 16)
	place(ui.side_panel, Vector2((w - overview_width) / 2, top + 12), Vector2(overview_width, h - top - (70 if mobile else 28)))
	if not mobile and not playing: layout_desktop(ui, dimensions)
	if mobile and not playing:
		mobile_management.update_state()
		mobile_management.layout(ui, dimensions)

func layout_desktop(ui: Control, dimensions: Vector2) -> void:
	ui.hud_bar.add_theme_stylebox_override("panel", DesktopTheme.luxury_panel())
	ui.inspector_panel.add_theme_stylebox_override("panel", DesktopTheme.luxury_panel())
	ui.metric_panels[3].get_node("ReputationBar").show()
	var w := dimensions.x
	var h := dimensions.y
	var top := clampf(h * 0.085, 64, 82)
	ui.inspector_expand.custom_minimum_size.x = 96
	ui.inspector_expand.get_parent().get_node("Close").custom_minimum_size.x = 80
	ui.floor_view.management_top = top
	# Developer tools remain available through Menu/F10 without a floor badge.
	if is_instance_valid(ui.mobile_dev): ui.mobile_dev.hide()
	place(ui.hud_bar, Vector2.ZERO, Vector2(w, top))
	place(ui.logo, Vector2(17, 14), Vector2(36, 36))
	place(ui.brand, Vector2(62, 9), Vector2(140, 32))
	ui.brand.add_theme_font_size_override("font_size", 24)
	ui.brand.modulate = Color("efd392")
	place(ui.subtitle, Vector2(63, 40), Vector2(135, 20))
	ui.subtitle.add_theme_font_size_override("font_size", 10)
	var widths := [164.0, 142.0, 100.0, 108.0]
	var x := 212.0
	for i in range(4):
		var card: Panel = ui.metric_panels[i]
		place(card, Vector2(x, 7), Vector2(widths[i], top - 14))
		place(card.get_node("Caption"), Vector2(34, 5), Vector2(widths[i] - 36, 18))
		card.get_node("Caption").text = ["CASINO CASH", "PERSONAL WALLET", "GUESTS", "REPUTATION"][i]
		card.get_node("Caption").add_theme_font_size_override("font_size", 10)
		place(card.get_node("Value"), Vector2(12, 22), Vector2(widths[i] - 20, top - 38))
		card.get_node("Value").add_theme_font_size_override("font_size", 22 if i < 2 else 18)
		x += widths[i] + 6
	ui.staff_metric.visible = not ui.sim.staff.is_empty() and w >= 1420
	place(ui.staff_metric, Vector2(x + 10, 15), Vector2(105, 45))
	ui.staff_metric.add_theme_font_size_override("font_size", 14)
	if ui.staff_metric.visible: x += 115
	place(ui.status, Vector2(x + 14, 10), Vector2(100, 48))
	ui.status.add_theme_font_size_override("font_size", 15)
	place(ui.header_actions, Vector2(w - 246, 12), Vector2(92, 40))
	ui.pause_button.custom_minimum_size = Vector2(88, 40)
	ui.pause_button.add_theme_font_size_override("font_size", 14)
	place(ui.mobile_speed, Vector2(w - 146, 12), Vector2(52, 40))
	ui.mobile_speed.add_theme_font_size_override("font_size", 14)
	place(ui.mobile_menu, Vector2(w - 84, 12), Vector2(72, 40))
	ui.mobile_menu.custom_minimum_size = Vector2(72, 40)
	ui.mobile_menu.add_theme_font_size_override("font_size", 14)
	place(ui.doors_button, Vector2(w - 158, top + 16), Vector2(142, 36))
	ui.doors_button.custom_minimum_size.y = 36
	ui.doors_button.add_theme_font_size_override("font_size", 13)
	place(ui.alert_button, Vector2(w - 122, top + 62), Vector2(106, 38))
	ui.alert_button.custom_minimum_size.y = 38
	ui.alert_button.add_theme_font_size_override("font_size", 13)
	place(ui.nav_rail, Vector2(15, top + 16), Vector2(76, 8 * 48 + 7 * 5))
	ui.nav_rail.add_theme_constant_override("separation", 5)
	for button in ui.nav_rail.get_children():
		button.custom_minimum_size = Vector2(76, 48)
		button.add_theme_font_size_override("font_size", 11)
	place(ui.floor_actions, Vector2(110, h - 54), Vector2(470 if ui.building else 330, 42))
	place(ui.mode_hint, Vector2(113, h - 88), Vector2(w - 288, 28))
	if ui.page == "build":
		place(ui.inspector_panel, Vector2(w - 390, top + 116), Vector2(374, h - top - 132))
	if ui.inspector_panel.visible and ui.page in ["table", "guest"]:
		ui.floor_view.inspector_occlusion = ui.inspector_panel.get_rect()
	else:
		ui.floor_view.inspector_occlusion = Rect2()

func update_desktop_state(ui: Control) -> void:
	mobile_management.update_state()
	if ui.mobile or ui.in_back_room or ui.sim.joined >= 0 or not ui.sim.owner_play.is_empty(): return
	ui.alert_button.visible = ui.mobile_pane != "log" and not ui.requires_floor_targeting()
	capacity = ui.sim.usable_gaming_capacity()
	active_staff = ui.sim.staff.filter(func(employee): return employee.duty == "Active").size()
	ui.staff_metric.text = "STAFF\n%d / %d active" % [active_staff, ui.sim.staff.size()]
	ui.pause_button.icon = PitBoss.texture("icons/gameplay/play.svg" if ui.speed == 0 else "icons/gameplay/pause.svg")
	for button in ui.nav_rail.get_children():
		button.add_theme_color_override("icon_normal_color", PitBoss.GOLD if button.button_pressed else Color("bcb4a0"))
		button.add_theme_constant_override("icon_max_width", 22)
	ui.metric_panels[3].get_node("ReputationBar").value = ui.sim.reputation
	ui.confirm_placement_button.visible = ui.building
	ui.confirm_placement_button.disabled = not ui.floor_view.placement_is_valid()
	ui.confirm_placement_button.text = "Move" if ui.moving > 0 else "Place"
	placement_caption = (ui.sim.slot_profile(ui.sim.get_table(ui.moving)).short_name if ui.moving > 0 and ui.build_kind == "slots" else CasinoTuning.SLOT_PROFILES[ui.build_slot_profile].short_name if ui.build_kind == "slots" else CasinoGames.NAMES[ui.build_kind]) + "  /  " + ("Moving existing asset" if ui.moving > 0 else ui.money(ui.sim.purchase_cost(ui.build_kind, ui.build_slot_profile))) + "  /  R rotates"
	ui.mode_hint.text = placement_caption
	ui.doors_button.remove_theme_stylebox_override("normal")

func _process(_delta: float) -> void:
	if controller == null or not controller.building: return
	var enabled: bool = controller.floor_view.placement_is_valid() and (not controller.mobile or controller.floor_view.placement_target.is_finite())
	if controller.confirm_placement_button.disabled == enabled: controller.confirm_placement_button.disabled = not enabled
	var caption := ("Tap target | Drag to pan" if controller.mobile else placement_caption) + (" | Valid" if enabled else " | Choose a clear cell" if controller.mobile and not controller.floor_view.placement_target.is_finite() else " | Blocked")
	if controller.mode_hint.text != caption: controller.mode_hint.text = caption
