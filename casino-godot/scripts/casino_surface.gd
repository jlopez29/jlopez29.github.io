extends "res://scripts/game_art.gd"
signal command(action: String)
signal chip_added(spot: String, amount: float)
var table_guests: Array = []
var wallet := 0.0
var wager := 10.0
var side_bet := false
var locked := false
var pending := false
var minimum := 10.0
var options := {}
var selected_chip := 10.0
var dragging := false
var pointer := Vector2.ZERO
var zones := {}
var tray := {}
var buttons: Array[Button] = []
var zoom := 1.0
var origin := Vector2.ZERO

func _ready() -> void:
	super._ready()
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(arrange)

func configure() -> void:
	for item in buttons: item.queue_free()
	buttons.clear()
	if kind == "roulette": return
	for action in options:
		var item := Button.new()
		item.text = options[action].text
		item.disabled = locked or options[action].disabled
		item.pressed.connect(func(): command.emit(action))
		var skin := StyleBoxFlat.new()
		skin.bg_color = Color("e5d6a1") if action in ["Deal", "Spin"] else Color("253d3e")
		skin.border_color = GOLD
		skin.set_border_width_all(2)
		skin.set_corner_radius_all(8)
		item.add_theme_stylebox_override("normal",skin)
		item.add_theme_color_override("font_color",Color("17252a") if action in ["Deal","Spin"] else Color("fff1cb"))
		add_child(item); buttons.append(item)
	arrange()

func arrange() -> void:
	if kind == "roulette": return
	var canvas_width := 440.0 if kind == "blackjack" and size.x < 600 else 760.0
	zoom = minf(1.0 if kind == "blackjack" else 1.2, size.x / canvas_width)
	origin = Vector2((size.x - canvas_width * zoom)/2,0)
	var base := blackjack_height() + 16 if kind == "blackjack" else 620.0
	var cols := 1 if kind == "blackjack" and size.x < 400 else (2 if size.x < 600 else maxi(1, buttons.size()))
	custom_minimum_size.y = base * zoom + ceili(buttons.size() / float(cols)) * 50 + 12
	for i in range(buttons.size()):
		buttons[i].position = Vector2(8+(i%cols)*(size.x-16)/cols,base*zoom+int(i/cols)*50)
		buttons[i].size = Vector2((size.x-16)/cols-6,46)
	queue_redraw()

func centered(at: Vector2, value: String, fs: int, color: Color = GOLD) -> void:
	text(at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x/2,0),value,fs,color)

func stack(at: Vector2, amount: float, color: Color = Color("b8394f"), radius: float = 22.0) -> void:
	var count := mini(5, maxi(1, int(amount / 10)))
	var top := at
	for i in range(count):
		var position := at - Vector2(0, i * 3)
		top = position
		draw_circle(position, radius, Color("f4e9c4"))
		draw_circle(position, radius - 3, color)
		for j in range(8):
			var direction := Vector2.from_angle(j * TAU / 8)
			draw_line(position + direction * (radius - 7), position + direction * (radius - 2), Color("f4e9c4"), 3)
	var value := "$%d" % amount
	var font_size := maxi(13, floori(radius * 0.6))
	var available_width := (radius - 5) * 2
	while font_size > 7 and font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > available_width:
		font_size -= 1
	var baseline := (font.get_ascent(font_size) - font.get_descent(font_size)) / 2
	centered(top + Vector2(0, baseline), value, font_size, Color.WHITE)

func symbol(at: Vector2, value: int, s: float = 1.0) -> void:
	if value == 0:
		for offset in [Vector2(-17,7),Vector2(17,13)]:
			draw_circle(at+offset*s,19*s,Color("631526"))
			draw_circle(at+(offset-Vector2(2,3))*s,16*s,Color("e73640"))
			draw_circle(at+(offset-Vector2(6,9))*s,4*s,Color("ffada2"))
		draw_polyline(PackedVector2Array([at+Vector2(-17,-6)*s,at+Vector2(3,-35)*s,at+Vector2(17,-2)*s]),Color("356b35"),5*s)
		draw_colored_polygon(PackedVector2Array([at+Vector2(3,-35)*s,at+Vector2(36,-39)*s,at+Vector2(19,-19)*s]),Color("66a741"))
	elif value == 1:
		var oval := PackedVector2Array()
		for i in range(40): oval.append(at+Vector2(cos(i*TAU/40)*32,sin(i*TAU/40)*20)*s)
		draw_colored_polygon(oval,Color("ffe367"))
	elif value == 2:
		draw_circle(at+Vector2(0,-16)*s,8*s,GOLD)
		draw_colored_polygon(PackedVector2Array([at+Vector2(-14,-20)*s,at+Vector2(14,-20)*s,at+Vector2(30,23)*s,at+Vector2(-30,23)*s]),Color("e6ae38"))
		draw_line(at+Vector2(-31,24)*s,at+Vector2(31,24)*s,Color("fff0a3"),6*s)
		draw_circle(at+Vector2(0,29)*s,7*s,GOLD)
	elif value == 3:
		panel(Rect2(at-Vector2(46,23)*s,Vector2(92,46)*s),Color("10202a"),3)
		centered(at+Vector2(0,12*s),"BAR",int(32*s),Color("f6dd91"))
	else:
		centered(at+Vector2(3,30)*s,"7",int(88*s),Color("142437"))
		centered(at+Vector2(0,25)*s,"7",int(82*s),Color("f3422d"))

