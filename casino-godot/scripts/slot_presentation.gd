extends "res://scripts/game_art.gd"
## Presentation over committed stops. Drawing never generates or settles outcomes.
const SlotAudio = preload("res://scripts/slot_audio.gd")
const State = preload("res://scripts/slot_presentation_state.gd")
const Particles = preload("res://scripts/slot_particles.gd")
const SYMBOL_ASSETS := ["cherry","lemon","bell","bar","seven"]
const PREMIUM_ASSETS := "casino_play/slots/premium/"
const LINE_COLORS := [Color("ffd879"),Color("79d7ed"),Color("9fe8ad"),Color("df9cec"),Color("ffa685")]
var machine_profile := {}
var wager := 10.0
var sponsored := false
var reduced_motion := false
var slot_audio: Node
var timeline := State.new()
var particles := Particles.new()
var idle_time := 0.0
var idle_redraw_elapsed := 0.0
var initial_stops := [3,11,18]
var slot_lines := 1
var free_remaining := -1
var last_win := 0.0
var status_message := ""
# Crop atlas remnants and excess transparent padding without altering the supplied PNGs.
const SYMBOL_REGIONS := [Rect2(72,92,372,328),Rect2(94,104,325,304),Rect2(104,96,328,320),Rect2(109,154,341,203),Rect2(84,112,344,315)]
var slot_textures: Array[Texture2D] = []
var effect_textures := {}
var slot_elapsed: float:
	get: return timeline.elapsed
var reveal_time: float:
	get: return timeline.reveal_at
var win_tier: String:
	get: return str(timeline.info.get("category",""))

func _ready() -> void:
	super._ready()
	slot_audio = SlotAudio.new()
	add_child(slot_audio)
	timeline.cue.connect(on_presentation_cue)
	for i in range(SYMBOL_ASSETS.size()):
		slot_textures.append(art_region("symbols/"+SYMBOL_ASSETS[i],SYMBOL_REGIONS[i]))
	# Use clean, isolated sprites from the supplied effect sheets.
	effect_textures["coin"] = art_region("slot_coin_particle",Rect2(231,200,77,65))
	effect_textures["sparkle"] = art_region("slot_sparkle_particle",Rect2(337,201,57,50))
	effect_textures["stop"] = art_region("slot_stop_flash",Rect2(178,195,155,138))
	effect_textures["burst"] = PitBoss.texture(PREMIUM_ASSETS+"slot_jackpot_burst.png")
	if OS.has_feature("web"):
		reduced_motion = bool(JavaScriptBridge.eval("window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches",true))
	timeline.reset(round,sponsored)

func on_presentation_cue(name: String) -> void:
	if name == "burst":
		if not reduced_motion and is_visible_in_tree() and not timeline.wins.is_empty(): particles.burst(timeline.wins,int(timeline.info.level))
	else:
		slot_audio.cue(name)

func _process(delta: float) -> void:
	if kind != "slots":
		super._process(delta)
		return
	if not is_visible_in_tree(): return
	idle_time += delta
	particles.advance(delta)
	var was_active := timeline.active
	timeline.advance(delta)
	if was_active and not timeline.active and sponsored: slot_audio.cue("free")
	spinning = maxf(0,timeline.finish_at-timeline.elapsed) if timeline.active else 0.0
	if timeline.revealed: last_win = float(timeline.info.credit)
	idle_redraw_elapsed += delta
	if was_active or timeline.active or idle_redraw_elapsed >= 0.05:
		idle_redraw_elapsed = 0.0
		queue_redraw()

func reset_slot_presentation(result: Dictionary, sponsor_funded: bool) -> void:
	sponsored = sponsor_funded
	timeline.reset(result,sponsored)
	particles.clear()
	spinning = 0
	last_win = float(result.get("credit",0))
	queue_redraw()

func begin_slot_reveal(previous_stops: Array = [3,11,18]) -> void:
	initial_stops = previous_stops.duplicate()
	particles.clear()
	timeline.start(round,sponsored)
	duration = timeline.finish_at
	spinning = duration
	queue_redraw()

func can_skip_slot_reveal() -> bool:
	return timeline.active and timeline.revealed

