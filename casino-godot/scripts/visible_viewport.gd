extends RefCounted
# Authoritative layout dimensions/insets for every presentation system.
var bridge: JavaScriptObject
var callback: JavaScriptObject
var changed: Callable

func connect_web(on_changed: Callable) -> void:
	if not OS.has_feature("web"): return
	changed = on_changed
	bridge = JavaScriptBridge.get_interface("PitBossViewport")
	if bridge == null: return
	callback = JavaScriptBridge.create_callback(func(_arguments): changed.call())
	bridge.subscribe(callback)
	# Godot may become ready after the browser's bounded page-load retries.
	bridge.schedule()

func disconnect_web() -> void:
	if bridge != null and callback != null: bridge.unsubscribe(callback)
	callback = null
	bridge = null

func measure(window: Window) -> Dictionary:
	var dimensions := Vector2(window.size)
	var insets := Vector4.ZERO # left, top, right, bottom in UI coordinates
	if OS.has_feature("web") and bridge != null:
		var value = JSON.parse_string(str(bridge.getSnapshot()))
		if value is Dictionary:
			dimensions = Vector2(float(value.width), float(value.height))
			insets = Vector4(float(value.left), float(value.top), float(value.right), float(value.bottom))
	elif OS.has_feature("android") or OS.has_feature("ios"):
		var safe := DisplayServer.get_display_safe_area()
		var screen := Vector2(DisplayServer.screen_get_size())
		var ratio := dimensions / screen
		insets = Vector4(safe.position.x * ratio.x, safe.position.y * ratio.y, (screen.x - safe.end.x) * ratio.x, (screen.y - safe.end.y) * ratio.y)
	if not OS.has_feature("web"):
		dimensions = Vector2(maxf(320, dimensions.x), maxf(300, dimensions.y))
	return {"dimensions": dimensions, "insets": insets}
