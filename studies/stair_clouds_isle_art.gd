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
## next, on a plinth at its foot's height; side 9 is the entry (the lawn). A
## pad (flat at a leg's head height) joins each pair of legs at a vertex.
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
const WEATHERED := 0.3

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

## The strip's height at `u` on side `s`: the leg's foot level under its
## stair; the pads at either end the foot of the next leg and the head of
## this one. On side 9 the lawn, with the summit's pad at its start end.
static func strip(s: int, u: float) -> float:
	if s < LEGS:
		if u > RUN*0.5: return STEP*float(s+1)
		return STEP*float(s)
	if u < -RUN*0.5: return STEP*8.0
	return 0.0

static func on_lawn(p: Vector2) -> bool:
	return p.distance_to(O+normal_of(SIDES-1)*(AC+LAWN_AT)) < LAWN_R

## The ground's height over TOP at world (x, z).
static func height(p: Vector2) -> float:
	var f := locate(p)
	var s: int = f[0]
	var v: float = f[2]
	if v < 0.0: return terrace(s,f[1])
	if v <= W: return strip(s,f[1])
	if on_lawn(p): return 0.0
	return strip(s,f[1])

static func ground(x: float, z: float) -> float:
	return TOP+height(Vector2(x,z))

## The plan's outline (world x, z): the nonagon a hair out of the strip,
## joined to the lawn's disc.
static func outline() -> Array:
	var ring: Array = []
	var lawn_c := O+normal_of(SIDES-1)*(AC+LAWN_AT)
	var k := 0
	while k < 180:
		var a := TAU*float(k)/180.0
		var dir := Vector2.from_angle(a)
		var s := mini(int(fposmod(a-PHI0,TAU)/SECTOR),SIDES-1)
		var r := (AC+W+0.4)/maxf(dir.dot(normal_of(s)),0.2)
		# The lawn's far side along this ray, if it crosses it.
		var to := lawn_c-O
		var along := to.dot(dir)
		var off := absf(to.cross(dir))
		if along > 0.0 and off < LAWN_R:
			r = maxf(r,along+sqrt(LAWN_R*LAWN_R-off*off)-0.3)
		ring.append(O+dir*r)
		k += 1
	return ring

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

const CLIFFS := Rect2(46.0,-50.0,68.0,86.0)

## The mesa: its ground over `height`, its steps cliffs, its sides hung from
## the rim (the plinths' faces and the summit's) down to a keel, collided so
## the plane meets them.
static func mesa(seed_value: int) -> Node3D:
	var spec := {"outline":outline(),"seed":seed_value,"ground":ground,
		"top":TOP,"depth":26.0,"cliffs":CLIFFS,"fine":1.3,"hang":true,"resample":[60.0,160,32],
		"tone":KitLook.turf(seed_value,KitLand.wear_of(paths()))}
	var node := KitLand.island(spec)
	node.name = "Mesa"
	var sides := node.get_node_or_null("Mesh") as MeshInstance3D
	if sides == null:
		for c in node.get_children():
			if c is MeshInstance3D and c.name != "Ground" and c.name != "Crags": sides = c
	if sides != null and sides.mesh != null:
		var body := StaticBody3D.new()
		body.name = "Sides"
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(sides.mesh.get_faces())
		shape.backface_collision = true
		var holder := CollisionShape3D.new()
		holder.shape = shape
		body.add_child(holder)
		node.add_child(body)
	dress_walls(node,sides,seed_value)
	return node

# --- The walls drawn ------------------------------------------------------------------
#
# The heightfield draws a sheer step as slivers (a point on its lip and one at
# its foot every half metre, a mid point between), and the hanging sides as
# rings a metre apart from the rim down to the rock: from the air both read
# as long thin dark streaks. Collided as built, they are drawn instead as the
# islets' faceted basalt: broad facets a few metres each way, every lattice
# point set back into the rock a little, painted by depth under their own
# rim (KitLook `RockMesh`). The collision is untouched.

## A facet's width along a wall and its height (m), and how far a lattice
## point sits back into the rock (m).
const FACET_W := Vector2(2.4,4.4)
const FACET_H := 4.6
const FACET_BACK := Vector2(0.05,0.75)
## A step shorter than this (m) is not a wall.
const WALL_MIN := 1.0
## The sides' facade: down to SIDE_FOOT under TOP, its foot drawn in toward
## the middle by SIDE_IN of the radius, over the rock rings below.
const SIDE_FOOT := 7.5
const SIDE_IN := 0.15
## Drawn sides faces wholly above this (m under TOP) give way to the facade.
const SIDE_CUT := 4.6

