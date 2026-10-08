extends RefCounted
# Employee lifecycle and coverage allocation; game resolution stays in simulation.

static func new_employee(sim, role: String, table_id: int = -1) -> Dictionary:
	var employee_id: int = sim.next_id
	sim.next_id += 1
	var employee := {"id": employee_id, "name": CasinoTuning.NAMES[sim.rng.randi_range(0, 11)], "role": role,
		"table": table_id, "energy": 100.0, "duty": "Active" if table_id > 0 else "Off Duty",
		"state_since": sim.elapsed, "shift_end": sim.elapsed + CasinoTuning.STAFF_SHIFT_MINUTES,
		"available_at": sim.elapsed, "rest_due": "", "service_product": ""}
	if role == "Tech":
		employee.duty = "On Call"
		employee.merge({"call_speed": CasinoTuning.ENTITY_WALK_SPEED, "repair_target": -1, "repair_minutes": 0, "x": CasinoTuning.ENTRY.x, "y": CasinoTuning.ENTRY.y, "tx": CasinoTuning.ENTRY.x, "ty": CasinoTuning.ENTRY.y})
	return employee

static func wage(role: String) -> float:
	return CasinoTuning.DEALER_WAGE if role == "Dealer" else CasinoTuning.TECH_WAGE if role == "Tech" else CasinoTuning.SERVICE_WAGE

static func compatible(sim, employee: Dictionary, table: Dictionary) -> bool:
	# One compatibility hook; all current dealers cover all current table games.
	return employee.role == "Dealer" and sim.required_crew(table) > 0

static func has_commitments(sim, table: Dictionary) -> bool:
	return not table.is_empty() and (sim.game_pending(table) or sim.asset_pending_stakes(table) > 0)

static func available(employee: Dictionary) -> bool:
	return employee.duty in ["Active", "Relief"] and employee.rest_due == ""

static func can_start(sim, employee: Dictionary) -> bool:
	return employee.duty == "Off Duty" and sim.elapsed >= int(employee.available_at) and float(employee.energy) >= CasinoTuning.STAFF_RETURN_ENERGY

static func start_shift(sim, employee: Dictionary) -> void:
	employee.duty = "Relief"
	employee.state_since = sim.elapsed
	employee.shift_end = sim.elapsed + CasinoTuning.STAFF_SHIFT_MINUTES
	employee.rest_due = ""

static func rest(sim, employee: Dictionary, state: String) -> void:
	employee.duty = state
	employee.table = -1
	employee.state_since = sim.elapsed
	employee.rest_due = ""
	if state == "Off Duty": employee.available_at = sim.elapsed + CasinoTuning.STAFF_OFF_DUTY_MINUTES
	if employee.role == "Service":
		for guest in sim.guests:
			if int(guest.id) == int(employee.get("service_target", -1)) and guest.drink_state == "SERVICE_ASSIGNED":
				sim.DrinkService.transition(sim, guest, "WAITING_FOR_SERVICE")
		employee.service_target = -1
		employee.service_product = ""
		employee.erase("service_state")
		employee.erase("path")

static func best_relief(sim, role: String, table: Dictionary = {}) -> Dictionary:
	var pool: Array = sim.staff.filter(func(e): return e.role == role and e.duty == "Relief" and e.rest_due == "" and e.energy >= CasinoTuning.STAFF_RETURN_ENERGY and (table.is_empty() or compatible(sim, e, table)))
	pool.sort_custom(func(a, b): return a.energy > b.energy)
	return {} if pool.is_empty() else pool[0]

static func request_rest(sim, employee: Dictionary, state: String) -> void:
	if employee.duty == "Off Duty" or (employee.duty == "Break" and state == "Break"): return
	var table: Dictionary = sim.get_table(int(employee.table))
	var replacement: Dictionary = best_relief(sim, str(employee.role), table if employee.role == "Dealer" else {}) if employee.duty == "Active" else {}
	if not replacement.is_empty():
		replacement.duty = "Active"
		replacement.table = employee.table
		replacement.state_since = sim.elapsed
		if not table.is_empty(): table.staff_rotation_until = sim.elapsed + CasinoTuning.STAFF_ROTATION_NOTICE_MINUTES
	elif employee.role == "Dealer" and employee.duty == "Active" and has_commitments(sim, table):
		# Keep the actual crew until funded contracts finish; accept no new play.
		employee.rest_due = state
		return
	rest(sim, employee, state)

