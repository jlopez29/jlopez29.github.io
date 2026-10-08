extends "res://scripts/slot_presentation.gd"
const Card = preload("res://presentation/play/playing_card.gd")
var pending := false
var play_height := 600.0
var staged_trips := 0.0
var selecting_trips := false
var card_limit := 86.0
var bet_spots := {}
signal spot_selected(trips: bool)
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
	var width := clampf(available / maxf(2, cards.size() + 0.5), 30, card_limit)
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
	bet_spots.clear()
	if kind in ["blackjack", "holdem"]:
		custom_minimum_size.y = maxf(180, play_height)
		var compact := size.x < 600 or play_height < 440
		var short := play_height < 300 and size.x > 600
		var h := maxf(180, play_height)
		var seat_height := 48.0 if compact else 150.0 if not seated_players.is_empty() else 0.0
		var field_h := h - seat_height
		var center := size.x / 2
		var done: bool = round.get("phase", "") == "done"
		var dealer: Array = round.get("dealer", [0, 0])
		card_limit = clampf(field_h * (0.20 if kind == "holdem" else 0.24), 36, 108)
		var dealer_total := str(Games.total(dealer)) if done else str(Games.total([dealer[0]])) if not round.is_empty() else ""
		if kind == "holdem": dealer_total = ""
		captions.append({"at": Vector2(size.x * 0.13 if short else center, 20), "text": "DEALER " + dealer_total, "size": 15})
		hand(dealer, Vector2(size.x * 0.13 if short else center, 30), size.x * 0.24 if short else size.x - 32, 99 if done else 1 if not round.is_empty() and kind == "blackjack" else 0)
		if kind == "blackjack":
			var hands: Array = round.get("hands", [])
			var columns := maxi(1, hands.size()) if short else mini(2 if compact else 4, maxi(1, hands.size()))
			var rows := ceili(maxi(1, hands.size()) / float(columns))
			var start := 34.0 if short else field_h * 0.50
			var row_h := (field_h - start - 52) / rows
			card_limit = clampf(row_h / 1.6, 30, 108)
			for i in range(maxi(1, hands.size())):
				var at := Vector2(size.x * (0.28 + (i + 0.5) * 0.72 / columns) if short else (i % columns + 0.5) * size.x / columns, start + int(i / columns) * row_h)
				var cards: Array = hands[i].cards if i < hands.size() else [0, 0]
				var active: bool = pending and int(round.get("active", 0)) == i
				var title := "YOUR HAND" if hands.size() < 2 else "HAND %d" % (i + 1)
				if i < hands.size(): title += " | %d" % Games.total(cards) + (" | TURN" if active else " | " + hand_result(hands[i]) if done else "")
				captions.append({"at": at - Vector2(0, 10), "text": title, "size": 13, "active": active})
				hand(cards, at, size.x * (0.72 if short else 1.0) / columns - 24, 0 if round.is_empty() else 99)
				if active: active_hand_rect = Rect2(at - Vector2(size.x / columns / 2 - 8, 22), Vector2(size.x / columns - 16, row_h))
				var stake := float(hands[i].bet) if pending and i < hands.size() else wager if i == 0 else 0.0
				var spot := Rect2(Vector2(at.x - 42, field_h - 44), Vector2(84, 40))
				bet_spots["Bet %d" % i] = spot
				captions.append({"at": spot.get_center(), "text": "", "size": 12, "chip": stake, "stack_at": spot.get_center(), "seat": -1})
		else:
			var visible_board := 5 if done or round.get("phase", "") == "river" else 3 if round.get("phase", "") == "flop" else 0
			captions.append({"at": Vector2(center, 20 if short else field_h * 0.35 - 10), "text": "COMMUNITY", "size": 13})
			hand(round.get("board", [0, 0, 0, 0, 0]), Vector2(center, 30 if short else field_h * 0.35), size.x * 0.48 if short else size.x - 24, visible_board)
			captions.append({"at": Vector2(size.x * 0.87 if short else center, 20 if short else field_h * 0.66 - 10), "text": "YOUR HAND", "size": 14})
			hand(round.get("player", [0, 0]), Vector2(size.x * 0.87 if short else center, 30 if short else field_h * 0.66), size.x * 0.24 if short else size.x - 32, 0 if round.is_empty() else 99)
			var amounts := {"Ante": float(round.get("base", wager)), "Blind": float(round.get("base", wager)), "Trips": float(round.get("trips", staged_trips)), "Play": float(round.get("play", 0))}
			if not pending: amounts = {"Ante": wager, "Blind": wager, "Trips": staged_trips, "Play": 0.0}
			var index := 0
			for title in amounts:
				var at := Vector2((index + 0.5) * size.x / 4, field_h - 26)
				bet_spots[title] = Rect2(at - Vector2(38, 22), Vector2(76, 44))
				captions.append({"at": at + Vector2(0, 17), "text": title, "size": 12})
				if amounts[title] > 0: captions.append({"at": at, "text": "", "size": 12, "stack_at": at - Vector2(0, 6), "chip": amounts[title], "seat": -1})
				index += 1
		configure_seats(field_h, done)
	else:
		custom_minimum_size.y = 0
	for i in range(card_cursor, card_nodes.size()): card_nodes[i].hide()
	queue_redraw()


