extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
const COLORS := ["cream", "blue", "green", "cyan", "purple", "orange"]
enum Reaction { NONE, WIN, BIG_WIN, JACKPOT, LOSS, BIG_LOSS, DRINK_DELIVERED, THIRSTY, WAITING, FRUSTRATED, SERVICE_FAIL }
const PRIORITIES := [0, 4, 6, 7, 4, 6, 3, 1, 1, 2, 5]
const SPARKLES := [Vector2(-8, -6), Vector2(7, -8), Vector2(10, 2), Vector2(-7, 5), Vector2(0, -11), Vector2(5, 8)]
var signature: Array = []
var last_zoom := -1.0
var reaction := Reaction.NONE
var reaction_time := 0.0
var reaction_duration := 0.0
var reaction_strength := 1.0
var cooldown_until := 0
var need_until := 0
var mood_state := 2
var vip := false
var high_roller := false
var selected := false
var mood_color := Color.TRANSPARENT
var idle_time := -1.0
var idle_next := 0
@onready var visual: Node2D = $Visual
@onready var body: Sprite2D = $Visual/Body
@onready var ring: Sprite2D = $Visual/Ring
@onready var rank: Sprite2D = $Visual/Rank
@onready var accent: Sprite2D = $Visual/ReactionAccent
@onready var thought: Sprite2D = $Visual/Thought
@onready var status: Label = $Status

func _ready() -> void:
	accent.visible = false
	set_process(false)

func _draw() -> void:
	draw_circle(Vector2(0, 1), 13, Color(0.025, 0.03, 0.03, 0.9))
	if mood_color.a > 0:
		draw_circle(Vector2.ZERO, 15, Color(mood_color, 0.09))
		draw_arc(Vector2.ZERO, 12.8, 0, TAU, 32, mood_color, 1.2, true)
	if high_roller:
		draw_arc(Vector2.ZERO, 14, 0.2, 2.8 if vip else TAU + 0.2, 32, Color("ec84c8"), 1.2, true)
	if selected:
		draw_arc(Vector2.ZERO, 16, 0, TAU, 32, Color("caffef"), 2, true)
	if idle_time >= 0:
		var gentle := sin(idle_time / CasinoTuning.REACTION_SERVICE_SECONDS * PI)
		draw_arc(Vector2.ZERO, 14 + gentle, 0, TAU, 32, Color(mood_color, gentle * 0.2), 1, true)
		if vip:
			var at := Vector2(10, -12)
			draw_line(at - Vector2(gentle * 2, 0), at + Vector2(gentle * 2, 0), Color(1, 0.82, 0.44, gentle), 1, true)
			draw_line(at - Vector2(0, gentle * 2), at + Vector2(0, gentle * 2), Color(1, 0.82, 0.44, gentle), 1, true)
	if reaction == Reaction.NONE: return
	var progress := clampf(reaction_time / reaction_duration, 0, 1)
	var pulse := sin(progress * PI)
	var positive := reaction in [Reaction.WIN, Reaction.BIG_WIN, Reaction.JACKPOT]
	var color := Color("f4d06f") if reaction in [Reaction.BIG_WIN, Reaction.JACKPOT] else Color("67e6b3") if positive else Color("70dce4") if reaction in [Reaction.DRINK_DELIVERED, Reaction.THIRSTY, Reaction.WAITING] else Color("ef9161")
	draw_circle(visual.position, 14 + pulse * 5, Color(color, pulse * 0.18))
	draw_arc(visual.position, 13 + progress * 9, 0, TAU, 32, Color(color, (1 - progress) * 0.8), 1.5, true)
	var count := 6 if reaction == Reaction.JACKPOT else 4 if reaction == Reaction.BIG_WIN else 2 if reaction == Reaction.WIN else 0
	for i in range(count):
		var at: Vector2 = visual.position + SPARKLES[i] * (1.4 + progress)
		var radius := pulse * 2
		draw_line(at - Vector2(radius, 0), at + Vector2(radius, 0), Color(color, pulse), 1.2, true)
		draw_line(at - Vector2(0, radius), at + Vector2(0, radius), Color(color, pulse), 1.2, true)

