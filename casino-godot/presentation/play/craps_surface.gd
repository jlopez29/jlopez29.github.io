extends "res://scripts/craps_layout.gd"
# Source-art coordinates. A single uniform transform drives felt, chips and input.
const FELT_SIZE := Vector2(1536, 1024)
const PLAY_SIZE := Vector2(1536, 1120)
const PRINTED_REGIONS := {
	"pass": Rect2(285, 790, 790, 80),
	"dont_pass": Rect2(290, 716, 785, 64),
	"dont_come": Rect2(160, 103, 120, 310),
	"come": Rect2(160, 427, 915, 140),
	"field": Rect2(290, 580, 785, 125),
	"hard_4": Rect2(1178, 314, 155, 82),
	"hard_6": Rect2(1344, 314, 153, 82),
	"hard_8": Rect2(1178, 408, 155, 79),
	"hard_10": Rect2(1344, 408, 153, 79),
	"any_seven": Rect2(1178, 560, 319, 52),
	"aces": Rect2(1178, 616, 155, 76),
	"boxcars": Rect2(1344, 616, 153, 76),
	# The center Horn rectangle is deliberately excluded from both regions.
	"yo": Rect2(1178, 704, 120, 78),
	"ace_deuce": Rect2(1380, 704, 117, 78),
	"any_craps": Rect2(1178, 795, 319, 49),
}
const NUMBER_EDGES := [286, 424, 565, 709, 852, 997, 1155]
var layouts := {}
var display_signature: Array = []
const ROLL_SECONDS := 1.2
const SETTLE_SECONDS := 1.0
const RETURN_SECONDS := 1.3
const PLAYER_COLORS := [Color("edcf78"), Color("72aaff"), Color("ee88be"), Color("82d890"), Color("ba96ec"), Color("ed9974"), Color("77d6d9"), Color("e5e8ef")]
var animation_duration := ROLL_SECONDS + SETTLE_SECONDS
var observed_sim: PitBossGameContext
var resting_dice := Vector2(1130, 920)
var return_from := Vector2.ZERO
var return_to := Vector2.ZERO
var pan_distance := 0.0
var mouse_down := false
var drag_stack := false
var chip_positions := {}
var reference_dice: Array = []
var rebound := Vector2.ZERO
const DICE_BOUNDS := Rect2(110, 95, 990, 785)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null or sim.joined < 0:
		if dice_held: cancel_throw()
		return
	var mobile := get_viewport_rect().size.x < 1000
	var minimum := Vector2(1300, 948) if mobile else Vector2.ZERO
	if custom_minimum_size != minimum:
		custom_minimum_size = minimum
		if mobile: call_deferred("focus_line")
	clock += delta
	var animating := animation > 0 or dice_held or delivery > 0
	var table := sim.get_table(sim.joined)
	if observed_sim != sim or table_id != sim.joined:
		initialize_table(table)
		if mobile: call_deferred("focus_line")
	animation = maxf(0, animation - delta)
	if int(table.rolls) != last_roll: capture_roll(table)
	if animation <= SETTLE_SECONDS and int(table.rolls) > 0:
		reference_dice = table.dice.duplicate()
	if animation <= 0:
		for kind in chip_positions.keys():
			if float(table.owner.get(kind, 0)) <= 0: chip_positions.erase(kind)
	if animation <= 0:
		if shooter_seen != int(table.shooter):
			# A handoff starts at the visible dice, even if the shooter changes mid-return.
			resting_dice = dice_center()
			shooter_seen = int(table.shooter)
			reset_dice()
		if not locked and not dice_held and not dice_ready:
			if delivery > 0:
				delivery = maxf(0, delivery - delta)
				if delivery == 0:
					dice_ready = true
					resting_dice = return_to
			else:
				betting_wait -= delta
				if betting_wait <= 0:
					return_from = resting_dice
					return_to = shooter_pocket()
					delivery = RETURN_SECONDS
	if mobile and not mouse_down and (animation > 0 or delivery > 0): follow_dice(delta)
	var guests := sim.seated(sim.joined)
	var next := [table.dice, table.point, table.owner, table.shooter, guests.map(func(g): return [g.id, g.seat, g.bets, g.wallet]), locked, size, dice_ready]
	if next != display_signature or animating or delivery > 0:
		display_signature = next.duplicate(true)
		if animation <= 0: previous = snapshot(table)
		queue_redraw()

