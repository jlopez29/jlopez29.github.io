extends VBoxContainer
## Collapsible content inside Log; never opens a modal or targets the floor.
signal changed
const Goals = preload("res://scripts/optional_objectives.gd")
var sim: CasinoSimulation
var expanded := false
var heading: Button
var body: VBoxContainer
var cards := {}
var message: Label

func _ready() -> void:
	size_flags_horizontal = SIZE_EXPAND_FILL
	heading = button(self, "Optional goals", func():
		expanded = not expanded
		body.visible = expanded)
	body = VBoxContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	add_child(body)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(message)
	message.text = "Start only goals you want. Ignore or expire safely."
	var policy := label(body)
	policy.text = "Personal rewards: $%.0f per game day, $%.0f bankroll cap including committed stakes. A partial claim uses up the goal." % [CasinoTuning.OBJECTIVE_DAILY_REWARD, CasinoTuning.OBJECTIVE_BANKROLL_CAP]
	body.hide()
	hide()

func button(parent: Node, title: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = title
	control.custom_minimum_size.y = 44
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	control.clip_text = true
	control.pressed.connect(callback)
	parent.add_child(control)
	return control

func label(parent: Node) -> Label:
	var control := Label.new()
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(control)
	return control

func reset() -> void:
	expanded = false
	if is_instance_valid(body): body.hide()
	for card in cards.values():
		body.remove_child(card.root)
		card.root.queue_free()
	cards.clear()

func refresh(simulation: CasinoSimulation) -> void:
	sim = simulation
	if not is_node_ready(): return
	visible = not sim.optional_objectives.active.is_empty()
	var ids := {}
	var ready := 0
	for goal in sim.optional_objectives.active:
		var id := int(goal.id)
		ids[id] = true
		if goal.state == "ready": ready += 1
		if not cards.has(id):
			var box := VBoxContainer.new()
			body.add_child(box)
			var card := {"root": box, "title": label(box), "progress": label(box), "reward": label(box), "terms": label(box)}
			var actions := preload("res://scripts/responsive_row.gd").new()
			box.add_child(actions)
			card.action = button(actions, "Start goal", func():
				var current: Dictionary = sim.optional_objectives.find_goal(id)
				var ok: bool = sim.optional_objectives.claim(sim, id) if current.get("state") == "ready" else sim.optional_objectives.start(sim, id)
				message.text = "Start only goals you want. Ignore or expire safely." if ok else "Unavailable: check current conditions, bankroll cap, reward budget or save storage."
				AudioManager.play_ui("win" if ok and current.get("state") == "claimed" else "confirm" if ok else "invalid")
				changed.emit())
			card.dismiss = button(actions, "Ignore", func(): sim.optional_objectives.dismiss(sim, id); changed.emit())
			cards[id] = card
		var card: Dictionary = cards[id]
		card.title.text = Goals.TITLES[goal.kind]
		card.progress.text = progress_text(goal)
		card.reward.text = "Reward: up to $%.0f Owner Bankroll + %.0f Momentum" % [float(goal.reward), CasinoTuning.OBJECTIVE_MOMENTUM_REWARD]
		card.reward.tooltip_text = "Personal funds only. $%.0f per game day, $%.0f bankroll cap including committed personal stakes. Partial rewards consume the goal; no reward if caps are full." % [CasinoTuning.OBJECTIVE_DAILY_REWARD, CasinoTuning.OBJECTIVE_BANKROLL_CAP]
		card.terms.text = "%d game min left. %s" % [maxi(0, int(goal.expires) - sim.elapsed), terms(goal)]
		card.action.visible = goal.state != "active"
		card.action.text = "Claim $%.0f" % sim.optional_objectives.claimable(sim, goal) if goal.state == "ready" else "Start goal"
		card.action.disabled = sim.elapsed >= int(goal.expires) or (sim.optional_objectives.claimable(sim, goal) <= 0 if goal.state == "ready" else not sim.optional_objectives.eligible(sim, str(goal.kind)))
		card.dismiss.text = "Dismiss" if goal.state == "ready" else "Ignore"
	for id in cards.keys():
		if ids.has(id): continue
		body.remove_child(cards[id].root)
		cards[id].root.queue_free()
		cards.erase(id)
	heading.text = "Optional goals (%d)%s" % [sim.optional_objectives.active.size(), " - reward ready" if ready > 0 else ""]
	body.visible = expanded

func progress_text(goal: Dictionary) -> String:
	var prefix := "Ready to claim" if goal.state == "ready" else "Not started" if goal.state == "offered" else "In progress"
	var progress := maxf(0, float(goal.progress))
	if goal.kind == "gaming_profit": return "%s: $%.0f / $%.0f net guest gaming win" % [prefix, progress, float(goal.target)]
	return "%s: %.0f / %.0f%s" % [prefix, progress, float(goal.target), " consecutive game min" if goal.kind in ["momentum", "occupied_games"] else ""]

func terms(goal: Dictionary) -> String:
	match str(goal.kind):
		"happy_visits": return "Real gambling visits ending at %.0f%% satisfaction or better; closing departures do not count." % CasinoTuning.OBJECTIVE_HAPPY_SATISFACTION
		"gaming_profit": return "Settled guest gaming win, including losses; excludes owner play and operating expenses."
		"paid_drinks": return "Delivered paid orders; complimentary drinks do not count."
		"occupied_games": return "Keep %d game(s) operating with guests placing real wagers. Closing resets the streak." % int(goal.threshold)
		"momentum": return "Maintain %.0f Momentum with at least one game in real guest play. Closing resets the streak." % float(goal.threshold)
		"owner_win": return "A net-positive committed owner slots or blackjack opportunity; normal odds, personal stakes."
	return ""
