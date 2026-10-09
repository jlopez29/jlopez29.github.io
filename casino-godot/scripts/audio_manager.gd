extends Node
## Presentation-only application audio. Never reads or advances gambling RNG.
signal settings_changed
const Catalog = preload("res://scripts/audio_catalog.gd")
const SETTINGS_PATH := "user://pit_boss_audio.cfg"
const DEFAULTS := {"Master": 0.8, "Music": 0.25, "Ambience": 0.35, "World": 0.55, "UI": 0.55, "Games": 0.7, "Slots": 0.75, "Blackjack": 0.75, "Roulette": 0.75, "Craps": 0.75, "Holdem": 0.75}
const GAME_BUSES := {"slots": "Slots", "blackjack": "Blackjack", "roulette": "Roulette", "craps": "Craps", "holdem": "Holdem"}
var volumes := DEFAULTS.duplicate()
var mutes := {}
var streams := {}
var variants := {}
var cooldowns := {}
var pools := {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var wheel: AudioStreamPlayer
var context := "public"
var active_game := ""
var floor_state := "closed"
var listener := Vector2.ZERO
var visible_world := Rect2()
var near_bar := 0.0
var music_gain := 0.0
var ambience_gain := 0.0
var duck_until := 0
var enabled := false
var suspended := false
var dirty_seconds := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Layout is the source of truth. Safe repair also supports standalone smoke scenes.
	for bus in DEFAULTS:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus)
		if bus != "Master": AudioServer.set_bus_send(AudioServer.get_bus_index(bus), "Games" if bus in GAME_BUSES.values() else "Master")
	load_settings()
	streams = Catalog.load_streams()
	for group in {"slot": 1, "game": 3, "world": 5, "ui": 1}:
		pools[group] = []
		for i in range({"slot": 1, "game": 3, "world": 5, "ui": 1}[group]):
			pools[group].append(make_player("UI"))
	music = make_player("Music")
	ambience = make_player("Ambience")
	wheel = make_player("Roulette")
	for pair in [[music, "music"], [ambience, "floor"]]:
		var choices: Array = streams.get(pair[1], [])
		if not choices.is_empty():
			pair[0].stream = choices[0]
			if pair[0].stream is AudioStreamOggVorbis: pair[0].stream.loop = true
		pair[0].volume_db = -80
	if not OS.has_feature("web"): enable_audio()

func make_player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player