func initialize_table(table: Dictionary) -> void:
	observed_sim = sim
	table_id = sim.joined
	last_roll = int(table.rolls)
	animation = 0
	flights.clear()
	chip_positions.clear()
	reference_dice = table.dice.duplicate() if int(table.rolls) > 0 else []
	resting_dice = endpoint("bank", -1)
	shooter_seen = int(table.shooter)
	reset_dice()
	previous = snapshot(table)

func snapshot(table: Dictionary) -> Dictionary:
	# Only capture the visible participants and fields needed to animate this roll.
	var guests: Array = []
	for guest in sim.seated(int(table.id)):
		guests.append({"id": guest.id, "seat": guest.seat, "name": guest.name, "wallet": guest.wallet, "bets": guest.bets.duplicate(true)})
	return {"table": {"owner": table.owner.duplicate(true), "point": table.point, "owner_working": table.owner_working, "rolls": table.rolls, "shooter": table.shooter, "minimum": table.minimum}, "guests": guests}

func prepare_roll(table: Dictionary) -> void:
	if observed_sim != sim or table_id != sim.joined: initialize_table(table)
	previous = snapshot(table)

func capture_roll(table: Dictionary) -> void:
	if int(table.rolls) == last_roll: return
	if not throw_pending:
		throw_power = 0.55
		throw_aim = 0.0
		plan_throw(int(previous.table.shooter) if not previous.is_empty() else int(table.shooter))
	throw_pending = false
	reset_dice()
	flights.clear()
	# Reuse the existing deterministic presentation resolver, never settle accounts here.
	# A skipped simulation roll has no trustworthy pre-roll snapshot to animate.
	if not previous.is_empty() and int(previous.table.rolls) == int(table.rolls) - 1:
		var before: Dictionary = previous.table
		var expected := CrapsRules.resolve(int(before.point), before.owner, int(table.dice[0]), int(table.dice[1]), bool(before.owner_working))
		if expected.bets == table.owner and is_equal_approx(float(expected.credit), float(table.history[0].credit)):
			settlement(before.owner, int(before.point), table.dice, bool(before.owner_working), -1)
		var seated_by_id := {}
		for guest in sim.seated(int(table.id)): seated_by_id[int(guest.id)] = guest
		for guest in previous.guests:
			var current: Dictionary = seated_by_id.get(int(guest.id), {})
			if current.is_empty(): continue
			var bets: Dictionary = guest.bets.duplicate(true)
			var added := 0.0
			if sim.operating(table) and int(before.point) == 0 and bets.pass == 0 and float(guest.wallet) >= float(before.minimum):
				added = minf(sim.guest_wager(table, current), float(guest.wallet))
				bets.pass = added
			var result := CrapsRules.resolve(int(before.point), bets, int(table.dice[0]), int(table.dice[1]))
			if result.bets == current.bets and is_equal_approx(float(result.credit), float(current.wallet) - float(guest.wallet) + added):
				guest.bets = bets
				settlement(bets, int(before.point), table.dice, false, int(guest.seat))
	last_roll = int(table.rolls)
	animation = animation_duration
	resting_dice = landing
	message = str(table.result).replace("·", "|").replace("’", "'")

func reset_dice() -> void:
	cancel_throw()
	dice_ready = false
	delivery = 0
	betting_wait = 0.8

