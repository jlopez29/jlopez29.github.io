extends PanelContainer
## A bounded, real-time presentation queue. Simulation owns accomplishment truth.
const FinancialText = preload("res://scripts/financial_text.gd")
var pending: Array[Dictionary] = []
var remaining := 0.0
var duration := 0.0
var gap := 0.0
var enabled := true
var heading: Label
var message: Label
var amount: Label

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 50
	var body := VBoxContainer.new()
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_theme_constant_override("separation", 5)
	add_child(body)
	heading = Label.new()
	message = Label.new()
	amount = Label.new()
	for label in [heading, message, amount]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(label)
	heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", 13)
	amount.autowrap_mode = TextServer.AUTOWRAP_OFF
	amount.add_theme_font_size_override("font_size", 22)
	hide()

func enqueue(event: Dictionary) -> void:
	pending.append(event.duplicate(true))
	if pending.size() > CasinoTuning.MILESTONE_QUEUE_LIMIT:
		# Preserve major events over ordinary unlocks in accelerated bursts.
		var least := 0
		for i in range(pending.size()):
			if int(pending[i].importance) < int(pending[least].importance): least = i
		pending.remove_at(least)

func reset() -> void:
	pending.clear()
	remaining = 0
	gap = 0
	hide()

func _process(delta: float) -> void:
	if not enabled:
		hide()
		return
	if remaining <= 0:
		hide()
		gap = maxf(0, gap - delta)
		if pending.is_empty() or gap > 0: return
		present(pending.pop_front())
	remaining = maxf(0, remaining - delta)
	var dimensions := get_viewport_rect().size
	var width := minf(420, dimensions.x - 24)
	size = Vector2(width, 0) # Content-derived height, never a stretched empty card.
	position = Vector2((dimensions.x - width) / 2, 78)
	modulate.a = minf(clampf((duration - remaining) / 0.18, 0, 1), clampf(remaining / 0.5, 0, 1))
	show()
	if remaining <= 0: gap = CasinoTuning.MILESTONE_GAP_SECONDS

func present(event: Dictionary) -> void:
	var major := int(event.importance) >= 2
	var color := Color("f2ba78") if event.tone == "caution" else Color("e3bb70") if major else Color("57d6b1")
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color("172735")
	skin.border_color = color
	skin.set_border_width_all(2 if major else 1)
	skin.set_corner_radius_all(8)
	skin.content_margin_left = 14
	skin.content_margin_right = 14
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	add_theme_stylebox_override("panel", skin)
	heading.text = ("DEV - " if bool(event.get("dev", false)) else "") + str(event.title)
	heading.add_theme_font_size_override("font_size", 18 if major else 16)
	heading.add_theme_color_override("font_color", color)
	message.text = str(event.body)
	amount.visible = event.has("amount")
	if amount.visible:
		amount.text = FinancialText.house_result(float(event.amount))
		amount.add_theme_color_override("font_color", color)
	duration = CasinoTuning.MILESTONE_MAJOR_SECONDS if major else CasinoTuning.MILESTONE_SECONDS
	remaining = duration
