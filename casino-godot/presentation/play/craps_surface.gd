extends "res://scripts/craps_layout.gd"
# Source-art coordinates. A single uniform transform drives felt, chips and input.
const Chips = preload("res://presentation/play/chip_stack.gd")
const DragChip = preload("res://presentation/play/chip_drag.gd")
var drag_overlay: Control
var PLAY_SIZE := Vector2(1200, 760)
var layouts := {}
var display_signature: Array = []
const ROLL_SECONDS := 1.2
const SETTLE_SECONDS := 1.0
const RESULT_HOLD_SECONDS := 1.25
const ROLL_END := SETTLE_SECONDS + RESULT_HOLD_SECONDS
const RETURN_SECONDS := 1.3
var animation_duration := ROLL_SECONDS + ROLL_END
var observed_sim: PitBossGameContext
var resting_dice := Vector2(1130, 920)
var return_from := Vector2.ZERO
var return_to := Vector2.ZERO
var pan_distance := 0.0
var mouse_down := false
var drag_stack := false
var reference_dice: Array = []
var audio_wall := false
var audio_settled := false
var audio_bounced := false
var audio_point := 0
var audio_credit := 0.0
var audio_sum := 0
var audio_held := false
var rebound := Vector2.ZERO
var dice_bounds := Rect2(20, 20, 1160, 650)

# Camera state is independent of rolls, shooter changes and simulation refreshes.
var view_zoom := 1.0
var view_center := PLAY_SIZE / 2
var pan_mode := false
var remove_drop: Control
var input_overlay: Control
var options_overlay: Control
var VIEW_REGIONS := {}
var hover := ""
var context_menu: PopupMenu
var context_key := ""
var bet_press_started := 0.0
var printed_keys: Array[String] = []
var context_odds := ""
var context_choices: Array = []
var touch_points := {}
var gesture_active := false
var side_open := false
var side_touch_index := -1
var side_button: Button
const SIDE_KEYS := ["hard_4", "hard_6", "hard_8", "hard_10", "any_seven", "any_craps", "aces", "ace_deuce", "yo", "boxcars"]
const PROP_DICE := {"hard_4": [2, 2], "hard_10": [5, 5], "hard_6": [3, 3], "hard_8": [4, 4], "aces": [1, 1], "ace_deuce": [1, 2], "yo": [5, 6], "boxcars": [6, 6], "any_seven": [1, 6], "any_craps": [1, 2]}

func rebuild_geometry() -> void:
	var old_size := PLAY_SIZE
	portrait = size.x < size.y
	PLAY_SIZE = Vector2(600 if portrait else 1200, (600 if portrait else 1200) * size.y / maxf(1, size.x))
	if old_size != PLAY_SIZE:
		view_center = PLAY_SIZE / 2
	canvas = PLAY_SIZE
	dice_bounds = Rect2(Vector2(84, 44), PLAY_SIZE - Vector2(168, 108))
	layouts.clear()
	targets.clear()
	spots.clear()
	printed_keys.clear()
	var margin := 12.0
	var width := PLAY_SIZE.x - margin * 2
	var height := PLAY_SIZE.y - 100
	var main_width := width if portrait else width * 0.75
	var main_height := height
	var number_height := main_height * (0.34 if portrait else 0.29)
	var dc_width := main_width * 0.14
	region(Rect2(margin, margin, dc_width, number_height), "dont_come")
	var columns := 3 if portrait else 6
	var rows := 2 if portrait else 1
	var cell_width := (main_width - dc_width) / columns
	var cell_height := number_height / rows
	for i in range(6):
		var n: int = CrapsRules.NUMBERS[i]
		var rect := Rect2(margin + dc_width + (i % columns) * cell_width, margin + int(i / columns) * cell_height, cell_width, cell_height)
		region(rect, CrapsRules.PLACE_KEYS[n])
		spots[CrapsRules.PLACE_KEYS[n]] = rect.position + rect.size * Vector2(0.22, 0.42)
		# Contract metadata is never a printed row or an empty-area target.
		for j in range(4):
			var key: String = ["come_", "dont_come_", "come_odds_", "dont_come_odds_"][j] + str(n)
			var area := Rect2(rect.position + Vector2((j % 2) * cell_width / 2, cell_height * (0.52 + int(j / 2) * 0.24)), Vector2(cell_width / 2, cell_height * 0.24))
			region(area, key, false)
			spots[key] = area.position + area.size * Vector2(0.25, 0.5)
	var y := margin + number_height
	var short_landscape := not portrait and size.x < 1000
	for pair in [["come", 0.20 if portrait else (0.17 if short_landscape else 0.21)], ["field", 0.20 if portrait else (0.18 if short_landscape else 0.22)], ["dont_pass", 0.12 if portrait else (0.17 if short_landscape else 0.13)], ["pass", 0.14 if portrait else (0.19 if short_landscape else 0.15)]]:
		var band := main_height * float(pair[1])
		region(Rect2(margin, y, main_width, band), pair[0])
		y += band
	for pair in [["pass", "odds"], ["dont_pass", "lay_odds"]]:
		var parent: Rect2 = layouts[pair[0]]
		# Zero-height metadata lies on the exact existing border, not a new row.
		region(Rect2(parent.position.x, parent.end.y, parent.size.x, 0), pair[1], false)
	if portrait:
		for i in range(SIDE_KEYS.size()):
			var cell := Rect2(margin + (i % 2) * width / 2, 60 + int(i / 2) * (height - 60) / 5, width / 2, (height - 60) / 5)
			if not side_open: cell.position.x -= PLAY_SIZE.x * 2
			region(cell, SIDE_KEYS[i], side_open)
	else:
		side_open = false
		var prop_x := margin + main_width
		var prop_width := width - main_width
		var row_height := height / 6
		region(Rect2(prop_x, margin, prop_width, row_height), "any_seven")
		var keys := ["hard_4", "hard_10", "hard_6", "hard_8", "aces", "ace_deuce", "yo", "boxcars"]
		for i in range(keys.size()):
			region(Rect2(prop_x + (i % 2) * prop_width / 2, margin + (1 + int(i / 2)) * row_height, prop_width / 2, row_height), keys[i])
		region(Rect2(prop_x, margin + row_height * 5, prop_width, row_height), "any_craps")
	tray = Rect2(PLAY_SIZE.x * 0.68, PLAY_SIZE.y - 64, PLAY_SIZE.x * 0.3, 48)
	if portrait: tray = Rect2(PLAY_SIZE.x * 0.50, PLAY_SIZE.y - 64, PLAY_SIZE.x * 0.30, 48)
	if is_instance_valid(side_button):
		side_button.visible = portrait and not busy()
		side_button.position = Vector2(size.x - 60, size.y - 62)
		side_button.size = Vector2(52, 52)
		side_button.text = "Board" if side_open else "Hard"
		if sim != null and sim.joined >= 0 and not side_open:
			for key in SIDE_KEYS:
				if float(sim.get_table(sim.joined).owner.get(key, 0)) > 0: side_button.text = "Side *"; break
	VIEW_REGIONS = {"Lines / odds": layouts.pass.merge(layouts.dont_pass), "Numbers left": Rect2(margin + dc_width, margin, (main_width - dc_width) / 2, number_height), "Numbers right": Rect2(margin + dc_width + (main_width - dc_width) / 2, margin, (main_width - dc_width) / 2, number_height), "Come / Don't Come": layouts.come.merge(layouts.dont_come), "Field": layouts.field, "Hardways": layouts.hard_4.merge(layouts.hard_8), "Proposition bets": layouts.any_seven.merge(layouts.any_craps), "Dice": Rect2(shooter_pocket() - Vector2(60, 40), Vector2(120, 80))}

