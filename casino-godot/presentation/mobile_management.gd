extends Control
# Mobile presentation only. All purchases, navigation and management use the controller.
const Art = preload("res://scripts/pit_boss_theme.gd")
var controller: Control
var palette: PanelContainer
var body: BoxContainer
var categories: HBoxContainer
var catalog_scroll: ScrollContainer
var catalog: HBoxContainer
var category := "slots"
var purchases: Array[Dictionary] = []
var more: PopupMenu

func mount(ui: Control) -> void:
	controller = ui
	mouse_filter = MOUSE_FILTER_IGNORE
	palette = PanelContainer.new()
	palette.add_theme_stylebox_override("panel", Art.box(Color("101315"), Color("51452b"), 8))
	add_child(palette)
	body = BoxContainer.new()
	body.vertical = true
	body.add_theme_constant_override("separation", 4)
	palette.add_child(body)
	categories = HBoxContainer.new()
	body.add_child(categories)
	for kind in ["slots", "tables"]:
		var button: Button = ui.add_button(categories, kind.capitalize(), func():
			category = kind
			update_state())
		button.toggle_mode = true
		button.set_meta("category", kind)
	ui.add_button(categories, "Close", ui.close_context)
	catalog_scroll = ScrollContainer.new()
	catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	catalog_scroll.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_child(catalog_scroll)
	catalog = HBoxContainer.new()
	catalog.add_theme_constant_override("separation", 8)
	catalog_scroll.add_child(catalog)
	for profile_id in CasinoTuning.SLOT_PROFILES:
		add_purchase("slots", profile_id, str(CasinoTuning.SLOT_PROFILES[profile_id].short_name))
	for kind in ["blackjack", "roulette", "craps", "holdem"]:
		add_purchase(kind, "starter", CasinoGames.NAMES[kind].replace("’", "'"))
	more = PopupMenu.new()
	add_child(more)
	more.add_theme_constant_override("v_separation", 26)
	more.add_theme_font_size_override("font_size", 16)
	for title in ["Guests", "Finance", "Casino overview", "Casino development", "House Activity", "Incidents", "Open / close casino", "Walk / manage floor"]:
		more.add_item(title)
	more.id_pressed.connect(func(id: int):
		match id:
			0: ui.open_page("guests")
			1: ui.open_page("finance")
			2: ui.navigate_shell("manage")
			3: ui.open_page("development")
			4: ui.navigate_shell("log")
			5: ui.open_page("incidents")
			6: ui.toggle_doors()
			7: ui.toggle_walk()
	)

func add_purchase(kind: String, profile_id: String, title: String) -> void:
	var ui := controller
	var button: Button = ui.add_button(catalog, title, func():
		ui.build_kind = kind
		ui.build_slot_profile = profile_id
		ui.context_expanded = false
		ui.toggle_build())
	button.custom_minimum_size = Vector2(138, 56)
	button.add_theme_font_size_override("font_size", 14)
	purchases.append({"button": button, "kind": kind, "profile": profile_id, "title": title})

static func short_money(amount: float) -> String:
	for unit in [{"scale": 1.0e12, "suffix": "T"}, {"scale": 1.0e9, "suffix": "B"}, {"scale": 1.0e6, "suffix": "M"}, {"scale": 1.0e3, "suffix": "K"}]:
		if absf(amount) >= float(unit.scale) * 0.999995:
			return "%s$%.2f%s" % ["-" if amount < 0 else "", absf(amount) / float(unit.scale), unit.suffix]
	return ("-$" if amount < 0 else "$") + String.num(absf(amount), 0)

func show_more() -> void:
	var ui := controller
	var nav: Rect2 = ui.bottom_nav.get_global_rect()
	more.position = Vector2i(nav.position.x, maxf(8, nav.position.y - more.get_contents_minimum_size().y))
	more.popup()

