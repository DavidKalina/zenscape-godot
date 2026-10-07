extends RefCounted
## The built things on the showcase cluster (scripts/sky_showcase.gd): a
## windmill, a lighthouse, a plank dock, a split-rail fence, a fishing rod
## and a hand lantern. Made as the stone lamp and the footbridge are
## (scripts/stone_lamp.gd, scripts/footbridge.gd): upright faceted prisms
## and boxes, one flat face a facet, vertex-coloured in the scene's own
## earthy palette, so they read as cut from the same world. Sizes are real
## metres, each thing's foot at its origin, its front toward -Z.
##
## What moves or glows is a separate mesh, for the showcase to turn or
## light: the windmill's sails (about +Z through the hub), the lighthouse's
## lamp and its beams.

const STONE := Color("9a958a")
const STONE_DARK := Color("7a756c")
const LIME := Color("e6dccb")
const ROOF := Color("8a4a36")
const ROOF_DARK := Color("6e3a2c")
const WOOD := Color("6f5238")
const WOOD_DARK := Color("4c3a2a")
const PLANK := Color("8a6a4a")
const CLOTH := Color("efe4cc")
const GLASS := Color("3b4a52")
const BAND := Color("b4483c")
const BRASS := Color("d6ad62")
const LAMP := Color("ffd391")

## The windmill: the hub's height and how far it stands out front.
const HUB := Vector3(0.0,6.0,-1.25)
const SAIL := 4.2
## The lighthouse: the lamp's middle.
const LAMP_AT := Vector3(0.0,8.75,0.0)

## The windmill's tower, cap and door (no sails).
static func windmill() -> ArrayMesh:
	var st := _begin()
	prism(st,8,1.55,1.45,0.0,0.55,STONE,PI/8.0)
	prism(st,8,1.35,0.95,0.55,5.85,LIME,PI/8.0)
	prism(st,8,1.05,1.05,5.85,6.05,WOOD_DARK,PI/8.0)
	prism(st,8,1.18,0.32,6.05,7.35,ROOF,PI/8.0)
	prism(st,8,0.14,0.04,7.35,7.75,ROOF_DARK,PI/8.0)
	# The door and two small windows up the front, the shaft's housing.
	box(st,Vector3(0.0,0.75,-1.33),Basis(Vector3.RIGHT,0.08),Vector3(0.42,0.75,0.05),WOOD)
	box(st,Vector3(0.0,3.1,-1.17),Basis(Vector3.RIGHT,0.08),Vector3(0.22,0.3,0.04),GLASS)
	box(st,Vector3(0.0,4.7,-1.06),Basis(Vector3.RIGHT,0.08),Vector3(0.2,0.26,0.04),GLASS)
	box(st,Vector3(0.0,HUB.y,-0.95),Basis.IDENTITY,Vector3(0.18,0.18,0.35),WOOD_DARK)
	return _end(st)

## The four sails round the hub, in the hub's frame (-Z out of the front,
## as the mill faces, so the showcase turns them about Z).
static func sails() -> ArrayMesh:
	var st := _begin()
	prism_axis(st,8,0.22,0.16,-0.25,0.1,WOOD_DARK,0.0)
	for k in range(4):
		var turn := Basis(Vector3.BACK,PI*0.5*k+0.3)
		# The stock out along the arm, then the lattice frame and its cloth
		# on the trailing side.
		box(st,turn*Vector3(0.0,SAIL*0.5,-0.12),turn,Vector3(0.07,SAIL*0.5,0.05),WOOD)
		var frame_mid := Vector3(0.36,SAIL*0.58,-0.16)
		box(st,turn*frame_mid,turn,Vector3(0.36,SAIL*0.4,0.025),CLOTH)
		for edge: Vector3 in [Vector3(0.72,SAIL*0.58,-0.18),Vector3(0.36,SAIL*0.98,-0.18),Vector3(0.36,SAIL*0.18,-0.18)]:
			var half := Vector3(0.03,SAIL*0.4,0.03) if edge.x > 0.5 else Vector3(0.38,0.03,0.03)
			box(st,turn*edge,turn,half,WOOD_DARK)
		for bar in range(1,4):
			box(st,turn*Vector3(0.36,SAIL*(0.18+0.2*bar),-0.19),turn,Vector3(0.36,0.018,0.02),WOOD_DARK)
	return _end(st)