func update_view_transform() -> void:
	rebuild_geometry()
	var fitted := minf(size.x / PLAY_SIZE.x, size.y / PLAY_SIZE.y)
	factor = maxf(0.0001, fitted * view_zoom)
	var half_visible := size / (2 * factor)
	for axis in range(2):
		view_center[axis] = PLAY_SIZE[axis] / 2 if half_visible[axis] >= PLAY_SIZE[axis] / 2 else clampf(view_center[axis], half_visible[axis], PLAY_SIZE[axis] - half_visible[axis])
	offset = size / 2 - view_center * factor

func fit_view() -> void:
	if dice_held or mouse_down: return
	pan_mode = false
	view_zoom = 1
	view_center = PLAY_SIZE / 2
	update_view_transform()
	queue_redraw()

func zoom_view(multiplier: float, anchor: Vector2 = Vector2(-1, -1)) -> void:
	if dice_held or mouse_down: return
	if anchor.x < 0: anchor = size / 2
	var source := felt_position(anchor)
	view_zoom = clampf(view_zoom * multiplier, 1, 8)
	update_view_transform()
	view_center += source - felt_position(anchor)
	update_view_transform()
	queue_redraw()

func focus_region(title: String) -> void:
	if dice_held or mouse_down or not VIEW_REGIONS.has(title): return
	var rect: Rect2 = VIEW_REGIONS[title]
	if title == "Dice": rect = Rect2(shooter_pocket() - Vector2(130, 90), Vector2(260, 180))
	var fitted := minf(size.x / PLAY_SIZE.x, size.y / PLAY_SIZE.y)
	view_zoom = clampf(minf(size.x / (rect.size.x + 40), size.y / (rect.size.y + 40)) / maxf(fitted, 0.0001), 1, 8)
	if title == "Dice": view_zoom = clampf(maxf(view_zoom, 1.1 / maxf(fitted, 0.0001)), 1, 8)
	view_center = rect.get_center()
	update_view_transform()
	queue_redraw()

func begin_chip_drag(amount: float) -> void:
	if sim == null or sim.joined < 0 or locked or busy(): return
	var table := sim.get_table(sim.joined)
	if amount < float(table.minimum) or amount > sim.maximum_wager(table) or amount > sim.owner_bankroll: return
	pan_mode = false
	chip = amount
	action_requested.emit("chip:%.2f" % amount)
	mouse_down = true
	pan_distance = 0
	dragging = "chip"
	drag_stack = false

