extends VBoxContainer
## Paired dispatch/receipt evidence, illustrated without identity-based cues.
var clues: Array = []
func _ready() -> void:
	add_theme_constant_override("separation",8)
	for i in range(clues.size()):
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel",preload("res://scripts/pit_boss_theme.gd").box(Color("25303a"),Color("bd9654"),8))
		add_child(panel)
		var row := HBoxContainer.new()
		panel.add_child(row)
		var seal := Label.new()
		seal.text="%02d\n>" % (i+1)
		seal.add_theme_font_size_override("font_size",20)
		seal.add_theme_color_override("font_color",Color("e3bb70"))
		row.add_child(seal)
		var receipt := Label.new()
		receipt.text=str(clues[i])
		receipt.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		receipt.size_flags_horizontal=SIZE_EXPAND_FILL
		receipt.add_theme_font_size_override("font_size",15)
		row.add_child(receipt)