func configure_seats(top: float, done: bool) -> void:
	var by_id := {}
	for npc in round.get("npcs", []): by_id[int(npc.id)] = npc
	var roster := seated_players.duplicate()
	roster.sort_custom(func(a, b): return int(a.seat) < int(b.seat))
	var columns := maxi(1, roster.size())
	var width := size.x / columns
	var compact := size.x < 600 or play_height < 440
	card_limit = 54
	for i in range(roster.size()):
		var guest: Dictionary = roster[i]
		var npc: Dictionary = by_id.get(int(guest.id), {})
		var seat := int(guest.seat)
		var at := Vector2((i + 0.5) * width, top)
		seat_panels.append({"rect": Rect2(at + Vector2(-width / 2 + 2, 0), Vector2(width - 4, 46 if compact else 148)), "at": at + Vector2(-width / 2 + 16, 15), "seat": seat})
		captions.append({"at": at + Vector2(8, 17), "text": "S%d" % (seat + 1), "size": 11})
		if not compact and not npc.is_empty(): hand(npc.cards, at + Vector2(0, 24), width - 12, 0 if kind == "holdem" and not done else 99)
		captions.append({"at": at + Vector2(0, 36 if compact else 118), "text": FinancialText.cash(float(npc.get("staked", 0)), 2) if not npc.is_empty() else "Waiting", "size": 11})
		if done and not compact: captions.append({"at": at + Vector2(0, 138), "text": "Back " + FinancialText.cash(float(npc.returned), 2), "size": 11})

func _gui_input(event: InputEvent) -> void:
	if pending or kind != "holdem": return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		for key in ["Ante", "Trips"]:
			if bet_spots.has(key) and bet_spots[key].has_point(event.position):
				spot_selected.emit(key == "Trips")
				accept_event()

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
		if active_hand_rect.has_area(): draw_rect(active_hand_rect, GOLD, false, 2)
		if kind == "blackjack" and play_height >= 300:
			var rule_y := maxf(30, (play_height - (48 if size.x < 600 else 150 if not seated_players.is_empty() else 0)) * 0.43)
			draw_arc(Vector2(size.x / 2, rule_y - 100), minf(size.x * 0.43, 420), 0.35, PI - 0.35, 48, Color("bda365"), 2)
			centered(Vector2(size.x / 2, rule_y), "BLACKJACK 3:2 | DEALER STANDS ON 17", 12, GOLD)
		for key in bet_spots:
			var spot: Rect2 = bet_spots[key]
			draw_style_box(PitBoss.box(Color(0.03, 0.16, 0.10, 0.3), GOLD if (key == "Trips" if selecting_trips else key == "Ante") else Color("b5aa7b"), 20), spot)
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
	var extent := minf(size.x - 24, size.y - 24)
	wheel_rect = Rect2((size - Vector2.ONE * extent) / 2, Vector2.ONE * extent)
	var center := wheel_rect.get_center()
	var remaining := clampf(spinning / maxf(0.01, duration), 0, 1)
	var rotation := TAU * 3 * pow(remaining, 3)
	draw_circle(center + Vector2(0, 5), extent * 0.50, Color(0, 0, 0, 0.3))
	draw_arc(center, extent * 0.51, 0, TAU, 96, Color("b99854"), 2, true)
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
		angle -= TAU * 5 * pow(remaining, 2)
		var orbit := extent * lerpf(0.39, 0.46, smoothstep(0, 0.45, remaining))
		if spinning > 0:
			for i in range(1, 7):
				var trail := center + Vector2.from_angle(angle + i * 0.06 * remaining) * orbit
				draw_circle(trail, maxf(2, extent * 0.012), Color(1, 0.94, 0.72, (1 - i / 7.0) * 0.28 * remaining))
		var ball := center + Vector2.from_angle(angle) * orbit
		draw_circle(ball + Vector2(1, 2), maxf(4, extent * 0.017), Color(0, 0, 0, 0.4))
		draw_circle(ball, maxf(4, extent * 0.015), Color("fff5dd"))
		if remaining < 0.18:
			draw_arc(center, extent * 0.41, angle - 0.07, angle + 0.07, 12, Color("ffe397"), 3, true)
	if spinning <= 0 and not round.is_empty():
		panel(Rect2(center - Vector2(30, 24), Vector2(60, 48)), Color("15241e"))
		centered(center + Vector2(0, 8), str(result_number), 26)
