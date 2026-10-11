extends Node3D
## A balustrade to slide (docs/design/foot-interactables.md): a stone
## banister down a stair, its coping's top the line `rail` (world points,
## head to foot), on balusters standing HEIGHT under it, a newel at each
## end, all in the ruin kit's eroded stone (scripts/ruin_kit.gd Build: worn
## arrises, chips, lichen, moss).
##
## It is only stone: its coping is a real, narrow, steep surface (a clean
## box of collision COPING wide under its top, the line), and nothing takes
## him onto it or holds him there. The motor (scripts/pilot_motor.gd) does
## the rest as on any slope: hopped up onto it he stands and can run it;
## crouched (or landed crouched) on its 24° he boot-surfs down it, pulled
## by its slope, carving with the stick across; his feet leaving its top
## (carved or drifted off its side) he falls off; its end is a drop, and he
## flies off it at all his pace. Round 2 dropped round 1's rider (a catch
## within reach, set onto the line, a balance meter): organic play.
##
## Its head is eased down (MOUNT over the landing, RAMP back from the top
## step) so a plain jump, or a step, gets him up onto it.
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The coping's top over the treads (m), its width and depth; the
## balusters' pitch along it.
const HEIGHT := 0.95
const COPING := Vector2(0.38,0.16)
const PITCH := 0.42
## The head eased down: its top MOUNT over the landing, RAMP m back from
## the top step's nosing.
const MOUNT := 0.42
const RAMP := 1.3
## The foot's newel stands this far under the coping's end (m).
const NEWEL_DROP := 0.3

var rail := PackedVector3Array()
var _cum := PackedFloat32Array()
var length := 0.0
var seed_value := 0
var weathered := 0.3
var body: StaticBody3D
## The treads' line under the coping (world points, `floor_at`), or none:
## HEIGHT under the coping.
var floor_line := PackedVector3Array()

## Along `points` (the coping's top, world), over the treads' line `floor`
## (world; none: HEIGHT under it).
func setup(points: PackedVector3Array, seed_in: int, weathered_in := 0.3, floor := PackedVector3Array()) -> void:
	rail = points
	floor_line = floor
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

## The treads' height under `p` (on `floor_line`, nearest across the
## ground), or HEIGHT under the coping's line there.
func floor_at(p: Vector3) -> float:
	if floor_line.size() < 2: return float(nearest(p)[2])-HEIGHT
	var best := INF
	var y := 0.0
	for i in range(floor_line.size()-1):
		var a := Vector2(floor_line[i].x,floor_line[i].z)
		var b := Vector2(floor_line[i+1].x,floor_line[i+1].z)
		var q := Geometry2D.get_closest_point_to_segment(Vector2(p.x,p.z),a,b)
		var d := q.distance_to(Vector2(p.x,p.z))
		if d < best:
			best = d
			y = lerpf(floor_line[i].y,floor_line[i+1].y,a.distance_to(q)/maxf(a.distance_to(b),1e-4))
	return y

func rid() -> RID:
	return body.get_rid() if body != null else RID()

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

## The coping's line down one cheek of the ruin kit's grand stair
## (RuinKit `grand_stair`, its frame `stair`), `side` -1 its left, 1 its
## right (facing up it): from its head's landing (eased down to MOUNT over
## it, RAMP back) up to HEIGHT over the top step's nosing, then straight
## down to HEIGHT over the foot step's, over the half landing too (ramped,
## as a handrail is, not level there: one unbroken slope to slide, about
## 21°, 0.67 to 1.24 m over the steps).
static func grand_stair_rail(stair: Transform3D, side: float) -> PackedVector3Array:
	var f := _grand(side)
	var local := [
		Vector3(f.x,f.top+MOUNT,f.head-RAMP),
		Vector3(f.x,f.top+HEIGHT,f.head),
		Vector3(f.x,f.r+HEIGHT,f.front),
	]
	var out := PackedVector3Array()
	for p: Vector3 in local: out.append(stair*p)
	return out

