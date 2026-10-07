extends RefCounted
## One durable cycle, independent real clock and promotional RNG.
const Account = preload("res://scripts/owner_bankroll.gd")
const TARGET := CasinoTuning.OWNER_STARTING_BANKROLL
const CATEGORIES := ["Cage reconciliation", "Security investigation", "Slot technician", "Operations planning"]
var rng := RandomNumberGenerator.new()
var state := {}
var anchor_ticks := Time.get_ticks_msec()
var anchor_utc := int(Time.get_unix_time_from_system())

func _init() -> void:
	rng.randomize()
	new_cycle(0, 0, anchor_utc, anchor_utc, [])

func now() -> int:
	# In-session elapsed time is monotonic. Offline wall time is accepted on restore.
	return anchor_utc + maxi(0, int((Time.get_ticks_msec()-anchor_ticks)/1000))

static func stage(rating: float, cycles: int) -> String:
	return "Late" if rating >= CasinoTuning.RECOVERY_LATE_RATING else "Early" if rating < CasinoTuning.RECOVERY_MID_RATING and cycles < CasinoTuning.RECOVERY_EARLY_CYCLES else "Mid"

func new_cycle(id: int, completed: int, started: int, last: int, tickets: Array, rating: float = 0) -> void:
	var offered := stage(rating, completed)
	var categories := [0,1,2,3]
	for i in range(3,0,-1):
		var j := rng.randi_range(0,i)
		var temp: int = categories[i]; categories[i] = categories[j]; categories[j] = temp
	var contracts: Array = []
	for i in range(3):
		contracts.append({"id": "%d:%d" % [id,i], "category": categories[i], "variant": rng.randi_range(0,11), "tier": ["Early","Mid","Late"].find(offered), "done": false, "failures": 0, "retry_utc": 0, "feedback": ""})
	state = {"cycle_id": id, "started_utc": started, "last_full_utc": last, "next_time_utc": started + int(CasinoTuning.RECOVERY_SECONDS[offered]), "completed": completed, "stage": offered, "contracts": contracts, "tickets": tickets, "scratch_issued": false, "raffle_issued": false, "last_source": "", "last_amount": 0.0, "clock_utc": started}

# Finite curated parameter bank. Labels, quantities, circuit equations and staffing requirements vary.
static func puzzle(c: Dictionary) -> Dictionary:
	var v := int(c.variant)
	var tier := int(c.tier)
	match int(c.category):
		0:
			var receipts := [125+v*5, 80+tier*20, 45+v*3]
			var error := v % 3
			var delta := (10 + (v%4)*5 + tier*10) * (-1 if v%2 else 1)
			var recorded := receipts.duplicate()
			recorded[error] += delta
			return {"text": "Reconcile three cage receipts. Recorded minus verified is the discrepancy. Select the faulty receipt and enter the signed discrepancy.\nA: verified $%d / recorded $%d\nB: verified $%d / recorded $%d\nC: verified $%d / recorded $%d" % [receipts[0],recorded[0],receipts[1],recorded[1],receipts[2],recorded[2]], "options": ["Correct receipt A", "Correct receipt B", "Correct receipt C"], "answer": error, "number": delta, "hint": "Compare each recorded receipt with its verified amount; subtract verified from recorded."}
		1:
			var culprit := (v+tier)%3
			var names := ["Runner A", "Runner B", "Runner C"]
			var clue: String = ["seal", "time", "count"][v%3]
			var lines: Array = []
			for i in range(3):
				var faulty: bool = i == culprit
				if clue == "seal": lines.append("%02d:00 %s: dispatch seal %d; cage receipt seal %d." % [10+i,names[i],200+v*3+i,200+v*3+i+(1 if faulty else 0)])
				elif clue == "time": lines.append("%s: dispatch %02d:10; receipt %02d:%02d." % [names[i],10+i,10+i,5 if faulty else 20])
				else: lines.append("%02d:00 %s: dispatch %d bundles; receipt %d bundles." % [10+i,names[i],4+i+tier,4+i+tier+(1 if faulty else 0)])
			return {"text": "Review the dispatch timeline. Exactly one record conflicts with the paired receipt. Identify it and the evidence; no personal characteristics are clues.", "clues": lines, "options": names, "reasons": ["Seal differs", "Receipt precedes dispatch", "Bundle count differs"], "answer": culprit, "reason": ["seal","time","count"].find(clue), "hint": "Match each dispatch to its receipt. Check seal, chronological order and bundle count."}
		2:
			var target := 1 + (v*3+tier*2)%7
			var a := target & 1
			var b := (target >> 1)&1
			var d := (target >> 2)&1
			return {"text": "A virtual slot has stable power and a good reel sensor, but its controller self-test fails. Diagnose the component, then set switches A/B/C (ON=1).\nTest lamps must read: A XOR B = %d, B XOR C = %d, A = %d.\nThese switches affect only this training machine." % [a^b,b^d,a], "options": ["Power supply", "Reel sensor", "Controller circuit"], "answer": 2, "mask": target, "hint": "Power and sensor passed. Set A from the last lamp, then derive B and C with XOR."}
		_:
			var costs := [40+v*2,55+tier*5,70+v,90+tier*10]
			var coverage := [[1,1,0],[0,1,1],[1,0,1],[1,1,1]]
			# A+B covers all shifts; budget excludes full-coverage luxury worker D.
			var budget: int = costs[0]+costs[1]
			var required := [1,2 if v%2 else 1,1]
			return {"text": "Staff a virtual three-shift cage. Select a team within $%d. Required coverage: morning %d, afternoon %d, night %d. Keep the emergency aisle open.\nA $%d: morning + afternoon\nB $%d: afternoon + night\nC $%d: morning + night\nD $%d: all three shifts" % [budget,required[0],required[1],required[2],costs[0],costs[1],costs[2],costs[3]], "costs": costs, "coverage": coverage, "budget": budget, "required": required, "hint": "Add selected worker costs and coverage. Check every shift and the emergency aisle."}

