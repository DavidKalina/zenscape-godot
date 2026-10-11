extends Node3D
## A balustrade to slide (docs/design/foot-interactables.md): a stone
## banister down a stair, its coping's top the line `rail` (world points,
## head to foot or any way), on balusters standing HEIGHT under it, a newel
## at each end, all in the ruin kit's eroded stone (scripts/ruin_kit.gd
## Build: worn arrises, chips, lichen, moss), solid as a low wall.
##
## Jumped onto (landed on its coping, or in the air with his feet within
## CATCH of its line across and CATCH_LOW under to CATCH_HIGH over it), he
## grinds it (the motor's `rider`, scripts/pilot_motor.gd; drawn as the
## slide, move "slide", leaning as he balances): his pace along it is kept
## from the jump (under START, START the way down it), the slope pulls him
## down it (PULL by its sine, as the surf's SLIDE_PULL) less DRAG and the
## air's AIR by his pace squared, never past TOP. Crouch or the stick on
## along his way tucks (the air's drag cut by TUCK); the stick back against
## it brakes (BRAKE). His balance drifts the faster he goes (WOBBLE) and
## grows the further over he is (TIP); the stick across his way leans him
## back (LEAN): leant over past it, he falls off that side, his pace
## mostly kept. Jump leaves it with all his pace and JUMP up, the slide
## hop's weave his in the air (out of the carve family, landed crouched he
## slides on); its end flings him off with his pace and END_POP up. Under
## STOP on the level he steps off. Let go of, it can't be caught again for
## REGRAB s. The numbers are live (`t_*`, the yard's F4, studies/
## interactables_yard.gd).
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

const PULL := 18.0
const DRAG := 1.0
const AIR := 0.03
const TUCK := 0.6
const BRAKE := 5.0
const TOP := 18.0
const START := 2.0
const STOP := 0.8
const JUMP := 0.9
const END_POP := 1.2
const TIP := 1.1
const WOBBLE := 0.35
const LEAN := 2.4
const CATCH := 0.45
const CATCH_LOW := 0.4
const CATCH_HIGH := 0.5
const REGRAB := 0.4
## The coping's top over the treads (m), its width and depth; the balusters'
## pitch along it.
const HEIGHT := 0.95
const COPING := Vector2(0.3,0.16)
const PITCH := 0.42
## The figure's lean at a full lean over (radians), as the carve's bank.
const LEAN_SHOW := 0.4

static var t_pull := PULL
static var t_drag := DRAG
static var t_air := AIR
static var t_tuck := TUCK
static var t_brake := BRAKE
static var t_top := TOP
static var t_jump := JUMP
static var t_tip := TIP
static var t_wobble := WOBBLE
static var t_lean := LEAN
static var t_catch := CATCH

var rail := PackedVector3Array()
var _cum := PackedFloat32Array()
var length := 0.0
var seed_value := 0
var weathered := 0.3
var body: StaticBody3D
## Riding: where along it (m from its first point), the pace along it
## (m/s, + toward its last point), the balance (-1 to 1, + over to the
## right of his way).
var s := 0.0
var pace := 0.0
var balance := 0.0
var motor: PilotMotor = null
## The fastest he has gone on it this ride, and on the last.
var ride_top := 0.0
var _cool := 0.0
var _time := 0.0

## Along `points` (the coping's top, world).
func setup(points: PackedVector3Array, seed_in: int, weathered_in := 0.3) -> void:
	rail = points
	seed_value = seed_in
	weathered = weathered_in
	_cum.clear()
	_cum.append(0.0)
	length = 0.0
	for i in range(1,rail.size()):
		length += rail[i-1].distance_to(rail[i])
		_cum.append(length)

func _ready() -> void:
	add_child(_build())

func rid() -> RID:
	return body.get_rid() if body != null else RID()

func held() -> bool:
	return motor != null and motor.rider == self

func advance(delta: float) -> void:
	_time += delta
	_cool = maxf(_cool-delta,0.0)
	if not held(): motor = null

## The point `d` m along it, and its way there (unit, + along).
func point(d: float) -> Vector3:
	var i := _segment(d)
	var span: float = _cum[i+1]-_cum[i]
	return rail[i].lerp(rail[i+1],clampf((d-_cum[i])/maxf(span,1e-4),0.0,1.0))

func way(d: float) -> Vector3:
	var i := _segment(d)
	return (rail[i+1]-rail[i]).normalized()

func _segment(d: float) -> int:
	for i in range(rail.size()-2):
		if d < _cum[i+1]: return i
	return rail.size()-2