## The steps of `height` laid out as walls: [{line (world x z), top, foot
## (over TOP, a point each), into (unit (x z), toward the high side)}], found
## along every line the plan can step on (each side's core face and strip
## edge, each pad's ends, each vertex's ray, the lawn's rim).
static func wall_runs() -> Array:
	var lines: Array = []
	var reach := (AC+W+0.4)/cos(SECTOR*0.5)
	var half := (AC+W+0.4)*tan(SECTOR*0.5)+0.5
	for s in range(SIDES):
		var n := normal_of(s)
		var t := tangent_of(s)
		for v: float in [0.0,W]:
			lines.append([side_at(s,-half,v),side_at(s,half,v),n])
		for u: float in [-RUN*0.5,RUN*0.5]:
			lines.append([O+t*u,O+t*u+n*(AC+W+0.4),t])
	for i in range(SIDES):
		var d := vertex_dir(i)
		lines.append([O,O+d*reach,Vector2(-d.y,d.x)])
	var lawn_c := O+normal_of(SIDES-1)*(AC+LAWN_AT)
	var ring: Array = []
	for k in range(97): ring.append(lawn_c+Vector2.from_angle(TAU*k/96.0)*LAWN_R)
	for k in range(96):
		var mid: Vector2 = ((ring[k] as Vector2)+(ring[k+1] as Vector2))*0.5
		lines.append([ring[k],ring[k+1],(mid-lawn_c).normalized()])
	var poly := PackedVector2Array(outline())
	var runs: Array = []
	for line: Array in lines:
		var a: Vector2 = line[0]
		var b: Vector2 = line[1]
		var perp: Vector2 = line[2]
		var count := maxi(int(a.distance_to(b)/0.3),1)
		var run := {}
		for k in range(count+1):
			var p := a.lerp(b,float(k)/count)
			var h1 := height(p+perp*0.35)
			var h2 := height(p-perp*0.35)
			var inside := Geometry2D.is_point_in_polygon(p,poly) and KitLand.edge_distance(p,poly) > 0.3
			var wall := inside and absf(h1-h2) >= WALL_MIN
			var into := perp if h1 > h2 else -perp
			var top := maxf(h1,h2)
			var foot := minf(h1,h2)
			if not run.is_empty() and (not wall or absf(top-float(run.top[-1])) > 0.2 or absf(foot-float(run.foot[-1])) > 0.2 or into.dot(run.into) < 0.0):
				runs.append(run)
				run = {}
			if not wall: continue
			if run.is_empty(): run = {"line":[],"top":[],"foot":[],"into":into}
			run.line.append(p)
			run.top.append(top)
			run.foot.append(foot)
		if not run.is_empty(): runs.append(run)
	# Each a hair longer either end, so two meet at a corner (a lone point is
	# no wall).
	runs = runs.filter(func(run: Dictionary) -> bool: return (run.line as Array).size() >= 2)
	for run: Dictionary in runs:
		var pts: Array = run.line
		pts[0] = (pts[0] as Vector2)+((pts[0] as Vector2)-(pts[1] as Vector2)).normalized()*0.3
		pts[-1] = (pts[-1] as Vector2)+((pts[-1] as Vector2)-(pts[-2] as Vector2)).normalized()*0.3
	return runs

