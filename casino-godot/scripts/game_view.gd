extends Control
signal leave_requested
signal changed
signal pause_requested
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
var signature := ""
var current_id := -1
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
			"Bet": bet = [5,10,25,100][([5,10,25,100].find(int(bet))+1)%4]; bet = maxf(bet,sim.get_table(sim.joined).minimum)
			"Max": bet = 100; transact(true)
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
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.pressed.connect(callback)
	item.disabled = disabled
	parent.add_child(item)
	return item

func grid(columns: int) -> GridContainer:
	var item := GridContainer.new()
	item.columns = columns
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
		bet = table.minimum
		feedback = ""
		trips = false
		art.spinning = 0
	var next := JSON.stringify([current_id, sim.wallet, table.round, table.roulette_bets, paused, bet, trips, feedback, show_rules, art.spinning > 0, int(size.x / 100), table.broken])
	if next == signature: return
	signature = next
	render(table)

func transact(start: bool, action: String = "") -> void:
	if paused or art.spinning > 0: return
	var ok := sim.start_game(sim.joined, bet, bet if trips else 0) if start else sim.game_action(sim.joined, action)
	feedback = "" if ok else "Cannot place that wager. Check your bankroll, minimum and dealer coverage."
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
	var pending := sim.game_pending(table)
	var locked: bool = paused or art.spinning > 0 or not sim.ready_for_play(table)
	label("%s  ·  WALLET $%.2f" % [Games.NAMES[kind], sim.wallet], controls, 23)
	label("PAUSED — use Space or the time control below." if paused else ("Finish this hand before leaving." if pending else "Choose a wager. Your casino pays every win."))
	felt.visible = kind == "roulette"
	felt.bets = table.roulette_bets
	felt.selected = bet
	felt.minimum = table.minimum
	felt.locked = locked
	felt.queue_redraw()
	if kind == "roulette":
		label("Single zero · seams place splits/corners; gold edge marks place streets/six lines.")
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
	art.options = {}
	if kind == "slots":
		art.options = {"Bet": {"text": "BET / $%d" % bet, "disabled": false}, "Spin": {"text": "SPIN REELS", "disabled": sim.wallet < bet}, "Max": {"text": "PLAY MAX / $100", "disabled": sim.wallet < 100}}
	elif kind != "roulette":
		if pending:
			var actions := Games.actions(table.round, sim.wallet)
			for action in actions: art.options[action] = {"text": action + (" · $%.2f" % actions[action] if actions[action] > 0 else ""), "disabled": false}
		else:
			art.options = {"Clear": {"text": "RESET BETS", "disabled": false}, "Deal": {"text": "DEAL / $%d" % (bet*(3 if trips else 2) if kind == "holdem" else bet), "disabled": sim.wallet < (bet*(7 if trips else 6) if kind == "holdem" else bet)}}
	art.configure()
	if art.spinning <= 0 and not table.round.is_empty(): label(str(table.round.message), controls, 18)
	if not table.round.is_empty() and table.round.get("phase", "") == "done" and art.spinning <= 0:
		for npc in table.round.get("npcs", []): label("%s · returned $%.2f" % [npc.name, npc.returned], controls, 13)
	if feedback != "": label(feedback)
	button("Hide rules / paytable" if show_rules else "Rules / paytable", func(): show_rules = not show_rules)
	if show_rules:
		match kind:
			"slots": label("PAYTABLE (total returned): 3 cherries 5× · lemons 8× · bells 15× · BAR 30× · sevens 100×. Two cherries or one cherry on the first reel returns 1×. Three 20-stop reels; one payline. Theoretical return: 91.725%.", controls, 13)
			"roulette": label("35:1 straight · 17:1 split · 11:1 street/trio · 8:1 corner/first four · 5:1 six line · 2:1 dozens/columns · 1:1 even-money bets. Zero loses all outside bets.", controls, 13)
			"blackjack": label("Six decks shuffled each round · blackjack 3:2 · dealer stands on soft 17 and peeks · double any first two cards, including after split · up to four hands · split aces receive one card · late surrender before splitting · insurance 2:1.", controls, 13)
			"holdem": label("Ante + equal Blind. Preflop raise 3×/4× or check; flop raise 2× or check; river raise 1× or fold. Dealer qualifies with a pair. Blind win pays straight 1:1, flush 3:2, full house 3:1, quads 10:1, straight flush 50:1, royal 500:1; weaker wins push Blind. Trips pays independently, even after folding: trips 3, straight 4, flush 7, full house 8, quads 30, straight flush 40, royal 50 to 1.", controls, 13)
	button("Resume time" if paused else "Pause time", func(): pause_requested.emit(), controls, art.spinning > 0)
	button("Leave / walk floor", func(): leave_requested.emit(), controls, pending or art.spinning > 0)
