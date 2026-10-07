class_name CasinoSimulation
extends RefCounted

signal reputation_loss(event: Dictionary)
signal financial_event(event: Dictionary)
signal guest_thought(event: Dictionary)
signal milestone_reached(event: Dictionary)
signal owner_event_completed(result: Dictionary)

const Games = preload("res://scripts/casino_games.gd")
const Staffing = preload("res://scripts/staffing.gd")
const Property = preload("res://scripts/floor_property.gd")
const Placement = preload("res://scripts/asset_placement.gd")
const Seating = preload("res://presentation/art_catalog.gd")
const Bar = preload("res://scripts/drink_economy.gd")
const DrinkService = preload("res://scripts/drink_service.gd")

var cash := CasinoTuning.STARTING_CASH
const OwnerAccount = preload("res://scripts/owner_bankroll.gd")
const OwnerPlay = preload("res://scripts/owner_event_play.gd")
const BackRoom = preload("res://scripts/back_room_session.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var back_room := BackRoom.new()
var recovery := Recovery.new()
var owner_play := {}
var owner_checkpoint := Callable() # Controller supplies local persistence; tests can remain in memory.
const OptionalEvents = preload("res://scripts/optional_events.gd")
var owner_account := OwnerAccount.new()
var optional_events := OptionalEvents.new()
const Momentum = preload("res://scripts/casino_momentum.gd")
var momentum := Momentum.new()
const Objectives = preload("res://scripts/optional_objectives.gd")
var optional_objectives := Objectives.new()
var owner_bankroll: float:
	get: return owner_account.balance
var sponsored_income := 0.0
var revenue := 0.0
var payouts := 0.0
var payroll := 0.0
var overhead := 0.0
# Cash expenses recorded once; classifications never make an additional charge.
var expense_totals := {"dealer_payroll": 0.0, "service_payroll": 0.0, "upkeep": 0.0, "repairs": 0.0, "comps": 0.0, "hiring": 0.0, "construction": 0.0, "sales": 0.0, "drink_products": 0.0, "drink_comps": 0.0, "property_upkeep": 0.0}
var payroll_by_state := {"active": 0.0, "relief": 0.0, "break": 0.0, "off_duty": 0.0}
var relief_targets := {"Dealer": 1, "Service": 1}
var bar_owned := false
var service_positions := 1
var staff_shift_handover_at := -CasinoTuning.STAFF_SHIFT_HANDOVER_GAP
var staffing_notice_signature := "" # Transient, rate-limited operational warnings.
var staffing_notice_at := -CasinoTuning.STAFF_NOTICE_COOLDOWN
var drink_access: Array = []
var drink_menu: Array = []
var drink_prices := {}
var drink_stats := {}
var bar_totals := {"sold": 0, "comped": 0, "revenue": 0.0, "product_cost": 0.0, "comp_cost": 0.0}
var visitor_net := 0.0
var reputation := 60.0
var recent_reputation_losses: Array = [] # Bounded transient diagnostics, never saved.
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
var floor_chunks := {"left": 0, "right": 0, "bottom": 0}
var vip_enabled := false
var high_limit_enabled := false
var minute := 1080
var day := 1
var elapsed := 0
var opened := false
var traffic_totals := {"arrivals": 0, "unmet_visits": 0, "severe_departures": 0, "deferred_attempts": 0, "position_minutes": 0, "occupied_minutes": 0, "departures": {"capacity": 0, "affordability": 0, "service": 0, "closed": 0, "visit": 0}}
var traffic_bad_visits := 0
var traffic_reputation_at := -CasinoTuning.TRAFFIC_REPUTATION_COOLDOWN
var arrival_in := 10
var tables: Array = []
var guests: Array = []
var cashout_effects: Array = []
var recent_financial_events: Array = [] # Transient; never replay settlements after Load.
var house_activity: Array = [] # Transient management notices, separate from detailed financial events.
var slot_access: Array = ["starter"]
var earned_milestones: Array = []
var milestone_initializing := true
var financial_sequence := 0
var presentation_revision := 0
var step_tables := {}
var step_crew := {}
var indexed_step := false
var thought_last := {} # Transient emission cooldowns, not saved guest history.
var table_interest := {} # Bounded recent actual guest wagers, never an odds input.
const CAGE_PICKUP := Vector2(120, 90)
var staff: Array = []
var alerts: Array = []
var incidents: Array = []
var next_id := 1
var joined := -1
var player := CasinoTuning.ENTRY + Vector2(0, 20)
var rng := RandomNumberGenerator.new()
var navigation_grid: AStarGrid2D # Transient; shared until geometry changes.
var geometry_revision := 0
var placement_world_revision := -1
var placement_world: Array = [] # Read-only geometry index, independent of guests/staff.
var placement_signature: Array = []
var placement_result := {} # Last proposal only; recompute on geometry or target change.

func _init(mode: String = "normal", preferred_games: Array = ["slots"]) -> void:
	rng.randomize()
	Bar.initialize(self)
	difficulty = mode if CasinoTuning.DIFFICULTIES.has(mode) else "normal"
	var config: Dictionary = CasinoTuning.DIFFICULTIES[difficulty]
	cash = float(config.cash)
	floor_chunks = config.floor_chunks.duplicate()
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
				staff.append(Staffing.new_employee(self, "Dealer", int(table.id)))
	refresh_progression()
	for level in range(2, stars() + 1): earned_milestones.append("rating:%d" % level)
	if tables.any(func(table): return table_kind(table) != "slots"): earned_milestones.append("first_table")
	milestone_initializing = false
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
	return float({"service": CasinoTuning.BAR_PURCHASE_COST, "vip": CasinoTuning.VIP_COST, "high_limit": CasinoTuning.HIGH_LIMIT_COST}.get(feature, 0))

func feature_owned(feature: String) -> bool:
	match feature:
		"service": return bar_owned
		"expansion": return Property.count(floor_chunks) > 0
		"vip": return vip_enabled
		"high_limit": return high_limit_enabled
	return tables.any(func(t): return table_kind(t) == feature)

func guest_feature_relevant(feature: String) -> bool:
	if feature_owned(feature) or unlocked(feature): return true
	# Only foreshadow the next revealed opportunity. Blackjack's UI is revealed
	# from day one, but guests should not expect it before access is earned.
	if feature == "blackjack" or not blackjack_unlocked: return false
	for milestone in CasinoTuning.MILESTONES:
		if feature_owned(str(milestone.id)): continue
		return str(milestone.id) == feature and revealed(feature)
	return false

func guest_current_interest(guest: Dictionary) -> String:
	# Preserve latent preference; adapt current expectations to this property.
	if feature_owned(str(guest.preference)): return str(guest.preference)
	for kind in archetype(guest).games:
		if feature_owned(str(kind)): return str(kind)
	if guest.archetype in ["dice", "tables"]:
		for table in tables:
			if table_kind(table) != "slots": return table_kind(table)
	for table in tables:
		return table_kind(table)
	return "slots"

func guest_profile_name(guest: Dictionary) -> String:
	if guest.archetype in ["dice", "tables"] and not guest_feature_relevant(str(guest.preference)):
		return "Variety seeker"
	return str(archetype(guest).name)

func guest_arrival_thought(guest: Dictionary) -> String:
	var interest := guest_current_interest(guest)
	var name: String = "hold'em" if interest == "holdem" else interest
	if feature_owned(interest):
		if interest == "slots" and guest.preference != "slots": return "I'll try the slots here."
		return "Let's try the slots." if interest == "slots" else "I'll try %s." % name
	return "I'd love a %s table." % name

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
		return "Open your chosen games, watch the guests, and manage crews and cash. Walk to a game to play with your separate Owner Bankroll."
	if not ever_opened: return "1. Open the casino. Your two slots need no staff."
	if guest_rounds == 0: return "2. Watch the first guest play a slot. Arrivals begin after 10 open minutes."
	if guest_revenue < CasinoTuning.OPENING_REVENUE:
		return "3. Collect $%d in guest wagers: $%.0f so far. Payouts and costs reduce your profit." % [CasinoTuning.OPENING_REVENUE, guest_revenue]
	if not feature_owned("blackjack"):
		return "4. Develop capacity with better slots, serve gamblers and retain an operating reserve. Blackjack: $%d + dealer $%d; suggested payout/payroll reserve $%d." % [Games.COSTS.blackjack, CasinoTuning.HIRING_COST, CasinoTuning.BLACKJACK_RESERVE]
	if not feature_owned("service"):
		return "Bar access unlocks a $%d purchase. Budget for service hires and hourly wages before buying." % CasinoTuning.BAR_PURCHASE_COST
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
	if Property.count(floor_chunks) > 0: development += 4.0
	if vip_enabled: development += 4.0
	if high_limit_enabled: development += 4.0
	if feature_owned("service"): development += 2.0
	return development

func rating_for_activity(handle: float, served: int) -> float:
	var development := property_development()
	return minf(100, development * 2.0 + minf(development, handle / CasinoTuning.RATING_HANDLE_UNIT) + minf(development, served / CasinoTuning.RATING_GUEST_UNIT))

func award_milestone(id: String, title: String, body: String, importance: int = 1, tone: String = "positive", details: Dictionary = {}) -> bool:
	if milestone_initializing or id in earned_milestones: return false
	earned_milestones.append(id)
	var event := {"id": id, "title": title, "body": body, "importance": importance, "tone": tone, "elapsed": elapsed}
	event.merge(details, true)
	milestone_reached.emit(event)
	return true

func refresh_progression() -> void:
	casino_rating = rating_for_activity(guest_handle, guests_served)
	Bar.refresh_access(self)
	for level in range(2, stars() + 1):
		if award_milestone("rating:%d" % level, "Casino level %d" % level, CasinoTuning.STAR_NAMES[level - 1] + " - your property and guest business are growing."):
			log_event("DEVELOPMENT - Casino rating increased to %d stars." % level)
	for id in CasinoTuning.SLOT_PROFILES:
		var profile: Dictionary = CasinoTuning.SLOT_PROFILES[id]
		if id not in slot_access and casino_rating >= float(profile.unlock_rating) and guest_handle >= float(profile.unlock_handle):
			slot_access.append(id)
		if restricted() and id != "starter" and id in slot_access:
			if award_milestone("slot:" + id, str(profile.name) + " unlocked", "A new machine option. Compare throughput, repair costs and reserves before buying."):
				log_event("Unlocked: %s. Purchase through Build; retain payout reserves." % profile.name)
	if not restricted(): return
	if not blackjack_unlocked and blackjack_ready(): blackjack_unlocked = true
	if blackjack_unlocked:
		if award_milestone("unlock:blackjack", "Blackjack unlocked", "Your slot business earned table-game access. Plan the table, dealer and payout reserve; purchase when ready.", 2):
			log_event("Unlocked: Blackjack. Table $%d + dealer $%d; aim to retain $%d for payroll and payouts. Purchase when ready." % [Games.COSTS.blackjack, CasinoTuning.HIRING_COST, CasinoTuning.BLACKJACK_RESERVE])
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id in ["slots", "blackjack"] or not unlocked(str(milestone.id)): continue
		if milestone.id == "service":
			if award_milestone("unlock:service", "Bar Service Available", "Your casino can now purchase a bar. Drink expectations begin only after purchase; budget for hires and payroll."):
				log_event("Unlocked: Bar purchase. Buy through Build / Amenities when ready; drink service is optional until purchase.")
			continue
		if award_milestone("unlock:" + str(milestone.id), str(milestone.name).replace("’", "'") + " unlocked", "New options are available in Build / Staff. Expand when your business can support them.", 2 if milestone.id == "craps" else 1):
			log_event("Unlocked: %s. Purchase through Build / Staff." % milestone.name)

func check_profit_milestone() -> void:
	var profit := operating_profit()
	if guest_handle >= CasinoTuning.MILESTONE_PROFIT_HANDLE and profit >= CasinoTuning.MILESTONE_PROFIT:
		if award_milestone("first_profit", "First meaningful operating profit", "Settled guest gaming and bar income have covered recurring costs. Capital purchases remain separate.", 1, "positive", {"amount": profit}):
			log_event("MILESTONE - First meaningful operating profit: $%.2f after recurring costs." % profit)

func thirst_discomfort() -> float:
	return CasinoTuning.THIRST_DISCOMFORT

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

func floor_rect() -> Rect2:
	return Property.rectangle(floor_chunks)

func walk_area() -> Rect2:
	return Property.walking(floor_chunks)

func build_area() -> Rect2:
	return Property.placement("blackjack", floor_chunks)

func placement_area(kind: String) -> Rect2:
	return Property.placement(kind, floor_chunks)

func property_upkeep_rate() -> float:
	return Property.upkeep(floor_chunks)

func expansion_quote(direction: String) -> Dictionary:
	return Property.quote(floor_chunks, direction)

func purchase_expansion(direction: String) -> bool:
	var quote := expansion_quote(direction)
	if quote.is_empty() or not quote.allowed or not unlocked("expansion"): return false
	if cash < float(quote.cost):
		log_event("Expansion needs $%.0f in casino cash." % float(quote.cost))
		return false
	spend_nonpayroll(float(quote.cost), "construction")
	floor_chunks = quote.chunks.duplicate()
	emit_financial_event(-float(quote.cost), "construction", {}, -1, {"position": CasinoTuning.ENTRY, "source": "floor_expansion", "direction": direction, "added_area": float(quote.added_area)})
	reroute()
	refresh_progression()
	award_milestone("expansion", "Floor expanded", "More space also adds property overhead. Income requires operating assets.", 2)
	log_event("PROPERTY - Added %s floor space. Property upkeep is now $%.2f/game hour." % [direction, property_upkeep_rate()])
	return true

func purchase_upgrade(feature: String) -> bool:
	if feature not in ["vip", "high_limit"] or feature_owned(feature) or not unlocked(feature): return false
	var cost := feature_cost(feature)
	if cash < cost:
		log_event("This upgrade needs $%d in casino cash." % cost)
		return false
	spend_nonpayroll(cost, "construction")
	match feature:
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
	var item := {"kind": kind, "staff_priority": 1, "staff_enabled": true, "staff_rotation_until": -1, "slot_profile": profile_id if kind == "slots" else "", "round": {}, "roulette_bets": {}, "id": next_id, "x": at.x, "y": at.y, "rotated": rotated, "point": 0, "dice": [1, 1], "timer": 0.0, "wagers": 0.0, "payouts": 0.0, "broken": false, "rolls": 0, "shooter": -1, "shooter_seat": -1, "hand_rolls": 0, "owner_queued": false, "betting_hold": false, "owner_working": false, "history": [], "service_minutes": 0, "available_minutes": 0, "occupied_minutes": 0, "downtime_minutes": 0, "operating_expense": 0.0, "repair_expense": 0.0, "payroll_expense": 0.0, "visitor_gaming_win": 0.0, "repairs": 0, "breakdowns": 0, "minimum": float(CasinoTuning.SLOT_PROFILES[profile_id].minimum) if kind == "slots" else float(CasinoTuning.GAME_LIMITS[kind].minimum), "owner": CrapsRules.empty_bets(), "result": "Come-out roll. Place a Pass Line bet to start." if kind == "craps" else "Ready for the first guest."}
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
	if category == "gaming" and (guest_id > 0 or (guest_id == -1 and not event.get("participants", []).is_empty())) and absf(amount) >= CasinoTuning.MILESTONE_LARGE_RESULT:
		award_milestone("first_large_win" if amount > 0 else "first_large_loss", "First large house win" if amount > 0 else "First large guest win", "A settled gambling result. Short-term swings are real; keep a payout reserve.", 2 if absf(amount) >= CasinoTuning.MILESTONE_MAJOR_RESULT else 1, "positive" if amount > 0 else "caution", {"amount": amount, "asset_id": event.asset_id, "guest_id": guest_id})
	if category == "gaming" and amount <= -CasinoTuning.EVENT_GUEST_BIG_WIN and (guest_id > 0 or (guest_id == -1 and not event.get("participants", []).is_empty())):
		momentum.guest_win(elapsed)
	if category == "gaming" and (guest_id > 0 or (guest_id == -1 and not event.get("participants", []).is_empty())):
		optional_objectives.observe(self, "gaming_profit", amount, float(details.get("settled_stake", 0)))
	if category == "bar" and guest_id > 0 and not bool(details.get("comped", true)) and float(details.get("price", 0)) > 0:
		optional_objectives.observe(self, "paid_drinks", 1)
	financial_event.emit(event)

func emit_gaming_result(table: Dictionary, staked: float, returned: float, guest_id: int, participants: Array = []) -> void:
	if staked <= 0 and returned <= 0: return # No resolved activity: no invented result.
	if guest_id == 0: table.visitor_gaming_win += staked - returned
	emit_financial_event(staked - returned, "gaming", table, guest_id, {"settled_stake": staked, "returned": returned, "asset_wagers": float(table.wagers), "asset_payouts": float(table.payouts), "asset_repair_expense": float(table.repair_expense), "asset_operating_expense": float(table.operating_expense), "asset_payroll_expense": float(table.payroll_expense), "asset_available_minutes": int(table.available_minutes), "asset_occupied_minutes": int(table.occupied_minutes), "asset_downtime_minutes": int(table.downtime_minutes), "participants": participants.duplicate(true), "slot_profile": str(table.slot_profile) if table_kind(table) == "slots" else "", "round": int(table.rolls) + 1})

func get_table(id: int) -> Dictionary:
	if indexed_step: return step_tables.get(id, {})
	for table in tables:
		if int(table.id) == id:
			return table
	return {}

func crew(id: int) -> Array:
	if indexed_step: return step_crew.get(id, [])
	return staff.filter(func(s): return s.role == "Dealer" and s.duty == "Active" and int(s.table) == id)

func seated(id: int) -> Array:
	return guests.filter(func(g): return int(g.table) == id and g.state == "Playing")

func reserved_guests(id: int, except_guest_id: int = -1) -> Array:
	# Walking guests already own a position; presentation must show that reservation.
	return guests.filter(func(g): return int(g.table) == id and int(g.id) != except_guest_id and int(g.seat) >= 0 and g.state in ["Walking", "Entering seat", "Playing"])

func table_kind(table: Dictionary) -> String:
	return str(table.get("kind", ""))

func required_crew(table: Dictionary) -> int:
	return 0 if table_kind(table) == "slots" else (CasinoTuning.CREW_REQUIRED if table_kind(table) == "craps" else 1)

func capacity(table: Dictionary) -> int:
	return 1 if table_kind(table) == "slots" else CasinoTuning.TABLE_CAPACITY

func guest_capacity(table: Dictionary) -> int:
	# Table games reserve an owner rail seat; slots only do so when joined.
	var owner_seats := 1 if table_kind(table) != "slots" or joined == int(table.id) else 0
	return maxi(0, capacity(table) - owner_seats)

func game_pending(table: Dictionary) -> bool:
	return not table.get("round", {}).is_empty() and table.round.get("phase", "done") != "done"

func ready_for_play(table: Dictionary) -> bool:
	return not table.is_empty() and not table.broken and (required_crew(table) == 0 or crew(int(table.id)).size() >= required_crew(table))

func operating(table: Dictionary) -> bool:
	return opened and accepting_new_play(table)

func table_status(table: Dictionary, assigned: Variant = null) -> String:
	if table.broken: return "Repair needed"
	var required := required_crew(table)
	if required > 0:
		var employees: Array = crew(int(table.id)) if assigned == null else assigned
		if employees.any(func(e): return e.rest_due != ""): return "Finishing bets for staff rest"
		if not table.staff_enabled: return "Staffing paused"
		if employees.size() < required: return "Needs %d dealers" % (required - employees.size())
	return "Open" if opened else "Doors closed | owner play available"

func floor_presentation() -> Dictionary:
	# Read-only references scoped to a draw/refresh; never used to settle gameplay.
	var result := {"tables": {}, "guests": {}, "seated": {}, "reserved": {}, "crew": {}, "status": {}, "operating": {}, "hot": {}}
	for guest in guests:
		result.guests[int(guest.id)] = guest
		var id := int(guest.table)
		if guest.state == "Playing":
			if not result.seated.has(id): result.seated[id] = []
			result.seated[id].append(guest)
		if int(guest.seat) >= 0 and guest.state in ["Walking", "Entering seat", "Playing"]:
			if not result.reserved.has(id): result.reserved[id] = []
			result.reserved[id].append(guest)
	for employee in staff:
		if employee.role != "Dealer" or employee.duty != "Active": continue
		var id := int(employee.table)
		if not result.crew.has(id): result.crew[id] = []
		result.crew[id].append(employee)
	for table in tables:
		var id := int(table.id)
		result.tables[id] = table
		var employees: Array = result.crew.get(id, [])
		result.status[id] = table_status(table, employees)
		result.operating[id] = opened and not table.broken and (required_crew(table) == 0 or (table.staff_enabled and employees.size() >= required_crew(table) and not employees.any(func(e): return e.rest_due != "")))
		result.hot[id] = table_hot(table, result.seated.get(id, []).size(), bool(result.operating[id]))
	return result

func hire(role: String, target: int) -> bool:
	if role not in ["Dealer", "Service"]: return false
	if role == "Service" and not bar_owned:
		log_event("Purchase the bar before hiring drink service staff.")
		return false
	if role == "Dealer" and not unlocked("blackjack"):
		log_event("Develop the casino and complete the next unlock requirements for this staff role.")
		return false
	if staff.size() >= CasinoTuning.MAX_STAFF:
		log_event("Staff limit reached for this small casino.")
		return false
	if cash < CasinoTuning.HIRING_COST:
		log_event("Hiring needs $%d for training." % CasinoTuning.HIRING_COST)
		return false
	spend_nonpayroll(CasinoTuning.HIRING_COST, "hiring")
	staff.append(Staffing.new_employee(self, role))
	Staffing.rebalance(self, true)
	refresh_progression()
	log_event("%s hired. Automatic coverage and relief rotation enabled." % role)
	return true

func staffing_summary(role: String) -> Dictionary:
	return Staffing.summary(self, role)

func set_relief_target(role: String, amount: int) -> void:
	if role not in relief_targets: return
	relief_targets[role] = clampi(amount, 0, CasinoTuning.MAX_STAFF)
	Staffing.rebalance(self, true)

func set_service_positions(amount: int) -> void:
	service_positions = clampi(amount, 1, CasinoTuning.MAX_STAFF)
	Staffing.rebalance(self, true)

func staff_rest(employee: Dictionary, off_duty: bool = false) -> void:
	if employee not in staff: return
	Staffing.request_rest(self, employee, "Off Duty" if off_duty else "Break")
	Staffing.rebalance(self)

func set_staff_priority(id: int, priority: int) -> void:
	var table := get_table(id)
	if table.is_empty() or required_crew(table) == 0: return
	table.staff_priority = clampi(priority, 0, 2)
	Staffing.rebalance(self)

func set_table_staffed(id: int, enabled: bool) -> void:
	var table := get_table(id)
	if table.is_empty() or required_crew(table) == 0: return
	table.staff_enabled = enabled
	Staffing.rebalance(self)

func accepting_new_play(table: Dictionary) -> bool:
	return ready_for_play(table) and (required_crew(table) == 0 or (table.staff_enabled and not crew(int(table.id)).any(func(e): return e.rest_due != "")))

func bounds(table: Dictionary) -> Rect2:
	var size := furniture_size(table_kind(table), bool(table.rotated))
	return Rect2(Vector2(table.x, table.y), size)

func approach_position(table: Dictionary) -> Vector2:
	# Owners use the reserved rail position on table games, or the slot chair.
	return guest_approach_position(table, capacity(table) - 1)

func guest_seat_position(table: Dictionary, seat: int) -> Vector2:
	return Seating.seat_position_for(table_kind(table), seat, bounds(table), bool(table.rotated), int(table.id))

func guest_approach_position(table: Dictionary, seat: int) -> Vector2:
	return Seating.approach_position_for(table_kind(table), seat, bounds(table), bool(table.rotated), int(table.id))

func furniture_size(kind: String, rotated: bool) -> Vector2:
	return Placement.furniture_size(kind, rotated)

func dealer_position(table: Dictionary, index: int) -> Vector2:
	return Seating.dealer_position_for(table_kind(table), index, bounds(table), bool(table.rotated), int(table.id))

func placement_geometry() -> Array:
	if placement_world_revision != geometry_revision:
		placement_world = []
		for table in tables: placement_world.append(Placement.for_table(table))
		placement_world_revision = geometry_revision
	return placement_world

func placement_access_points(owns_bar: bool) -> PackedVector2Array:
	var points := PackedVector2Array([CAGE_PICKUP])
	if owns_bar:
		points.append(bar_pickup())
		for slot in range(CasinoTuning.BAR_GUEST_OFFSETS.size()): points.append(bar_guest_position(slot))
	return points

func placement_report(at: Vector2, rotated: bool, ignore_id: int = -1, kind: String = "craps") -> Dictionary:
	if ignore_id >= 0:
		var moving := get_table(ignore_id)
		if moving.is_empty(): return {"valid": false, "errors": [{"message": "Missing asset to move", "position": at}], "candidate": {}}
		kind = table_kind(moving)
	var proposed_id := ignore_id if ignore_id >= 0 else next_id
	var signature := [at, rotated, ignore_id, kind, proposed_id, geometry_revision, bar_owned]
	if signature == placement_signature: return placement_result
	var candidate := Placement.geometry(kind, at, rotated, proposed_id)
	var assets: Array = []
	for asset in placement_geometry():
		if int(asset.id) != ignore_id: assets.append(asset)
	assets.append(candidate)
	placement_result = Placement.validate(floor_chunks, assets, placement_access_points(bar_owned))
	placement_result.candidate = candidate
	if ignore_id < 0 and tables.size() >= CasinoTuning.MAX_ASSETS:
		placement_result.valid = false
		placement_result.errors.append({"message": "Asset limit reached", "position": at})
	placement_signature = signature
	return placement_result

func can_place(at: Vector2, rotated: bool, ignore_id: int = -1, kind: String = "craps") -> bool:
	return bool(placement_report(at, rotated, ignore_id, kind).valid)

func place(at: Vector2, rotated: bool, kind: String = "craps", profile_id: String = "starter") -> int:
	if tables.size() >= CasinoTuning.MAX_ASSETS:
		log_event("This prototype supports up to %d gaming assets." % CasinoTuning.MAX_ASSETS)
		return -1
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
	if kind != "slots": award_milestone("first_table", "First table installed", "Your casino has its first purchased table. Assign the required dealers before accepting guests.", 2, "positive", {"asset_id": int(table.id)})
	log_event("%s #%d built for $%d. Required dealers: %d." % [asset_name(table), table.id, cost, required_crew(table)])
	if kind == "slots" and cash < float(slot_profile(table).reserve): log_event("RESERVE - %s suggests $%d operating reserve; treasury $%d." % [asset_name(table), slot_profile(table).reserve, cash])
	return int(table.id)

func busy(table: Dictionary) -> bool:
	return int(owner_play.get("target", -1)) == int(table.id) or joined == int(table.id) or guests.any(func(g): return int(g.table) == int(table.id)) or CrapsRules.exposure(table.owner) > 0 or game_pending(table) or not table.get("roulette_bets", {}).is_empty()

func sell(id: int) -> bool:
	var table := get_table(id)
	if table.is_empty() or busy(table):
		log_event("Let guests leave and settle visitor bets before selling this table.")
		return false
	for employee in crew(id):
		employee.table = -1
		employee.duty = "Relief"
	table_interest.erase(int(table.id))
	clear_repair_waiters(id)
	tables.erase(table)
	Staffing.rebalance(self)
	reroute()
	incidents = incidents.filter(func(incident): return int(incident.table) != id)
	var resale := (float(slot_profile(table).cost) if table_kind(table) == "slots" else float(Games.COSTS[table_kind(table)])) / 2
	spend_nonpayroll(-resale, "sales")
	emit_financial_event(resale, "sale", table, -1, {"asset_wagers": table.wagers, "asset_payouts": table.payouts, "asset_repair_expense": table.repair_expense, "asset_operating_expense": table.operating_expense, "asset_payroll_expense": table.payroll_expense, "asset_visitor_gaming_win": table.visitor_gaming_win, "asset_spins": table.rolls, "asset_available_minutes": table.available_minutes, "asset_occupied_minutes": table.occupied_minutes, "asset_downtime_minutes": table.downtime_minutes, "slot_profile": table.slot_profile})
	refresh_progression()
	log_event("Sold for $%d. Dealers return to the relief / shift roster." % resale)
	return true

func set_open(value: bool) -> void:
	opened = value
	Staffing.rebalance(self)
	if value: ever_opened = true
	if not value:
		for guest in guests: Bar.cancel_order(self, guest)
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

func table_hot(table: Dictionary, occupancy: int = -1, active: Variant = null) -> bool:
	if table.is_empty() or table_kind(table) == "slots": return false
	if not (operating(table) if active == null else bool(active)): return false
	if (seated(int(table.id)).size() if occupancy < 0 else occupancy) < CasinoTuning.HOT_PLAYER_COUNT: return false
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
	if restricted() and not vip:
		for offer in CasinoTuning.GUEST_UNLOCK_BUDGETS:
			if float(offer.wager) > float(budget.wager) and slot_unlocked(str(offer.slot_profile)) and rng.randf() < float(offer.share):
				budget = offer
	var archetype_id := choose_archetype(vip)
	var profile: Dictionary = CasinoTuning.GUEST_ARCHETYPES[archetype_id]
	var bankroll := float(rng.randi_range(budget.bankroll.x, budget.bankroll.y)) if not vip else 5000.0
	if not vip: bankroll = clampf(roundf(bankroll * float(profile.bankroll_scale)), budget.bankroll.x, budget.bankroll.y)
	guests.append({"archetype": archetype_id, "id": next_id, "name": CasinoTuning.NAMES[rng.randi_range(0, 11)] + (" | VIP" if vip else ""), "x": CasinoTuning.ENTRY.x, "y": CasinoTuning.ENTRY.y, "tx": CasinoTuning.ENTRY.x, "ty": CasinoTuning.ENTRY.y + 20, "table": -1, "seat": -1, "state": "Arriving", "wallet": bankroll, "start": bankroll, "rounds": 0, "last_wager_minute": -1, "bar_slot": -1, "drink_spending": 0.0, "drink_order": "", "drink_quote": 0.0, "drink_request_at": 0, "wager_limit": 100.0 if vip else float(budget.wager), "satisfaction": 80.0, "thirst": 0.0, "age": 0, "session_left": 0.0, "activities": 0, "activity_since": elapsed, "decision_at": elapsed + rng.randi_range(1, 5), "wait_since": -1, "last_table": -1, "explored_without_game": false, "preference": profile.games[rng.randi_range(0, profile.games.size() - 1)], "patience": roundi(rng.randi_range(profile.patience.x, profile.patience.y) * float(CasinoTuning.TRAFFIC_RULES[difficulty].patience)), "demand_blocked": false, "unmet_visit_recorded": false, "demand_wait": 0, "demand_attempts": 0, "demand_failure_wait": 0, "operational_failure": "", "repair_wait_table": -1, "repair_frustrated": false, "watch_left": 0, "watch_style": rng.randi_range(0, 2), "vip": vip, "bets": CrapsRules.empty_bets(), "thought": "Looking for an open game."})
	traffic_totals.arrivals += 1
	if vip: award_milestone("first_vip", "First VIP arrival", "A real VIP guest has entered. Higher wagers also mean greater payout exposure.", 2, "positive", {"guest_id": next_id})
	DrinkService.initialize(guests[-1], elapsed)
	think(guests[-1], guest_arrival_thought(guests[-1]))
	next_id += 1

func traffic_snapshot() -> Dictionary:
	var positions := 0
	var occupied := 0
	var appeal := 0.0
	var kinds := {}
	for table in tables:
		if not operating(table): continue
		var seats := guest_capacity(table)
		positions += seats
		occupied += mini(seats, reserved_guests(int(table.id)).size())
		appeal += seats * (float(slot_profile(table).appeal) if table_kind(table) == "slots" else 1.2)
		kinds[table_kind(table)] = true
	var peak := minute >= 1080 and minute < 1380
	var quiet := minute < 420
	var rules: Dictionary = CasinoTuning.TRAFFIC_RULES[difficulty]
	var extra := maxi(1, ceili(positions * float(rules.peak_overflow if peak else rules.overflow)))
	var active := guests.filter(func(g): return g.state not in ["To cage", "Cashing out", "Leaving"]).size()
	var waiting := guests.filter(func(g): return bool(g.demand_blocked) and g.state not in ["To cage", "Cashing out", "Leaving"]).size()
	# Bound perception effects: a bad night cannot switch off all future business.
	var attraction := clampf(0.85 + reputation / 300.0, 0.85, 1.18)
	attraction *= momentum.arrival_modifier()
	attraction *= clampf(0.9 + satisfaction() / 800.0, 0.9, 1.025)
	attraction *= clampf(appeal / maxf(1, positions), 1.0, 1.6)
	attraction *= 1.0 + minf(0.25, maxf(0, kinds.size() - 1) * 0.08 + casino_rating / 500.0)
	if positions > 0 and occupied > 0 and active <= positions: attraction *= 1.05 # Moderate activity is social proof.
	var scale := clampf(sqrt(maxf(1, positions) / 2.0) * attraction * float(rules.pressure), 0.65, CasinoTuning.TRAFFIC_MAX_ACCELERATION)
	return {"positions": positions, "occupied": occupied, "waiting": waiting, "active": active,
		"limit": mini(CasinoTuning.MAX_GUESTS, positions + extra), "scale": scale,
		"cycle": "Peak" if peak else "Quiet" if quiet else "Steady"}

func arrival_step() -> void:
	if not opened: return
	var traffic := traffic_snapshot()
	traffic_totals.position_minutes += int(traffic.positions)
	traffic_totals.occupied_minutes += int(traffic.occupied)
	arrival_in -= 1
	if arrival_in > 0: return
	var interval := CasinoTuning.ARRIVAL_MINUTES if traffic.cycle == "Peak" else CasinoTuning.QUIET_ARRIVAL_MINUTES
	var quiet_scale := 1.5 if traffic.cycle == "Quiet" else 1.0
	arrival_in = maxi(4, roundi(rng.randi_range(interval.x, interval.y) * quiet_scale / float(traffic.scale)))
	if guests.size() >= int(traffic.limit) or guests.size() >= CasinoTuning.MAX_GUESTS:
		traffic_totals.deferred_attempts += 1
		return
	# Overflow remains possible, but crowded floors do not receive every opportunity.
	if int(traffic.active) >= int(traffic.positions) and rng.randf() > CasinoTuning.TRAFFIC_FULL_ARRIVAL_CHANCE:
		traffic_totals.deferred_attempts += 1
		return
	var party := 2 if rng.randf() < CasinoTuning.TRAFFIC_GROUP_CHANCE else 1
	for i in range(mini(party, int(traffic.limit) - guests.size())):
		var vip := vip_enabled and rng.randf() < 0.05
		spawn_guest(vip)
		if vip: log_event("A VIP arrived with the next small group.")

func mark_unmet_demand(guest: Dictionary) -> void:
	if not guest.unmet_visit_recorded:
		traffic_totals.unmet_visits += 1
		guest.unmet_visit_recorded = true
	guest.demand_blocked = true
	guest.demand_attempts += 1
	if int(guest.wait_since) < 0: guest.wait_since = elapsed

func demand_wait_step(guest: Dictionary) -> bool:
	if not guest.demand_blocked: return false
	# Gambling down a wallet is a completed visit, not unmet casino demand.
	if not tables.any(func(table): return game_within_budget(table, guest)):
		guest.demand_blocked = false
		leave(guest, "Time to cash out." if guest.rounds > 0 else "These stakes aren't for me.")
		return true
	guest.demand_wait += 1
	var repair := guest_blocked_repair(guest)
	guest.repair_wait_table = int(repair.get("id", -1))
	var failure := "unresolved_repair" if not repair.is_empty() else guest_demand_failure(guest)
	if failure != "": guest.demand_failure_wait += 1
	else: guest.demand_failure_wait = 0
	guest.repair_frustrated = not repair.is_empty() and guest.demand_failure_wait > CasinoTuning.REPAIR_WAIT_GRACE_MINUTES
	if guest.repair_frustrated:
		guest.operational_failure = "unresolved_repair"
		guest.satisfaction = maxf(0, guest.satisfaction - CasinoTuning.REPAIR_WAIT_SATISFACTION_LOSS)
		change_reputation(-CasinoTuning.REPAIR_WAIT_REPUTATION_LOSS * float(CasinoTuning.TRAFFIC_RULES[difficulty].rep_loss), "repair.waiting_guest", guest, "waiting", "An unrepaired game is blocking this guest's play.")
		think(guest, "This game is still broken. Why hasn't it been repaired?", 3)
	elif float(guest.demand_failure_wait) > guest.patience * CasinoTuning.TRAFFIC_WAIT_GRACE_FRACTION:
		guest.operational_failure = failure
		guest.satisfaction = maxf(0, guest.satisfaction - CasinoTuning.TRAFFIC_WAIT_SATISFACTION_LOSS / float(CasinoTuning.TRAFFIC_RULES[difficulty].patience))
		think(guest, "Still waiting for a game. I'll try again.", 2)
	if float(guest.demand_wait) >= guest.patience * CasinoTuning.TRAFFIC_WAIT_LIMIT_FRACTION:
		var affordable: bool = tables.any(func(table): return affordable_game(table, guest))
		leave(guest, "No room tonight. I'll come back later." if affordable else "No affordable staffed game tonight.", "capacity" if affordable else "affordability")
		return true
	return false

func wait_for_game(guest: Dictionary) -> void:
	mark_unmet_demand(guest)
	if float(guest.demand_wait) >= guest.patience * CasinoTuning.TRAFFIC_WAIT_LIMIT_FRACTION:
		leave(guest, "No room tonight. I'll come back later.", "capacity")
		return
	var repair := guest_blocked_repair(guest)
	if not repair.is_empty():
		wait_near_repair(guest, repair)
		return
	# Waiting at the bar never resets the cumulative unmet-demand budget.
	if rng.randf() < CasinoTuning.BAR_WAIT_CHANCE and start_guest_bar(guest): return
	if guest.state == "Waiting" and int(guest.demand_attempts) % 3 == 0:
		start_guest_exploration(guest)
	else:
		guest.table = -1
		guest.seat = -1
		guest.state = "Waiting"
		guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_DECISION_GAP.x, CasinoTuning.GUEST_DECISION_GAP.y)
		think(guest, "The games in my budget are taken. I'll wait.", 2)

