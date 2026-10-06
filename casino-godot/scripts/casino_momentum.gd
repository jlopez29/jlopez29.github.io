extends RefCounted
## Slow, deterministic operating reputation. No RNG, wall-clock catch-up or money.
var value := CasinoTuning.MOMENTUM_BASELINE
var influence := 0.0
var guest_win_at := -CasinoTuning.MOMENTUM_WIN_COOLDOWN
var last_outcome := "Normal operation"
var contributors := {}
var target := CasinoTuning.MOMENTUM_BASELINE

func band() -> String:
	for entry in CasinoTuning.MOMENTUM_BANDS:
		if value < float(entry.ceiling): return str(entry.name)
	return "Electric"

func arrival_modifier() -> float:
	return 1.0 + CasinoTuning.MOMENTUM_MAX_ARRIVAL_BONUS * clampf((value - CasinoTuning.MOMENTUM_BASELINE) / (100.0 - CasinoTuning.MOMENTUM_BASELINE), 0, 1)

func outcome(amount: float, reason: String) -> void:
	influence = clampf(influence + amount, -CasinoTuning.MOMENTUM_INFLUENCE_LOSS_CAP, CasinoTuning.MOMENTUM_INFLUENCE_GAIN_CAP)
	last_outcome = reason

func guest_win(at: int) -> void:
	if at - guest_win_at < CasinoTuning.MOMENTUM_WIN_COOLDOWN: return
	guest_win_at = at
	outcome(CasinoTuning.MOMENTUM_GUEST_WIN_GAIN, "A guest landed a real big win")

func update(opened: bool, satisfaction: float, occupancy: float, coverage: float) -> void:
	# Closed/absent sessions freeze, rather than recharge or punish inactivity.
	if not opened: return
	influence *= CasinoTuning.MOMENTUM_INFLUENCE_RETENTION
	contributors = {
		"Normal operation": CasinoTuning.MOMENTUM_BASELINE,
		"Guest experience": clampf((satisfaction - 65.0) * CasinoTuning.MOMENTUM_SATISFACTION_WEIGHT, -CasinoTuning.MOMENTUM_SATISFACTION_LOSS_CAP, CasinoTuning.MOMENTUM_SATISFACTION_GAIN_CAP),
		"Occupied games": clampf(occupancy, 0, 1) * CasinoTuning.MOMENTUM_OCCUPANCY_GAIN,
		"Unavailable games": -(1.0 - clampf(coverage, 0, 1)) * CasinoTuning.MOMENTUM_COVERAGE_LOSS,
		"Recent outcomes": influence,
	}
	target = 0.0
	for amount in contributors.values(): target += float(amount)
	target = clampf(target, 0, 100)
	value = clampf(value + clampf((target - value) * CasinoTuning.MOMENTUM_RESPONSE, -CasinoTuning.MOMENTUM_MAX_STEP, CasinoTuning.MOMENTUM_MAX_STEP), 0, 100)

func detail() -> String:
	var text := "Momentum %s: %.1f / 100. Arrival bonus +%.1f%%.\nSlowly follows guest experience, occupied games and operating coverage. Odds and payouts stay unchanged.\nIgnoring Opportunities has no penalty. Closed or offline casinos retain momentum." % [band(), value, (arrival_modifier() - 1.0) * 100]
	if not contributors.is_empty(): text += "\nOperating target: %.1f / 100" % target
	for reason in contributors:
		text += "\n%s: %+.1f" % [reason, float(contributors[reason])]
	text += "\nLatest outcome: " + last_outcome
	return text

func snapshot() -> Dictionary:
	return {"value": value, "influence": influence, "guest_win_at": guest_win_at, "last_outcome": last_outcome}

func restore(data: Variant, at: int) -> bool:
	if not data is Dictionary: return false
	for key in ["value", "influence", "guest_win_at"]:
		if not (data.get(key) is float or data.get(key) is int) or not is_finite(float(data[key])): return false
	if data.value < 0 or data.value > 100 or data.influence < -CasinoTuning.MOMENTUM_INFLUENCE_LOSS_CAP or data.influence > CasinoTuning.MOMENTUM_INFLUENCE_GAIN_CAP: return false
	if data.guest_win_at != int(data.guest_win_at) or data.guest_win_at < -CasinoTuning.MOMENTUM_WIN_COOLDOWN or data.guest_win_at > at: return false
	if not data.get("last_outcome") is String or data.last_outcome.length() > 120: return false
	value = float(data.value)
	influence = float(data.influence)
	guest_win_at = int(data.guest_win_at)
	last_outcome = data.last_outcome
	return true
