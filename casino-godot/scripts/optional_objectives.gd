extends RefCounted
## Small opt-in goals. Authoritative outcomes only; no RNG or wall-clock replay.
const KINDS := ["happy_visits", "gaming_profit", "paid_drinks", "occupied_games", "momentum", "owner_win"]
const TITLES := {"happy_visits": "Send guests home happy", "gaming_profit": "A profitable gaming run", "paid_drinks": "Deliver paid drink orders", "occupied_games": "Keep the floor playing", "momentum": "Keep the good atmosphere", "owner_win": "Win an owner opportunity"}
var active: Array = []
var history: Array = []
var samples: Array = []
var cooldowns := {}
var next_id := 1
var next_check := CasinoTuning.OBJECTIVE_INTERVAL
var cursor := 0
var reward_day := 0
var rewarded := 0.0

func recent(at: int) -> Dictionary:
	var result := {"gaming_profit": 0.0, "handle": 0.0, "happy_visits": 0.0, "paid_drinks": 0.0}
	for sample in samples:
		if at - int(sample.at) > CasinoTuning.OBJECTIVE_RECENT_WINDOW: continue
		for key in result: result[key] += float(sample[key])
	return result

func record(at: int, kind: String, amount: float, handle: float = 0.0) -> void:
	var bucket := at / CasinoTuning.OBJECTIVE_SAMPLE_MINUTES * CasinoTuning.OBJECTIVE_SAMPLE_MINUTES
	if samples.is_empty() or int(samples[-1].at) != bucket:
		samples.append({"at": bucket, "gaming_profit": 0.0, "handle": 0.0, "happy_visits": 0.0, "paid_drinks": 0.0})
		while samples.size() > CasinoTuning.OBJECTIVE_SAMPLE_LIMIT: samples.pop_front()
	samples[-1][kind] += amount
	samples[-1].handle += handle

func occupied_games(sim) -> int:
	# One guest pass and one asset pass, without repeated per-asset filtering.
	var playing := {}
	for guest in sim.guests:
		if guest.state == "Playing" and sim.elapsed - int(guest.last_wager_minute) <= CasinoTuning.OBJECTIVE_RECENT_WAGER and int(guest.last_wager_minute) >= 0:
			playing[int(guest.table)] = true
	var count := 0
	for table in sim.tables:
		if playing.has(int(table.id)) and sim.operating(table): count += 1
	return count

func eligible(sim, kind: String) -> bool:
	if not sim.opened or sim.usable_gaming_capacity() <= 0: return false
	var stats := recent(sim.elapsed)
	match kind:
		"happy_visits": return stats.happy_visits > 0
		"gaming_profit": return stats.gaming_profit > 0 and stats.handle >= CasinoTuning.OBJECTIVE_PROFIT_MIN_HANDLE
		"paid_drinks": return stats.paid_drinks > 0 and sim.bar_available() and not sim.drink_menu.is_empty()
		"occupied_games": return occupied_games(sim) > 0
		"momentum": return sim.momentum.value >= CasinoTuning.MOMENTUM_BASELINE and occupied_games(sim) > 0
		"owner_win":
			for event in sim.optional_events.active:
				if event.type not in ["owner_slots", "owner_blackjack"] or event.state != "pending" or sim.elapsed >= int(event.expires): continue
				if not sim.optional_events.target_valid(sim, event): continue
				var options: Array = sim.optional_events.stake_options(sim, str(event.type), int(event.target))
				if not options.is_empty() and sim.owner_bankroll >= float(options[0]) * int(sim.optional_events.DEFINITIONS[event.type].rounds): return true
	return false

