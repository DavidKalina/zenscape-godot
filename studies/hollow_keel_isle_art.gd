extends RefCounted
## The Hollow Keel's art (docs/scenic/hollow-keel.md; scripts/kit_isle/
## motif_hollow_keel.gd): a medium isle that looks modest from above, a plate
## of turf with a broken chapel on it, and hides a vaulted undercroft in its
## underside: the colossus hall (scripts/ruin_kit_hall.gd) hung under the
## plate, ten bays long, its two mouths open and its side walls breached, so
## the plane flies in under the isle's edge, weaves the aisles between the
## colossus columns and out under the other. A shaft in the chapel's floor
## drops to the hall's open bays, three of the kit's grand stairs switching
## back down it to the floor; the hall's end comes out on a stone porch in
## the keel with a rope bridge to a small hanging islet. Rock crags hang from
## the plate's underside either side of the hall, and the hull of the keel
## under its floor.
##
## Everything in the isle's own frame (y up): the hall runs along x, centred
## on MID, its floor YF, its roof top SOFFIT under the plate. The plate's
## turf is at TOP; the shaft is a hole in it over the hall's open bays.
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Hall = preload("res://scripts/ruin_kit_hall.gd")
const Footbridge = preload("res://scripts/footbridge.gd")
const Art = preload("res://studies/aqueduct_isle_art.gd")

const TOP := 30.0
## The isle's middle (x, z), the hall's.
const MID := Vector2(80.0,-15.0)
const BAYS := 10
const LENGTH := Hall.BAY*BAYS
## The hall's first mouth (world x); it runs along +x.
const HALL_X := MID.x-LENGTH*0.5
## A grand stair's rise (its two flights): three switch back from the turf
## down to the hall's floor.
const FLIGHT := 2.0*RuinKit.GRAND_STEPS*RuinKit.GRAND_RISER
const YF := TOP-3.0*FLIGHT
## The plate's underside, just over the hall's roof slabs.
const SOFFIT := YF+Hall.ROOF_TOP+0.15
const HALL_SEED := 41
const WEATHERED := 0.55
const SEED := 43
## The hall's bays open to the sky of the shaft (their roofs gone).
const SHAFT_BAYS := [3,4,5]
## The stairs: their middles along the hall (x from its mouth), the first
## and last climbing north, the second south, each a grand stair; their
## shared z offset from MID.
const STAIR_XS := [28.0,33.5,39.0]
const STAIR_Z := -2.3
## The grand stair's cheeks stand this far over its landing (a bit over the
## cheek and its coping).
const CURB := 0.55
## The shaft in the plate (x, z, world): flush with the first stair's head
## on the north and over its foot on the south.
const SHAFT := Rect2(HALL_X+25.0,MID.y-8.5,17.4,14.0)
## The plate: the outline's half axes and its squareness.
const PLATE_A := 47.0
const PLATE_B := 40.0
const PLATE_P := 3.2
## The hull under the hall's floor, its half length and half width.
const HULL := Vector2(45.5,16.5)
## The hanging islet (x, z, radius, top) off the east porch and the rope
## bridge's ends.
const ISLET := Vector4(MID.x+72.0,MID.y+4.0,8.0,YF-1.1)
const WORN := 0.45

static var _noise: FastNoiseLite

static func warm() -> void:
	noise()

static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = SEED
		_noise.frequency = 0.045
	return _noise

# --- The plate -----------------------------------------------------------------------

## The chapel's flat floor (x, z): the shaft and what stands round it.
static func chapel_rect() -> Rect2:
	return Rect2(HALL_X+13.0,MID.y-16.0,43.0,34.0)

static func outline() -> Array:
	var out: Array = []
	for k in range(72):
		var a := TAU*k/72.0
		var c := cos(a)
		var s := sin(a)
		var r := pow(pow(absf(c)/PLATE_A,PLATE_P)+pow(absf(s)/PLATE_B,PLATE_P),-1.0/PLATE_P)
		out.append(MID+Vector2(c,s)*r)
	return out

## The turf's height: flat round the chapel and the shaft, a gentle swell
## elsewhere (never under TOP: the hall's parapets stand to just under it).
static func ground(x: float, z: float) -> float:
	var r := chapel_rect()
	var d := maxf(maxf(r.position.x-x,x-r.end.x),maxf(r.position.y-z,z-r.end.y))
	var n := noise().get_noise_2d(x,z)*0.5+0.5
	return TOP+0.7*n*smoothstep(0.0,9.0,d)

## The worn way from the chapel's arch to the shaft's head.
static func paths() -> Array:
	return [[Vector2(stair_x(0),SHAFT.position.y-9.0),Vector2(stair_x(0),SHAFT.position.y+0.5)]]