func observation_spot(table: Dictionary, id: int) -> Vector2:
	var rect := bounds(table)
	var offset := float(id % 3 - 1) * 32
	var spots := [Vector2(rect.get_center().x + offset, rect.end.y + 60), Vector2(rect.get_center().x + offset, rect.position.y - 60), Vector2(rect.end.x + 55, rect.get_center().y + offset), Vector2(rect.position.x - 55, rect.get_center().y + offset)]
	for at in spots:
		if walk_area().has_point(at) and not tables.any(func(t): return bounds(t).grow(16).has_point(at)):
			return at
	return Vector2(INF, INF)

func watching_step(guest: Dictionary) -> void:
	var table := get_table(int(guest.table))
	if not opened or table.is_empty() or not operating(table):
		if opened: start_guest_exploration(guest)
		else: leave(guest, "The casino is closing.")
		return
	var reserved := reserved_guests(int(table.id), int(guest.id)).size()
	# Watching follows real players; do not linger at a deserted game.
	if seated(int(table.id)).is_empty():
		if affordable_game(table, guest): choose_table(guest, false)
		else: start_guest_exploration(guest)
		return
	if guest_current_interest(guest) == table_kind(table) and affordable_game(table, guest) and reserved < guest_capacity(table) and elapsed - int(guest.activity_since) >= 2:
		think(guest, "A seat opened. I'll play.", 2)
		choose_table(guest, false)
		return
	guest.watch_left = maxi(0, int(guest.watch_left) - 1)
	var hot := table_hot(table)
	var dice_game := table_kind(table) == "craps"
	var reset: bool = dice_game and not table.history.is_empty() and bool(table.history[0].seven_out)
	think(guest, "Watching the slot player before deciding." if table_kind(table) == "slots" else "Watching the table before deciding.")
	if hot: think(guest, "This table is getting hot.", 2)
	elif reset: think(guest, "Seven-out. Watching the new shooter.")
	if int(guest.watch_left) > 0: return
	# This is guest psychology only; history never changes the dice probabilities.
	var chance := 0.70
	if int(guest.watch_style) == 1: chance = 0.90 if hot else (0.30 if reset else 0.55)
	elif int(guest.watch_style) == 2 and dice_game: chance = 0.85 if reset or int(table.point) == 0 else 0.45
	if rng.randf() < chance:
		choose_table(guest, false)
	else:
		finish_guest_session(guest)

