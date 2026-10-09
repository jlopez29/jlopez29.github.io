class_name PitBossPlayView
extends Control
# Shared play shell. Simulation methods remain the sole owners of wagers/results.
signal leave_requested
signal changed
signal pause_requested
signal craps_action_requested(action: String)
const FinancialText = preload("res://scripts/financial_text.gd")
const Games = preload("res://scripts/casino_games.gd")
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const SlotResult = preload("res://scripts/slot_result.gd")
const RESULT_HOLD_SECONDS := 1.25
const SLOT_STEPS := [1, 5, 10, 25, 50, 100, 1000]
const Surface = preload("res://scripts/casino_surface.gd")
const RouletteLayout = preload("res://scripts/roulette_layout.gd")
var sim: PitBossGameContext:
	set(value):
		if sim == value: return
		sim = value
		current_id = -1
		player_round = {}
		result_hold = 0
		result_pending = false
		roulette_guests.clear()
		roulette_display_remaining = 0
		signature.clear()
		surface_signature.clear()
		roulette_signature.clear()
var paused := false
var bet := 10.0
var slot_step := 1.0
var result_hold := 0.0
var result_pending := false
var audio_button: Button
var bet_indicator: Label
var slot_lines := 1
var balance_before := Vector2.ZERO
var slot_dimmer: ColorRect
var slot_spin: Button
var slot_wager_row: HBoxContainer
var line_diagrams: Control
var trips_bet := 0.0
var trips_composition: Array[float] = []
var compose_trips := false
var art: Control
var felt: Control
var craps: Control
var header: Panel
var brand: Label
var wallet: Label
var wallet_value: Label
var casino_cash: Label
var game_title: Label
var return_button: Button
var pause_button: Button
var surface_scroll: ScrollContainer
var rack_scroll: ScrollContainer
var rack: Control
var menu_button: MenuButton
var options_panel: PanelContainer
var compose := false
var composition: Array[float] = []
var selected_chip := 25.0
var fine_chips := false
var stage: BoxContainer
var controls_scroll: ScrollContainer
var controls: BoxContainer
var result_label: Label
var wager_label: Label
var actions: GridContainer
var details: VBoxContainer
var rules: PanelContainer
var rules_text: Label
var player_round: Dictionary = {}
var roulette_guests: Array = []
var roulette_display_remaining := 0.0
var current_id := -1
var feedback := ""
var rendered_sequence := -1
var show_rules := false
var show_details := false
var show_wheel := false
var selected_wager := "pass"
var cursors := {}
var signature: Array = []
var surface_signature: Array = []
var roulette_signature: Array = []
var last_active_hand := -1
var poll := 0.0
var compact := false
var landscape := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	header = Panel.new()
	header.add_theme_stylebox_override("panel", PitBoss.box(Color("101315"), PitBoss.GOLD, 0))
	add_child(header)
	brand = make_label(header, "PIT BOSS", 22, PitBoss.GOLD)
	wallet = make_label(header, "", 17)
	wallet_value = make_label(header, "", 18)
	casino_cash = make_label(header, "", 13, PitBoss.MUTED)
	game_title = make_label(header, "", 14, PitBoss.GOLD)
	return_button = make_button(header, "Floor", func():
		if result_hold <= 0 and not result_pending and art.spinning <= 0 and (not is_instance_valid(craps) or not craps.visible or not craps.busy()): leave_requested.emit())
	return_button.tooltip_text = "Return to Floor"
	pause_button = make_button(header, "Pause", func(): pause_requested.emit())
	audio_button = make_button(header, "", toggle_audio)
	audio_button.expand_icon = true
	audio_button.add_theme_constant_override("icon_max_width", 22)
	bet_indicator = make_label(header, "", 13, PitBoss.GOLD)
	bet_indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bet_indicator.clip_text = true
	surface_scroll = ScrollContainer.new()
	surface_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(surface_scroll)
	stage = BoxContainer.new()
	stage.vertical = true
	stage.size_flags_horizontal = SIZE_EXPAND_FILL
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	surface_scroll.add_child(stage)
	menu_button = MenuButton.new()
	header.add_child(menu_button)
	menu_button.text = "..."
	menu_button.tooltip_text = "Wallet, bets, rules and table options"
	menu_button.get_popup().id_pressed.connect(menu_action)
	rack_scroll = ScrollContainer.new()
	rack_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(rack_scroll)
	rack = preload("res://presentation/play/chip_rack.gd").new()
	rack_scroll.add_child(rack)
	rack.selected.connect(select_chip)
	rack.drag_requested.connect(func():
		if sim.table_kind(current_table()) == "craps": craps.begin_chip_drag(bet)
		elif sim.table_kind(current_table()) == "roulette": felt.begin_chip_drag())
	art = Surface.new()
	art.size_flags_horizontal = SIZE_EXPAND_FILL
	art.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(art)
	art.spot_selected.connect(func(value: bool): compose_trips = value; notify_change())
	felt = RouletteLayout.new()
	felt.hide_tray = true
	felt.size_flags_horizontal = SIZE_EXPAND_FILL
	stage.add_child(felt)
	felt.wager_requested.connect(func(name: String, amount: float):
		if locked(): return
		feedback = "" if sim.roulette_bet(sim.joined, name, amount) else "Wager unavailable. Check wallet and table limits."
		notify_change())
	felt.denomination_changed.connect(func(amount: float): bet = amount; notify_change())
	controls_scroll = ScrollContainer.new()
	controls_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(controls_scroll)
	controls = BoxContainer.new()
	controls.vertical = true
	controls.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	controls_scroll.add_child(controls)
	slot_spin = make_button(controls, "SPIN", press_slot_spin)
	slot_spin.z_index = 10
	slot_spin.custom_minimum_size.y = 54
	slot_spin.add_theme_font_size_override("font_size", 22)
	slot_spin.add_theme_stylebox_override("normal", PitBoss.box(Color("70562b"), PitBoss.GOLD, 10))
	slot_spin.add_theme_stylebox_override("hover", PitBoss.box(Color("92713b"), PitBoss.GOLD, 10))
	slot_spin.add_theme_stylebox_override("pressed", PitBoss.box(Color("584522"), PitBoss.GOLD, 10))
	slot_spin.add_theme_stylebox_override("disabled", PitBoss.box(Color("302a21"), Color("6f603f"), 10))
	slot_spin.hide()
	slot_wager_row = HBoxContainer.new()
	slot_wager_row.add_theme_constant_override("separation", 6)
	slot_wager_row.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.add_child(slot_wager_row)
	slot_wager_row.hide()
	wager_label = make_label(controls, "", 16)
	actions = preload("res://scripts/responsive_grid.gd").new()
	actions.maximum_columns = 3
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	controls.add_child(actions)
	result_label = make_label(controls, "", 16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	options_panel = PanelContainer.new()
	options_panel.z_index = 19
	options_panel.add_theme_stylebox_override("panel", PitBoss.box(Color("101f1a"), PitBoss.GOLD, 12))
	add_child(options_panel)
	var option_scroll := ScrollContainer.new()
	option_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	options_panel.add_child(option_scroll)
	option_scroll.add_child(details)
	options_panel.hide()
	slot_dimmer = ColorRect.new()
	slot_dimmer.color = Color(0,0,0,0.22)
	slot_dimmer.mouse_filter = MOUSE_FILTER_IGNORE
	slot_dimmer.z_index = 8
	add_child(slot_dimmer)
	slot_dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_dimmer.hide()
	rules = PanelContainer.new()
	rules.z_index = 20
	rules.add_theme_stylebox_override("panel", PitBoss.box(Color("101315"), PitBoss.GOLD, 12))
	add_child(rules)
	var rules_stack := VBoxContainer.new()
	rules.add_child(rules_stack)
	make_button(rules_stack, "Close rules", func(): show_rules = false; rules.hide())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	rules_stack.add_child(scroll)
	var rule_content := VBoxContainer.new()
	rule_content.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(rule_content)
	line_diagrams = preload("res://scripts/slot_line_diagrams.gd").new()
	rule_content.add_child(line_diagrams)
	rules_text = make_label(rule_content, "", 16)
	rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.hide()
	resized.connect(layout_play)
	layout_play()

func attach_craps(surface: Control) -> void:
	craps = surface
	craps.reparent(self)
	craps.remove_drop = null
	craps.input_overlay = rules
	craps.options_overlay = options_panel
	craps.size_flags_horizontal = SIZE_EXPAND_FILL
	craps.size_flags_vertical = SIZE_EXPAND_FILL

func make_label(parent: Node, text_value: String, font_size: int, color: Color = PitBoss.TEXT) -> Label:
	var item := Label.new()
	parent.add_child(item)
	item.text = text_value
	item.add_theme_font_size_override("font_size", font_size)
	item.add_theme_color_override("font_color", color)
	item.size_flags_horizontal = SIZE_EXPAND_FILL
	item.mouse_filter = MOUSE_FILTER_IGNORE
	return item

func make_button(parent: Node, title: String, callback: Callable) -> Button:
	var item := Button.new()
	parent.add_child(item)
	item.text = title
	item.custom_minimum_size = Vector2(0, 44)
	item.clip_text = true
	item.size_flags_horizontal = SIZE_EXPAND_FILL
	item.add_theme_font_size_override("font_size", 14)
	item.pressed.connect(callback)
	return item

func button(title: String, callback: Callable, parent: Node = null, disabled: bool = false, primary: bool = false) -> Button:
	if parent == null: parent = actions
	var item: Button = retained(parent, "button", func(): return make_button(parent, "", func(): pass))
	item.text = title.replace("×", "x")
	if parent == actions and art.kind != "slots":
		item.size_flags_horizontal = SIZE_SHRINK_CENTER
		item.custom_minimum_size = Vector2(76 if title not in ["Dice", "Deal", "Spin"] else 48, 44)
	item.disabled = disabled
	for connection in item.get_signal_connection_list("pressed"): item.disconnect("pressed", connection.callable)
	item.pressed.connect(callback)
	var skin := StyleBoxTexture.new()
	skin.texture = PitBoss.texture("casino_play/shared/ui/action_primary.svg" if primary else "casino_play/shared/ui/action_secondary.svg")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 16)
		skin.set_content_margin(side, 8)
	item.add_theme_stylebox_override("normal", skin)
	if parent == actions and art.kind != "slots":
		for state in ["normal", "hover", "pressed", "disabled"]:
			var pill := PitBoss.box(Color("244d38") if state != "disabled" else Color("20332a"), PitBoss.GOLD if state != "disabled" else PitBoss.MUTED, 8)
			pill.set_corner_radius_all(24)
			item.add_theme_stylebox_override(state, pill)
	return item

