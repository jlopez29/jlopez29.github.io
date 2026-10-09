extends "res://scripts/recovery/minigame_base.gd"
var slips: Array[Button] = []
var balance: Label
var entry: LineEdit
func build() -> void:
	var art := preload("res://scripts/recovery/desk_art.gd").new()
	art.category=0
	add_child(art)
	UI.text(self, "RECONCILE THE DRAWER", 24)
	UI.text(self, "Tap the mismatched receipt, then count its signed discrepancy into the ledger. This is a practice drawer.")
	lesson("Recorded - Verified = difference. Example: recorded $35 minus verified $50 = -$15. A shortage needs a negative sign.")
	for i in range(3):
		var slip := UI.button(self, "RECEIPT %s   |   Verified $%d   /   Recorded $%d" % [char(65+i),puzzle.verified[i],puzzle.recorded[i]], func(): draft.choice=i; refresh())
		slip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		slip.alignment = HORIZONTAL_ALIGNMENT_LEFT
		slips.append(slip)
	var tray := UI.card(self, Color("352c23"))
	UI.text(tray, "SIGNED COUNTING TRAY", 18)
	var tokens := GridContainer.new()
	tokens.columns = 3
	tray.add_child(tokens)
	for amount in [-25,-5,-1,25,5,1]:
		UI.button(tokens, ("+" if amount>0 else "-")+"$"+str(absi(amount)), func(): draft.number=int(draft.get("number",0))+amount; refresh())
	entry = LineEdit.new()
	entry.custom_minimum_size.y=48
	entry.placeholder_text="Signed difference, e.g. -15"
	entry.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	tray.add_child(entry)
	entry.text_changed.connect(func(value):
		if value.is_valid_int(): draft.number=int(value); refresh(false))
	balance = UI.text(tray, "")
	refresh()
func refresh(sync_entry: bool = true) -> void:
	for i in range(slips.size()):
		var selected: bool=int(draft.get("choice",-1))==i
		slips[i].add_theme_stylebox_override("normal", UI.WorkbenchTheme.box(Color("514526") if selected else Color("ddd0b3"),UI.WorkbenchTheme.GOLD if selected else Color("776342"),14))
		slips[i].add_theme_color_override("font_color",Color("f6e6bf") if selected else Color("292721"))
	var count := int(draft.get("number",0))
	if sync_entry: entry.text=str(count)
	var selected := int(draft.get("choice",-1))
	balance.text = "Tray difference: %s$%d" % ["-" if count<0 else "+",absi(count)]
	if selected>=0:
		balance.text += "\nLedger comparison: recorded $%d - your difference (%d) = $%d; verified $%d" % [puzzle.recorded[selected],count,puzzle.recorded[selected]-count,puzzle.verified[selected]]
