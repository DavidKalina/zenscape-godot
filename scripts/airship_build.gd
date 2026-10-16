extends RefCounted
## The airship's meshes (scripts/sky_airship.gd): a little cargo airship of
## the sky folk, made as the clusters' builds are (scripts/showcase_builds.gd):
## flat faces, one facet a face, vertex-coloured in the scene's own earthy
## palette. A fat canvas envelope in cream and rust gores with a darker nose
## and tail cap, four tail fins; hung under it on rigging lines a wooden
## gondola with a little cabin (its windows a mesh of their own, to glow at
## night), a bow rail and a lantern post; two pusher pods on outriggers whose
## propellers turn (`propeller`, a mesh of its own); a winch drum on the
## stern deck (`drum`, turned as the lines pay out); and the crossbeam and
## keel hook under the hull the tow lines hang from (TETHERS).
##
## Real metres, the gondola's deck at the origin, the bow toward -Z. Sized to
## the sky folk (0.85 m tall, scripts/islander_figure.gd SKY_SCALE): the
## cabin a head over them, the rail at their waist.

const Builds = preload("res://scripts/showcase_builds.gd")

## Aged: a smoke-yellowed canvas, oxide rust, a dull sage, tarred wood
## (shaders/airship_surface.gdshader streaks and dirties it on top).
const CANVAS := Color("d2c6aa")
const CANVAS_SHADE := Color("beb194")
const RUST := Color("85513f")
const RUST_DARK := Color("643a2e")
const SAGE := Color("5f6656")
const WOOD := Color("5c4430")
const WOOD_DARK := Color("3e3024")
const PLANK := Color("73583e")
const LIME := Color("c4b8a0")
const ROOF := Color("70402f")
const BRASS := Color("a8884c")
const IRON := Color("3f3c37")
const ROPE := Color("7a6849")

## The envelope: its middle over the deck, its length along Z, its fattest
## radius, how far forward of its middle the fattest ring stands (share of
## the half length), and the faces round.
const ENVELOPE_AT := Vector3(0.0,6.4,0.3)
const ENVELOPE_LENGTH := 17.0
const ENVELOPE_RADIUS := 3.3
const ENVELOPE_FAT := -0.18
const GORES := 15
## The gondola: its half length, half width, how deep the hull hangs under
## the deck.
const HULL := Vector3(0.85,0.55,2.5)
## The pusher pods' middles (one a side; the other mirrored), their
## propellers' hubs behind them, and the blades' reach.
const POD := Vector3(1.75,0.75,1.2)
const PROP := Vector3(1.75,0.75,2.05)
const BLADE := 0.75
## The winch drum on the stern deck (turns about X).
const DRUM := Vector3(0.0,0.42,1.9)
## Where the tow lines hang from (ship frame): the crossbeam's ends under
## the hull and the keel hook under the bow.
const TETHERS := [Vector3(-1.25,-0.62,0.9),Vector3(1.25,-0.62,0.9),Vector3(0.0,-0.72,-1.7)]
## The lantern's middle on its bow post, and the windows' middles (for
## their halos).
const LANTERN := Vector3(0.0,1.25,-2.75)
const WINDOWS := [Vector3(-0.71,0.72,0.55),Vector3(-0.71,0.72,1.25),Vector3(0.71,0.72,0.55),Vector3(0.71,0.72,1.25),Vector3(0.0,0.72,-0.12)]
## Where the crew stands on deck (bow, by the rail), and the second hand
## (stern, by the winch).
const CREW := [Vector3(0.0,0.0,-1.7),Vector3(0.35,0.0,1.55)]

## The hull, the envelope, the rigging, the pods: every solid part but what
## turns or glows, as one mesh.
static func body() -> ArrayMesh:
	var st := Builds._begin()
	_envelope(st)
	_fins(st)
	_gondola(st)
	_rigging(st)
	_pods(st)
	return _end(st)

