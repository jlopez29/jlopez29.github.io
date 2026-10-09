extends Control
var caption := ""
var actual := 0
var target := 0
var glow := 0.0:
	set(value):
		glow=value
		queue_redraw()
var fade: Tween
func _ready() -> void:
	custom_minimum_size=Vector2(0,84)
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(func():
		if not is_visible_in_tree() and fade: fade.kill())
func update(value: int, goal: int) -> void:
	actual=value
	target=goal
	if fade: fade.kill()
	if is_inside_tree() and is_visible_in_tree():
		fade=create_tween()
		fade.tween_property(self,"glow",1.0 if actual==target else 0.0,0.18)
	else: glow=1.0 if actual==target else 0.0
	queue_redraw()
func _draw() -> void:
	var color := Color("cfa55f").lerp(Color("7fcca1"),glow)
	draw_circle(Vector2(32,40),26,Color("0c1617"))
	draw_arc(Vector2(32,40),25,0,TAU,32,Color("948367"),2,true)
	draw_circle(Vector2(32,40),19,color.darkened(0.3))
	draw_circle(Vector2(28,35),8,color.lightened(0.2))
	var font := get_theme_font("font")
	draw_string(font,Vector2(72,25),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-78,18,Color("f0e7d4"))
	draw_string(font,Vector2(72,48),"Actual %d / Target %d" % [actual,target],HORIZONTAL_ALIGNMENT_LEFT,size.x-78,17,Color("f0e7d4"))
	draw_string(font,Vector2(72,70),"MATCH" if actual==target else "ADJUST",HORIZONTAL_ALIGNMENT_LEFT,size.x-78,14,color)
