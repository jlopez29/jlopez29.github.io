extends "res://scripts/game_art.gd"
## Presentation over committed stops. Drawing never generates or settles outcomes.
const SlotAudio = preload("res://scripts/slot_audio.gd")
const State = preload("res://scripts/slot_presentation_state.gd")
const Result = preload("res://scripts/slot_result.gd")
const Particles = preload("res://scripts/slot_particles.gd")
const SYMBOL_ASSETS := ["cherry","lemon","bell","bar","seven"]
const LINE_COLORS := [Color("ffd879"),Color("79d7ed"),Color("9fe8ad"),Color("df9cec"),Color("ffa685")]
var machine_profile := {}
var wager := 10.0
var sponsored := false
var reduced_motion := false
var slot_audio: Node
var timeline := State.new()
var particles := Particles.new()
var idle_time := 0.0
var initial_stops := [3,11,18]
var slot_lines := 1
var free_remaining := -1
var last_win := 0.0
var slot_textures: Array[Texture2D] = []
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
	for asset in SYMBOL_ASSETS: slot_textures.append(PitBoss.texture("casino_play/slots/symbols/"+asset+".svg"))
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

func slot_rect() -> Rect2:
	var width := minf(minf(size.x-16,(size.y-12)*1.70),1120)
	var height := minf(size.y-12,width/(0.78 if size.x < size.y*0.9 else 1.35))
	return Rect2((size-Vector2(width,height))/2,Vector2(width,height))

func draw_slots() -> void:
	var rect := slot_rect()
	if not rect.has_area(): return
	var tint := Color(machine_profile.get("color","685344")).lightened(0.28)
	var window := Rect2(rect.position+rect.size*Vector2(0.10,0.23),rect.size*Vector2(0.80,0.48))
	window.size.y -= maxf(0,24-rect.size.y*0.023)
	var cell := window.size/3
	apply_cabinet_impulse(rect)
	draw_cabinet(rect,tint)
	draw_marquee(rect,tint)
	draw_reel_wells(window,tint)
	draw_winning_lines(window,cell)
	draw_reel_symbols(window,cell,tint)
	draw_reel_depth(window,cell)
	draw_line_markers(window,cell)
	draw_result_plate(rect,window)
	draw_meters(rect)
	draw_particles(rect)
	draw_set_transform(Vector2.ZERO)

func apply_cabinet_impulse(rect: Rect2) -> void:
	var shake := Vector2.ZERO
	var scale_value := 1.0
	if timeline.active and not reduced_motion:
		if timeline.elapsed < 0.16: scale_value -= sin(timeline.elapsed/0.16*PI)*0.009
		for col in range(3):
			var age := timeline.elapsed-float(timeline.ends[col])
			if age >= 0 and age < 0.16: shake.y += sin(age/0.16*TAU)*(0.7+col*0.3)*(1-age/0.16)
		var count_age := timeline.elapsed-timeline.count_at
		if timeline.strong_result() and count_age >= 0 and count_age < 0.20:
			var magnitude := 4.0 if int(timeline.info.level) == 6 else 2.5
			shake += (Vector2(sin(count_age*95),sin(count_age*71))*magnitude).limit_length(magnitude)*(1-count_age/0.20)
	draw_set_transform(rect.get_center()*(1-scale_value)+shake,0,Vector2.ONE*scale_value)

func draw_cabinet(rect: Rect2, tint: Color) -> void:
	panel(rect,Color("13171c"))
	image("slots/slot_cabinet_frame.svg",rect)
	var state := timeline.cabinet_state()
	var intensity := 0.32+sin(idle_time*1.2)*0.03
	if state == "SPINNING": intensity = 0.58
	elif state == "ANTICIPATION": intensity = 0.72+sin(timeline.elapsed*12)*0.15
	elif timeline.active and timeline.revealed: intensity = 0.65 if timeline.info.positive else 0.48
	var trim := GOLD if timeline.revealed and timeline.active else tint
	draw_rect(rect.grow(-3),Color(trim,intensity),false,3)
	if timeline.active and timeline.revealed:
		var age := timeline.elapsed-timeline.reveal_at
		var warm_pulse := sin(minf(1,age/0.35)*PI)*0.18
		draw_rect(rect.grow(-5),Color(trim,warm_pulse),false,8)
		if timeline.info.positive: draw_trim_chase(rect,age,int(timeline.info.level))

func draw_trim_chase(rect: Rect2, age: float, level: int) -> void:
	var perimeter := 2*(rect.size.x+rect.size.y)
	var speed := 1.3 if level < 4 else 2.3
	var envelope := clampf(1-age/(1.0 if level < 4 else 2.0),0,1)
	for i in range(32):
		var distance := fmod(i*perimeter/32,perimeter)
		var at := rect.position
		if distance < rect.size.x: at += Vector2(distance,0)
		elif distance < rect.size.x+rect.size.y: at += Vector2(rect.size.x,distance-rect.size.x)
		elif distance < rect.size.x*2+rect.size.y: at += Vector2(rect.size.x*2+rect.size.y-distance,rect.size.y)
		else: at += Vector2(0,perimeter-distance)
		var wave := pow(maxf(0,sin(i*0.42-age*TAU*speed)),6)
		draw_circle(at,2.5 if level < 4 else 4,Color(GOLD,(0.2+wave*0.8)*envelope))

