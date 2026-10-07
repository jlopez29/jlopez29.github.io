extends RefCounted
## Reuses actual game rules, with event escrow as counterparty and no NPC wagers.
const Games = preload("res://scripts/casino_games.gd")
const Events = preload("res://scripts/optional_events.gd")
const Account = preload("res://scripts/owner_bankroll.gd")

static func start(sim, event_id: int, stake: float) -> bool:
	if not sim.owner_play.is_empty() or sim.joined >= 0: return false
	var event: Dictionary = sim.optional_events.find_event(event_id)
	if event.is_empty() or event.state != "engaged" or sim.elapsed >= int(event.expires) or not sim.optional_events.target_valid(sim, event): return false
	var definition: Dictionary = Events.DEFINITIONS[event.type]
	if definition.action != "owner_game" or not Account.money(stake) or stake not in sim.optional_events.stake_options(sim, str(event.type), int(event.target)): return false
	var funding := str(definition.get("funding", "owner"))
	var total := stake * int(definition.rounds) if funding == "owner" else 0.0
	var operation: int = sim.owner_account.next_operation
	if funding == "owner":
		if not sim.owner_wager_debit(operation, total): return false
	else:
		sim.owner_account.next_operation += 1 # Unique checkpoint identity; no owner transaction.
	var table: Dictionary = sim.get_table(int(event.target))
	var session := {"funding": funding, "event_id": event_id, "type": event.type, "target": int(event.target), "kind": definition.game, "profile": table.slot_profile, "base": stake, "rounds": int(definition.rounds), "operation": operation, "staked": total, "revealed": 0, "sequence": 0, "status": "playing", "round": {}, "spins": [], "result": {}}
	# Commit the complete slot batch now. Exiting/reloading cannot reroll later spins.
	if definition.game == "slots":
		for i in range(int(definition.rounds)):
			var round := Games.spin_slots(stake, sim.optional_events.rng, sim.slot_profile(table), 5)
			round.staked = stake if funding == "owner" else 0.0
			session.spins.append(round)
	else:
		session.round = Games.blackjack(stake, sim.optional_events.rng)
		session.round.staked = stake
		session.revealed = 1
	event.operation = operation
	sim.owner_play = session
	finish_if_ready(sim)
	return true

static func act(sim, action: String, sequence: int) -> bool:
	var session: Dictionary = sim.owner_play
	if session.is_empty() or session.status != "playing" or sequence != int(session.sequence): return false
	if session.kind == "slots":
		if action != "Spin" or int(session.revealed) >= int(session.rounds): return false
		session.round = session.spins[int(session.revealed)].duplicate(true)
		session.revealed += 1
	else:
		var actions := Games.actions(session.round, sim.owner_bankroll)
		if not actions.has(action): return false
		var cost: float = actions[action]
		if float(session.staked) + cost > float(session.base) * CasinoTuning.OWNER_EVENT_EXPOSURE_MULTIPLIER: return false
		if cost > 0 and not sim.owner_account.increase_wager(int(session.operation), cost, sim.elapsed): return false
		session.staked += cost
		session.round.staked = session.staked
		Games.act(session.round, action)
	session.sequence += 1 # Reject a replayed UI action before financial callbacks.
	if session.funding == "sponsor":
		sim.cash += float(session.round.credit)
		sim.sponsored_income += float(session.round.credit)
	finish_if_ready(sim)
	return true

static func finish_if_ready(sim) -> void:
	var session: Dictionary = sim.owner_play
	if session.is_empty() or session.status != "playing": return
	if session.kind == "slots" and int(session.revealed) != int(session.rounds): return
	if session.kind == "blackjack" and session.round.phase != "done": return
	var returned := 0.0
	if session.kind == "slots":
		for round in session.spins: returned += float(round.credit)
	else: returned = float(session.round.credit)
	var key := str(int(session.operation))
	if session.funding == "owner" and not sim.owner_account.pending.has(key): return
	var definition: Dictionary = Events.DEFINITIONS[session.type]
	var profit := maxf(0, returned - float(session.staked))
	var bonus := float(definition.get("bonus_profit", 0)) if profit > 0 else 0.0
	# Mark complete before transaction signals, so a synchronous callback cannot replay.
	session.status = "done"
	if session.funding == "owner" and not sim.owner_wager_settle(int(session.operation), returned, false):
		session.status = "playing"
		return
	if bonus > 0:
		sim.cash += bonus
		sim.owner_account.profit_transferred += bonus
		sim.owner_account.record("event_bonus", 0, sim.elapsed, int(session.operation), bonus)
	session.result = {"returned": returned, "stake": session.staked, "bankroll_change": minf(0, returned - float(session.staked)) if session.funding == "owner" else 0.0, "casino_profit": profit + bonus, "bonus": bonus, "outcome": "Win" if profit > 0 else "Loss" if returned < float(session.staked) else "Push", "hooks": definition.get("reward_hooks", {}).duplicate(true)}
	sim.optional_events.resolve(sim, int(session.event_id), "success", session.result)

