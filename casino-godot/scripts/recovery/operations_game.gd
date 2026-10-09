extends "res://scripts/recovery/minigame_base.gd"
var workers: Array[Button] = []
var lanes: Array[Label] = []
var budget: Label
var gauge: ProgressBar
var aisle: Button
var aisle_layout: Control
func build() -> void:
	var art := preload("res://scripts/recovery/desk_art.gd").new()
	art.category=3
	add_child(art)
	UI.text(self,"STAFF THE CAGE SHIFTS",24)
	UI.text(self,"Tap worker cards to assign or remove them. Each worker covers the listed shifts. Move the supply cart out of the emergency aisle before verifying.")
	lesson("Add each selected worker's cost once. A morning + afternoon worker counts in both lanes. Meet every shift's need within budget; people must have a clear emergency exit.")
	var board := UI.card(self)
	var drop := preload("res://scripts/recovery/staffing_board.gd").new()
	board.add_child(drop)
	drop.worker_dropped.connect(func(index): draft.mask=int(draft.get("mask",0))|(1<<index); refresh())
	UI.text(drop,"DROP WORKER HERE / or tap a worker card",16)
	for i in range(3): lanes.append(UI.text(drop,"",19))
	budget=UI.text(board,"")
	gauge=ProgressBar.new()
	gauge.show_percentage=false
	gauge.max_value=puzzle.budget
	board.add_child(gauge)
	for i in range(4):
		var shifts: Array[String]=[]
		for j in range(3):
			if puzzle.coverage[i][j]: shifts.append(["Morning","Afternoon","Night"][j])
		var worker := preload("res://scripts/recovery/worker_card.gd").new()
		worker.worker_index=i
		worker.text="WORKER %s / $%d / %s" % [char(65+i),puzzle.costs[i]," + ".join(shifts)]
		worker.custom_minimum_size.y=48
		worker.pressed.connect(func(): draft.mask=int(draft.get("mask",0))^(1<<i); refresh())
		add_child(worker)
		worker.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		workers.append(worker)
	var lane := UI.card(self,Color("373027"))
	UI.text(lane,"EMERGENCY EXIT  >>>  AISLE  >>>",18)
	aisle_layout=preload("res://scripts/recovery/aisle_board.gd").new()
	lane.add_child(aisle_layout)
	aisle=UI.button(lane,"",func(): draft.aisle=not bool(draft.get("aisle",false)); refresh())
	refresh()
func refresh() -> void:
	var mask := int(draft.get("mask",0))
	var cost := 0
	var coverage := [0,0,0]
	for i in range(4):
		UI.mark(workers[i],bool(mask&(1<<i)))
		if mask&(1<<i):
			cost+=int(puzzle.costs[i])
			for j in range(3): coverage[j]+=int(puzzle.coverage[i][j])
	for j in range(3):
		lanes[j].text="%s / Need %d / Assigned %d / %s" % [["MORNING","AFTERNOON","NIGHT"][j],puzzle.required[j],coverage[j],"COVERED" if coverage[j]>=puzzle.required[j] else "NEEDS STAFF"]
	budget.text="Budget used $%d / Limit $%d %s" % [cost,puzzle.budget,"[OVER BUDGET]" if cost>puzzle.budget else ""]
	budget.add_theme_color_override("font_color",Color("f0a397") if cost>puzzle.budget else Color("eae4d6"))
	gauge.value=cost
	var clear := bool(draft.get("aisle",false))
	aisle_layout.clear=clear
	aisle.text="[CLEAR >>>] Cart in storage bay / Move into aisle" if clear else "[BLOCKED: SUPPLY CART] Move cart to storage bay"
	aisle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	UI.mark(aisle,clear)