func draw_marquee(rect: Rect2, tint: Color) -> void:
	var marquee := Rect2(rect.position+rect.size*Vector2(0.04,0.02),rect.size*Vector2(0.92,0.16))
	var title := str(machine_profile.get("name","PIT BOSS REELS")).to_upper()
	if timeline.active:
		if not timeline.revealed: title = "GOOD LUCK"
		elif int(timeline.info.level) == 6: title = "TOP AWARD"
		elif int(timeline.info.level) >= 4: title = str(timeline.info.category)
		elif timeline.info.positive: title = "NICE HIT"
		elif int(timeline.info.level) == 1: title = "LINE HIT"
	var pulse := 0.07+sin(idle_time*1.2)*0.02
	if timeline.active: pulse = 0.18+sin(timeline.elapsed*(12 if timeline.phase == State.Phase.ANTICIPATION else 4))*0.06
	panel(marquee,tint.darkened(0.72))
	draw_rect(marquee.grow(2),Color(GOLD if timeline.strong_result() else tint,pulse),false,5)
	var fs := clampi(int(rect.size.y*0.048),14,32)
	centered(marquee.get_center()+Vector2(0,fs*0.15),title,fs,Color("fff0ce"))
	centered(Vector2(rect.get_center().x,marquee.end.y-5),"FREE SPINS" if sponsored else "PIT BOSS / CLASSIC REELS",clampi(fs-10,10,15),tint.lightened(0.4))

func draw_reel_wells(window: Rect2, tint: Color) -> void:
	panel(window.grow(7),tint.darkened(0.4))
	var column_width := window.size.x/3
	for col in range(3):
		var well := Rect2(window.position+Vector2(col*column_width+2,0),Vector2(column_width-4,window.size.y))
		draw_rect(well,Color("e8dfce"))
		draw_rect(Rect2(well.position+Vector2(0,well.size.y*0.33),Vector2(well.size.x,well.size.y*0.34)),Color("fff9e9"))
		draw_rect(well,Color("5b5144"),false,2)

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
	var core := clampf(cell.y*0.065,4,7)
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
	var p := clampf(timeline.elapsed/end_time,0,1)
	var eased := p*p*p*(p*(p*6-15)+10)
	var target := int(round.stops[col])
	var distance: float = float(initial_stops[col])-machine_profile.get("reel",CasinoTuning.SLOT_REEL).size()*3.0-target
	if p < 1: return distance*(1-eased)
	var age := timeline.elapsed-end_time
	if age >= State.SNAP_SECONDS or reduced_motion: return 0.0
	# A 2-4 logical pixel overshoot, then a smaller counter-bounce.
	return sin(age/State.SNAP_SECONDS*TAU)*(2.0+col)*exp(-age*12)/maxf(1,cell_height)

func draw_reel_symbols(window: Rect2, cell: Vector2, tint: Color) -> void:
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
			var extent := minf(cell.x*0.80,cell.y*0.80)
			var at := Vector2(column.get_center().x,window.position.y+(strip_row+1.5-fraction)*cell.y)
			var scale_value := 1.0
			if age >= 0:
				scale_value = symbol_scale(age)
				if not reduced_motion: at.y -= sin(minf(1,age/0.22)*PI)*minf(5,cell.y*0.06)
				draw_symbol_halo(at,extent,LINE_COLORS[int(timeline.wins[maxi(0,timeline.line_index())].index)],age)
			var brightness := 0.65 if highlighting and age < 0 else 1.0
			if age >= 0: brightness = 1.0+maxf(0,1-age/0.20)*0.18
			var symbol_rect := Rect2(at-Vector2.ONE*extent*scale_value/2,Vector2.ONE*extent*scale_value)
			clipped_symbol(symbol,symbol_rect,column,Color(brightness,brightness,brightness,0.84 if moving else 1))
			if moving and timeline.elapsed < float(timeline.ends[col])-0.12:
				clipped_symbol(symbol,Rect2(symbol_rect.position+Vector2(0,cell.y*0.12),symbol_rect.size),column,Color(1,1,1,0.14))
		var impact_age := timeline.elapsed-float(timeline.ends[col])
		if timeline.active and impact_age >= 0 and impact_age < 0.18:
			draw_rect(column,Color(tint,0.18*(1-impact_age/0.18)))

func symbol_scale(age: float) -> float:
	if reduced_motion: return 1.04
	if age < 0.08: return lerpf(1.0,1.15,age/0.08)
	if age < 0.22: return lerpf(1.15,1.04,1-pow(1-(age-0.08)/0.14,3))
	return 1.04

