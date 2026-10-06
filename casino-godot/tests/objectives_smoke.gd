extends "res://tests/momentum_smoke.gd"

func run() -> void:
	objective_checks()
	momentum_checks()
	owner_gambling_events()
	floor_event_catalog()
	floor_crowds_and_payouts()
	await event_ui_smoke()
	await momentum_ui_smoke()
	await objective_ui_smoke()
	print("OBJECTIVES SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func objective_ui_smoke() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.set_process(false)
	ui.owner_checkpoint_path = "/tmp/neon-objectives-smoke.json"
	ui.sim = objective_fixture("gaming_profit")
	ui.floor_view.sim = ui.sim
	ui.bind_optional_events()
	for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.transition_pane("log")
		ui.refresh()
		await process_frame
		var cards = ui.objective_cards
		check(cards.visible and not cards.expanded, "Goals initially collapsed in Log " + str(dimensions))
		cards.heading.pressed.emit()
		await process_frame
		var id: int = ui.sim.optional_objectives.active[0].id
		var card: Dictionary = cards.cards[id]
		var retained: Node = card.root
		for repetition in range(10): ui.refresh()
		check(cards.cards[id].root == retained and card.action.get_signal_connection_list("pressed").size() == 1, "Goal controls retained without duplicate callbacks " + str(dimensions))
		check(cards.body.visible and card.root.size.x <= dimensions.x, "Expanded goals fit viewport " + str(dimensions))
		ui.building = true
		ui.refresh()
		check(ui.floor_view.visible and not ui.events_panel.visible if ui.mobile else ui.floor_view.visible, "Build interaction takes priority over objectives " + str(dimensions))
		ui.cancel_placement()
		ui.transition_pane("log")
		ui.refresh()
		cards.heading.pressed.emit()
	ui.transition_pane("log")
	ui.refresh()
	ui.objective_cards.heading.pressed.emit()
	var id: int = ui.sim.optional_objectives.active[0].id
	ui.objective_cards.cards[id].action.pressed.emit()
	check(ui.sim.optional_objectives.find_goal(id).state == "active", "UI starts optional goal")
	ui.sim.optional_objectives.observe(ui.sim, "gaming_profit", 500)
	ui.refresh()
	var bankroll: float = ui.sim.owner_bankroll
	ui.objective_cards.cards[id].action.pressed.emit()
	var saved = JSON.parse_string(FileAccess.get_file_as_string(ui.owner_checkpoint_path))
	var copy := CasinoSimulation.new()
	check(ui.sim.owner_bankroll > bankroll and copy.restore(saved) and copy.optional_objectives.active.is_empty(), "UI claim durably persists reward and consumed goal")
	ui.queue_free()
	await process_frame
