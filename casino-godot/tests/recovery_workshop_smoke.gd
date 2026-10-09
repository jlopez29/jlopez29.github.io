extends SceneTree
## Bounded UI/input checks, using the authoritative curated puzzles.
const Sim = preload("res://scripts/simulation.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var checks := 0
var failures := 0
var captures := OS.get_environment("RECOVERY_CAPTURES")=="1"
func _initialize() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(message)
func settle() -> void:
	for i in range(5): await process_frame
func click(button: Button, emulated: bool = false) -> void:
	var ancestor := button.get_parent()
	while ancestor!=null:
		if ancestor is ScrollContainer:
			ancestor.ensure_control_visible(button)
			await settle()
			break
		ancestor=ancestor.get_parent()
	var event := InputEventMouseButton.new()
	event.button_index=MOUSE_BUTTON_LEFT
	event.position=button.get_global_rect().get_center()
	event.global_position=event.position
	event.device=InputEvent.DEVICE_ID_EMULATION if emulated else 0
	event.pressed=true
	root.push_input(event)
	event=event.duplicate()
	event.pressed=false
	root.push_input(event)
	await settle()
func capture(name: String) -> void:
	if not captures: return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/tmp/recovery_"+name+".png")
func run() -> void:
	root.content_scale_size=Vector2i.ZERO
	root.size=Vector2i(1440,900)
	var host := Control.new()
	root.add_child(host)
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sim := Sim.new()
	sim.owner_checkpoint=func(): return true
	var desk = load("res://scripts/recovery_view.gd").new()
	desk.sim=sim
	host.add_child(desk)
	desk.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desk.set_process(false)
	desk.open()
	await settle()
	await capture("overview_1440")
	var id: String=sim.recovery.state.contracts[0].id
	for category in range(4):
		var contract: Dictionary=sim.recovery.state.contracts[0]
		contract.category=category
		contract.variant=1
		contract.tier=0
		desk.drafts[id]={}
		desk.open_job(id)
		await settle()
		var game=desk.game
		var before: Dictionary=sim.recovery.state.duplicate(true)
		var rng_before: int=sim.recovery.rng.state
		match category:
			0:
				await click(game.slips[1])
				check(game.response()=={"choice":1},"Receipt mouse selection is canonical draft")
				game.entry.text="-15"
				game.entry.text_changed.emit("-15")
				check(game.response()=={"choice":1,"number":-15},"Signed numeric entry remains canonical")
			1:
				await click(game.records[1],true)
				game.stamps[1].pressed.emit()
				check(game.response()=={"choice":1,"reason":1},"Folder touch-equivalent and evidence emit canonical draft")
				check(game.documents[0].text.contains("11:10") and game.documents[1].text.contains("11:05"),"Documents use structured timestamps without solution highlight")
			2:
				await click(game.modules[2])
				game.switches[0].grab_focus()
				var key := InputEventAction.new()
				key.action="ui_accept"
				key.pressed=true
				root.push_input(key)
				key=key.duplicate(); key.pressed=false
				root.push_input(key)
				await settle()
				check(game.response()=={"choice":2,"mask":1},"Native keyboard rocker emits canonical mask")
				game.switches[1].pressed.emit()
				check(game.response().mask==3,"Switch toggle changes only corresponding bit")
				for rocker in game.switches: rocker.pressed.emit()
				check(game.response().mask==4,"Switch bank can reach the curated target")
			3:
				await click(game.workers[0])
				game.drop._drop_data(Vector2.ZERO,{"worker":1})
				game.aisle.pressed.emit()
				check(game.response()=={"mask":3,"aisle":true},"Worker mouse, drag and aisle emit canonical draft")
				check(game.lanes[1].badges==[0,1],"Worker magnets appear in each covered shift")
		check(Recovery.solved(contract,game.response()),"Object controls produce a valid canonical solution %d" % category)
		check(sim.recovery.state==before and sim.recovery.rng.state==rng_before,"Exploration leaves attempts, tickets and RNG unchanged")
		var draft: Dictionary=game.response()
		for viewport in [Vector2i(1440,900),Vector2i(390,844),Vector2i(360,740),Vector2i(844,390),Vector2i(768,1024)]:
			root.size=viewport
			await settle()
			desk.layout()
			await settle()
			check(game.response()==draft,"Orientation preserves draft %d / %s" % [category,viewport])
			check(desk.frame.get_global_rect().end.x<=viewport.x and desk.frame.get_global_rect().end.y<=viewport.y,"Workshop fits viewport %d / %s" % [category,viewport])
			check(game.size.x<=desk.frame.size.x and game.get_global_rect().end.x<=desk.frame.get_global_rect().end.x,"No horizontal workstation overflow %d / %s" % [category,viewport])
			check(desk.verify.size.y>=48 and desk.verify.get_global_rect().end.y<=viewport.y and desk.verify.get_global_rect().position.y>=0,"Verify remains visible %d / %s" % [category,viewport])
			await capture("%d_%dx%d" % [category,viewport.x,viewport.y])
			if captures and viewport.x==360:
				var scroll: ScrollContainer=desk.content.get_parent().get_parent()
				scroll.scroll_vertical=100000
				await settle()
				await capture("%d_%dx%d_bottom" % [category,viewport.x,viewport.y])
				scroll.scroll_vertical=0
				await settle()
		root.size=Vector2i(1440,900)
		await settle()
		desk.show_overview()
		desk.open_job(id)
		await settle()
		check(desk.game.response()==draft,"Navigation preserves unsent selections")
	# Completion artwork cannot alter the authoritative state.
	var state: Dictionary=sim.recovery.state.duplicate(true)
	var rng_state: int=sim.recovery.rng.state
	desk.result_stamp.stamp(true,"VERIFIED")
	await settle()
	check(sim.recovery.state==state and sim.recovery.rng.state==rng_state,"Stamp animation cannot grant or mutate rewards")
	# A wrong Verify is the sole durable attempt and exposes saved retry hint.
	var c: Dictionary=sim.recovery.state.contracts[0]
	c.category=0
	desk.open_job(id)
	desk.drafts[id]={}
	desk.game.draft=desk.drafts[id]
	desk.submit()
	check(c.failures==1 and not c.done and desk.verify.disabled and desk.feedback.visible,"Verify alone saves wrong attempt with retry and hint")
	# Both touch and mouse scratching request a claim; no visual result is generated.
	sim.owner_account.balance=100
	sim.recovery.issue("scratch")
	var ticket: Dictionary=sim.recovery.state.tickets[-1]
	var ticket_copy: Dictionary=ticket.duplicate(true)
	var scratch := preload("res://scripts/recovery_scratch_card.gd").new()
	host.add_child(scratch)
	scratch.size=Vector2(300,150)
	var reveal_requests := [0]
	scratch.scratched.connect(func(): reveal_requests[0]+=1)
	for y in range(3):
		for x in range(0,12,2):
			var touch := InputEventScreenTouch.new()
			touch.position=Vector2(x*25+10,y*30+10)
			touch.pressed=true
			scratch._gui_input(touch)
	check(reveal_requests[0]==1 and ticket==ticket_copy,"Touch scratch requests reveal once without exposing saved reward")
	scratch.reset_after_failure()
	for y in range(3):
		for x in range(0,12,2):
			var mouse := InputEventMouseButton.new()
			mouse.button_index=MOUSE_BUTTON_LEFT
			mouse.position=Vector2(x*25+10,y*30+10)
			mouse.pressed=true
			scratch._gui_input(mouse)
	check(reveal_requests[0]==2 and ticket==ticket_copy,"Mouse scratch shares save-safe claim request")
	sim.owner_account.balance=1000
	desk.show_promotions()
	await settle()
	var row: Dictionary=desk.promotions.rows[ticket.id]
	check(row.action.disabled and row.scratch.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Full wallet gates both accessible reveal and scratch")
	# The accessible action must honor checkpoint rejection and saved outcomes.
	sim.owner_account.balance=100
	desk.promotions.update_values()
	var saved_ticket: Dictionary=sim.recovery.state.tickets[-1].duplicate(true)
	sim.owner_checkpoint=func(): return false
	row.action.pressed.emit()
	check(sim.recovery.state.tickets[-1]==saved_ticket and sim.owner_bankroll==100,"Rejected save keeps unrevealed ticket and predetermined outcome")
	sim.owner_checkpoint=func(): return true
	row=desk.promotions.rows[saved_ticket.id]
	row.action.pressed.emit()
	var claimed := {}
	for t in sim.recovery.state.tickets:
		if t.id==saved_ticket.id: claimed=t
	check(claimed.claimed and claimed.revealed and claimed.award==saved_ticket.award and sim.owner_bankroll==100+minf(900,saved_ticket.award),"Accessible reveal commits only the saved predetermined award")
	id=sim.recovery.state.contracts[0].id
	# Insets reserve the footer even in short landscape.
	root.size=Vector2i(844,390)
	desk.insets=Vector4(12,8,12,34)
	desk.open_job(id)
	await settle()
	desk.layout()
	await settle()
	check(desk.verify.get_global_rect().end.y<=356,"Verify respects bottom safe inset")
	desk.hide()
	check(not desk.is_processing() and not desk.result_stamp.is_visible_in_tree(),"Hidden workshop stops UI activity")
	host.queue_free()
	await settle()
	root.get_node("AudioManager").shutdown()
	await create_timer(0.12).timeout
	print("RECOVERY_WORKSHOP_SMOKE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