## The nearest place along it to `p` across the ground (x, z): [m along,
## the distance across, the coping's height there].
func nearest(p: Vector3) -> Array:
	var best := [0.0,INF,0.0]
	for i in range(rail.size()-1):
		var a := Vector2(rail[i].x,rail[i].z)
		var b := Vector2(rail[i+1].x,rail[i+1].z)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),a,b)
		var d := q.distance_to(Vector2(p.x,p.z))
		if d < float(best[1]):
			var f := a.distance_to(q)/maxf(a.distance_to(b),1e-4)
			best = [lerpf(_cum[i],_cum[i+1],f),d,lerpf(rail[i].y,rail[i+1].y,f)]
	return best

## Whether he takes to it now: landed on its coping (`under` the body he
## stands on), or in the air over its line.
func try_catch(walker: PilotMotor, under: RID) -> bool:
	if _cool > 0.0 or walker.rider != null or walker.on_ledge() or walker.swimming or walker.move == "tumble": return false
	var near := nearest(walker.feet)
	var on := walker.grounded and under.is_valid() and under == rid()
	if not on:
		if walker.grounded or walker.velocity.y > 4.0 or float(near[1]) > t_catch: return false
		var dy := walker.feet.y-float(near[2])
		if dy < -CATCH_LOW or dy > CATCH_HIGH: return false
	_take(walker,float(near[0]))
	return true

func _take(walker: PilotMotor, at: float) -> void:
	motor = walker
	s = clampf(at,0.05,length-0.05)
	var t := way(s)
	pace = walker.velocity.dot(t)
	if absf(pace) < START:
		# Too slow along it: START down it (or his way along a level one).
		var down := -signf(t.y) if absf(t.y) > 0.02 else (signf(pace) if pace != 0.0 else 1.0)
		pace = down*START
	var side := Vector3(t.z,0.0,-t.x).normalized()*signf(pace)
	balance = clampf(walker.velocity.dot(side)*0.06,-0.4,0.4)
	ride_top = absf(pace)
	walker.rider = self
	walker.hold = ""
	walker.chain = 0
	walker.skidding = false
	walker.sail.rest()
	_place(walker)

## One step riding (the motor's rider).
func ride(walker: PilotMotor, delta: float, want: Vector2, pressed: bool) -> Dictionary:
	var out := {}
	var t := way(s)
	var dir := signf(pace) if pace != 0.0 else 1.0
	var travel := t*dir
	var flat := Vector2(travel.x,travel.z).normalized()
	var right := Vector2(-flat.y,flat.x)
	var along := want.dot(flat)
	var across := want.dot(right)
	if pressed:
		_leave(walker,travel*absf(pace)+Vector3.UP*sqrt(2.0*walker.gravity*t_jump),true)
		out["jumped"] = 1
		out["rail"] = false
		out["rail_jump"] = true
		return out
	# The slope's pull along it, the drag (tucked less, braking more).
	pace -= t_pull*t.y*delta
	var tuck := maxf(1.0 if walker.crouch else 0.0,maxf(along,0.0))
	var drag := t_drag+t_air*pace*pace*(1.0-t_tuck*tuck)+t_brake*maxf(-along,0.0)
	pace = clampf(move_toward(pace,0.0,drag*delta),-t_top,t_top)
	# The balance: drifting faster the faster, leant back by the stick.
	var wobble := sin(_time*2.3+float(seed_value))*0.6+sin(_time*3.7+1.3)*0.4
	balance += (t_tip*balance+t_wobble*wobble*(0.3+absf(pace)/t_top)+across*t_lean)*delta
	ride_top = maxf(ride_top,absf(pace))
	if absf(balance) >= 1.0:
		var r3 := Vector3(right.x,0.0,right.y)
		_leave(walker,travel*absf(pace)*0.8+r3*signf(balance)*2.0+Vector3.UP*2.0,false)
		out["rail"] = false
		out["rail_fell"] = true
		return out
	s += pace*delta
	if s <= 0.0 or s >= length:
		s = clampf(s,0.0,length)
		walker.feet = point(s)
		_leave(walker,travel*absf(pace)+Vector3.UP*END_POP,true)
		out["rail"] = false
		out["rail_end"] = true
		return out
	if absf(pace) < STOP and absf(t.y) < 0.05:
		_leave(walker,travel*absf(pace)+Vector3.UP*1.5,false)
		out["rail"] = false
		return out
	_place(walker)
	return out

func _leave(walker: PilotMotor, push: Vector3, hop: bool) -> void:
	_cool = REGRAB
	motor = null
	walker.toss(push,hop)

