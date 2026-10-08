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
	var sim := CasinoSimulation.new()
	assert(sim.back_room.choose("roulette"))
	var view = load("res://scripts/game_view.gd").new()
	view.sim = PitBossGameContext.new(sim, {"id": 9001, "kind": "roulette"})
	root.add_child(view)
	for dimensions in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		view.size = dimensions
		view.render_current()
		view.show_wheel = true
		view.layout_play()
		for i in range(8): await process_frame
		assert(not view.art.get_global_rect().intersects(view.surface_scroll.get_global_rect()), "Wheel has dedicated space " + str(dimensions))
		assert(not view.art.get_global_rect().intersects(view.rack_scroll.get_global_rect()), "Wheel avoids chip rack")
		assert(view.art.size.x > 0 and view.surface_scroll.size.y >= 80, "Usable wheel and felt")
		view.signature.clear()
		view.render_current()
		assert(not view.felt.locked, "Wheel visibility does not lock bets")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/roulette-%dx%d.png" % [dimensions.x, dimensions.y])
		view.show_wheel = false
		view.art.animate(2.8)
		view.layout_play()
		assert(not view.art.get_global_rect().intersects(view.surface_scroll.get_global_rect()), "Automatic spin reserves wheel space")
		view.art.spinning = 0
		view.layout_play()
		assert(view.surface_scroll.position.y == (100 if dimensions.x < 760 else 56) and is_equal_approx(view.surface_scroll.size.x, dimensions.x - 8), "Hidden wheel returns felt space")
	view.queue_free()
	felt.queue_free()
	await process_frame
	print("ROULETTE_UI_SMOKE_OK")
	quit()
