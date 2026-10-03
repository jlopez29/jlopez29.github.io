class_name CrapsRules
extends RefCounted

# All payouts are returns to the bettor, including a resolved contract's stake.
# Place bets stay on the layout after a hit; they are OFF on come-out rolls.
static func empty_bets() -> Dictionary:
	return {"pass": 0.0, "odds": 0.0, "six": 0.0, "eight": 0.0, "field": 0.0}

static func exposure(bets: Dictionary) -> float:
	var amount := 0.0
	for key in empty_bets():
		amount += float(bets.get(key, 0))
	return amount

static func resolve(point: int, bets: Dictionary, die_a: int, die_b: int) -> Dictionary:
	assert(die_a >= 1 and die_a <= 6 and die_b >= 1 and die_b <= 6)
	var next := bets.duplicate()
	var total := die_a + die_b
	var credit := 0.0
	var outcome := "Roll %d. Bets stay on the layout." % total
	var new_point := point
	if point == 0:
		if total == 7 or total == 11:
			credit += next.pass * 2.0
			next.pass = 0.0
			outcome = "Natural %d! Pass Line wins." % total
		elif total in [2, 3, 12]:
			next.pass = 0.0
			outcome = "Craps %d. Pass Line loses." % total
		else:
			new_point = total
			outcome = "Point is %d. Make %d before seven." % [total, total]
	else:
		if total == point:
			var ratio := 2.0 if point in [4, 10] else (1.5 if point in [5, 9] else 1.2)
			credit += next.pass * 2.0 + next.odds * (1.0 + ratio)
			next.pass = 0.0
			next.odds = 0.0
			new_point = 0
			outcome = "Point made! Pass Line and odds win."
		elif total == 7:
			next.pass = 0.0
			next.odds = 0.0
			next.six = 0.0
			next.eight = 0.0
			new_point = 0
			outcome = "Seven out. Line, odds and working Place bets lose."
		if total == 6:
			credit += next.six * 7.0 / 6.0
		elif total == 8:
			credit += next.eight * 7.0 / 6.0
	if total in [2, 3, 4, 9, 10, 11, 12]:
		var field_return := 3.0 if total == 2 else (4.0 if total == 12 else 2.0)
		credit += next.field * field_return
	next.field = 0.0
	return {"point": new_point, "bets": next, "credit": credit, "message": outcome, "total": total}
