extends RefCounted
# Disposable, seeded stress state; never used by production progression.
static func create(scale: String) -> CasinoSimulation:
	var sim := CasinoSimulation.new("easy", ["slots"])
	sim.rng.seed = 42042
	sim.cash = 10000000
	sim.tables.clear()
	sim.staff.clear()
	sim.floor_chunks = {"left": 0, "right": 4, "bottom": 4}
	var count: int = {"small": 2, "medium": 24, "large": 80}[scale]
	for i in range(count):
		var kind := "blackjack" if i % 4 == 3 else "slots"
		var table := sim.new_table(Vector2(50 + (i % 10) * 200, 150 + (i / 10) * 180), false, kind)
		sim.tables.append(table)
		for j in range(sim.required_crew(table)):
			sim.staff.append(CasinoSimulation.Staffing.new_employee(sim, "Dealer", int(table.id)))
	sim.service_positions = 4 if scale != "small" else 0
	for i in range(sim.service_positions * 2): sim.staff.append(CasinoSimulation.Staffing.new_employee(sim, "Service"))
	sim.opened = true
	sim.reputation = 85
	sim.refresh_progression()
	if scale != "small": sim.set_drink_menu("basic", true)
	var population: int = {"small": 2, "medium": 32, "large": 100}[scale]
	for i in range(population):
		sim.spawn_guest()
		var guest: Dictionary = sim.guests.back()
		var table: Dictionary = sim.tables[i % count]
		guest.table = table.id
		guest.state = "Playing"
		guest.seat = i / count + 1
		guest.x = table.x - 15
		guest.y = table.y + 30
		guest.wallet = 1000.0
		guest.start = 1000.0
		guest.session_left = 500
	return sim
