extends "res://scripts/slot_presentation.gd"
const Card = preload("res://presentation/play/playing_card.gd")
var pending := false
var seated_players: Array = []
var seat_panels: Array[Dictionary] = []
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
	seat_panels.clear()
	active_hand_rect = Rect2()
	if kind in ["blackjack", "holdem"]:
		var compact := size.x < 600
		var center := size.x / 2
		var done: bool = round.get("phase", "") == "done"
		var dealer: Array = round.get("dealer", [0, 0])
		var dealer_total := str(Games.total(dealer)) if done else str(Games.total([dealer[0]])) if not round.is_empty() else ""
		if kind == "holdem": dealer_total = ""
		captions.append({"at": Vector2(center, 30), "text": ("DEALER " if done or round.is_empty() or kind == "holdem" else "DEALER SHOWING ") + dealer_total + (" | Bust" if done and kind == "blackjack" and Games.total(dealer) > 21 else ""), "size": 16})
		hand(dealer, Vector2(center, 42), size.x - 32, 99 if done else 1 if not round.is_empty() and kind == "blackjack" else 0)
		if kind == "blackjack":
			var hands: Array = round.get("hands", [])
			var cols := 1 if compact else mini(4, maxi(1, hands.size()))
			var row_height := 220.0
			custom_minimum_size.y = 180 + ceili(maxi(1, hands.size()) / float(cols)) * row_height + 60
			var y0 := 236.0
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
				if i < hands.size():
					captions.append({"at": at + Vector2(-22, 165), "text": "YOUR BET", "size": 14, "chip": float(hands[i].bet)})
				else:
					captions.append({"at": at + Vector2(0, 145), "text": "Choose a wager below", "size": 14})
				if active: active_hand_rect = Rect2(at - Vector2(100, 28), Vector2(200, 230))
			configure_seats(y0 + ceili(maxi(1, hands.size()) / float(cols)) * row_height + 12, done)
		else:
			custom_minimum_size.y = 600
			var visible_board := 5 if done or round.get("phase", "") == "river" else 3 if round.get("phase", "") == "flop" else 0
			captions.append({"at": Vector2(center, 200), "text": "COMMUNITY", "size": 14})
			hand(round.get("board", [0, 0, 0, 0, 0]), Vector2(center, 212), size.x - 24, visible_board)
			captions.append({"at": Vector2(center, 345), "text": "YOUR HAND", "size": 16})
			hand(round.get("player", [0, 0]), Vector2(center, 356), size.x - 32, 0 if round.is_empty() else 99)
			if not round.is_empty():
				var amounts := {"Ante": float(round.get("base", 0)), "Blind": float(round.get("base", 0)), "Trips": float(round.get("trips", 0)), "Play": float(round.get("play", 0))}
				var index := 0
				for title in amounts:
					var at := Vector2((index + 0.5) * size.x / 4, 580)
					captions.append({"at": at, "text": title, "size": 14})
					if amounts[title] > 0: captions.append({"at": at - Vector2(0, 60), "text": "", "size": 14, "stack_at": at - Vector2(0, 60), "chip": amounts[title], "seat": -1})
					index += 1
			configure_seats(600, done)
	else:
		custom_minimum_size.y = 240 if kind == "roulette" else 0
	for i in range(card_cursor, card_nodes.size()): card_nodes[i].hide()
	queue_redraw()

func configure_seats(top: float, done: bool) -> void:
	# Seat identity comes from the live roster, never the round's array order.
	var by_id := {}
	for npc in round.get("npcs", []): by_id[int(npc.id)] = npc
	var roster := seated_players.duplicate()
	roster.sort_custom(func(a, b): return int(a.seat) < int(b.seat))
	var columns := maxi(1, mini(3, int(size.x / 270)))
	var width := size.x / columns
	for i in range(roster.size()):
		var guest: Dictionary = roster[i]
		var npc: Dictionary = by_id.get(int(guest.id), {})
		var seat := int(guest.seat)
		var at := Vector2((i % columns + 0.5) * width, top + int(i / columns) * 320)
		seat_panels.append({"rect": Rect2(at + Vector2(-width / 2 + 8, 0), Vector2(width - 16, 308)), "at": at + Vector2(-width / 2 + 34, 28), "seat": seat})
		captions.append({"at": at + Vector2(12, 26), "text": "Seat %d | %s" % [seat + 1, str(guest.name).get_slice(" |", 0).left(16)], "size": 14})
		if npc.is_empty():
			captions.append({"at": at + Vector2(0, 100), "text": "Seated / awaiting next hand", "size": 14})
			continue
		hand(npc.cards, at + Vector2(0, 40), width - 40, 0 if kind == "holdem" and not done else 99)
		if kind == "blackjack":
			captions.append({"at": at + Vector2(0, 220), "text": "", "size": 14, "chip": float(npc.staked), "stack_at": at + Vector2(0, 220), "seat": seat})
			captions.append({"at": at + Vector2(0, 184), "text": "Total %d" % Games.total(npc.cards), "size": 14})
		else:
			# The engine has already committed Ante + Blind + optional Play.
			# Split that actual total for display; NPCs have no Trips stake.
			var amounts := {"Ante": float(npc.bet), "Blind": float(npc.bet), "Play": maxf(0, float(npc.staked) - float(npc.bet) * 2)}
			var index := 0
			for title in amounts:
				var chip_at := at + Vector2((index - 1) * width / 3.5, 220)
				captions.append({"at": chip_at - Vector2(0, 36), "text": title, "size": 12})
				if amounts[title] > 0: captions.append({"at": chip_at, "text": "", "size": 12, "chip": amounts[title], "stack_at": chip_at, "seat": seat})
				index += 1
		if done:
			var outcome := "Fold" if kind == "holdem" and npc.get("folded", false) else "Win" if float(npc.returned) > float(npc.staked) else "Push" if is_equal_approx(float(npc.returned), float(npc.staked)) else "Loss"
			captions.append({"at": at + Vector2(0, 290), "text": outcome + " | Back " + FinancialText.cash(float(npc.returned), 2), "size": 14})
	custom_minimum_size.y = maxf(custom_minimum_size.y, top + ceili(roster.size() / float(columns)) * 320 + 16)

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
		for seat_panel in seat_panels:
			draw_rect(seat_panel.rect, Color(0.02, 0.12, 0.09, 0.75))
			draw_rect(seat_panel.rect, Chips.seat_color(int(seat_panel.seat)), false, 1)
			Chips.avatar(self, seat_panel.at, int(seat_panel.seat), 18)
		for caption in captions:
			if caption.get("active", false):
				draw_line(caption.at + Vector2(-80, 7), caption.at + Vector2(80, 7), GOLD, 2)
			centered(caption.at, caption.text, caption.size, GOLD if caption.get("active", false) else Color("f1ead8"))
			if caption.has("chip"):
				Chips.draw_stack(self, caption.get("stack_at", caption.at + Vector2(70, -7)), float(caption.chip), 18, Chips.seat_color(int(caption.get("seat", -1))))
	elif kind == "slots": draw_slots()
	elif kind == "roulette": draw_wheel()

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
