extends RefCounted
## The lake motif's small things (scripts/lake_dress.gd), made as the
## showcase's builds are (scripts/showcase_builds.gd): flat faces,
## vertex-coloured in the scene's earthy palette, real metres, each
## thing's foot at its origin and its front toward -Z.
##   the rowing boat: a faceted clinker hull, two thwarts, a pair of oars
##     shipped along it and a lantern pole at the stern (BOAT_LANTERN);
##     its paint by `paint` (BOAT_PAINTS);
##   a lily pad, a notched heptagon, and one with a bloom on it;
##   a floating lantern: a little raft with a paper shade on it, the shade
##     a second surface for the paper's own material (it glows at night).

const Builds = preload("res://scripts/showcase_builds.gd")

## The boat: its stations from bow (-Z) to stern (+Z): [z, gunwale half
## width, gunwale height, bilge half width, keel height] (m).
const HULL := [[-1.45,0.03,0.56,0.0,0.2],[-1.05,0.36,0.46,0.16,0.05],[-0.35,0.56,0.41,0.3,0.0],
	[0.45,0.56,0.41,0.3,0.0],[1.12,0.46,0.45,0.25,0.05],[1.25,0.43,0.47,0.22,0.08]]
## How deep the hull sits in the water (m), where its lantern's foot stands
## (boat frame), and the paints a boat is drawn in: [hull, band].
const DRAFT := 0.22
const BOAT_LANTERN := Vector3(0.0,1.18,1.08)
const BOAT_PAINTS := [[Color("4f6f6c"),Color("d8cdb4")],[Color("8a4a36"),Color("e6dccb")],[Color("6f5238"),Color("4f6f6c")],
	[Color("d8cdb4"),Color("8a4a36")]]
const INSIDE := Color("5a4330")
## A lily pad's radius (m) and greens; a bloom's petals.
const PAD := 0.32
const PAD_GREENS := [Color("5b8a43"),Color("4c7a3a"),Color("6a944c")]
const PETAL := Color("f3ecef")
const PETAL_PINK := Color("eab8c4")
const HEART := Color("e8c34e")
## The floating lantern: the raft's half width, the shade's radius and
## height (m), and its paper.
const RAFT := 0.13
const SHADE := Vector2(0.1,0.2)
const PAPER := Color("e9cc98")

## The rowing boat in paint `paint` (an index into BOAT_PAINTS).
static func boat(paint: int) -> ArrayMesh:
	var st := Builds._begin()
	var colours: Array = BOAT_PAINTS[paint % BOAT_PAINTS.size()]
	var hull: Color = colours[0]
	var band: Color = colours[1]
	var rings := []
	for s: Array in HULL:
		var z: float = s[0]
		var gw: float = s[1]
		var gy: float = s[2]
		var bw: float = s[3]
		var ky: float = s[4]
		# Round the hull: gunwale, a strake, the bilge, the keel.
		rings.append([Vector3(-gw,gy,z),Vector3(-lerpf(gw,bw,0.45)-0.03,lerpf(gy,ky,0.45),z),Vector3(-bw,ky+0.06,z),Vector3(0.0,ky,z),
			Vector3(bw,ky+0.06,z),Vector3(lerpf(gw,bw,0.45)+0.03,lerpf(gy,ky,0.45),z),Vector3(gw,gy,z)])
	for r in range(rings.size()-1):
		var a: Array = rings[r]
		var b: Array = rings[r+1]
		for k in range(a.size()-1):
			var tone := band if k == 0 or k == a.size()-2 else hull.darkened(0.06*float(k % 2))
			var middle: Vector3 = (a[k]+a[k+1]+b[k]+b[k+1])*0.25
			var out := Vector3(middle.x,middle.y-0.5,0.0)
			_quad(st,tone,a[k],a[k+1],b[k+1],b[k],out)
			# The inside, a little in, so it shows over the gunwale.
			var inset := func(v: Vector3) -> Vector3: return Vector3(v.x*0.9,v.y+0.035,v.z*0.97)
			_quad(st,INSIDE.darkened(0.08*float(k % 2)),inset.call(a[k]),inset.call(a[k+1]),inset.call(b[k+1]),inset.call(b[k]),-out)
	# The transom, outside and in.
	var stern: Array = rings[rings.size()-1]
	for k in range(1,stern.size()-1):
		_tri(st,hull,stern[0],stern[k],stern[k+1],Vector3.BACK)
		_tri(st,INSIDE,stern[0]+Vector3(0.0,0.0,-0.03),stern[k]+Vector3(0.0,0.0,-0.03),stern[k+1]+Vector3(0.0,0.0,-0.03),Vector3.FORWARD)
	# The gunwale's rail, the thwarts, the oars shipped along the sides.
	for side: float in [-1.0,1.0]:
		for r in range(rings.size()-1):
			var a: Vector3 = rings[r][0 if side < 0.0 else 6]
			var b: Vector3 = rings[r+1][0 if side < 0.0 else 6]
			var way := b-a
			Builds.box(st,(a+b)*0.5+Vector3(0.0,0.02,0.0),Basis.looking_at(way.normalized(),Vector3.UP),Vector3(0.035,0.025,way.length()*0.5+0.02),Builds.WOOD_DARK)
	for z: float in [-0.55,0.35,0.95]:
		Builds.box(st,Vector3(0.0,0.31,z),Basis.IDENTITY,Vector3(0.5 if z < 0.9 else 0.4,0.022,0.11),Builds.PLANK)
	for side: float in [-1.0,1.0]:
		var basis := Basis(Vector3.UP,side*0.06)*Basis(Vector3.RIGHT,0.05)
		Builds.box(st,Vector3(side*0.3,0.37,-0.1),basis,Vector3(0.022,0.022,1.05),Builds.WOOD)
		Builds.box(st,Vector3(side*0.3+side*0.04,0.39,-1.05),basis,Vector3(0.07,0.012,0.22),Builds.WOOD)
	# The lantern's pole at the stern, its hook toward the bow.
	Builds.prism(st,6,0.025,0.02,0.3,BOAT_LANTERN.y+0.42,Builds.WOOD_DARK,0.0,Vector3(0.0,0.0,BOAT_LANTERN.z+0.12))
	Builds.box(st,Vector3(0.0,BOAT_LANTERN.y+0.4,BOAT_LANTERN.z+0.06),Basis.IDENTITY,Vector3(0.015,0.015,0.07),Builds.WOOD_DARK)
	return Builds._end(st)