static func path_wear(p: Vector2) -> float:
	return KitLand.wear_of(paths(),1.6).call(p)

## The plate: its turf with the shaft cut through (a hole in the ground
## mesh, the cut faces its walls), its skirt and soffit in rock, collided.
## Meta "outline", "shaft".
static func plate(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var ring := KitLand.resample(outline(),96,rng)
	var g := KitLand.Gather.new(ring,ground)
	var pad := SHAFT.grow(0.9)
	g.grid(1.7,rng,ground,[pad],false,false)
	# The shaft's edge: a row on it and rows either side, so the hole is crisp.
	for grow_by in [0.0,0.7,1.5]:
		var r := SHAFT.grow(grow_by)
		for p in _perimeter(r,0.8 if grow_by == 0.0 else 1.1):
			if grow_by == 0.0 or not SHAFT.has_point(p): _add_point(g,p)
	var poly := g.poly
	var tone := KitLook.turf(seed_value,wear_fn())
	var tris := Geometry2D.triangulate_delaunay(g.points)
	var ground_mesh := KitLook.GroundMesh.new()
	var faces := PackedVector3Array()
	for t in range(0,tris.size(),3):
		var a := g.points[tris[t]]
		var b := g.points[tris[t+1]]
		var c := g.points[tris[t+2]]
		var mid := (a+b+c)/3.0
		if not Geometry2D.is_point_in_polygon(mid,poly) or SHAFT.has_point(mid): continue
		var pa := Vector3(a.x,g.heights[tris[t]],a.y)
		var pb := Vector3(b.x,g.heights[tris[t+1]],b.y)
		var pc := Vector3(c.x,g.heights[tris[t+2]],c.y)
		faces.append_array([pa,pb,pc])
		ground_mesh.add(pa,pb,pc,tone.call(mid,Vector3.UP,rng.randf_range(-0.035,0.035),(pa.y+pb.y+pc.y)/3.0))
	var node := Node3D.new()
	node.name = "Plate"
	KitLand.draw(node,{"ground":ground_mesh,"rock":KitLook.RockMesh.new()})
	KitLand.bodies(node,faces,[],true)
	node.set_meta("outline",poly)
	node.set_meta("shaft",SHAFT)
	var rock := KitLook.RockMesh.new()
	var under := _skirt(rock,ring,rng)
	_soffit(rock,under)
	_underside(rock,under,rng)
	_jambs(rock)
	_solid_rock(node,"Sides",rock)
	return node

static func wear_fn() -> Callable:
	return func(p: Vector2) -> float: return path_wear(p)

static func _add_point(g: KitLand.Gather, p: Vector2) -> void:
	if not Geometry2D.is_point_in_polygon(p,g.poly) or KitLand.edge_distance(p,g.poly) < 0.5: return
	g.points.append(p)
	g.heights.append(ground(p.x,p.y))

## Points round `r`'s edge, `step` apart.
static func _perimeter(r: Rect2, step: float) -> Array[Vector2]:
	var out: Array[Vector2] = []
	var corners := [r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i+1)%4]
		var n := maxi(1,int(ceil(a.distance_to(b)/step)))
		for k in range(n): out.append(a.lerp(b,float(k)/n))
	return out

## The skirt: the turf's lip, the earth, down to the soffit's level.
static func _skirt(rock: KitLook.RockMesh, ring: Array[Vector2], rng: RandomNumberGenerator) -> PackedVector2Array:
	var count := ring.size()
	var out := KitLand.outward(ring)
	var centre := KitLand.centre_of(ring)
	var a: Array[Vector3] = []
	var b: Array[Vector3] = []
	var c: Array[Vector3] = []
	for i in range(count):
		var p: Vector2 = ring[i]
		var h := ground(p.x,p.y)-0.02
		a.append(Vector3(p.x,h,p.y))
		var pb := p+out[i]*rng.randf_range(0.15,0.5)
		b.append(Vector3(pb.x,h-rng.randf_range(0.4,0.7),pb.y))
		var pc := p.lerp(centre,0.012)+out[i]*rng.randf_range(0.0,0.3)
		c.append(Vector3(pc.x,SOFFIT,pc.y))
	for i in range(count):
		var j := (i+1)%count
		for pair: Array in [[a,b],[b,c]]:
			var u: Array[Vector3] = pair[0]
			var l: Array[Vector3] = pair[1]
			var m1 := (u[i]+u[j]+l[i])/3.0
			rock.add([u[i],l[i],u[j]],TOP,Vector3(m1.x-centre.x,0.0,m1.z-centre.y),rng.randf_range(0.9,1.1))
			var m2 := (u[j]+l[i]+l[j])/3.0
			rock.add([u[j],l[i],l[j]],TOP,Vector3(m2.x-centre.x,0.0,m2.z-centre.y),rng.randf_range(0.9,1.1))
	var under := PackedVector2Array()
	for p: Vector3 in c: under.append(Vector2(p.x,p.z))
	return under