func plan_throw(shooter: int = -99, released_at: Vector2 = Vector2(-1, -1)) -> void:
	launch = shooter_pocket(shooter) if released_at.x < 0 else released_at
	launch = launch.clamp(DICE_BOUNDS.position, DICE_BOUNDS.end)
	var direction := Vector2(throw_aim, -1).normalized() if portrait else Vector2(1, throw_aim).normalized()
	# Trace the actual flick to the first cushion, including side/corner hits.
	var normal := Vector2.DOWN if portrait else Vector2.LEFT
	var travel := (DICE_BOUNDS.position.y - launch.y) / direction.y if portrait else (DICE_BOUNDS.end.x - launch.x) / direction.x
	if absf(direction.x) > 0.001:
		var side := ((DICE_BOUNDS.end.x if direction.x > 0 else DICE_BOUNDS.position.x) - launch.x) / direction.x
		if side < travel:
			travel = side
			normal = Vector2.LEFT if direction.x > 0 else Vector2.RIGHT
	if absf(direction.y) > 0.001:
		var side := ((DICE_BOUNDS.end.y if direction.y > 0 else DICE_BOUNDS.position.y) - launch.y) / direction.y
		if side < travel:
			travel = side
			normal = Vector2.UP if direction.y > 0 else Vector2.DOWN
	impact = launch + direction * maxf(0, travel)
	# Cushion absorbs most normal momentum; felt friction slows the rebound.
	rebound = (direction - normal * direction.dot(normal)) * 0.55 - normal * direction.dot(normal) * 0.38
	landing = (impact + rebound * (100 + throw_power * 210)).clamp(DICE_BOUNDS.position, DICE_BOUNDS.end)

func dice_center() -> Vector2:
	if dice_held: return free_hand_position()
	if animation > SETTLE_SECONDS:
		var t := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
		var hit := 0.58 - throw_power * 0.12
		if t < hit:
			var u := t / hit
			return launch.lerp(impact, u) + Vector2(0, -sin(u * PI) * (35 + throw_power * 65))
		var u := (t - hit) / (1 - hit)
		return impact.lerp(landing, 1 - pow(1 - u, 2)) + Vector2(0, -absf(sin(u * PI * 3)) * 24 * pow(1 - u, 2))
	if delivery > 0:
		var t := 1 - delivery / RETURN_SECONDS
		var bank := endpoint("bank", -1)
		return return_from.lerp(bank, smoothstep(0, 0.45, t)) if t < 0.45 else bank.lerp(return_to, smoothstep(0.45, 1, t))
	return resting_dice

func region(rect: Rect2, kind: String, clickable: bool = true) -> void:
	spots[kind] = rect.get_center()
	layouts[kind] = rect
	if clickable: targets.append({"rect": rect, "kind": kind, "enabled": true})

func supplemental(rect: Rect2, kind: String) -> void:
	region(rect, kind)
	box(rect, Color("12372b"), 6, GOLD)
	centered(rect, CrapsRules.name_for(kind).replace("’", "'"), 19)

func correction(rect: Rect2, text: String) -> void:
	box(rect, Color("06441c"), 0)
	centered(rect, text, 20)

func printed_pair(center: Vector2, first: int, second: int) -> void:
	# Correct decorative dice that do not match the supported named wager.
	for i in range(2):
		draw_texture_rect(PitBoss.texture("casino_play/craps/die_%d.svg" % (first if i == 0 else second)), Rect2(center + Vector2(-48 + i * 54, -21), Vector2(42, 42)), false)

func wager_art(kind: String, first: int, second: int, caption: String) -> void:
	# Mask the entire printed cell before drawing correct wager faces and payout.
	# The opaque mask avoids red dice/shadows peeking around the new faces.
	var rect: Rect2 = PRINTED_REGIONS[kind]
	box(rect, Color("06441c"), 0)
	printed_pair(Vector2(rect.get_center().x, rect.position.y + 27), first, second)
	centered(Rect2(rect.position + Vector2(0, rect.size.y - 26), Vector2(rect.size.x, 26)), caption, 20)

