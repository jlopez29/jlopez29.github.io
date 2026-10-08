extends Control

signal bet_clicked(kind: String)
signal action_requested(action: String)
var sim: PitBossGameContext
var chip := 25.0
var locked := false
var font: Font
var targets: Array = []
var spots := {}
var flights: Array = []
var previous: Dictionary = {}
var table_id := -1
var last_roll := -1
var animation := 0.0
var clock := 0.0
var dragging := ""
var pointer := Vector2.ZERO
var origin := Vector2.ZERO
var message := "Drag a chip onto the felt • tap a chip, then a bet, also works"
var canvas := Vector2(1100, 690)
var factor := 1.0
var offset := Vector2.ZERO
var portrait := false
var tray := Rect2()
var dice_ready := false
var dice_held := false
var delivery := 0.0
var betting_wait := 0.8
var shooter_seen := -99
var exposure_seen := -1.0
var hold_started := 0.0
var gesture_velocity := Vector2.ZERO
var gesture_time := 0.0
var throw_power := 0.55
var throw_aim := 0.0
var throw_pending := false
var launch := Vector2.ZERO
var impact := Vector2.ZERO
var landing := Vector2.ZERO
var scroll_mode := ScrollContainer.SCROLL_MODE_AUTO
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const GOLD := Color("e6c888")
const INK := Color("eee7cf")
const TEAL := Color("89d7c6")

func _ready() -> void:
	font = ThemeDB.fallback_font
	clip_contents = true
	mouse_filter = MOUSE_FILTER_STOP

func busy() -> bool:
	return animation > 0 or dice_held

func _process(delta: float) -> void:
	clock += delta
	animation = maxf(0, animation - delta)
	if sim != null and sim.joined >= 0 and sim.table_kind(sim.get_table(sim.joined)) == "craps":
		var table := sim.get_table(sim.joined)
		if table_id != sim.joined:
			table_id = sim.joined
			last_roll = int(table.rolls)
			animation = 0
			flights.clear()
			reset_dice()
			shooter_seen = -99
			previous = snapshot(table)
		if int(table.rolls) != last_roll:
			capture_roll(table)
		elif animation <= 0:
			previous = snapshot(table)
			if shooter_seen != int(table.shooter):
				reset_dice()
				shooter_seen = int(table.shooter)
			var exposure := CrapsRules.exposure(table.owner)
			if exposure != exposure_seen and not dice_ready:
				betting_wait = 0.8
				exposure_seen = exposure
			if not locked and not dice_held:
				if delivery > 0:
					delivery = maxf(0, delivery - delta)
					if delivery == 0: dice_ready = true
				elif not dice_ready:
					betting_wait -= delta
					if betting_wait <= 0: delivery = 0.85
	else:
		if dice_held: cancel_throw()
		table_id = -1
	queue_redraw()

func reset_dice() -> void:
	cancel_throw()
	dice_ready = false
	delivery = 0.0
	betting_wait = 0.8

func shooter_pocket(shooter: int = -99) -> Vector2:
	if portrait: return Vector2(canvas.x / 2, 650)
	var table := sim.get_table(sim.joined)
	if shooter == -99: shooter = int(table.shooter)
	var seat := -1
	for guest in sim.seated(sim.joined):
		if int(guest.id) == shooter: seat = int(guest.seat)
	var at := player_at(seat)
	return Vector2(clampf(at.x, 150, canvas.x - 210), 168 if at.y < 200 else canvas.y - 217)

func plan_throw(shooter: int = -99, released_at: Vector2 = Vector2(-1, -1)) -> void:
	launch = shooter_pocket(shooter) if released_at.x < 0 else released_at
	if portrait:
		impact = Vector2(clampf(canvas.x / 2 + throw_aim * 95, 95, canvas.x - 95), 132)
		landing = impact + Vector2(throw_aim * 15, 50 + throw_power * 65)
	else:
		impact = Vector2(canvas.x - 80, clampf(launch.y + throw_aim * 120, 153, canvas.y - 230))
		landing = impact + Vector2(-55 - throw_power * 85, -throw_aim * 25)

func free_hand_position() -> Vector2:
	var hand := shooter_pocket() + pointer - origin
	return Vector2(clampf(hand.x, 85, canvas.x - 100), clampf(hand.y, 145, canvas.y - 205))

