extends SceneTree
const Fixture = preload("res://tests/performance_fixture.gd")
const Main = preload("res://scripts/main.gd")
var results: Array = []
func _initialize() -> void: call_deferred("run")
func measure(call: Callable, count: int) -> Dictionary:
	var total := 0
	var worst := 0
	for i in range(count):
		var start := Time.get_ticks_usec()
		call.call()
		var duration := Time.get_ticks_usec() - start
		total += duration
		worst = maxi(worst, duration)
	return {"mean_usec": float(total) / count, "worst_usec": worst}
func run() -> void:
	var ui := Main.new()
	root.add_child(ui)
	await process_frame
	ui.close_modal()
	ui.set_process(false)
	ui.floor_view.set_process(false)
	for scale in ["small", "medium", "large"]:
		ui.sim = Fixture.create(scale)
		ui.floor_view.sim = ui.sim
		ui.selected = ui.sim.tables[0].id
		ui.refresh()
		await process_frame
		var sample := {"scenario": scale, "guests": ui.sim.guests.size(), "assets": ui.sim.tables.size(), "staff": ui.sim.staff.size(), "page": ui.page, "debug": OS.is_debug_build()}
		sample.floor_queries = measure(func():
			for table in ui.sim.tables:
				ui.sim.seated(int(table.id)); ui.sim.reserved_guests(int(table.id)); ui.sim.crew(int(table.id)); ui.sim.table_hot(table); ui.sim.table_status(table); ui.sim.operating(table), 300)
		if ui.sim.has_method("floor_presentation"):
			sample.floor_cache = measure(func(): ui.sim.floor_presentation(), 300)
		sample.refresh = measure(ui.refresh, 100)
		sample.snapshot_json = measure(func(): JSON.stringify(ui.sim.snapshot()), 100)
		sample.step = measure(ui.sim.step, 100)
		await process_frame
		sample.memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
		sample.nodes = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
		results.append(sample)
		print(JSON.stringify(sample))
	ui.queue_free()
	await process_frame
	var path := "/tmp/neon-performance-profile.json"
	if OS.get_cmdline_user_args().size(): path = OS.get_cmdline_user_args()[0]
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(results, "  "))
	quit()
