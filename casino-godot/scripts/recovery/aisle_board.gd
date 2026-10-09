extends Control
var clear := false:
	set(value):
		clear=value
		queue_redraw()
func _ready() -> void:
	custom_minimum_size=Vector2(0,88)
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
func _draw() -> void:
	var lane := Rect2(4,6,size.x*0.6,76)
	var bay := Rect2(size.x*0.65,6,size.x*0.35-4,76)
	draw_rect(lane,Color("776740"))
	draw_rect(bay,Color("31453e"))
	for i in range(5):
		var x := 14+i*lane.size.x/5
		draw_line(Vector2(x,70),Vector2(x+20,20),Color("dfc268"),3)
	var cart := Rect2(Vector2(size.x*0.72 if clear else size.x*0.22,28),Vector2(48,32))
	draw_rect(cart,Color("94a0a3"))
	draw_circle(cart.position+Vector2(10,34),5,Color("121f20"))
	draw_circle(cart.position+Vector2(38,34),5,Color("121f20"))
	draw_string(ThemeDB.fallback_font,Vector2(10,24),"EXIT AISLE",HORIZONTAL_ALIGNMENT_LEFT,lane.size.x-10,15,Color.WHITE)
	draw_string(ThemeDB.fallback_font,Vector2(bay.position.x+6,24),"STORAGE",HORIZONTAL_ALIGNMENT_LEFT,bay.size.x-8,15,Color.WHITE)