## On the coping at `s`, his pace along it, facing his way, drawn as the
## slide leaning with his balance.
func _place(walker: PilotMotor) -> void:
	var t := way(s)*(signf(pace) if pace != 0.0 else 1.0)
	walker.feet = point(s)
	walker.ground_y = walker.feet.y
	walker.velocity = t*absf(pace)
	var flat := Vector2(t.x,t.z)
	if flat.length() > 0.05: walker.facing = PilotMotor.facing_of(flat)
	walker.grounded = true
	walker.move = "slide"
	walker.carving = -balance*LEAN_SHOW/(maxf(absf(pace),2.0)*0.025)

## The coping's line down one cheek of the ruin kit's grand stair
## (RuinKit `grand_stair`, its frame `stair`), `side` -1 its left, 1 its
## right (facing up it): from its head's landing down the upper flight,
## level over the half landing, down the lower flight to its foot; HEIGHT
## over the steps' nosings.
static func grand_stair_rail(stair: Transform3D, side: float) -> PackedVector3Array:
	var r := RuinKit.GRAND_RISER
	var t := RuinKit.GRAND_TREAD
	var n := RuinKit.GRAND_STEPS
	var run1 := (n-1)*t+RuinKit.GRAND_LANDING
	var run2 := (n-1)*t+RuinKit.LANDING
	var front := (run1+run2)*0.5
	var half := n*r
	var x := side*(RuinKit.GRAND_WIDTH*0.5+RuinKit.CHEEK.x*0.5)
	var mid := front-run1
	var local := [
		Vector3(x,2.0*half+HEIGHT,mid-(n-1)*t-RuinKit.LANDING*0.6),
		Vector3(x,2.0*half+HEIGHT,mid-(n-1)*t),
		Vector3(x,half+r+HEIGHT,mid),
		Vector3(x,half+HEIGHT,front-(n-1)*t),
		Vector3(x,r+HEIGHT,front),
	]
	var out := PackedVector3Array()
	for p: Vector3 in local: out.append(stair*p)
	return out

# --- The stone ----------------------------------------------------------------------

## The banister in the kit's stone: the coping along each run of the line,
## balusters under it every PITCH to HEIGHT under, a newel at each end; a
## clean wall of collision under the coping, its top the line.
func _build() -> Node3D:
	var b := RuinKit.Build.new(seed_value,weathered,"Balustrade")
	body = null
	var walls: Array = []
	for i in range(rail.size()-1):
		var a := rail[i]
		var c := rail[i+1]
		var along := (c-a)
		var run := along.length()
		if run < 0.01: continue
		var x := along/run
		var side := Vector3(x.z,0.0,-x.x).normalized()
		var up := side.cross(x).normalized()
		if up.y < 0.0:
			side = -side
			up = -up
		var basis := Basis(x,up,side)
		var mid := (a+c)*0.5
		b.solid(RuinKit._box(b,Vector3(run*0.5+0.03,COPING.y*0.5,COPING.x*0.5)),Transform3D(basis,mid-up*COPING.y*0.5),RuinKit._stone(b,1.08),false)
		# Balusters, upright, from the coping's underside to the treads.
		var count := maxi(int(run/PITCH),1)
		for k in range(count):
			var f := (float(k)+0.5)/count
			var top := a.lerp(c,f)-Vector3.UP*COPING.y
			var tall := HEIGHT-COPING.y+0.08
			var planes := RuinKit._prism(6,0.065,0.075,-tall*0.5,tall*0.5,b.rng.randf()*TAU)
			b.solid(planes,Transform3D(Basis.IDENTITY,top-Vector3.UP*tall*0.5),RuinKit._stone(b,0.98),false,true,[],-1,0.6)
		walls.append([basis,mid-up*(HEIGHT*0.5),Vector3(run,HEIGHT,COPING.x)])
	# A newel at each end: a post to the coping and a little over, capped.
	for end: int in [0,rail.size()-1]:
		var top := rail[end]
		var post := HEIGHT+0.22
		b.solid(RuinKit._box(b,Vector3(0.19,post*0.5,0.19)),Transform3D(Basis(Vector3.UP,b.rng.randf_range(-0.05,0.05)),top+Vector3.UP*(0.22-post*0.5)),RuinKit._stone(b,1.04),false)
		b.solid(RuinKit._prism(4,0.24,0.06,0.0,0.2,PI*0.25),Transform3D(Basis.IDENTITY,top+Vector3.UP*0.22),RuinKit._stone(b,1.1),false)
	var root := b.finish()
	body = root.get_node("Body")
	for wall: Array in walls:
		var shape := BoxShape3D.new()
		shape.size = wall[2]
		var holder := CollisionShape3D.new()
		holder.shape = shape
		holder.transform = Transform3D(wall[0],wall[1])
		body.add_child(holder)
	return root
