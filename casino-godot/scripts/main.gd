extends Control

const FloorScript = preload("res://scripts/floor.gd")
const FeltScript = preload("res://scripts/craps_layout.gd")
const GOLD := Color("e3bb70")
const TEAL := Color("57d6b1")
const MUTED := Color("8195a9")
const TEXT := Color("dbe5ed")

var sim := CasinoSimulation.new()
var floor_view: Control
var selected := 1
var selected_guest := -1
var visitor := false
var building := false
var moving := -1
var speed := 1
var previous_speed := 1
var tick := 0.0
var refresh_timer := 0.0
var rolling := 0.0
var page := "table"
var stats: Label
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
var chip_value := 25.0
var craps_category := "Line"
var active_roll_table := -1

func _ready() -> void:
	var theme := Theme.new()
	theme.default_font_size = 15
	theme.set_color("font_color", "Label", TEXT)
	theme.set_color("font_color", "Button", TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("233747")
		if state == "hover": bg = Color("325365")
		if state == "pressed": bg = Color("41625e")
		if state == "disabled": bg = Color("162433")
		var box := style(bg, Color("3c5360") if state != "focus" else GOLD)
		box.content_margin_left = 8
		box.content_margin_right = 8
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
	subtitle = label_at(Vector2.ZERO, "CASINO TYCOON  /  0.2", 11, MUTED)
	stats = label_at(Vector2.ZERO, "", 18, TEXT)
	status = label_at(Vector2.ZERO, "", 12, MUTED)
	header_actions = HBoxContainer.new()
	header_actions.add_theme_constant_override("separation", 6)
	add_child(header_actions)
	add_button(header_actions, "Save", save_game)
	add_button(header_actions, "Load", load_game)
	add_button(header_actions, "Help", show_help)
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
	build_button = add_button(left, "+ Build craps · $3,500", toggle_build)
	walk_button = add_button(left, "Walk the floor", toggle_walk)
	add_gap(left, 8)
	add_label(left, "MANAGEMENT", 11, MUTED)
	add_button(left, "Staff & assignments", func(): open_page("staff"))
	add_button(left, "Finance & performance", func(): open_page("finance"))
	add_button(left, "Incidents & decisions", func(): open_page("incidents"))
	add_gap(left, 10)
	add_label(left, "SIMULATION SPEED", 11, MUTED)
	var speeds := HBoxContainer.new()
	left.add_child(speeds)
	pause_button = add_button(speeds, "Pause", toggle_pause)
	for multiplier in [1, 2, 4]:
		add_button(speeds, "%d×" % multiplier, func(): speed = multiplier; previous_speed = multiplier; refresh())
	add_label(left, "Tap a table to inspect.
Tap the floor to walk.
Space: pause · R: rotate", 12, MUTED)
	add_button(left, "New casino…", confirm_reset)
	floor_view = FloorScript.new()
	floor_view.sim = sim
	floor_view.table_clicked.connect(select_table)
	floor_view.floor_clicked.connect(click_floor)
	floor_view.guest_clicked.connect(select_guest)
	add_child(floor_view)
	felt = FeltScript.new()
	felt.sim = sim
	felt.bet_clicked.connect(place_chip)
	add_child(felt)
	floor_actions = HBoxContainer.new()
	floor_actions.add_theme_constant_override("separation", 6)
	add_child(floor_actions)
	add_button(floor_actions, "Walk / manage", toggle_walk)
	floor_join_button = add_button(floor_actions, "Inspect table", func():
		if visitor and can_join(): join_table()
		else: open_page("table"))
	rotate_button = add_button(floor_actions, "Rotate", func(): floor_view.rotated = not floor_view.rotated; refresh())
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
	layout_ui()
	refresh()
	show_help()

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
	mobile = w < 1050 or h < 600
	backdrop.size = dimensions
	brand.add_theme_font_size_override("font_size", 16 if mobile else 24)
	brand.position = Vector2(12 if mobile else 20, 8 if mobile else 18)
	subtitle.visible = not mobile
	subtitle.position = Vector2(20, 50)
	header_actions.position = Vector2(w - 198, 34) if mobile else Vector2(w - 260, 16)
	header_actions.size = Vector2(186 if mobile else 240, 44)
	stats.position = Vector2(12, 88) if mobile else Vector2(340, 18)
	stats.add_theme_font_size_override("font_size", 15 if mobile else 18)
	status.position = Vector2(12, 112) if mobile else Vector2(340, 50)
	status.add_theme_font_size_override("font_size", 11 if mobile else 12)
	mode_hint.visible = not mobile
	bottom_nav.visible = mobile
	if mobile:
		var area := Rect2(10, 138, w - 20, maxf(100, h - 202))
		for panel in [side_panel, inspector_panel, events_panel]:
			panel.position = area.position
			panel.size = area.size
		bottom_nav.position = Vector2(10, h - 56)
		bottom_nav.size = Vector2(w - 20, 48)
		floor_view.position = area.position
		floor_view.size = Vector2(area.size.x, maxf(50, area.size.y - 58))
		floor_actions.position = Vector2(10, h - 116)
		floor_actions.size = Vector2(w - 20, 48)
	else:
		var side_width := 215.0
		var right_width := 370.0
		var middle_x := side_width + 36
		var middle_width := w - middle_x - right_width - 36
		side_panel.position = Vector2(16, 100)
		side_panel.size = Vector2(side_width, h - 116)
		inspector_panel.position = Vector2(w - right_width - 16, 100)
		inspector_panel.size = Vector2(right_width, h - 116)
		floor_view.position = Vector2(middle_x, 126)
		floor_view.size = Vector2(middle_width, h - 320)
		felt.position = floor_view.position
		felt.size = floor_view.size + Vector2(0, 54)
		mode_hint.position = Vector2(middle_x, 96)
		mode_hint.size = Vector2(middle_width, 26)
		floor_actions.position = Vector2(middle_x, h - 180)
		floor_actions.size = Vector2(middle_width, 44)
		events_panel.position = Vector2(middle_x, h - 120)
		events_panel.size = Vector2(middle_width, 104)
	apply_visibility()
	if modal != null:
		modal.position = Vector2(maxf(12, (w - 660) / 2), 12)
		modal.size = Vector2(minf(660, w - 24), h - 24)
		for child in get_children():
			if child.has_meta("modal_shade"): child.size = dimensions

func apply_visibility() -> void:
	side_panel.visible = not mobile or mobile_pane == "manage"
	inspector_panel.visible = not mobile or mobile_pane == "table"
	events_panel.visible = not mobile or mobile_pane == "log"
	felt.visible = not mobile and sim.joined >= 0
	floor_view.visible = (not mobile and sim.joined < 0) or (mobile and mobile_pane == "floor")
	floor_actions.visible = floor_view.visible
	rotate_button.visible = building
	floor_join_button.text = "Join table" if visitor and can_join() else "Inspect table"

func open_page(value: String) -> void:
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
	return not table.is_empty() and sim.operating(table) and sim.player.distance_to(sim.bounds(table).get_center()) <= 165


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
	if OS.has_feature("web") and OS.is_debug_build():
		publish_debug()
	if modal != null:
		return
	if speed > 0:
		sim.move_guests(delta * speed)
		tick += delta * speed
		while tick >= 1:
			tick -= 1
			sim.step()
	if rolling > 0:
		rolling -= delta
		if rolling <= 0:
			sim.shoot_player(active_roll_table)
			active_roll_table = -1
			refresh()
		elif is_instance_valid(dice_label):
			dice_label.text = "[ %d ]  [ %d ]" % [randi_range(1, 6), randi_range(1, 6)]
	refresh_timer += delta
	if refresh_timer >= 1:
		refresh_timer = 0
		refresh()

func _unhandled_key_input(event: InputEvent) -> void:
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
	return ("-$" if amount < 0 else "$") + String.num(absf(amount), 0)

func refresh() -> void:
	stats.text = "%s  /  %d guests  /  %.0f%% rep" % [money(sim.cash), sim.guests.size(), sim.reputation]
	status.text = "DAY %d  ·  %02d:%02d    |    NET %s    |    SATISFACTION %.0f%%    |    %s" % [sim.day, sim.minute / 60, sim.minute % 60, money(sim.net_profit()), sim.satisfaction(), "PAUSED" if speed == 0 else "%d× SPEED" % speed]
	if mobile:
		status.text = "DAY %d · %02d:%02d  |  NET %s  |  %s" % [sim.day, sim.minute / 60, sim.minute % 60, money(sim.net_profit()), "PAUSED" if speed == 0 else "%d×" % speed]
	doors_button.text = "Close to new arrivals" if sim.opened else "Open casino"
	build_button.text = "Cancel placement" if building else "+ Build craps · $3,500"
	walk_button.text = "Manage casino" if visitor else "Walk the floor"
	pause_button.text = "Play" if speed == 0 else "Pause"
	floor_view.visitor_mode = visitor
	floor_view.building = building
	floor_view.selected = selected
	mode_hint.text = "Click to place · R to rotate · Esc to cancel" if building else ("Tap to walk · tap a table to approach · E or Join to play" if visitor else "Select a table or guest to inspect · build and staff to expand")
	apply_visibility()
	felt.chip = chip_value
	felt.locked = rolling > 0 or speed == 0
	felt.queue_redraw()
	clear(feed)
	add_label(feed, "FLOOR REPORT   /   %d unresolved incidents" % sim.incidents.size(), 11, GOLD)
	for i in range(mini(8 if mobile else 3, sim.alerts.size())):
		add_label(feed, "• " + sim.alerts[i], 13, TEXT if i == 0 else MUTED)
	var scroll: ScrollContainer = inspector.get_parent()
	var scroll_position := scroll.scroll_vertical
	var live_inspector := inspector
	inspector = VBoxContainer.new()
	if sim.joined >= 0 and page == "table":
		render_craps()
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

func render_table() -> void:
	add_label(inspector, "TABLE INSPECTOR", 11, GOLD)
	var table := sim.get_table(selected)
	if table.is_empty():
		add_label(inspector, "Your next great craps pit", 24)
		add_label(inspector, "Build a table on the floor, hire two dealers, then open the doors.", 15, MUTED)
		return
	add_label(inspector, "Craps %02d" % selected, 26)
	add_label(inspector, sim.table_status(table), 14, TEAL if sim.operating(table) else GOLD)
	add_label(inspector, "CREW  %d/2      PLAYERS  %d/8" % [sim.crew(selected).size(), sim.seated(selected).size()], 12, MUTED)
	add_gap(inspector, 4)
	add_label(inspector, "Minimum %s\nWagers %s\nPayouts %s\nGaming win %s\nRounds %d" % [money(table.minimum), money(table.wagers), money(table.payouts), money(table.wagers - table.payouts), table.rolls], 16)
	add_label(inspector, "POINT: %s" % ("OFF / COME-OUT" if int(table.point) == 0 else str(int(table.point))), 12, GOLD)
	add_label(inspector, table.result, 13, MUTED)
	add_gap(inspector, 6)
	add_button(inspector, "Hire dealer · $150", func(): sim.hire("Dealer", selected); refresh(), sim.crew(selected).size() >= 2)
	add_button(inspector, "Assign standby dealers", func(): sim.assign_standby(selected); refresh())
	if table.broken:
		add_button(inspector, "Repair rail · $120", func():
			for i in range(sim.incidents.size()):
				if sim.incidents[i].type == "repair" and int(sim.incidents[i].table) == selected:
					sim.resolve_incident(i, true)
					break
			refresh())
	if visitor:
		var distance := sim.player.distance_to(sim.bounds(table).get_center())
		add_button(inspector, "Join craps table", join_table, not sim.operating(table) or distance > 165)
		add_label(inspector, "Approach the rail to join." if distance > 165 else "You're close enough to take a seat.", 12, MUTED)
		if distance > 165:
			add_button(inspector, "Walk to this table", func(): floor_view.walk_to_table(selected); mobile_pane = "floor"; refresh())
	else:
		add_button(inspector, "Experience this table", func(): toggle_walk())
	add_button(inspector, "Minimum: $25 / $50", func():
		if sim.busy(table):
			sim.log_event("Change limits when the table is empty.")
		else:
			table.minimum = 50.0 if table.minimum == 25 else 25.0
		refresh())
	add_button(inspector, "Move table", begin_move, sim.busy(table))
	add_button(inspector, "Sell · $1,750", func(): sim.sell(selected); refresh(), sim.busy(table))

func render_staff() -> void:
	add_label(inspector, "STAFF & COVERAGE", 11, GOLD)
	add_label(inspector, "%d employees" % sim.staff.size(), 24)
	add_label(inspector, "Two dealers operate each craps table. Tired crews slow rolls. Service staff prevent drink backlogs.", 14, MUTED)
	add_button(inspector, "Hire dealer · $150", func(): sim.hire("Dealer", selected); refresh())
	add_button(inspector, "Hire service · $150", func(): sim.hire("Service", -1); refresh())
	add_gap(inspector, 4)
	for employee in sim.staff:
		add_label(inspector, "%s · %s" % [employee.name, employee.role], 15)
		add_label(inspector, "%s · %.0f%% energy · $%d/hr" % ["Table %d" % int(employee.table) if int(employee.table) > 0 else "Floor / standby", employee.energy, 20 if employee.role == "Dealer" else 16], 12, MUTED)
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

func render_finance() -> void:
	add_label(inspector, "FINANCE / LIFETIME", 11, GOLD)
	add_label(inspector, money(sim.cash), 30, TEAL)
	add_label(inspector, "Casino treasury", 12, MUTED)
	add_gap(inspector, 6)
	var liabilities := 0.0
	for table in sim.tables:
		liabilities += CrapsRules.exposure(table.owner)
	for guest in sim.guests:
		liabilities += CrapsRules.exposure(guest.bets)
	add_label(inspector, "Wagers collected  %s\nPayouts returned  %s\nPayroll  %s\nOperations & builds  %s\n\nCash result  %s\nLive stakes held  %s\nSettled result  %s" % [money(sim.revenue), money(sim.payouts), money(sim.payroll), money(sim.overhead), money(sim.net_profit()), money(liabilities), money(sim.net_profit() - liabilities)], 16)
	add_label(inspector, "Live stakes are not earned profit. Payouts include returned stakes. Building and hiring costs are included in cash result.", 12, MUTED)
	add_gap(inspector, 6)
	add_label(inspector, "YOUR VISITOR ACCOUNT", 11, GOLD)
	add_label(inspector, "Wallet %s · net %s" % [money(sim.wallet), money(sim.visitor_net)], 16)
	add_label(inspector, "Visitor bets move money against the same treasury. Keep this transfer in mind when judging profitability.", 12, MUTED)
	if sim.cash < 1000:
		add_label(inspector, "Low cash: slow expansion and protect payroll. A hot table can make this worse.", 14, GOLD)

func render_incidents() -> void:
	add_label(inspector, "MANAGEMENT DECISIONS", 11, GOLD)
	add_label(inspector, "%d open incidents" % sim.incidents.size(), 24)
	if sim.incidents.is_empty():
		add_label(inspector, "A quiet floor. Watch service coverage and crew fatigue as the evening gets busier.", 15, MUTED)
	for i in range(sim.incidents.size()):
		var item: Dictionary = sim.incidents[i]
		add_label(inspector, item.title, 17, GOLD)
		add_label(inspector, item.detail, 14)
		add_button(inspector, "Repair · $120" if item.type == "repair" else "Offer comp · $60", func(): sim.resolve_incident(i, true); refresh())
		if item.type != "repair":
			add_button(inspector, "Dismiss complaint · -3 rep", func(): sim.resolve_incident(i, false); refresh())
		add_gap(inspector, 8)

func render_guest() -> void:
	add_label(inspector, "GUEST INSPECTOR", 11, GOLD)
	var found := sim.guests.filter(func(g): return int(g.id) == selected_guest)
	if found.is_empty():
		add_label(inspector, "Guest has left the casino.", 18)
		return
	var guest: Dictionary = found[0]
	add_label(inspector, guest.name, 25, GOLD if guest.vip else TEXT)
	add_label(inspector, guest.state, 14, TEAL)
	add_label(inspector, "Wallet %s\nSession net %s\nSatisfaction %.0f%%\nThirst %.0f%%\nPreferred game: craps" % [money(guest.wallet), money(guest.wallet + CrapsRules.exposure(guest.bets) - guest.start), guest.satisfaction, guest.thirst], 16)
	add_gap(inspector, 8)
	add_label(inspector, '“%s”' % guest.thought, 18, GOLD)
	add_label(inspector, "Watch your guests for clues about staffing, limits, and service.", 13, MUTED)

func row(parent: Node, columns: int = 0) -> Container:
	var container: Container = GridContainer.new() if columns > 0 else HBoxContainer.new()
	if columns > 0: container.columns = columns
	container.add_theme_constant_override("h_separation", 6)
	container.add_theme_constant_override("v_separation", 6)
	container.add_theme_constant_override("separation", 6)
	parent.add_child(container)
	return container

func place_chip(kind: String) -> void:
	if rolling > 0 or speed == 0 or sim.joined < 0: return
	sim.bet(sim.joined, kind, chip_value)
	refresh()

func begin_player_roll() -> void:
	var table := sim.get_table(sim.joined)
	if rolling > 0 or speed == 0 or table.is_empty() or int(table.shooter) != 0 or not sim.operating(table): return
	active_roll_table = sim.joined
	rolling = 0.65
	refresh()

func render_craps() -> void:
	var table := sim.get_table(sim.joined)
	var locked := rolling > 0 or speed == 0 or not sim.operating(table)
	add_label(inspector, "CRAPS %02d  /  WALLET %s" % [sim.joined, money(sim.wallet)], 18, GOLD)
	add_label(inspector, "SHOOTER: %s · hand roll %d" % [sim.shooter_name(table), int(table.hand_rolls)], 15, TEAL)
	var heading := "COME-OUT" if int(table.point) == 0 else "POINT %d" % int(table.point)
	dice_label = add_label(inspector, "[ %d ] [ %d ]    %s" % [table.dice[0], table.dice[1], heading], 23)
	var roll_controls := row(inspector)
	add_button(roll_controls, "Rolling…" if rolling > 0 else "SHOOT DICE", begin_player_roll, locked or int(table.shooter) != 0)
	add_button(roll_controls, "Pass dice to CPU" if int(table.shooter) == 0 else ("Resume CPU" if table.betting_hold else "Hold betting"), func():
		if int(table.shooter) == 0: sim.pass_dice(sim.joined)
		else:
			table.betting_hold = not table.betting_hold
			table.timer = 0.0
		refresh(), rolling > 0)
	if int(table.shooter) != 0:
		var wait := "Betting held" if table.betting_hold else ("Paused" if speed == 0 else "Next roll ~%ds" % ceili(maxf(0, sim.roll_interval(table) - table.timer) / maxf(1, speed)))
		add_label(inspector, "%s · %s" % [wait, "you're in rotation" if table.owner_queued else "you're betting only"], 12, MUTED)
		add_button(inspector, "Skip my turns" if table.owner_queued else "Join shooter rotation", func():
			if table.owner_queued: sim.pass_dice(sim.joined)
			else: sim.queue_for_dice(sim.joined)
			refresh(), rolling > 0)
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
			explanation = "Pass / Don't Pass: even money; Don't pushes on 12. Odds: true odds, 3× limit (lay to win 3×). Field: double 2, triple 12."
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
			add_label(inspector, "On layout: %s · wallet net: %s" % [money(CrapsRules.exposure(table.owner)), money(sim.visitor_net)], 14, GOLD)
			for kind in table.owner:
				if table.owner[kind] <= 0: continue
				var removable := CrapsRules.removable(kind, int(table.point))
				add_button(inspector, "%s · %s%s" % [CrapsRules.name_for(kind), money(table.owner[kind]), " · remove" if removable else " · locked"], func(): sim.remove_bet(sim.joined, kind); refresh(), not removable or rolling > 0)
			add_button(inspector, "Take down removable bets", func(): sim.reclaim(sim.joined); refresh(), rolling > 0)
			explanation = "Established Pass and Come contracts stay until resolved. Removing a Don't contract also returns its attached odds."
		"History":
			if table.history.is_empty(): add_label(inspector, "No rolls yet.")
			for entry in table.history:
				add_label(inspector, "%d + %d = %d  ·  %s%s" % [entry.a, entry.b, entry.total, entry.shooter, " · SEVEN OUT" if entry.seven_out else ""], 14, GOLD if entry.seven_out else TEXT)
	var bets_grid := row(inspector, 2)
	for kind in kinds:
		var amount := sim.bet_amount(table, kind, chip_value)
		var error := sim.bet_error(sim.joined, kind, chip_value)
		var button := add_button(bets_grid, "%s +%s\nOn: %s" % [CrapsRules.name_for(kind), money(amount), money(table.owner[kind])], func(): place_chip(kind), locked or error != "")
		button.custom_minimum_size.y = 58
		button.tooltip_text = error
	if craps_category in ["Place", "Hard", "Come"]:
		add_button(inspector, "Come-out: WORKING" if table.owner_working else "Come-out: OFF", func(): table.owner_working = not table.owner_working; refresh(), rolling > 0)
		add_label(inspector, "Applies to Place, hardways and Come odds.", 11, MUTED)
	add_label(inspector, explanation, 12, MUTED)
	add_label(inspector, table.result, 13, GOLD)
	add_button(inspector, "Leave table / walk floor", leave_table, rolling > 0)


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
		var id := sim.place(at, floor_view.rotated)
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
	floor_view.rotated = bool(sim.get_table(selected).rotated)
	refresh()

func toggle_build() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
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
	visitor = not visitor
	mobile_pane = "floor"
	building = false
	moving = -1
	page = "table"
	refresh()

func join_table() -> void:
	var table := sim.get_table(selected)
	if table.is_empty() or not visitor or not sim.operating(table) or sim.player.distance_to(sim.bounds(table).get_center()) > 165:
		return
	if sim.seated(selected).size() >= 8:
		sim.log_event("All eight seats are taken. Try another table.")
		refresh()
		return
	if not sim.join_table(selected): return
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
	var file := FileAccess.open("user://neon-house-v1.json", FileAccess.WRITE)
	if file == null:
		sim.log_event("Save failed: browser storage is unavailable.")
	else:
		file.store_string(JSON.stringify(sim.snapshot()))
		file.close()
		sim.log_event("Casino saved locally in this browser.")
	refresh()

func load_game() -> void:
	if rolling > 0:
		return
	if not FileAccess.file_exists("user://neon-house-v1.json"):
		sim.log_event("No local save found. Save your casino first.")
		refresh()
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://neon-house-v1.json"))
	if not data is Dictionary or not sim.restore(data):
		sim.log_event("Save is invalid or belongs to a different version.")
	else:
		visitor = sim.joined >= 0
		page = "table"
		mobile_pane = "table" if visitor else "floor"
		selected = sim.joined if sim.joined >= 0 else (int(sim.tables[0].id) if not sim.tables.is_empty() else -1)
		building = false
		moving = -1
		tick = 0
		sim.log_event("Casino restored, including guests, wagers and dice state.")
	refresh()

func close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null
		for child in get_children():
			if child.has_meta("modal_shade"):
				child.queue_free()

func dialog(title: String, body: String, confirm: String, action: Callable) -> void:
	if modal != null:
		return
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
	if confirm != "Let's open the house":
		add_button(layout, "Cancel", close_modal)
	layout_ui()

func show_help() -> void:
	dialog("Run it. Walk it. Play it.", "Hire two dealers at your first craps table, then open the casino.

Tap a table to inspect. Walk mode: tap a table to approach the rail, then Join. WASD also works.

The shooter keeps the dice until seven-out. Pass dice lets a CPU shoot while you bet. Joining an active table queues your turn. Hold betting pauses only that table's CPU rolls.

Choose chips and a bet category. The My bets tab lists contracts and removable stakes. Place, hardways and Come odds are off on come-out unless called working.

On phones use Floor, Table, Manage and Log below. Save locally before leaving.", "Let's open the house", func(): pass)
	layout_ui()

func confirm_reset() -> void:
	dialog("Start a new casino?", "This resets the current session. Your existing local save is kept until you save again.", "Start new casino", func():
		sim = CasinoSimulation.new()
		floor_view.sim = sim
		felt.sim = sim
		selected = 1
		sim.joined = -1
		visitor = false
		building = false
		moving = -1
		speed = 1
		tick = 0
		page = "table"
		refresh())

func publish_debug() -> void:
	if not OS.has_feature("web") or not OS.is_debug_build():
		return
	var buttons: Array = []
	for button in get_tree().get_nodes_in_group("debug_buttons"):
		if button.is_visible_in_tree():
			var rect: Rect2 = button.get_global_rect()
			buttons.append({"text": button.text, "disabled": button.disabled, "x": rect.position.x, "y": rect.position.y, "w": rect.size.x, "h": rect.size.y})
	JavaScriptBridge.eval("window.neonHouseSnapshot = " + JSON.stringify(sim.snapshot()) + ";window.neonHouseUI = " + JSON.stringify(buttons), true)

# Preserve live buttons across simulation refreshes: a mouse-down must not lose
# its button before mouse-up just because the clock advanced.
func patch_inspector(proposed: VBoxContainer) -> void:
	patch_children(inspector, proposed)

func patch_children(parent: Control, proposed: Control) -> void:
	var compatible := parent.get_child_count() == proposed.get_child_count()
	if compatible:
		for i in range(parent.get_child_count()):
			if parent.get_child(i).get_class() != proposed.get_child(i).get_class():
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
		if live is Label:
			live.text = fresh.text
			live.add_theme_font_size_override("font_size", fresh.get_theme_font_size("font_size"))
			live.add_theme_color_override("font_color", fresh.get_theme_color("font_color"))
			if dice_label == fresh: dice_label = live
		elif live is Button:
			live.text = fresh.text
			live.disabled = fresh.disabled
			live.tooltip_text = fresh.tooltip_text
			live.toggle_mode = fresh.toggle_mode
			live.set_pressed_no_signal(fresh.button_pressed)
			for connection in live.get_signal_connection_list("pressed"):
				live.disconnect("pressed", connection.callable)
			for connection in fresh.get_signal_connection_list("pressed"):
				live.connect("pressed", connection.callable)
		elif live is Container:
			if live is GridContainer: live.columns = fresh.columns
			patch_children(live, fresh)