func game_within_budget(table: Dictionary, guest: Dictionary) -> bool:
	if table.is_empty() or guest.wager_limit < table.minimum: return false
	var wager := guest_wager(table, guest)
	return wager >= float(table.minimum) and guest.wallet >= wager * (6 if table_kind(table) == "holdem" else 1)

func affordable_game(table: Dictionary, guest: Dictionary) -> bool:
	return operating(table) and game_within_budget(table, guest)

func capacity_expansion_reasonable() -> bool:
	# A tiny advertised offering is not poor service, even when the owner saves cash.
	# Expectations grow with actual development, not elapsed time or unlocked variety.
	if gaming_development(true) < CasinoTuning.REPUTATION_CAPACITY_DEVELOPMENT: return false
	var reserve := reserve_report("slots", "starter")
	if development_cash() < float(reserve.purchase) + float(reserve.required): return false
	# Requiring a property purchase first is not a readily preventable seat shortage.
	var area := placement_area("slots")
	for y in range(ceili(area.position.y), floori(area.end.y), CasinoTuning.REPUTATION_CAPACITY_PLACEMENT_STEP):
		for x in range(ceili(area.position.x), floori(area.end.x), CasinoTuning.REPUTATION_CAPACITY_PLACEMENT_STEP):
			if can_place(Vector2(x, y), false, -1, "slots"): return true
	return false