## A faceted wall into `rock` along `line` (world x z, in order), from
## `top` (world y, a point each) down to `foot`, its rock toward `into` (a
## unit (x z) each): a lattice of facets about FACET_W wide and FACET_H
## tall, its rows slanting a little, each inner point set back into the rock
## FACET_BACK, its ends and lip flush; its foot kicked out `kick` m (over the
## turf's edge) or drawn toward `pull_to` by `pull` of the way.
static func facade(rock: KitLook.RockMesh, line: Array, top: PackedFloat32Array, foot: PackedFloat32Array, into: Array, rng: RandomNumberGenerator,
		kick := 0.0, pull_to := Vector2.ZERO, pull := 0.0, closed := false) -> void:
	# The columns: along the line by length, FACET_W apart (jittered).
	var lengths := PackedFloat32Array([0.0])
	for i in range(1,line.size()): lengths.append(lengths[i-1]+(line[i] as Vector2).distance_to(line[i-1]))
	if closed: lengths.append(lengths[-1]+(line[-1] as Vector2).distance_to(line[0]))
	var total := lengths[-1]
	if total < 0.05: return
	var cols := PackedFloat32Array([0.0])
	while true:
		var next := cols[-1]+rng.randf_range(FACET_W.x,FACET_W.y)
		if next > total-FACET_W.x*0.5: break
		cols.append(next)
	if not closed: cols.append(total)
	var tallest := 0.0
	for i in range(top.size()): tallest = maxf(tallest,top[i]-foot[i])
	var rows := maxi(ceili(tallest/FACET_H),1)
	var grid: Array = []
	var rims := PackedFloat32Array()
	# Each column's way into the rock (the faces turn out against it).
	var ins: Array[Vector2] = []
	for c in range(cols.size()):
		var d := cols[c]
		var seg := 0
		while seg < lengths.size()-2 and lengths[seg+1] < d: seg += 1
		var t := clampf((d-lengths[seg])/maxf(lengths[seg+1]-lengths[seg],0.0001),0.0,1.0)
		var j := (seg+1)%line.size()
		var p := (line[seg] as Vector2).lerp(line[j],t)
		var hi := lerpf(top[seg],top[j],t)
		var lo := lerpf(foot[seg],foot[j],t)
		var inw := ((into[seg] as Vector2).lerp(into[j],t)).normalized()
		var end := not closed and (c == 0 or c == cols.size()-1)
		var lean := 0.0 if end else rng.randf_range(0.0,0.3)
		var column: Array[Vector3] = []
		for r in range(rows+1):
			var f := float(r)/rows
			if r > 0 and r < rows: f = clampf(f+rng.randf_range(-0.38,0.38)/rows,0.0,1.0)
			var y := lerpf(hi,lo,f)
			var back := 0.0
			if r > 0 and not end: back = lean+rng.randf_range(FACET_BACK.x,FACET_BACK.y)
			var q := p+inw*back
			if r == rows:
				q = p-inw*kick if pull <= 0.0 else p.lerp(pull_to,pull)
				y -= 0.06
			if r == 0: y -= 0.02
			column.append(Vector3(q.x,y,q.y))
		grid.append(column)
		ins.append(inw)
		rims.append(hi)
	var span := grid.size() if closed else grid.size()-1
	for c in range(span):
		var a: Array = grid[c]
		var b: Array = grid[(c+1)%grid.size()]
		var rim := maxf(rims[c],rims[(c+1)%grid.size()])
		var out := Vector3(-ins[c].x,0.0,-ins[c].y)
		for r in range(rows):
			var a0: Vector3 = a[r]
			var a1: Vector3 = a[r+1]
			var b0: Vector3 = b[r]
			var b1: Vector3 = b[r+1]
			var jitter := rng.randf_range(0.9,1.1)
			if rng.randf() < 0.5:
				rock.add([a0,a1,b1],rim,out,jitter)
				rock.add([a0,b1,b0],rim,out,rng.randf_range(0.9,1.1))
			else:
				rock.add([a0,a1,b0],rim,out,jitter)
				rock.add([b0,a1,b1],rim,out,rng.randf_range(0.9,1.1))

## `mesh`'s faces (non-indexed, as KitLook draws them) but those `drop`
## (its three points -> bool) says go.
static func filtered(mesh: ArrayMesh, drop: Callable) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var kv := PackedVector3Array()
	var kn := PackedVector3Array()
	var kc := PackedColorArray()
	for i in range(0,v.size(),3):
		if bool(drop.call(v[i],v[i+1],v[i+2])): continue
		for k in range(3):
			kv.append(v[i+k])
			kn.append(n[i+k])
			kc.append(c[i+k])
	var out := ArrayMesh.new()
	if kv.is_empty(): return out
	var keep := []
	keep.resize(Mesh.ARRAY_MAX)
	keep[Mesh.ARRAY_VERTEX] = kv
	keep[Mesh.ARRAY_NORMAL] = kn
	keep[Mesh.ARRAY_COLOR] = kc
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,keep)
	out.surface_set_material(0,mesh.surface_get_material(0))
	return out