static func put(node: Control, position_value: Vector2, extent: Vector2) -> void:
	node.position = position_value
	node.size = extent

func layout_play() -> void:
	if not is_node_ready(): return
	compact = size.x < 1000
	landscape = size.x > size.y and size.y < 600
	# The browser wrapper already reports the visible viewport, including safe areas.
	var tall_header := size.x < 760
	var top := 100.0 if tall_header else 56.0
	put(header, Vector2(4, 4), Vector2(size.x - 8, top - 8))
	brand.hide()
	casino_cash.hide()
	wallet_value.hide()
	put(game_title, Vector2(8, 2), Vector2(maxf(80, minf(200, size.x - 210)), 19))
	put(wallet, Vector2(8, 70 if tall_header else 24), Vector2(size.x - 16 if tall_header else maxf(80, size.x - 210), 20))
	put(bet_indicator, Vector2(8, 48) if tall_header else Vector2(210, 2), Vector2(size.x - 24 if tall_header else maxf(0, size.x - 420), 22))
	wallet.add_theme_font_size_override("font_size", 14)
	put(return_button, Vector2(header.size.x - 192, 2), Vector2(44, 44))
	return_button.text = "<"
	put(pause_button, Vector2(header.size.x - 144, 2), Vector2(44, 44))
	put(audio_button, Vector2(header.size.x - 96, 2), Vector2(44, 44))
	put(menu_button, Vector2(header.size.x - 48, 2), Vector2(44, 44))
	var slots: bool = art.kind == "slots"
	if slots:
		controls.vertical = true
		var footer := 198.0 if not landscape else 0.0
		var rail := clampf(size.x * 0.34, 264, 304)
		put(surface_scroll, Vector2(4, top), Vector2(size.x - (rail if landscape else 8), size.y - top - footer - 4))
		put(controls_scroll, Vector2(size.x - rail + 8, top) if landscape else Vector2(8, size.y - footer), Vector2(rail - 16, size.y - top - 4) if landscape else Vector2(size.x - 16, footer))
	else:
		var spatial: bool = art.kind in ["craps", "roulette"]
		controls.vertical = not spatial
		var footer := 126.0 if spatial else 206.0 if size.x < 600 else 142.0
		var wheel_visible: bool = art.kind == "roulette" and (show_wheel or art.spinning > 0)
		var wheel_lane := clampf(size.x * 0.30, 280, 420) if wheel_visible and size.x >= 1000 else 0.0
		var wheel_top := minf(240, (size.y - top - footer) * 0.38) if wheel_visible and size.x < 1000 and not landscape else 0.0
		if wheel_visible and landscape: wheel_lane = minf(260, size.x * 0.32)
		put(surface_scroll, Vector2(4, top + wheel_top), Vector2(size.x - 8 - wheel_lane, maxf(80, size.y - top - footer - wheel_top)))
		put(controls_scroll, Vector2(8, size.y - footer), Vector2(size.x - 16, 48 if spatial else footer - 68))
		put(rack_scroll, Vector2(8, size.y - 76), Vector2(size.x - 16, 74))
	rack_scroll.visible = not slots
	surface_scroll.visible = art.kind != "craps"
	if is_instance_valid(craps): put(craps, surface_scroll.position, surface_scroll.size)
	stage.vertical = true
	art.custom_minimum_size.x = 0
	art.play_height = surface_scroll.size.y
	felt.available_height = surface_scroll.size.y
	if art.kind == "roulette":
		if art.get_parent() != self: art.reparent(self)
		art.z_index = 3
		var wheel_extent := minf(clampf(size.x * 0.30, 280, 420) - 16, surface_scroll.size.y - 16) if size.x >= 1000 else minf(244, minf(size.x * 0.32 - 16, surface_scroll.size.y - 16)) if landscape else minf(224, (size.y - top - 126) * 0.38 - 16)
		var wheel_position := Vector2(size.x - wheel_extent - 12, top + 8) if size.x >= 1000 or landscape else Vector2((size.x - wheel_extent) / 2, top + 8)
		put(art, wheel_position, Vector2(wheel_extent, wheel_extent))
	elif art.get_parent() != stage:
		art.reparent(stage)
	art.size_flags_horizontal = SIZE_EXPAND_FILL if stage.vertical else SIZE_FILL
	felt.vertical_layout = not landscape and size.x < 1000
	felt.rebuild()
	put(rules, Vector2(8, top), Vector2(size.x - 16, size.y - top - 8))
	var drawer_width := minf(size.x - 16, 380)
	put(options_panel, Vector2(size.x - drawer_width - 8, top if not compact else size.y * 0.4), Vector2(drawer_width, size.y - top - 8 if not compact else size.y * 0.6 - 8))
	art.configure()