## The lighthouse: plinth, banded tower, gallery and rail, the lamp room's
## dark glass and its red cap.
static func lighthouse() -> ArrayMesh:
	var st := _begin()
	prism(st,8,1.95,1.85,0.0,0.5,STONE,PI/8.0)
	var bands := [[0.5,2.4,LIME],[2.4,3.3,BAND],[3.3,5.2,LIME],[5.2,6.1,BAND],[6.1,8.0,LIME]]
	for b: Array in bands:
		var r0 := lerpf(1.55,1.05,(float(b[0])-0.5)/7.5)
		var r1 := lerpf(1.55,1.05,(float(b[1])-0.5)/7.5)
		prism(st,8,r0,r1,b[0],b[1],b[2],PI/8.0)
	prism(st,8,1.6,1.6,8.0,8.2,STONE_DARK,PI/8.0)
	for k in range(16):
		var a := TAU*k/16.0
		box(st,Vector3(cos(a)*1.48,8.5,sin(a)*1.48),Basis(Vector3.UP,-a),Vector3(0.03,0.3,0.03),WOOD_DARK)
	prism(st,16,1.5,1.5,8.78,8.84,WOOD_DARK,0.0)
	prism(st,8,0.8,0.8,8.2,8.3,STONE_DARK,PI/8.0)
	for k in range(8):
		var a := TAU*k/8.0+PI/8.0
		box(st,Vector3(cos(a)*0.78,8.85,sin(a)*0.78),Basis(Vector3.UP,-a),Vector3(0.04,0.55,0.04),STONE_DARK)
	prism(st,8,1.05,0.1,9.4,10.35,BAND,PI/8.0)
	prism(st,8,0.06,0.1,10.35,10.65,BRASS,PI/8.0)
	box(st,Vector3(0.0,0.95,-1.56),Basis(Vector3.RIGHT,0.06),Vector3(0.4,0.6,0.05),WOOD)
	return _end(st)

## The lamp room's glass and the lamp in it: one mesh the showcase lights
## at night (emission), dark glass by day.
static func lamp_room() -> ArrayMesh:
	var st := _begin()
	prism(st,8,0.74,0.74,8.3,9.4,GLASS,PI/8.0)
	return _end(st)

