extends RefCounted
# One drink attempt owns waiting, failure and assignment cleanup. Counter service
# is part of the purchased bar; floor employees provide delivery convenience.
const STATES := ["NEED", "SEEKING_SERVICE", "WAITING_FOR_SERVICE", "SERVICE_ASSIGNED", "FULFILLED", "SERVICE_FAILED"]

static func initialize(guest: Dictionary, now: int) -> void:
	guest.merge({"drink_state": "FULFILLED", "drink_since": now, "drink_attempt_at": -1,
		"drink_wait_loss": 0.0, "drink_wait_minutes": 0, "drink_failure": "", "drink_prep_left": -1.0}, true)

static func transition(sim, guest: Dictionary, state: String) -> void:
	if guest.drink_state == state: return
	guest.drink_state = state
	guest.drink_since = sim.elapsed
	var thoughts := {"NEED": "I could use a drink.", "SEEKING_SERVICE": "Heading to the bar.",
		"WAITING_FOR_SERVICE": "Getting a drink.", "SERVICE_ASSIGNED": "Drink's on the way!",
		"FULFILLED": "Perfect!", "SERVICE_FAILED": "Where's my drink?"}
	sim.think(guest, thoughts[state], 2)

static func begin(sim, guest: Dictionary) -> void:
	if int(guest.drink_attempt_at) >= 0: return
	guest.drink_attempt_at = sim.elapsed
	guest.drink_wait_loss = 0.0
	guest.drink_wait_minutes = 0
	guest.drink_failure = ""

static func release_assignment(sim, guest: Dictionary) -> void:
	for employee in sim.staff:
		if employee.role == "Service" and int(employee.get("service_target", -1)) == int(guest.id):
			employee.service_target = -1
			employee.service_product = ""
			employee.service_wait = 0.0
			if employee.has("x"):
				sim.send_to_bar(employee)
			else:
				employee.erase("service_state")
				employee.erase("path")
	guest.drink_prep_left = -1.0

static func fail(sim, guest: Dictionary, cause: String) -> void:
	if guest.drink_state == "SERVICE_FAILED": return
	sim.Bar.cancel_order(sim, guest)
	guest.drink_failure = cause
	var loss: float = maxf(0, CasinoTuning.DRINK_FAILURE_SATISFACTION_LOSS - float(guest.drink_wait_loss))
	guest.satisfaction = maxf(0, float(guest.satisfaction) - loss * float(sim.archetype(guest).service_expectation))
	transition(sim, guest, "SERVICE_FAILED")
	if sim.incidents.size() < 3 and not sim.incidents.any(func(item): return item.type == "service"):
		sim.incidents.append({"type": "service", "table": -1, "title": "Drink service failure",
			"detail": "%s. Check menu, counter access and floor delivery coverage." % cause})
		sim.log_event("SERVICE - Drink request failed: %s." % cause.to_lower())
	# The failure is retained until fulfilled, so departure attribution is traceable.

static func can_leave_activity(sim, guest: Dictionary) -> bool:
	return CrapsRules.exposure(guest.bets) <= 0 and not sim.game_pending(sim.get_table(int(guest.table)))

static func valid_slot(sim, guest: Dictionary) -> bool:
	var slot: int = int(guest.bar_slot)
	if slot < 0 or slot >= CasinoTuning.BAR_GUEST_OFFSETS.size(): return false
	var position: Vector2 = sim.bar_guest_position(slot)
	return not sim.tables.any(func(table): return sim.bounds(table).grow(16).has_point(position))

