class_name CasinoSimulation
extends RefCounted

signal financial_event(event: Dictionary)
signal guest_thought(event: Dictionary)

const Games = preload("res://scripts/casino_games.gd")

var cash := CasinoTuning.STARTING_CASH
var wallet := CasinoTuning.VISITOR_CASH
var revenue := 0.0
var payouts := 0.0
var payroll := 0.0
var overhead := 0.0
# Cash expenses recorded once; classifications never make an additional charge.
var expense_totals := {"dealer_payroll": 0.0, "service_payroll": 0.0, "upkeep": 0.0, "repairs": 0.0, "comps": 0.0, "hiring": 0.0, "construction": 0.0, "sales": 0.0, "drink_products": 0.0, "drink_comps": 0.0}
var payroll_by_state := {"working": 0.0, "idle": 0.0, "standby": 0.0, "unavailable": 0.0}
var bar_totals := {"sold": 0, "comped": 0, "revenue": 0.0, "product_cost": 0.0, "comp_cost": 0.0}
var visitor_net := 0.0
var reputation := 60.0
var difficulty := "normal"
var starting_games: Array = ["slots"]
var casino_rating := 0.0
var guest_rounds := 0
var guest_revenue := 0.0
var guest_handle := 0.0 # Settled stakes only; independent of visitor transfers.
var guests_served := 0
var blackjack_unlocked := false
# Session-only developer access; ignored by release builds and never serialized.
var debug_forced_unlocks: Array[String] = []
var ever_opened := false
var expanded := false
var vip_enabled := false
var high_limit_enabled := false
var minute := 1080
var day := 1
var elapsed := 0
var opened := false
var arrival_in := 10
var tables: Array = []
var guests: Array = []
var cashout_effects: Array = []
var recent_financial_events: Array = [] # Transient; never replay settlements after Load.
var house_activity: Array = [] # Transient management notices, separate from detailed financial events.
var slot_access: Array = ["starter"]
var financial_sequence := 0
var thought_last := {} # Transient emission cooldowns, not saved guest history.
var table_interest := {} # Bounded recent actual guest wagers, never an odds input.
const BAR_PICKUP := Vector2(730, 90)
const CAGE_PICKUP := Vector2(120, 90)
var staff: Array = []
var alerts: Array = []
var incidents: Array = []
var next_id := 1
var joined := -1
var player := Vector2(425, 510)
var rng := RandomNumberGenerator.new()

func _init(mode: String = "normal", preferred_games: Array = ["slots"]) -> void:
	rng.randomize()
	difficulty = mode if CasinoTuning.DIFFICULTIES.has(mode) else "normal"
	var config: Dictionary = CasinoTuning.DIFFICULTIES[difficulty]
	cash = float(config.cash)
	expanded = bool(config.expanded)
	vip_enabled = not bool(config.restricted)
	high_limit_enabled = not bool(config.restricted)
	starting_games = ["slots"]
	if not bool(config.restricted):
		starting_games = []
		for kind in preferred_games:
			if Games.NAMES.has(kind) and kind not in starting_games: starting_games.append(kind)
		if starting_games.is_empty(): starting_games = ["slots"]
	var positions := [Vector2(90, 140), Vector2(370, 140), Vector2(90, 330), Vector2(370, 330), Vector2(660, 300)]
	if restricted():
		tables.append(new_table(Vector2(120, 180), false, "slots"))
		tables.append(new_table(Vector2(230, 180), false, "slots"))
	else:
		for i in range(starting_games.size()):
			var kind: String = starting_games[i]
			var table := new_table(positions[i], kind == "holdem", kind)
			tables.append(table)
			for j in range(required_crew(table)):
				staff.append({"name": CasinoTuning.NAMES[rng.randi_range(0, 11)], "role": "Dealer", "table": int(table.id), "energy": 100.0})
	refresh_progression()
	log_event("Normal: two slots, $%d and room to grow. Open the casino to welcome your first guest." % CasinoTuning.STARTING_CASH if restricted() else "Easy: your chosen games and crews are ready. Access is unrestricted; wages and gaming risk still apply.")

func restricted() -> bool:
	return bool(CasinoTuning.DIFFICULTIES[difficulty].restricted)

func unlocked(feature: String) -> bool:
	if feature.begins_with("slot:"): return slot_unlocked(feature.trim_prefix("slot:"))
	if OS.is_debug_build() and feature in debug_forced_unlocks: return true
	if not restricted(): return true
	if feature == "blackjack": return blackjack_unlocked
	if feature != "slots" and not blackjack_unlocked: return false
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id == feature: return casino_rating >= float(milestone.rating)
	return false

func revealed(feature: String) -> bool:
	if feature == "blackjack": return true
	if unlocked(feature): return true
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id == feature: return casino_rating >= float(milestone.rating) - CasinoTuning.REVEAL_DISTANCE
	return false

func stars() -> int:
	var count := 1
	for i in range(1, CasinoTuning.STAR_THRESHOLDS.size()):
		if casino_rating >= float(CasinoTuning.STAR_THRESHOLDS[i]): count = i + 1
	return count

func feature_cost(feature: String) -> float:
	if Games.COSTS.has(feature): return float(Games.COSTS[feature])
	return float({"service": CasinoTuning.HIRING_COST, "expansion": CasinoTuning.EXPANSION_COST, "vip": CasinoTuning.VIP_COST, "high_limit": CasinoTuning.HIGH_LIMIT_COST}.get(feature, 0))

func feature_owned(feature: String) -> bool:
	match feature:
		"service": return staff.any(func(s): return s.role == "Service")
		"expansion": return expanded
		"vip": return vip_enabled
		"high_limit": return high_limit_enabled
	return tables.any(func(t): return table_kind(t) == feature)

func next_milestone_text() -> String:
	if not restricted(): return "All games available. Add favorites through Build; keep cash for crews and payouts."
	for milestone in CasinoTuning.MILESTONES:
		if feature_owned(str(milestone.id)): continue
		var name: String = milestone.name if revealed(str(milestone.id)) else "???"
		if not unlocked(str(milestone.id)):
			return blackjack_progress_text() if milestone.id == "blackjack" else "Next: %s | Development Rating %.1f / %.0f." % [name, casino_rating, milestone.rating]
		var crew_note := ""
		if Games.COSTS.has(milestone.id) and milestone.id != "slots":
			crew_note = " + %d dealer(s) at $%d each" % [2 if milestone.id == "craps" else 1, CasinoTuning.HIRING_COST]
		return "Next: %s | $%d%s. Treasury: $%d." % [name, feature_cost(str(milestone.id)), crew_note, cash]
	return "Your gaming catalog is complete. Grow the floor and protect your operating reserve."

func onboarding_text() -> String:
	if not restricted():
		return "Open your chosen games, watch the guests, and manage crews and cash. Walk to a game to play with your separate visitor wallet."
	if not ever_opened: return "1. Open the casino. Your two slots need no staff."
	if guest_rounds == 0: return "2. Watch the first guest play a slot. Arrivals begin after 10 open minutes."
	if guest_revenue < CasinoTuning.OPENING_REVENUE:
		return "3. Collect $%d in guest wagers: $%.0f so far. Payouts and costs reduce your profit." % [CasinoTuning.OPENING_REVENUE, guest_revenue]
	if not feature_owned("blackjack"):
		return "4. Develop capacity with better slots, serve gamblers and retain an operating reserve. Blackjack: $%d + dealer $%d; suggested payout/payroll reserve $%d." % [Games.COSTS.blackjack, CasinoTuning.HIRING_COST, CasinoTuning.BLACKJACK_RESERVE]
	if not feature_owned("service"):
		return "Your first table needs one dealer. Drink service is the next step; staff cost $%d plus hourly wages." % CasinoTuning.HIRING_COST
	return "Grow at your own pace. Cash pays for purchases; developed capacity and guest business earn access."

func slot_profile(table: Dictionary) -> Dictionary:
	return CasinoTuning.slot_profile(str(table.slot_profile))

func slot_unlocked(profile_id: String) -> bool:
	if not CasinoTuning.SLOT_PROFILES.has(profile_id): return false
	return not restricted() or profile_id in slot_access or (OS.is_debug_build() and "slot:" + profile_id in debug_forced_unlocks)

func purchase_cost(kind: String, profile_id: String = "starter") -> float:
	return float(CasinoTuning.SLOT_PROFILES[profile_id].cost) if kind == "slots" else float(Games.COSTS[kind])

func asset_name(table: Dictionary) -> String:
	return str(slot_profile(table).name) if table_kind(table) == "slots" else str(Games.NAMES[table_kind(table)])

func repair_cost(table: Dictionary) -> float:
	return float(slot_profile(table).repair_cost) if table_kind(table) == "slots" else CasinoTuning.TABLE_REPAIR_COST

func progression_targets() -> Array:
	var targets: Array = CasinoTuning.MILESTONES.duplicate(true)
	for id in CasinoTuning.SLOT_PROFILES:
		if id == "starter": continue
		var profile: Dictionary = CasinoTuning.SLOT_PROFILES[id]
		targets.append({"id": "slot:" + id, "name": profile.name, "rating": profile.unlock_rating, "handle": profile.unlock_handle})
	targets.sort_custom(func(a, b): return float(a.rating) < float(b.rating))
	return targets

func slot_progress_text(profile_id: String) -> String:
	var profile: Dictionary = CasinoTuning.SLOT_PROFILES[profile_id]
	return "Rating %.1f/%.0f | guest handle $%.0f/$%.0f" % [casino_rating, profile.unlock_rating, guest_handle, profile.unlock_handle]

func maximum_wager(table: Dictionary) -> float:
	return float(slot_profile(table).maximum) if table_kind(table) == "slots" else float(CasinoTuning.GAME_LIMITS[table_kind(table)].maximum)

func wager_limits(table: Dictionary) -> Array:
	if table_kind(table) == "slots": return slot_profile(table).denominations
	var limits: Array = CasinoTuning.GAME_LIMITS[table_kind(table)].limits
	return limits if high_limit_enabled else limits.filter(func(value): return float(value) < 50.0)

func gaming_development(usable_only: bool = false) -> float:
	var profile_values: Dictionary = {}
	var other := 0.0
	var kinds: Array = []
	for table in tables:
		if usable_only and not ready_for_play(table): continue
		var kind := table_kind(table)
		if kind == "slots":
			var id := str(table.slot_profile)
			profile_values[id] = float(profile_values.get(id, 0)) + float(slot_profile(table).development)
		elif kind not in kinds:
			other += float(CasinoTuning.DEVELOPMENT_VALUES[kind])
			kinds.append(kind)
	var slots := 0.0
	for id in profile_values:
		slots += minf(float(profile_values[id]), float(CasinoTuning.SLOT_PROFILES[id].development_cap))
	return minf(slots, CasinoTuning.SLOT_DEVELOPMENT_CAP) + other

func usable_gaming_capacity() -> int:
	var seats := 0
	for table in tables:
		if ready_for_play(table): seats += capacity(table)
	return seats

func development_cash() -> float:
	# Owner gambling losses cannot manufacture financial readiness. Pending
	# stakes are liabilities, not earned operating reserves.
	var visitor_stakes := 0.0
	for table in tables:
		visitor_stakes += CrapsRules.exposure(table.owner)
		for stake in table.roulette_bets.values(): visitor_stakes += float(stake)
		if game_pending(table): visitor_stakes += float(table.round.get("staked", 0))
	return cash - live_stakes() + minf(0, visitor_net + visitor_stakes)

func blackjack_ready() -> bool:
	var goal: Dictionary = CasinoTuning.BLACKJACK_REQUIREMENTS
	return casino_rating >= float(goal.rating) and gaming_development(true) >= float(goal.development) and usable_gaming_capacity() >= int(goal.capacity) and guest_handle >= float(goal.handle) and guests_served >= int(goal.guests) and development_cash() >= float(goal.cash)

func blackjack_progress_text() -> String:
	var goal: Dictionary = CasinoTuning.BLACKJACK_REQUIREMENTS
	return "Next: Blackjack | floor %.0f/%.0f | seats %d/%d | guest handle $%.0f/$%d | served %d/%d | Rating %.1f/%.0f | reserve $%.0f/$%d" % [gaming_development(true), goal.development, usable_gaming_capacity(), goal.capacity, guest_handle, goal.handle, guests_served, goal.guests, casino_rating, goal.rating, development_cash(), goal.cash]

func property_development() -> float:
	var development := gaming_development()
	if expanded: development += 4.0
	if vip_enabled: development += 4.0
	if high_limit_enabled: development += 4.0
	if feature_owned("service"): development += 2.0
	return development

func rating_for_activity(handle: float, served: int) -> float:
	var development := property_development()
	return minf(100, development * 2.0 + minf(development, handle / CasinoTuning.RATING_HANDLE_UNIT) + minf(development, served / CasinoTuning.RATING_GUEST_UNIT))

