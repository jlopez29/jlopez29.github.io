class_name CasinoSimulation
extends RefCounted

var cash := CasinoTuning.STARTING_CASH
var wallet := CasinoTuning.VISITOR_CASH
var revenue := 0.0
var payouts := 0.0
var payroll := 0.0
var overhead := 0.0
var visitor_net := 0.0
var reputation := 60.0
var minute := 1080
var day := 1
var elapsed := 0
var opened := false
var tables: Array = []
var guests: Array = []
var staff: Array = []
var alerts: Array = []
var incidents: Array = []
var next_id := 1
var joined := -1
var player := Vector2(425, 510)
var rng := RandomNumberGenerator.new()

func _init() -> void:
	rng.randomize()
	tables.append(new_table(Vector2(320, 240), false))
	log_event("Welcome to Neon House. Hire a two-dealer crew, then open the doors.")

func new_table(at: Vector2, rotated: bool) -> Dictionary:
	var item := {"id": next_id, "x": at.x, "y": at.y, "rotated": rotated, "point": 0, "dice": [1, 1], "timer": 0.0, "wagers": 0.0, "payouts": 0.0, "broken": false, "rolls": 0, "minimum": 25.0, "owner": CrapsRules.empty_bets(), "result": "Come-out roll. Place a Pass Line bet to start."}
	next_id += 1
	return item

func log_event(message: String) -> void:
	alerts.push_front(message)
	if alerts.size() > 8:
		alerts.pop_back()

func get_table(id: int) -> Dictionary:
	for table in tables:
		if int(table.id) == id:
			return table
	return {}

func crew(id: int) -> Array:
	return staff.filter(func(s): return s.role == "Dealer" and int(s.table) == id)

func seated(id: int) -> Array:
	return guests.filter(func(g): return int(g.table) == id and g.state == "Playing")

func operating(table: Dictionary) -> bool:
	return opened and not table.broken and crew(int(table.id)).size() >= CasinoTuning.CREW_REQUIRED

func table_status(table: Dictionary) -> String:
	if table.broken:
		return "Repair needed"
	if crew(int(table.id)).size() < CasinoTuning.CREW_REQUIRED:
		return "Needs %d dealers" % (CasinoTuning.CREW_REQUIRED - crew(int(table.id)).size())
	return "Open" if opened else "Doors closed"

func hire(role: String, target: int) -> bool:
	if staff.size() >= 16:
		log_event("Staff limit reached for this small casino.")
		return false
	if cash < 150:
		log_event("Hiring needs $150 for training.")
		return false
	cash -= 150
	overhead += 150
	var assignment := -1
	if role == "Dealer":
		if not get_table(target).is_empty() and crew(target).size() < 2:
			assignment = target
		else:
			for table in tables:
				if crew(int(table.id)).size() < 2:
					assignment = int(table.id)
					break
	staff.append({"name": CasinoTuning.NAMES[rng.randi_range(0, 11)], "role": role, "table": assignment, "energy": 100.0})
	log_event("%s hired. %s" % [role, "Assigned to table %d." % assignment if assignment > 0 else "Covering the floor / on standby."])
	return true

func assign_standby(id: int) -> void:
	for employee in staff:
		if employee.role == "Dealer" and int(employee.table) == -1 and crew(id).size() < 2:
			employee.table = id
	log_event("Table %d has %d / 2 dealers." % [id, crew(id).size()])

func bounds(table: Dictionary) -> Rect2:
	var size := Vector2(100, 190) if table.rotated else CasinoTuning.TABLE_SIZE
	return Rect2(Vector2(table.x, table.y), size)

func can_place(at: Vector2, rotated: bool, ignore_id: int = -1) -> bool:
	var size := Vector2(100, 190) if rotated else CasinoTuning.TABLE_SIZE
	var rect := Rect2(at, size)
	if not Rect2(65, 100, 720, 400).encloses(rect):
		return false
	for table in tables:
		if int(table.id) != ignore_id and rect.grow(22).intersects(bounds(table)):
			return false
	return true

