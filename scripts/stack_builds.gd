extends RefCounted
## The hermit's stack's built things (scripts/cluster_stack.gd), made as the
## showcase's are (scripts/showcase_builds.gd): faceted boxes and prisms,
## one flat face a facet, vertex-coloured in the same earthy palette.
##   The plank stair: open treads a riser apart up each of its decks (the
##     pilot walks the deck's even slope, the treads never more than half a
##     riser off it), two stringers under them, a post and rail along the
##     outer side; the trestle legs down to the land under it and the struts
##     into the rock that hold it.
##   A box beehive: a stone slab, two painted boxes, a lid, the entrance.
## And the furnishing of a stack's member by the dresser (scripts/
## cluster_dresser.gd `furnish`): its stairs, the lanterns climbing them
## (the dresser's lantern posts, each with its halo and light), its hives.

const Builds = preload("res://scripts/showcase_builds.gd")

## A riser (m), a tread's depth on a level run (m), a tread's thickness.
const RISER := 0.19
const LEVEL_TREAD := 0.3
const TREAD := 0.05
## The rail's height and the posts' spacing (m).
const RAIL := 0.95
const POST_EVERY := 1.6
const HIVE_BODY := Color("e6dccb")
const HIVE_HONEY := Color("d9b56e")

static var _hive: ArrayMesh

## A stack stair's mesh (the from member's frame): see the head.
static func stair(st: Dictionary, seed: int) -> ArrayMesh:
	var surface := Builds._begin()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var points: Array = st.points
	var around: Vector2 = st.around
	var width := 1.0
	var since_post := POST_EVERY
	for i in range(points.size()-1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i+1]
		var flat := Vector3(b.x-a.x,0.0,b.z-a.z)
		var run := flat.length()
		if run < 0.01: continue
		var along := flat/run
		var across := along.cross(Vector3.UP).normalized()
		var mid := Vector2((a.x+b.x)*0.5,(a.z+b.z)*0.5)
		var outer := across if (mid-around).dot(Vector2(across.x,across.z)) > 0.0 else -across
		var rise := b.y-a.y
		var turn := Basis(across,Vector3.UP,-along)
		var steps := maxi(1,roundi(rise/RISER)) if rise > RISER*0.5 else maxi(1,roundi(run/LEVEL_TREAD))
		for k in range(steps):
			var t := (k+0.5)/steps
			var top := a.y+rise*t+0.02
			var at := Vector3(a.x,0.0,a.z)+flat*t+Vector3.UP*(top-TREAD)
			var yaw := Basis(Vector3.UP,rng.randf_range(-0.04,0.04))
			Builds.box(surface,at,turn*yaw,Vector3(width*0.5+rng.randf_range(-0.04,0.03),TREAD,run/steps*0.5+0.03),Builds.PLANK.darkened(rng.randf_range(0.0,0.18)))
		var slope := Basis.looking_at((b-a).normalized(),Vector3.UP)
		for side: float in [-1.0,1.0]:
			var middle := a.lerp(b,0.5)+across*side*(width*0.5-0.05)+Vector3.DOWN*0.13
			Builds.box(surface,middle,slope,Vector3(0.045,0.1,(b-a).length()*0.5+0.06),Builds.WOOD_DARK)
		# The rail along the outer side, a post every POST_EVERY.
		var rail_a := a+outer*(width*0.5-0.03)+Vector3.UP*RAIL
		var rail_b := b+outer*(width*0.5-0.03)+Vector3.UP*RAIL
		Builds.box(surface,(rail_a+rail_b)*0.5,Basis.looking_at((rail_b-rail_a).normalized(),Vector3.UP),Vector3(0.03,0.03,(rail_b-rail_a).length()*0.5+0.03),Builds.WOOD)
		since_post += run
		if since_post >= POST_EVERY or i == 0:
			since_post = 0.0
			var foot := a+outer*(width*0.5-0.03)
			Builds.box(surface,foot+Vector3.UP*(RAIL*0.5-0.1),Basis(Vector3.UP,rng.randf_range(-0.2,0.2)),Vector3(0.04,RAIL*0.5+0.1,0.04),Builds.WOOD_DARK)
	var last: Vector3 = points.back()
	var before: Vector3 = points[points.size()-2]
	var out_last := Vector3(last.x-before.x,0.0,last.z-before.z).normalized().cross(Vector3.UP)
	if (Vector2(last.x,last.z)-around).dot(Vector2(out_last.x,out_last.z)) < 0.0: out_last = -out_last
	Builds.box(surface,last+out_last*0.47+Vector3.UP*(RAIL*0.5-0.1),Basis.IDENTITY,Vector3(0.04,RAIL*0.5+0.1,0.04),Builds.WOOD_DARK)
	for leg: Dictionary in st.stilts:
		var top: Vector3 = leg.top
		var foot: Vector3 = leg.foot
		var h := top.y-foot.y
		if h < 0.05: continue
		Builds.box(surface,(top+foot)*0.5,Basis(Vector3.UP,rng.randf_range(0.0,0.6)),Vector3(0.055,h*0.5,0.055),Builds.WOOD_DARK)
		Builds.prism(surface,6,0.13,0.1,0.0,0.16,Builds.STONE_DARK,rng.randf(),foot)
	for strut: Dictionary in st.struts:
		var top: Vector3 = strut.top
		var foot: Vector3 = strut.foot
		var way := top-foot
		Builds.box(surface,(top+foot)*0.5,Basis.looking_at(way.normalized(),Vector3.UP if absf(way.normalized().y) < 0.95 else Vector3.RIGHT),Vector3(0.05,0.05,way.length()*0.5),Builds.WOOD_DARK)
	return Builds._end(surface)

