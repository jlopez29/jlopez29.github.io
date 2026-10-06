extends Control
signal leave_requested
signal changed
signal pause_requested
const FinancialText = preload("res://scripts/financial_text.gd")
const Games = preload("res://scripts/casino_games.gd")
const RouletteLayout = preload("res://scripts/roulette_layout.gd")
const Art = preload("res://scripts/casino_surface.gd")
var sim: CasinoSimulation
var paused := false
var bet := 10.0
var trips := false
var art: Control
var stage: BoxContainer
var content: VBoxContainer
var signature: Array = []
var current_id := -1
var player_round: Dictionary = {}
var felt: Control
var feedback := ""
var show_rules := false
var controls: VBoxContainer

func _ready() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 12)
	scroll.add_child(content)
	stage = BoxContainer.new()
	stage.vertical = true
	stage.add_theme_constant_override("separation", 12)
	content.add_child(stage)
	art = Art.new()
	stage.add_child(art)
	art.command.connect(func(action: String):
		match action:
			"Deal", "Spin": transact(true)
			"Bet":
				var table := sim.get_table(sim.joined)
				var denominations: Array = sim.slot_profile(table).denominations
				bet = maxf(float(denominations[(denominations.find(bet) + 1) % denominations.size()]), float(table.minimum))
			"Max": bet = sim.maximum_wager(sim.get_table(sim.joined)); transact(true)
			"Clear": bet = sim.get_table(sim.joined).minimum; trips = false
			_: transact(false,action)
	)
	art.chip_added.connect(func(spot: String, amount: float):
		if spot == "Trips": trips = not trips
		elif spot != "Play": bet += amount
		feedback = "Trips matches your Ante; tap again to remove." if spot == "Trips" else ""
		changed.emit())
	felt = RouletteLayout.new()
	felt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(felt)
	felt.wager_requested.connect(func(name: String, amount: float):
		if not paused and art.spinning <= 0:
			feedback = "" if sim.roulette_bet(sim.joined, name, amount) else "Not enough funds or table unavailable."
			changed.emit())
	felt.denomination_changed.connect(func(amount: float): bet = amount)
	controls = VBoxContainer.new()
	controls.add_theme_constant_override("separation", 10)
	content.add_child(controls)

func label(text: String, parent: Node = null, font_size: int = 16) -> void:
	if parent == null: parent = controls
	var item := Label.new()
	item.text = text
	item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item.add_theme_font_size_override("font_size", font_size)
	parent.add_child(item)

func button(text: String, callback: Callable, parent: Node = null, disabled: bool = false) -> Button:
	if parent == null: parent = controls
	var item := Button.new()
	item.text = text
	item.custom_minimum_size = Vector2(0, 46)
	item.clip_text = true
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.pressed.connect(callback)
	item.disabled = disabled
	parent.add_child(item)
	return item

func grid(columns: int) -> GridContainer:
	var item := preload("res://scripts/responsive_grid.gd").new()
	item.maximum_columns = columns
	item.add_theme_constant_override("h_separation", 6)
	item.add_theme_constant_override("v_separation", 6)
	controls.add_child(item)
	return item

func _process(_delta: float) -> void:
	if not is_visible_in_tree() or sim == null or sim.joined < 0: return
	var table := sim.get_table(sim.joined)
	if table.is_empty() or sim.table_kind(table) == "craps": return
	if current_id != sim.joined:
		current_id = sim.joined
		player_round = table.round if sim.game_pending(table) else {}
		bet = table.minimum
		feedback = ""
		trips = false
		art.spinning = 0
	var seated_guests := sim.seated(int(table.id)).map(func(guest): return {"id": guest.id, "name": guest.name, "seat": guest.seat, "thought": guest.thought})
	var next: Array = [seated_guests, current_id, sim.wallet, table.round, table.roulette_bets, paused, bet, trips, feedback, show_rules, sim.financial_sequence, art.spinning > 0, int(size.x), table.broken]
	if next == signature: return
	signature = next.duplicate(true)
	render(table)

func transact(start: bool, action: String = "") -> void:
	if paused or art.spinning > 0: return
	var ok := sim.start_game(sim.joined, bet, bet if trips else 0) if start else sim.game_action(sim.joined, action)
	feedback = "" if ok else "Cannot place that wager. Check your bankroll, minimum and dealer coverage."
	if ok and start: player_round = sim.get_table(sim.joined).round
	if ok: art.spinning = 1.4 if sim.table_kind(sim.get_table(sim.joined)) in ["slots", "roulette"] else 0.35
	changed.emit()

