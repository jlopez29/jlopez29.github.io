extends SceneTree
# Focused geometry/input check; does not run game regressions.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var felt = load("res://scripts/roulette_layout.gd").new()
	root.add_child(felt)
	felt.wallet = 1000
	felt.minimum = 5
	for width in [950, 360]:
		felt.size.x = width
		felt.rebuild()
		await process_frame
		for name in felt.cells:
			assert(felt.target(felt.cells[name].get_center()) == name, "Wrong cell: " + name)
		for name in felt.spots:
			assert(felt.target(felt.spots[name]) == name, "Wrong seam: " + name)
		var received: Array = []
		var callback := func(name, amount): received.append([name, amount])
		felt.wager_requested.connect(callback)
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		event.position = felt.tray[25]
		felt._gui_input(event)
		event.pressed = false
		event.position = felt.cells["17"].get_center()
		felt._gui_input(event)
		assert(received == [["17", 25.0]], "Chip drop mismatch")
		felt.locked = true
		felt._gui_input(event)
		assert(received.size() == 1, "Locked felt accepted bet")
		felt.locked = false
		felt.wager_requested.disconnect(callback)
	print("ROULETTE_UI_SMOKE_OK")
	quit()
