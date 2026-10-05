extends RefCounted
# Developer state preparation belongs here, not in UI callbacks or gameplay rules.
var sim: CasinoSimulation
var used := false
var message := "Developer actions create artificial testing state."

func _init(simulation: CasinoSimulation) -> void:
	sim = simulation

func _begin() -> bool:
	if not OS.is_debug_build(): return false
	used = true
	return true

func _report(text: String) -> void:
	message = text
	sim.log_event("DEV: " + text)

func add_cash(amount: float) -> void:
	if not _begin() or not is_finite(amount) or amount <= 0: return
	sim.cash += amount # Developer funding, never gaming revenue or profit feedback.
	sim.refresh_progression()
	_report("Added $%d to treasury for development." % amount)

func spawn_guests(count: int) -> void:
	if not _begin(): return
	var before := sim.guests.size()
	for i in range(clampi(count, 1, 5)): sim.spawn_guest()
	_report("Spawned %d guest(s) through normal guest creation." % (sim.guests.size() - before))

func force_unlock(feature: String) -> void:
	if not _begin(): return
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id == feature and feature != "slots":
			if feature not in sim.debug_forced_unlocks: sim.debug_forced_unlocks.append(feature)
			_report("Forced access: %s. Requirements unchanged; no equipment purchased." % str(milestone.name).replace("’", "'"))
			return

func advance_next_unlock() -> void:
	if not _begin(): return
	for milestone in CasinoTuning.MILESTONES:
		var feature := str(milestone.id)
		if sim.unlocked(feature): continue
		# Later milestones require the genuine Blackjack accomplishment too.
		if not sim.blackjack_unlocked and not _prepare_blackjack(): return
		if feature != "blackjack" and not _prepare_rating(float(milestone.rating)): return
		sim.refresh_progression()
		if not sim.unlocked(feature):
			_report("Could not satisfy %s; inspect current prerequisites." % milestone.name)
			return
		_report("Prepared real prerequisites for %s. Normal unlock detection ran." % str(milestone.name).replace("’", "'"))
		return
	_report("All current milestones are already accessible.")

func rating_plus_one() -> void:
	if not _begin(): return
	var target := minf(100, sim.casino_rating + 1.0)
	if _prepare_rating(target):
		sim.refresh_progression()
		_report("Prepared property/activity for Rating %.1f (now %.1f)." % [target, sim.casino_rating])

func _fund(amount: float) -> void:
	# Fund only a shortfall; normal purchase paths still record their actual costs.
	if sim.cash < amount: sim.cash = amount

func _build_game(kind: String) -> bool:
	var area := sim.build_area()
	for rotated in [false, true]:
		for y in range(int(area.position.y), int(area.end.y), 10):
			for x in range(int(area.position.x), int(area.end.x), 10):
				var at := Vector2(x, y)
				if not sim.can_place(at, rotated, -1, kind): continue
				_fund(sim.feature_cost(kind))
				var id := sim.place(at, rotated, kind)
				if id < 0: return false
				var table := sim.get_table(id)
				while sim.crew(id).size() < sim.required_crew(table):
					_fund(CasinoTuning.HIRING_COST)
					if not sim.hire("Dealer", id): return false
				return true
	return false

func _prepare_blackjack() -> bool:
	var goal: Dictionary = CasinoTuning.BLACKJACK_REQUIREMENTS
	# Repair existing slots before adding real, legally placed starter capacity.
	for index in range(sim.incidents.size() - 1, -1, -1):
		var incident: Dictionary = sim.incidents[index]
		var table := sim.get_table(int(incident.table))
		if incident.type == "repair" and not table.is_empty() and sim.table_kind(table) == "slots":
			_fund(float(sim.slot_profile(table).repair_cost))
			sim.resolve_incident(index, true)
	while sim.gaming_development(true) < float(goal.development) or sim.usable_gaming_capacity() < int(goal.capacity):
		var before := sim.gaming_development(true)
		if not _build_game("slots"):
			_report("No legal room for required slots. Move equipment, then retry Advance.")
			return false
		if sim.gaming_development(true) <= before and sim.usable_gaming_capacity() < int(goal.capacity):
			_report("Current slot profiles cannot satisfy the development requirement.")
			return false
	sim.guest_handle = maxf(sim.guest_handle, float(goal.handle))
	sim.guests_served = maxi(sim.guests_served, int(goal.guests))
	sim.guest_rounds = maxi(sim.guest_rounds, sim.guests_served)
	# Cover liabilities and owner-transfer exclusions using the actual readiness value.
	sim.cash += maxf(0, float(goal.cash) - sim.development_cash())
	if not _prepare_rating(float(goal.rating)): return false
	sim.refresh_progression()
	return sim.blackjack_unlocked

func _add_property_development() -> bool:
	# Use only owned-state changes for systems that actually exist and are accessible.
	for milestone in CasinoTuning.MILESTONES:
		var feature := str(milestone.id)
		if not sim.unlocked(feature): continue
		if feature == "slots":
			var slots := 0.0
			for table in sim.tables:
				if sim.table_kind(table) == "slots": slots += float(sim.slot_profile(table).development)
			if slots < CasinoTuning.SLOT_DEVELOPMENT_CAP and _build_game(feature): return true
		elif not sim.feature_owned(feature):
			if CasinoSimulation.Games.COSTS.has(feature):
				if _build_game(feature): return true
			elif feature == "service":
				_fund(CasinoTuning.HIRING_COST)
				if sim.hire("Service", -1): return true
			else:
				_fund(sim.feature_cost(feature))
				if sim.purchase_upgrade(feature): return true
	return false

func _prepare_rating(target: float) -> bool:
	# The simulation owns the formula. Find supporting activity through its evaluator;
	# no rating override, elapsed-time shortcut or synthetic gambling is necessary.
	while sim.rating_for_activity(1.0e9, 1000000) < target:
		if not _add_property_development():
			if not sim.blackjack_unlocked and target > float(CasinoTuning.BLACKJACK_REQUIREMENTS.rating):
				if _prepare_blackjack(): continue
			_report("More property development/space is needed before Rating %.1f. Advance or purchase the next feature." % target)
			return false
	var low := 0.0
	var high := sim.property_development()
	for i in range(32):
		var activity := (low + high) / 2.0
		var handle := maxf(sim.guest_handle, activity * CasinoTuning.RATING_HANDLE_UNIT)
		var served := maxi(sim.guests_served, ceili(activity * CasinoTuning.RATING_GUEST_UNIT))
		if sim.rating_for_activity(handle, served) >= target: high = activity
		else: low = activity
	sim.guest_handle = maxf(sim.guest_handle, high * CasinoTuning.RATING_HANDLE_UNIT)
	sim.guests_served = maxi(sim.guests_served, ceili(high * CasinoTuning.RATING_GUEST_UNIT))
	sim.guest_rounds = maxi(sim.guest_rounds, sim.guests_served)
	sim.refresh_progression()
	return sim.casino_rating >= target
