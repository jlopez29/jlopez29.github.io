extends Button
## Object surfaces retain native keyboard, focus, pointer and touch activation.
const ObjectTheme = preload("res://scripts/pit_boss_theme.gd")
var kind := "folder"
var serial := "A"
var heading := ""
var detail := ""
var footer := ""
var selected := false:
	set(value):
		if selected == value: return
		selected = value
		queue_redraw()
var hover := false
var press_depth := 0.0:
	set(value):
		press_depth=value
		queue_redraw()
var motion: Tween
var surface: StyleBoxFlat
var inset: StyleBoxFlat
func _ready() -> void:
	custom_minimum_size.y = {"receipt":154,"folder":72,"stamp":68,"module":100,"rocker":120,"token":64,"worker":108,"tray":82}.get(kind,72)
	size_flags_horizontal=SIZE_EXPAND_FILL
	clip_text=true
	for state in ["normal","hover","pressed","focus","disabled"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	for color_key in ["font_color","font_hover_color","font_pressed_color","font_focus_color","font_disabled_color","font_outline_color"]:
		add_theme_color_override(color_key,Color.TRANSPARENT)
	surface=ObjectTheme.box(Color("39332a"),Color("88754e"),0)
	inset=ObjectTheme.box(Color("151e20"),Color("77756a"),0)
	resized.connect(queue_redraw)
	mouse_entered.connect(func(): hover=true; queue_redraw())
	mouse_exited.connect(func(): hover=false; queue_redraw())
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	button_down.connect(func(): animate_press(3.0))
	button_up.connect(func(): animate_press(0.0))
	visibility_changed.connect(func():
		if not is_visible_in_tree() and motion: motion.kill(); press_depth=0)
func animate_press(depth: float) -> void:
	if motion: motion.kill()
	motion=create_tween()
	motion.tween_property(self,"press_depth",depth,0.10)
func words(value: String, at: Vector2, width: float, points: int, color: Color) -> void:
	draw_string(get_theme_font("font"),at,value,HORIZONTAL_ALIGNMENT_LEFT,maxf(1,width),points,color)
func _draw() -> void:
	if surface==null: return
	var brass := Color("d8bb78")
	var ink := Color("302b23")
	var paper := Color("eee0bc")
	var light := Color("f0e7d4")
	var rect := Rect2(Vector2(3,5+press_depth),size-Vector2(6,10))
	var y := rect.position.y
	surface.bg_color=Color("4b4734") if selected else Color("36332c")
	surface.border_color=brass if selected or hover else Color("796b4f")
	if kind!="token": draw_style_box(surface,rect)
	match kind:
		"receipt":
			draw_rect(rect,paper)
			for x in range(6,int(size.x)-5,12):
				draw_colored_polygon(PackedVector2Array([Vector2(x,y+rect.size.y),Vector2(x+6,y+rect.size.y-5),Vector2(x+12,y+rect.size.y)]),Color("1b2524"))
			words("CAGE / RECEIPT "+serial,Vector2(16,y+26),size.x-32,17,ink)
			for x in range(16,int(size.x)-16,8): draw_line(Vector2(x,y+38),Vector2(x+4,y+38),Color("9b8964"))
			words(heading,Vector2(16,y+66),size.x-32,19,ink)
			words(detail,Vector2(16,y+94),size.x-32,19,ink)
			words("PINNED TO LEDGER" if selected else "SERIAL "+serial+" / TAP TO PIN",Vector2(16,y+123),size.x-32,13,Color("476148"))
		"token":
			var center := Vector2(size.x/2,size.y/2+press_depth)
			var radius := minf(28,size.x/2-4)
			draw_circle(center,radius,Color("ad9158"))
			draw_circle(center,radius-4,Color("28483e"))
			for i in range(8):
				var ray := Vector2.from_angle(i*TAU/8)
				draw_line(center+ray*(radius-3),center+ray*(radius-9),paper,3)
			draw_string(get_theme_font("font"),center+Vector2(-radius+3,6),heading,HORIZONTAL_ALIGNMENT_CENTER,radius*2-6,17,light)
		"folder":
			draw_rect(Rect2(12,y,78,18),Color("bea36a"))
			words("FILE "+serial,Vector2(18,y+14),70,12,ink)
			words(heading,Vector2(18,y+35),size.x-36,19,light)
			words("OPEN / INVESTIGATING" if selected else detail,Vector2(18,y+55),size.x-36,13,brass)
		"stamp":
			var stamp := rect.grow(-7)
			draw_rect(stamp,Color("163b33") if selected else Color("312b29"))
			draw_rect(stamp,brass if selected else Color("a99175"),false,2)
			words(heading,Vector2(18,y+29),size.x-36,17,light)
			words(footer if selected else "ATTACH EVIDENCE",Vector2(18,y+45),size.x-36,13,brass)
		"module":
			for x in [12.0,size.x-12]:
				for sy in [y+10,y+rect.size.y-10]:
					draw_circle(Vector2(x,sy),3,Color("91968e"))
			for i in range(5): draw_line(Vector2(18+i*8,y+64),Vector2(18+i*8,y+82),Color("101917"),3)
			draw_circle(Vector2(size.x-25,y+72),6,Color("d8aa60") if serial=="C" else Color("89ba98"))
			words(heading,Vector2(20,y+32),size.x-40,18,light)
			words(detail,Vector2(20,y+53),size.x-40,14,brass)
		"rocker":
			var center := size.x/2
			words(serial,Vector2(12,y+24),size.x-24,20,brass)
			var housing := Rect2(center-23,y+31,46,52)
			draw_style_box(inset,housing)
			draw_rect(Rect2(center-18,y+35+(0 if selected else 23),36,21),Color("668e76") if selected else Color("878b81"))
			draw_line(Vector2(center-11,y+46+(0 if selected else 23)),Vector2(center+11,y+46+(0 if selected else 23)),paper,2)
			words("ON / 1" if selected else "OFF / 0",Vector2(12,y+102),size.x-24,16,light)
		"worker":
			draw_circle(Vector2(31,y+26),10,brass)
			draw_circle(Vector2(31,y+44),15,Color("6b8270"))
			draw_rect(Rect2(17,y+48,28,10),surface.bg_color)
			words(heading,Vector2(60,y+31),size.x-76,20,light)
			words(detail,Vector2(16,y+72),size.x-32,16,brass)
			words("ASSIGNED / TAP TO REMOVE" if selected else "DRAG OR TAP TO ASSIGN",Vector2(16,y+92),size.x-32,12,light)
		"tray":
			for i in range(3):
				draw_rect(Rect2(14+i*4,y+16-i*3,38,40),paper)
				draw_line(Vector2(20+i*4,y+25-i*3),Vector2(45+i*4,y+25-i*3),ink,2)
			words(heading,Vector2(72,y+32),size.x-88,18,brass)
			words(detail,Vector2(72,y+57),size.x-88,15,light)
	if selected or has_focus():
		draw_rect(rect.grow(-2),brass,false,2)
	if has_focus(): draw_rect(rect.grow(-5),light,false,1)
