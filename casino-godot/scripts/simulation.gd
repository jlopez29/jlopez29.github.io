class_name CasinoSimulation
extends RefCounted

const Games = preload("res://scripts/casino_games.gd")

var cash := CasinoTuning.STARTING_CASH
var wallet := CasinoTuning.VISITOR_CASH
var revenue := 0.0
var payouts := 0.0
var payroll := 0.0
var overhead := 0.0
var visitor_net := 0.0
var reputation := 60.0
var difficulty := "normal"
var starting_games: Array = ["slots"]
var casino_rating := 0.0
var guest_rounds := 0
var guest_revenue := 0.0
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
	log_event("Normal: two slots, $%d and room to grow. Open the casino to welcome your first guest." % CasinoTuning.STARTING_CASH if restricted() else "Easy: your chosen games and crews are ready. Access is unrestricted; wages and gaming risk still apply.")

func restricted() -> bool:
	return bool(CasinoTuning.DIFFICULTIES[difficulty].restricted)

func unlocked(feature: String) -> bool:
	if not restricted(): return true
	for milestone in CasinoTuning.MILESTONES:
		if milestone.id == feature: return casino_rating >= float(milestone.rating)
	return false

func revealed(feature: String) -> bool:
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
			return "Next: %s · Rating %.1f / %.0f. Satisfied guest play earns Rating." % [name, casino_rating, milestone.rating]
		var crew_note := ""
		if Games.COSTS.has(milestone.id) and milestone.id != "slots":
			crew_note = " + %d dealer(s) at $%d each" % [2 if milestone.id == "craps" else 1, CasinoTuning.HIRING_COST]
		return "Next: %s · $%d%s. Treasury: $%d." % [name, feature_cost(str(milestone.id)), crew_note, cash]
	return "Your gaming catalog is complete. Grow the floor and protect your operating reserve."

func onboarding_text() -> String:
	if not restricted():
		return "Open your chosen games, watch the guests, and manage crews and cash. Walk to a game to play with your separate visitor wallet."
	if not ever_opened: return "1. Open the casino. Your two slots need no staff."
	if guest_rounds == 0: return "2. Watch the first guest play a slot. Arrivals begin after 10 open minutes."
	if guest_revenue < CasinoTuning.OPENING_REVENUE:
		return "3. Collect $%d in guest wagers: $%.0f so far. Payouts and costs reduce your profit." % [CasinoTuning.OPENING_REVENUE, guest_revenue]
	if not feature_owned("blackjack"):
		return "4. Another slot costs $%d; blackjack costs $%d plus a dealer. Reinvest or save a reserve." % [Games.COSTS.slots, Games.COSTS.blackjack]
	if not feature_owned("service"):
		return "Your first table needs one dealer. Drink service is the next step; staff cost $%d plus hourly wages." % CasinoTuning.HIRING_COST
	return "Grow at your own pace. Cash pays for purchases; Casino Rating earns access."

func record_guest_round(guest: Dictionary) -> void:
	guest_rounds += 1
	if float(guest.satisfaction) < CasinoTuning.RATING_SATISFACTION_MIN: return
	var old_rating := casino_rating
	casino_rating = minf(100, casino_rating + CasinoTuning.RATING_PER_ROUND)
	if restricted():
		for milestone in CasinoTuning.MILESTONES:
			if old_rating < float(milestone.rating) and casino_rating >= float(milestone.rating):
				log_event("Unlocked: %s. Purchase through Build / Staff." % milestone.name)

func build_area() -> Rect2:
	return CasinoTuning.FULL_BUILD_AREA if expanded else CasinoTuning.STARTER_BUILD_AREA

func purchase_upgrade(feature: String) -> bool:
	if feature not in ["expansion", "vip", "high_limit"] or feature_owned(feature) or not unlocked(feature): return false
	var cost := feature_cost(feature)
	if cash < cost:
		log_event("This upgrade needs $%d in casino cash." % cost)
		return false
	cash -= cost
	overhead += cost
	match feature:
		"expansion": expanded = true
		"vip": vip_enabled = true
		"high_limit": high_limit_enabled = true
	log_event("Purchased: %s." % feature.replace("_", " "))
	return true

