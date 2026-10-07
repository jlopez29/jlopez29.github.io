extends SceneTree
## Isolated screenshot fixtures; no test controls in shipped gameplay.
const Sim = preload("res://scripts/simulation.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var output := "/tmp/back-room-captures"
func _initialize() -> void:
	call_deferred("run")
func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output+"/"+name+".png")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(output)
	for dimensions in [Vector2i(1440,900),Vector2i(390,844),Vector2i(844,390)]:
		root.size=dimensions
		root.content_scale_size=dimensions
		var sim := Sim.new()
		var view := preload("res://scripts/back_room_view.gd").new()
		view.sim=sim
		root.add_child(view)
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.open()
		var prefix := "%dx%d-" % [dimensions.x,dimensions.y]
		await shot(prefix+"lobby")
		sim.private_action(0,"choose",{"kind":"slots"})
		view.page="game"; view.rebuild()
		await shot(prefix+"slots")
		sim.owner_account.floor_debit(850,0)
		view.page="recovery"; view.expanded_contract=sim.recovery.state.contracts[0].id; view.rebuild()
		await shot(prefix+"puzzle")
		for c in sim.recovery.state.contracts:
			var p := Recovery.puzzle(c)
			sim.recovery.submit(sim,c.id,{"choice":p.get("answer",0),"number":p.get("number",0),"reason":p.get("reason",0),"mask":p.get("mask",3),"aisle":true})
		view.rebuild()
		await process_frame
		view.body_scroll.scroll_vertical=10000
		await shot(prefix+"rewards")
		view.queue_free()
		await process_frame
	quit()
