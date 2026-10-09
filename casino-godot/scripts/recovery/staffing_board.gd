extends VBoxContainer
signal worker_dropped(index: int)
func _ready() -> void:
	add_theme_constant_override("separation",10)
func add_lane(title: String) -> Control:
	var lane := preload("res://scripts/recovery/shift_lane.gd").new()
	lane.title=title
	add_child(lane)
	return lane
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("worker") is int and data.worker>=0 and data.worker<4
func _drop_data(_at: Vector2, data: Variant) -> void:
	if _can_drop_data(_at,data): worker_dropped.emit(int(data.worker))