## A lily pad, a notched heptagon lying flat at y 0 (its notch toward +Z);
## `bloom` puts a flower on it.
static func lily(bloom: bool, pink := false) -> ArrayMesh:
	var st := Builds._begin()
	var sides := 7
	for k in range(sides):
		if k == 0: continue
		var a0 := TAU*(k-0.5)/sides
		var a1 := TAU*(k+0.5)/sides
		var tone: Color = PAD_GREENS[k % PAD_GREENS.size()]
		var rim := PAD*(0.92 if k % 2 == 0 else 1.0)
		_tri(st,tone,Vector3(0.0,0.012,0.0),Vector3(sin(a0)*rim,0.0,cos(a0)*rim),Vector3(sin(a1)*rim,0.0,cos(a1)*rim),Vector3.UP)
	if bloom:
		var petal := PETAL_PINK if pink else PETAL
		for k in range(6):
			var a := TAU*k/6.0
			var tip := Vector3(sin(a)*0.11,0.08,cos(a)*0.11)
			var l := Vector3(sin(a-0.5)*0.04,0.02,cos(a-0.5)*0.04)
			var r := Vector3(sin(a+0.5)*0.04,0.02,cos(a+0.5)*0.04)
			_tri(st,petal,l,tip,r,Vector3(sin(a),0.6,cos(a)))
			_tri(st,petal.darkened(0.12),l,r,tip,-Vector3(sin(a),0.6,cos(a)))
		Builds.prism(st,5,0.03,0.025,0.02,0.06,HEART,0.0)
	return Builds._end(st)

## A floating lantern: surface 0 the raft and the shade's frame (vertex
## colours), surface 1 the paper shade (for the paper's own material).
static func float_lantern() -> ArrayMesh:
	var st := Builds._begin()
	Builds.box(st,Vector3(0.0,0.02,0.0),Basis.IDENTITY,Vector3(RAFT,0.025,RAFT),Builds.WOOD)
	Builds.prism(st,6,SHADE.x+0.015,SHADE.x+0.015,0.045,0.06,Builds.WOOD_DARK,0.0)
	Builds.prism(st,6,0.03,0.0,0.06+SHADE.y,0.06+SHADE.y+0.05,Builds.WOOD_DARK,0.0)
	var mesh := Builds._end(st)
	var paper := Builds._begin()
	Builds.prism(paper,6,SHADE.x,SHADE.x*0.8,0.06,0.06+SHADE.y,PAPER,0.0)
	paper.generate_normals()
	paper.commit(mesh)
	return mesh

## The glow's middle in a floating lantern (its frame).
static func float_glow() -> Vector3:
	return Vector3(0.0,0.06+SHADE.y*0.5,0.0)

## One flat face of `colour`, wound to face `out`.
static func _tri(st: SurfaceTool, colour: Color, a: Vector3, b: Vector3, c: Vector3, out: Vector3) -> void:
	if (b-a).cross(c-a).dot(out) > 0.0:
		var swap := b
		b = c
		c = swap
	Builds._tri(st,Transform3D.IDENTITY,colour.srgb_to_linear(),a,b,c)

static func _quad(st: SurfaceTool, colour: Color, a: Vector3, b: Vector3, c: Vector3, d: Vector3, out: Vector3) -> void:
	_tri(st,colour,a,b,c,out)
	_tri(st,colour,a,c,d,out)
