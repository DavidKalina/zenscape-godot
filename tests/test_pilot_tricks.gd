extends SceneTree
## The pilot's tricks on foot (scripts/pilot_motor.gd), over heights alone
## (the game's own way): the twirl pressed in the air twirls him, once an
## airtime, giving back some airtime, never from crouch, and a second jump press falling still asks to fly; held crouched
## on a slope he boot-surfs down it, faster and faster past 11 m/s, steers
## across it, and on one too steep to stand on surfs without the crouch;
## jumped out of the surf uncrouched he flies on at its pace over a gap no
## run jump clears; onto flat ground he slides on, slowing to his run; running up a steep slope he
## slows; jumped in a skid it is the side flip, higher than the pump and
## shorter, the way the stick now points, up onto a 1.9 m ledge; and a
## climb from a hang takes him up in under half a second.
##   godot --headless --path . --script tests/test_pilot_tricks.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const PilotLedge = preload("res://scripts/pilot_ledge.gd")
const DT := 1.0/60.0
var failures := 0
var flat := func(_p: Vector2) -> float: return 0.0
var free := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
var figure: Node3D

func _initialize() -> void:
	figure = PilotFigure.new()
	root.add_child(figure)
	_twirl()
	_surf()
	_side_flip()
	_climb_time()
	figure.free()
	print("PASS: pilot tricks" if failures == 0 else "FAIL: pilot tricks (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

func _step(m: PilotMotor, want: Vector2, jump: bool, ground: Callable = flat, ledge := Callable()) -> Dictionary:
	var out := m.step(DT,want,PilotMotor.RUN,jump,ground,free,ledge)
	figure.drive(m,DT)
	return out

## A held jump from a stand, the twirl pressed `at` s after takeoff (never if
## negative): seconds in the air, and the twirls it gave.
func _airtime(at: float, presses := 1) -> Dictionary:
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,0.0)
	var t := 0.0
	var twirls := 0
	var peak := 0.0
	var spun := false
	_step(m,Vector2.ZERO,true)
	for i in range(240):
		t += DT
		var press := false
		for k in range(presses): press = press or (at >= 0.0 and t >= at+0.15*k and t < at+0.15*k+DT*2.0)
		m.twirl = press
		var out := _step(m,Vector2.ZERO,true)
		if out.has("twirl"): twirls += 1
		spun = spun or m.move == "twirl"
		peak = maxf(peak,m.feet.y)
		if out.has("landed"): break
	return {"time":t,"twirls":twirls,"peak":peak,"spun":spun,"weight":float(figure._move_weights.get("twirl",0.0))}

func _twirl() -> void:
	var plain := _airtime(-1.0)
	var at_peak := _airtime(0.25)
	var falling := _airtime(0.4)
	check(at_peak.twirls == 1 and at_peak.spun,"The twirl pressed at the jump's top twirls him")
	check(float(at_peak.time)-float(plain.time) > 0.3,"The twirl at the top gives %.2f s more airtime (%.2f s against %.2f s)" % [float(at_peak.time)-float(plain.time),at_peak.time,plain.time])
	check(float(falling.time)-float(plain.time) > 0.3,"Pressed late, falling, it still gives %.2f s more" % (float(falling.time)-float(plain.time)))
	var twice := _airtime(0.2,3)
	check(twice.twirls == 1,"Pressed again and again, once an airtime (%d twirls)" % twice.twirls)
	# Landing gives it back.
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,0.0)
	var twirls := 0
	var jump := true
	for i in range(240):
		m.twirl = not m.grounded and m.velocity.y < 0.5 and i%20 < 2
		var out := _step(m,Vector2.ZERO,jump)
		if out.has("twirl"): twirls += 1
		if out.has("landed"): jump = false
		elif m.grounded: jump = true
		if twirls >= 2: break
	check(twirls >= 2,"Landed, he can twirl again (%d)" % twirls)
	# Crouch, held into the long jump or pressed in the air, does not twirl.
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.twirl = false
	m.crouch = true
	_step(m,Vector2(1.0,0.0),false)
	var out := _step(m,Vector2(1.0,0.0),true)
	var spun := false
	for i in range(60):
		m.crouch = i < 10 or i > 14
		var o := _step(m,Vector2(1.0,0.0),true)
		spun = spun or o.has("twirl")
		if m.grounded: break
	check(out.has("long") and not spun,"Crouch held into the long jump, or pressed again in the air, does not twirl")
	# Jump pressed again in the air still asks to fly, twirled or not.
	m.reset(Vector3.ZERO,0.0)
	m.crouch = false
	_step(m,Vector2.ZERO,false)
	_step(m,Vector2.ZERO,true)
	for i in range(6): _step(m,Vector2.ZERO,true)
	m.twirl = true
	_step(m,Vector2.ZERO,false)
	m.twirl = false
	out = _step(m,Vector2.ZERO,true)
	check(out.has("fly") and m.move == "twirl","Twirling, Jump pressed again still asks to fly")

