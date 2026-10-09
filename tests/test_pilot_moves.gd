extends SceneTree
## The pilot's moves on foot (scripts/pilot_motor.gd), over heights alone
## (the game's own way: no physics, walls from the ground's rise): the jump
## and the pump peak at their set heights at 30, 60 and 144 frames a
## second; jumped again within CHAIN_WINDOW of a landing (or pressed in the
## buffer before it) is the pump, later is not, and there is no third
## tier; crouched at a run he slides to a stop, and jumped from it it is the
## long jump, low and far (over a 3.5 m gap, short of a 4 m one), while a crouch
## from a stand jumps as ever; into a wall in the air with the stick held
## he slides down it no faster than WALL_SLIDE, lets go when the stick does,
## and Jump kicks him up and out, not steering a while; kicked between two
## walls facing each other he climbs.
##   godot --headless --path . --script tests/test_pilot_moves.gd
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
var failures := 0
var flat := func(_p: Vector2) -> float: return 0.0
var free := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)
## A wall 6 m tall past x 2.
var one_wall := func(p: Vector2) -> float: return 6.0 if p.x > 2.0 else 0.0
## A shaft: walls 9 m tall past x -1.25 and 1.25 (a body 0.28 m round
## between walls 2.8 m apart).
var shaft := func(p: Vector2) -> float: return 9.0 if absf(p.x) > 1.25 else 0.0
var figure: Node3D

func _initialize() -> void:
	figure = PilotFigure.new()
	root.add_child(figure)
	_frame_rates()
	_pump_window()
	_long_jump()
	_wall_slide()
	_wall_jumps()
	figure.free()
	print("PASS: pilot moves" if failures == 0 else "FAIL: pilot moves (%d)" % failures)
	quit(1 if failures else 0)

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)

func _step(m: PilotMotor, dt: float, want: Vector2, jump: bool, ground: Callable = flat) -> Dictionary:
	var out := m.step(dt,want,PilotMotor.RUN,jump,ground,free)
	figure.drive(m,dt)
	return out

## The jump held from a stand, then (pressed again on the landing) the pump:
## their peaks at `fps`.
func _peaks(fps: float) -> Array:
	var dt := 1.0/fps
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,0.0)
	var peaks := []
	var jump := true
	for i in range(int(fps*3.0)):
		var out := _step(m,dt,Vector2.ZERO,jump)
		if out.has("jumped"): peaks.append(0.0)
		if not peaks.is_empty(): peaks[-1] = maxf(peaks[-1],m.feet.y)
		# Held up, let go falling, pressed again on the touch.
		jump = m.grounded or m.velocity.y > 0.0
		if out.has("landed") and peaks.size() == 2: break
	return peaks

func _frame_rates() -> void:
	for fps: float in [30.0,60.0,144.0]:
		var peaks := _peaks(fps)
		check(peaks.size() == 2 and absf(peaks[0]-PilotMotor.JUMPS[0]) < 0.01 and absf(peaks[1]-PilotMotor.JUMPS[1]) < 0.01,
			"At %d fps the jump peaks at %.3f m and the pump at %.3f m (set %.2f and %.2f)" % [fps,peaks[0] if peaks.size() > 0 else -1.0,peaks[1] if peaks.size() > 1 else -1.0,PilotMotor.JUMPS[0],PilotMotor.JUMPS[1]])
	var reaches := []
	for fps: float in [30.0,60.0,144.0]: reaches.append(_long_reach(1.0/fps).reach)
	check(absf(reaches[0]-reaches[2]) < 0.15 and absf(reaches[1]-reaches[2]) < 0.08,"The long jump goes as far at 30, 60 and 144 fps: %s" % [reaches])

## Jumped, landed, then pressed `wait` s after the landing (negative: before
## it, in the buffer): the jump's number.
func _after_landing(wait: float) -> int:
	var dt := 1.0/60.0
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,0.0)
	_step(m,dt,Vector2.ZERO,true)
	var landed_at := -1.0
	var t := 0.0
	var was_down := false
	for i in range(400):
		t += dt
		var press := false
		if wait < 0.0: press = not m.grounded and m.velocity.y < 0.0 and m.feet.y < -wait*absf(m.velocity.y)
		elif landed_at >= 0.0: press = t-landed_at >= wait-1e-6
		var out := _step(m,dt,Vector2.ZERO,press)
		if out.has("landed") and landed_at < 0.0: landed_at = t
		if out.has("jumped"): return int(out.jumped)
		if was_down and not press: pass
		was_down = press
	return 0

