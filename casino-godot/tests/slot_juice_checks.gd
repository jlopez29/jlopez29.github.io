extends SceneTree
const Games = preload("res://scripts/casino_games.gd")
const Result = preload("res://scripts/slot_result.gd")
const State = preload("res://scripts/slot_presentation_state.gd")
const View = preload("res://scripts/game_view.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("SLOT JUICE: "+label)

func fixture(stops: Array, lines: int = 5) -> Dictionary:
	var result := Games.slots_at_stops(5,stops,CasinoTuning.slot_profile("starter"),lines)
	result.staked = 5.0
	result.paid = true
	return result

func run() -> void:
	var even := fixture([2,7,12])
	var partial := fixture([6,12,16])
	var big := fixture([3,3,3])
	var top := fixture([18,18,18])
	check(even.credit == 5 and Result.describe(even).category == "BREAK EVEN","$5 paid/$5 returned is BREAK EVEN")
	check(partial.credit == 2 and Result.describe(partial).category == "PARTIAL RETURN" and Result.describe(partial).net == -3,"$2 return is NET -$3")
	check(Result.summary(Result.describe(partial)).contains("NET -$3.00"),"Partial-return summary is economically truthful")
	check(Result.describe(fixture([7,12,16],1)).category == "LOSS","Zero return is LOSS")
	check(Result.describe(big).category == "BIG WIN" and Result.describe(top).category == "TOP AWARD","Positive big/top tiers")
	check(Result.describe(even,true).positive and Result.describe(even,true).net == 5,"Sponsored $5 is positive casino cash")
	check(Result.describe(fixture([7,12,16],1),true).category == "NO RETURN","Sponsored loss costs nothing")
	for sample in [{"credit":7.0,"label":"SMALL WIN"},{"credit":10.0,"label":"WIN"},{"credit":25.0,"label":"BIG WIN"},{"credit":50.0,"label":"HUGE WIN"}]:
		check(Result.describe({"credit":sample.credit,"staked":5.0,"total_wager":5.0,"winning_lines":[]}).category == sample.label,"Central tier threshold "+str(sample.credit))
	for round in [even,partial,big,top]:
		var state := State.new()
		var cues: Array = []
		state.cue.connect(func(name): cues.append(name))
		var before := JSON.stringify(round)
		state.start(round,false)
		check(not state.skip() and not state.revealed,"Cannot skip unrevealed outcome")
		state.advance(float(state.ends[0])-0.001)
		check(cues == ["spin"],"Stop cue waits for physical impact")
		state.advance(0.0011)
		check(cues.count("stop1") == 1,"First impact cue exactly once")
		state.advance(state.reveal_at-state.elapsed+0.001)
		check(state.revealed and state.phase == State.Phase.LINE_REVEAL,"Recognition pause precedes first line")
		check(state.symbol_age(int(round.winning_lines[0].path[0]),0) >= 0 and state.symbol_age(int(round.winning_lines[0].path[2]),2) < 0,"Symbols react as tracer reaches them")
		state.advance(0.3)
		check(state.line_progress(0) == 1 and state.symbol_age(int(round.winning_lines[0].path[2]),2) >= 0,"Tracer completes within 320ms")
		if Result.describe(round).positive:
			check(cues.count("burst") == 1,"One positive-result particle burst")
		else:
			check(not cues.has("burst") and not cues.has("big") and not cues.has("small"),"Break-even/partial have no win celebration")
		check(state.skip() and state.count_progress() == 1,"Safe skip snaps display to authoritative return")
		state.advance(10)
		check(cues.count("stop1") == 1 and cues.count("stop2") == 1 and cues.count("stop3") == 1,"Refresh/skip never repeats audio")
		check(JSON.stringify(round) == before,"Presentation leaves committed result unchanged")
		check(not state.skip(),"Ready state cannot replay skip")
	var state := State.new()
	state.start(even,false)
	state.advance(state.reveal_at+even.winning_lines.size()*State.LINE_SECONDS+0.01)
	check(state.all_lines(),"Multiple lines illuminate together briefly")
	state.advance(State.ALL_LINES_SECONDS)
	check(not state.all_lines() and not state.active,"Full paths clear to edge markers at ready")
	await view_checks(even)
	await create_timer(0.15).timeout
	print("SLOT JUICE: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func view_checks(even: Dictionary) -> void:
	var sim := CasinoSimulation.new()
	sim.opened = true
	sim.join_table(int(sim.tables[0].id))
	sim.tables[0].round = even
	var view := View.new()
	view.sim = PitBossGameContext.new(sim)
	root.add_child(view)
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.render_current()
	view.art.slot_audio.volume = 0
	view.art.begin_slot_reveal()
	view.balance_before = Vector2(sim.owner_bankroll,sim.cash)
	var snapshot := JSON.stringify(sim.snapshot())
	view.press_slot_spin()
	check(JSON.stringify(sim.snapshot()) == snapshot,"Early repeated Spin cannot settle again")
	view.art._process(view.art.reveal_time+0.2)
	view.render_current()
	check(view.slot_spin.text == "SKIP" and not view.slot_spin.disabled,"Post-reveal Spin offers safe SKIP")
	check(view.result_text(sim.tables[0],false).begins_with("BREAK EVEN"),"Play UI never labels paid break-even WIN")
	check(view.art.particles.count == 0 and not view.slot_dimmer.visible,"Break-even avoids particles and strong dimming")
	view.press_slot_spin()
	check(not view.locked() and JSON.stringify(sim.snapshot()) == snapshot,"Skip completes presentation without a second wager")
	for dimensions in [Vector2i(1440,810),Vector2i(2560,1080),Vector2i(800,600),Vector2i(390,844),Vector2i(844,390),Vector2i(320,568)]:
		root.size = dimensions
		root.content_scale_size = dimensions
		await process_frame
		view.layout_play()
		view.render_current()
		await process_frame
		check(view.slot_spin.get_global_rect().end.y <= dimensions.y,"Visible Spin/Skip target "+str(dimensions))
		check(view.art.round == even,"Resize preserves committed screen "+str(dimensions))
	view.art.reduced_motion = true
	check(view.art.symbol_scale(0.05) == 1.04,"Reduced motion removes symbol overshoot")
	view.queue_free()
	await process_frame
