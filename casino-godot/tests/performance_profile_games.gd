extends SceneTree
const View = preload("res://scripts/game_view.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var sim := CasinoSimulation.new("easy", ["slots", "blackjack", "roulette", "holdem"])
	var view := View.new()
	view.sim = sim
	view.size = Vector2(1000, 800)
	root.add_child(view)
	await process_frame
	for table in sim.tables:
		sim.joined = table.id
		view._process(0)
		var start := Time.get_ticks_usec()
		for i in range(20000): view._process(0)
		print("GAME SIGNATURE %s: %.3f usec/frame" % [table.kind, float(Time.get_ticks_usec() - start) / 20000])
	view.queue_free()
	await process_frame
	quit()