func place(at: Vector2, rotated: bool) -> int:
	if not can_place(at, rotated) or cash < CasinoTuning.CRAPS_COST:
		log_event("Placement needs $3,500, clear space and an aisle around the table.")
		return -1
	cash -= CasinoTuning.CRAPS_COST
	overhead += CasinoTuning.CRAPS_COST
	var table := new_table(at, rotated)
	tables.append(table)
	reroute()
	log_event("Craps table %d built. Hire or assign two dealers." % table.id)
	return int(table.id)

func busy(table: Dictionary) -> bool:
	return joined == int(table.id) or guests.any(func(g): return int(g.table) == int(table.id)) or CrapsRules.exposure(table.owner) > 0

func sell(id: int) -> bool:
	var table := get_table(id)
	if table.is_empty() or busy(table):
		log_event("Let guests leave and settle visitor bets before selling this table.")
		return false
	for employee in crew(id):
		employee.table = -1
	tables.erase(table)
	cash += 1750
	overhead -= 1750
	log_event("Table sold for $1,750. Dealers are now on standby.")
	return true

func set_open(value: bool) -> void:
	opened = value
	if not value:
		log_event("Doors closed to new guests. Existing bets will finish before guests leave.")
	else:
		log_event("Doors open. The evening crowd is on its way.")

func spawn_guest(vip: bool = false) -> void:
	if guests.size() >= CasinoTuning.MAX_GUESTS:
		return
	var bankroll := float(rng.randi_range(400, 1500)) if not vip else 5000.0
	guests.append({"id": next_id, "name": CasinoTuning.NAMES[rng.randi_range(0, 11)] + (" · VIP" if vip else ""), "x": 425.0, "y": 565.0, "tx": 425.0, "ty": 510.0, "table": -1, "seat": -1, "state": "Arriving", "wallet": bankroll, "start": bankroll, "satisfaction": 80.0, "thirst": 0.0, "age": 0, "patience": rng.randi_range(20, 40), "vip": vip, "bets": CrapsRules.empty_bets(), "thought": "Looking for a craps seat."})
	next_id += 1

func choose_table(guest: Dictionary) -> void:
	var best: Dictionary = {}
	var score := -INF
	for table in tables:
		# Reserve one owner rail position, including guests still walking to seats.
		var reserved := guests.filter(func(g): return int(g.table) == int(table.id)).size() + 1
		if not operating(table) or reserved >= CasinoTuning.TABLE_CAPACITY or guest.wallet < table.minimum:
			continue
		var value := 100.0 - Vector2(guest.x, guest.y).distance_to(bounds(table).get_center()) * 0.08 + reserved * 2.0
		if value > score:
			score = value
			best = table
	if best.is_empty():
		guest.state = "Waiting"
		guest.thought = "No affordable, staffed seat available."
		if guest.age > guest.patience or not opened:
			leave(guest, "Couldn't find an open craps seat.")
		return
	guest.table = int(best.id)
	guest.state = "Walking"
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
	guest.thought = "Found a seat. Heading to table %d." % best.id
	route(guest)

func leave(guest: Dictionary, reason: String) -> void:
	if CrapsRules.exposure(guest.bets) > 0:
		return
	guest.state = "Leaving"
	guest.table = -1
	guest.seat = -1
	guest.tx = 425.0
	guest.ty = 565.0
	guest.thought = "Leaving: " + reason
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
	for guest in guests:
		if guest.state in ["Arriving", "Walking", "Leaving"]:
			route(guest)

func move_guests(delta: float) -> void:
	for guest in guests:
		if guest.state not in ["Arriving", "Walking", "Leaving"]:
			continue
		if not guest.has("path"):
			route(guest)
		var pos := Vector2(guest.x, guest.y)
		var target := Vector2(guest.tx, guest.ty)
		var waypoint := target
		if not guest.path.is_empty():
			waypoint = Vector2(guest.path[0][0], guest.path[0][1])
		var moved := pos.move_toward(waypoint, delta * 64)
		guest.x = moved.x
		guest.y = moved.y
		if moved.distance_to(waypoint) < 1 and not guest.path.is_empty():
			guest.path.pop_front()
		if moved.distance_to(target) < 2:
			guest.erase("path")
			if guest.state == "Walking":
				guest.state = "Playing"
				guest.thought = "Let's see a long roll!"
			elif guest.state == "Arriving":
				guest.state = "Waiting"