func guest_blocked_repair(guest: Dictionary) -> Dictionary:
	if not opened: return {}
	var repair: Dictionary = {}
	var nearest := INF
	for table in tables:
		if not game_within_budget(table, guest): continue
		if operating(table) and reserved_guests(int(table.id), int(guest.id)).size() < guest_capacity(table): return {}
		if not table.broken: continue
		var distance := Vector2(guest.x, guest.y).distance_squared_to(bounds(table).get_center())
		if distance < nearest:
			nearest = distance
			repair = table
	return repair

func clear_repair_waiters(table_id: int) -> void:
	for guest in guests:
		if guest.repair_wait_table != table_id: continue
		guest.repair_wait_table = -1
		guest.repair_frustrated = false
		guest.decision_at = elapsed

func wait_near_repair(guest: Dictionary, table: Dictionary) -> void:
	guest.repair_wait_table = int(table.id)
	guest.table = -1
	guest.seat = -1
	guest.state = "Waiting"
	guest.decision_at = elapsed + CasinoTuning.REPAIR_WAIT_RETRY_MINUTES
	var at := observation_spot(table, int(guest.id))
	if at.is_finite():
		guest.tx = at.x
		guest.ty = at.y
		route(guest)
	think(guest, "I'm waiting for this machine to be repaired." if table_kind(table) == "slots" else "I'm waiting for this table to be repaired.", 2)

func guest_demand_failure(guest: Dictionary) -> String:
	var funded := false
	var unavailable := false
	for table in tables:
		if not game_within_budget(table, guest): continue
		funded = true
		if not operating(table): unavailable = true
		elif reserved_guests(int(table.id), int(guest.id)).size() < guest_capacity(table): return ""
	if unavailable: return "equipment_or_coverage"
	if funded and capacity_expansion_reasonable(): return "preventable_capacity"
	return ""

func game_choice_score(table: Dictionary, guest: Dictionary, reserved: int, interest: String) -> float:
	var profile := archetype(guest)
	var value := 100.0 + (float(profile.preference_bonus) if interest == table_kind(table) else 0.0)
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

func release_guest_seat(guest: Dictionary, preserve_drink_order: bool = false) -> void:
	if preserve_drink_order: DrinkService.release_assignment(self, guest)
	else: Bar.cancel_order(self, guest)
	if int(guest.table) > 0: guest.last_table = int(guest.table)
	guest.table = -1
	guest.seat = -1
	guest.bar_slot = -1
	guest.wait_since = -1
	guest.activity_since = elapsed

func start_guest_bar(guest: Dictionary) -> bool:
	if not opened or not bar_available() or drink_menu.is_empty(): return false
	for slot in range(CasinoTuning.BAR_GUEST_OFFSETS.size()):
		if guests.any(func(other): return other != guest and int(other.bar_slot) == slot and other.state in ["To bar", "At bar"]): continue
		var target := bar_guest_position(slot)
		if tables.any(func(table): return bounds(table).grow(16).has_point(target)): continue
		release_guest_seat(guest, true)
		guest.bar_slot = slot
		guest.state = "To bar"
		guest.tx = target.x
		guest.ty = target.y
		route(guest)
		if guest.thirst >= CasinoTuning.DRINK_THIRST_TRIGGER:
			DrinkService.begin(self, guest)
			DrinkService.transition(self, guest, "SEEKING_SERVICE")
		else: think(guest, "Taking a break at the bar.", 2)
		return true
	return false

func start_guest_exploration(guest: Dictionary) -> void:
	release_guest_seat(guest)
	guest.state = "Exploring"
	guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_EXPLORE_MINUTES.x, CasinoTuning.GUEST_EXPLORE_MINUTES.y)
	# A purposeful short walk through reachable aisles; no indefinite wandering.
	var area := walk_area().grow(-20)
	var target := Vector2(guest.x, guest.y)
	for attempt in range(12):
		var candidate := Vector2(rng.randf_range(area.position.x, area.end.x), rng.randf_range(area.position.y, area.end.y))
		if not tables.any(func(table): return bounds(table).grow(20).has_point(candidate)):
			target = candidate
			break
	guest.tx = target.x
	guest.ty = target.y
	route(guest)
	think(guest, "I'll look around.", 2)

func guest_exit_reason(guest: Dictionary) -> String:
	if not opened: return "The casino is closing."
	if guest.satisfaction < 25: return "My drink never arrived. I'm leaving." if guest.drink_failure != "" else "Not my night. I'm leaving."
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
	if (guest.thirst >= CasinoTuning.DRINK_THIRST_TRIGGER or rng.randf() < CasinoTuning.BAR_BREAK_CHANCE) and start_guest_bar(guest): return
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
	if guest.state not in ["To bar", "At bar"] and demand_wait_step(guest): return
	if guest.satisfaction < 25:
		leave(guest, guest_exit_reason(guest))
		return
	if guest.state == "Watching":
		watching_step(guest)
	elif guest.state in ["Walking", "Entering seat"] and elapsed - int(guest.activity_since) > guest.patience:
		guest.operational_failure = "unreachable_game"
		guest.satisfaction = maxf(0, float(guest.satisfaction) - CasinoTuning.REPUTATION_ROUTE_SATISFACTION_LOSS)
		leave(guest, "Could not reach that game.")
	elif guest.state == "Browsing" and elapsed - int(guest.activity_since) > guest.patience:
		start_guest_exploration(guest)
	elif guest.state == "Exploring" and elapsed >= int(guest.decision_at):
		if elapsed - int(guest.activity_since) > guest.patience:
			leave(guest, "Couldn't find a comfortable route.")
		elif Vector2(guest.x, guest.y).distance_to(Vector2(guest.tx, guest.ty)) < 3: choose_table(guest)
	elif guest.state in ["To bar", "At bar"]:
		if guest.drink_state == "SERVICE_FAILED":
			start_guest_exploration(guest)
		elif not bar_available():
			start_guest_exploration(guest)
		elif guest.state == "To bar" and elapsed - int(guest.activity_since) > guest.patience:
			DrinkService.fail(self, guest, "Could not reach the bar")
			start_guest_exploration(guest)
		elif guest.state == "At bar":
			if guest.drink_state in ["SEEKING_SERVICE", "WAITING_FOR_SERVICE", "SERVICE_ASSIGNED"]: return
			if elapsed >= int(guest.decision_at):
				think(guest, "Back to the games.", 2)
				choose_table(guest)
			else:
				think(guest, "Watching the floor from the bar.")
	elif guest.state == "Waiting" and elapsed >= int(guest.decision_at):
		guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_DECISION_GAP.x, CasinoTuning.GUEST_DECISION_GAP.y)
		choose_table(guest)

func choose_table(guest: Dictionary, allow_watch: bool = true) -> void:
	Bar.cancel_order(self, guest)
	guest.bar_slot = -1
	var best: Dictionary = {}
	var score := -INF
	var interest := guest_current_interest(guest)
	var reservations := {}
	# Compute once per decision instead of scanning the crowd for every asset.
	for other in guests:
		if int(other.id) != int(guest.id) and int(other.seat) >= 0 and other.state in ["Walking", "Entering seat", "Playing"]:
			reservations[int(other.table)] = int(reservations.get(int(other.table), 0)) + 1
	for table in tables:
		# Include guests still walking to their reserved seats.
		var reserved := int(reservations.get(int(table.id), 0))
		if not affordable_game(table, guest) or (reserved >= guest_capacity(table) and not allow_watch): continue
		var value := game_choice_score(table, guest, reserved, interest)
		if reserved >= guest_capacity(table): value -= 10000.0
		if value > score:
			score = value
			best = table
	if best.is_empty():
		if not tables.any(func(table): return game_within_budget(table, guest)):
			guest.demand_blocked = false
			leave(guest, "Time to cash out." if guest.rounds > 0 else "These stakes aren't for me.")
			return
		if not guest_blocked_repair(guest).is_empty():
			wait_for_game(guest)
			return
		if tables.any(func(table): return affordable_game(table, guest)):
			wait_for_game(guest)
			return
		mark_unmet_demand(guest)
		# A bounded observation activity can be worthwhile without a table bankroll.
		if allow_watch and not guest.explored_without_game:
			for table in tables:
				if not operating(table) or seated(int(table.id)).is_empty(): continue
				var watchers := guests.filter(func(other): return int(other.table) == int(table.id) and other.state in ["Browsing", "Watching"]).size()
				var spot := observation_spot(table, int(guest.id))
				if watchers >= CasinoTuning.OBSERVERS_PER_TABLE or not spot.is_finite(): continue
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
			leave(guest, "Couldn't find an affordable open game.", "affordability")
		return
	var observers := guests.filter(func(g): return int(g.table) == int(best.id) and g.state in ["Browsing", "Watching"]).size()
	var seats := reserved_guests(int(best.id), int(guest.id)).size()
	var spot := observation_spot(best, int(guest.id))
	var watch_chance := float(archetype(guest).watch_chance)
	if guest_current_interest(guest) == table_kind(best) and table_kind(best) != "craps": watch_chance *= 0.15
	var intentional_watch: bool = not seated(int(best.id)).is_empty() and (seats >= guest_capacity(best) or rng.randf() < watch_chance)
	if seats >= guest_capacity(best) and not guest_blocked_repair(guest).is_empty():
		wait_for_game(guest)
		return
	if allow_watch and observers < CasinoTuning.OBSERVERS_PER_TABLE and spot.is_finite() and intentional_watch:
		if seats >= guest_capacity(best): mark_unmet_demand(guest)
		guest.table = int(best.id)
		guest.seat = -1
		guest.state = "Browsing"
		guest.activity_since = elapsed
		guest.wait_since = -1
		guest.watch_left = rng.randi_range(4, 10) if seats < guest_capacity(best) else rng.randi_range(CasinoTuning.OBSERVE_MINUTES.x, CasinoTuning.OBSERVE_MINUTES.y)
		guest.tx = spot.x
		guest.ty = spot.y
		think(guest, "I'll watch this slot player while I wait." if table_kind(best) == "slots" else "Watching %s before buying in." % Games.NAMES[table_kind(best)])
		route(guest)
		return
	if seats >= guest_capacity(best):
		wait_for_game(guest)
		return
	guest.table = int(best.id)
	guest.state = "Walking"
	guest.demand_blocked = false
	guest.demand_wait = 0
	guest.demand_attempts = 0
	guest.demand_failure_wait = 0
	guest.repair_wait_table = -1
	guest.repair_frustrated = false
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
	var approach := guest_approach_position(best, slot)
	guest.tx = approach.x
	guest.ty = approach.y
	if table_hot(best):
		think(guest, "This table is drawing a crowd.", 2)
	elif table_kind(best) == "slots" and guest.archetype in ["slots", "vip"]:
		var better_available: bool = tables.any(func(table): return table_kind(table) == "slots" and int(slot_profile(table).prestige) > int(slot_profile(best).prestige))
		think(guest, "That other machine looks better." if better_available else "I like this machine.", 2)
	elif guest_current_interest(guest) != table_kind(best):
		think(guest, "I'll try %s instead." % ("slots" if table_kind(best) == "slots" else "hold'em" if table_kind(best) == "holdem" else table_kind(best)))
	else:
		think(guest, "Found my preferred game.")
	route(guest)

