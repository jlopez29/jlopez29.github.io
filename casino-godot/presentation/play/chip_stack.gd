extends RefCounted
## Drawing only. Layer count illustrates a stack; the total is the actual money.
const Art = preload("res://scripts/pit_boss_theme.gd")
const Money = preload("res://scripts/financial_text.gd")
const DENOMINATIONS := [1, 5, 25, 100, 500, 1000]
const COLORS := [Color("ead189"), Color("72aaff"), Color("ee88be"), Color("82d890"), Color("ba96ec"), Color("ed9974"), Color("77d6d9"), Color("e5e8ef")]

static func seat_color(seat: int) -> Color:
	return COLORS[clampi(seat + 1, 0, COLORS.size() - 1)]

static func draw_stack(canvas: Control, at: Vector2, amount: float, radius: float = 19, marker: Color = Color.TRANSPARENT, total: bool = true, well: bool = false) -> void:
	if amount <= 0: return
	var denomination := 1
	for value in DENOMINATIONS:
		if amount >= value: denomination = value
	var layers := 4 if well else clampi(ceili(amount / denomination), 1, 6)
	canvas.draw_circle(at + Vector2(2, 5), radius + 3, Color(0, 0, 0, 0.3))
	var texture := Art.texture("casino_play/shared/chips/chip_%d.svg" % denomination)
	for layer in range(layers):
		var center := at - Vector2(0, layer * maxf(2, radius * 0.15))
		canvas.draw_circle(center + Vector2(0, 2), radius, Color("353941"))
		for stripe in range(8):
			var angle := stripe * TAU / 8
			canvas.draw_arc(center + Vector2(0, 2), radius - 1, angle, angle + 0.18, 4, Color("e6dfc9"), 2)
		canvas.draw_texture_rect(texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	if marker.a > 0:
		canvas.draw_circle(at + Vector2(radius + 4, 0), 4, marker)
	if total:
		var font := ThemeDB.fallback_font
		var value := Money.cash(amount, 2 if not is_equal_approx(amount, roundf(amount)) else 0)
		var fs := 12 if radius < 20 else 16
		var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var label_at := at + Vector2(-width / 2, radius + fs + 3)
		canvas.draw_rect(Rect2(label_at + Vector2(-3, -fs), Vector2(width + 6, fs + 4)), Color(0.04, 0.08, 0.07, 0.9))
		canvas.draw_string(font, label_at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff3d1"))

static func avatar(canvas: Control, at: Vector2, seat: int, radius: float = 20) -> void:
	var color := seat_color(seat)
	canvas.draw_circle(at, radius, Color("17282b"))
	canvas.draw_arc(at, radius, 0, TAU, 32, color, 2)
	canvas.draw_circle(at - Vector2(0, radius * 0.32), radius * 0.28, Color("e3bb94"))
	canvas.draw_arc(at + Vector2(0, radius * 0.52), radius * 0.50, PI, TAU, 16, color, radius * 0.40)