func refresh_progression() -> void:
	var before := casino_rating
	var previous_stars := stars()
	casino_rating = rating_for_activity(guest_handle, guests_served)
	if stars() > previous_stars:
		log_event("DEVELOPMENT - Casino rating increased to %d stars." % stars())
	for id in CasinoTuning.SLOT_PROFILES:
		var profile: Dictionary = CasinoTuning.SLOT_PROFILES[id]
		if id not in slot_access and casino_rating >= float(profile.unlock_rating) and guest_handle >= float(profile.unlock_handle):
			slot_access.append(id)
			if restricted(): log_event("Unlocked: %s. Purchase through Build; retain payout reserves." % profile.name)
	if not restricted(): return
	if not blackjack_unlocked and blackjack_ready():
		blackjack_unlocked = true
		log_event("Unlocked: Blackjack. Table $%d + dealer $%d; aim to retain $%d for payroll and payouts. Purchase when ready." % [Games.COSTS.blackjack, CasinoTuning.HIRING_COST, CasinoTuning.BLACKJACK_RESERVE])
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id not in ["slots", "blackjack"] and before < float(milestone.rating) and unlocked(str(milestone.id)):
			log_event("Unlocked: %s. Purchase through Build / Staff." % milestone.name)

func record_guest_round(guest: Dictionary, stake: float) -> void:
	if stake <= 0: return
	guest_rounds += 1
	guest_handle += stake
	guest.rounds += 1

func guest_wager(table: Dictionary, guest: Dictionary) -> float:
	var desired := float(table.minimum) * (2 if guest.vip else 1)
	if table_kind(table) == "slots":
		var eligible: Array = slot_profile(table).denominations.filter(func(value): return float(value) >= float(table.minimum) and float(value) <= float(guest.wager_limit) and float(value) <= float(guest.wallet))
		if not eligible.is_empty(): desired = float(eligible.back())
	return minf(desired, minf(maximum_wager(table), float(guest.wager_limit)))

func build_area() -> Rect2:
	return CasinoTuning.FULL_BUILD_AREA if expanded else CasinoTuning.STARTER_BUILD_AREA

func purchase_upgrade(feature: String) -> bool:
	if feature not in ["expansion", "vip", "high_limit"] or feature_owned(feature) or not unlocked(feature): return false
	var cost := feature_cost(feature)
	if cash < cost:
		log_event("This upgrade needs $%d in casino cash." % cost)
		return false
	spend_nonpayroll(cost, "construction")
	match feature:
		"expansion": expanded = true
		"vip": vip_enabled = true
		"high_limit": high_limit_enabled = true
	refresh_progression()
	log_event("Purchased: %s." % feature.replace("_", " "))
	return true

func change_minimum(id: int) -> bool:
	var table := get_table(id)
	if table.is_empty() or busy(table):
		log_event("Change limits when the game is empty.")
		return false
	var limits := wager_limits(table)
	table.minimum = limits[(limits.find(float(table.minimum)) + 1) % limits.size()]
	return true

func new_table(at: Vector2, rotated: bool, kind: String = "craps", profile_id: String = "starter") -> Dictionary:
	var item := {"kind": kind, "slot_profile": profile_id if kind == "slots" else "", "round": {}, "roulette_bets": {}, "id": next_id, "x": at.x, "y": at.y, "rotated": rotated, "point": 0, "dice": [1, 1], "timer": 0.0, "wagers": 0.0, "payouts": 0.0, "broken": false, "rolls": 0, "shooter": -1, "shooter_seat": -1, "hand_rolls": 0, "owner_queued": false, "betting_hold": false, "owner_working": false, "history": [], "service_minutes": 0, "available_minutes": 0, "occupied_minutes": 0, "downtime_minutes": 0, "operating_expense": 0.0, "repair_expense": 0.0, "payroll_expense": 0.0, "visitor_gaming_win": 0.0, "repairs": 0, "breakdowns": 0, "minimum": float(CasinoTuning.SLOT_PROFILES[profile_id].minimum) if kind == "slots" else float(CasinoTuning.GAME_LIMITS[kind].minimum), "owner": CrapsRules.empty_bets(), "result": "Come-out roll. Place a Pass Line bet to start." if kind == "craps" else "Ready for the first guest."}
	next_id += 1
	return item

func log_house_activity(message: String) -> void:
	house_activity.push_front(message)
	if house_activity.size() > CasinoTuning.HOUSE_ACTIVITY_LIMIT: house_activity.pop_back()

func log_event(message: String, management: bool = true) -> void:
	if management: log_house_activity(message)
	alerts.push_front(message)
	if alerts.size() > 8:
		alerts.pop_back()

func emit_financial_event(amount: float, category: String, table: Dictionary = {}, guest_id: int = -1, details: Dictionary = {}) -> void:
	# A reusable transaction hook for floor feedback and later audio/milestones.
	# Gaming callers supply resolved stakes minus total credit, never gross cash flow.
	financial_sequence += 1
	var event := {"sequence": financial_sequence, "amount": amount, "category": category, "game": table_kind(table) if not table.is_empty() else "", "asset_id": int(table.id) if not table.is_empty() else -1, "guest_id": guest_id, "actor": "visitor" if guest_id == 0 else ("guest" if guest_id > 0 else "aggregate"), "importance": CasinoTuning.money_importance(amount), "elapsed": elapsed, "position": bounds(table).get_center() if not table.is_empty() else Vector2.ZERO}
	event.merge(details, true)
	if category == "gaming":
		recent_financial_events.push_front(event.duplicate(true))
		if recent_financial_events.size() > CasinoTuning.MONEY_HISTORY_LIMIT: recent_financial_events.pop_back()
	if category == "gaming" and absf(amount) >= CasinoTuning.HOUSE_ACTIVITY_GAMING_THRESHOLD:
		log_house_activity("%s #%d - House %s $%.2f" % [str(Games.NAMES[event.game]).to_upper().replace("’", "'"), event.asset_id, "won" if amount > 0 else "lost", absf(amount)])
	financial_event.emit(event)

func emit_gaming_result(table: Dictionary, staked: float, returned: float, guest_id: int, participants: Array = []) -> void:
	if staked <= 0 and returned <= 0: return # No resolved activity: no invented result.
	if guest_id == 0: table.visitor_gaming_win += staked - returned
	emit_financial_event(staked - returned, "gaming", table, guest_id, {"settled_stake": staked, "returned": returned, "asset_wagers": float(table.wagers), "asset_payouts": float(table.payouts), "asset_repair_expense": float(table.repair_expense), "asset_operating_expense": float(table.operating_expense), "asset_payroll_expense": float(table.payroll_expense), "asset_available_minutes": int(table.available_minutes), "asset_occupied_minutes": int(table.occupied_minutes), "asset_downtime_minutes": int(table.downtime_minutes), "participants": participants.duplicate(true), "slot_profile": str(table.slot_profile) if table_kind(table) == "slots" else "", "round": int(table.rolls) + 1})

func get_table(id: int) -> Dictionary:
	for table in tables:
		if int(table.id) == id:
			return table
	return {}

func crew(id: int) -> Array:
	return staff.filter(func(s): return s.role == "Dealer" and int(s.table) == id)

func seated(id: int) -> Array:
	return guests.filter(func(g): return int(g.table) == id and g.state == "Playing")

func table_kind(table: Dictionary) -> String:
	return str(table.get("kind", ""))

func required_crew(table: Dictionary) -> int:
	return 0 if table_kind(table) == "slots" else (2 if table_kind(table) == "craps" else 1)

func capacity(table: Dictionary) -> int:
	return 1 if table_kind(table) == "slots" else 8

func guest_capacity(table: Dictionary) -> int:
	# Table games reserve an owner rail seat; slots only do so when joined.
	var owner_seats := 1 if table_kind(table) != "slots" or joined == int(table.id) else 0
	return maxi(0, capacity(table) - owner_seats)

func game_pending(table: Dictionary) -> bool:
	return not table.get("round", {}).is_empty() and table.round.get("phase", "done") != "done"

func ready_for_play(table: Dictionary) -> bool:
	return not table.is_empty() and not table.broken and crew(int(table.id)).size() >= required_crew(table)

func operating(table: Dictionary) -> bool:
	return opened and ready_for_play(table)

func table_status(table: Dictionary) -> String:
	if table.broken:
		return "Repair needed"
	if crew(int(table.id)).size() < required_crew(table):
		return "Needs %d dealers" % (required_crew(table) - crew(int(table.id)).size())
	return "Open" if opened else "Doors closed · owner play available"

func hire(role: String, target: int) -> bool:
	if role not in ["Dealer", "Service"]: return false
	if (role == "Service" and not unlocked("service")) or (role == "Dealer" and not unlocked("blackjack")):
		log_event("Develop the casino and complete the next unlock requirements for this staff role.")
		return false
	if staff.size() >= 16:
		log_event("Staff limit reached for this small casino.")
		return false
	if cash < CasinoTuning.HIRING_COST:
		log_event("Hiring needs $%d for training." % CasinoTuning.HIRING_COST)
		return false
	spend_nonpayroll(CasinoTuning.HIRING_COST, "hiring")
	var assignment := -1
	if role == "Dealer":
		if not get_table(target).is_empty() and crew(target).size() < required_crew(get_table(target)):
			assignment = target
		else:
			for table in tables:
				if crew(int(table.id)).size() < required_crew(table):
					assignment = int(table.id)
					break
	staff.append({"name": CasinoTuning.NAMES[rng.randi_range(0, 11)], "role": role, "table": assignment, "energy": 100.0})
	refresh_progression()
	log_event("%s hired. %s" % [role, "Assigned to table %d." % assignment if assignment > 0 else "Covering the floor / on standby."])
	return true

func assign_standby(id: int) -> void:
	for employee in staff:
		if employee.role == "Dealer" and int(employee.table) == -1 and crew(id).size() < required_crew(get_table(id)):
			employee.table = id
	log_event("Table %d has %d / %d dealers." % [id, crew(id).size(), required_crew(get_table(id))])

func bounds(table: Dictionary) -> Rect2:
	var size := furniture_size(table_kind(table), bool(table.rotated))
	return Rect2(Vector2(table.x, table.y), size)

func furniture_size(kind: String, rotated: bool) -> Vector2:
	var dimensions := Vector2(60, 70) if kind == "slots" else (CasinoTuning.CRAPS_SIZE if kind == "craps" else CasinoTuning.TABLE_SIZE)
	return Vector2(dimensions.y, dimensions.x) if rotated else dimensions

func can_place(at: Vector2, rotated: bool, ignore_id: int = -1, kind: String = "craps") -> bool:
	if ignore_id >= 0: kind = table_kind(get_table(ignore_id))
	var size := furniture_size(kind, rotated)
	var rect := Rect2(at, size)
	if not build_area().encloses(rect):
		return false
	for table in tables:
		if int(table.id) != ignore_id and rect.grow(22).intersects(bounds(table)):
			return false
	return true

func place(at: Vector2, rotated: bool, kind: String = "craps", profile_id: String = "starter") -> int:
	if not Games.COSTS.has(kind): return -1
	if kind == "slots" and not slot_unlocked(profile_id):
		log_event("Develop the casino and guest business to unlock this machine.")
		return -1
	if not unlocked(kind):
		log_event("Complete the casino development requirements to unlock this game.")
		return -1
	var cost := purchase_cost(kind, profile_id)
	if not can_place(at, rotated, -1, kind) or cash < cost:
		log_event("Placement needs $%d, clear space and an aisle." % cost)
		return -1
	spend_nonpayroll(cost, "construction")
	var table := new_table(at, rotated, kind, profile_id)
	tables.append(table)
	refresh_progression()
	reroute()
	emit_financial_event(-cost, "construction", table)
	log_event("%s #%d built for $%d. Required dealers: %d." % [asset_name(table), table.id, cost, required_crew(table)])
	if kind == "slots" and cash < float(slot_profile(table).reserve): log_event("RESERVE - %s suggests $%d operating reserve; treasury $%d." % [asset_name(table), slot_profile(table).reserve, cash])
	return int(table.id)

func busy(table: Dictionary) -> bool:
	return joined == int(table.id) or guests.any(func(g): return int(g.table) == int(table.id)) or CrapsRules.exposure(table.owner) > 0 or game_pending(table) or not table.get("roulette_bets", {}).is_empty()

