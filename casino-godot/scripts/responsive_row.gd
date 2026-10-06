extends BoxContainer
## Reflow action rows from their content width, including clipped Button text.

static func content_width(child: Control) -> float:
	var needed := child.get_combined_minimum_size().x
	if child is Button or child is Label:
		var font := child.get_theme_font("font")
		var font_size := child.get_theme_font_size("font_size")
		for line in child.text.split("\n"):
			var width := font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			if child is Button:
				width += child.get_theme_stylebox("normal").get_minimum_size().x
			needed = maxf(needed, width)
	return needed

func _init() -> void:
	vertical = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or not is_inside_tree(): return
	var needed := float(maxi(0, get_child_count() - 1) * get_theme_constant("separation"))
	for child in get_children():
		if child is Control: needed += content_width(child)
	vertical = size.x < ceilf(needed)