func offer(sim, debug: bool = false) -> bool:
	if debug and not OS.is_debug_build(): return false
	if active.size() >= CasinoTuning.OBJECTIVE_ACTIVE_LIMIT: return false
	for offset in range(KINDS.size()):
		var index := (cursor + offset) % KINDS.size()
		var kind: String = KINDS[index]
		if active.any(func(goal): return goal.kind == kind) or sim.elapsed < int(cooldowns.get(kind, 0)) or not eligible(sim, kind): continue
		var stats := recent(sim.elapsed)
		var target := 1.0
		var threshold := 0.0
		match kind:
			"happy_visits": target = clampf(ceil(float(stats.happy_visits) * CasinoTuning.OBJECTIVE_COUNT_FRACTION), 2, CasinoTuning.OBJECTIVE_COUNT_MAX)
			"gaming_profit": target = clampf(ceil(float(stats.gaming_profit) * CasinoTuning.OBJECTIVE_PROFIT_FRACTION / 5.0) * 5.0, CasinoTuning.OBJECTIVE_PROFIT_MIN, CasinoTuning.OBJECTIVE_PROFIT_MAX)
			"paid_drinks": target = clampf(ceil(float(stats.paid_drinks) * CasinoTuning.OBJECTIVE_COUNT_FRACTION), 2, CasinoTuning.OBJECTIVE_COUNT_MAX)
			"occupied_games":
				target = CasinoTuning.OBJECTIVE_HOLD_MINUTES
				threshold = mini(occupied_games(sim), CasinoTuning.OBJECTIVE_OCCUPIED_MAX)
			"momentum":
				target = CasinoTuning.OBJECTIVE_HOLD_MINUTES
				threshold = minf(CasinoTuning.OBJECTIVE_MOMENTUM_MAX, floor(sim.momentum.value / 5.0) * 5.0)
		var reward := minf(CasinoTuning.OBJECTIVE_REWARD_MAX, CasinoTuning.OBJECTIVE_REWARD_BASE + sim.stars() * CasinoTuning.OBJECTIVE_REWARD_PER_STAR)
		active.append({"id": next_id, "kind": kind, "target": target, "threshold": threshold, "progress": 0.0, "reward": reward, "created": sim.elapsed, "started": -1, "expires": sim.elapsed + CasinoTuning.OBJECTIVE_OFFER_MINUTES, "state": "offered"})
		next_id += 1
		cursor = (index + 1) % KINDS.size()
		cooldowns[kind] = sim.elapsed + CasinoTuning.OBJECTIVE_KIND_COOLDOWN
		return true
	return false

func find_goal(id: int) -> Dictionary:
	for goal in active:
		if int(goal.id) == id: return goal
	return {}

func start(sim, id: int) -> bool:
	var goal := find_goal(id)
	if goal.is_empty() or goal.state != "offered" or sim.elapsed >= int(goal.expires) or not eligible(sim, str(goal.kind)): return false
	if goal.kind == "occupied_games" and occupied_games(sim) < int(goal.threshold): return false
	if goal.kind == "momentum" and sim.momentum.value < float(goal.threshold): return false
	goal.state = "active"
	goal.started = sim.elapsed
	goal.expires = sim.elapsed + CasinoTuning.OBJECTIVE_DURATION
	return true

func observe(sim, kind: String, amount: float, handle: float = 0.0) -> void:
	if not sim.opened: return
	if kind in ["gaming_profit", "happy_visits", "paid_drinks"]: record(sim.elapsed, kind, amount, handle)
	for goal in active:
		if goal.state != "active" or goal.kind != kind or sim.elapsed >= int(goal.expires): continue
		# Profit includes losses; do not count only positive settlements.
		goal.progress += amount
		complete(sim, goal)

func complete(sim, goal: Dictionary) -> void:
	if goal.state != "active" or float(goal.progress) < float(goal.target): return
	goal.progress = float(goal.target)
	goal.state = "ready"
	goal.expires = sim.elapsed + CasinoTuning.OBJECTIVE_CLAIM_MINUTES
	sim.log_house_activity("Optional goal ready: %s. Claim in Log." % TITLES[goal.kind])

func tick(sim) -> void:
	for goal in active.duplicate():
		if sim.elapsed >= int(goal.expires):
			finish(goal, "expired", sim.elapsed)
			continue
		if goal.state != "active" or goal.kind not in ["occupied_games", "momentum"]: continue
		var holds: bool = sim.opened and (occupied_games(sim) >= int(goal.threshold) if goal.kind == "occupied_games" else sim.momentum.value >= float(goal.threshold) and occupied_games(sim) > 0)
		goal.progress = float(goal.progress) + 1.0 if holds else 0.0
		complete(sim, goal)
	if sim.elapsed < next_check: return
	next_check = sim.elapsed + CasinoTuning.OBJECTIVE_INTERVAL
	if sim.opened: offer(sim)

