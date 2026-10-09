extends Control
## Shared, retained modal: the footer stays reachable while category rows scroll.
const PitBoss = preload("res://scripts/pit_boss_theme.gd")
const SECTIONS := {
	"MASTER": {"Master": "Master Volume"},
	"MUSIC & ATMOSPHERE": {"Music": "Jazz Music", "Ambience": "Casino Ambience", "World": "World Sounds"},
	"INTERFACE": {"UI": "UI Sounds"},
	"CASINO GAMES": {"Games": "All Game Sounds"},
	"INDIVIDUAL GAME AUDIO": {"Slots": "Slots", "Blackjack": "Blackjack", "Roulette": "Roulette", "Craps": "Craps", "Holdem": "Ultimate Texas Hold'em"}
}
var panel: PanelContainer
var rows := {}
var master_mute: CheckButton
var prior_focus: Control

func _ready() -> void:
	theme = PitBoss.create()
	z_index = 90
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.72)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	panel = PanelContainer.new()
	add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var title := Label.new()
	title.text = "AUDIO SETTINGS"
	title.add_theme_color_override("font_color", PitBoss.GOLD)
	body.add_child(title)
	master_mute = CheckButton.new()
	master_mute.text = "Mute All Audio"
	master_mute.custom_minimum_size.y = 44
	body.add_child(master_mute)
	master_mute.toggled.connect(AudioManager.set_master_muted)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var categories := VBoxContainer.new()
	categories.size_flags_horizontal = SIZE_EXPAND_FILL
	categories.add_theme_constant_override("separation", 8)
	scroll.add_child(categories)
	for section in SECTIONS:
		var heading := Label.new()
		heading.text = section
		heading.add_theme_font_size_override("font_size", 14)
		heading.add_theme_color_override("font_color", PitBoss.GOLD)
		categories.add_child(heading)
		for bus in SECTIONS[section]: add_category(categories, bus, SECTIONS[section][bus])
	var footer := HBoxContainer.new()
	body.add_child(footer)
	var reset := Button.new()
	reset.text = "Reset Audio Defaults"
	reset.custom_minimum_size.y = 44
	reset.size_flags_horizontal = SIZE_EXPAND_FILL
	reset.add_theme_font_size_override("font_size", 14)
	footer.add_child(reset)
	reset.pressed.connect(AudioManager.reset_defaults)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(70, 44)
	footer.add_child(close)
	close.pressed.connect(close_panel)
	AudioManager.settings_changed.connect(sync_settings)
	resized.connect(layout_panel)
	sync_settings()
	layout_panel()
	hide()

func add_category(parent: Node, bus: String, caption: String) -> void:
	var row := VBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = caption
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	var controls := HBoxContainer.new()
	row.add_child(controls)
	var slider := HSlider.new()
	slider.min_value = 0
	slider.max_value = 100
	slider.step = 1
	slider.custom_minimum_size = Vector2(0, 44)
	slider.size_flags_horizontal = SIZE_EXPAND_FILL
	slider.tooltip_text = caption + " volume (0 to 100 percent)"
	controls.add_child(slider)
	var percent := Label.new()
	percent.custom_minimum_size.x = 44
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	percent.add_theme_font_size_override("font_size", 14)
	controls.add_child(percent)
	var mute: CheckButton
	if bus != "Master":
		mute = CheckButton.new()
		mute.text = "Mute"
		mute.custom_minimum_size.y = 44
		mute.add_theme_font_size_override("font_size", 14)
		mute.tooltip_text = "Mute " + caption + " while keeping its volume"
		controls.add_child(mute)
		mute.toggled.connect(func(value: bool): AudioManager.set_category_muted(bus, value))
	slider.value_changed.connect(func(value: float): AudioManager.set_volume(bus, value / 100.0))
	rows[bus] = {"slider": slider, "percent": percent, "mute": mute}

func sync_settings() -> void:
	master_mute.set_pressed_no_signal(AudioManager.is_category_muted("Master"))
	for bus in rows:
		var row: Dictionary = rows[bus]
		row.slider.set_value_no_signal(round(AudioManager.get_volume(bus) * 100))
		row.percent.text = "%d%%" % row.slider.value
		if row.mute != null: row.mute.set_pressed_no_signal(AudioManager.is_category_muted(bus))

func layout_panel() -> void:
	var extent := Vector2(minf(600, maxf(0, size.x - 16)), minf(830, maxf(0, size.y - 16)))
	panel.position = (size - extent) / 2
	panel.size = extent

func open() -> void:
	prior_focus = get_viewport().gui_get_focus_owner()
	sync_settings()
	show()
	master_mute.grab_focus()
	AudioManager.play_ui("menu")

func close_panel() -> void:
	AudioManager.save_settings()
	hide()
	if is_instance_valid(prior_focus): prior_focus.grab_focus()
	else: master_mute.release_focus()

func _input(event: InputEvent) -> void:
	if not visible or not event is InputEventKey or not event.pressed: return
	# Prevent the underlying game's space/enter shortcuts while editing audio.
	if event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
