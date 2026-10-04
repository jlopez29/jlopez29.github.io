class_name CrapsRules
extends RefCounted

const NUMBERS := [4, 5, 6, 8, 9, 10]
const PLACE_KEYS := {4: "four", 5: "five", 6: "six", 8: "eight", 9: "nine", 10: "ten"}
const HARD_NUMBERS := [4, 6, 8, 10]
const PROPS := {"any_craps": [2, 3, 12], "any_seven": [7], "yo": [11], "aces": [2], "ace_deuce": [3], "boxcars": [12]}
const PROP_PAY := {"any_craps": 7.0, "any_seven": 4.0, "yo": 15.0, "aces": 30.0, "ace_deuce": 15.0, "boxcars": 30.0}

static func empty_bets() -> Dictionary:
	var bets := {"pass": 0.0, "odds": 0.0, "dont_pass": 0.0, "lay_odds": 0.0, "come": 0.0, "dont_come": 0.0, "field": 0.0}
	for n in NUMBERS:
		bets[PLACE_KEYS[n]] = 0.0
		for prefix in ["come_", "come_odds_", "dont_come_", "dont_come_odds_"]:
			bets[prefix + str(n)] = 0.0
	for n in HARD_NUMBERS:
		bets["hard_" + str(n)] = 0.0
	for kind in PROPS:
		bets[kind] = 0.0
	return bets

static func exposure(bets: Dictionary) -> float:
	var amount := 0.0
	for kind in empty_bets():
		amount += float(bets.get(kind, 0))
	return amount

static func true_odds(point: int) -> float:
	return 2.0 if point in [4, 10] else (1.5 if point in [5, 9] else 1.2)

static func name_for(kind: String) -> String:
	var names := {"pass": "Pass Line", "odds": "Pass odds", "dont_pass": "Don't Pass", "lay_odds": "Don't Pass odds", "come": "Come", "dont_come": "Don't Come", "field": "Field", "any_craps": "Any craps", "any_seven": "Any seven", "yo": "Yo 11", "aces": "Aces 2", "ace_deuce": "Ace-deuce 3", "boxcars": "Boxcars 12"}
	if names.has(kind): return names[kind]
	for n in NUMBERS:
		if kind == PLACE_KEYS[n]: return "Place %d" % n
		if kind == "come_" + str(n): return "Come %d" % n
		if kind == "come_odds_" + str(n): return "Come %d odds" % n
		if kind == "dont_come_" + str(n): return "Don't Come %d" % n
		if kind == "dont_come_odds_" + str(n): return "DC %d odds" % n
	return "Hard " + kind.trim_prefix("hard_")

static func removable(kind: String, point: int) -> bool:
	if kind == "pass": return point == 0
	for n in NUMBERS:
		if kind == "come_" + str(n): return false
	return true

# Returns include a resolved contract's stake; standing bets receive profit only.
# Don't-side odds always work. Come contracts work on come-out, but Come odds,
# Place bets and hardways are off unless the player explicitly calls them working.
static func resolve(point: int, bets: Dictionary, die_a: int, die_b: int, working_on_comeout: bool = false) -> Dictionary:
	assert(die_a >= 1 and die_a <= 6 and die_b >= 1 and die_b <= 6)
	var next := empty_bets()
	next.merge(bets, true)
	var total := die_a + die_b
	var credit := 0.0
	var outcome := "Roll %d. Bets stay on the layout." % total
	var new_point := point
	var working := point != 0 or working_on_comeout
	var seven_out := point != 0 and total == 7
	if point == 0:
		if total in [7, 11]:
			credit += next.pass * 2.0
			next.pass = 0.0
			next.dont_pass = 0.0
			outcome = "Natural %d! Pass wins; Don't Pass loses." % total
		elif total in [2, 3, 12]:
			next.pass = 0.0
			if total != 12:
				credit += next.dont_pass * 2.0
				next.dont_pass = 0.0
			outcome = "Craps %d. Pass loses; Don't Pass %s." % [total, "pushes" if total == 12 else "wins"]
		else:
			new_point = total
			outcome = "Point is %d. Same shooter: make %d before seven." % [total, total]
	else:
		if total == point:
			credit += next.pass * 2.0 + next.odds * (1.0 + true_odds(point))
			next.pass = 0.0
			next.odds = 0.0
			next.dont_pass = 0.0
			next.lay_odds = 0.0
			new_point = 0
			outcome = "Point made! Pass and odds win. Shooter keeps the dice."
		elif seven_out:
			credit += next.dont_pass * 2.0 + next.lay_odds * (1.0 + 1.0 / true_odds(point))
			for kind in ["pass", "odds", "dont_pass", "lay_odds"]: next[kind] = 0.0
			new_point = 0
			outcome = "Seven out. Don't bets win. Dice pass to the next shooter."
	# Settle existing numbered contracts BEFORE a new Come/Don't Come travels.
	for n in NUMBERS:
		var come := "come_" + str(n)
		var odds := "come_odds_" + str(n)
		var dc := "dont_come_" + str(n)
		var lay := "dont_come_odds_" + str(n)
		if total == n or total == 7:
			if total == n:
				credit += next[come] * 2.0
				credit += next[odds] * (1.0 + true_odds(n)) if working else next[odds]
			else:
				if not working: credit += next[odds]
				credit += next[dc] * 2.0 + next[lay] * (1.0 + 1.0 / true_odds(n))
			for kind in [come, odds, dc, lay]: next[kind] = 0.0
		var place: String = PLACE_KEYS[n]
		if working:
			if total == n:
				var ratio := 9.0 / 5 if n in [4, 10] else (7.0 / 5 if n in [5, 9] else 7.0 / 6)
				credit += next[place] * ratio
			elif total == 7:
				next[place] = 0.0
	if total in [7, 11]:
		credit += next.come * 2.0
		next.come = 0.0
		next.dont_come = 0.0
	elif total in [2, 3, 12]:
		next.come = 0.0
		if total != 12:
			credit += next.dont_come * 2.0
			next.dont_come = 0.0
	else:
		next["come_" + str(total)] += next.come
		next["dont_come_" + str(total)] += next.dont_come
		next.come = 0.0
		next.dont_come = 0.0
	for n in HARD_NUMBERS:
		var kind := "hard_" + str(n)
		if working:
			if total == n and die_a == die_b:
				credit += next[kind] * (7.0 if n in [4, 10] else 9.0)
			elif total == n or total == 7:
				next[kind] = 0.0
	if total in [2, 3, 4, 9, 10, 11, 12]:
		credit += next.field * (3.0 if total == 2 else (4.0 if total == 12 else 2.0))
	next.field = 0.0
	for kind in PROPS:
		if total in PROPS[kind]: credit += next[kind] * (1.0 + PROP_PAY[kind])
		next[kind] = 0.0
	return {"point": new_point, "bets": next, "credit": credit, "message": outcome, "total": total, "seven_out": seven_out}
