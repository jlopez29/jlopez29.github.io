extends Control

const FloorScript = preload("res://scripts/floor.gd")
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
		box.content_margin_left = 12
		box.content_margin_right = 12
		box.content_margin_top = 9
		box.content_margin_bottom = 9
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_disabled_color", "Button", Color("5e7184"))
	self.theme = theme
	var bg := ColorRect.new()
	bg.color = Color("0b121d")
	bg.size = Vector2(1440, 900)
	bg.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(bg)
	label_at(Vector2(24, 22), "N E O N   H O U S E", 25, GOLD)
	label_at(Vector2(24, 58), "CASINO TYCOON  /  FIRST PLAYABLE 0.1", 11, MUTED)
	stats = label_at(Vector2(355, 24), "", 20, TEXT)
	status = label_at(Vector2(355, 58), "", 13, MUTED)
	button_at(Vector2(1130, 22), Vector2(80, 40), "Save", save_game)
	button_at(Vector2(1218, 22), Vector2(80, 40), "Load", load_game)
	button_at(Vector2(1306, 22), Vector2(108, 40), "How to play", show_help)
	label_at(Vector2(280, 103), "THE GAMING FLOOR", 13, GOLD)
	mode_hint = label_at(Vector2(550, 103), "", 12, MUTED)
	var side := panel_at(Vector2(20, 140), Vector2(240, 735))
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	side.add_child(left)
	add_label(left, "YOUR CASINO", 13, GOLD)
	add_label(left, "Run the house.\nThen see it from the floor.", 18, TEXT)
	add_gap(left, 10)
	doors_button = add_button(left, "Open casino", toggle_doors)
	build_button = add_button(left, "+ Build craps · $3,500", toggle_build)
	walk_button = add_button(left, "Walk the floor", toggle_walk)
	add_gap(left, 8)
	add_label(left, "MANAGEMENT", 11, MUTED)
	add_button(left, "Staff & assignments", func(): page = "staff"; refresh())
	add_button(left, "Finance & performance", func(): page = "finance"; refresh())
	add_button(left, "Incidents & decisions", func(): page = "incidents"; refresh())
	add_gap(left, 10)
	add_label(left, "SIMULATION SPEED", 11, MUTED)
	var speeds := HBoxContainer.new()
	left.add_child(speeds)
	pause_button = add_button(speeds, "Pause", toggle_pause)
	for multiplier in [1, 2, 4]:
		add_button(speeds, "%d×" % multiplier, func(): speed = multiplier; previous_speed = multiplier; refresh())
	add_label(left, "1 second = 1 game minute\nSpace: pause · R: rotate\nEsc: cancel / leave table", 12, MUTED)
	add_gap(left, 4)
	add_button(left, "New casino…", confirm_reset)
	floor_view = FloorScript.new()
	floor_view.position = Vector2(280, 140)
	floor_view.size = Vector2(850, 615)
	floor_view.sim = sim
	floor_view.table_clicked.connect(select_table)
	floor_view.floor_clicked.connect(click_floor)
	floor_view.guest_clicked.connect(select_guest)
	add_child(floor_view)
	var right := panel_at(Vector2(1150, 140), Vector2(270, 615))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(scroll)
	inspector = VBoxContainer.new()
	inspector.size_flags_horizontal = SIZE_EXPAND_FILL
	inspector.add_theme_constant_override("separation", 9)
	scroll.add_child(inspector)
	var events := panel_at(Vector2(280, 775), Vector2(1140, 104))
	feed = VBoxContainer.new()
	feed.add_theme_constant_override("separation", 5)
	events.add_child(feed)
	refresh()
	show_help()

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
			sim.roll(sim.joined)
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
	stats.text = "%s    /    %d guests    /    %.0f%% reputation" % [money(sim.cash), sim.guests.size(), sim.reputation]
	status.text = "DAY %d  ·  %02d:%02d    |    NET %s    |    SATISFACTION %.0f%%    |    %s" % [sim.day, sim.minute / 60, sim.minute % 60, money(sim.net_profit()), sim.satisfaction(), "PAUSED" if speed == 0 else "%d× SPEED" % speed]
	doors_button.text = "Close to new arrivals" if sim.opened else "Open casino"
	build_button.text = "Cancel placement" if building else "+ Build craps · $3,500"
	walk_button.text = "Return to management" if visitor else "Walk the floor"
	pause_button.text = "Play" if speed == 0 else "Pause"
	floor_view.visitor_mode = visitor
	floor_view.building = building
	floor_view.selected = selected
	mode_hint.text = "Click to place · R to rotate · Esc to cancel" if building else ("WASD / arrows to walk · select a nearby table · E to join" if visitor else "Select a table or guest to inspect · build and staff to expand")
	clear(feed)
	add_label(feed, "FLOOR REPORT   /   %d unresolved incidents" % sim.incidents.size(), 11, GOLD)
	for i in range(mini(3, sim.alerts.size())):
		add_label(feed, "• " + sim.alerts[i], 13, TEXT if i == 0 else MUTED)
	var scroll: ScrollContainer = inspector.get_parent()
	var scroll_position := scroll.scroll_vertical
	var live_inspector := inspector
	inspector = VBoxContainer.new()
	if sim.joined >= 0:
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
		add_label(inspector, "Walk beside the table to join." if distance > 165 else "You're close enough to take a seat.", 12, MUTED)
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