## The underside of the plate over the hall (the band `BAND` either side of
## its walls, the whole length), level, in four pieces round the shaft.
static func _soffit(rock: KitLook.RockMesh, under: PackedVector2Array) -> void:
	var big := 1000.0
	var s := SHAFT
	var lo := MID.y-BAND
	var hi := MID.y+BAND
	var pieces: Array[Rect2] = [
		Rect2(-big,lo,2.0*big,s.position.y-lo),
		Rect2(-big,s.end.y,2.0*big,hi-s.end.y),
		Rect2(-big,s.position.y,big+s.position.x,s.size.y),
		Rect2(s.end.x,s.position.y,big,s.size.y)]
	for r in pieces:
		var box := PackedVector2Array([r.position,Vector2(r.end.x,r.position.y),r.end,Vector2(r.position.x,r.end.y)])
		for poly in Geometry2D.intersect_polygons(under,box):
			var idx := Geometry2D.triangulate_polygon(poly)
			for t in range(0,idx.size(),3):
				var p0: Vector2 = poly[idx[t]]
				var p1: Vector2 = poly[idx[t+1]]
				var p2: Vector2 = poly[idx[t+2]]
				rock.add([Vector3(p0.x,SOFFIT,p0.y),Vector3(p1.x,SOFFIT,p1.y),Vector3(p2.x,SOFFIT,p2.y)],TOP,Vector3.DOWN,1.0)

# --- The keel: the plate's hanging rock either side of the hall ----------------------------
#
# Off the band over the hall, the plate's underside hangs as the islets'
# keels do: one faceted face under each point of a jittered grid, deeper
# toward the middle of each side, in ridges and spurs, tapering back up to
# the skirt at the rim and up to the band at the hall in a steep inner face
# (a gallery along the walls). Over each flyable breach a gully stays
# shallow, so the plane that leaves the hall by it is clear to the sky.

## The band (m either side of MID) over the hall that stays level.
static var BAND: float = Hall.WALL_Z+1.0
## The gallery along the walls (m past the band) before the inner face
## drops, and the run it drops over.
const GALLERY := 4.5
const INNER_RUN := 5.0
## How deep the keel hangs (m under the soffit): the least and the most a
## ridge reaches, how far in from the rim it reaches it.
const KEEL_DEPTH := Vector2(7.0,19.0)
const RIM_RUN := 9.0
## Over a breach: a gully this wide past its bay's half, this shallow.
const GULLY := Vector2(6.0,0.12)
## The spurs: [x from the hall's mouth, z from MID, radius, extra depth].
const SPURS := [[6.0,-24.0,3.5,7.0],[30.0,-27.0,4.0,9.0],[52.0,-23.0,3.0,6.0],[72.0,-26.0,3.5,8.0],
	[14.0,25.0,4.0,8.0],[44.0,27.0,3.5,10.0],[62.0,24.0,3.0,6.5],[86.0,20.0,3.0,5.0],[-6.0,-20.0,3.0,5.0]]

## The flyable breaches' bays (their middles, x from the mouth) on side
## `side` (0 the -z wall, 1 the +z).
static func breach_bays(side: int) -> Array[float]:
	var out: Array[float] = []
	var ps := plans()
	for i in range(BAYS):
		if Hall.BREACHES[ps[i].breach[side]] in ["low","arch","collapse"]: out.append(Hall.BAY*(i+0.5))
	return out

## How far the keel hangs under the soffit at (x, z), `edge` m in from the
## underside's rim.
static func keel_depth(p: Vector2, edge: float, bays: Array) -> float:
	var off := absf(p.y-MID.y)-BAND
	if off <= 0.0: return 0.0
	var inner := smoothstep(GALLERY,GALLERY+INNER_RUN,off)
	var rim := smoothstep(0.0,RIM_RUN,edge)
	var n := noise().get_noise_2d(p.x*0.8+311.0,p.y*1.6-97.0)*0.5+0.5
	var ridge := 1.0-absf(noise().get_noise_2d(p.x*0.35-50.0,p.y*0.9+120.0))
	var deep := lerpf(KEEL_DEPTH.x,KEEL_DEPTH.y,clampf(n*0.6+ridge*0.55-0.1,0.0,1.0))
	var x := p.x-HALL_X
	for spur: Array in SPURS:
		var d := Vector2(x,p.y-MID.y).distance_to(Vector2(float(spur[0]),float(spur[1])))
		deep += float(spur[3])*clampf(1.0-d/float(spur[2]),0.0,1.0)
	var gully := 1.0
	for bx: float in bays[0 if p.y < MID.y else 1]:
		gully = minf(gully,lerpf(GULLY.y,1.0,smoothstep(Hall.BAY*0.5,Hall.BAY*0.5+GULLY.x,absf(x-bx))))
	return deep*inner*rim*gully

