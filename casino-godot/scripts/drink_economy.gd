extends RefCounted
# Menu, demand and product accounting. Simulation owns physical deliveries/cash.

static func empty_stats() -> Dictionary:
	return {"sold": 0, "comped": 0, "revenue": 0.0, "product_cost": 0.0,
		"comp_cost": 0.0, "service_payroll": 0.0, "requests": 0,
		"menu_misses": 0, "price_declines": 0, "orders": 0, "unserved": 0}

static func initialize(sim) -> void:
	for id in CasinoTuning.DRINK_PROFILES:
		sim.drink_prices[id] = float(CasinoTuning.DRINK_PROFILES[id].price)
		sim.drink_stats[id] = empty_stats()

static func refresh_access(sim) -> void:
	if not sim.bar_available(): return
	var units: int = int(sim.bar_totals.sold) + int(sim.bar_totals.comped)
	for id in CasinoTuning.DRINK_PROFILES:
		if id in sim.drink_access: continue
		var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
		if sim.restricted() and (sim.casino_rating < profile.rating or units < profile.served or (profile.vip and not sim.vip_enabled)): continue
		sim.drink_access.append(id)
		# Access is an earned option; never mutate the menu here.
		if not sim.milestone_initializing:
			sim.log_event("BAR - %s unlocked. Add it through the drink menu when ready." % profile.name)

static func set_menu(sim, id: String, enabled: bool) -> void:
	if id not in sim.drink_access: return
	if enabled:
		if id not in sim.drink_menu: sim.drink_menu.append(id)
	else:
		sim.drink_menu.erase(id)
		for guest in sim.guests:
			if guest.drink_order == id:
				cancel_order(sim, guest)
				sim.think(guest, "That drink is off the menu. I'll choose again.", 2)

static func set_price(sim, id: String, price: float) -> void:
	if id not in sim.drink_access or not is_finite(price): return
	var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
	sim.drink_prices[id] = clampf(snappedf(price, CasinoTuning.DRINK_PRICE_STEP), float(profile.price_min), float(profile.price_max))
	# Existing orders retain their quoted price; new orders see the changed price.

static func eligible_state(sim, guest: Dictionary) -> bool:
	return sim.bar_available() and sim.opened and guest.state in ["Playing", "Watching", "Waiting", "At bar"] and guest.thirst >= CasinoTuning.DRINK_THIRST_TRIGGER

static func price_for(sim, guest: Dictionary, id: String, quote: float = -1) -> float:
	if sim.gambling_comp_eligible(guest, CasinoTuning.DRINK_PROFILES[id]): return 0.0
	return float(sim.drink_prices[id]) if quote < 0 else quote

static func weight(sim, guest: Dictionary, id: String) -> float:
	var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
	var prestige_taste: float = float(CasinoTuning.DRINK_PRESTIGE_TASTES[str(guest.archetype)])
	var appeal: float = float(profile.demand) * float(profile.preferences[str(guest.archetype)]) * (1.0 + float(profile.prestige) * prestige_taste)
	var price: float = price_for(sim, guest, id)
	if price > 0: appeal *= pow(float(profile.price) / price, CasinoTuning.DRINK_PRICE_ELASTICITY)
	return appeal

static func choose(sim, guest: Dictionary, choices: Array) -> String:
	if choices.is_empty(): return ""
	var total := 0.0
	for id in choices: total += weight(sim, guest, str(id))
	var draw: float = sim.rng.randf() * total
	for id in choices:
		draw -= weight(sim, guest, str(id))
		if draw <= 0: return str(id)
	return str(choices[-1])

static func willing(sim, guest: Dictionary, id: String) -> bool:
	var price: float = price_for(sim, guest, id)
	if guest.wallet < price: return false
	if price <= 0: return true
	var reference: float = float(CasinoTuning.DRINK_PROFILES[id].price)
	var acceptance: float = clampf(pow(reference / price, CasinoTuning.DRINK_PRICE_ELASTICITY), 0.0, 1.0)
	return sim.rng.randf() < acceptance