func sell(id: int) -> bool:
	var table := get_table(id)
	if table.is_empty() or busy(table):
		log_event("Let guests leave and settle visitor bets before selling this table.")
		return false
	for employee in crew(id):
		employee.table = -1
	table_interest.erase(int(table.id))
	tables.erase(table)
	incidents = incidents.filter(func(incident): return int(incident.table) != id)
	var resale := (float(slot_profile(table).cost) if table_kind(table) == "slots" else float(Games.COSTS[table_kind(table)])) / 2
	spend_nonpayroll(-resale, "sales")
	emit_financial_event(resale, "sale", table, -1, {"asset_wagers": table.wagers, "asset_payouts": table.payouts, "asset_repair_expense": table.repair_expense, "asset_operating_expense": table.operating_expense, "asset_payroll_expense": table.payroll_expense, "asset_visitor_gaming_win": table.visitor_gaming_win, "asset_spins": table.rolls, "asset_available_minutes": table.available_minutes, "asset_occupied_minutes": table.occupied_minutes, "asset_downtime_minutes": table.downtime_minutes, "slot_profile": table.slot_profile})
	refresh_progression()
	log_event("Sold for $%d. Dealers are now on standby." % resale)
	return true

func set_open(value: bool) -> void:
	opened = value
	if value: ever_opened = true
	if not value:
		if joined >= 0: leave_table()
		log_event("Doors closed to new guests. Existing bets will finish before guests leave.")
	else:
		log_event("Doors open. The evening crowd is on its way.")

func archetype(guest: Dictionary) -> Dictionary:
	return CasinoTuning.GUEST_ARCHETYPES[str(guest.archetype)]

func choose_archetype(vip: bool) -> String:
	if vip: return "vip"
	var weights: Dictionary = CasinoTuning.STARTER_ARCHETYPE_WEIGHTS if restricted() and casino_rating < 16 else CasinoTuning.DEVELOPED_ARCHETYPE_WEIGHTS
	var pick := rng.randi_range(1, 100)
	for id in weights:
		pick -= int(weights[id])
		if pick <= 0: return str(id)
	return "casual"

func think(guest: Dictionary, text: String, priority: int = 1) -> void:
	text = text.replace("’", "'").replace(" · ", " / ")
	guest.thought = text
	var last: Dictionary = thought_last.get(int(guest.id), {})
	if not last.is_empty():
		if last.text == text and elapsed - int(last.minute) < 30: return
		if elapsed - int(last.minute) < CasinoTuning.THOUGHT_GAME_COOLDOWN and priority <= int(last.priority): return
	thought_last[int(guest.id)] = {"text": text, "minute": elapsed, "priority": priority}
	if thought_last.size() > CasinoTuning.THOUGHT_HISTORY_LIMIT: thought_last.erase(thought_last.keys()[0])
	guest_thought.emit({"guest_id": int(guest.id), "text": text, "priority": priority, "position": Vector2(guest.x, guest.y), "elapsed": elapsed})

func note_guest_wager(table: Dictionary, guest: Dictionary, amount: float) -> void:
	if amount <= 0: return
	guest.last_wager_minute = elapsed
	var recent: Array = table_interest.get(int(table.id), [])
	recent = recent.filter(func(item): return elapsed - int(item.minute) <= CasinoTuning.HOT_ACTIVITY_MINUTES)
	recent.append({"minute": elapsed, "guest_id": int(guest.id)})
	if recent.size() > 64: recent.pop_front()
	table_interest[int(table.id)] = recent

func table_hot(table: Dictionary) -> bool:
	if table.is_empty() or table_kind(table) == "slots" or not operating(table) or seated(int(table.id)).size() < CasinoTuning.HOT_PLAYER_COUNT: return false
	var recent: Array = table_interest.get(int(table.id), [])
	var count := 0
	var players := {}
	for item in recent:
		if elapsed - int(item.minute) <= CasinoTuning.HOT_ACTIVITY_MINUTES:
			count += 1
			players[item.guest_id] = true
	return count >= CasinoTuning.HOT_WAGER_COUNT and players.size() >= CasinoTuning.HOT_PLAYER_COUNT

func spawn_guest(vip: bool = false) -> void:
	if guests.size() >= CasinoTuning.MAX_GUESTS:
		return
	var budget: Dictionary = CasinoTuning.GUEST_BUDGETS[0]
	for level in CasinoTuning.GUEST_BUDGETS:
		if not restricted() or casino_rating >= float(level.rating): budget = level
	var archetype_id := choose_archetype(vip)
	var profile: Dictionary = CasinoTuning.GUEST_ARCHETYPES[archetype_id]
	var bankroll := float(rng.randi_range(budget.bankroll.x, budget.bankroll.y)) if not vip else 5000.0
	if not vip: bankroll = clampf(roundf(bankroll * float(profile.bankroll_scale)), budget.bankroll.x, budget.bankroll.y)
	guests.append({"archetype": archetype_id, "id": next_id, "name": CasinoTuning.NAMES[rng.randi_range(0, 11)] + (" · VIP" if vip else ""), "x": 425.0, "y": 565.0, "tx": 425.0, "ty": 510.0, "table": -1, "seat": -1, "state": "Arriving", "wallet": bankroll, "start": bankroll, "rounds": 0, "last_wager_minute": -1, "drink_spending": 0.0, "wager_limit": 100.0 if vip else float(budget.wager), "satisfaction": 80.0, "thirst": 0.0, "age": 0, "session_left": 0.0, "activities": 0, "activity_since": elapsed, "decision_at": elapsed + rng.randi_range(1, 5), "wait_since": -1, "last_table": -1, "explored_without_game": false, "preference": profile.games[rng.randi_range(0, profile.games.size() - 1)], "patience": rng.randi_range(profile.patience.x, profile.patience.y), "watch_left": 0, "watch_style": rng.randi_range(0, 2), "vip": vip, "bets": CrapsRules.empty_bets(), "thought": "Looking for an open game."})
	think(guests[-1], "I came here for %s." % str(Games.NAMES[guests[-1].preference]).replace("Ultimate Texas Hold’em", "hold'em").to_lower())
	next_id += 1

func arrival_step() -> void:
	if not opened: return
	arrival_in -= 1
	if arrival_in > 0: return
	var interval := CasinoTuning.ARRIVAL_MINUTES if minute >= 1080 and minute < 1440 else CasinoTuning.QUIET_ARRIVAL_MINUTES
	arrival_in = rng.randi_range(interval.x, interval.y)
	var gaming_positions := 0
	for table in tables:
		if operating(table): gaming_positions += guest_capacity(table)
	# Keep occasional unmet demand visible even when every position is occupied.
	var extra_visitors := maxi(1, ceili(gaming_positions * CasinoTuning.ARRIVAL_OVERFLOW_RATIO))
	var floor_capacity := mini(CasinoTuning.MAX_GUESTS, gaming_positions + extra_visitors)
	var browsing := guests.filter(func(g): return g.state in ["Arriving", "Waiting", "Browsing", "Watching", "Exploring", "Seeking drink", "Getting drink"]).size()
	if browsing >= extra_visitors or guests.size() >= floor_capacity: return
	var party := 2 if rng.randf() < 0.35 else 1
	for i in range(mini(party, floor_capacity - guests.size())):
		var vip := vip_enabled and rng.randf() < 0.05
		spawn_guest(vip)
		if vip: log_event("A VIP arrived with the next small group.")

func observation_spot(table: Dictionary, id: int) -> Vector2:
	var rect := bounds(table)
	var offset := float(id % 3 - 1) * 32
	var spots := [Vector2(rect.get_center().x + offset, rect.end.y + 60), Vector2(rect.get_center().x + offset, rect.position.y - 60), Vector2(rect.end.x + 55, rect.get_center().y + offset), Vector2(rect.position.x - 55, rect.get_center().y + offset)]
	for at in spots:
		if Rect2(30, 100, 790, 450).has_point(at) and not tables.any(func(t): return bounds(t).grow(16).has_point(at)):
			return at
	return Vector2(-1, -1)

func watching_step(guest: Dictionary) -> void:
	var table := get_table(int(guest.table))
	if not opened or table.is_empty() or not operating(table):
		if opened: start_guest_exploration(guest)
		else: leave(guest, "The casino is closing.")
		return
	var reserved := guests.filter(func(other): return other != guest and int(other.table) == int(table.id) and int(other.seat) >= 0).size()
	if guest.preference == table_kind(table) and affordable_game(table, guest) and reserved < guest_capacity(table) and elapsed - int(guest.activity_since) >= 2:
		think(guest, "A seat opened. I'll play.", 2)
		choose_table(guest, false)
		return
	guest.watch_left = maxi(0, int(guest.watch_left) - 1)
	var hot := table_hot(table)
	var reset: bool = not table.history.is_empty() and bool(table.history[0].seven_out)
	think(guest, "Watching the table before deciding.")
	if hot: think(guest, "This table is getting hot.", 2)
	elif reset: think(guest, "Seven-out. Watching the new shooter.")
	if int(guest.watch_left) > 0: return
	# This is guest psychology only; history never changes the dice probabilities.
	var chance := 0.70
	if int(guest.watch_style) == 1: chance = 0.90 if hot else (0.30 if reset else 0.55)
	elif int(guest.watch_style) == 2: chance = 0.85 if reset or int(table.point) == 0 else 0.45
	if rng.randf() < chance:
		choose_table(guest, false)
	else:
		finish_guest_session(guest)

func affordable_game(table: Dictionary, guest: Dictionary) -> bool:
	if table.is_empty() or not operating(table) or guest.wager_limit < table.minimum: return false
	var wager := guest_wager(table, guest)
	return wager >= float(table.minimum) and guest.wallet >= wager * (6 if table_kind(table) == "holdem" else 1)

func game_choice_score(table: Dictionary, guest: Dictionary, reserved: int) -> float:
	var profile := archetype(guest)
	var value := 100.0 + (float(profile.preference_bonus) if guest.preference == table_kind(table) else 0.0)
	value -= Vector2(guest.x, guest.y).distance_to(bounds(table).get_center()) * 0.08
	value += reserved * 2.0
	if table_kind(table) == "slots":
		value += (float(slot_profile(table).appeal) - 1.0) * CasinoTuning.GUEST_APPEAL_WEIGHT + float(slot_profile(table).prestige) * float(profile.quality)
		if guest.archetype == "tables": value *= 0.45
	if table_hot(table): value += float(profile.hot_interest)
	if int(guest.last_table) == int(table.id): value += 8.0 if guest.archetype in ["regular", "slots"] else -8.0
	return value

func session_length(guest: Dictionary) -> int:
	var span: Vector2i = CasinoTuning.GUEST_VISITS[str(guest.archetype)].session
	return rng.randi_range(span.x, span.y)

func release_guest_seat(guest: Dictionary) -> void:
	if int(guest.table) > 0: guest.last_table = int(guest.table)
	guest.table = -1
	guest.seat = -1
	guest.wait_since = -1
	guest.activity_since = elapsed

func start_guest_exploration(guest: Dictionary, drink: bool = false) -> void:
	release_guest_seat(guest)
	guest.state = "Seeking drink" if drink else "Exploring"
	guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_EXPLORE_MINUTES.x, CasinoTuning.GUEST_EXPLORE_MINUTES.y)
	# A purposeful short walk through reachable aisles; no indefinite wandering.
	var area := CasinoTuning.STARTER_BUILD_AREA if not expanded else Rect2(45, 110, 740, 400)
	var target := Vector2(guest.x, guest.y)
	for attempt in range(12):
		var candidate := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if not tables.any(func(table): return bounds(table).grow(20).has_point(candidate)):
			target = candidate
			break
	guest.tx = target.x
	guest.ty = target.y
	route(guest)
	think(guest, "I'll find a drink." if drink else "I'll look around.", 2)

func guest_exit_reason(guest: Dictionary) -> String:
	if not opened: return "The casino is closing."
	if guest.satisfaction < 25: return "I need a drink. I'm leaving." if guest.thirst > CasinoTuning.THIRST_DISCOMFORT else "Not my night. I'm leaving."
	if not tables.any(func(table): return affordable_game(table, guest)): return "No affordable games for me."
	return ""

func finish_guest_session(guest: Dictionary) -> void:
	# Call only after contracts/hand stakes settle. Time alone never removes a bettor.
	guest.activities += 1
	var reason := guest_exit_reason(guest)
	if not reason.is_empty():
		if opened and guest.satisfaction >= 25 and not guest.explored_without_game:
			guest.explored_without_game = true
			start_guest_exploration(guest)
		else: leave(guest, reason)
		return
	var bankroll_fraction := float(guest.wallet) / maxf(1, float(guest.start))
	var chance := CasinoTuning.GUEST_DEPARTURE_BASE + int(guest.activities) * CasinoTuning.GUEST_ACTIVITY_DEPARTURE
	chance += 0.18 if bankroll_fraction < 0.25 else 0.0
	chance += 0.15 if guest.satisfaction < 55 else -0.07 if guest.satisfaction > 80 else 0.0
	chance += minf(0.45, maxf(0, float(guest.age) - CasinoTuning.GUEST_VISIT_FATIGUE_START) / CasinoTuning.GUEST_VISIT_FATIGUE_SPAN)
	if guest.wallet + guest.drink_spending > guest.start: chance -= 0.04
	chance *= float(CasinoTuning.GUEST_VISITS[str(guest.archetype)].departure)
	if rng.randf() < clampf(chance, 0.02, 0.85):
		leave(guest, "Time to cash out." if guest.rounds > 0 else "I'm done for tonight.")
		return
	if guest.thirst >= CasinoTuning.DRINK_THIRST_TRIGGER and feature_owned("service") and guest.wallet >= float(CasinoTuning.DRINK_PROFILES.basic.price):
		start_guest_exploration(guest, true)
		return
	# Reconsider even if the guest elects to return to a familiar game.
	release_guest_seat(guest)
	if rng.randf() < float(CasinoTuning.GUEST_VISITS[str(guest.archetype)].explore): start_guest_exploration(guest)
	else:
		guest.state = "Waiting"
		guest.decision_at = elapsed + rng.randi_range(1, 3)
		think(guest, "Maybe another game.", 2)

