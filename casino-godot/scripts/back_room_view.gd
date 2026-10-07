extends PanelContainer
signal leave_requested
signal changed
const ThemeStyle = preload("res://scripts/pit_boss_theme.gd")
const Games = preload("res://scripts/casino_games.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
const Craps = preload("res://scripts/craps.gd")
var sim: CasinoSimulation
var page := "lobby"
var content: VBoxContainer
var body_scroll: ScrollContainer
var metrics: BoxContainer
var brand_label: Label
var disclosure: Label
var surface_holder: MarginContainer
var wallet: Label
var cash: Label
var timer: Label
var message: Label
var body: VBoxContainer
var surface: Control
var numeric: SpinBox
var trips: SpinBox
var lines := 5
var sequence := 0
var revision: Array = []
var poll := 0.0
var ticket_labels := {}
var retry_labels := {}
var controls: BoxContainer
var form: VBoxContainer
var selected_key := ""
var error := ""
var expanded_contract := ""
var work_min: Label
var timer_claim: Button
var work_claim: Button

func _ready() -> void:
	add_theme_stylebox_override("panel",ThemeStyle.box(Color("281720"),ThemeStyle.GOLD,12))
	content = VBoxContainer.new()
	content.size_flags_horizontal = SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",6)
	add_child(content)
	brand_label = label(content,"THE BACK ROOM | PRIVATE CLUB",22)
	metrics = BoxContainer.new()
	metrics.vertical = true
	metrics.add_theme_constant_override("separation",8)
	content.add_child(metrics)
	wallet = label(metrics,"",22)
	cash = label(metrics,"",15)
	disclosure = label(content,"Net winnings become Casino Cash; losses spend your personal wallet.",14)
	var nav := preload("res://scripts/responsive_grid.gd").new()
	nav.maximum_columns = 3
	content.add_child(nav)
	button(nav,"Game lobby",func(): page="lobby"; rebuild())
	button(nav,"Wallet recovery",func(): page="recovery"; rebuild())
	button(nav,"Return to floor",func(): leave_requested.emit())
	timer = label(content,"",15)
	message = label(content,"",15)
	body = VBoxContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",10)
	body_scroll = ScrollContainer.new()
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = SIZE_EXPAND_FILL
	content.add_child(body_scroll)
	body_scroll.add_child(body)
	resized.connect(reflow)

func label(parent: Node, text: String, size_value: int = 16) -> Label:
	var node := Label.new()
	node.text = text
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	node.add_theme_font_size_override("font_size",size_value)
	parent.add_child(node)
	return node

func button(parent: Node, text: String, action: Callable, disabled: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.clip_text = true
	node.custom_minimum_size.y = 48
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	node.disabled = disabled
	node.pressed.connect(action)
	parent.add_child(node)
	if OS.is_debug_build(): node.add_to_group("debug_buttons")
	return node

func amount(parent: Node, title: String, value: float = 1) -> SpinBox:
	label(parent,title,14)
	var node := SpinBox.new()
	node.min_value = 0.01
	node.max_value = CasinoTuning.OWNER_MONEY_LIMIT
	node.step = 0.01
	node.value = value
	node.prefix = "$"
	node.custom_minimum_size.y = 48
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	parent.add_child(node)
	return node

func open() -> void:
	show()
	page = "game" if sim.back_room.busy() else "lobby"
	error = ""
	rebuild()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null: return
	poll += delta
	if poll < 0.2: return
	poll = 0
	var key := [sim,sim.back_room.state.sequence,sim.recovery.state.cycle_id,sim.recovery.successes()]
	if key != revision: rebuild()
	update_values()

static func countdown(seconds: int) -> String:
	return "%02d:%02d" % [maxi(0,seconds)/60,maxi(0,seconds)%60]

func update_values() -> void:
	wallet.text = "PERSONAL WALLET $%.2f" % sim.owner_bankroll
	cash.text = "Casino Cash $%.2f" % sim.cash
	var exposure := 0.0
	for stake in sim.owner_account.pending.values(): exposure += float(stake)
	var r: Dictionary = sim.recovery.state
	timer.text = "%s support | Next guaranteed top-up: %s | Active exposure $%.2f" % [Recovery.stage(sim.casino_rating,int(r.completed)),countdown(int(r.next_time_utc)-sim.recovery.now()),exposure]
	message.text = error
	message.visible = not error.is_empty()
	if is_instance_valid(work_min): work_min.text = "Three verified contracts unlock recovery after the 10-minute real-time minimum. Minimum remaining: " + countdown(int(r.last_full_utc)+CasinoTuning.RECOVERY_WORK_MIN_SECONDS-sim.recovery.now())
	if is_instance_valid(timer_claim): timer_claim.disabled = not sim.recovery.can_refill(sim) or sim.recovery.now()<int(r.next_time_utc)
	if is_instance_valid(work_claim): work_claim.disabled = not sim.recovery.can_refill(sim) or sim.recovery.successes()!=3 or sim.recovery.now()<int(r.last_full_utc)+CasinoTuning.RECOVERY_WORK_MIN_SECONDS
	for t in r.tickets:
		if ticket_labels.has(t.id): ticket_labels[t.id].text = "Ticket %s | %s" % [t.id,"Granted $%.2f (card maximum $%.2f)" % [t.granted,t.award] if t.claimed else "Drawing in "+countdown(int(t.draw_utc)-sim.recovery.now()) if t.kind == "raffle" else "Free earned card. Scratch or use Reveal."]
	for c in r.contracts:
		if retry_labels.has(c.id): retry_labels[c.id].text = str(c.feedback) + (" Retry in " + countdown(int(c.retry_utc)-sim.recovery.now()) if sim.recovery.now() < int(c.retry_utc) else "")

func rebuild() -> void:
	if not is_node_ready() or sim == null: return
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	surface = null; surface_holder=null; controls = null
	ticket_labels.clear(); retry_labels.clear()
	work_min=null; timer_claim=null; work_claim=null
	sequence = int(sim.back_room.state.sequence)
	revision = [sim,sequence,sim.recovery.state.cycle_id,sim.recovery.successes()]
	match page:
		"lobby": lobby()
		"game": game()
		"recovery": recovery_panel()
	reflow()
	update_values()

func lobby() -> void:
	label(body,"Five games, available from day one. Public casino unlocks are unchanged.")
	if sim.back_room.busy():
		button(body,"Resume committed "+str(sim.back_room.state.kind),func(): page="game"; rebuild())
		label(body,"Finish committed hands/contracts before choosing another game or claiming recovery.")
	var grid := preload("res://scripts/responsive_grid.gd").new()
	grid.maximum_columns = 3
	body.add_child(grid)
	for kind in ["slots","blackjack","craps","roulette","holdem"]:
		button(grid,{"slots":"Slots","holdem":"Ultimate Hold'em"}.get(kind,kind.capitalize()),func():
			if transact("choose",{"kind":kind}): page="game"; selected_key=""; rebuild(),sim.back_room.busy())
	if sim.owner_bankroll < 0.01: label(body,"No spendable funds. Manage your casino or complete recovery work; no credit wagers.")
	button(body,"Owner wallet ledger",ledger)

func transact(action: String, args: Dictionary = {}) -> bool:
	if is_instance_valid(surface) and surface.spinning > 0: return false
	var ok := sim.private_action(sequence,action,args)
	error = "" if ok else "Action unavailable: check funds, game rules and local save storage. Hold'em requires 6x ante + Trips before dealing."
	if not ok and sim.back_room.state.kind=="holdem":
		var extra := float(args.get("trips",0))
		error += " Largest financeable ante: $%.2f." % (floor(maxf(0,sim.owner_bankroll-extra)/6*100)/100)
	if ok: changed.emit()
	return ok

func game() -> void:
	var s: Dictionary = sim.back_room.state
	var kind := str(s.kind)
	label(body,"Back Room / "+kind.capitalize(),18)
	controls = BoxContainer.new()
	controls.vertical = true
	controls.add_theme_constant_override("separation",12)
	body.add_child(controls)
	if kind != "craps":
		surface = preload("res://scripts/casino_surface.gd").new()
		surface.size_flags_horizontal = SIZE_EXPAND_FILL
		surface.custom_minimum_size = Vector2(0,360)
		surface.kind = kind; surface.round = s.round.duplicate(true)
		surface.machine_profile = CasinoTuning.slot_profile("starter")
		surface.slot_lines = lines
		surface.pending = not s.round.is_empty() and s.round.get("phase") != "done"
		surface_holder = MarginContainer.new()
		surface_holder.size_flags_horizontal=SIZE_EXPAND_FILL
		surface_holder.size_flags_vertical=SIZE_SHRINK_BEGIN
		surface_holder.custom_minimum_size.y=360
		controls.add_child(surface_holder)
		surface_holder.add_child(surface)
		surface.configure()
		if surface.kind=="slots": surface.custom_minimum_size.y=240 if size.x>size.y and size.y<600 else 360
	form = VBoxContainer.new()
	form.size_flags_horizontal = SIZE_EXPAND_FILL
	form.add_theme_constant_override("separation",8)
	controls.add_child(form)
	var pending: bool = not s.round.is_empty() and s.round.get("phase") != "done" and kind in ["blackjack","holdem"]
	if pending:
		label(form,"Committed $%.2f" % s.round.staked)
		for action in Games.actions(s.round,sim.owner_bankroll):
			button(form,action.replace("×","x"),func(): if transact("act",{"action":action}): rebuild())
	else:
		numeric = amount(form,"Custom total stake (whole cents)",minf(10,maxf(0.01,sim.owner_bankroll)))
		var denominations := preload("res://scripts/responsive_grid.gd").new()
		denominations.maximum_columns = 3
		form.add_child(denominations)
		for value in [1,5,25,100,500,1000]: button(denominations,"$%d" % value,func(): numeric.value=value)
		if kind == "slots":
			button(form,"LINES %d (equal fractional-cent line shares)" % lines,func(): lines=CasinoTuning.SLOT_LINE_COUNTS[(CasinoTuning.SLOT_LINE_COUNTS.find(lines)+1)%3]; rebuild())
			button(form,"SPIN",func():
				var stake := numeric.value
				if transact("start",{"stake":stake,"lines":lines}):
					rebuild()
					surface.wager = stake
					surface.begin_slot_reveal()
					body_scroll.set_deferred("scroll_vertical",0),sim.owner_bankroll < 0.01)
			button(form,"Sound on / low / off",func(): surface.slot_audio.volume=0.3 if surface.slot_audio.volume>0.5 else 0.65 if surface.slot_audio.volume==0 else 0.0)
		elif kind in ["blackjack","holdem"]:
			if kind == "holdem":
				trips = amount(form,"Optional Trips",0.01)
				trips.min_value = 0; trips.value = 0
				label(form,"Ante + matching Blind. Maximum commitment 6x ante + Trips.",14)
			button(form,"Deal",func(): if transact("start",{"stake":numeric.value,"trips":trips.value if kind=="holdem" else 0}): rebuild(),sim.owner_bankroll < 0.01)
		else:
			var options: Dictionary = Games.roulette_bets() if kind == "roulette" else Craps.empty_bets()
			var picker := OptionButton.new()
			picker.fit_to_longest_item = false
			picker.custom_minimum_size.y = 48
			form.add_child(picker)
			for key in options:
				picker.add_item(key.replace("–","-") if kind=="roulette" else Craps.name_for(key))
				picker.set_item_metadata(picker.item_count-1,key)
				if selected_key == key: picker.select(picker.item_count-1)
			if selected_key.is_empty(): selected_key = str(picker.get_item_metadata(0))
			picker.item_selected.connect(func(i): selected_key=str(picker.get_item_metadata(i)))
			button(form,"Place wager",func(): if transact("add",{"key":selected_key,"stake":numeric.value}): rebuild(),sim.owner_bankroll < 0.01)
			button(form,"Clear bets" if kind=="roulette" else "Take down selected (if rules permit)",func(): if transact("remove",{"key":selected_key}): rebuild())
			button(form,"Spin wheel" if kind=="roulette" else "Throw dice",func(): if transact("roll"): rebuild())
			if kind == "craps":
				label(form,"Solo shooter | Point %d" % s.point)
				button(form,"Come-out working: "+("ON" if s.working else "OFF"),func(): if transact("working"): rebuild())
			for key in sim.back_room.layout(): label(form,"%s: $%.2f" % [key.replace("–","-"),sim.back_room.layout()[key]],14)
	label(form,str(s.result),18)
	if not s.round.is_empty() and kind in ["blackjack","holdem"]: label(form,str(s.round.get("message","")).replace("·","|").replace("×","x"),14)
	button(form,"Rules / paytable",func(): rules(kind))

func rules(kind: String) -> void:
	var shared := preload("res://scripts/game_view.gd").new()
	shared.sim = sim
	shared.slot_lines = lines
	# Slot paytable uses private starter profile, never a floor asset.
	var text := ""
	if kind=="slots":
		var p := CasinoTuning.slot_profile("starter")
		var metrics := CasinoTuning.slot_line_metrics("starter",lines)
		text = "1 / 3 / 5 lines. Total stake is divided equally without rounding each line. Total return rounds once to nearest cent (half up). RTP %.2f%%.\nCherries %dx, lemons %dx, bells %dx, BAR %dx, sevens %dx. Partial cherry return %dx per line.\nPublic slot art, audio and mathematical rules are shared." % [metrics.rtp*100,p.pays[0],p.pays[1],p.pays[2],p.pays[3],p.pays[4],p.cherry_return]
	else:
		text=shared.rules_for(kind)
		if kind=="craps": text = "Solo shooter. Select any supported bet and whole-cent amount. Throw dice to resolve through normal craps rules. Pass/Come contracts stay escrowed until they resolve; only removable wagers can be taken down. Place/hardway bets remain standing on wins. Come-out WORKING controls their action. There are no NPCs or shooter waits."
		if kind=="blackjack": text=text.replace("Finish the hand before returning to Floor.","Returning to Floor preserves the hand; resume it in the Back Room.")
	shared.free()
	page="rules"
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	surface=null; controls=null
	label(body,text.replace("·","|").replace("×","x").replace("’","'"))
	button(body,"Back to game",func(): page="game"; rebuild())

func recovery_panel() -> void:
	var r: Dictionary = sim.recovery.state
	label(body,"Your wallet will top up to $1000. Only the missing amount is granted.",18)
	label(body,"Offer: %s | Full recoveries completed: %d | Work progress %d / 3" % [r.stage,r.completed,sim.recovery.successes()])
	work_min = label(body,"Three verified contracts unlock recovery after the 10-minute real-time minimum. Minimum remaining: "+countdown(int(r.last_full_utc)+CasinoTuning.RECOVERY_WORK_MIN_SECONDS-sim.recovery.now()),14)
	timer_claim = button(body,"Claim guaranteed timer top-up",func(): recover("timer"))
	work_claim = button(body,"Claim completed work top-up",func(): recover("contracts"))
	if not sim.owner_account.pending.is_empty(): label(body,"Resolve outstanding wagers before claiming wallet recovery.")
	for c in r.contracts:
		button(body,Recovery.CATEGORIES[int(c.category)]+(" / COMPLETE" if c.done else " / Expand"),func(): expanded_contract="" if expanded_contract==c.id else c.id; rebuild())
		retry_labels[c.id] = label(body, str(c.feedback),14)
		if c.done or expanded_contract!=c.id: continue
		var p := Recovery.puzzle(c)
		label(body,p.text,15)
		if p.has("clues"):
			var diagram := preload("res://scripts/recovery_clues.gd").new()
			diagram.clues = p.clues
			body.add_child(diagram)
		var choice := OptionButton.new()
		var reason := OptionButton.new()
		var number := SpinBox.new()
		var switches: Array = []
		var aisle := CheckBox.new()
		for field in [choice,reason,number,aisle]: body.add_child(field); field.hide()
		if p.has("options"):
			choice.fit_to_longest_item=false; choice.custom_minimum_size.y=48
			for option in p.options: choice.add_item(option)
			choice.show()
		if int(c.category)==0:
			number.min_value=-10000; number.max_value=10000; number.step=1; number.custom_minimum_size.y=48
			number.show()
		elif int(c.category)==1:
			reason.fit_to_longest_item=false; reason.custom_minimum_size.y=48
			for value in p.reasons: reason.add_item(value)
			reason.show()
		elif int(c.category) in [2,3]:
			for title in (["Switch A","Switch B","Switch C"] if int(c.category)==2 else ["Worker A","Worker B","Worker C","Worker D"]):
				var toggle := CheckBox.new(); toggle.text=title; toggle.custom_minimum_size.y=44
				body.add_child(toggle); switches.append(toggle)
			if int(c.category)==3: aisle.text="Keep emergency aisle open"; aisle.custom_minimum_size.y=44; aisle.show()
		button(body,"Submit verified solution",func():
			var mask := 0
			for i in range(switches.size()):
				if switches[i].button_pressed: mask |= 1<<i
			var response := {"choice":choice.selected,"reason":reason.selected,"number":number.value,"mask":mask,"aisle":aisle.button_pressed}
			var ok := sim.private_transaction(func(): return sim.recovery.submit(sim,str(c.id),response))
			error="" if ok else "Contract locked: already complete, retry cooldown, or save unavailable."
			pass
			rebuild(); changed.emit())
	for t in r.tickets:
		var ticket_art := preload("res://scripts/recovery_ticket.gd").new()
		ticket_art.ticket_id = str(t.id)
		ticket_art.caption = "FREE " + str(t.kind).to_upper()
		body.add_child(ticket_art)
		ticket_labels[t.id]=label(body,"")
		if t.kind=="scratch": label(body,"Odds: 50% $0 | 25% $100 | 15% $250 | 8% $500 | 2% $1000. Maximum top-ups.",14)
		else: label(body,"Odds: 65% $0 | 22% $100 | 10% $250 | 3% $1000. Maximum top-ups.",14)
		if t.claimed:
			if t.award==0: label(body,"No award this time. Your guaranteed recovery is still available.",14)
			continue
		if t.kind=="scratch":
			var card := preload("res://scripts/recovery_scratch_card.gd").new()
			body.add_child(card)
			card.scratched.connect(func(): ticket(str(t.id)))
		button(body,"Reveal card" if t.kind=="scratch" else "Check drawing",func(): ticket(str(t.id)))
	label(body,"These free rewards have no real-money value. Device time is local; offline clock manipulation cannot be fully prevented.",13)


func recover(source: String) -> void:
	var ok := sim.private_transaction(func(): return sim.recovery.claim(sim,source))
	error="" if ok else "Not ready: check real-time eligibility, completed work, wallet gap and outstanding wagers."
	rebuild(); changed.emit()

func ticket(id: String) -> void:
	var ok := sim.private_transaction(func(): return sim.recovery.claim_ticket(sim,id))
	error="" if ok else "Drawing not ready, already claimed, outstanding wagers, or local save unavailable."
	rebuild(); changed.emit()

func ledger() -> void:
	surface=null; controls=null
	page="ledger"
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	for entry in sim.owner_account.history: label(body,"%s | $%.2f | Profit transfer $%.2f" % [entry.kind,entry.amount,entry.profit],14)

func reflow() -> void:
	if not is_node_ready(): return
	var landscape := size.x>size.y and size.y<600
	metrics.vertical = not landscape
	brand_label.visible = page!="game"
	disclosure.visible = page!="game"
	wallet.add_theme_font_size_override("font_size",18 if landscape else 22)
	if not is_instance_valid(controls): return
	controls.vertical = size.x < 1000 and not (size.x > size.y and size.y < 600)
	if is_instance_valid(surface):
		surface_holder.custom_minimum_size = Vector2(0 if controls.vertical else maxf(240,size.x*0.58),240 if landscape else 360)
		surface.custom_minimum_size.x = 0
		surface.configure()
		if surface.kind=="slots": surface.custom_minimum_size.y=240 if size.x>size.y and size.y<600 else 360