func render(table: Dictionary) -> void:
	for child in controls.get_children(): controls.remove_child(child); child.queue_free()
	var kind := sim.table_kind(table)
	stage.vertical = kind != "roulette" or size.x < 1050
	art.custom_minimum_size.x = 250 if not stage.vertical else 0
	art.size_flags_horizontal = Control.SIZE_FILL if not stage.vertical else Control.SIZE_EXPAND_FILL
	art.kind = kind
	art.round = table.round
	if kind == "blackjack":
		art.round = table.round if sim.game_pending(table) or player_round == table.round else {}
		art.table_guests = sim.seated(int(table.id)).map(func(guest): return {"id": guest.id, "name": guest.name, "seat": guest.seat})
	var pending := sim.game_pending(table)
	var locked: bool = paused or art.spinning > 0 or not sim.ready_for_play(table)
	label("%s  |  WALLET $%.2f" % [sim.asset_name(table), sim.wallet], controls, 23)
	var companions := sim.seated(int(table.id))
	if not companions.is_empty():
		var speaker: Dictionary = companions[0]
		for guest in companions:
			if guest.thirst > speaker.thirst: speaker = guest
		label('%s: "%s"' % [speaker.name, speaker.thought], controls, 14)
	label("PAUSED - use Space or the time control below." if paused else ("Finish this hand before leaving." if pending else "Choose a wager. Your casino pays every win."))
	felt.visible = kind == "roulette"
	felt.bets = table.roulette_bets
	felt.selected = bet
	felt.minimum = table.minimum
	felt.locked = locked
	felt.queue_redraw()
	if kind == "roulette":
		label("Single zero | seams place splits/corners; gold edge marks place streets/six lines.")
		var amount := 0.0
		for wager in table.roulette_bets.values(): amount += float(wager)
		label("On layout: $%.2f" % amount)
		for name in table.roulette_bets:
			if not name.is_valid_int(): label("%s: $%.2f" % [name, table.roulette_bets[name]], controls, 13)
		button("SPIN WHEEL", func(): transact(true), controls, locked or amount <= 0)
		button("Take down all bets", func(): sim.clear_roulette(sim.joined); changed.emit(), controls, locked or amount <= 0)
	art.wallet = sim.wallet
	art.wager = bet
	art.side_bet = trips
	art.locked = locked
	art.pending = pending
	art.minimum = table.minimum
	art.machine_profile = sim.slot_profile(table) if kind == "slots" else {}
	art.options = {}
	if kind == "slots":
		art.options = {"Bet": {"text": "BET / $%d" % bet, "disabled": false}, "Spin": {"text": "SPIN REELS", "disabled": sim.wallet < bet}, "Max": {"text": "PLAY MAX / $%d" % sim.maximum_wager(table), "disabled": sim.wallet < sim.maximum_wager(table)}}
	elif kind != "roulette":
		if pending:
			var actions := Games.actions(table.round, sim.wallet)
			for action in actions: art.options[action] = {"text": action + (" | $%.2f" % actions[action] if actions[action] > 0 else ""), "disabled": false}
		else:
			art.options = {"Clear": {"text": "RESET BETS", "disabled": false}, "Deal": {"text": "DEAL / $%d" % (bet*(3 if trips else 2) if kind == "holdem" else bet), "disabled": sim.wallet < (bet*(7 if trips else 6) if kind == "holdem" else bet)}}
	art.configure()
	var visible_round: Dictionary = art.round
	if art.spinning <= 0 and not visible_round.is_empty(): label(str(visible_round.message), controls, 18)
	# Canvas art scales to the screen; wager controls and totals must stay legible.
	if size.x < 600 and kind != "roulette":
		var amount := FinancialText.cash(bet)
		if kind == "holdem": amount += " Ante + matching Blind"
		label("Current wager: " + amount)
		if kind == "slots" and not visible_round.is_empty() and art.spinning <= 0:
			label("Returned: " + FinancialText.cash(float(visible_round.get("credit", 0))))
		if kind in ["blackjack", "holdem"] and not pending:
			var chips := grid(4)
			for value in [5, 10, 25, 100]:
				button("+$%d" % value, func(): bet += value; changed.emit(), chips, locked)
			if kind == "holdem":
				button("Trips: " + ("On" if trips else "Off"), func(): trips = not trips; changed.emit(), controls, locked)
	if not visible_round.is_empty() and visible_round.get("phase", "") == "done" and art.spinning <= 0:
		for npc in visible_round.get("npcs", []): label("%s | returned $%.2f" % [npc.name, npc.returned], controls, 13)
	if art.spinning <= 0:
		# Keep the visitor's own result visible even when seven NPCs share a hand.
		for actor in ["visitor", "guest", "aggregate"]:
			for event in sim.recent_financial_events:
				if int(event.asset_id) != int(table.id) or event.actor != actor: continue
				label("Recent settled HOUSE %s | %s" % [FinancialText.house_result(float(event.amount)), "visitor" if actor == "visitor" else "guests"], controls, 14)
				break
	if feedback != "": label(feedback)
	button("Hide rules / paytable" if show_rules else "Rules / paytable", func(): show_rules = not show_rules)
	if show_rules:
		match kind:
			"slots":
				var profile := sim.slot_profile(table)
				label("PAYTABLE (total returned): cherries %dx | lemons %dx | bells %dx | BAR %dx | sevens %dx. Two cherries or one on the first reel returns %dx. RTP %.2f%% | house edge %.2f%% | %s volatility | top award chance %.2f%% | max wager $%d." % [profile.pays[0], profile.pays[1], profile.pays[2], profile.pays[3], profile.pays[4], profile.cherry_return, profile.rtp * 100, profile.house_edge * 100, profile.volatility, profile.jackpot_probability * 100, profile.maximum], controls, 13)
			"roulette": label("35:1 straight | 17:1 split | 11:1 street/trio | 8:1 corner/first four | 5:1 six line | 2:1 dozens/columns | 1:1 even-money bets. Zero loses all outside bets.", controls, 13)
			"blackjack": label("Six decks shuffled each round | blackjack 3:2 | dealer stands on soft 17 and peeks | double any first two cards, including after split | up to four hands | split aces receive one card | late surrender before splitting | insurance 2:1.", controls, 13)
			"holdem": label("Ante + equal Blind. Preflop raise 3x/4x or check; flop raise 2x or check; river raise 1x or fold. Dealer qualifies with a pair. Blind win pays straight 1:1, flush 3:2, full house 3:1, quads 10:1, straight flush 50:1, royal 500:1; weaker wins push Blind. Trips pays independently, even after folding: trips 3, straight 4, flush 7, full house 8, quads 30, straight flush 40, royal 50 to 1.", controls, 13)
	button("Resume time" if paused else "Pause time", func(): pause_requested.emit(), controls, art.spinning > 0)
	button("Leave / walk floor", func(): leave_requested.emit(), controls, pending or art.spinning > 0)