func guest_lifecycle_step(guest: Dictionary) -> void:
	if guest.state in ["To cage", "Cashing out", "Leaving"]: return
	if guest.state == "Playing":
		guest.session_left = maxf(0, float(guest.session_left) - 1)
		var table := get_table(int(guest.table))
		if CrapsRules.exposure(guest.bets) > 0 or game_pending(table): return
		if not opened or guest.satisfaction < 25:
			leave(guest, guest_exit_reason(guest))
		elif not affordable_game(table, guest) or guest.session_left <= 0:
			finish_guest_session(guest)
		return
	if not opened:
		leave(guest, "The casino is closing.")
		return
	if guest.satisfaction < 25:
		leave(guest, guest_exit_reason(guest))
		return
	if guest.state == "Watching":
		watching_step(guest)
	elif guest.state == "Walking" and elapsed - int(guest.activity_since) > guest.patience:
		leave(guest, "Could not reach that game.")
	elif guest.state == "Browsing" and elapsed - int(guest.activity_since) > guest.patience:
		start_guest_exploration(guest)
	elif guest.state == "Exploring" and elapsed >= int(guest.decision_at):
		if elapsed - int(guest.activity_since) > guest.patience:
			leave(guest, "Couldn't find a comfortable route.")
		elif Vector2(guest.x, guest.y).distance_to(Vector2(guest.tx, guest.ty)) < 3: choose_table(guest)
	elif guest.state == "Seeking drink" and elapsed - int(guest.activity_since) > guest.patience:
		leave(guest, "Couldn't reach drink service.")
	elif guest.state == "Getting drink" and (guest.thirst < CasinoTuning.DRINK_THIRST_TRIGGER or elapsed >= int(guest.decision_at)):
		think(guest, "Back to the games." if guest.thirst < CasinoTuning.DRINK_THIRST_TRIGGER else "I'll try something else.", 2)
		choose_table(guest)
	elif guest.state == "Waiting" and elapsed >= int(guest.decision_at):
		guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_DECISION_GAP.x, CasinoTuning.GUEST_DECISION_GAP.y)
		choose_table(guest)

func choose_table(guest: Dictionary, allow_watch: bool = true) -> void:
	var best: Dictionary = {}
	var score := -INF
	for table in tables:
		# Include guests still walking to their reserved seats.
		var reserved := guests.filter(func(g): return int(g.table) == int(table.id) and int(g.seat) >= 0 and g != guest).size()
		if not affordable_game(table, guest) or (reserved >= guest_capacity(table) and not allow_watch): continue
		var value := game_choice_score(table, guest, reserved)
		if reserved >= guest_capacity(table): value -= 10000.0
		if value > score:
			score = value
			best = table
	if best.is_empty():
		# A bounded observation activity can be worthwhile without a table bankroll.
		if allow_watch and not guest.explored_without_game:
			for table in tables:
				if not operating(table) or table_kind(table) == "slots" or seated(int(table.id)).is_empty(): continue
				var watchers := guests.filter(func(other): return int(other.table) == int(table.id) and other.state in ["Browsing", "Watching"]).size()
				var spot := observation_spot(table, int(guest.id))
				if watchers >= CasinoTuning.OBSERVERS_PER_TABLE or spot.x < 0: continue
				guest.explored_without_game = true
				guest.table = int(table.id)
				guest.seat = -1
				guest.state = "Browsing"
				guest.activity_since = elapsed
				guest.watch_left = rng.randi_range(6, 12)
				guest.tx = spot.x
				guest.ty = spot.y
				route(guest)
				think(guest, "I'll watch. These stakes are too high for me.", 2)
				return
		guest.state = "Waiting"
		think(guest, "No affordable, staffed seat available.")
		if int(guest.wait_since) < 0: guest.wait_since = elapsed
		if elapsed - int(guest.wait_since) > guest.patience or not opened:
			leave(guest, "Couldn't find an open game.")
		return
	var observers := guests.filter(func(g): return int(g.table) == int(best.id) and g.state in ["Browsing", "Watching"]).size()
	var seats := guests.filter(func(g): return int(g.table) == int(best.id) and int(g.seat) >= 0 and g != guest).size()
	var spot := observation_spot(best, int(guest.id))
	var watch_chance := float(archetype(guest).watch_chance)
	if guest.preference == table_kind(best) and table_kind(best) != "craps": watch_chance *= 0.15
	var intentional_watch: bool = seats >= guest_capacity(best) or (not seated(int(best.id)).is_empty() and rng.randf() < watch_chance)
	if allow_watch and table_kind(best) != "slots" and observers < CasinoTuning.OBSERVERS_PER_TABLE and spot.x >= 0 and intentional_watch:
		guest.table = int(best.id)
		guest.seat = -1
		guest.state = "Browsing"
		guest.activity_since = elapsed
		guest.wait_since = -1
		guest.watch_left = rng.randi_range(4, 10) if seats < guest_capacity(best) else rng.randi_range(CasinoTuning.OBSERVE_MINUTES.x, CasinoTuning.OBSERVE_MINUTES.y)
		guest.tx = spot.x
		guest.ty = spot.y
		think(guest, "Watching %s before buying in." % Games.NAMES[table_kind(best)])
		route(guest)
		return
	if seats >= guest_capacity(best):
		if table_kind(best) == "slots" and bool(archetype(guest).wait_for_slots) and (int(guest.wait_since) < 0 or elapsed - int(guest.wait_since) < guest.patience):
			guest.table = -1
			guest.seat = -1
			guest.state = "Waiting"
			if int(guest.wait_since) < 0: guest.wait_since = elapsed
			think(guest, "All the machines are taken. I'll wait.", 3)
			return
		leave(guest, "All the machines are taken. I'll come back later." if table_kind(best) == "slots" else "The rail is crowded. I'll come back later.")
		return
	guest.table = int(best.id)
	guest.state = "Walking"
	guest.activity_since = elapsed
	guest.wait_since = -1
	guest.session_left = session_length(guest)
	var used_seats: Array = []
	for occupant in guests:
		if int(occupant.table) == int(best.id) and occupant != guest:
			used_seats.append(int(occupant.get("seat", -1)))
	var slot := 0
	while slot in used_seats:
		slot += 1
	guest.seat = slot
	var rect := bounds(best)
	guest.tx = rect.position.x + 22 + (slot % 4) * (rect.size.x - 44) / 3.0
	guest.ty = rect.position.y - 22 if slot < 4 else rect.end.y + 22
	if table_hot(best):
		think(guest, "This table is drawing a crowd.", 2)
	elif table_kind(best) == "slots" and guest.archetype in ["slots", "vip"]:
		think(guest, "I like this machine." if int(slot_profile(best).prestige) >= 3 else "I'd prefer a better machine." if guest.vip else "I wish they had better slots.", 2)
	elif guest.preference != table_kind(best):
		think(guest, "I'll try %s instead." % ("slots" if table_kind(best) == "slots" else "hold'em" if table_kind(best) == "holdem" else table_kind(best)))
	else:
		think(guest, "Found my preferred game.")
	route(guest)

func leave(guest: Dictionary, reason: String) -> void:
	if CrapsRules.exposure(guest.bets) > 0 or guest.state in ["To cage", "Cashing out", "Leaving"]:
		return
	if int(guest.rounds) > 0:
		guests_served += 1
		refresh_progression()
	guest.state = "To cage" if int(guest.rounds) > 0 else "Leaving"
	guest.table = -1
	guest.seat = -1
	guest.tx = CAGE_PICKUP.x if int(guest.rounds) > 0 else CasinoTuning.ENTRY.x
	guest.ty = CAGE_PICKUP.y if int(guest.rounds) > 0 else CasinoTuning.ENTRY.y
	think(guest, reason, 3)
	route(guest)
	reputation = clampf(reputation + (guest.satisfaction - 65.0) * 0.006, 0, 100)

func route(guest: Dictionary) -> void:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(2, 9, 81, 50)
	grid.cell_size = Vector2(10, 10)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	for table in tables:
		var rect := bounds(table).grow(9)
		for x in range(2, 83):
			for y in range(9, 59):
				if rect.has_point(Vector2(x * 10, y * 10)):
					grid.set_point_solid(Vector2i(x, y))
	var origin := Vector2i(roundi(guest.x / 10), roundi(guest.y / 10))
	var destination := Vector2i(roundi(guest.tx / 10), roundi(guest.ty / 10))
	var path: Array = []
	if grid.is_in_boundsv(origin) and grid.is_in_boundsv(destination):
		for at in grid.get_point_path(origin, destination):
			path.append([at.x, at.y])
	guest.path = path

func reroute() -> void:
	for employee in staff:
		if employee.role == "Service" and employee.has("service_state"): route(employee)
	for guest in guests:
		if guest.state in ["Arriving", "Walking", "Browsing", "Exploring", "Seeking drink", "To cage", "Leaving"]:
			route(guest)

func move_entity(entity: Dictionary, delta: float) -> Vector2:
	# Consume distance across waypoints, not one waypoint per frame/substep.
	# This avoids losing travel time at 0.1-second developer substeps.
	var at := Vector2(entity.x, entity.y)
	var target := Vector2(entity.tx, entity.ty)
	var distance := maxf(0, delta) * CasinoTuning.ENTITY_WALK_SPEED
	while distance > 0:
		var waypoint := Vector2(entity.path[0][0], entity.path[0][1]) if not entity.path.is_empty() else target
		var needed := at.distance_to(waypoint)
		if needed > distance:
			at = at.move_toward(waypoint, distance)
			break
		at = waypoint
		distance -= needed
		if entity.path.is_empty(): break
		entity.path.pop_front()
	entity.x = at.x
	entity.y = at.y
	return at

func move_guests(delta: float) -> void:
	move_service(delta)
	for effect in cashout_effects: effect.life -= delta
	cashout_effects = cashout_effects.filter(func(e): return e.life > 0)
	for guest in guests:
		if guest.state in ["To cage", "Cashing out"] and int(guest.rounds) == 0:
			# Never allow an unplayed wallet to produce a cage visit or cash-out effect.
			guest.state = "Waiting"
			leave(guest, "No games are available. I'll come back later.")
		if guest.state == "Cashing out":
			guest.cage_wait = float(guest.get("cage_wait", 2.0)) - delta
			if guest.cage_wait <= 0:
				var house_net := float(guest.start) - float(guest.wallet) - float(guest.drink_spending)
				cashout_effects.push_front({"name": guest.name, "net": house_net, "cash": guest.wallet, "life": 16.0})
				if cashout_effects.size() > 4: cashout_effects.pop_back()
				log_event("CAGE - %s cashed out $%.2f%s" % [guest.name, guest.wallet, " | VIP" if guest.vip else ""])
				# Wagers already settled against treasury. Do not pay/debit twice here.
				guest.state = "Leaving"
				guest.tx = CasinoTuning.ENTRY.x
				guest.ty = CasinoTuning.ENTRY.y
				think(guest, "Cashed out. Heading home.")
				route(guest)
			continue
		if guest.state not in ["Arriving", "Walking", "Browsing", "Exploring", "Seeking drink", "To cage", "Leaving"]:
			continue
		if guest.state == "Exploring" and Vector2(guest.x, guest.y).distance_to(Vector2(guest.tx, guest.ty)) < 3: continue
		# Hold at the exit until the next economic tick removes this guest.
		# Rerouting here can pull them back to the rounded navigation-grid point.
		if guest.state == "Leaving" and Vector2(guest.x, guest.y).distance_to(CasinoTuning.ENTRY) < 3:
			continue
		if not guest.has("path"):
			route(guest)
		var target := Vector2(guest.tx, guest.ty)
		var moved := move_entity(guest, delta)
		if moved.distance_to(target) < 2:
			guest.erase("path")
			if guest.state == "To cage":
				guest.state = "Cashing out"
				guest.cage_wait = 2.0
			elif guest.state == "Walking":
				guest.state = "Playing"
				think(guest, "Ready to play %s!" % Games.NAMES[table_kind(get_table(int(guest.table)))])
			elif guest.state == "Browsing":
				guest.state = "Watching"
				think(guest, "Watching the table before deciding.")
			elif guest.state == "Seeking drink":
				guest.state = "Getting drink"
				guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_DRINK_BREAK_MINUTES.x, CasinoTuning.GUEST_DRINK_BREAK_MINUTES.y)
			elif guest.state == "Arriving":
				guest.state = "Waiting"
				guest.decision_at = elapsed + rng.randi_range(1, 5)

