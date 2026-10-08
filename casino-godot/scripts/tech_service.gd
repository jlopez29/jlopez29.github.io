extends RefCounted
# On-call repairs use the same incident settlement as manual repairs.

static func release(employee: Dictionary) -> void:
	employee.duty = "On Call"
	employee.repair_target = -1
	employee.repair_minutes = 0
	employee.erase("path")

static func tick(sim) -> void:
	var claimed := {}
	var technicians: Array = sim.staff.filter(func(e): return e.role == "Tech")
	for employee in technicians:
		var table: Dictionary = sim.get_table(int(employee.repair_target))
		if employee.duty != "Repairing" or table.is_empty() or not table.broken:
			release(employee)
		else:
			claimed[int(table.id)] = true
	# Rotate calls through the roster, with the longest-idle Tech first.
	technicians.sort_custom(func(a, b): return a.state_since < b.state_since if a.state_since != b.state_since else a.id < b.id)
	for employee in technicians:
		if int(employee.repair_target) < 0:
			for incident in sim.incidents:
				if incident.type != "repair" or claimed.has(int(incident.table)): continue
				var table: Dictionary = sim.get_table(int(incident.table))
				if table.is_empty() or not table.broken: continue
				if sim.cash < sim.repair_cost(table): continue
				var target: Vector2 = sim.guest_approach_position(table, 0)
				employee.repair_target = int(table.id)
				employee.duty = "Repairing"
				employee.state_since = sim.elapsed
				employee.tx = target.x
				employee.ty = target.y
				sim.route(employee)
				# A call-out reaches the job within one game minute, including
				# larger floors. Keep movement on the shared walkable route.
				var distance := 0.0
				var at := Vector2(employee.x, employee.y)
				for point in employee.path:
					var next := Vector2(point[0], point[1])
					distance += at.distance_to(next)
					at = next
				employee.call_speed = maxf(CasinoTuning.ENTITY_WALK_SPEED, distance / CasinoTuning.TECH_CALL_TRAVEL_MINUTES)
				claimed[int(table.id)] = true
				break
			continue # Start work on the next minute, after the call-out.
		if int(employee.repair_target) < 0: continue
		if Vector2(employee.x, employee.y).distance_to(Vector2(employee.tx, employee.ty)) > 6: continue
		employee.repair_minutes = mini(int(employee.repair_minutes) + 1, CasinoTuning.TECH_REPAIR_MINUTES)
		if int(employee.repair_minutes) < CasinoTuning.TECH_REPAIR_MINUTES: continue
		var table: Dictionary = sim.get_table(int(employee.repair_target))
		if sim.cash < sim.repair_cost(table):
			release(employee)
			continue
		for index in range(sim.incidents.size()):
			var incident: Dictionary = sim.incidents[index]
			if incident.type == "repair" and int(incident.table) == int(employee.repair_target):
				sim.resolve_incident(index, true)
				release(employee)
				break

static func move(sim, delta: float) -> void:
	for employee in sim.staff:
		if employee.role != "Tech" or employee.duty != "Repairing" or int(employee.repair_target) < 0: continue
		if not employee.has("path"): sim.route(employee)
		sim.move_entity(employee, delta * float(employee.call_speed) / CasinoTuning.ENTITY_WALK_SPEED)

static func summary(sim) -> Dictionary:
	var employees: Array = sim.staff.filter(func(e): return e.role == "Tech")
	var repairing: int = employees.filter(func(e): return e.duty == "Repairing").size()
	var needed: int = sim.Staffing.required(sim, "Tech")
	return {"employed": employees.size(), "repairing": repairing, "on_call": employees.size() - repairing,
		"required": needed, "games": sim.tables.size(), "capacity": employees.size() * CasinoTuning.TECH_GAMES_PER_PERSON,
		"coverage": "GOOD COVERAGE" if employees.size() >= needed else "SHORT STAFFED"}

static func valid_employee(sim, employee: Dictionary, tables: Array, claims: Dictionary) -> bool:
	if int(employee.table) != -1 or employee.rest_due != "" or employee.service_product != "": return false
	for key in ["repair_target", "repair_minutes", "x", "y", "tx", "ty", "call_speed"]:
		if not sim.valid_number(employee.get(key)): return false
	if employee.repair_target != int(employee.repair_target) or employee.repair_minutes != int(employee.repair_minutes): return false
	if employee.repair_minutes < 0 or employee.repair_minutes > CasinoTuning.TECH_REPAIR_MINUTES: return false
	var target := int(employee.repair_target)
	if employee.call_speed < CasinoTuning.ENTITY_WALK_SPEED: return false
	if target == -1: return employee.repair_minutes == 0 and employee.duty == "On Call"
	if employee.duty != "Repairing" or claims.has(target): return false
	if not tables.any(func(t): return int(t.id) == target): return false
	claims[target] = true
	return true
