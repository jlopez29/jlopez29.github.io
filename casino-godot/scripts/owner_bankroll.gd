extends RefCounted
## Single personal account. Event wagers escrow stakes outside casino cash.
## Callers capture next_operation once per action; reusing it is rejected.
var balance := CasinoTuning.OWNER_STARTING_BANKROLL
var next_operation := 1
var pending := {}
var history: Array = []
var profit_transferred := 0.0

static func money(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= CasinoTuning.OWNER_MONEY_LIMIT

func record(kind: String, amount: float, at: int, id: int = 0, profit: float = 0) -> void:
	history.push_front({"kind": kind, "amount": amount, "balance": balance, "at": at, "id": id, "profit": profit})
	if history.size() > CasinoTuning.OWNER_HISTORY_LIMIT: history.pop_back()

# Normal floor games retain their existing house-counterparty accounting.
func floor_debit(amount: float, at: int) -> bool:
	if not money(amount) or amount > balance: return false
	balance -= amount
	if amount > 0: record("floor_wager", -amount, at)
	return true

func floor_credit(amount: float, at: int, kind: String = "floor_return") -> bool:
	if not money(amount) or not money(balance + amount): return false
	balance += amount
	if amount > 0: record(kind, amount, at)
	return true

func wager(id: int, amount: float, at: int) -> bool:
	if id != next_operation or not money(amount) or amount <= 0 or amount > balance or pending.size() >= CasinoTuning.OWNER_PENDING_LIMIT: return false
	pending[str(id)] = amount
	next_operation += 1
	balance -= amount
	record("wager", -amount, at, id)
	return true

func settle(id: int, total_return: float, at: int, kind: String = "") -> Dictionary:
	var key := str(id)
	if not pending.has(key) or not money(total_return): return {}
	var stake: float = pending[key]
	var returned := minf(stake, total_return)
	var profit := maxf(0, total_return - stake)
	if not money(balance + returned) or not money(profit_transferred + profit): return {}
	pending.erase(key) # Remove before publishing or crediting anything.
	balance += returned
	profit_transferred += profit
	if kind.is_empty(): kind = "win" if profit > 0 else "loss" if total_return < stake else "push"
	record(kind, returned, at, id, profit)
	return {"stake": stake, "returned_stake": returned, "profit": profit}

func refund(id: int, at: int) -> Dictionary:
	return settle(id, float(pending.get(str(id), -1)), at, "refund_push")

func reward(id: int, amount: float, reason: String, at: int) -> bool:
	if id != next_operation or reason.is_empty() or not money(amount) or amount <= 0 or amount > CasinoTuning.OWNER_MAX_REWARD or not money(balance + amount): return false
	next_operation += 1
	balance += amount
	record("reward: " + reason.left(80), amount, at, id)
	return true

func snapshot() -> Dictionary:
	return {"balance": balance, "next_operation": next_operation, "pending": pending.duplicate(), "history": history.duplicate(true), "profit_transferred": profit_transferred}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not money(data.get("balance")) or not money(data.get("profit_transferred")): return false
	var serial = data.get("next_operation")
	if not money(serial) or serial != int(serial) or serial < 1: return false
	if not data.get("pending") is Dictionary or data.pending.size() > CasinoTuning.OWNER_PENDING_LIMIT: return false
	for id in data.pending:
		if not id is String or not id.is_valid_int() or str(int(id)) != id or int(id) < 1 or int(id) >= serial: return false
		if not money(data.pending[id]) or data.pending[id] <= 0: return false
	var escrow := float(data.balance)
	for stake in data.pending.values(): escrow += float(stake)
	if not money(escrow): return false
	if not data.get("history") is Array or data.history.size() > CasinoTuning.OWNER_HISTORY_LIMIT: return false
	for entry in data.history:
		if not entry is Dictionary or not entry.get("kind") is String: return false
		for key in ["amount", "balance", "at", "id", "profit"]:
			var value = entry.get(key)
			if not (value is int or value is float) or not is_finite(float(value)): return false
		if not money(entry.balance) or not money(entry.profit) or entry.at < 0 or entry.id < 0 or entry.id >= serial: return false
	balance = float(data.balance)
	next_operation = int(serial)
	pending = data.pending.duplicate()
	history = data.history.duplicate(true)
	profit_transferred = float(data.profit_transferred)
	return true

# Additional blackjack stakes belong to the existing escrow, never house revenue.
func increase_wager(id: int, amount: float, at: int) -> bool:
	var key := str(id)
	if not pending.has(key) or not money(amount) or amount <= 0 or amount > balance or not money(float(pending[key]) + amount): return false
	pending[key] = float(pending[key]) + amount
	balance -= amount
	record("additional_wager", -amount, at, id)
	return true
