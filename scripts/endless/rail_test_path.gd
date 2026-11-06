extends RefCounted
## A test rail path for the train lane (docs/design/endless-flight/spec-railroad.md,
## lane `train`): the rail path contract on an oval of two straights and two half
## circles laid over flat land, so the train can be built and flown before the
## line is in the land. `--train-test` puts it in endless flight (rail_train.gd).
##
## The contract (the line lane's real path offers the same):
## - `length()`: one lap (m);
## - `pose(s, track)`: the centre of track 0 or 1 at `s` m along the loop
##   (wrapping), the basis's -z along +s (the way track 0's train runs), y up off
##   the bed, x to the right of +s;
## - `kind(s)`: grade, cut, fill, tunnel, trestle or bridge.
##
## Track 0 runs on the right of +s, track 1 on the left, SPACING m apart centre
## to centre (RailTrain `spacing`: the gap between two trains' sides an opening).
##
## Its bed: the land under it (the mean of the middle and both tracks' outer
## edges) every STEP m, eased over EASE m either way and graded to GRADE: a
## little fill over the hollows and a little cut through the rises (`fill_range`).

const STEP := 10.0
const EASE := 150.0
const GRADE := 0.035
## The oval on the open sea north-east of the start (seed 1: water 40 m out from
## every track the whole way round, off the swell's belt), its long axis along
## `turn` (radians, from +x toward +z), its straights LEG m and its ends RADIUS m
## round. Not on the land: seed 1's plains rise and fall 7 m or more under a
## kilometre's loop until the line lane cuts its bed (2026-11-05), and a train
## half sunk in a rise can't be flown beside. On the sea the bed is a causeway
## BED m over the calm water, under the plane's skim of it.
const AT := Vector2(2500.0,-2000.0)
const TURN := 0.0
const LEG := 1400.0
const RADIUS := 260.0
const BED := 0.6
## The causeway's look: how far it runs out past the tracks, and down.
const CAUSEWAY_OUT := 6.0
const CAUSEWAY_DEEP := 4.0
## The rails' look: half the gauge, a rail's width and height, the ballast's
## half width and height (m), and the step along the loop the mesh is cut at.
const GAUGE_HALF := 1.5
const RAIL := Vector2(0.25,0.22)
const BALLAST := Vector2(2.3,0.1)
const LOOK_STEP := 5.0
## How far out from the middle line the land is read for the bed, past a track.
const EDGE := 5.0

var at := AT
var turn := TURN
var leg := LEG
var radius := RADIUS
var spacing := 13.0
var _len := 0.0
## The bed's samples' spacing (m): STEP, shortened to a whole number a lap.
var _step := STEP
var _bed := PackedFloat32Array()
var _land := PackedFloat32Array()

## `height`: the bed's floor, (x, z) -> float (the land's height, or the sea's
## plus BED).
func _init(height: Callable, track_spacing: float, centre := AT, long_turn := TURN, straight := LEG, round_r := RADIUS) -> void:
	at = centre
	turn = long_turn
	leg = straight
	radius = round_r
	spacing = track_spacing
	_len = 2.0*leg+TAU*radius
	_lay(height)

func length() -> float:
	return _len

## The centre of `track` (0 or 1) at `s` m along the loop.
func pose(s: float, track: int) -> Transform3D:
	s = fposmod(s,_len)
	var p := point(s)
	var d := way(s)
	var y := bed(s)
	var slope := (bed(s+_step*0.5)-bed(s-_step*0.5))/_step
	var f := Vector3(d.x,slope,d.y).normalized()
	var up := (Vector3.UP-f*f.dot(Vector3.UP)).normalized()
	var z := -f
	var x := up.cross(z)
	var side := 0.5*spacing*(1.0 if track == 0 else -1.0)
	var o := Vector3(p.x,y,p.y)+Vector3(-d.y,0.0,d.x)*side
	return Transform3D(Basis(x,up,z),o)

func kind(s: float) -> String:
	var i := _index(s)
	if _bed[i] > _land[i]+1.0: return "fill"
	return "cut" if _bed[i] < _land[i]-1.0 else "grade"

## The middle line's world XZ at `s`.
func point(s: float) -> Vector2:
	return _rot(_local(fposmod(s,_len)))+at

## The way +s runs at `s` (world XZ, unit).
func way(s: float) -> Vector2:
	s = fposmod(s,_len)
	var a := PI*radius
	var d: Vector2
	if s < leg: d = Vector2(1.0,0.0)
	elif s < leg+a:
		var t := (s-leg)/radius
		d = Vector2(cos(t),sin(t))
	elif s < 2.0*leg+a: d = Vector2(-1.0,0.0)
	else:
		var t := (s-2.0*leg-a)/radius
		d = Vector2(-cos(t),-sin(t))
	return _rot(d)

## The bed's height (world y) at `s`, between its samples.
func bed(s: float) -> float:
	s = fposmod(s,_len)
	var f := s/_step
	var i := int(floor(f))
	var n := _bed.size()
	return lerpf(_bed[i%n],_bed[(i+1)%n],f-floor(f))