func skip_slot_reveal() -> bool:
	if not timeline.skip(): return false
	if sponsored: slot_audio.cue("free")
	particles.clear()
	spinning = 0
	last_win = float(timeline.info.credit)
	queue_redraw()
	return true

func slot_reveal_fraction() -> float:
	return timeline.balance_progress()

func art_region(asset: String, region: Rect2) -> Texture2D:
	var texture := AtlasTexture.new()
	texture.atlas = PitBoss.texture(PREMIUM_ASSETS+asset+".png")
	texture.region = region
	texture.filter_clip = true
	return texture

func slot_side_controls() -> bool:
	return size.x > size.y*1.5 and size.y < 500

func slot_portrait() -> bool:
	return not slot_side_controls() and size.x < size.y*0.9

func slot_rect() -> Rect2:
	var aspect := 0.78 if slot_portrait() else 1.35
	var deck := Vector2(clampf(size.x*0.26,210,248),0) if slot_side_controls() else Vector2(0,130)
	var width := maxf(0,minf(1120,minf(size.x-16-deck.x,(size.y-12-deck.y)*aspect)))
	var extent := Vector2(width,width/aspect)
	return Rect2((size-extent-deck)*0.5,extent)

func slot_deck_rect() -> Rect2:
	var rect := slot_rect()
	if slot_side_controls():
		return Rect2(Vector2(rect.end.x-8,rect.position.y+rect.size.y*0.16),Vector2(clampf(size.x*0.26,210,248)+8,rect.size.y*0.82))
	return Rect2(Vector2(rect.position.x+rect.size.x*0.05,rect.end.y-6),Vector2(rect.size.x*0.9,136))

func slot_spin_rect() -> Rect2:
	var rect := slot_rect()
	if slot_side_controls():
		var deck := slot_deck_rect()
		return Rect2(deck.position+Vector2(16,12),Vector2(deck.size.x-28,48))
	var extent := Vector2(rect.size.x*0.30,clampf(rect.size.y*0.105,44,72))
	return Rect2(rect.position+rect.size*Vector2(0.735,0.825)-extent*0.5,extent)

func slot_settings_rect() -> Rect2:
	var deck := slot_deck_rect()
	if slot_side_controls():
		return Rect2(deck.position+Vector2(16,68),Vector2(deck.size.x-28,maxf(0,deck.size.y-80)))
	return Rect2(deck.position+Vector2(10,9),deck.size-Vector2(20,16))

func draw_slots() -> void:
	var rect := slot_rect()
	if not rect.has_area(): return
	var tint := Color(machine_profile.get("color","685344")).lightened(0.28)
	var window := Rect2(rect.position+rect.size*Vector2(0.10,0.23),rect.size*Vector2(0.80,0.48))
	var cell := window.size/3.0
	var deck_skin := PitBoss.box(Color("10151b"),Color("977336"),8)
	deck_skin.set_corner_radius_all(12)
	draw_style_box(deck_skin,slot_deck_rect())
	draw_cabinet(rect)
	draw_reel_wells(window)
	draw_win_fx(window)
	draw_reel_symbols(window,cell)
	draw_reel_depth(window,cell)
	draw_particles(rect,window)
	draw_reel_glass(rect)
	draw_winning_lines(window,cell)
	draw_line_markers(window,cell)
	draw_marquee(rect,tint)
	draw_result_plate(rect)
	draw_meters(rect)

func draw_cabinet(rect: Rect2) -> void:
	var mode := "portrait" if slot_portrait() else "landscape"
	draw_texture_rect(PitBoss.texture(PREMIUM_ASSETS+"slot_cabinet_"+mode+"_base.png"),rect,false)
	var intensity := 0.10 if reduced_motion else 0.10+sin(idle_time*1.2)*0.04
	if timeline.active and not reduced_motion:
		intensity = 0.32+sin(timeline.elapsed*(8 if timeline.phase == State.Phase.ANTICIPATION else 3))*0.10
	var gem := rect.position+rect.size*Vector2(0.532,0.056 if slot_portrait() else 0.085)
	var extent := minf(rect.size.x*0.055,42)
	draw_texture_rect(effect_textures.sparkle,Rect2(gem-Vector2.ONE*extent/2,Vector2.ONE*extent),false,Color(1,1,1,intensity))