func service_position(employee: Dictionary) -> void:
	if employee.has("service_state"): return
	employee.merge({"x": BAR_PICKUP.x, "y": BAR_PICKUP.y, "tx": BAR_PICKUP.x, "ty": BAR_PICKUP.y, "service_state": "At bar", "service_wait": CasinoTuning.DRINK_PREP_SECONDS, "service_target": -1}, true)

func send_to_bar(employee: Dictionary) -> void:
	employee.service_state = "To bar"
	employee.service_target = -1
	employee.tx = BAR_PICKUP.x
	employee.ty = BAR_PICKUP.y
	route(employee)

func gambling_comp_eligible(guest: Dictionary, profile: Dictionary) -> bool:
	# A seat or a wallet is not gambling. Only a successfully funded real wager counts.
	return bool(CasinoTuning.COMP_POLICY.basic_gambling_comps) and bool(profile.comp_eligible) and guest.state == "Playing" and int(guest.last_wager_minute) >= 0 and elapsed - int(guest.last_wager_minute) <= int(CasinoTuning.COMP_POLICY.recent_wager_minutes)

func wants_drink(guest: Dictionary) -> bool:
	if not opened or guest.state not in ["Playing", "Watching", "Waiting", "Getting drink"] or float(guest.thirst) < CasinoTuning.DRINK_THIRST_TRIGGER: return false
	var profile: Dictionary = CasinoTuning.DRINK_PROFILES.basic
	var price := 0.0 if gambling_comp_eligible(guest, profile) else float(profile.price)
	return float(guest.wallet) >= price and cash + price >= float(profile.cost)

func deliver_drink(guest: Dictionary, employee: Dictionary) -> void:
	# Recheck current state/eligibility/funds at delivery, not when the route started.
	if not wants_drink(guest): return
	var profile: Dictionary = CasinoTuning.DRINK_PROFILES.basic
	var comped := gambling_comp_eligible(guest, profile)
	var price := 0.0 if comped else float(profile.price)
	var cost := float(profile.cost)
	guest.wallet -= price
	guest.drink_spending += price
	cash += price
	bar_totals.revenue += price
	if comped:
		bar_totals.comped += 1
		bar_totals.comp_cost += cost
	else:
		bar_totals.sold += 1
		bar_totals.product_cost += cost
	spend_nonpayroll(cost, "drink_comps" if comped else "drink_products")
	guest.thirst = 0.0
	guest.satisfaction = minf(100, float(guest.satisfaction) + CasinoTuning.DRINK_SATISFACTION_GAIN)
	think(guest, "A complimentary drink for playing. Thanks!" if comped else "My drink arrived - $%.2f. Thanks!" % price)
	var asset := get_table(int(guest.table))
	emit_financial_event(price - cost, "comp" if comped else "bar", asset, int(guest.id), {"position": Vector2(guest.x, guest.y), "drink_profile": "basic", "comped": comped, "price": price, "product_cost": cost, "staff_name": str(employee.name), "source": "drink"})

func bar_margin() -> float:
	return float(bar_totals.revenue) - float(bar_totals.product_cost) - float(bar_totals.comp_cost)

func bar_contribution() -> float:
	return bar_margin() - float(expense_totals.service_payroll)

func move_service(delta: float) -> void:
	for employee in staff:
		if employee.role != "Service": continue
		service_position(employee)
		if employee.service_state == "At bar":
			employee.service_wait = maxf(0, float(employee.service_wait) - delta)
			if employee.service_wait > 0: continue
			var candidates := guests.filter(func(g): return wants_drink(g) and not staff.any(func(other): return int(other.get("service_target", -1)) == int(g.id)))
			candidates.sort_custom(func(a, b): return a.thirst > b.thirst)
			if candidates.is_empty(): continue
			var guest: Dictionary = candidates[0]
			employee.service_state = "Delivering"
			employee.service_target = int(guest.id)
			employee.tx = float(guest.x)
			employee.ty = float(guest.y)
			route(employee)
		if employee.service_state == "Delivering":
			var target := guests.filter(func(g): return int(g.id) == int(employee.service_target) and g.state in ["Playing", "Watching", "Waiting", "Getting drink"])
			if target.is_empty():
				send_to_bar(employee)
			elif Vector2(target[0].x, target[0].y).distance_to(Vector2(employee.tx, employee.ty)) > 12:
				employee.tx = target[0].x
				employee.ty = target[0].y
				route(employee)
		if not employee.has("path"): route(employee)
		var goal := Vector2(employee.tx, employee.ty)
		var moved := move_entity(employee, delta)
		if moved.distance_to(goal) < 2:
			employee.erase("path")
			if employee.service_state == "To bar":
				employee.service_state = "At bar"
				employee.service_wait = CasinoTuning.DRINK_PREP_SECONDS
			else:
				for guest in guests:
					if int(guest.id) == int(employee.service_target): deliver_drink(guest, employee)
				send_to_bar(employee)

func step() -> void:
	elapsed += 1
	minute += 1
	if minute >= 1440:
		minute = 0
		day += 1
	var service_count := staff.filter(func(s): return s.role == "Service").size()
	var wages := 0.0
	for employee in staff:
		var wage := (CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE) / 60.0
		wages += wage
		expense_totals["dealer_payroll" if employee.role == "Dealer" else "service_payroll"] += wage
		payroll_by_state[payroll_state(employee)] += wage
		if employee.role == "Dealer":
			var assigned := get_table(int(employee.table))
			if not assigned.is_empty(): assigned.payroll_expense += wage
		var active: bool = not guests.is_empty() if employee.role == "Service" else opened and int(employee.table) > 0
		employee.energy = clampf(employee.energy + (-0.13 if active else 0.5), 15, 100)
	payroll += wages
	cash -= wages
	var costs := 0.0
	for table in tables:
		var asset_cost := (float(slot_profile(table).overhead) if table_kind(table) == "slots" else CasinoTuning.TABLE_OVERHEAD) / 60.0
		costs += asset_cost
		table.operating_expense += asset_cost
		if opened and table.broken: table.downtime_minutes += 1
		if operating(table):
			table.available_minutes += 1
			if not seated(int(table.id)).is_empty() or joined == int(table.id): table.occupied_minutes += 1
	spend_nonpayroll(costs, "upkeep")
	arrival_step()
	for guest in guests:
		guest.age += 1
		guest.thirst = minf(100, guest.thirst + CasinoTuning.THIRST_PER_MINUTE)
		if guest.thirst > CasinoTuning.THIRST_DISCOMFORT:
			guest.satisfaction = maxf(0, guest.satisfaction - CasinoTuning.THIRST_SATISFACTION_LOSS * float(archetype(guest).service_expectation))
			think(guest, "I expected better drink service." if guest.vip else "I could use a drink.", 2)
		guest_lifecycle_step(guest)
	guests = guests.filter(func(g): return not (g.state == "Leaving" and Vector2(g.x, g.y).distance_to(CasinoTuning.ENTRY) < 3))
	for table in tables:
		# Closed tables finish contracts and allow owner play; guests place no new bets.
		if table.broken or crew(int(table.id)).size() < required_crew(table):
			continue
		if not opened and joined != int(table.id) and not seated(int(table.id)).any(func(g): return CrapsRules.exposure(g.bets) > 0) and CrapsRules.exposure(table.owner) == 0:
			continue
		if table_kind(table) != "craps":
			if joined == int(table.id): continue
			table.timer += 1.0
			if table.timer >= (int(slot_profile(table).round_minutes) if table_kind(table) == "slots" else int(CasinoTuning.TABLE_GAME_ROUND_MINUTES[table_kind(table)])):
				table.timer = 0.0
				if opened: npc_games(table)
			continue
		ensure_shooter(table)
		if joined == int(table.id) and (int(table.shooter) == 0 or table.betting_hold):
			continue
		table.timer += 1.0
		var energy := 0.0
		for employee in crew(int(table.id)):
			energy += employee.energy / 2
		var interval := roll_interval(table, energy)
		var activity: bool = not seated(int(table.id)).is_empty() or CrapsRules.exposure(table.owner) > 0 or joined == int(table.id)
		if joined == int(table.id):
			# Preserve the existing visitor/manual rail timing and shooter controls.
			if table.timer >= interval and activity:
				table.timer = 0
				roll(int(table.id))
			continue
		if not activity:
			table.timer = 0 # Empty tables cannot bank future gambling opportunities.
			continue
		# Carry fractional NPC dice time. Never replay an old manual/empty backlog.
		table.timer = minf(float(table.timer), interval + 1.0)
		while table.timer >= interval and (not seated(int(table.id)).is_empty() or CrapsRules.exposure(table.owner) > 0):
			var remaining := float(table.timer) - interval
			roll(int(table.id))
			table.timer = remaining
	for table in tables:
		if not operating(table) or game_pending(table): continue
		table.service_minutes += 1
		var grace := int(slot_profile(table).repair_grace) if table_kind(table) == "slots" else CasinoTuning.REPAIR_GRACE_MINUTES
		var repair_chance := float(slot_profile(table).repair_chance) if table_kind(table) == "slots" else CasinoTuning.REPAIR_CHANCE
		if table.service_minutes >= grace and int(table.service_minutes) % CasinoTuning.REPAIR_CHECK_MINUTES == 0 and incidents.size() < 3:
			if rng.randf() < repair_chance:
				table.broken = true
				table.breakdowns += 1
				incidents.append({"type": "repair", "table": int(table.id), "title": "%s #%d - repair needed" % [asset_name(table), table.id], "detail": "Wear has halted play. Repair costs $%d." % repair_cost(table)})
				log_event("%s #%d halted: repair $%d." % [asset_name(table), table.id, repair_cost(table)])
				if table_kind(table) == "slots":
					for guest in seated(int(table.id)):
						start_guest_exploration(guest)
						think(guest, "This machine needs repair. Maybe another game.", 3)
	if opened and unlocked("service") and not guests.is_empty() and elapsed % 70 == 0 and service_count == 0 and incidents.size() < 3:
		incidents.append({"type": "service", "table": -1, "title": "Drink service complaint", "detail": "No service staff. A $60 comp buys goodwill; hire service for lasting relief."})
		log_event("Guests are asking for drinks. Hire service staff or offer a comp.")

	refresh_progression()
	update_reserve_warning()

func take_bet(table: Dictionary, bettor: Dictionary, kind: String, amount: float, owner: bool) -> bool:
	var funds: float = wallet if owner else float(bettor.wallet)
	if not is_finite(amount) or funds < amount or amount <= 0:
		return false
	if owner:
		wallet -= amount
		visitor_net -= amount
	else:
		bettor.wallet -= amount
		note_guest_wager(table, bettor, amount)
		guest_revenue += amount
	bettor.bets[kind] += amount
	cash += amount
	revenue += amount
	table.wagers += amount
	return true

func bet_amount(table: Dictionary, kind: String, chip: float = 0.0) -> float:
	var amount := maxf(table.minimum, chip)
	var multiple := 5.0
	if kind in ["six", "eight"]: multiple = 6.0
	if kind.begins_with("hard_") or CrapsRules.PROPS.has(kind): amount = maxf(5, chip)
	if kind == "odds" or kind == "lay_odds" or kind.contains("odds_"):
		amount = chip if chip > 0 else 30.0
		var number := int(table.point) if kind in ["odds", "lay_odds"] else int(kind.get_slice("_", kind.get_slice_count("_") - 1))
		if kind == "lay_odds" or kind.begins_with("dont_come_odds_"):
			multiple = 2.0 if number in [4, 10] else (3.0 if number in [5, 9] else 6.0)
		else:
			multiple = 10.0 if number in [5, 9] else 5.0
	return ceilf(amount / multiple) * multiple