func step() -> void:
	elapsed += 1
	minute += 1
	if minute >= 1440:
		minute = 0
		day += 1
	var service_count := staff.filter(func(s): return s.role == "Service").size()
	var wages := 0.0
	for employee in staff:
		wages += (CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE) / 60.0
		var active := opened and int(employee.table) > 0
		employee.energy = clampf(employee.energy + (-0.13 if active else 0.5), 15, 100)
	payroll += wages
	cash -= wages
	var costs := tables.size() * CasinoTuning.TABLE_OVERHEAD / 60.0
	overhead += costs
	cash -= costs
	if opened and elapsed % (3 if minute >= 1080 else 5) == 0:
		spawn_guest()
	if opened and elapsed % 100 == 0:
		spawn_guest(true)
		log_event("VIP arrival. A $5,000 player is looking for craps and quick service.")
	for guest in guests:
		guest.age += 1
		guest.thirst = maxf(0, guest.thirst + 0.35 - service_count * 0.28)
		if guest.thirst > 25:
			guest.satisfaction = maxf(0, guest.satisfaction - 0.12)
			guest.thought = "I've been waiting for a drink."
		if guest.state == "Waiting" and guest.age % 3 == 0:
			choose_table(guest)
		if guest.state == "Playing":
			var table := get_table(int(guest.table))
			if CrapsRules.exposure(guest.bets) == 0 and (not opened or guest.age > 180 or guest.wallet < table.minimum or guest.satisfaction < 25):
				leave(guest, "Heading home." if guest.wallet >= table.minimum else "Gambling budget used up.")
	guests = guests.filter(func(g): return not (g.state == "Leaving" and Vector2(g.x, g.y).distance_to(CasinoTuning.ENTRY) < 3))
	for table in tables:
		# After closing, finish existing contracts but don't take new bets.
		if table.broken or crew(int(table.id)).size() < 2 or joined == int(table.id):
			continue
		if not opened and not seated(int(table.id)).any(func(g): return CrapsRules.exposure(g.bets) > 0) and CrapsRules.exposure(table.owner) == 0:
			continue
		table.timer += 1.0
		var energy := 0.0
		for employee in crew(int(table.id)):
			energy += employee.energy / 2
		var interval := CasinoTuning.ROLL_SECONDS + (100 - energy) * 0.04
		if table.timer >= interval and (not seated(int(table.id)).is_empty() or CrapsRules.exposure(table.owner) > 0):
			table.timer = 0
			roll(int(table.id))
	if opened and elapsed % 95 == 0 and incidents.size() < 3 and not tables.is_empty():
		var table: Dictionary = tables[rng.randi_range(0, tables.size() - 1)]
		if not table.broken:
			table.broken = true
			incidents.append({"type": "repair", "table": int(table.id), "title": "Table %d · damaged rail" % table.id, "detail": "Play is halted. Repair $120 or keep the table closed."})
			log_event("Table %d halted: a damaged rail needs repair." % table.id)
	if opened and elapsed % 70 == 0 and service_count == 0 and incidents.size() < 3:
		incidents.append({"type": "service", "table": -1, "title": "Drink service complaint", "detail": "No service staff. A $60 comp buys goodwill; hire service for lasting relief."})
		log_event("Guests are asking for drinks. Hire service staff or offer a comp.")

func take_bet(table: Dictionary, bettor: Dictionary, kind: String, amount: float, owner: bool) -> bool:
	var funds: float = wallet if owner else float(bettor.wallet)
	if funds < amount or amount <= 0:
		return false
	if owner:
		wallet -= amount
		visitor_net -= amount
	else:
		bettor.wallet -= amount
	bettor.bets[kind] += amount
	cash += amount
	revenue += amount
	table.wagers += amount
	return true