func draw_marquee(rect: Rect2, tint: Color) -> void:
	var title := str(machine_profile.get("name","PIT BOSS REELS")).to_upper()
	if timeline.active:
		if not timeline.revealed: title = "GOOD LUCK"
		elif int(timeline.info.level) == 6: title = "TOP AWARD"
		elif int(timeline.info.level) >= 4: title = str(timeline.info.category)
		elif timeline.info.positive: title = "NICE HIT"
		elif int(timeline.info.level) == 1: title = "LINE HIT"
	var fs := clampi(int(rect.size.y*0.035),12,26)
	var y := rect.position.y+(rect.size.y*0.10+fs+1 if slot_portrait() else maxf(rect.size.y*0.17,rect.size.y*0.14+fs+2))
	var subtitle := "FREE SPINS" if sponsored else "PIT BOSS / CLASSIC REELS"
	var subtitle_color := tint.lightened(0.42)
	var selected := timeline.line_index()
	if selected >= 0:
		var win: Dictionary = timeline.wins[selected]
		subtitle = "LINE %d / $%.2f RETURNED" % [int(win.index)+1,win.returned]
		subtitle_color = LINE_COLORS[int(win.index)]
	var subtitle_y := rect.position.y+rect.size.y*0.195 if slot_portrait() else y+maxf(12,rect.size.y*0.03)
	if subtitle_y > rect.position.y+rect.size.y*0.222:
		if selected >= 0: title = subtitle
		centered(Vector2(rect.get_center().x,y),title,11,subtitle_color if selected >= 0 else Color("fff1c9"))
	else:
		centered(Vector2(rect.get_center().x,y),title,fs,Color("fff1c9"))
		centered(Vector2(rect.get_center().x,subtitle_y),subtitle,11 if selected >= 0 else clampi(fs-9,9,13),subtitle_color)

func draw_reel_glass(rect: Rect2) -> void:
	var mode := "portrait" if slot_portrait() else "landscape"
	var texture := PitBoss.texture(PREMIUM_ASSETS+"slot_cabinet_"+mode+"_glass.png")
	# Exclude baked decorative dots: runtime markers represent the actual selected lines.
	draw_texture_rect_region(texture,Rect2(rect.position+rect.size*Vector2(0.09,0.22),rect.size*Vector2(0.82,0.50)),Rect2(texture.get_size()*Vector2(0.09,0.22),texture.get_size()*Vector2(0.82,0.50)))

func draw_win_fx(window: Rect2) -> void:
	if reduced_motion or not timeline.active or not timeline.revealed or int(timeline.info.level) < 4: return
	var age := timeline.elapsed-timeline.count_at
	if age < 0.0 or age > 1.15: return
	var alpha := clampf(age/0.18,0.0,1.0)*(1.0-smoothstep(0.6,1.15,age))
	var diameter := minf(window.size.x*0.75,window.size.y*0.95)
	draw_texture_rect(effect_textures.burst,Rect2(window.get_center()-Vector2.ONE*diameter/2,Vector2.ONE*diameter),false,Color(1,1,1,alpha*0.32))

func draw_reel_wells(window: Rect2) -> void:
	# The artwork supplies the bezel and dividers; avoid a second drawn border.
	draw_rect(window,Color("e9e1d0"))
	draw_rect(Rect2(window.position+Vector2(0,window.size.y/3),Vector2(window.size.x,window.size.y/3)),Color("fff9eb"))

func draw_winning_lines(window: Rect2, cell: Vector2) -> void:
	var selected := timeline.line_index()
	if selected < 0 and not timeline.all_lines(): return
	for i in range(timeline.wins.size()):
		if selected >= 0 and i != selected: continue
		var win: Dictionary = timeline.wins[i]
		var age := timeline.elapsed-timeline.reveal_at-i*State.LINE_SECONDS
		var pulse := 1+sin(age*TAU*4)*0.12*exp(-maxf(0,age)*3)
		draw_neon_line(window,cell,int(win.index),timeline.line_progress(i),pulse)

