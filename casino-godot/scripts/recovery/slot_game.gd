extends "res://scripts/recovery/minigame_base.gd"
var modules: Array[Button] = []
var switches: Array[Button] = []
var lamps: Array[Control] = []
var matched: Label
var compartments: GridContainer
var lamp_grid: GridContainer
func build() -> void:
	response_keys=["choice", "mask"]
	UI.text(self,"SLOT SERVICE / DIAGNOSTIC CONSOLE",24)
	UI.text(self,"Inspect the faulty module. Set A, B and C to match all test lamps.")
	compartments=GridContainer.new()
	compartments.add_theme_constant_override("h_separation",10)
	add_child(compartments)
	for i in range(3):
		var module := UI.object(compartments,"module",["POWER","REEL SENSOR","CONTROLLER"][i],["Supply stable / OK","Sensor passed / OK","Self-test / FAULT"][i],func(): draft.choice=i; refresh())
		module.serial=char(65+i)
		modules.append(module)
	var console := UI.card(self,Color("202b2b"))
	UI.text(console,"SWITCH BANK / ON = 1",18)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",12)
	console.add_child(row)
	for i in range(3):
		var rocker := UI.object(row,"rocker",char(65+i),"",func(): draft.mask=int(draft.get("mask",0))^(1<<i); refresh())
		rocker.serial=char(65+i)
		switches.append(rocker)
	UI.text(console,"OUTPUT BUS / ACTUAL vs TARGET",18)
	lamp_grid=GridContainer.new()
	lamp_grid.add_theme_constant_override("h_separation",12)
	console.add_child(lamp_grid)
	for i in range(3):
		var lamp := preload("res://scripts/recovery/indicator_lamp.gd").new()
		lamp.caption=["A XOR B","B XOR C","A"][i]
		lamp.size_flags_horizontal=SIZE_EXPAND_FILL
		lamp_grid.add_child(lamp)
		lamps.append(lamp)
	matched=UI.text(console,"",18)
	lesson("XOR means DIFFERENT values: 0 XOR 1 = 1; 1 XOR 0 = 1; 0 XOR 0 = 0; 1 XOR 1 = 0. The last lamp reads A directly. Work backward from A to B to C.")
	resized.connect(reflow)
	reflow()
	refresh()
func reflow() -> void:
	compartments.columns=3 if size.x>=700 else 1
	lamp_grid.columns=3 if size.x>=800 else 1
func refresh() -> void:
	var mask := int(draft.get("mask",0))
	var a := mask&1
	var b := (mask>>1)&1
	var c := (mask>>2)&1
	var values := [a^b,b^c,a]
	for i in range(3):
		modules[i].selected=int(draft.get("choice",-1))==i
		switches[i].selected=bool(mask&(1<<i))
		switches[i].text="Switch %s / %s" % [char(65+i),"ON" if switches[i].selected else "OFF"]
		lamps[i].update(values[i],int(puzzle.lamps[i]))
	matched.text="SYSTEM TEST MATCHED / draft ready to Verify" if values==puzzle.lamps else "TEST IN PROGRESS / adjust the switch bank"
	matched.add_theme_color_override("font_color",Color("a5d6ac") if values==puzzle.lamps else Color("efc27b"))
