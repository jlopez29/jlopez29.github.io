extends Control
var result_text := "":
	set(value):
		if result_text==value: return
		result_text=value
		queue_redraw()
var skin: StyleBoxFlat
var ticket_id := "":
	set(value):
		ticket_id=value
		queue_redraw()
var caption := "":
	set(value):
		caption=value
		queue_redraw()
func _ready() -> void:
	custom_minimum_size=Vector2(0,126)
	mouse_filter=MOUSE_FILTER_IGNORE
	skin=preload("res://scripts/pit_boss_theme.gd").box(Color("4b2930"),Color("e3bb70"),12)
	resized.connect(queue_redraw)
func _draw() -> void:
	var gold := Color("e3bb70")
	var rect := Rect2(Vector2(4,4),size-Vector2(8,8))
	if skin==null: return
	draw_style_box(skin,rect)
	for y in range(14,int(size.y)-10,12): draw_circle(Vector2(size.x-32,y),2,gold)
	draw_circle(Vector2(26,25),8,gold)
	draw_string(ThemeDB.fallback_font,Vector2(44,32),caption,HORIZONTAL_ALIGNMENT_LEFT,size.x-90,18,gold)
	draw_string(ThemeDB.fallback_font,Vector2(20,70),"TICKET "+ticket_id,HORIZONTAL_ALIGNMENT_LEFT,size.x-64,16,Color("fff0d0"))

	if not result_text.is_empty():
		draw_rect(Rect2(16,83,size.x-64,30),Color("8cd1aa"),false,2)
		draw_string(ThemeDB.fallback_font,Vector2(24,105),result_text,HORIZONTAL_ALIGNMENT_LEFT,size.x-80,18,Color("a5d6ac"))