func draw_neon_line(window: Rect2, cell: Vector2, index: int, progress: float, pulse: float) -> void:
	var path: Array = CasinoTuning.SLOT_LINES[index]
	var color: Color = LINE_COLORS[index]
	var core := clampf(cell.y*0.025,1.5,3)
	var start := window.position+Vector2(0.5,path[0]+0.5)*cell
	for col in range(2):
		var target := window.position+Vector2(col+1.5,path[col+1]+0.5)*cell
		var portion := clampf(progress*2-col,0,1)
		if portion > 0:
			var end := start.lerp(target,portion)
			for layer in range(3):
				var thickness := core*(4.5 if layer == 0 else 2.3 if layer == 1 else 1.0)
				var glow := Color(color,0.11*pulse if layer == 0 else 0.28*pulse if layer == 1 else 0.9)
				draw_line(start,end,glow,thickness,true)
				draw_circle(start,thickness/2,glow)
				draw_circle(end,thickness/2,glow)
			draw_line(start,end,Color(color.lightened(0.6),0.9),core*0.42,true)
		start = target
	if progress > 0 and progress < 1:
		var segment := mini(1,floori(progress*2))
		var a := window.position+Vector2(segment+0.5,path[segment]+0.5)*cell
		var b := window.position+Vector2(segment+1.5,path[segment+1]+0.5)*cell
		var tracer := a.lerp(b,progress*2-segment)
		draw_circle(tracer,core*2,Color(color,0.22))
		draw_circle(tracer,core*0.85,Color("fffbe4"))

func reel_offset(col: int, cell_height: float) -> float:
	if not timeline.active: return 0.0
	var end_time := float(timeline.ends[col])
	var p := clampf(timeline.elapsed/end_time,0.0,1.0)
	# Continuous velocity across acceleration, cruise and braking; exact final stop.
	const SPEED := 1.0/0.75
	var travel := 0.0
	if p < 0.16:
		travel = SPEED*p*p/(2.0*0.16)
	elif p < 0.66:
		travel = SPEED*(0.08+p-0.16)
	else:
		var brake := p-0.66
		travel = SPEED*(0.58+brake-brake*brake/(2.0*0.34))
	var target := int(round.stops[col])
	var distance: float = float(initial_stops[col])-machine_profile.get("reel",CasinoTuning.SLOT_REEL).size()*3.0-target
	if p < 1.0: return distance*(1.0-travel)
	var age := timeline.elapsed-end_time
	if age >= State.SNAP_SECONDS or reduced_motion: return 0.0
	return sin(age/State.SNAP_SECONDS*TAU)*(2.0+col)*exp(-age*12.0)/maxf(1.0,cell_height)

func draw_reel_symbols(window: Rect2, cell: Vector2) -> void:
	var stops: Array = round.get("stops",[3,11,18])
	var reel: Array = machine_profile.get("reel",CasinoTuning.SLOT_REEL)
	var highlighting := timeline.line_index() >= 0 or timeline.all_lines()
	for col in range(3):
		var column := Rect2(window.position+Vector2(col*cell.x+2,0),Vector2(cell.x-4,window.size.y))
		var moving := timeline.active and timeline.elapsed < float(timeline.ends[col])+State.SNAP_SECONDS
		var position_value := float(stops[col])+(reel_offset(col,cell.y) if timeline.active else 0.0)
		var whole := floori(position_value)
		var fraction := position_value-whole
		for strip_row in range(-2,3):
			var symbol := int(reel[posmod(whole+strip_row,reel.size())])
			var row := strip_row+1
			var age := timeline.symbol_age(row,col) if not moving and row in range(3) else -1.0
			var extent := minf(cell.x*0.76,cell.y*0.76)
			var at := Vector2(column.get_center().x,window.position.y+(strip_row+1.5-fraction)*cell.y)
			var scale_value := 1.0
			if age >= 0:
				scale_value = symbol_scale(age)
				if not reduced_motion and row == 1: at.y -= sin(minf(1,age/0.22)*PI)*minf(5,cell.y*0.06)
				draw_symbol_halo(at,extent,LINE_COLORS[int(timeline.wins[maxi(0,timeline.line_index())].index)],age)
			var brightness := 0.65 if highlighting and age < 0 else 1.0
			if age >= 0: brightness = 1.0+maxf(0,1-age/0.20)*0.18
			var texture_size := slot_textures[symbol].get_size()
			var symbol_size := texture_size*(extent*scale_value/maxf(texture_size.x,texture_size.y))
			if not moving:
				# The painted glass masks the outer 4.5% at each end of the well.
				# Keep edge-row highlights inside that opening, including their pop.
				var clearance := 2*minf(at.y-window.position.y-window.size.y*0.045,window.end.y-window.size.y*0.045-at.y)
				symbol_size *= minf(1.0,maxf(0,clearance)/symbol_size.y)
			var symbol_rect := Rect2(at-symbol_size/2,symbol_size)
			clipped_symbol(symbol,symbol_rect,column,Color(brightness,brightness,brightness,0.84 if moving else 1))
			if moving and not reduced_motion and timeline.elapsed < float(timeline.ends[col])-0.12:
				for trail in range(1,3):
					clipped_symbol(symbol,Rect2(symbol_rect.position+Vector2(0,cell.y*0.09*trail),symbol_rect.size),column,Color(1,1,1,0.10/float(trail)))
		var impact_age := timeline.elapsed-float(timeline.ends[col])
		if timeline.active and not reduced_motion and impact_age >= 0 and impact_age < 0.18:
			var strength := 1.0-impact_age/0.18
			var flash_size: Vector2 = effect_textures.stop.get_size()*(cell.x*0.9/155.0)
			draw_texture_rect(effect_textures.stop,Rect2(column.get_center()-flash_size/2,flash_size),false,Color(1,1,1,0.28*strength))