func change_minimum(id: int) -> bool:
	var table := get_table(id)
	if table.is_empty() or busy(table):
		log_event("Change limits when the game is empty.")
		return false
	if table_kind(table) == "slots":
		table.minimum = 10.0 if table.minimum == 5 else 5.0
	elif float(table.minimum) < 25:
		table.minimum = 25.0
	elif float(table.minimum) == 25 and high_limit_enabled:
		table.minimum = 50.0
	else:
		table.minimum = 25.0 if table_kind(table) == "craps" else 10.0
	return true

func new_table(at: Vector2, rotated: bool, kind: String = "craps") -> Dictionary:
	var item := {"kind": kind, "round": {}, "roulette_bets": {}, "id": next_id, "x": at.x, "y": at.y, "rotated": rotated, "point": 0, "dice": [1, 1], "timer": 0.0, "wagers": 0.0, "payouts": 0.0, "broken": false, "rolls": 0, "shooter": -1, "shooter_seat": -1, "hand_rolls": 0, "owner_queued": false, "betting_hold": false, "owner_working": false, "history": [], "service_minutes": 0, "minimum": 5.0 if kind == "slots" else (10.0 if kind != "craps" else 25.0), "owner": CrapsRules.empty_bets(), "result": "Come-out roll. Place a Pass Line bet to start." if kind == "craps" else "Ready for the first guest."}
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

func table_kind(table: Dictionary) -> String:
	return str(table.get("kind", ""))

func required_crew(table: Dictionary) -> int:
	return 0 if table_kind(table) == "slots" else (2 if table_kind(table) == "craps" else 1)

func capacity(table: Dictionary) -> int:
	return 1 if table_kind(table) == "slots" else 8

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
		log_event("Earn more Casino Rating to unlock this staff role.")
		return false
	if staff.size() >= 16:
		log_event("Staff limit reached for this small casino.")
		return false
	if cash < CasinoTuning.HIRING_COST:
		log_event("Hiring needs $%d for training." % CasinoTuning.HIRING_COST)
		return false
	cash -= CasinoTuning.HIRING_COST
	overhead += CasinoTuning.HIRING_COST
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

func place(at: Vector2, rotated: bool, kind: String = "craps") -> int:
	if not Games.COSTS.has(kind): return -1
	if not unlocked(kind):
		log_event("Earn more Casino Rating to unlock this game.")
		return -1
	var cost := int(Games.COSTS[kind])
	if not can_place(at, rotated, -1, kind) or cash < cost:
		log_event("Placement needs $%d, clear space and an aisle." % cost)
		return -1
	cash -= cost
	overhead += cost
	var table := new_table(at, rotated, kind)
	tables.append(table)
	reroute()
	log_event("%s %d built. Required dealers: %d." % [Games.NAMES[kind], table.id, required_crew(table)])
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
	tables.erase(table)
	var resale := float(Games.COSTS[table_kind(table)]) / 2
	cash += resale
	overhead -= resale
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

func spawn_guest(vip: bool = false) -> void:
	if guests.size() >= CasinoTuning.MAX_GUESTS:
		return
	var bankroll := float(rng.randi_range(400, 1500)) if not vip else 5000.0
	guests.append({"id": next_id, "name": CasinoTuning.NAMES[rng.randi_range(0, 11)] + (" · VIP" if vip else ""), "x": 425.0, "y": 565.0, "tx": 425.0, "ty": 510.0, "table": -1, "seat": -1, "state": "Arriving", "wallet": bankroll, "start": bankroll, "satisfaction": 80.0, "thirst": 0.0, "age": 0, "preference": ["craps", "slots", "roulette", "blackjack", "holdem"][rng.randi_range(0, 4)], "patience": rng.randi_range(30, 50), "watch_left": 0, "watch_style": rng.randi_range(0, 2), "vip": vip, "bets": CrapsRules.empty_bets(), "thought": "Looking for an open game."})
	next_id += 1