func change_reputation(delta: float, source: String, guest: Dictionary = {}, departure: String = "", reason: String = "") -> void:
	# A happy visit cannot hide ongoing, real repair-blocked guest frustration.
	if delta > 0 and source == "guest.visit_review":
		for other in guests:
			if not other.repair_frustrated or not other.demand_blocked or other.state in ["To cage", "Cashing out", "Leaving"]: continue
			if not guest_blocked_repair(other).is_empty(): return
	var before := reputation
	reputation = clampf(before + delta, 0, 100)
	if delta >= 0: return
	# Snapshot at the mutation, before departure releases seats. No RNG/serialization.
	var available: Array = []
	var affordable: Array = []
	var assets: Array = []
	var occupied := 0
	var positions := 0
	for table in tables:
		var active := operating(table)
		var seats := guest_capacity(table)
		var reserved := mini(seats, reserved_guests(int(table.id)).size())
		if active:
			positions += seats
			occupied += reserved
			if table_kind(table) not in available: available.append(table_kind(table))
		if not guest.is_empty() and affordable_game(table, guest) and table_kind(table) not in affordable:
			affordable.append(table_kind(table))
		assets.append({"id": table.id, "game": table_kind(table), "operating": active, "broken": table.broken, "capacity": seats, "occupied": reserved, "minimum": table.minimum})
	var event := {"source": source, "guest_id": guest.get("id", -1), "guest_satisfaction": guest.get("satisfaction", null), "guest_state": guest.get("state", "N/A"), "guest_wallet": guest.get("wallet", null), "guest_start_bankroll": guest.get("start", null), "drink_failure": guest.get("drink_failure", ""), "departure_reason": departure, "reason": reason, "desired_game": guest_current_interest(guest) if not guest.is_empty() else "N/A", "available_games": available, "affordable_games": affordable, "occupied_capacity": occupied, "available_capacity": positions, "assets": assets, "reputation_before": before, "delta": reputation - before, "requested_delta": delta, "reputation_after": reputation, "elapsed": elapsed, "rating": casino_rating, "cash": cash, "demand_wait": guest.get("demand_wait", 0), "demand_attempts": guest.get("demand_attempts", 0), "operational_failure": guest.get("operational_failure", ""), "repair_wait_table": guest.get("repair_wait_table", -1), "demand_failure_wait": guest.get("demand_failure_wait", 0), "rounds": guest.get("rounds", 0)}
	recent_reputation_losses.append(event)
	if recent_reputation_losses.size() > 128: recent_reputation_losses.pop_front()
	reputation_loss.emit(event)
	if OS.is_debug_build(): print("REPUTATION_LOSS ", JSON.stringify(event))

func leave(guest: Dictionary, reason: String, departure: String = "visit") -> void:
	if CrapsRules.exposure(guest.bets) > 0 or guest.state in ["To cage", "Cashing out", "Leaving"]:
		return
	if int(guest.rounds) > 0:
		guests_served += 1
		if opened and departure != "closed" and float(guest.satisfaction) >= CasinoTuning.OBJECTIVE_HAPPY_SATISFACTION:
			optional_objectives.observe(self, "happy_visits", 1)
		refresh_progression()
	if not opened: departure = "closed"
	elif guest.drink_failure != "" and guest.satisfaction < 25:
		departure = "service"
		log_event("SERVICE - %s left after %s." % [guest.name, str(guest.drink_failure).to_lower()])
	traffic_totals.departures[departure] += 1
	var severe: bool = departure in ["capacity", "affordability"] and guest.demand_blocked and guest.demand_failure_wait >= guest.patience and guest.demand_attempts >= 3 and guest.operational_failure != "unresolved_repair"
	if severe:
		traffic_totals.severe_departures += 1
		traffic_bad_visits += 1
		if traffic_bad_visits >= CasinoTuning.TRAFFIC_BAD_VISITS_PER_REVIEW and elapsed - traffic_reputation_at >= CasinoTuning.TRAFFIC_REPUTATION_COOLDOWN:
			change_reputation(-CasinoTuning.TRAFFIC_REPUTATION_LOSS * float(CasinoTuning.TRAFFIC_RULES[difficulty].rep_loss), "traffic.long_wait_review", guest, departure, reason)
			traffic_bad_visits = 0
			traffic_reputation_at = elapsed
			log_event("DEMAND - Repeated unresolved game access failures disappointed guests. Check repairs, staffing and affordable capacity.")
	# Unserved demand is neutral. Only genuine visits/service experiences affect perception.
	if (not guest.demand_blocked and (int(guest.rounds) > 0 or guest.operational_failure != "")) or guest.drink_failure != "":
		var change := (float(guest.satisfaction) - 65.0) * 0.006
		if int(guest.rounds) == 0: change = minf(0, change)
		if change < 0:
			if guest.drink_failure == "" and guest.operational_failure in ["", "unresolved_repair"]: change = 0
			else: change *= float(CasinoTuning.TRAFFIC_RULES[difficulty].rep_loss)
		change_reputation(change, "guest.visit_review", guest, departure, reason)

	guest.repair_frustrated = false
	guest.repair_wait_table = -1
	Bar.cancel_order(self, guest)
	guest.state = "To cage" if int(guest.rounds) > 0 else "Leaving"
	guest.table = -1
	guest.seat = -1
	guest.bar_slot = -1
	guest.tx = CAGE_PICKUP.x if int(guest.rounds) > 0 else CasinoTuning.ENTRY.x
	guest.ty = CAGE_PICKUP.y if int(guest.rounds) > 0 else CasinoTuning.ENTRY.y
	think(guest, reason, 3)
	route(guest)

func floor_navigation() -> AStarGrid2D:
	if navigation_grid == null:
		navigation_grid = Placement.navigation(floor_chunks, placement_geometry())
	return navigation_grid

func route(guest: Dictionary) -> void:
	var grid := floor_navigation()
	var origin := Vector2i(roundi(guest.x / CasinoTuning.FLOOR_NAV_CELL), roundi(guest.y / CasinoTuning.FLOOR_NAV_CELL))
	var destination := Vector2i(roundi(guest.tx / CasinoTuning.FLOOR_NAV_CELL), roundi(guest.ty / CasinoTuning.FLOOR_NAV_CELL))
	var exit_point := Vector2(INF, INF)
	if grid.is_in_boundsv(origin) and grid.is_point_solid(origin):
		for table in tables:
			if not bounds(table).grow(CasinoTuning.ASSET_NAV_RADIUS + CasinoTuning.FLOOR_NAV_CELL / 2).has_point(Vector2(guest.x, guest.y)): continue
			var nearest := INF
			for seat in range(capacity(table)):
				var distance := Vector2(guest.x, guest.y).distance_squared_to(guest_seat_position(table, seat))
				if distance < nearest:
					nearest = distance
					exit_point = guest_approach_position(table, seat)
			break
		if exit_point.is_finite():
			# Reverse the short seat-entry motion before routing over walkable cells.
			origin = Vector2i(roundi(exit_point.x / CasinoTuning.FLOOR_NAV_CELL), roundi(exit_point.y / CasinoTuning.FLOOR_NAV_CELL))
	origin = origin.clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	destination = destination.clamp(grid.region.position, grid.region.end - Vector2i.ONE)
	var path: Array = []
	if grid.is_in_boundsv(origin) and grid.is_in_boundsv(destination):
		for at in grid.get_point_path(origin, destination):
			path.append([at.x, at.y])
	if not path.is_empty():
		if exit_point.is_finite(): path.push_front([exit_point.x, exit_point.y])
		path.append([guest.tx, guest.ty])
	guest.path = path

func reroute() -> void:
	navigation_grid = null
	geometry_revision += 1
	placement_signature.clear()
	for employee in staff:
		if employee.role == "Service" and employee.has("service_state"): route(employee)
	for guest in guests:
		if guest.state in ["Walking", "Playing"]:
			var table := get_table(int(guest.table))
			var target := guest_approach_position(table, int(guest.seat)) if guest.state == "Walking" else guest_seat_position(table, int(guest.seat))
			if guest.state == "Walking":
				guest.tx = target.x
				guest.ty = target.y
			else:
				guest.x = target.x
				guest.y = target.y
		if guest.state in ["To bar", "At bar"]:
			var target := bar_guest_position(int(guest.bar_slot))
			if Vector2(guest.tx, guest.ty).distance_to(target) > 1:
				guest.tx = target.x
				guest.ty = target.y
				guest.state = "To bar"
				guest.activity_since = elapsed
		if guest.state in ["Arriving", "Walking", "Browsing", "Exploring", "To bar", "To cage", "Leaving"]:
			route(guest)

func move_entity(entity: Dictionary, delta: float) -> Vector2:
	# Consume distance across waypoints, not one waypoint per frame/substep.
	# This avoids losing travel time at 0.1-second developer substeps.
	var at := Vector2(entity.x, entity.y)
	if entity.path.is_empty(): return at
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
	DrinkService.move_counter(self, delta)
	for effect in cashout_effects: effect.life -= delta
	cashout_effects = cashout_effects.filter(func(e): return e.life > 0)
	for guest in guests:
		if guest.state in ["To cage", "Cashing out"] and int(guest.rounds) == 0:
			# Never allow an unplayed wallet to produce a cage visit or cash-out effect.
			presentation_revision += 1
			guest.state = "Waiting"
			leave(guest, "No games are available. I'll come back later.")
		if guest.state == "Cashing out":
			guest.cage_wait = maxf(0, float(guest.get("cage_wait", 2.0)) - delta)
			if guest.cage_wait <= 0:
				var house_net := float(guest.start) - float(guest.wallet) - float(guest.drink_spending)
				cashout_effects.push_front({"name": guest.name, "net": house_net, "cash": guest.wallet, "life": 16.0})
				if cashout_effects.size() > 4: cashout_effects.pop_back()
				log_event("CAGE - %s cashed out $%.2f%s" % [guest.name, guest.wallet, " | VIP" if guest.vip else ""])
				# Wagers already settled against treasury. Do not pay/debit twice here.
				presentation_revision += 1
				guest.state = "Leaving"
				guest.tx = CasinoTuning.ENTRY.x
				guest.ty = CasinoTuning.ENTRY.y
				think(guest, "Cashed out. Heading home.")
				route(guest)
			continue
		if guest.state == "Entering seat":
			var table := get_table(int(guest.table))
			if not operating(table):
				leave(guest, "That game is no longer available.")
				continue
			var seat := guest_seat_position(table, int(guest.seat))
			# This short movement bypasses obstacle routing into the chair itself.
			var at := Vector2(guest.x, guest.y).move_toward(seat, maxf(0, delta) * CasinoTuning.ENTITY_WALK_SPEED)
			guest.x = at.x
			guest.y = at.y
			if at.is_equal_approx(seat):
				guest.state = "Playing"
				presentation_revision += 1
				think(guest, "Ready to play %s!" % Games.NAMES[table_kind(table)])
			continue
		if guest.state not in ["Arriving", "Walking", "Browsing", "Exploring", "To bar", "To cage", "Leaving"] and not (guest.state == "Waiting" and guest.repair_wait_table > 0):
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
				presentation_revision += 1
				guest.state = "Cashing out"
				guest.cage_wait = 2.0
			elif guest.state == "Walking":
				presentation_revision += 1
				guest.state = "Entering seat"
			elif guest.state == "Browsing":
				presentation_revision += 1
				guest.state = "Watching"
				think(guest, "Watching the slot player before deciding." if table_kind(get_table(int(guest.table))) == "slots" else "Watching the table before deciding.")
			elif guest.state == "To bar":
				presentation_revision += 1
				guest.state = "At bar"
				guest.activity_since = elapsed
				guest.decision_at = elapsed + rng.randi_range(CasinoTuning.GUEST_DRINK_BREAK_MINUTES.x, CasinoTuning.GUEST_DRINK_BREAK_MINUTES.y)
				if guest.thirst >= CasinoTuning.DRINK_THIRST_TRIGGER:
					DrinkService.transition(self, guest, "WAITING_FOR_SERVICE")
				else: think(guest, "Taking a break and watching the floor.", 2)
			elif guest.state == "Arriving":
				presentation_revision += 1
				guest.state = "Waiting"
				guest.decision_at = elapsed + rng.randi_range(1, 5)

func bar_bounds() -> Rect2:
	return CasinoTuning.BAR_COUNTER

func bar_available() -> bool:
	return bar_owned

func purchase_bar() -> bool:
	if bar_owned or not unlocked("service") or cash < CasinoTuning.BAR_PURCHASE_COST: return false
	spend_nonpayroll(CasinoTuning.BAR_PURCHASE_COST, "construction")
	bar_owned = true
	# Purchase provides a usable basic menu. Later unlocks remain optional.
	for id in ["basic", "water"]:
		if id not in drink_access: drink_access.append(id)
		Bar.set_menu(self, id, true)
	presentation_revision += 1
	refresh_progression()
	log_event("BAR - Bar purchased. House Soda and Sparkling Water are on the menu. Counter service is available; hire Service staff for floor delivery.")
	return true

func bar_guest_position(slot: int) -> Vector2:
	return bar_bounds().position + CasinoTuning.BAR_GUEST_OFFSETS[clampi(slot, 0, CasinoTuning.BAR_GUEST_OFFSETS.size() - 1)]

func bar_pickup() -> Vector2:
	return bar_bounds().position + CasinoTuning.BAR_PICKUP_OFFSET

func service_position(employee: Dictionary) -> void:
	if employee.has("service_state"): return
	var pickup := bar_pickup()
	employee.merge({"x": pickup.x, "y": pickup.y, "tx": pickup.x, "ty": pickup.y, "service_state": "At bar", "service_wait": 0.0, "service_target": -1, "service_product": ""}, true)

func send_to_bar(employee: Dictionary) -> void:
	employee.service_state = "To bar"
	for guest in guests:
		if int(guest.id) == int(employee.get("service_target", -1)) and guest.drink_state == "SERVICE_ASSIGNED":
			DrinkService.transition(self, guest, "WAITING_FOR_SERVICE")
	employee.service_target = -1
	employee.service_product = ""
	var pickup := bar_pickup()
	employee.tx = pickup.x
	employee.ty = pickup.y
	route(employee)

func gambling_comp_eligible(guest: Dictionary, profile: Dictionary) -> bool:
	# A seat or a wallet is not gambling. Only a successfully funded real wager counts.
	return bool(CasinoTuning.COMP_POLICY.basic_gambling_comps) and bool(profile.comp_eligible) and guest.state == "Playing" and int(guest.last_wager_minute) >= 0 and elapsed - int(guest.last_wager_minute) <= int(CasinoTuning.COMP_POLICY.recent_wager_minutes)

