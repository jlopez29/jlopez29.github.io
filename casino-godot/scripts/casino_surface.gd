extends "res://scripts/game_art.gd"
signal command(action: String)
signal chip_added(spot: String, amount: float)
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
	zoom = minf(1.2, size.x / 760.0)
	origin = Vector2((size.x - 760 * zoom)/2,0)
	var extra := 0.0
	if kind == "blackjack": extra = maxf(0, round.get("hands",[]).size()-1)*100
	var base := 620.0 + extra
	custom_minimum_size.y = base * zoom + ceilf(buttons.size()/2.0)*50 + 12
	var cols := 2 if size.x < 600 else maxi(1,buttons.size())
	for i in range(buttons.size()):
		buttons[i].position = Vector2(8+(i%cols)*(size.x-16)/cols,base*zoom+int(i/cols)*50)
		buttons[i].size = Vector2((size.x-16)/cols-6,46)
	queue_redraw()

func centered(at: Vector2, value: String, fs: int, color: Color = GOLD) -> void:
	text(at-Vector2(font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x/2,0),value,fs,color)

func stack(at: Vector2, amount: float, color: Color = Color("b8394f")) -> void:
	for i in range(mini(5,maxi(1,int(amount/10)))):
		var p := at-Vector2(0,i*3)
		draw_circle(p,22,Color("f4e9c4")); draw_circle(p,19,color)
		for j in range(8):
			var d := Vector2.from_angle(j*TAU/8)
			draw_line(p+d*15,p+d*20,Color("f4e9c4"),3)
	centered(at+Vector2(0,4),"$%d" % amount,13,Color.WHITE)

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
	var extra := maxf(0,round.get("hands",[]).size()-1)*100 if kind == "blackjack" else 0.0
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
	if kind == "holdem":
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
	else:
		centered(Vector2(380,237),"BLACKJACK PAYS 3 TO 2",24)
		centered(Vector2(380,260),"DEALER STANDS ON ALL 17s  •  INSURANCE PAYS 2 TO 1",12)
		var hands: Array = round.get("hands",[])
		for h in range(maxi(1,hands.size())):
			var y := 290+h*100
			if h < hands.size():
				var hand: Dictionary = hands[h]
				var gap := minf(52,460.0/maxi(1,hand.cards.size()))
				for i in range(hand.cards.size()): card(Vector2(380-hand.cards.size()*gap/2+i*gap,y),int(hand.cards[i]))
				centered(Vector2(380,y+86),"HAND %d • %d%s" % [h+1,Games.total(hand.cards)," • YOUR TURN" if pending and int(round.active)==h else ""],13)
		var at := Vector2(380,455+extra)
		zones["Bet"] = at
		draw_arc(at,40,0,TAU,60,GOLD,2); stack(at,wager)
		centered(at+Vector2(0,-47),"PLACE BET",13)
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
