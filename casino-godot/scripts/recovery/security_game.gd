extends "res://scripts/recovery/minigame_base.gd"
var records: Array[Button] = []
var stamps: Array[Button] = []
var documents: Array[Label] = []
var paired: GridContainer
var attached: Label
var folders: GridContainer
func build() -> void:
	response_keys=["choice", "reason"]
	UI.text(self,"SECURITY / DELIVERY CASE DESK",24)
	UI.text(self,"Open a case folder. Compare both documents and attach evidence.")
	folders=GridContainer.new()
	folders.add_theme_constant_override("h_separation",12)
	add_child(folders)
	for i in range(3):
		var folder := UI.object(folders,"folder",puzzle.records[i].name,"DISPATCH + RECEIPT",func(): draft.choice=i; refresh())
		folder.serial=char(65+i)
		records.append(folder)
	paired=GridContainer.new()
	paired.add_theme_constant_override("h_separation",12)
	paired.add_theme_constant_override("v_separation",12)
	add_child(paired)
	for title in ["DISPATCH / OUTBOUND","RECEIPT / CAGE COPY"]:
		var document := UI.paper(paired,title)
		documents.append(UI.text(document,"Open a folder to inspect.

TIME
SEAL
BUNDLES
RUNNER",18))
	attached=UI.text(self,"")
	for i in range(3):
		stamps.append(UI.object(self,"stamp",["SEAL MISMATCH","INVALID TIMELINE","BUNDLE MISMATCH"][i],"",func(): draft.reason=i; refresh()))
	lesson("Seals and bundle counts must agree. A receipt must follow dispatch: dispatch 11:10 / receipt 11:05 is impossible. Runner identity is never evidence.")
	resized.connect(reflow)
	reflow()
	refresh()
func reflow() -> void:
	paired.columns=2 if size.x>=620 else 1
	folders.columns=3 if size.x>=720 else 1
func refresh() -> void:
	var selected := int(draft.get("choice",-1))
	var reason := int(draft.get("reason",-1))
	for i in range(records.size()): records[i].selected=selected==i
	for i in range(stamps.size()):
		stamps[i].selected=reason==i
		stamps[i].footer="ATTACHED TO CASE "+char(65+selected) if selected>=0 else "SELECT A CASE"
		stamps[i].queue_redraw()
	attached.text="CASE %s / %s" % [char(65+selected),["Seal mismatch","Invalid timeline","Bundle mismatch"][reason] if reason>=0 else "No evidence attached"] if selected>=0 else "Choose a case and an evidence stamp."
	if selected<0: return
	var r: Dictionary=puzzle.records[selected]
	for i in range(2):
		var record: Dictionary=r.dispatch if i==0 else r.receipt
		documents[i].text="TIMESTAMP     %s

SEAL NUMBER   #%d

BUNDLE COUNT  %d

RUNNER ID     %s" % [record.time,record.seal,record.count,r.name]
