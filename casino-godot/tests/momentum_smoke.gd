extends "res://tests/owner_events_smoke.gd"

func run() -> void:
	momentum_checks()
	owner_gambling_events()
	floor_event_catalog()
	floor_crowds_and_payouts()
	await event_ui_smoke()
	await momentum_ui_smoke()
	print("MOMENTUM SMOKE: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func momentum_ui_smoke() -> void:
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.set_process(false)
	for dimensions in [Vector2i(1440,900), Vector2i(844,390), Vector2i(390,844), Vector2i(320,568)]:
		root.size = dimensions
		await process_frame
		ui.open_page("development")
		await process_frame
		var toggle: Button
		for button in ui.inspector.get_children():
			if button is Button and button.text == "Momentum details": toggle = button
		check(is_instance_valid(toggle), "Momentum detail available at " + str(dimensions))
		if is_instance_valid(toggle):
			check(toggle.size.x <= dimensions.x, "Momentum control fits viewport " + str(dimensions))
			toggle.pressed.emit()
			var count: int = ui.inspector.get_child_count()
			for iteration in range(10): ui.refresh()
			check(ui.inspector.get_child_count() == count and toggle.get_signal_connection_list("pressed").size() == 1, "Momentum refresh retains controls without duplicate subscriptions " + str(dimensions))
			var detail_visible := false
			for child in ui.inspector.get_children():
				if child is Label and child.text.begins_with("Momentum Busy:"): detail_visible = child.visible
			check(detail_visible, "Momentum explanation actually visible " + str(dimensions))
			check(ui.momentum_expanded, "Touch-accessible momentum explanation " + str(dimensions))
			toggle.pressed.emit()
		ui.transition_pane("floor")
		ui.refresh()
		check(ui.floor_view.visible, "Momentum leaves floor interactions accessible " + str(dimensions))
	ui.queue_free()
	await process_frame
