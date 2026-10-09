extends SceneTree
## The pilot's momentum on foot (scripts/pilot_motor.gd), over heights alone
## (the game's own way), measured and printed: a long jump from a run goes
## further than it did; long jumps strung together, each pressed on the
## touch, go faster and further, to LONG_TOP and no faster, where late ones
## stay at the long jump's own pace; carried pace bleeds away on the ground
## and is kept longer with the stick held on; the crouched slide runs on far
## along the flat; crouched down a long steep slope he gains well past the
## run, steeper faster, under SLIDE_TOP, and carries it out onto the flat;
## and the twirl stretches a running jump and a long jump. No pace ever
## turns into height.
##   godot --headless --path . --script tests/test_pilot_momentum.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const DT := 1.0/60.0
var failures := 0
var flat := func(_p: Vector2) -> float: return 0.0
var free := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)

func _initialize() -> void:
	_long_once()
	_chains()
	_carry()
	_flat_slide()
	_slopes()
	_twirl()
	print("PASS: pilot momentum" if failures == 0 else "FAIL: pilot momentum (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

func _step(m: PilotMotor, want: Vector2, jump: bool, ground: Callable = flat) -> Dictionary:
	return m.step(DT,want,PilotMotor.RUN,jump,ground,free)

## Running along +x at full pace.
func _runner(at := Vector3.ZERO) -> PilotMotor:
	var m := PilotMotor.new()
	m.reset(at,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	return m

## A long jump from a full run, level: its reach.
func _long_once() -> void:
	var m := _runner()
	m.crouch = true
	_step(m,Vector2(1.0,0.0),false)
	var from := m.feet.x
	var out := _step(m,Vector2(1.0,0.0),true)
	var peak := 0.0
	for i in range(180):
		out = _step(m,Vector2(1.0,0.0),true)
		peak = maxf(peak,m.feet.y)
		if out.has("landed"): break
	print("MEASURE long jump from a run: %.2f m level, %.2f m up" % [m.feet.x-from,peak])
	check(m.feet.x-from > 4.0 and absf(peak-PilotMotor.LONG_HEIGHT) < 0.02,"One long jump from a run goes %.2f m (it went 3.31)" % (m.feet.x-from))

## Long jumps one after another, crouch held throughout, Jump pressed
## `late` s after each landing (0: the step after the touch; negative: in
## the buffer before it): the paces taken off at, the distance from the
## first takeoff to the last landing, and the seconds.
func _chain(late: float, count := 5) -> Dictionary:
	var m := _runner()
	m.crouch = true
	_step(m,Vector2(1.0,0.0),false)
	var from := m.feet.x
	var paces := []
	var t := 0.0
	var since := -1.0
	var press := true
	var top := 0.0
	var landed := 0
	for i in range(1200):
		var out := _step(m,Vector2(1.0,0.0),press)
		t += DT
		top = maxf(top,m.speed())
		if out.has("long"): paces.append(snappedf(m.speed(),0.01))
		if out.has("landed"):
			landed += 1
			since = 0.0
			if landed >= count: break
		elif since >= 0.0: since += DT
		if late < 0.0: press = not m.grounded and m.velocity.y < 0.0 and m.feet.y < 0.25 and not press
		else: press = since >= late-1e-6 and since >= 0.0 and m.grounded and not press
		if press: since = -1.0
		if m.move != "long" and not m.grounded: break
	return {"paces":paces,"distance":m.feet.x-from,"time":t,"top":top,"jumps":paces.size()}

func _chains() -> void:
	var good := _chain(0.0)
	var buffered := _chain(-1.0)
	var late := _chain(0.35)
	for pair: Array in [["on the touch",good],["in the buffer",buffered],["late (0.35 s)",late]]:
		var c: Dictionary = pair[1]
		print("MEASURE 5 long jumps, pressed %s: paces %s, top %.2f m/s, %.2f m in %.2f s (%.2f m/s; a run %.2f m)" % [pair[0],c.paces,c.top,c.distance,c.time,c.distance/c.time,PilotMotor.RUN*c.time])
	check(good.jumps == 5 and float(good.top) > 11.5 and float(good.top) <= PilotMotor.LONG_TOP+0.01,"Timed on the touch, the chain builds to %.2f m/s (LONG_TOP %.1f)" % [good.top,PilotMotor.LONG_TOP])
	check(buffered.jumps == 5 and float(buffered.top) > 11.5,"Pressed in the buffer before the touch, it chains too (%.2f m/s)" % buffered.top)
	check(late.jumps == 5 and float(late.top) <= PilotMotor.LONG_SPEED+0.01,"Pressed late, nothing is added (%.2f m/s)" % late.top)
	check(float(good.distance)/float(good.time) > 2.0*PilotMotor.RUN,"A timed chain goes %.2f m/s on average, over twice the run" % (float(good.distance)/float(good.time)))
	check(float(good.distance)/float(good.time) > float(late.distance)/float(late.time)*1.3,"Timed, the five go %.2f m in %.2f s; late, %.2f m in %.2f s" % [good.distance,good.time,late.distance,late.time])
	var long := _chain(0.0,12)
	check(float(long.top) <= PilotMotor.LONG_TOP+0.01,"Twelve timed, no faster than LONG_TOP (%.2f m/s)" % long.top)

## Carried pace: landed at 10 m/s, held on, at half stick, let go.
func _carry() -> void:
	var times := {}
	for how: String in ["on","half","none"]:
		var m := PilotMotor.new()
		m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),10.0)
		var want := {"on":Vector2(1.0,0.0),"half":Vector2(0.5,0.0),"none":Vector2.ZERO}[how] as Vector2
		var t := 0.0
		while m.speed() > PilotMotor.RUN+0.05 and t < 10.0:
			_step(m,want,false)
			t += DT
		times[how] = t
	print("MEASURE carried 10 m/s back to the run: held on %.2f s, half stick %.2f s, let go %.2f s" % [times.on,times.half,times.none])
	check(float(times.on) > 1.5 and float(times.on) < 3.0,"Held on, 10 m/s bleeds to the run over %.2f s" % times.on)
	check(float(times.half) < float(times.on)*0.6,"At half stick, sooner (%.2f s)" % times.half)

