extends SceneTree
## The terrace rock builder (scripts/kit_isle/terrace_rock.gd), headless, on
## its test shape (studies/terrace_rock_test.tscn: nested tiers, a tier run
## out past the rim, one over a lower riser, a grand stair seated in a cut):
## the terrace check (tools/terrace_check.gd) finds no see-in gap, no sight
## through rock, no floor hole and no collision off the drawn faces.
##   godot --headless --path . --script tests/test_terrace_rock.gd
const TerraceCheck = preload("res://tools/terrace_check.gd")
var failures := 0

## The scene swept and its name (tests/test_stair_clouds_terrace.gd sweeps
## the Stair to the Clouds instead).
func scene() -> String: return "res://studies/terrace_rock_test.tscn"
func label() -> String: return "terrace rock"

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(300.0).timeout.connect(func() -> void: push_error("%s test timed out" % label()); quit(2))
	var study: Node3D = load(scene()).instantiate()
	study.set("scripted",true)
	root.add_child(study)
	current_scene = study
	while not study.get("walk_ready"): await process_frame
	for i in range(3): await physics_frame
	await sweep_all(study,label())
	print(("PASS: %s" % label()) if failures == 0 else "FAIL: %s (%d)" % [label(),failures])
	quit(1 if failures else 0)

## Every terraced solid under `study` (meta terrace_tops) swept, with the
## pieces seated on it (meta terrace_seated) counted as drawn and walked.
func sweep_all(study: Node3D, label: String) -> void:
	var terraces: Array = []
	var seated: Array = []
	for n: Node in study.find_children("*","Node3D",true,false):
		if n.has_meta("terrace_tops"): terraces.append(n)
		if n.has_meta("terrace_seated"): seated.append(n)
	check(terraces.size() == 1,"%s: one terraced solid (%d)" % [label,terraces.size()])
	check(not seated.is_empty(),"%s: a grand stair seated in its cut (%d seated)" % [label,seated.size()])
	for t: Node3D in terraces:
		var got: Dictionary = await TerraceCheck.sweep(t,{"drawn":seated,"bodies":seated,"quiet":true})
		check(int(got.samples) > 100,"%s: %d floor samples, %d rays" % [label,int(got.samples),int(got.rays)])
		for k: String in ["see_in","through","holes","standoff"]:
			check(int(got[k]) == 0,"%s: %s none (%d, first at %s)" % [label,k,int(got[k]),str((got.get(k+"_at",[]) as Array).slice(0,4))])
