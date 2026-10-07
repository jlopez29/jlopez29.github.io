extends Control
var ticket_id := ""
var caption := ""
var elapsed := 0.0
func _ready() -> void:
	custom_minimum_size=Vector2(0,100)
	mouse_filter=MOUSE_FILTER_IGNORE
func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	elapsed+=delta
	queue_redraw()
func _draw() -> void:
	var gold := Color("e3bb70")
	var rect := Rect2(Vector2(4,4),size-Vector2(8,8))
	draw_style_box(preload("res://scripts/pit_boss_theme.gd").box(Color("4b2930"),gold,12),rect)
	for y in range(14,int(size.y)-10,12): draw_circle(Vector2(size.x-32,y),2,gold)
	draw_circle(Vector2(26,25),8+sin(elapsed*2),gold)
	draw_string(ThemeDB.fallback_font,Vector2(44,32),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-90,18,gold)
	draw_string(ThemeDB.fallback_font,Vector2(20,70),"TICKET "+ticket_id,HORIZONTAL_ALIGNMENT_LEFT,size.x-64,16,Color("fff0d0"))
