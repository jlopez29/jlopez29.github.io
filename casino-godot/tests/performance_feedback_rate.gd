extends SceneTree
const Fixture = preload("res://tests/performance_fixture.gd")
class CountingFloor:
	extends "res://scripts/floor.gd"
	var labels_created := 0
	func _on_financial_event(event: Dictionary) -> void:
		var prior := floating_results.duplicate()
		super._on_financial_event(event)
		for effect in floating_results:
			if not prior.has(effect): labels_created += 1
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for speed in [1, 4]:
		var sim := Fixture.create("medium")
		var floor := CountingFloor.new()
		floor.sim = sim
		floor.size = Vector2(1440, 900)
		root.add_child(floor)
		floor.set_process(false)
		var batched := floor.has_method("presentation_step")
		if batched: floor.set_presentation_speed(speed)
		var thoughts := 0
		for tick in range(200):
			sim.move_guests(1)
			sim.step()
			if batched: floor.presentation_step()
			var prior := floor.thought_bubbles.duplicate()
			floor._process(1.0 / speed)
			for thought in floor.thought_bubbles:
				if not prior.has(thought): thoughts += 1
		var labels: int = int(floor.get("feedback_batch_count")) if batched else floor.labels_created
		print(JSON.stringify({"speed": speed, "ticks": 200, "real_equivalent_seconds": 200.0 / speed, "economic_events": sim.financial_sequence, "visible_money_created": labels, "thoughts_created": thoughts}))
		floor.queue_free()
		await process_frame
	quit()
