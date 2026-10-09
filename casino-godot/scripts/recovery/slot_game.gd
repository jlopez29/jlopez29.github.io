extends "res://scripts/recovery/minigame_base.gd"
var modules: Array[Button] = []
var switches: Array[Button] = []
var lamps: Array[Label] = []
func build() -> void:
	var art := preload("res://scripts/recovery/desk_art.gd").new()
	art.category=2
	add_child(art)
	UI.text(self,"CONTROLLER DIAGNOSTIC",24)
	UI.text(self,"Inspect a module to diagnose the fault. Flip the three switches until the test lamps match their targets.")
	lesson("XOR means DIFFERENT values: 0 XOR 1 = 1; 1 XOR 0 = 1; 0 XOR 0 = 0; 1 XOR 1 = 0. The last lamp reads A directly. Work backward from A to B to C.")
	for i in range(3):
		modules.append(UI.button(self,["[POWER] Stable supply / OK","[REEL] Sensor test / OK","[CIRCUIT] Controller self-test / FAULT"][i],func(): draft.choice=i; refresh()))
	var console := UI.card(self,Color("202b33"))
	UI.text(console,"SWITCH BANK / LIVE TEST",18)
	var row := HBoxContainer.new()
	console.add_child(row)
	for i in range(3):
		var rocker := UI.button(row,"",func(): draft.mask=int(draft.get("mask",0))^(1<<i); refresh())
		rocker.size_flags_horizontal=SIZE_EXPAND_FILL
		switches.append(rocker)
	for i in range(3): lamps.append(UI.text(console,"",19))
	refresh()
func refresh() -> void:
	var mask := int(draft.get("mask",0))
	var a := mask&1
	var b := (mask>>1)&1
	var c := (mask>>2)&1
	var values := [a^b,b^c,a]
	for i in range(3):
		UI.mark(modules[i],int(draft.get("choice",-1))==i)
		switches[i].text="%s %s (%d)" % [char(65+i),"ON" if mask&(1<<i) else "OFF",(mask>>i)&1]
		UI.mark(switches[i],bool(mask&(1<<i)))
		lamps[i].text="%s   Actual %d / Target %d   [%s]" % [["A XOR B","B XOR C","A"][i],values[i],puzzle.lamps[i],"MATCH" if values[i]==puzzle.lamps[i] else "ADJUST"]
		lamps[i].add_theme_color_override("font_color",Color("a5d6ac") if values[i]==puzzle.lamps[i] else Color("efc27b"))
