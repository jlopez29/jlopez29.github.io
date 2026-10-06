extends Node2D
const Art = preload("res://scripts/pit_boss_theme.gd")
const COLORS := ["cream", "blue", "green", "cyan", "purple", "orange"]
@onready var body: Sprite2D = $Body
@onready var ring: Sprite2D = $Ring
@onready var rank: Sprite2D = $Rank
@onready var mood: Sprite2D = $Mood
@onready var thought: Sprite2D = $Thought
@onready var status: Label = $Status

func set_image(node: Sprite2D, path: String, extent: float) -> void:
	node.visible = not path.is_empty()
	if path.is_empty(): return
	var image := Art.texture(path)
	if node.texture != image: node.texture = image
	node.scale = Vector2.ONE * extent / maxf(image.get_width(), image.get_height())

func update_guest(guest: Dictionary, selected_id: int, has_thought: bool, compact: bool) -> void:
	position = Vector2(float(guest.x), float(guest.y))
	var vip: bool = guest.get("vip", false)
	# High roller is a presentation of actual wager capacity, never a new AI flag.
	var high_roller := float(guest.get("wager_limit", 0)) >= 100
	var color: String = "gold" if vip else COLORS[int(guest.id) % COLORS.size()]
	set_image(body, "guests/base/guest_" + color + ".svg", 28)
	var state := "selected" if int(guest.id) == selected_id else "alert" if float(guest.satisfaction) < 35 else "vip" if vip else "high_roller" if high_roller else ""
	set_image(ring, "guests/rings/ring_" + state + ".svg" if not state.is_empty() else "", 34)
	set_image(rank, "icons/status/vip.svg" if vip else "icons/status/star.svg" if high_roller else "", 11)
	var mood_name := "angry" if float(guest.satisfaction) < 35 else "unhappy" if float(guest.satisfaction) < 50 else ""
	set_image(mood, "guests/moods/mood_" + mood_name + ".svg" if not mood_name.is_empty() else "", 11)
	set_image(thought, "icons/status/info.svg" if has_thought else "", 9)
	status.text = "BAR" if str(guest.state) in ["To bar", "At bar"] else "WATCH" if str(guest.state) in ["Browsing", "Watching"] else "CASH OUT" if str(guest.state) in ["To cage", "Cashing out"] else ""
	status.visible = not compact and not status.text.is_empty()