func bet(id: int, kind: String) -> bool:
	var table := get_table(id)
	if table.is_empty() or not operating(table) or joined != id:
		log_event("Join an open, staffed table before placing a bet.")
		return false
	var amount := 30.0 if kind in ["six", "eight", "odds"] else float(table.minimum)
	if kind == "pass" and (int(table.point) != 0 or table.owner.pass > 0):
		log_event("Pass Line: one bet, placed before the come-out roll.")
		return false
	if kind == "odds" and (int(table.point) == 0 or table.owner.pass <= 0 or table.owner.odds + amount > table.owner.pass * 3):
		log_event("Odds require a Pass Line point; maximum 3× your line bet.")
		return false
	if kind == "field" and table.owner.field > 0:
		return false
	var placed := take_bet(table, {"bets": table.owner}, kind, amount, true)
	log_event("%s bet placed: $%d." % [kind.capitalize(), amount] if placed else "Your visitor wallet cannot cover that bet.")
	return placed

func reclaim(id: int) -> void:
	var table := get_table(id)
	if table.is_empty():
		return
	var returned := 0.0
	for kind in ["odds", "six", "eight", "field", "pass"]:
		if kind == "pass" and int(table.point) != 0:
			continue
		returned += table.owner[kind]
		table.owner[kind] = 0.0
	wallet += returned
	visitor_net += returned
	cash -= returned
	revenue -= returned
	table.wagers -= returned
	log_event("Returned $%d. An established Pass Line contract stays until resolved." % returned)

func roll(id: int, forced: Array = []) -> void:
	var table := get_table(id)
	if table.is_empty() or table.broken or crew(id).size() < 2:
		return
	var old_point := int(table.point)
	for guest in seated(id):
		if opened and old_point == 0 and guest.bets.pass == 0 and guest.wallet >= table.minimum:
			var stake: float = table.minimum * (4 if guest.vip else 1)
			take_bet(table, guest, "pass", minf(stake, guest.wallet), false)
	var dice := [rng.randi_range(1, 6), rng.randi_range(1, 6)] if forced.is_empty() else forced
	table.dice = dice
	for guest in seated(id):
		var result := CrapsRules.resolve(old_point, guest.bets, int(dice[0]), int(dice[1]))
		var previous := CrapsRules.exposure(guest.bets)
		guest.bets = result.bets
		guest.wallet += result.credit
		cash -= result.credit
		payouts += result.credit
		table.payouts += result.credit
		if result.credit > 0:
			guest.satisfaction = minf(100, guest.satisfaction + 3)
			guest.thought = "Winner! This table has energy."
		elif previous > CrapsRules.exposure(guest.bets):
			guest.satisfaction = maxf(0, guest.satisfaction - 1)
			guest.thought = "Next shooter, please."
	var result := CrapsRules.resolve(old_point, table.owner, int(dice[0]), int(dice[1]))
	table.owner = result.bets
	wallet += result.credit
	visitor_net += result.credit
	cash -= result.credit
	payouts += result.credit
	table.payouts += result.credit
	table.point = result.point
	table.result = result.message
	table.rolls += 1
	if joined == id:
		log_event(result.message + (" Returned $%d to your wallet." % result.credit if result.credit > 0 else ""))

func resolve_incident(index: int, pay: bool) -> void:
	if index < 0 or index >= incidents.size():
		return
	var incident: Dictionary = incidents[index]
	var cost := 120.0 if incident.type == "repair" else 60.0
	if pay and cash < cost:
		log_event("Not enough casino cash to resolve this incident.")
		return
	if incident.type == "repair" and not pay:
		log_event("Table stays halted. Repair it when cash is available.")
		return
	if pay:
		cash -= cost
		overhead += cost
		if incident.type == "repair":
			var table := get_table(int(incident.table))
			if not table.is_empty():
				table.broken = false
		else:
			reputation = minf(100, reputation + 2)
			for guest in guests:
				guest.satisfaction = minf(100, guest.satisfaction + 8)
		log_event("%s resolved for $%d." % [incident.title, cost])
	else:
		reputation = maxf(0, reputation - 3)
		log_event("Complaint dismissed. Reputation -3: guests felt ignored.")
	incidents.remove_at(index)

