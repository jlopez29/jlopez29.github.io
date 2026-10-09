extends Control
var completed := 0:
	set(value):
		if completed==value: return
		completed=value
		queue_redraw()
func _ready() -> void:
	custom_minimum_size=Vector2(0,52)
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var font := get_theme_font("font")
	draw_string(font,Vector2(0,21),"%d / 3 JOBS VERIFIED" % completed,HORIZONTAL_ALIGNMENT_LEFT,size.x,19,Color("e9dfc8"))
	var width := (size.x-16)/3
	for i in range(3):
		var rect := Rect2(i*(width+8),33,width,12)
		draw_rect(rect,Color("619c7a") if i<completed else Color("353d36"))
		draw_rect(rect,Color("b39b62"),false,1)