func set_image(node: Sprite2D, path: String, extent: float) -> void:
	node.visible = not path.is_empty()
	if path.is_empty(): return
	var image := Art.texture(path)
	if node.texture != image: node.texture = image
	node.scale = Vector2.ONE * extent / maxf(image.get_width(), image.get_height())

func update_guest(guest: Dictionary, selected_id: int, has_thought: bool, compact: bool) -> void:
	position = Vector2(float(guest.x), float(guest.y))
	var satisfaction := float(guest.satisfaction)
	var next_mood := 0
	for threshold in CasinoTuning.CHARACTER_MOOD_THRESHOLDS:
		if satisfaction >= threshold: next_mood += 1
	if bool(guest.get("repair_frustrated", false)): next_mood = 0
	var next := [int(guest.id), guest.vip, int(guest.id) == selected_id, next_mood, guest.state, float(guest.get("wager_limit", 0)), has_thought, compact]
	var now := Time.get_ticks_msec()
	if idle_next == 0: idle_next = now + 3000 + (int(guest.id) * 977) % 7000
	if now >= idle_next:
		idle_next = now + int(CasinoTuning.CHARACTER_IDLE_INTERVAL_SECONDS * 1000)
		if reaction == Reaction.NONE and (vip or mood_state in [0, 3, 4]) and is_visible_in_tree():
			idle_time = 0
			set_process(true)
	if signature == next: return
	signature = next
	vip = bool(guest.get("vip", false))
	high_roller = float(guest.get("wager_limit", 0)) >= CasinoTuning.CHARACTER_HIGH_ROLLER_WAGER
	selected = int(guest.id) == selected_id
	mood_state = next_mood
	mood_color = [Color("ef7855"), Color("daa46b"), Color.TRANSPARENT, Color("8acbb2"), Color("f4d06f")][mood_state]
	var color: String = "gold" if vip else COLORS[int(guest.id) % COLORS.size()]
	set_image(body, "guests/base/guest_" + color + ".svg", CasinoTuning.GUEST_BASE_SCREEN_SIZE / CasinoTuning.CHARACTER_TEXTURE_DIAMETER)
	body.modulate = Color(1.1, 1.07, 1.0) if mood_state == 4 else Color(0.86, 0.82, 0.78) if mood_state <= 1 else Color.WHITE
	set_image(ring, "guests/rings/ring_vip.svg" if vip else "", 33)
	set_image(rank, "icons/status/vip.svg" if vip else "icons/status/star.svg" if high_roller else "", 10)
	set_image(thought, "icons/status/info.svg" if has_thought else "", 9)
	status.text = "BAR" if str(guest.state) in ["To bar", "At bar"] else "WATCH" if str(guest.state) in ["Browsing", "Watching"] else "CASH OUT" if str(guest.state) in ["To cage", "Cashing out"] else ""
	status.visible = not compact and selected and not status.text.is_empty()
	queue_redraw()

func set_view_zoom(value: float) -> void:
	if is_equal_approx(last_zoom, value): return
	last_zoom = value
	scale = Vector2.ONE * CasinoTuning.character_scale(value)