static func tick(sim) -> void:
	for employee in sim.staff:
		if employee.role == "Tech": continue
		var rate := 0.0
		match employee.duty:
			"Active":
				var working: bool = sim.opened or (sim.joined >= 0 and sim.joined == int(employee.table)) or has_commitments(sim, sim.get_table(int(employee.table)))
				rate = -CasinoTuning.STAFF_FATIGUE_PER_MINUTE if working else CasinoTuning.STAFF_IDLE_RECOVERY
			"Relief": rate = CasinoTuning.STAFF_RELIEF_RECOVERY
			"Break": rate = CasinoTuning.STAFF_BREAK_RECOVERY
			"Off Duty": rate = CasinoTuning.STAFF_OFF_DUTY_RECOVERY
		employee.energy = clampf(float(employee.energy) + rate, 0, 100)
		if employee.duty == "Off Duty": continue
		if sim.elapsed >= int(employee.shift_end):
			request_rest(sim, employee, "Off Duty")
		elif employee.duty == "Break":
			if sim.elapsed - int(employee.state_since) >= CasinoTuning.STAFF_BREAK_MINUTES and employee.energy >= CasinoTuning.STAFF_RETURN_ENERGY:
				employee.duty = "Relief"
				employee.state_since = sim.elapsed
		elif employee.rest_due != "":
			request_rest(sim, employee, str(employee.rest_due))
		elif employee.duty == "Active" and employee.energy <= CasinoTuning.STAFF_BREAK_ENERGY:
			var relief: Dictionary = best_relief(sim, str(employee.role), sim.get_table(int(employee.table)) if employee.role == "Dealer" else {})
			if not relief.is_empty() or employee.energy <= CasinoTuning.STAFF_EXHAUSTED_ENERGY:
				request_rest(sim, employee, "Break")
	rebalance(sim)
	shift_handover(sim)
	report_problems(sim)

static func shift_handover(sim) -> void:
	if not sim.opened or sim.elapsed - sim.staff_shift_handover_at < CasinoTuning.STAFF_SHIFT_HANDOVER_GAP: return
	var finishing: Array = sim.staff.filter(func(e): return e.role != "Tech" and e.duty == "Active" and e.rest_due == "" and int(e.shift_end) - sim.elapsed <= CasinoTuning.STAFF_SHIFT_HANDOVER_MINUTES)
	finishing.sort_custom(func(a, b): return a.shift_end < b.shift_end)
	for employee in finishing:
		var rested: Array = sim.staff.filter(func(e): return e.role == employee.role and can_start(sim, e))
		if rested.is_empty(): continue
		start_shift(sim, rested[0])
		request_rest(sim, employee, "Off Duty")
		sim.staff_shift_handover_at = sim.elapsed
		rebalance(sim)
		return

static func targets(sim) -> Array:
	var result: Array = sim.tables.filter(func(t): return sim.required_crew(t) > 0 and not t.broken and t.staff_enabled)
	result.sort_custom(func(a, b): return int(a.staff_priority) > int(b.staff_priority) if a.staff_priority != b.staff_priority else int(a.id) < int(b.id))
	return result

static func required(sim, role: String) -> int:
	if role == "Service": return int(sim.service_positions) if sim.bar_available() else 0
	if role == "Tech": return ceili(float(sim.tables.size()) / CasinoTuning.TECH_GAMES_PER_PERSON)
	var count := 0
	for table in targets(sim): count += sim.required_crew(table)
	return count

static func rebalance(sim, admit_closed: bool = false) -> void:
	for role in ["Dealer", "Service"]:
		var need: int = required(sim, role)
		var target: int = need + int(sim.relief_targets[role]) if need > 0 else 0
		var employees: Array = sim.staff.filter(func(e): return e.role == role)
		var usable: int = employees.filter(func(e): return available(e)).size()
		var on_shift: int = employees.filter(func(e): return e.duty != "Off Duty").size()
		if sim.opened or sim.joined >= 0 or admit_closed:
			var resting: Array = employees.filter(func(e): return can_start(sim, e))
			resting.sort_custom(func(a, b): return a.available_at < b.available_at)
			for employee in resting:
				if on_shift >= target and usable >= need: break
				start_shift(sim, employee)
				on_shift += 1
				usable += 1
		if role == "Service":
			var active: Array = employees.filter(func(e): return available(e) and e.duty == "Active")
			var pool: Array = employees.filter(func(e): return available(e) and e.duty == "Relief")
			pool.sort_custom(func(a, b): return a.energy > b.energy)
			for employee in pool:
				if active.size() >= need: break
				employee.duty = "Active"
				employee.state_since = sim.elapsed
				active.append(employee)
			while active.size() > need:
				var employee: Dictionary = active.pop_back()
				rest(sim, employee, "Relief")
		else:
			allocate_dealers(sim, employees)
		# Extra roster depth waits unpaid for the next shift, rather than all
		# joining one synchronized shift. Break cover may temporarily exceed target.
		var reserves: Array = employees.filter(func(e): return e.duty == "Relief")
		reserves.sort_custom(func(a, b): return a.energy < b.energy)
		for employee in reserves:
			if on_shift <= target: break
			rest(sim, employee, "Off Duty")
			on_shift -= 1

