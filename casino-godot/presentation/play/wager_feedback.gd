extends RefCounted
## Shared preview only; execution always goes through the context's authoritative action.
const Games = preload("res://scripts/casino_games.gd")
static func resolve(context: PitBossGameContext, key: String, chip: float, region: Rect2, locked: bool = false) -> Dictionary:
	if key.is_empty(): return {}
	var table := context.get_table(context.joined)
	var kind := context.table_kind(table)
	var amount := context.bet_amount(table, key, chip) if kind == "craps" else chip
	var reason := "Paused or table busy." if locked else "Choose a chip amount." if chip <= 0 else ""
	var detail := ""
	if kind == "craps" and reason.is_empty(): reason = context.bet_error(context.joined, key, chip)
	if kind == "roulette":
		var options := Games.roulette_bets()
		if not options.has(key): reason = "Unknown wager."
		else: detail = "%d:1" % options[key].pay
		if reason.is_empty():
			var exposure := amount
			for stake in table.roulette_bets.values(): exposure += float(stake)
			if not context.ready_for_play(table): reason = "Table unavailable."
			elif amount < table.minimum: reason = "Below table minimum."
			elif amount > context.owner_bankroll: reason = "Insufficient wallet."
			elif exposure > context.maximum_wager(table): reason = "Exceeds table maximum."
	return {"key": key, "amount": amount, "valid": reason.is_empty(), "reason": reason, "region": region, "detail": detail}