static func solved(c: Dictionary, response: Dictionary) -> bool:
	var p := puzzle(c)
	match int(c.category):
		0: return response.get("choice", -1) == p.answer and response.get("number") == p.number
		1: return response.get("choice", -1) == p.answer and response.get("reason", -1) == p.reason
		2: return response.get("choice", -1) == p.answer and response.get("mask", -1) == p.mask
		_:
			if not response.get("aisle", false) or not response.get("mask") is int or response.mask < 0 or response.mask > 15: return false
			var spend := 0
			var coverage := [0,0,0]
			for i in range(4):
				if int(response.mask) & (1<<i):
					spend += int(p.costs[i])
					for j in range(3): coverage[j] += int(p.coverage[i][j])
			return spend <= int(p.budget) and coverage[0] >= p.required[0] and coverage[1] >= p.required[1] and coverage[2] >= p.required[2]

func successes() -> int:
	return state.contracts.filter(func(c): return c.done).size()

func submit(sim, id: String, response: Dictionary) -> bool:
	for c in state.contracts:
		if c.id != id: continue
		if c.done or now() < int(c.retry_utc): return false
		if solved(c, response): c.done = true; c.feedback = "Verified. Contract complete."
		else:
			c.failures += 1
			c.retry_utc = now() + CasinoTuning.RECOVERY_RETRY_SECONDS
			c.feedback = "Attempt failed. " + str(puzzle(c).hint)
		if c.done and stage(sim.casino_rating, int(state.completed)) == "Early" and state.stage == "Early":
			if successes() >= 1 and not state.scratch_issued: issue("scratch"); state.scratch_issued = true
			if successes() >= 2 and not state.raffle_issued: issue("raffle"); state.raffle_issued = true
		return true # A failed attempt is also a durable transition.
	return false

static func award_for(kind: String, roll: int) -> int:
	if kind == "scratch": return 0 if roll < 50 else 100 if roll < 75 else 250 if roll < 90 else 500 if roll < 98 else 1000
	return 0 if roll < 65 else 100 if roll < 87 else 250 if roll < 97 else 1000

func issue(kind: String) -> void:
	state.tickets.append({"id": "%d:%s" % [state.cycle_id,kind], "kind": kind, "award": award_for(kind,rng.randi_range(0,99)), "draw_utc": now() + (CasinoTuning.RECOVERY_RAFFLE_SECONDS if kind == "raffle" else 0), "claimed": false, "revealed": false, "granted": 0.0})

func can_refill(sim) -> bool:
	return sim.owner_bankroll < TARGET and sim.owner_account.pending.is_empty() and sim.owner_pending_stakes() <= 0 and sim.joined < 0 and sim.owner_play.is_empty()

func claim(sim, source: String) -> bool:
	if not can_refill(sim): return false
	if source == "timer":
		if now() < int(state.next_time_utc): return false
	elif source == "contracts":
		if successes() != 3 or now() < int(state.last_full_utc)+CasinoTuning.RECOVERY_WORK_MIN_SECONDS: return false
	else: return false
	var amount := minf(TARGET-sim.owner_bankroll,snappedf(TARGET-sim.owner_bankroll,0.01))
	if not sim.owner_account.reward(sim.owner_account.next_operation, amount, "recovery_"+source,sim.elapsed): return false
	advance(sim, source, amount)
	return true

