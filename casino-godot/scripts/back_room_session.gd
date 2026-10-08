extends RefCounted
## Private external counterparty. No floor asset, guest, dealer or game-clock dependency.
const MINIMUM_STAKE := 1.0
const Games = preload("res://scripts/casino_games.gd")
const Account = preload("res://scripts/owner_bankroll.gd")
const Craps = preload("res://scripts/craps.gd")
var rng := RandomNumberGenerator.new()
var state := {"mode": "BACK_ROOM", "kind": "", "sequence": 0, "operation": 0, "round": {}, "bets": {}, "contracts": [], "point": 0, "working": false, "result": "", "profit": 0.0}

func _init() -> void:
	rng.randomize()

static func cents(value: float) -> float:
	return round(value * 100.0) / 100.0

static func stake_valid(value: float) -> bool:
	return Account.money(value) and value >= MINIMUM_STAKE and is_equal_approx(value * 100, round(value * 100))

func busy() -> bool:
	return not state.contracts.is_empty() or not state.bets.is_empty() or (not state.round.is_empty() and state.round.get("phase") != "done")

func choose(kind: String) -> bool:
	if kind not in ["slots", "blackjack", "craps", "roulette", "holdem"] or busy(): return false
	state.kind = kind
	state.round = {}
	state.result = ""
	state.profit = 0.0
	state.sequence += 1
	return true

func debit(sim, stake: float) -> int:
	var id: int = sim.owner_account.next_operation
	sim.owner_account.balance = cents(sim.owner_account.balance)
	if not sim.owner_account.wager(id, stake, sim.elapsed): return 0
	sim.owner_account.balance = cents(sim.owner_account.balance)
	sim.owner_account.history[0].kind = "back_room_stake"
	return id

func settle(sim, id: int, returned: float) -> bool:
	returned = cents(returned)
	if not Account.money(returned): return false
	var result: Dictionary = sim.owner_account.settle(id, returned, sim.elapsed, "back_room_settlement", true)
	if result.is_empty(): return false
	sim.owner_account.balance = cents(sim.owner_account.balance)
	state.profit += float(result.profit)
	sim.owner_account.record("back_room_return", returned, sim.elapsed, id)
	sim.owner_account.record("back_room_loss", -maxf(0, float(result.stake) - returned), sim.elapsed, id)
	state.result = "Returned $%.2f | Personal loss $%.2f | PERSONAL WINNINGS +$%.2f" % [returned, maxf(0, float(result.stake)-returned), state.profit]
	return true

func start(sim, stake: float, lines: int = 1, trips: float = 0) -> bool:
	if busy() or not stake_valid(stake) or not Account.money(trips) or (trips > 0 and not stake_valid(trips)): return false
	if state.kind not in ["slots", "blackjack", "holdem"]: return false
	if state.kind == "slots" and lines not in CasinoTuning.SLOT_LINE_COUNTS: return false
	# Full maximum Hold'em action exposure must be affordable before dealing.
	if state.kind == "holdem" and sim.owner_bankroll < stake * 6 + trips: return false
	var cost := cents(stake * 2 + trips) if state.kind == "holdem" else stake
	var id := debit(sim, cost)
	if id == 0: return false
	state.operation = id
	state.profit = 0.0
	match state.kind:
		"slots": state.round = Games.spin_slots(stake, rng, CasinoTuning.slot_profile("starter"), lines)
		"blackjack": state.round = Games.blackjack(stake, rng)
		"holdem": state.round = Games.holdem(stake, trips, rng)
	if state.kind == "blackjack": state.round.currency_step = 0.01
	state.round.staked = cost
	state.sequence += 1
	return finish(sim)

func finish(sim) -> bool:
	if state.round.get("phase") != "done": return true
	return settle(sim, int(state.operation), float(state.round.credit))

