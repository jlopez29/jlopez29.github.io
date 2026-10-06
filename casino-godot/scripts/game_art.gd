extends Control
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const Games = preload("res://scripts/casino_games.gd")
var kind := "slots"
var round := {}
var spinning := 0.0
var clock := 0.0
var font: Font
const GOLD := Color("e6c888")

func _ready() -> void:
	font = ThemeDB.fallback_font
	mouse_filter = MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 270

func _process(delta: float) -> void:
	clock += delta
	var was_spinning := spinning > 0
	spinning = maxf(0, spinning - delta)
	if is_visible_in_tree() and was_spinning:
		queue_redraw()

func text(at: Vector2, value: String, fs: int = 18, color: Color = Color.WHITE) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)

func panel(rect: Rect2, color: Color, radius: int = 12) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = GOLD
	style.set_border_width_all(1)
	draw_style_box(style, rect)

func card(at: Vector2, number: int, hidden: bool = false, scale: float = 1) -> void:
	var rank: String = str(number % 13 + 2) if number % 13 < 9 else ["J", "Q", "K", "A"][number % 13 - 9]
	var suit: String = ["spades", "hearts", "diamonds", "clubs"][int(number / 13)]
	var asset: String = "card_back" if hidden else rank + "_" + suit
	draw_texture_rect(PitBoss.texture("casino_play/shared/cards/" + asset + ".svg"), Rect2(at, Vector2(49, 67) * scale), false)
	# Godot's SVG importer omits <text>; keep ranks/suits as native presentation.
	if not hidden:
		var color := Color("72202a") if int(number / 13) in [1, 2] else Color("0e0f10")
		text(at + Vector2(5, 24) * scale, rank, int(20 * scale), color)
		suit_symbol(at + Vector2(25, 46) * scale, int(number / 13), scale, color)


func suit_symbol(center: Vector2, suit: int, scale: float, color: Color) -> void:
	var points := PackedVector2Array()
	if suit == 1: # Heart: two lobes and a tapered point.
		draw_circle(center + Vector2(-5,-4)*scale,6*scale,color)
		draw_circle(center + Vector2(5,-4)*scale,6*scale,color)
		for p in [Vector2(-11,-3),Vector2(11,-3),Vector2(0,11)]: points.append(center+p*scale)
	elif suit == 2:
		for p in [Vector2(0,-12),Vector2(9,0),Vector2(0,12),Vector2(-9,0)]: points.append(center+p*scale)
	else:
		if suit == 0: # Spade.
			draw_circle(center+Vector2(-5,2)*scale,6*scale,color)
			draw_circle(center+Vector2(5,2)*scale,6*scale,color)
			for p in [Vector2(-11,2),Vector2(0,-12),Vector2(11,2)]: points.append(center+p*scale)
		else:
			for p in [Vector2(0,-6),Vector2(-6,2),Vector2(6,2)]: draw_circle(center+p*scale,6*scale,color)
		draw_colored_polygon(PackedVector2Array([center+Vector2(0,2)*scale,center+Vector2(-4,12)*scale,center+Vector2(4,12)*scale]),color)
	if not points.is_empty(): draw_colored_polygon(points,color)

func cards(cards_array: Array, at: Vector2, hidden_after: int = 99) -> void:
	var scale := minf(1, (size.x - 34) / maxf(1, cards_array.size() * 56))
	for i in range(cards_array.size()): card(at + Vector2(i * 56 * scale, 0), int(cards_array[i]), i >= hidden_after or spinning > 0, scale)

