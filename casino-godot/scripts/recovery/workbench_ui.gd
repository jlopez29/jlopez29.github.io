extends RefCounted
const WorkbenchTheme = preload("res://scripts/pit_boss_theme.gd")
static func text(parent: Node, value: String, font_size: int = 17) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label
static func button(parent: Node, value: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 17)
	button.pressed.connect(func(): AudioManager.play_ui("confirm"); action.call())
	parent.add_child(button)
	return button
static func card(parent: Node, color: Color = Color("16332f")) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", WorkbenchTheme.box(color, Color("766342"), 14))
	parent.add_child(panel)
	var stack := VBoxContainer.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_theme_constant_override("separation", 10)
	panel.add_child(stack)
	return stack
static func clock(seconds: int) -> String:
	seconds = maxi(0, seconds)
	return "%02d:%02d:%02d" % [seconds/3600,(seconds/60)%60,seconds%60]
static func mark(button: Button, selected: bool) -> void:
	button.add_theme_stylebox_override("normal", WorkbenchTheme.box(Color("514526") if selected else Color("242e36"), WorkbenchTheme.GOLD if selected else Color("45413a"), 10))
