extends PanelContainer
signal changed
signal speed_requested(multiplier: int)
signal session_reset
const Actions = preload("res://scripts/developer_actions.gd")
var actions: RefCounted
var feedback: Label
var momentum_status: Label
var momentum_refresh := 0.0

func _init(simulation: CasinoSimulation) -> void:
	actions = Actions.new(simulation)

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	z_index = 100
	var box := StyleBoxFlat.new()
	box.bg_color = Color("14232f")
	box.border_color = Color("e3bb70")
	box.set_border_width_all(2)
	box.content_margin_left = 12
	box.content_margin_right = 12
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	add_theme_stylebox_override("panel", box)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 8)
	scroll.add_child(content)
	var title := Label.new()
	title.text = "DEV MODE | F10 to close"
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	feedback = Label.new()
	feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feedback.text = actions.message
	content.add_child(feedback)
	momentum_status = Label.new()
	momentum_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(momentum_status)
	var speeds := preload("res://scripts/responsive_grid.gd").new()
	speeds.maximum_columns = 2
	content.add_child(speeds)
	for multiplier in [1, 4, 100, 1000]:
		var button := _add_button(speeds, "%dx" % multiplier, func(): speed_requested.emit(multiplier))
		# Short speed labels must determine button width instead of being clipped.
		button.clip_text = false
		button.custom_minimum_size.x = 64
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_add_button(content, "+$1,000", func(): actions.add_cash(1000))
	_add_button(content, "+$10,000", func(): actions.add_cash(10000))
	_add_button(content, "Advance to Next Unlock", actions.advance_next_unlock)
	var choice := OptionButton.new()
	choice.custom_minimum_size.y = 44
	choice.size_flags_horizontal = SIZE_EXPAND_FILL
	choice.clip_text = true
	choice.fit_to_longest_item = false
	for milestone in actions.sim.progression_targets():
		if milestone.id == "slots": continue
		choice.add_item(str(milestone.name).replace("’", "'"))
		choice.set_item_metadata(choice.item_count - 1, milestone.id)
	content.add_child(choice)
	_add_button(content, "Force Unlock Selected Feature", func(): actions.force_unlock(str(choice.get_item_metadata(choice.selected))))
	_add_button(content, "Rating +1 (prepare development/activity)", actions.rating_plus_one)
	_add_button(content, "Spawn Guest", func(): actions.spawn_guests(1))
	_add_button(content, "Spawn 5 Guests", func(): actions.spawn_guests(5))
	for type in ["floor_tip", "owner_slots", "owner_blackjack", "busy_table", "slot_crowd", "jackpot_celebration", "drink_demand", "service_rush", "staff_fatigue", "machine_repair", "guest_complaint", "management_sample", "emergency_sample"]:
		_add_button(content, "DEV event: " + type, func(): actions.sample_event(type))
	_add_button(content, "DEV: Offer eligible goal", actions.offer_objective)
	_add_button(content, "DEV owner $100 win", actions.sample_owner_win)
	_add_button(content, "Close Panel", func(): hide())
	minimum_size_changed.connect(func(): call_deferred("_layout"))
	get_viewport().size_changed.connect(_layout)
	_layout()

func _add_button(parent: Node, text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_to_group("debug_buttons")
	button.clip_text = true
	button.custom_minimum_size.y = 44
	button.pressed.connect(func():
		if not OS.is_debug_build(): return
		action.call()
		feedback.text = actions.message
		changed.emit())
	parent.add_child(button)
	return button

func _layout() -> void:
	var viewport_size := get_viewport_rect().size
	size = Vector2(minf(370, viewport_size.x - 24), maxf(100, minf(565, viewport_size.y - 64)))
	position = Vector2(maxf(12, viewport_size.x - size.x - 12), 56)

func reset_session(simulation: CasinoSimulation) -> void:
	if not OS.is_debug_build(): return
	actions = Actions.new(simulation)
	session_reset.emit()
	if is_instance_valid(feedback): feedback.text = actions.message
	hide()

func _process(delta: float) -> void:
	if not visible or not is_instance_valid(momentum_status): return
	momentum_refresh -= delta
	if momentum_refresh > 0: return
	momentum_refresh = 1.0
	var text: String = actions.sim.momentum.detail()
	if momentum_status.text != text: momentum_status.text = text
