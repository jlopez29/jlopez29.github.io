extends "res://scripts/game_art.gd"
const Card = preload("res://presentation/play/playing_card.gd")
const SYMBOL_ASSETS := ["cherry", "lemon", "bell", "bar", "seven"]
var wager := 10.0
var pending := false
var machine_profile := {}
var card_nodes: Array[TextureRect] = []
var captions: Array[Dictionary] = []
var card_cursor := 0
var result_number := -1
var wheel_rect := Rect2()
var active_hand_rect := Rect2()

func _ready() -> void:
	super._ready()
	resized.connect(configure)

func hand(cards: Array, at: Vector2, available: float, hidden_after: int = 99) -> void:
	var width := clampf(available / maxf(2, cards.size() + 0.5), 48, 86)
	var gap := minf(width + 8, maxf(18, (available - width) / maxi(1, cards.size() - 1)))
	var span := width + gap * (cards.size() - 1)
	for i in range(cards.size()):
		if card_cursor >= card_nodes.size():
			var node := Card.new()
			add_child(node)
			card_nodes.append(node)
		var node := card_nodes[card_cursor]
		node.show()
		node.show_card(int(cards[i]), i >= hidden_after)
		node.position = at + Vector2(-span / 2 + gap * i, 0)
		node.size = Vector2(width, width * 1.4)
		card_cursor += 1

func configure() -> void:
	if not is_node_ready(): return
	card_cursor = 0
	captions.clear()
	active_hand_rect = Rect2()
	if kind in ["blackjack", "holdem"]:
		var compact := size.x < 600
		var center := size.x / 2
		var done: bool = round.get("phase", "") == "done"
		var dealer: Array = round.get("dealer", [0, 0])
		var dealer_total := str(Games.total(dealer)) if done else str(Games.total([dealer[0]])) if not round.is_empty() else ""
		if kind == "holdem" and not done: dealer_total = ""
		captions.append({"at": Vector2(center, 30), "text": ("DEALER " if done or round.is_empty() or kind == "holdem" else "DEALER SHOWING ") + dealer_total + (" | Bust" if done and Games.total(dealer) > 21 else ""), "size": 16})
		hand(dealer, Vector2(center, 42), size.x - 32, 99 if done else 1 if not round.is_empty() and kind == "blackjack" else 0)
		if kind == "blackjack":
			var hands: Array = round.get("hands", [])
			var cols := 1 if compact else mini(4, maxi(1, hands.size()))
			var row_height := 174.0 if compact else 190.0
			custom_minimum_size.y = 180 + ceili(maxi(1, hands.size()) / float(cols)) * row_height + 60
			var y0 := maxf(190, size.y * 0.45) if hands.size() <= 1 else 178.0
			for i in range(maxi(1, hands.size())):
				var at := Vector2((i % cols + 0.5) * size.x / cols, y0 + int(i / cols) * row_height)
				var cards: Array = hands[i].cards if i < hands.size() else [0, 0]
				var active: bool = pending and int(round.get("active", 0)) == i
				var title := "YOUR HAND" if hands.size() < 2 else "HAND %d" % (i + 1)
				if i < hands.size():
					title += " | %d" % Games.total(cards)
					if active: title += " | YOUR TURN"
					elif done: title += " | " + hand_result(hands[i])
				captions.append({"at": at - Vector2(0, 12), "text": title, "size": 16, "active": active})
				hand(cards, at, size.x / cols - 30, 0 if round.is_empty() else 99)
				var amount: float = hands[i].bet if i < hands.size() else wager
				captions.append({"at": at + Vector2(-22, 145), "text": "Bet " + FinancialText.cash(amount, 0), "size": 14, "chip": amount})
				if active: active_hand_rect = Rect2(at - Vector2(100, 28), Vector2(200, 190))
		else:
			custom_minimum_size.y = 490
			var visible_board := 5 if done or round.get("phase", "") == "river" else 3 if round.get("phase", "") == "flop" else 0
			captions.append({"at": Vector2(center, 200), "text": "COMMUNITY", "size": 14})
			hand(round.get("board", [0, 0, 0, 0, 0]), Vector2(center, 212), size.x - 24, visible_board)
			captions.append({"at": Vector2(center, 345), "text": "YOUR HAND", "size": 16})
			hand(round.get("player", [0, 0]), Vector2(center, 356), size.x - 32, 0 if round.is_empty() else 99)
	else:
		custom_minimum_size.y = 240 if kind == "roulette" else 300
	for i in range(card_cursor, card_nodes.size()): card_nodes[i].hide()
	queue_redraw()

const FinancialText = preload("res://scripts/financial_text.gd")
static func hand_result(hand_data: Dictionary) -> String:
	if hand_data.get("surrender", false): return "Surrender"
	if Games.total(hand_data.cards) > 21: return "Bust"
	if not hand_data.split and hand_data.cards.size() == 2 and Games.total(hand_data.cards) == 21: return "Blackjack / Push" if is_equal_approx(float(hand_data.get("returned", 0)), float(hand_data.bet)) else "Blackjack"
	var returned := float(hand_data.get("returned", 0))
	return "Win" if returned > float(hand_data.bet) else "Push" if is_equal_approx(returned, float(hand_data.bet)) else "Loss"