func select_chip(amount: float) -> void:
	if sim == null or locked() or sim.game_pending(current_table()) or (sim.is_private and amount < float(current_table().minimum)): return
	selected_chip = amount
	var kind := sim.table_kind(current_table())
	if kind == "holdem" and compose_trips:
		trips_composition.append(trips_bet)
		trips_bet = snappedf(trips_bet + amount, 0.01)
	elif kind in ["blackjack", "holdem"] or compose:
		composition.append(bet)
		bet = snappedf(bet + amount, 0.01)
	else: bet = amount
	if is_instance_valid(craps): craps.chip = bet
	notify_change()

func undo_staged() -> void:
	if locked() or sim.game_pending(current_table()): return
	if compose_trips:
		if not trips_composition.is_empty(): trips_bet = trips_composition.pop_back()
	elif not composition.is_empty(): bet = composition.pop_back()
	notify_change()

func reset_staged() -> void:
	if locked() or sim.game_pending(current_table()): return
	if compose_trips: trips_composition.clear(); trips_bet = 0
	else: composition.clear(); bet = 0
	notify_change()

func menu_action(id: int) -> void:
	var table := current_table()
	var kind := sim.table_kind(table)
	match id:
		0: open_rules(kind)
		1: show_details = not show_details
		2: fine_chips = not fine_chips; rack.configure(fine_chips and not sim.is_private)
		3: compose = not compose; composition.clear(); bet = 0 if compose else selected_chip
		4: undo_staged()
		5: reset_staged()
		6: if not locked(): sim.clear_roulette(sim.joined)
		7: show_wheel = not show_wheel; layout_play()
		8: if is_instance_valid(craps): craps.fit_view()
	if is_instance_valid(craps): craps.chip = bet
	notify_change()

func update_menu(kind: String, event: bool) -> void:
	var popup := menu_button.get_popup()
	popup.clear()
	popup.add_item("Rules / help", 0)
	popup.add_item("Close options" if show_details else "Wallet / bets / options", 1)
	if kind != "slots" and not event:
		if not sim.is_private: popup.add_item("Standard chips" if fine_chips else "Fine chips / cents", 2)
		if kind in ["craps", "roulette"]: popup.add_item("Select single chip" if compose else "Compose chip amount", 3)
		popup.add_item("Undo staged chip", 4)
		popup.add_item("Reset staged amount", 5)
		for id in [3, 4, 5]:
			var index := popup.get_item_index(id)
			if index >= 0: popup.set_item_disabled(index, sim.game_pending(current_table()) or locked())
		if kind == "roulette":
			popup.add_item("Clear unspun bets", 6)
			popup.set_item_disabled(popup.get_item_index(6), locked())
			popup.add_item("Show layout" if show_wheel else "Show wheel", 7)
		if kind == "craps": popup.add_item("Center felt", 8)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null or (sim.joined < 0 and sim.owner_play.is_empty()): return
	update_result_hold(delta)
	if art.kind in ["craps", "roulette"]: update_bet_indicator()
	if roulette_display_remaining > 0:
		roulette_display_remaining = maxf(0, roulette_display_remaining - delta)
		if roulette_display_remaining == 0: roulette_guests.clear()
	poll += delta
	if poll < 0.1: return
	poll = 0
	render_current()

