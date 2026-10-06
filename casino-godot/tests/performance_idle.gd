extends SceneTree
class CountingFloor:
	extends "res://scripts/floor.gd"
	var draws := 0
	func _draw() -> void:
		draws += 1
		super._draw()
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Engine.max_fps = 60
	var floor := CountingFloor.new()
	floor.sim = CasinoSimulation.new()
	floor.size = Vector2(800, 600)
	root.add_child(floor)
	if floor.has_method("set_presentation_speed"): floor.set_presentation_speed(0)
	for i in range(180): await process_frame
	var start := floor.draws
	for i in range(180): await process_frame
	var count := floor.draws - start
	print("IDLE REDRAWS: %d / 180 frames" % count)
	if floor.has_method("set_presentation_speed") and count > 8:
		printerr("FAIL: idle floor still redraws continuously")
		quit(1)
	else: quit()
