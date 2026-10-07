extends SceneTree
# Focused reputation investigation. No gambling probabilities or settlements mocked.
# Run: Godot --headless --path casino-godot --script res://tests/test_reputation.gd
var failures := 0
var checks := 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + message)

func fresh(seed_value: int = 321) -> CasinoSimulation:
	var sim := CasinoSimulation.new("normal")
	sim.rng.seed = seed_value
	sim.optional_events.rng.seed = seed_value
	sim.set_open(true)
	return sim

func advance(sim: CasinoSimulation, minutes: int, repair: bool = false) -> void:
	# Same 0.1-second movement slices and minute steps as developer 1000x.
	for minute_index in range(minutes):
		for substep in range(10): sim.move_guests(0.1)
		sim.step()
		if repair:
			for index in range(sim.incidents.size() - 1, -1, -1):
				if sim.incidents[index].type == "repair": sim.resolve_incident(index, true)

func place_slot(sim: CasinoSimulation, profile: String) -> bool:
	var area := sim.placement_area("slots")
	for y in range(ceili(area.position.y), floori(area.end.y), 20):
		for x in range(ceili(area.position.x), floori(area.end.x), 20):
			if sim.can_place(Vector2(x, y), false, -1, "slots"):
				return sim.place(Vector2(x, y), false, "slots", profile) > 0
	return false