## The most the bed stands over the land (m) and the most it is under it.
func fill_range() -> Vector2:
	var most := -INF
	var least := INF
	for i in range(_bed.size()):
		most = maxf(most,_bed[i]-_land[i])
		least = minf(least,_bed[i]-_land[i])
	return Vector2(least,most)

func _index(s: float) -> int:
	return int(round(fposmod(s,_len)/_step))%_bed.size()

func _local(s: float) -> Vector2:
	var a := PI*radius
	if s < leg: return Vector2(-leg*0.5+s,-radius)
	if s < leg+a:
		var t := (s-leg)/radius
		return Vector2(leg*0.5+radius*sin(t),-radius*cos(t))
	if s < 2.0*leg+a: return Vector2(leg*0.5-(s-leg-a),radius)
	var t := (s-2.0*leg-a)/radius
	return Vector2(-leg*0.5-radius*sin(t),radius*cos(t))

func _rot(v: Vector2) -> Vector2:
	return v.rotated(turn)

func _lay(height: Callable) -> void:
	var n := int(ceil(_len/STEP))
	_step = _len/n
	_land.resize(n)
	var out := 0.5*spacing+EDGE
	for i in range(n):
		var s := i*_step
		var p := point(s)
		var d := way(s)
		var across := Vector2(-d.y,d.x)
		var h := 0.0
		for k: float in [-out,0.0,out]:
			var q := p+across*k
			h += float(height.call(q.x,q.y))/3.0
		_land[i] = h
	# Eased: a moving average over EASE m either way.
	var w := int(round(EASE/_step))
	_bed.resize(n)
	for i in range(n):
		var sum := 0.0
		for k in range(-w,w+1): sum += _land[(i+k+n)%n]
		_bed[i] = sum/float(2*w+1)
	# Graded: no step between samples steeper than GRADE.
	var most := GRADE*_step
	for _pass in range(4):
		for i in range(n): _bed[i] = clampf(_bed[i],_bed[(i-1+n)%n]-most,_bed[(i-1+n)%n]+most)
		for i in range(n-1,-1,-1): _bed[i] = clampf(_bed[i],_bed[(i+1)%n]-most,_bed[(i+1)%n]+most)

## The greybox look: the causeway's top and sides under both tracks, the
## ballast and two rails on each; one mesh under `parent`, no collision (the
## plane skims the water over the causeway's top).
func build(parent: Node3D) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := int(ceil(_len/LOOK_STEP))
	var top := Color(0.46,0.42,0.36)
	var side := Color(0.36,0.33,0.29)
	var gravel := Color(0.3,0.28,0.26)
	var steel := Color(0.22,0.21,0.2)
	var half := 0.5*spacing+CAUSEWAY_OUT
	for i in range(n):
		var a := pose(i*_len/n,0)
		var b := pose((i+1)*_len/n,0)
		# The causeway: the middle line, its top across both tracks.
		var ma := a.origin-a.basis.x*0.5*spacing
		var mb := b.origin-b.basis.x*0.5*spacing
		_strip(st,ma,mb,a.basis,b.basis,-half,half,0.0,0.0,top)
		_strip(st,ma,mb,a.basis,b.basis,half,half,0.0,-CAUSEWAY_DEEP,side)
		_strip(st,ma,mb,a.basis,b.basis,-half,-half,-CAUSEWAY_DEEP,0.0,side)
		for track in range(2):
			var ta := pose(i*_len/n,track)
			var tb := pose((i+1)*_len/n,track)
			_strip(st,ta.origin,tb.origin,ta.basis,tb.basis,-BALLAST.x,BALLAST.x,BALLAST.y,BALLAST.y,gravel)
			for g: float in [-GAUGE_HALF,GAUGE_HALF]:
				var y := BALLAST.y+RAIL.y
				_strip(st,ta.origin,tb.origin,ta.basis,tb.basis,g-RAIL.x*0.5,g+RAIL.x*0.5,y,y,steel)
				_strip(st,ta.origin,tb.origin,ta.basis,tb.basis,g+RAIL.x*0.5,g+RAIL.x*0.5,y,BALLAST.y,steel)
				_strip(st,ta.origin,tb.origin,ta.basis,tb.basis,g-RAIL.x*0.5,g-RAIL.x*0.5,BALLAST.y,y,steel)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Lit a little in shade (as RailTrain's blocks).
	mat.emission_enabled = true
	mat.emission = Color(0.12,0.11,0.1)
	var mi := MeshInstance3D.new()
	mi.name = "TestRails"
	mi.mesh = st.commit()
	mi.material_override = mat
	parent.add_child(mi)
	return mi

## One quad along the loop from frame (`a`, `ba`) to (`b`, `bb`): across from
## `x0` (at height `y0`) to `x1` (at `y1`), facing up or out.
static func _strip(st: SurfaceTool, a: Vector3, b: Vector3, ba: Basis, bb: Basis, x0: float, x1: float, y0: float, y1: float, c: Color) -> void:
	var p0 := a+ba.x*x0+ba.y*y0
	var p1 := a+ba.x*x1+ba.y*y1
	var q0 := b+bb.x*x0+bb.y*y0
	var q1 := b+bb.x*x1+bb.y*y1
	st.set_color(c)
	for v: Vector3 in [p0,q0,p1,p1,q0,q1]: st.add_vertex(v)
