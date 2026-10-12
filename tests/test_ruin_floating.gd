extends SceneTree
## No ruin piece leaves a stone hanging in the air (docs/design/
## plane-ground-scale.md, "Opening ratio 1.0 + collision audit"), headless:
## each kit piece whose ruin takes stones away by rule (a lost crown, a
## torn head, a broken tracery: RuinKit Build `drop_floating`) is built at
## four weatherings and four seeds, and the floating-stone check (Build
## `check_floating`: every drawn block joined to the ground through blocks
## touching) finds none left. The user's screenshot: a lancet's oculus, a
## fixed 0.5 m ring in a window grown to 6.8 m, one stone of it hanging in
## the window's head. Its oculus is sized to the window and rests on the
## lights' heads; broken tracery has none.
##   godot --headless --path . --script tests/test_ruin_floating.gd
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The pieces that drop what their ruin leaves resting on nothing.
const DROPPING := ["arch","lancet_wall","rose_gable","buttress","wall","aqueduct_end"]
const WEATHERINGS := [0.0,0.35,0.6,1.0]
const SEEDS := [7,11,20,31]

var failures := 0

func _initialize() -> void:
	RuinKit.Build.check_floating = true
	for id: String in DROPPING:
		var found := 0
		var where := ""
		for w: float in WEATHERINGS:
			for s: int in SEEDS:
				var before := RuinKit.Build.floaters.size()
				var node := RuinKit.piece(id,s,w)
				node.free()
				var more := RuinKit.Build.floaters.size()-before
				if more > 0 and where == "":
					where = " (first: seed %d, weathered %.2f, at %s)" % [s,w,str((RuinKit.Build.floaters[before].box as AABB).position.snapped(Vector3.ONE*0.01))]
				found += more
		check(found == 0,"%s: no stone resting on nothing over %d builds (%d)%s" % [id,WEATHERINGS.size()*SEEDS.size(),found,where])
	RuinKit.Build.check_floating = false
	RuinKit.Build.floaters.clear()
	print("PASS: ruin floating" if failures == 0 else "FAIL: ruin floating (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)