func _ready() -> void:
	super._ready()
	mouse_exited.connect(func(): hover = ""; queue_redraw())
	resized.connect(func(): update_view_transform(); queue_redraw())
	var drag_layer := CanvasLayer.new()
	drag_layer.layer = 100
	add_child(drag_layer)
	context_menu = PopupMenu.new()
	add_child(context_menu)
	context_menu.id_pressed.connect(func(id: int):
		if id >= 100:
			var choice: Dictionary = context_choices[id - 100]
			open_context(choice.key, int(choice.seat))
		elif id == 0:
			if not locked and not busy() and CrapsRules.removable(context_key, int(sim.get_table(sim.joined).point)):
				sim.remove_bet(sim.joined, context_key)
				action_requested.emit("refresh")
		elif id == 2: place_chip(context_odds, spots[context_odds])
		elif id == 3: place_chip(context_key, spots[context_key]))
	side_button = Button.new()
	add_child(side_button)
	side_button.z_index = 5
	side_button.tooltip_text = "Hardways and one-roll side bets / close"
	side_button.add_theme_font_size_override("font_size", 12)
	for state in ["normal", "hover", "pressed", "disabled"]:
		var style := PitBoss.box(Color("382e54"), GOLD, 26)
		style.content_margin_left = 4
		style.content_margin_right = 4
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		side_button.add_theme_stylebox_override(state, style)
	side_button.pressed.connect(func():
		if dice_held or busy(): return
		side_open = not side_open
		hover = ""
		mouse_down = false
		dragging = ""
		update_view_transform()
		queue_redraw())
	drag_overlay = DragChip.new()
	drag_layer.add_child(drag_overlay)

func update_drag_overlay() -> void:
	if dragging.is_empty() or not mouse_down or not is_visible_in_tree():
		drag_overlay.hide()
		return
	var table := sim.get_table(sim.joined)
	var amount := float(table.owner.get(dragging, chip)) if drag_stack else chip
	drag_overlay.update_chip(get_viewport().get_mouse_position(), amount)

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null or sim.joined < 0:
		if dice_held: cancel_throw()
		drag_overlay.hide()
		return
	update_drag_overlay()
	clock += delta
	var animating := animation > 0 or dice_held or delivery > 0
	var table := sim.get_table(sim.joined)
	if observed_sim != sim or table_id != sim.joined:
		initialize_table(table)
	if dice_held and not audio_held: AudioManager.play_game("craps", "pickup")
	audio_held = dice_held
	animation = maxf(0, animation - delta)
	if animation > 0:
		var progress := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
		var hit := 0.58 - throw_power * 0.12
		if not audio_wall and progress >= hit:
			audio_wall = true
			AudioManager.play_game("craps", "wall")
		if not audio_bounced and progress >= hit + (1 - hit) / 3:
			audio_bounced = true
			AudioManager.play_game("craps", "bounce")
		if not audio_settled and animation <= ROLL_END:
			audio_settled = true
			AudioManager.play_game("craps", "settle")
			var cue := "seven_out" if audio_point > 0 and audio_sum == 7 else "point_made" if audio_point > 0 and audio_sum == audio_point else "point" if audio_point == 0 and int(table.point) > 0 else "payout" if audio_credit > 0 else ""
			if not cue.is_empty(): AudioManager.play_game("craps", cue)
	if int(table.rolls) != last_roll: capture_roll(table)
	if animation <= ROLL_END and int(table.rolls) > 0:
		reference_dice = table.dice.duplicate()
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
	reference_dice = table.dice.duplicate() if int(table.rolls) > 0 else []
	resting_dice = endpoint("bank", -1)
	shooter_seen = int(table.shooter)
	reset_dice()
	previous = snapshot(table)
	fit_view()

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
	var skip := animation > 0 or int(table.rolls) != last_roll + 1
	var before := sim.craps_roll_before(table)
	if before.is_empty(): before = previous # Private games share the same presentation.
	if not throw_pending:
		throw_power = 0.55
		throw_aim = 0.0
		plan_throw(int(before.table.shooter) if not before.is_empty() else int(table.shooter))
	throw_pending = false
	reset_dice()
	flights.clear()
	# Only the latest contiguous roll may animate. Overlap/gaps finish visually
	# immediately instead of restarting an old snapshot for another 3.45 seconds.
	if not skip and not before.is_empty() and int(before.table.rolls) == int(table.rolls) - 1:
		settlement(before.table.owner, int(before.table.point), table.dice, bool(before.table.owner_working), -1)
		for guest in before.guests:
			settlement(guest.bets, int(before.table.point), table.dice, false, int(guest.seat))
	audio_point = int(before.get("table", {}).get("point", table.point))
	audio_credit = float(table.history[0].credit) if not table.history.is_empty() else 0.0
	audio_sum = int(table.dice[0]) + int(table.dice[1])
	audio_wall = false
	audio_bounced = false
	audio_settled = false
	last_roll = int(table.rolls)
	previous = snapshot(table)
	reference_dice = table.dice.duplicate()
	message = str(table.result).replace("·", "|").replace("’", "'")
	var seven_out := audio_point > 0 and audio_sum == 7
	if skip:
		animation = 0
		shooter_seen = int(table.shooter)
		dice_ready = true
		resting_dice = shooter_pocket()
		queue_redraw()
		return
	# Manual seven-out retains its immediate rake; observed CPU rolls show the throw.
	var manual_seven_out := seven_out and int(before.get("table", {}).get("shooter", 0)) == 0
	animation = SETTLE_SECONDS if manual_seven_out else animation_duration
	resting_dice = landing
	if manual_seven_out:
		audio_settled = true
		AudioManager.play_game("craps", "seven_out")
	else: AudioManager.play_game("craps", "throw")
	queue_redraw()

# Active chips and hit targets always use the same authoritative wager state.
# Collection/payout flights are disposable decoration, never live wagers.
func active_wagers(table: Dictionary) -> Array:
	var active: Array = [{"seat": -1, "bets": table.owner}]
	active.append_array(sim.seated(int(table.id)))
	return active

func reset_dice() -> void:
	cancel_throw()
	dice_ready = false
	delivery = 0
	betting_wait = 0.8

