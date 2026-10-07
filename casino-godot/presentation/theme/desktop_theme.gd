extends RefCounted
const Art = preload("res://scripts/pit_boss_theme.gd")

static func panel(border: Color = Color("51452b")) -> StyleBoxFlat:
	var skin := Art.box(Color("101315"), border, 14)
	skin.shadow_color = Color(0, 0, 0, 0.5)
	skin.shadow_size = 12
	skin.shadow_offset = Vector2(0, 5)
	return skin

static func luxury_panel() -> StyleBoxTexture:
	var skin := StyleBoxTexture.new()
	skin.texture = Art.texture("ui/panels/panel_luxury.svg")
	skin.modulate_color = Color(0.52, 0.52, 0.52, 1)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		skin.set_texture_margin(side, 24)
		skin.set_content_margin(side, 14)
	return skin

static func create() -> Theme:
	var theme := Art.create()
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("17191a")
		if state == "hover": bg = Color("292720")
		if state == "pressed": bg = Color("46391f")
		if state == "disabled": bg = Color("101214")
		var skin := Art.box(bg, Art.GOLD if state in ["pressed", "focus"] else Color("3e3a30"), 9)
		skin.set_corner_radius_all(6)
		for type in ["Button", "MenuButton"]: theme.set_stylebox(state, type, skin)
	theme.set_stylebox("panel", "PanelContainer", panel())
	theme.set_stylebox("panel", "Panel", panel())
	theme.set_color("font_color", "Button", Art.TEXT)
	theme.set_color("font_hover_color", "Button", Color("fff0cc"))
	theme.set_color("font_pressed_color", "Button", Color("ffe3a0"))
	return theme