func _pump_window() -> void:
	check(_after_landing(0.0) == 2,"Pressed on the landing, the pump")
	check(_after_landing(0.25) == 2,"Pressed 0.25 s after the landing, still the pump")
	check(_after_landing(0.12*-1.0) == 2,"Pressed just before the landing (the buffer), the pump")
	check(_after_landing(0.45) == 1,"Pressed 0.45 s after it, a plain jump")
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,0.0)
	var numbers := []
	var jump := true
	for i in range(1200):
		var out := _step(m,1.0/60.0,Vector2.ZERO,jump)
		if out.has("jumped"): numbers.append(out.jumped)
		jump = m.grounded or m.velocity.y > 0.0
		if numbers.size() == 5 and m.grounded: break
	check(numbers == [1,2,2,2,2],"Timed jumps on and on: %s (no third tier)" % [numbers])

## A long jump from a full run, level: its reach and peak.
func _long_reach(dt: float) -> Dictionary:
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.crouch = true
	_step(m,dt,Vector2(1.0,0.0),false)
	var from := m.feet
	var out := _step(m,dt,Vector2(1.0,0.0),true)
	var long := out.has("long")
	m.crouch = false
	var peak := 0.0
	for i in range(int(2.0/dt)):
		out = _step(m,dt,Vector2(1.0,0.0),true)
		peak = maxf(peak,m.feet.y)
		if out.has("landed"): break
	return {"long":long,"reach":m.feet.x-from.x,"peak":peak,"move":m.move}

