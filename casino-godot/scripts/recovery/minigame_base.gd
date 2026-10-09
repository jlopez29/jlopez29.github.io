extends VBoxContainer
const UI = preload("res://scripts/recovery/workbench_ui.gd")
var puzzle: Dictionary
var draft: Dictionary
func setup(case_data: Dictionary, temporary: Dictionary) -> void:
	puzzle = case_data
	draft = temporary
	size_flags_horizontal = SIZE_EXPAND_FILL
	add_theme_constant_override("separation", 12)
	build()
func build() -> void: pass
func response() -> Dictionary: return draft.duplicate(true)
func lesson(value: String) -> void:
	var help := UI.card(self, Color("252b30"))
	var words := UI.text(help, value)
	words.hide()
	UI.button(help, "How this works / example", func(): words.visible = not words.visible)