func act(sim, action: String) -> bool:
	if state.kind not in ["blackjack", "holdem"] or state.round.is_empty(): return false
	var actions := Games.actions(state.round, sim.owner_bankroll)
	if not actions.has(action): return false
	var cost := cents(float(actions[action]))
	if cost > 0 and not sim.owner_account.increase_wager(int(state.operation), cost, sim.elapsed): return false
	sim.owner_account.balance = cents(sim.owner_account.balance)
	state.round.staked = cents(float(state.round.staked) + cost)
	Games.act(state.round, action)
	state.sequence += 1
	return finish(sim)

func add(sim, key: String, amount: float) -> bool:
	if not stake_valid(amount): return false
	if state.kind == "roulette":
		if not Games.roulette_bets().has(key): return false
	elif state.kind == "craps":
		if not Craps.empty_bets().has(key): return false
		var all := layout()
		if key in ["pass", "dont_pass"] and int(state.point) != 0: return false
		if key in ["come", "dont_come"] and int(state.point) == 0: return false
		if key == "odds" and (int(state.point) == 0 or all.get("pass", 0) <= 0): return false
		if key == "lay_odds" and (int(state.point) == 0 or all.get("dont_pass", 0) <= 0): return false
		for n in Craps.NUMBERS:
			if key in ["come_"+str(n), "dont_come_"+str(n)]: return false
			if key == "come_odds_"+str(n) and all.get("come_"+str(n), 0) <= 0: return false
			if key == "dont_come_odds_"+str(n) and all.get("dont_come_"+str(n), 0) <= 0: return false
	else: return false
	var id := debit(sim, amount)
	if id == 0: return false
	if state.kind == "roulette": state.bets[str(id)] = {"key": key, "amount": amount}
	else: state.contracts.append({"id": id, "key": key, "amount": amount})
	state.sequence += 1
	return true

func layout() -> Dictionary:
	var result := {}
	if state.kind == "roulette":
		for item in state.bets.values(): result[item.key] = float(result.get(item.key, 0)) + float(item.amount)
	else:
		for item in state.contracts: result[item.key] = float(result.get(item.key, 0)) + float(item.amount)
	return result

func remove(sim, key: String = "") -> bool:
	var removed := false
	if state.kind == "roulette":
		for id in state.bets:
			if not sim.owner_wager_refund(int(id)): return false
		removed = not state.bets.is_empty()
		state.bets.clear()
	elif state.kind == "craps" and Craps.removable(key, int(state.point)):
		for i in range(state.contracts.size()-1, -1, -1):
			var item: Dictionary = state.contracts[i]
			if item.key == key:
				if not sim.owner_wager_refund(int(item.id)): return false
				state.contracts.remove_at(i)
				removed = true
	if removed: state.sequence += 1
	return removed

func roll(sim) -> bool:
	state.profit = 0.0
	if state.kind == "roulette":
		if state.bets.is_empty(): return false
		var bets := layout()
		state.round = Games.spin_roulette(bets, rng)
		state.round.bets = bets
		# Roulette is one resolved portfolio: aggregate its stakes and total return.
		var ids: Array = state.bets.keys()
		var id := int(ids[0])
		var total := 0.0
		for entry in state.bets.values(): total += float(entry.amount)
		for other in ids.slice(1):
			sim.owner_account.pending.erase(str(other))
			sim.owner_account.record("back_room_portfolio_merge_into_"+str(id),0,sim.elapsed,int(other))
		sim.owner_account.pending[str(id)] = cents(total)
		state.round.staked = cents(total)
		if not settle(sim, id, float(state.round.credit)): return false
		state.bets.clear()
	elif state.kind == "craps":
		if state.contracts.is_empty(): return false
		var a := rng.randi_range(1, 6)
		var b := rng.randi_range(1, 6)
		var result := Craps.resolve(int(state.point), layout(), a, b, bool(state.working))
		var remaining: Array = []
		for item in state.contracts:
			var single := Craps.resolve(int(state.point), {item.key: item.amount}, a, b, bool(state.working))
			var live := Craps.exposure(single.bets)
			if live <= 0:
				if not settle(sim, int(item.id), float(single.credit)): return false
			else:
				for key in single.bets:
					if single.bets[key] > 0: item.key = key; break
				remaining.append(item)
				# Standing place/hardway winnings are profit; their principal remains escrowed.
				var profit := cents(float(single.credit))
				if not Account.money(sim.owner_account.balance + profit): return false
				sim.owner_account.balance = cents(sim.owner_account.balance + profit)
				state.profit += profit
				if profit > 0: sim.owner_account.record("back_room_standing_profit", profit, sim.elapsed, int(item.id), profit)
		state.contracts = remaining
		state.point = result.point
		state.result = "Dice %d + %d | %s | PERSONAL WINNINGS +$%.2f" % [a,b,result.message,state.profit]
		state.round = {"dice": [a,b], "phase": "done", "rolls": int(state.round.get("rolls", 0)) + 1, "credit": result.credit}
	else: return false
	state.sequence += 1
	return true