## A slope `degrees` steep falling to +x from x 0 to `length`, a platform
## over it before, flat after, then a gap from `gap_at` `gap` wide (the
## ground 4 m down), then flat again.
func _hill(degrees: float, length: float, gap_at := 999.0, gap := 0.0) -> Callable:
	var rise := tan(deg_to_rad(degrees))
	return func(p: Vector2) -> float:
		if p.x > gap_at and p.x < gap_at+gap: return -4.0
		return clampf(length-p.x,0.0,length)*rise

func _surf() -> void:
	# Crouched on a 32° slope from a stand: surfing, faster and faster.
	var hill := _hill(32.0,12.0)
	var m := PilotMotor.new()
	m.reset(Vector3(0.5,float(hill.call(Vector2(0.5,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var paces := []
	var started := false
	var top := 0.0
	var t := 0.0
	var reached := -1.0
	for i in range(180):
		var out := _step(m,Vector2.ZERO,false,hill)
		t += DT
		if out.get("slide",false): started = true
		if i%20 == 0: paces.append(snappedf(m.speed(),0.1))
		top = maxf(top,m.speed())
		if reached < 0.0 and m.speed() > PilotMotor.SLIDE_TOP-0.05: reached = t
		if m.feet.x > 12.0: break
	var rising := true
	for k in range(1,paces.size()): rising = rising and paces[k] >= paces[k-1]
	check(started and m.move == "slide" and m.grounded,"Crouched on a 32° slope he surfs down it (%s)" % m.move)
	check(rising and top <= PilotMotor.SLIDE_TOP+0.01 and top > 11.0,"Faster and faster, %s m/s, to %.2f in 12 m (SLIDE_TOP %.1f)" % [paces,top,PilotMotor.SLIDE_TOP])
	check(PilotMotor.forward(m.facing).dot(Vector2(1.0,0.0)) > 0.95,"Facing down the fall line")
	check(figure._has_moves and float(figure._move_weights["slide"]) > 0.99,"The drawn pilot surfs in its own clip")
	# Steered across it.
	m.reset(Vector3(0.5,float(hill.call(Vector2(0.5,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	for i in range(60): _step(m,Vector2(0.0,1.0),false,hill)
	check(m.move == "slide" and m.feet.z > 0.5,"The stick steers him across the slope (%.2f m)" % m.feet.z)
	# Without the crouch he stands on 32° (slowed running up it), and can't
	# on 50°.
	m.reset(Vector3(6.0,float(hill.call(Vector2(6.0,0.0))),0.0),PilotMotor.facing_of(Vector2(-1.0,0.0)))
	m.crouch = false
	for i in range(30): _step(m,Vector2.ZERO,false,hill)
	check(m.move == "" and m.speed() < 0.01,"Uncrouched he stands still on 32° (%s)" % m.move)
	for i in range(30): _step(m,Vector2(-1.0,0.0),false,hill)
	check(m.speed() < PilotMotor.RUN*0.9 and m.speed() > PilotMotor.RUN*0.5,"Running up 32° he slows to %.2f m/s" % m.speed())
	var steep := _hill(50.0,8.0)
	m.reset(Vector3(3.0,float(steep.call(Vector2(3.0,0.0))),0.0),PilotMotor.facing_of(Vector2(-1.0,0.0)))
	var auto := false
	for i in range(60):
		_step(m,Vector2(-1.0,0.0),false,steep)
		auto = auto or m.move == "slide"
	check(auto and m.feet.x > 3.0,"On 50° he can't stand: he surfs down it, running up or not (x %.2f)" % m.feet.x)
	# Onto flat ground: he keeps his pace, slows, and runs on.
	var hill2 := _hill(32.0,10.0)
	m.reset(Vector3(0.5,float(hill2.call(Vector2(0.5,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var at_foot := 0.0
	var ran_at := -1.0
	for i in range(300):
		if m.feet.x > 10.0 and at_foot == 0.0:
			at_foot = m.speed()
			m.crouch = false
		_step(m,Vector2(1.0,0.0),false,hill2)
		if at_foot > 0.0 and m.move == "" and ran_at < 0.0: ran_at = m.feet.x
		if ran_at > 0.0 and m.feet.x > ran_at+2.0: break
	check(at_foot > 9.0 and ran_at > 17.0 and ran_at < 24.0 and absf(m.speed()-PilotMotor.RUN) < 0.2,"At the foot at %.1f m/s, he slides on along the flat and runs on %.1f m later at %.2f m/s" % [at_foot,ran_at-10.0,m.speed()])
	# Jumped out at the foot over a 4.5 m gap: across, where a run jump falls.
	var course := _hill(32.0,10.0,11.0,4.5)
	var jumped := {}
	m.reset(Vector3(0.5,float(course.call(Vector2(0.5,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var landed_x := -1.0
	for i in range(300):
		# Uncrouched off the slope: the slide jump (crouched it would be the
		# long jump).
		if m.feet.x > 10.0: m.crouch = false
		var jump := m.feet.x > 10.7
		var out := _step(m,Vector2(1.0,0.0),jump,course)
		if out.has("slide_jump"): jumped = {"x":m.feet.x,"pace":m.speed()}
		if out.has("landed"):
			landed_x = m.feet.x
			break
		if m.feet.y < -1.0: break
	check(not jumped.is_empty() and float(jumped.pace) > 9.0,"Jumped surfing, it is the slide jump at its pace (%s)" % [jumped])
	check(landed_x > 15.5 and m.feet.y > -0.01,"It clears the 4.5 m gap (landed at %.2f, %.2f m past the takeoff)" % [landed_x,landed_x-float(jumped.get("x",0.0))])
	var gap_only := func(p: Vector2) -> float: return -4.0 if p.x > 11.0 and p.x < 15.5 else 0.0
	m.reset(Vector3(6.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.crouch = false
	var across := false
	for i in range(240):
		var out := _step(m,Vector2(1.0,0.0),m.feet.x > 10.7,gap_only)
		if out.has("landed"):
			across = m.feet.y > -0.01
			break
		if m.feet.y < -1.0: break
	check(not across,"A run jump from the same edge falls short")

## Run at full pace along +x, then the stick thrown back: Jump in the skid.
func _flip(ground: Callable, start := Vector3.ZERO) -> Dictionary:
	var m := PilotMotor.new()
	m.reset(start,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	var out := {}
	var flipped := false
	var from := m.feet
	var peak := 0.0
	var ledge := func(near: Vector2, y: float) -> Dictionary: return PilotLedge.find(ground,near,y)
	for i in range(200):
		var skid := m.skidding
		var was := m.feet
		out = _step(m,Vector2(-1.0,0.0),skid and not flipped,ground,ledge)
		if out.has("side_flip"):
			flipped = true
			from = was
		peak = maxf(peak,m.feet.y-from.y)
		if flipped and (m.grounded or m.on_ledge()) and not out.has("side_flip"): break
	return {"flipped":flipped,"peak":peak,"reach":absf(m.feet.x-from.x),"facing":PilotMotor.forward(m.facing),"motor":m}

func _side_flip() -> void:
	var f := _flip(flat)
	var m: PilotMotor = f.motor
	check(f.flipped,"Jumped skidding round, it is the side flip")
	check(absf(float(f.peak)-PilotMotor.SIDE_FLIP) < 0.02 and float(f.peak) > PilotMotor.JUMPS[1],"It goes %.2f m up, over the pump's %.1f" % [f.peak,PilotMotor.JUMPS[1]])
	check(float(f.reach) < 2.2 and (f.facing as Vector2).dot(Vector2(-1.0,0.0)) > 0.99,"%.2f m along, the way the stick points" % f.reach)
	check(m.grounded and m.move == "","And lands")
	# Onto a 1.9 m ledge behind him.
	var ledge := func(p: Vector2) -> float: return 1.9 if p.x < -1.2 else 0.0
	var up := _flip(ledge)
	var um: PilotMotor = up.motor
	check(up.flipped and (um.grounded and um.feet.y > 1.89 or um.on_ledge()),"Flipped at a 1.9 m ledge behind him he gets up onto it (%.2f, %s)" % [um.feet.y,um.hold])
	# A plain jump at a run is not one.
	var p := PilotMotor.new()
	p.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	var out := _step(p,Vector2(1.0,0.0),true)
	check(out.get("jumped",0) == 1 and not out.has("side_flip"),"A jump at a run is the plain jump")

## Hanging on a 2 m wall, Jump: seconds to standing on top.
func _climb_time() -> void:
	var wall := func(p: Vector2) -> float: return 2.0 if p.x > 1.0 else 0.0
	var ledge := func(near: Vector2, y: float) -> Dictionary: return PilotLedge.find(wall,near,y)
	var m := PilotMotor.new()
	m.reset(Vector3(0.6,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.feet.y = 1.4
	m.grounded = false
	for i in range(60):
		_step(m,Vector2.ZERO,false,wall,ledge)
		if m.hold == "hang": break
	for i in range(10): _step(m,Vector2.ZERO,false,wall,ledge)
	var t := 0.0
	var pressed := true
	for i in range(120):
		var out := _step(m,Vector2.ZERO,pressed,wall,ledge)
		pressed = false
		t += DT
		if out.has("climbed"): break
	check(m.grounded and m.feet.y > 1.99 and t <= 0.45,"Hanging, Jump stands him on top in %.2f s" % t)
	# A press while the catch settles is kept for the climb.
	m.reset(Vector3(0.6,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.feet.y = 1.4
	m.grounded = false
	var hung_at := -1
	for i in range(120):
		var out := _step(m,Vector2.ZERO,hung_at >= 0 and i == hung_at+1,wall,ledge)
		if m.hold == "hang" and hung_at < 0: hung_at = i
		if out.has("climbed"): break
	check(m.grounded and m.feet.y > 1.99,"Jump pressed as he catches the lip is kept for the climb")
