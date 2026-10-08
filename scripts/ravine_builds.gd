extends RefCounted
## The ravine's lookout (scripts/ravine_cut.gd `feature`): a plank deck run
## out from the far half's lip over the gap, railed round its end, held up
## by raking braces set into the rock wall under the lip (nothing hangs down
## into the gap), a lantern post at its outer corner. Made as the dock is
## (scripts/showcase_builds.gd): faceted boxes and prisms, vertex-coloured
## in the builds' own palette, so it reads as the same hands' work.

const Builds = preload("res://scripts/showcase_builds.gd")

## The deck's width (m); the rail's height and its posts' spacing (m); the
## braces' drop under the lip (m) and how far back into the wall they bed.
const WIDTH := 1.4
const RAIL := 0.95
const RAIL_STEP := 1.1
const BRACE_DROP := 2.3
const BRACE_BED := 0.35
## The lantern post's height (m).
const POST := 1.85

## The lookout for feature `f` ({a, b: deck ends, lip: where the land
## ends under it}, the islet's frame).
static func overlook(f: Dictionary, seed: int) -> ArrayMesh:
	var a: Vector3 = f.a
	var b: Vector3 = f.b
	var lip: Vector3 = f.get("lip",a.lerp(b,0.3))
	var st := Builds._begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var span := flat.length()
	var along := flat/span
	var across := along.cross(Vector3.UP).normalized()
	var turn := Basis(across,Vector3.UP,-along)
	var planks := roundi(span/0.24)
	for i in range(planks):
		var t := (i+0.5)/planks
		var at := a.lerp(b,t)+Vector3.DOWN*0.04
		var yaw := Basis(Vector3.UP,rng.randf_range(-0.03,0.03))
		Builds.box(st,at,turn*yaw,Vector3(WIDTH*0.5+rng.randf_range(-0.05,0.04),0.04,0.1),Builds.PLANK.darkened(rng.randf_range(0.0,0.16)))
	for side: float in [-1.0,1.0]:
		Builds.box(st,a.lerp(b,0.5)+across*side*WIDTH*0.36+Vector3.DOWN*0.16,turn,Vector3(0.07,0.08,span*0.5),Builds.WOOD_DARK)
	# The rail: from just short of the lip round the end.
	var from := clampf((lip-a).dot(along)/span-0.12,0.0,0.6)
	var posts: Array = []
	var n := maxi(2,ceili(span*(1.0-from)/RAIL_STEP))
	for k in range(n+1):
		var t := lerpf(from,0.98,float(k)/n)
		for side: float in [-1.0,1.0]:
			posts.append([a.lerp(b,t)+across*side*(WIDTH*0.5-0.04),side,k])
	for p: Array in posts:
		Builds.box(st,(p[0] as Vector3)+Vector3.UP*RAIL*0.5,turn,Vector3(0.045,RAIL*0.5,0.045),Builds.WOOD_DARK)
	for side: float in [-1.0,1.0]:
		var s0: Vector3 = a.lerp(b,from)+across*side*(WIDTH*0.5-0.04)
		var s1: Vector3 = a.lerp(b,0.98)+across*side*(WIDTH*0.5-0.04)
		for h: float in [RAIL,RAIL*0.5]:
			_beam(st,s0+Vector3.UP*h,s1+Vector3.UP*h,0.03,Builds.WOOD.darkened(rng.randf_range(0.0,0.12)))
	var e0: Vector3 = a.lerp(b,0.98)-across*(WIDTH*0.5-0.04)
	var e1: Vector3 = a.lerp(b,0.98)+across*(WIDTH*0.5-0.04)
	for h: float in [RAIL,RAIL*0.5]: _beam(st,e0+Vector3.UP*h,e1+Vector3.UP*h,0.03,Builds.WOOD)
	# The braces: from under the deck's outer part, raking down and back
	# into the wall under the lip.
	var bed := lip-along*BRACE_BED+Vector3.DOWN*BRACE_DROP
	for t: float in [0.62,0.92]:
		var out_t := lerpf((lip-a).dot(along)/span,1.0,t)
		for side: float in [-1.0,1.0]:
			var top := a.lerp(b,out_t)+across*side*WIDTH*0.36+Vector3.DOWN*0.2
			var foot := bed+across*side*WIDTH*0.3
			_beam(st,top,foot,0.06,Builds.WOOD_DARK)
	# The lantern post at the outer corner.
	var corner := a.lerp(b,0.98)-across*(WIDTH*0.5-0.08)
	Builds.prism(st,6,0.07,0.06,0.0,POST,Builds.WOOD_DARK,0.0,corner)
	Builds.box(st,corner+Vector3(0.0,POST-0.04,0.0)+along*0.14,turn,Vector3(0.03,0.03,0.17),Builds.WOOD_DARK)
	return Builds._end(st)

## Where the lookout's lantern hangs (islet frame), for its glow.
static func overlook_lantern(f: Dictionary) -> Vector3:
	var a: Vector3 = f.a
	var b: Vector3 = f.b
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var along := flat.normalized()
	var across := along.cross(Vector3.UP).normalized()
	return a.lerp(b,0.98)-across*(WIDTH*0.5-0.08)+along*0.28+Vector3(0.0,POST-0.36,0.0)

## A square beam of half thickness `half` from `p` to `q`.
static func _beam(st: SurfaceTool, p: Vector3, q: Vector3, half: float, colour: Color) -> void:
	var way := q-p
	var up := Vector3.UP if absf(way.normalized().dot(Vector3.UP)) < 0.95 else Vector3.RIGHT
	Builds.box(st,(p+q)*0.5,Basis.looking_at(way.normalized(),up),Vector3(half,half,way.length()*0.5),colour)