func draw_symbol_halo(at: Vector2, extent: float, color: Color, age: float) -> void:
	var strength := 0.20+0.12*exp(-age*5)
	draw_circle(at,extent*0.65,Color(color,strength*0.30))
	draw_circle(at,extent*0.53,Color(color,strength))
	draw_arc(at,extent*0.54,0,TAU,40,Color(color,0.50),2,true)

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
			if index in [1,2]: y -= 9
			if index in [3,4]: y += 9
			var x := window.position.x-12 if side == 0 else window.end.x+12
			draw_circle(Vector2(x,y),3.5 if selected_line else 2.5,color)
			centered(Vector2(x+(-10 if side == 0 else 10),y+4),str(index+1),11,color)

func draw_result_plate(rect: Rect2, window: Rect2) -> void:
	var center := rect.position+rect.size*Vector2(0.5,0.815)
	if not timeline.revealed:
		centered(center,"REELS IN MOTION" if timeline.active else "PRESS SPIN",clampi(int(rect.size.y*0.028),12,20),GOLD)
		return
	var info: Dictionary = timeline.info
	var age := timeline.elapsed-timeline.count_at
	var pop := 1.0
	if timeline.active and age >= 0 and not reduced_motion:
		pop = lerpf(0.86,1.12,age/0.10) if age < 0.10 else lerpf(1.12,1.0,clampf((age-0.10)/0.14,0,1))
	var strong := int(info.level) >= 4 and timeline.active
	var color := Color("ffd879") if info.positive else Color("e6c888") if int(info.level) == 1 else Color("c7bdb0")
	var fs := clampi(int(rect.size.y*0.027*pop),12,22)
	var amount_fs := clampi(int(rect.size.y*(0.060 if strong else 0.047)*pop),20,46 if strong else 34)
	var display_fs := amount_fs if info.positive else clampi(amount_fs-5,15,28)
	var detail_fs := clampi(fs-3,10,16)
	var plate_size := Vector2(rect.size.x*0.78*pop,maxf(rect.size.y*0.164*pop,fs+display_fs+detail_fs+14))
	var plate := Rect2(center-plate_size/2,plate_size)
	panel(plate,Color("14191e") if strong else Color("151719"))
	draw_rect(plate,Color(color,0.8 if strong else 0.35),false,3 if strong else 1)
	var title := "WIN" if info.category == "SMALL WIN" else str(info.category)
	centered(Vector2(center.x,plate.position.y+fs+3),title,fs,color)
	var shown := float(info.credit)*(1-pow(1-timeline.count_progress(),3))
	if not info.positive:
		centered(Vector2(center.x,plate.position.y+fs+display_fs+6),"$%.2f RETURNED" % shown,display_fs,color)
	else:
		centered(Vector2(center.x,plate.position.y+fs+display_fs+6),"$%.2f" % shown,amount_fs,color)
	var detail := "CASINO CASH +$%.2f" % info.credit if sponsored and info.positive else "NO STAKE CHARGED" if sponsored else "NET %s$%.2f" % ["+" if info.net > 0 else "-" if info.net < 0 else "",absf(float(info.net))]
	if info.positive and not sponsored: detail = "RETURNED / "+detail
	centered(Vector2(center.x,plate.end.y-5),detail,detail_fs,color)
	var selected := timeline.line_index()
	if selected >= 0:
		var win: Dictionary = timeline.wins[selected]
		centered(Vector2(rect.get_center().x,window.end.y+15),"LINE %d / $%.2f RETURNED" % [int(win.index)+1,win.returned],12,LINE_COLORS[int(win.index)])

func draw_meters(rect: Rect2) -> void:
	var y := rect.end.y-rect.size.y*0.028
	var fs := clampi(int(rect.size.y*0.030),11,19)
	centered(Vector2(rect.position.x+rect.size.x*0.20,y),"%d FREE LEFT" % free_remaining if sponsored else "BET $%.2f" % wager,fs)
	centered(Vector2(rect.get_center().x,y),"LINES %d" % slot_lines,fs)
	centered(Vector2(rect.position.x+rect.size.x*0.80,y),"LAST $%.2f" % last_win,fs)

func draw_particles(rect: Rect2) -> void:
	if not timeline.active or reduced_motion: return
	for i in range(particles.count):
		if particles.ages[i] >= particles.lifetimes[i]: continue
		var alpha := 1-particles.ages[i]/particles.lifetimes[i]
		var at := rect.position+particles.positions[i]*rect.size
		var extent := clampf(rect.size.y*0.006,2,4)
		var color := Color(LINE_COLORS[i%5] if particles.shapes[i] == 2 else GOLD,alpha)
		if particles.shapes[i] == 2:
			draw_line(at,at+Vector2(sin(i+particles.ages[i]*7),cos(i+particles.ages[i]*7))*extent*2,color,extent,true)
		elif particles.shapes[i] == 1:
			draw_circle(at,extent*1.3,color)
			draw_arc(at,extent,0,TAU,12,Color("fff4cb",alpha),1)
		else:
			draw_line(at-Vector2(extent,0),at+Vector2(extent,0),color,1.5,true)
			draw_line(at-Vector2(0,extent),at+Vector2(0,extent),color,1.5,true)
