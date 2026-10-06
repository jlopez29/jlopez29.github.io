extends Panel
# Static caption + retained native value label supplied by the live controller.
var title := ""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", preload("res://scripts/pit_boss_theme.gd").box(Color("15191d"), Color("45413a"), 0))
	var caption := Label.new()
	caption.text = title
	caption.position = Vector2(10, 7)
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_size_override("font_size", 13)
	caption.add_theme_color_override("font_color", Color("9ca3af"))
	add_child(caption)