func can_throw() -> bool:
	if sim == null or sim.joined < 0 or locked or busy() or not dice_ready: return false
	var table := sim.get_table(sim.joined)
	return not table.is_empty() and int(table.shooter) == 0 and sim.ready_for_play(table) and sim.shooter_has_line(table)

func cancel_throw() -> void:
	dice_held = false
	var parent := get_parent() as ScrollContainer
	if parent != null: parent.vertical_scroll_mode = scroll_mode

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: cancel_throw()

# Drawing and all pointer paths share this inverse transform.
func felt_position(local_position: Vector2) -> Vector2:
	return (local_position - offset) / maxf(factor, 0.0001)

# Catch dice gestures before the scroll container. Bets still use the normal GUI path.
func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or sim == null or sim.joined < 0 or factor <= 0: return
	var position_on_screen := Vector2.ZERO
	var pressed := false
	var released := false
	var motion := false
	if event is InputEventScreenTouch:
		if event.index != 0: return
		position_on_screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		if event.index != 0: return
		position_on_screen = event.position
		motion = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		position_on_screen = event.position
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion:
		position_on_screen = event.position
		motion = true
	else: return
	var local := get_global_transform_with_canvas().affine_inverse() * position_on_screen
	var at := felt_position(local)
	if pressed and not dice_held and can_throw():
		var parent := get_parent() as ScrollContainer
		if parent != null and not parent.get_global_rect().has_point(position_on_screen): return
		if not Rect2(shooter_pocket() - Vector2(68, 40), Vector2(136, 80)).has_point(at): return
		dice_held = true
		origin = at
		pointer = at
		hold_started = clock
		gesture_time = clock
		gesture_velocity = Vector2.ZERO
		if parent != null:
			scroll_mode = parent.vertical_scroll_mode
			parent.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		message = "Flick UP to the wall" if portrait else "Flick RIGHT to the wall"
		get_viewport().set_input_as_handled()
	elif dice_held:
		if motion:
			gesture_velocity = (at - pointer) / maxf(0.008, clock - gesture_time)
			gesture_time = clock
		pointer = at
		get_viewport().set_input_as_handled()
		if released:
			var swipe := gesture_velocity * 0.15 if clock - gesture_time < 0.2 and gesture_velocity.length() > 80 else pointer - origin
			var forward := -swipe.y if portrait else swipe.x
			var elapsed := maxf(0.08, clock - hold_started)
			cancel_throw()
			if locked or forward < 12:
				message = "Hold the dice, then flick toward the back wall."
				return
			throw_power = clampf(forward / 280.0 + forward / elapsed / 2400.0, 0.2, 1.0)
			throw_aim = clampf(swipe.x / forward if portrait else swipe.y / forward, -1, 1)
			var hand := free_hand_position()
			plan_throw(-99, hand)
			throw_pending = true
			action_requested.emit("shoot")
		elif motion: queue_redraw()

func snapshot(table: Dictionary) -> Dictionary:
	return {"table": table.duplicate(true), "owner_bankroll": sim.owner_bankroll, "guests": sim.seated(int(table.id)).duplicate(true)}

func capture_roll(table: Dictionary) -> void:
	if not throw_pending:
		throw_power = 0.55
		throw_aim = 0.0
		plan_throw(int(previous.table.shooter) if not previous.is_empty() else int(table.shooter))
	throw_pending = false
	reset_dice()
	flights.clear()
	if not previous.is_empty():
		var before: Dictionary = previous.table
		settlement(before.owner, int(before.point), table.dice, bool(before.owner_working), -1)
		for guest in previous.guests:
			var bets: Dictionary = guest.bets.duplicate(true)
			if sim.opened and int(before.point) == 0 and bets.pass == 0 and guest.wallet >= before.minimum:
				bets.pass = minf(before.minimum * (4 if guest.vip else 1), guest.wallet)
			settlement(bets, int(before.point), table.dice, false, int(guest.seat))
	last_roll = int(table.rolls)
	animation = 2.2
	message = table.result

