extends GridContainer
## Keep category and wager targets readable without forcing inspector overflow.
const ResponsiveRow = preload("res://scripts/responsive_row.gd")
var maximum_columns := 2

func _init() -> void:
	columns = 1
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

func _notification(what: int) -> void:
	if what != NOTIFICATION_SORT_CHILDREN or not is_inside_tree(): return
	var widest := 100.0
	for child in get_children():
		if child is Control: widest = maxf(widest, ResponsiveRow.content_width(child))
	var gap := get_theme_constant("h_separation")
	columns = clampi(floori((size.x + gap) / (widest + gap)), 1, maximum_columns)
