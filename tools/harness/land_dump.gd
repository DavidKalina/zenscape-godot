extends "res://tools/harness/drive.gd"
## The flight's land as a grid of heights, for tools that search it
## (tools/fall_sites.py). Writes `--out` (a res:// or absolute path): one
## line of JSON (cx, cz, r, step, n, sea, seed args as run), then n*n
## float32 ground heights (world y), then n*n float32 river or pond water
## levels (NaN where dry), rows z from cz-r, columns x from cx-r.
##
##   python tools/drive.py tools/harness/land_dump.gd --timeout 900 -- --out=res://scratch/land.bin --r=10000 --step=20 --scene-args --no-placed
##
## `--no-placed` gives the land without the hand-placed sites' cuts.
const Field = preload("res://scripts/endless/land_field.gd")

func drive() -> void:
	await open("studies/endless_flight.tscn")
	var f: RefCounted = study.field
	var r := arg_float("r", 5000.0)
	var step := arg_float("step", 20.0)
	var cx := arg_float("cx", 0.0)
	var cz := arg_float("cz", 0.0)
	var out: String = arg("out", "res://scratch/land.bin")
	var n := int(2.0*r/step)+1
	var h := PackedFloat32Array(); h.resize(n*n)
	var w := PackedFloat32Array(); w.resize(n*n)
	for j in n:
		var z := cz-r+j*step
		for i in n:
			var x := cx-r+i*step
			h[j*n+i] = f.height(x, z)
			w[j*n+i] = f.river_y(x, z)
	var file := FileAccess.open(out, FileAccess.WRITE)
	check(file != null, "opened %s" % out)
	if file == null: return
	file.store_line(JSON.stringify({"cx": cx, "cz": cz, "r": r, "step": step, "n": n, "sea": Field.SEA_Y}))
	file.store_buffer(h.to_byte_array())
	file.store_buffer(w.to_byte_array())
	file.close()
	say("wrote %s: %d x %d at %.0f m" % [out, n, n, step])
	result("n", n)
