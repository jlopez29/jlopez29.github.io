extends RefCounted
# One presentation palette and shared skins for the production interface.
const GOLD := Color("d4af37")
const TEXT := Color("eae4d6")
const MUTED := Color("9ca3af")
const ROOT := "res://assets/pit_boss/"
static var textures := {}

static func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path] = load(ROOT + path)
	return textures[path]

static func box(bg: Color = Color("1b1f24"), border: Color = Color("45413a"), margin: int = 12) -> StyleBoxFlat:
	var skin := StyleBoxFlat.new()
	skin.bg_color = bg
	skin.border_color = border
	skin.set_border_width_all(1)
	skin.set_corner_radius_all(10)
	skin.content_margin_left = margin
	skin.content_margin_right = margin
	skin.content_margin_top = margin
	skin.content_margin_bottom = margin
	return skin

static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	for type in ["Label", "Button", "MenuButton", "CheckButton", "PopupMenu"]:
		theme.set_color("font_color", type, TEXT)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := Color("242e36")
		if state == "hover": bg = Color("343c42")
		if state == "pressed": bg = Color("544624")
		if state == "disabled": bg = Color("16191c")
		theme.set_stylebox(state, "Button", box(bg, GOLD if state in ["pressed", "focus"] else Color("45413a"), 10))
	theme.set_color("font_disabled_color", "Button", Color("686c70"))
	theme.set_stylebox("panel", "PanelContainer", box())
	theme.set_stylebox("panel", "PopupMenu", box())
	theme.set_stylebox("panel", "TooltipPanel", box(Color("0e0f10"), GOLD))
	return theme

static func decorate(button: Button, title: String) -> void:
	var icon := ""
	if "Build" in title: icon = "navigation/build"
	elif "Staff" in title: icon = "navigation/staff"
	elif title == "Finance": icon = "navigation/finance"
	elif title == "Log": icon = "navigation/events"
	elif "Move" in title: icon = "gameplay/move"
	elif "Upgrade" in title: icon = "gameplay/upgrade"
	elif title == "Pause": icon = "gameplay/pause"
	elif title == "Floor": icon = "gameplay/spade"
	button.icon = texture("icons/" + icon + ".svg") if not icon.is_empty() else null
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 20)