func settlement(bets: Dictionary, point: int, dice: Array, working: bool, seat: int) -> void:
	# The same rules drive the animation and the accounting; never roll visual dice for money.
	for kind in bets:
		if float(bets[kind]) <= 0: continue
		var only := CrapsRules.empty_bets()
		only[kind] = bets[kind]
		var result := CrapsRules.resolve(point, only, int(dice[0]), int(dice[1]), working)
		var destination := ""
		for next_kind in result.bets:
			if result.bets[next_kind] > 0: destination = next_kind
		if destination != "" and destination != kind:
			flights.append({"from": kind, "to": destination, "seat": seat, "amount": bets[kind], "pay": false})
		elif destination == "" and result.credit == 0:
			flights.append({"from": kind, "to": "bank", "seat": seat, "amount": bets[kind], "pay": false})
		if result.credit > 0:
			flights.append({"from": "bank", "to": "player", "seat": seat, "amount": result.credit, "pay": true})

func label(at: Vector2, value: String, font_size: int = 16, color: Color = INK, width: float = -1) -> void:
	draw_string(font, at, value, HORIZONTAL_ALIGNMENT_LEFT, width, font_size, color)

func box(rect: Rect2, color: Color, radius: int = 12, border: Color = Color.TRANSPARENT, thickness: int = 1) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.border_color = border
	style.set_border_width_all(thickness)
	draw_style_box(style, rect)

func chip_at(at: Vector2, value: float, radius: float = 17, tint: Color = Color.TRANSPARENT) -> void:
	var denomination := 1
	for amount in [1, 5, 25, 100, 500, 1000]:
		if value >= amount: denomination = amount
	draw_texture_rect(PitBoss.texture("casino_play/shared/chips/chip_%d.svg" % denomination), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false)
	var text := str(int(value))
	var fs := 12 if radius < 20 else 15
	label(at + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, 5), text, fs)

func button(rect: Rect2, text: String, action: String, enabled: bool = true) -> void:
	box(rect, Color("263e47") if enabled else Color("172c32"), 10, Color("62756e"))
	label(rect.position + Vector2(10, rect.size.y / 2 + 5), text, 15, INK if enabled else Color("728983"), rect.size.x - 16)
	targets.append({"rect": rect, "kind": "@" + action, "enabled": enabled})

func cell(rect: Rect2, kind: String, title: String, table: Dictionary, sub: String = "") -> void:
	spots[kind] = rect.get_center() + Vector2(0, 12)
	var over := rect.has_point(pointer) and dragging != ""
	box(rect, Color("18762b") if over else Color("065d18"), 0, Color("f1eed9"))
	label(rect.position + Vector2(8, 21), title, 15, INK, rect.size.x - 12)
	if sub != "": label(rect.position + Vector2(8, 38), sub, 10, GOLD, rect.size.x - 12)
	targets.append({"rect": rect, "kind": kind, "enabled": true})

func player_at(seat: int) -> Vector2:
	if seat < 0: return Vector2(canvas.x - 40 if portrait else 180, canvas.y - 183 if portrait else canvas.y - 154)
	if portrait: return Vector2(27 if seat < 4 else canvas.x - 27, 125 + (seat % 4) * 92)
	return Vector2(180 + (seat if seat < 4 else seat - 3) * 220, 79 if seat < 4 else canvas.y - 154)

func avatar(at: Vector2, name: String, shooter: bool, owner: bool = false) -> void:
	draw_circle(at + Vector2(0, 5), 20, Color("354454") if not owner else Color("836c43"))
	draw_circle(at + Vector2(0, -5), 10, Color("d6b99a"))
	if shooter: draw_arc(at, 25, 0, TAU, 40, GOLD, 2)
	label(at + Vector2(-27, 38), name, 11, GOLD if shooter else INK, 54)

func endpoint(kind: String, seat: int) -> Vector2:
	if kind == "bank": return Vector2(canvas.x / 2, 78) if portrait else Vector2(31, 315)
	if kind == "player": return player_at(seat)
	if spots.has(kind): return spots[kind] + Vector2(seat * 5 if seat >= 0 else 0, 0)
	# Traveled contracts sit on the matching number, differentiated by stack color.
	if kind.begins_with("come_") or kind.begins_with("dont_come_"):
		var n := int(kind.get_slice("_", kind.get_slice_count("_") - 1))
		if CrapsRules.PLACE_KEYS.has(n): return spots.get(CrapsRules.PLACE_KEYS[n], Vector2(canvas.x / 2, 230)) + Vector2(-12 if kind.begins_with("dont") else 12, 16)
	return Vector2(canvas.x / 2, 570 if portrait else 300)