func _draw() -> void:
	if kind == "roulette": super._draw(); return
	if font == null: return
	draw_set_transform(origin,0,Vector2.ONE*zoom)
	zones.clear(); tray.clear()
	if kind == "slots": draw_cabinet()
	else: draw_table_surface()
	if dragging: stack((pointer-origin)/zoom,selected_chip)
	draw_set_transform(Vector2.ZERO)

func draw_cabinet() -> void:
	panel(Rect2(7,7,746,601),Color("8c6735"),30)
	panel(Rect2(19,18,722,577),Color("201c21"),25)
	panel(Rect2(31,30,698,74),Color("351e2b"),14)
	centered(Vector2(380,67),"N E O N   R E E L S",32)
	centered(Vector2(380,91),"CLASSIC THREE REEL • SINGLE PAYLINE",12,Color("ded3af"))
	for i in range(18):
		draw_circle(Vector2(50+i*39,18),3,Color("ffeab1") if int(clock*4+i)%3 else Color("9d713f"))
	for i in range(3):
		var x := 47.0+i*224
		panel(Rect2(x,117,218,280),Color("af9967"),12)
		panel(Rect2(x+7,124,204,266),Color("ecebdc"),8)
		var result := int(round.get("reels",[4,0,3])[i])
		var moving := spinning > i*0.22
		var step := fmod(clock*(9+i),1.0) if moving else 0.0
		for row in range(-1,2):
			var value := posmod(result+row,5) if not moving else posmod(int(clock*(9+i))+row,5)
			var position_y := 256+(row+step)*83
			if position_y < 354: symbol(Vector2(x+109,position_y),value,0.78 if row != 0 else 1.0)
		# Shaded reel edges, with the center winning row kept clear.
		draw_rect(Rect2(x+8,125,202,32),Color(0.1,0.12,0.15,0.22))
		draw_rect(Rect2(x+8,357,202,32),Color(0.1,0.12,0.15,0.22))
		draw_line(Vector2(x+8,302),Vector2(x+210,302),Color("ac904a"),2)
		draw_line(Vector2(x+8,211),Vector2(x+210,211),Color("ac904a"),2)
	centered(Vector2(380,419),"ONLY THE CENTER ROW PAYS",13)
	var values := [wallet,wager,float(round.get("credit",0)) if spinning <= 0 else 0.0]
	for i in range(3):
		var x := 48+i*224
		centered(Vector2(x+105,449),["CREDITS ($)","BET ($)","WIN PAID ($)"][i],14)
		panel(Rect2(x,460,210,59),Color("090e12"),6)
		centered(Vector2(x+105,499),"%.2f" % values[i],29,Color("ff8d79"))
	centered(Vector2(380,552),"SELECT YOUR STAKE • SPIN THE REELS",16)
	centered(Vector2(380,581),"3 matching symbols win • cherries can pay on their own",13,Color("c7bfae"))

