extends "res://scripts/recovery/minigame_base.gd"
var records: Array[Button] = []
var stamps: Array[Button] = []
var documents: Array[Label] = []
var paired: GridContainer
func build() -> void:
	var art := preload("res://scripts/recovery/desk_art.gd").new()
	art.category=1
	add_child(art)
	UI.text(self, "TRACE THE CASH DELIVERY", 24)
	UI.text(self, "Inspect each dispatch and receipt pair. Mark a suspicious transfer and attach the evidence stamp.")
	lesson("Seals and bundle counts must agree. A receipt must follow dispatch: dispatch 11:10 / receipt 11:05 is impossible. Inspect records; identity is never evidence.")
	for i in range(3):
		records.append(UI.button(self,"CASE %s  /  Inspect %s" % [char(65+i),puzzle.records[i].name],func(): draft.choice=i; refresh()))
	var file := UI.card(self, Color("29323a"))
	paired=GridContainer.new()
	paired.columns=2
	paired.add_theme_constant_override("h_separation",12)
	file.add_child(paired)
	for title in ["DISPATCH","RECEIPT"]:
		var document := UI.card(paired,Color("343c42"))
		UI.text(document,title,18)
		documents.append(UI.text(document,"Tap a case to inspect.",18))
	resized.connect(func(): paired.columns=2 if size.x>550 else 1)
	UI.text(self,"ATTACH EVIDENCE STAMP",18)
	for i in range(3):
		stamps.append(UI.button(self,["[SEAL] Seal mismatch","[CLOCK] Receipt before dispatch","[BUNDLES] Bundle mismatch"][i],func(): draft.reason=i; refresh()))
	refresh()
func refresh() -> void:
	var selected := int(draft.get("choice",-1))
	for i in range(records.size()): UI.mark(records[i],selected==i)
	for i in range(stamps.size()): UI.mark(stamps[i],int(draft.get("reason",-1))==i)
	if selected<0: return
	var r: Dictionary=puzzle.records[selected]
	for i in range(2):
		var record: Dictionary=r.dispatch if i==0 else r.receipt
		documents[i].text="%s\nSeal #%d\nClock %s\nBundles %d" % [r.name,record.seal,record.time,record.count]