func stacks(bets: Dictionary, seat: int) -> void:
	for kind in bets:
		var amount := float(bets[kind])
		if amount <= 0: continue
		var at := endpoint(kind, seat)
		for i in range(mini(4, maxi(1, ceili(amount / 25)))):
			chip_at(at - Vector2(0, i * 3), amount, 12 if seat >= 0 else 16, Color("596ca2") if seat >= 0 else Color("b3484e"))

func centered(rect: Rect2, text: String, fs: int, color: Color = INK) -> void:
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	label(rect.get_center() + Vector2(-text_size.x / 2, fs * 0.35), text, fs, color)

func printed_die(at: Vector2, value: int) -> void:
	box(Rect2(at - Vector2(9, 9), Vector2(18, 18)), Color("d32d2d"), 1, INK)
	var dots := [Vector2(-4, -4), Vector2(4, 4)]
	if value >= 4: dots.append_array([Vector2(4, -4), Vector2(-4, 4)])
	if value % 2 == 1: dots.append(Vector2.ZERO)
	for dot in dots: draw_circle(at + dot, 1.6, INK)

func traditional_layout(rail: Rect2, table: Dictionary, shown: Dictionary) -> void:
	var area := rail.grow(-12)
	var x := area.position.x
	var y := area.position.y
	var width := area.size.x if portrait else area.size.x * 0.75
	var side := 28.0 if portrait else 42.0
	var dc := 42.0 if portrait else 70.0
	var top_h := 122.0 if portrait else 153.0
	var main_x := x + side + dc
	var number_w := (width - side - dc) / 6
	# The continuous Pass / Don't Pass bands wrap the left and bottom edges.
	cell(Rect2(x, y, side, 324), "pass", "", table)
	draw_set_transform(offset + Vector2(x + side / 2, y + 245) * factor, -PI / 2, Vector2.ONE * factor)
	label(Vector2.ZERO, "PASS LINE", 14, INK)
	draw_set_transform(offset, 0, Vector2.ONE * factor)
	cell(Rect2(x + side, y, dc, top_h), "dont_come", "", table)
	centered(Rect2(x + side, y + 30, dc, 28), "DON'T", 11)
	centered(Rect2(x + side, y + 52, dc, 28), "COME", 11)
	centered(Rect2(x + side, y + 78, dc, 28), "BAR 12", 10, GOLD)
	for i in range(6):
		var n: int = CrapsRules.NUMBERS[i]
		var rect := Rect2(main_x + i * number_w, y, number_w, top_h)
		cell(rect, CrapsRules.PLACE_KEYS[n], "", table)
		draw_line(Vector2(rect.position.x, y + 24), Vector2(rect.end.x, y + 24), INK)
		draw_line(Vector2(rect.position.x, y + 40), Vector2(rect.end.x, y + 40), INK)
		draw_line(Vector2(rect.position.x, rect.end.y - 17), Vector2(rect.end.x, rect.end.y - 17), INK)
		var title := "SIX" if n == 6 else ("NINE" if n == 9 else str(n))
		centered(Rect2(rect.position.x, y + 43, number_w, top_h - 63), title, (14 if portrait else 30) if n in [6, 9] else (29 if portrait else 62), Color("ffe62b"))
		spots[CrapsRules.PLACE_KEYS[n]] = Vector2(rect.get_center().x, rect.end.y - 15)
		if int(shown.point) == n:
			var at := Vector2(rect.get_center().x, y + 13)
			draw_circle(at, 12, INK)
			label(at + Vector2(-9, 4), "ON", 10, Color("163b34"))
	var inner_x := x + side
	var inner_w := width - side
	var come_y := y + top_h
	cell(Rect2(inner_x, come_y, inner_w, 57), "come", "", table)
	centered(Rect2(inner_x, come_y, inner_w, 57), "C O M E", 26 if portrait else 36, Color("ee3434"))
	var field_y := come_y + 57
	cell(Rect2(inner_x, field_y, inner_w, 64), "field", "", table)
	centered(Rect2(inner_x, field_y + 3, inner_w, 26), "2   3 · 4 · 9 · 10 · 11   12", 13 if portrait else 23, Color("ffe62b"))
	centered(Rect2(inner_x, field_y + 30, inner_w, 30), "FIELD · 2 DOUBLE / 12 TRIPLE", 10 if portrait else 16, GOLD)
	var dp_y := field_y + 64
	cell(Rect2(inner_x, dp_y, inner_w, 38), "dont_pass", "", table)
	centered(Rect2(inner_x, dp_y, inner_w, 38), "DON'T PASS · BAR 12", 14 if portrait else 19)
	cell(Rect2(x, dp_y + 38, width, 38), "pass", "", table)
	centered(Rect2(x, dp_y + 38, width, 38), "P A S S   L I N E", 17 if portrait else 24)
	# Odds sit behind their line; separate drop targets keep placement unambiguous.
	cell(Rect2(x, dp_y + 78, width / 2, 35), "odds", "PASS ODDS",  table)
	cell(Rect2(x + width / 2, dp_y + 78, width / 2, 35), "lay_odds", "LAY ODDS", table)
	var px := x if portrait else x + width + 12
	var py := dp_y + 150 if portrait else y + 38
	var pw := width if portrait else area.size.x - width - 12
	centered(Rect2(px, py - 26, pw, 25), "HARDWAYS", 13, INK)
	var kinds := ["hard_4", "hard_6", "hard_8", "hard_10"]
	for i in range(4):
		var rect := Rect2(px + (i % 2) * pw / 2, py + (i / 2) * 52, pw / 2, 52)
		cell(rect, kinds[i], "", table)
		printed_die(rect.position + Vector2(rect.size.x / 2 - 12, 13), i + 2)
		printed_die(rect.position + Vector2(rect.size.x / 2 + 12, 13), i + 2)
		centered(Rect2(rect.position + Vector2(0, 26), Vector2(rect.size.x, 23)), "7 to 1" if i in [0, 3] else "9 to 1", 11)
	if not portrait:
		py += 137
		centered(Rect2(px, py - 27, pw, 25), "ONE ROLL BETS", 14)
		var props := ["any_seven", "any_craps", "aces", "yo", "boxcars", "ace_deuce"]
		for i in range(props.size()):
			cell(Rect2(px + (i % 2) * pw / 2, py + (i / 2) * 49, pw / 2, 49), props[i], CrapsRules.name_for(props[i]), table, "%d to 1" % CrapsRules.PROP_PAY[props[i]])

