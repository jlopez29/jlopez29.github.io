extends RefCounted
# Presentation only. Settlement amounts and importance come from the simulation.
static func cash(amount: float, precision: int = 2) -> String:
	var parts := (String.num(absf(amount), precision)).split(".")
	var whole := parts[0]
	var grouped := ""
	for i in range(whole.length()):
		if i > 0 and (whole.length() - i) % 3 == 0: grouped += ","
		grouped += whole[i]
	return ("-$" if amount < 0 else "$") + grouped + ("." + (parts[1] if parts.size() > 1 else "").rpad(precision, "0") if precision > 0 else "")

static func house_result(amount: float) -> String:
	var cents := roundi(absf(amount) * 100)
	return ("+" if amount > 0 else ("-" if amount < 0 else "")) + cash(absf(amount), 0 if cents % 100 == 0 else 2)