func plan_throw(shooter: int = -99, released_at: Vector2 = Vector2(-1, -1)) -> void:
	launch = shooter_pocket(shooter) if released_at.x < 0 else released_at
	launch = launch.clamp(dice_bounds.position, dice_bounds.end)
	var direction := Vector2(throw_aim, -1).normalized() if portrait else Vector2(1, throw_aim).normalized()
	# Trace the actual flick to the first cushion, including side/corner hits.
	var normal := Vector2.DOWN if portrait else Vector2.LEFT
	var travel := (dice_bounds.position.y - launch.y) / direction.y if portrait else (dice_bounds.end.x - launch.x) / direction.x
	if absf(direction.x) > 0.001:
		var side := ((dice_bounds.end.x if direction.x > 0 else dice_bounds.position.x) - launch.x) / direction.x
		if side < travel:
			travel = side
			normal = Vector2.LEFT if direction.x > 0 else Vector2.RIGHT
	if absf(direction.y) > 0.001:
		var side := ((dice_bounds.end.y if direction.y > 0 else dice_bounds.position.y) - launch.y) / direction.y
		if side < travel:
			travel = side
			normal = Vector2.UP if direction.y > 0 else Vector2.DOWN
	impact = launch + direction * maxf(0, travel)
	# Cushion absorbs most normal momentum; felt friction slows the rebound.
	rebound = (direction - normal * direction.dot(normal)) * 0.55 - normal * direction.dot(normal) * 0.38
	landing = (impact + rebound * (100 + throw_power * 210)).clamp(dice_bounds.position, dice_bounds.end)

func dice_center() -> Vector2:
	if dice_held: return free_hand_position()
	if animation > ROLL_END:
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
	if kind in ["pass", "dont_pass"]: spots[kind] = rect.position + rect.size * Vector2(0.34, 0.5)
	layouts[kind] = rect
	if clickable:
		printed_keys.append(kind)
		targets.append({"rect": rect, "kind": kind, "enabled": true})

func wager_caption(kind: String) -> String:
	if kind in CrapsRules.PLACE_KEYS.values(): return CrapsRules.name_for(kind).trim_prefix("Place ")
	if kind == "dont_come": return "DON'T COME"
	return CrapsRules.name_for(kind).to_upper()

func border_band(kind: String) -> Rect2:
	var line: Rect2 = layouts[kind]
	var half_width := (16.0 if portrait or size.x < 1000 else 9.0) / factor
	var inset := minf(12 / factor, line.size.x * 0.05)
	return Rect2(line.position + Vector2(inset, -half_width), Vector2(line.size.x - inset * 2, half_width * 2))

func draw_printed_cell(kind: String) -> void:
	var rect: Rect2 = layouts[kind]
	box(rect, Color(0.07, 0.29, 0.21, 0.45), 0, INK)
	if kind in CrapsRules.PLACE_KEYS.values():
		centered(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.46)), wager_caption(kind), int(minf(rect.size.x * 0.48, rect.size.y * 0.40)), GOLD)
	elif kind == "dont_come":
		for i in range(3):
			var text: String = ["DON'T", "COME", "BAR 12"][i]
			centered(Rect2(rect.position + Vector2(0, rect.size.y * (0.24 + i * 0.16)), Vector2(rect.size.x, rect.size.y * 0.16)), text, int(minf(20, rect.size.x * 0.22)), INK)
	elif PROP_DICE.has(kind):
		var fs := int(minf(20, rect.size.x / maxf(6, wager_caption(kind).length()) * 1.6))
		centered(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.32)), wager_caption(kind), fs)
		var die_size := minf(rect.size.y * (0.34 if side_open else 0.36), rect.size.x * 0.25)
		for i in range(2):
			var at := rect.get_center() + Vector2((i * 2 - 1) * die_size * 0.60, 0)
			draw_texture_rect(PitBoss.texture("casino_play/craps/die_%d.svg" % PROP_DICE[kind][i]), Rect2(at - Vector2.ONE * die_size / 2, Vector2.ONE * die_size), false)
		var pay := int(CrapsRules.PROP_PAY[kind]) if CrapsRules.PROP_PAY.has(kind) else 9 if kind in ["hard_6", "hard_8"] else 7
		var payout := "%d:1" % pay
		if kind == "any_seven": payout = "All 7 totals | " + payout
		elif kind == "any_craps": payout = "All 2, 3, 12 | " + payout
		centered(Rect2(rect.position + Vector2(0, rect.size.y * 0.77), Vector2(rect.size.x, rect.size.y * 0.20)), payout, int(minf(18, rect.size.x / maxf(6, payout.length()) * 1.6)), GOLD)
	elif kind in ["field"]:
		centered(Rect2(rect.position, Vector2(rect.size.x, rect.size.y * 0.56)), wager_caption(kind), int(minf(38 if kind == "field" else 23, rect.size.y * 0.34)))
		var detail := "2   3   4   9   10   11   12" if kind == "field" else "7  |  %d:1" % CrapsRules.PROP_PAY[kind] if kind == "any_seven" else "2 | 3 | 12"
		centered(Rect2(rect.position + Vector2(0, rect.size.y * 0.52), Vector2(rect.size.x, rect.size.y * 0.35)), detail, int(minf(25, rect.size.y * 0.23)), GOLD)
	else:
		centered(rect, wager_caption(kind), int(minf(42 if kind == "come" else 30, rect.size.y * 0.40)), Color("edb97b") if kind == "come" else INK)