func symbol_scale(age: float) -> float:
	if reduced_motion: return 1.04
	if age < 0.08: return lerpf(1.0,1.15,age/0.08)
	if age < 0.22: return lerpf(1.15,1.04,1-pow(1-(age-0.08)/0.14,3))
	return 1.04

func draw_symbol_halo(at: Vector2, extent: float, color: Color, age: float) -> void:
	# The supplied glow sheet contains a baked heading and a cut-off ring.
	# Use a clean procedural halo rather than displaying those atlas artifacts.
	var strength := 0.16+0.10*exp(-age*5.0)
	draw_circle(at,extent*0.55,Color(color,strength))
	draw_arc(at,extent*0.53,0,TAU,40,Color(color,0.55),1.5,true)

func clipped_symbol(symbol: int, rect: Rect2, column: Rect2, modulate: Color) -> void:
	var visible_rect := rect.intersection(column)
	if not visible_rect.has_area(): return
	var texture: Texture2D = slot_textures[symbol]
	var source := Rect2((visible_rect.position-rect.position)/rect.size*Vector2(texture.get_size()),visible_rect.size/rect.size*Vector2(texture.get_size()))
	draw_texture_rect_region(texture,visible_rect,source,modulate)

func draw_reel_depth(window: Rect2, cell: Vector2) -> void:
	for col in range(3):
		var well := Rect2(window.position+Vector2(col*cell.x+2,0),Vector2(cell.x-4,window.size.y))
		for step in range(8):
			var shade := 0.20*pow(1-step/8.0,2)
			var height := cell.y*0.035
			draw_rect(Rect2(well.position+Vector2(0,step*height),Vector2(well.size.x,height)),Color(0.12,0.10,0.07,shade))
			draw_rect(Rect2(Vector2(well.position.x,well.end.y-(step+1)*height),Vector2(well.size.x,height)),Color(0.12,0.10,0.07,shade))

func draw_line_markers(window: Rect2, cell: Vector2) -> void:
	var active_count := int(round.get("active_lines",slot_lines)) if timeline.active else slot_lines
	var selected := timeline.line_index()
	for index in range(active_count):
		var path: Array = CasinoTuning.SLOT_LINES[index]
		var selected_line: bool = selected >= 0 and int(timeline.wins[selected].index) == index
		var color := Color(LINE_COLORS[index],0.95 if selected_line else 0.50)
		for side in range(2):
			var row := int(path[0 if side == 0 else 2])
			var y := window.position.y+(row+0.5)*cell.y
			# Separate same-row markers: center=1, top=2/4, bottom=3/5.
			if index in [1,2]: y -= minf(9,cell.y*0.14)
			if index in [3,4]: y += minf(9,cell.y*0.14)
			var x := window.position.x-cell.x*0.13 if side == 0 else window.end.x+cell.x*0.13
			draw_circle(Vector2(x,y),3.5 if selected_line else 2.5,color)
			centered(Vector2(x+(-8 if side == 0 else 8),y+3),str(index+1),10,color)

