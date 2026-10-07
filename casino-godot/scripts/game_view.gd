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
const Surface = preload("res://scripts/casino_surface.gd")
const RouletteLayout = preload("res://scripts/roulette_layout.gd")
var sim: CasinoSimulation:
	set(value):
		if sim == value: return
		sim = value
		current_id = -1
		player_round = {}
		signature.clear()
		surface_signature.clear()
var paused := false
var bet := 10.0
var trips := false
var art: Control
var felt: Control
var craps: Control
var mobile_header_skin: StyleBoxTexture
var header: Panel
var brand: Label
var wallet: Label
var wallet_value: Label
var casino_cash: Label
var game_title: Label
var return_button: Button
var pause_button: Button
var surface_scroll: ScrollContainer
var stage: BoxContainer
var controls_scroll: ScrollContainer
var controls: VBoxContainer
var result_label: Label
var wager_label: Label
var chips: HBoxContainer
var actions: GridContainer
var details: VBoxContainer
var rules: PanelContainer
var rules_text: Label
var player_round: Dictionary = {}
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
var last_active_hand := -1
var poll := 0.0
var compact := false
var landscape := false

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	mobile_header_skin = StyleBoxTexture.new()
	var chrome := AtlasTexture.new()
	chrome.atlas = PitBoss.texture("casino_play/mobile/mobile_play_chrome.svg")
	chrome.region = Rect2(20, 20, 1040, 118)
	mobile_header_skin.texture = chrome
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]: mobile_header_skin.set_texture_margin(side, 26)
	header = Panel.new()
	header.add_theme_stylebox_override("panel", PitBoss.box(Color("101315"), PitBoss.GOLD, 0))
	add_child(header)
	brand = make_label(header, "PIT BOSS", 22, PitBoss.GOLD)
	wallet = make_label(header, "", 17)
	wallet_value = make_label(header, "", 18)
	casino_cash = make_label(header, "", 13, PitBoss.MUTED)
	game_title = make_label(header, "", 14, PitBoss.GOLD)
	return_button = make_button(header, "Floor", func(): leave_requested.emit())
	return_button.tooltip_text = "Return to Floor"
	pause_button = make_button(header, "Pause", func(): pause_requested.emit())
	surface_scroll = ScrollContainer.new()
	surface_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	add_child(surface_scroll)
	stage = BoxContainer.new()
	stage.vertical = true
	stage.size_flags_horizontal = SIZE_EXPAND_FILL
	stage.size_flags_vertical = SIZE_EXPAND_FILL
	surface_scroll.add_child(stage)
	art = Surface.new()
	art.size_flags_horizontal = SIZE_EXPAND_FILL
	art.size_flags_vertical = SIZE_EXPAND_FILL
	stage.add_child(art)
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
	controls = VBoxContainer.new()
	controls.size_flags_horizontal = SIZE_EXPAND_FILL
	controls.add_theme_constant_override("separation", 6)
	controls_scroll.add_child(controls)
	wager_label = make_label(controls, "", 16)
	var chip_scroll := ScrollContainer.new()
	chip_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chip_scroll.custom_minimum_size.y = 52
	controls.add_child(chip_scroll)
	chips = HBoxContainer.new()
	chips.add_theme_constant_override("separation", 4)
	chip_scroll.add_child(chips)
	actions = preload("res://scripts/responsive_grid.gd").new()
	actions.maximum_columns = 3
	actions.add_theme_constant_override("h_separation", 6)
	actions.add_theme_constant_override("v_separation", 6)
	controls.add_child(actions)
	result_label = make_label(controls, "", 16)
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details = VBoxContainer.new()
	details.add_theme_constant_override("separation", 6)
	controls.add_child(details)
	rules = PanelContainer.new()
	rules.add_theme_stylebox_override("panel", PitBoss.box(Color("101315"), PitBoss.GOLD, 12))
	add_child(rules)
	var rules_stack := VBoxContainer.new()
	rules.add_child(rules_stack)
	make_button(rules_stack, "Close rules", func(): show_rules = false; rules.hide())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	rules_stack.add_child(scroll)
	rules_text = make_label(scroll, "", 16)
	rules_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rules.hide()
	resized.connect(layout_play)
	layout_play()