## A box beehive, its foot at the origin, its entrance toward -Z.
static func hive() -> ArrayMesh:
	if _hive != null: return _hive
	var surface := Builds._begin()
	Builds.prism(surface,4,0.3,0.28,0.0,0.1,Builds.STONE,PI/4.0)
	Builds.box(surface,Vector3(0.0,0.24,0.0),Basis.IDENTITY,Vector3(0.21,0.14,0.21),HIVE_BODY)
	Builds.box(surface,Vector3(0.0,0.5,0.0),Basis.IDENTITY,Vector3(0.21,0.12,0.21),HIVE_HONEY)
	Builds.box(surface,Vector3(0.0,0.66,0.0),Basis.IDENTITY,Vector3(0.25,0.04,0.25),Builds.ROOF_DARK)
	Builds.box(surface,Vector3(0.0,0.73,0.0),Basis(Vector3.RIGHT,0.0),Vector3(0.17,0.03,0.17),Builds.ROOF)
	Builds.box(surface,Vector3(0.0,0.13,-0.21),Basis.IDENTITY,Vector3(0.12,0.02,0.01),Builds.WOOD_DARK)
	Builds.box(surface,Vector3(0.0,0.11,-0.25),Basis.IDENTITY,Vector3(0.14,0.01,0.05),Builds.PLANK)
	_hive = Builds._end(surface)
	return _hive

## The meshes for the stairs that start on `member` (safe on a worker).
static func prepare(member: Dictionary, plan: Dictionary) -> Array:
	var out: Array = []
	for st: Dictionary in plan.get("stairs",[]):
		if st.from == member.name: out.append(stair(st,hash(st.to) % 997))
	return out

## Stands `member`'s stairs, their lanterns and its hives under `node`;
## halos and lights go with the dresser's (`halos`, `live`).
static func furnish(node: Node3D, member: Dictionary, plan: Dictionary, made: Dictionary, halos: Array, live: Dictionary) -> void:
	var stairs: Array = made.get("stairs",[])
	var hives: Array = (member.features as Array).filter(func(f: Dictionary) -> bool: return f.type == "hive")
	if stairs.is_empty() and hives.is_empty(): return
	var dresser: GDScript = load("res://scripts/cluster_dresser.gd")
	var solid: Material = dresser._mats().solid
	for mesh: Mesh in stairs:
		var built := MeshInstance3D.new()
		built.name = "Stair"
		built.mesh = mesh
		built.material_override = solid
		node.add_child(built)
	for st: Dictionary in plan.get("stairs",[]):
		if st.from != member.name: continue
		for l: Dictionary in st.lanterns: dresser._post(node,l.at,float(l.angle),halos,live)
	for f: Dictionary in hives: dresser._stand(node,member.shape,"Hive",hive(),f.at,float(f.angle))