## The keel hung under `under` (the skirt's foot), off the band.
static func _underside(rock: KitLook.RockMesh, under: PackedVector2Array, rng: RandomNumberGenerator) -> void:
	var bays := [breach_bays(0),breach_bays(1)]
	var pts := PackedVector2Array()
	for p: Vector2 in under: pts.append(p)
	# The band's edges, and a row on each gallery's edge, so the inner face
	# stands where it should.
	var box := Rect2(MID.x-60.0,MID.y-60.0,120.0,120.0)
	for edge_z: float in [-BAND,BAND,-(BAND+GALLERY),BAND+GALLERY]:
		var x := box.position.x
		while x < box.end.x:
			var p := Vector2(x,MID.y+edge_z)
			if Geometry2D.is_point_in_polygon(p,under): pts.append(p)
			x += 2.6
	var cell := 3.2
	var gx := box.position.x
	while gx < box.end.x:
		var gz := box.position.y
		while gz < box.end.y:
			var p := Vector2(gx+rng.randf_range(-1.1,1.1),gz+rng.randf_range(-1.1,1.1))
			if absf(p.y-MID.y) > BAND+0.6 and Geometry2D.is_point_in_polygon(p,under) and KitLand.edge_distance(p,under) > 1.2: pts.append(p)
			gz += cell
		gx += cell
	var ys := PackedFloat32Array()
	for p: Vector2 in pts:
		var edge := KitLand.edge_distance(p,under)
		var on_rim := edge < 0.05
		ys.append(SOFFIT if on_rim else SOFFIT-keel_depth(p,edge,bays)*rng.randf_range(0.92,1.08))
	var tris := Geometry2D.triangulate_delaunay(pts)
	for t in range(0,tris.size(),3):
		var a := pts[tris[t]]
		var b := pts[tris[t+1]]
		var c := pts[tris[t+2]]
		var mid := (a+b+c)/3.0
		if absf(mid.y-MID.y) < BAND or not Geometry2D.is_point_in_polygon(mid,under): continue
		rock.add([Vector3(a.x,ys[tris[t]],a.y),Vector3(b.x,ys[tris[t+1]],b.y),Vector3(c.x,ys[tris[t+2]],c.y)],TOP,Vector3.DOWN,rng.randf_range(0.88,1.1))

## The shaft's cut faces: the plate's earth and rock showing round it.
static func _jambs(rock: KitLook.RockMesh) -> void:
	var centre := SHAFT.get_center()
	var pts := _perimeter(SHAFT,1.6)
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i+1)%pts.size()]
		var in_by := Vector3(centre.x-p.x,0.0,centre.y-p.y)
		var a := Vector3(p.x,TOP-0.02,p.y)
		var b := Vector3(q.x,TOP-0.02,q.y)
		rock.add([a,Vector3(p.x,SOFFIT,p.y),b],TOP,in_by)
		rock.add([b,Vector3(p.x,SOFFIT,p.y),Vector3(q.x,SOFFIT,q.y)],TOP,in_by)

static func _solid_rock(node: Node3D, label: String, rock: KitLook.RockMesh) -> void:
	var m: MeshInstance3D = rock.node(label)
	if m == null: return
	node.add_child(m)
	var body := StaticBody3D.new()
	body.name = label+"Body"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(rock.faces())
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)

# --- The hull under the floor ------------------------------------------------------------