func arrival_step() -> void:
	if not opened: return
	arrival_in -= 1
	if arrival_in > 0: return
	var interval := CasinoTuning.ARRIVAL_MINUTES if minute >= 1080 and minute < 1440 else CasinoTuning.QUIET_ARRIVAL_MINUTES
	arrival_in = rng.randi_range(interval.x, interval.y)
	var open_tables := tables.filter(func(t): return operating(t)).size()
	var capacity := mini(CasinoTuning.MAX_GUESTS, open_tables * 7 + 3)
	var browsing := guests.filter(func(g): return g.state in ["Arriving", "Waiting", "Browsing", "Watching"]).size()
	if browsing >= 3 + open_tables or guests.size() >= capacity: return
	var party := 2 if rng.randf() < 0.35 else 1
	for i in range(mini(party, capacity - guests.size())):
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
		leave(guest, "I'll try another evening.")
		return
	guest.watch_left = maxi(0, int(guest.watch_left) - 1)
	var hot := int(table.hand_rolls) >= 5
	var reset: bool = not table.history.is_empty() and bool(table.history[0].seven_out)
	guest.thought = "Watching the table before deciding."
	if hot: guest.thought = "That hand feels hot. Do I want in?"
	elif reset: guest.thought = "Seven-out. Watching the new shooter."
	if int(guest.watch_left) > 0: return
	# This is guest psychology only; history never changes the dice probabilities.
	var chance := 0.70
	if int(guest.watch_style) == 1: chance = 0.90 if hot else (0.30 if reset else 0.55)
	elif int(guest.watch_style) == 2: chance = 0.85 if reset or int(table.point) == 0 else 0.45
	if rng.randf() < chance:
		choose_table(guest, false)
		if guest.state == "Waiting": leave(guest, "No seat right now; maybe later.")
	else:
		leave(guest, "Just watching tonight. I'll pass on playing.")

func choose_table(guest: Dictionary, allow_watch: bool = true) -> void:
	var best: Dictionary = {}
	var score := -INF
	for table in tables:
		# Reserve one owner rail position, including guests still walking to seats.
		var reserved := guests.filter(func(g): return int(g.table) == int(table.id) and int(g.seat) >= 0 and g != guest).size() + 1
		if not operating(table) or (reserved >= capacity(table) + (1 if table_kind(table) == "slots" and joined != int(table.id) else 0) and not allow_watch) or guest.wallet < table.minimum:
			continue
		var value := (135.0 if guest.get("preference", "craps") == table_kind(table) else 100.0) - Vector2(guest.x, guest.y).distance_to(bounds(table).get_center()) * 0.08 + reserved * 2.0 - (100.0 if reserved >= capacity(table) + (1 if table_kind(table) == "slots" and joined != int(table.id) else 0) else 0.0)
		if value > score:
			score = value
			best = table
	if best.is_empty():
		guest.state = "Waiting"
		guest.thought = "No affordable, staffed seat available."
		if guest.age > guest.patience or not opened:
			leave(guest, "Couldn't find an open game.")
		return
	var observers := guests.filter(func(g): return int(g.table) == int(best.id) and g.state in ["Browsing", "Watching"]).size()
	var seats := guests.filter(func(g): return int(g.table) == int(best.id) and int(g.seat) >= 0 and g != guest).size()
	var spot := observation_spot(best, int(guest.id))
	if allow_watch and table_kind(best) != "slots" and observers < CasinoTuning.OBSERVERS_PER_TABLE and spot.x >= 0 and (seats >= (1 if table_kind(best) == "slots" and joined != int(best.id) else (0 if table_kind(best) == "slots" else 7)) or rng.randf() < 0.65):
		guest.table = int(best.id)
		guest.seat = -1
		guest.state = "Browsing"
		guest.watch_left = rng.randi_range(CasinoTuning.OBSERVE_MINUTES.x, CasinoTuning.OBSERVE_MINUTES.y)
		guest.tx = spot.x
		guest.ty = spot.y
		guest.thought = "Watching %s before buying in." % Games.NAMES[table_kind(best)]
		route(guest)
		return
	if seats >= (1 if table_kind(best) == "slots" and joined != int(best.id) else (0 if table_kind(best) == "slots" else 7)):
		leave(guest, "The rail is crowded. I'll come back later.")
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
	if CrapsRules.exposure(guest.bets) > 0 or guest.state in ["To cage", "Cashing out", "Leaving"]:
		return
	guest.state = "To cage"
	guest.table = -1
	guest.seat = -1
	guest.tx = CAGE_PICKUP.x
	guest.ty = CAGE_PICKUP.y
	guest.thought = "Cashing out: " + reason
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
		if guest.state in ["Arriving", "Walking", "Browsing", "To cage", "Leaving"]:
			route(guest)