## One propeller (two blades and a hub), about +Z through its hub, the
## blades in the XY plane.
static func propeller() -> ArrayMesh:
	var st := Builds._begin()
	Builds.prism_axis(st,6,0.11,0.08,-0.12,0.1,BRASS,0.0)
	for k in range(2):
		var turn := Basis(Vector3.BACK,PI*k+0.2)*Basis(Vector3.UP,0.35)
		Builds.box(st,turn*Vector3(0.0,BLADE*0.5,0.0),turn,Vector3(0.09,BLADE*0.5,0.018),WOOD)
		Builds.box(st,turn*Vector3(0.0,BLADE*0.92,0.0),turn,Vector3(0.1,BLADE*0.08,0.02),RUST)
	return Builds._end(st)

## The winch drum, about X through its middle: the drum wound with line,
## brass rims, a crank.
static func drum() -> ArrayMesh:
	var st := Builds._begin()
	var along := Transform3D(Basis(Vector3.BACK,PI*0.5),Vector3.ZERO)
	_cylinder(st,8,0.2,0.2,0.7,along,ROPE)
	for side in [-0.37,0.37]:
		_cylinder(st,8,0.28,0.28,0.05,Transform3D(along.basis,Vector3(side,0.0,0.0)),BRASS)
	Builds.box(st,Vector3(0.44,0.12,0.0),Basis.IDENTITY,Vector3(0.025,0.16,0.025),IRON)
	Builds.box(st,Vector3(0.5,0.26,0.0),Basis.IDENTITY,Vector3(0.07,0.025,0.025),WOOD_DARK)
	return Builds._end(st)

## The cabin's windows and the lantern's pane: drawn in the glow material
## (dark glass by day, warm at night).
static func windows() -> ArrayMesh:
	var st := Builds._begin()
	for w: Vector3 in WINDOWS:
		var half := Vector3(0.02,0.16,0.2) if absf(w.x) > 0.1 else Vector3(0.24,0.14,0.02)
		Builds.box(st,w,Basis.IDENTITY,half,Color.WHITE)
	Builds.box(st,LANTERN,Basis(Vector3.UP,PI*0.25),Vector3(0.09,0.12,0.09),Color.WHITE)
	return Builds._end(st)

## A grapple: a shank down from the line's end, a ring at its top and
## three claws curled up round it, the line's end at the origin.
static func grapple() -> ArrayMesh:
	var st := Builds._begin()
	Builds.prism(st,6,0.1,0.1,-0.06,0.06,BRASS,0.0)
	Builds.prism(st,6,0.06,0.05,-0.75,-0.04,IRON,0.0)
	for k in range(3):
		var turn := Basis(Vector3.UP,TAU*k/3.0)
		Builds.box(st,turn*Vector3(0.0,-0.72,-0.2),turn*Basis(Vector3.RIGHT,-0.5),Vector3(0.045,0.04,0.22),IRON)
		Builds.box(st,turn*Vector3(0.0,-0.55,-0.4),turn*Basis(Vector3.RIGHT,0.5),Vector3(0.04,0.15,0.04),IRON)
	return Builds._end(st)

