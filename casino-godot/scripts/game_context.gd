class_name PitBossGameContext
extends RefCounted
## Presentation provider. Private station snapshots never enter public tables/staff.
var source: CasinoSimulation
var private_station: Dictionary = {}
var sequence := -1
var is_private: bool:
	get: return not private_station.is_empty()
var joined: int:
	get: return int(private_station.id) if is_private else source.joined
var owner_play: Dictionary:
	get: return {} if is_private else source.owner_play
var owner_bankroll: float:
	get: return source.owner_bankroll
var cash: float:
	get: return source.cash
var opened: bool:
	get: return true if is_private else source.opened
var optional_events:
	get: return source.optional_events

func _init(simulation: CasinoSimulation, station: Dictionary = {}) -> void:
	source = simulation
	private_station = station
	sequence = int(source.back_room.state.sequence)

func execute(action: String, args: Dictionary = {}) -> bool:
	return source.private_action(sequence, action, args)

func get_table(id: int) -> Dictionary:
	if not is_private: return source.get_table(id)
	sequence = int(source.back_room.state.sequence)
	var s: Dictionary = source.back_room.state
	var owner := CrapsRules.empty_bets()
	owner.merge(source.back_room.layout(), true)
	return {"id": joined, "kind": s.kind, "minimum": 0.01, "round": s.round,
		"roulette_bets": source.back_room.layout() if s.kind == "roulette" else {},
		"owner": owner, "point": s.point, "owner_working": s.working, "dice": s.round.get("dice", [1, 1]),
		"rolls": s.round.get("rolls", 0), "shooter": 0, "owner_queued": false, "betting_hold": false,
		"result": s.result, "history": [{"credit": s.round.get("credit", 0)}], "broken": false,
		"slot_profile": "starter"}

func table_kind(table: Dictionary) -> String:
	return source.table_kind(table)
func game_pending(table: Dictionary) -> bool:
	return source.game_pending(table)
func ready_for_play(table: Dictionary) -> bool:
	return true if is_private else source.ready_for_play(table)
func operating(table: Dictionary) -> bool:
	return true if is_private else source.operating(table)
func slot_profile(table: Dictionary) -> Dictionary:
	return source.slot_profile(table)
func maximum_wager(table: Dictionary) -> float:
	return owner_bankroll if is_private else source.maximum_wager(table)
func seated(id: int) -> Array:
	return [] if is_private else source.seated(id)
func guest_wager(table: Dictionary, guest: Dictionary) -> float:
	return source.guest_wager(table, guest)
func shooter_name(table: Dictionary) -> String:
	return "You" if is_private else source.shooter_name(table)
func shooter_has_line(table: Dictionary) -> bool:
	return CrapsRules.exposure(table.owner) > 0 if is_private else source.shooter_has_line(table)
func owner_event_table() -> Dictionary:
	return source.owner_event_table()
func owner_event_action(action: String, event_sequence: int) -> bool:
	return source.owner_event_action(action, event_sequence)
func start_game(id: int, stake: float, trips: float = 0, lines: int = 1) -> bool:
	if not is_private: return source.start_game(id, stake, trips, lines)
	return execute("roll") if private_station.kind == "roulette" else execute("start", {"stake": stake, "trips": trips, "lines": lines})
func game_action(id: int, action: String) -> bool:
	return execute("act", {"action": action}) if is_private else source.game_action(id, action)
func roulette_bet(id: int, key: String, amount: float) -> bool:
	return execute("add", {"key": key, "stake": amount}) if is_private else source.roulette_bet(id, key, amount)
func clear_roulette(id: int) -> void:
	if is_private: execute("remove")
	else: source.clear_roulette(id)
func bet_amount(table: Dictionary, key: String, chip: float = 0) -> float:
	return chip if is_private else source.bet_amount(table, key, chip)
func bet_error(id: int, key: String, chip: float = 0) -> String:
	if not is_private: return source.bet_error(id, key, chip)
	if not source.back_room.stake_valid(chip) or chip > owner_bankroll: return "Check wallet and whole-cent chip amount."
	var table := get_table(id)
	if key in ["pass", "dont_pass"] and int(table.point) != 0: return "Wait for come-out."
	if key in ["come", "dont_come"] and int(table.point) == 0: return "Wait for a point."
	if key == "odds" and (int(table.point) == 0 or table.owner.pass <= 0): return "Place Pass first."
	if key == "lay_odds" and (int(table.point) == 0 or table.owner.dont_pass <= 0): return "Place Don't Pass first."
	return ""
func bet(id: int, key: String, chip: float = 0) -> bool:
	return execute("add", {"key": key, "stake": chip}) if is_private else source.bet(id, key, chip)
func remove_bet(id: int, key: String) -> float:
	if not is_private: return source.remove_bet(id, key)
	var before := owner_bankroll
	execute("remove", {"key": key})
	return owner_bankroll - before
func reclaim(id: int) -> void:
	if not is_private: source.reclaim(id); return
	# Each take-down retains the existing atomic save checkpoint and operation protection.
	for key in source.back_room.layout():
		if CrapsRules.removable(key, int(source.back_room.state.point)):
			sequence = int(source.back_room.state.sequence)
			execute("remove", {"key": key})
func shoot_player(id: int) -> bool:
	return execute("roll") if is_private else source.shoot_player(id)
func working() -> void:
	if is_private: execute("working")

func roulette_committed() -> Array:
	if is_private or int(source.roulette_presentation.get("table_id", -1)) != joined: return []
	return source.roulette_presentation.get("wagers", [])
