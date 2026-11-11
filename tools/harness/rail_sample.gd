extends "res://tools/harness/drive.gd"
## tools/rail_line.py's half in Godot: the land's own height and river water
## at a list of world XZ points, read from the live field (`study.field`) of
## the main scene opened headless. Nothing is built or streamed.
##   --in=FILE   {"pts": [[x, z], ...]}
##   --out=FILE  {"ground": [y, ...], "river": [y or null, ...], "bench": [y or
##               null, ...], "sea": y}; bench: the Peak shelf's bench top under
##               the point (world y), null off it or with no shelf
## Scene flags go after --scene-args (the seed, --no-railroad).

func drive() -> void:
	await open("studies/endless_flight.tscn")
	var f: RefCounted = study.field
	var src := FileAccess.get_file_as_string(str(arg("in", "")))
	var data: Dictionary = JSON.parse_string(src)
	var pts: Array = data.get("pts", [])
	var ground: Array = []
	var river: Array = []
	var bench: Array = []
	ground.resize(pts.size())
	river.resize(pts.size())
	bench.resize(pts.size())
	var pk: RefCounted = f.peak() if f.has_method("peak") else null
	var body: RefCounted = pk.body if pk != null and pk.shaped() else null
	var shelf: Dictionary = body.shelf if body != null else {}
	for i in pts.size():
		var p: Array = pts[i]
		var x := float(p[0])
		var z := float(p[1])
		ground[i] = snappedf(float(f.height(x, z)), 0.01)
		var r := float(f.river_y(x, z))
		river[i] = null if is_nan(r) else snappedf(r, 0.01)
		bench[i] = null
		if not shelf.is_empty():
			var q: Vector2 = Vector2(x, z) - (pk.centre as Vector2)
			var at: Vector4 = body.shelf_at(q.dot(pk.facing), q.dot(pk.side))
			if at.w > 0.5 and absf(at.x) < 0.5 * at.z:
				var cant := float(body._shelf_cfg.cant)
				bench[i] = snappedf(float(body.shelf_y(at.y)) - cant * at.x + float(f.SEA_Y), 0.01)
	var out := str(arg("out", "scratch/rail/sample.json"))
	var fa := FileAccess.open(out, FileAccess.WRITE)
	check(fa != null, "opened " + out)
	fa.store_string(JSON.stringify({"ground": ground, "river": river, "bench": bench, "sea": f.SEA_Y}))
	fa.close()
	result("points", pts.size())