func _draw() -> void:
	targets.clear()
	spots.clear()
	layouts.clear()
	if sim == null or font == null or sim.joined < 0: return
	var table := sim.get_table(sim.joined)
	if table.is_empty(): return
	canvas = PLAY_SIZE
	portrait = get_viewport_rect().size.x < get_viewport_rect().size.y
	factor = minf(size.x / PLAY_SIZE.x, size.y / PLAY_SIZE.y)
	offset = (size - PLAY_SIZE * factor) / 2
	draw_set_transform(offset, 0, Vector2.ONE * factor)
	# The full new felt is drawn once, without cropping or aspect distortion.
	draw_texture_rect(PitBoss.texture("casino_play/craps/craps_felt_layout.png"), Rect2(Vector2.ZERO, FELT_SIZE), false)
	for kind in PRINTED_REGIONS: region(PRINTED_REGIONS[kind], kind)
	# The straight and left Pass bands share a key; curved/unsupported areas do not.
	targets.append({"rect": Rect2(37, 245, 57, 414), "kind": "pass", "enabled": true})
	for i in range(6):
		var n: int = CrapsRules.NUMBERS[i]
		var x: float = NUMBER_EDGES[i] + 5
		var w: float = NUMBER_EDGES[i + 1] - x - 5
		region(Rect2(x, 211, w, 163), CrapsRules.PLACE_KEYS[n])
		region(Rect2(x, 103, w / 2, 45), "come_%d" % n, false)
		region(Rect2(x + w / 2, 103, w / 2, 45), "dont_come_%d" % n, false)
		region(Rect2(x, 153, w / 2, 54), "come_odds_%d" % n, float(table.owner["come_%d" % n]) > 0)
		region(Rect2(x + w / 2, 153, w / 2, 54), "dont_come_odds_%d" % n, float(table.owner["dont_come_%d" % n]) > 0)
		centered(Rect2(x, 103, w, 45), "COME / DC", 15, GOLD)
		centered(Rect2(x, 159, w, 42), "ODDS / LAY", 14, GOLD)
		if int(table.point) == n:
			box(Rect2(x + 8, 383, w - 16, 31), Color("111d20"), 5, GOLD)
			centered(Rect2(x + 8, 383, w - 16, 31), "POINT ON", 18, GOLD)
	# No targets for Big 6/8, C/E or Horn. All supported hardways are explicit.
	wager_art("hard_4", 2, 2, "Hard 4 | 7:1")
	wager_art("hard_6", 3, 3, "Hard 6 | 9:1")
	wager_art("hard_8", 4, 4, "Hard 8 | 9:1")
	wager_art("hard_10", 5, 5, "Hard 10 | 7:1")
	wager_art("aces", 1, 1, "Aces 2 | 30:1")
	wager_art("boxcars", 6, 6, "12 | 30:1")
	# Mask the full lower row, including shadows; retain a non-clickable Horn marker.
	box(Rect2(1178, 700, 319, 88), Color("06441c"), 0)
	printed_pair(Vector2(1240, 727), 5, 6)
	printed_pair(Vector2(1438, 727), 1, 2)
	box(Rect2(1305, 690, 70, 56), Color("12372b"), 0, INK, 2)
	centered(Rect2(1305, 693, 70, 25), "HORN", 18, GOLD)
	centered(Rect2(1305, 717, 70, 25), "BET", 18, GOLD)
	correction(Rect2(1179, 756, 120, 28), "Yo 11 | 15:1")
	correction(Rect2(1381, 756, 117, 28), "3 | 15:1")
	correction(Rect2(841, 678, 181, 29), "12 pays 3:1")
	# Supported wagers without a printed area get explicit labeled regions.
	supplemental(Rect2(285, 875, 790, 42), "odds")
	supplemental(Rect2(110, 718, 168, 62), "lay_odds")
	for i in range(6):
		var denomination: int = [1, 5, 25, 100, 500, 1000][i]
		var at := Vector2(64 + i * 106, 1062)
		chip_at(at, denomination, 25)
		if chip == denomination: draw_arc(at, 29, 0, TAU, 36, GOLD, 2)
		targets.append({"rect": Rect2(at - Vector2(32, 32), Vector2(64, 64)), "kind": "#%d" % denomination, "enabled": true})
	tray = Rect2(730, 1030, 780, 64)
	box(tray, Color("111d20"), 6, Color("51452b"))
	centered(tray, "Drag removable chips here to take down", 20, GOLD)
	box(Rect2(1178, 50, 320, 185), Color("10291f"), 8, GOLD)
	centered(Rect2(1180, 58, 316, 42), "POINT OFF" if int(table.point) == 0 else "POINT %d / ON" % table.point, 24, GOLD)
	centered(Rect2(1180, 100, 316, 30), "You have the dice" if int(table.shooter) == 0 else sim.shooter_name(table) + " has the dice", 19)
	if reference_dice.size() == 2:
		centered(Rect2(1180, 139, 316, 26), "LAST ROLL: %d + %d = %d" % [reference_dice[0], reference_dice[1], int(reference_dice[0]) + int(reference_dice[1])], 18, GOLD)
		for i in range(2):
			draw_texture_rect(PitBoss.texture("casino_play/craps/die_%d.svg" % int(reference_dice[i])), Rect2(1294 + i * 48, 176, 36, 36), false)
	else:
		centered(Rect2(1180, 145, 316, 30), "LAST ROLL: --", 18, GOLD)
	draw_players(table)
	draw_dice(table)
	var shown: Dictionary = previous.table if animation > SETTLE_SECONDS and not previous.is_empty() else table
	draw_wagers(shown.owner, -1)
	var guests: Array = previous.guests if animation > SETTLE_SECONDS and not previous.is_empty() else sim.seated(sim.joined)
	for guest in guests: draw_wagers(guest.bets, int(guest.seat))
	if animation > 0 and animation <= SETTLE_SECONDS:
		var t := smoothstep(0, 1, 1 - animation / SETTLE_SECONDS)
		for flight in flights:
			var at := endpoint(str(flight.from), int(flight.seat)).lerp(endpoint(str(flight.to), int(flight.seat)), t)
			if flight.to == "bank":
				draw_line(endpoint("bank", -1), at + Vector2(0, 14), Color("c5a071"), 4)
				draw_line(at + Vector2(-15, 14), at + Vector2(15, 14), Color("c5a071"), 4)
			chip_at(at, float(flight.amount), 17, player_color(int(flight.seat)))
		var owner_returned := 0.0
		for flight in flights:
			if flight.pay and int(flight.seat) == -1: owner_returned += float(flight.amount)
		if owner_returned > 0:
			centered(Rect2(70, 923, 220, 28), "$%d returned" % owner_returned, 20, player_color(-1))
	if dragging != "":
		var amount := float(table.owner.get(dragging, chip)) if drag_stack else chip
		chip_at(pointer, amount, 22)
	draw_set_transform(Vector2.ZERO)

