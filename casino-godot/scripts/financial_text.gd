extends RefCounted
# Presentation only. Settlement amounts and importance come from the simulation.
static func cash(amount: float) -> String:
	return ("-$" if amount < 0 else "$") + ("%.2f" % absf(amount))

static func house_result(amount: float) -> String:
	return ("+" if amount > 0 else ("-" if amount < 0 else "")) + ("$%.2f" % absf(amount))