func set_drink_menu(id: String, enabled: bool) -> void:
	Bar.set_menu(self, id, enabled)

func set_drink_price(id: String, price: float) -> void:
	Bar.set_price(self, id, price)

func wants_drink(guest: Dictionary) -> bool:
	if not Bar.eligible_state(self, guest) or str(guest.drink_order) not in drink_menu: return false
	var id: String = str(guest.drink_order)
	var price := Bar.price_for(self, guest, id, float(guest.drink_quote))
	return float(guest.wallet) >= price and cash + price >= float(CasinoTuning.DRINK_PROFILES[id].cost)

func deliver_drink(guest: Dictionary, employee: Dictionary) -> void:
	if employee.is_empty():
		if guest.state != "At bar" or not DrinkService.valid_slot(self, guest): return
	elif employee.duty != "Active" or int(employee.service_target) != int(guest.id) or str(employee.service_product) != str(guest.drink_order): return
	# Recheck eligibility/funds at delivery. Retain the quoted paid price.
	if not wants_drink(guest): return
	var id: String = str(guest.drink_order)
	var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
	var comped := gambling_comp_eligible(guest, profile)
	var price := Bar.price_for(self, guest, id, float(guest.drink_quote))
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
	Bar.fulfill(self, guest, id, price, comped)
	DrinkService.release_assignment(self, guest)
	guest.drink_attempt_at = -1
	guest.drink_failure = ""
	guest.drink_wait_loss = 0.0
	guest.drink_wait_minutes = 0
	guest.thirst = 0.0
	DrinkService.transition(self, guest, "FULFILLED")
	incidents = incidents.filter(func(item): return item.type != "service")
	guest.satisfaction = minf(100, float(guest.satisfaction) + CasinoTuning.DRINK_SATISFACTION_GAIN + float(profile.prestige) * CasinoTuning.DRINK_PRESTIGE_SATISFACTION)
	if guest.state == "At bar":
		guest.decision_at = elapsed + rng.randi_range(CasinoTuning.BAR_SOCIAL_MINUTES.x, CasinoTuning.BAR_SOCIAL_MINUTES.y)
	think(guest, "Perfect!", 2)
	var asset := get_table(int(guest.table))
	emit_financial_event(price - cost, "comp" if comped else "bar", asset, int(guest.id), {"position": Vector2(guest.x, guest.y), "drink_profile": id, "comped": comped, "price": price, "product_cost": cost, "staff_name": str(employee.get("name", "Bar counter")), "source": "drink"})

func bar_margin() -> float:
	return float(bar_totals.revenue) - float(bar_totals.product_cost) - float(bar_totals.comp_cost)

func bar_contribution() -> float:
	return bar_margin() - float(expense_totals.service_payroll)

func service_guest_access(guest: Dictionary) -> Vector2:
	var table := get_table(int(guest.table))
	return guest_approach_position(table, int(guest.seat)) if not table.is_empty() else Vector2(guest.x, guest.y)

func move_service(delta: float) -> void:
	for employee in staff:
		if employee.role != "Service" or employee.duty != "Active": continue
		service_position(employee)
		var pickup := bar_pickup()
		if (employee.service_state == "To bar" and Vector2(employee.tx, employee.ty) != pickup) or (employee.service_state in ["At bar", "Preparing"] and Vector2(employee.x, employee.y).distance_to(pickup) > 2):
			send_to_bar(employee)
		if employee.service_state == "At bar":
			var candidates := guests.filter(func(g): return g.state == "Playing" and g.drink_state in ["WAITING_FOR_SERVICE", "NEED"] and wants_drink(g) and not staff.any(func(other): return int(other.get("service_target", -1)) == int(g.id)))
			candidates.sort_custom(func(a, b): return a.thirst > b.thirst)
			if candidates.is_empty(): continue
			var guest: Dictionary = candidates[0]
			DrinkService.transition(self, guest, "SERVICE_ASSIGNED")
			employee.service_state = "Preparing"
			employee.service_target = int(guest.id)
			employee.service_product = str(guest.drink_order)
			employee.service_wait = float(CasinoTuning.DRINK_PROFILES[str(guest.drink_order)].prep_minutes)
		if employee.service_state in ["Preparing", "Delivering"]:
			var target := guests.filter(func(g): return int(g.id) == int(employee.service_target) and g.state == "Playing" and g.drink_state == "SERVICE_ASSIGNED" and wants_drink(g) and str(g.drink_order) == str(employee.service_product))
			if target.is_empty():
				send_to_bar(employee)
			elif employee.service_state == "Preparing":
				employee.service_wait = maxf(0, float(employee.service_wait) - delta)
				if employee.service_wait > 0: continue
				employee.service_state = "Delivering"
				var access := service_guest_access(target[0])
				employee.tx = access.x
				employee.ty = access.y
				route(employee)
			elif service_guest_access(target[0]).distance_to(Vector2(employee.tx, employee.ty)) > 12:
				var access := service_guest_access(target[0])
				employee.tx = access.x
				employee.ty = access.y
				route(employee)
		if not employee.has("path"): route(employee)
		var goal := Vector2(employee.tx, employee.ty)
		var moved := move_entity(employee, delta)
		if moved.distance_to(goal) < 2:
			employee.erase("path")
			if employee.service_state == "To bar":
				employee.service_state = "At bar"
				employee.service_product = ""
			else:
				for guest in guests:
					if int(guest.id) == int(employee.service_target): deliver_drink(guest, employee)
				send_to_bar(employee)

func momentum_step() -> void:
	if not opened: return
	var positions := 0
	var available := 0
	for table in tables:
		positions += guest_capacity(table)
		if operating(table): available += guest_capacity(table)
	var active := 0
	var occupied := 0
	var contentment := 0.0
	for guest in guests:
		if guest.state in ["To cage", "Cashing out", "Leaving"]: continue
		active += 1
		contentment += float(guest.satisfaction)
		if int(guest.table) > 0: occupied += 1
	momentum.update(true, contentment / active if active > 0 else 65.0, float(occupied) / maxf(1, positions), float(available) / maxf(1, positions) if active > 0 else 1.0)

func step() -> void:
	presentation_revision += 1
	# Scoped indexes: staffing mutates assignments first; guest membership stays live.
	elapsed += 1
	optional_events.tick(self)
	minute += 1
	if minute >= 1440:
		minute = 0
		day += 1
	var wages := 0.0
	for employee in staff:
		if employee.duty == "Off Duty": continue
		var wage := (CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE) / 60.0
		wages += wage
		expense_totals["dealer_payroll" if employee.role == "Dealer" else "service_payroll"] += wage
		payroll_by_state[payroll_state(employee)] += wage
		if employee.role == "Service" and employee.duty == "Active" and str(employee.get("service_product", "")) in drink_stats:
			drink_stats[str(employee.service_product)].service_payroll += wage
		if employee.role == "Dealer":
			var assigned := get_table(int(employee.table))
			if not assigned.is_empty(): assigned.payroll_expense += wage
	payroll += wages
	cash -= wages
	Staffing.tick(self)
	step_tables.clear()
	step_crew.clear()
	for table in tables: step_tables[int(table.id)] = table
	for employee in staff:
		if employee.role != "Dealer" or employee.duty != "Active": continue
		var id := int(employee.table)
		if not step_crew.has(id): step_crew[id] = []
		step_crew[id].append(employee)
	indexed_step = true
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
	spend_nonpayroll(property_upkeep_rate() / 60.0, "property_upkeep")
	arrival_step()
	for guest in guests:
		guest.age += 1
		if bar_available(): guest.thirst = minf(100, guest.thirst + CasinoTuning.THIRST_PER_MINUTE)
		DrinkService.tick(self, guest)
		guest_lifecycle_step(guest)
	guests = guests.filter(func(g): return not (g.state == "Leaving" and Vector2(g.x, g.y).distance_to(CasinoTuning.ENTRY) < 3))
	for table in tables:
		# Closed tables finish contracts and allow owner play; guests place no new bets.
		if table.broken or (required_crew(table) > 0 and crew(int(table.id)).size() < required_crew(table)):
			continue
		if not opened and joined != int(table.id) and not seated(int(table.id)).any(func(g): return CrapsRules.exposure(g.bets) > 0) and CrapsRules.exposure(table.owner) == 0:
			continue
		if table_kind(table) != "craps":
			if joined == int(table.id): continue
			table.timer += 1.0
			if table.timer >= (int(slot_profile(table).round_minutes) if table_kind(table) == "slots" else int(CasinoTuning.TABLE_GAME_ROUND_MINUTES[table_kind(table)])):
				table.timer = 0.0
				if operating(table): npc_games(table)
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

	momentum_step()
	optional_objectives.tick(self)
	refresh_progression()
	update_reserve_warning()
	check_profit_milestone()
	indexed_step = false
	step_tables.clear()
	step_crew.clear()

func take_bet(table: Dictionary, bettor: Dictionary, kind: String, amount: float, owner: bool) -> bool:
	var funds: float = owner_bankroll if owner else float(bettor.wallet)
	if not is_finite(amount) or funds < amount or amount <= 0:
		return false
	if owner:
		if not owner_account.floor_debit(amount, elapsed): return false
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
	if not accepting_new_play(table) or joined != id:
		return "Join a staffed, repaired table to bet. Doors can stay closed."
	if not CrapsRules.empty_bets().has(kind): return "Unknown bet."
	var amount := bet_amount(table, kind, chip)
	if not is_finite(amount) or amount + float(table.owner[kind]) > maximum_wager(table): return "This bet exceeds the game maximum ($%d)." % maximum_wager(table)
	if owner_bankroll < amount: return "Your Owner Bankroll cannot cover this bet."
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
	owner_account.floor_credit(returned, elapsed, "floor_refund")
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
	if back_room.busy(): return false
	if not owner_play.is_empty(): return false
	Staffing.rebalance(self, true)
	var table := get_table(id)
	if not accepting_new_play(table): return false
	if joined >= 0:
		leave_table()
		if joined >= 0: return false
	if table_kind(table) == "slots" and not reserved_guests(id).is_empty():
		log_event("That machine is occupied or reserved for an arriving guest.", false)
		return false
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
		if operating(table) and old_point == 0 and guest.bets.pass == 0 and guest.wallet >= table.minimum:
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
	owner_account.floor_credit(float(result.credit), elapsed)
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
		log_event(result.message + (" Returned $%d to your Owner Bankroll." % result.credit if result.credit > 0 else ""), false)

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
				clear_repair_waiters(int(table.id))
				table.service_minutes = 0
				table.repair_expense += cost
				table.repairs += 1
				emit_financial_event(-cost, "repair", table)
		else:
			emit_financial_event(-cost, "comp", {}, -1, {"source": "complaint", "position": bar_pickup()})
			change_reputation(2, "incident.comp")
			for guest in guests:
				guest.satisfaction = minf(100, guest.satisfaction + 8)
		momentum.outcome(CasinoTuning.MOMENTUM_REPAIR_GAIN if incident.type == "repair" else CasinoTuning.MOMENTUM_COMP_GAIN, "Repaired a halted game" if incident.type == "repair" else "Resolved a service complaint")
		log_event("%s resolved for $%d." % [incident.title, cost])
	else:
		change_reputation(-3, "incident.dismissed_complaint", {}, "", str(incident.title))
		momentum.outcome(-CasinoTuning.MOMENTUM_COMPLAINT_LOSS, "Dismissed a service complaint")
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
	return {"Active": "active", "Relief": "relief", "Break": "break", "Off Duty": "off_duty"}[employee.duty]

func payroll_rate() -> float:
	var amount := 0.0
	for employee in staff:
		if employee.duty != "Off Duty": amount += CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE
	return amount

func planned_payroll_rate() -> float:
	var amount := 0.0
	for role in ["Dealer", "Service"]:
		var employees: Array = staff.filter(func(e): return e.role == role)
		var on_shift := employees.filter(func(e): return e.duty != "Off Duty").size()
		var needed := Staffing.required(self, role)
		var planned := mini(employees.size(), needed + int(relief_targets[role])) if needed > 0 else 0
		amount += maxi(on_shift, planned) * (CasinoTuning.DEALER_WAGE if role == "Dealer" else CasinoTuning.SERVICE_WAGE)
	return amount

func recurring_costs() -> float:
	return payroll + float(expense_totals.property_upkeep) + float(expense_totals.upkeep) + float(expense_totals.repairs) + float(expense_totals.comps) + float(expense_totals.drink_products) + float(expense_totals.drink_comps)

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
	var upkeep := property_upkeep_rate()
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
		var standby := staff.filter(func(employee): return employee.role == "Dealer" and employee.duty == "Relief" and employee.energy >= CasinoTuning.STAFF_RETURN_ENERGY).size()
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
	var payroll_buffer := (planned_payroll_rate() + extra_payroll) * CasinoTuning.RESERVE_OPERATING_HOURS
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
	return revenue - payouts + float(bar_totals.revenue) - payroll - overhead + owner_account.profit_transferred + sponsored_income

func satisfaction() -> float:
	if guests.is_empty():
		return 80
	var total := 0.0
	for guest in guests:
		total += guest.satisfaction
	return total / guests.size()

