extends Control
signal scratched
var erased := {}
var dragging := false
var complete := false

func _ready() -> void:
	custom_minimum_size = Vector2(0,150)
	mouse_filter = MOUSE_FILTER_STOP

func _gui_input(event: InputEvent) -> void:
	if complete: return
	var at := Vector2.ZERO
	var rub := false
	if event is InputEventMouseButton:
		dragging = event.pressed
		at = event.position; rub = dragging
	elif event is InputEventMouseMotion:
		at = event.position; rub = dragging
	elif event is InputEventScreenTouch:
		at = event.position; rub = event.pressed
	elif event is InputEventScreenDrag:
		at = event.position; rub = true
	if not rub: return
	var col := clampi(int(at.x / maxf(1,size.x) * 12),0,11)
	var row := clampi(int(at.y / maxf(1,size.y) * 5),0,4)
	for x in range(maxi(0,col-1),mini(12,col+2)):
		for y in range(maxi(0,row-1),mini(5,row+2)): erased[y*12+x] = true
	queue_redraw()
	accept_event()
	if erased.size() >= 36:
		complete = true
		scratched.emit()

func _draw() -> void:
	draw_style_box(preload("res://scripts/pit_boss_theme.gd").box(Color("652b38"),Color("e3bb70"),12),Rect2(Vector2.ZERO,size))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(16,78),"FREE TRAINING REWARD",HORIZONTAL_ALIGNMENT_LEFT,size.x-32,16,Color("e3bb70"))
	for y in range(5):
		for x in range(12):
			if not erased.has(y*12+x): draw_rect(Rect2(Vector2(x*size.x/12,y*size.y/5),Vector2(size.x/12+1,size.y/5+1)),Color("94908a"))
	draw_string(font,Vector2(16,28),"SCRATCH HERE / OR REVEAL BELOW",HORIZONTAL_ALIGNMENT_LEFT,size.x-32,13,Color("fff0d0"))
