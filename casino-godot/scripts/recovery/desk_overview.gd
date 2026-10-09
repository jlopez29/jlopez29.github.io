extends VBoxContainer
signal job_requested(id: String)
signal claim_requested(source: String)
signal promotions_requested
const UI = preload("res://scripts/recovery/workbench_ui.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var sim: CasinoSimulation
var timed: Label
var work: Label
var payable: Label
var claim: Button
var cards := {}
var actions := {}
var source := ""
var started := {}
var tickets: Button
var grid: GridContainer
func _ready() -> void:
	add_theme_constant_override("separation",12)
	var feature := UI.card(self)
	UI.text(feature,"A LITTLE WORK. A FRESH START.",24)
	UI.text(feature,"Restore your personal wallet through time or three verified jobs. Both paths share one recovery cycle.")
	timed=UI.text(feature,"")
	work=UI.text(feature,"")
	payable=UI.text(feature,"")
	claim=UI.button(feature,"Claim recovery",func(): claim_requested.emit(source))
	UI.text(self,"THREE JOBS / Recovery tier: "+str(sim.recovery.state.stage),20)
	grid=GridContainer.new()
	grid.add_theme_constant_override("h_separation",12)
	grid.add_theme_constant_override("v_separation",12)
	add_child(grid)
	resized.connect(reflow)
	for c in sim.recovery.state.contracts:
		var category := int(c.category)
		var card := UI.card(grid,Color(["302c23","26323d","202d35","28372d"][category]))
		var art := preload("res://scripts/recovery/desk_art.gd").new()
		art.category=category
		card.add_child(art)
		UI.text(card,["[LEDGER] Reconcile the drawer","[CASE FILE] Trace the cash delivery","[CIRCUIT] Controller diagnostic","[SHIFT BOARD] Staff the cage shifts"][category],20)
		UI.text(card,["Compare receipt slips and count a signed difference.","Pair dispatch documents and attach evidence.","Diagnose a module and tune live XOR lamps.","Assign shift coverage and clear an emergency aisle."][category])
		cards[c.id]=UI.text(card,"")
		actions[c.id]=UI.button(card,"Open job",func(): job_requested.emit(str(c.id)))
	tickets=UI.button(self,"Earned promotions",func(): promotions_requested.emit())
	UI.text(self,"Virtual game rewards. No real-money value.",15)
	update_values()
func update_values() -> void:
	var r: Dictionary=sim.recovery.state
	var now: int=sim.recovery.now()
	var timer_left := maxi(0,int(r.next_time_utc)-now)
	var work_left := maxi(0,int(r.last_full_utc)+CasinoTuning.RECOVERY_WORK_MIN_SECONDS-now)
	var gap := maxf(0,Recovery.TARGET-sim.owner_bankroll)
	timed.text="Timed safety refill / REAL TIME / "+("Ready" if timer_left==0 else "Ready in "+UI.clock(timer_left))
	work.text="Earn it by working / %d/3 verified / %s" % [sim.recovery.successes(),"Ready" if work_left==0 and sim.recovery.successes()==3 else "Minimum wait "+UI.clock(work_left) if work_left>0 else "Finish the three jobs"]
	source="timer" if timer_left==0 else "contracts" if work_left==0 and sim.recovery.successes()==3 else ""
	claim.visible=sim.recovery.can_refill(sim) and not source.is_empty()
	claim.text="Claim personal wallet refill +$%.2f" % gap
	payable.text="Eligible gap / $%.2f payable" % gap
	if gap==0: payable.text="No recovery needed yet. $0 payable. Ready when wallet drops below $%.0f." % Recovery.TARGET
	elif not sim.recovery.can_refill(sim): payable.text+="\nSettle active bet before recovery."
	for c in r.contracts:
		var retry := maxi(0,int(c.retry_utc)-now)
		cards[c.id].text="[VERIFIED STAMP]" if c.done else "Retry in "+UI.clock(retry) if retry>0 else "In progress" if started.has(c.id) else "Available"
		actions[c.id].text="Review job" if c.done else "Resume" if started.has(c.id) else "Open job"
	var pending: int=r.tickets.filter(func(t): return not t.claimed).size()
	tickets.visible=not r.tickets.is_empty()
	tickets.text="Promotion drawer / %d unclaimed" % pending

func reflow() -> void:
	grid.columns=3 if size.x>=960 else 1