func claim_ticket(sim, id: String) -> bool:
	if not sim.owner_account.pending.is_empty() or sim.owner_pending_stakes() > 0 or not sim.owner_play.is_empty(): return false
	for ticket in state.tickets:
		if ticket.id != id: continue
		if ticket.claimed or now() < int(ticket.draw_utc): return false
		var amount := minf(maxf(0,TARGET-sim.owner_bankroll),snappedf(minf(float(ticket.award),maxf(0,TARGET-sim.owner_bankroll)),0.01))
		if amount > 0 and not sim.owner_account.reward(sim.owner_account.next_operation,amount,"recovery_"+str(ticket.kind),sim.elapsed): return false
		ticket.claimed = true; ticket.revealed = true; ticket.granted = amount
		if amount == 0: sim.owner_account.record("recovery_"+str(ticket.kind)+"_zero",0,sim.elapsed)
		state.last_source = ticket.kind; state.last_amount = amount
		if amount > 0 and sim.owner_bankroll >= TARGET: advance(sim,str(ticket.kind),amount)
		return true
	return false

func advance(sim, source: String, amount: float) -> void:
	# Issued unclaimed tickets survive full refills and stage boundaries; no expiration.
	var retained: Array = state.tickets.filter(func(t): return not t.claimed)
	var claimed: Array = state.tickets.filter(func(t): return t.claimed)
	retained.append_array(claimed.slice(maxi(0,claimed.size()-2)))
	new_cycle(int(state.cycle_id)+1,int(state.completed)+1,now(),now(),retained,sim.casino_rating)
	state.last_source = source; state.last_amount = amount

func snapshot() -> Dictionary:
	var copy: Dictionary = state.duplicate(true)
	copy.clock_utc = now()
	return {"state": copy, "rng": str(rng.state)}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("state") is Dictionary or not data.get("rng") is String or not data.rng.is_valid_int() or str(int(data.rng)) != data.rng: return false
	var s: Dictionary = data.state
	for key in ["cycle_id","started_utc","last_full_utc","next_time_utc","completed","clock_utc"]:
		if not Account.money(s.get(key)) or s[key] != int(s[key]): return false
	if s.cycle_id != s.completed or s.get("stage") not in ["Early","Mid","Late"] or not s.get("last_source") is String or not Account.money(s.get("last_amount")) or s.last_amount > TARGET: return false
	if not s.get("scratch_issued") is bool or not s.get("raffle_issued") is bool: return false
	if s.next_time_utc != s.started_utc + int(CasinoTuning.RECOVERY_SECONDS[s.stage]) or s.last_full_utc > s.started_utc: return false
	if not s.get("contracts") is Array or s.contracts.size() != 3 or not s.get("tickets") is Array or s.tickets.size() > 14: return false
	var categories := {}
	for i in range(3):
		var c = s.contracts[i]
		if not c is Dictionary or c.get("id") != "%d:%d" % [int(s.cycle_id),i] or not c.get("done") is bool or not c.get("feedback") is String: return false
		for key in ["category","variant","tier","failures","retry_utc"]:
			if not Account.money(c.get(key)) or c[key] != int(c[key]): return false
		if c.category > 3 or c.variant > 11 or c.tier != ["Early","Mid","Late"].find(s.stage) or categories.has(int(c.category)): return false
		categories[int(c.category)] = true
	var ids := {}
	for t in s.tickets:
		if not t is Dictionary or not t.get("id") is String or ids.has(t.id) or t.get("kind") not in ["scratch","raffle"]: return false
		var parts: PackedStringArray = t.id.split(":")
		if parts.size()!=2 or not parts[0].is_valid_int() or parts[1]!=t.kind or str(int(parts[0]))!=parts[0] or int(parts[0])<0 or int(parts[0])>=CasinoTuning.RECOVERY_EARLY_CYCLES or int(parts[0])>int(s.cycle_id): return false
		if int(parts[0])==int(s.cycle_id) and (s.stage!="Early" or not s[t.kind+"_issued"]): return false
		ids[t.id] = true
		if not t.get("claimed") is bool or not t.get("revealed") is bool or t.claimed != t.revealed: return false
		for key in ["award","draw_utc","granted"]:
			if not Account.money(t.get(key)): return false
		if int(t.award) not in ([0,100,250,500,1000] if t.kind == "scratch" else [0,100,250,1000]) or t.granted > t.award or (not t.claimed and t.granted != 0): return false
	state = s.duplicate(true)
	rng.state = int(data.rng)
	anchor_ticks = Time.get_ticks_msec()
	var wall := int(Time.get_unix_time_from_system())
	# Backward/implausible clock readings freeze offline accrual at the last checkpoint.
	anchor_utc = maxi(int(s.clock_utc),wall) if wall >= 1577836800 and wall <= 4102444800 else int(s.clock_utc)
	return true
