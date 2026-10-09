extends "res://scripts/recovery/object_button.gd"
var worker_index := 0
func _get_drag_data(_at: Vector2) -> Variant:
	var preview := Label.new()
	preview.text="Assign worker "+char(65+worker_index)
	set_drag_preview(preview)
	return {"worker":worker_index}
