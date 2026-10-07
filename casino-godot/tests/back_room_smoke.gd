extends SceneTree
const Sim = preload("res://scripts/simulation.gd")
const Room = preload("res://scripts/back_room_session.gd")
const Recovery = preload("res://scripts/recovery_system.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, description: String) -> void:
	checks += 1
	if not value: failures += 1; push_error(description)

func saved(sim) -> Dictionary:
	return JSON.parse_string(JSON.stringify(sim.snapshot()))

func solution(c: Dictionary) -> Dictionary:
	var p := Recovery.puzzle(c)
	return {"choice":p.get("answer",0),"number":p.get("number",0),"reason":p.get("reason",0),"mask":p.get("mask",3),"aisle":true}

func run() -> void:
	money()
	precision_and_funding()
	tickets_and_cycles()
	games()
	recovery()
	puzzles()
	monte_carlo()
	await ui()
	print("BACK ROOM: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func money() -> void:
	for pair in [[250,0],[250,250],[250,750],[1000,3000]]:
		var sim := Sim.new()
		var initial: float = sim.cash
		check(sim.owner_wager_debit(1,pair[0]),"Escrow example")
		check(sim.back_room.settle(sim,1,pair[1]),"Private settlement")
		check(sim.owner_bankroll==1000-maxf(0,pair[0]-pair[1]) and sim.cash==initial+maxf(0,pair[1]-pair[0]),"Verified exact settlement "+str(pair))
		check(not sim.back_room.settle(sim,1,pair[1]),"Duplicate settlement rejected")
		var copy := Sim.new()
		check(copy.restore(saved(sim)) and not copy.back_room.settle(copy,1,pair[1]),"Settled operation survives JSON")
	var sim := Sim.new()
	for bad in [0.0,-1.0,0.001,NAN,INF,1001.0]:
		check(sim.private_action(sim.back_room.state.sequence,"choose",{"kind":"slots"}),"Choose slots")
		check(not sim.private_action(sim.back_room.state.sequence,"start",{"stake":bad}),"Reject bad stake")
	var count := [0]
	sim.owner_checkpoint = func(): count[0]+=1; return count[0]%2==1
	var before := sim.snapshot()
	check(not sim.private_action(6,"choose",{"kind":"roulette"}),"Failed save transaction rejects")
	check(sim.back_room.snapshot()==before.back_room and sim.owner_account.snapshot()==before.owner_bankroll and sim.cash==before.cash,"Failed checkpoint rolls back complete private state")

func precision_and_funding() -> void:
	var sim := Sim.new()
	sim.owner_account.floor_debit(999,0)
	for i in range(100):
		var id := sim.back_room.debit(sim,0.01)
		check(id>0 and sim.back_room.settle(sim,id,0),"One-cent loss remains spendable without drift")
	check(sim.owner_bankroll==0,"100 penny losses close exactly to zero")
	for action in ["Insurance","Double","Split"]:
		var found := false
		for seed_value in range(300):
			var sample := Sim.new()
			sample.back_room.rng.seed=seed_value
			sample.back_room.choose("blackjack")
			sample.back_room.start(sample,0.01)
			var actions := CasinoGames.actions(sample.back_room.state.round,sample.owner_bankroll)
			if not actions.has(action): continue
			var before: float = sample.owner_bankroll
			check(sample.back_room.act(sample,action),"Private blackjack "+action)
			check(sample.back_room.state.round.staked==0.02,"Cent-funded "+action+" exposure")
			if action=="Insurance": check(sample.back_room.state.round.insurance==0.01,"Insurance uses actual rounded cent stake")
			check(sample.owner_bankroll>=0 and sample.owner_bankroll<=before+0.02,"No credit gambling")
			var copy := Sim.new()
			check(copy.restore(saved(sample)),"Additional exposure persists "+action)
			found=true
			break
		check(found,"Reproducible legal action fixture "+action)

func tickets_and_cycles() -> void:
	var sim := Sim.new()
	var cash: float = sim.cash
	sim.owner_account.floor_debit(100,0)
	for c in sim.recovery.state.contracts: sim.recovery.submit(sim,c.id,solution(c))
	var card: Dictionary = sim.recovery.state.tickets[0]
	# Explicit isolated test outcome; shipping selection always uses persisted recovery RNG.
	card.award=500
	var id: String = card.id
	check(sim.recovery.claim_ticket(sim,id) and sim.owner_bankroll==1000,"$500 card caps to missing $100")
	check(sim.cash==cash and sim.revenue==0 and sim.recovery.state.completed==1,"Promotion touches personal wallet only")
	check(not sim.recovery.claim_ticket(sim,id),"Claimed promotion cannot replay after full cycle")
	var copy := Sim.new()
	check(copy.restore(saved(sim)) and not copy.recovery.claim_ticket(copy,id),"Claim checkpoints persist")
	var issued := 2
	for i in range(7):
		sim.owner_account.floor_debit(100,0)
		for c in sim.recovery.state.contracts: sim.recovery.submit(sim,c.id,solution(c))
		if sim.recovery.state.scratch_issued: issued+=2
		sim.recovery.anchor_utc+=3600
		check(sim.recovery.claim(sim,"timer"),"Repeated legitimate full refill")
		check(copy.restore(saved(sim)),"Stable repeated cycle checkpoint")
	check(issued==12 and sim.recovery.state.stage=="Mid","Six early cycles cap lifetime issuance to 12 tickets")
	check(not sim.recovery.state.scratch_issued and not sim.recovery.state.raffle_issued,"No endless promotion farming")

func games() -> void:
	for kind in ["slots","blackjack","holdem","roulette","craps"]:
		var sim := Sim.new()
		check(sim.private_action(0,"choose",{"kind":kind}),"Fresh Normal access "+kind)
		if kind in ["slots","blackjack","holdem"]:
			check(sim.private_action(1,"start",{"stake":1000 if kind=="slots" else 1,"lines":5}),"Independent affordable game "+kind)
			if kind!="slots":
				for i in range(30):
					if sim.back_room.state.round.phase=="done": break
					var actions: Dictionary = CasinoGames.actions(sim.back_room.state.round,sim.owner_bankroll)
					var action := "Stand" if actions.has("Stand") else "Decline insurance" if actions.has("Decline insurance") else "Check" if actions.has("Check") else "Fold"
					check(sim.private_action(sim.back_room.state.sequence,"act",{"action":action}),"Funded rules action")
		else:
			check(sim.private_action(1,"add",{"key":"Red" if kind=="roulette" else "pass","stake":10}),"Fund layout")
			check(not sim.private_action(1,"add",{"key":"Red","stake":10}),"Repeated sequence rejected")
			var copy := Sim.new()
			check(copy.restore(saved(sim)) and copy.back_room.busy(),"Live layout save")
			check(sim.private_action(2,"roll"),"Independent spin/throw")
		var copy := Sim.new()
		check(copy.restore(saved(sim)),"Private state restore "+kind)
		check(sim.guest_handle==0 and sim.revenue==0 and sim.payouts==0,"Private play never guest revenue")
	var sim := Sim.new()
	sim.private_action(0,"choose",{"kind":"roulette"})
	sim.private_action(1,"add",{"key":"Red","stake":250})
	sim.private_action(2,"add",{"key":"Black","stake":250})
	check(sim.private_action(3,"remove") and sim.owner_bankroll==1000,"Pre-spin roulette refund")
	var room := Room.new()
	room.choose("craps")
	room.add(sim,"pass",25)
	# Existing deterministic rules: 4 establishes point, 4 resolves pass.
	var first := CrapsRules.resolve(0,{"pass":25},2,2)
	check(first.point==4 and first.bets.pass==25 and first.credit==0,"Craps line persists")
	var second := CrapsRules.resolve(4,first.bets,2,2)
	check(second.credit==50 and second.bets.pass==0,"Craps line settles through rules")
	check(not sim.join_table(int(sim.tables[0].id)) or sim.joined>=0,"Public play retains normal restrictions")
	var funds := Sim.new()
	funds.back_room.choose("holdem")
	check(not funds.back_room.start(funds,200) and funds.back_room.start(funds,100),"Hold'em full exposure boundary")
	check(not funds.back_room.act(funds,"Raise 9x"),"Unbacked raise rejected")

func recovery() -> void:
	var sim := Sim.new()
	var r = sim.recovery
	check(r.state.next_time_utc-r.state.started_utc==1800,"Early 30 real minutes")
	check(Recovery.stage(16,0)=="Mid" and Recovery.stage(55,0)=="Late" and Recovery.stage(0,6)=="Mid","Stage boundaries")
	sim.owner_account.floor_debit(850,0)
	for c in r.state.contracts:
		check(r.submit(sim,c.id,solution(c)),"Verified hands-on contract")
	check(r.successes()==3 and r.state.tickets.size()==2,"Three contracts and distinct earned tickets")
	check(not r.claim(sim,"contracts"),"Ten-minute minimum")
	var state := saved(sim)
	var copy := Sim.new()
	check(copy.restore(state) and copy.recovery.successes()==3 and saved(copy).recovery.state.tickets==saved(sim).recovery.state.tickets,"Stable contracts and immutable promotions")
	r.anchor_utc += 600
	check(r.claim(sim,"contracts") and sim.owner_bankroll==1000 and r.state.completed==1,"Missing $850 restored, one cycle")
	check(not r.claim(sim,"timer") and not r.claim(sim,"contracts"),"No stacked full refill")
	sim.owner_account.floor_debit(1,0)
	check(not r.claim(sim,"timer"),"Loss does not reset/mature timer")
	r.anchor_utc += 1800
	check(r.claim(sim,"timer") and sim.owner_bankroll==1000 and r.state.completed==2,"One dollar top-up")
	var escrow := sim.owner_account.next_operation
	sim.owner_account.wager(escrow,1000,0)
	r.anchor_utc += 3600
	check(not r.claim(sim,"timer"),"Escrow blocks refill")
	sim.owner_account.settle(escrow,0,0)
	check(r.claim(sim,"timer"),"Mature refill after settlement")
	sim.casino_rating=55
	sim.owner_account.floor_debit(100,0)
	r.anchor_utc += 3600
	check(r.claim(sim,"timer") and r.state.stage=="Late" and r.state.next_time_utc-r.state.started_utc==3600,"Late one-hour offer")
	for c in r.state.contracts: r.submit(sim,c.id,solution(c))
	check(not r.state.scratch_issued and not r.state.raffle_issued,"Late issues no chance rewards")
	var speed_before: int = r.state.next_time_utc
	for i in range(50): sim.step()
	check(r.state.next_time_utc==speed_before,"Simulation clock cannot accelerate recovery")
	var broken := saved(sim)
	broken.recovery.state.contracts[0].variant=500
	check(not copy.restore(broken),"Corrupt puzzle rejected")

func puzzles() -> void:
	for category in range(4):
		for tier in range(3):
			for variant in range(12):
				var c := {"category":category,"tier":tier,"variant":variant}
				check(Recovery.solved(c,solution(c)),"Solvable scenario "+str(c))
				check(not Recovery.solved(c,{"choice":-1,"mask":0,"number":999,"aisle":false}),"Bad answer rejected")
	var sim := Sim.new()
	var c: Dictionary = sim.recovery.state.contracts[0]
	check(sim.recovery.submit(sim,c.id,{}),"Failed attempt saved")
	check(sim.recovery.successes()==0 and not sim.recovery.submit(sim,c.id,solution(c)),"Failure cooldown no progress")

func monte_carlo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=716
	for kind in ["scratch","raffle"]:
		var sum := 0
		var counts := {}
		for i in range(100000):
			var award := Recovery.award_for(kind,rng.randi_range(0,99))
			counts[award]=int(counts.get(award,0))+1
			sum+=award
		var expected := 122.5 if kind=="scratch" else 77.0
		check(absf(sum/100000.0-expected)<3,"Promotion mean "+kind)
		print("%s seeded distribution %s mean %.3f" % [kind,str(counts),sum/100000.0])
	for lines in [1,3,5]:
		var sum := 0.0
		for i in range(100000): sum+=CasinoGames.spin_slots(1,rng,CasinoTuning.slot_profile("starter"),lines).credit
		var expected: float = CasinoTuning.slot_line_metrics("starter",lines).rtp
		check(absf(sum/100000.0-expected)<0.03,"Shared slot RTP "+str(lines))
		print("Slots %d lines seeded RTP %.5f / exact %.5f" % [lines,sum/100000.0,expected])

func ui() -> void:
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.close_modal()
	main.owner_checkpoint_path="/tmp/back-room-smoke.json"
	main.enter_back_room()
	check(main.in_back_room and main.back_room_view.visible and not main.floor_view.visible,"Private room mounted without floor obstruction")
	for viewport in [Vector2i(1440,900),Vector2i(844,390),Vector2i(390,844),Vector2i(320,568)]:
		root.size=viewport
		await process_frame
		main.layout_ui()
		for kind in ["slots","blackjack","holdem","roulette","craps"]:
			main.sim.private_action(main.sim.back_room.state.sequence,"choose",{"kind":kind})
			main.back_room_view.page="game"; main.back_room_view.rebuild()
			await process_frame
			if kind!="craps": check(main.back_room_view.surface.size.y>=200,"Game surface remains visible "+kind+str(viewport))
		main.back_room_view.page="recovery"
		main.back_room_view.rebuild()
		await process_frame
		print("UI viewport ",viewport," actual ",main.back_room_view.get_rect())
		check(main.back_room_view.get_rect().size==Vector2(viewport),"Recovery viewport reflow "+str(viewport))
		main.back_room_view.page="lobby"
		main.back_room_view.rebuild()
		await process_frame
	main.back_room_view.leave_requested.emit()
	check(not main.in_back_room and main.floor_view.visible,"Exit preserves floor state")
	main.queue_free()
	await process_frame
