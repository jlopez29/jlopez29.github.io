extends BoxContainer
## Content-driven Finance reflow. Currency labels retain their intrinsic width.
## Start stacked so minimum sizes cannot force a narrow inspector wider.

var fit_header: bool = false

func _init() -> void:
	vertical = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 8)

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or not is_inside_tree(): return
	var needed := float(maxi(0, get_child_count() - 1) * get_theme_constant("separation"))
	for child in get_children():
		if child is Label:
			# Measure the full label, rather than its wrapped minimum width.
			needed += child.get_theme_font("font").get_string_size(child.text, HORIZONTAL_ALIGNMENT_LEFT, -1, child.get_theme_font_size("font_size")).x
		elif child is Control:
			needed += child.get_combined_minimum_size().x
	vertical = size.x < ceilf(needed)
	if get_child_count() == 2 and get_child(1) is Label:
		get_child(1).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if vertical else HORIZONTAL_ALIGNMENT_RIGHT
	if fit_header:
		# A Button does not include anchored children in its minimum size.
		# Include the actual row plus the surrounding MarginContainer padding.
		var margin := get_parent() as MarginContainer
		var header := margin.get_parent() as Button
		var padding := margin.get_theme_constant("margin_top") + margin.get_theme_constant("margin_bottom")
		header.custom_minimum_size.y = maxf(50, get_combined_minimum_size().y + padding)
