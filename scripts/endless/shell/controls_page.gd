extends "res://scripts/endless/shell/shell_page.gd"
## Controls: the flight's keys, mouse and pad buttons (README's Play section,
## pad.gd's ACTIONS), the pad's drawn as glyphs read from the InputMap.

## Each row: what it does, the keys ("or" and "twice" drawn as plain
## words, the rest as caps), and the pad actions or glyph ids.
const ROWS := [
	["Bank and pitch",["W","A","S","D"],["LS"]],
	["Steer",["Mouse"],["LS"]],
	["Boost",["Space"],[&"fly_boost"]],
	["Brake",["Shift"],[&"fly_brake"]],
	["Knife edge (hold)",["Q","E"],[&"fly_lean_left",&"fly_lean_right"]],
	["Barrel roll",["Z","or","Q","E","twice"],[&"fly_roll"]],
	["Flaps, land",["F"],[&"fly_land"]],
	["Surge (full meter)",["B"],[&"fly_surge"]],
	["Look round (hold)",["Right mouse"],["RS"]],
	["Race a plane (hold)",["Tab"],[&"fly_challenge"]],
	["Weight",["V"],[&"fly_weight"]],
	["Pace",["P"],[&"fly_pace"]],
	["Back into the air",["R"],[]],
	["Logbook",["J"],[]],
	["Photo mode",["O"],[&"photo"]],
	["Numbers",["F1"],[]],
	["Graphics preset",["F3"],[]],
	["Pause",["Esc"],[&"menu"]],
]

func _init(_shell: Node) -> void:
	super()
	title = "Controls"
	width = 720.0
	var rows: Array = []
	for r: Array in ROWS:
		var keys: Array = r[1]
		var pad: Array = []
		for p: Variant in r[2]:
			var g := Pad.glyph(p) if p is StringName else str(p)
			if g != "": pad.append(g)
		rows.append({"kind":"keys","text":str(r[0]),"keys":keys,"pad":pad})
	rows.append({"kind":"gap"})
	rows.append({"kind":"note","text":"Land on any flat turf; stopped, Space or the right trigger rolls it off again. The pad's A, B and the d-pad work every menu."})
	set_rows(rows)
