extends RefCounted
## One scheduler and separate persisted RNG; never consumes gambling RNG.
## Data definitions own eligibility, presentation metadata and explicit effects.
signal action_requested(event: Dictionary)
const DEFINITIONS := {
	"floor_tip": {"category": "OPPORTUNITY", "title": "Take a look around", "description": "Inspect a machine while the casino keeps running.", "details": "Optional floor insight. Ignoring or expiration has no penalty.", "theme": "positive", "icon": "floor", "weight": 1.0, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "action": "focus_asset", "success": {}, "failure": {}, "expired": {}},
	"management_sample": {"category": "MANAGEMENT", "title": "DEV: coverage review", "description": "Review staffing. Ignoring costs 0.25 reputation.", "details": "Developer sample: dismiss, failure or expiration costs 0.25 reputation; success has no reward.", "theme": "caution", "icon": "staff", "weight": 1.0, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": false, "target_kind": "", "action": "open_staff", "dev_only": true, "success": {}, "failure": {"reputation": -0.25}, "expired": {"reputation": -0.25}},
	"emergency_sample": {"category": "EMERGENCY", "title": "DEV: urgent review", "description": "Review operations. Ignoring costs 1 reputation.", "details": "Developer sample only: dismiss, failure or expiration costs 1 reputation. No production emergency scheduling yet.", "theme": "urgent", "icon": "operations", "weight": 0.05, "cooldown": 2400, "duration": 60, "min_rating": 0.0, "max_rating": 100.0, "requires_open": false, "target_kind": "", "action": "open_staff", "dev_only": true, "success": {}, "failure": {"reputation": -1.0}, "expired": {"reputation": -1.0}},
	"owner_slots": {"category": "OPPORTUNITY", "title": "Lucky Machine", "description": "Take 3 spins with your personal chips.", "details": "Normal machine odds and paytable. The total stake is reserved before play. Net winnings across the 3 spins enter Casino Cash; losses spend Owner Bankroll only. Leaving reveals and settles all committed spins. A net win gently boosts Momentum. Ignore safely.", "theme": "positive", "icon": "owner_slots", "weight": 1.0, "cooldown": 1200, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "owner_slots", "action": "owner_game", "success": {}, "failure": {}, "expired": {}, "game": "slots", "stake_options": [5.0, 10.0, 25.0], "rounds": 3, "bonus_profit": 0.0, "reward_hooks": {"momentum": CasinoTuning.MOMENTUM_OWNER_WIN_GAIN, "reputation": 0.0, "mystery": null}},
	"owner_blackjack": {"category": "OPPORTUNITY", "title": "Owner's Hand", "description": "Play 1 blackjack hand with personal chips.", "details": "Normal six-deck blackjack, 3:2 natural, split/double/insurance available at their usual additional stakes. Net winnings enter Casino Cash; losses spend Owner Bankroll only. Leaving declines insurance and stands all remaining hands. A net win gently boosts Momentum. Ignore safely.", "theme": "positive", "icon": "owner_blackjack", "weight": 1.0, "cooldown": 1200, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "owner_blackjack", "action": "owner_game", "success": {}, "failure": {}, "expired": {}, "game": "blackjack", "stake_options": [10.0, 25.0], "rounds": 1, "bonus_profit": 0.0, "reward_hooks": {"momentum": CasinoTuning.MOMENTUM_OWNER_WIN_GAIN, "reputation": 0.0, "mystery": null}},
	"busy_table": {"category": "OPPORTUNITY", "title": "A table is getting attention", "description": "Recent wagers have drawn a real crowd.", "details": "Inspect the active table to see why guests are watching. Attention comes from actual play and does not change odds. Ignore safely.", "theme": "positive", "icon": "busy_table", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "busy_table", "action": "focus_asset", "success": {}, "failure": {}, "expired": {}},
	"slot_crowd": {"category": "OPPORTUNITY", "title": "Reels drawing a crowd", "description": "Guests are gathering around a working slot.", "details": "Inspect the machine and nearby guest thoughts. This is actual floor activity, not a payout boost. Ignore safely.", "theme": "positive", "icon": "slot_crowd", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "slot_crowd", "action": "focus_asset", "success": {}, "failure": {}, "expired": {}},
	"jackpot_celebration": {"category": "OPPORTUNITY", "title": "A guest landed a big slot win", "description": "A real payout has just happened at this machine.", "details": "See the machine and recent settled result. The payout has already been accounted for; viewing or ignoring gives no extra money.", "theme": "positive", "icon": "jackpot", "weight": 0.6, "cooldown": 1200, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "jackpot", "action": "focus_asset", "success": {}, "failure": {}, "expired": {}},
	"drink_demand": {"category": "OPPORTUNITY", "title": "Drinks are in demand", "description": "Several guests have orders for your bar.", "details": "Review the real menu and pricing. No bonus demand or ignored-event penalty is added.", "theme": "positive", "icon": "drink_demand", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "bar", "context": "drink_demand", "action": "open_bar", "success": {}, "failure": {}, "expired": {}},
	"service_rush": {"category": "MANAGEMENT", "title": "Drink queue is growing", "description": "Pending orders are building up. Review service coverage.", "details": "Ignoring adds no event penalty. The existing simulation continues: thirsty guests may lose satisfaction while waiting. Add relief or review your menu through management.", "theme": "caution", "icon": "service_rush", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "bar", "context": "service_rush", "action": "open_staff", "success": {}, "failure": {}, "expired": {}, "responses": [{"id": "bar", "label": "Review menu", "action": "open_bar"}]},
	"staff_fatigue": {"category": "MANAGEMENT", "title": "A dealer needs relief", "description": "An active dealer is getting tired.", "details": "Automatic staffing rotation still operates. Ignoring adds no event penalty; existing fatigue and coverage rules may stop new table play. Review relief staffing instead of manually resetting energy.", "theme": "caution", "icon": "staff_fatigue", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "staff", "context": "staff_fatigue", "action": "open_staff", "success": {}, "failure": {}, "expired": {}},
	"machine_repair": {"category": "MANAGEMENT", "title": "A game needs repair", "description": "A real breakdown has halted this game.", "details": "Ignoring adds no event penalty. The broken asset remains halted under existing maintenance rules. Inspect it or pay the quoted repair cost once.", "theme": "caution", "icon": "machine_repair", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "asset", "context": "machine_repair", "action": "focus_asset", "success": {}, "failure": {}, "expired": {}, "responses": [{"id": "repair", "label": "Repair", "action": "repair"}]},
	"guest_complaint": {"category": "MANAGEMENT", "title": "Guests want drink service", "description": "A real service complaint needs attention.", "details": "Ignoring adds no event penalty; unmet drink needs continue under existing satisfaction rules. Review service or offer the existing $60 complaint comp (+2 reputation, +8 guest satisfaction).", "theme": "caution", "icon": "guest_complaint", "weight": 0.6, "cooldown": 900, "duration": 90, "min_rating": 0.0, "max_rating": 100.0, "requires_open": true, "target_kind": "bar", "context": "guest_complaint", "action": "open_staff", "success": {}, "failure": {}, "expired": {}, "responses": [{"id": "comp", "label": "Comp $60", "action": "comp"}]}
}
var active: Array = []
var history: Array = []
var cooldowns := {}
var next_id := 1
var next_check := CasinoTuning.EVENT_INTERVAL_MINUTES
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()

func targets(sim, type: String) -> Array:
	if not DEFINITIONS.has(type): return []
	var definition: Dictionary = DEFINITIONS[type]
	var context := str(definition.get("context", ""))
	if context == "staff_fatigue":
		return sim.staff.filter(func(employee): return employee.role == "Dealer" and employee.duty == "Active" and employee.energy <= CasinoTuning.STAFF_BREAK_ENERGY and not sim.get_table(int(employee.table)).is_empty()).map(func(employee): return int(employee.id))
	if context in ["drink_demand", "service_rush"]:
		var functioning: bool = sim.bar_available() and not sim.drink_menu.is_empty() and sim.staff.any(func(employee): return employee.role == "Service" and employee.duty == "Active")
		var orders: int = sim.guests.filter(func(guest): return guest.drink_order != "" and guest.state not in ["Leaving", "To cage", "Cashing out"]).size()
		return [-1] if functioning and orders >= CasinoTuning.EVENT_DRINK_QUEUE_THRESHOLD else []
	if context == "guest_complaint":
		return [-1] if sim.bar_available() and sim.incidents.any(func(incident): return incident.type == "service") else []
	var result: Array = []
	for table in sim.tables:
		var matches := false
		match context:
			"owner_slots", "owner_blackjack":
				matches = sim.operating(table) and sim.table_kind(table) == str(definition.game) and not stake_options(sim, type, int(table.id)).is_empty()
			"busy_table": matches = sim.table_hot(table)
			"slot_crowd": matches = sim.operating(table) and sim.table_kind(table) == "slots" and sim.guests.filter(func(guest): return int(guest.table) == int(table.id) and guest.state in ["Playing", "Watching"]).size() >= CasinoTuning.EVENT_SLOT_CROWD_THRESHOLD
			"jackpot": matches = sim.operating(table) and sim.table_kind(table) == "slots" and sim.recent_financial_events.any(func(event): return int(event.asset_id) == int(table.id) and int(event.guest_id) > 0 and float(event.amount) <= -CasinoTuning.EVENT_GUEST_BIG_WIN and sim.elapsed - int(event.elapsed) <= CasinoTuning.HOT_ACTIVITY_MINUTES)
			"machine_repair": matches = table.broken and sim.incidents.any(func(incident): return incident.type == "repair" and int(incident.table) == int(table.id))
			_: matches = definition.target_kind == "asset"
		if matches: result.append(int(table.id))
	if definition.target_kind == "": return [-1]
	return result

func stake_options(sim, type: String, target: int) -> Array:
	var definition: Dictionary = DEFINITIONS[type]
	var table: Dictionary = sim.get_table(target)
	if table.is_empty(): return []
	var options: Array = definition.get("stake_options", [definition.get("fixed_stake", 0)])
	return options.filter(func(stake): return float(stake) >= float(table.minimum) and float(stake) <= sim.maximum_wager(table) and (sim.table_kind(table) != "slots" or float(stake) in sim.slot_profile(table).denominations))

func eligible(sim, type: String) -> bool:
	if not DEFINITIONS.has(type): return false
	var definition: Dictionary = DEFINITIONS[type]
	if bool(definition.requires_open) and not sim.opened: return false
	if sim.casino_rating < definition.min_rating or sim.casino_rating > definition.max_rating: return false
	return not targets(sim, type).is_empty()

func target_valid(sim, event: Dictionary) -> bool:
	var definition: Dictionary = DEFINITIONS[event.type]
	if bool(definition.requires_open) and not sim.opened: return false
	if sim.casino_rating < definition.min_rating or sim.casino_rating > definition.max_rating: return false
	return int(event.target) in targets(sim, str(event.type))

func spawn(sim, type: String, debug: bool = false) -> bool:
	if debug and not OS.is_debug_build(): return false
	if not eligible(sim, type) or active.size() >= CasinoTuning.EVENT_QUEUE_LIMIT: return false
	var definition: Dictionary = DEFINITIONS[type]
	if bool(definition.get("dev_only", false)) and not debug: return false
	if active.any(func(event): return event.type == type): return false
	if not debug and sim.elapsed < int(cooldowns.get(type, 0)): return false
	var candidates := targets(sim, type)
	var target: int = candidates[rng.randi_range(0, candidates.size() - 1)]
	active.append({"id": next_id, "type": type, "created": sim.elapsed, "expires": sim.elapsed + int(definition.duration), "target": target, "state": "pending", "dev": debug})
	# Urgent cards lead the bounded queue so their warning is visible in time.
	active.sort_custom(func(a, b):
		var ranks := {"EMERGENCY": 0, "MANAGEMENT": 1, "OPPORTUNITY": 2}
		var left: int = ranks[DEFINITIONS[a.type].category]
		var right: int = ranks[DEFINITIONS[b.type].category]
		return int(a.id) < int(b.id) if left == right else left < right)
	next_id += 1
	cooldowns[type] = sim.elapsed + int(definition.cooldown)
	return true

func tick(sim) -> void:
	for event in active.duplicate():
		if sim.owner_play.get("event_id", -1) == int(event.id): continue
		if sim.elapsed >= int(event.expires) or not target_valid(sim, event): resolve(sim, int(event.id), "expired")
	if not sim.opened:
		next_check = sim.elapsed + CasinoTuning.EVENT_INTERVAL_MINUTES
		return
	if sim.elapsed < next_check: return
	next_check = sim.elapsed + CasinoTuning.EVENT_INTERVAL_MINUTES
	if active.size() >= CasinoTuning.EVENT_QUEUE_LIMIT or rng.randf() >= CasinoTuning.EVENT_SPAWN_CHANCE: return
	var candidates: Array = []
	var weight := 0.0
	for type in DEFINITIONS:
		var definition: Dictionary = DEFINITIONS[type]
		if definition.get("dev_only", false) or not eligible(sim, type) or sim.elapsed < int(cooldowns.get(type, 0)): continue
		if active.any(func(event): return event.type == type): continue
		candidates.append(type)
		weight += float(definition.weight)
	if candidates.is_empty(): return
	var pick := rng.randf() * weight
	for type in candidates:
		pick -= float(DEFINITIONS[type].weight)
		if pick <= 0:
			spawn(sim, type)
			return

func find_event(id: int) -> Dictionary:
	for event in active:
		if int(event.id) == id: return event
	return {}

func engage(sim, id: int) -> bool:
	var event := find_event(id)
	if event.is_empty() or event.state != "pending" or sim.elapsed >= int(event.expires): return false
	if not target_valid(sim, event):
		resolve(sim, id, "expired")
		return false
	if DEFINITIONS[event.type].target_kind == "asset" and sim.get_table(int(event.target)).is_empty():
		resolve(sim, id, "expired")
		return false
	event.state = "engaged" # Guard double taps before invoking a potentially async handler.
	var request := event.duplicate(true)
	request.action = DEFINITIONS[event.type].action
	action_requested.emit(request)
	return true

func respond(sim, id: int, response_id: String) -> bool:
	var event := find_event(id)
	if event.is_empty() or event.state != "pending" or sim.elapsed >= int(event.expires) or not target_valid(sim, event): return false
	for response in DEFINITIONS[event.type].get("responses", []):
		if response.id != response_id: continue
		if response.action in ["repair", "comp"]:
			var index := -1
			for i in range(sim.incidents.size()):
				var incident: Dictionary = sim.incidents[i]
				if (response.action == "repair" and incident.type == "repair" and int(incident.table) == int(event.target)) or (response.action == "comp" and incident.type == "service"):
					index = i
					break
			if index < 0: return false
			var cost: float = sim.repair_cost(sim.get_table(int(event.target))) if response.action == "repair" else 60.0
			if sim.cash < cost: return false
			event.state = "engaged"
			sim.resolve_incident(index, true)
			return resolve(sim, id, "success")
		event.state = "engaged"
		var request := event.duplicate(true)
		request.action = response.action
		action_requested.emit(request)
		return true
	return false

func resolve(sim, id: int, outcome: String, result: Dictionary = {}) -> bool:
	if outcome not in ["success", "failure", "expired", "dismissed"]: return false
	var event := find_event(id)
	if event.is_empty(): return false
	if sim.owner_play.get("event_id", -1) == id and sim.owner_play.get("status") != "done": return false
	if outcome in ["success", "failure"] and event.state != "engaged": return false
	var definition: Dictionary = DEFINITIONS[event.type]
	active.erase(event) # Exactly once, including synchronous callbacks.
	var effects: Dictionary = definition["expired" if outcome == "dismissed" else outcome]
	# Opportunity rejection never mutates the economy, reputation or momentum.
	if definition.category != "OPPORTUNITY" or outcome == "success":
		sim.change_reputation(float(effects.get("reputation", 0)), "optional_event.%s.%s" % [event.type, outcome])
		if effects.has("bankroll_reward"):
			sim.reward_owner_bankroll(sim.owner_account.next_operation, float(effects.bankroll_reward), str(event.type))
	# Navigation is not a successful management outcome. Only settled owner wins
	# earn an event boost; repair/comp rewards belong to resolve_incident.
	if outcome == "success" and str(definition.get("action", "")) == "owner_game" and float(result.get("casino_profit", 0)) > 0:
		sim.optional_objectives.observe(sim, "owner_win", 1)
		sim.momentum.outcome(float(definition.get("reward_hooks", {}).get("momentum", 0)), "Won an owner gambling opportunity")
	history.push_front({"id": id, "type": event.type, "outcome": outcome, "at": sim.elapsed, "result": result.duplicate(true)})
	if history.size() > CasinoTuning.EVENT_HISTORY_LIMIT: history.pop_back()
	return true

func snapshot() -> Dictionary:
	return {"active": active.duplicate(true), "history": history.duplicate(true), "cooldowns": cooldowns.duplicate(), "next_id": next_id, "next_check": next_check, "rng_state": str(rng.state)}

static func integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= 0 and value == int(value) and value < 1.0e12

func restore(data: Variant, at: int) -> bool:
	if not data is Dictionary or not integer(data.get("next_id")) or data.next_id < 1 or not integer(data.get("next_check")): return false
	if not data.get("rng_state") is String or not data.rng_state.is_valid_int(): return false
	if not data.get("active") is Array or data.active.size() > CasinoTuning.EVENT_QUEUE_LIMIT: return false
	if not data.get("history") is Array or data.history.size() > CasinoTuning.EVENT_HISTORY_LIMIT: return false
	if not data.get("cooldowns") is Dictionary: return false
	var ids := {}
	var types := {}
	for event in data.active:
		if not event is Dictionary or not DEFINITIONS.has(event.get("type")): return false
		for key in ["id", "created", "expires"]:
			if not integer(event.get(key)): return false
		if event.id < 1 or event.id >= data.next_id or ids.has(event.id) or types.has(event.type): return false
		if event.created > at or event.expires < event.created or event.expires - event.created != DEFINITIONS[event.type].duration: return false
		if event.get("state") not in ["pending", "engaged"] or not event.get("dev") is bool: return false
		if not (event.get("target") is int or event.get("target") is float) or not is_finite(float(event.target)) or event.target != int(event.target): return false
		if event.has("operation") and (not integer(event.operation) or event.operation < 1): return false
		var target_kind: String = DEFINITIONS[event.type].target_kind
		if target_kind in ["asset", "staff"] and event.target < 1: return false
		if target_kind in ["bar", ""] and event.target != -1: return false
		ids[event.id] = true
		types[event.type] = true
	for type in data.cooldowns:
		if not DEFINITIONS.has(type) or not integer(data.cooldowns[type]): return false
	for entry in data.history:
		if not entry is Dictionary or not DEFINITIONS.has(entry.get("type")) or not integer(entry.get("id")) or entry.id < 1 or entry.id >= data.next_id or ids.has(entry.id): return false
		if entry.get("outcome") not in ["success", "failure", "expired", "dismissed"] or not integer(entry.get("at")) or entry.at > at: return false
		ids[entry.id] = true
	active = data.active.duplicate(true)
	if not OS.is_debug_build():
		active = active.filter(func(event): return not DEFINITIONS[event.type].get("dev_only", false))
	history = data.history.duplicate(true)
	cooldowns = data.cooldowns.duplicate()
	next_id = int(data.next_id)
	# Preserve future scheduling, clamp overdue check; no replay/catch-up loop.
	next_check = at + CasinoTuning.EVENT_INTERVAL_MINUTES if int(data.next_check) <= at else int(data.next_check)
	rng.state = int(data.rng_state)
	return true
