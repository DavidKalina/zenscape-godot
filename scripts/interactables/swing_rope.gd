extends Node3D
## A swing rope (docs/design/foot-interactables.md): a rope `length` m long
## hung from `anchor` (an arch's soffit, a lintel, a beam), its free end
## swinging as a pendulum. Jumped into (his hands within CATCH of it, or his
## chest within CATCH_BODY, on its lower part, from GRIP_HIGH of its length
## down), he takes hold where his hands are, the rope swung to them (he is
## never pulled in), and rides it (the motor's `rider`, scripts/pilot_motor.gd,
## hanging as on a ledge: `hold` "swing"): the rope's swing takes up his
## pace across it, so a run and a jump into it is a swing at once.
##
## Hanging, he is a pendulum from the anchor at his grip (GRAVITY): the
## stick along his swing pumps it (PUMP, m/s², only while it goes the
## stick's way, so a held stick pumps the half swing it points along and a
## stick worked in time pumps both), across it steers its plane round
## (STEER), and he turns to face the stick (TURN). The swing is held under
## MOST from the plumb; it loses DAMP of its pace a second. Jump lets go
## with the rope's velocity at his hands, BOOST more along it as well as
## the release is timed (`timing`: all of it rising BEST past the plumb,
## none WINDOW either side), capped at TOP, and POP more up: let go well,
## it is a launch (a 5.6 m rope's about 18 m/s, 19 m out, a running long
## jump's 4.2 m four times over); let go early or late, about half that.
## The twirl, the wall run and the sail are fresh after it. Crouch drops
## off (no boost, no pop). Let go, the same rope can't be caught for
## REGRAB s; another can, so ropes chain. On the ground he takes it only
## running into it (RUN_IN): his hands meet its knot.
##
## Free, its end swings on as a pendulum and settles (and sways a little in
## the air), drawn as a faceted rope in the footbridges' rope tone
## (scripts/footbridge.gd ROPE), thick enough to read across a gap, a knot
## at its end and an iron ring at the anchor; `add_tag` hangs a weathered
## cloth tag beside it, so a rope is seen from across the isle. The numbers are live (the yard's F4, studies/
## interactables_yard.gd): `t_*` read each frame.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const PilotFigure = preload("res://scripts/pilot_figure.gd")
const Footbridge = preload("res://scripts/footbridge.gd")

## The placed ropes' length (m) and their knot's height over the ground
## they hang over (m): at a standing walker's hands (PilotMotor HANG_DROP
## 0.825), so a run straight into one takes it, and a jump's hands, rising
## to 1.6 m, meet it anywhere on its lower part. The yard's F4 `t_length`
## re-lays its ropes, the knot kept there.
const LENGTH := 5.6
const KNOT := 0.9
const GRAVITY := 20.0
const PUMP := 3.5
const STEER := 3.0
const TURN := 2.5
const MOST := 1.35
const DAMP := 0.08
const TOP := 24.0
const POP := 1.5
## The release's boost (m/s, along the swing) for a perfect timing: let go
## rising, the rope BEST rad past the plumb, it is all of it; WINDOW rad
## either side of that, none (falling off as the square). Let go falling,
## or at the bottom, or crouched off, no boost.
const BOOST := 6.0
const BEST := 0.75
const WINDOW := 0.5
## Run into on the ground at RUN_IN m/s or more (toward it), he takes it
## too: its knot hangs at his hands.
const RUN_IN := 3.0
const CATCH := 0.3
const CATCH_BODY := 0.32
## The chest's height over the feet (m), for running into it.
const CHEST := 0.6
const GRIP_HIGH := 0.35
const REGRAB := 0.45
## Free, its end's damping a second, and its sway (m/s² at the end).
const FREE_DAMP := 0.35
const SWAY := 0.25
## The rope's radius drawn (m).
const RADIUS := 0.06
## A tag's width and length (m), its cloth's tone (a faded madder).
const TAG := Vector2(0.6,1.8)
const TAG_TONE := Color("b04a2c")

