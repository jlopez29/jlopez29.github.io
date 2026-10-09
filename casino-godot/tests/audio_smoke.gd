extends SceneTree
## Focused audio acceptance smoke; no long simulation or regression runner.
var failures := 0
var checks := 0
var audio: Node
var original_settings := ""
var had_settings := false

func _initialize() -> void: call_deferred("run")

func check(ok: bool, caption: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("AUDIO FAIL: " + caption)

func frames(count: int = 3) -> void:
	for i in range(count): await process_frame

func run() -> void:
	audio = root.get_node("AudioManager")
	had_settings = FileAccess.file_exists(audio.SETTINGS_PATH)
	if had_settings: original_settings = FileAccess.get_file_as_string(audio.SETTINGS_PATH)
	audio.reset_defaults()
	for bus in audio.DEFAULTS:
		check(AudioServer.get_bus_index(bus) >= 0, "bus " + bus)
		if bus != "Master": check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == ("Games" if bus in audio.GAME_BUSES.values() else "Master"), "parent " + bus)
	for cue in audio.streams:
		check(not audio.streams[cue].is_empty(), "real asset " + cue)
		for stream in audio.streams[cue]: check(stream.get_length() > 0.01, "nonempty " + cue)
	check(audio.music.playing and audio.music.stream.loop, "one looping Jazz player")
	check(audio.music.stream.get_length() > 70, "full Jazz track")
	check(audio.ambience.playing and audio.ambience.stream.loop, "looping real ambience")
	audio.set_volume("Blackjack", 0.42)
	audio.set_game_muted("blackjack", true)
	audio.save_settings()
	audio.volumes["Blackjack"] = 0.9
	audio.mutes.clear()
	audio.load_settings()
	check(is_equal_approx(audio.get_volume("Blackjack"), 0.42) and audio.is_game_muted("blackjack"), "persistent game volume and mute")
	check(audio.audible("Slots") and audio.audible("Craps") and audio.audible("Music"), "mute isolation")
	audio.set_category_muted("Games", true)
	check(not audio.audible("Slots") and not audio.is_game_muted("slots"), "parent mute preserves independent preference")
	audio.set_master_muted(true)
	for bus in audio.DEFAULTS: check(not audio.audible(bus), "master silences " + bus)
	audio.reset_defaults()
	audio.set_volume("UI", 0)
	check(not audio.audible("UI") and not audio.is_category_muted("UI"), "zero level is silent")
	audio.reset_defaults()
	for bus in audio.DEFAULTS:
		audio.set_volume(bus, 0.63)
		check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus)), linear_to_db(0.63)), "immediate slider gain " + bus)
	audio.reset_defaults()
	for bus in audio.DEFAULTS:
		check(is_equal_approx(audio.get_volume(bus), audio.DEFAULTS[bus]) and not audio.is_category_muted(bus), "reset " + bus)
	audio.update_floor(true, 1, Vector2.ZERO, Vector2.ZERO, true, Rect2())
	check(audio.floor_state == "quiet" and audio.near_bar == 1, "quiet floor and real bar proximity")
	audio.update_floor(true, 15, Vector2.ZERO, Vector2.ZERO, false, Rect2())
	check(audio.floor_state == "busy", "busy real population")
	audio.update_floor(true, 11, Vector2.ZERO, Vector2.ZERO, false, Rect2())
	check(audio.floor_state == "busy", "population hysteresis")
	audio.update_floor(true, 8, Vector2.ZERO, Vector2.ZERO, false, Rect2())
	check(audio.floor_state == "quiet", "busy falls to quiet at threshold")
	audio.update_floor(false, 15, Vector2.ZERO, Vector2.ZERO, false, Rect2())
	check(audio.floor_state == "closed", "closed casino overrides population")
	var app = load("res://main.tscn").instantiate()
	root.add_child(app)
	await frames()
	app.close_modal()
	app.global_action(6)
	check(app.audio_settings.visible, "public menu")
	app.audio_settings.close_panel()
	app.in_back_room = true
	app.apply_visibility()
	app.global_action(6)
	check(app.audio_settings.visible and audio.context == "back_room", "Back Room menu and ambience context")
	for extent in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390), Vector2i(320, 480)]:
		root.size = extent
		root.content_scale_size = extent
		app.size = extent
		app.audio_settings.size = extent
		app.audio_settings.layout_panel()
		await frames()
		check(Rect2(Vector2.ZERO, extent).encloses(app.audio_settings.panel.get_rect()), "settings bounds " + str(extent))
	check(not app.felt.is_processing_input() and not app.game_view.is_processing_input(), "settings blocks game gestures without stopping reveal")
	app.audio_settings.rows.Music.slider.value = 31
	check(is_equal_approx(audio.get_volume("Music"), 0.31), "slider applies bus volume immediately")
	app.audio_settings.rows.Music.mute.button_pressed = true
	check(audio.is_category_muted("Music") and is_equal_approx(audio.get_volume("Music"), 0.31), "mute keeps volume")
	app.audio_settings.close_panel()
	app.audio_settings.open()
	check(app.audio_settings.rows.Music.slider.value == 31 and app.audio_settings.rows.Music.mute.button_pressed, "reopen reflects state")
	app.audio_settings.close_panel()
	for kind in audio.GAME_BUSES:
		app.start_casino("normal", ["slots"])
		app.sim.owner_checkpoint = Callable()
		app.in_back_room = true
		app.sim.back_room.choose(kind)
		app.private_play = true
		app.game_view.sim = PitBossGameContext.new(app.sim, {"id": 9001, "kind": kind})
		app.felt.sim = app.game_view.sim
		app.game_view.render_current()
		app.apply_visibility()
		var view = app.game_view
		var funds: float = app.sim.owner_bankroll
		view.menu_action(9)
		check(app.audio_settings.visible and app.sim.owner_bankroll == funds, kind + " settings do not wager")
		app.audio_settings.close_panel()
		view.toggle_audio()
		check(audio.is_game_muted(kind), kind + " speaker controls its own bus")
		view.toggle_audio()
		audio.cooldowns.clear()
		audio.play_game(kind, "spin" if kind == "slots" else "chip")
		var voices: Array = audio.pools.slot if kind == "slots" else audio.pools.game
		check(voices.any(func(player): return player.playing and player.bus == audio.GAME_BUSES[kind]), kind + " foreground route")
		await create_timer(0.03).timeout
		audio.stop_game()
		if kind in ["slots", "blackjack", "holdem"]:
			audio.cooldowns.clear()
			view.bet = 1
			view.transact(true)
			check(view.art.spinning > 0, kind + " committed reveal begins")
			check(voices.any(func(player): return player.playing), kind + " action emits audio")
			view.art.spinning = 0
			view.finish_audio_result()
		elif kind == "roulette":
			check(view.sim.roulette_bet(9001, "Red", 1), "roulette real chip")
			view.transact(true)
			check(audio.wheel.playing, "roulette orbit loop")
			view.art.spinning = 0
			view.finish_audio_result()
			check(not audio.wheel.playing, "roulette completion stops loop")
		elif kind == "craps":
			var table: Dictionary = view.current_table()
			app.felt.initialize_table(table)
			app.felt.prepare_roll(table)
			check(view.sim.bet(9001, "pass", 1), "craps actual wager")
			view.current_table() # Refresh the private operation sequence after betting.
			check(view.sim.shoot_player(9001), "craps confirmed roll")
			table = view.current_table()
			app.felt.capture_roll(table)
			app.felt._process(app.felt.ROLL_SECONDS * 0.6)
			check(app.felt.audio_wall, "craps cushion boundary")
			app.felt._process(app.felt.ROLL_SECONDS * 0.5)
			check(app.felt.audio_bounced and app.felt.audio_settled, "craps bounce and settle boundaries")
		await create_timer(0.03).timeout
		audio.stop_game()
	# Sound dispatch must never consume gambling/simulation RNG or change money.
	var rng_state: int = app.sim.rng.state
	var cash: float = app.sim.cash
	var wallet: float = app.sim.owner_bankroll
	for i in range(200):
		audio.play_ui("confirm")
		audio.play_world("chip", app.sim.player)
		audio.play_game("blackjack", "deal")
	check(app.sim.rng.state == rng_state and app.sim.cash == cash and app.sim.owner_bankroll == wallet, "audio preserves RNG and finances")
	check(audio.pools.slot.size() == 1 and audio.pools.game.size() == 3 and audio.pools.world.size() == 5 and audio.pools.ui.size() == 1, "bounded reusable voices")
	var music_id: int = audio.music.get_instance_id()
	for i in range(10): audio.set_context("public" if i % 2 else "back_room", "blackjack")
	check(audio.music.get_instance_id() == music_id and audio.music.playing, "rapid transitions retain one Jazz stream")
	audio.set_volume("Music", 0.31)
	app.start_casino("normal", ["slots"])
	check(is_equal_approx(audio.get_volume("Music"), 0.31), "new casino keeps application settings")
	var casino_snapshot: Dictionary = app.sim.snapshot()
	check(app.sim.restore(casino_snapshot), "current casino state reload")
	app.bind_audio_events()
	check(is_equal_approx(audio.get_volume("Music"), 0.31), "casino reload keeps application settings")
	var cfg := FileAccess.open(audio.SETTINGS_PATH, FileAccess.WRITE)
	cfg.store_string("not a valid config [")
	cfg.close()
	audio.load_settings()
	check(audio.volumes == audio.DEFAULTS and not audio.is_game_muted("blackjack"), "corrupt config defaults")
	audio.shutdown()
	await create_timer(0.12).timeout
	app.queue_free()
	await frames()
	if had_settings:
		cfg = FileAccess.open(audio.SETTINGS_PATH, FileAccess.WRITE)
		cfg.store_string(original_settings)
		cfg.close()
	else: DirAccess.remove_absolute(audio.SETTINGS_PATH)
	audio.load_settings()
	print("Audio smoke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
