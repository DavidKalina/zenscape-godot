extends SceneTree
## Holding on to the hat in a real host, headless: the pocket sail study
## (studies/pocket_sail_study.tscn, a studies/character_study.gd, as the
## kit isles are), where the sail's figure (scripts/pocket_sail_figure.gd)
## is the body's sibling under the walker's node, not its child. Opened in
## the air, the hat comes off his head into his hands: each mitt reaches
## its grip on the brim and the arms are up over his head; folded, the hat
## is back on his head and the arms come down.
##   godot --headless --path . --script tests/test_pocket_sail_hold.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func ticks(n: int, want := Vector2.ZERO) -> void:
	study.script_want = want
	for i in range(n): study.tick(DT)

func press() -> void:
	study.script_jump = true
	study.tick(DT)
	study.script_jump = false
	study.tick(DT)

## The mitts' worst miss of their grips (m), and how high the lower
## wrist stands over the head bone (m).
func reach() -> Vector2:
	var body: Node3D = study.body
	var grips: Array = study.sail_wing.grips()
	if grips.size() != 2: return Vector2(INF,-INF)
	var miss := 0.0
	for side in range(2): miss = maxf(miss,body.mitt(side).distance_to(grips[side]))
	var skeleton: Skeleton3D = body.get("_skeleton")
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
	return Vector2(miss,minf(body.mitt(0).y,body.mitt(1).y)-head.y)

func run() -> void:
	create_timer(60.0).timeout.connect(func() -> void: push_error("pocket sail hold test timed out"); quit(2))
	study = load("res://studies/pocket_sail_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	check(study.sail_wing.get_parent() != study.body,"The sail's figure is the body's sibling here, as in the kit isles")
	study.place(Vector3(-40.0,40.0,40.0),Vector2(0.0,-1.0))
	ticks(20)
	press()
	check(m.move == "sail","Off the edge, Space: the sail")
	ticks(30)
	var held := reach()
	print("MEASURE: held, the mitts miss their grips by %.3f m; the wrists stand %.3f m over the head bone" % [held.x,held.y])
	check(held.x < 0.2,"Holding: each mitt at its grip on the brim (%.3f m off)" % held.x)
	check(held.y > 0.15,"Holding: the mitts up over his head (%.3f m over the head bone)" % held.y)
	check(study.sail_wing.global_position.distance_to(study.body.global_position) < 0.01,"The hat rides with him")
	ticks(40,Vector2(1.0,0.0))
	var turning := reach()
	check(turning.x < 0.2,"Turning: the mitts still hold the brim (%.3f m off)" % turning.x)
	press()
	ticks(30)
	check(m.move != "sail" and not study.sail_wing.visible,"Folded: the hat is back on his head")
	var skeleton: Skeleton3D = study.body.get("_skeleton")
	var head := skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone("head")).origin
	var high := maxf(study.body.mitt(0).y,study.body.mitt(1).y)-head.y
	check(high < held.y-0.2,"Folded: the arms come down, out of the hold (%.3f m over the head bone)" % high)
	print("PASS: pocket sail hold" if failures == 0 else "FAIL: pocket sail hold")
	quit(1 if failures else 0)
