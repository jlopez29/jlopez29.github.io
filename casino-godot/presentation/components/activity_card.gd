extends PanelContainer
const Art = preload("res://scripts/pit_boss_theme.gd")
var signature := ""
func configure(event: Dictionary, latest: bool) -> void:
	var key := str(event) + str(latest)
	if signature == key: return
	signature = key
	var category: String = event.category
	var icon := "status/info"
	var color := Art.GOLD
	if category == "VIP": icon = "status/vip"
	elif category in ["BREAKDOWN", "REPAIR"]: icon = "status/maintenance"; color = Color("e5aa67")
	elif category == "STAFF": icon = "navigation/staff"
	elif category == "SERVICE": icon = "gameplay/drink"; color = Color("b6cdbb")
	elif category == "RESERVE": icon = "gameplay/cash"; color = Color("e9a07f")
	elif category in ["SLOTS", "CRAPS", "ROULETTE", "BLACKJACK"]: icon = "status/jackpot"
	$Row/Icon.texture = Art.texture("icons/" + icon + ".svg")
	$Row/Icon.modulate = color
	$Row/Text/Category.text = category
	$Row/Text/Category.modulate = color
	$Row/Text/Body.text = event.body
	modulate.a = 1.0 if latest else 0.85
