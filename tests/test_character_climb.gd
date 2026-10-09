extends SceneTree
## Every orange lip in the character study (studies/character_study.tscn) is
## caught and climbed: dropped just over each, facing its wall, the pilot
## catches it in the air and hangs, then Jump takes him up onto its top. The
## lips: the step ladder's blocks, the gap decks, the L's straight lips, its
## outside and inside corners, the curved lip, the pit's beams (and the pit's
## own rim), the catch walls and a corner of one, the low bridge's sides, and
## the tower's face and the blocks up to it, the wall-jump shaft's ledge.
##   godot --headless --path . --script tests/test_character_climb.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
## Each lip: a name, a point on its edge (x, z), the way off it (x, z) and
## its top's height.
const LIPS := [
	["step 0.8 m",Vector2(17.0,25.5),Vector2(0.0,-1.0),0.8],
	["step 1.1 m",Vector2(20.0,25.5),Vector2(0.0,-1.0),1.1],
	["step 1.5 m",Vector2(23.0,25.5),Vector2(0.0,-1.0),1.5],
	["step 2.0 m",Vector2(26.0,25.5),Vector2(0.0,-1.0),2.0],
	["step 2.4 m",Vector2(29.0,25.5),Vector2(0.0,-1.0),2.4],
	["gap deck 1.2 m",Vector2(-25.0,0.0),Vector2(1.0,0.0),1.2],
	["upper deck 2.4 m",Vector2(-25.0,-14.0),Vector2(1.0,0.0),2.4],
	["L straight south",Vector2(-17.0,-25.0),Vector2(0.0,1.0),2.0],
	["L straight east",Vector2(-21.0,-22.5),Vector2(1.0,0.0),2.0],
	["L outside corner, south side",Vector2(-21.4,-20.0),Vector2(0.0,1.0),2.0],
	["L outside corner, east side",Vector2(-21.0,-20.4),Vector2(1.0,0.0),2.0],
	["L inside corner, south side",Vector2(-20.6,-25.0),Vector2(0.0,1.0),2.0],
	["L inside corner, east side",Vector2(-21.0,-24.6),Vector2(1.0,0.0),2.0],
	["curved lip south",Vector2(-4.0,-22.5),Vector2(0.0,1.0),2.0],
	["curved lip west",Vector2(-6.5,-25.0),Vector2(-1.0,0.0),2.0],
	["curved lip south-west",Vector2(-5.76777,-23.23223),Vector2(-0.70711,0.70711),2.0],
	["beam 0.3 m",Vector2(-15.15,-20.0),Vector2(-1.0,0.0),0.0],
	["beam 0.6 m",Vector2(-11.7,-20.0),Vector2(1.0,0.0),0.0],
	["pit rim",Vector2(-17.0,-18.0),Vector2(0.0,-1.0),0.0],
	["catch wall 1.7 m",Vector2(6.0,-28.0),Vector2(0.0,1.0),1.7],
	["catch wall 2.1 m",Vector2(11.0,-28.0),Vector2(0.0,1.0),2.1],
	["catch wall 2.5 m",Vector2(16.0,-28.0),Vector2(0.0,1.0),2.5],
	["catch wall 3.0 m",Vector2(21.0,-28.0),Vector2(0.0,1.0),3.0],
	["catch wall corner",Vector2(4.4,-28.0),Vector2(0.0,1.0),1.7],
	["bridge side south",Vector2(0.0,8.0),Vector2(0.0,-1.0),1.7],
	["bridge side north",Vector2(-3.0,10.0),Vector2(0.0,1.0),1.7],
	["tower block 0.9",Vector2(11.0,-4.0),Vector2(0.0,1.0),0.9],
	["tower block 2.4",Vector2(11.0,-6.5),Vector2(0.0,1.0),2.4],
	["tower block 3.3",Vector2(11.0,-9.0),Vector2(0.0,1.0),3.3],
	["tower block 4.6",Vector2(9.0,-11.5),Vector2(1.0,0.0),4.6],
	["tower top, east face",Vector2(9.5,-8.0),Vector2(1.0,0.0),6.0],
	["tower top, north face",Vector2(8.0,-9.5),Vector2(0.0,-1.0),6.0],
	["wall-jump shaft ledge",Vector2(-11.0,-10.0),Vector2(1.0,0.0),6.0],
]
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func drive(want: Vector2, jump: bool, frames: int) -> void:
	study.script_want = want
	study.script_jump = jump
	for i in range(frames): study.tick(DT)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("character climb test timed out"); quit(2))
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	for lip: Array in LIPS: _grab_and_climb(lip[0],lip[1],lip[2],lip[3])
	print("character climb: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## Dropped with the hands a little over the lip at `edge` (way off it `out`,
## its top `top`), facing it: caught, then climbed with Jump.
func _grab_and_climb(name: String, edge: Vector2, out: Vector2, top: float) -> void:
	var m: PilotMotor = study.motor
	var hang := edge+out*PilotMotor.HANG_OUT
	study.place(Vector3(hang.x,top-PilotMotor.HANG_DROP+0.15,hang.y),-out)
	m.grounded = false
	var caught := false
	for i in range(30):
		drive(Vector2.ZERO,false,1)
		if m.hold == "hang":
			caught = true
			break
	if not caught:
		check(false,"%s: caught (%s, feet %.2f)" % [name,m.hold if m.hold != "" else ("grounded" if m.grounded else "air"),m.feet.y])
		return
	drive(Vector2.ZERO,false,20)
	drive(Vector2.ZERO,true,2)
	var climbing := m.hold == "climb"
	drive(Vector2.ZERO,false,70)
	var on_top: bool = m.hold == "" and m.grounded and absf(m.feet.y-top) < 0.06
	var inside: bool = (Vector2(m.feet.x,m.feet.z)-edge).dot(-out) > 0.05
	check(climbing and on_top and inside,"%s: caught and climbed (climbing %s, %s, feet %.2f, %.2f in)" % [name,climbing,m.hold if m.hold != "" else ("grounded" if m.grounded else "air"),m.feet.y,(Vector2(m.feet.x,m.feet.z)-edge).dot(-out)])
