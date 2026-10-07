extends SceneTree
## The pilot on foot (scripts/pilot_motor.gd, drawn by scripts/pilot_figure.gd):
## the stick runs it up to its pace and turns it to face the way; let go it
## stops; thrown back at a run it skids, then turns; a tap jumps lower than a
## held jump, which reaches the first of JUMPS; jumps chained at a run go
## higher, the third with a flip; a press just before landing is kept, one
## just after a ledge still jumps; a ledge drops it, a wall in the air stops
## it; Space again on the way up asks to fly, near the ground falling it does
## not. The drawn pilot follows it through every state without its pose
## going wrong.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const DT := 1.0/60.0
var failures := 0
## The ground: flat at 0, a ledge down 2 m past x 10, a wall up 3 m past
## z -10.
var ground := func(p: Vector2) -> float:
	if p.y < -10.0: return 3.0
	return -2.0 if p.x > 10.0 else 0.0
var slide := func(feet: Vector3, step: Vector2) -> Vector3: return feet+Vector3(step.x,0.0,step.y)

func _initialize() -> void:
	var m := PilotMotor.new()
	var figure := PilotFigure.new()
	root.add_child(figure)
	# The run.
	m.reset(Vector3.ZERO,0.0)
	_run(m,figure,Vector2(1.0,0.0),PilotMotor.RUN,false,60)
	check(absf(m.speed()-PilotMotor.RUN) < 0.05,"The stick runs it up to its pace (%.2f)" % m.speed())
	check(PilotMotor.forward(m.facing).distance_to(Vector2(1.0,0.0)) < 0.01,"Facing the way it runs")
	_run(m,figure,Vector2.ZERO,PilotMotor.RUN,false,40)
	check(m.speed() < 0.01,"Let go, it stops")
	# The skid.
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.RUN)
	m.step(DT,Vector2(-1.0,0.0),PilotMotor.RUN,false,ground,slide)
	check(m.skidding,"Thrown back at a run, it skids")
	_run(m,figure,Vector2(-1.0,0.0),PilotMotor.RUN,false,60)
	check(not m.skidding and PilotMotor.forward(m.facing).distance_to(Vector2(-1.0,0.0)) < 0.01 and m.velocity.x < -1.0,"Then turns and runs back")
	# Tap against hold.
	var held := _jump_height(m,figure,999)
	var tapped := _jump_height(m,figure,3)
	check(absf(held-float(PilotMotor.JUMPS[0])) < 0.08,"A held jump reaches the first height (%.2f m)" % held)
	check(tapped < held*0.75,"A tap jumps lower (%.2f m)" % tapped)
	# The chain.
	m.reset(Vector3.ZERO,PilotMotor.facing_of(Vector2(0.0,1.0)))
	_run(m,figure,Vector2(0.0,1.0),PilotMotor.RUN,false,40)
	var chained := []
	var flipped := false
	var jump := false
	for i in range(600):
		# Held through each jump; let go just before landing and pressed
		# again on it, with the buffer.
		jump = not (m.velocity.y < 0.0 and m.feet.y < 0.3) if not m.grounded else not jump
		var out := m.step(DT,Vector2(0.0,1.0),PilotMotor.RUN,jump,ground,slide)
		figure.drive(m,DT)
		if out.has("jumped"): chained.append(out.jumped)
		flipped = flipped or m.flip > 0.5
		if chained.size() == 3 and m.grounded: break
	check(chained == [1,2,3],"Chained at a run, the jumps go 1, 2, 3: %s" % [chained])
	check(flipped,"The third flips")
	# The ledge, coyote time and the buffer.
	m.reset(Vector3(9.5,0.0,0.0),PilotMotor.facing_of(Vector2(1.0,0.0)),PilotMotor.WALK)
	var fell := false
	for i in range(30):
		m.step(DT,Vector2(1.0,0.0),PilotMotor.WALK,false,ground,slide)
		if not m.grounded:
			fell = true
			break
	check(fell and m.feet.y > -0.01,"Off a ledge it falls, from where it stood")
	var coyote := m.step(DT,Vector2(1.0,0.0),PilotMotor.WALK,true,ground,slide)
	check(coyote.has("jumped"),"Just off it, Space still jumps")
	_settle(m)
	m.step(DT,Vector2.ZERO,PilotMotor.RUN,true,ground,slide)
	var pressed_early := false
	var flew := false
	var again := false
	for i in range(120):
		var low: bool = m.velocity.y < 0.0 and m.feet.y < 0.25
		var out := m.step(DT,Vector2.ZERO,PilotMotor.RUN,low,ground,slide)
		flew = flew or out.has("fly")
		pressed_early = pressed_early or low
		if out.has("jumped"):
			again = true
			break
	check(not flew,"Near the ground falling, Space does not fly")
	check(pressed_early and again and not m.grounded and m.velocity.y > 0.0,"Pressed just before landing, it jumps on the touch")
	# A wall in the air.
	_settle(m)
	m.reset(Vector3(0.0,0.0,-9.8),PilotMotor.facing_of(Vector2(0.0,-1.0)),PilotMotor.RUN)
	m.step(DT,Vector2(0.0,-1.0),PilotMotor.RUN,true,ground,slide)
	for i in range(30): m.step(DT,Vector2(0.0,-1.0),PilotMotor.RUN,true,ground,slide)
	check(m.feet.z >= -10.01,"A wall in the air stops it (%.2f)" % m.feet.z)
	_settle(m)
	m.reset(Vector3(0.0,0.0,-9.8),PilotMotor.facing_of(Vector2(0.0,-1.0)),PilotMotor.RUN)
	for i in range(30): m.step(DT,Vector2(0.0,-1.0),PilotMotor.RUN,false,ground,slide)
	check(m.feet.z >= -10.01 and m.feet.y < 0.01,"And on the ground (%.2f)" % m.feet.z)
	# Fly: again on the way up.
	_settle(m)
	m.step(DT,Vector2.ZERO,PilotMotor.RUN,true,ground,slide)
	m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)
	var fly := m.step(DT,Vector2.ZERO,PilotMotor.RUN,true,ground,slide)
	check(fly.has("fly"),"Space again on the way up asks to fly")
	var ok := true
	for node: Node3D in figure.find_children("*","Node3D",true,false):
		ok = ok and node.transform.origin.is_finite() and node.transform.basis.x.is_finite()
	check(ok,"The drawn pilot's parts stay finite")
	figure.free()
	print("PASS: pilot motor" if failures == 0 else "FAIL: pilot motor")
	quit(1 if failures else 0)

## Stood on the ground at the origin, Space let go.
func _settle(m: RefCounted) -> void:
	m.reset(Vector3.ZERO,0.0)
	m.step(DT,Vector2.ZERO,PilotMotor.RUN,false,ground,slide)

func _run(m: RefCounted, figure: Node3D, want: Vector2, top: float, jump: bool, frames: int) -> void:
	for i in range(frames):
		m.step(DT,want,top,jump,ground,slide)
		figure.drive(m,DT)

## The highest a jump from a stand goes, Space held `frames` frames.
func _jump_height(m: RefCounted, figure: Node3D, frames: int) -> float:
	m.reset(Vector3.ZERO,0.0)
	_run(m,figure,Vector2.ZERO,PilotMotor.RUN,false,30)
	var high := 0.0
	for i in range(240):
		m.step(DT,Vector2.ZERO,PilotMotor.RUN,i < frames,ground,slide)
		figure.drive(m,DT)
		high = maxf(high,m.feet.y)
		if i > 2 and m.grounded: break
	return high

func check(ok: bool, what: String) -> void:
	if ok: print("ok   ",what)
	else:
		failures += 1
		print("FAIL ",what)