func attach_craps(surface: Control) -> void:
	craps = surface
	craps.reparent(stage)
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
	item.disabled = disabled
	for connection in item.get_signal_connection_list("pressed"): item.disconnect("pressed", connection.callable)
	item.pressed.connect(callback)
	var skin := StyleBoxTexture.new()
	skin.texture = PitBoss.texture("casino_play/shared/ui/action_primary.svg" if primary else "casino_play/shared/ui/action_secondary.svg")
	for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 16)
		skin.set_content_margin(side, 8)
	item.add_theme_stylebox_override("normal", skin)
	return item

static func put(node: Control, position_value: Vector2, extent: Vector2) -> void:
	node.position = position_value
	node.size = extent

func layout_play() -> void:
	if not is_node_ready(): return
	compact = size.x < 1000
	landscape = size.x > size.y and size.y < 600
	var top := 94.0 if compact and not landscape else 78.0 if landscape else 70.0
	header.add_theme_stylebox_override("panel", mobile_header_skin if compact and not landscape else PitBoss.box(Color("101315"), PitBoss.GOLD, 0))
	put(header, Vector2(8, 8), Vector2(size.x - 16, top - 12))
	brand.visible = not compact
	put(brand, Vector2(12, 10), Vector2(150, 44))
	wallet_value.visible = compact and not landscape
	wallet.add_theme_font_size_override("font_size", 10 if wallet_value.visible else 17)
	put(wallet, Vector2(10 if compact else 170, 5), Vector2(maxf(120, size.x - 200) if compact else 230, 24))
	put(wallet_value, Vector2(10, 20), Vector2(maxf(120, size.x - 200), 24))
	put(casino_cash, Vector2(10 if compact else 420, 44 if compact and not landscape else 32 if landscape else 7), Vector2(maxf(140, size.x - 180) if compact else 220, 20))
	put(game_title, Vector2(200 if landscape else 10 if compact else 420, 62 if compact and not landscape else 32), Vector2(size.x - 36 if compact else 260, 18))
	return_button.text = "Floor" if compact else "Return to Floor"
	put(return_button, Vector2(header.size.x - (80 if compact else 146), 5), Vector2(72 if compact else 138, 44))
	put(pause_button, Vector2(header.size.x - (144 if compact else 210), 5), Vector2(58, 44))
	pause_button.add_theme_font_size_override("font_size", 12)
	if landscape:
		put(surface_scroll, Vector2(8, top), Vector2(maxf(180, size.x - 236), size.y - top - 8))
		put(controls_scroll, Vector2(size.x - 220, top), Vector2(212, size.y - top - 8))
	else:
		var footer := 210.0 if size.x >= 1000 else 208.0
		put(surface_scroll, Vector2(8, top), Vector2(size.x - 16, maxf(130, size.y - top - footer - 12)))
		put(controls_scroll, Vector2(12, size.y - footer - 8), Vector2(size.x - 24, footer))
	stage.vertical = art.kind != "roulette" or size.x < 1000
	art.custom_minimum_size.x = 0 if stage.vertical else clampf(size.x * 0.32, 280, 450)
	art.size_flags_horizontal = SIZE_EXPAND_FILL if stage.vertical else SIZE_FILL
	felt.vertical_layout = not landscape and size.x < 1000
	felt.rebuild()
	put(rules, Vector2(12, top + 8), Vector2(size.x - 24, size.y - top - 20))
	art.configure()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null or (sim.joined < 0 and sim.owner_play.is_empty()): return
	poll += delta
	if poll < 0.1: return
	poll = 0
	render_current()

func current_table() -> Dictionary:
	return sim.get_table(sim.joined) if sim.owner_play.is_empty() else sim.owner_event_table()

func locked() -> bool:
	return paused or art.spinning > 0 or (is_instance_valid(craps) and craps.visible and craps.busy())

func notify_change() -> void:
	signature.clear()
	render_current()
	changed.emit()

