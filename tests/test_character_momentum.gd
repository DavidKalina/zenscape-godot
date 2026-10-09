extends SceneTree
## Momentum in the character study (studies/character_study.tscn), headless,
## through the physics bridge (scripts/pilot_physics_ground.gd), in the
## momentum field: on the runway ([) five long jumps timed on each landing
## build to LONG_TOP and cover the ground far faster than the run; at the
## chain (]) a timed string crosses all five pits onto the far deck, where a
## string pressed late drops into one; down the big slope (\) crouched he
## reaches well past 14 m/s at the foot, runs out far along the flat, and
## long-jumped out of the slide clears the 6 m gap; F1 shows the chain.
##   godot --headless --path . --script tests/test_character_momentum.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var study: Node3D

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(120.0).timeout.connect(func() -> void: push_error("character momentum test timed out"); quit(2))
	study = load("res://studies/character_study.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	var m: PilotMotor = study.motor
	_runway(m)
	_chain_course(m)
	_big_slope(m)
	print("character momentum: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

## From station `key`, run along +x, crouch at `crouch_x`, the first long jump
## at `jump_x`, then crouch held and Jump `late` s after each landing, for
## `count` long jumps. Where it ends, the paces, the seconds from the first
## takeoff and the distance.
func _string(m: PilotMotor, key: int, crouch_x: float, jump_x: float, late: float, count: int) -> Dictionary:
	study.go_to(key)
	study.script_want = Vector2(1.0,0.0)
	study.script_jump = false
	study.script_crouch = false
	var paces := []
	var since := -1.0
	var from := 0.0
	var t := 0.0
	var landed := 0
	var fell := false
	var downs := []
	for i in range(1200):
		var first := paces.is_empty()
		study.script_crouch = (m.feet.x > crouch_x) if first else true
		var press := false
		if first: press = m.grounded and m.feet.x > jump_x and not study.script_jump
		elif since >= late-1e-6 and m.grounded and not study.script_jump: press = true
		study.script_jump = press
		var long_was := m.move == "long"
		study.tick(DT)
		if m.move == "long" and not long_was:
			if paces.is_empty(): from = m.feet.x
			paces.append(snappedf(m.speed(),0.01))
			since = -1.0
		if not paces.is_empty(): t += DT
		if long_was and m.grounded:
			landed += 1
			downs.append(snappedf(m.feet.x,0.01))
			since = 0.0
			if landed >= count: break
		elif since >= 0.0: since += DT
		if m.feet.y < -0.5:
			fell = true
			break
	study.script_jump = false
	study.script_crouch = false
	return {"paces":paces,"time":t,"distance":m.feet.x-from,"x":m.feet.x,"y":m.feet.y,"fell":fell,"downs":downs,"from":from}

func _runway(m: PilotMotor) -> void:
	var good := _string(m,13,-27.0,-26.0,0.0,5)
	print("MEASURE runway, 5 long jumps timed: paces %s, %.2f m in %.2f s (%.2f m/s)" % [good.paces,good.distance,good.time,float(good.distance)/float(good.time)])
	check(good.paces.size() == 5 and float(good.paces[4]) > 11.5 and float(good.paces[4]) <= PilotMotor.LONG_TOP+0.01,"On the runway five timed long jumps build to %s m/s" % [good.paces])
	check(float(good.distance)/float(good.time) > 2.0*PilotMotor.RUN,"Covering %.2f m in %.2f s, over twice the run's pace" % [good.distance,good.time])
	study._show_hud()
	check(study._hud.text.contains("long chain 5"),"F1 shows the chain of five")

func _chain_course(m: PilotMotor) -> void:
	var good := _string(m,14,-21.0,-19.3,0.0,5)
	print("MEASURE chain course timed: paces %s, took off at x %.2f, came down at %s, ended at x %.2f, y %.2f" % [good.paces,good.from,good.downs,good.x,good.y])
	check(not good.fell and float(good.x) > 8.2 and absf(float(good.y)) < 0.02,"Timed on each landing he crosses all five pits onto the far deck (x %.2f, paces %s)" % [good.x,good.paces])
	var late := _string(m,14,-21.0,-19.3,0.35,5)
	print("MEASURE chain course late (0.35 s): paces %s, ended at x %.2f, y %.2f" % [late.paces,late.x,late.y])
	check(late.fell or float(late.x) < 8.2,"Pressed late, he falls into a pit (x %.2f, y %.2f)" % [late.x,late.y])

func _big_slope(m: PilotMotor) -> void:
	# Crouched down it on the ticked half, to a stop.
	study.go_to(15)
	study.place(Vector3(-29.0,20.0,62.0),Vector2(1.0,0.0))
	study.script_want = Vector2(1.0,0.0)
	study.script_jump = false
	var foot := -1.0
	for i in range(1200):
		study.script_crouch = m.feet.x > -25.0
		study.tick(DT)
		if foot < 0.0 and m.feet.x >= 3.563: foot = m.speed()
		if foot >= 0.0 and m.speed() < 0.05: break
	study.script_crouch = false
	print("MEASURE big slope: %.2f m/s at the foot, runs out %.2f m (surf top on F1 %.2f)" % [foot,m.feet.x-3.563,study.slide_top])
	check(foot > 14.0 and m.feet.x-3.563 > 12.0,"Down the big slope crouched: %.2f m/s at the foot, and %.2f m out along the flat" % [foot,m.feet.x-3.563])
	# Long-jumped out of the slide over the 6 m gap.
	study.place(Vector3(-29.0,20.0,66.0),Vector2(1.0,0.0))
	var took := {}
	for i in range(1200):
		study.script_crouch = m.feet.x > -25.0
		study.script_jump = m.grounded and m.feet.x > 5.8 and took.is_empty()
		study.tick(DT)
		if took.is_empty() and m.move == "long": took = {"x":m.feet.x,"pace":m.speed()}
		if not took.is_empty() and (m.grounded or m.on_ledge() or m.feet.y < -0.5): break
	study.script_jump = false
	study.script_crouch = false
	print("MEASURE big slope gap: long jump at %s, came down at x %.2f, y %.2f" % [took,m.feet.x,m.feet.y])
	check(not took.is_empty() and m.grounded and absf(m.feet.y) < 0.02 and m.feet.x > 12.563,"Long-jumped out of the slide he clears the 6 m gap (%s, down at x %.2f)" % [took,m.feet.x])
