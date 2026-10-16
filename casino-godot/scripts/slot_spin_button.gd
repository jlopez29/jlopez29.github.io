extends Button
## Slot-only circular control; Button retains keyboard, focus, tooltip and signals.
func _ready() -> void:
	custom_minimum_size = Vector2(84,84)
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for state in ["font_color","font_hover_color","font_pressed_color","font_disabled_color","font_focus_color"]:
		add_theme_color_override(state,Color.TRANSPARENT)
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	return point.distance_to(size/2) <= minf(size.x,size.y)/2

func _draw() -> void:
	var center := size/2
	var radius := minf(size.x,size.y)/2-2
	var pressed := is_pressed() and not disabled
	draw_circle(center+Vector2(0,2),radius,Color("09090c"))
	draw_circle(center,radius-1,Color("4e341b"))
	draw_circle(center,radius-3,Color("e1ba63") if not disabled else Color("84714b"))
	draw_arc(center,radius-5,PI,TAU,48,Color("fff0bd") if not disabled else Color("a69676"),2,true)
	draw_circle(center,radius-8,Color("442015"))
	for ring in range(16):
		var t := ring/15.0
		var color := Color("6b1022").lerp(Color("d72e3c") if is_hovered() else Color("b72335"),t)
		if pressed: color = color.darkened(0.22)
		if disabled: color = Color("38252b").lerp(Color("5c3b42"),t)
		draw_circle(center+Vector2(-t*2,-t*3),radius-10-t*9,color)
	draw_arc(center,radius-11,PI*1.12,PI*1.88,40,Color("f89e89",0.5 if not disabled else 0.12),2,true)
	if has_focus(): draw_arc(center,radius,0,TAU,64,Color("fff0b8"),2,true)
	var font := get_theme_font("font")
	var lines := text.split(" ") if text.length() > 6 else PackedStringArray([text])
	var font_size := 18 if lines.size() > 1 else 22
	var line_height := font.get_height(font_size)
	for i in range(lines.size()):
		var at := center+Vector2(-font.get_string_size(lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x/2,(i-(lines.size()-1)/2.0)*line_height+(font.get_ascent(font_size)-font.get_descent(font_size))/2+(1 if pressed else 0))
		draw_string(font,at,lines[i],HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color("fff0c6") if not disabled else Color("b1a08a"))
