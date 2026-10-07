extends SceneTree
# Presentation and current rules/accounting integration, using existing forced-roll hooks.
var ui: Control
var checks := 0
func check(value: bool, message: String) -> void:
	assert(value, message)
	checks += 1
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func join() -> Dictionary:
	ui.start_casino("easy", ["craps"])
	ui.speed = 0
	ui.selected = int(ui.sim.tables[0].id)
	ui.visitor = true
	ui.sim.player = ui.sim.bounds(ui.sim.tables[0]).get_center()
	ui.join_table()
	ui.game_view.paused = false
	check(ui.sim.joined == ui.selected, "Craps joined")
	return ui.sim.get_table(ui.sim.joined)
func run() -> void:
	ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	await settle()
	ui.close_modal()
	ui.set_process(false)
	var table: Dictionary = join()
	# Every supported key gets a distinct mapped stack position, including traveled contracts.
	await settle()
	var positions := {}
	for key in CrapsRules.empty_bets():
		check(ui.felt.spots.has(key), "Mapped supported key " + key)
		var at: Vector2 = ui.felt.endpoint(key, -1)
		check(not positions.has(at), "Distinct stack " + key)
		positions[at] = key
	for at in [Vector2(180, 690), Vector2(1114, 600), Vector2(1340, 719), Vector2(1420, 450)]:
		for target in ui.felt.targets: check(not target.rect.has_point(at), "Unsupported region inactive")
	# Actual placement, stake rounding and refunds use the unchanged simulation entry points.
	for key in ["pass", "dont_pass", "field", "four", "five", "six", "eight", "nine", "ten", "hard_4", "hard_6", "hard_8", "hard_10", "any_craps", "any_seven", "yo", "aces", "ace_deuce", "boxcars"]:
		var wallet: float = ui.sim.owner_bankroll
		var cash: float = ui.sim.cash
		var amount: float = ui.sim.bet_amount(table, key, 25)
		check(ui.sim.bet(int(table.id), key, 25), "Place " + key)
		check(ui.sim.owner_bankroll == wallet - amount and ui.sim.cash == cash + amount, "Debit " + key)
		check(ui.sim.remove_bet(int(table.id), key) == amount, "Refund " + key)
		check(ui.sim.owner_bankroll == wallet and ui.sim.cash == cash, "Refund accounting " + key)
	# Establish all six Come and Don't Come contracts through real rolls; attach odds.
	for number in CrapsRules.NUMBERS:
		for prefix in ["come", "dont_come"]:
			table = join()
			check(ui.sim.bet(int(table.id), "pass", 25), "Line")
			check(ui.sim.shoot_player(int(table.id), [3, 3]), "Establish point")
			check(ui.sim.bet(int(table.id), prefix, 25), "Come box")
			var first := mini(5, number - 1)
			check(ui.sim.shoot_player(int(table.id), [first, number - first]), "Travel contract")
			check(table.owner[prefix + "_%d" % number] == 25, "Traveled " + prefix)
			var odds: String = prefix + "_odds_%d" % number
			check(ui.sim.bet(int(table.id), odds, 5), "Attach " + odds)
			check(ui.sim.remove_bet(int(table.id), odds) > 0, "Remove " + odds)
	# Exercise every supported bet against every dice pair at come-out and established point.
	# Fixture stakes still use take_bet, and settlements use the production roll path.
	table = join()
	for point in [0, 6]:
		for key in CrapsRules.empty_bets():
			for a in range(1, 7):
				for b in range(1, 7):
					table.owner = CrapsRules.empty_bets()
					table.point = point
					table.shooter = 0
					check(ui.sim.take_bet(table, {"bets": table.owner}, key, 5, true), "Fixture debit")
					var expected := CrapsRules.resolve(point, table.owner.duplicate(true), a, b, bool(table.owner_working))
					var wallet: float = ui.sim.owner_bankroll
					var cash: float = ui.sim.cash
					ui.sim.roll(int(table.id), [a, b])
					check(table.owner == expected.bets and table.point == expected.point, "Settlement " + key)
					check(ui.sim.owner_bankroll == wallet + float(expected.credit) and ui.sim.cash == cash - float(expected.credit), "Settlement accounting " + key)
					ui.felt.capture_roll(table)
					check(ui.felt.last_roll == table.rolls and ui.felt.message == str(table.result).replace("·", "|").replace("’", "'"), "Dice/result snapshot")
					# Recover surviving fixture stakes through the existing account, avoiding fixture insolvency.
					ui.sim.owner_account.floor_credit(5, ui.sim.elapsed)
	# Felt taps route through the real controller, and the Roll action captures one real roll.
	table = join()
	ui.speed = 1
	ui.felt.locked = false
	ui.felt.animation = 0
	ui.felt.dice_ready = true
	ui.chip_value = 25
	ui.felt.chip = 25
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = ui.felt.offset + ui.felt.spots.pass * ui.felt.factor
	click.pressed = true
	ui.felt._gui_input(click)
	click.pressed = false
	ui.felt._gui_input(click)
	check(table.owner.pass == 25, "Felt tap places line through controller")
	ui.felt.dice_ready = true
	ui.table_action("shoot")
	check(table.rolls == 1 and ui.felt.last_roll == 1 and ui.felt.busy(), "Roll action synchronized")
	ui.felt.animation = 0
	ui.rolling = 0
	ui.game_view.signature.clear()
	ui.game_view.render_current()
	check(ui.game_view.wallet.text.contains(str(int(ui.sim.owner_bankroll))), "Wallet label updates")
	# Natural RNG: presentation capture never consumes RNG or performs extra settlement.
	table = join()
	check(ui.sim.bet(int(table.id), "pass", 25), "Natural roll line")
	check(ui.sim.shoot_player(int(table.id)), "Natural roll")
	var rng_state: int = ui.sim.rng.state
	var wallet: float = ui.sim.owner_bankroll
	ui.felt.capture_roll(table)
	check(ui.sim.rng.state == rng_state and ui.sim.owner_bankroll == wallet, "Presentation does not reroll/pay")
	check(table.dice == [table.history[0].a, table.history[0].b], "Dice synchronized with history")
	ui.felt.animation = 0
	ui.rolling = 0
	ui.sim.reclaim(int(table.id))
	# Clear a locked contract by completing the actual hand before return.
	if table.point > 0: ui.sim.roll(int(table.id), [1, 6])
	ui.leave_table()
	check(ui.sim.joined < 0 and not ui.game_view.visible, "Return to Floor")
	for dims in [Vector2i(1440, 900), Vector2i(390, 844), Vector2i(844, 390)]:
		root.size = dims
		table = join()
		await settle()
		ui.game_view.render_current()
		await settle()
		check(ui.game_view.return_button.is_visible_in_tree(), "Floor return visible")
		check(ui.game_view.wallet.is_visible_in_tree(), "Wallet visible")
		check(ui.felt.factor > 0 and ui.felt.canvas == Vector2(1536, 1120), "Uniform felt transform")
		if dims.x < 1000:
			var scroll: ScrollContainer = ui.felt.play_scroll()
			var before := scroll.scroll_horizontal
			var press := InputEventMouseButton.new()
			press.button_index = MOUSE_BUTTON_LEFT
			press.pressed = true
			press.position = Vector2(400, 500)
			ui.felt._gui_input(press)
			var motion := InputEventMouseMotion.new()
			motion.position = Vector2(300, 500)
			motion.relative = Vector2(-100, 0)
			ui.felt._gui_input(motion)
			check(scroll.scroll_horizontal > before, "Mobile felt pans")
			press.pressed = false
			ui.felt._gui_input(press)
			check(CrapsRules.exposure(table.owner) == 0, "Panning does not place a wager")
	print("PASS: ", checks, " Craps presentation/integration checks")
	quit()