## A hanging mass: `ring` (x, z) at height `y`, rings tapering in and down to
## a keel `depth` under, faceted (pushed in and out by `rng`), its colours by
## depth under `rim`. With `rough`, as the islets' keels hang: each column
## round it its own drop (ridges and gullies down the taper, a spur here and
## there), the rings drawn in unevenly, the keel's point off the middle.
static func cone(rock: KitLook.RockMesh, ring: Array, y: float, depth: float, rim: float, rng: RandomNumberGenerator, specs: Array = [], rough := false) -> void:
	if specs.is_empty(): specs = [[0.0,0.0],[0.22,0.3],[0.55,0.62],[0.85,0.88]]
	var centre := KitLand.centre_of(ring)
	var out := KitLand.outward(ring)
	var count := ring.size()
	var drops := PackedFloat32Array()
	var ins := PackedFloat32Array()
	for i in range(count):
		var wave := noise().get_noise_2d((ring[i] as Vector2).x*1.3+40.0,(ring[i] as Vector2).y*1.3-70.0)
		var spur := rng.randf_range(0.18,0.4) if rough and rng.randf() < 0.14 else 0.0
		drops.append(1.0+(wave*0.45+spur if rough else 0.0))
		ins.append(wave*0.12 if rough else 0.0)
	var rings: Array = []
	for spec: Array in specs:
		var r: Array[Vector3] = []
		var f := float(spec[1])
		for i in range(count):
			var inset := float(spec[0])
			if inset > 0.0: inset = clampf(inset+ins[i]*(1.0-inset)+rng.randf_range(-0.03,0.05),0.0,0.95)
			var p: Vector2 = (ring[i] as Vector2).lerp(centre,inset)
			var push := rng.randf_range(-0.12,0.2)*(0.0 if float(spec[0]) == 0.0 else 1.0)
			p += out[i]*push*(1.0+depth*0.1)
			var drop := f*drops[i]*rng.randf_range(0.9,1.1)
			r.append(Vector3(p.x,y-depth*minf(drop,0.97) if f > 0.0 else y,p.y))
		rings.append(r)
	var tip := Vector3(centre.x+rng.randf_range(-0.8,0.8),y-depth,centre.y+rng.randf_range(-0.8,0.8))
	if rough:
		var reach := (ring[0] as Vector2).distance_to(centre)
		tip = Vector3(centre.x+rng.randf_range(-0.25,0.25)*reach,y-depth*rng.randf_range(1.0,1.06),centre.y+rng.randf_range(-1.5,1.5))
	for k in range(rings.size()-1):
		var u: Array = rings[k]
		var l: Array = rings[k+1]
		for i in range(count):
			var j := (i+1)%count
			var m1: Vector3 = (u[i]+u[j]+l[i])/3.0
			rock.add([u[i],l[i],u[j]],rim,Vector3(m1.x-centre.x,-0.2,m1.z-centre.y),rng.randf_range(0.88,1.1))
			var m2: Vector3 = (u[j]+l[i]+l[j])/3.0
			rock.add([u[j],l[i],l[j]],rim,Vector3(m2.x-centre.x,-0.2,m2.z-centre.y),rng.randf_range(0.88,1.1))
	var last: Array = rings[rings.size()-1]
	for i in range(count):
		var j := (i+1)%count
		var m: Vector3 = (last[i]+last[j]+tip)/3.0
		rock.add([last[i],tip,last[j]],rim,Vector3(m.x-centre.x,-1.0,m.z-centre.y),rng.randf_range(0.88,1.1))

static func keel(seed_value: int) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var rock := KitLook.RockMesh.new()
	# The hull under the hall's floor: a boat's lines, long and narrow, its
	# porches beyond the mouths.
	var hull: Array = []
	var around := 40
	for s in range(around):
		var a := TAU*s/around
		var cs := cos(a)
		var sn := sin(a)
		var r := pow(pow(absf(cs)/HULL.x,4.0)+pow(absf(sn)/HULL.y,4.0),-0.25)
		hull.append(MID+Vector2(cs,sn)*r)
	var floor_y := YF-0.32
	cone(rock,hull,floor_y,15.0,YF+3.0,rng,[[0.0,0.0],[0.03,0.1],[0.2,0.3],[0.5,0.62],[0.8,0.9]],true)
	# Its top: the porches and the hall's floor under it, stone; the shelf
	# either side of the hall, outside its walls, turf like the plate.
	var big := 1000.0
	var keep_z := Hall.WALL_Z+0.8
	var mid_band := PackedVector2Array([Vector2(-big,MID.y-keep_z),Vector2(big,MID.y-keep_z),Vector2(big,MID.y+keep_z),Vector2(-big,MID.y+keep_z)])
	var tone := KitLook.turf(seed_value,Callable())
	for part: PackedVector2Array in Geometry2D.intersect_polygons(PackedVector2Array(hull),mid_band):
		var idx := Geometry2D.triangulate_polygon(part)
		for t in range(0,idx.size(),3):
			var tri: Array = []
			for q in range(3):
				var p: Vector2 = part[idx[t+q]]
				tri.append(Vector3(p.x,floor_y,p.y))
			rock.add(tri,YF+3.0,Vector3.UP,1.0)
	for part: PackedVector2Array in Geometry2D.clip_polygons(PackedVector2Array(hull),mid_band):
		var idx := Geometry2D.triangulate_polygon(part)
		for t in range(0,idx.size(),3):
			var tri: Array = []
			var mid := Vector2.ZERO
			for q in range(3):
				var p: Vector2 = part[idx[t+q]]
				tri.append(Vector3(p.x,floor_y,p.y))
				mid += p/3.0
			rock.add_toned(tri,tone.call(mid,Vector3.UP,rng.randf_range(-0.035,0.035),floor_y),Vector3.UP)
	var node := Node3D.new()
	node.name = "Keel"
	_solid_rock(node,"Keel",rock)
	return node