func move_guests(delta: float) -> void:
	move_service(delta)
	for effect in cashout_effects: effect.life -= delta
	cashout_effects = cashout_effects.filter(func(e): return e.life > 0)
	for guest in guests:
		if guest.state == "Cashing out":
			guest.cage_wait = float(guest.get("cage_wait", 2.0)) - delta
			if guest.cage_wait <= 0:
				var house_net := float(guest.start) - float(guest.wallet)
				cashout_effects.push_front({"name": guest.name, "net": house_net, "cash": guest.wallet, "life": 16.0})
				if cashout_effects.size() > 4: cashout_effects.pop_back()
				log_event("%s cashed out $%d · HOUSE %s$%d" % [guest.name, guest.wallet, "+" if house_net >= 0 else "-", absf(house_net)])
				# Wagers already settled against treasury. Do not pay/debit twice here.
				guest.state = "Leaving"
				guest.tx = CasinoTuning.ENTRY.x
				guest.ty = CasinoTuning.ENTRY.y
				guest.thought = "Cashed out. Heading home."
				route(guest)
			continue
		if guest.state not in ["Arriving", "Walking", "Browsing", "To cage", "Leaving"]:
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
			if guest.state == "To cage":
				guest.state = "Cashing out"
				guest.cage_wait = 2.0
			elif guest.state == "Walking":
				guest.state = "Playing"
				guest.thought = "Ready to play %s!" % Games.NAMES[table_kind(get_table(int(guest.table)))]
			elif guest.state == "Browsing":
				guest.state = "Watching"
				guest.thought = "Watching the table before deciding."
			elif guest.state == "Arriving":
				guest.state = "Waiting"

func service_position(employee: Dictionary) -> void:
	if employee.has("service_state"): return
	employee.merge({"x": BAR_PICKUP.x, "y": BAR_PICKUP.y, "tx": BAR_PICKUP.x, "ty": BAR_PICKUP.y, "service_state": "At bar", "service_wait": 2.0, "service_target": -1}, true)

func send_to_bar(employee: Dictionary) -> void:
	employee.service_state = "To bar"
	employee.service_target = -1
	employee.tx = BAR_PICKUP.x
	employee.ty = BAR_PICKUP.y
	route(employee)