## Crouched at a run on the flat: how far the slide goes.
func _flat_slide() -> void:
	var m := _runner()
	m.crouch = true
	var moves := {}
	var t := 0.0
	for i in range(600):
		_step(m,Vector2(1.0,0.0),false)
		moves[m.move] = true
		t += DT
		if m.speed() < 0.05: break
	print("MEASURE flat slide from a run: %.2f m in %.2f s (the crouch's stop went 1.65 m)" % [m.feet.x,t])
	check(moves.has("slide") and m.move == "crouch" and m.feet.x > 3.5,"Crouched at a run he slides on %.2f m and ends crouched" % m.feet.x)

## A slope `degrees` steep dropping `drop` m to a flat at x = its length
## (and a pit `gap` wide from `gap_at` m past its foot).
func _hill(degrees: float, drop: float, gap_at := 999.0, gap := 0.0) -> Dictionary:
	var rise := tan(deg_to_rad(degrees))
	var length := drop/rise
	var ground := func(p: Vector2) -> float:
		if p.x > length+gap_at and p.x < length+gap_at+gap: return -6.0
		return clampf(length-p.x,0.0,length)*rise
	return {"ground":ground,"foot":length}

## Crouched from a stand at the top of `hill`: the pace at its foot, and how
## far onto the flat he goes, crouched to a stop or (`stand`) uncrouched at
## the foot until he runs.
func _surf_out(hill: Dictionary, stand := false) -> Dictionary:
	var g: Callable = hill.ground
	var foot: float = hill.foot
	var m := PilotMotor.new()
	m.reset(Vector3(0.3,float(g.call(Vector2(0.3,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var at_foot := -1.0
	var top := 0.0
	var t := 0.0
	var foot_t := 0.0
	for i in range(3000):
		_step(m,Vector2(1.0,0.0),false,g)
		t += DT
		top = maxf(top,m.speed())
		if at_foot < 0.0 and m.feet.x >= foot:
			at_foot = m.speed()
			foot_t = t
			if stand: m.crouch = false
		if at_foot >= 0.0 and (m.speed() < 0.05 or (stand and m.move == "")): break
	return {"foot":at_foot,"out":m.feet.x-foot,"top":top,"down":foot_t,"pace":m.speed()}

func _slopes() -> void:
	var big := _hill(35.0,20.0)
	var crouched := _surf_out(big)
	var stood := _surf_out(big,true)
	print("MEASURE 35° slope, 20 m drop (%.1f m along the ground): %.2f m/s at the foot after %.2f s; crouched it runs out %.2f m to a stop; uncrouched %.2f m to a run (at %.2f m/s)" % [big.foot,crouched.foot,crouched.down,crouched.out,stood.out,stood.pace])
	check(float(crouched.foot) > 14.0 and float(crouched.top) <= PilotMotor.SLIDE_TOP+0.01,"Down the big slope he gains to %.2f m/s, under SLIDE_TOP" % crouched.foot)
	check(float(crouched.out) > 12.0,"And runs out %.2f m along the flat" % crouched.out)
	var small := _surf_out(_hill(32.0,6.25))
	var steep := _surf_out(_hill(50.0,6.25*tan(deg_to_rad(50.0))/tan(deg_to_rad(32.0))))
	print("MEASURE 10 m of 32°: %.2f m/s at the foot, runs out %.2f m; as long a run of 50°: %.2f m/s" % [small.foot,small.out,steep.foot])
	check(float(steep.foot) > float(small.foot)+1.0,"Steeper gains faster (%.2f against %.2f m/s)" % [steep.foot,small.foot])
	var sheer := _surf_out(_hill(60.0,80.0))
	check(float(sheer.top) <= PilotMotor.SLIDE_TOP+0.01,"Down 80 m of 60°, no faster than SLIDE_TOP (%.2f)" % sheer.top)
	# Long-jumped out at the foot of the big slope: at its pace.
	var g: Callable = big.ground
	var m := PilotMotor.new()
	m.reset(Vector3(0.3,float(g.call(Vector2(0.3,0.0))),0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	m.crouch = true
	var from := 0.0
	var pace := 0.0
	var peak := 0.0
	for i in range(1200):
		var out := _step(m,Vector2(1.0,0.0),m.feet.x > float(big.foot)+1.0 and m.grounded,g)
		if out.has("long"):
			from = m.feet.x
			pace = m.speed()
		if from > 0.0: peak = maxf(peak,m.feet.y)
		if from > 0.0 and out.has("landed"): break
	print("MEASURE long jump 1 m out of the big slope's foot: %.2f m/s, %.2f m, %.2f m up" % [pace,m.feet.x-from,peak])
	check(pace > 13.0 and absf(peak-PilotMotor.LONG_HEIGHT) < 0.02,"Long-jumped out at its foot he keeps the slide's pace (%.2f m/s), no higher" % pace)

## A running jump held, the twirl pressed at its top (or not): its reach.
## A long jump from a run, the twirl pressed as it comes down (or not).
func _twirl() -> void:
	var reach := []
	for twirl: bool in [false,true]:
		var m := _runner()
		var from := m.feet.x
		_step(m,Vector2(1.0,0.0),true)
		for i in range(240):
			m.crouch = twirl and m.velocity.y <= 0.0
			var out := _step(m,Vector2(1.0,0.0),true)
			if out.has("landed"): break
		reach.append(m.feet.x-from)
	var long := []
	for twirl: bool in [false,true]:
		var m := _runner()
		m.crouch = true
		_step(m,Vector2(1.0,0.0),false)
		var from := m.feet.x
		_step(m,Vector2(1.0,0.0),true)
		m.crouch = false
		for i in range(240):
			m.crouch = twirl and m.velocity.y < 0.0 and m.feet.y < 0.3
			var out := _step(m,Vector2(1.0,0.0),true)
			if out.has("landed"): break
		long.append(m.feet.x-from)
	print("MEASURE twirl at a running jump's top: %.2f m against %.2f m (+%.2f); at a long jump's end: %.2f m against %.2f m (+%.2f)" % [reach[1],reach[0],reach[1]-reach[0],long[1],long[0],long[1]-long[0]])
	check(reach[1]-reach[0] > 2.5,"A twirl at a running jump's top stretches it %.2f m" % (reach[1]-reach[0]))
	check(long[1]-long[0] > 3.5,"A twirl at a long jump's end stretches it %.2f m" % (long[1]-long[0]))