func finish(goal: Dictionary, outcome: String, at: int) -> void:
	active.erase(goal) # Claim/dismiss/expiration consumes the ID exactly once.
	history.push_front({"id": goal.id, "kind": goal.kind, "outcome": outcome, "at": at})
	if history.size() > CasinoTuning.OBJECTIVE_HISTORY_LIMIT: history.pop_back()

func dismiss(sim, id: int) -> bool:
	var goal := find_goal(id)
	if goal.is_empty(): return false
	finish(goal, "dismissed", sim.elapsed)
	return true

func claimable(sim, goal: Dictionary) -> float:
	var budget: float = CasinoTuning.OBJECTIVE_DAILY_REWARD - (rewarded if reward_day == sim.elapsed / 1440 else 0.0)
	var room: float = CasinoTuning.OBJECTIVE_BANKROLL_CAP - sim.owner_bankroll
	for stake in sim.owner_account.pending.values(): room -= float(stake)
	for table in sim.tables:
		room -= CrapsRules.exposure(table.owner)
		for stake in table.get("roulette_bets", {}).values(): room -= float(stake)
		if sim.game_pending(table): room -= float(table.round.get("staked", 0))
	return maxf(0, minf(float(goal.reward), minf(budget, room)))

func claim(sim, id: int) -> bool:
	var goal := find_goal(id)
	if goal.is_empty() or goal.state != "ready" or sim.elapsed >= int(goal.expires): return false
	var reward := claimable(sim, goal)
	if reward <= 0: return false
	var before: Dictionary = sim.snapshot()
	if not sim.reward_owner_bankroll(sim.owner_account.next_operation, reward, "optional goal: " + str(goal.kind)): return false
	var today: int = sim.elapsed / 1440
	if reward_day != today:
		reward_day = today
		rewarded = 0.0
	rewarded += reward
	finish(goal, "claimed", sim.elapsed)
	sim.momentum.outcome(CasinoTuning.OBJECTIVE_MOMENTUM_REWARD, "Completed an optional goal")
	# Use the existing durable owner transaction checkpoint. Roll back on failure.
	if sim.owner_checkpoint.is_valid() and not sim.owner_checkpoint.call():
		sim.restore(before)
		sim.log_event("Objective reward canceled: local save storage is unavailable.")
		return false
	sim.log_house_activity("Optional goal claimed: Owner Bankroll +$%.2f." % reward)
	return true

func snapshot() -> Dictionary:
	return {"active": active.duplicate(true), "history": history.duplicate(true), "samples": samples.duplicate(true), "cooldowns": cooldowns.duplicate(), "next_id": next_id, "next_check": next_check, "cursor": cursor, "reward_day": reward_day, "rewarded": rewarded}

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and absf(float(value)) < CasinoTuning.OWNER_MONEY_LIMIT

static func integer(value: Variant, minimum: int = 0) -> bool:
	return number(value) and value == int(value) and value >= minimum