func bet_error(id: int, kind: String, chip: float = 0.0) -> String:
	var table := get_table(id)
	if not ready_for_play(table) or joined != id:
		return "Join a staffed, repaired table to bet. Doors can stay closed."
	if not CrapsRules.empty_bets().has(kind): return "Unknown bet."
	var amount := bet_amount(table, kind, chip)
	if not is_finite(amount) or amount + float(table.owner[kind]) > maximum_wager(table): return "This bet exceeds the game maximum ($%d)." % maximum_wager(table)
	if wallet < amount: return "Your visitor wallet cannot cover this bet."
	if kind in ["pass", "dont_pass"] and (int(table.point) != 0 or table.owner[kind] > 0):
		return "Place one line bet before the come-out roll."
	if kind in ["come", "dont_come"] and (int(table.point) == 0 or table.owner[kind] > 0):
		return "A Come / Don't Come bet starts after a table point is established."
	var base := ""
	var number := int(table.point)
	var laying := false
	if kind == "odds": base = "pass"
	elif kind == "lay_odds":
		base = "dont_pass"
		laying = true
	elif kind.begins_with("come_odds_"):
		base = kind.replace("odds_", "")
		number = int(kind.trim_prefix("come_odds_"))
	elif kind.begins_with("dont_come_odds_"):
		base = kind.replace("odds_", "")
		number = int(kind.trim_prefix("dont_come_odds_"))
		laying = true
	elif kind.begins_with("come_") or kind.begins_with("dont_come_"):
		return "Place a Come bet in the box; it travels on the next roll."
	if base != "":
		if number == 0 or table.owner[base] <= 0: return "Odds need an established contract."
		var limit: float = table.owner[base] * 3.0 * (CrapsRules.true_odds(number) if laying else 1.0)
		if table.owner[kind] + amount > limit + 0.001: return "Odds limit: 3× the contract (lay to win 3×)."
	return ""

func bet(id: int, kind: String, chip: float = 0.0) -> bool:
	var reason := bet_error(id, kind, chip)
	if reason != "":
		log_event(reason, false)
		return false
	var table := get_table(id)
	var amount := bet_amount(table, kind, chip)
	var placed := take_bet(table, {"bets": table.owner}, kind, amount, true)
	table.timer = 0.0 # Give the bettor a fresh window after changing a wager.
	log_event("%s: $%d added." % [CrapsRules.name_for(kind), amount], false)
	return placed

func remove_bet(id: int, kind: String) -> float:
	var table := get_table(id)
	if table.is_empty() or not table.owner.has(kind) or not CrapsRules.removable(kind, int(table.point)): return 0.0
	var returned: float = table.owner[kind]
	table.owner[kind] = 0.0
	var attached := "lay_odds" if kind == "dont_pass" else ("dont_come_odds_" + kind.trim_prefix("dont_come_") if kind.begins_with("dont_come_") and not kind.contains("odds") else "")
	if attached != "":
		returned += table.owner[attached]
		table.owner[attached] = 0.0
	wallet += returned
	visitor_net += returned
	cash -= returned
	revenue -= returned
	table.wagers -= returned
	table.timer = 0.0
	return returned

func reclaim(id: int) -> void:
	var returned := 0.0
	for kind in CrapsRules.empty_bets(): returned += remove_bet(id, kind)
	log_event("Returned $%d. Established Pass and Come contracts remain until resolved." % returned, false)

# A shooter owns a hand, not a UI mode. 0 is the visitor, positive IDs are guests,
# -2 is a CPU stand-in at an otherwise empty table, and -1 is unassigned.
func participants(table: Dictionary) -> Array:
	var result: Array = []
	for guest in seated(int(table.id)):
		result.append({"id": int(guest.id), "seat": int(guest.seat)})
	if result.is_empty(): result.append({"id": -2, "seat": 0})
	if joined == int(table.id) and table.owner_queued:
		result.append({"id": 0, "seat": 7})
	result.sort_custom(func(a, b): return a.seat < b.seat)
	return result

func ensure_shooter(table: Dictionary, advance: bool = false) -> void:
	var players := participants(table)
	if not advance and int(table.shooter) == -2 and (int(table.hand_rolls) > 0 or joined == int(table.id)): return
	if not advance and players.any(func(p): return int(p.id) == int(table.shooter)):
		return
	var next: Dictionary = players[0]
	for candidate in players:
		if int(candidate.seat) > int(table.shooter_seat):
			next = candidate
			break
	table.shooter = int(next.id)
	table.shooter_seat = int(next.seat)
	table.hand_rolls = 0
	table.timer = 0.0
	if joined == int(table.id): log_event("Dice to %s." % shooter_name(table), false)

func shooter_name(table: Dictionary) -> String:
	if int(table.shooter) == 0: return "You"
	for guest in guests:
		if int(guest.id) == int(table.shooter): return guest.name + " (CPU)"
	return "CPU shooter"

func join_table(id: int) -> bool:
	var table := get_table(id)
	if not ready_for_play(table): return false
	if joined >= 0:
		leave_table()
		if joined >= 0: return false
	if table_kind(table) == "slots" and not seated(id).is_empty(): return false
	joined = id
	if table_kind(table) != "craps":
		log_event("Joined %s." % Games.NAMES[table_kind(table)], false)
		return true
	table.owner_queued = true
	table.betting_hold = false
	table.timer = 0.0
	if seated(id).is_empty() and int(table.hand_rolls) == 0:
		table.shooter = 0
		table.shooter_seat = 7
	else:
		ensure_shooter(table)
	log_event("Joined craps. %s has the dice; your bets share every roll." % shooter_name(table), false)
	return true

func leave_table() -> void:
	var table := get_table(joined)
	if not table.is_empty() and table_kind(table) != "craps":
		if game_pending(table):
			log_event("Finish your hand before leaving.", false)
			return
		clear_roulette(int(table.id))
		joined = -1
		return
	joined = -1
	if table.is_empty(): return
	table.owner_queued = false
	table.betting_hold = false
	ensure_shooter(table)
	log_event("Left the rail. CPU play continues and your outstanding bets stay live.", false)

func pass_dice(id: int) -> void:
	var table := get_table(id)
	if table.is_empty() or joined != id: return
	table.owner_queued = false
	if int(table.shooter) == 0: ensure_shooter(table, true)
	table.betting_hold = false
	table.timer = 0.0
	log_event("You passed the dice. %s will shoot; your bets remain live." % shooter_name(table), false)

func queue_for_dice(id: int) -> void:
	var table := get_table(id)
	if table.is_empty() or joined != id: return
	table.owner_queued = true
	log_event("You're in the shooter rotation. The current shooter keeps their hand.", false)

func shooter_has_line(table: Dictionary) -> bool:
	return not table.is_empty() and (float(table.owner.pass) > 0 or float(table.owner.dont_pass) > 0)

func shoot_player(id: int, forced: Array = []) -> bool:
	var table := get_table(id)
	if table.is_empty() or joined != id or int(table.shooter) != 0 or not ready_for_play(table): return false
	if not shooter_has_line(table):
		log_event("The shooter must have a Pass or Don’t Pass bet. Wait for come-out or pass the dice.", false)
		return false
	roll(id, forced)
	return true

func roll_interval(table: Dictionary, energy: float = 100.0) -> float:
	return (CasinoTuning.VISITOR_ROLL_SECONDS + (100 - energy) * CasinoTuning.VISITOR_ROLL_FATIGUE) if joined == int(table.id) else (CasinoTuning.ROLL_SECONDS + (100 - energy) * CasinoTuning.NPC_ROLL_FATIGUE)

func roll(id: int, forced: Array = []) -> void:
	var table := get_table(id)
	if table.is_empty() or table.broken or crew(id).size() < required_crew(get_table(id)):
		return
	ensure_shooter(table)
	var rolled_by := shooter_name(table)
	var old_point := int(table.point)
	for guest in seated(id):
		if opened and old_point == 0 and guest.bets.pass == 0 and guest.wallet >= table.minimum:
			var stake := guest_wager(table, guest)
			take_bet(table, guest, "pass", minf(stake, guest.wallet), false)
	var dice := [rng.randi_range(1, 6), rng.randi_range(1, 6)] if forced.is_empty() else forced
	table.dice = dice
	var guest_staked := 0.0
	var guest_returned := 0.0
	var participants: Array = []
	for guest in seated(id):
		var result := CrapsRules.resolve(old_point, guest.bets, int(dice[0]), int(dice[1]))
		var previous := CrapsRules.exposure(guest.bets)
		guest.bets = result.bets
		var settled := previous - CrapsRules.exposure(guest.bets)
		guest.wallet += result.credit
		cash -= result.credit
		payouts += result.credit
		table.payouts += result.credit
		record_guest_round(guest, settled)
		guest_staked += settled
		guest_returned += float(result.credit)
		if settled > 0 or float(result.credit) > 0:
			participants.append({"guest_id": int(guest.id), "settled_stake": settled, "returned": float(result.credit), "amount": settled - float(result.credit)})
		if result.credit > 0:
			guest.satisfaction = minf(100, guest.satisfaction + 3)
			think(guest, "Winner! This table has energy.")
		elif previous > CrapsRules.exposure(guest.bets):
			guest.satisfaction = maxf(0, guest.satisfaction - 1)
			think(guest, "Next shooter, please.")
	var owner_exposure := CrapsRules.exposure(table.owner)
	var result := CrapsRules.resolve(old_point, table.owner, int(dice[0]), int(dice[1]), bool(table.owner_working))
	table.owner = result.bets
	wallet += result.credit
	visitor_net += result.credit
	cash -= result.credit
	payouts += result.credit
	table.payouts += result.credit
	emit_gaming_result(table, guest_staked, guest_returned, -1, participants)
	emit_gaming_result(table, owner_exposure - CrapsRules.exposure(table.owner), float(result.credit), 0)
	table.point = result.point
	table.result = result.message
	table.rolls += 1
	table.hand_rolls += 1
	table.timer = 0.0
	table.history.push_front({"a": int(dice[0]), "b": int(dice[1]), "total": int(result.total), "shooter": rolled_by, "seven_out": bool(result.seven_out), "point": int(result.point), "credit": float(result.credit)})
	if table.history.size() > 20: table.history.pop_back()
	if result.seven_out: ensure_shooter(table, true)
	if joined == id:
		log_event(result.message + (" Returned $%d to your wallet." % result.credit if result.credit > 0 else ""), false)

func resolve_incident(index: int, pay: bool) -> void:
	if index < 0 or index >= incidents.size():
		return
	var incident: Dictionary = incidents[index]
	var affected := get_table(int(incident.table))
	var cost := repair_cost(affected) if incident.type == "repair" and not affected.is_empty() else 60.0
	if pay and cash < cost:
		log_event("Not enough casino cash to resolve this incident.")
		return
	if incident.type == "repair" and not pay:
		log_event("Table stays halted. Repair it when cash is available.")
		return
	if pay:
		spend_nonpayroll(cost, "repairs" if incident.type == "repair" else "comps")
		if incident.type == "repair":
			var table := get_table(int(incident.table))
			if not table.is_empty():
				table.broken = false
				table.service_minutes = 0
				table.repair_expense += cost
				table.repairs += 1
				emit_financial_event(-cost, "repair", table)
		else:
			emit_financial_event(-cost, "comp", {}, -1, {"source": "complaint", "position": BAR_PICKUP})
			reputation = minf(100, reputation + 2)
			for guest in guests:
				guest.satisfaction = minf(100, guest.satisfaction + 8)
		log_event("%s resolved for $%d." % [incident.title, cost])
	else:
		reputation = maxf(0, reputation - 3)
		log_event("Complaint dismissed. Reputation -3: guests felt ignored.")
	incidents.remove_at(index)

func live_stakes() -> float:
	var amount := 0.0
	for table in tables:
		amount += CrapsRules.exposure(table.owner) + game_liability(table)
	for guest in guests:
		amount += CrapsRules.exposure(guest.bets)
	return amount

func gaming_profit() -> float:
	return revenue - payouts - live_stakes()

func spend_nonpayroll(amount: float, category: String) -> void:
	cash -= amount
	overhead += amount
	expense_totals[category] += amount

func payroll_state(employee: Dictionary) -> String:
	if employee.role == "Service":
		return "working" if opened and not guests.is_empty() else "idle" if opened else "unavailable"
	var table := get_table(int(employee.table))
	if table.is_empty(): return "standby"
	if not operating(table): return "unavailable"
	return "working" if not seated(int(table.id)).is_empty() or joined == int(table.id) else "idle"

func payroll_rate() -> float:
	var amount := 0.0
	for employee in staff: amount += CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE
	return amount

func recurring_costs() -> float:
	return payroll + float(expense_totals.upkeep) + float(expense_totals.repairs) + float(expense_totals.comps) + float(expense_totals.drink_products) + float(expense_totals.drink_comps)

func net_capital_spending() -> float:
	return float(expense_totals.construction) + float(expense_totals.sales)

func owner_pending_stakes() -> float:
	var pending := 0.0
	for table in tables:
		pending += CrapsRules.exposure(table.owner)
		for amount in table.roulette_bets.values(): pending += float(amount)
		if game_pending(table): pending += float(table.round.get("staked", 0))
	return pending

func visitor_house_result() -> float:
	return -visitor_net - owner_pending_stakes()

func guest_gaming_profit() -> float:
	return gaming_profit() - visitor_house_result()

func operating_profit() -> float:
	return guest_gaming_profit() + float(bar_totals.revenue) - recurring_costs()

func asset_pending_stakes(table: Dictionary) -> float:
	var pending := game_liability(table) + CrapsRules.exposure(table.owner)
	for guest in guests:
		if int(guest.table) == int(table.id): pending += CrapsRules.exposure(guest.bets)
	return pending