func _input(event: InputEvent) -> void:
	if (event is InputEventMouseButton or event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed(): enable_audio()

func enable_audio() -> void:
	if enabled: return
	enabled = true
	if music.stream != null: music.play()
	if ambience.stream != null: ambience.play()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: suspend_audio(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: suspend_audio(false)
	elif what == NOTIFICATION_WM_CLOSE_REQUEST: save_settings()

func suspend_audio(value: bool) -> void:
	suspended = value
	if not is_instance_valid(music): return
	music.stream_paused = value
	ambience.stream_paused = value
	if value:
		stop_game()
		for group in ["world", "ui"]:
			for player in pools[group]: player.stop()

func _process(delta: float) -> void:
	if dirty_seconds >= 0:
		dirty_seconds -= delta
		if dirty_seconds < 0: save_settings()
	if not enabled or suspended: return
	var private_room := context == "back_room"
	var target_music := (0.35 if private_room or floor_state == "closed" else 0.65 + near_bar * 0.35)
	var target_ambience := 0.0 if floor_state == "closed" else 0.25 if private_room else 0.48 if floor_state == "quiet" else 0.8
	if not active_game.is_empty(): target_ambience *= 0.55
	if near_bar > 0 and not private_room: target_ambience *= 1.0 - near_bar * 0.3
	if Time.get_ticks_msec() < duck_until: target_ambience *= 0.35
	music_gain = move_toward(music_gain, target_music, delta * 0.28)
	ambience_gain = move_toward(ambience_gain, target_ambience, delta * 0.28)
	music.volume_db = gain_db(music_gain) - 10
	ambience.volume_db = gain_db(ambience_gain) - 20

func gain_db(value: float) -> float:
	return linear_to_db(value) if value > 0.0001 else -80.0

func set_volume(category: String, value: float) -> void:
	if not DEFAULTS.has(category) or not is_finite(value): return
	volumes[category] = clampf(value, 0, 1)
	apply_settings()

func get_volume(category: String) -> float:
	return float(volumes.get(category, 0))

func set_category_muted(category: String, value: bool) -> void:
	if not DEFAULTS.has(category): return
	mutes[category] = value
	apply_settings()

func is_category_muted(category: String) -> bool:
	return bool(mutes.get(category, false))

func set_master_muted(value: bool) -> void:
	set_category_muted("Master", value)

func set_game_muted(kind: String, value: bool) -> void:
	if GAME_BUSES.has(kind): set_category_muted(GAME_BUSES[kind], value)

func is_game_muted(kind: String) -> bool:
	return is_category_muted(GAME_BUSES.get(kind, "Games"))

func audible(category: String) -> bool:
	for bus in ["Master", category]:
		if is_category_muted(bus) or get_volume(bus) <= 0: return false
	if category in GAME_BUSES.values() and (is_category_muted("Games") or get_volume("Games") <= 0): return false
	return true

func apply_settings(persist: bool = true) -> void:
	for bus in DEFAULTS:
		var index := AudioServer.get_bus_index(bus)
		if index < 0: continue
		AudioServer.set_bus_volume_db(index, gain_db(get_volume(bus)))
		AudioServer.set_bus_mute(index, is_category_muted(bus) or get_volume(bus) <= 0)
	settings_changed.emit()
	if persist: dirty_seconds = 0.35

func reset_defaults() -> void:
	volumes = DEFAULTS.duplicate()
	mutes.clear()
	apply_settings()

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "version", 1)
	for bus in DEFAULTS:
		cfg.set_value(bus, "volume", get_volume(bus))
		cfg.set_value(bus, "muted", is_category_muted(bus))
	if cfg.save(SETTINGS_PATH) != OK: push_warning("Audio preferences could not be saved.")
	dirty_seconds = -1

func load_settings() -> void:
	volumes = DEFAULTS.duplicate()
	mutes.clear()
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK and cfg.get_value("audio", "version", 0) == 1:
		for bus in DEFAULTS:
			var level = cfg.get_value(bus, "volume", DEFAULTS[bus])
			var muted = cfg.get_value(bus, "muted", false)
			if (level is float or level is int) and is_finite(float(level)) and float(level) >= 0 and float(level) <= 1: volumes[bus] = float(level)
			if muted is bool: mutes[bus] = muted
	dirty_seconds = -1
	apply_settings(false)

func play_ui(cue: String) -> void:
	one_shot("ui", "UI", cue, -16, 120)

func play_game(kind: String, cue: String) -> void:
	if not GAME_BUSES.has(kind): return
	var played := one_shot("slot" if kind == "slots" else "game", GAME_BUSES[kind], "slot_" + cue if kind == "slots" else cue, (-17.0 if cue == "ack" else -12.0) if kind == "slots" else -9.0, 65)
	if played and cue in ["big", "top"]: duck_until = Time.get_ticks_msec() + 1800

func play_world(cue: String, position_value: Vector2, important: bool = false) -> void:
	if context != "public": return
	if visible_world.has_area() and not visible_world.grow(40).has_point(position_value): return
	var gain := clampf(1.0 - listener.distance_to(position_value) / 900.0, 0, 1)
	if gain < 0.05: return
	if not active_game.is_empty(): gain *= 0.55
	var played := one_shot("world", "World", cue, gain_db(gain) - 17, 5000 if important else 1400)
	if played and important: duck_until = Time.get_ticks_msec() + 1800

func play_ambience(cue: String, position_value: Vector2 = Vector2.INF) -> void:
	# Supporting activity stays separate from the owner's game mute.
	if context != "public" or floor_state == "closed": return
	var gain := 1.0
	if position_value.is_finite():
		if visible_world.has_area() and not visible_world.grow(40).has_point(position_value): return
		gain = clampf(1.0 - listener.distance_to(position_value) / 900.0, 0, 1)
	if gain < 0.05: return
	if not active_game.is_empty(): gain *= 0.55
	if floor_state == "quiet": gain *= 0.6
	one_shot("world", "Ambience", cue, gain_db(gain) - 28, 4000)

func one_shot(group: String, bus: String, cue: String, db: float, cooldown_ms: int) -> bool:
	if not enabled or suspended or not audible(bus): return false
	var now := Time.get_ticks_msec()
	var key := "Slots:voice" if group == "slot" else bus + ":" + cue
	if now - int(cooldowns.get(key, -100000)) < cooldown_ms: return false
	var choices: Array = streams.get(cue, [])
	if choices.is_empty(): return false
	var player: AudioStreamPlayer
	for candidate in pools[group]:
		if not candidate.playing: player = candidate; break
	if player == null:
		if group in ["slot", "ui"]: player = pools[group][0]; player.stop()
		else: return false
	cooldowns[key] = now
	var index := int(variants.get(cue, 0))
	variants[cue] = index + 1
	player.stream = choices[index % choices.size()]
	player.bus = bus
	player.volume_db = db
	player.pitch_scale = 1.0 + (index % 3 - 1) * 0.015 if cue in ["deal", "chip", "bounce", "glass"] else 1.0
	player.play()
	return true

func start_wheel() -> void:
	play_game("roulette", "wheel")
	if not enabled or suspended or not audible("Roulette"): return
	var choices: Array = streams.get("ball", [])
	if choices.is_empty(): return
	wheel.stream = choices[0]
	# Repeat a restrained physical rattle underneath the visible orbit.
	if wheel.stream is AudioStreamWAV:
		wheel.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wheel.stream.loop_end = int(wheel.stream.get_length() * wheel.stream.mix_rate)
	wheel.volume_db = -19
	wheel.play()

func stop_wheel() -> void:
	wheel.stop()

func stop_game() -> void:
	for group in ["slot", "game"]:
		for player in pools.get(group, []): player.stop()
	if is_instance_valid(wheel): wheel.stop()

func set_context(value: String, kind: String = "") -> void:
	if context == value and active_game == kind: return
	stop_game()
	for player in pools.get("world", []): player.stop()
	context = value
	active_game = kind

func update_floor(opened: bool, guests: int, owner: Vector2, bar: Vector2, bar_owned: bool, view: Rect2) -> void:
	listener = owner
	visible_world = view
	near_bar = clampf(1.0 - owner.distance_to(bar) / 320.0, 0, 1) if bar_owned else 0.0
	if not opened: floor_state = "closed"
	elif floor_state == "busy":
		if guests <= 8: floor_state = "quiet"
	else: floor_state = "busy" if guests >= 14 else "quiet"

func shutdown() -> void:
	enabled = false
	if dirty_seconds >= 0: save_settings()
	for child in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null
	streams.clear()
	pools.clear()

func _exit_tree() -> void:
	shutdown()
