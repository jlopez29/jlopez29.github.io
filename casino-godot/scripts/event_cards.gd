extends VBoxContainer
signal changed
## Embedded in the existing edge activity panel, never an overlay on the floor.
const Events = preload("res://scripts/optional_events.gd")
var sim: CasinoSimulation
var current_id := -1
var card: VBoxContainer
var title: Label
var description: Label
var details: Label
var countdown: Label
var engage: Button
var dismiss: Button
var expand: Button
var queue_label: Label
var wager_terms: Label
var stakes: OptionButton
var commit: Button
var response: Button
var message: Label

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	queue_label = Label.new()
	queue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(queue_label)
	card = VBoxContainer.new()
	card.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(card)
	title = Label.new()
	description = Label.new()
	countdown = Label.new()
	details = Label.new()
	for label in [title, description, countdown, details]:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card.add_child(label)
	details.hide()
	var actions := preload("res://scripts/responsive_row.gd").new()
	card.add_child(actions)
	engage = make_button(actions, "Engage", func():
		if sim != null: sim.optional_events.engage(sim, current_id)
		changed.emit())
	dismiss = make_button(actions, "Ignore", func():
		if sim != null: sim.optional_events.resolve(sim, current_id, "dismissed")
		changed.emit())
	response = make_button(actions, "Response", func():
		if sim != null and response.has_meta("response_id"):
			message.text = "" if sim.optional_events.respond(sim, current_id, str(response.get_meta("response_id"))) else "Action unavailable, already handled or casino cash is too low."
		changed.emit())
	expand = make_button(actions, "Details", func():
		details.visible = not details.visible
		expand.text = "Less" if details.visible else "Details")
	wager_terms = Label.new()
	wager_terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(wager_terms)
	stakes = OptionButton.new()
	stakes.custom_minimum_size.y = 44
	card.add_child(stakes)
	stakes.item_selected.connect(func(_index): update_terms())
	commit = make_button(card, "Commit personal stake", func():
		var stake := float(stakes.get_item_metadata(stakes.selected)) if stakes.selected >= 0 else 0.0
		message.text = "" if sim.start_owner_event(current_id, stake) else "Cannot commit: check personal bankroll, availability, or finish your current game."
		changed.emit())
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card.add_child(message)
	hide()

func make_button(parent: Node, text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(76, 44)
	button.size_flags_horizontal = SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func refresh(simulation: CasinoSimulation) -> void:
	sim = simulation
	if not is_node_ready(): return
	visible = not sim.optional_events.active.is_empty()
	if not visible:
		current_id = -1
		return
	# One visible card; bounded overflow remains in simulation and also expires.
	var event: Dictionary = sim.optional_events.active[0]
	var definition: Dictionary = Events.DEFINITIONS[event.type]
	if current_id != int(event.id):
		details.hide()
		expand.text = "Details"
		message.text = ""
	current_id = int(event.id)
	queue_label.visible = sim.optional_events.active.size() > CasinoTuning.EVENT_VISIBLE_CAP
	queue_label.text = "%d more event(s) queued" % (sim.optional_events.active.size() - CasinoTuning.EVENT_VISIBLE_CAP)
	title.text = "%s - %s" % [definition.category, definition.title]
	var color := Color("ff9486") if definition.theme == "urgent" else Color("e3bb70") if definition.theme == "caution" else Color("57d6b1")
	title.add_theme_color_override("font_color", color)
	description.text = definition.description
	if definition.target_kind == "asset":
		var target: Dictionary = sim.get_table(int(event.target))
		if not target.is_empty(): description.text += " Source: %s #%d." % [sim.asset_name(target), event.target]
	elif definition.target_kind == "staff":
		for employee in sim.staff:
			if int(employee.id) == int(event.target): description.text += " Dealer: %s (#%d)." % [employee.name, employee.id]
	elif definition.target_kind == "bar": description.text += " Source: bar counter."
	details.text = definition.details
	countdown.text = "%d game min remaining%s" % [maxi(0, int(event.expires) - sim.elapsed), " | In progress" if event.state == "engaged" else ""]
	countdown.tooltip_text = "Countdown pauses with the simulation. Closed casinos do not schedule new events."
	engage.disabled = event.state != "pending"
	engage.text = "In progress" if engage.disabled else "Engage"
	dismiss.text = "Ignore" if definition.category == "OPPORTUNITY" else "Dismiss"
	var choices: Array = definition.get("responses", [])
	response.visible = not choices.is_empty() and event.state == "pending"
	if response.visible:
		response.text = str(choices[0].label)
		if choices[0].action == "repair": response.text = "Repair $%d" % sim.repair_cost(sim.get_table(int(event.target)))
		response.set_meta("response_id", choices[0].id)
	var owner_game: bool = definition.action == "owner_game"
	stakes.visible = owner_game and event.state == "engaged"
	commit.visible = stakes.visible
	wager_terms.visible = owner_game
	if owner_game:
		var options: Array = sim.optional_events.stake_options(sim, str(event.type), int(event.target))
		var previous := float(stakes.get_item_metadata(stakes.selected)) if stakes.selected >= 0 else 0.0
		var shown_options: Array = []
		for i in range(stakes.item_count): shown_options.append(float(stakes.get_item_metadata(i)))
		if options != shown_options:
			stakes.clear()
			for option in options:
				stakes.add_item("$%.2f per %s" % [option, "spin" if definition.game == "slots" else "hand"])
				stakes.set_item_metadata(stakes.item_count - 1, option)
			stakes.select(maxi(0, options.find(previous)))
		update_terms()
	engage.text = "Review stake" if owner_game and event.state == "pending" else engage.text

func update_terms() -> void:
	if sim == null or stakes.selected < 0: return
	var event: Dictionary = sim.optional_events.find_event(current_id)
	if event.is_empty(): return
	var definition: Dictionary = Events.DEFINITIONS[event.type]
	var stake := float(stakes.get_item_metadata(stakes.selected))
	var total := stake * int(definition.rounds)
	wager_terms.text = "Owner Bankroll $%.2f | Commit $%.2f | %s. " % [sim.owner_bankroll, total, "Play %d spins" % definition.rounds if definition.game == "slots" else "Play 1 hand"]
	wager_terms.text += "Only NET winnings go to casino cash; pushes return stake. Committing autosaves your current casino. "
	if definition.game == "blackjack": wager_terms.text += "Even-money wins / blackjack 3:2; extra split, double and insurance stakes spend personal funds (up to $%.2f total)." % (stake * CasinoTuning.OWNER_EVENT_EXPOSURE_MULTIPLIER)
	else:
		var table: Dictionary = sim.get_table(int(event.target))
		var profile: Dictionary = sim.slot_profile(table)
		wager_terms.text += "Per spin: $0 to $%.2f total return, RTP %.2f%%. All 3 spins settle together." % [stake * float(profile.pays.max()), float(profile.rtp) * 100]
	commit.text = "Commit $%.2f and play" % total
	commit.disabled = sim.owner_bankroll < total or not sim.owner_play.is_empty() or sim.joined >= 0 or not sim.optional_events.target_valid(sim, event)