func feedback_for(kind: String) -> Dictionary:
	if kind.is_empty() or not layouts.has(kind): return {}
	return preload("res://presentation/play/wager_feedback.gd").resolve(sim, kind, chip, layouts[kind], locked or busy())

func _draw() -> void:
	targets.clear()
	spots.clear()
	layouts.clear()
	if sim == null or font == null or sim.joined < 0: return
	var table := sim.get_table(sim.joined)
	if table.is_empty(): return
	update_view_transform()
	draw_set_transform(offset, 0, Vector2.ONE * factor)
	# Flat fabric only; geometry owns all printed regions and input.
	draw_texture_rect(PitBoss.texture("casino_play/blackjack/blackjack_felt_base.png"), Rect2(Vector2.ZERO, PLAY_SIZE), false)
	for kind in printed_keys:
		if side_open and kind not in SIDE_KEYS: continue
		draw_printed_cell(kind)
		if kind in CrapsRules.PLACE_KEYS.values() and CrapsRules.PLACE_KEYS.get(int(table.point), "") == kind:
			var rect: Rect2 = layouts[kind]
			box(Rect2(rect.position + Vector2(4, 4), Vector2(32, 18)), Color("111d20"), 2, GOLD)
			centered(Rect2(rect.position + Vector2(4, 4), Vector2(32, 18)), "ON", 12, GOLD)
	box(tray, Color("111d20"), 6, Color("51452b"))
	centered(tray, "TAKE DOWN", 18, GOLD)
	if side_open: centered(Rect2(0, 8, PLAY_SIZE.x, 42), "HARDWAYS / ONE-ROLL BETS", 23, GOLD)
	draw_players(table)
	if not side_open: draw_dice(table)
	for participant in active_wagers(table): draw_wagers(participant.bets, int(participant.seat))
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
	var preview := feedback_for(hover)
	var stack_preview := chips_at(pointer)
	if not preview.is_empty() and stack_preview.size() == 1 and stack_preview[0].key == hover:
		var entry: Dictionary = stack_preview[0]
		preview.amount = entry.amount
		preview.reason = "Tap for contract details." if int(entry.seat) < 0 else "Seat %d | Read-only wager." % (int(entry.seat) + 1)
		preview.valid = false
		if hover not in ["odds", "lay_odds"]: preview.region = chip_bounds(hover, int(entry.seat), float(entry.amount))
	if not preview.is_empty():
		var rect: Rect2 = preview.region
		var color := Color("ead189") if preview.valid else Color("d18a76")
		if hover in ["odds", "lay_odds"]:
			draw_line(rect.position, rect.end, Color(color, 0.25), 8 / factor)
			draw_line(rect.position, rect.end, color, 3 / factor)
		else:
			draw_rect(rect, Color(color, 0.18))
			draw_rect(rect, color, false, 2 / factor)
		if preview.valid and not mouse_down: chip_at(pointer, preview.amount, 12 / factor, color)
	draw_set_transform(Vector2.ZERO)
	var last := last_roll_caption()
	var last_rect := Rect2(8, size.y - 36, minf(size.x * 0.48 - 16, 240), 30)
	box(last_rect, Color(0.04, 0.10, 0.08, 0.96), 6)
	centered(last_rect, last, 14, GOLD)

func preview_caption() -> String:
	var preview := feedback_for(hover)
	if preview.is_empty(): return ""
	var entries := chips_at(pointer)
	if entries.size() == 1 and entries[0].key == hover:
		return "%s | %s | Tap for details" % [CrapsRules.name_for(hover), Chips.Money.cash(float(entries[0].amount), 2)]
	var text := CrapsRules.name_for(preview.key) + " | " + Chips.Money.cash(preview.amount, 2)
	return text if preview.valid else text + " | " + preview.reason

# Include rotated corners, die separation and shadows in the visible-area clamp.
# This also keeps dice visible when the player zooms or pans the board.
func visible_pair_position(at: Vector2) -> Vector2:
	var margin := Vector2(90, 58) + Vector2.ONE * 6 / factor
	var low := felt_position(Vector2.ZERO) + margin
	var high := felt_position(size) - margin
	for axis in range(2):
		at[axis] = clampf(at[axis], low[axis], high[axis]) if low[axis] <= high[axis] else (low[axis] + high[axis]) / 2
	return at

func visible_die_position(at: Vector2) -> Vector2:
	var inset := Vector2.ONE * (37 + 6 / factor)
	var low := felt_position(Vector2.ZERO) + inset
	var high := felt_position(size) - inset
	return at.clamp(low, high)


func player_at(seat: int) -> Vector2:
	return Vector2(PLAY_SIZE.x * (0.12 if seat < 0 else 0.25 + seat * 0.06), PLAY_SIZE.y - 34)

func player_color(seat: int) -> Color:
	return Chips.seat_color(seat)

func draw_players(table: Dictionary) -> void:
	var players: Array = [{"seat": -1, "name": "YOU", "id": 0}]
	players.append_array(sim.seated(sim.joined))
	for player in players:
		var seat := int(player.seat)
		var at := player_at(seat)
		Chips.avatar(self, at, seat, 15)
		if int(player.id) == int(table.shooter): draw_arc(at, 20, 0, TAU, 36, GOLD, 2)
		centered(Rect2(at + Vector2(-34, 14), Vector2(68, 20)), str(player.name).get_slice(" |", 0).left(8), 12, player_color(seat))
	var point_text := "POINT OFF" if int(table.point) == 0 else "POINT %d" % table.point
	centered(Rect2(PLAY_SIZE.x * 0.22, PLAY_SIZE.y - 72, PLAY_SIZE.x * 0.44, 25), point_text + " | " + sim.shooter_name(table), 18, GOLD)