func move_service(delta: float) -> void:
	for employee in staff:
		if employee.role != "Service": continue
		service_position(employee)
		if employee.service_state == "At bar":
			employee.service_wait = maxf(0, float(employee.service_wait) - delta)
			if employee.service_wait > 0: continue
			var candidates := guests.filter(func(g): return g.state in ["Playing", "Watching", "Waiting"] and not staff.any(func(other): return int(other.get("service_target", -1)) == int(g.id)))
			candidates.sort_custom(func(a, b): return a.thirst > b.thirst)
			if candidates.is_empty(): continue
			var guest: Dictionary = candidates[0]
			employee.service_state = "Delivering"
			employee.service_target = int(guest.id)
			employee.tx = float(guest.x)
			employee.ty = float(guest.y)
			route(employee)
		if employee.service_state == "Delivering":
			var target := guests.filter(func(g): return int(g.id) == int(employee.service_target) and g.state in ["Playing", "Watching", "Waiting"])
			if target.is_empty():
				send_to_bar(employee)
			elif Vector2(target[0].x, target[0].y).distance_to(Vector2(employee.tx, employee.ty)) > 12:
				employee.tx = target[0].x
				employee.ty = target[0].y
				route(employee)
		if not employee.has("path"): route(employee)
		var pos := Vector2(employee.x, employee.y)
		var goal := Vector2(employee.tx, employee.ty)
		var waypoint := goal if employee.path.is_empty() else Vector2(employee.path[0][0], employee.path[0][1])
		var moved := pos.move_toward(waypoint, delta * 64)
		employee.x = moved.x
		employee.y = moved.y
		if moved.distance_to(waypoint) < 1 and not employee.path.is_empty(): employee.path.pop_front()
		if moved.distance_to(goal) < 2:
			employee.erase("path")
			if employee.service_state == "To bar":
				employee.service_state = "At bar"
				employee.service_wait = 2.0
			else:
				for guest in guests:
					if int(guest.id) == int(employee.service_target): guest.thought = "My drink arrived. Thanks!"
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
		wages += (CasinoTuning.DEALER_WAGE if employee.role == "Dealer" else CasinoTuning.SERVICE_WAGE) / 60.0
		var active: bool = not guests.is_empty() if employee.role == "Service" else opened and int(employee.table) > 0
		employee.energy = clampf(employee.energy + (-0.13 if active else 0.5), 15, 100)
	payroll += wages
	cash -= wages
	var costs := 0.0
	for table in tables:
		costs += (CasinoTuning.SLOT_OVERHEAD if table_kind(table) == "slots" else CasinoTuning.TABLE_OVERHEAD) / 60.0
	overhead += costs
	cash -= costs
	arrival_step()
	for guest in guests:
		guest.age += 1
		guest.thirst = maxf(0, guest.thirst + 0.35 - service_count * 0.28)
		if guest.thirst > 25 and unlocked("service"):
			guest.satisfaction = maxf(0, guest.satisfaction - 0.12)
			guest.thought = "I've been waiting for a drink."
		if guest.state in ["Arriving", "Waiting", "Browsing", "Watching"] and not opened:
			leave(guest, "The casino is closing.")
		elif guest.state == "Watching":
			watching_step(guest)
		elif guest.state == "Browsing" and guest.age > guest.patience + CasinoTuning.OBSERVE_MINUTES.y:
			leave(guest, "Could not reach a comfortable viewing spot.")
		if guest.state == "Waiting" and int(guest.age) % 3 == 0:
			choose_table(guest)
		if guest.state == "Playing":
			var table := get_table(int(guest.table))
			if CrapsRules.exposure(guest.bets) == 0 and not game_pending(table) and (not opened or guest.age > 180 or guest.wallet < table.minimum or guest.satisfaction < 25):
				leave(guest, "Heading home." if guest.wallet >= table.minimum else "Gambling budget used up.")
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
			if table.timer >= (CasinoTuning.SLOT_ROUND_MINUTES if table_kind(table) == "slots" else CasinoTuning.TABLE_GAME_ROUND_MINUTES):
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
		if table.timer >= interval and (not seated(int(table.id)).is_empty() or CrapsRules.exposure(table.owner) > 0 or joined == int(table.id)):
			table.timer = 0
			roll(int(table.id))
	for table in tables:
		if not operating(table) or game_pending(table): continue
		table.service_minutes += 1
		if table.service_minutes >= CasinoTuning.REPAIR_GRACE_MINUTES and int(table.service_minutes) % CasinoTuning.REPAIR_CHECK_MINUTES == 0 and incidents.size() < 3:
			if rng.randf() < CasinoTuning.REPAIR_CHANCE:
				table.broken = true
				incidents.append({"type": "repair", "table": int(table.id), "title": "Table %d · worn rail" % table.id, "detail": "Wear has halted play. Repair the rail for $120."})
				log_event("Table %d halted: a worn rail needs repair." % table.id)
	if opened and unlocked("service") and not guests.is_empty() and elapsed % 70 == 0 and service_count == 0 and incidents.size() < 3:
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
		log_event(reason)
		return false
	var table := get_table(id)
	var amount := bet_amount(table, kind, chip)
	var placed := take_bet(table, {"bets": table.owner}, kind, amount, true)
	table.timer = 0.0 # Give the bettor a fresh window after changing a wager.
	log_event("%s: $%d added." % [CrapsRules.name_for(kind), amount])
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
	log_event("Returned $%d. Established Pass and Come contracts remain until resolved." % returned)

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
	if joined == int(table.id): log_event("Dice to %s." % shooter_name(table))

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
		log_event("Joined %s." % Games.NAMES[table_kind(table)])
		return true
	table.owner_queued = true
	table.betting_hold = false
	table.timer = 0.0
	if seated(id).is_empty() and int(table.hand_rolls) == 0:
		table.shooter = 0
		table.shooter_seat = 7
	else:
		ensure_shooter(table)
	log_event("Joined craps. %s has the dice; your bets share every roll." % shooter_name(table))
	return true