func render_craps() -> void:
	var table := sim.get_table(sim.joined)
	add_label(inspector, "AT THE RAIL / CRAPS %02d" % sim.joined, 11, GOLD)
	add_label(inspector, money(sim.wallet), 28, TEAL)
	add_label(inspector, "YOUR WALLET · SESSION %s" % money(sim.visitor_net), 11, MUTED)
	add_label(inspector, "COME-OUT" if int(table.point) == 0 else "POINT  %d" % int(table.point), 21, GOLD)
	dice_label = add_label(inspector, "[ %d ]  [ %d ]" % [table.dice[0], table.dice[1]], 34, TEXT)
	add_label(inspector, table.result, 13, MUTED)
	var locked := rolling > 0 or speed == 0 or not sim.operating(table)
	add_button(inspector, "Pass Line %s   [%s]" % [money(table.minimum), money(table.owner.pass)], func(): sim.bet(sim.joined, "pass"); refresh(), locked or int(table.point) != 0 or table.owner.pass > 0)
	add_button(inspector, "Add odds $30   [%s]" % money(table.owner.odds), func(): sim.bet(sim.joined, "odds"); refresh(), locked or int(table.point) == 0 or table.owner.pass == 0 or table.owner.odds + 30 > table.owner.pass * 3)
	for kind in ["six", "eight"]:
		add_button(inspector, "Place %s $30   [%s]" % ["6" if kind == "six" else "8", money(table.owner[kind])], func(): sim.bet(sim.joined, kind); refresh(), locked)
	add_button(inspector, "Field %s   [%s]" % [money(table.minimum), money(table.owner.field)], func(): sim.bet(sim.joined, "field"); refresh(), locked or table.owner.field > 0)
	add_button(inspector, "Rolling…" if rolling > 0 else "SHOOT THE DICE", func(): rolling = 0.65; refresh(), locked)
	add_button(inspector, "Take down removable bets", func(): sim.reclaim(sim.joined); refresh(), rolling > 0)
	add_button(inspector, "Leave table", leave_table, rolling > 0)
	add_label(inspector, "Place 6/8: 7:6, OFF on come-out. Field: double 2, triple 12. Odds: true odds, up to 3×. Pass contracts lock after a point.", 11, MUTED)
	add_label(inspector, "Your table rolls when you shoot. The rest of the casino keeps running.", 11, GOLD)

func select_table(id: int) -> void:
	if sim.joined >= 0:
		return
	selected = id
	selected_guest = -1
	page = "table"
	refresh()

func select_guest(id: int) -> void:
	if sim.joined >= 0:
		return
	selected_guest = id
	page = "guest"
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
	refresh()

func toggle_walk() -> void:
	if rolling > 0:
		return
	if sim.joined >= 0:
		leave_table()
	visitor = not visitor
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
	sim.joined = selected
	var rect := sim.bounds(table)
	sim.player = Vector2(rect.get_center().x, rect.end.y + 24)
	floor_view.move_target = Vector2(-1, -1)
	sim.log_event("You're at the rail. Place bets and shoot; other players share your rolls.")
	refresh()

func leave_table() -> void:
	if rolling > 0:
		return
	sim.joined = -1
	sim.log_event("Left the rail. Any locked bets remain and settle with the next table rolls.")
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
	modal.add_child(layout)
	add_label(layout, "N E O N   H O U S E", 13, GOLD)
	add_label(layout, title, 31)
	add_label(layout, body, 17)
	add_gap(layout, 8)
	add_button(layout, confirm, func(): close_modal(); action.call())
	if confirm != "Let's open the house":
		add_button(layout, "Cancel", close_modal)

func show_help() -> void:
	dialog("Run it. Walk it. Play it.", "Start with $24,000 and one craps table.\n\n1  Hire two dealers using the table inspector.\n2  Open the casino and watch guests arrive.\n3  Build another table; hire service to keep guests happy.\n4  Walk the floor with WASD / arrows, select a nearby table, and join.\n5  Place a Pass Line bet and shoot. Add odds after a point.\n\nCasino money and your $1,000 visitor wallet are separate. Guest wagers and your bets settle against the same house. Save locally before leaving.", "Let's open the house", func(): pass)

func confirm_reset() -> void:
	dialog("Start a new casino?", "This resets the current session. Your existing local save is kept until you save again.", "Start new casino", func():
		sim = CasinoSimulation.new()
		floor_view.sim = sim
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
	var compatible := inspector.get_child_count() == proposed.get_child_count()
	if compatible:
		for i in range(inspector.get_child_count()):
			if inspector.get_child(i).get_class() != proposed.get_child(i).get_class():
				compatible = false
				break
	if not compatible:
		clear(inspector)
		for child in proposed.get_children():
			proposed.remove_child(child)
			inspector.add_child(child)
		return
	for i in range(inspector.get_child_count()):
		var live: Control = inspector.get_child(i)
		var fresh: Control = proposed.get_child(i)
		live.custom_minimum_size = fresh.custom_minimum_size
		if live is Label:
			live.text = fresh.text
			live.add_theme_font_size_override("font_size", fresh.get_theme_font_size("font_size"))
			live.add_theme_color_override("font_color", fresh.get_theme_color("font_color"))
			if dice_label == fresh:
				dice_label = live
		elif live is Button:
			live.text = fresh.text
			live.disabled = fresh.disabled
			for connection in live.get_signal_connection_list("pressed"):
				live.disconnect("pressed", connection.callable)
			for connection in fresh.get_signal_connection_list("pressed"):
				live.connect("pressed", connection.callable)