func current_table() -> Dictionary:
	if sim == null: return {}
	return sim.get_table(sim.joined) if sim.owner_play.is_empty() else sim.owner_event_table()

func locked() -> bool:
	return paused or result_pending or result_hold > 0 or art.spinning > 0 or (is_instance_valid(craps) and craps.visible and craps.busy())

func notify_change() -> void:
	signature.clear()
	render_current()
	changed.emit()

func transact(start: bool, action: String = "") -> void:
	if locked(): return
	var slots := sim.table_kind(current_table()) == "slots"
	var previous_stops: Array = art.round.get("stops", [3,11,18])
	if slots:
		balance_before = Vector2(sim.owner_bankroll, sim.cash)
		art.spinning = 0.001 # Lock synchronously before any transaction callbacks.
	var ok := false
	if not sim.owner_play.is_empty():
		ok = sim.owner_event_action(action, rendered_sequence)
	else:
		ok = sim.start_game(sim.joined, bet, trips_bet, slot_lines) if start else sim.game_action(sim.joined, action)
	feedback = "" if ok else "Action unavailable. Check wallet, limits and coverage."
	if ok and sim.owner_play.is_empty(): player_round = sim.get_table(sim.joined).round
	if ok and sim.table_kind(current_table()) == "roulette":
		roulette_guests = sim.roulette_committed().duplicate(true)
		roulette_display_remaining = 2.8 + RESULT_HOLD_SECONDS
	if ok and current_table().round.get("phase") == "done": result_pending = true
	if slots:
		if ok:
			art.round = current_table().round if not sim.owner_play.is_empty() else player_round
			art.sponsored = not sim.owner_play.is_empty() and sim.owner_play.funding == "sponsor"
			art.begin_slot_reveal(previous_stops)
		else: art.spinning = 0
	elif ok: art.animate(2.8 if sim.table_kind(current_table()) == "roulette" else 0.2)
	notify_change()