func draw_table_surface() -> void:
	if kind == "blackjack":
		draw_blackjack_surface()
		return
	var extra := 0.0
	panel(Rect2(4,4,752,602+extra),Color("372821"),55)
	panel(Rect2(19,18,722,574+extra),Color("172629"),48)
	panel(Rect2(34,30,692,547+extra),Color("105447") if kind == "blackjack" else Color("163d66"),42)
	for y in range(42,int(566+extra),7): draw_line(Vector2(49,y),Vector2(711,y),Color(1,1,1,0.018),1)
	centered(Vector2(380,59),"NEON HOUSE  /  " + ("BLACKJACK" if kind == "blackjack" else "ULTIMATE TEXAS HOLD'EM"),20)
	panel(Rect2(286,74,188,23),Color("142323"),5)
	for i in range(16): draw_line(Vector2(293+i*11,78),Vector2(293+i*11,93),[Color("c35259"),GOLD,Color("5d9bca")][i%3],7)
	centered(Vector2(380,119),"DEALER",12)
	var done: bool = round.get("phase","") == "done"
	if not round.is_empty():
		for i in range(round.dealer.size()): card(Vector2(328+i*55,130),int(round.dealer[i]),not done and (kind == "holdem" or i > 0))
	else:
		card(Vector2(328,130),0,true); card(Vector2(383,130),0,true)
	var count := 5 if done or round.get("phase","") == "river" else (3 if round.get("phase","") == "flop" else 0)
	for i in range(5): card(Vector2(242+i*56,230),int(round.get("board",[0,0,0,0,0])[i]),i >= count)
	centered(Vector2(380,218),"COMMUNITY CARDS",12)
	for i in range(2): card(Vector2(328+i*55,335),int(round.get("player",[0,0])[i]),round.is_empty())
	for i in range(4):
		var name: String = ["Ante","Blind","Trips","Play"][i]
		var at := Vector2(185+i*130,458)
		zones[name] = at
		draw_arc(at,39,0,TAU,60,GOLD,2)
		centered(at+Vector2(0,-46),name.to_upper(),14)
		var amount := wager if name in ["Ante","Blind"] else (wager if name == "Trips" and side_bet else 0.0)
		if pending: amount = float(round.get("play",0)) if name == "Play" else (float(round.get("trips",0)) if name == "Trips" else float(round.get("base",wager)))
		if amount > 0: stack(at,amount)
	for i in range(4):
		var amount: int = [5,10,25,100][i]
		var at := Vector2(245+i*90,545+extra)
		tray[amount] = at
		stack(at,amount,Color("2b7ea0") if selected_chip == amount else Color("b8394f"))
	centered(Vector2(380,597+extra),"Drag chips to a circle • tap chips then a circle • Clear to reset",12)

func _gui_input(event: InputEvent) -> void:
	if kind in ["slots","roulette"]: return
	if event is InputEventMouseMotion:
		pointer = event.position; queue_redraw()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = event.position
		var at := (pointer-origin)/zoom
		if event.pressed and not locked and not pending:
			for amount in tray:
				if at.distance_to(tray[amount]) < 32:
					selected_chip = amount; dragging = true
		elif not event.pressed:
			if not locked and not pending:
				for name in zones:
					if at.distance_to(zones[name]) < 42: chip_added.emit(name,selected_chip)
			dragging = false
		accept_event(); queue_redraw()

func blackjack_seat_rows() -> int:
	var columns := 2 if size.x < 600 else 4
	return ceili(table_guests.size() / float(columns))

func blackjack_height() -> float:
	var extra_hands := maxi(0, round.get("hands", []).size() - 1)
	return 640.0 + blackjack_seat_rows() * 150 + extra_hands * 128

