extends RefCounted
## The Stair to the Clouds' art (studies/stair_clouds_isle.gd): a small
## round isle, the tallest in the sky: a stepped mesa of dark faceted rock
## under a low lawn, four broad terraces climbing round it as wedges, each a
## flight of the ruin kit's grand stair over the last, and a ceremonial
## stair of eight grand flights winding once round its outside from the
## lawn to the summit, a landing (pad) at each turn.
##
## The plan is a nonagon of nine sides round O (MX, MZ): the core inside it,
## the stair's strip (W wide) outside. Side i (1..8) carries leg i, one grand
## stair (RUN long, STEP = 4.48 m up) climbing along the side toward the
## next, in a cut let down into the strip (the strip at its head's height,
## the cut's floor at its foot's); side 9 is the entry (the lawn). A pad
## (flat at a leg's head height) joins each pair of legs at a vertex. The
## whole mesa is one terraced solid (scripts/kit_isle/terrace_rock.gd).
## Inside, the core's wedge for sides 1-2 is the first terrace (2 STEP), 3-4
## the second, 5-6 the third, 7-9 the summit (8 STEP, 35.84 m): each leg's
## head is flush with the terrace it hugs, a walk onto it from the pad.
##
## Everything is in the isle's own frame (y up, its lawn at TOP), the frame
## the other motifs share (the aqueduct isle's: its middle near (80, -10)).
## The sky's offset (scripts/kit_isle/motif_sky.gd) moves it.
##
## Off the summit's south rim a rope bridge reaches a detached pinnacle that
## hangs over the lawn; between the two the gap is the plane's slot.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Build = RuinKit.Build

