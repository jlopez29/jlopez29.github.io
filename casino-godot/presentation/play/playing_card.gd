extends TextureRect
const Art = preload("res://scripts/pit_boss_theme.gd")
const SUITS := ["spades", "hearts", "diamonds", "clubs"]
# CasinoGames.card_name/total: IDs 0..12 are 2..A spades, then hearts/diamonds/clubs.
static func asset_for(card_id: int, hidden: bool = false) -> String:
	if hidden: return "casino_play/shared/cards/card_back.svg"
	assert(card_id >= 0 and card_id < 52)
	var rank := card_id % 13 + 2
	return "casino_play/shared/cards/%s_%s.svg" % [{11: "J", 12: "Q", 13: "K", 14: "A"}.get(rank, str(rank)), SUITS[card_id / 13]]
func _init() -> void:
	expand_mode = EXPAND_IGNORE_SIZE
	stretch_mode = STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = MOUSE_FILTER_IGNORE
func show_card(card_id: int, hidden: bool = false) -> void:
	var image := Art.texture(asset_for(card_id, hidden))
	if texture != image: texture = image