func last_roll_caption() -> String:
	if reference_dice.size() != 2: return "Last roll: --"
	return "Last roll: %d + %d = %d" % [reference_dice[0], reference_dice[1], int(reference_dice[0]) + int(reference_dice[1])]

func draw_dice(table: Dictionary) -> void:
	var center := visible_pair_position(dice_center())
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
		var at := center + Vector2(-40 + i * 80, i * 3)
		var angle := -0.1 if i == 0 else 0.12
		var value := int(table.dice[i])
		if animation > ROLL_END:
			var t := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
			angle += (1 - t) * (12 + i * 5) * throw_power
			# Decorative cycling is deterministic and never reads the simulation RNG.
			value = 1 + (int(clock * 19) + i * 3) % 6
		elif dice_held: angle += sin(clock * 23 + i) * 0.15
		if animation > ROLL_END:
			var progress := clampf((animation_duration - animation) / ROLL_SECONDS, 0, 1)
			at += Vector2((i * 2 - 1) * 12, (i * 2 - 1) * 17) * sin(progress * PI / 2)
		at = visible_die_position(at)
		if animation > ROLL_END: draw_ellipse_shadow(at)
		die(at, value, angle)
	if can_throw(): centered(Rect2(center + Vector2(-95, -60), Vector2(190, 30)), "HOLD & FLICK", 21, GOLD)

func draw_ellipse_shadow(at: Vector2) -> void:
	draw_circle(at + Vector2(3, 19), 16, Color(0, 0, 0, 0.22))

func draw_wagers(bets: Dictionary, seat: int) -> void:
	for kind in bets:
		var amount := float(bets[kind])
		if amount <= 0 or not spots.has(kind) or (portrait and ((kind in SIDE_KEYS) != side_open)): continue
		var at := endpoint(kind, seat)
		var radius := wager_radius(kind, seat)
		Chips.draw_stack(self, at, amount, radius, player_color(seat), seat < 0 and kind not in ["odds", "lay_odds"])
		if seat < 0 and is_contract(kind):
			label(at + Vector2(-radius, -radius - 3), ("DC" if kind.begins_with("dont") else "C") + ("+" if "odds" in kind else ""), int(9 / factor), player_color(seat))

func chip_at(at: Vector2, value: float, radius: float = 17, tint: Color = Color.TRANSPARENT) -> void:
	Chips.draw_stack(self, at, value, radius, player_color(-1) if tint == Color.TRANSPARENT else tint)

func shooter_pocket(shooter: int = -99) -> Vector2:
	if shooter == -99:
		shooter = int(sim.get_table(sim.joined).get("shooter", -1)) if sim != null and sim.joined >= 0 else -1
	if shooter < 0: return endpoint("bank", -1)
	var seat := -1
	for guest in sim.seated(sim.joined):
		if int(guest.id) == shooter: seat = int(guest.seat)
	return Vector2(PLAY_SIZE.x * 0.065 if seat < 0 else player_at(seat).x, PLAY_SIZE.y - 50)

func free_hand_position() -> Vector2:
	var hand := shooter_pocket() + pointer - origin
	return hand.clamp(dice_bounds.position, dice_bounds.end)

func is_contract(kind: String) -> bool:
	return kind.begins_with("come_") or kind.begins_with("dont_come_")

func wager_radius(kind: String, seat: int = -1) -> float:
	var rect: Rect2 = layouts[kind]
	if kind in ["odds", "lay_odds"]: return (12 if seat < 0 else 8) / factor
	return minf((12 if seat < 0 else 5) / factor, minf(rect.size.x * (0.19 if seat < 0 else 0.07), rect.size.y * 0.30))

func chip_bounds(kind: String, seat: int, amount: float) -> Rect2:
	var radius := wager_radius(kind, seat)
	var denomination := 1
	for value in Chips.DENOMINATIONS:
		if amount >= value: denomination = value
	var layers := clampi(ceili(amount / denomination), 1, 6)
	var rise := (layers - 1) * maxf(2, radius * 0.15)
	return Rect2(endpoint(kind, seat) - Vector2(radius, radius + rise), Vector2(radius * 2, radius * 2 + rise))

func endpoint(kind: String, seat: int) -> Vector2:
	if kind == "bank": return Vector2(PLAY_SIZE.x * 0.64, PLAY_SIZE.y - 70)
	if kind == "player": return player_at(seat)
	if not spots.has(kind): return Vector2.ZERO
	var rect: Rect2 = layouts[kind]
	if kind in ["odds", "lay_odds"]:
		# Every chip center remains on the exact border, including NPC chips.
		return Vector2(rect.position.x + rect.size.x * (0.22 if seat < 0 else 0.4 + seat * 0.075), rect.position.y)
	if seat < 0: return spots[kind]
	if is_contract(kind):
		return rect.position + rect.size * Vector2(0.54 + (seat % 3) * 0.17, 0.25 + int(seat / 3) * 0.25)
	return rect.position + rect.size * Vector2(0.42 + (seat % 4) * 0.16, 0.68 + int(seat / 4) * 0.18)