func player_at(seat: int) -> Vector2:
	return Vector2(180 if seat < 0 else 330 + seat * 125, 968)

func player_color(seat: int) -> Color:
	return PLAYER_COLORS[clampi(seat + 1, 0, PLAYER_COLORS.size() - 1)]

func draw_players(table: Dictionary) -> void:
	var players: Array = [{"seat": -1, "name": "YOU", "id": 0}]
	players.append_array(sim.seated(sim.joined))
	for player in players:
		var seat := int(player.seat)
		var at := player_at(seat)
		chip_at(at, 0, 16, player_color(seat))
		if int(player.id) == int(table.shooter): draw_arc(at, 23, 0, TAU, 36, GOLD, 3)
		centered(Rect2(at + Vector2(-58, 20), Vector2(116, 28)), str(player.name).get_slice(" |", 0).left(11), 18, player_color(seat))
	centered(Rect2(1050, 945, 160, 28), "DEALER", 18, GOLD)
	var phase := "Hold dice, flick UP" if portrait else "Hold dice, flick RIGHT"
	if animation > SETTLE_SECONDS: phase = "Dice rolling to the wall"
	elif animation > 0: phase = "Raking / paying the table"
	elif delivery > 0: phase = "Pulling dice back / pushing to shooter"
	elif not dice_ready: phase = "Dealer preparing dice"
	elif int(table.shooter) != 0: phase = sim.shooter_name(table) + " is shooting"
	centered(Rect2(380, 38, 750, 34), phase, 22, GOLD)

