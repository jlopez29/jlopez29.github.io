extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
var checks := 0
var failures := 0

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func break_game(sim, index: int) -> void:
	var table: Dictionary = sim.tables[index]
	table.broken = true
	sim.incidents.append({"type": "repair", "table": int(table.id), "title": "Broken slot", "detail": "Needs repair"})

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var sim = Sim.new("normal")
	var before: float = sim.cash
	check(sim.hire("Tech", -1), "Tech hiring available immediately")
	check(sim.cash == before - CasinoTuning.HIRING_COST, "Training charged once")
	var tech: Dictionary = sim.staff[0]
	check(tech.duty == "On Call" and tech.table == -1, "Tech starts on call without a floor position")
	check(sim.payroll_rate() == 0 and sim.planned_payroll_rate() == 0, "On-call Tech has no idle payroll")
	check(sim.staffing_summary("Tech").coverage == "GOOD COVERAGE", "One Tech gives full coverage for starting games")
	sim.step()
	check(sim.expense_totals.tech_payroll == 0, "Actual idle minute charges no Tech payroll")
	for i in range(500):
		sim.elapsed += 1
		sim.Staffing.tick(sim)
	check(tech.duty == "On Call" and tech.energy == 100, "On-call roster bypasses shift expiry and fatigue")
	check(Sim.new("normal").restore(sim.snapshot()), "Idle roster persists")
	break_game(sim, 0)
	break_game(sim, 1)
	sim.TechService.tick(sim)
	check(tech.duty == "Repairing" and tech.repair_target == sim.tables[0].id, "Breakdown calls Tech for oldest job")
	check(sim.payroll_rate() == CasinoTuning.TECH_WAGE, "Repair call is paid")
	var restored = Sim.new("normal")
	check(restored.restore(sim.snapshot()), "Dispatched repair persists")
	var restored_tech: Dictionary = restored.staff[0]
	restored.move_guests(1)
	check(Vector2(restored_tech.x, restored_tech.y).distance_to(Vector2(restored_tech.tx, restored_tech.ty)) <= 6, "Tech reaches repair within one game minute")
	before = restored.cash
	restored.step()
	check(not restored.tables[0].broken and restored.tables[1].broken, "One call repairs one game")
	check(is_equal_approx(restored.expense_totals.tech_payroll, CasinoTuning.TECH_WAGE / 60.0) and restored.expense_totals.repairs == restored.repair_cost(restored.tables[0]), "Parts and actual call wage charged once")
	check(restored_tech.duty == "On Call" and restored.payroll_rate() == 0, "Finished Tech returns to unpaid availability")
	check(restored.tables[0].repairs == 1 and restored.incidents.size() == 1, "Shared incident settlement updates accounting")
	restored.cash = 0
	for i in range(10): restored.TechService.tick(restored)
	check(restored_tech.duty == "On Call" and restored.tables[1].broken, "Unfunded repair stays queued without idle call wages")
	check(Sim.new("normal").restore(restored.snapshot()), "Unfunded queue persists")
	restored.cash = 1000
	restored.TechService.tick(restored)
	restored.move_guests(1)
	restored.TechService.tick(restored)
	check(not restored.tables[1].broken and restored.incidents.is_empty(), "Funded repair resumes automatically")
	check(restored.expense_totals.service_payroll == 0, "Tech wages never inflate bar costs")
	var six = Sim.new("normal")
	for y in [160, 320, 480]:
		for x in [100, 240, 380, 520, 660]:
			if six.tables.size() == 6: break
			var at := Vector2(x, y)
			if six.can_place(at, false, -1, "slots"):
				six.tables.append(six.new_table(at, false, "slots"))
				six.reroute()
	check(six.tables.size() == 6, "Six-game physical fixture fits")
	six.cash = 10000
	six.hire("Tech", -1)
	check(six.staffing_summary("Tech").required == 2 and six.staffing_summary("Tech").coverage == "SHORT STAFFED", "Six games require two Techs")
	six.hire("Tech", -1)
	check(six.staffing_summary("Tech").coverage == "GOOD COVERAGE", "Exactly two Techs fully cover six games")
	for i in range(6): break_game(six, i)
	six.TechService.tick(six)
	check(six.staff[0].repair_target != six.staff[1].repair_target, "Simultaneous calls claim distinct repairs")
	var duplicate: Dictionary = six.snapshot()
	duplicate.staff[1].repair_target = duplicate.staff[0].repair_target
	check(not Sim.new("normal").restore(duplicate), "Duplicate saved repair assignments rejected")
	check(Sim.new("normal").restore(six.snapshot()), "Six-game repair queue survives save")
	var elapsed := 0
	var wallet: float = six.owner_bankroll
	while six.tables.any(func(t): return t.broken) and elapsed <= CasinoTuning.REPAIR_WAIT_GRACE_MINUTES:
		six.move_guests(1)
		six.step()
		elapsed += 1
	check(not six.tables.any(func(t): return t.broken) and elapsed <= CasinoTuning.REPAIR_WAIT_GRACE_MINUTES, "Two Techs clear all six within reputation grace")
	check(six.tables.all(func(t): return t.repairs == 1), "Each simultaneous breakdown settled exactly once")
	check(six.staff.all(func(e): return e.duty == "On Call"), "Both Techs return to on-call roster")
	check(six.owner_bankroll == wallet, "Call costs leave personal wallet alone")
	break_game(six, 0)
	six.TechService.tick(six)
	var first: int = int(six.staff.filter(func(e): return e.duty == "Repairing")[0].id)
	six.resolve_incident(0, true)
	check(six.staff.all(func(e): return e.repair_target == -1), "Manual repair cancels dispatched job")
	six.elapsed += 1
	break_game(six, 0)
	six.TechService.tick(six)
	check(int(six.staff.filter(func(e): return e.duty == "Repairing")[0].id) != first, "Single repair calls rotate through Tech roster")
	check(Sim.new("normal").restore(six.snapshot()), "Rotated call persists")
	var mixed = Sim.new("easy", ["slots", "blackjack", "roulette"])
	mixed.hire("Tech", -1)
	check(mixed.staffing_summary("Tech").required == 1 and mixed.staffing_summary("Tech").coverage == "GOOD COVERAGE", "Machines and tables count equally toward coverage")
	for i in range(3): break_game(mixed, i)
	mixed.TechService.tick(mixed)
	for i in range(CasinoTuning.REPAIR_WAIT_GRACE_MINUTES):
		mixed.move_guests(1)
		mixed.step()
	check(mixed.tables.all(func(t): return not t.broken and t.repairs == 1), "One Tech repairs three mixed games within reputation grace")
	var ui = load("res://main.tscn").instantiate()
	root.add_child(ui)
	ui.close_modal()
	ui.open_page("staff")
	check(ui.sim.staffing_summary("Tech").required == 1, "Staff screen exposes one-per-three coverage")
	ui.free()
	print("TECH_SMOKE: %d checks, %d failures; six repairs cleared in %d game minutes" % [checks, failures, elapsed])
	quit(1 if failures else 0)
