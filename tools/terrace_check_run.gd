extends "res://tools/harness/drive.gd"
## The terrace check (tools/terrace_check.gd) over every terraced solid in a
## scene (each node with the meta "terrace_tops", scripts/kit_isle/
## terrace_rock.gd): see-in gaps, sight through rock, floor holes and
## collision off the drawn faces, each a check that wants zero.
##   python tools/drive.py tools/terrace_check_run.gd -- --scene=studies/terrace_rock_test.tscn [--grid=1.5] [--eye-every=3] [--scene-args ...]
## --drawn=Name,Name: more nodes (by name) whose meshes count as drawn and
## whose bodies as the game's (pieces seated on the terrace; every node with
## the meta terrace_seated is counted so without it).

const TerraceCheck = preload("res://tools/terrace_check.gd")

func drive() -> void:
	await open(String(arg("scene","studies/terrace_rock_test.tscn")))
	if study == null: return
	var terraces: Array = []
	for n: Node in study.find_children("*","Node3D",true,false):
		if n.has_meta("terrace_tops"): terraces.append(n)
	check(not terraces.is_empty(),"the scene has a terrace","none with meta terrace_tops")
	# Pieces seated on a terrace (meta terrace_seated: a stair in its cut).
	var extra: Array = []
	for n: Node in study.find_children("*","Node3D",true,false):
		if n.has_meta("terrace_seated"): extra.append(n)
	for name in String(arg("drawn","")).split(",",false):
		var n := first(name)
		if n != null: extra.append(n)
	var total := {"see_in":0,"through":0,"holes":0,"standoff":0}
	for t: Node3D in terraces:
		var got: Dictionary = await TerraceCheck.sweep(t,{"grid":float(arg("grid",1.5)),"eye_every":float(arg("eye-every",3.0)),"drawn":extra,"bodies":extra})
		for k: String in total: total[k] += int(got[k])
		row({"terrace":String(t.get_path()),"samples":got.samples,"rays":got.rays,"see_in":got.see_in,"through":got.through,"holes":got.holes,"standoff":got.standoff})
	for k: String in total:
		check(int(total[k]) == 0,"%s none" % k,"%d" % int(total[k]))
		result(k,total[k])
