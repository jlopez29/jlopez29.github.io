extends "res://tests/run_tests.gd"
# Focused feature checks only: no broad regression or long simulation scenarios.

func run() -> void:
	owner_gambling_events()
	floor_event_catalog()
	floor_crowds_and_payouts()
	await event_ui_smoke()
	print("OWNER EVENTS SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func event_ui_smoke() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.owner_checkpoint_path = "/tmp/neon-owner-events-smoke.json"
	for kind in ["slots", "blackjack"]:
		ui.start_casino("easy", [kind])
		ui.close_modal()
		ui.set_process(false)
		ui.sim.opened = true
		check(ui.sim.optional_events.spawn(ui.sim, "owner_" + kind, true), "UI sample eligible: " + kind)
		ui.transition_pane("log")
		ui.refresh()
		ui.event_cards.engage.pressed.emit()
		check(ui.sim.owner_play.is_empty() and ui.event_cards.commit.visible, "Review before funding: " + kind)
		ui.sim.optional_events.rng.seed = 15
		ui.event_cards.commit.pressed.emit()
		await process_frame
		check(not ui.sim.owner_play.is_empty() and ui.game_view.visible and ui.sim.joined == -1, "Existing game UI with isolated owner event: " + kind)
		var saved = JSON.parse_string(FileAccess.get_file_as_string(ui.owner_checkpoint_path))
		var copy := CasinoSimulation.new()
		check(copy.restore(saved) and not copy.owner_play.is_empty(), "Durable wager checkpoint: " + kind)
		for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
			root.size = dimensions
			await process_frame
			ui.layout_ui()
			ui.game_view._process(0)
			await process_frame
			check(ui.game_view.visible and not ui.events_panel.visible and not ui.inspector_panel.visible, "Unobstructed event game: " + kind + str(dimensions))
		ui.leave_table()
		check(ui.sim.owner_play.is_empty() and ui.floor_view.visible, "Clean return to management: " + kind)
		saved = JSON.parse_string(FileAccess.get_file_as_string(ui.owner_checkpoint_path))
		check(copy.restore(saved) and copy.owner_play.is_empty() and copy.owner_account.pending.is_empty(), "Exit persisted exactly one settlement: " + kind)
	ui.queue_free()
	await process_frame
