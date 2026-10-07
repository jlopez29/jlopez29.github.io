extends SceneTree
# Focused real-simulation service regressions; run with Godot --headless --script.
var checks := 0
var failures := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func fixture(employees: int = 0) -> CasinoSimulation:
	var sim := CasinoSimulation.new("easy", ["slots"])
	sim.rng.seed = 321
	sim.purchase_bar()
	for index in range(employees): sim.hire("Service", -1)
	sim.set_open(true)
	sim.arrival_in = 10000
	sim.spawn_guest()
	var guest: Dictionary = sim.guests.back()
	guest.state = "Waiting"
	guest.decision_at = 10000
	guest.satisfaction = 65.0
	guest.thirst = 30.0
	guest.wallet = 1000.0
	guest.start = 1000.0
	return sim

func advance(sim: CasinoSimulation, minutes: int, speed: int = 1) -> void:
	# Same simulation time, different frame grouping at supported speeds.
	for minute_index in range(minutes):
		sim.step()
		for frame in range(20 / speed): sim.move_guests(0.05 * speed)

func gambler(sim: CasinoSimulation) -> Dictionary:
	var guest: Dictionary = sim.guests[0]
	var table: Dictionary = sim.tables[0]
	guest.state = "Playing"
	guest.table = table.id
	guest.seat = 0
	guest.session_left = 500
	var seat: Vector2 = sim.guest_seat_position(table, 0)
	guest.x = seat.x
	guest.y = seat.y
	return guest

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for speed in [1, 2, 4]:
		var sim := fixture()
		var guest: Dictionary = sim.guests[0]
		var reputation := sim.reputation
		sim.step()
		check(guest.state == "To bar" and guest.drink_state == "SEEKING_SERVICE", "Thirst starts counter trip at %dx" % speed)
		check(guest.satisfaction == 65.0 and sim.reputation == reputation, "Travel need is neutral")
		var restored := CasinoSimulation.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Save/load traveling request")
		advance(sim, 12, speed)
		check(guest.drink_state == "FULFILLED" and guest.thirst < CasinoTuning.DRINK_THIRST_TRIGGER, "Counter delivers without floor employees at %dx" % speed)
		check(sim.bar_totals.sold == 1 and guest.drink_spending > 0, "Counter uses real purchase")
		check(sim.reputation >= reputation and guest.drink_failure == "", "Normal need never hurts reputation")
		check(guest.bar_slot == -1 and guest.state not in ["To bar", "At bar"], "Resumes casino behavior and frees counter slot")
		for count in [1, 4]:
			sim = fixture(count)
			guest = gambler(sim)
			advance(sim, 1, speed)
			check(guest.drink_state == "SERVICE_ASSIGNED", "Active employee claims request with %d hires" % count)
			restored = CasinoSimulation.new()
			check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Save/load assigned floor request")
			advance(restored, 12, speed)
			check(restored.guests[0].drink_state == "FULFILLED", "Loaded request completes")
			advance(sim, 12, speed)
			check(guest.drink_state == "FULFILLED" and guest.state == "Playing", "Floor delivery retains gambling activity")
			check(not sim.staff.any(func(e): return int(e.get("service_target", -1)) == int(guest.id)), "Completed delivery clears assignment")
	var sim := fixture(4)
	var guest := gambler(sim)
	advance(sim, 1)
	var active: Dictionary = sim.staff.filter(func(e): return e.duty == "Active")[0]
	sim.Staffing.request_rest(sim, active, "Break")
	check(active.duty == "Break" and int(active.service_target) == -1 and guest.drink_state == "WAITING_FOR_SERVICE", "Break releases claim to relief coverage")
	advance(sim, 12)
	check(guest.drink_state == "FULFILLED", "Relief completes interrupted request")
	sim = fixture(1)
	guest = gambler(sim)
	advance(sim, 1)
	sim.leave(guest, "Time to cash out.")
	check(guest.drink_order == "" and not sim.staff.any(func(e): return int(e.get("service_target", -1)) == int(guest.id)), "Departure clears order and employee")
	sim = fixture(1)
	guest = gambler(sim)
	advance(sim, 1)
	sim.start_guest_exploration(guest)
	check(guest.drink_order == "" and not sim.staff.any(func(e): return int(e.get("service_target", -1)) == int(guest.id)), "Activity change clears delivery")
	sim = fixture()
	guest = gambler(sim)
	advance(sim, 14)
	check(guest.state in ["To bar", "At bar"] or guest.drink_state == "FULFILLED", "No floor employee falls back to counter")
	sim = fixture()
	guest = sim.guests[0]
	sim.step()
	var before: float = guest.satisfaction
	# Stop movement deliberately to create a genuine failed attempt.
	for minute_index in range(CasinoTuning.DRINK_SERVICE_TIMEOUT_MINUTES):
		sim.elapsed += 1
		sim.DrinkService.tick(sim, guest)
	check(guest.drink_state == "SERVICE_FAILED" and guest.drink_failure == "Drink service timed out", "Excessive travel fails traceably")
	check(is_equal_approx(before - guest.satisfaction, CasinoTuning.DRINK_FAILURE_SATISFACTION_LOSS * float(sim.archetype(guest).service_expectation)), "Failure applies one bounded loss")
	before = guest.satisfaction
	sim.DrinkService.tick(sim, guest)
	check(guest.satisfaction == before, "Failure cannot stack on next tick")
	guest.satisfaction = 20
	sim.leave(guest, sim.guest_exit_reason(guest))
	check(sim.traffic_totals.departures.service == 1, "Failed service departure is attributed")
	for closure in [false, true]:
		sim = fixture()
		guest = sim.guests[0]
		sim.step()
		if closure: sim.set_open(false)
		else: sim.bar_owned = false
		sim.step()
		check(guest.bar_slot == -1 and guest.drink_order == "", "Bar/casino closure frees counter reservation")
	sim = fixture()
	guest = sim.guests[0]
	sim.step()
	guest.bar_slot = -1
	sim.step()
	check(guest.drink_failure == "Bar position became unavailable" and guest.drink_order == "", "Invalid counter position fails and clears")
	# One busy employee cannot trap another gambler in an unclaimed request.
	sim = fixture(1)
	guest = gambler(sim)
	guest.thirst = 50
	sim.tables.append(sim.new_table(Vector2(650, 350), false, "slots", "starter"))
	sim.spawn_guest()
	var waiting: Dictionary = sim.guests.back()
	waiting.state = "Playing"
	waiting.table = sim.tables.back().id
	waiting.seat = 0
	waiting.session_left = 500
	waiting.thirst = 30
	waiting.wallet = 1000
	waiting.start = 1000
	var position: Vector2 = sim.guest_seat_position(sim.tables.back(), 0)
	waiting.x = position.x
	waiting.y = position.y
	advance(sim, 1)
	active = sim.staff.filter(func(e): return e.duty == "Active")[0]
	active.service_wait = 30.0
	check(guest.drink_state == "SERVICE_ASSIGNED" and waiting.drink_state == "WAITING_FOR_SERVICE", "Busy employee leaves second request unclaimed")
	advance(sim, 13)
	check(waiting.state in ["To bar", "At bar"] or waiting.drink_state == "FULFILLED", "All floor staff busy permits counter fallback")
	# Keep every counter position reserved, then check grace and one loss budget.
	sim = fixture()
	guest = gambler(sim)
	for slot in range(CasinoTuning.BAR_GUEST_OFFSETS.size()):
		sim.spawn_guest()
		var patron: Dictionary = sim.guests.back()
		patron.state = "At bar"
		patron.bar_slot = slot
		patron.decision_at = 10000
	sim.step()
	before = guest.satisfaction
	for minute_index in range(CasinoTuning.DRINK_WAIT_GRACE_MINUTES - 1):
		sim.elapsed += 1
		sim.DrinkService.tick(sim, guest)
	check(guest.satisfaction == before, "Legitimate waiting receives full grace")
	for minute_index in range(CasinoTuning.DRINK_SERVICE_TIMEOUT_MINUTES - CasinoTuning.DRINK_WAIT_GRACE_MINUTES + 1):
		sim.elapsed += 1
		sim.DrinkService.tick(sim, guest)
	check(guest.drink_state == "SERVICE_FAILED" and guest.drink_order == "", "Excessive unresolved wait fails and clears order")
	check(is_equal_approx(before - guest.satisfaction, CasinoTuning.DRINK_FAILURE_SATISFACTION_LOSS * float(sim.archetype(guest).service_expectation)), "Wait and failure share one dissatisfaction budget")
	# Closure/menu change releases an in-flight delivery immediately.
	for remove_menu in [false, true]:
		sim = fixture(1)
		guest = gambler(sim)
		advance(sim, 1)
		if remove_menu: sim.set_drink_menu(str(guest.drink_order), false)
		else: sim.set_open(false)
		check(guest.drink_order == "" and not sim.staff.any(func(e): return int(e.get("service_target", -1)) == int(guest.id)), "Closure/menu removal releases active delivery")
	# Save timed counter preparation, then finish it through the normal movement loop.
	sim = fixture()
	guest = sim.guests[0]
	sim.start_guest_bar(guest)
	position = sim.bar_guest_position(int(guest.bar_slot))
	guest.x = position.x
	guest.y = position.y
	guest.state = "At bar"
	sim.step()
	sim.move_guests(0.1)
	var restored := CasinoSimulation.new()
	check(guest.drink_prep_left > 0 and restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Counter preparation survives save/load")
	advance(restored, 5)
	check(restored.guests[0].drink_state == "FULFILLED", "Loaded counter preparation completes")
	sim = fixture(1)
	guest = gambler(sim)
	advance(sim, 1)
	var bad: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot()))
	bad.staff[0].service_target = 99999
	check(not restored.restore(bad), "Corrupt stale delivery target is rejected")
	# Every employee marked Active can claim a distinct request.
	sim = fixture(4)
	sim.set_service_positions(4)
	guest = gambler(sim)
	for index in range(3):
		sim.tables.append(sim.new_table(Vector2(600 + index * 100, 350), false, "slots", "starter"))
		sim.spawn_guest()
		var player: Dictionary = sim.guests.back()
		player.state = "Playing"
		player.table = sim.tables.back().id
		player.seat = 0
		player.session_left = 500
		player.thirst = 30
		player.wallet = 1000
		player.start = 1000
		position = sim.guest_seat_position(sim.tables.back(), 0)
		player.x = position.x
		player.y = position.y
	advance(sim, 1)
	check(sim.staff.all(func(e): return e.duty == "Active" and int(e.get("service_target", -1)) > 0), "All four Active employees can claim requests")
	# Break recovery and unpaid reserves use the existing roster lifecycle.
	sim = fixture(4)
	active = sim.staff.filter(func(e): return e.duty == "Active")[0]
	sim.staff_rest(active)
	active.energy = CasinoTuning.STAFF_RETURN_ENERGY
	sim.elapsed = int(active.state_since) + CasinoTuning.STAFF_BREAK_MINUTES
	sim.Staffing.tick(sim)
	check(active.duty in ["Relief", "Active"], "Recovered employee returns to usable roster")
	var reserve: Dictionary = sim.staff.filter(func(e): return e.duty == "Off Duty")[0]
	sim.elapsed = int(reserve.available_at)
	sim.Staffing.start_shift(sim, reserve)
	sim.set_service_positions(4)
	check(reserve.duty == "Active", "Recovered Off Duty reserve fills an active position")
	print("Drink service: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