static func _end(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

# --- The envelope ---------------------------------------------------------------

## The envelope's radius at `z` along it (its middle at 0), a fat teardrop:
## round at the nose, drawn out to the tail.
static func envelope_radius(z: float) -> float:
	var h := ENVELOPE_LENGTH*0.5
	var u := clampf(z/h,-1.0,1.0)
	var fat := ENVELOPE_FAT
	# Ahead of the fattest ring a round nose; behind it a longer taper.
	var s := (u-fat)/(1.0+fat) if u < fat else (u-fat)/(1.0-fat)
	s = clampf(s,-1.0,1.0)
	var r := sqrt(maxf(0.0,1.0-s*s)) if s < 0.0 else pow(maxf(0.0,1.0-pow(s,2.2)),0.62)
	return ENVELOPE_RADIUS*r

static func _envelope(st: SurfaceTool) -> void:
	var h := ENVELOPE_LENGTH*0.5
	var zs := [-1.0,-0.96,-0.86,-0.7,-0.5,-0.25,-0.05,0.18,0.4,0.6,0.77,0.9,0.97,1.0]
	var rings := []
	for u: float in zs: rings.append(Vector2(u*h,envelope_radius(u*h)))
	var inside := ENVELOPE_AT
	for k in range(rings.size()-1):
		var a: Vector2 = rings[k]
		var b: Vector2 = rings[k+1]
		var cap := k == 0 or k >= rings.size()-3
		var band := k == 4 or k == 9
		for i in range(GORES):
			# Cream gores, every third a faded terracotta.
			var c := RUST if (i % 3 == 0) else (CANVAS if i % 3 == 1 else CANVAS_SHADE)
			if cap: c = RUST_DARK
			elif band: c = SAGE
			var p := func(r: Vector2, j: int) -> Vector3:
				var t := TAU*(float(j)+0.5)/GORES
				return ENVELOPE_AT+Vector3(cos(t)*r.y,sin(t)*r.y*0.94,r.x)
			_face(st,p.call(a,i),p.call(b,i),p.call(b,i+1),inside,c)
			_face(st,p.call(a,i),p.call(b,i+1),p.call(a,i+1),inside,c)
	# A brass ring at the nose.
	_cylinder(st,8,0.32,0.32,0.12,Transform3D(Basis(Vector3.RIGHT,PI*0.5),ENVELOPE_AT+Vector3(0.0,0.0,-h-0.02)),BRASS)

## Four fins round the tail, cruciform, rust with a canvas edge.
static func _fins(st: SurfaceTool) -> void:
	var h := ENVELOPE_LENGTH*0.5
	for k in range(4):
		var turn := Basis(Vector3.BACK,PI*0.25+PI*0.5*k)
		var root_a := h*0.42
		var root_b := h*0.95
		var r_a := envelope_radius(root_a)*0.9
		var r_b := envelope_radius(root_b)*0.9
		var a := Vector3(0.0,r_a,root_a)
		var b := Vector3(0.0,r_b,root_b+0.2)
		var tip := Vector3(0.0,r_b+2.3,root_b+0.5)
		var tip_front := Vector3(0.0,r_b+2.1,root_b-0.9)
		var at := ENVELOPE_AT
		_slab(st,[turn*a+at,turn*tip_front+at,turn*tip+at,turn*b+at],turn*Vector3.RIGHT,0.07,RUST)
		_slab(st,[turn*(tip_front+Vector3(0,0.02,0))+at,turn*(tip_front+Vector3(0,0.3,0.05))+at,turn*(tip+Vector3(0,0.3,0.05))+at,turn*(tip+Vector3(0,0.02,0))+at],turn*Vector3.RIGHT,0.08,CANVAS)

# --- The gondola ----------------------------------------------------------------

## The hull's stations along it (shares of HULL.z), its half width and its
## depth there (shares of HULL.x, HULL.y), and its sides round a half.
const HULL_ZS := [-1.0,-0.85,-0.6,-0.2,0.3,0.75,1.0]
const HULL_WIDTHS := [0.05,0.45,0.8,0.97,1.0,0.94,0.8]
const HULL_DEEPS := [0.05,0.55,0.85,1.0,1.0,0.9,0.7]
const HULL_SIDES := 7
## The cabin's middle on deck.
const CABIN_AT := Vector3(0.0,0.0,0.85)

## The gondola as it is drawn, for its solid: the hull's half shell up to
## the deck, and the cabin with its pitched roof (convex hulls' points,
## ship frame). The rails, posts and lantern are left to fly through.
static func gondola_hulls() -> Array[PackedVector3Array]:
	var hull := PackedVector3Array()
	for k in range(HULL_ZS.size()):
		for j in range(HULL_SIDES+1):
			var t := PI+PI*float(j)/HULL_SIDES
			hull.append(Vector3(cos(t)*HULL.x*float(HULL_WIDTHS[k]),sin(t)*HULL.y*float(HULL_DEEPS[k])+0.02,float(HULL_ZS[k])*HULL.z))
	var cabin := PackedVector3Array()
	for corner: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		cabin.append(CABIN_AT+Vector3(corner.x*0.72,0.0,corner.y*0.95))
		cabin.append(CABIN_AT+Vector3(corner.x*0.86,0.98,corner.y*1.08))
	for end: float in [-1.0,1.0]: cabin.append(CABIN_AT+Vector3(0.0,1.55,end*1.1))
	return [hull,cabin]

static func _gondola(st: SurfaceTool) -> void:
	# The hull: a half shell under the deck, round in section, drawn to a
	# point at the bow and blunt at the stern.
	var zs := HULL_ZS
	var widths := HULL_WIDTHS
	var deeps := HULL_DEEPS
	var sides := HULL_SIDES
	var inside := Vector3(0.0,-HULL.y*0.4,0.0)
	for k in range(zs.size()-1):
		for i in range(sides):
			var p := func(j: int, z_i: int) -> Vector3:
				var t := PI+PI*float(j)/sides
				return Vector3(cos(t)*HULL.x*widths[z_i],sin(t)*HULL.y*deeps[z_i]+0.02,zs[z_i]*HULL.z)
			var c := WOOD if i % 2 == 0 else PLANK
			if i == 0 or i == sides-1: c = RUST
			_face(st,p.call(i,k),p.call(i,k+1),p.call(i+1,k+1),inside,c)
			_face(st,p.call(i,k),p.call(i+1,k+1),p.call(i+1,k),inside,c)
	# The stern's transom, a flat face across the hull's blunt end.
	var last := zs.size()-1
	for i in range(sides):
		var t0 := PI+PI*float(i)/sides
		var t1 := PI+PI*float(i+1)/sides
		var a := Vector3(cos(t0)*HULL.x*widths[last],sin(t0)*HULL.y*deeps[last]+0.02,HULL.z)
		var b := Vector3(cos(t1)*HULL.x*widths[last],sin(t1)*HULL.y*deeps[last]+0.02,HULL.z)
		_face(st,Vector3(0.0,0.02,HULL.z),a,b,Vector3(0.0,-0.1,HULL.z-0.3),WOOD_DARK)
	# The deck, planked, and a gunwale round it.
	Builds.box(st,Vector3(0.0,0.02,0.2),Basis.IDENTITY,Vector3(HULL.x*0.92,0.04,HULL.z*0.82),PLANK)
	Builds.box(st,Vector3(0.0,0.02,-1.55),Basis(Vector3.UP,0.0),Vector3(HULL.x*0.6,0.04,0.55),PLANK)
	for side in [-1.0,1.0]:
		Builds.box(st,Vector3(side*HULL.x*0.93,0.12,0.25),Basis.IDENTITY,Vector3(0.05,0.1,HULL.z*0.78),WOOD_DARK)
	# The bow rail: posts and a top rail round the foredeck.
	var rail := [Vector3(-0.7,0.0,-0.9),Vector3(-0.5,0.0,-1.75),Vector3(0.0,0.0,-2.2),Vector3(0.5,0.0,-1.75),Vector3(0.7,0.0,-0.9)]
	for p: Vector3 in rail: Builds.box(st,p+Vector3(0.0,0.24,0.0),Basis.IDENTITY,Vector3(0.03,0.24,0.03),WOOD_DARK)
	for k in range(rail.size()-1):
		_beam(st,rail[k]+Vector3(0.0,0.47,0.0),rail[k+1]+Vector3(0.0,0.47,0.0),0.035,WOOD)
	# The cabin aft of the foredeck: lime walls on a dark sill, a pitched
	# roof of terracotta shakes, a little stovepipe.
	var cabin_at := CABIN_AT
	Builds.box(st,cabin_at+Vector3(0.0,0.06,0.0),Basis.IDENTITY,Vector3(0.72,0.06,0.95),WOOD_DARK)
	Builds.box(st,cabin_at+Vector3(0.0,0.58,0.0),Basis.IDENTITY,Vector3(0.68,0.48,0.92),LIME)
	for corner in [Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		Builds.box(st,cabin_at+Vector3(corner.x*0.68,0.58,corner.y*0.92),Basis.IDENTITY,Vector3(0.05,0.5,0.05),WOOD)
	for side in [-1.0,1.0]:
		_slab(st,[cabin_at+Vector3(side*0.02,1.5,-1.08),cabin_at+Vector3(side*0.86,0.98,-1.08),cabin_at+Vector3(side*0.86,0.98,1.08),cabin_at+Vector3(side*0.02,1.5,1.08)],Vector3.UP,0.07,ROOF)
	for end in [-1.0,1.0]:
		_face(st,cabin_at+Vector3(-0.68,1.06,end*0.92),cabin_at+Vector3(0.68,1.06,end*0.92),cabin_at+Vector3(0.0,1.46,end*0.92),cabin_at,LIME)
	Builds.box(st,cabin_at+Vector3(0.0,1.5,0.0),Basis.IDENTITY,Vector3(0.06,0.05,1.1),RUST_DARK)
	Builds.prism(st,6,0.07,0.07,1.2,1.85,IRON,0.0,cabin_at+Vector3(0.38,0.0,0.45))
	# The door, toward the bow.
	Builds.box(st,cabin_at+Vector3(0.28,0.42,-0.93),Basis.IDENTITY,Vector3(0.17,0.36,0.02),WOOD)
	# The lantern post at the bow, its arm out over the rail.
	Builds.prism(st,6,0.05,0.04,0.0,1.45,WOOD_DARK,0.0,Vector3(0.0,0.0,-2.2))
	_beam(st,Vector3(0.0,1.42,-2.2),Vector3(0.0,1.42,-2.78),0.03,WOOD_DARK)
	Builds.prism(st,6,0.11,0.07,LANTERN.y+0.13,LANTERN.y+0.24,IRON,0.0,Vector3(LANTERN.x,0.0,LANTERN.z))
	Builds.prism(st,6,0.11,0.11,LANTERN.y-0.16,LANTERN.y-0.12,IRON,0.0,Vector3(LANTERN.x,0.0,LANTERN.z))
	# The winch's frame on the stern deck.
	for side in [-0.45,0.45]:
		Builds.box(st,DRUM+Vector3(side,-0.2,0.0),Basis.IDENTITY,Vector3(0.04,0.24,0.12),WOOD_DARK)
	# Under the hull: the crossbeam the side lines hang from, braced to the
	# keel, and the keel hook under the bow.
	_beam(st,TETHERS[0]+Vector3.UP*0.08,TETHERS[1]+Vector3.UP*0.08,0.07,WOOD_DARK)
	for t: Vector3 in [TETHERS[0],TETHERS[1]]:
		_beam(st,t+Vector3.UP*0.08,Vector3(t.x*0.35,-0.3,t.z-0.6),0.04,WOOD_DARK)
		Builds.prism(st,6,0.09,0.09,t.y-0.05,t.y+0.05,BRASS,0.0,Vector3(t.x,0.0,t.z))
	_beam(st,Vector3(0.0,-0.35,-1.7),TETHERS[2],0.06,IRON)
	Builds.prism(st,6,0.09,0.09,TETHERS[2].y-0.05,TETHERS[2].y+0.05,BRASS,0.0,Vector3(TETHERS[2].x,0.0,TETHERS[2].z))

## The lines from the envelope's belly down to the gondola's gunwales.
static func _rigging(st: SurfaceTool) -> void:
	var belly := ENVELOPE_AT.y-ENVELOPE_RADIUS*0.94
	var lows := [Vector3(-0.8,0.2,-1.3),Vector3(0.8,0.2,-1.3),Vector3(-0.8,0.2,0.3),Vector3(0.8,0.2,0.3),Vector3(-0.75,0.2,1.9),Vector3(0.75,0.2,1.9)]
	for low: Vector3 in lows:
		var z := low.z*2.1
		var r := envelope_radius(z-ENVELOPE_AT.z)
		var t := -PI*0.5+signf(low.x)*0.55
		var high := ENVELOPE_AT+Vector3(cos(t)*r,sin(t)*r*0.94,z-ENVELOPE_AT.z)
		_beam(st,low,high,0.025,ROPE)
		# And a cross line to the far side, so the hang reads braced.
		_beam(st,low,Vector3(-high.x*0.6,belly+0.2,high.z),0.02,ROPE)
	# A keel batten along the belly the lines meet.
	_beam(st,Vector3(0.0,belly+0.05,-4.6),Vector3(0.0,belly+0.05,4.6),0.08,WOOD_DARK)

## The two pusher pods on their outriggers, each a faceted nacelle with a
## brass nose.
static func _pods(st: SurfaceTool) -> void:
	for side in [-1.0,1.0]:
		var at := Vector3(POD.x*side,POD.y,POD.z)
		_cylinder(st,8,0.24,0.3,0.8,Transform3D(Basis(Vector3.RIGHT,PI*0.5),at),SAGE)
		_cylinder(st,8,0.3,0.12,0.25,Transform3D(Basis(Vector3.RIGHT,PI*0.5),at+Vector3(0.0,0.0,0.52)),IRON)
		_cylinder(st,8,0.05,0.24,0.22,Transform3D(Basis(Vector3.RIGHT,-PI*0.5),at+Vector3(0.0,0.0,-0.5)),BRASS)
		_beam(st,Vector3(HULL.x*0.85*side,0.25,POD.z-0.2),at+Vector3(-0.2*side,-0.15,-0.1),0.06,WOOD_DARK)
		_beam(st,Vector3(HULL.x*0.85*side,0.25,POD.z+0.5),at+Vector3(-0.2*side,-0.15,0.15),0.05,WOOD_DARK)
		_beam(st,at+Vector3(0.0,0.2,0.0),Vector3(side*1.4,ENVELOPE_AT.y-ENVELOPE_RADIUS*0.75,POD.z),0.025,ROPE)

# --- Pieces ---------------------------------------------------------------------

## A square beam from `a` to `b`, `half` m thick each way.
static func _beam(st: SurfaceTool, a: Vector3, b: Vector3, half: float, colour: Color) -> void:
	var along := b-a
	var length := along.length()
	if length < 0.001: return
	var z := along/length
	var x := z.cross(Vector3.UP if absf(z.y) < 0.95 else Vector3.RIGHT).normalized()
	var y := z.cross(x).normalized()
	Builds.box(st,(a+b)*0.5,Basis(x,y,z),Vector3(half,half,length*0.5),colour)

## A flat polygon `points` (convex, in order) thickened `thick` m along
## `normal`, both sides and the edges.
static func _slab(st: SurfaceTool, points: Array, normal: Vector3, thick: float, colour: Color) -> void:
	var off := normal.normalized()*thick*0.5
	var mid := Vector3.ZERO
	for p: Vector3 in points: mid += p
	mid /= points.size()
	for k in range(1,points.size()-1):
		_face(st,points[0]+off,points[k]+off,points[k+1]+off,mid-off*4.0,colour)
		_face(st,points[0]-off,points[k]-off,points[k+1]-off,mid+off*4.0,colour)
	for k in range(points.size()):
		var a: Vector3 = points[k]
		var b: Vector3 = points[(k+1)%points.size()]
		_face(st,a+off,b+off,b-off,mid,colour)
		_face(st,a+off,b-off,a-off,mid,colour)

## A prism of `sides` from radius `bottom` to `top`, `height` along its
## local Y, posed by `pose`.
static func _cylinder(st: SurfaceTool, sides: int, bottom: float, top: float, height: float, pose: Transform3D, colour: Color) -> void:
	var low := -height*0.5
	var high := height*0.5
	var inside := pose*Vector3.ZERO
	for k in range(sides):
		var a0 := TAU*k/sides
		var a1 := TAU*(k+1)/sides
		var b0 := pose*Vector3(sin(a0)*bottom,low,cos(a0)*bottom)
		var b1 := pose*Vector3(sin(a1)*bottom,low,cos(a1)*bottom)
		var t0 := pose*Vector3(sin(a0)*top,high,cos(a0)*top)
		var t1 := pose*Vector3(sin(a1)*top,high,cos(a1)*top)
		_face(st,b0,t0,t1,inside,colour)
		_face(st,b0,t1,b1,inside,colour)
		_face(st,pose*Vector3(0.0,high,0.0),t1,t0,pose*Vector3(0.0,low,0.0),colour)
		_face(st,pose*Vector3(0.0,low,0.0),b0,b1,pose*Vector3(0.0,high,0.0),colour)

## One flat face, wound to face away from `inside` (Godot's front faces are
## clockwise seen from outside).
static func _face(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, inside: Vector3, colour: Color) -> void:
	var n := (b-a).cross(c-a)
	if n.length_squared() < 1e-12: return
	# Clockwise from outside: the cross product of (b-a, c-a) points in.
	if n.dot((a+b+c)/3.0-inside) > 0.0:
		var s := b
		b = c
		c = s
	var linear := colour.srgb_to_linear()
	for v: Vector3 in [a,b,c]:
		st.set_color(linear)
		st.add_vertex(v)