# --- The hall ------------------------------------------------------------------------------

## The hall's plans: the kit's (drawn from the seed), made into an undercroft:
## every roof whole but the shaft's open bays (so the plate stands on it),
## no gables or buttresses (the plate is on the roof), the shaft's bays
## cleared of inner columns, ties and screens for the stairs, flyable breaches
## on both sides.
static func plans() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([HALL_SEED,"hollow keel"])
	var ps: Array = Hall.plan(rng,WEATHERED,BAYS)
	for i in range(BAYS):
		var p: Dictionary = ps[i]
		p.roof = "whole"
		p.gaps = []
		p.gable = false
		p.last_gable = false
		p.buttress = ""
		p.right_buttress = false
		if i in SHAFT_BAYS:
			p.roof = "open"
			p.inner = []
			p.tie = ""
			p.screen = false
			p.fallen = false
			p.breach = Vector2i.ZERO
			p.beam = i == SHAFT_BAYS[0]
			p.architraves = Vector2.ZERO
	# Bay 6's line, the shaft's closing one: inner columns off it too.
	ps[SHAFT_BAYS[-1]+1].inner = []
	ps[SHAFT_BAYS[-1]+1].tie = ""
	ps[SHAFT_BAYS[-1]+1].screen = false
	# At least two flyable breaches a side, outside the shaft.
	for side in range(2):
		var have := 0
		for i in range(BAYS):
			if Hall.BREACHES[ps[i].breach[side]] in ["low","arch","collapse"]: have += 1
		var spots := [1,8,6,2] if side == 0 else [2,7,6,1]
		for i: int in spots:
			if have >= 2: break
			var p: Dictionary = ps[i]
			if Hall.BREACHES[p.breach[side]] != "": continue
			var v: Vector2i = p.breach
			v[side] = Hall.BREACHES.find("arch")
			p.breach = v
			p.fallen = false
			have += 1
	return ps

## The hall, at in-world detail, merged into one mesh and one body. In the
## hall's own frame (x along it, y 0 at the floor), placed by `hall_frame`.
## Meta "weave", "plans", "lane".
static func hall(seed_value: int) -> Node3D:
	var kept := RuinKit.Build.detail
	RuinKit.set_detail(Hall.IN_WORLD)
	var root := Node3D.new()
	root.name = "Hall"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"hollow keel bays"])
	var ps := plans()
	var weave := {"low_ties":[],"high_ties":[],"fallen":[],"gaps":[],"slits":[],"narrows":[],"breaches":[],"doors":[],"open":[]}
	for i in range(BAYS):
		var node: Node3D = Hall.bay(seed_value*31+i,clampf(WEATHERED+rng.randf_range(-0.12,0.12),0.0,1.0),ps[i],Callable(),null)
		node.name = "Bay%d" % i
		node.position.x = Hall.BAY*i
		root.add_child(node)
		var w: Dictionary = node.get_meta("weave")
		for key: String in weave:
			for item: Variant in w[key]: weave[key].append(Hall._moved(item,Vector3(Hall.BAY*i,0.0,0.0)))
	root.set_meta("weave",weave)
	root.set_meta("plans",ps)
	root.set_meta("lane",Hall._lane(0.0,LENGTH,Callable()))
	RuinKit.merge(root)
	RuinKit.set_detail(kept)
	return root

static func hall_frame() -> Transform3D:
	return Transform3D(Basis.IDENTITY,Vector3(HALL_X,YF,MID.y))

## The roots and ivy hanging over the mouths and the breaches' heads: a
## piece of its own (the ruin kit's free strands), in the hall's frame.
static func roots(seed_value: int) -> Node3D:
	var b := RuinKit.Build.new(seed_value,0.9,"Roots")
	var drape := Hall.ROOF_TOP-0.4
	for end_x: float in [-0.4,LENGTH+0.4]:
		for k in range(9):
			var z := lerpf(-11.0,11.0,float(k)/8.0)+b.rng.randf_range(-0.6,0.6)
			b.hang(Vector3(end_x,0.0,z),b.rng.randf_range(2.0,5.5),true,drape)
	var ps := plans()
	for i in range(BAYS):
		for side in range(2):
			var kind: String = Hall.BREACHES[ps[i].breach[side]]
			if kind in ["arch","door","collapse"]:
				var z := (Hall.WALL_Z+0.7)*(1.0 if side == 1 else -1.0)
				for k in range(4):
					b.hang(Vector3(Hall.BAY*i+Hall.BAY*0.5+b.rng.randf_range(-2.0,2.0),0.0,z),b.rng.randf_range(1.2,3.2),true,5.6)
	return b.finish()