func leave_table() -> void:
	var table := get_table(joined)
	if not table.is_empty() and table_kind(table) != "craps":
		if game_pending(table):
			log_event("Finish your hand before leaving.")
			return
		clear_roulette(int(table.id))
		joined = -1
		return
	joined = -1
	if table.is_empty(): return
	table.owner_queued = false
	table.betting_hold = false
	ensure_shooter(table)
	log_event("Left the rail. CPU play continues and your outstanding bets stay live.")

func pass_dice(id: int) -> void:
	var table := get_table(id)
	if table.is_empty() or joined != id: return
	table.owner_queued = false
	if int(table.shooter) == 0: ensure_shooter(table, true)
	table.betting_hold = false
	table.timer = 0.0
	log_event("You passed the dice. %s will shoot; your bets remain live." % shooter_name(table))

func queue_for_dice(id: int) -> void:
	var table := get_table(id)
	if table.is_empty() or joined != id: return
	table.owner_queued = true
	log_event("You're in the shooter rotation. The current shooter keeps their hand.")

func shooter_has_line(table: Dictionary) -> bool:
	return not table.is_empty() and (float(table.owner.pass) > 0 or float(table.owner.dont_pass) > 0)

func shoot_player(id: int, forced: Array = []) -> bool:
	var table := get_table(id)
	if table.is_empty() or joined != id or int(table.shooter) != 0 or not ready_for_play(table): return false
	if not shooter_has_line(table):
		log_event("The shooter must have a Pass or Don’t Pass bet. Wait for come-out or pass the dice.")
		return false
	roll(id, forced)
	return true

func roll_interval(table: Dictionary, energy: float = 100.0) -> float:
	return (CasinoTuning.VISITOR_ROLL_SECONDS if joined == int(table.id) else CasinoTuning.ROLL_SECONDS) + (100 - energy) * 0.04

func roll(id: int, forced: Array = []) -> void:
	var table := get_table(id)
	if table.is_empty() or table.broken or crew(id).size() < required_crew(get_table(id)):
		return
	ensure_shooter(table)
	var rolled_by := shooter_name(table)
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
		if previous > 0: record_guest_round(guest)
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
	var result := CrapsRules.resolve(old_point, table.owner, int(dice[0]), int(dice[1]), bool(table.owner_working))
	table.owner = result.bets
	wallet += result.credit
	visitor_net += result.credit
	cash -= result.credit
	payouts += result.credit
	table.payouts += result.credit
	table.point = result.point
	table.result = result.message
	table.rolls += 1
	table.hand_rolls += 1
	table.timer = 0.0
	table.history.push_front({"a": int(dice[0]), "b": int(dice[1]), "total": int(result.total), "shooter": rolled_by, "seven_out": bool(result.seven_out), "point": int(result.point), "credit": float(result.credit)})
	if table.history.size() > 20: table.history.pop_back()
	if result.seven_out: ensure_shooter(table, true)
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
				table.service_minutes = 0
		else:
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

