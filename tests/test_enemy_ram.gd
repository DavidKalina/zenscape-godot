extends SceneTree
## The Plinth Ram (scripts/enemies/plinth_ram.gd) in the enemy yard
## (studies/enemy_yard.tscn), headless, played through the real loop: the
## study's own `tick` reading the InputMap actions as the pad drives them
## (scripts/pad.gd: the left stick's axes for move_*, A for walk_jump, LT for
## walk_crouch), the stick pushed relative to the camera as a player does.
## The pilot and the ram are only set down at the start of each bout; every
## dodge is input. "tau" is the time left before its horns reach him (his
## own pace counted) when the dodge is begun.
##   - notice, tell (paws, heating colour), charge (wind-up), commit (a
##     snort, deep red); the charge curves after a pilot running sideways,
##     still hooking after the lock but less, banking into the turn;
##   - a stone animal: walked or run into in every state but a charge (idle,
##     wandering, backing off, telling, skidding, dug in, stunned) he never
##     passes into its body; still, he stands on its back; a jump that comes
##     down on a charging back is bucked off behind it;
##   - a pilot standing on its line is hit and shoved (knocked, not hurt);
##   - near a rim, a late jump, a late run aside, a late power slide (run
##     aside then LT), a late drop into a rim hang: it goes over (a teeter
##     at the lip first); he is not hit, and still hangs;
##   - early dodges (jump, run aside, slide) are followed and hit, and so is
##     a lazy slide just after the cue (hooked); a drop into the hang made
##     early is waited out at the lip: it does not fall;
##   - a late dodge in the open: it skids round, tells again, comes again,
##     and does not fall;
##   - idle at the rims for a long while, it never walks off; a charge that
##     loses him out of range stops at a rim; a pilot on the high ledge is
##     charged into the wall (a stun), not off an edge; across the gap on
##     the islet he is not charged at all;
##   - long-jumped into its side near a rim, it is knocked over it;
##   - out on the spit, a late jump sends it off the end.
##   godot --headless --path . --script tests/test_enemy_ram.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
## A line clear of the spit and the boulders; the south rim is at z 12.
const LANE := -4.0
const RIM := 12.0
var failures := 0
var study: Node3D
var m: PilotMotor

func _initialize() -> void:
	run.call_deferred()

func check(ok: bool, label: String) -> void:
	if not ok: failures += 1
	print(("OK   " if ok else "FAIL ")+label)

func run() -> void:
	create_timer(240.0).timeout.connect(func() -> void: push_error("enemy ram test timed out"); quit(2))
	study = load("res://studies/enemy_yard.tscn").instantiate()
	study.scripted = true
	root.add_child(study)
	current_scene = study
	while not study.walk_ready: await process_frame
	# From here the study is stepped by hand and reads the real input.
	study.set_process(false)
	study.scripted = false
	m = study.motor
	check(study.enemies.enemies.size() == 1,"The yard has its one ram")
	_telegraph_and_commit()
	_the_charge_curves()
	_solid_when_not_charging()
	_stands_on_it_still()
	_standing_is_hit()
	_late_jump_near_rim()
	_late_run_and_slide_near_rim()
	_hang_drops_it()
	_late_dodge_in_the_open()
	_early_dodges_are_hit()
	_never_off_an_edge_unbaited()
	_long_jump_into_its_side()
	_late_jump_on_the_spit()
	release()
	study.queue_free()
	await process_frame
	print("enemy ram: %d failure(s)" % failures)
	quit(1 if failures > 0 else 0)

# --- The pad -----------------------------------------------------------------------