static func allocate_dealers(sim, employees: Array) -> void:
	var pool: Array = employees.filter(func(e): return available(e))
	var protected := {}
	# Committed games keep their crew through settlement, even after disabling.
	for table in sim.tables:
		if not has_commitments(sim, table): continue
		protected[int(table.id)] = true
		for employee in sim.crew(int(table.id)):
			pool.erase(employee)
		var missing: int = sim.required_crew(table) - sim.crew(int(table.id)).size()
		var cover: Array = pool.filter(func(e): return compatible(sim, e, table))
		for i in range(mini(missing, cover.size())):
			cover[i].table = int(table.id)
			cover[i].duty = "Active"
			pool.erase(cover[i])
	var allocations := {}
	for table in targets(sim):
		if protected.has(int(table.id)): continue
		var candidates: Array = pool.filter(func(e): return compatible(sim, e, table))
		candidates.sort_custom(func(a, b): return int(a.table) == int(table.id) if (int(a.table) == int(table.id)) != (int(b.table) == int(table.id)) else a.energy > b.energy)
		if candidates.size() < sim.required_crew(table): continue
		for i in range(sim.required_crew(table)):
			var employee: Dictionary = candidates[i]
			allocations[int(employee.id)] = int(table.id)
			pool.erase(employee)
	for i in range(employees.size()):
		var employee: Dictionary = employees[i]
		if employee.duty not in ["Active", "Relief"] or protected.has(int(employee.table)): continue
		var assignment: int = int(allocations.get(int(employee.id), -1))
		employee.table = assignment
		employee.duty = "Active" if assignment >= 0 else "Relief"

static func continuous_roster(positions: int, relief: int) -> int:
	return ceili((positions + relief) * float(CasinoTuning.STAFF_SHIFT_MINUTES + CasinoTuning.STAFF_OFF_DUTY_MINUTES) / CasinoTuning.STAFF_SHIFT_MINUTES)

static func summary(sim, role: String) -> Dictionary:
	if role == "Tech": return sim.TechService.summary(sim)
	var result := {"employed": 0, "active": 0, "relief": 0, "break": 0, "off_duty": 0, "ready_next_shift": 0, "required": required(sim, role)}
	for employee in sim.staff:
		if employee.role != role: continue
		result.employed += 1
		var key: String = {"Active": "active", "Relief": "relief", "Break": "break", "Off Duty": "off_duty"}[employee.duty]
		result[key] += 1
		if can_start(sim, employee): result.ready_next_shift += 1
	result.relief_recommended = maxi(1, ceili(int(result.required) * CasinoTuning.STAFF_RELIEF_RECOMMENDATION)) if int(result.required) > 0 else 0
	result.continuous_recommended = continuous_roster(int(result.required), maxi(int(result.relief_recommended), int(sim.relief_targets[role]))) if int(result.required) > 0 else 0
	result.coverage = "NO POSITIONS" if int(result.required) == 0 else "SHORT STAFFED" if int(result.active) < int(result.required) else "LEAN COVERAGE" if int(result.employed) < int(result.continuous_recommended) or int(result.relief) < int(sim.relief_targets[role]) else "GOOD COVERAGE"
	return result

static func report_problems(sim) -> void:
	if not sim.opened: return
	var missing: Array = targets(sim).filter(func(t): return sim.crew(int(t.id)).size() < sim.required_crew(t))
	var service: Dictionary = summary(sim, "Service")
	var exhausted: bool = sim.staff.any(func(e): return e.role != "Tech" and e.duty == "Active" and e.energy <= CasinoTuning.STAFF_BREAK_ENERGY and best_relief(sim, str(e.role), sim.get_table(int(e.table))).is_empty())
	var signature: String = str(missing.map(func(t): return int(t.id))) + str(service.active < service.required) + str(exhausted)
	if signature == sim.staffing_notice_signature: return
	if sim.elapsed - sim.staffing_notice_at < CasinoTuning.STAFF_NOTICE_COOLDOWN: return
	sim.staffing_notice_signature = signature
	sim.staffing_notice_at = sim.elapsed
	if not missing.is_empty():
		var table: Dictionary = missing[0]
		sim.log_event("STAFF - Dealer shortage: %s #%d cannot accept play. Check coverage and table priorities." % [sim.asset_name(table), table.id])
	elif service.active < service.required:
		sim.log_event("STAFF - Drink service is short staffed. Rested service staff are needed.")
	elif exhausted:
		sim.log_event("STAFF - Relief pool exhausted. Tired workers need break coverage.")