func update_state() -> void:
	var ui := controller
	var playing: bool = ui.sim.joined >= 0 or not ui.sim.owner_play.is_empty()
	palette.visible = ui.mobile and not playing and not ui.building and ui.page == "build" and ui.inspector_open and ui.mobile_pane == "table"
	for button in categories.get_children():
		if button.has_meta("category"): button.button_pressed = button.get_meta("category") == category
	for purchase in purchases:
		var kind: String = purchase.kind
		var button: Button = purchase.button
		button.visible = (kind == "slots") == (category == "slots")
		var unlocked: bool = ui.sim.slot_unlocked(purchase.profile) if kind == "slots" else ui.sim.unlocked(kind)
		var revealed: bool = kind == "slots" or ui.sim.revealed(kind)
		var price: float = ui.sim.purchase_cost(kind, purchase.profile)
		button.text = (purchase.title if revealed else "???") + "\n" + (short_money(price) if unlocked else "Locked")
		button.disabled = not unlocked or ui.sim.cash < price
		button.tooltip_text = "Purchase price: " + ui.money(price) if unlocked else "See Casino development in More for access requirements."
	for button in ui.bottom_nav.get_children():
		var target: String = button.get_meta("shell_page", "")
		button.visible = target not in ["guests", "finance"] or get_viewport_rect().size.x >= 540
		button.button_pressed = target == ui.mobile_pane or (ui.mobile_pane == "table" and target == ui.page) or (target == "build" and ui.building)
	if ui.mobile and not playing:
		ui.floor_actions.visible = ui.building
		ui.confirm_placement_button.disabled = not ui.floor_view.placement_target.is_finite() or not ui.floor_view.placement_is_valid()
		ui.inspector_panel.visible = ui.inspector_panel.visible and ui.page != "build"
		ui.doors_button.hide()
		ui.alert_button.visible = not ui.building and (ui.mobile_pane == "floor" or (ui.mobile_pane == "table" and ui.page in ["table", "guest", "build"] and not ui.context_expanded))