static func request(sim, guest: Dictionary) -> void:
	if not eligible_state(sim, guest) or not sim.bar_available(): return
	if guest.drink_order != "":
		var price: float = price_for(sim, guest, str(guest.drink_order), float(guest.drink_quote))
		if guest.wallet >= price: return
		sim.drink_stats[str(guest.drink_order)].price_declines += 1
		cancel_order(sim, guest)
	if sim.elapsed < int(guest.drink_request_at): return
	guest.drink_request_at = sim.elapsed + CasinoTuning.DRINK_ORDER_RETRY_MINUTES
	var desired: String = choose(sim, guest, sim.drink_access)
	if desired == "": return
	sim.drink_stats[desired].requests += 1
	var chosen := ""
	if desired not in sim.drink_menu:
		sim.drink_stats[desired].menu_misses += 1
		sim.think(guest, "I'd enjoy %s on the menu." % str(CasinoTuning.DRINK_PROFILES[desired].name).to_lower(), 2)
	elif willing(sim, guest, desired):
		chosen = desired
	else:
		sim.drink_stats[desired].price_declines += 1
		sim.think(guest, "That drink costs more than I want to spend.", 2)
	if chosen == "":
		var alternatives: Array = sim.drink_menu.filter(func(id): return id != desired)
		while not alternatives.is_empty():
			var candidate: String = choose(sim, guest, alternatives)
			alternatives.erase(candidate)
			if willing(sim, guest, candidate):
				chosen = candidate
				break
			sim.drink_stats[candidate].price_declines += 1
	if chosen == "":
		if sim.drink_menu.is_empty(): sim.think(guest, "The bar has nothing on the menu yet.", 2)
		return
	guest.drink_order = chosen
	guest.drink_quote = float(sim.drink_prices[chosen])
	sim.drink_stats[chosen].orders += 1
	if desired == chosen: sim.think(guest, "I'd like %s." % str(CasinoTuning.DRINK_PROFILES[chosen].name).to_lower())

static func cancel_order(sim, guest: Dictionary) -> void:
	if guest.drink_order != "": sim.drink_stats[str(guest.drink_order)].unserved += 1
	guest.drink_order = ""
	guest.drink_quote = 0.0

static func fulfill(sim, guest: Dictionary, id: String, price: float, comped: bool) -> void:
	var stats: Dictionary = sim.drink_stats[id]
	var cost: float = float(CasinoTuning.DRINK_PROFILES[id].cost)
	stats.revenue += price
	stats["comped" if comped else "sold"] += 1
	stats["comp_cost" if comped else "product_cost"] += cost
	guest.drink_order = ""
	guest.drink_quote = 0.0
	guest.drink_request_at = sim.elapsed + CasinoTuning.DRINK_ORDER_RETRY_MINUTES

static func contribution(sim, id: String, net: bool = false) -> float:
	var stats: Dictionary = sim.drink_stats[id]
	var gross: float = float(stats.revenue) - float(stats.product_cost) - float(stats.comp_cost)
	return gross - float(stats.service_payroll) if net else gross

static func shared_payroll(sim) -> float:
	var allocated := 0.0
	for stats in sim.drink_stats.values(): allocated += float(stats.service_payroll)
	return maxf(0, float(sim.expense_totals.service_payroll) - allocated)

static func identity(sim) -> String:
	if sim.drink_menu.is_empty(): return "Menu not set"
	var prestige := 0.0
	for id in sim.drink_menu: prestige += float(CasinoTuning.DRINK_PROFILES[id].prestige)
	prestige /= sim.drink_menu.size()
	return "Reserve lounge" if prestige >= 4 else "Cocktail bar" if prestige >= 2 else "Classic bar" if prestige >= 0.5 else "Everyday refreshments"

static func valid_snapshot(sim, data: Dictionary) -> bool:
	for field in ["drink_access", "drink_menu"]:
		if not data.get(field) is Array or data[field].size() > CasinoTuning.DRINK_PROFILES.size(): return false
		var unique := {}
		for id in data[field]:
			if not id is String or not CasinoTuning.DRINK_PROFILES.has(id) or unique.has(id): return false
			unique[id] = true
	for id in data.drink_menu:
		if id not in data.drink_access: return false
	if not data.get("drink_prices") is Dictionary or not data.get("drink_stats") is Dictionary: return false
	if data.drink_prices.size() != CasinoTuning.DRINK_PROFILES.size() or data.drink_stats.size() != CasinoTuning.DRINK_PROFILES.size(): return false
	var sums := {"sold": 0.0, "comped": 0.0, "revenue": 0.0, "product_cost": 0.0, "comp_cost": 0.0, "service_payroll": 0.0}
	for id in CasinoTuning.DRINK_PROFILES:
		var profile: Dictionary = CasinoTuning.DRINK_PROFILES[id]
		var price = data.drink_prices.get(id)
		if not sim.valid_number(price) or price < profile.price_min or price > profile.price_max or not is_equal_approx(float(price), snappedf(float(price), CasinoTuning.DRINK_PRICE_STEP)): return false
		if not data.drink_stats.get(id) is Dictionary: return false
		var stats: Dictionary = data.drink_stats[id]
		for key in empty_stats():
			if not sim.valid_number(stats.get(key)) or stats[key] < 0: return false
			if key in ["sold", "comped", "requests", "menu_misses", "price_declines", "orders", "unserved"] and stats[key] != int(stats[key]): return false
		if stats.sold + stats.comped + stats.unserved > stats.orders or stats.menu_misses > stats.requests: return false
		for key in sums: sums[key] += float(stats[key])
	for key in data.bar_totals:
		if sums.has(key) and not is_equal_approx(float(sums[key]), float(data.bar_totals[key])): return false
	return sums.service_payroll <= float(data.expense_totals.service_payroll) + 0.01