func transact(start: bool, action: String = "") -> void:
	if locked(): return
	var ok := false
	if not sim.owner_play.is_empty():
		ok = sim.owner_event_action(action, rendered_sequence)
	else:
		ok = sim.start_game(sim.joined, bet, bet if trips else 0) if start else sim.game_action(sim.joined, action)
	feedback = "" if ok else "Action unavailable. Check wallet, limits and coverage."
	if ok and sim.owner_play.is_empty(): player_round = sim.get_table(sim.joined).round
	if ok: art.animate(0.9 if sim.table_kind(current_table()) in ["slots", "roulette"] else 0.2)
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
		player_round = table.round if not event and sim.game_pending(table) else {}
		bet = float(sim.owner_play.base) if event else float(table.minimum)
		trips = false
		feedback = ""
		show_details = false
		show_wheel = false
		show_rules = false
		art.spinning = 0
		selected_wager = "pass" if kind == "craps" else "Red"
		layout_play()
	var pending := sim.game_pending(table)
	var next := [id, table.round, table.roulette_bets, table.owner, table.dice, table.point, table.shooter, table.owner_queued, table.betting_hold, sim.owner_bankroll, sim.cash, paused, bet, trips, feedback, show_details, show_wheel, event, sim.owner_play.get("sequence", -1), sim.owner_play.get("status", ""), art.spinning > 0, craps.dice_ready if is_instance_valid(craps) else false, craps.busy() if is_instance_valid(craps) else false, selected_wager, size]
	if next == signature: return
	signature = next.duplicate(true)
	wallet.text = "PERSONAL WALLET" if wallet_value.visible else "PERSONAL WALLET " + FinancialText.cash(sim.owner_bankroll, 0)
	wallet_value.text = preload("res://presentation/mobile_management.gd").short_money(sim.owner_bankroll)
	casino_cash.text = "CASINO CASH " + preload("res://presentation/mobile_management.gd").short_money(sim.cash)
	game_title.text = ("PIT BOSS / " if compact else "") + (str(sim.optional_events.DEFINITIONS[sim.owner_play.type].title) if event else Games.NAMES[kind].replace("’", "'") + " #%d" % table.id)
	game_title.clip_text = true
	pause_button.text = "Resume" if paused else "Pause"
	return_button.disabled = (pending and not event) or (kind == "craps" and craps.busy())
	return_button.tooltip_text = "Finish this hand before leaving" if pending and not event else "Return to Floor"
	art.kind = kind
	art.round = table.round if event else player_round
	art.wager = bet
	art.pending = pending
	art.machine_profile = sim.slot_profile(table) if kind == "slots" else {}
	var art_key := [kind, art.round, bet, art.size]
	if art_key != surface_signature:
		surface_signature = art_key.duplicate(true)
		art.configure()
		var active_hand := int(art.round.get("active", -1)) if pending else -1
		if active_hand != last_active_hand and art.active_hand_rect.size.y > 0:
			last_active_hand = active_hand
			var hand_end: float = art.active_hand_rect.end.y
			if hand_end > surface_scroll.scroll_vertical + surface_scroll.size.y:
				surface_scroll.set_deferred("scroll_vertical", maxi(0, int(hand_end - surface_scroll.size.y + 16)))
	felt.bets = player_round.get("bets", {}) if art.spinning > 0 else table.roulette_bets
	felt.selected = bet
	felt.minimum = table.minimum
	felt.wallet = sim.owner_bankroll
	felt.locked = locked() or not sim.ready_for_play(table) or event
	felt.winning_number = int(player_round.get("number", -1)) if art.spinning <= 0 else -1
	felt.queue_redraw()
	art.visible = kind != "craps" and (kind != "roulette" or size.x >= 1000 or show_wheel or art.spinning > 0)
	felt.visible = kind == "roulette" and (size.x >= 1000 or (not show_wheel and art.spinning <= 0))
	if is_instance_valid(craps): craps.visible = kind == "craps"
	cursors.clear()
	cursors[chips] = 0
	cursors[actions] = 0
	cursors[details] = 0
	var disabled := locked() or not sim.ready_for_play(table)
	var amount := bet
	if kind == "roulette":
		amount = sum_bets(table.roulette_bets)
	elif kind == "craps": amount = CrapsRules.exposure(table.owner)
	elif pending: amount = float(table.round.get("staked", bet))
	wager_label.text = ("Event committed " + FinancialText.cash(float(sim.owner_play.staked), 0)) if event else ("On felt " if kind in ["roulette", "craps"] else "Wager ") + FinancialText.cash(amount, 0)
	chips.get_parent().visible = not event and kind != "slots" and not pending
	if chips.get_parent().visible:
		for denomination in [1, 5, 25, 100, 500, 1000]:
			var chip_button := button("$%d" % denomination, func():
				bet = denomination
				if kind == "craps":
					craps.chip = bet
					craps_action_requested.emit("chip:%d" % denomination)
				notify_change(), chips, disabled or denomination < table.minimum or denomination > sim.maximum_wager(table) or denomination > sim.owner_bankroll)
			chip_button.icon = PitBoss.texture("casino_play/shared/chips/chip_%d.svg" % denomination)
			chip_button.expand_icon = true
			chip_button.add_theme_constant_override("icon_max_width", 32)
			chip_button.custom_minimum_size = Vector2(84, 48)
			chip_button.toggle_mode = true
			chip_button.button_pressed = bet == denomination
	if event: render_event_actions(table)
	elif kind == "slots":
		button("Bet -", func(): change_slot_bet(-1), actions, disabled or bet <= table.minimum)
		button("Bet +", func(): change_slot_bet(1), actions, disabled or bet >= sim.maximum_wager(table))
		button("Spin", func(): transact(true), actions, disabled or bet > sim.owner_bankroll, true)
		button("Max Bet", func(): bet = sim.maximum_wager(table); notify_change(), actions, disabled or sim.owner_bankroll < sim.maximum_wager(table))
	elif kind == "roulette":
		button("Spin", func(): transact(true), actions, disabled or amount <= 0, true)
		button("Clear bets", func(): sim.clear_roulette(sim.joined); notify_change(), actions, disabled or amount <= 0)
		button("Layout" if show_wheel else "Wheel", func(): show_wheel = not show_wheel; notify_change(), actions, art.spinning > 0)
	elif kind == "craps": render_craps_actions(table, disabled)
	elif pending:
		for action in Games.actions(table.round, sim.owner_bankroll):
			button(action, func(): transact(false, action), actions, disabled, action in ["Hit", "Stand"])
	else:
		button("Bet -", func(): bet = maxf(table.minimum, bet - table.minimum); notify_change(), actions, disabled or bet <= table.minimum)
		button("Bet +", func(): bet = minf(sim.maximum_wager(table), bet + table.minimum); notify_change(), actions, disabled or bet >= sim.maximum_wager(table))
		button("Deal", func(): transact(true), actions, disabled or sim.owner_bankroll < (bet * (7 if trips else 6) if kind == "holdem" else bet), true)
		if kind == "holdem": button("Trips " + ("On" if trips else "Off"), func(): trips = not trips; notify_change(), actions, disabled)
	button("Less" if show_details else "Bets / details", func(): show_details = not show_details; notify_change(), actions)
	button("Rules", func(): show_rules = true; rules.show(); rules_text.text = rules_for(kind))
	result_label.text = result_text(table, event)
	result_label.add_theme_color_override("font_color", result_color(table, event))
	if show_details: render_details(table, event, disabled)
	finish_controls()