## A beam: a long, thin fan out along -Z from the origin, `reach` m and
## `spread` m wide each side at its end, as two crossed sheets; its alpha
## in the vertex colours, bright along its middle line and gone at its
## edges and its end, so no sheet's edge shows.
static func beam(reach: float, spread: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 10
	for s in range(segments):
		var u0 := float(s)/segments
		var u1 := float(s+1)/segments
		var w0 := lerpf(0.2,spread,u0)
		var w1 := lerpf(0.2,spread,u1)
		var a0 := pow(1.0-u0,1.4)*smoothstep(0.0,0.08,u0+0.02)
		var a1 := pow(1.0-u1,1.4)
		for plane: Vector3 in [Vector3.RIGHT,Vector3.UP]:
			for side: float in [-1.0,1.0]:
				var c0 := Vector3.FORWARD*reach*u0
				var c1 := Vector3.FORWARD*reach*u1
				var e0 := c0+plane*side*w0
				var e1 := c1+plane*side*w1
				for v: Array in [[c0,a0],[c1,a1],[e1,0.0],[c0,a0],[e1,0.0],[e0,0.0]]:
					st.set_color(Color(LAMP,float(v[1])))
					st.add_vertex(v[0])
	return st.commit()

## A plank dock from `a` to `b` (its deck's top, in the islet's frame),
## `width` m wide: planks across two stringers, posts dropping under its
## far half, and a bollard and a lantern post at its end.
static func dock(a: Vector3, b: Vector3, width: float, seed: int) -> ArrayMesh:
	var st := _begin()
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
		box(st,at,turn*yaw,Vector3(width*0.5+rng.randf_range(-0.05,0.04),0.04,0.1),PLANK.darkened(rng.randf_range(0.0,0.16)))
	for side: float in [-1.0,1.0]:
		var mid := a.lerp(b,0.5)+across*side*width*0.36+Vector3.DOWN*0.16
		box(st,mid,turn,Vector3(0.06,0.07,span*0.5),WOOD_DARK)
	for t: float in [0.45,0.72,0.98]:
		for side: float in [-1.0,1.0]:
			var top := a.lerp(b,t)+across*side*(width*0.5-0.05)
			box(st,top+Vector3.DOWN*0.95,turn,Vector3(0.08,0.95,0.08),WOOD_DARK)
	var end := b-along*0.25
	prism(st,6,0.12,0.1,0.0,0.4,WOOD_DARK,0.0,end+across*(width*0.5-0.15))
	prism(st,6,0.06,0.06,0.0,1.7,WOOD_DARK,0.0,end-across*(width*0.5-0.1))
	box(st,end-across*(width*0.5-0.1)+Vector3(0.0,1.7,0.0)+along*0.12,turn,Vector3(0.03,0.03,0.16),WOOD_DARK)
	return _end(st)

## Where the dock's lantern hangs, for its light (islet frame).
static func dock_lantern(a: Vector3, b: Vector3, width: float) -> Vector3:
	var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
	var along := flat.normalized()
	var across := along.cross(Vector3.UP).normalized()
	return b-along*0.25-across*(width*0.5-0.1)+along*0.26+Vector3(0.0,1.48,0.0)

## The windmill's two windows, as panes just proud of their glass, for the
## showcase to light at night.
static func windmill_windows() -> ArrayMesh:
	var st := _begin()
	box(st,Vector3(0.0,3.1,-1.19),Basis(Vector3.RIGHT,0.08),Vector3(0.18,0.26,0.03),GLASS)
	box(st,Vector3(0.0,4.7,-1.08),Basis(Vector3.RIGHT,0.08),Vector3(0.16,0.22,0.03),GLASS)
	return _end(st)

## A lantern post: a post `height` m tall with an arm out along -Z, the
## lantern hung from its end (`post_lantern`).
static func post(height := 1.9) -> ArrayMesh:
	var st := _begin()
	prism(st,6,0.11,0.09,0.0,0.25,STONE,0.0)
	prism(st,6,0.06,0.06,0.0,height,WOOD_DARK,0.0)
	box(st,Vector3(0.0,height-0.04,-0.17),Basis.IDENTITY,Vector3(0.03,0.03,0.2),WOOD_DARK)
	return _end(st)

static func post_lantern(height := 1.9) -> Vector3:
	return Vector3(0.0,height-0.08,-0.34)

## A hanging lantern: a small faceted cage with a roof (its foot at the
## origin, about 0.3 m tall); the glow is the showcase's.
static func lantern() -> ArrayMesh:
	var st := _begin()
	prism(st,6,0.075,0.075,0.0,0.03,WOOD_DARK,0.0)
	for k in range(6):
		var a := TAU*k/6.0
		box(st,Vector3(cos(a)*0.065,0.12,sin(a)*0.065),Basis.IDENTITY,Vector3(0.008,0.09,0.008),WOOD_DARK)
	prism(st,6,0.1,0.02,0.21,0.3,ROOF_DARK,0.0)
	box(st,Vector3(0.0,0.34,0.0),Basis.IDENTITY,Vector3(0.006,0.04,0.006),WOOD_DARK)
	return _end(st)

## A split-rail fence round the corners `posts` (islet frame, x, z),
## closed back to the first, a gap left on the side from `gate` to
## `gate`+1; each post seated on `ground` (Callable(Vector2) -> float),
## none where it gives -INF (off the land), nor the rails to it.
static func fence(posts: PackedVector2Array, gate: int, ground: Callable, seed: int) -> ArrayMesh:
	var st := _begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var stands := []
	for i in range(posts.size()):
		var a := posts[i]
		var b := posts[(i+1)%posts.size()]
		var n := maxi(1,ceili(a.distance_to(b)/2.0))
		for k in range(n):
			var p := a.lerp(b,float(k)/n)
			stands.append([p,i])
	for s in range(stands.size()):
		var p: Vector2 = stands[s][0]
		var y: float = ground.call(p)
		if y == -INF: continue
		box(st,Vector3(p.x,y+0.42,p.y),Basis(Vector3.UP,rng.randf_range(-0.2,0.2)),Vector3(0.06,0.5,0.06),WOOD_DARK)
		var next: Array = stands[(s+1)%stands.size()]
		if int(stands[s][1]) == gate: continue
		var q: Vector2 = next[0]
		var yq: float = ground.call(q)
		if yq == -INF: continue
		for h: float in [0.35,0.68]:
			var from := Vector3(p.x,y+h,p.y)
			var to := Vector3(q.x,yq+h,q.y)
			var way := to-from
			var basis := Basis.looking_at(way.normalized(),Vector3.UP)
			box(st,(from+to)*0.5,basis,Vector3(0.035,0.03,way.length()*0.5),WOOD.darkened(rng.randf_range(0.0,0.15)))
	return _end(st)

## A fishing rod `length` m long up along -Z and +Y from the origin (the
## hand), its tip at `rod_tip`.
static func rod(length: float) -> ArrayMesh:
	var st := _begin()
	var tip := rod_tip(length)
	var basis := Basis.looking_at(tip.normalized(),Vector3.UP)
	box(st,tip*0.5,basis,Vector3(0.012,0.012,length*0.5),WOOD)
	return _end(st)

static func rod_tip(length: float) -> Vector3:
	return Vector3(0.0,0.55,-0.83).normalized()*length

## A line hanging `drop` m from the origin.
static func line(drop: float) -> ArrayMesh:
	var st := _begin()
	box(st,Vector3(0.0,-drop*0.5,0.0),Basis.IDENTITY,Vector3(0.006,drop*0.5,0.006),CLOTH)
	box(st,Vector3(0.0,-drop,0.0),Basis.IDENTITY,Vector3(0.03,0.03,0.03),BAND)
	return _end(st)

# --- Pieces -----------------------------------------------------------------------

static func _begin() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	return st

static func _end(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()

## An upright n-sided prism from `low` to `high` (m), corner radii `bottom`
## and `top`, turned `turn` about up and stood at `at`.
static func prism(st: SurfaceTool, sides: int, bottom: float, top: float, low: float, high: float, colour: Color, turn: float, at := Vector3.ZERO) -> void:
	_cylinder(st,sides,bottom,top,high-low,Transform3D(Basis(Vector3.UP,turn),at+Vector3(0.0,(low+high)*0.5,0.0)),colour)

## A prism along +Z (for the hub), from `low` to `high` along it.
static func prism_axis(st: SurfaceTool, sides: int, bottom: float, top: float, low: float, high: float, colour: Color, turn: float) -> void:
	_cylinder(st,sides,bottom,top,high-low,Transform3D(Basis(Vector3.RIGHT,PI*0.5)*Basis(Vector3.UP,turn),Vector3(0.0,0.0,(low+high)*0.5)),colour)

static func _cylinder(st: SurfaceTool, sides: int, bottom: float, top: float, height: float, pose: Transform3D, colour: Color) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = height
	cylinder.radial_segments = sides
	cylinder.rings = 0
	var linear := colour.srgb_to_linear()
	for vertex in cylinder.get_faces():
		st.set_color(linear)
		st.add_vertex(pose*vertex)

## A box of half extents `half` at `centre`, turned by `basis`.
static func box(st: SurfaceTool, centre: Vector3, basis: Basis, half: Vector3, colour: Color) -> void:
	var cube := BoxMesh.new()
	cube.size = half*2.0
	var pose := Transform3D(basis,centre)
	var linear := colour.srgb_to_linear()
	for vertex in cube.get_faces():
		st.set_color(linear)
		st.add_vertex(pose*vertex)