func net_profit() -> float:
	return revenue - payouts - payroll - overhead

func satisfaction() -> float:
	if guests.is_empty():
		return 80
	var total := 0.0
	for guest in guests:
		total += guest.satisfaction
	return total / guests.size()

func snapshot() -> Dictionary:
	return {"version": CasinoTuning.SAVE_VERSION, "cash": cash, "wallet": wallet, "revenue": revenue, "payouts": payouts, "payroll": payroll, "overhead": overhead, "visitor_net": visitor_net, "reputation": reputation, "minute": minute, "day": day, "elapsed": elapsed, "opened": opened, "tables": tables.duplicate(true), "guests": guests.duplicate(true), "staff": staff.duplicate(true), "alerts": alerts.duplicate(), "incidents": incidents.duplicate(true), "next_id": next_id, "joined": joined, "player": [player.x, player.y], "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	if int(data.get("version", -1)) != CasinoTuning.SAVE_VERSION:
		return false
	# Saves are local, versioned simulation snapshots rather than scene-tree dumps.
	for key in ["cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "opened", "tables", "guests", "staff", "alerts", "incidents", "next_id", "joined", "player", "rng_state"]:
		if not data.has(key):
			return false
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
		for key in ["id", "x", "y", "rotated", "point", "dice", "timer", "wagers", "payouts", "broken", "rolls", "minimum", "owner", "result"]:
			if not table.has(key):
				return false
		for key in ["id", "x", "y", "point", "timer", "wagers", "payouts", "rolls", "minimum"]:
			if not valid_number(table[key]):
				return false
		if int(table.id) in ids or int(table.id) < 1 or int(table.point) not in [0, 4, 5, 6, 8, 9, 10]:
			return false
		ids.append(int(table.id))
		if not table.rotated is bool or not table.broken is bool or not table.result is String or not valid_bets(table.owner):
			return false
		if not table.dice is Array or table.dice.size() != 2:
			return false
		for die in table.dice:
			if not valid_number(die) or int(die) < 1 or int(die) > 6:
				return false
		if float(table.minimum) not in [25.0, 50.0] or not Rect2(65, 100, 720, 400).encloses(bounds(table)):
			return false
	if int(data.joined) != -1 and int(data.joined) not in ids:
		return false
	for guest in data.guests:
		if not guest is Dictionary:
			return false
		for key in ["id", "name", "x", "y", "tx", "ty", "table", "seat", "state", "wallet", "start", "satisfaction", "thirst", "age", "patience", "vip", "bets", "thought"]:
			if not guest.has(key):
				return false
		for key in ["id", "x", "y", "tx", "ty", "table", "seat", "wallet", "start", "satisfaction", "thirst", "age", "patience"]:
			if not valid_number(guest[key]):
				return false
		if float(guest.wallet) < 0 or not valid_bets(guest.bets) or not guest.vip is bool:
			return false
		if int(guest.table) != -1 and int(guest.table) not in ids:
			return false
		if guest.state in ["Walking", "Playing"] and (int(guest.table) < 1 or int(guest.seat) not in range(7)):
			return false
		if guest.state not in ["Arriving", "Waiting", "Walking", "Playing", "Leaving"] or not guest.name is String or not guest.thought is String:
			return false
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
	for key in ["cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation"]:
		set(key, float(data[key]))
	for key in ["minute", "day", "elapsed", "next_id", "joined"]:
		set(key, int(data[key]))
	opened = bool(data.opened)
	for key in ["tables", "guests", "staff", "alerts", "incidents"]:
		set(key, data[key].duplicate(true))
	player = Vector2(data.player[0], data.player[1])
	rng.state = int(data.rng_state)
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