# --- The stairs, the chapel -----------------------------------------------------------------

static func stair_x(k: int) -> float:
	return HALL_X+float(STAIR_XS[k])

## Stair `k`'s frame: its foot on the floor (the third), a flight higher (the
## second), two (the first); the middle one climbs south.
static func stair_frame(k: int) -> Transform3D:
	var z := MID.y+STAIR_Z
	var yaw := PI if k == 1 else 0.0
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(stair_x(k),YF+float(2-k)*FLIGHT,z+(1.1 if k == 1 else 0.0)))

## How sheltered stair `k`'s faces are (Build `shelter`, the hall's): the
## shaft is a well in the plate, its sky small and far, so the stairs take a
## share of the hall's bounce, more the deeper they go.
static func stair_shelter(k: int) -> Callable:
	var amount: float = [0.75,0.9,1.0][k]
	return func(_p: Vector3, _n: Vector3) -> float: return amount

## The landing at the head of stair `k` (world): where the walker steps on.
static func stair_head(k: int) -> Vector3:
	return stair_frame(k)*_head_local()

## The turn between the second stair's foot and the third's head: a slab of
## stone laid across at the third's head level, its edge to the second's
## last tread (the stairs stand side by side, so this is the way across).
static func turn_slab(seed_value: int) -> Node3D:
	var b := RuinKit.Build.new(seed_value,0.35,"TurnLanding")
	b.shelter = stair_shelter(2)
	var a := stair_foot(1)
	var c := stair_head(2)
	var half := Vector3((c.x-a.x)*0.5+2.5,0.28,0.62)
	var at := Vector3((a.x+c.x)*0.5,c.y-half.y,c.z-0.1)
	b.solid(RuinKit._box(b,half),Transform3D(Basis.IDENTITY,at),RuinKit._stone(b,1.02))
	# The third stair's west cheek stands CURB over the slab: a ramp up over
	# it and a deck across (a plain stone wedge, so the whole way down walks
	# on the stick), the landing a step down beyond.
	var cheek_x := c.x-RuinKit.GRAND_WIDTH*0.5-RuinKit.CHEEK.x
	var run := 1.6
	var tilt := atan2(CURB,run)
	var slope := Vector3(run,CURB,0.0).length()
	var out := Vector3(-sin(tilt),cos(tilt),0.0)
	var mid := Vector3(cheek_x-run*0.5,c.y+CURB*0.5,a.z)-out*0.06
	b.solid(RuinKit._box(b,Vector3(slope*0.5,0.06,0.9),0.02),Transform3D(Basis(Vector3.BACK,tilt),mid),RuinKit._stone(b,1.04))
	var deck := Vector3((c.x-RuinKit.GRAND_WIDTH*0.5+0.3-cheek_x)*0.5+0.05,0.06,0.9)
	b.solid(RuinKit._box(b,deck,0.02),Transform3D(Basis.IDENTITY,Vector3(cheek_x+deck.x-0.05,c.y+CURB-0.06,a.z)),RuinKit._stone(b,1.04))
	return b.finish()