func chips_at(at: Vector2) -> Array:
	var matches: Array = []
	if sim == null or sim.joined < 0: return matches
	var table := sim.get_table(sim.joined)
	var participants: Array = [{"seat": -1, "bets": table.owner}]
	participants.append_array(sim.seated(sim.joined))
	for participant in participants:
		# Canonical order, independent of dictionary insertion order.
		for key in CrapsRules.empty_bets():
			var amount := float(participant.bets.get(key, 0))
			if amount > 0 and layouts.has(key) and (not portrait or ((key in SIDE_KEYS) == side_open)) and chip_bounds(key, int(participant.seat), amount).has_point(at):
				matches.append({"key": key, "seat": participant.seat, "amount": amount})
	return matches

func target_at(at: Vector2, include_chips: bool = true) -> String:
	if include_chips:
		var matches := chips_at(at)
		# Ambiguous and NPC stacks are handled by their read-only/context menu.
		if matches.size() == 1: return matches[0].key
		if matches.size() > 1: return ""
	for key in ["odds", "lay_odds"]:
		if not side_open and layouts.has(key) and border_band(key).has_point(at): return key
	for target in targets:
		if target.enabled and (not side_open or target.kind in SIDE_KEYS) and target.rect.has_point(at): return str(target.kind)
	return ""

func place_chip(kind: String, _at: Vector2) -> void:
	if kind.is_empty() or chip <= 0: return
	if locked or busy():
		message = "Paused or table busy."
		return
	var error := sim.bet_error(sim.joined, kind, chip)
	if error.is_empty():
		bet_clicked.emit(kind)
	else: message = error
	queue_redraw()

func odds_for(key: String) -> String:
	if key == "pass": return "odds"
	if key == "dont_pass": return "lay_odds"
	if key.begins_with("come_") and not key.begins_with("come_odds_"): return key.replace("come_", "come_odds_")
	if key.begins_with("dont_come_") and not key.begins_with("dont_come_odds_"): return key.replace("dont_come_", "dont_come_odds_")
	return ""

func open_context(key: String, seat: int = -1) -> void:
	if key.is_empty(): return
	context_key = key
	context_odds = odds_for(key)
	var table := sim.get_table(sim.joined)
	var bets: Dictionary = table.owner
	if seat >= 0:
		for guest in sim.seated(sim.joined):
			if int(guest.seat) == seat: bets = guest.bets
	context_menu.clear()
	context_menu.add_item(CrapsRules.name_for(key) + " | " + Chips.Money.cash(float(bets.get(key, 0)), 2), 4)
	context_menu.set_item_disabled(0, true)
	if seat < 0:
		if not is_contract(key):
			context_menu.add_item("Add " + CrapsRules.name_for(key), 3)
			context_menu.set_item_disabled(context_menu.item_count - 1, not feedback_for(key).valid)
		elif "odds" in key:
			context_menu.add_item("Add " + CrapsRules.name_for(key), 3)
			context_menu.set_item_disabled(context_menu.item_count - 1, not feedback_for(key).valid)
		if not context_odds.is_empty() and float(bets.get(key, 0)) > 0:
			context_menu.add_item("Add " + CrapsRules.name_for(context_odds), 2)
			context_menu.set_item_disabled(context_menu.item_count - 1, not feedback_for(context_odds).valid)
		if float(bets.get(key, 0)) > 0:
			context_menu.add_item("Remove wager", 0)
			context_menu.set_item_disabled(context_menu.item_count - 1, locked or busy() or not CrapsRules.removable(key, int(table.point)))
	var pay := ""
	if CrapsRules.PROP_PAY.has(key): pay = "%d:1" % CrapsRules.PROP_PAY[key]
	elif key.begins_with("hard_"): pay = "%d:1" % (9 if key in ["hard_6", "hard_8"] else 7)
	if not pay.is_empty():
		context_menu.add_item("Pays " + pay, 5)
		context_menu.set_item_disabled(context_menu.item_count - 1, true)
	context_menu.position = Vector2i(get_global_transform_with_canvas() * (offset + spots[key] * factor))
	context_menu.popup()

func open_stack_context(at: Vector2) -> bool:
	var matches := chips_at(at)
	if matches.is_empty(): return false
	if matches.size() == 1:
		open_context(matches[0].key, int(matches[0].seat))
	else:
		context_choices = matches
		context_menu.clear()
		for i in range(matches.size()):
			var entry: Dictionary = matches[i]
			context_menu.add_item(("You" if int(entry.seat) < 0 else "Seat %d" % (int(entry.seat) + 1)) + " | " + CrapsRules.name_for(entry.key), 100 + i)
		context_menu.position = Vector2i(get_global_transform_with_canvas() * (offset + at * factor))
		context_menu.popup()
	return true

