extends SceneTree
## Isolated presentation fixtures: actual stop-model payouts, no live settlement.
const Games = preload("res://scripts/casino_games.gd")
const View = preload("res://scripts/game_view.gd")
var output := "/tmp/slot-juice-before"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="): output = arg.trim_prefix("--out=")
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1440,810),Vector2i(390,844),Vector2i(844,390)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		var sim := CasinoSimulation.new()
		sim.opened = true
		sim.join_table(int(sim.tables[0].id))
		var view := View.new()
		view.sim = sim
		root.add_child(view)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.render_current()
		view.art.slot_audio.volume = 0
		for fixture in [{"name":"break-even","stops":[2,7,12]}, {"name":"partial","stops":[6,12,16]}, {"name":"big-win","stops":[3,3,3]}, {"name":"top-award","stops":[18,18,18]}]:
			var round := Games.slots_at_stops(5,fixture.stops,sim.slot_profile(sim.tables[0]),5)
			round.staked = 5.0
			round.paid = true
			sim.tables[0].round = round
			view.player_round = round
			view.slot_lines = 5
			view.notify_change()
			view.art.begin_slot_reveal()
			# Freeze a genuine line/result moment independent of wall-clock rendering.
			view.art.set_process(false)
			view.set_process(false)
			view.balance_before = Vector2(sim.owner_bankroll,sim.cash)
			var seek: float = view.art.reveal_time + 0.60
			while seek > 0:
				var step := minf(seek,1.0/60)
				view.art._process(step)
				seek -= step
			view.signature.clear()
			view.render_current()
			view.art.queue_redraw()
			await process_frame
			await RenderingServer.frame_post_draw
			var path := output + "/%dx%d-%s.png" % [dimensions.x,dimensions.y,fixture.name]
			root.get_texture().get_image().save_png(path)
			print("CAPTURE ",path," credit=",round.credit)
		view.queue_free()
		await process_frame
	await create_timer(0.15).timeout
	quit()