func render_current() -> void:
	var table := current_table()
	if table.is_empty(): return
	var kind := sim.table_kind(table)
	art.kind = kind
	var event: bool = not sim.owner_play.is_empty()
	var id := -int(sim.owner_play.event_id) - 2 if event else sim.joined
	if current_id != id:
		current_id = id
		roulette_guests.clear()
		roulette_display_remaining = 0
		player_round = table.round if sim.is_private or (not event and (sim.game_pending(table) or kind == "slots")) else {}
		bet = float(sim.owner_play.base) if event else 0.0 if kind in ["blackjack", "holdem"] else selected_chip if kind != "slots" else minf(10, sim.owner_bankroll) if sim.is_private else float(table.minimum)
		composition.clear()
		fine_chips = false
		rack.configure(fine_chips and not sim.is_private)
		if is_instance_valid(craps): craps.chip = bet
		trips_bet = 0
		trips_composition.clear()
		compose_trips = false
		feedback = ""
		show_details = false
		show_wheel = size.x >= 1000
		show_rules = false
		art.reset_slot_presentation(table.round if event else player_round, event and sim.owner_play.funding == "sponsor")
		if event and sim.owner_play.funding == "sponsor": art.slot_audio.cue("free")
		slot_lines = 5 if event else int(player_round.get("active_lines", 1))
		selected_wager = "pass" if kind == "craps" else "Red"
		layout_play()
	var pending := sim.game_pending(table)
	var seats := sim.seated(sim.joined).map(func(guest): return {"id": guest.id, "seat": guest.seat, "name": guest.name}) if not event else []
	var next := [seats, roulette_guests, id, table.round, table.roulette_bets, table.owner, table.dice, table.point, table.shooter, table.owner_queued, table.betting_hold, sim.owner_bankroll, sim.cash, paused, bet, trips_bet, compose_trips, feedback, show_details, show_wheel, event, sim.owner_play.get("sequence", -1), sim.owner_play.get("status", ""), art.spinning > 0, result_hold > 0, result_pending, craps.pan_mode if is_instance_valid(craps) else false, craps.chip if is_instance_valid(craps) else 0, craps.dice_ready if is_instance_valid(craps) else false, craps.busy() if is_instance_valid(craps) else false, selected_wager, size, slot_lines, snappedf(art.slot_reveal_fraction(), 0.05), art.can_skip_slot_reveal()]
	if next == signature: return
	signature = next.duplicate(true)
	if kind == "roulette": layout_play()
	var balances := Vector2(sim.owner_bankroll, sim.cash)
	if kind == "slots" and art.spinning > 0:
		balances = balance_before.lerp(balances, art.slot_reveal_fraction())
	wallet.text = "PERSONAL WALLET" if wallet_value.visible else "PERSONAL WALLET " + FinancialText.cash(balances.x, 2)
	wallet_value.text = FinancialText.cash(balances.x, 2)
	casino_cash.text = "CASINO CASH " + FinancialText.cash(balances.y, 2)
	game_title.text = ("PIT BOSS / " if compact else "") + (str(sim.optional_events.DEFINITIONS[sim.owner_play.type].title) if event else Games.NAMES[kind].replace("’", "'") + " #%d" % table.id)
	game_title.clip_text = true
	pause_button.text = ">" if paused else "II"
	pause_button.tooltip_text = "Resume" if paused else "Pause"
	return_button.disabled = result_pending or result_hold > 0 or art.spinning > 0 or (pending and not event and not sim.is_private) or (kind == "craps" and craps.busy())
	return_button.tooltip_text = "Return to Back Room" if sim.is_private else "Finish this hand before leaving" if pending and not event else "Return to Floor"
	art.kind = kind
	art.z_index = 9 if kind == "slots" else 3 if kind == "roulette" else 0
	slot_dimmer.visible = kind == "slots" and art.timeline.strong_result()
	art.round = table.round if event else player_round
	art.wager = bet
	art.staged_trips = trips_bet
	art.selecting_trips = compose_trips
	art.sponsored = event and sim.owner_play.funding == "sponsor"
	art.slot_lines = slot_lines
	art.free_remaining = int(sim.owner_play.rounds) - int(sim.owner_play.revealed) if event and sim.owner_play.funding == "sponsor" else -1
	art.pending = pending
	art.machine_profile = sim.slot_profile(table) if kind == "slots" else {}
	art.seated_players = seats
	var art_key := [kind, art.round, bet, trips_bet, compose_trips, art.size, seats]
	if art_key != surface_signature:
		surface_signature = art_key.duplicate(true)
		art.configure()
		var active_hand := int(art.round.get("active", -1)) if pending else -1
		if active_hand != last_active_hand and art.active_hand_rect.size.y > 0:
			last_active_hand = active_hand
			var hand_end: float = art.active_hand_rect.end.y
			if kind != "craps" and hand_end > surface_scroll.scroll_vertical + surface_scroll.size.y:
				surface_scroll.set_deferred("scroll_vertical", maxi(0, int(hand_end - surface_scroll.size.y + 16)))
	var roster_changed: bool = felt.seated_players != seats
	felt.seated_players = seats
	if roster_changed: felt.rebuild()
	felt.settled = art.spinning <= 0
	felt.guest_wagers = roulette_guests
	felt.bets = player_round.get("bets", {}) if art.spinning > 0 or result_pending or result_hold > 0 else table.roulette_bets
	felt.selected = bet
	felt.context = sim
	felt.minimum = table.minimum
	felt.wallet = sim.owner_bankroll
	felt.locked = locked() or not sim.ready_for_play(table) or event or show_rules or show_details
	felt.winning_number = int(player_round.get("number", -1)) if art.spinning <= 0 else -1
	var roulette_key := [felt.bets, seats, roulette_guests, felt.settled, bet, felt.minimum, felt.wallet, felt.locked, felt.winning_number]
	if roulette_key != roulette_signature:
		roulette_signature = roulette_key.duplicate(true)
		felt.queue_redraw()
	art.visible = kind != "craps" and (kind != "roulette" or show_wheel or art.spinning > 0)
	art.mouse_filter = MOUSE_FILTER_STOP if kind in ["roulette", "holdem"] else MOUSE_FILTER_IGNORE
	felt.visible = kind == "roulette"
	if is_instance_valid(craps): craps.visible = kind == "craps"
	rack.wallet = sim.owner_bankroll
	rack.locked = locked() or not sim.ready_for_play(table) or pending or event
	rack.amount = selected_chip
	rack.queue_redraw()
	update_menu(kind, event)
	options_panel.visible = show_details
	cursors.clear()
	cursors[slot_wager_row] = 0
	cursors[actions] = 0
	cursors[details] = 0
	actions.size_flags_horizontal = SIZE_EXPAND_FILL
	actions.maximum_columns = 2 if kind == "slots" else 3 if size.x < 600 else 6
	var disabled := locked() or not sim.ready_for_play(table)
	var amount := bet
	if kind == "roulette":
		amount = sum_bets(table.roulette_bets)
	elif kind == "craps": amount = CrapsRules.exposure(table.owner)
	elif pending: amount = float(table.round.get("staked", bet))
	wager_label.text = ("Event committed " + FinancialText.cash(float(sim.owner_play.staked), 0)) if event else ("On felt " if kind in ["roulette", "craps"] else "Wager ") + FinancialText.cash(amount, 2)
	wager_label.add_theme_font_size_override("font_size", 13 if kind == "slots" else 16)
	if kind == "slots":
		wager_label.text = "Min %s | Max %s" % [FinancialText.cash(float(table.minimum), 2), FinancialText.cash(sim.maximum_wager(table), 2)]
		render_slot_controls(table, event, disabled)
	elif event: render_event_actions(table)
	elif kind == "roulette":
		button("Spin", func(): transact(true), actions, disabled or amount <= 0, true)
	elif kind == "craps": render_craps_actions(table, disabled)
	elif pending:
		for action in Games.actions(table.round, sim.owner_bankroll):
			button(action, func(): transact(false, action), actions, disabled, action in ["Hit", "Stand"])
	else:
		button("Deal", func(): transact(true), actions, disabled or bet < table.minimum or bet > sim.maximum_wager(table) or trips_bet > sim.maximum_wager(table) or (sim.is_private and trips_bet > 0 and trips_bet < table.minimum) or sim.owner_bankroll < (bet * 6 + trips_bet if kind == "holdem" else bet), true)
		if kind == "holdem":
			button("Ante" if compose_trips else "Trips", func(): compose_trips = not compose_trips; notify_change(), actions, disabled).tooltip_text = "Choose where rack chips go: Ante (Blind matches) or optional Trips"
	if not event and not pending and kind in ["blackjack", "holdem"]:
		button("Undo", undo_staged, actions, trips_composition.is_empty() if compose_trips else composition.is_empty())
		button("Reset", reset_staged, actions, (trips_bet if compose_trips else bet) <= 0)
	if kind in ["blackjack", "holdem"] and not seats.is_empty() and not pending:
		button("Seats", func(): show_details = not show_details; notify_change(), actions)
	slot_spin.visible = kind == "slots"
	slot_wager_row.visible = kind == "slots" and not event
	wager_label.visible = kind != "slots" or not event
	result_label.visible = not feedback.is_empty()
	if kind == "holdem" and not pending:
		wager_label.text = "Deal %s | Wallet needs %s" % [FinancialText.cash(bet * 2 + trips_bet, 2), FinancialText.cash(bet * 6 + trips_bet, 2)]
	elif kind in ["blackjack", "holdem", "roulette"] and not player_round.is_empty():
		wager_label.text += " | " + result_text(table, event)
	wager_label.tooltip_text = result_text(table, event)
	if kind in ["craps", "roulette"]: wager_label.text += " | Chip " + FinancialText.cash(bet, 2)
	wager_label.clip_text = true
	result_label.text = result_text(table, event)
	result_label.add_theme_color_override("font_color", result_color(table, event))
	if show_details:
		render_details(table, event, disabled)
		var balances_label: Label = retained(details, "label", func(): return make_label(details, "", 14))
		balances_label.text = casino_cash.text + "\nMin " + FinancialText.cash(table.minimum, 2) + " / Max " + FinancialText.cash(sim.maximum_wager(table), 2)
	finish_controls()
	update_bet_indicator()
	update_audio_icon()