func operating_costs() -> float:
	return payroll + overhead

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
	return {"difficulty": difficulty, "starting_games": starting_games.duplicate(), "casino_rating": casino_rating, "guest_rounds": guest_rounds, "guest_revenue": guest_revenue, "ever_opened": ever_opened, "expanded": expanded, "vip_enabled": vip_enabled, "high_limit_enabled": high_limit_enabled, "version": CasinoTuning.SAVE_VERSION, "arrival_in": arrival_in, "cash": cash, "wallet": wallet, "revenue": revenue, "payouts": payouts, "payroll": payroll, "overhead": overhead, "visitor_net": visitor_net, "reputation": reputation, "minute": minute, "day": day, "elapsed": elapsed, "opened": opened, "tables": tables.duplicate(true), "guests": guests.duplicate(true), "staff": staff.duplicate(true), "alerts": alerts.duplicate(), "incidents": incidents.duplicate(true), "next_id": next_id, "joined": joined, "player": [player.x, player.y], "rng_state": str(rng.state)}

func restore(data: Dictionary) -> bool:
	if not valid_number(data.get("version")) or data.version != CasinoTuning.SAVE_VERSION:
		return false
	data = data.duplicate(true)
	# Validate the current schema before applying any state.
	for key in ["difficulty", "starting_games", "casino_rating", "guest_rounds", "guest_revenue", "ever_opened", "expanded", "vip_enabled", "high_limit_enabled", "arrival_in", "cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation", "minute", "day", "elapsed", "opened", "tables", "guests", "staff", "alerts", "incidents", "next_id", "joined", "player", "rng_state"]:
		if not data.has(key): return false
	if not data.difficulty is String or not CasinoTuning.DIFFICULTIES.has(data.difficulty): return false
	if not data.starting_games is Array or data.starting_games.size() > Games.NAMES.size(): return false
	for kind in data.starting_games:
		if not kind is String or not Games.NAMES.has(kind): return false
	for key in ["casino_rating", "guest_rounds", "guest_revenue"]:
		if not valid_number(data[key]) or float(data[key]) < 0: return false
	if float(data.casino_rating) > 100: return false
	for key in ["ever_opened", "expanded", "vip_enabled", "high_limit_enabled"]:
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
		for key in ["kind", "round", "roulette_bets"]:
			if not table.has(key): return false
		if not table.kind is String or not Games.NAMES.has(table.kind): return false
		if not table.round is Dictionary or not table.roulette_bets is Dictionary: return false
		if not Games.valid_round(table.round, str(table.kind)): return false
		var roulette_options := Games.roulette_bets()
		for name in table.roulette_bets:
			if not roulette_options.has(name) or not valid_number(table.roulette_bets[name]) or float(table.roulette_bets[name]) < 0: return false
		for key in ["id", "x", "y", "rotated", "point", "dice", "timer", "wagers", "payouts", "broken", "rolls", "minimum", "owner", "result", "shooter", "shooter_seat", "hand_rolls", "owner_queued", "betting_hold", "owner_working", "history", "service_minutes"]:
			if not table.has(key):
				return false
		for key in ["id", "x", "y", "point", "timer", "wagers", "payouts", "rolls", "minimum", "shooter", "shooter_seat", "hand_rolls", "service_minutes"]:
			if not valid_number(table[key]):
				return false
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
		if float(table.minimum) not in [5.0, 10.0, 25.0, 50.0] or not Rect2(65, 100, 720, 400).encloses(bounds(table)):
			return false
	if int(data.joined) != -1 and int(data.joined) not in ids:
		return false
	for guest in data.guests:
		if not guest is Dictionary:
			return false
		for key in ["id", "name", "x", "y", "tx", "ty", "table", "seat", "state", "wallet", "start", "satisfaction", "thirst", "age", "patience", "vip", "bets", "thought", "preference", "watch_left", "watch_style"]:
			if not guest.has(key):
				return false
		for key in ["id", "x", "y", "tx", "ty", "table", "seat", "wallet", "start", "satisfaction", "thirst", "age", "patience"]:
			if not valid_number(guest[key]):
				return false
		if not guest.preference is String or not Games.NAMES.has(guest.preference): return false
		if float(guest.wallet) < 0 or not valid_bets(guest.bets) or not guest.vip is bool:
			return false
		if int(guest.table) != -1 and int(guest.table) not in ids:
			return false
		if guest.state in ["Walking", "Playing"] and (int(guest.table) < 1 or int(guest.seat) not in range(7)):
			return false
		if guest.state not in ["Arriving", "Waiting", "Walking", "Playing", "Browsing", "Watching", "To cage", "Cashing out", "Leaving"] or not guest.name is String or not guest.thought is String:
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
	for key in ["cash", "wallet", "revenue", "payouts", "payroll", "overhead", "visitor_net", "reputation"]:
		set(key, float(data[key]))
	for key in ["minute", "day", "elapsed", "next_id", "joined"]:
		set(key, int(data[key]))
	difficulty = str(data.difficulty)
	starting_games = data.starting_games.duplicate()
	casino_rating = float(data.casino_rating)
	guest_rounds = int(data.guest_rounds)
	guest_revenue = float(data.guest_revenue)
	for key in ["ever_opened", "expanded", "vip_enabled", "high_limit_enabled"]: set(key, bool(data[key]))
	cashout_effects.clear()
	arrival_in = int(data.arrival_in)
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