func _draw() -> void:
	if font == null: return
	if kind in ["slots", "roulette"]: custom_minimum_size.y = 270
	panel(Rect2(Vector2.ZERO, size), Color("0f493b"), 22)
	if kind == "slots":
		text(Vector2(18, 30), "P I T   B O S S   R E E L S", 22, GOLD)
		var width := (size.x - 48) / 3
		for i in range(3):
			var rect := Rect2(12 + i * (width + 12), 67, width, 118)
			panel(rect, Color("152330"))
			var value := (int(clock * (17 + i * 3)) + i) % 5 if spinning > 0 else int(round.get("reels", [0,3,4])[i])
			var center := rect.get_center()
			if value == 0:
				draw_circle(center + Vector2(-9, 0), 13, Color("d74c65")); draw_circle(center + Vector2(12, 4), 13, Color("d74c65"))
				draw_line(center + Vector2(-9, -10), center + Vector2(4, -29), Color("79c276"), 3)
				draw_line(center + Vector2(12, -8), center + Vector2(4, -29), Color("79c276"), 3)
			else:
				var title: String = ["", "LEMON", "BELL", "BAR", "7"][value]
				text(center + Vector2(-minf(30, width / 2 - 4), 9), title, 30 if value == 4 else 15, GOLD)
		text(Vector2(18, 223), "Spinning…" if spinning > 0 else "ONE PAYLINE  •  THREE REELS", 16, GOLD)
	elif kind == "roulette":
		var center := Vector2(size.x / 2, 134)
		var radius := minf(110, size.x / 2 - 20)
		var angle := clock * 5 if spinning > 0 else 0.0
		draw_set_transform(center, angle)
		draw_texture_rect(PitBoss.texture("casino_play/roulette/roulette_wheel.svg"), Rect2(Vector2.ONE * -radius, Vector2.ONE * radius * 2), false)
		draw_set_transform(Vector2.ZERO)
		# Runtime pockets follow the rules' number/color order, over authored wood.
		for i in range(37):
			var a := i * TAU / 37 - PI / 2 + angle
			var b := (i + 1) * TAU / 37 - PI / 2 + angle
			var pocket: int = Games.WHEEL[i]
			var color := Color("0f5132") if pocket == 0 else Color("72202a") if pocket in Games.RED else Color("0e0f10")
			draw_colored_polygon(PackedVector2Array([center + Vector2.from_angle(a) * radius * 0.46, center + Vector2.from_angle(a) * radius * 0.78, center + Vector2.from_angle(b) * radius * 0.78, center + Vector2.from_angle(b) * radius * 0.46]), color)
			var at := center + Vector2.from_angle((i + 0.5) * TAU / 37 - PI / 2 + angle) * (radius * 0.73)
			text(at - Vector2(4, -3), str(Games.WHEEL[i]), 8)
		var number := int(round.get("number", 0))
		var ball_angle := -clock * 9 if spinning > 0 else (Games.WHEEL.find(number) + 0.5) * TAU / 37 - PI / 2
		draw_circle(center + Vector2.from_angle(ball_angle) * (radius * 0.64), 5, Color.WHITE)
		text(center + Vector2(-15, 9), "…" if spinning > 0 else str(number), 29)
	else:
		var done: bool = round.get("phase", "") == "done"
		text(Vector2(16, 25), "DEALER", 13, GOLD)
		if round.is_empty():
			text(Vector2(18, 110), "Place your wager to deal.", 20, GOLD)
			return
		cards(round.dealer, Vector2(16, 36), 99 if done else (1 if kind == "blackjack" else 0))
		if kind == "holdem":
			var visible_count := 5 if done or round.phase == "river" else (3 if round.phase == "flop" else 0)
			cards(round.board, Vector2(16, 119), visible_count)
			text(Vector2(16, 207), "YOUR HAND", 13, GOLD)
			cards(round.player, Vector2(16, 218))
			custom_minimum_size.y = 300
		else:
			var y := 127.0
			for i in range(round.hands.size()):
				var hand: Dictionary = round.hands[i]
				text(Vector2(16, y), "HAND %d  ·  %d  ·  $%.2f%s" % [i + 1, Games.total(hand.cards), hand.bet, "  ← YOUR TURN" if not done and int(round.active) == i else ""], 14, GOLD)
				cards(hand.cards, Vector2(16, y + 12))
				y += 104
			custom_minimum_size.y = maxf(270, y)