## The mesa's walls drawn as faceted basalt ("Walls"): the steps' slivers in
## "Crags" and the sides' upper rings in `sides` give way to it.
static func dress_walls(node: Node3D, sides: MeshInstance3D, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7+11
	var rock := KitLook.RockMesh.new()
	var runs := wall_runs()
	# Where the walls stand (a 1 m grid of their points), to clear the crags.
	var near := {}
	for run: Dictionary in runs:
		var tops := PackedFloat32Array()
		var foots := PackedFloat32Array()
		var intos: Array = []
		for i in range((run.line as Array).size()):
			tops.append(TOP+float(run.top[i]))
			foots.append(TOP+float(run.foot[i]))
			intos.append(run.into)
			var p: Vector2 = run.line[i]
			var key := Vector2i(floori(p.x),floori(p.y))
			var have: Array = near.get(key,[])
			have.append(Vector4(p.x,p.y,TOP+float(run.foot[i]),TOP+float(run.top[i])))
			near[key] = have
		facade(rock,run.line,tops,foots,intos,rng,0.85)
	var crags := node.get_node_or_null("Crags") as MeshInstance3D
	if crags != null:
		crags.mesh = filtered(crags.mesh,func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			var m := (a+b+c)/3.0
			var k := Vector2i(floori(m.x),floori(m.z))
			for dx in range(-1,2):
				for dz in range(-1,2):
					for w: Vector4 in near.get(k+Vector2i(dx,dz),[]):
						if Vector2(w.x,w.y).distance_to(Vector2(m.x,m.z)) < 1.0 and m.y > w.z-0.6 and m.y < w.w+0.6: return true
			return false)
	# The sides: a facade round the rim down past the earth to the rock rings.
	var ring: PackedVector2Array = node.get_meta("outline")
	var line: Array = []
	var tops := PackedFloat32Array()
	var foots := PackedFloat32Array()
	var intos: Array = []
	var outs := KitLand.outward(Array(ring))
	var centre := KitLand.centre_of(Array(ring))
	for i in range(ring.size()):
		line.append(ring[i])
		tops.append(ground(ring[i].x,ring[i].y))
		foots.append(TOP-SIDE_FOOT)
		intos.append(-outs[i])
	facade_closed_sides(rock,line,tops,foots,intos,rng,centre)
	if sides != null and sides.mesh != null:
		var cut := TOP-SIDE_CUT
		sides.mesh = filtered(sides.mesh,func(a: Vector3, b: Vector3, c: Vector3) -> bool:
			return maxf(a.y,maxf(b.y,c.y)) > cut)
	var drawn := rock.node("Walls")
	if drawn != null: node.add_child(drawn)

## The sides' facade round the closed outline: its foot drawn in toward
## `centre` by SIDE_IN of the way.
static func facade_closed_sides(rock: KitLook.RockMesh, line: Array, top: PackedFloat32Array, foot: PackedFloat32Array, into: Array, rng: RandomNumberGenerator, centre: Vector2) -> void:
	facade(rock,line,top,foot,into,rng,0.0,centre,SIDE_IN,true)

# --- The stair --------------------------------------------------------------------

## Leg `s`'s frame (the kit's grand stair: its run centred, climbing toward
## -Z): along the side's tangent, on the strip's centre at the foot's height.
static func leg_frame(s: int) -> Transform3D:
	var t := tangent_of(s)
	var at := side_at(s,0.0,MID)
	return Transform3D(Basis(Vector3(-t.y,0.0,t.x),Vector3.UP,Vector3(-t.x,0.0,-t.y)),Vector3(at.x,TOP+STEP*float(s),at.y))

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

## The eight legs' stairs, the kit's grand stair a little ruined.
static func stairs(seed_value: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Stair"
	for s in range(LEGS):
		var stair: Node3D = RuinKit.grand_stair(seed_value+s,WEATHERED)
		stair.name = "Leg%d" % (s+1)
		stair.transform = leg_frame(s)
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
const SLOT := [[16.0,22.0,11.0],[8.0,9.0,17.0],[0.0,6.5,22.0],[-9.0,8.0,25.5]]
const CORK_R := 31.0
const CORK_UP := 3.0