static func sum_bets(bets: Dictionary) -> float:
	var amount := 0.0
	for value in bets.values(): amount += float(value)
	return amount

func slot_steps() -> Array:
	var table := current_table()
	var ceiling := minf(sim.owner_bankroll, sim.maximum_wager(table))
	if sim.is_private: return SLOT_STEPS.filter(func(value): return value <= ceiling)
	var unit := float(sim.slot_profile(table).denominations.front())
	var steps: Array = [int(unit)]
	for value in SLOT_STEPS:
		if value > unit and is_equal_approx(fmod(float(value), unit), 0.0): steps.append(value)
	return steps.filter(func(value): return value <= ceiling)

func cycle_slot_step() -> void:
	if locked(): return
	var steps := slot_steps()
	if steps.is_empty(): return
	slot_step = float(steps[(steps.find(int(slot_step)) + 1) % steps.size()])
	notify_change()

func change_slot_bet(direction: int) -> void:
	if locked(): return
	var table := current_table()
	var ceiling := minf(sim.owner_bankroll, sim.maximum_wager(table))
	if ceiling < float(table.minimum): return
	if not sim.is_private:
		var unit := float(sim.slot_profile(table).denominations.front())
		ceiling = float(table.minimum) + floorf((ceiling - float(table.minimum)) / unit) * unit
	bet = clampf(bet + direction * slot_step, float(table.minimum), ceiling)
	notify_change()

func update_result_hold(delta: float) -> void:
	if not paused: result_hold = maxf(0, result_hold - delta)
	if result_pending and (art.timeline.revealed if art.kind == "slots" else art.spinning <= 0):
		result_pending = false
		result_hold = RESULT_HOLD_SECONDS

func update_bet_indicator() -> void:
	if sim == null: return
	var kind: String = art.kind
	var preview: String = craps.preview_caption() if kind == "craps" and is_instance_valid(craps) else felt.preview_caption() if kind == "roulette" else ""
	bet_indicator.text = preview if not preview.is_empty() else ("BET " + FinancialText.cash(bet, 2) if kind == "slots" else wager_label.text.get_slice(" | ", 0))
	bet_indicator.tooltip_text = bet_indicator.text

func toggle_audio() -> void:
	art.slot_audio.volume = 0.65 if art.slot_audio.volume == 0 else 0.0
	if art.slot_audio.volume == 0: art.slot_audio.player.stop()
	update_audio_icon()

func update_audio_icon() -> void:
	var enabled: bool = art.slot_audio.volume > 0
	audio_button.icon = PitBoss.texture("casino_play/shared/ui/music_on.svg" if enabled else "casino_play/shared/ui/music_off.svg")
	audio_button.tooltip_text = "Game audio on" if enabled else "Game audio off"

func render_craps_actions(table: Dictionary, disabled: bool) -> void:
	if int(table.shooter) == 0:
		button("Dice", func(): craps_action_requested.emit("shoot"), actions, disabled or not craps.can_throw(), true)
	else:
		button("Resume rolls" if table.betting_hold else "Hold rolls", func(): craps_action_requested.emit("shoot"), actions, disabled)
	if show_details and not sim.is_private: button("Pass dice" if table.shooter == 0 else "Skip turn" if table.owner_queued else "Queue dice", func(): craps_action_requested.emit("pass"), details, craps.busy())
	if not show_details: return
	button("Working ON" if table.owner_working else "Working OFF", func():
		if sim.is_private: sim.working()
		else: table.owner_working = not table.owner_working
		notify_change(), details, disabled)
	button("Take down", func(): sim.reclaim(sim.joined); notify_change(), details, disabled or CrapsRules.exposure(table.owner) <= 0)

func render_event_actions(table: Dictionary) -> void:
	var session: Dictionary = sim.owner_play
	rendered_sequence = int(session.sequence)
	if session.status != "playing": return
	if session.kind == "slots":
		button("Spin %d/%d" % [int(session.revealed) + 1, session.rounds], func(): transact(false, "Spin"), actions, locked(), true)
	else:
		for action in Games.actions(table.round, sim.owner_bankroll):
			button(action, func(): transact(false, action), actions, locked(), true)