static func tick(sim, guest: Dictionary) -> void:
	if not sim.opened or guest.state in ["To cage", "Cashing out", "Leaving"]:
		sim.Bar.cancel_order(sim, guest)
		return
	if guest.thirst < CasinoTuning.DRINK_THIRST_TRIGGER: return
	if guest.drink_state == "FULFILLED": transition(sim, guest, "NEED")
	if guest.drink_state == "SERVICE_FAILED":
		if sim.elapsed - int(guest.drink_since) < CasinoTuning.DRINK_ORDER_RETRY_MINUTES: return
		guest.drink_attempt_at = -1
		transition(sim, guest, "NEED")
	if sim.bar_available() and sim.drink_menu.is_empty():
		begin(sim, guest)
		fail(sim, guest, "Bar menu unavailable")
		return
	if not sim.bar_available():
		if int(guest.drink_attempt_at) >= 0: fail(sim, guest, "Bar became unavailable")
		return
	if guest.state in ["To bar", "At bar"]:
		begin(sim, guest)
		if not valid_slot(sim, guest):
			fail(sim, guest, "Bar position became unavailable")
			sim.start_guest_exploration(guest)
			return
		transition(sim, guest, "SEEKING_SERVICE" if guest.state == "To bar" else "WAITING_FOR_SERVICE")
	else:
		if guest.drink_order != "" and not sim.wants_drink(guest): sim.Bar.cancel_order(sim, guest)
		if guest.drink_state == "SERVICE_ASSIGNED" and not sim.staff.any(func(e): return e.role == "Service" and e.duty == "Active" and int(e.get("service_target", -1)) == int(guest.id)):
			transition(sim, guest, "WAITING_FOR_SERVICE")
		if guest.state != "Playing" or (guest.drink_state != "SERVICE_ASSIGNED" and int(guest.drink_attempt_at) >= 0 and sim.elapsed - int(guest.drink_attempt_at) >= CasinoTuning.DRINK_FLOOR_FALLBACK_MINUTES):
			if can_leave_activity(sim, guest):
				begin(sim, guest)
				if sim.start_guest_bar(guest): return
	var request_ready: bool = sim.elapsed >= int(guest.drink_request_at)
	sim.Bar.request(sim, guest)
	if guest.drink_order != "":
		begin(sim, guest)
		if guest.drink_state not in ["SEEKING_SERVICE", "SERVICE_ASSIGNED"]: transition(sim, guest, "WAITING_FOR_SERVICE")
	elif request_ready and int(guest.drink_attempt_at) >= 0 and guest.state == "At bar":
		fail(sim, guest, "No acceptable drink available")
		return
	if int(guest.drink_attempt_at) < 0: return
	var waited: int = sim.elapsed - int(guest.drink_attempt_at)
	if waited >= CasinoTuning.DRINK_SERVICE_TIMEOUT_MINUTES:
		fail(sim, guest, "Drink service timed out")
		return
	if guest.drink_state != "SEEKING_SERVICE": guest.drink_wait_minutes += 1
	if guest.drink_wait_minutes > CasinoTuning.DRINK_WAIT_GRACE_MINUTES and guest.drink_state != "SEEKING_SERVICE":
		var loss: float = minf(CasinoTuning.DRINK_WAIT_SATISFACTION_LOSS, maxf(0, CasinoTuning.DRINK_WAIT_LOSS_CAP - float(guest.drink_wait_loss)))
		if loss > 0: guest.drink_failure = "Excessive drink wait"
		guest.drink_wait_loss += loss
		guest.satisfaction = maxf(0, float(guest.satisfaction) - loss * float(sim.archetype(guest).service_expectation))
		sim.think(guest, "Where's my drink?", 2)

static func move_counter(sim, delta: float) -> void:
	for guest in sim.guests:
		if guest.state != "At bar" or guest.drink_state != "WAITING_FOR_SERVICE": continue
		if not sim.wants_drink(guest) or not valid_slot(sim, guest): continue
		if guest.drink_prep_left < 0:
			guest.drink_prep_left = float(CasinoTuning.DRINK_PROFILES[str(guest.drink_order)].prep_minutes)
		guest.drink_prep_left = maxf(0, float(guest.drink_prep_left) - delta)
		if guest.drink_prep_left <= 0: sim.deliver_drink(guest, {})

static func valid_guest(sim, guest: Dictionary, now: float) -> bool:
	if guest.get("drink_state") not in STATES or not guest.get("drink_failure") is String: return false
	for key in ["drink_since", "drink_attempt_at", "drink_wait_loss", "drink_wait_minutes", "drink_prep_left"]:
		if not sim.valid_number(guest.get(key)): return false
	if guest.drink_since < 0 or guest.drink_since > now or guest.drink_attempt_at < -1 or guest.drink_attempt_at > now or guest.drink_wait_loss < 0 or guest.drink_wait_minutes < 0 or guest.drink_prep_left < -1: return false
	if guest.drink_state == "SEEKING_SERVICE" and guest.state != "To bar": return false
	if guest.drink_state == "SERVICE_ASSIGNED" and (guest.state != "Playing" or guest.drink_order == ""): return false
	return true