func asset_performance(table: Dictionary) -> Dictionary:
	var handle := float(table.wagers) - asset_pending_stakes(table)
	var gaming_win := handle - float(table.payouts)
	var hours := float(table.available_minutes) / 60.0
	return {"handle": handle, "payouts": float(table.payouts), "gaming_win": gaming_win,
		"guest_win": gaming_win - float(table.visitor_gaming_win),
		"contribution": asset_operating_profit(table), "hours": hours,
		"utilization": float(table.occupied_minutes) / maxf(1, float(table.available_minutes)) * 100.0,
		"handle_hour": handle / hours if hours > 0 else 0.0,
		"contribution_hour": asset_operating_profit(table) / hours if hours > 0 else 0.0}

func asset_payout_buffer(kind: String, profile_id: String = "starter", pending: float = 0.0) -> float:
	if kind == "slots":
		var profile := CasinoTuning.slot_profile(profile_id)
		return maxf(float(profile.reserve), float(profile.top_return) * float(profile.maximum))
	var profile: Dictionary = CasinoTuning.TABLE_RESERVE_PROFILES[kind]
	var seats := 1.0 + CasinoTuning.RESERVE_ADDITIONAL_SEAT_WEIGHT * float(capacity({"kind": kind}) - 1)
	var swing := float(CasinoTuning.GAME_LIMITS[kind].maximum) * float(profile.return_multiple) * seats
	return maxf(float(profile.base), maxf(swing, pending * float(profile.return_multiple)))

func reserve_report(add_kind: String = "", profile_id: String = "starter") -> Dictionary:
	var total := 0.0
	var largest := 0.0
	var largest_name := "No gaming assets"
	var upkeep := 0.0
	var repairs := 0.0
	for table in tables:
		var kind := table_kind(table)
		upkeep += float(slot_profile(table).overhead) if kind == "slots" else CasinoTuning.TABLE_OVERHEAD
		if table.broken: repairs += repair_cost(table)
		if not ready_for_play(table) and not table.broken and asset_pending_stakes(table) <= 0: continue
		var buffer := asset_payout_buffer(kind, str(table.slot_profile), asset_pending_stakes(table))
		total += buffer
		if buffer > largest:
			largest = buffer
			largest_name = "%s #%d" % [asset_name(table), table.id]
	var purchase := 0.0
	var onboarding := 0.0
	var extra_payroll := 0.0
	if add_kind != "":
		purchase = purchase_cost(add_kind, profile_id)
		var crew_needed := required_crew({"kind": add_kind})
		var standby := staff.filter(func(employee): return employee.role == "Dealer" and int(employee.table) == -1).size()
		var hires := maxi(0, crew_needed - standby)
		onboarding = hires * CasinoTuning.HIRING_COST
		extra_payroll = hires * CasinoTuning.DEALER_WAGE
		upkeep += float(CasinoTuning.slot_profile(profile_id).overhead) if add_kind == "slots" else CasinoTuning.TABLE_OVERHEAD
		var buffer := asset_payout_buffer(add_kind, profile_id)
		total += buffer
		if buffer > largest:
			largest = buffer
			largest_name = "Proposed " + (str(CasinoTuning.slot_profile(profile_id).name) if add_kind == "slots" else str(Games.NAMES[add_kind]))
	var payouts_buffer := largest + (total - largest) * CasinoTuning.RESERVE_ADDITIONAL_ASSET_WEIGHT
	var payroll_buffer := (payroll_rate() + extra_payroll) * CasinoTuning.RESERVE_OPERATING_HOURS
	var upkeep_buffer := upkeep * CasinoTuning.RESERVE_OPERATING_HOURS
	var required := payouts_buffer + payroll_buffer + upkeep_buffer + repairs
	var pending := live_stakes()
	var available := cash - pending - purchase - onboarding
	var margin := available - required
	var level := "short" if margin < 0 else "thin" if required > 0 and margin < required * CasinoTuning.RESERVE_THIN_FRACTION else "covered"
	return {"pending": pending, "available": available, "required": required, "margin": margin,
		"payouts": payouts_buffer, "payroll": payroll_buffer, "upkeep": upkeep_buffer, "repairs": repairs,
		"purchase": purchase, "onboarding": onboarding, "largest": largest_name, "level": level}

var reserve_alert_level := "covered"
var reserve_alert_at := -CasinoTuning.RESERVE_ALERT_MINUTES

func update_reserve_warning() -> void:
	var report := reserve_report()
	if report.level == reserve_alert_level or elapsed - reserve_alert_at < CasinoTuning.RESERVE_ALERT_MINUTES: return
	reserve_alert_level = report.level
	reserve_alert_at = elapsed
	if report.level == "covered":
		log_event("RESERVE - Operating buffer restored. Estimates do not guarantee coverage of every payout.")
	else:
		log_event("RESERVE - %s: free cash $%.0f / suggested $%.0f. Main payout exposure: %s." % ["Buffer short" if report.level == "short" else "Thin buffer", report.available, report.required, report.largest])

func asset_operating_profit(table: Dictionary) -> float:
	return float(table.wagers) - float(table.payouts) - asset_pending_stakes(table) - float(table.visitor_gaming_win) - float(table.operating_expense) - float(table.repair_expense) - float(table.payroll_expense)

func operating_costs() -> float:
	return payroll + overhead

func net_profit() -> float:
	return revenue - payouts + float(bar_totals.revenue) - payroll - overhead

func satisfaction() -> float:
	if guests.is_empty():
		return 80
	var total := 0.0
	for guest in guests:
		total += guest.satisfaction
	return total / guests.size()