func _draw() -> void:
	targets.clear()
	spots.clear()
	if sim == null or font == null or sim.joined < 0: return
	var table := sim.get_table(sim.joined)
	if table.is_empty(): return
	portrait = size.x < size.y * 0.95
	canvas = Vector2(420, 940) if portrait else Vector2(1100, 690)
	factor = minf(size.x / canvas.x, size.y / canvas.y)
	offset = (size - canvas * factor) / 2
	draw_set_transform(offset, 0, Vector2.ONE * factor)
	box(Rect2(Vector2(3, 4), canvas - Vector2(6, 8)), Color("0a161e"), 30)
	var rail := Rect2(53, 106, canvas.x - 106, canvas.y - 280)
	box(rail.grow(13), Color("48372d"), 42, Color("aa8351"), 3)
	box(rail.grow(5), Color("211f20"), 36)
	draw_texture_rect(PitBoss.texture("casino_play/craps/craps_felt_base.png"), rail, false)
	label(Vector2(18, 24), "PIT BOSS / CRAPS %02d" % sim.joined, 14, GOLD)
	label(Vector2(18, 46), "Personal Wallet $%d" % (previous.owner_bankroll if animation > 1 and not previous.is_empty() else sim.owner_bankroll), 16)
	label(Vector2(canvas.x - 160, 24), "POINT %d" % table.point if table.point else "COME-OUT", 15, GOLD)
	# Cropped half-table: crew at the center edge, players along the outer rail.
	var dealer := Vector2(canvas.x / 2 - 58, 77) if portrait else Vector2(27, 260)
	var stick := Vector2(canvas.x / 2 + 58, 77) if portrait else Vector2(27, 365)
	avatar(dealer, "DEALER", false)
	avatar(stick, "STICK", false)
	for i in range(7): chip_at(endpoint("bank", 0) + Vector2(0 if not portrait else -27 + i * 9, -27 + i * 9 if not portrait else 0), 25, 9)
	# Rubber back wall at the far end of the visible half.
	if portrait:
		for i in range(19): draw_line(Vector2(72 + i * 15, 111), Vector2(77 + i * 15, 122), Color("20332d"), 4)
	else:
		for i in range(24): draw_line(Vector2(canvas.x - 65, 131 + i * 15), Vector2(canvas.x - 76, 136 + i * 15), Color("20332d"), 4)
	for guest in sim.seated(sim.joined): avatar(player_at(int(guest.seat)), guest.name, int(table.shooter) == int(guest.id))
	avatar(player_at(-1), "YOU", int(table.shooter) == 0, true)
	var shown: Dictionary = previous.table if animation > 1.0 and not previous.is_empty() else table
	traditional_layout(rail, table, shown)
	stacks(shown.owner, -1)
	var guests: Array = previous.guests if animation > 1.0 and not previous.is_empty() else sim.seated(sim.joined)
	for guest in guests: stacks(guest.bets, int(guest.seat))
	var pocket := shooter_pocket()
	if can_throw() or dice_held:
		label(pocket + Vector2(-52, 49), "HOLD & FLICK", 12, GOLD)
	if dice_held:
		var aim := pointer - origin
		var hand := free_hand_position()
		var end := hand + (Vector2.UP if portrait else Vector2.RIGHT) * 65
		draw_line(hand, end, GOLD, 3)
		draw_circle(end, 5, GOLD)
	for i in range(2):
		var separation := Vector2(-24 + i * 48, i * 4)
		var at := pocket + separation
		var value := int(table.dice[i])
		var angle := -0.1 if i == 0 else 0.12
		if animation > 1.0:
			var t := clampf((2.2 - animation) / 1.2, 0, 1)
			var hit_time := 0.58 - throw_power * 0.12
			if t < hit_time:
				var u := t / hit_time
				at = launch.lerp(impact, u) + Vector2(0, -sin(u * PI) * (25 + throw_power * 45))
			else:
				var u := (t - hit_time) / (1 - hit_time)
				at = impact.lerp(landing, u) + Vector2(0, -absf(sin(u * PI * 2)) * 20 * (1 - u))
			at += Vector2(-24 + i * 48, 0) if portrait else Vector2(0, -24 + i * 48)
			angle += (1 - t) * (12 + i * 5) * throw_power
			value = 1 + (int(clock * 19) + i * 3) % 6
		elif animation > 0:
			at = landing + (Vector2(-24 + i * 48, 0) if portrait else Vector2(0, -24 + i * 48))
		elif dice_held:
			at = free_hand_position() + separation
			angle += sin(clock * 23 + i) * 0.15
		elif delivery > 0:
			at = (endpoint("bank", 0) + (separation if portrait else Vector2(0, -24 + i * 48))).lerp(pocket + separation, smoothstep(0, 1, 1 - delivery / 0.85))
			draw_line(stick, at + Vector2(0, 15), Color("c5a071"), 3)
			draw_line(at + Vector2(-15, 15), at + Vector2(15, 15), Color("c5a071"), 3)
		elif not dice_ready:
			at = endpoint("bank", 0) + (separation if portrait else Vector2(0, -24 + i * 48))
		die(at, value, angle)
	if animation > 0 and animation <= 1.0:
		var t := 1.0 - animation
		for flight in flights:
			var a := endpoint(flight.from, int(flight.seat))
			var b := endpoint(flight.to, int(flight.seat))
			var at := a.lerp(b, smoothstep(0, 1, t))
			if flight.to == "bank":
				draw_line(endpoint("bank", 0) + Vector2(58, 0), at, Color("c5a071"), 3)
				draw_line(at + Vector2(-10, 3), at + Vector2(10, 3), Color("c5a071"), 3)
			chip_at(at, flight.amount, 16, GOLD if flight.pay else Color("b3484e"))
			if flight.pay: label(at + Vector2(16, -8), "+$%d" % flight.amount, 13, GOLD)
	var info_y := canvas.y - 126
	var phase := "%s has the dice" % sim.shooter_name(table)
	if animation > 1: phase = "Dice in motion…"
	elif animation > 0: phase = "Paying the table…"
	elif delivery > 0: phase = "Dealer returning dice…"
	elif not dice_ready: phase = "Place bets • dealer preparing dice"
	elif int(table.shooter) == 0 and not sim.shooter_has_line(table): phase = "Place Pass / Don’t Pass to shoot" if int(table.point) == 0 else "No line bet • pass dice until come-out"
	elif int(table.shooter) == 0: phase = "Hold dice • flick UP" if portrait else "Hold dice • flick RIGHT"
	label(Vector2(18, info_y), phase, 14, GOLD, canvas.x - 36)
	tray = Rect2(12, canvas.y - 112, canvas.x - 24, 53)
	box(tray, Color("152932"), 12)
	for i in range(3):
		var value: int = [5, 25, 100][i]
		var at := Vector2(44 + i * 65, canvas.y - 86)
		if chip == value: draw_arc(at, 25, 0, TAU, 40, GOLD, 2)
		chip_at(at, value, 22)
		targets.append({"rect": Rect2(at - Vector2(27, 27), Vector2(54, 54)), "kind": "#" + str(value), "enabled": true})
	label(Vector2(226, canvas.y - 82), "Drag to bet" if portrait else "Drag chips to bet • drag your stack back here to remove it", 12, INK, canvas.x - 245)
	var by := canvas.y - 52
	var bw := (canvas.x - 30) / 4
	if int(table.shooter) == 0:
		button(Rect2(9, by, bw, 46), "Roll", "shoot", can_throw())
	else:
		button(Rect2(9, by, bw, 46), "Resume" if table.betting_hold else "Hold", "shoot", not locked and not busy())
	button(Rect2(13 + bw, by, bw, 46), "Pass dice" if table.shooter == 0 else ("Skip turn" if table.owner_queued else "Queue"), "pass", not busy())
	button(Rect2(17 + bw * 2, by, bw, 46), "More…", "more", not busy())
	button(Rect2(21 + bw * 3, by, bw, 46), "Leave", "leave", not busy())
	if not portrait: label(Vector2(255, canvas.y - 151), ("Dice in motion…" if animation > 1 else message), 13, TEAL, canvas.x - 275)
	else: label(Vector2(18, canvas.y - 147), ("Dice in motion…" if animation > 1 else message), 12, TEAL, canvas.x - 36)
	if dragging != "": chip_at(pointer, chip, 22)
	draw_set_transform(Vector2.ZERO)

