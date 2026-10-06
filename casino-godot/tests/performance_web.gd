extends "res://scripts/main.gd"
const Fixture = preload("res://tests/performance_fixture.gd")
var sample_timer := 0.0
func _ready() -> void:
	super._ready()
	close_modal()
	var scale := str(JavaScriptBridge.eval("new URLSearchParams(location.search).get('scale') || 'medium'", true))
	sim = Fixture.create(scale)
	floor_view.sim = sim
	game_view.sim = sim
	selected = sim.tables[0].id
	speed = int(JavaScriptBridge.eval("Number(new URLSearchParams(location.search).get('speed') || 4)", true))
	refresh()
func _process(delta: float) -> void:
	super._process(delta)
	sample_timer += delta
	if sample_timer < 1: return
	sample_timer = 0
	var data := {"elapsed": sim.elapsed, "guests": sim.guests.size(), "assets": sim.tables.size(), "staff": sim.staff.size(), "speed": speed, "page": page, "cash": sim.cash, "events": sim.financial_sequence, "redraws": floor_view.redraw_count, "batches": floor_view.feedback_batch_count, "thought_visuals": floor_view.thought_presentation_count, "nodes": Performance.get_monitor(Performance.OBJECT_NODE_COUNT), "objects": Performance.get_monitor(Performance.OBJECT_COUNT), "memory": Performance.get_monitor(Performance.MEMORY_STATIC), "fps": Engine.get_frames_per_second(), "process_seconds": Performance.get_monitor(Performance.TIME_PROCESS)}
	JavaScriptBridge.eval("window.neonPerformance = " + JSON.stringify(data), true)