static var t_length := LENGTH
static var t_gravity := GRAVITY
static var t_pump := PUMP
static var t_steer := STEER
static var t_most := MOST
static var t_damp := DAMP
static var t_top := TOP
static var t_pop := POP
static var t_boost := BOOST
static var t_best := BEST
static var t_window := WINDOW
static var t_catch := CATCH
static var t_catch_body := CATCH_BODY

var anchor := Vector3.ZERO
var length := 5.0
## The rope's held point or its end (world), and its velocity.
var hands := Vector3.ZERO
var velocity := Vector3.ZERO
## Held at `grip` m from the anchor (its length, free).
var grip := 5.0
var motor: PilotMotor = null
var facing := 0.0
## The figure's tilt as last posed (the rope's frame) for letting go.
var tilt := Basis.IDENTITY
var _cool := 0.0
## The last release's timing (0 to 1, `timing`), for F1.
var last_timing := 0.0
var _crouch_was := true
var _time := 0.0
var _upper: MeshInstance3D
var _lower: MeshInstance3D
var _knot: MeshInstance3D
## Its tags (`add_tag`): [mesh instance, its rest pose].
var _tags: Array = []

## Hung from `at`, `rope_length` m long.
func setup(at: Vector3, rope_length: float) -> void:
	anchor = at
	length = rope_length
	grip = length
	hands = anchor+Vector3.DOWN*length

## The updraft's ring blast (scripts/updraft.gd) swings the free end.
const Downdraft = preload("res://scripts/downdraft.gd")
const WIND_SWING := 9.0       # m/s of swing at full power

func wind_point() -> Vector3: return hands

func wind_push(_origin: Vector3, dir: Vector3, power: float) -> void:
	if held(): return
	velocity += dir*WIND_SWING*power

## The downdraft (scripts/downdraft.gd) swings it the same way, out and
## down from where it touched (the pendulum keeps what goes across it).
func downdraft(at: Vector3, radius: float, strength: float) -> void:
	var s := Downdraft.share(at,radius,hands)
	if s > 0.0: wind_push(at,Downdraft.way(at,hands),strength*s)

func _ready() -> void:
	add_to_group(&"wind_pushable")
	add_to_group(Downdraft.GROUP)
	var mesh := _rope_mesh()
	_upper = MeshInstance3D.new()
	_upper.mesh = mesh
	add_child(_upper)
	_lower = MeshInstance3D.new()
	_lower.mesh = mesh
	add_child(_lower)
	_knot = MeshInstance3D.new()
	_knot.mesh = _knot_mesh(0.12,0.22,Footbridge.ROPE.darkened(0.12))
	add_child(_knot)
	var ring := MeshInstance3D.new()
	ring.mesh = _knot_mesh(0.11,0.14,Color("2c2a28"))
	ring.position = anchor+Vector3.DOWN*0.04
	add_child(ring)
	_draw()

func held() -> bool:
	return motor != null and motor.rider == self

## Free: its end on as a pendulum, settling, swaying a little.
func advance(delta: float) -> void:
	if delta <= 0.0: return
	_time += delta
	_cool = maxf(_cool-delta,0.0)
	if not held():
		motor = null
		grip = length
		var sway := Vector3(sin(_time*0.7+anchor.x),0.0,cos(_time*0.53+anchor.z))*SWAY
		_swing(delta,sway,FREE_DAMP)
	_draw()
	for k in range(_tags.size()):
		var tag: MeshInstance3D = _tags[k][0]
		var rest: Transform3D = _tags[k][1]
		var wave := sin(_time*1.3+float(k)*1.7+anchor.z)*0.07+sin(_time*2.9+anchor.x)*0.03
		tag.transform = rest*Transform3D(Basis(Vector3.RIGHT,wave),Vector3.ZERO)

## A weathered cloth tag hung from the beam beside it (its top's middle at
## `at`, its face turned `yaw` about up), stirring in the air: a rope to
## swing on, seen from across the isle. TAG wide and long.
func add_tag(at: Vector3, yaw := 0.0, seed_value := 0) -> void:
	var tag := MeshInstance3D.new()
	tag.mesh = _tag_mesh(seed_value)
	var rest := Transform3D(Basis(Vector3.UP,yaw),at)
	tag.transform = rest
	add_child(tag)
	_tags.append([tag,rest])

