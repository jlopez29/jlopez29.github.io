extends SceneTree
const Fixture = preload("res://tests/performance_fixture.gd")
func _initialize() -> void:
	var results: Array = []
	for scale in ["small", "medium", "large"]:
		var sim := Fixture.create(scale)
		for i in range(300):
			sim.move_guests(1)
			sim.step()
		results.append({"scenario": scale, "rng": str(sim.rng.state), "snapshot": sim.snapshot()})
	var file := FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string(JSON.stringify(results))
	quit()
