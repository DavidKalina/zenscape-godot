extends "res://tools/harness/drive.gd"
## tools/rail_line.py's half in Godot: the land's own height and river water
## at a list of world XZ points, read from the live field (`study.field`) of
## the main scene opened headless. Nothing is built or streamed.
##   --in=FILE   {"pts": [[x, z], ...]}
##   --out=FILE  {"ground": [y, ...], "river": [y or null, ...], "sea": y}
## Scene flags go after --scene-args (the seed, --no-railroad).

func drive() -> void:
	await open("studies/endless_flight.tscn")
	var f: RefCounted = study.field
	var src := FileAccess.get_file_as_string(str(arg("in", "")))
	var data: Dictionary = JSON.parse_string(src)
	var pts: Array = data.get("pts", [])
	var ground: Array = []
	var river: Array = []
	ground.resize(pts.size())
	river.resize(pts.size())
	for i in pts.size():
		var p: Array = pts[i]
		var x := float(p[0])
		var z := float(p[1])
		ground[i] = snappedf(float(f.height(x, z)), 0.01)
		var r := float(f.river_y(x, z))
		river[i] = null if is_nan(r) else snappedf(r, 0.01)
	var out := str(arg("out", "scratch/rail/sample.json"))
	var fa := FileAccess.open(out, FileAccess.WRITE)
	check(fa != null, "opened " + out)
	fa.store_string(JSON.stringify({"ground": ground, "river": river, "sea": f.SEA_Y}))
	fa.close()
	result("points", pts.size())