func draw_dice(table: Dictionary) -> void:
	var center := dice_center()
	if delivery > 0:
		var bank := endpoint("bank", -1)
		draw_line(bank + Vector2(60, -40), center + Vector2(0, 26), Color("c5a071"), 5)
		draw_line(center + Vector2(-52, 26), center + Vector2(52, 26), Color("c5a071"), 5)
	if dice_held:
		var direction := Vector2.UP if portrait else Vector2.RIGHT
		if gesture_velocity.length() > 80: direction = gesture_velocity.normalized()
		draw_line(center, center + direction * 85, GOLD, 4)
		draw_circle(center + direction * 85, 6, GOLD)
	for i in range(2):
		var at := center + Vector2(-27 + i * 54, i * 3)
		var angle := -0.1 if i == 0 else 0.12
		var value := int(table.dice[i])
		if animation > SETTLE_SECONDS:
			var t := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
			angle += (1 - t) * (12 + i * 5) * throw_power
			# Decorative cycling is deterministic and never reads the simulation RNG.
			value = 1 + (int(clock * 19) + i * 3) % 6
		elif dice_held: angle += sin(clock * 23 + i) * 0.15
		if animation > SETTLE_SECONDS:
			var progress := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
			at += Vector2((i * 2 - 1) * 12, (i * 2 - 1) * 17) * sin(progress * PI / 2)
			draw_ellipse_shadow(at)
		die(at, value, angle)
	if can_throw(): centered(Rect2(center + Vector2(-95, -60), Vector2(190, 30)), "HOLD & FLICK", 21, GOLD)

func draw_ellipse_shadow(at: Vector2) -> void:
	draw_circle(at + Vector2(3, 19), 16, Color(0, 0, 0, 0.22))

func draw_wagers(bets: Dictionary, seat: int) -> void:
	for kind in bets:
		var amount := float(bets[kind])
		if animation > 0 and animation <= SETTLE_SECONDS:
			for flight in flights:
				if int(flight.seat) == seat and flight.to == kind and not flight.pay:
					amount -= float(flight.amount)
		if amount <= 0 or not spots.has(kind): continue
		var small: bool = layouts[kind].size.y < 60 or layouts[kind].size.x < 100
		var radius := float((8 if small else 13) if seat >= 0 else (10 if small else 20))
		var layers := mini(7, maxi(1, ceili(amount / maxf(1, float(sim.get_table(sim.joined).minimum)))))
		for layer in range(layers):
			chip_at(endpoint(kind, seat) - Vector2(0, layer * 3), amount if layer == layers - 1 else 0, radius, player_color(seat))

