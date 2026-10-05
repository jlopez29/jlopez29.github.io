extends SceneTree

# Startup only: instantiate the real scene, check onboarding, then reveal the UI.
# No rolls, simulation scenarios, saves, or browser automation.
func _initialize() -> void:
	call_deferred("check_startup")

func fail(message: String) -> void:
	printerr("STARTUP FAIL: " + message)
	quit(1)

func check_startup() -> void:
	root.size = Vector2i(1440, 900)
	root.content_scale_size = Vector2i(1440, 900)
	var script := load("res://scripts/main.gd") as Script
	if script == null or not script.can_instantiate():
		fail("Main script could not compile.")
		return
	var scene := load("res://main.tscn") as PackedScene
	if scene == null:
		fail("Main scene could not load.")
		return
	var ui := scene.instantiate()
	root.add_child(ui)
	for i in range(3): await process_frame
	for key in ["brand", "header_actions", "doors_button", "walk_button", "floor_view", "inspector", "felt", "modal"]:
		var control = ui.get(key)
		if not is_instance_valid(control) or not control is Control or not control.is_inside_tree():
			fail("Missing startup control: " + key)
			return
	if not ui.get("modal").is_visible_in_tree():
		fail("Onboarding did not appear.")
		return
	ui.call("close_modal")
	for i in range(3): await process_frame
	for key in ["brand", "doors_button", "walk_button", "floor_view"]:
		var control: Control = ui.get(key)
		if not control.is_visible_in_tree() or control.size.x <= 0 or control.size.y <= 0:
			fail("Startup control is hidden or has no size: " + key)
			return
	print("STARTUP_SMOKE_OK")
	quit(0)