func game_debit(table: Dictionary, amount: float, guest: Dictionary = {}) -> bool:
	var funds: float = wallet if guest.is_empty() else guest.wallet
	if amount < 0 or funds < amount: return false
	if guest.is_empty():
		wallet -= amount
		visitor_net -= amount
	else:
		guest.wallet -= amount
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
	for npc in round.get("npcs", []):
		for guest in guests:
			if int(guest.id) == int(npc.id):
				game_credit(table, float(npc.returned), guest)
				record_guest_round(guest)
				guest.thought = "Our dealer paid my win!" if npc.returned > npc.staked else "Next hand, please."
	table.result = round.message
	table.rolls += 1
	log_event("%s: %s" % [Games.NAMES[table_kind(table)], round.message])

func start_game(id: int, bet: float, trips: float = 0) -> bool:
	var table := get_table(id)
	if joined != id or not ready_for_play(table) or game_pending(table): return false
	var kind := table_kind(table)
	if kind == "craps" or bet < table.minimum or trips < 0: return false
	var cost := bet * 2 + trips if kind == "holdem" else bet
	if kind == "roulette":
		cost = 0
		for amount in table.roulette_bets.values(): cost += float(amount)
		if cost <= 0: return false
	else:
		if kind == "holdem" and wallet < bet * 6 + trips:
			log_event("Hold’em needs enough for Ante, Blind and a 4× raise ($%d)." % (bet * 6 + trips))
			return false
		if not game_debit(table, cost): return false
	var participants: Array = []
	if opened and kind in ["blackjack", "holdem"]:
		for guest in seated(id):
			var stake := float(table.minimum) * (2 if guest.vip else 1)
			if guest.wallet >= stake * (3 if kind == "holdem" else 1): participants.append({"id": guest.id, "name": guest.name, "bet": stake})
	match kind:
		"slots": table.round = Games.spin_slots(bet, rng)
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
	if table.is_empty() or table_kind(table) != "roulette" or joined != id or not ready_for_play(table) or not Games.roulette_bets().has(name) or amount < table.minimum: return false
	if not game_debit(table, amount): return false
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
		table.rolls += 1
		return
	for guest in seated(int(table.id)):
		var bet := float(table.minimum) * (2 if guest.vip else 1)
		var kind := table_kind(table)
		if guest.wallet < bet * (6 if kind == "holdem" else 1):
			leave(guest, "Time to cash out.")
			continue
		var cost := bet * 2 if kind == "holdem" else bet
		game_debit(table, cost, guest)
		var round := {}
		match kind:
			"slots": round = Games.spin_slots(bet, rng)
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
			game_debit(table, float(options[action]), guest)
			Games.act(round, action)
		game_credit(table, float(round.credit), guest)
		record_guest_round(guest)
		table.rolls += 1
		table.result = "%s · %s" % [guest.name, round.message]
		guest.thought = "A win!" if round.credit > cost else "One more round?"
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
		var stake := float(table.minimum) * (2 if guest.vip else 1)
		if not game_debit(table, stake, guest): continue
		var result := Games.spin_roulette({"Red" if int(guest.id) % 2 else "Black": stake}, rng, number)
		game_credit(table, result.credit, guest)
		record_guest_round(guest)
		guest.thought = "Our wheel hit %d!" % number