func render_details(table: Dictionary, event: bool, disabled: bool) -> void:
	var kind := sim.table_kind(table)
	button("Close options", func(): show_details = false; notify_change(), details)
	var summary: Label = retained(details, "label", func(): return make_label(details, "", 14))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary.text = casino_cash.text
	if event:
		summary.text = "Sponsored spins charge neither wallet. Promotional returns enter Casino Cash after each spin." if sim.owner_play.funding == "sponsor" else "Personal funds were committed before play. Only event net winnings transfer to Casino Cash. Leaving resolves the remaining committed play."
	elif kind in ["roulette", "craps"]:
		var options := Games.roulette_bets() if kind == "roulette" else CrapsRules.empty_bets()
		var picker: OptionButton = retained(details, "picker", func():
			var node := OptionButton.new()
			details.add_child(node)
			node.custom_minimum_size.y = 44
			node.get_popup().add_theme_font_size_override("font_size", 16)
			node.get_popup().add_theme_constant_override("v_separation", 26)
			node.get_popup().max_size = Vector2i(int(size.x - 24), int(size.y * 0.6))
			node.fit_to_longest_item = false
			node.clip_text = true
			return node)
		picker.clear()
		var index := 0
		for key in options:
			picker.add_item(key.replace("–", "-") if kind == "roulette" else CrapsRules.name_for(key))
			picker.set_item_metadata(index, key)
			if key == selected_wager: picker.select(index)
			index += 1
		for connection in picker.get_signal_connection_list("item_selected"): picker.disconnect("item_selected", connection.callable)
		picker.item_selected.connect(func(value: int): selected_wager = picker.get_item_metadata(value); notify_change())
		var error := sim.bet_error(sim.joined, selected_wager, bet) if kind == "craps" else ""
		var stake: float = sim.bet_amount(table, selected_wager, bet) if kind == "craps" else bet
		button("Add " + FinancialText.cash(stake, 2), func():
			if kind == "craps": sim.bet(sim.joined, selected_wager, bet)
			else: sim.roulette_bet(sim.joined, selected_wager, bet)
			notify_change(), details, disabled or not error.is_empty(), true)
		if kind == "craps":
			button("Remove selected", func(): sim.remove_bet(sim.joined, selected_wager); notify_change(), details, disabled or not CrapsRules.removable(selected_wager, int(table.point)) or float(table.owner.get(selected_wager, 0)) <= 0)
		var bets: Dictionary = table.roulette_bets if kind == "roulette" else table.owner
		var lines: PackedStringArray = []
		for key in bets:
			if float(bets[key]) <= 0: continue
			lines.append((key.replace("–", "-") if kind == "roulette" else CrapsRules.name_for(key)) + ": " + FinancialText.cash(float(bets[key]), 2))
		summary.text = ("Chip " + FinancialText.cash(bet, 2) + (" / Stake " + FinancialText.cash(stake, 2) if kind == "craps" else "")) + ("\n" + error if not error.is_empty() else "") + "\n" + "\n".join(lines)
	else:
		if kind in ["blackjack", "holdem"]:
			for guest in sim.seated(sim.joined):
				var npc: Dictionary = {}
				for participant in table.round.get("npcs", []):
					if int(participant.id) == int(guest.id): npc = participant
				var title: Label = retained(details, "label", func(): return make_label(details, "", 14))
				title.text = "Seat %d | %s | %s" % [int(guest.seat) + 1, guest.name, "Awaiting hand" if npc.is_empty() else FinancialText.cash(float(npc.staked), 2)]
				if npc.is_empty(): continue
				var cards: HBoxContainer = retained(details, "cards", func(): return HBoxContainer.new())
				for child in cards.get_children(): cards.remove_child(child); child.queue_free()
				for value in npc.cards:
					var card = preload("res://presentation/play/playing_card.gd").new()
					cards.add_child(card)
					card.custom_minimum_size = Vector2(42, 59)
					card.size_flags_horizontal = SIZE_EXPAND_FILL
					card.show_card(int(value), kind == "holdem" and table.round.get("phase", "") != "done")
		summary.text = ("Min %s / Max %s. Returns and winnings go to your personal wallet. Transfer funds to Casino Cash from the menu." if sim.is_private else "Min %s / Max %s. Personal wagers use the same table, dealer and casino treasury as other guests.") % [FinancialText.cash(table.minimum, 0), FinancialText.cash(sim.maximum_wager(table), 0)]

func result_text(table: Dictionary, event: bool) -> String:
	if feedback != "": return feedback
	if paused: return "PAUSED | Resume time to play."
	if sim.table_kind(table) == "slots":
		if art.spinning > 0 and not art.can_skip_slot_reveal(): return "Reels spinning..."
		var result: Dictionary = sim.owner_play.round if event else player_round
		if result.is_empty(): return "5 FREE SPINS ready" if event and sim.owner_play.funding == "sponsor" else "Choose your lines, then Spin."
		var info := SlotResult.describe(result,event and sim.owner_play.funding == "sponsor")
		return SlotResult.summary(info)
	if art.spinning > 0 or (sim.table_kind(table) == "craps" and craps.busy()): return "Revealing the result..."
	if event:
		var session: Dictionary = sim.owner_play
		if session.status == "done": return "%s | Personal %s | Casino %s" % [session.result.outcome, FinancialText.house_result(float(session.result.bankroll_change)), FinancialText.house_result(float(session.result.casino_profit))]
		return "%d/%d shown | %s" % [session.revealed, session.rounds, str(session.round.get("message", "Committed spins ready")).replace("·", "|")]
	var round: Dictionary = player_round
	if sim.table_kind(table) == "craps": return str(table.result).replace("·", "|").replace("’", "'") + (" | Place Pass / Don't Pass to shoot" if int(table.shooter) == 0 and not sim.shooter_has_line(table) else "")
	if round.is_empty(): return "Choose a wager. Personal funds and Casino Cash are separate."
	if round.phase != "done": return str(round.message).replace("·", "|").replace("×", "x")
	var net := float(round.credit) - float(round.get("staked", 0))
	var outcome := "Win" if net > 0 else "Push" if is_zero_approx(net) else "Loss"
	if sim.table_kind(table) == "blackjack":
		outcome = " / ".join(round.hands.map(func(hand_data): return Surface.hand_result(hand_data)))
	elif sim.table_kind(table) == "roulette": outcome = "%d %s" % [round.number, "GREEN" if int(round.number) == 0 else "RED" if int(round.number) in Games.RED else "BLACK"]
	if sim.is_private: return outcome + " | Personal " + FinancialText.house_result(net) + " | Returned " + FinancialText.cash(float(round.credit), 2)
	return outcome + " | Personal " + FinancialText.house_result(net) + " | Returned " + FinancialText.cash(float(round.credit), 0)

func result_color(table: Dictionary, event: bool) -> Color:
	if sim.table_kind(table) == "slots":
		if art.spinning > 0 and not art.can_skip_slot_reveal(): return PitBoss.TEXT
		var result: Dictionary = sim.owner_play.round if event else player_round
		var info := SlotResult.describe(result,event and sim.owner_play.funding == "sponsor")
		return Color("86d7ae") if info.positive else PitBoss.GOLD if int(info.level) == 1 else PitBoss.TEXT
	if event and sim.owner_play.status == "done": return Color("ef9486") if float(sim.owner_play.result.bankroll_change) < 0 else PitBoss.GOLD
	if not player_round.is_empty() and player_round.get("phase", "") == "done":
		var net := float(player_round.credit) - float(player_round.get("staked", 0))
		return Color("86d7ae") if net > 0 else Color("ef9486") if net < 0 else PitBoss.TEXT
	return PitBoss.TEXT

