extends VBoxContainer
signal worker_dropped(index: int)
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.has("worker")
func _drop_data(_at: Vector2, data: Variant) -> void:
	worker_dropped.emit(int(data.worker))