func react(type: Reaction, strength: float = 1.0) -> void:
	if type == Reaction.NONE: return
	var now := Time.get_ticks_msec()
	if reaction != Reaction.NONE and PRIORITIES[type] <= PRIORITIES[reaction]: return
	if now < cooldown_until and PRIORITIES[type] <= 4: return
	if type in [Reaction.THIRSTY, Reaction.WAITING, Reaction.FRUSTRATED] and now < need_until: return
	if type in [Reaction.THIRSTY, Reaction.WAITING, Reaction.FRUSTRATED]:
		need_until = now + int(CasinoTuning.REACTION_NEED_COOLDOWN_SECONDS * 1000)
	idle_time = -1
	reaction = type
	reaction_time = 0
	reaction_strength = clampf(strength, 0.5, 1.5)
	reaction_duration = CasinoTuning.REACTION_JACKPOT_SECONDS if type == Reaction.JACKPOT else CasinoTuning.REACTION_BIG_SECONDS if type in [Reaction.BIG_WIN, Reaction.BIG_LOSS] else CasinoTuning.REACTION_WIN_SECONDS if type == Reaction.WIN else CasinoTuning.REACTION_LOSS_SECONDS if type == Reaction.LOSS else CasinoTuning.REACTION_SERVICE_SECONDS
	set_image(accent, "icons/gameplay/drink.svg" if type in [Reaction.DRINK_DELIVERED, Reaction.THIRSTY] else "icons/status/jackpot.svg" if type == Reaction.JACKPOT else "", 10)
	set_process(true)
	queue_redraw()

func _process(delta: float) -> void:
	if reaction == Reaction.NONE:
		idle_time += delta
		if idle_time >= CasinoTuning.REACTION_SERVICE_SECONDS:
			idle_time = -1
			set_process(false)
		queue_redraw()
		return
	reaction_time += delta
	if reaction_time >= reaction_duration:
		reaction = Reaction.NONE
		visual.position = Vector2.ZERO
		visual.scale = Vector2.ONE
		visual.rotation = 0
		accent.visible = false
		cooldown_until = Time.get_ticks_msec() + int(CasinoTuning.REACTION_COOLDOWN_SECONDS * 1000)
		set_process(false)
		queue_redraw()
		return
	var progress := reaction_time / reaction_duration
	var pulse := sin(progress * PI) * reaction_strength
	visual.position = Vector2.ZERO
	visual.scale = Vector2.ONE
	visual.rotation = 0
	match reaction:
		Reaction.WIN, Reaction.BIG_WIN, Reaction.JACKPOT, Reaction.DRINK_DELIVERED:
			var big := reaction in [Reaction.BIG_WIN, Reaction.JACKPOT]
			visual.position.y = -pulse * (7 if big else 4)
			visual.scale = Vector2.ONE * (1 + pulse * (0.2 if big else 0.1))
		Reaction.LOSS, Reaction.BIG_LOSS, Reaction.SERVICE_FAIL:
			var squash := pulse * (0.18 if reaction != Reaction.LOSS else 0.09)
			visual.scale = Vector2(1 + squash, 1 - squash)
			visual.position.y = pulse * 2
			if reaction != Reaction.LOSS: visual.position.x = sin(progress * TAU * 5) * pulse * 2
		Reaction.WAITING, Reaction.FRUSTRATED:
			visual.rotation = sin(progress * TAU * 3) * pulse * 0.08
	queue_redraw()

static func financial_reaction(event: Dictionary) -> Reaction:
	if str(event.get("source", "")) == "drink" and str(event.get("category", "")) in ["bar", "comp"]: return Reaction.DRINK_DELIVERED
	if str(event.get("category", "")) != "gaming": return Reaction.NONE
	var amount := float(event.get("amount", 0))
	if is_zero_approx(amount): return Reaction.NONE
	# Identify an actual slot top award from settled stake/credit and its existing paytable.
	var profile := str(event.get("slot_profile", ""))
	var stake := float(event.get("settled_stake", 0))
	if amount < 0 and stake > 0 and CasinoTuning.SLOT_PROFILES.has(profile):
		if float(event.get("returned", 0)) >= stake * float(CasinoTuning.SLOT_PROFILES[profile].pays.max()): return Reaction.JACKPOT
	var big := absf(amount) >= CasinoTuning.EVENT_GUEST_BIG_WIN
	return (Reaction.BIG_LOSS if big else Reaction.LOSS) if amount > 0 else (Reaction.BIG_WIN if big else Reaction.WIN)