## The steps' nosing line under that cheek's coping (its `floor_line`):
## the head's landing, the upper flight, the half landing, the lower flight.
static func grand_stair_floor(stair: Transform3D, side: float) -> PackedVector3Array:
	var f := _grand(side)
	var local := [
		Vector3(f.x,f.top,f.head-RAMP-0.5),
		Vector3(f.x,f.top,f.head),
		Vector3(f.x,f.half+f.r,f.mid),
		Vector3(f.x,f.half,f.mid+0.01),
		Vector3(f.x,f.half,f.lower),
		Vector3(f.x,f.r,f.front),
		Vector3(f.x,f.r,f.front+0.5),
	]
	var out := PackedVector3Array()
	for p: Vector3 in local: out.append(stair*p)
	return out

## The grand stair's numbers along that cheek (its frame): x, the riser, the
## half's height, the head's height, the top step's nosing z, the upper
## flight's foot, the lower's top, the foot step's nosing.
static func _grand(side: float) -> Dictionary:
	var r := RuinKit.GRAND_RISER
	var t := RuinKit.GRAND_TREAD
	var n := RuinKit.GRAND_STEPS
	var run1 := (n-1)*t+RuinKit.GRAND_LANDING
	var run2 := (n-1)*t+RuinKit.LANDING
	var front := (run1+run2)*0.5
	var mid := front-run1
	return {"x":side*(RuinKit.GRAND_WIDTH*0.5+RuinKit.CHEEK.x*0.5),"r":r,"half":n*r,"top":2.0*n*r,
		"head":mid-(n-1)*t,"mid":mid,"lower":front-(n-1)*t,"front":front}

# --- The stone ----------------------------------------------------------------------

## The banister in the kit's stone: the coping along each run of the line,
## balusters under it every PITCH to HEIGHT under, a newel at each end (the
## head's no higher than the coping, the foot's a little lower, so neither
## stands in his way); a clean wall of collision under the coping, its top
## the line, the surface he slides.
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
		# Balusters, upright, from the coping's underside to the treads (the
		# head's run eased down).
		var count := maxi(int(run/PITCH),1)
		for k in range(count):
			var f := (float(k)+0.5)/count
			var top := a.lerp(c,f)-Vector3.UP*COPING.y
			var tall := top.y-floor_at(top)+0.08
			var planes := RuinKit._prism(6,0.065,0.075,-tall*0.5,tall*0.5,b.rng.randf()*TAU)
			b.solid(planes,Transform3D(Basis.IDENTITY,top-Vector3.UP*tall*0.5),RuinKit._stone(b,0.98),false,true,[],-1,0.6)
		walls.append([basis,mid-up*(HEIGHT*0.5),Vector3(run,HEIGHT,COPING.x)])
	# A newel at each end: at the head a pedestal its top the coping's (a
	# step up onto it), at the foot a post standing NEWEL_DROP under the
	# coping's end, so he flies on over it. Both collide.
	for end: int in [0,rail.size()-1]:
		var top := rail[end]-Vector3.UP*(0.0 if end == 0 else NEWEL_DROP)
		var post := maxf(top.y-floor_at(top),0.3)
		var yaw := b.rng.randf_range(-0.05,0.05)
		b.solid(RuinKit._box(b,Vector3(0.21,(post-0.06)*0.5,0.21)),Transform3D(Basis(Vector3.UP,yaw),top-Vector3.UP*(0.06+(post-0.06)*0.5)),RuinKit._stone(b,1.04),false)
		b.solid(RuinKit._prism(4,0.3,0.24,-0.06,0.0,PI*0.25),Transform3D(Basis.IDENTITY,top),RuinKit._stone(b,1.1),false)
		walls.append([Basis(Vector3.UP,yaw),top-Vector3.UP*post*0.5,Vector3(0.42,post,0.42)])
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