func snapshot() -> Dictionary:
	return {"state": state.duplicate(true), "rng": str(rng.state)}

func restore(data: Variant, account) -> bool:
	if not data is Dictionary or not data.get("state") is Dictionary or not data.get("rng") is String or not data.rng.is_valid_int() or str(int(data.rng)) != data.rng: return false
	var s: Dictionary = data.state
	if s.get("mode") != "BACK_ROOM" or s.get("kind") not in ["", "slots", "blackjack", "roulette", "holdem", "craps"]: return false
	for key in ["sequence", "operation", "point"]:
		if not Account.money(s.get(key)) or s[key] != int(s[key]): return false
	if int(s.point) not in [0,4,5,6,8,9,10] or not s.get("working") is bool or not s.get("result") is String or not Account.money(s.get("profit")): return false
	if not s.get("round") is Dictionary or not s.get("bets") is Dictionary or not s.get("contracts") is Array: return false
	if s.bets.size() + s.contracts.size() > CasinoTuning.OWNER_PENDING_LIMIT: return false
	var ids := {}
	for item in s.contracts:
		if not item is Dictionary or not Account.money(item.get("id")) or item.id != int(item.id) or not Craps.empty_bets().has(item.get("key")) or not Account.money(item.get("amount")): return false
		if ids.has(str(int(item.id))) or account.pending.get(str(int(item.id)), -1) != item.amount: return false
		ids[str(int(item.id))] = true
	for id in s.bets:
		var item = s.bets[id]
		if not item is Dictionary or not Games.roulette_bets().has(item.get("key")) or not Account.money(item.get("amount")) or account.pending.get(id, -1) != item.amount: return false
	if (s.kind != "craps" and not s.contracts.is_empty()) or (s.kind != "roulette" and not s.bets.is_empty()): return false
	if s.kind == "craps" and not s.round.is_empty():
		if s.round.get("phase") != "done" or not s.round.get("dice") is Array or s.round.dice.size() != 2: return false
		for die in s.round.dice:
			if not Account.money(die) or die != int(die) or int(die) not in range(1,7): return false
	if s.kind != "craps" and not Games.valid_round(s.round, str(s.kind)): return false
	if not s.round.is_empty() and s.kind in ["blackjack", "holdem"]:
		if s.kind == "blackjack":
			if s.round.get("currency_step") != 0.01: return false
			var cards: Array = s.round.deck + s.round.dealer
			var exposure := cents(float(s.round.insurance))
			for hand in s.round.hands: cards += hand.cards; exposure += float(hand.bet)
			if cards.size() != 312 or not is_equal_approx(exposure, float(s.round.staked)): return false
		else:
			if not is_equal_approx(float(s.round.base)*2 + float(s.round.trips) + float(s.round.play),float(s.round.staked)): return false
		if s.round.phase != "done" and account.pending.get(str(int(s.operation)), -1) != s.round.get("staked"): return false
		if s.round.phase == "done" and account.pending.has(str(int(s.operation))): return false
	state = s.duplicate(true)
	rng.state = int(data.rng)
	return true