## Whether he catches it now: his hands within CATCH of its lower part
## (from GRIP_HIGH of its length down), or his chest within CATCH_BODY of
## it; in the air, or on the ground running into it (at RUN_IN or more,
## toward it: the knot hangs at his hands). Nothing pulls him in: taken
## hold of, the rope comes to his hands where they are, and he rides it.
func try_catch(walker: PilotMotor) -> bool:
	if _cool > 0.0 or walker.rider != null or walker.on_ledge() or walker.swimming or walker.move == "tumble": return false
	var hand := hand_of(walker)
	if walker.grounded:
		# On the ground only run into: at a run, toward it.
		var flat := Vector2(walker.velocity.x,walker.velocity.z)
		var to := Vector2(hands.x-walker.feet.x,hands.z-walker.feet.z)
		if flat.length() < RUN_IN or flat.dot(to) <= 0.0: return false
	var low := anchor+(hands-anchor).normalized()*length*GRIP_HIGH
	var q := Geometry3D.get_closest_point_to_segment(hand,low,hands)
	var met := hand.distance_to(q) <= t_catch
	if not met:
		var chest := walker.feet+Vector3.UP*CHEST
		met = chest.distance_to(Geometry3D.get_closest_point_to_segment(chest,low,hands)) <= t_catch_body
	if not met: return false
	_take(walker,hand)
	return true

## Where his hands are, reaching up and ahead as they hang from a ledge
## (PilotFigure GRIP).
static func hand_of(walker: PilotMotor) -> Vector3:
	var f := PilotMotor.forward(walker.facing)
	return walker.feet+Vector3.UP*PilotMotor.HANG_DROP+Vector3(f.x,0.0,f.y)*(PilotMotor.HANG_OUT+0.03)

## Taken hold of with his hands at `at`: the rope swung to them (its grip
## that far from the anchor, inside its length), his pace across the rope
## its swing, all of it kept (what went along the rope turned into the
## swing, up to TOP).
func _take(walker: PilotMotor, at: Vector3) -> void:
	motor = walker
	grip = clampf(anchor.distance_to(at),length*GRIP_HIGH,length)
	var u := (at-anchor).normalized() if at.distance_to(anchor) > 0.01 else Vector3.DOWN
	hands = anchor+u*grip
	var v := walker.velocity
	velocity = v-u*v.dot(u)
	if velocity.length() > 0.5: velocity = velocity.normalized()*minf(v.length(),maxf(velocity.length(),t_top))
	var flat := Vector2(v.x,v.z)
	facing = PilotMotor.facing_of(flat) if flat.length() > 1.0 else walker.facing
	walker.rider = self
	walker.hold = "swing"
	walker.move = ""
	walker.chain = 0
	walker.grounded = false
	walker.skidding = false
	walker.sail.rest()
	_crouch_was = walker.crouch
	_place(walker)

## One step held (the motor's rider): pumped and steered by the stick,
## let go by Jump (with the pop) or crouch (without).
func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var out := {}
	var dropped := walker.crouch and not _crouch_was
	_crouch_was = walker.crouch
	if pressed or dropped:
		_let_go(walker,not dropped)
		out["swing"] = false
		if pressed:
			out["jumped"] = 1
			out["rope_jump"] = true
		return out
	var w := Vector3(want.x,0.0,want.y)
	var u := (hands-anchor).normalized()
	var tangent := w-u*w.dot(u)
	var push := Vector3.ZERO
	if velocity.length() > 0.4:
		var way := velocity.normalized()
		var along := tangent.dot(way)
		push = way*t_pump*maxf(along,0.0)+(tangent-way*along)*t_steer
	else:
		push = tangent*t_pump
	if want.length() > 0.3: facing = rotate_toward(facing,PilotMotor.facing_of(want),TURN*delta)
	_swing(delta,push,t_damp)
	_place(walker)
	return out

