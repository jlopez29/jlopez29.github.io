extends Control
## Presentation only: no model reference and no reward mutation.
var caption := "VERIFIED"
var success := true
var imprint := 0.0:
	set(value):
		imprint=value
		queue_redraw()
var animation: Tween
func _ready() -> void:
	custom_minimum_size=Vector2(0,40)
	mouse_filter=MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)
	visibility_changed.connect(func():
		if not is_visible_in_tree() and animation: animation.kill())
func stamp(ok: bool, title: String) -> void:
	success=ok
	caption=title
	show()
	if animation: animation.kill()
	imprint=0.0
	animation=create_tween()
	animation.tween_property(self,"imprint",1.0,0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
func _draw() -> void:
	var color := Color("8cd1aa") if success else Color("efc27b")
	color.a=clampf(imprint,0,1)
	var width := minf(size.x-4,330)
	var rect := Rect2(Vector2((size.x-width)/2,3),Vector2(width,34)).grow((1-imprint)*5)
	draw_rect(rect,color,false,2)
	draw_rect(rect.grow(-4),color,false,1)
	draw_string(get_theme_font("font"),rect.position+Vector2(8,24),caption,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-16,20,color)