func _draw() -> void:
	if font == null: return
	if kind in ["blackjack", "holdem"]:
		image("blackjack/blackjack_felt_base.png", Rect2(Vector2.ZERO, size))
		if kind == "blackjack":
			# Crop the printed rules/arc; existing hands and wager chips stay dynamic.
			var overlay := PitBoss.texture("casino_play/blackjack/blackjack_felt_overlay.png")
			var rules_rect := Rect2(size.x * 0.12, 150, size.x * 0.76, 62)
			var print_width := minf(size.x * 0.8, 580)
			rules_rect = Rect2((size.x - print_width) / 2, 166, print_width, 50)
			draw_texture_rect_region(overlay, rules_rect, Rect2(440, 330, 1170, 270))
		for caption in captions:
			if caption.get("active", false):
				draw_line(caption.at + Vector2(-80, 7), caption.at + Vector2(80, 7), GOLD, 2)
			centered(caption.at, caption.text, caption.size, GOLD if caption.get("active", false) else Color("f1ead8"))
			if caption.has("chip"): stack(caption.at + Vector2(70, -7), float(caption.chip), 18)
	elif kind == "slots": draw_slots()
	elif kind == "roulette": draw_wheel()

func draw_slots() -> void:
	var extent := minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * extent) / 2, Vector2.ONE * extent)
	image("slots/slot_cabinet_frame.svg", rect)
	centered(rect.position + Vector2(extent / 2, extent * 0.09), str(machine_profile.get("short_name", "PIT BOSS REELS")).to_upper(), 22)
	var reels: Array = round.get("reels", [])
	for i in range(3):
		var window := Rect2(rect.position + Vector2((0.127 + i * 0.258) * extent, 0.186 * extent), Vector2(0.23, 0.38) * extent)
		if reels.is_empty():
			centered(window.get_center(), "READY", 14)
			continue
		var moving: bool = spinning > i * 0.18
		var travel := fmod((duration - spinning) * 2.5, 1.0) if moving else 0.0
		# Temporary motion cycles deterministically around the committed reel result.
		for row in range(-1, 2):
			var symbol_id: int = int(reels[i]) if row == 0 else posmod(int(reels[i]) + row, 5)
			var symbol_size := minf(window.size.x * 0.86, window.size.y * 0.45)
			var y := window.get_center().y + (row + travel) * window.size.y * 0.42
			var symbol_rect := Rect2(Vector2(window.get_center().x - symbol_size / 2, y - symbol_size / 2), Vector2.ONE * symbol_size)
			# Only show symbols contained in their real reel windows.
			var visible_rect := symbol_rect.intersection(window)
			if visible_rect.size.x > 0 and visible_rect.size.y > 0:
				var source := Rect2((visible_rect.position - symbol_rect.position) / symbol_size * 128, visible_rect.size / symbol_size * 128)
				draw_texture_rect_region(PitBoss.texture("casino_play/slots/symbols/" + SYMBOL_ASSETS[symbol_id] + ".svg"), visible_rect, source)
		var payline_y := window.get_center().y
		draw_line(Vector2(window.position.x, payline_y), Vector2(window.end.x, payline_y), Color(0.7, 0.5, 0.12, 0.45), 1)
	centered(rect.position + Vector2(extent / 2, extent * 0.76), "BET " + FinancialText.cash(wager, 0), 18)
	centered(rect.position + Vector2(extent / 2, extent * 0.81), "CENTER ROW PAYS", 12)

func draw_wheel() -> void:
	image("roulette/roulette_felt_base.png", Rect2(Vector2.ZERO, size))
	var extent := minf(size.x - 16, size.y - 16)
	wheel_rect = Rect2((size - Vector2.ONE * extent) / 2, Vector2.ONE * extent)
	var center := wheel_rect.get_center()
	var rotation := TAU * 2 * pow(spinning / maxf(0.01, duration), 2) if spinning > 0 else 0.0
	draw_set_transform(center, rotation)
	image("roulette/roulette_wheel.svg", Rect2(-Vector2.ONE * extent / 2, Vector2.ONE * extent))
	# The art's green pocket begins at twelve o'clock; WHEEL owns European order.
	for i in range(Games.WHEEL.size()):
		var angle := -PI / 2 + (i + 0.5) * TAU / 37
		var at := Vector2.from_angle(angle) * extent * 0.33
		centered(at, str(Games.WHEEL[i]), maxi(8, mini(14, int(extent / 32))), Color.WHITE)
	draw_set_transform(Vector2.ZERO)
	if not round.is_empty():
		result_number = int(round.number)
		var angle := -PI / 2 + (Games.WHEEL.find(result_number) + 0.5) * TAU / 37 + rotation
		if spinning > 0: angle += TAU * spinning / duration
		var ball := center + Vector2.from_angle(angle) * extent * 0.39
		draw_circle(ball, maxf(4, extent * 0.015), Color("fff5dd"))
	if spinning <= 0 and not round.is_empty():
		panel(Rect2(center - Vector2(30, 24), Vector2(60, 48)), Color("15241e"))
		centered(center + Vector2(0, 8), str(result_number), 26)
