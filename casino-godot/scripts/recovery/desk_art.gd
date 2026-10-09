extends Control
## Lightweight desk silhouettes; no animation or economic state.
var category := 0
func _ready() -> void:
	custom_minimum_size=Vector2(0,90)
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	get_viewport().size_changed.connect(reflow)
	reflow()
func reflow() -> void:
	visible=get_viewport_rect().size.y>=600
	custom_minimum_size.y=60 if get_viewport_rect().size.x<600 else 90
func _draw() -> void:
	var gold := Color("d4af37")
	var paper := Color("ded2b7")
	var center := size/2
	match category:
		0:
			for i in range(3):
				var at := center+Vector2((i-1)*72-25,-34)
				draw_rect(Rect2(at,Vector2(50,68)),paper)
				for j in range(4): draw_line(at+Vector2(8,18+j*10),at+Vector2(42,18+j*10),Color("635c4f"),2)
			for i in range(4): draw_circle(center+Vector2(100-i*7,26-i*4),10,gold)
		1:
			draw_line(center+Vector2(-100,0),center+Vector2(100,0),gold,2)
			for i in range(3):
				var at := center+Vector2((i-1)*80,0)
				draw_circle(at,22,Color("59636b"))
				draw_arc(at,18,0,TAU,32,paper,2)
				draw_line(at,at+Vector2(0,-12),paper,2)
				draw_line(at,at+Vector2(10,6),paper,2)
		2:
			draw_style_box(preload("res://scripts/pit_boss_theme.gd").box(Color("202b33"),gold,0),Rect2(center-Vector2(120,38),Vector2(240,76)))
			for i in range(3):
				var at := center+Vector2((i-1)*65,0)
				draw_line(at-Vector2(0,24),at+Vector2(0,22),gold,3)
				draw_circle(at-Vector2(0,22),8,Color("a5d6ac"))
				draw_rect(Rect2(at-Vector2(12,0),Vector2(24,26)),paper)
		3:
			for i in range(3):
				var y := center.y-28+i*25
				draw_line(Vector2(center.x-115,y),Vector2(center.x+115,y),gold,2)
				for j in range(3): draw_rect(Rect2(Vector2(center.x-100+j*74,y-10),Vector2(40,18)),Color("708a76"))