static func _head_local() -> Vector3:
	var run1 := (RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.GRAND_LANDING
	var run2 := (RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.LANDING
	var front := (run1+run2)*0.5
	return Vector3(0.0,2.0*RuinKit.GRAND_STEPS*RuinKit.GRAND_RISER,front-run1-run2+RuinKit.LANDING*0.5)

static func _foot_local() -> Vector3:
	var run1 := (RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.GRAND_LANDING
	var run2 := (RuinKit.GRAND_STEPS-1)*RuinKit.GRAND_TREAD+RuinKit.LANDING
	return Vector3(0.0,0.0,(run1+run2)*0.5+0.6)

static func stair_foot(k: int) -> Vector3:
	return stair_frame(k)*_foot_local()

## The chapel: [piece, seed, weathered, x, z, yaw in degrees], x from the
## hall's mouth, z from MID. A rose gable at the south with the shaft before
## it, lancet walls east and west, buttresses outside them, the arch the
## way in at the north, the fallen and the carved.
const CHAPEL := [
	["rose_gable",5,0.5,33.7,12.5,180],
	["lancet_wall",6,0.5,19.0,-2.0,90],["lancet_wall",7,0.6,19.0,6.0,90],["lancet_wall",8,0.45,47.5,-2.0,-90],["lancet_wall",9,0.6,47.5,6.0,-90],
	["buttress",10,0.5,17.0,-2.0,90],["buttress",11,0.5,17.0,6.0,90],["buttress",12,0.55,49.5,-2.0,-90],["buttress",13,0.5,49.5,6.0,-90],
	["arch",14,0.45,28.0,-12.0,0],
	["pier",15,0.8,41.0,-11.0,0],["pier",16,0.7,23.0,-11.5,0],["fallen_pier",17,0.6,38.0,-15.0,70],["tomb_chest",18,0.5,45.0,10.0,20],
	["wall",19,0.7,24.0,10.0,0],["wall",20,0.8,43.5,9.0,0],["floor",21,0.5,28.0,-10.4,0],
]

# --- The balcony, the islet, the rope bridge ---------------------------------------------------

## The rope bridge's ends (world): the porch's edge under the plate and the
## hanging islet's.
static func bridge_ends() -> Array:
	var a := Vector3(MID.x+LENGTH*0.5+4.0,YF-0.32,MID.y+3.0)
	var to := Vector2(ISLET.x,ISLET.y)
	var way := (to-Vector2(a.x,a.z)).normalized()
	var edge := to-way*(ISLET.z*0.78)
	return [[a,Vector3(edge.x,ISLET.w,edge.y)]]

static func islet(seed_value: int) -> Node3D:
	var c := Vector2(ISLET.x,ISLET.y)
	var top := ISLET.w
	var flat := func(_x: float, _z: float) -> float: return top
	var node := Art.island(Art.blob(c,ISLET.z,seed_value),11.0,seed_value,flat,top)
	node.name = "Islet"
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

static func anchors(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Anchors"
	var k := 0
	for ends: Array in bridge_ends():
		for e in range(2):
			var here: Vector3 = ends[e]
			var there: Vector3 = ends[1-e]
			var way := Vector3(there.x-here.x,0.0,there.z-here.z).normalized()
			var piece: Node3D = RuinKit.bridge_anchor(seed_value+k,WORN,Footbridge.WIDTH)
			piece.transform = Transform3D(Basis(way.cross(Vector3.UP).normalized()*-1.0,Vector3.UP,way),here)
			root.add_child(piece)
			k += 1
	return root

# --- The plane's lines, the walker's tokens ------------------------------------------------------

## The hall's lane (z from MID) the plane flies, its height over the floor.
const LANE_Z := 6.3
const LANE_Y := 2.4

## The first flyable breach on the right (+z) wall: its bay's middle.
static func right_breach() -> float:
	var ps := plans()
	for i in range(BAYS):
		if Hall.BREACHES[ps[i].breach[1]] in ["low","arch","collapse"]: return Hall.BAY*(i+0.5)
	return -1.0

## [line id, category, kind, points (the isle's frame)].
static func plane_tokens() -> Array:
	var lane := PackedVector3Array()
	for x in [-3.0,6.0,16.0,24.0,34.0,46.0,56.0,66.0,76.0,84.0]:
		lane.append(Vector3(HALL_X+x,YF+LANE_Y,MID.y+LANE_Z))
	var out: Array = [["hk:undercroft","air","thread",lane]]
	var bx := right_breach()
	if bx > 0.0:
		var side := PackedVector3Array([Vector3(HALL_X+bx,YF+LANE_Y+0.4,MID.y+LANE_Z),Vector3(HALL_X+bx,YF+3.2,MID.y+Hall.WALL_Z+0.2),Vector3(HALL_X+bx,YF+3.0,MID.y+Hall.WALL_Z+3.6)])
		out.append(["hk:breach","air","break",side])
	out.append(["hk:keel","under","keel",PackedVector3Array([Vector3(MID.x,YF-18.0,MID.y)])])
	return out

## The walker's tokens: {name, at, move}.
static func foot_spots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	out.append({"name":"chapel","at":Vector3(HALL_X+33.5,TOP+0.85,MID.y+9.0),"move":"Walk the chapel's floor to its rose gable and back"})
	var turn := stair_head(1)
	out.append({"name":"turn","at":turn+Vector3(0.0,0.85,0.0),"move":"Down the grand stair's first flights to the turn"})
	out.append({"name":"vault","at":Vector3(HALL_X+13.0,YF+0.85,MID.y-11.0),"move":"Down into the undercroft and along its north aisle"})
	out.append({"name":"aisle","at":Vector3(HALL_X+60.0,YF+0.85,MID.y+11.0),"move":"Along the hall to its south aisle between the columns"})
	out.append({"name":"porch","at":Vector3(MID.x+LENGTH*0.5+2.2,YF+0.85,MID.y-5.0),"move":"Out onto the porch in the keel"})
	out.append({"name":"islet","at":Vector3(ISLET.x,ISLET.w+0.85,ISLET.y),"move":"Over the rope bridge to the hanging islet"})
	return out