const TOP := 30.0
## A grand stair's rise (its head over its foot): every leg climbs one.
const STEP := 2.0*RuinKit.STEPS*RuinKit.RISER
## A grand stair's run, foot to head.
const RUN := 2.0*(RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.GRAND_LANDING+RuinKit.LANDING
const SIDES := 9
const LEGS := 8
const SECTOR := TAU/9.0
## Where side 1 begins (the angle of vertex 0 round O, in (x, z)): the entry
## side (9) faces south.
const PHI0 := 1.91986
## The core's apothem, the strip's width and its stair's centre off the core.
const AC := 19.66
const W := 6.4
const MID := 3.2
## The plan's centre (the aqueduct isle's frame).
const O := Vector2(80.0,-10.0)
## The lawn: a disc off the entry side, flat at TOP.
const LAWN_AT := 7.0
const LAWN_R := 11.0
## The summit's height over TOP.
const SUMMIT := 8.0*STEP

## The pinnacle: off the entry side's wall (v, along its normal), its radius,
## its top over TOP and how far its rock hangs.
const PIN_V := 13.8
const PIN_R := 3.0
const PIN_TOP := SUMMIT-1.8
const PIN_DEPTH := 18.0
## The legs' weathering: 0 (at 0.2 a chipped slab or a rubble stone shows a
## back face the terrace check sees; dressing may raise it with a proof).
const WEATHERED := 0.0

# --- The plan ---------------------------------------------------------------------

## Side `s` (0..8)'s outward normal and tangent (the way up the stair), as
## world (x, z).
static func normal_of(s: int) -> Vector2:
	return Vector2.from_angle(PHI0+(float(s)+0.5)*SECTOR)

static func tangent_of(s: int) -> Vector2:
	var n := normal_of(s)
	return Vector2(-n.y,n.x)

## Side `s`'s point `u` along, `v` out of the core's face (world x, z).
static func side_at(s: int, u: float, v: float) -> Vector2:
	return O+normal_of(s)*(AC+v)+tangent_of(s)*u

## Vertex `i` (0..8)'s direction (unit, x z).
static func vertex_dir(i: int) -> Vector2:
	return Vector2.from_angle(PHI0+float(i)*SECTOR)

## A point at radius `r` round O along vertex `i`, turned `turn` rad.
static func vertex_at(i: int, r: float, turn := 0.0) -> Vector2:
	return O+Vector2.from_angle(PHI0+float(i)*SECTOR+turn)*r

## [side, u, v] of world (x, z).
static func locate(p: Vector2) -> Array:
	var d := p-O
	var a := fposmod(atan2(d.y,d.x)-PHI0,TAU)
	var s := mini(int(a/SECTOR),SIDES-1)
	return [s,d.dot(tangent_of(s)),d.dot(normal_of(s))-AC]

## The core's terrace over TOP for side `s`.
static func terrace(s: int, u := 0.0) -> float:
	# Where a flight meets the terrace below (the even vertices), that
	# terrace runs on a little way behind the pad, so the pad opens onto it.
	if s > 0 and s < LEGS and (s&1) == 0 and u < -RUN*0.5: return terrace(s-1)
	return STEP*2.0*float(mini((s>>1)+1,4))

## The spiral's centre line, foot of leg 1 to the summit pad (world x, z):
## the paths worn in the turf.
static func paths() -> Array:
	var way: Array = []
	for s in range(LEGS):
		way.append(side_at(s,-RUN*0.5,MID))
		way.append(side_at(s,RUN*0.5,MID))
	way.append(vertex_at(LEGS,AC+MID+3.0))
	# The lawn to the first foot.
	var entry: Array = [O+normal_of(SIDES-1)*(AC+LAWN_AT),side_at(0,-RUN*0.5-2.0,MID),side_at(0,-RUN*0.5,MID)]
	return [way,entry]

# --- The island ---------------------------------------------------------------------
#
# One closed solid of terraced rock (scripts/kit_isle/terrace_rock.gd): the
# lawn and the nonagon's foot at TOP, the core's wedges at their terraces,
# each side's strip at its leg's head height with the leg's cut let down
# into it to the foot (the grand stair stands in the cut, its cheeks on the
# cut's walls: no slot beside a flight), a pad at each turn at the height of
# the leg it joins. Its collision is the faces drawn.

## The core's corner `i` (on its face) and the strip's outer corner.
static func core_corner(i: int) -> Vector2:
	return O+vertex_dir(i)*(AC/cos(SECTOR*0.5))

static func rim_corner(i: int) -> Vector2:
	return O+vertex_dir(i)*((AC+W)/cos(SECTOR*0.5))

## Leg `s`'s foot: its first riser's middle (world, the low top's height).
static func leg_foot(s: int) -> Vector3:
	var p := side_at(s,-RUN*0.5,MID)
	return Vector3(p.x,TOP+STEP*float(s),p.y)

## How far a leg's cut runs on past its foot, over the pad it climbs from.
const MOUTH := 1.0
## The lawn's disc: its points.
const LAWN_POINTS := 40

static func lawn_centre() -> Vector2:
	return O+normal_of(SIDES-1)*(AC+LAWN_AT)

## The mesa's tiers (TerraceRock spec, world x, z; y).
static func tiers() -> Array:
	var h := RUN*0.5
	var out: Array = []
	# The foot: the nonagon out to the strip's edge, and the lawn's disc, at TOP.
	var foot: Array = []
	for i in range(SIDES): foot.append(rim_corner(i))
	out.append({"outline":foot,"y":TOP})
	var lawn: Array = []
	var lc := lawn_centre()
	for k in range(LAWN_POINTS): lawn.append(lc+Vector2.from_angle(TAU*float(k)/float(LAWN_POINTS))*LAWN_R)
	out.append({"outline":lawn,"y":TOP})
	# The core's wedges; on an even side past the first, the corner by its
	# pad stays at the terrace below, so the pad opens onto it.
	var back := AC*(1.0-h/(AC*tan(SECTOR*0.5)))
	for s in range(SIDES):
		var y := TOP+terrace(s)
		if s > 0 and s < LEGS and (s&1) == 0:
			var p := side_at(s,-h,-back)
			out.append({"outline":[O,p,side_at(s,-h,0.0),core_corner(s+1)],"y":y})
			out.append({"outline":[p,core_corner(s),side_at(s,-h,0.0)],"y":TOP+terrace(s-1)})
		else:
			out.append({"outline":[O,core_corner(s),core_corner(s+1)],"y":y})
	# Each leg's strip at its head, and the pads at the turns.
	for s in range(LEGS):
		out.append({"outline":[side_at(s,-h,0.0),side_at(s,h,0.0),side_at(s,h,W),side_at(s,-h,W)],"y":TOP+STEP*float(s+1)})
	for i in range(1,LEGS+1):
		out.append({"outline":[side_at(i-1,h,0.0),core_corner(i),side_at(i,-h,0.0),side_at(i,-h,W),rim_corner(i),side_at(i-1,h,W)],"y":TOP+STEP*float(i)})
	# The legs' cuts.
	for s in range(LEGS):
		out.append(TerraceRock.grand_stair_cut(leg_foot(s),tangent_of(s),MOUTH))
	return out

## The mesa: one terraced solid (meta outline, terrace_tops ...), its body
## the faces drawn, so the plane and the walker meet what they see.
static func mesa(seed_value: int) -> Node3D:
	var node := TerraceRock.build({"tiers":tiers(),"seed":seed_value,"depth":26.0,
		"tone":KitLook.turf(seed_value,KitLand.wear_of(paths()))})
	node.name = "Mesa"
	return node

# --- The stair --------------------------------------------------------------------

## Leg `s`'s frame (the kit's grand stair: its run centred, climbing toward
## -Z): along the side's tangent, on the strip's centre, its foot on the
## floor of its cut (TerraceRock.grand_stair_frame).
static func leg_frame(s: int) -> Transform3D:
	return TerraceRock.grand_stair_frame(leg_foot(s),tangent_of(s))

## A frame on side `s` at (u, v) at height `y` over TOP, its -Z toward the
## outer side of the mesa (+n) when `out`, else along the way up.
static func frame_at(s: int, u: float, v: float, y: float, yaw := 0.0) -> Transform3D:
	var n := normal_of(s)
	var basis := Basis(Vector3(n.y,0.0,-n.x),Vector3.UP,Vector3(n.x,0.0,n.y))*Basis(Vector3.UP,yaw)
	var p := side_at(s,u,v)
	return Transform3D(basis,Vector3(p.x,TOP+y,p.y))

## Where a pad's piece stands: along vertex `i` at radius `r`, turned `turn`
## rad round O (world), its z to face out when `yaw` 0.
static func pad_frame(i: int, r: float, turn: float, y: float, yaw := 0.0) -> Transform3D:
	var p := vertex_at(i,r,turn)
	var dir := (p-O).normalized()
	var basis := Basis(Vector3(dir.y,0.0,-dir.x),Vector3.UP,Vector3(dir.x,0.0,dir.y))*Basis(Vector3.UP,yaw)
	return Transform3D(basis,Vector3(p.x,TOP+y,p.y))

## The eight legs' stairs, the kit's grand stair a little ruined, each
## seated in its cut (TerraceRock.seat_grand_stair: weathered at most 0.24,
## its cheeks kept whole on the cut's walls).
static func stairs(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Stair"
	for s in range(LEGS):
		var stair := TerraceRock.seat_grand_stair(leg_foot(s),tangent_of(s),seed_value+s,WEATHERED)
		stair.name = "Leg%d" % (s+1)
		lit_under_wall(stair)
		root.add_child(stair)
	return root

# --- The stair's light -------------------------------------------------------------
#
# The stair climbs in the mesa's lee: in a low sun most of it stands in the
# wall's shadow, and the kit stone in shadow takes only the sky's hemisphere.
# The halls light their sheltered stone with a bounce (the stone shader's
# `shelter_fill`, the shelter carried in the vertex alpha: scripts/
# ruin_kit_hall.gd `_shelter`); here the wall over a face shelters it the
# same way, a little: the sunlit lawn, the cloud sea and the wall's lit
# faces bouncing back under it, so the treads read in shadow without
# lifting the stone in the sun much.

## The most shelter a face under the wall takes, and the wall over it (m)
## that gives it all.
const STAIR_SHELTER := 0.8
const SHELTER_WALL := 18.0

## How sheltered a face at world `p` is: the whole stair stands in the
## mesa's lee, more under a tall wall, less out past the strip.
static func wall_shelter(p: Vector3, _n: Vector3) -> float:
	var f := locate(Vector2(p.x,p.z))
	var s: int = f[0]
	var over := TOP+terrace(s)-p.y
	var near := 1.0-clampf((float(f[2])-W)/8.0,0.0,1.0)
	return STAIR_SHELTER*(0.6+0.4*clampf(over/SHELTER_WALL,0.0,1.0))*near

## The kit stone under `node` (its "Mesh"es, in `node`'s parent frame at
## `node.transform`) given its shelter (`wall_shelter`) in the vertex alpha.
static func lit_under_wall(node: Node3D) -> void:
	var stone: Material = RuinKit.materials().stone
	var stack: Array = [[node,node.transform]]
	while not stack.is_empty():
		var at: Array = stack.pop_back()
		var here: Node3D = at[0]
		var xf: Transform3D = at[1]
		for child in here.get_children():
			if child is Node3D: stack.append([child,xf*(child as Node3D).transform])
		var drawn := here as MeshInstance3D
		if drawn == null or not drawn.mesh is ArrayMesh or not drawn.mesh.has_meta("arrays"): continue
		var mesh := drawn.mesh as ArrayMesh
		if mesh.surface_get_material(0) != stone: continue
		var arrays: Array = (mesh.get_meta("arrays") as Array).duplicate()
		var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var c: PackedColorArray = (arrays[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
		for i in range(0,v.size(),3):
			var mid := xf*((v[i]+v[i+1]+v[i+2])/3.0)
			var open := 1.0-clampf(wall_shelter(mid,xf.basis*n[i]),0.0,1.0)
			for k in range(3): c[i+k].a = minf(c[i+k].a,open)
		arrays[Mesh.ARRAY_COLOR] = c
		var out := ArrayMesh.new()
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		out.surface_set_material(0,stone)
		out.set_meta("arrays",arrays)
		for i in range(1,mesh.get_surface_count()):
			var grown := RuinKit.RuinGrowth.arrays_of(mesh)
			if grown.is_empty(): break
			out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,grown,[],{},RuinKit.RuinGrowth.FORMAT)
			out.surface_set_material(out.get_surface_count()-1,mesh.surface_get_material(i))
			out.set_meta("growth_arrays",grown)
			break
		drawn.mesh = out

# --- The shrines ------------------------------------------------------------------------

## The pads' and terraces' pieces: [kind, place, ...]. A pad piece:
## ["pad", vertex i, radius, turn (deg), piece, weathered, yaw (deg)]; a
## terrace piece: ["ter", side s (its middle), radius from O, turn (deg),
## piece, weathered, yaw (deg), height over TOP].
const SHRINES := [
	["pad",1,26.0,-3.4,"pier",0.55,0.0],
	["pad",1,26.0,3.4,"pier",0.25,0.0],
	["pad",2,25.6,0.0,"tomb_chest",0.4,0.0],
	["pad",3,26.2,-3.0,"fallen_pier",0.5,35.0],
	["pad",5,26.0,-3.4,"pier",0.7,0.0],
	["pad",5,26.0,3.4,"pier",0.3,0.0],
	["pad",6,25.6,0.0,"tomb_chest",0.5,0.0],
	["pad",7,26.0,0.0,"tomb_chest",0.5,0.0],
	["ter",0,13.0,0.0,"tomb_chest",0.45,90.0,2.0*STEP],
	["ter",1,10.0,0.0,"floor",0.55,0.0,2.0*STEP],
	["ter",3,12.5,0.0,"arch",0.6,90.0,4.0*STEP],
	["ter",4,9.0,-14.0,"pier",0.55,0.0,6.0*STEP],
	["ter",5,9.0,14.0,"pier",0.35,0.0,6.0*STEP],
]

## The summit: the lone gate on the south rim, a broken turret and lancet
## walls behind it, floor slabs.
static func summit(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Summit"
	var y := SUMMIT
	var gate: Node3D = RuinKit.piece("arch",seed_value,0.4)
	gate.name = "Gate"
	gate.transform = frame_at(SIDES-1,0.0,-7.0,y)
	root.add_child(gate)
	var turret: Node3D = RuinKit.piece("turret",seed_value+1,0.65)
	turret.name = "Turret"
	var f := pad_frame(7,12.0,0.35,y)
	turret.transform = f
	root.add_child(turret)
	for k in range(2):
		var wall: Node3D = RuinKit.piece("lancet_wall",seed_value+2+k,0.5+0.2*float(k))
		wall.name = "Lancet%d" % k
		wall.transform = pad_frame(7,8.5+3.0*float(k),-0.5+0.5*float(k),y,PI)
		root.add_child(wall)
	var slabs: Node3D = RuinKit.piece("floor",seed_value+5,0.5)
	slabs.name = "Slabs"
	slabs.transform = frame_at(SIDES-1,0.0,-12.5,y)
	root.add_child(slabs)
	return root

## A shrine piece's frame (`SHRINES`' row).
static func shrine_frame(spec: Array) -> Transform3D:
	if spec[0] == "pad":
		return pad_frame(int(spec[1]),float(spec[2]),deg_to_rad(float(spec[3])),STEP*float(spec[1]),deg_to_rad(float(spec[6])))
	var s: int = spec[1]
	var p := O+Vector2.from_angle(PHI0+(float(s)+0.5)*SECTOR+deg_to_rad(float(spec[3])))*float(spec[2])
	var dir := (p-O).normalized()
	return Transform3D(Basis(Vector3(dir.y,0.0,-dir.x),Vector3.UP,Vector3(dir.x,0.0,dir.y))*Basis(Vector3.UP,deg_to_rad(float(spec[6]))),Vector3(p.x,TOP+float(spec[7]),p.y))

## The shrines on the pads and terraces.
static func shrines(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Shrines"
	var k := 0
	for spec: Array in SHRINES:
		var piece: Node3D = RuinKit.piece(str(spec[4]),seed_value+k,float(spec[5]))
		piece.name = "%s%d" % [str(spec[4]).capitalize(),k]
		piece.transform = shrine_frame(spec)
		if spec[0] == "pad": lit_under_wall(piece)
		root.add_child(piece)
		k += 1
	return root

# --- The pinnacle and its bridge ----------------------------------------------------------

static func pinnacle_at() -> Vector2:
	return side_at(SIDES-1,0.0,PIN_V)

## The detached pinnacle: a little hanging rock off the entry wall, over the
## lawn; its rock hangs PIN_DEPTH.
static func pinnacle(seed_value: int) -> Node3D:
	var c := pinnacle_at()
	var top := TOP+PIN_TOP
	var flat := func(_x: float, _z: float) -> float: return top
	var node := Art.island(Art.blob(c,PIN_R,seed_value),PIN_DEPTH,seed_value,flat,top)
	node.name = "Pinnacle"
	var hull := PackedVector3Array()
	for q: Vector2 in (node.get_meta("outline") as PackedVector2Array):
		hull.append(Vector3(q.x,top-0.01,q.y))
		hull.append(Vector3(c.x+(q.x-c.x)*0.7,top-2.2,c.y+(q.y-c.y)*0.7))
	var solid := ConvexPolygonShape3D.new()
	solid.points = hull
	var held := CollisionShape3D.new()
	held.shape = solid
	node.get_node("Body").add_child(held)
	return node

## The rope bridge's ends (world): the summit's south rim to the pinnacle's
## near edge.
static func bridge_ends() -> Array:
	var a := side_at(SIDES-1,0.0,-1.5)
	var b := side_at(SIDES-1,0.0,PIN_V-PIN_R+0.9)
	return [Vector3(a.x,TOP+SUMMIT,a.y),Vector3(b.x,TOP+PIN_TOP,b.y)]

static func anchors(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Anchors"
	var ends := bridge_ends()
	for e in range(2):
		var here: Vector3 = ends[e]
		var there: Vector3 = ends[1-e]
		var way := Vector3(there.x-here.x,0.0,there.z-here.z).normalized()
		var piece: Node3D = RuinKit.bridge_anchor(seed_value+e,0.3,Footbridge.WIDTH)
		piece.transform = Transform3D(Basis(way.cross(Vector3.UP).normalized()*-1.0,Vector3.UP,way),here)
		root.add_child(piece)
	return root

# --- The plane's lines ---------------------------------------------------------------------

## The tokens for the plane: [line id, category, kind, points (frame)]. The
## slot: in over the lawn, between the summit's wall and the pinnacle, under
## the bridge, and out past the wall; and the corkscrew: round the outside of
## the stair from its foot to over the summit, a landing at each turn.
static func plane_tokens() -> Array:
	var slot := PackedVector3Array()
	for spec: Array in SLOT:
		var p := side_at(SIDES-1,float(spec[0]),float(spec[1]))
		slot.append(Vector3(p.x,TOP+float(spec[2]),p.y))
	var corkscrew := PackedVector3Array()
	for i in range(1,LEGS+1):
		var p := vertex_at(i,CORK_R)
		corkscrew.append(Vector3(p.x,TOP+STEP*float(i)+CORK_UP,p.y))
	var over := vertex_at(LEGS,CORK_R-3.0,0.45)
	corkscrew.append(Vector3(over.x,TOP+SUMMIT+CORK_UP+3.0,over.y))
	return [["sc:slot","air","thread",slot],["sc:corkscrew","air","thread",corkscrew]]

## The slot's points: [u along the entry wall, v out of it, y over TOP].
## (The last out 1 m and 3 m off the wall: a token line keeps a THREAD's
## room from the rock, CollectibleLines WING.)
const SLOT := [[16.0,22.0,11.0],[8.0,9.0,17.0],[0.0,6.5,22.0],[-8.0,11.0,25.5]]
const CORK_R := 31.0
const CORK_UP := 3.0