static func sum_bets(bets: Dictionary) -> float:
	var amount := 0.0
	for value in bets.values(): amount += float(value)
	return amount

func change_slot_bet(direction: int) -> void:
	var table := current_table()
	var denominations: Array = sim.slot_profile(table).denominations.filter(func(value): return value >= table.minimum and value <= sim.maximum_wager(table))
	if denominations.is_empty(): return
	var index := denominations.find(bet)
	bet = float(denominations[clampi(index + direction, 0, denominations.size() - 1)])
	notify_change()

func render_craps_actions(table: Dictionary, disabled: bool) -> void:
	if int(table.shooter) == 0:
		button("Roll", func(): craps_action_requested.emit("shoot"), actions, disabled or not craps.can_throw(), true)
	else:
		button("Resume rolls" if table.betting_hold else "Hold rolls", func(): craps_action_requested.emit("shoot"), actions, disabled)
	button("Pass dice" if table.shooter == 0 else "Skip turn" if table.owner_queued else "Queue dice", func(): craps_action_requested.emit("pass"), actions, craps.busy())
	button("Take down", func(): sim.reclaim(sim.joined); notify_change(), actions, disabled or CrapsRules.exposure(table.owner) <= 0)

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
	var summary: Label = retained(details, "label", func(): return make_label(details, "", 14))
	summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if event:
		summary.text = "Personal funds were committed before play. Only event net winnings transfer to Casino Cash. Leaving resolves the remaining committed play."
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
		button("Add " + FinancialText.cash(stake, 0), func():
			if kind == "craps": sim.bet(sim.joined, selected_wager, bet)
			else: sim.roulette_bet(sim.joined, selected_wager, bet)
			notify_change(), details, disabled or not error.is_empty(), true)
		if kind == "craps":
			button("Remove selected", func(): sim.remove_bet(sim.joined, selected_wager); notify_change(), details, disabled or not CrapsRules.removable(selected_wager, int(table.point)) or float(table.owner.get(selected_wager, 0)) <= 0)
		var bets: Dictionary = table.roulette_bets if kind == "roulette" else table.owner
		var lines: PackedStringArray = []
		for key in bets:
			if float(bets[key]) <= 0: continue
			lines.append((key.replace("–", "-") if kind == "roulette" else CrapsRules.name_for(key)) + ": " + FinancialText.cash(float(bets[key]), 0))
		summary.text = ("Chip " + FinancialText.cash(bet, 0) + (" / Stake " + FinancialText.cash(stake, 0) if kind == "craps" else "")) + ("\n" + error if not error.is_empty() else "") + "\n" + "\n".join(lines)
	else:
		summary.text = "Min %s / Max %s. Personal wagers use the same table, dealer and casino treasury as other guests." % [FinancialText.cash(table.minimum, 0), FinancialText.cash(sim.maximum_wager(table), 0)]