func snapshot() -> Dictionary:
	return {"difficulty": difficulty, "starting_games": starting_games.duplicate(), "casino_rating": casino_rating, "guest_rounds": guest_rounds, "guest_revenue": guest_revenue, "guest_handle": guest_handle, "guests_served": guests_served, "blackjack_unlocked": blackjack_unlocked, "ever_opened": ever_opened, "floor_chunks": floor_chunks.duplicate(), "vip_enabled": vip_enabled, "high_limit_enabled": high_limit_enabled, "bar_owned": bar_owned, "bar_totals": bar_totals.duplicate(), "drink_access": drink_access.duplicate(), "drink_menu": drink_menu.duplicate(), "drink_prices": drink_prices.duplicate(), "drink_stats": drink_stats.duplicate(true), "expense_totals": expense_totals.duplicate(), "payroll_by_state": payroll_by_state.duplicate(), "relief_targets": relief_targets.duplicate(), "service_positions": service_positions, "staff_shift_handover_at": staff_shift_handover_at, "slot_access": slot_access.duplicate(), "earned_milestones": earned_milestones.duplicate(), "traffic_totals": traffic_totals.duplicate(true), "traffic_bad_visits": traffic_bad_visits, "traffic_reputation_at": traffic_reputation_at, "version": CasinoTuning.SAVE_VERSION, "arrival_in": arrival_in, "cash": cash, "owner_bankroll": owner_account.snapshot(), "optional_events": optional_events.snapshot(), "momentum": momentum.snapshot(), "optional_objectives": optional_objectives.snapshot(), "owner_play": owner_play.duplicate(true), "back_room": back_room.snapshot(), "recovery": recovery.snapshot(), "sponsored_income": sponsored_income, "revenue": revenue, "payouts": payouts, "payroll": payroll, "overhead": overhead, "visitor_net": visitor_net, "reputation": reputation, "minute": minute, "day": day, "elapsed": elapsed, "opened": opened, "tables": tables.duplicate(true), "guests": guests.duplicate(true), "staff": staff.duplicate(true), "alerts": alerts.duplicate(), "incidents": incidents.duplicate(true), "next_id": next_id, "joined": joined, "player": [player.x, player.y], "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	if not valid_number(data.get("version")) or data.version != CasinoTuning.SAVE_VERSION:
		return false
	if not data.get("bar_owned") is bool: return false
	data = data.duplicate(true)
	var restored_owner := OwnerAccount.new()
	if not restored_owner.restore(data.get("owner_bankroll")): return false
	var restored_room := BackRoom.new()
	var restored_recovery := Recovery.new()
	if not restored_room.restore(data.get("back_room"), restored_owner) or not restored_recovery.restore(data.get("recovery")): return false
	var restored_events := OptionalEvents.new()
	if not valid_number(data.get("elapsed")): return false
	var restored_objectives := Objectives.new()
	if data.has("optional_objectives"):
		if not restored_objectives.restore(data.optional_objectives, int(data.elapsed)): return false
	else: restored_objectives.next_check = int(data.elapsed) + CasinoTuning.OBJECTIVE_INTERVAL
	var restored_momentum := Momentum.new()
	if data.has("momentum") and not restored_momentum.restore(data.momentum, int(data.elapsed)): return false
	if data.has("optional_events"):
		if not restored_events.restore(data.optional_events, int(data.elapsed)): return false
	else:
		restored_events.next_check = int(data.elapsed) + CasinoTuning.EVENT_INTERVAL_MINUTES
	if not valid_number(data.get("elapsed")) or not valid_number(data.get("staff_shift_handover_at")) or data.staff_shift_handover_at > data.elapsed or data.staff_shift_handover_at < -CasinoTuning.STAFF_SHIFT_HANDOVER_GAP: return false
	if not data.get("relief_targets") is Dictionary: return false
	for role in relief_targets:
		if not valid_number(data.relief_targets.get(role)) or data.relief_targets[role] != int(data.relief_targets[role]) or int(data.relief_targets[role]) not in range(CasinoTuning.MAX_STAFF + 1): return false
	if not valid_number(data.get("service_positions")) or data.service_positions != int(data.service_positions) or int(data.service_positions) not in range(1, CasinoTuning.MAX_STAFF + 1): return false
	if not data.get("earned_milestones") is Array or data.earned_milestones.size() > 64: return false
	var unique_milestones := {}
	for id in data.earned_milestones:
		if not id is String or id.is_empty() or unique_milestones.has(id): return false
		unique_milestones[id] = true
	if not data.get("traffic_totals") is Dictionary: return false
	for key in traffic_totals:
		if key == "departures": continue
		if not valid_number(data.traffic_totals.get(key)) or float(data.traffic_totals[key]) < 0: return false
	if data.traffic_totals.occupied_minutes > data.traffic_totals.position_minutes: return false
	if not data.traffic_totals.get("departures") is Dictionary: return false
	for key in traffic_totals.departures:
		if not valid_number(data.traffic_totals.departures.get(key)) or float(data.traffic_totals.departures[key]) < 0: return false
	if not valid_number(data.get("traffic_bad_visits")) or data.traffic_bad_visits < 0: return false
	if not valid_number(data.get("elapsed")) or not valid_number(data.get("traffic_reputation_at")) or data.traffic_reputation_at > data.elapsed: return false
	if not data.get("slot_access") is Array or "starter" not in data.slot_access: return false
	for id in data.slot_access:
		if not id is String or not CasinoTuning.SLOT_PROFILES.has(id): return false
	for field in ["expense_totals", "payroll_by_state", "bar_totals"]:
		if not data.get(field) is Dictionary: return false
		var expected: Dictionary = expense_totals if field == "expense_totals" else payroll_by_state if field == "payroll_by_state" else bar_totals
		for key in expected:
			if not data[field].has(key) or not valid_number(data[field][key]): return false
			if key != "sales" and float(data[field][key]) < 0: return false
	if not Bar.valid_snapshot(self, data): return false
	# Validate the current schema before applying any state.
	for key in ["difficulty", "starting_games", "casino_rating", "guest_rounds", "guest_revenue", "guest_handle", "guests_served", "blackjack_unlocked", "ever_opened", "floor_chunks", "vip_enabled", "high_limit_enabled", "arrival_in", "cash", "sponsored_income", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "opened", "tables", "guests", "staff", "alerts", "incidents", "next_id", "joined", "player", "rng_state"]:
		if not data.has(key): return false
	if not data.difficulty is String or not CasinoTuning.DIFFICULTIES.has(data.difficulty): return false
	if not data.starting_games is Array or data.starting_games.size() > Games.NAMES.size(): return false
	for kind in data.starting_games:
		if not kind is String or not Games.NAMES.has(kind): return false
	for key in ["casino_rating", "guest_rounds", "guest_revenue", "guest_handle", "guests_served"]:
		if not valid_number(data[key]) or float(data[key]) < 0: return false
	if float(data.casino_rating) > 100: return false
	if not Property.valid(data.get("floor_chunks")): return false
	for key in ["blackjack_unlocked", "ever_opened", "vip_enabled", "high_limit_enabled"]:
		if not data[key] is bool: return false
	if not valid_number(data.arrival_in) or float(data.arrival_in) < 0: return false
	for key in ["tables", "guests", "staff", "alerts", "incidents", "player"]:
		if not data[key] is Array:
			return false
	if data.player.size() != 2 or data.tables.size() > CasinoTuning.MAX_ASSETS or data.guests.size() > CasinoTuning.MAX_GUESTS or data.staff.size() > CasinoTuning.MAX_STAFF:
		return false
	for key in ["cash", "sponsored_income", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "next_id", "joined"]:
		if not valid_number(data[key]):
			return false
	if data.sponsored_income < 0 or not data.opened is bool or not data.rng_state is String:
		return false
	if not data.rng_state.is_valid_int():
		return false
	if not valid_number(data.player[0]) or not valid_number(data.player[1]):
		return false
	if not Property.walking(data.floor_chunks).has_point(Vector2(data.player[0], data.player[1])): return false
	var ids: Array = []
	for table in data.tables:
		if not table is Dictionary:
			return false
		if not table.get("staff_enabled") is bool or not valid_number(table.get("staff_priority")) or table.staff_priority != int(table.staff_priority) or int(table.staff_priority) not in [0, 1, 2]: return false
		if not valid_number(table.get("staff_rotation_until")) or table.staff_rotation_until < -1: return false
		for key in ["kind", "slot_profile", "round", "roulette_bets"]:
			if not table.has(key): return false
		if not table.kind is String or not Games.NAMES.has(table.kind): return false
		if not table.slot_profile is String or (table.kind == "slots" and not CasinoTuning.SLOT_PROFILES.has(table.slot_profile)): return false
		if not table.round is Dictionary or not table.roulette_bets is Dictionary: return false
		if not Games.valid_round(table.round, str(table.kind)): return false
		if table.kind == "slots" and not table.round.is_empty() and table.round.profile != table.slot_profile: return false
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
		if float(table.minimum) not in limits:
			return false
	var saved_geometry: Array = []
	for table in data.tables: saved_geometry.append(Placement.for_table(table))
	if not Placement.validate(data.floor_chunks, saved_geometry, placement_access_points(bool(data.bar_owned))).valid: return false
	if int(data.joined) != -1 and int(data.joined) not in ids:
		return false
	var reserved_bar_slots := {}
	for guest in data.guests:
		if not guest is Dictionary:
			return false
		for key in ["id", "name", "x", "y", "tx", "ty", "table", "seat", "state", "wallet", "start", "rounds", "last_wager_minute", "bar_slot", "drink_spending", "drink_order", "drink_quote", "drink_request_at", "wager_limit", "satisfaction", "thirst", "age", "patience", "vip", "bets", "thought", "archetype", "session_left", "activities", "activity_since", "decision_at", "wait_since", "last_table", "explored_without_game", "preference", "watch_left", "watch_style", "demand_blocked", "demand_wait", "demand_attempts", "demand_failure_wait", "repair_wait_table"]:
			if not guest.has(key):
				return false
		for key in ["id", "x", "y", "tx", "ty", "table", "seat", "wallet", "start", "rounds", "last_wager_minute", "bar_slot", "drink_spending", "drink_quote", "drink_request_at", "wager_limit", "satisfaction", "thirst", "age", "patience", "session_left", "activities", "activity_since", "decision_at", "wait_since", "last_table", "demand_wait", "demand_attempts", "demand_failure_wait", "repair_wait_table"]:
			if not valid_number(guest[key]):
				return false
		if not DrinkService.valid_guest(self, guest, float(data.elapsed)): return false
		if int(guest.last_wager_minute) < -1 or float(guest.last_wager_minute) > float(data.elapsed) or float(guest.drink_spending) < 0: return false
		if not guest.drink_order is String or (guest.drink_order != "" and guest.drink_order not in data.drink_menu) or guest.drink_quote < 0 or guest.drink_request_at < 0: return false
		if guest.drink_order != "":
			var product: Dictionary = CasinoTuning.DRINK_PROFILES[str(guest.drink_order)]
			if guest.drink_quote < product.price_min or guest.drink_quote > product.price_max: return false
		if not guest.has("operational_failure") or not guest.operational_failure is String: return false
		if not guest.get("unmet_visit_recorded") is bool or not guest.get("repair_frustrated") is bool: return false
		if int(guest.repair_wait_table) != -1 and int(guest.repair_wait_table) not in ids: return false
		if not guest.demand_blocked is bool or guest.demand_wait < 0 or guest.demand_attempts < 0 or guest.demand_failure_wait < 0: return false
		if not guest.explored_without_game is bool or guest.session_left < 0 or guest.activities < 0 or guest.activity_since < 0 or guest.activity_since > data.elapsed or guest.decision_at < 0 or guest.wait_since < -1 or guest.wait_since > data.elapsed: return false
		if not guest.archetype is String or not CasinoTuning.GUEST_ARCHETYPES.has(guest.archetype): return false
		if bool(guest.vip) != (guest.archetype == "vip"): return false
		if not guest.preference is String or not Games.NAMES.has(guest.preference): return false
		if float(guest.wallet) < 0 or float(guest.rounds) < 0 or float(guest.wager_limit) <= 0 or not valid_bets(guest.bets) or not guest.vip is bool:
			return false
		if int(guest.table) != -1 and int(guest.table) not in ids:
			return false
		if guest.state in ["Walking", "Entering seat", "Playing"]:
			if int(guest.table) < 1: return false
			var assigned: Dictionary = data.tables.filter(func(table): return int(table.id) == int(guest.table))[0]
			var seats := 1 if table_kind(assigned) == "slots" else CasinoTuning.TABLE_CAPACITY - 1
			if int(guest.seat) not in range(seats): return false
		if guest.state not in ["Arriving", "Waiting", "Walking", "Entering seat", "Playing", "Browsing", "Watching", "Exploring", "To bar", "At bar", "To cage", "Cashing out", "Leaving"] or not guest.name is String or not guest.thought is String:
			return false
		if guest.state in ["Browsing", "Watching"] and (int(guest.table) < 1 or int(guest.seat) != -1): return false
		if guest.bar_slot != int(guest.bar_slot) or int(guest.bar_slot) < -1 or int(guest.bar_slot) >= CasinoTuning.BAR_GUEST_OFFSETS.size(): return false
		if guest.state in ["To bar", "At bar"]:
			if int(guest.bar_slot) < 0 or int(guest.table) != -1 or int(guest.seat) != -1 or reserved_bar_slots.has(int(guest.bar_slot)): return false
			reserved_bar_slots[int(guest.bar_slot)] = true
		elif int(guest.bar_slot) != -1: return false
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
	var employee_ids := {}
	for employee in data.staff:
		if not employee is Dictionary:
			return false
		for key in ["id", "name", "role", "table", "energy", "duty", "state_since", "shift_end", "available_at", "rest_due", "service_product"]:
			if not employee.has(key):
				return false
		if not employee.name is String or employee.role not in ["Dealer", "Service"] or not valid_number(employee.table) or not valid_number(employee.energy):
			return false
		if not valid_number(employee.id) or employee.id != int(employee.id) or employee.id < 1 or employee.id >= data.next_id or employee_ids.has(int(employee.id)) or int(employee.id) in ids: return false
		employee_ids[int(employee.id)] = true
		if employee.duty not in ["Active", "Relief", "Break", "Off Duty"] or employee.rest_due not in ["", "Break", "Off Duty"] or employee.energy < 0 or employee.energy > 100: return false
		if not employee.service_product is String or (employee.service_product != "" and not CasinoTuning.DRINK_PROFILES.has(employee.service_product)): return false
		for key in ["state_since", "shift_end", "available_at"]:
			if not valid_number(employee[key]) or employee[key] < 0: return false
		if employee.state_since > data.elapsed: return false
		if employee.duty != "Active" and (int(employee.table) != -1 or employee.rest_due != ""): return false
		if employee.role == "Service" and (int(employee.table) != -1 or employee.rest_due != ""): return false
		if employee.role == "Dealer" and employee.duty == "Active":
			var assigned: Array = data.tables.filter(func(t): return int(t.id) == int(employee.table))
			if assigned.is_empty() or required_crew(assigned[0]) == 0: return false
		for key in ["x", "y", "tx", "ty", "service_target", "service_wait"]:
			if employee.has(key) and not valid_number(employee[key]): return false
		if employee.has("service_state") and employee.service_state not in ["At bar", "To bar", "Preparing", "Delivering"]: return false
		if employee.has("service_state"):
			for key in ["x", "y", "tx", "ty", "service_target", "service_wait"]:
				if not employee.has(key): return false
			if employee.role != "Service" or float(employee.service_wait) < 0: return false
			if employee.service_state in ["Preparing", "Delivering"] and employee.service_product == "": return false
		employee.erase("path")
		if int(employee.table) != -1 and int(employee.table) not in ids:
			return false
	var drink_claims := {}
	for employee in data.staff:
		var target_id := int(employee.get("service_target", -1))
		if target_id == -1: continue
		if employee.role != "Service" or employee.duty != "Active" or employee.get("service_state", "") not in ["Preparing", "Delivering"] or drink_claims.has(target_id): return false
		var targets: Array = data.guests.filter(func(g): return int(g.id) == target_id)
		if targets.is_empty() or targets[0].drink_state != "SERVICE_ASSIGNED" or targets[0].drink_order != employee.service_product: return false
		drink_claims[target_id] = true
	for guest in data.guests:
		if guest.drink_state == "SERVICE_ASSIGNED" and not drink_claims.has(int(guest.id)): return false
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
	if not data.bar_owned:
		if not data.drink_access.is_empty() or not data.drink_menu.is_empty(): return false
		if data.staff.any(func(employee): return employee.role == "Service"): return false
		if data.guests.any(func(guest): return guest.state in ["To bar", "At bar"] or guest.drink_order != ""): return false
		if data.incidents.any(func(incident): return incident.type == "service"): return false
		if float(data.bar_totals.sold) + float(data.bar_totals.comped) > 0: return false
	var restored_play = data.get("owner_play", {})
	if not OwnerPlay.valid(restored_play, restored_owner, restored_events, data.tables) or (not restored_play.is_empty() and int(data.joined) >= 0): return false
	if restored_room.busy() and (not restored_play.is_empty() or int(data.joined) >= 0): return false
	back_room = restored_room
	recovery = restored_recovery
	owner_play = restored_play.duplicate(true)
	owner_account = restored_owner
	optional_events = restored_events
	momentum = restored_momentum
	optional_objectives = restored_objectives
	debug_forced_unlocks.clear()
	for key in ["cash", "sponsored_income", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation"]:
		set(key, float(data[key]))
	for key in ["minute", "day", "elapsed", "next_id", "joined"]:
		set(key, int(data[key]))
	earned_milestones = data.earned_milestones.duplicate()
	traffic_totals = data.traffic_totals.duplicate(true)
	traffic_bad_visits = int(data.traffic_bad_visits)
	traffic_reputation_at = int(data.traffic_reputation_at)
	bar_owned = data.bar_owned
	bar_totals = data.bar_totals.duplicate()
	drink_access = data.drink_access.duplicate()
	drink_menu = data.drink_menu.duplicate()
	drink_prices = data.drink_prices.duplicate()
	drink_stats = data.drink_stats.duplicate(true)
	expense_totals = data.expense_totals.duplicate()
	payroll_by_state = data.payroll_by_state.duplicate()
	relief_targets = data.relief_targets.duplicate()
	service_positions = int(data.service_positions)
	staff_shift_handover_at = int(data.staff_shift_handover_at)
	staffing_notice_signature = ""
	staffing_notice_at = int(data.elapsed) - CasinoTuning.STAFF_NOTICE_COOLDOWN
	slot_access = data.slot_access.duplicate()
	difficulty = str(data.difficulty)
	starting_games = data.starting_games.duplicate()
	casino_rating = float(data.casino_rating)
	guest_rounds = int(data.guest_rounds)
	guest_revenue = float(data.guest_revenue)
	guest_handle = float(data.guest_handle)
	guests_served = int(data.guests_served)
	floor_chunks = {"left": int(data.floor_chunks.left), "right": int(data.floor_chunks.right), "bottom": int(data.floor_chunks.bottom)}
	for key in ["blackjack_unlocked", "ever_opened", "vip_enabled", "high_limit_enabled"]: set(key, bool(data[key]))
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
	reroute()
	player = Vector2(data.player[0], data.player[1])
	rng.state = int(data.rng_state)
	milestone_initializing = true
	refresh_progression()
	milestone_initializing = false
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
	var funds: float = owner_bankroll if guest.is_empty() else guest.wallet
	if not is_finite(amount) or amount < 0 or funds < amount: return false
	if guest.is_empty():
		if not owner_account.floor_debit(amount, elapsed): return false
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
		if not owner_account.floor_credit(amount, elapsed): return
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

func start_game(id: int, bet: float, trips: float = 0, slot_lines: int = 1) -> bool:
	var table := get_table(id)
	if joined != id or not ready_for_play(table) or game_pending(table): return false
	if not accepting_new_play(table) and table.get("roulette_bets", {}).is_empty(): return false
	var kind := table_kind(table)
	if slot_lines not in CasinoTuning.SLOT_LINE_COUNTS: return false
	if kind == "slots" and bet not in slot_profile(table).denominations: return false
	if kind == "craps" or not is_finite(bet) or not is_finite(trips) or bet < table.minimum or bet > maximum_wager(table) or trips < 0 or trips > maximum_wager(table): return false
	var cost := bet * 2 + trips if kind == "holdem" else bet
	if kind == "roulette":
		cost = 0
		for amount in table.roulette_bets.values(): cost += float(amount)
		if cost <= 0: return false
	else:
		if kind == "holdem" and owner_bankroll < bet * 6 + trips:
			log_event("Hold’em needs enough for Ante, Blind and a 4× raise ($%d)." % (bet * 6 + trips), false)
			return false
		if not game_debit(table, cost): return false
	var participants: Array = []
	if operating(table) and kind in ["blackjack", "holdem"]:
		for guest in seated(id):
			var stake := guest_wager(table, guest)
			if stake >= float(table.minimum) and guest.wallet >= stake * (3 if kind == "holdem" else 1): participants.append({"id": guest.id, "name": guest.name, "bet": stake})
	match kind:
		"slots": table.round = Games.spin_slots(bet, rng, slot_profile(table), slot_lines)
		"roulette":
			table.round = Games.spin_roulette(table.roulette_bets, rng)
			table.round.bets = table.roulette_bets.duplicate(true)
			table.roulette_bets.clear()
		"blackjack": table.round = Games.blackjack(bet, rng, participants)
		"holdem": table.round = Games.holdem(bet, trips, rng, participants)
	for npc in table.round.get("npcs", []):
		for guest in guests:
			if int(guest.id) == int(npc.id): game_debit(table, float(npc.staked), guest)
	if kind == "roulette" and operating(table): shared_roulette(table, int(table.round.number))
	table.round.staked = cost
	settle_game(table)
	return true

func game_action(id: int, action: String) -> bool:
	var table := get_table(id)
	if joined != id or not ready_for_play(table) or not game_pending(table): return false
	var actions := Games.actions(table.round, owner_bankroll)
	if not actions.has(action): return false
	var cost := float(actions[action])
	if not game_debit(table, cost): return false
	table.round.staked += cost
	Games.act(table.round, action)
	settle_game(table)
	return true

func roulette_bet(id: int, name: String, amount: float) -> bool:
	var table := get_table(id)
	if table.is_empty() or table_kind(table) != "roulette" or joined != id or not accepting_new_play(table) or not Games.roulette_bets().has(name) or not is_finite(amount) or amount < table.minimum: return false
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
	owner_account.floor_credit(amount, elapsed, "floor_refund")
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

# Event wagering is a separate counterparty from play at the owner's own tables.
# total_return includes original stake; only positive net profit enters casino cash.
func owner_wager_debit(operation_id: int, stake: float) -> bool:
	return owner_account.wager(operation_id, stake, elapsed)

func owner_wager_settle(operation_id: int, total_return: float, publish: bool = true) -> bool:
	if not OwnerAccount.money(total_return) or not is_finite(cash + total_return): return false
	var result := owner_account.settle(operation_id, total_return, elapsed)
	if result.is_empty(): return false
	cash += float(result.profit)
	if publish and float(result.profit) > 0:
		emit_financial_event(float(result.profit), "owner_event_profit", {}, -1, {"actor": "owner", "operation_id": operation_id})
	return true

func owner_wager_refund(operation_id: int) -> bool:
	return not owner_account.refund(operation_id, elapsed).is_empty()

func owner_wager_loss(operation_id: int) -> bool:
	return owner_wager_settle(operation_id, 0)

func reward_owner_bankroll(operation_id: int, amount: float, reason: String) -> bool:
	return owner_account.reward(operation_id, amount, reason, elapsed)

func owner_wager_win(operation_id: int, net_profit_amount: float) -> bool:
	if not OwnerAccount.money(net_profit_amount): return false
	var key := str(operation_id)
	if not owner_account.pending.has(key): return false
	return owner_wager_settle(operation_id, float(owner_account.pending[key]) + net_profit_amount)

func owner_play_transaction(action: Callable) -> bool:
	# A failed checkpoint rolls back this rare gameplay transaction atomically.
	if owner_checkpoint.is_valid() and not owner_checkpoint.call(): return false
	var before: Dictionary = snapshot() if owner_checkpoint.is_valid() else {}
	var already_done: bool = owner_play.get("status") == "done"
	var promotion_before := sponsored_income
	if not action.call(): return false
	if owner_checkpoint.is_valid() and not owner_checkpoint.call():
		restore(before)
		log_event("Owner event action canceled because its save checkpoint failed.")
		return false
	if sponsored_income > promotion_before:
		emit_financial_event(sponsored_income - promotion_before, "sponsored_promotion", {}, -1, {"actor": "sponsor", "event_id": owner_play.event_id, "virtual_stake": float(owner_play.base), "revealed": int(owner_play.revealed)})
	if not already_done and owner_play.get("status") == "done":
		var result: Dictionary = owner_play.result
		if float(result.casino_profit) > 0 and owner_play.funding == "owner":
			emit_financial_event(float(result.casino_profit), "owner_event_profit", {}, -1, {"actor": "owner", "event_id": owner_play.event_id})
		owner_event_completed.emit(result.duplicate(true))
	return true

func start_owner_event(event_id: int, stake: float) -> bool:
	if back_room.busy(): return false
	return owner_play_transaction(func(): return OwnerPlay.start(self, event_id, stake))

func owner_event_action(action: String, sequence: int) -> bool:
	return owner_play_transaction(func(): return OwnerPlay.act(self, action, sequence))

func exit_owner_event() -> bool:
	return owner_play_transaction(func(): return OwnerPlay.exit(self))

func owner_event_table() -> Dictionary:
	return OwnerPlay.view_table(self)

# Private transactions snapshot only their owned state. Public simulation/RNG timing is untouched.
func private_transaction(action: Callable) -> bool:
	if joined >= 0 or not owner_play.is_empty(): return false
	if owner_checkpoint.is_valid() and not owner_checkpoint.call(): return false
	var account_before := owner_account.snapshot()
	var room_before := back_room.snapshot()
	var recovery_before := recovery.snapshot()
	var cash_before := cash
	var profit_before := owner_account.profit_transferred
	var accepted: bool = action.call()
	if not accepted or (owner_checkpoint.is_valid() and not owner_checkpoint.call()):
		owner_account.restore(account_before)
		back_room.restore(room_before, owner_account)
		recovery.restore(recovery_before)
		cash = cash_before
		return false
	var profit := owner_account.profit_transferred - profit_before
	if profit > 0: emit_financial_event(profit, "back_room_profit", {}, -1, {"actor": "owner"})
	return true

func private_action(sequence: int, action: String, args: Dictionary = {}) -> bool:
	if sequence != int(back_room.state.sequence): return false
	return private_transaction(func():
		match action:
			"choose": return back_room.choose(str(args.get("kind", "")))
			"start": return back_room.start(self, float(args.get("stake", 0)), int(args.get("lines", 1)), float(args.get("trips", 0)))
			"act": return back_room.act(self, str(args.get("action", "")))
			"add": return back_room.add(self, str(args.get("key", "")), float(args.get("stake", 0)))
			"remove": return back_room.remove(self, str(args.get("key", "")))
			"roll": return back_room.roll(self)
			"working":
				back_room.state.working = not back_room.state.working
				back_room.state.sequence += 1
				return true
		return false)