func restore(data: Variant, at: int) -> bool:
	if not data is Dictionary: return false
	for key in ["next_id", "next_check", "cursor", "reward_day"]:
		if not integer(data.get(key)): return false
	if data.next_id < 1 or data.cursor >= KINDS.size() or data.reward_day > at / 1440: return false
	if not number(data.get("rewarded")) or data.rewarded < 0 or data.rewarded > CasinoTuning.OBJECTIVE_DAILY_REWARD: return false
	if not data.get("active") is Array or data.active.size() > CasinoTuning.OBJECTIVE_ACTIVE_LIMIT: return false
	if not data.get("history") is Array or data.history.size() > CasinoTuning.OBJECTIVE_HISTORY_LIMIT: return false
	if not data.get("samples") is Array or data.samples.size() > CasinoTuning.OBJECTIVE_SAMPLE_LIMIT: return false
	if not data.get("cooldowns") is Dictionary: return false
	var ids := {}
	var kinds := {}
	for goal in data.active:
		if not goal is Dictionary or goal.get("kind") not in KINDS or goal.get("state") not in ["offered", "active", "ready"]: return false
		for key in ["id", "created", "expires"]:
			if not integer(goal.get(key)): return false
		if not integer(goal.get("started"), -1): return false
		for key in ["target", "threshold", "progress", "reward"]:
			if not number(goal.get(key)): return false
		if goal.id < 1 or goal.id >= data.next_id or ids.has(goal.id) or kinds.has(goal.kind) or goal.created > at or goal.expires < goal.created: return false
		if goal.started > at or goal.started < -1 or goal.target <= 0 or goal.threshold < 0 or goal.reward <= 0 or goal.reward > CasinoTuning.OBJECTIVE_REWARD_MAX: return false
		if goal.expires > at + maxi(CasinoTuning.OBJECTIVE_CLAIM_MINUTES, maxi(CasinoTuning.OBJECTIVE_DURATION, CasinoTuning.OBJECTIVE_OFFER_MINUTES)): return false
		if goal.state == "offered" and (goal.started != -1 or goal.progress != 0): return false
		if goal.state != "offered" and goal.started < goal.created: return false
		if goal.state == "ready" and goal.progress != goal.target: return false
		if goal.state == "active" and goal.progress >= goal.target: return false
		if goal.kind != "gaming_profit" and (goal.progress < 0 or goal.progress != int(goal.progress)): return false
		if goal.kind in ["happy_visits", "paid_drinks"] and (goal.target < 2 or goal.target > CasinoTuning.OBJECTIVE_COUNT_MAX or goal.target != int(goal.target) or goal.threshold != 0): return false
		if goal.kind == "gaming_profit" and (goal.target < CasinoTuning.OBJECTIVE_PROFIT_MIN or goal.target > CasinoTuning.OBJECTIVE_PROFIT_MAX or goal.threshold != 0): return false
		if goal.kind == "owner_win" and (goal.target != 1 or goal.threshold != 0): return false
		if goal.kind in ["momentum", "occupied_games"] and goal.target != CasinoTuning.OBJECTIVE_HOLD_MINUTES: return false
		if goal.kind == "occupied_games" and (goal.threshold < 1 or goal.threshold > CasinoTuning.OBJECTIVE_OCCUPIED_MAX or goal.threshold != int(goal.threshold)): return false
		if goal.kind == "momentum" and (goal.threshold < CasinoTuning.MOMENTUM_BASELINE or goal.threshold > CasinoTuning.OBJECTIVE_MOMENTUM_MAX): return false
		ids[goal.id] = true
		kinds[goal.kind] = true
	for entry in data.history:
		if not entry is Dictionary or entry.get("kind") not in KINDS or entry.get("outcome") not in ["claimed", "dismissed", "expired"]: return false
		if not integer(entry.get("id"), 1) or entry.id >= data.next_id or ids.has(entry.id) or not integer(entry.get("at")) or entry.at > at: return false
		ids[entry.id] = true
	var previous := -1
	for sample in data.samples:
		if not sample is Dictionary or not integer(sample.get("at")) or sample.at > at or sample.at <= previous or int(sample.at) % CasinoTuning.OBJECTIVE_SAMPLE_MINUTES != 0: return false
		for key in ["gaming_profit", "handle", "happy_visits", "paid_drinks"]:
			if not number(sample.get(key)) or (key != "gaming_profit" and sample[key] < 0): return false
		previous = int(sample.at)
	for kind in data.cooldowns:
		if kind not in KINDS or not integer(data.cooldowns[kind]) or data.cooldowns[kind] > at + CasinoTuning.OBJECTIVE_KIND_COOLDOWN: return false
	active = data.active.duplicate(true)
	history = data.history.duplicate(true)
	samples = data.samples.duplicate(true)
	cooldowns = data.cooldowns.duplicate()
	next_id = int(data.next_id)
	next_check = int(data.next_check) if data.next_check > at else at + CasinoTuning.OBJECTIVE_INTERVAL
	cursor = int(data.cursor)
	reward_day = int(data.reward_day)
	rewarded = float(data.rewarded)
	return true