func result_text(table: Dictionary, event: bool) -> String:
	if feedback != "": return feedback
	if paused: return "PAUSED | Resume time to play."
	if art.spinning > 0 or (sim.table_kind(table) == "craps" and craps.busy()): return "Revealing the table result..."
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
	if sim.table_kind(table) == "slots" and round.reels == [4, 4, 4]: outcome = "TOP AWARD"
	if sim.table_kind(table) == "blackjack":
		outcome = " / ".join(round.hands.map(func(hand_data): return Surface.hand_result(hand_data)))
	elif sim.table_kind(table) == "roulette": outcome = "%d %s" % [round.number, "GREEN" if int(round.number) == 0 else "RED" if int(round.number) in Games.RED else "BLACK"]
	return outcome + " | Personal " + FinancialText.house_result(net) + " | Returned " + FinancialText.cash(float(round.credit), 0)

func result_color(table: Dictionary, event: bool) -> Color:
	if event and sim.owner_play.status == "done": return Color("ef9486") if float(sim.owner_play.result.bankroll_change) < 0 else PitBoss.GOLD
	if not player_round.is_empty() and player_round.get("phase", "") == "done":
		var net := float(player_round.credit) - float(player_round.get("staked", 0))
		return Color("86d7ae") if net > 0 else Color("ef9486") if net < 0 else PitBoss.TEXT
	return PitBoss.TEXT

func rules_for(kind: String) -> String:
	match kind:
		"slots":
			var profile := sim.slot_profile(current_table())
			return "SLOTS / TOTAL RETURN\nCherries %dx | Lemons %dx | Bells %dx | BAR %dx | Sevens %dx. Two cherries, or one on the first reel, return %dx.\nRTP %.2f%% | House edge %.2f%%\n%s volatility | Top award chance %.2f%%" % [profile.pays[0], profile.pays[1], profile.pays[2], profile.pays[3], profile.pays[4], profile.cherry_return, profile.rtp * 100, profile.house_edge * 100, profile.volatility, profile.jackpot_probability * 100]
		"roulette": return "SINGLE ZERO ROULETTE\n35:1 straight | 17:1 split | 11:1 street/trio | 8:1 corner/first four | 5:1 six line | 2:1 dozens/columns | 1:1 even-money. Zero loses outside bets.\nTap a number or inside seam. Bets / details exposes every supported wager with a large touch target. Clear bets returns all unstaked layout wagers."
		"blackjack": return "BLACKJACK\nSix decks shuffled each round | Blackjack 3:2 | Dealer stands on soft 17 and peeks.\nDouble any first two cards, including after split | Up to four hands | Split aces receive one card | Late surrender before splitting | Insurance 2:1.\nOnly currently legal actions appear. Finish the hand before returning to Floor."
		"craps": return "CRAPS\nTap the felt to place the selected chip. More supported wagers and exact amounts are in Bets / details.\nCome-out starts a Pass / Don't Pass contract. Come / Don't Come start after a point. Odds use established contracts.\nTake down returns removable bets; established contracts remain until resolved. Roll or hold/flick the dice when you are shooting. Queue dice joins the shooter rotation."
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
