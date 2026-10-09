extends Control
signal leave_requested
signal changed
const UI = preload("res://scripts/recovery/workbench_ui.gd")
const WorkbenchTheme = preload("res://scripts/pit_boss_theme.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
const Games = [preload("res://scripts/recovery/cage_game.gd"),preload("res://scripts/recovery/security_game.gd"),preload("res://scripts/recovery/slot_game.gd"),preload("res://scripts/recovery/operations_game.gd")]
var sim: CasinoSimulation
var frame: PanelContainer
var content: VBoxContainer
var wallet: Label
var feedback: Label
var help: Label
var toolbar: VBoxContainer
var verify: Button
var overview: Control
var promotions: Control
var game: Control
var job_layout: GridContainer
var sidebar: PanelContainer
var job_status: Label
var active_id := ""
var mode := "overview"
var drafts := {}
var scratch_progress := {}
var revision := ""
var poll := 0.0
var insets := Vector4.ZERO
var result_tween: Tween
func _ready() -> void:
	theme=WorkbenchTheme.create()
	mouse_filter=MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color=Color(0.025,0.035,0.035,0.94)
	shade.mouse_filter=MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	frame=PanelContainer.new()
	frame.add_theme_stylebox_override("panel",WorkbenchTheme.box(Color("121f20"),WorkbenchTheme.GOLD,16))
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation",10)
	frame.add_child(stack)
	var header := HBoxContainer.new()
	stack.add_child(header)
	UI.button(header,"< Back",back)
	var title := UI.text(header,"RECOVERY WORKSHOP",20)
	title.size_flags_horizontal=SIZE_EXPAND_FILL
	UI.button(header,"Help",func(): help.visible=not help.visible)
	wallet=UI.text(stack,"",18)
	help=UI.text(stack,"",16)
	help.hide()
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical=SIZE_EXPAND_FILL
	stack.add_child(scroll)
	content=VBoxContainer.new()
	content.size_flags_horizontal=SIZE_EXPAND_FILL
	scroll.add_child(content)
	toolbar=VBoxContainer.new()
	stack.add_child(toolbar)
	feedback=UI.text(toolbar,"",17)
	feedback.hide()
	verify=UI.button(toolbar,"Verify my work",submit)
	verify.hide()
	resized.connect(layout)
	visibility_changed.connect(on_visibility_changed)
	layout()
func on_visibility_changed() -> void:
	set_process(is_visible_in_tree())
	set_process_unhandled_input(is_visible_in_tree())
	if not is_visible_in_tree() and result_tween: result_tween.kill()

func layout() -> void:
	if not is_instance_valid(frame): return
	var usable := size-Vector2(insets.x+insets.z,insets.y+insets.w)
	var margin := 8.0 if usable.x<600 else 24.0
	frame.size=Vector2(minf(1200,usable.x-margin*2),maxf(1,usable.y-margin*2))
	frame.position=Vector2(insets.x+(usable.x-frame.size.x)/2,insets.y+margin)
	if is_instance_valid(job_layout):
		job_layout.columns=2 if frame.size.x>=1000 else 1
		sidebar.visible=job_layout.columns==2
func open() -> void:
	show()
	if revision!=fingerprint(): show_overview()
	elif content.get_child_count()==0: show_overview()
	update_values()
func fingerprint() -> String:
	return str([sim.recovery.state.cycle_id,sim.recovery.state.contracts,sim.recovery.state.tickets])
func clear_content() -> void:
	for child in content.get_children(): content.remove_child(child); child.queue_free()
	overview=null
	promotions=null
	game=null
	job_layout=null
	sidebar=null
	job_status=null
	verify.hide()
func show_overview() -> void:
	clear_content()
	mode="overview"
	active_id=""
	var view := preload("res://scripts/recovery/desk_overview.gd").new()
	view.sim=sim
	view.started=drafts
	view.job_requested.connect(open_job)
	view.claim_requested.connect(recover)
	view.promotions_requested.connect(show_promotions)
	content.add_child(view)
	overview=view
	revision=fingerprint()
	update_values()
func open_job(id: String) -> void:
	var c := contract(id)
	if c.is_empty(): show_overview(); return
	clear_content()
	feedback.hide()
	mode="job"
	active_id=id
	if not drafts.has(id): drafts[id]={}
	job_layout=GridContainer.new()
	job_layout.add_theme_constant_override("h_separation",16)
	content.add_child(job_layout)
	game=Games[int(c.category)].new()
	game.setup(Recovery.puzzle(c),drafts[id])
	job_layout.add_child(game)
	var notes := UI.card(job_layout,Color("302b24"))
	sidebar=notes.get_parent()
	sidebar.custom_minimum_size.x=260
	sidebar.size_flags_horizontal=SIZE_FILL
	UI.text(notes,"WORKSHOP NOTES",20)
	job_status=UI.text(notes,"")
	UI.text(notes,"1. Inspect the case.\n2. Adjust your draft.\n3. Verify once.\n\nWrong attempts save a retry gate. Local taps never spend an attempt.")
	UI.button(notes,"Back to job overview",show_overview)
	verify.show()
	layout()
	update_values()
func contract(id: String) -> Dictionary:
	for c in sim.recovery.state.contracts:
		if c.id==id: return c
	return {}
func show_promotions() -> void:
	clear_content()
	mode="promotions"
	var view := preload("res://scripts/recovery/promotion_panel.gd").new()
	view.sim=sim
	view.scratch_progress=scratch_progress
	view.claim_requested.connect(ticket)
	content.add_child(view)
	promotions=view
	update_values()
func back() -> void:
	if mode!="overview": show_overview()
	else: leave_requested.emit()
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		back()
		get_viewport().set_input_as_handled()
func _process(delta: float) -> void:
	poll+=delta
	if poll<1.0: return
	poll=0
	if revision!=fingerprint():
		if mode=="overview": show_overview()
		elif mode=="promotions": show_promotions()
		elif contract(active_id).is_empty(): show_overview()
		revision=fingerprint()
	update_values()
func update_values() -> void:
	if sim==null or not is_instance_valid(wallet): return
	var gap := maxf(0,Recovery.TARGET-sim.owner_bankroll)
	wallet.text="Personal wallet $%.2f / Target $%.0f / Eligible gap $%.2f" % [sim.owner_bankroll,Recovery.TARGET,gap]
	var remaining: int=sim.recovery.passive_minutes_remaining(sim.elapsed)
	help.text="Work is a virtual casino exercise. Inspect, adjust, then Verify once. Back keeps your draft while the workshop is open.\nRecovery timers use REAL TIME. Work minimum: %s. Retry: %s.\nPassive allowance +$%.0f every %d GAME minutes; next in %dh %02dm GAME time. Offline time follows the device clock. Rewards have no real-money value." % [UI.clock(CasinoTuning.RECOVERY_WORK_MIN_SECONDS),UI.clock(CasinoTuning.RECOVERY_RETRY_SECONDS),CasinoTuning.OWNER_ALLOWANCE_AMOUNT,CasinoTuning.OWNER_ALLOWANCE_INTERVAL_MINUTES,remaining/60,remaining%60]
	if is_instance_valid(overview): overview.update_values()
	if is_instance_valid(promotions): promotions.update_values()
	if mode=="job":
		var c := contract(active_id)
		if c.is_empty(): return
		var retry := maxi(0,int(c.retry_utc)-sim.recovery.now())
		if is_instance_valid(job_status): job_status.text="Recovery tier: %s\n%d/3 jobs verified\nEligible gap: $%.2f\n\n%s" % [sim.recovery.state.stage,sim.recovery.successes(),gap,"[VERIFIED]" if c.done else "Retry in "+UI.clock(retry) if retry>0 else "Draft in progress"]
		verify.disabled=c.done or retry>0 or sim.joined>=0 or not sim.owner_play.is_empty()
		verify.text="Verified / Return with Back" if c.done else "Retry in "+UI.clock(retry) if retry>0 else "Verify my work"
func result(value: String, success: bool) -> void:
	feedback.text=value
	feedback.show()
	if result_tween: result_tween.kill()
	feedback.modulate.a=0.25
	result_tween=create_tween()
	result_tween.tween_property(feedback,"modulate:a",1.0,0.25)
	feedback.add_theme_color_override("font_color",Color("a5d6ac") if success else Color("efc27b"))
func submit() -> void:
	if mode!="job" or verify.disabled: return
	var response: Dictionary=game.response()
	var ok: bool=sim.private_transaction(func(): return sim.recovery.submit(sim,active_id,response))
	var c := contract(active_id) # Rollback can replace the model dictionary.
	if not ok: result("Could not save verification. Check eligibility or local save availability; your draft is kept.",false)
	elif c.done:
		result("[VERIFIED] %d/3 jobs complete. %s Check the overview for earned tickets and recovery readiness." % [sim.recovery.successes(),str(c.feedback)],true)
	else: result("[INCORRECT] "+str(c.feedback),false)
	AudioManager.play_ui("win" if ok and c.done else "invalid")
	revision=fingerprint()
	update_values()
	changed.emit()
func recover(source: String) -> void:
	var before: float=sim.owner_bankroll
	var ok: bool=sim.private_transaction(func(): return sim.recovery.claim(sim,source))
	if ok:
		drafts.clear()
		show_overview()
	result("Saved refill +$%.2f to personal wallet. New work cycle ready." % (sim.owner_bankroll-before) if ok else "Recovery unavailable: check wallet gap, active wager, real-time wait or local save.",ok)
	AudioManager.play_ui("win" if ok else "invalid")
	changed.emit()
func ticket(id: String) -> void:
	var ok: bool=sim.private_transaction(func(): return sim.recovery.claim_ticket(sim,id))
	var claimed := {}
	for t in sim.recovery.state.tickets:
		if t.id==id: claimed=t
	if ok:
		show_promotions()
		result("No award this time. Ticket result saved." if claimed.award==0 else "Prize $%.2f / Actual credit +$%.2f / Wallet cap $%.0f" % [claimed.award,claimed.granted,Recovery.TARGET],claimed.award>0)
	else:
		result("Ticket kept: need a wallet gap, settled wagers, a ready draw and a successful local save.",false)
		if is_instance_valid(promotions): promotions.update_values()
	revision=fingerprint()
	AudioManager.play_ui("win" if ok and float(claimed.get("granted",0))>0 else "confirm" if ok else "invalid")
	changed.emit()