static func exit(sim) -> bool:
	if sim.owner_play.is_empty(): return false
	# Never refund a dealt hand or committed spins on exit.
	if sim.owner_play.status == "playing":
		if sim.owner_play.kind == "slots" and sim.owner_play.funding == "sponsor":
			while sim.owner_play.status == "playing":
				if not act(sim, "Spin", int(sim.owner_play.sequence)): return false
		elif sim.owner_play.kind == "slots":
			sim.owner_play.revealed = sim.owner_play.rounds
			sim.owner_play.round = sim.owner_play.spins.back().duplicate(true)
			finish_if_ready(sim)
		else:
			while sim.owner_play.status == "playing":
				var action := "Decline insurance" if sim.owner_play.round.phase == "insurance" else "Stand"
				if not act(sim, action, int(sim.owner_play.sequence)): return false
	return sim.owner_play.status == "done"

static func view_table(sim) -> Dictionary:
	if sim.owner_play.is_empty(): return {}
	# Presentation copy only; real asset remains financially active for NPCs.
	var table: Dictionary = sim.get_table(int(sim.owner_play.target)).duplicate(true)
	if table.is_empty(): return {}
	table.round = sim.owner_play.round
	return table

static func valid(data: Variant, account, events, tables: Array) -> bool:
	if not data is Dictionary: return false
	if data.is_empty():
		return not events.active.any(func(event): return event.state == "engaged" and Events.DEFINITIONS[event.type].action == "owner_game" and event.has("operation"))
	for key in ["event_id", "target", "rounds", "operation", "revealed", "sequence"]:
		if not Events.integer(data.get(key)): return false
	if data.event_id < 1 or data.operation < 1 or data.operation >= account.next_operation or data.sequence > 128: return false
	if not Events.DEFINITIONS.has(data.get("type")) or data.get("status") not in ["playing", "done"]: return false
	var definition: Dictionary = Events.DEFINITIONS[data.type]
	if data.get("funding") != definition.get("funding", "owner"): return false
	if definition.action != "owner_game" or data.get("kind") != definition.game or data.rounds != definition.rounds: return false
	if not tables.any(func(table): return int(table.id) == int(data.target) and table.kind == data.kind and table.slot_profile == data.get("profile")): return false
	if not Account.money(data.get("base")) or float(data.base) <= 0 or not Account.money(data.get("staked")): return false
	if data.base not in definition.get("stake_options", [definition.get("fixed_stake", 0)]): return false
	if not data.get("round") is Dictionary or not data.get("spins") is Array or not data.get("result") is Dictionary: return false
	if not Games.valid_round(data.round, str(data.kind)) or not data.round.get("npcs", []).is_empty(): return false
	if data.kind == "slots":
		if data.spins.size() != data.rounds or data.revealed > data.rounds or data.staked != (data.base * data.rounds if data.funding == "owner" else 0.0): return false
		if data.revealed == 0 and not data.round.is_empty(): return false
		if data.revealed > 0 and data.round != data.spins[int(data.revealed)-1]: return false
		for round in data.spins:
			if not round is Dictionary or not Games.valid_round(round, "slots") or round.get("staked") != (data.base if data.funding == "owner" else 0.0): return false
			if round.profile != data.profile or round.total_wager != data.base or round.active_lines != 5: return false
	else:
		if data.round.is_empty() or data.revealed != 1 or not data.spins.is_empty(): return false
		var cards: Array = data.round.deck + data.round.dealer
		for hand in data.round.hands: cards += hand.cards
		if cards.size() != 312: return false
		var wagered := float(data.round.insurance)
		for hand in data.round.hands: wagered += float(hand.bet)
		if not is_equal_approx(wagered, float(data.staked)) or data.round.base != data.base or data.round.get("staked") != data.staked or data.staked > data.base * CasinoTuning.OWNER_EVENT_EXPOSURE_MULTIPLIER: return false
	var event: Dictionary = events.find_event(int(data.event_id))
	var key := str(int(data.operation))
	if data.status == "playing":
		if event.is_empty() or event.state != "engaged" or event.type != data.type or int(event.target) != int(data.target) or int(event.get("operation", -1)) != int(data.operation): return false
		if not data.result.is_empty(): return false
		if data.funding == "owner" and (not account.pending.has(key) or account.pending[key] != data.staked): return false
		if data.funding == "sponsor" and account.pending.has(key): return false
	else:
		if account.pending.has(key) or not event.is_empty() or (data.kind == "blackjack" and data.round.phase != "done") or data.revealed != data.rounds: return false
		for key_name in ["returned", "stake", "casino_profit", "bonus"]:
			if not Account.money(data.result.get(key_name)): return false
		if not (data.result.get("bankroll_change") is int or data.result.get("bankroll_change") is float) or not is_finite(float(data.result.bankroll_change)): return false
		if data.result.get("outcome") not in ["Win", "Loss", "Push"]: return false
	return true
