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
	"hard_8": Rect2(1344, 314, 153, 82),
	"hard_6": Rect2(1178, 408, 155, 79),
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
var animation_duration := 0.85
var pan_distance := 0.0
var mouse_down := false
var drag_stack := false

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null or sim.joined < 0: return
	# Mobile keeps native-sized targets and pans inside the shared play viewport.
	var mobile := get_viewport_rect().size.x < 1000
	var minimum := Vector2(1300, 948) if mobile else Vector2.ZERO
	if custom_minimum_size != minimum:
		custom_minimum_size = minimum
		if mobile: call_deferred("focus_line")
	clock += delta
	var animating := animation > 0 or dice_held
	animation = maxf(0, animation - delta)
	var table := sim.get_table(sim.joined)
	if table_id != sim.joined:
		table_id = sim.joined
		last_roll = int(table.rolls)
		shooter_seen = -99
		reset_dice()
		if mobile: call_deferred("focus_line")
	if int(table.rolls) != last_roll: capture_roll(table)
	if shooter_seen != int(table.shooter):
		shooter_seen = int(table.shooter)
		reset_dice()
	if not locked and not dice_held and not dice_ready:
		betting_wait -= delta
		if betting_wait <= 0: dice_ready = true
	var next := [table.dice, table.point, table.owner, table.shooter, locked, size, dice_ready]
	if next != display_signature or animating:
		display_signature = next.duplicate(true)
		queue_redraw()

func capture_roll(table: Dictionary) -> void:
	last_roll = int(table.rolls)
	animation = animation_duration
	message = str(table.result).replace("·", "|").replace("’", "'")
	throw_pending = false
	reset_dice()
	flights.clear()

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
		draw_texture_rect(PitBoss.texture("casino_play/craps/die_%d.svg" % (first if i == 0 else second)), Rect2(center + Vector2(-57 + i * 60, -25), Vector2(50, 50)), false)

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
	# No targets for Big 6/8, C/E, Horn, or the printed twelve hardway.
	correction(Rect2(1345, 414, 150, 72), "Not supported")
	printed_pair(Vector2(1255, 341), 2, 2)
	correction(Rect2(1180, 367, 149, 29), "Hard 4 | 7:1")
	printed_pair(Vector2(1255, 643), 1, 1)
	printed_pair(Vector2(1250, 730), 5, 6)
	printed_pair(Vector2(1435, 730), 1, 2)
	correction(Rect2(1179, 756, 120, 28), "Yo 11 | 15:1")
	correction(Rect2(1381, 756, 117, 28), "3 | 15:1")
	correction(Rect2(841, 678, 181, 29), "12 pays 3:1")
	# Supported wagers without a printed area get explicit labeled regions.
	supplemental(Rect2(25, 1030, 270, 64), "odds")
	supplemental(Rect2(310, 1030, 270, 64), "lay_odds")
	supplemental(Rect2(595, 1030, 240, 64), "hard_10")
	tray = Rect2(860, 1030, 650, 64)
	box(tray, Color("111d20"), 6, Color("51452b"))
	centered(tray, "Drag removable chips here to take down", 20, GOLD)
	box(Rect2(1178, 50, 320, 185), Color("10291f"), 8, GOLD)
	centered(Rect2(1180, 58, 316, 42), "POINT OFF" if int(table.point) == 0 else "POINT %d / ON" % table.point, 24, GOLD)
	centered(Rect2(1180, 100, 316, 30), sim.shooter_name(table) + " has the dice", 19)
	for i in range(2):
		var at := shooter_pocket() + Vector2(-33 + i * 66, 0)
		if dice_held: at = free_hand_position() + Vector2(-33 + i * 66, 0)
		var angle := 0.0
		if animation > 0:
			at.y -= sin((animation_duration - animation) / animation_duration * PI) * 26
			angle = animation * (5 if i == 0 else -5)
		die(at, int(table.dice[i]), angle)
	for kind in table.owner:
		var amount := float(table.owner[kind])
		if amount <= 0 or not spots.has(kind): continue
		var at: Vector2 = spots[kind]
		# Chips remain on their mapped region; small contracts use smaller stacks.
		chip_at(at, amount, 19 if kind.contains("odds") or kind.ends_with("_4") or kind.ends_with("_6") or kind.ends_with("_8") or kind.ends_with("_10") else 24)
	draw_set_transform(Vector2.ZERO)

func shooter_pocket(_shooter: int = -99) -> Vector2:
	return Vector2(1338, 180)

func free_hand_position() -> Vector2:
	return shooter_pocket() + pointer - origin

func endpoint(kind: String, _seat: int) -> Vector2:
	return spots.get(kind, Vector2.ZERO)

func play_scroll() -> ScrollContainer:
	var node := get_parent()
	while node != null:
		if node is ScrollContainer: return node
		node = node.get_parent()
	return null

func _gui_input(event: InputEvent) -> void:
	if dice_held or factor <= 0: return
	if event is InputEventMouseMotion:
		pointer = (event.position - offset) / factor
		if mouse_down:
			pan_distance += event.relative.length()
			if pan_distance > 10 and not drag_stack:
				var scroll := play_scroll()
				if scroll != null:
					scroll.scroll_horizontal -= int(event.relative.x)
					scroll.scroll_vertical -= int(event.relative.y)
			accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		pointer = (event.position - offset) / factor
		if event.pressed:
			mouse_down = true
			pan_distance = 0
			dragging = ""
			drag_stack = false
			if not locked and not busy():
				for kind in sim.get_table(sim.joined).owner:
					if float(sim.get_table(sim.joined).owner[kind]) > 0 and spots.has(kind) and pointer.distance_to(spots[kind]) < 28:
						dragging = kind
						drag_stack = true
		else:
			mouse_down = false
			if locked or busy():
				dragging = ""
				return
			if drag_stack and pan_distance > 10:
				if tray.has_point(pointer):
					sim.remove_bet(sim.joined, dragging)
					action_requested.emit("refresh")
			elif pan_distance <= 10:
				for target in targets:
					if target.enabled and target.rect.has_point(pointer):
						var error := sim.bet_error(sim.joined, target.kind, chip)
						if error.is_empty(): bet_clicked.emit(target.kind)
						else: message = error
						break
			dragging = ""
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