func axis(which: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = which
	e.axis_value = value
	Input.parse_input_event(e)
	Input.flush_buffered_events()

func button(which: JoyButton, down: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = which
	e.pressed = down
	Input.parse_input_event(e)
	Input.flush_buffered_events()

## The left stick pushed so he goes `way` (x, z, world), from the camera's way.
func stick(way: Vector2) -> void:
	var f := PilotMotor.forward(study._yaw)
	var r := Vector2(-f.y,f.x)
	axis(JOY_AXIS_LEFT_X,way.dot(r))
	axis(JOY_AXIS_LEFT_Y,-way.dot(f))

func crouch(down: bool) -> void:
	axis(JOY_AXIS_TRIGGER_LEFT,1.0 if down else 0.0)

func release() -> void:
	axis(JOY_AXIS_LEFT_X,0.0)
	axis(JOY_AXIS_LEFT_Y,0.0)
	crouch(false)
	button(JOY_BUTTON_A,false)

# --- Bouts -------------------------------------------------------------------------

## He is set down at `p` facing the ram, set down at `r` facing him.
func _arena(p: Vector2, r: Vector2) -> Node3D:
	release()
	study.place(Vector3(p.x,0.0,p.y),r-p)
	var ram: Node3D = study.enemies.enemies[0]
	ram.position = Vector3(r.x,0.0,r.y)
	ram.facing = PilotMotor.facing_of(p-r)
	ram.rotation.y = ram.facing
	return ram

func _charging(ram: Node3D) -> bool:
	return ram.state == "charge" or ram.state == "commit"

## Seconds till its horns reach him, his pace counted.
func _tau(ram: Node3D) -> float:
	var to := Vector2(m.feet.x-ram.position.x,m.feet.z-ram.position.z)
	var gap: float = to.length()-ram.length*0.5-float(ram.knobs.radius)
	var closing: float = Vector2(ram.vel.x,ram.vel.z).length()-Vector2(m.velocity.x,m.velocity.z).dot(to.normalized())
	return gap/maxf(closing,0.5)

## A bout: he stands at `p` (or, `flee`, runs from it along +z once it
## charges), the ram at `r`; at `tau` he dodges by `kind`:
##   "none", "jump" (A held), "run" (stick across, +x), "slide" (stick
##   across, LT once he is at a slide's pace), "hang" (eased toward the rim,
##   +z, let go once he hangs), "matador" (runs at it from tau+0.6, then at
##   tau LT with the stick across: a power slide carving out of its line).
## Played `after` s past the dodge. {hit, over (it fell), hung, slid, ram,
## tells (at the end), again (it charged a second time)}.
func _bout(p: Vector2, r: Vector2, kind: String, tau: float, after := 3.0) -> Dictionary:
	var ram := _arena(p,r)
	var hit := [false]
	var knocked := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void:
		knocked[0] = m.move == "tumble"
		if ram.told_count <= 1: hit[0] = true)
	var n := 0
	while n < 600 and not _charging(ram):
		study.tick(DT)
		n += 1
	var dodged := false
	var over := false
	var slid := false
	var again := false
	n = 0
	while n < int(6.0/DT) and not hit[0] and not dodged:
		if kind == "matador" and _tau(ram) <= tau+0.6: stick(Vector2(0.0,-1.0))
		if _tau(ram) <= tau and _charging(ram):
			dodged = true
			match kind:
				"jump": button(JOY_BUTTON_A,true)
				"run","slide": stick(Vector2(1.0,0.0))
				"hang": stick(Vector2(0.0,0.5))
				"matador":
					stick(Vector2(1.0,0.0))
					crouch(true)
		study.tick(DT)
		n += 1
	for i in range(int(after/DT)):
		if kind in ["run","slide","matador"]: stick(Vector2(1.0,0.0))
		if kind == "slide" and m.speed() >= 3.3: crouch(true)
		if kind == "hang" and m.hold != "": stick(Vector2.ZERO)
		if m.move == "slide": slid = true
		study.tick(DT)
		if not is_instance_valid(ram) or ram.gone or not ram.grounded:
			over = true
			break
		if ram.told_count >= 2 and _charging(ram): again = true
	var out := {"hit":hit[0],"over":over,"hung":m.hold == "hang","slid":slid,"ram":ram,
		"tells":ram.told_count if is_instance_valid(ram) else 0,"again":again,"knocked":knocked[0]}
	release()
	return out

# --- The checks --------------------------------------------------------------------

func _telegraph_and_commit() -> void:
	var ram := _arena(Vector2(LANE,6.0),Vector2(LANE,-4.0))
	study.enemies.sounds.clear()
	var seen := {}
	var commit_facing := INF
	var colour_at_commit := Color.BLACK
	var top := 0.0
	var early_pace := -1.0
	var charge_t := 0.0
	for i in range(int(4.0/DT)):
		study.tick(DT)
		if not seen.has(ram.state): seen[ram.state] = i
		if ram.state == "charge":
			charge_t += DT
			if early_pace < 0.0 and charge_t >= float(ram.knobs.wind_up)*0.3: early_pace = Vector2(ram.vel.x,ram.vel.z).length()
		if ram.state == "commit":
			if commit_facing == INF:
				commit_facing = ram.facing
				colour_at_commit = ram.get("_mat").albedo_color
		top = maxf(top,Vector2(ram.vel.x,ram.vel.z).length())
		if ram.state in ["skid","teeter","stun"]: break
	release()
	var names: Array = study.enemies.sounds.map(func(s: Array) -> StringName: return s[0])
	check(seen.has("notice") and seen.has("tell") and seen.has("charge") and seen.has("commit"),"It notices, tells, charges, commits (%s)" % str(seen.keys()))
	check(seen.get("notice",99) < seen.get("tell",0) and seen.get("tell",99) < seen.get("charge",0) and seen.get("charge",99) < seen.get("commit",0),"...in that order")
	check(names.has(&"ram_huff") and names.count(&"ram_paw") >= 2 and names.has(&"ram_charge") and names.has(&"ram_snort"),"It huffs, paws (%d), charges and snorts (%s)" % [names.count(&"ram_paw"),str(names)])
	check(colour_at_commit.is_equal_approx(ram.COMMIT_COLOUR),"Committed it is deep red")
	check(early_pace >= 0.0 and early_pace < float(ram.knobs.charge_speed)*0.6,"It winds up: early in the charge it is well under its top speed (%.2f)" % early_pace)
	check(top > m.run,"It charges above his run (%.2f over %.2f m/s)" % [top,m.run])

## A charge at him from 12 m, he running sideways (+x) from the moment it
## charges (`at_lock` false) or from the lock (true): per phase, its peak
## turn rate (rad/s), the turn summed, and its bank and head into the turn.
func _curve(at_lock: bool) -> Dictionary:
	var ram := _arena(Vector2(LANE,6.0),Vector2(LANE,-6.0))
	var out := {"pre":0.0,"post":0.0,"post_turn":0.0,"blind":0.0,"bank":0.0,"head":0.0,"snap":false}
	var last := INF
	for i in range(int(5.0/DT)):
		if (ram.state == "commit" or (ram.state == "charge" and not at_lock)): stick(Vector2(1.0,0.0))
		var was_state: String = ram.state
		study.tick(DT)
		if not _charging(ram):
			if last != INF: break
			continue
		if last == INF:
			last = ram.facing
			continue
		var d := absf(angle_difference(last,ram.facing))
		last = ram.facing
		# Toward +x from a run along +z is a turn to its left (facing
		# rising): banked left (+z roll), the head looking left (+y).
		out.bank = maxf(out.bank,ram.skin.rotation.z)
		out.head = maxf(out.head,ram.get("_head").rotation.y)
		if ram.state == "charge": out.pre = maxf(out.pre,d/DT)
		elif was_state == "charge": out.snap = true # the lock's snap: the head's jerk, not a turn
		elif _tau(ram) > float(ram.knobs.blind)+0.05:
			out.post = maxf(out.post,d/DT)
			out.post_turn += d
		elif _tau(ram) < float(ram.knobs.blind)-0.05: out.blind += d
	release()
	return out

## The charge curves: it hooks after him, hard before the lock and still
## after it, but tighter, and blind (no turn) for its last `blind` s; it
## banks and looks into the turn.
func _the_charge_curves() -> void:
	var early := _curve(false)
	var late := _curve(true)
	check(early.snap and early.pre > 1.0,"Charging, it hooks after him running sideways (%.2f rad/s at most)" % early.pre)
	check(late.post_turn > 0.05,"After the lock it still turns after him: the path curves (%.3f rad)" % late.post_turn)
	check(late.post > 0.1 and late.post < early.pre*0.75,"...but tighter than before the lock (%.2f rad/s at most after, %.2f before)" % [late.post,early.pre])
	check(late.blind < 0.01 and early.blind < 0.01,"Head down for its last %.2f s it runs blind, its line set (%.3f / %.3f rad)" % [float(study.enemies.enemies[0].knobs.blind),early.blind,late.blind])
	check(early.bank > 0.05 and early.head > 0.05 and late.bank > 0.02,"It banks and looks into the turn (body %.2f rad, head %.2f rad; after the lock %.2f rad)" % [early.bank,early.head,late.bank])

## How far his feet are outside its body (m, the box's footprint; negative
## inside), or INF when he is over its back.
func _outside(ram: Node3D) -> float:
	if m.feet.y-ram.position.y >= ram.height-0.15: return INF
	var l: Vector3 = Basis(Vector3.UP,ram.facing).inverse()*(m.feet-ram.position)
	return maxf(absf(l.x)-ram.width*0.5,absf(l.z)-ram.length*0.5)

## Pushes the stick at it (`pace` of full tilt) while it is in `state` (or
## for `seconds`): [nearest his feet came to its body, frames he was in it].
func _press(ram: Node3D, state: String, seconds: float, pace := 1.0) -> Array:
	var nearest := INF
	var inside := 0
	for i in range(int(seconds/DT)):
		if state != "" and ram.state != state: break
		stick(Vector2(ram.position.x-m.feet.x,ram.position.z-m.feet.z).normalized()*pace)
		study.tick(DT)
		var o := _outside(ram)
		nearest = minf(nearest,o)
		if o < -0.05: inside += 1
	release()
	return [nearest,inside]

## Walked or run into in every state but a charge, it is a stone: he never
## passes into its body (he stops against it).
func _solid_when_not_charging() -> void:
	var touching: float = float(study.enemies.numbers().radius)+0.15
	for pace: float in [0.5,1.0]:
		var how := "walking" if pace < 1.0 else "running"
		# Idle, standing, looking away: into its back.
		var ram := _arena(Vector2(LANE,-3.0),Vector2(LANE,0.0))
		ram.facing = PilotMotor.facing_of(Vector2(0.0,1.0))
		ram.rotation.y = ram.facing
		ram.set("_wander_t",100.0)
		ram.set("_walking",false)
		var res := _press(ram,"",1.5,pace)
		check(res[0] < touching and res[1] == 0,"Idle, %s into its back: he stops against it (%.2f m off, %d frames in it)" % [how,res[0],res[1]])
		# Idle, wandering across his way: into its flank.
		ram = _arena(Vector2(LANE-2.5,0.6),Vector2(LANE,0.0))
		ram.facing = PilotMotor.facing_of(Vector2(0.0,1.0))
		ram.rotation.y = ram.facing
		ram.set("_wander_t",100.0)
		ram.set("_walking",true)
		ram.set("_turn_to",ram.facing)
		res = _press(ram,"",1.5,pace)
		check(res[0] < touching and res[1] == 0,"Wandering, %s into its flank: he stops against it (%.2f m off, %d frames in it)" % [how,res[0],res[1]])
		# Noticing him too close, it backs off for a run-up: after it.
		ram = _arena(Vector2(LANE,-1.4),Vector2(LANE,0.0))
		study.tick(DT)
		res = _press(ram,"notice",2.0,pace)
		check(res[1] == 0,"Backing off, %s at its face: never in it (%.2f m off, %d frames in it)" % [how,res[0],res[1]])
		# Telling (pawing): at its face till it charges (from just past the
		# run-up it would back off for).
		ram = _arena(Vector2(LANE,-(ram.length*0.5+float(ram.knobs.room)+0.1)),Vector2(LANE,0.0))
		while ram.state != "tell": study.tick(DT)
		res = _press(ram,"tell",1.0,pace)
		check(res[0] < touching and res[1] == 0,"Telling, %s at its face: he stops against it (%.2f m off, %d frames in it)" % [how,res[0],res[1]])
		# A miss in the open (run aside late), then at it as it skids and digs in.
		ram = _arena(Vector2(LANE,2.0),Vector2(LANE,-8.0))
		var dodged := false
		for i in range(int(4.0/DT)):
			if ram.state == "skid": break
			if not dodged and _charging(ram) and _tau(ram) <= 0.4:
				dodged = true
				stick(Vector2(1.0,0.0))
			study.tick(DT)
		var skid := _press(ram,"skid",2.0,pace)
		var dig := _press(ram,"dig",2.0,pace)
		# (Walking, he doesn't catch it before it comes round to tell again.)
		check(ram.told_count == 1 and (pace < 1.0 or minf(skid[0],dig[0]) < touching) and skid[1]+dig[1] == 0,"Skidding and dug in, %s at it: never in it (%.2f / %.2f m off, %d frames in it)" % [how,skid[0],dig[0],skid[1]+dig[1]])
		# Stunned: into its side.
		ram = _arena(Vector2(LANE,-3.0),Vector2(LANE,0.0))
		ram.facing = PilotMotor.facing_of(Vector2(1.0,0.0))
		ram.rotation.y = ram.facing
		ram.stun(3.0)
		res = _press(ram,"stun",1.5,pace)
		check(res[0] < touching and res[1] == 0,"Stunned, %s into its side: he stops against it (%.2f m off, %d frames in it)" % [how,res[0],res[1]])
	# Standing by its shoulder as it notices him and turns: its body sweeps
	# round into him and shoves him out, never through.
	var ram := _arena(Vector2(LANE+0.75,-0.3),Vector2(LANE,0.0))
	ram.facing = PilotMotor.facing_of(Vector2(0.0,-1.0))
	ram.rotation.y = ram.facing
	var inside := 0
	for i in range(int(2.0/DT)):
		study.tick(DT)
		if _outside(ram) < -0.05: inside += 1
	check(inside == 0,"Stood by its shoulder as it turns to him, its body shoves him aside, never through (%d frames in it)" % inside)

## Still, it is a stone to stand on: he jumps onto its back and stays there.
func _stands_on_it_still() -> void:
	var ram := _arena(Vector2(LANE,-1.9),Vector2(LANE,0.0))
	ram.facing = PilotMotor.facing_of(Vector2(1.0,0.0))
	ram.rotation.y = ram.facing
	ram.stun(5.0)
	var up := false
	for i in range(int(1.2/DT)):
		if not up: stick(Vector2(0.0,1.0))
		if i == 2: button(JOY_BUTTON_A,true)
		study.tick(DT)
		if m.grounded and m.feet.y > ram.height-0.05:
			up = true
			release()
	release()
	for i in range(int(1.0/DT)): study.tick(DT)
	check(up and m.grounded and absf(m.feet.y-ram.height) < 0.05,"Still (stunned), it is a stone he stands on (feet %.2f, its back %.2f)" % [m.feet.y,ram.height])

func _standing_is_hit() -> void:
	var res := _bout(Vector2(LANE,6.0),Vector2(LANE,-4.0),"none",0.0)
	check(res.hit,"A pilot standing on its line is hit")
	check(res.knocked,"He is knocked (tumbling), not damaged")
	res = _bout(Vector2(LANE,RIM-0.7),Vector2(LANE,RIM-10.0),"none",0.0)
	check(res.hit and not res.over,"Standing at the lip he is hit; it does not go over")

## 2 m from the south rim: the jump window, both ends, and outside it.
func _late_jump_near_rim() -> void:
	for tau: float in [0.1,0.2,0.3]:
		var res := _bout(Vector2(LANE,RIM-2.0),Vector2(LANE,RIM-12.0),"jump",tau)
		check(not res.hit and res.over,"A late jump %.2f s out clears its horns and it goes over the rim (hit %s, over %s)" % [tau,res.hit,res.over])
	# A little early: he comes down on its back, and is bucked off behind it,
	# not carried over the rim.
	var buck := _bout(Vector2(LANE,RIM-2.0),Vector2(LANE,RIM-12.0),"jump",0.45)
	check(not buck.hit and buck.over and m.feet.y > -0.5 and m.feet.z < RIM,"A jump 0.45 s out lands on its back: bucked off behind it, it goes over, he stays on the isle (hit %s, over %s, feet %s)" % [buck.hit,buck.over,str(m.feet)])
	var early := _bout(Vector2(LANE,RIM-2.0),Vector2(LANE,RIM-12.0),"jump",0.55)
	check(early.hit,"A jump 0.55 s out comes down on its horns: hit")
	var late := _bout(Vector2(LANE,RIM-2.0),Vector2(LANE,RIM-12.0),"jump",0.0)
	check(late.hit,"A jump at the last instant is too late: run down")

func _late_run_and_slide_near_rim() -> void:
	var res := _bout(Vector2(LANE,RIM-1.5),Vector2(LANE,RIM-11.5),"run",0.5)
	check(not res.hit and res.over,"A late run out of its line (0.5 s) sends it over (hit %s, over %s)" % [res.hit,res.over])
	for tau: float in [0.4,0.6]:
		res = _bout(Vector2(LANE,RIM-1.5),Vector2(LANE,RIM-11.5),"slide",tau)
		check(res.slid and not res.hit and res.over,"A late power slide (stick across, then LT) %.1f s out sends it over (slid %s, hit %s, over %s)" % [tau,res.slid,res.hit,res.over])
	res = _bout(Vector2(LANE,RIM-1.5),Vector2(LANE,RIM-11.5),"slide",0.15)
	check(res.hit,"A slide begun 0.15 s out is too late: hit")
	res = _bout(Vector2(LANE,RIM-0.6),Vector2(LANE,RIM-12.0),"matador",0.4)
	check(res.slid and not res.hit,"Run at it, then a power slide carving out of its line 0.4 s out: not hit (slid %s, hit %s)" % [res.slid,res.hit])
	res = _bout(Vector2(LANE,RIM-1.5),Vector2(LANE,RIM-11.5),"slide",0.75)
	check(res.slid and res.hit,"A lazy power slide 0.75 s out (just after the cue): it hooks after him and hits (slid %s, hit %s)" % [res.slid,res.hit])

func _hang_drops_it() -> void:
	var res := _bout(Vector2(LANE,RIM-0.4),Vector2(LANE,RIM-10.0),"hang",0.5)
	check(res.hung,"Eased off the rim, he hangs from it")
	check(res.over and not res.hit,"It runs over his hands and falls (over %s, hit %s)" % [res.over,res.hit])
	check(m.hold == "hang","...and he is still hanging (%s)" % m.hold)
	res = _bout(Vector2(LANE,RIM-0.4),Vector2(LANE,RIM-10.0),"hang",1.3)
	check(res.hung and not res.over and not res.hit,"Dropped into the hang too early, it gives up and pulls up short of the lip: no fall, no hit (over %s, hit %s)" % [res.over,res.hit])

func _late_dodge_in_the_open() -> void:
	var ram := _arena(Vector2(LANE,0.0),Vector2(LANE,-10.0))
	var hit := [false]
	ram.hit_pilot.connect(func(_e: Node3D) -> void:
		if ram.told_count <= 1: hit[0] = true)
	var dodged := false
	var skidded := false
	var swung := 0.0
	var fell := false
	var again := false
	for i in range(int(8.0/DT)):
		if not dodged and _charging(ram) and _tau(ram) <= 0.2:
			dodged = true
			button(JOY_BUTTON_A,true)
		study.tick(DT)
		if dodged and m.grounded and m.move != "jump": button(JOY_BUTTON_A,false)
		if ram.gone or not ram.grounded: fell = true
		if ram.state == "skid":
			skidded = true
			swung = maxf(swung,absf(angle_difference(ram.facing,PilotMotor.facing_of(Vector2(0.0,1.0)))))
		if ram.told_count >= 2 and _charging(ram): again = true
		if again: break
	release()
	check(not hit[0],"Dodged in the open: not hit")
	check(skidded and swung > 0.5,"It lost him and skidded, its front swinging round (%.2f rad)" % swung)
	check(not fell,"A miss in the open costs it nothing: it did not fall")
	check(again and ram.told_count >= 2,"It tells again and comes again (%d tells)" % ram.told_count)

func _early_dodges_are_hit() -> void:
	var res := _bout(Vector2(LANE,6.0),Vector2(LANE,-4.0),"run",1.3)
	check(res.hit,"Run out of its line early (1.3 s out): it leads him and hits him")
	res = _bout(Vector2(LANE,6.0),Vector2(LANE,-4.0),"slide",1.3)
	check(res.slid and res.hit,"A power slide begun early (1.3 s out): followed and hit (slid %s)" % res.slid)
	res = _bout(Vector2(LANE,6.0),Vector2(LANE,-4.0),"jump",0.8)
	check(res.hit,"A jump made early (0.8 s out): he lands in front of it and is hit")

## Tick `seconds`; whether the ram fell meanwhile.
func _soak(ram: Node3D, seconds: float) -> bool:
	for i in range(int(seconds/DT)):
		study.tick(DT)
		if not is_instance_valid(ram) or ram.gone or not ram.grounded: return true
	return false

func _never_off_an_edge_unbaited() -> void:
	# He is gone out of range (thrown far off by the scene) as it charges at the south rim.
	var ram := _arena(Vector2(LANE,RIM-1.0),Vector2(LANE,RIM-8.0))
	while not _charging(ram): study.tick(DT)
	while ram.position.z < RIM-6.0: study.tick(DT)
	m.reset(Vector3(-10.0,0.0,-12.0),0.0)
	check(not _soak(ram,6.0),"A charge that loses its pilot out of range stops at the rim")
	# Idle at each rim, him far off and behind it, for a long while.
	for pair: Array in [[Vector2(LANE,RIM-0.8),Vector2(8.0,-12.0)],[Vector2(11.0,0.0),Vector2(-10.0,-12.0)],
			[Vector2(-11.0,-8.0),Vector2(10.0,10.0)],[Vector2(0.0,RIM+8.0),Vector2(-10.0,-12.0)]]:
		var at: Vector2 = pair[0]
		ram = _arena(pair[1],at)
		ram.facing = PilotMotor.facing_of(Vector2(at.x,at.y).normalized())
		ram.rotation.y = ram.facing
		check(not _soak(ram,40.0),"Wandering by the rim at %s for 40 s, it never goes over" % at)
	# He is on the high ledge, out of reach: it charges the wall, no more.
	ram = _arena(Vector2(0.0,-12.5),Vector2(0.0,-2.0))
	m.reset(Vector3(0.0,1.2,-12.5),0.0)
	var stunned := false
	var fell := false
	for i in range(int(10.0/DT)):
		study.tick(DT)
		if ram.state == "stun": stunned = true
		if ram.gone or not ram.grounded: fell = true
	check(not fell,"Chasing a pilot it cannot reach (the ledge), it does not fall (stunned on the wall: %s)" % stunned)
	# He is on the islet over the gap: it won't charge across.
	ram = _arena(Vector2(-16.5,0.0),Vector2(-8.0,0.0))
	fell = _soak(ram,8.0)
	check(not fell and ram.told_count == 0,"Across a gap it does not charge him (%d tells)" % ram.told_count)

func _long_jump_into_its_side() -> void:
	# Idle by the rim, side on, looking away; he runs at it and long-jumps
	# (LT at a run, then A) into its side.
	var ram := _arena(Vector2(LANE,RIM-9.0),Vector2(LANE,RIM-1.0))
	ram.facing = PilotMotor.facing_of(Vector2(1.0,0.0))
	ram.rotation.y = ram.facing
	ram.set("_wander_t",100.0)
	ram.set("_walking",false)
	var knocked := [false]
	ram.knocked.connect(func(_e: Node3D) -> void: knocked[0] = true)
	var jumped := false
	for i in range(int(4.0/DT)):
		stick(Vector2(0.0,1.0))
		if m.speed() >= m.run*0.95 and m.grounded and not jumped and m.feet.z > RIM-8.0:
			crouch(true)
		if m.move == "slide" and not jumped:
			button(JOY_BUTTON_A,true)
			jumped = true
		study.tick(DT)
		if knocked[0] or ram.gone: break
	release()
	check(jumped and knocked[0],"Long-jumped into its side, it is knocked (jumped %s)" % jumped)
	var fell: bool = ram.gone or not ram.grounded or _soak(ram,3.0)
	check(fell,"...and goes over the rim")

func _late_jump_on_the_spit() -> void:
	var spit: Rect2 = study.SPIT
	var tip := Vector2(spit.get_center().x,spit.end.y-1.2)
	var res := _bout(tip,tip-Vector2(0.0,10.0),"jump",0.2)
	check(not res.hit and res.over,"Out on the spit, a late jump sends it off the end (hit %s, over %s)" % [res.hit,res.over])