func _gui_input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1: return
	if dice_held or factor <= 0 or sim == null or sim.joined < 0 or (is_instance_valid(options_overlay) and options_overlay.visible) or (is_instance_valid(input_overlay) and input_overlay.visible): return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		var at := felt_position(event.position)
		if not open_stack_context(at): open_context(target_at(at, false))
		accept_event()
		return
	if event is InputEventMouseMotion:
		pointer = felt_position(event.position)
		hover = target_at(pointer)
		queue_redraw()
		if mouse_down:
			pan_distance += event.relative.length()
			if pan_distance > 10 and dragging == "":
				view_center -= event.relative / factor
				update_view_transform()
				pointer = felt_position(event.position)
			queue_redraw()
			accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom_view(1.25 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.8, event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = felt_position(event.position)
		hover = target_at(pointer)
		if event.pressed:
			mouse_down = true
			bet_press_started = clock
			pan_distance = 0
			dragging = ""
			drag_stack = false
			if pan_mode:
				accept_event()
				return
			if not locked and not busy():
				var matches := chips_at(pointer)
				if matches.size() == 1 and int(matches[0].seat) < 0:
					dragging = matches[0].key
					drag_stack = true
		else:
			mouse_down = false
			if not pan_mode and not locked and not busy():
				var target := target_at(pointer)
				if (pan_distance <= 10 or dragging == "chip") and open_stack_context(pointer):
					pass
				elif pan_distance <= 10 and clock - bet_press_started >= 0.5:
					open_context(target)
				elif drag_stack and pan_distance > 10:
					if tray.has_point(pointer) or (is_instance_valid(remove_drop) and remove_drop.get_global_rect().has_point(get_global_transform_with_canvas() * event.position)):
						var returned := sim.remove_bet(sim.joined, dragging)
						message = "Chips returned to your wallet." if returned > 0 else "That contract stays until it resolves."
						action_requested.emit("refresh")
					elif target == dragging:
						queue_redraw()
				elif (dragging == "chip" or pan_distance <= 10) and Rect2(Vector2.ZERO, size).has_point(event.position):
					place_chip(target_at(pointer, false), pointer)
			dragging = ""
			drag_stack = false
		update_drag_overlay()
		queue_redraw()
		accept_event()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or context_menu.visible or (is_instance_valid(input_overlay) and input_overlay.is_visible_in_tree()) or (is_instance_valid(options_overlay) and options_overlay.is_visible_in_tree()): return
	# Dice and bets use the same source-art inverse, including native touch events.
	var pointer_event := event is InputEventMouseButton or event is InputEventMouseMotion or event is InputEventScreenTouch or event is InputEventScreenDrag
	if not pointer_event: return
	# Own the complete native button gesture; Godot's emulated mouse path
	# must never activate the same button a second time.
	if event is InputEventScreenTouch:
		if event.pressed and side_touch_index < 0 and side_button.visible and side_button.get_global_rect().has_point(event.position) and not mouse_down and not dice_held:
			side_touch_index = event.index
			get_viewport().set_input_as_handled()
			return
		if event.index == side_touch_index:
			if not event.pressed:
				side_touch_index = -1
				if side_button.get_global_rect().has_point(event.position): side_button.pressed.emit()
			get_viewport().set_input_as_handled()
			return
	if event is InputEventScreenDrag and event.index == side_touch_index:
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1 and (side_touch_index >= 0 or (side_button.visible and side_button.get_global_rect().has_point(event.position))):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		if event is InputEventScreenTouch:
			if event.pressed: touch_points[event.index] = event.position
			else: touch_points.erase(event.index)
		elif touch_points.has(event.index):
			var previous_points := touch_points.values()
			var old_span: float = previous_points[0].distance_to(previous_points[1]) if previous_points.size() == 2 else 0.0
			var old_center: Vector2 = (previous_points[0] + previous_points[1]) / 2 if previous_points.size() == 2 else Vector2.ZERO
			touch_points[event.index] = event.position
			if touch_points.size() == 2 and not dice_held:
				var points := touch_points.values()
				var center: Vector2 = (points[0] + points[1]) / 2
				var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * center
				mouse_down = false
				dragging = ""
				drag_stack = false
				gesture_active = true
				zoom_view(points[0].distance_to(points[1]) / maxf(1, old_span), local)
				view_center -= (center - old_center) / factor
				update_view_transform()
				queue_redraw()
		if touch_points.size() >= 2 or gesture_active or event.index != 0:
			if touch_points.size() >= 2:
				gesture_active = true
				mouse_down = false
				dragging = ""
				drag_stack = false
				hover = ""
			if touch_points.is_empty(): gesture_active = false
			get_viewport().set_input_as_handled()
			return
	var inside := get_global_rect().has_point(event.position)
	# Godot also emits mouse events for native touch. Consume that second path
	# only over our felt/active drag, leaving ordinary toolbar buttons usable.
	if (event is InputEventMouseButton or event is InputEventMouseMotion) and event.device == -1:
		if inside or mouse_down or dice_held: get_viewport().set_input_as_handled()
		return
	if not dice_held and not mouse_down and not inside: return
	if not side_open and (not pan_mode or dice_held):
		super._input(event)
	if dice_held:
		mouse_down = false
		dragging = ""
		drag_stack = false
		drag_overlay.hide()
		return
	# The inherited release may have just consumed a dice flick.
	if get_viewport().is_input_handled(): return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		var local: Vector2 = get_global_transform_with_canvas().affine_inverse() * event.position
		if event is InputEventScreenTouch:
			var click := InputEventMouseButton.new()
			click.position = local
			click.button_index = MOUSE_BUTTON_LEFT
			click.pressed = event.pressed
			_gui_input(click)
		else:
			var motion := InputEventMouseMotion.new()
			motion.position = local
			motion.relative = get_global_transform_with_canvas().basis_xform_inv(event.relative)
			_gui_input(motion)
		get_viewport().set_input_as_handled()
	elif mouse_down and (event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed)):
		_gui_input(make_input_local(event))
		update_drag_overlay()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	super._notification(what)
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		side_touch_index = -1
		touch_points.clear()
		gesture_active = false
		mouse_down = false
		dragging = ""
		drag_stack = false
