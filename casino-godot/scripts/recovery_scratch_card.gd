extends Control
signal scratched
var erased := {}
var dragging := false
var complete := false
var skin: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(0,150)
	mouse_filter = MOUSE_FILTER_STOP
	skin=preload("res://scripts/pit_boss_theme.gd").box(Color("652b38"),Color("e3bb70"),12)
	resized.connect(queue_redraw)

func _gui_input(event: InputEvent) -> void:
	if complete: return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION: return
	var at := Vector2.ZERO
	var rub := false
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
		dragging = event.pressed
		at = event.position; rub = dragging
	elif event is InputEventMouseMotion:
		at = event.position; rub = dragging
	elif event is InputEventScreenTouch:
		dragging=event.pressed
		at = event.position; rub = dragging
	elif event is InputEventScreenDrag:
		at = event.position; rub = dragging
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

func reset_after_failure() -> void:
	complete=false
	dragging=false
	erased.clear()
	queue_redraw()

func _draw() -> void:
	if skin==null: return
	draw_style_box(skin,Rect2(Vector2.ZERO,size))
	var font := ThemeDB.fallback_font
	draw_string(font,Vector2(16,78),"TICKET / READY FOR SAVED REVEAL",HORIZONTAL_ALIGNMENT_LEFT,size.x-32,16,Color("e3bb70"))
	for y in range(5):
		for x in range(12):
			if not erased.has(y*12+x): draw_rect(Rect2(Vector2(x*size.x/12,y*size.y/5),Vector2(size.x/12+1,size.y/5+1)),Color("a6aaa8") if (x+y)%2 else Color("bdc0b9"))
	for y in range(40,int(size.y)-8,12):
		draw_line(Vector2(8,y),Vector2(size.x-8,y),Color(1,1,1,0.09))
	draw_rect(Rect2(10,size.y-16,(size.x-20)*minf(1,erased.size()/36.0),6),Color("e3bb70"))
	draw_string(font,Vector2(16,28),"RUB TO REVEAL / %d%%" % mini(100,int(erased.size()*100/36)),HORIZONTAL_ALIGNMENT_LEFT,size.x-32,13,Color("fff0d0"))
