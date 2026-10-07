extends Control
var active_lines := 1

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	resized.connect(func():
		custom_minimum_size.y = 90 if size.x >= 560 else 170
		queue_redraw())
	custom_minimum_size.y = 90

func _draw() -> void:
	var columns := 5 if size.x >= 560 else 3
	var width := size.x / columns
	for i in range(5):
		var origin := Vector2((i % columns)*width + 12, (i / columns)*80 + 12)
		var cell := Vector2(minf(25,(width-24)/3),14)
		for row in range(3):
			for col in range(3): draw_rect(Rect2(origin + Vector2(col,row)*cell,cell-Vector2.ONE*2),Color("3c4149"))
		var path: Array = CasinoTuning.SLOT_LINES[i]
		var color := Color("ffd879") if i < active_lines else Color("777e89")
		for col in range(2):
			draw_line(origin+Vector2(col+0.5,path[col]+0.5)*cell,origin+Vector2(col+1.5,path[col+1]+0.5)*cell,color,2,true)
		draw_string(ThemeDB.fallback_font,origin+Vector2(0,60),["1 Center","2 Top","3 Bottom","4 V","5 Inverted V"][i],HORIZONTAL_ALIGNMENT_LEFT,-1,12,color)
