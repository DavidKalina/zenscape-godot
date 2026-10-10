extends SceneTree
## The tricks in the character study (studies/character_study.tscn), headless,
## through the physics bridge (scripts/pilot_physics_ground.gd): at the slide
## run (0) he surfs the 32° ramp crouched, past 10.5 m/s, jumps out
## over the 4 m gap and lands across, then kicks up the slot to its lip and
## climbs out; the 50° chute (-) surfs him on its own, the 40° one doesn't
## until he crouches; at the side-flip ledges (=) a flip out of a skid gets
## him up onto the 2.0 m and the 1.8 m ledge; a twirl at a jump's top keeps
## him in the air longer, and the F1 numbers show it all.
##   godot --headless --path . --script tests/test_character_tricks.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func drive(want: Vector2, jump: bool, crouch: bool, frames: int) -> void:
	study.script_want = want
	study.script_jump = jump
	study.script_crouch = crouch
	for i in range(frames): study.tick(DT)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("character tricks test timed out"); quit(2))
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	_slide_run(m)
	_chutes(m)
	_side_flips(m)
	_twirl(m)
	study._show_hud()
	var hud: String = study._hud.text
	check(hud.contains("surf") and hud.contains("side flip") and hud.contains("twirl"),"F1 shows the surf, the side flip and the twirl")
	print("character tricks: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

func _slide_run(m: PilotMotor) -> void:
	study.go_to(10)
	drive(Vector2.ZERO,false,false,5)
	var way := Vector2(0.0,-1.0)
	var surfed := false
	var top := 0.0
	var landed := false
	study.script_want = way
	for i in range(600):
		# Crouched down the ramp; Jump at the pit's edge.
		study.script_crouch = m.grounded and m.feet.z > 14.6 and m.feet.z < 26.0
		study.script_jump = (m.move == "slide" and m.feet.z < 14.6) or (not m.grounded and m.velocity.y > 0.0)
		study.tick(DT)
		if m.move == "slide":
			surfed = true
			top = maxf(top,m.speed())
		if surfed and m.grounded and m.feet.z < 9.9:
			landed = absf(m.feet.y) < 0.02
			break
		if m.feet.y < -1.0 or m.on_ledge(): break
	study.script_jump = false
	study.script_crouch = false
	check(surfed and top > 10.5,"Crouched down the 32° ramp he surfs, up to %.2f m/s" % top)
	check(absf(study.slide_top-top) < 0.01,"F1's surf top reads it (%.2f)" % study.slide_top)
	check(landed and study.last_jump.get("kind","") == "slide jump","Jumped out at the pit's edge he lands across the 4 m gap (%s, z %.2f)" % [study.last_jump,m.feet.z])
	# On into the slot and up it: into the west wall, kicked to the east, and
	# on up to the 5.5 m lip. Stopped first: he lands with the slide's pace
	# carried, which would run him through the 5 m slot.
	drive(Vector2.ZERO,false,false,45)
	var side := Vector2(-1.0,0.0)
	var on_wall := 0
	var out_top := false
	var kicks := 0
	var was := ""
	for i in range(1500):
		on_wall = on_wall+1 if m.move == "wall" else 0
		var into_slot := m.feet.z > 3.0
		study.script_want = way if into_slot and m.grounded else side
		study.script_jump = (m.grounded and not into_slot) or (m.move != "wall" and m.velocity.y > 0.0) or on_wall >= 5 or (m.on_ledge() and i%20 < 3)
		study.tick(DT)
		if m.move == "kick" and was != "kick":
			kicks += 1
			side = -side
		was = m.move
		if m.grounded and m.feet.y > 5.4:
			out_top = true
			break
	study.script_jump = false
	check(out_top and kicks >= 2,"Kicked up the slot he reaches its 5.5 m lip and climbs out (%d kicks, feet %.2f)" % [kicks,m.feet.y])

func _chutes(m: PilotMotor) -> void:
	study.go_to(11)
	var surfed := false
	study.script_want = Vector2(0.0,-1.0)
	study.script_crouch = false
	for i in range(240):
		study.tick(DT)
		surfed = surfed or m.move == "slide"
		if m.grounded and m.feet.z < 18.0: break
	check(surfed and absf(m.feet.y) < 0.02,"Walked onto the 50° chute he surfs down it on his own (feet %.2f, z %.2f)" % [m.feet.y,m.feet.z])
	study.place(Vector3(57.0,5.0,27.5),Vector2(0.0,-1.0))
	surfed = false
	var on_it := false
	for i in range(120):
		study.script_want = Vector2(0.0,-0.4)
		study.tick(DT)
		surfed = surfed or m.move == "slide"
		if m.grounded and m.feet.z < 24.0 and m.feet.y < 4.0 and m.feet.y > 1.0:
			on_it = true
			break
	check(on_it and not surfed and m.steepness() > 35.0,"On the 40° chute he walks, not surfs (%.0f°, %s)" % [m.steepness(),m.move])
	study.script_crouch = true
	drive(Vector2.ZERO,false,true,20)
	check(m.move == "slide","Crouched there, he surfs (%s)" % m.move)
	drive(Vector2.ZERO,false,true,120)
	study.script_crouch = false

## From the lane `x`, run out along it, throw the stick back, Jump in the
## skid: whether he ends up on the ledge `top` high.
func _flip_onto(m: PilotMotor, x: float, top: float) -> bool:
	study.place(Vector3(x,0.0,-23.0),Vector2(0.0,1.0))
	var flipped := false
	for i in range(240):
		var back := i >= 18
		study.script_want = Vector2(0.0,-1.0) if back else Vector2(0.0,1.0)
		study.script_jump = back and m.skidding and not flipped
		study.tick(DT)
		flipped = flipped or m.move == "flip"
		if flipped and m.on_ledge(): study.script_jump = i%20 < 3
		if flipped and m.grounded and i > 30 and not m.on_ledge(): break
	study.script_jump = false
	return flipped and m.grounded and absf(m.feet.y-top) < 0.02

func _side_flips(m: PilotMotor) -> void:
	check(_flip_onto(m,54.5,2.0),"Side-flipped out of a skid he gets up onto the 2.0 m ledge (feet %.2f, %s)" % [m.feet.y,study.last_flip])
	check(not study.last_flip.is_empty() and absf(float(study.last_flip.peak)-PilotMotor.SIDE_FLIP) < 0.15 or m.feet.y > 1.7,"F1's side flip reads %s" % [study.last_flip])
	check(_flip_onto(m,51.5,1.8),"And onto the 1.8 m one (feet %.2f)" % m.feet.y)

func _twirl(m: PilotMotor) -> void:
	study.place(Vector3(0.0,0.0,2.0),Vector2(0.0,-1.0))
	drive(Vector2.ZERO,false,false,10)
	var t := 0
	study.script_jump = true
	var twirled := false
	for i in range(240):
		study.script_twirl = i == 15
		study.tick(DT)
		t += 1
		twirled = twirled or m.move == "twirl"
		if i > 2 and m.grounded: break
	study.script_jump = false
	study.script_twirl = false
	check(twirled and t*DT > 0.8 and study.last_twirl > 0.4,"A twirl at the jump's top keeps him up %.2f s (a plain jump 0.45 s); F1 shows %.2f s from it" % [t*DT,study.last_twirl])