func queue_visit(sim: CasinoSimulation) -> Dictionary:
	sim.spawn_guest()
	var guest: Dictionary = sim.guests.back()
	guest.state = "Waiting"
	guest.patience = 20
	for minute_index in range(32):
		sim.elapsed += 1
		if minute_index % 4 == 0: sim.mark_unmet_demand(guest)
		if sim.demand_wait_step(guest): break
	return guest

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in [321, 17, 2026]:
		var sim := fresh(seed_value)
		for day_index in range(5):
			advance(sim, 1440, true)
			check(sim.recent_reputation_losses.is_empty(), "Competent starter has no reputation losses: seed %d day %d" % [seed_value, day_index + 1])
		check(sim.reputation > 60 and sim.guest_rounds > 0, "Real happy visits gradually improve reputation")
		check(sim.tables.size() == 2 and not sim.bar_owned and sim.staff.is_empty(), "Fresh Normal offering unchanged")
		var restored := CasinoSimulation.new()
		check(restored.restore(JSON.parse_string(JSON.stringify(sim.snapshot()))), "Current-version reputation/guest save restores")
		print("STARTER_RESULT ", JSON.stringify({"seed": seed_value, "days": 5, "reputation": sim.reputation, "cash": sim.cash, "guest_rounds": sim.guest_rounds, "losses": sim.recent_reputation_losses.size()}))

	var sim := fresh()
	sim.spawn_guest()
	var guest: Dictionary = sim.guests.back()
	guest.preference = "blackjack"
	check(sim.guest_current_interest(guest) == "slots", "Arrival expectations match owned games")
	guest.rounds = 10
	guest.wallet = 0
	guest.state = "Waiting"
	guest.demand_blocked = true
	guest.demand_wait = 100
	guest.demand_attempts = 20
	sim.choose_table(guest)
	check(sim.traffic_totals.severe_departures == 0 and sim.recent_reputation_losses.is_empty(), "Gambling down bankroll is not a failed experience")
	check(guest.state == "To cage", "Bankroll-depleted gambler exits normally")

	sim = fresh()
	sim.spawn_guest()
	guest = sim.guests.back()
	sim.mark_unmet_demand(guest)
	guest.demand_wait = 30
	guest.demand_failure_wait = 20
	guest.demand_attempts = 6
	sim.choose_table(guest, false)
	check(not guest.demand_blocked and guest.demand_wait == 0 and guest.demand_failure_wait == 0 and guest.demand_attempts == 0, "Getting a seat resets the current queue budget")
	sim.mark_unmet_demand(guest)
	check(sim.traffic_totals.unmet_visits == 1, "Repeated queue sessions count one unmet visit")

	sim = fresh()
	for table in sim.tables:
		sim.spawn_guest()
		var occupant: Dictionary = sim.guests.back()
		occupant.state = "Playing"
		occupant.table = table.id
		occupant.seat = 0
	guest = queue_visit(sim)
	check(guest.satisfaction == 80 and sim.traffic_totals.severe_departures == 0, "Busy starter queue stays neutral and bounded")
	check(guest.state == "Leaving", "Neutral queue does not trap guests")

	sim = fresh()
	for table in sim.tables: table.broken = true
	advance(sim, 1440)
	check(sim.reputation < 60 and not sim.recent_reputation_losses.is_empty(), "Unrepaired starter equipment can reduce reputation")
	var event: Dictionary = sim.recent_reputation_losses.back()
	for key in ["source", "guest_id", "guest_satisfaction", "guest_state", "departure_reason", "desired_game", "available_games", "affordable_games", "occupied_capacity", "reputation_before", "delta", "reputation_after"]:
		check(event.has(key), "Loss diagnostic includes " + key)
	check(event.guest_state not in ["To cage", "Leaving"], "Diagnostics capture state before releasing guest")
	print("BROKEN_RESULT ", JSON.stringify({"reputation": sim.reputation, "losses": sim.recent_reputation_losses.size()}))

	# A developed, crowded property can reasonably add another funded seat.
	sim = fresh()
	sim.cash = 30000
	sim.debug_forced_unlocks.append("slot:standard")
	check(place_slot(sim, "standard"), "Prepare real developed capacity")
	for table in sim.tables:
		sim.spawn_guest()
		var occupant: Dictionary = sim.guests.back()
		occupant.state = "Playing"
		occupant.table = table.id
		occupant.seat = 0
	check(sim.capacity_expansion_reasonable(), "Developed floor has reserves and room to expand")
	for index in range(3): queue_visit(sim)
	check(sim.reputation < 60, "Repeated preventable developed-capacity failures reduce reputation")
	sim.cash = 500
	check(not sim.capacity_expansion_reasonable(), "Thin reserves do not force expansion")
	guest = queue_visit(sim)
	check(guest.satisfaction == 80, "Guests tolerate crowding when expansion is not reasonably funded")

	# Owned table coverage failure is actionable even without optional amenities.
	sim = CasinoSimulation.new("easy", ["blackjack"])
	sim.set_open(true)
	sim.tables[0].staff_enabled = false
	for index in range(3): queue_visit(sim)
	check(sim.reputation < 60, "Preventable table coverage failure reduces reputation")

	sim = fresh()
	sim.spawn_guest()
	guest = sim.guests.back()
	# A guest at the neutral review threshold suffers a real service failure.
	guest.satisfaction = 65.0
	sim.DrinkService.fail(sim, guest, "Blocked bar route")
	sim.leave(guest, "Service failed.")
	check(sim.reputation < 60 and sim.recent_reputation_losses.back().source == "guest.visit_review", "Actual drink-service failure remains accountable")
	sim.incidents.append({"type": "service", "table": -1, "title": "Unresolved service complaint", "detail": ""})
	sim.resolve_incident(sim.incidents.size() - 1, false)
	check(sim.recent_reputation_losses.back().source == "incident.dismissed_complaint", "Dismissed complaints use centralized diagnostics")
	check(sim.optional_events.spawn(sim, "management_sample", true), "Prepare developer management event")
	var optional_id: int = sim.optional_events.active.back().id
	sim.optional_events.resolve(sim, optional_id, "expired")
	check(sim.recent_reputation_losses.back().source == "optional_event.management_sample.expired", "Event penalties use centralized diagnostics")

	print("Reputation checks: %d; failures: %d" % [checks, failures])
	quit(1 if failures else 0)
