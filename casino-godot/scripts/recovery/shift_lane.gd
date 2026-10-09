extends Control
## Assigned worker magnets remain visible in every covered shift.
var title := ""
var required := 0
var assigned := 0
var badges: Array[int] = []
var skin: StyleBoxFlat
func _ready() -> void:
	custom_minimum_size=Vector2(0,112)
	mouse_filter=MOUSE_FILTER_PASS
	skin=preload("res://scripts/pit_boss_theme.gd").box(Color("263a32"),Color("817454"),0)
	resized.connect(queue_redraw)
func set_coverage(need: int, count: int, workers: Array[int]) -> void:
	required=need
	assigned=count
	badges=workers
	queue_redraw()
func _draw() -> void:
	if skin==null: return
	draw_style_box(skin,Rect2(Vector2.ZERO,size))
	var font := get_theme_font("font")
	var color := Color("a5d6ac") if assigned>=required else Color("efc27b")
	draw_string(font,Vector2(12,25),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-24,18,Color("eee3ce"))
	draw_string(font,Vector2(12,49),"Need %d / Assigned %d / %s" % [required,assigned,"COVERED" if assigned>=required else "NEEDS STAFF"],HORIZONTAL_ALIGNMENT_LEFT,size.x-24,15,color)
	if badges.is_empty():
		draw_string(font,Vector2(12,87),"Drop or tap worker badges below",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,14,Color("c2beab"))
	for i in range(badges.size()):
		var at := Vector2(13+i*57,62)
		draw_rect(Rect2(at,Vector2(46,38)),Color("d5c79e"))
		draw_circle(at+Vector2(23,3),4,Color("b98643"))
		draw_string(font,at+Vector2(12,28),char(65+badges[i]),HORIZONTAL_ALIGNMENT_CENTER,22,22,Color("223b32"))