func draw_blackjack_surface() -> void:
	var compact := size.x < 600
	var width := 440.0 if compact else 760.0
	var center := width / 2
	var height := blackjack_height()
	panel(Rect2(4, 4, width - 8, height - 8), Color("372821"), 45)
	panel(Rect2(19, 18, width - 38, height - 34), Color("172629"), 38)
	panel(Rect2(34, 30, width - 68, height - 66), Color("105447"), 32)
	for y in range(42, int(height - 42), 7):
		draw_line(Vector2(49, y), Vector2(width - 49, y), Color(1, 1, 1, 0.018), 1)
	centered(Vector2(center, 59), "NEON HOUSE / BLACKJACK", 20)
	var done: bool = round.get("phase", "") == "done"
	var dealer: Array = round.get("dealer", [])
	var dealer_text := "DEALER - waiting for deal"
	if not dealer.is_empty():
		# Match the existing hole-card rendering: only card zero is exposed in play.
		var visible_cards: Array = dealer if done else [dealer[0]]
		dealer_text = "DEALER - %d%s" % [Games.total(visible_cards), "" if done else " (showing)"]
	centered(Vector2(center, 98), dealer_text, 24)
	if dealer.is_empty():
		card(Vector2(center - 52, 115), 0, true)
		card(Vector2(center + 3, 115), 0, true)
	else:
		var gap := minf(55, (width - 110) / maxi(1, dealer.size()))
		var span: float = (dealer.size() - 1) * gap + 49
		for i in range(dealer.size()): card(Vector2(center - span / 2 + i * gap, 115), int(dealer[i]), not done and i > 0)
	var guest_top := 200.0
	var columns := 2 if compact else 4
	var column_width := (width - 90) / columns
	for index in range(table_guests.size()):
		var guest: Dictionary = table_guests[index]
		var at := Vector2(45 + (index % columns) * column_width, guest_top + (index / columns) * 150)
		draw_blackjack_guest(guest, Rect2(at, Vector2(column_width - 8, 136)), done)
	var hand_top := guest_top + blackjack_seat_rows() * 150
	var hands: Array = round.get("hands", [])
	for index in range(maxi(1, hands.size())):
		var y := hand_top + index * 128
		var active := pending and int(round.get("active", 0)) == index
		var name := "YOUR HAND" if hands.size() <= 1 else "HAND %d" % (index + 1)
		var title := name + " - waiting for deal"
		if index < hands.size(): title = "%s - %d" % [name, Games.total(hands[index].cards)]
		centered(Vector2(center, y + 34), title, 36 if index < hands.size() else 25, Color("fff3cb"))
		if index < hands.size():
			var hand: Dictionary = hands[index]
			var gap := minf(52, (width - 110) / maxi(1, hand.cards.size()))
			var span: float = (hand.cards.size() - 1) * gap + 49
			for i in range(hand.cards.size()): card(Vector2(center - span / 2 + i * gap, y + 46), int(hand.cards[i]))
			var state := "YOUR TURN" if active else ("FINISHED" if done else "WAITING")
			if Games.total(hand.cards) > 21: state = "BUSTED"
			elif hand.surrender: state = "SURRENDERED"
			elif not hand.split and hand.cards.size() == 2 and Games.total(hand.cards) == 21: state = "BLACKJACK"
			centered(Vector2(center, y + 127), state, 14, GOLD)
	var bet_at := Vector2(center, hand_top + maxi(1, hands.size()) * 128 + 68)
	zones["Bet"] = bet_at
	draw_arc(bet_at, 36, 0, TAU, 60, GOLD, 2)
	stack(bet_at, wager)
	centered(bet_at + Vector2(0, -45), "BET", 13)
	var tray_y := bet_at.y + 92
	var step := minf(90, (width - 120) / 3)
	for i in range(4):
		var amount: int = [5, 10, 25, 100][i]
		var at := Vector2(center + (i - 1.5) * step, tray_y)
		tray[amount] = at
		stack(at, amount, Color("2b7ea0") if selected_chip == amount else Color("b8394f"), 28 if compact else 22)
	centered(Vector2(center, tray_y + 47), "Drag chips to BET | tap chip then BET", 13, Color("cbd8c8"))
	centered(Vector2(center, tray_y + 68), "Reset Bets clears your wager selection", 12, Color("cbd8c8"))
	centered(Vector2(center, height - 41), "Blackjack pays 3:2 | dealer stands on 17", 13)
	centered(Vector2(center, height - 23), "Insurance pays 2:1", 12)

func draw_blackjack_guest(guest: Dictionary, rect: Rect2, done: bool) -> void:
	panel(rect, Color("16463d"), 8)
	var center := rect.get_center().x
	var name := "SEAT %d - %s" % [int(guest.seat) + 1, str(guest.name).replace(" · ", " | ")]
	var name_size := 13
	while name_size > 10 and font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, name_size).x > rect.size.x - 10: name_size -= 1
	centered(Vector2(center, rect.position.y + 19), name, name_size, Color("dce8d9"))
	var participant: Dictionary = {}
	for npc in round.get("npcs", []):
		if int(npc.id) == int(guest.id): participant = npc; break
	if participant.is_empty():
		centered(Vector2(center, rect.position.y + 67), "NEXT HAND", 14)
		return
	centered(Vector2(center, rect.position.y + 38), "$%d BET" % participant.bet, 12)
	var cards: Array = participant.cards
	var scale := 0.65
	var gap := minf(26, (rect.size.x - 20 - 49 * scale) / maxi(1, cards.size() - 1))
	var span: float = (cards.size() - 1) * gap + 49 * scale
	for i in range(cards.size()): card(Vector2(center - span / 2 + i * gap, rect.position.y + 46), int(cards[i]), false, scale)
	var value := Games.total(cards)
	var state := "STOOD" # Current NPC rules complete their draws before owner actions.
	if value > 21: state = "BUSTED"
	elif value == 21 and cards.size() == 2: state = "BLACKJACK"
	elif done: state = "FINISHED"
	centered(Vector2(center, rect.position.y + 111), "%d - %s" % [value, state], 15, Color("edf2d9"))