func chip_at(at: Vector2, value: float, radius: float = 17, tint: Color = Color.TRANSPARENT) -> void:
	var color := player_color(-1) if tint == Color.TRANSPARENT else tint
	draw_texture_rect(PitBoss.texture("casino_play/shared/chips/chip_1.svg"), Rect2(at - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, color)
	draw_circle(at, radius * 0.65, Color("162025"))
	if value <= 0: return
	var text := str(int(value))
	var fs := 10 if radius < 14 else 14
	label(at + Vector2(-font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x / 2, fs * 0.35), text, fs)

func shooter_pocket(shooter: int = -99) -> Vector2:
	if shooter == -99: shooter = int(sim.get_table(sim.joined).shooter)
	if shooter < 0: return endpoint("bank", -1)
	var seat := -1
	for guest in sim.seated(sim.joined):
		if int(guest.id) == shooter: seat = int(guest.seat)
	return player_at(seat) + Vector2(0, -65)

func free_hand_position() -> Vector2:
	var hand := shooter_pocket() + pointer - origin
	return Vector2(clampf(hand.x, 80, 1450), clampf(hand.y, 80, 990))

func endpoint(kind: String, seat: int) -> Vector2:
	if kind == "bank": return Vector2(1130, 920)
	if kind == "player": return player_at(seat)
	if not spots.has(kind): return Vector2.ZERO
	var at: Vector2 = spots[kind]
	if seat < 0: return chip_positions.get(kind, at)
	var rect: Rect2 = layouts[kind]
	var shift: Vector2 = [Vector2(-1, -1), Vector2(0, -1), Vector2(1, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1), Vector2(1, 1)][clampi(seat, 0, 6)]
	return at + shift * Vector2(minf(32, rect.size.x / 3), minf(28, rect.size.y / 3))

func play_scroll() -> ScrollContainer:
	var node := get_parent()
	while node != null:
		if node is ScrollContainer: return node
		node = node.get_parent()
	return null

func target_at(at: Vector2) -> String:
	for target in targets:
		if target.enabled and target.rect.has_point(at): return str(target.kind)
	return ""

func place_chip(kind: String, at: Vector2) -> void:
	if kind.is_empty() or kind.begins_with("#") or locked or busy(): return
	var error := sim.bet_error(sim.joined, kind, chip)
	if error.is_empty():
		bet_clicked.emit(kind)
		chip_positions[kind] = at
	else: message = error
	queue_redraw()

func _can_drop_data(at: Vector2, data: Variant) -> bool:
	return data is Dictionary and data.get("type", "") == "craps_chip" and not locked and not busy() and not target_at((at - offset) / factor).is_empty()

func _drop_data(at: Vector2, data: Variant) -> void:
	chip = float(data.amount)
	action_requested.emit("chip:%d" % int(chip))
	var felt_at := (at - offset) / factor
	place_chip(target_at(felt_at), felt_at)

func _gui_input(event: InputEvent) -> void:
	if dice_held or factor <= 0 or sim == null or sim.joined < 0: return
	if event is InputEventMouseMotion:
		pointer = (event.position - offset) / factor
		if mouse_down:
			pan_distance += event.relative.length()
			if pan_distance > 10 and dragging == "":
				var scroll := play_scroll()
				if scroll != null:
					scroll.scroll_horizontal -= int(event.relative.x)
					scroll.scroll_vertical -= int(event.relative.y)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = (event.position - offset) / factor
		if event.pressed:
			mouse_down = true
			pan_distance = 0
			dragging = ""
			drag_stack = false
			var target := target_at(pointer)
			if target.begins_with("#"):
				chip = float(target.substr(1))
				action_requested.emit("chip:%d" % int(chip))
				dragging = "chip"
			elif not locked and not busy():
				for kind in sim.get_table(sim.joined).owner:
					if float(sim.get_table(sim.joined).owner[kind]) > 0 and spots.has(kind) and pointer.distance_to(endpoint(kind, -1)) < 30:
						dragging = kind
						drag_stack = true
		else:
			mouse_down = false
			if not locked and not busy():
				var target := target_at(pointer)
				if drag_stack and pan_distance > 10:
					if tray.has_point(pointer):
						var returned := sim.remove_bet(sim.joined, dragging)
						message = "Chips returned to your wallet." if returned > 0 else "That contract stays until it resolves."
						action_requested.emit("refresh")
					elif target == dragging:
						chip_positions[dragging] = pointer
				elif dragging == "chip" or pan_distance <= 10:
					place_chip(target, pointer)
			dragging = ""
			drag_stack = false
		queue_redraw()
		accept_event()

func focus_line() -> void:
	# Let container minimum-size propagation and scrollbar ranges settle first.
	await get_tree().process_frame
	await get_tree().process_frame
	var scroll := play_scroll()
	if scroll != null:
		scroll.scroll_horizontal = int(160 * factor)
		scroll.scroll_vertical = maxi(0, int(830 * factor - scroll.size.y / 2))

func _input(event: InputEvent) -> void:
	# The inherited dice gesture must respect the actual clipped play viewport.
	if not dice_held and (event is InputEventMouseButton or event is InputEventScreenTouch):
		var scroll := play_scroll()
		if scroll != null and not scroll.get_global_rect().has_point(event.position): return
	super._input(event)
	if dice_held:
		mouse_down = false
		dragging = ""
		drag_stack = false

func follow_dice(delta: float) -> void:
	var scroll := play_scroll()
	if scroll == null: return
	var at := offset + dice_center() * factor
	var blend := 1 - exp(-delta * 9)
	scroll.scroll_horizontal = int(lerpf(scroll.scroll_horizontal, maxf(0, at.x - scroll.size.x / 2), blend))
	scroll.scroll_vertical = int(lerpf(scroll.scroll_vertical, maxf(0, at.y - scroll.size.y / 2), blend))
