extends "res://scripts/recovery/minigame_base.gd"
var slips: Array[Button] = []
var balance: Label
var comparison: Label
var pinned: Label
var entry: LineEdit
var receipts: GridContainer
func build() -> void:
	response_keys=["choice", "number"]
	UI.text(self,"CAGE / CASH RECONCILIATION",24)
	UI.text(self,"Pin a receipt. Count recorded minus verified into the ledger.")
	receipts=GridContainer.new()
	receipts.add_theme_constant_override("h_separation",12)
	add_child(receipts)
	for i in range(3):
		var slip := UI.object(receipts,"receipt","Recorded  $%d" % puzzle.recorded[i],"Verified   $%d" % puzzle.verified[i],func(): draft.choice=i; refresh())
		slip.serial=char(65+i)
		slips.append(slip)
	var ledger := UI.paper(self,"CASHIER'S RECONCILIATION LEDGER")
	pinned=UI.text(ledger,"")
	balance=UI.text(ledger,"",32)
	comparison=UI.text(ledger,"",16)
	var tokens := GridContainer.new()
	tokens.columns=3
	ledger.add_child(tokens)
	for amount in [-25,-5,-1,25,5,1]:
		UI.object(tokens,"token",("+" if amount>0 else "-")+"$"+str(absi(amount)),"dollars",func(): draft.number=int(draft.get("number",0))+amount; refresh())
	UI.text(ledger,"Signed difference / type or count with chips",15)
	entry=LineEdit.new()
	entry.custom_minimum_size.y=48
	entry.placeholder_text="Signed difference, e.g. -15"
	entry.virtual_keyboard_type=LineEdit.KEYBOARD_TYPE_NUMBER
	ledger.add_child(entry)
	entry.text_changed.connect(func(value):
		if value.is_valid_int(): draft.number=int(value); refresh(false))
	lesson("Recorded - Verified = difference. Example: recorded $35 minus verified $50 = -$15. Use a negative sign when recorded is lower.")
	resized.connect(reflow)
	reflow()
	refresh()
func reflow() -> void:
	receipts.columns=3 if size.x>=680 else 1
func refresh(sync_entry: bool = true) -> void:
	var selected := int(draft.get("choice",-1))
	for i in range(slips.size()): slips[i].selected=selected==i
	var count := int(draft.get("number",0))
	if sync_entry: entry.text=str(count)
	pinned.text="PINNED: RECEIPT "+char(65+selected) if selected>=0 else "No receipt pinned / choose one above"
	balance.text="%s$%d  /  %s" % ["-" if count<0 else "+",absi(count),"SHORTAGE" if count<0 else "OVERAGE" if count>0 else "BALANCED"]
	comparison.text="Draft count only / Verify records your answer."
	if selected>=0:
		comparison.text="Recorded $%d - draft (%d) = $%d
Compare your adjusted total with verified $%d." % [puzzle.recorded[selected],count,puzzle.recorded[selected]-count,puzzle.verified[selected]]