## The pendulum over `delta` at the grip: gravity and `push` (m/s²), the
## pace kept across the rope, held under MOST from the plumb.
func _swing(delta: float, push: Vector3, damping: float) -> void:
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/120.0)
		left -= dt
		var u := (hands-anchor).normalized()
		velocity += (Vector3.DOWN*t_gravity+push)*dt
		velocity -= u*velocity.dot(u)
		velocity *= maxf(1.0-damping*dt,0.0)
		hands = anchor+(hands+velocity*dt-anchor).normalized()*grip
		u = (hands-anchor).normalized()
		var angle := u.angle_to(Vector3.DOWN)
		if angle > t_most:
			# Held at the most: turned back to it, the pace outward taken off.
			var axis := Vector3.DOWN.cross(u).normalized()
			if axis.length() < 0.5: axis = Vector3.RIGHT
			u = Vector3.DOWN.rotated(axis,t_most)
			hands = anchor+u*grip
			var outward := axis.cross(u).normalized()
			if velocity.dot(outward) > 0.0: velocity -= outward*velocity.dot(outward)
		velocity -= u*velocity.dot(u)

## How well a release now is timed, 0 to 1: rising, the rope t_best past
## the plumb is 1, falling off as the square to 0 t_window either side;
## falling (or near still) 0.
func timing() -> float:
	if velocity.y <= 0.05 or velocity.length() < 1.0: return 0.0
	var a := (hands-anchor).angle_to(Vector3.DOWN)
	var x := (a-t_best)/maxf(t_window,0.01)
	return clampf(1.0-x*x,0.0,1.0)

## Let go: off the rope with its pace at his hands; jumped off (`pop`), the
## boost along the swing as well timed (`timing`), and the pop up.
func _let_go(walker: PilotMotor, pop: bool) -> void:
	var v := velocity
	last_timing = timing() if pop else 0.0
	if v.length() > 0.5: v += v.normalized()*t_boost*last_timing
	v = v.limit_length(t_top)
	if pop: v.y = maxf(v.y,0.0)+t_pop
	_cool = REGRAB
	walker.toss(v)
	walker.feet.y -= 0.02
	motor = null
	grip = length

## His body under his hands: the hang's grip on the rope, hanging along it.
func _place(walker: PilotMotor) -> void:
	walker.facing = facing
	walker.velocity = velocity
	walker.feet = hands-_frame()*PilotFigure.GRIP
	walker.ground_y = walker.feet.y

## The hanging body's frame: up along the rope to the anchor, facing his
## way across it.
func _frame() -> Basis:
	var up := (anchor-hands).normalized()
	var f := PilotMotor.forward(facing)
	var ahead := Vector3(f.x,0.0,f.y)
	ahead = (ahead-up*ahead.dot(up))
	if ahead.length() < 1e-3: ahead = Vector3.FORWARD
	ahead = ahead.normalized()
	var back := -ahead
	tilt = Basis(up.cross(back),up,back)
	return tilt

## The rope drawn: anchor to his hands, then the tail on past them; free,
## anchor to its end.
func _draw() -> void:
	if _upper == null: return
	var u := (hands-anchor).normalized()
	var end := anchor+u*length
	_segment(_upper,anchor,hands)
	_lower.visible = grip < length-0.05
	if _lower.visible: _segment(_lower,hands,end)
	_knot.transform = Transform3D(_segment_basis(end-u,end).orthonormalized(),end)

