extends RefCounted
## Presentation semantics only. Never settles, rounds or changes a payout.
const BIG_RETURN := 5.0
const HUGE_RETURN := 10.0

static func describe(result: Dictionary, sponsored: bool = false) -> Dictionary:
	var credit := float(result.get("credit", 0))
	var stake := 0.0 if sponsored else float(result.get("staked", result.get("total_wager", 0)))
	var net := credit - stake
	if is_equal_approx(credit, stake): net = 0.0
	var ratio := credit / maxf(0.01, float(result.get("total_wager", stake)))
	var category := "NO RETURN" if sponsored else "LOSS"
	var level := 0
	if credit > 0 and net < 0:
		category = "PARTIAL RETURN"
		level = 1
	elif credit > 0 and net == 0:
		category = "BREAK EVEN"
		level = 1
	elif net > 0:
		category = "SMALL WIN" if ratio < 2 else "WIN" if ratio < BIG_RETURN else "BIG WIN" if ratio < HUGE_RETURN else "HUGE WIN"
		level = 2 if ratio < 2 else 3 if ratio < BIG_RETURN else 4 if ratio < HUGE_RETURN else 5
		for line in result.get("winning_lines", []):
			if line.reason == "three" and int(line.symbol) == 4:
				category = "TOP AWARD"
				level = 6
	var count_seconds := 0.30 if level <= 2 else 0.65 if level == 3 else 1.15 if level == 4 else 1.35 if level == 5 else 1.80
	return {"category": category, "level": level, "credit": credit, "stake": stake, "net": net, "ratio": ratio, "sponsored": sponsored, "positive": net > 0, "count_seconds": count_seconds}

static func summary(info: Dictionary) -> String:
	if info.sponsored:
		return "%s\nCASINO CASH\n+$%.2f" % [info.category,info.credit] if info.positive else "NO RETURN\nNo stake charged"
	return "%s\n$%.2f RETURNED\nNET %s$%.2f" % [info.category,info.credit,"+" if info.net > 0 else "-" if info.net < 0 else "",absf(float(info.net))]