func die(at: Vector2, value: int, angle: float) -> void:
	draw_set_transform(offset + at * factor, angle, Vector2.ONE * factor)
	draw_texture_rect(PitBoss.texture("casino_play/craps/die_%d.svg" % value), Rect2(-26, -26, 52, 52), false)
	draw_set_transform(offset, 0, Vector2.ONE * factor)

func _gui_input(event: InputEvent) -> void:
	if dice_held: return
	if event is InputEventMouseMotion:
		pointer = felt_position(event.position)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = felt_position(event.position)
		if event.pressed:
			origin = pointer
			for target in targets:
				if target.rect.has_point(pointer) and target.enabled:
					if target.kind.begins_with("#"):
						chip = float(target.kind.substr(1))
						action_requested.emit("chip:" + str(int(chip)))
						dragging = "chip"
					elif target.kind.begins_with("@"):
						action_requested.emit(target.kind.substr(1))
					elif not locked and not busy(): dragging = target.kind
					accept_event()
					return
		elif dragging != "":
			var held := dragging
			dragging = ""
			if locked or busy(): return
			if held != "chip" and tray.has_point(pointer):
				if CrapsRules.removable(held, int(sim.get_table(sim.joined).point)):
					sim.remove_bet(sim.joined, held)
					message = "Removable chips returned to your tray."
				else: message = "That contract stays until it resolves."
				action_requested.emit("refresh")
				return
			for target in targets:
				if target.rect.has_point(pointer) and not target.kind.begins_with("@") and not target.kind.begins_with("#"):
					var error := sim.bet_error(sim.joined, target.kind, chip)
					if error == "":
						bet_clicked.emit(target.kind)
						message = "%s: chip placed." % CrapsRules.name_for(target.kind)
					else: message = error
					break
			accept_event()
