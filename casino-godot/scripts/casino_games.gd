class_name CasinoGames
extends RefCounted

const NAMES := {"craps": "Craps", "slots": "Neon Reels", "roulette": "Roulette", "blackjack": "Blackjack", "holdem": "Ultimate Hold’em"}
const COSTS := CasinoTuning.GAME_COSTS
const RED := [1,3,5,7,9,12,14,16,18,19,21,23,25,27,30,32,34,36]
const WHEEL := [0,32,15,19,4,21,2,25,17,34,6,27,13,36,11,30,8,23,10,5,24,16,33,1,20,14,31,9,22,18,29,7,28,12,35,3,26]
const SYMBOLS := ["CHERRY", "LEMON", "BELL", "BAR", "SEVEN"]

static func deck(rng: RandomNumberGenerator, packs: int = 1) -> Array:
	var result: Array = []
	for i in range(52 * packs): result.append(i % 52)
	for i in range(result.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var temp = result[i]
		result[i] = result[j]
		result[j] = temp
	return result

static func card_name(card: int) -> String:
	var rank := card % 13 + 2
	return ({11: "J", 12: "Q", 13: "K", 14: "A"}.get(rank, str(rank))) + ["♠", "♥", "♦", "♣"][card / 13]

static func total(cards: Array) -> int:
	var sum := 0
	var aces := 0
	for c in cards:
		var rank := int(c) % 13 + 2
		if rank == 14: aces += 1; sum += 11
		else: sum += mini(rank, 10)
	while sum > 21 and aces > 0: sum -= 10; aces -= 1
	return sum

static func card_value(card: int) -> int:
	return 11 if card % 13 == 12 else mini(card % 13 + 2, 10)

static func roulette_bets() -> Dictionary:
	var bets := {}
	for n in range(37): bets[str(n)] = {"numbers": [n], "pay": 35}
	bets["Red"] = {"numbers": RED, "pay": 1}
	bets["Black"] = {"numbers": [], "pay": 1}
	for name in ["Odd", "Even", "1–18", "19–36", "1st dozen", "2nd dozen", "3rd dozen", "Column 1", "Column 2", "Column 3"]: bets[name] = {"numbers": [], "pay": 2 if "dozen" in name or "Column" in name else 1}
	for n in range(1, 37):
		if n not in RED: bets.Black.numbers.append(n)
		bets["Odd" if n % 2 else "Even"].numbers.append(n)
		bets["1–18" if n <= 18 else "19–36"].numbers.append(n)
		bets[["1st dozen", "2nd dozen", "3rd dozen"][(n - 1) / 12]].numbers.append(n)
		bets["Column %d" % ((n - 1) % 3 + 1)].numbers.append(n)
		if n % 3 != 0: bets["Split %d/%d" % [n, n + 1]] = {"numbers": [n,n+1], "pay": 17}
		if n <= 33: bets["Split %d/%d" % [n, n + 3]] = {"numbers": [n,n+3], "pay": 17}
		if n <= 32 and n % 3 != 0: bets["Corner %d/%d/%d/%d" % [n,n+1,n+3,n+4]] = {"numbers": [n,n+1,n+3,n+4], "pay": 8}
	for n in range(1, 35, 3):
		bets["Street %d–%d" % [n,n+2]] = {"numbers": [n,n+1,n+2], "pay": 11}
		if n <= 31: bets["Six line %d–%d" % [n,n+5]] = {"numbers": [n,n+1,n+2,n+3,n+4,n+5], "pay": 5}
	for n in [1,2,3]: bets["Split 0/%d" % n] = {"numbers": [0,n], "pay": 17}
	bets["Trio 0/1/2"] = {"numbers": [0,1,2], "pay": 11}
	bets["Trio 0/2/3"] = {"numbers": [0,2,3], "pay": 11}
	bets["First four"] = {"numbers": [0,1,2,3], "pay": 8}
	return bets

static func spin_roulette(bets: Dictionary, rng: RandomNumberGenerator, forced: int = -1) -> Dictionary:
	var number := rng.randi_range(0, 36) if forced < 0 else forced
	var credit := 0.0
	var options := roulette_bets()
	for name in bets:
		if options.has(name) and number in options[name].numbers: credit += float(bets[name]) * (1 + int(options[name].pay))
	return {"phase": "done", "kind": "roulette", "number": number, "credit": credit, "message": "%d %s · returned $%.2f" % [number, "GREEN" if number == 0 else ("RED" if number in RED else "BLACK"), credit]}

static func spin_slots(bet: float, rng: RandomNumberGenerator, profile: Dictionary, active_lines: int = 1) -> Dictionary:
	# Exactly three authoritative draws; presentation never touches this RNG.
	var stops := []
	for i in range(3): stops.append(rng.randi_range(0, profile.reel.size() - 1))
	return slots_at_stops(bet, stops, profile, active_lines)

static func slots_at_stops(bet: float, stops: Array, profile: Dictionary, active_lines: int = 1) -> Dictionary:
	assert(active_lines in CasinoTuning.SLOT_LINE_COUNTS)
	var grid := CasinoTuning.slot_grid(stops, profile.reel)
	var wins := []
	var credit := 0.0
	var line_bet := bet / active_lines
	for index in range(active_lines):
		var path: Array = CasinoTuning.SLOT_LINES[index]
		var symbols := [grid[path[0]][0], grid[path[1]][1], grid[path[2]][2]]
		var multiplier := CasinoTuning.slot_award(symbols, profile)
		if multiplier <= 0: continue
		var returned := line_bet * multiplier
		credit += returned
		wins.append({"index": index, "path": path.duplicate(), "symbol": int(symbols[0]) if symbols[0] == symbols[1] and symbols[1] == symbols[2] else 0, "reason": "three" if symbols[0] == symbols[1] and symbols[1] == symbols[2] else "cherry", "multiplier": multiplier, "line_bet": line_bet, "returned": returned})
	return {"kind": "slots", "phase": "done", "profile": profile.id, "stops": stops.duplicate(), "grid": grid, "active_lines": active_lines, "total_wager": bet, "winning_lines": wins, "credit": credit, "message": "Returned $%.2f on %d line%s" % [credit, wins.size(), "" if wins.size() == 1 else "s"] if credit > 0 else "No win"}

static func valid_slot_round(state: Dictionary) -> bool:
	if state.get("phase") != "done" or not CasinoTuning.SLOT_PROFILES.has(state.get("profile")): return false
	if not numeric(state.get("active_lines")) or state.active_lines != int(state.active_lines) or int(state.active_lines) not in CasinoTuning.SLOT_LINE_COUNTS: return false
	if not numeric(state.get("total_wager")) or state.total_wager <= 0: return false
	var profile := CasinoTuning.slot_profile(state.profile)
	if not state.get("stops") is Array or state.stops.size() != 3: return false
	for stop in state.stops:
		if not numeric(stop) or stop != int(stop) or stop >= profile.reel.size(): return false
	if not state.get("grid") is Array or state.grid.size() != 3: return false
	for row in state.grid:
		if not row is Array or row.size() != 3: return false
		for symbol in row:
			if not numeric(symbol) or symbol != int(symbol) or symbol > 4: return false
	var expected := slots_at_stops(float(state.total_wager), state.stops, profile, int(state.active_lines))
	for row in range(3):
		for col in range(3):
			if int(state.grid[row][col]) != int(expected.grid[row][col]): return false
	if not state.get("winning_lines") is Array or state.winning_lines.size() != expected.winning_lines.size(): return false
	for i in range(expected.winning_lines.size()):
		var win = state.winning_lines[i]
		if not win is Dictionary: return false
		var correct: Dictionary = expected.winning_lines[i]
		if win.get("reason") != correct.reason or not win.get("path") is Array or win.path.size() != 3: return false
		for col in range(3):
			if not numeric(win.path[col]) or float(win.path[col]) != int(win.path[col]) or int(win.path[col]) != int(correct.path[col]): return false
		for field in ["index", "symbol", "multiplier"]:
			if not numeric(win.get(field)) or float(win[field]) != float(correct[field]): return false
		for field in ["line_bet", "returned"]:
			if not numeric(win.get(field)) or not is_equal_approx(float(win[field]), float(correct[field])): return false
	return numeric(state.get("credit")) and is_equal_approx(float(state.credit), float(expected.credit))

static func blackjack(bet: float, rng: RandomNumberGenerator, participants: Array = []) -> Dictionary:
	var shoe := deck(rng, 6)
	var player := [shoe.pop_back(), shoe.pop_back()]
	var dealer := [shoe.pop_back(), shoe.pop_back()]
	var state := {"kind": "blackjack", "phase": "play", "deck": shoe, "dealer": dealer, "hands": [{"cards": player, "bet": bet, "split": false, "surrender": false}], "active": 0, "base": bet, "insurance": 0.0, "credit": 0.0, "message": "Choose your action."}
	state.npcs = []
	for participant in participants:
		var cards := [shoe.pop_back(), shoe.pop_back()]
		while total(cards) < 17: cards.append(shoe.pop_back())
		state.npcs.append({"id": participant.id, "name": participant.name, "cards": cards, "bet": participant.bet, "staked": participant.bet, "returned": 0.0})
	if card_value(int(dealer[0])) == 11: state.phase = "insurance"; state.message = "Dealer shows an ace. Insurance?"
	elif total(dealer) == 21 or total(player) == 21: finish_blackjack(state)
	return state

static func actions(state: Dictionary, funds: float) -> Dictionary:
	var result := {}
	if state.is_empty() or state.phase == "done": return result
	if state.kind == "blackjack":
		if state.phase == "insurance":
			result["Decline insurance"] = 0.0
			if funds >= state.base / 2: result["Insurance"] = state.base / 2
		else:
			var hand: Dictionary = state.hands[int(state.active)]
			result["Hit"] = 0.0
			result["Stand"] = 0.0
			if hand.cards.size() == 2 and funds >= hand.bet: result["Double"] = hand.bet
			if hand.cards.size() == 2 and not hand.split: result["Surrender"] = 0.0
			if hand.cards.size() == 2 and state.hands.size() < 4 and card_value(int(hand.cards[0])) == card_value(int(hand.cards[1])) and funds >= hand.bet: result["Split"] = hand.bet
	else:
		var raise := 4 if state.phase == "preflop" else (2 if state.phase == "flop" else 1)
		if funds >= state.base * raise: result["Raise %d×" % raise] = state.base * raise
		if state.phase == "preflop" and funds >= state.base * 3: result["Raise 3×"] = state.base * 3
		result["Fold" if state.phase == "river" else "Check"] = 0.0
	return result

static func act(state: Dictionary, action: String) -> void:
	if state.kind == "holdem":
		if action.begins_with("Raise"):
			state.play = state.base * int(action.substr(6, 1))
			finish_holdem(state, false)
		elif action == "Fold": finish_holdem(state, true)
		else: state.phase = "flop" if state.phase == "preflop" else "river"
		return
	if state.phase == "insurance":
		if action == "Insurance": state.insurance = state.base / 2
		state.phase = "play"
		if total(state.dealer) == 21 or total(state.hands[0].cards) == 21: finish_blackjack(state)
		else: state.message = "Dealer has no blackjack. Choose your action."
		return
	var hand: Dictionary = state.hands[int(state.active)]
	if action == "Hit":
		hand.cards.append(state.deck.pop_back())
		if total(hand.cards) < 21: return
	elif action == "Double":
		hand.bet *= 2
		hand.cards.append(state.deck.pop_back())
	elif action == "Surrender": hand.surrender = true
	elif action == "Split":
		var card = hand.cards.pop_back()
		hand.split = true
		hand.cards.append(state.deck.pop_back())
		state.hands.insert(int(state.active) + 1, {"cards": [card, state.deck.pop_back()], "bet": hand.bet, "split": true, "surrender": false})
		if card_value(int(card)) != 11: return
		# Split aces get one card each; neither is a natural blackjack.
		state.active += 1
	state.active += 1
	if int(state.active) >= state.hands.size(): finish_blackjack(state)

static func finish_blackjack(state: Dictionary) -> void:
	var dealer_bj: bool = state.dealer.size() == 2 and total(state.dealer) == 21
	var live := false
	for hand in state.hands:
		if total(hand.cards) <= 21 and not hand.surrender and not (not hand.split and hand.cards.size() == 2 and total(hand.cards) == 21): live = true
	for npc in state.get("npcs", []):
		if total(npc.cards) <= 21: live = true
	if live and not dealer_bj:
		while total(state.dealer) < 17: state.dealer.append(state.deck.pop_back())
	var dealer_total := total(state.dealer)
	var credit: float = state.insurance * 3 if dealer_bj else 0.0
	var results: Array = []
	for hand in state.hands:
		var value := total(hand.cards)
		var natural: bool = not hand.split and hand.cards.size() == 2 and value == 21
		var returned := 0.0
		if hand.surrender: returned = hand.bet / 2
		elif value > 21: returned = 0
		elif dealer_bj: returned = hand.bet if natural else 0.0
		elif natural: returned = hand.bet * 2.5
		elif dealer_total > 21 or value > dealer_total: returned = hand.bet * 2
		elif value == dealer_total: returned = hand.bet
		credit += returned
		hand.returned = returned
		results.append("%d: $%.2f back" % [value, returned])
	for npc in state.get("npcs", []):
		var value := total(npc.cards)
		var natural: bool = npc.cards.size() == 2 and value == 21
		if value > 21: npc.returned = 0.0
		elif dealer_bj: npc.returned = npc.bet if natural else 0.0
		elif natural: npc.returned = npc.bet * 2.5
		elif dealer_total > 21 or value > dealer_total: npc.returned = npc.bet * 2
		elif value == dealer_total: npc.returned = npc.bet
	state.credit = credit
	state.phase = "done"
	state.message = "Dealer %d · %s" % [dealer_total, " / ".join(results)]

# Rank all 21 five-card combinations, including ace-low straights and all kickers.
static func poker_rank(cards: Array) -> Array:
	var best: Array = [0,0,0,0,0,0]
	for a in range(cards.size() - 4):
		for b in range(a + 1, cards.size() - 3):
			for c in range(b + 1, cards.size() - 2):
				for d in range(c + 1, cards.size() - 1):
					for e in range(d + 1, cards.size()):
						var rank := rank_five([cards[a],cards[b],cards[c],cards[d],cards[e]])
						if rank_score(rank) > rank_score(best): best = rank
	return best

static func rank_score(rank: Array) -> int:
	var score := 0
	for i in range(6): score = score * 15 + (int(rank[i]) if i < rank.size() else 0)
	return score

static func rank_five(cards: Array) -> Array:
	var counts := {}
	var ranks: Array = []
	var suit := int(cards[0]) / 13
	var flush := true
	for card in cards:
		var rank := int(card) % 13 + 2
		counts[rank] = int(counts.get(rank, 0)) + 1
		ranks.append(rank)
		if int(card) / 13 != suit: flush = false
	ranks.sort(); ranks.reverse()
	var straight := 0
	if counts.size() == 5:
		if ranks[0] - ranks[4] == 4: straight = ranks[0]
		elif ranks == [14,5,4,3,2]: straight = 5
	var groups: Array = counts.keys()
	groups.sort_custom(func(a, b): return counts[a] > counts[b] if counts[a] != counts[b] else a > b)
	if flush and straight: return [8,straight]
	if counts[groups[0]] == 4: return [7,groups[0],groups[1]]
	if counts[groups[0]] == 3 and counts[groups[1]] == 2: return [6,groups[0],groups[1]]
	if flush: return [5] + ranks
	if straight: return [4,straight]
	if counts[groups[0]] == 3: return [3] + groups
	if counts[groups[0]] == 2 and counts[groups[1]] == 2: return [2] + groups
	if counts[groups[0]] == 2: return [1] + groups
	return [0] + ranks

static func rank_name(rank: Array) -> String:
	return ["High card", "Pair", "Two pair", "Three of a kind", "Straight", "Flush", "Full house", "Four of a kind", "Straight flush"][int(rank[0])]

static func holdem(bet: float, trips: float, rng: RandomNumberGenerator, participants: Array = []) -> Dictionary:
	var shoe := deck(rng)
	var state := {"kind": "holdem", "phase": "preflop", "base": bet, "trips": trips, "play": 0.0, "player": [shoe.pop_back(),shoe.pop_back()], "dealer": [shoe.pop_back(),shoe.pop_back()], "board": [shoe.pop_back(),shoe.pop_back(),shoe.pop_back(),shoe.pop_back(),shoe.pop_back()], "credit": 0.0, "message": "Preflop: check or raise 3× / 4×."}
	state.npcs = []
	for participant in participants:
		var cards := [shoe.pop_back(), shoe.pop_back()]
		var plays: bool = int(poker_rank(cards + state.board)[0]) >= 1
		state.npcs.append({"id": participant.id, "name": participant.name, "cards": cards, "bet": participant.bet, "staked": participant.bet * (3 if plays else 2), "folded": not plays, "returned": 0.0})
	return state

static func finish_holdem(state: Dictionary, folded: bool) -> void:
	var player := poker_rank(state.player + state.board)
	var dealer := poker_rank(state.dealer + state.board)
	var comparison := signi(rank_score(player) - rank_score(dealer))
	var qualifies: bool = int(dealer[0]) >= 1
	var credit := 0.0
	if not folded:
		if not qualifies or comparison == 0: credit += state.base
		elif comparison > 0: credit += state.base * 2
		if comparison == 0: credit += state.base + state.play
		elif comparison > 0:
			var blind := {4:1.0,5:1.5,6:3.0,7:10.0,8:50.0}
			var rate := float(blind.get(int(player[0]), 0))
			if int(player[0]) == 8 and int(player[1]) == 14: rate = 500
			credit += state.base * (1 + rate) + state.play * 2
	var trips_pay := {3:3,4:4,5:7,6:8,7:30,8:40}
	if trips_pay.has(int(player[0])):
		var rate := int(trips_pay[int(player[0])])
		if int(player[0]) == 8 and int(player[1]) == 14: rate = 50
		credit += state.trips * (1 + rate)
	for npc in state.get("npcs", []):
		var npc_round := {"player": npc.cards, "dealer": state.dealer, "board": state.board, "base": npc.bet, "play": 0.0 if npc.folded else npc.bet, "trips": 0.0}
		finish_holdem(npc_round, bool(npc.folded))
		npc.returned = npc_round.credit
	state.credit = credit
	state.phase = "done"
	state.message = "%s · You: %s / Dealer: %s (%s) · returned $%.2f" % ["Fold" if folded else ("Win" if comparison > 0 else ("Push" if comparison == 0 else "Loss")), rank_name(player), rank_name(dealer), "qualifies" if qualifies else "ante pushes", credit]

static func numeric(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0

static func valid_cards(value: Variant, minimum: int, maximum: int) -> bool:
	if not value is Array or value.size() < minimum or value.size() > maximum: return false
	for card in value:
		if not numeric(card) or float(card) != int(card) or int(card) > 51: return false
	return true

static func valid_round(state: Dictionary, kind: String) -> bool:
	if state.is_empty(): return true
	if state.get("kind") != kind or not state.get("message") is String or not numeric(state.get("credit")): return false
	if not state.get("npcs", []) is Array or state.get("npcs", []).size() > 7: return false
	for npc in state.get("npcs", []):
		if not npc is Dictionary or not npc.get("name") is String or not valid_cards(npc.get("cards"), 2, 24): return false
		for key in ["id", "bet", "staked", "returned"]:
			if not numeric(npc.get(key)): return false
		if kind == "holdem" and not npc.get("folded") is bool: return false
	if not numeric(state.get("staked", 0)) or not state.get("paid", false) is bool: return false
	match kind:
		"slots":
			if not valid_slot_round(state): return false
		"roulette":
			if state.get("phase") != "done" or not numeric(state.get("number")) or int(state.number) > 36 or int(state.number) != float(state.number): return false
		"blackjack":
			if state.get("phase") not in ["insurance", "play", "done"] or not state.get("hands") is Array or state.hands.is_empty() or state.hands.size() > 4: return false
			if not valid_cards(state.get("dealer"), 2, 24) or not valid_cards(state.get("deck"), 0, 312): return false
			if not numeric(state.get("base")) or not numeric(state.get("insurance")) or not numeric(state.get("active")): return false
			if state.phase != "done" and int(state.active) >= state.hands.size(): return false
			for hand in state.hands:
				if not hand is Dictionary or not valid_cards(hand.get("cards"), 2, 24) or not numeric(hand.get("bet")) or not hand.get("split") is bool or not hand.get("surrender") is bool: return false
		"holdem":
			if state.get("phase") not in ["preflop", "flop", "river", "done"]: return false
			if not valid_cards(state.get("dealer"), 2, 2) or not valid_cards(state.get("player"), 2, 2) or not valid_cards(state.get("board"), 5, 5): return false
			for key in ["base", "trips", "play"]:
				if not numeric(state.get(key)): return false
		_: return false
	return true