func rules_for(kind: String) -> String:
	match kind:
		"slots":
			var profile := sim.slot_profile(current_table())
			var metrics := CasinoTuning.slot_line_metrics(profile.id, slot_lines)
			return "SLOTS / TOTAL RETURN MULTIPLIERS\nCherries %dx | Lemons %dx | Bells %dx | BAR %dx | Sevens %dx.\nTwo cherries, or one on the first reel, return %dx per line (three matching symbols take priority).\n\n%d active lines / Total %s / Per line %s\nTotal wager is divided equally, never multiplied. Multiple winning lines pay together.\nRTP %.2f%% | House edge %.2f%%\n%s machine volatility | Return standard deviation %.3fx\nAny return %.2f%% | Any seven line %.3f%%\nMaximum combined return %.2fx total wager.\nAdjacent positions on physical reel strips form the three visible rows. Every spin is committed before animation." % [profile.pays[0],profile.pays[1],profile.pays[2],profile.pays[3],profile.pays[4],profile.cherry_return,slot_lines,FinancialText.cash(bet,2),FinancialText.cash(bet / slot_lines,3),metrics.rtp*100,(1-metrics.rtp)*100,profile.volatility,metrics.stddev,metrics.hit_probability*100,metrics.seven_probability*100,metrics.top_return]
		"roulette": return "SINGLE ZERO ROULETTE\n35:1 straight | 17:1 split | 11:1 street/trio | 8:1 corner/first four | 5:1 six line | 2:1 dozens/columns | 1:1 even-money. Zero loses outside bets.\nTap a number or inside seam. Bets / details exposes every supported wager with a large touch target. Clear bets returns all unstaked layout wagers."
		"blackjack": return "BLACKJACK\nSix decks shuffled each round | Blackjack 3:2 | Dealer stands on soft 17 and peeks.\nDouble any first two cards, including after split | Up to four hands | Split aces receive one card | Late surrender before splitting | Insurance 2:1.\nOnly currently legal actions appear. Finish the hand before returning to Floor."
		"craps": return "CRAPS\nTap the felt to place the selected chip. Use the chip rack; compose amounts or choose fine chips in the menu. Bets / details exposes every target.\nCome-out starts a Pass / Don't Pass contract. Come / Don't Come start after a point. Odds use established contracts.\nTake down returns removable bets; established contracts remain until resolved. Roll or hold/flick the dice when you are shooting. Queue dice joins the shooter rotation."
		_: return "ULTIMATE TEXAS HOLD'EM\nAnte + matching Blind. Preflop raise 3x/4x or check; flop raise 2x or check; river raise 1x or fold. Dealer qualifies with a pair.\nBlind pays straight 1:1, flush 3:2, full house 3:1, quads 10:1, straight flush 50:1, royal 500:1. Trips pays independently, even after folding: trips 3, straight 4, flush 7, full house 8, quads 30, straight flush 40, royal 50 to 1."

func retained(parent: Node, node_kind: String, create: Callable) -> Control:
	var index := int(cursors.get(parent, 0))
	cursors[parent] = index + 1
	if index < parent.get_child_count() and parent.get_child(index).get_meta("pit_kind", "") == node_kind: return parent.get_child(index)
	while parent.get_child_count() > index:
		var obsolete: Node = parent.get_child(index)
		parent.remove_child(obsolete)
		obsolete.queue_free()
	var item: Control = create.call()
	if item.get_parent() == null: parent.add_child(item)
	item.set_meta("pit_kind", node_kind)
	return item

func finish_controls() -> void:
	for parent in cursors:
		while parent.get_child_count() > int(cursors[parent]):
			var obsolete: Node = parent.get_child(int(cursors[parent]))
			parent.remove_child(obsolete)
			obsolete.queue_free()
	cursors.clear()

func open_rules(kind: String) -> void:
	show_rules = true
	line_diagrams.visible = kind == "slots"
	line_diagrams.active_lines = slot_lines
	line_diagrams.queue_redraw()
	rules_text.text = rules_for(kind)
	rules.show()

func render_slot_controls(table: Dictionary, event: bool, disabled: bool) -> void:
	var session: Dictionary = sim.owner_play
	slot_spin.text = "SKIP" if art.can_skip_slot_reveal() else "SPIN" if not event else "FREE SPIN" if session.funding == "sponsor" else "SPIN %d/%d" % [int(session.revealed)+1,session.rounds]
	slot_spin.disabled = paused or result_pending or result_hold > 0 if art.can_skip_slot_reveal() else locked() or (session.status != "playing" if event else disabled or bet > sim.owner_bankroll)
	if event: rendered_sequence = int(session.sequence)
	var steps := slot_steps()
	if not steps.is_empty() and not steps.has(int(slot_step)): slot_step = float(steps[0])
	if not event:
		button("- %s" % FinancialText.cash(slot_step, 0), func(): change_slot_bet(-1), slot_wager_row, disabled or bet - slot_step < float(table.minimum))
		var amount_button := button("BET %s" % FinancialText.cash(bet, 0), func(): pass, slot_wager_row)
		amount_button.focus_mode = Control.FOCUS_NONE
		amount_button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button("+ %s" % FinancialText.cash(slot_step, 0), func(): change_slot_bet(1), slot_wager_row, disabled or bet + slot_step > minf(sim.owner_bankroll, sim.maximum_wager(table)))
		for item in slot_wager_row.get_children():
			item.add_theme_font_size_override("font_size", 12)
			item.size_flags_horizontal = SIZE_EXPAND_FILL
	button("$$", cycle_slot_step, actions, disabled or event or steps.size() < 2).tooltip_text = "Cycle the affordable wager increment. Paytable is in Rules / help."
	button("LINES %d" % slot_lines, func():
		slot_lines = CasinoTuning.SLOT_LINE_COUNTS[(CasinoTuning.SLOT_LINE_COUNTS.find(slot_lines)+1)%3]
		notify_change(), actions, locked() or event).tooltip_text = "Choose 1 / 3 / 5 paylines; total bet stays the same."

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or sim == null or not event is InputEventKey or not event.pressed or event.echo: return
	if event.keycode not in [KEY_SPACE, KEY_ENTER] or current_table().is_empty() or sim.table_kind(current_table()) != "slots": return
	if show_rules or get_viewport().gui_get_focus_owner() != null: return
	get_viewport().set_input_as_handled()
	if not slot_spin.disabled: slot_spin.pressed.emit()

func press_slot_spin() -> void:
	update_result_hold(0)
	if paused or result_pending or result_hold > 0: return
	# First tap acknowledges an already revealed result; never starts another wager.
	if art.skip_slot_reveal():
		notify_change()
		return
	if not sim.owner_play.is_empty(): transact(false,"Spin")
	else: transact(true)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0d241b"))
