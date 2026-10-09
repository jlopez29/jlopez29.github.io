extends Button
const UI = preload("res://scripts/recovery/workbench_ui.gd")
var category := 0
var status: Label
var skin: StyleBoxFlat
func _ready() -> void:
	size_flags_horizontal=SIZE_EXPAND_FILL
	custom_minimum_size.y=248
	skin=UI.WorkbenchTheme.box(Color("2c3028"),Color("89764f"),14)
	add_theme_stylebox_override("normal",skin)
	add_theme_stylebox_override("hover",UI.WorkbenchTheme.box(Color("3a4235"),UI.WorkbenchTheme.GOLD,14))
	add_theme_stylebox_override("pressed",UI.WorkbenchTheme.box(Color("4b4734"),UI.WorkbenchTheme.GOLD,14))
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,16)
	add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",8)
	margin.add_child(stack)
	var art := preload("res://scripts/recovery/desk_art.gd").new()
	art.category=category
	stack.add_child(art)
	var title: String=["Cage ledger","Security case desk","Slot service console","Shift staffing board"][category]
	UI.text(stack,title,21)
	UI.text(stack,["Pin receipts. Count the discrepancy.","Compare documents. Attach evidence.","Inspect modules. Tune test outputs.","Assign workers. Clear the aisle."][category],16)
	status=UI.text(stack,"AVAILABLE / OPEN",17)
	ignore_pointer(margin)
	text=""
	tooltip_text=title+" / Open workstation"
func ignore_pointer(node: Control) -> void:
	node.mouse_filter=MOUSE_FILTER_IGNORE
	for child in node.get_children():
		if child is Control: ignore_pointer(child)
func set_status(value: String, verified: bool) -> void:
	if status.text==value: return
	status.text=value
	status.add_theme_color_override("font_color",Color("a5d6ac") if verified else Color("dfc58c"))
	if verified:
		status.add_theme_stylebox_override("normal",UI.WorkbenchTheme.box(Color("183d32"),Color("87b899"),6))