## A long jump from 0.1 m short of a gap `gap` wide onto a top level with
## the takeoff: whether he lands on it.
func _long_gap(gap: float) -> bool:
	var ground := func(p: Vector2) -> float: return -5.0 if p.x > 0.0 and p.x < gap else 0.0
	var m := PilotMotor.new()
	m.reset(Vector3(-3.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	for i in range(240):
		var out := _step(m,1.0/60.0,Vector2(1.0,0.0),m.feet.x > -0.1,ground)
		m.crouch = m.grounded and m.feet.x > -0.5
		if out.has("landed") and m.feet.x > 0.0: return m.feet.y > -0.01
		if m.feet.y < -1.0: return false
	return false

func _long_jump() -> void:
	# Crouched at a run he slides to a stop.
	var m := PilotMotor.new()
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.crouch = true
	var paces := []
	var turned := false
	for i in range(60):
		_step(m,1.0/60.0,Vector2(0.0,1.0),false)
		if i%15 == 0: paces.append(snappedf(m.speed(),0.01))
		if m.speed() > 0.5: turned = turned or PilotMotor.forward(m.facing).dot(Vector2(1.0,0.0)) < 0.99
	check(m.move == "crouch" and m.speed() < 0.01 and paces[0] > paces[1] and paces[1] > paces[2],"Crouched at a run he slides to a stop: %s m/s" % [paces])
	check(not turned,"Sliding crouched, the stick does not turn him")
	var long := _long_reach(1.0/60.0)
	check(long.long and absf(float(long.peak)-PilotMotor.LONG_HEIGHT) < 0.02,"Crouched at a run and jumped: the long jump, %.2f m up" % float(long.peak))
	check(absf(float(long.reach)-PilotMotor.LONG_SPEED*2.0*sqrt(2.0*PilotMotor.LONG_HEIGHT/PilotMotor.LONG_GRAVITY)) < 0.12,"Level it goes %.2f m" % float(long.reach))
	for gap: float in [3.0,3.5,4.0]:
		var over := _long_gap(gap)
		check(over == (gap < 3.9),"Long-jumped from the edge of a %.1f m gap, he %s" % [gap,"lands across it" if over else "falls short"])
	# From a stand a crouch jumps as ever.
	m.reset(Vector3.ZERO,0.0)
	m.crouch = true
	_step(m,1.0/60.0,Vector2.ZERO,false)
	var out := _step(m,1.0/60.0,Vector2.ZERO,true)
	check(out.get("jumped",0) == 1 and not out.has("long"),"Crouched at a stand, Jump is the plain jump")

## Run and jumped at the 6 m wall, the stick held into it.
func _onto_wall(m: PilotMotor) -> Array:
	m.reset(Vector3(0.6,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	var events := []
	for i in range(60):
		var out := _step(m,1.0/60.0,Vector2(1.0,0.0),i < 12,one_wall)
		if out.has("wall"): events.append(out.wall)
		if m.move == "wall": break
	return events

func _wall_slide() -> void:
	var m := PilotMotor.new()
	var events := _onto_wall(m)
	check(m.move == "wall" and events == [true] and m.wall_out.dot(Vector2(-1.0,0.0)) > 0.99,"Jumped into a tall wall with the stick held, he takes hold of it (%s, way off %s)" % [m.move,m.wall_out])
	var fastest := 0.0
	var high := m.feet.y
	for i in range(20):
		_step(m,1.0/60.0,Vector2(1.0,0.0),false,one_wall)
		fastest = maxf(fastest,-m.velocity.y)
	check(m.move == "wall" and fastest <= PilotMotor.WALL_SLIDE+0.01 and m.feet.y < high,"He slides down it, no faster than %.1f m/s (%.2f)" % [PilotMotor.WALL_SLIDE,fastest])
	check(PilotMotor.forward(m.facing).dot(Vector2(1.0,0.0)) > 0.9,"Facing the wall")
	var off := -1
	for i in range(30):
		var out := _step(m,1.0/60.0,Vector2.ZERO,false,one_wall)
		if out.get("wall",true) == false:
			off = i
			break
	check(off >= 0 and off <= roundi(PilotMotor.WALL_LET*60.0)+1 and m.move != "wall","The stick let go, he drops off it (%d frames)" % off)
	# Held on to the ground, the landing ends it.
	_onto_wall(m)
	var landed := false
	for i in range(240):
		var out := _step(m,1.0/60.0,Vector2(1.0,0.0),false,one_wall)
		if out.has("landed"):
			landed = true
			break
	check(landed and m.move == "" and m.grounded,"Held on to the bottom, he lands and lets go")
	# A short wall is not slid down.
	var low := func(p: Vector2) -> float: return 1.0 if p.x > 2.0 else 0.0
	m.reset(Vector3(0.6,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	var slid := false
	for i in range(60):
		_step(m,1.0/60.0,Vector2(1.0,0.0),i < 12,low)
		slid = slid or m.move == "wall"
	check(not slid,"A wall under WALL_TALL is not slid down")

func _wall_jumps() -> void:
	var m := PilotMotor.new()
	_onto_wall(m)
	var from := m.feet
	var out := _step(m,1.0/60.0,Vector2(1.0,0.0),true,one_wall)
	check(out.has("wall_jump") and m.move == "kick" and m.velocity.x < -PilotMotor.WALL_KICK*0.9 and m.velocity.y > 0.0,"Jump on the wall kicks him up and out (%.1f, %.1f m/s)" % [m.velocity.x,m.velocity.y])
	check(PilotMotor.forward(m.facing).dot(Vector2(-1.0,0.0)) > 0.99,"Turned round, away from it")
	var peak := from.y
	var steered := m.velocity.x
	for i in range(roundi(PilotMotor.WALL_LOCK*60.0)-2):
		_step(m,1.0/60.0,Vector2(1.0,0.0),true,one_wall)
		peak = maxf(peak,m.feet.y)
	check(absf(m.velocity.x-steered) < 0.01,"The stick held back at the wall does not steer him a while")
	for i in range(60):
		_step(m,1.0/60.0,Vector2.ZERO,true,one_wall)
		peak = maxf(peak,m.feet.y)
	check(absf(peak-from.y-PilotMotor.WALL_JUMP) < 0.05,"It kicks him %.2f m up (WALL_JUMP %.2f)" % [peak-from.y,PilotMotor.WALL_JUMP])
	# Up a shaft: kicked from wall to wall, the stick turned each time.
	m.reset(Vector3(0.0,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)))
	var way := Vector2(1.0,0.0)
	var kicks := []
	var on_wall := 0
	var jump := true
	for i in range(900):
		if m.move == "wall": on_wall += 1
		else: on_wall = 0
		# On the wall a few frames, Jump, and the stick to the far wall.
		jump = (m.move != "wall" and m.velocity.y > 0.0) or on_wall >= 4 or (m.grounded and m.feet.x > 0.5)
		out = _step(m,1.0/60.0,way,jump,shaft)
		if out.has("wall_jump"):
			kicks.append(snappedf(m.feet.y,0.01))
			way = -way
		if kicks.size() >= 5: break
	var gains := []
	for k in range(2,kicks.size()): gains.append(snappedf(kicks[k]-kicks[k-1],0.01))
	check(kicks.size() >= 5 and gains.all(func(g: float) -> bool: return g > 0.7),"Kicked between walls 2.8 m apart he climbs: kicks at %s m (from wall to wall, %s m a kick)" % [kicks,gains])
