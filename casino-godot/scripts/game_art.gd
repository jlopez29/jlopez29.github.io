extends Control
# Shared asset-backed drawing helpers. No outcome generation or settlement.
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const Games = preload("res://scripts/casino_games.gd")
const GOLD := Color("e6c888")
var kind := "slots"
var round := {}
var spinning := 0.0
var duration := 1.0
var font: Font
func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = MOUSE_FILTER_IGNORE
	clip_contents = true
func _process(delta: float) -> void:
	if not is_visible_in_tree() or spinning <= 0: return
	spinning = maxf(0, spinning - delta)
	queue_redraw()
func animate(seconds: float) -> void:
	duration = seconds
	spinning = seconds
	queue_redraw()
func text(at: Vector2, value: String, fs: int = 18, color: Color = GOLD) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
func centered(at: Vector2, value: String, fs: int = 18, color: Color = GOLD) -> void:
	text(at - Vector2(font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 0), value, fs, color)
func panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	draw_style_box(PitBoss.box(color, Color("92743b"), 0), rect)
func image(path: String, rect: Rect2) -> void:
	draw_texture_rect(PitBoss.texture("casino_play/" + path), rect, false)
func stack(at: Vector2, amount: float, radius: float = 24) -> void:
	var denomination := 1
	for value in [1, 5, 25, 100, 500, 1000]:
		if amount >= value: denomination = value
	image("shared/chips/chip_%d.svg" % denomination, Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2))