func layout(ui: Control, dimensions: Vector2) -> void:
	var w := dimensions.x
	var h := dimensions.y
	var landscape := w > h and h < 600
	var edge := Vector4(8, 8, 8, 8) # left, top, right, bottom; browser wrapper supplies web safe areas.
	if OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		var ratio := dimensions / screen
		edge = Vector4(maxf(8, safe.position.x * ratio.x), maxf(8, safe.position.y * ratio.y), maxf(8, (screen.x - safe.end.x) * ratio.x), maxf(8, (screen.y - safe.end.y) * ratio.y))
	var left := edge.x
	var right := w - edge.z
	var width := right - left
	var top := edge.y + (64 if landscape else 96)
	var nav_y := h - edge.w - 52
	body.vertical = not landscape
	for button in categories.get_children():
		button.add_theme_font_size_override("font_size", 14)
	var actions_y := h - edge.w - 44
	ui.brand.hide()
	ui.subtitle.hide()
	ui.header_actions.hide()
	ui.doors_button.hide()
	ui.floor_view.management_top = top
	ui.floor_view.inspector_occlusion = Rect2()
	ui.floor_view.mobile_viewport = Rect2(Vector2(left, top), Vector2(width, nav_y - top - 8))
	ui.hud_bar.add_theme_stylebox_override("panel", Art.box(Color("101315"), Color("51452b"), 0))
	ui.inspector_panel.add_theme_stylebox_override("panel", Art.box(Color("101315"), Color("51452b"), 8))
	ui.presentation_shell.place(ui.hud_bar, Vector2.ZERO, Vector2(w, top))
	var metric_width := (width - (120 if landscape else 0)) / 4
	for i in range(4):
		var card: Panel = ui.metric_panels[i]
		card.show()
		card.self_modulate.a = 0
		card.get_node("MetricIcon").hide()
		if card.has_node("ReputationBar"): card.get_node("ReputationBar").hide()
		card.get_node("Caption").show()
		var column := i if landscape else i % 2
		var y := edge.y if landscape else edge.y + (i / 2) * 44
		var extent := metric_width if landscape else (width - 116) / 2
		var x := left + column * extent
		ui.presentation_shell.place(card, Vector2(x, y), Vector2(extent - 4, 42))
		var caption: Label = card.get_node("Caption")
		caption.text = ["CASH", "WALLET", "GUESTS", "REPUTATION"][i]
		caption.add_theme_font_size_override("font_size", 10)
		ui.presentation_shell.place(caption, Vector2.ZERO, Vector2(extent - 4, 15))
		var value: Label = card.get_node("Value")
		value.show()
		value.add_theme_font_size_override("font_size", 18)
		value.autowrap_mode = TextServer.AUTOWRAP_OFF
		ui.presentation_shell.place(value, Vector2(0, 15), Vector2(extent - 4, 25))
	ui.presentation_shell.place(ui.mobile_speed, Vector2(right - 112, edge.y), Vector2(50, 44))
	ui.presentation_shell.place(ui.mobile_menu, Vector2(right - 58, edge.y), Vector2(58, 44))
	ui.mobile_menu.custom_minimum_size = Vector2(58, 44)
	ui.mobile_menu.add_theme_font_size_override("font_size", 14)
	ui.mobile_speed.add_theme_font_size_override("font_size", 16)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var skin: StyleBox = ui.mobile_speed.get_theme_stylebox(state).duplicate()
		skin.content_margin_left = 4
		skin.content_margin_right = 4
		ui.mobile_speed.add_theme_stylebox_override(state, skin)
	ui.status.show()
	ui.status.add_theme_font_size_override("font_size", 13)
	ui.presentation_shell.place(ui.status, Vector2(right - 112, edge.y + 44), Vector2(112, 20))
	ui.presentation_shell.place(ui.alert_button, Vector2(right - 62, top + 6), Vector2(62, 44))
	ui.presentation_shell.place(ui.bottom_nav, Vector2(left, nav_y), Vector2(width, 52))
	ui.bottom_nav.add_theme_constant_override("separation", 4)
	for button in ui.bottom_nav.get_children():
		button.custom_minimum_size = Vector2(0, 52)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_constant_override("icon_max_width", 18)
		for state in ["normal", "hover", "pressed", "focus", "disabled"]:
			var skin: StyleBox = button.get_theme_stylebox(state).duplicate()
			skin.content_margin_left = 4
			skin.content_margin_right = 4
			button.add_theme_stylebox_override(state, skin)
	var contextual: bool = ui.page in ["table", "guest"]
	var sheet_top := top + 8
	var sheet_size := Vector2(width, nav_y - sheet_top - 8)
	var sheet_x := left
	if contextual:
		var sheet_height := minf(h * 0.62, nav_y - top - 12) if ui.context_expanded else 144.0
		if landscape:
			sheet_size = Vector2(minf(340, width * 0.43), minf(sheet_height, nav_y - top - 12))
			sheet_x = right - sheet_size.x
		else:
			sheet_size.y = sheet_height
		sheet_top = nav_y - sheet_size.y - 8
	ui.presentation_shell.place(ui.inspector_panel, Vector2(sheet_x, sheet_top), sheet_size)
	ui.inspector_heading.add_theme_font_size_override("font_size", 13)
	ui.inspector_expand.custom_minimum_size.x = 72
	ui.inspector_expand.add_theme_font_size_override("font_size", 14)
	var close: Button = ui.inspector_expand.get_parent().get_node("Close")
	close.custom_minimum_size.x = 60
	close.add_theme_font_size_override("font_size", 14)
	ui.presentation_shell.place(ui.events_panel, Vector2(left, top + 8), Vector2(width, nav_y - top - 16))
	ui.presentation_shell.place(ui.side_panel, Vector2(left, top + 8), Vector2(width, nav_y - top - 16))
	var palette_height := 80.0 if landscape else 136.0
	ui.presentation_shell.place(palette, Vector2(left, nav_y - palette_height - 8), Vector2(width, palette_height))
	ui.presentation_shell.place(ui.floor_actions, Vector2(left, actions_y), Vector2(width, 44))
	for button in ui.floor_actions.get_children():
		button.custom_minimum_size.x = 0
		button.add_theme_font_size_override("font_size", 14)
	ui.presentation_shell.place(ui.mode_hint, Vector2(left, actions_y - 28), Vector2(width, 24))
	ui.mode_hint.add_theme_font_size_override("font_size", 13)
	if ui.building:
		ui.floor_view.mobile_viewport.size.y = actions_y - 32 - top
	elif palette.visible:
		ui.floor_view.mobile_viewport.size.y = palette.position.y - top - 8
	elif contextual and ui.inspector_open and ui.mobile_pane == "table":
		if landscape: ui.floor_view.mobile_viewport.size.x = sheet_x - left - 8
		else: ui.floor_view.mobile_viewport.size.y = sheet_top - top - 8
