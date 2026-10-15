extends "res://tools/harness/drive.gd"
## The generator's plan for one layer as data, headless, nothing built
## (scripts/roguelike/layer_shapes.gd `core`): its isles, its edges (the
## crossings, each lip to lip), its problems. For checking what a generator
## change did over seeds without opening run_layer (90 s a seed built).
##   python tools/godot.py -s tools/layer_dump.gd -- --shape=ring --seed=2 [--knob=gulf=60] [--isles] [--out=scratch/plan.json] [--full] [--next]
##   python tools/sweep.py tools/layer_dump.gd --seed 1..20 --shape sprawl,ring
## Prints a line per isle and per edge with --isles, the problems, and
## RESULT {seed, shape, isles, edges, kinds, gulfs, widest_gulf, longest_edge,
## problems, first_problem, plan_ms}. --out writes the summary as JSON
## (--full: the whole plan, vectors as arrays). --next lays the next region
## too (`make`, slower). Shape "" is round 3's. Args may come before or
## after --scene-args, so tools/sweep.py can hand them either way.
const LayerShapes = preload("res://scripts/roguelike/layer_shapes.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

func drive() -> void:
	var all := PackedStringArray(OS.get_cmdline_user_args())
	var shape := String(arg("shape",""))
	var seed_value := arg_int("seed",1)
	for a: String in scene_args():
		if a.begins_with("--shape="): shape = a.trim_prefix("--shape=")
		elif a.begins_with("--seed="): seed_value = int(a.trim_prefix("--seed="))
	var knobs := LayerPlan.knobs_from(all)
	var t := Time.get_ticks_msec()
	var plan: Dictionary = LayerShapes.make(shape,seed_value,knobs) if flag("next") else LayerShapes.core(shape,seed_value,knobs)
	var ms := Time.get_ticks_msec()-t
	var isles: Array = plan.get("isles",[])
	var edges: Array = plan.get("edges",[])
	var problems: Array = plan.get("problems",[])
	var kinds := {}
	var widest := 0.0
	var longest := 0.0
	var isle_rows := []
	var edge_rows := []
	for i in isles.size():
		var isle: Dictionary = isles[i]
		var r := {"i":i,"key":isle.get("key",""),"id":isle.get("id",""),"role":isle.get("role",""),
			"hood":isle.get("hood",-1),"offset":isle.get("offset",Vector3.ZERO)}
		isle_rows.append(r)
	for i in edges.size():
		var e: Dictionary = edges[i]
		var kind := String(e.get("kind",""))
		kinds[kind] = int(kinds.get(kind,0))+1
		var a: Vector3 = e.get("a",Vector3.ZERO)
		var b: Vector3 = e.get("b",Vector3.ZERO)
		var across := Vector2(a.x-b.x,a.z-b.z).length()
		longest = maxf(longest,across)
		var r := {"i":i,"kind":kind,"branch":e.get("branch",""),"from":e.get("from",[]),"to":e.get("to",[]),
			"a":a,"b":b,"across":across,"rise":b.y-a.y}
		if kind == "gulf":
			r["width"] = e.get("width",across)
			r["ride"] = e.get("ride","")
			widest = maxf(widest,float(e.get("width",across)))
		var stones: Variant = e.get("stones")
		if stones is Array: r["stones"] = (stones as Array).size()
		if e.get("trap") != null: r["trap"] = str(e.get("trap"))
		edge_rows.append(r)
	if flag("isles"):
		for r: Dictionary in isle_rows:
			note("isle %2d %-24s %-6s hood %d at %s" % [r.i,str(r.id),str(r.role),int(r.hood),(r.offset as Vector3).round()])
		for r: Dictionary in edge_rows:
			note("edge %2d %-7s %-6s %s -> %s  %.1f m across, %+.1f m rise%s" % [r.i,r.kind,str(r.branch),str(r.from),str(r.to),
				float(r.across),float(r.rise),(" (%s)" % r.ride) if r.has("ride") else ""])
	for p: Variant in problems: note("problem: %s" % str(p))
	result("seed",seed_value)
	result("shape",shape)
	result("attempt",plan.get("attempt",-1))
	result("isles",isles.size())
	result("edges",edges.size())
	result("kinds",kinds)
	result("gulfs",int(kinds.get("gulf",0)))
	result("widest_gulf",widest)
	result("longest_edge",longest)
	result("problems",problems.size())
	result("first_problem",str(problems[0]) if not problems.is_empty() else "")
	result("plan_ms",ms)
	# The run's world (scripts/roguelike/layer_worlds.gd): its region and the
	# motifs it drew (each id once, with its count).
	var LayerWorlds: GDScript = load("res://scripts/roguelike/layer_worlds.gd")
	result("world",LayerWorlds.of(plan))
	result("region",LayerWorlds.region_of(plan))
	var drawn := {}
	for r: Dictionary in isle_rows:
		if str(r.role) != "base": drawn[str(r.id)] = int(drawn.get(str(r.id),0))+1
	var listed := PackedStringArray()
	for id: String in drawn: listed.append("%s x%d" % [id,int(drawn[id])] if int(drawn[id]) > 1 else id)
	result("motifs"," ".join(listed))
	var out := String(arg("out",""))
	if out != "":
		var data: Variant = plan if flag("full") else {"seed":seed_value,"shape":shape,"knobs":plan.get("knobs",{}),
			"problems":problems,"isles":isle_rows,"edges":edge_rows,"route":plan.get("route",[]),
			"spawn":plan.get("spawn"),"exit":plan.get("exit"),"plan_ms":ms}
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out).get_base_dir())
		var f := FileAccess.open(out,FileAccess.WRITE)
		f.store_string(JSON.stringify(_plain(data),"  "))
		f.close()
		print("saved %s" % out)
	check(problems.is_empty(),"%s seed %d plans with no problems" % [shape if shape != "" else "round3",seed_value],
		"" if problems.is_empty() else str(problems[0]))