func draw_result_plate(rect: Rect2) -> void:
	# Use the lower panel already painted into the cabinet. Spin occupies its right side.
	var area := Rect2(rect.position+rect.size*Vector2(0.12,0.765),rect.size*Vector2(0.76 if slot_side_controls() else 0.42,0.13))
	var color := GOLD if timeline.info.get("positive",false) else Color("dfd6c4")
	if not status_message.is_empty():
		var headline := "PAUSED" if status_message == "PAUSED" else "WAGER UNAVAILABLE"
		var detail := "RESUME TO PLAY" if status_message == "PAUSED" else "CHECK WALLET / LIMITS"
		fit_text(Rect2(area.position,Vector2(area.size.x,area.size.y*0.55)),headline,13,color)
		fit_text(Rect2(area.position+Vector2(0,area.size.y*0.55),Vector2(area.size.x,area.size.y*0.45)),detail,10,color)
		return
	if not timeline.revealed:
		fit_text(area,"REELS IN MOTION" if timeline.active else "READY TO SPIN",14,color)
		return
	var info: Dictionary = timeline.info
	var shown := float(info.credit)*(1-pow(1-timeline.count_progress(),3))
	var detail := "CASINO CASH +$%.2f" % info.credit if sponsored and info.positive else "NO STAKE CHARGED" if sponsored else "NET %s$%.2f" % ["+" if info.net > 0 else "-" if info.net < 0 else "",absf(float(info.net))]
	if area.size.y < 52:
		fit_text(Rect2(area.position,Vector2(area.size.x,area.size.y*0.55)),"%s / $%.2f" % [info.category,shown],14,color)
		fit_text(Rect2(area.position+Vector2(0,area.size.y*0.55),Vector2(area.size.x,area.size.y*0.45)),"RETURNED / "+detail,11,color)
	else:
		fit_text(Rect2(area.position,Vector2(area.size.x,area.size.y*0.28)),str(info.category),14,color)
		fit_text(Rect2(area.position+Vector2(0,area.size.y*0.28),Vector2(area.size.x,area.size.y*0.43)),"$%.2f RETURNED" % shown,24,color)
		fit_text(Rect2(area.position+Vector2(0,area.size.y*0.73),Vector2(area.size.x,area.size.y*0.27)),detail,12,color)

func fit_text(area: Rect2, value: String, desired_size: int, color: Color) -> void:
	var fs := mini(desired_size,maxi(9,int(area.size.y*0.8)))
	while fs > 9 and font.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x > area.size.x: fs -= 1
	centered(area.get_center()+Vector2(0,(font.get_ascent(fs)-font.get_descent(fs))*0.5),value,fs,color)

func draw_meters(rect: Rect2) -> void:
	var y := rect.end.y-rect.size.y*0.028
	var fs := clampi(int(rect.size.y*0.030),11,19)
	centered(Vector2(rect.position.x+rect.size.x*0.20,y),"%d FREE LEFT" % free_remaining if sponsored else "BET $%.2f" % wager,fs)
	centered(Vector2(rect.get_center().x,y),"LINES %d" % slot_lines,fs)
	centered(Vector2(rect.position.x+rect.size.x*0.80,y),"LAST $%.2f" % last_win,fs)

func draw_particles(rect: Rect2, window: Rect2) -> void:
	if not timeline.active or reduced_motion: return
	for i in range(particles.count):
		if particles.ages[i] >= particles.lifetimes[i]: continue
		var alpha := 1.0-particles.ages[i]/particles.lifetimes[i]
		var at := rect.position+particles.positions[i]*rect.size
		var diameter := clampf(rect.size.y*0.025,7,18)
		var texture: Texture2D = effect_textures.coin if particles.shapes[i] == 1 else effect_textures.sparkle
		var extent := texture.get_size()*(diameter/maxf(texture.get_width(),texture.get_height()))
		var target := Rect2(at-extent/2,extent)
		var visible := target.intersection(window)
		if not visible.has_area(): continue
		var source := Rect2((visible.position-target.position)/target.size*texture.get_size(),visible.size/target.size*texture.get_size())
		draw_texture_rect_region(texture,visible,source,Color(1,1,1,alpha*0.8))
