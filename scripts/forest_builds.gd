extends RefCounted
## The forest hold's builds (scripts/forest_hold.gd), faceted and flat
## shaded in the showcase's woods and roof tones (scripts/showcase_builds.gd),
## made by hand so a worker can make them: the platform in the hold tree's
## boughs (a plank ring round the trunk under a skirt of roof, braced to the
## trunk, railed, a ladder down), and the strings the canopy's lanterns hang
## on. The lanterns themselves are the showcase's; the glow is the
## dresser's (scripts/cluster_dresser.gd).

const Builds = preload("res://scripts/showcase_builds.gd")

const ROPE := Color("8a7458")
## The platform: its planks round, its rail's height (m), the roof's rise
## over the deck (m), and the ladder's rungs apart (m) and width (m).
const PLANKS := 20
const RAIL := 0.85
const ROOF_LOW := 1.85
const ROOF_HIGH := 2.75
const RUNG := 0.32
const LADDER := 0.42
## A lantern's hook over its foot (Builds `lantern`), and the cord's length
## from a string down to the hook (m).
const HOOK := 0.38
const CORD := 0.12

## The platform round a trunk standing at the origin (its ground at y 0):
## its deck `height` m up between `inner` and `outer` m round; the ladder's
## foot out along +Z, the gap in the rail there. Turned and stood by the
## caller.
static func platform(st: SurfaceTool, height: float, inner: float, outer: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	# Planks, radial, each a little different.
	for k in range(PLANKS):
		var a := TAU*(k+0.5)/PLANKS
		var way := Vector3(sin(a),0.0,cos(a))
		var mid := way*(inner+outer)*0.5+Vector3.UP*(height-0.04)
		var basis := Basis(Vector3.UP,a+rng.randf_range(-0.03,0.03))
		Builds.box(st,mid,basis,Vector3(outer*PI/PLANKS*0.46,0.04,(outer-inner)*0.5+rng.randf_range(-0.04,0.06)),Builds.PLANK.darkened(rng.randf_range(0.0,0.16)))
	# A ring beam under the planks' outer ends, and braces down to the trunk.
	for k in range(8):
		var a0 := TAU*k/8.0
		var a1 := TAU*(k+1)/8.0
		var p := Vector3(sin(a0),0.0,cos(a0))*(outer-0.12)
		var q := Vector3(sin(a1),0.0,cos(a1))*(outer-0.12)
		_beam(st,p+Vector3.UP*(height-0.14),q+Vector3.UP*(height-0.14),0.06,Builds.WOOD_DARK)
		if k % 2 == 0:
			var foot := Vector3(sin(a0),0.0,cos(a0))*inner*0.9+Vector3.UP*(height-1.4)
			_beam(st,foot,p*0.85+Vector3.UP*(height-0.12),0.07,Builds.WOOD_DARK)
	# The rail: posts round the rim, rails between, open over the ladder.
	var posts := 10
	for k in range(posts):
		var a0 := TAU*k/posts+PI/posts
		var a1 := TAU*(k+1)/posts+PI/posts
		var p := Vector3(sin(a0),0.0,cos(a0))*(outer-0.06)
		var q := Vector3(sin(a1),0.0,cos(a1))*(outer-0.06)
		Builds.box(st,p+Vector3.UP*(height+RAIL*0.5),Basis(Vector3.UP,a0),Vector3(0.045,RAIL*0.5,0.045),Builds.WOOD_DARK)
		# The ladder comes up at +Z, between the last post and the first.
		if k == posts-1: continue
		for h: float in [RAIL-0.04,RAIL*0.5]:
			_beam(st,p+Vector3.UP*(height+h),q+Vector3.UP*(height+h),0.03,Builds.WOOD.darkened(rng.randf_range(0.0,0.12)))
	# The roof: a faceted skirt round the trunk over the deck.
	var sides := 9
	for k in range(sides):
		var a0 := TAU*k/sides
		var a1 := TAU*(k+1)/sides
		var low := outer+0.35
		var high := inner*0.85
		var b0 := Vector3(sin(a0)*low,height+ROOF_LOW,cos(a0)*low)
		var b1 := Vector3(sin(a1)*low,height+ROOF_LOW,cos(a1)*low)
		var t0 := Vector3(sin(a0)*high,height+ROOF_HIGH,cos(a0)*high)
		var t1 := Vector3(sin(a1)*high,height+ROOF_HIGH,cos(a1)*high)
		var tone := (Builds.ROOF if k % 2 == 0 else Builds.ROOF_DARK).darkened(rng.randf_range(0.0,0.08))
		_quad(st,b0,t0,t1,b1,tone)
		_quad(st,b1,t1,t0,b0,tone.darkened(0.3))
		# Posts holding the roof's eaves at every third side.
		if k % 3 == 0:
			var foot := Vector3(sin(a0),0.0,cos(a0))*(outer-0.06)
			if k != 0: Builds.box(st,foot+Vector3.UP*(height+ROOF_LOW*0.5),Basis(Vector3.UP,a0),Vector3(0.05,ROOF_LOW*0.5,0.05),Builds.WOOD_DARK)
	# The ladder, leaning from the ground out past the deck up to its rim.
	var top := Vector3(0.0,height,outer-0.05)
	var foot := Vector3(0.0,0.0,outer+0.55)
	for side in [-1.0,1.0]:
		var off := Vector3(side*LADDER*0.5,0.0,0.0)
		_beam(st,foot+off+Vector3.DOWN*0.1,top+off+Vector3.UP*0.5,0.035,Builds.WOOD_DARK)
	var rungs := int(height/RUNG)
	for k in range(1,rungs+1):
		var p := foot.lerp(top,float(k)/(rungs+1))
		Builds.box(st,p,Basis.IDENTITY,Vector3(LADDER*0.5,0.022,0.025),Builds.WOOD.darkened(rng.randf_range(0.0,0.15)))

## Where the ladder's foot stands (platform frame), for the land under it.
static func ladder_foot(outer: float) -> Vector3:
	return Vector3(0.0,0.0,outer+0.55)

## Lantern hooks round the platform's eaves (platform frame), for `count`
## lanterns.
static func eave_hooks(height: float, outer: float, count: int) -> Array:
	var out: Array = []
	for k in range(count):
		var a := TAU*(k+0.5)/count+0.3
		out.append(Vector3(sin(a),0.0,cos(a))*(outer+0.2)+Vector3.UP*(height+ROOF_LOW-0.02))
	return out

## A string of lanterns sagging `sag` m from `a` to `b`: the rope, and a
## short cord down to each of `count` hooks; returns the hooks.
static func string(st: SurfaceTool, a: Vector3, b: Vector3, sag: float, count: int) -> Array:
	var pieces := maxi(6,roundi(a.distance_to(b)/0.6))
	var prev := a
	for k in range(1,pieces+1):
		var p := along(a,b,sag,float(k)/pieces)
		_beam(st,prev,p,0.012,ROPE)
		prev = p
	var hooks: Array = []
	for k in range(count):
		var p := along(a,b,sag,(k+0.5)/count)
		_beam(st,p,p+Vector3.DOWN*CORD,0.008,ROPE)
		hooks.append(p+Vector3.DOWN*CORD)
	return hooks

## A point on a string `t` of the way from `a` to `b`, sagging `sag` m at
## its middle.
static func along(a: Vector3, b: Vector3, sag: float, t: float) -> Vector3:
	return a.lerp(b,t)+Vector3.DOWN*sag*4.0*t*(1.0-t)

## A cord from a bough at `from` down to a lantern's hook at `to`.
static func cord(st: SurfaceTool, from: Vector3, to: Vector3) -> void:
	_beam(st,from,to,0.008,ROPE)

## A lantern's glow: a small faceted bead (made by hand; a primitive mesh
## asks the renderer for its faces).
static func bead(radius: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := [Vector3.UP,Vector3.DOWN,Vector3.RIGHT,Vector3.LEFT,Vector3.FORWARD,Vector3.BACK]
	for tri: Array in [[0,2,4],[0,4,3],[0,3,5],[0,5,2],[1,4,2],[1,3,4],[1,5,3],[1,2,5]]:
		for i: int in tri:
			st.set_color(Color.WHITE)
			st.add_vertex((c[i] as Vector3)*radius)
	st.generate_normals()
	return st.commit()

static func _beam(st: SurfaceTool, p: Vector3, q: Vector3, half: float, colour: Color) -> void:
	var way := q-p
	if way.length() < 0.001: return
	var basis := Basis.looking_at(way.normalized(),Vector3.UP if absf(way.normalized().y) < 0.99 else Vector3.RIGHT)
	Builds.box(st,(p+q)*0.5,basis,Vector3(half,half,way.length()*0.5),colour)

static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, colour: Color) -> void:
	Builds._tri(st,Transform3D.IDENTITY,colour.srgb_to_linear(),a,b,c)
	Builds._tri(st,Transform3D.IDENTITY,colour.srgb_to_linear(),a,c,d)