func _segment(mesh: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	mesh.transform = Transform3D(_segment_basis(from,to),from)

## The rope mesh runs from 0 to -1 along y: its y axis the way back up,
## from `to` to `from`, as long as the span.
static func _segment_basis(from: Vector3, to: Vector3) -> Basis:
	var y := from-to
	if y.length() < 1e-4: y = Vector3.UP*1e-4
	var n := y.normalized()
	var x := n.cross(Vector3.FORWARD if absf(n.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var z := x.cross(n).normalized()
	return Basis(x,y,z)

## A faceted rope, a unit long down y: six faces, twisted bands of the rope
## tone, flat-shaded.
static func _rope_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 6
	var bands := 24
	var rng := RandomNumberGenerator.new()
	rng.seed = 4111
	for k in range(bands):
		var y0 := -float(k)/bands
		var y1 := -float(k+1)/bands
		var twist0 := float(k)*0.5
		var twist1 := float(k+1)*0.5
		for i in range(sides):
			var a0 := TAU*float(i)/sides
			var a1 := TAU*float(i+1)/sides
			var p0 := Vector3(cos(a0+twist0)*RADIUS,y0,sin(a0+twist0)*RADIUS)
			var p1 := Vector3(cos(a1+twist0)*RADIUS,y0,sin(a1+twist0)*RADIUS)
			var p2 := Vector3(cos(a1+twist1)*RADIUS,y1,sin(a1+twist1)*RADIUS)
			var p3 := Vector3(cos(a0+twist1)*RADIUS,y1,sin(a0+twist1)*RADIUS)
			var n := Vector3(cos((a0+a1)*0.5+(twist0+twist1)*0.5),0.0,sin((a0+a1)*0.5+(twist0+twist1)*0.5))
			var tone := Footbridge.ROPE.darkened(rng.randf_range(0.0,0.18) if (i+k)%2 == 0 else rng.randf_range(0.12,0.28))
			for p: Vector3 in [p0,p2,p1,p0,p3,p2]:
				st.set_color(tone)
				st.set_normal(n)
				st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0,_material())
	return mesh

## A cloth tag: a strip hanging down -y from its top's middle, folded in
## facets that turn a little in and out, frayed to a notched end, the madder
## faded and darker toward the hem.
static func _tag_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700+seed_value
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rows := 5
	var cols := 3
	var grid: Array = []
	for j in range(rows+1):
		var line: Array = []
		var y := -TAG.y*float(j)/rows
		for i in range(cols+1):
			var x := TAG.x*(float(i)/cols-0.5)*(1.0-0.12*float(j)/rows)
			var z := (0.05 if (i+j)%2 == 0 else -0.04)*float(j)/rows+rng.randf_range(-0.015,0.015)
			if j == rows: y -= (0.22 if i == 1 or i == 2 else 0.0)*rng.randf_range(0.6,1.0)
			line.append(Vector3(x,y,z))
		grid.append(line)
	for j in range(rows):
		var tone := TAG_TONE.darkened(0.08+0.32*float(j)/rows).lerp(Color("6f5a46"),rng.randf_range(0.0,0.25))
		for i in range(cols):
			var a: Vector3 = grid[j][i]
			var b: Vector3 = grid[j][i+1]
			var c: Vector3 = grid[j+1][i+1]
			var d: Vector3 = grid[j+1][i]
			for tri: Array in [[a,b,c],[a,c,d]]:
				var n: Vector3 = ((tri[1]-tri[0]) as Vector3).cross(tri[2]-tri[0]).normalized()
				var shade := tone.darkened(rng.randf_range(0.0,0.1))
				for p: Vector3 in tri:
					st.set_color(shade)
					st.set_normal(n)
					st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0,_material())
	return mesh

## A small faceted lump (a knot, a ring), `r` round and `h` tall about its
## middle.
static func _knot_mesh(r: float, h: float, colour: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sides := 7
	var top := Vector3.UP*h*0.5
	var low := Vector3.DOWN*h*0.5
	for i in range(sides):
		var a0 := TAU*float(i)/sides
		var a1 := TAU*float(i+1)/sides
		var p0 := Vector3(cos(a0)*r,0.0,sin(a0)*r)
		var p1 := Vector3(cos(a1)*r,0.0,sin(a1)*r)
		for tri: Array in [[top,p1,p0],[low,p0,p1]]:
			var n: Vector3 = ((tri[1]-tri[0]) as Vector3).cross(tri[2]-tri[0]).normalized()
			for p: Vector3 in tri:
				st.set_color(colour*(1.0 if n.y > 0.0 else 0.8))
				st.set_normal(n)
				st.add_vertex(p)
	var mesh := st.commit()
	mesh.surface_set_material(0,_material())
	return mesh

static var _shared: StandardMaterial3D

static func _material() -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.vertex_color_use_as_albedo = true
		_shared.roughness = 1.0
		_shared.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shared