func snapshot() -> Dictionary:
	return {"difficulty": difficulty, "starting_games": starting_games.duplicate(), "casino_rating": casino_rating, "guest_rounds": guest_rounds, "guest_revenue": guest_revenue, "guest_handle": guest_handle, "guests_served": guests_served, "blackjack_unlocked": blackjack_unlocked, "ever_opened": ever_opened, "expanded": expanded, "vip_enabled": vip_enabled, "high_limit_enabled": high_limit_enabled, "bar_totals": bar_totals.duplicate(), "expense_totals": expense_totals.duplicate(), "payroll_by_state": payroll_by_state.duplicate(), "slot_access": slot_access.duplicate(), "version": CasinoTuning.SAVE_VERSION, "arrival_in": arrival_in, "cash": cash, "wallet": wallet, "revenue": revenue, "payouts": payouts, "payroll": payroll, "overhead": overhead, "visitor_net": visitor_net, "reputation": reputation, "minute": minute, "day": day, "elapsed": elapsed, "opened": opened, "tables": tables.duplicate(true), "guests": guests.duplicate(true), "staff": staff.duplicate(true), "alerts": alerts.duplicate(), "incidents": incidents.duplicate(true), "next_id": next_id, "joined": joined, "player": [player.x, player.y], "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	if not valid_number(data.get("version")) or data.version != CasinoTuning.SAVE_VERSION:
		return false
	data = data.duplicate(true)
	if not data.get("slot_access") is Array or "starter" not in data.slot_access: return false
	for id in data.slot_access:
		if not id is String or not CasinoTuning.SLOT_PROFILES.has(id): return false
	for field in ["expense_totals", "payroll_by_state", "bar_totals"]:
		if not data.get(field) is Dictionary: return false
		var expected: Dictionary = expense_totals if field == "expense_totals" else payroll_by_state if field == "payroll_by_state" else bar_totals
		for key in expected:
			if not data[field].has(key) or not valid_number(data[field][key]): return false
			if key != "sales" and float(data[field][key]) < 0: return false
	# Validate the current schema before applying any state.
	for key in ["difficulty", "starting_games", "casino_rating", "guest_rounds", "guest_revenue", "guest_handle", "guests_served", "blackjack_unlocked", "ever_opened", "expanded", "vip_enabled", "high_limit_enabled", "arrival_in", "cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "opened", "tables", "guests", "staff", "alerts", "incidents", "next_id", "joined", "player", "rng_state"]:
		if not data.has(key): return false
	if not data.difficulty is String or not CasinoTuning.DIFFICULTIES.has(data.difficulty): return false
	if not data.starting_games is Array or data.starting_games.size() > Games.NAMES.size(): return false
	for kind in data.starting_games:
		if not kind is String or not Games.NAMES.has(kind): return false
	for key in ["casino_rating", "guest_rounds", "guest_revenue", "guest_handle", "guests_served"]:
		if not valid_number(data[key]) or float(data[key]) < 0: return false
	if float(data.casino_rating) > 100: return false
	for key in ["blackjack_unlocked", "ever_opened", "expanded", "vip_enabled", "high_limit_enabled"]:
		if not data[key] is bool: return false
	if not valid_number(data.arrival_in) or float(data.arrival_in) < 0: return false
	for key in ["tables", "guests", "staff", "alerts", "incidents", "player"]:
		if not data[key] is Array:
			return false
	if data.player.size() != 2 or data.tables.size() > 20 or data.guests.size() > 40 or data.staff.size() > 16:
		return false
	for key in ["cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "next_id", "joined"]:
		if not valid_number(data[key]):
			return false
	if float(data.wallet) < 0 or not data.opened is bool or not data.rng_state is String:
		return false
	if not data.rng_state.is_valid_int():
		return false
	if not valid_number(data.player[0]) or not valid_number(data.player[1]):
		return false
	var ids: Array = []
	for table in data.tables:
		if not table is Dictionary:
			return false
		for key in ["kind", "slot_profile", "round", "roulette_bets"]:
			if not table.has(key): return false
		if not table.kind is String or not Games.NAMES.has(table.kind): return false
		if not table.slot_profile is String or (table.kind == "slots" and not CasinoTuning.SLOT_PROFILES.has(table.slot_profile)): return false
		if not table.round is Dictionary or not table.roulette_bets is Dictionary: return false
		if not Games.valid_round(table.round, str(table.kind)): return false
		var roulette_options := Games.roulette_bets()
		for name in table.roulette_bets:
			if not roulette_options.has(name) or not valid_number(table.roulette_bets[name]) or float(table.roulette_bets[name]) < 0: return false
		for key in ["id", "x", "y", "rotated", "point", "dice", "timer", "wagers", "payouts", "broken", "rolls", "minimum", "owner", "result", "shooter", "shooter_seat", "hand_rolls", "owner_queued", "betting_hold", "owner_working", "history", "service_minutes", "available_minutes", "occupied_minutes", "downtime_minutes", "operating_expense", "repair_expense", "payroll_expense", "visitor_gaming_win", "repairs", "breakdowns"]:
			if not table.has(key):
				return false
		for key in ["id", "x", "y", "point", "timer", "wagers", "payouts", "rolls", "minimum", "shooter", "shooter_seat", "hand_rolls", "service_minutes", "available_minutes", "occupied_minutes", "downtime_minutes", "operating_expense", "repair_expense", "payroll_expense", "visitor_gaming_win", "repairs", "breakdowns"]:
			if not valid_number(table[key]):
				return false
		for key in ["available_minutes", "occupied_minutes", "downtime_minutes", "operating_expense", "repair_expense", "payroll_expense", "repairs", "breakdowns"]:
			if float(table[key]) < 0: return false
		if float(table.occupied_minutes) > float(table.available_minutes): return false
		if int(table.id) in ids or int(table.id) < 1 or int(table.point) not in [0, 4, 5, 6, 8, 9, 10]:
			return false
		ids.append(int(table.id))
		if not table.rotated is bool or not table.broken is bool or not table.result is String or not valid_bets(table.owner):
			return false
		if not table.owner_queued is bool or not table.betting_hold is bool or not table.owner_working is bool or not table.history is Array or table.history.size() > 20:
			return false
		for entry in table.history:
			if not entry is Dictionary: return false
			for key in ["a", "b", "total", "point", "credit"]:
				if not entry.has(key) or not valid_number(entry[key]): return false
			if not entry.get("shooter") is String or not entry.get("seven_out") is bool: return false
		if not table.dice is Array or table.dice.size() != 2:
			return false
		for die in table.dice:
			if not valid_number(die) or int(die) < 1 or int(die) > 6:
				return false
		var limits: Array = slot_profile(table).denominations if table.kind == "slots" else CasinoTuning.GAME_LIMITS[table.kind].limits
		if float(table.minimum) not in limits or not Rect2(65, 100, 720, 400).encloses(bounds(table)):
			return false
	if int(data.joined) != -1 and int(data.joined) not in ids:
		return false
	for guest in data.guests:
		if not guest is Dictionary:
			return false
		for key in ["id", "name", "x", "y", "tx", "ty", "table", "seat", "state", "wallet", "start", "rounds", "last_wager_minute", "drink_spending", "wager_limit", "satisfaction", "thirst", "age", "patience", "vip", "bets", "thought", "archetype", "session_left", "activities", "activity_since", "decision_at", "wait_since", "last_table", "explored_without_game", "preference", "watch_left", "watch_style"]:
			if not guest.has(key):
				return false
		for key in ["id", "x", "y", "tx", "ty", "table", "seat", "wallet", "start", "rounds", "last_wager_minute", "drink_spending", "wager_limit", "satisfaction", "thirst", "age", "patience", "session_left", "activities", "activity_since", "decision_at", "wait_since", "last_table"]:
			if not valid_number(guest[key]):
				return false
		if int(guest.last_wager_minute) < -1 or float(guest.last_wager_minute) > float(data.elapsed) or float(guest.drink_spending) < 0: return false
		if not guest.explored_without_game is bool or guest.session_left < 0 or guest.activities < 0 or guest.activity_since < 0 or guest.activity_since > data.elapsed or guest.decision_at < 0 or guest.wait_since < -1 or guest.wait_since > data.elapsed: return false
		if not guest.archetype is String or not CasinoTuning.GUEST_ARCHETYPES.has(guest.archetype): return false
		if bool(guest.vip) != (guest.archetype == "vip"): return false
		if not guest.preference is String or not Games.NAMES.has(guest.preference): return false
		if float(guest.wallet) < 0 or float(guest.rounds) < 0 or float(guest.wager_limit) <= 0 or not valid_bets(guest.bets) or not guest.vip is bool:
			return false
		if int(guest.table) != -1 and int(guest.table) not in ids:
			return false
		if guest.state in ["Walking", "Playing"] and (int(guest.table) < 1 or int(guest.seat) not in range(7)):
			return false
		if guest.state not in ["Arriving", "Waiting", "Walking", "Playing", "Browsing", "Watching", "Exploring", "Seeking drink", "Getting drink", "To cage", "Cashing out", "Leaving"] or not guest.name is String or not guest.thought is String:
			return false
		if guest.state in ["Browsing", "Watching"] and (int(guest.table) < 1 or int(guest.seat) != -1): return false
		for key in ["watch_left", "watch_style", "cage_wait"]:
			if not valid_number(guest.get(key, 0)) or float(guest.get(key, 0)) < 0: return false
		guest.watch_left = int(guest.watch_left)
		guest.watch_style = int(guest.watch_style)
		if guest.has("path"):
			if not guest.path is Array:
				return false
			for waypoint in guest.path:
				if not waypoint is Array or waypoint.size() != 2 or not valid_number(waypoint[0]) or not valid_number(waypoint[1]):
					return false
	for employee in data.staff:
		if not employee is Dictionary:
			return false
		for key in ["name", "role", "table", "energy"]:
			if not employee.has(key):
				return false
		if not employee.name is String or employee.role not in ["Dealer", "Service"] or not valid_number(employee.table) or not valid_number(employee.energy):
			return false
		for key in ["x", "y", "tx", "ty", "service_target", "service_wait"]:
			if employee.has(key) and not valid_number(employee[key]): return false
		if employee.has("service_state") and employee.service_state not in ["At bar", "To bar", "Delivering"]: return false
		employee.erase("path")
		if int(employee.table) != -1 and int(employee.table) not in ids:
			return false
	for incident in data.incidents:
		if not incident is Dictionary:
			return false
		for key in ["type", "table", "title", "detail"]:
			if not incident.has(key):
				return false
		if incident.type not in ["repair", "service"] or not incident.title is String or not incident.detail is String or not valid_number(incident.table):
			return false
		if incident.type == "repair" and int(incident.table) not in ids:
			return false
	for message in data.alerts:
		if not message is String:
			return false
	debug_forced_unlocks.clear()
	for key in ["cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation"]:
		set(key, float(data[key]))
	for key in ["minute", "day", "elapsed", "next_id", "joined"]:
		set(key, int(data[key]))
	bar_totals = data.bar_totals.duplicate()
	expense_totals = data.expense_totals.duplicate()
	payroll_by_state = data.payroll_by_state.duplicate()
	slot_access = data.slot_access.duplicate()
	difficulty = str(data.difficulty)
	starting_games = data.starting_games.duplicate()
	casino_rating = float(data.casino_rating)
	guest_rounds = int(data.guest_rounds)
	guest_revenue = float(data.guest_revenue)
	guest_handle = float(data.guest_handle)
	guests_served = int(data.guests_served)
	for key in ["blackjack_unlocked", "ever_opened", "expanded", "vip_enabled", "high_limit_enabled"]: set(key, bool(data[key]))
	thought_last.clear()
	table_interest.clear()
	cashout_effects.clear()
	recent_financial_events.clear()
	house_activity.clear()
	reserve_alert_level = "covered"
	reserve_alert_at = elapsed - CasinoTuning.RESERVE_ALERT_MINUTES
	arrival_in = int(data.arrival_in)
	opened = bool(data.opened)
	for key in ["tables", "guests", "staff", "alerts", "incidents"]:
		set(key, data[key].duplicate(true))
	player = Vector2(data.player[0], data.player[1])
	rng.state = int(data.rng_state)
	refresh_progression()
	return true

func valid_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func valid_bets(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for kind in CrapsRules.empty_bets():
		if not value.has(kind) or not valid_number(value[kind]) or float(value[kind]) < 0:
			return false
	return true

func game_debit(table: Dictionary, amount: float, guest: Dictionary = {}) -> bool:
	var funds: float = wallet if guest.is_empty() else guest.wallet
	if not is_finite(amount) or amount < 0 or funds < amount: return false
	if guest.is_empty():
		wallet -= amount
		visitor_net -= amount
	else:
		guest.wallet -= amount
		note_guest_wager(table, guest, amount)
		guest_revenue += amount
	cash += amount
	revenue += amount
	table.wagers += amount
	return true

func game_credit(table: Dictionary, amount: float, guest: Dictionary = {}) -> void:
	if guest.is_empty():
		wallet += amount
		visitor_net += amount
	else: guest.wallet += amount
	cash -= amount
	payouts += amount
	table.payouts += amount

func settle_game(table: Dictionary) -> void:
	var round: Dictionary = table.round
	if round.get("phase", "") != "done" or round.get("paid", false): return
	round.paid = true
	game_credit(table, float(round.credit))
	emit_gaming_result(table, float(round.staked), float(round.credit), 0)
	for npc in round.get("npcs", []):
		for guest in guests:
			if int(guest.id) == int(npc.id):
				game_credit(table, float(npc.returned), guest)
				emit_gaming_result(table, float(npc.staked), float(npc.returned), int(guest.id))
				record_guest_round(guest, float(npc.staked))
				think(guest, "Our dealer paid my win!" if npc.returned > npc.staked else "Next hand, please.")
	table.result = round.message
	table.rolls += 1
	refresh_progression() # Evaluate readiness only after all shared payouts are credited.
	log_event("%s: %s" % [Games.NAMES[table_kind(table)], round.message], false)

func start_game(id: int, bet: float, trips: float = 0) -> bool:
	var table := get_table(id)
	if joined != id or not ready_for_play(table) or game_pending(table): return false
	var kind := table_kind(table)
	if kind == "craps" or not is_finite(bet) or not is_finite(trips) or bet < table.minimum or bet > maximum_wager(table) or trips < 0 or trips > maximum_wager(table): return false
	var cost := bet * 2 + trips if kind == "holdem" else bet
	if kind == "roulette":
		cost = 0
		for amount in table.roulette_bets.values(): cost += float(amount)
		if cost <= 0: return false
	else:
		if kind == "holdem" and wallet < bet * 6 + trips:
			log_event("Hold’em needs enough for Ante, Blind and a 4× raise ($%d)." % (bet * 6 + trips), false)
			return false
		if not game_debit(table, cost): return false
	var participants: Array = []
	if opened and kind in ["blackjack", "holdem"]:
		for guest in seated(id):
			var stake := guest_wager(table, guest)
			if stake >= float(table.minimum) and guest.wallet >= stake * (3 if kind == "holdem" else 1): participants.append({"id": guest.id, "name": guest.name, "bet": stake})
	match kind:
		"slots": table.round = Games.spin_slots(bet, rng, slot_profile(table))
		"roulette":
			table.round = Games.spin_roulette(table.roulette_bets, rng)
			table.round.bets = table.roulette_bets.duplicate(true)
			table.roulette_bets.clear()
		"blackjack": table.round = Games.blackjack(bet, rng, participants)
		"holdem": table.round = Games.holdem(bet, trips, rng, participants)
	for npc in table.round.get("npcs", []):
		for guest in guests:
			if int(guest.id) == int(npc.id): game_debit(table, float(npc.staked), guest)
	if kind == "roulette" and opened: shared_roulette(table, int(table.round.number))
	table.round.staked = cost
	settle_game(table)
	return true

func game_action(id: int, action: String) -> bool:
	var table := get_table(id)
	if joined != id or not ready_for_play(table) or not game_pending(table): return false
	var actions := Games.actions(table.round, wallet)
	if not actions.has(action): return false
	var cost := float(actions[action])
	if not game_debit(table, cost): return false
	table.round.staked += cost
	Games.act(table.round, action)
	settle_game(table)
	return true

func roulette_bet(id: int, name: String, amount: float) -> bool:
	var table := get_table(id)
	if table.is_empty() or table_kind(table) != "roulette" or joined != id or not ready_for_play(table) or not Games.roulette_bets().has(name) or not is_finite(amount) or amount < table.minimum: return false
	var on_layout := amount
	for stake in table.roulette_bets.values(): on_layout += float(stake)
	if on_layout > maximum_wager(table) or not game_debit(table, amount): return false
	table.roulette_bets[name] = float(table.roulette_bets.get(name, 0)) + amount
	return true

func clear_roulette(id: int) -> void:
	var table := get_table(id)
	if table.is_empty(): return
	var amount := 0.0
	for stake in table.get("roulette_bets", {}).values(): amount += float(stake)
	table.roulette_bets.clear()
	wallet += amount
	visitor_net += amount
	cash -= amount
	revenue -= amount
	table.wagers -= amount

func npc_games(table: Dictionary) -> void:
	if table_kind(table) == "roulette":
		var number := rng.randi_range(0, 36)
		shared_roulette(table, number)
		table.round = Games.spin_roulette({}, rng, number)
		table.round.paid = true
		table.rolls += 1
		return
	for guest in seated(int(table.id)):
		var bet := guest_wager(table, guest)
		var kind := table_kind(table)
		if guest.wallet < bet * (6 if kind == "holdem" else 1):
			finish_guest_session(guest)
			continue
		var cost := bet * 2 if kind == "holdem" else bet
		if bet < float(table.minimum) or not game_debit(table, cost, guest): continue
		var staked := cost
		var round := {}
		match kind:
			"slots": round = Games.spin_slots(bet, rng, slot_profile(table))
			"roulette": round = Games.spin_roulette({"Red" if int(guest.id) % 2 else "Black": bet}, rng)
			"blackjack": round = Games.blackjack(bet, rng)
			"holdem": round = Games.holdem(bet, 0, rng)
		while round.get("phase", "done") != "done":
			var action := ""
			if kind == "blackjack":
				action = "Decline insurance" if round.phase == "insurance" else ("Hit" if Games.total(round.hands[int(round.active)].cards) < 17 else "Stand")
			else:
				if round.phase != "river": action = "Check"
				else: action = "Raise 1×" if int(Games.poker_rank(round.player + round.board)[0]) >= 1 else "Fold"
			var options := Games.actions(round, float(guest.wallet))
			if not options.has(action): action = options.keys()[0]
			var extra := float(options[action])
			if not game_debit(table, extra, guest): break
			staked += extra
			Games.act(round, action)
		game_credit(table, float(round.credit), guest)
		emit_gaming_result(table, staked, float(round.credit), int(guest.id))
		round.paid = true # NPC-only rounds have already credited the guest, never the owner.
		round.staked = staked
		record_guest_round(guest, staked)
		table.rolls += 1
		table.result = "%s · %s" % [guest.name, round.message]
		think(guest, "A win!" if round.credit > staked else "One more round?")
		if joined != int(table.id): table.round = round

func game_liability(table: Dictionary) -> float:
	var amount := 0.0
	for value in table.get("roulette_bets", {}).values(): amount += float(value)
	if game_pending(table):
		amount += float(table.round.get("staked", 0))
		for npc in table.round.get("npcs", []): amount += float(npc.staked)
	return amount

func shared_roulette(table: Dictionary, number: int) -> void:
	for guest in seated(int(table.id)):
		var stake := guest_wager(table, guest)
		if stake < float(table.minimum) or not game_debit(table, stake, guest): continue
		var result := Games.spin_roulette({"Red" if int(guest.id) % 2 else "Black": stake}, rng, number)
		game_credit(table, result.credit, guest)
		emit_gaming_result(table, stake, float(result.credit), int(guest.id))
		record_guest_round(guest, stake)
		think(guest, "Our wheel hit %d!" % number)
