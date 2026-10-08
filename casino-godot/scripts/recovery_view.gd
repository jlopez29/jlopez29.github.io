extends PanelContainer
signal leave_requested
signal changed
const ThemeStyle = preload("res://scripts/pit_boss_theme.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var sim: CasinoSimulation
var body: VBoxContainer
var wallet: Label
var cash: Label
var timer: Label
var message: Label
var work_min: Label
var timer_claim: Button
var work_claim: Button
var ticket_labels := {}
var retry_labels := {}
var expanded_contract := ""
var error := ""
var revision: Array = []
var poll := 0.0

func _ready() -> void:
	add_theme_stylebox_override("panel", ThemeStyle.box(Color("281720"), ThemeStyle.GOLD, 12))
	var stack := VBoxContainer.new()
	add_child(stack)
	label(stack, "WALLET RECOVERY DESK", 20)
	wallet = label(stack, "", 20)
	cash = label(stack, "", 14)
	timer = label(stack, "", 14)
	message = label(stack, "", 14)
	button(stack, "Back to room", func(): leave_requested.emit())
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = SIZE_EXPAND_FILL
	stack.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = SIZE_EXPAND_FILL
	scroll.add_child(body)

func open() -> void:
	show()
	rebuild()

func rebuild() -> void:
	for child in body.get_children(): body.remove_child(child); child.queue_free()
	ticket_labels.clear()
	retry_labels.clear()
	work_min = null
	timer_claim = null
	work_claim = null
	revision = [sim.recovery.state.cycle_id, sim.recovery.successes(), sim.recovery.state.tickets.duplicate(true)]
	recovery_panel()
	update_values()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or sim == null: return
	poll += delta
	if poll < 0.2: return
	poll = 0
	if revision != [sim.recovery.state.cycle_id, sim.recovery.successes(), sim.recovery.state.tickets]: rebuild()
	update_values()

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
