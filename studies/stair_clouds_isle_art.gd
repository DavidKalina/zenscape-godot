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
	# The island's ring sides give way to the mesa's own skirt (`skirt`):
	# buttresses, corner crags and an irregular keel, drawn and collided
	# ("Sides") so the plane meets what it sees.
	var sides := node.get_node_or_null("Mesh") as MeshInstance3D
	if sides != null:
		node.remove_child(sides)
		sides.free()
	var faces := dress_walls(node,seed_value)
	var body := StaticBody3D.new()
	body.name = "Sides"
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var holder := CollisionShape3D.new()
	holder.shape = shape
	body.add_child(holder)
	node.add_child(body)
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
## A turf triangle on a drawn wall steeper than this (its normal's height)
## stops colliding (`_collide_as_drawn`): the drawn wall collides instead.
const WALL_STEEP := 0.6
## How far under a wall's lip and over its foot its heightfield collision
## stays (the walked edges).
const WALL_KEEP := 0.5
## A lip's or foot's cliff prism's depth under its face (m).
const WALL_PRISM := 0.4
## Only a wall at least this tall (m) has its lip's prisms hung shallow: a
## step walked along its edge (a landing's side) keeps them as built.
const LIP_WALL := 4.6
## The skirt (`skirt`): a column of rock every SKIRT_COL m round the rim,
## each down WALL_ROWS rows to WALL_BASE under TOP, then in KEEL_ROWS
## ([way in toward the middle, drop under TOP over KEEL]) to the keel's tip
## KEEL under TOP.
const SKIRT_COL := Vector2(2.4,4.0)
const WALL_ROWS := 7
const WALL_BASE := 3.0
const KEEL := 27.0
const KEEL_ROWS := [[0.16,0.13],[0.34,0.3],[0.52,0.48],[0.68,0.66],[0.83,0.83]]
## The mesa's tiers: heights over TOP where the rock steps out a ledge
## (TIER_OUT m) all round, and the batter: the wall leaning out BATTER m a
## metre under its lip, up to BATTER_MOST.
const TIERS := [8.0,19.0,28.0]
const TIER_OUT := Vector2(0.5,1.3)
## Bulges and hollows down a face, up to BULGE m out or in.
const BULGE := 1.6
const BATTER := 0.05
const BATTER_MOST := 1.8
## Buttresses stand out of the rim up to BUTTRESS m (a slow wander round
## it), the crags at the plan's corners CORNER m; both start this far
## under the lip, so the lip stays clean.
const BUTTRESS := 3.2
const CORNER := Vector2(2.6,4.4)
const BUTTRESS_UNDER := 1.4

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
## "Crags" give way to it; and its skirt round the rim, down to the keel.
## Returns the skirt's faces (to collide).
static func dress_walls(node: Node3D, seed_value: int) -> PackedVector3Array:
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
	var on_wall := func(m: Vector3) -> bool:
		var k := Vector2i(floori(m.x),floori(m.z))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for w: Vector4 in near.get(k+Vector2i(dx,dz),[]):
					if Vector2(w.x,w.y).distance_to(Vector2(m.x,m.z)) < 1.0 and m.y > w.z-0.6 and m.y < w.w+0.6: return true
		return false
	# A wall's face between its lip and its foot (low, high: a face's or a
	# prism's lowest and highest corner), WALL_KEEP clear of both: the
	# lip and the foot keep the heightfield's collision (what is walked).
	var in_face := func(low: float, high: float, m: Vector3) -> bool:
		var k := Vector2i(floori(m.x),floori(m.z))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for w: Vector4 in near.get(k+Vector2i(dx,dz),[]):
					if Vector2(w.x,w.y).distance_to(Vector2(m.x,m.z)) < 1.0 and low > w.z+WALL_KEEP and high < w.w-WALL_KEEP: return true
		return false
	var crags := node.get_node_or_null("Crags") as MeshInstance3D
	if crags != null:
		crags.mesh = filtered(crags.mesh,func(a: Vector3, b: Vector3, c: Vector3) -> bool: return bool(on_wall.call((a+b+c)/3.0)))
	var drawn := rock.node("Walls")
	if drawn != null: node.add_child(drawn)
	# The walls collide as drawn (set back into the rock, bulging), not as
	# the heightfield's sheer slivers and cliff prisms they replace: those
	# stood up to a metre and more proud of the drawn rock, invisible.
	var at_lip := func(high: float, m: Vector3) -> bool:
		var k := Vector2i(floori(m.x),floori(m.z))
		for dx in range(-1,2):
			for dz in range(-1,2):
				for w: Vector4 in near.get(k+Vector2i(dx,dz),[]):
					if Vector2(w.x,w.y).distance_to(Vector2(m.x,m.z)) < 1.0 and high > w.w-WALL_KEEP-0.3 and w.w-w.z > LIP_WALL: return true
		return false
	_collide_as_drawn(node,in_face,on_wall,at_lip)
	var wall_faces := rock.faces()
	var sides := KitLook.RockMesh.new()
	skirt(sides,Array(node.get_meta("outline") as PackedVector2Array),seed_value)
	corner_spur(sides,rng)
	for k in range(TORS.size()): tor(sides,TORS[k],rng)
	node.add_child(sides.node("Skirt"))
	var out := sides.faces()
	out.append_array(wall_faces)
	return out

## The island's ground bodies (KitLand `bodies`) as the walls are drawn:
## the turf's steep triangles in a wall's face (`in_face`: lowest and
## highest corner, middle; lip and foot kept, they are walked) left out,
## and the cliff prisms on a wall (`on_wall`) left out in its face and, at
## its lip (`at_lip`), hung only WALL_PRISM under their face (a ray started
## under the lip still finds its top; hung 1.5 m straight down from the
## lip one stood out of the set-back rock); at its foot, as built.
static func _collide_as_drawn(node: Node3D, in_face: Callable, on_wall: Callable, at_lip: Callable) -> void:
	var body := node.get_node("Body") as StaticBody3D
	var bodies: Array = [body]
	bodies.append_array(node.get_meta("cliff_bodies",[]))
	for holder in body.get_children():
		var shape := (holder as CollisionShape3D).shape
		if not shape is ConcavePolygonShape3D: continue
		var faces := (shape as ConcavePolygonShape3D).get_faces()
		var kept := PackedVector3Array()
		for t in range(0,faces.size(),3):
			var a := faces[t]
			var b := faces[t+1]
			var c := faces[t+2]
			var n := (b-a).cross(c-a).normalized()
			if absf(n.y) < WALL_STEEP and bool(in_face.call(minf(a.y,minf(b.y,c.y)),maxf(a.y,maxf(b.y,c.y)),(a+b+c)/3.0)): continue
			kept.append_array([a,b,c])
		(shape as ConcavePolygonShape3D).set_faces(kept)
	for into: StaticBody3D in bodies:
		for holder in into.get_children():
			var prism := (holder as CollisionShape3D).shape as ConvexPolygonShape3D
			if prism == null or prism.points.size() < 6: continue
			var pts := prism.points
			var mid := (pts[0]+pts[1]+pts[2])/3.0
			if not bool(on_wall.call(mid)): continue
			var low := minf(pts[0].y,minf(pts[1].y,pts[2].y))
			var high := maxf(pts[0].y,maxf(pts[1].y,pts[2].y))
			if bool(in_face.call(low,high,mid)):
				into.remove_child(holder)
				holder.free()
				continue
			# At its foot a prism hangs into the ground under it: as built.
			if not bool(at_lip.call(high,mid)): continue
			var deep := low-WALL_PRISM
			prism.points = PackedVector3Array([pts[0],pts[1],pts[2],Vector3(pts[0].x,deep,pts[0].z),Vector3(pts[1].x,deep,pts[1].z),Vector3(pts[2].x,deep,pts[2].z)])

# --- The summit's spur and tors -----------------------------------------------------------
#
# The summit's pad stands 6.4 m out of the summit's wall over the lawn, a
# sheer face 36 m tall: seen edge-on from the lawn, a thin dark column. A
# spur of rock fills the corner between the two, from just under the pad's
# lip down to the lawn, widening as it goes like a talus fan, so the pad
# reads as a buttress of the mesa. On the summit's two outer corners, tors
# of the same rock break its square top.

## The spur's reach on the lawn along the summit wall (u) and out along
## the pad's face (v), its top under the pad's lip, its rows.
const SPUR := Vector2(5.5,5.2)
const SPUR_UNDER := 1.6
const SPUR_ROWS := 7
## The tors: [vertex, radius from O, base radius, height].
const TORS := [[6,17.6,2.6,4.2],[0,17.8,2.3,3.4]]

static func corner_spur(rock: KitLook.RockMesh, rng: RandomNumberGenerator) -> void:
	var s := SIDES-1
	var u0 := -RUN*0.5
	var top := TOP+SUMMIT-SPUR_UNDER
	var low := TOP-0.4
	var arc := 6
	var grid: Array = []
	for r in range(SPUR_ROWS+1):
		var f := float(r)/SPUR_ROWS
		var g := pow(f,0.6)
		var y := lerpf(top,low,f)
		var row: Array[Vector3] = []
		for k in range(arc+1):
			var th := PI*0.5*float(k)/arc
			var j := 1.0 if r == 0 or k == 0 or k == arc else rng.randf_range(0.8,1.15)
			var uu := u0+0.05+cos(th)*SPUR.x*g*j
			var vv := 0.05+sin(th)*minf(SPUR.y,W-0.3)*g*j
			# Each end stays on its wall.
			if k == 0: vv = 0.05
			if k == arc: uu = u0+0.05
			var p := side_at(s,uu,vv)
			row.append(Vector3(p.x,y,p.y))
		grid.append(row)
	var corner := side_at(s,u0,0.0)
	for r in range(SPUR_ROWS):
		for k in range(arc):
			var a0: Vector3 = grid[r][k]
			var a1: Vector3 = grid[r][k+1]
			var b0: Vector3 = grid[r+1][k]
			var b1: Vector3 = grid[r+1][k+1]
			var m := (a0+a1+b0+b1)*0.25
			var toward := Vector3(m.x-corner.x,0.3,m.z-corner.y)
			rock.add([a0,b0,b1],top+SPUR_UNDER,toward,rng.randf_range(0.88,1.1))
			rock.add([a0,b1,a1],top+SPUR_UNDER,toward,rng.randf_range(0.88,1.1))

## A tor on the summit (`spec`: TORS' row): a faceted lump of the rock,
## rings narrowing up to a ridge, its foot sunk in the turf.
static func tor(rock: KitLook.RockMesh, spec: Array, rng: RandomNumberGenerator) -> void:
	var c := vertex_at(int(spec[0]),float(spec[1]))
	var base := TOP+SUMMIT-0.8
	var r0 := float(spec[2])
	var h := float(spec[3])
	var n := 7
	var rings: Array = []
	for level: Array in [[0.0,1.0],[0.45,0.8],[0.8,0.5]]:
		var ring: Array[Vector3] = []
		for i in range(n):
			var a := TAU*i/n+rng.randf_range(-0.2,0.2)
			var rr := r0*float(level[1])*rng.randf_range(0.8,1.15)
			var y := base+h*float(level[0])*rng.randf_range(0.85,1.1) if float(level[0]) > 0.0 else base
			ring.append(Vector3(c.x+cos(a)*rr,y,c.y+sin(a)*rr))
		rings.append(ring)
	var lean := Vector2.from_angle(rng.randf()*TAU)*r0*0.25
	var ridge: Array[Vector3] = [Vector3(c.x+lean.x-0.6,base+h,c.y+lean.y),Vector3(c.x+lean.x+0.5,base+h*0.9,c.y+lean.y+0.4)]
	var rim := base+h+3.0
	var centre := Vector3(c.x,base+h*0.4,c.y)
	for k in range(rings.size()-1):
		for i in range(n):
			var j := (i+1)%n
			var a0: Vector3 = rings[k][i]
			var a1: Vector3 = rings[k][j]
			var b0: Vector3 = rings[k+1][i]
			var b1: Vector3 = rings[k+1][j]
			rock.add([a0,b0,a1],rim,(a0+a1+b0)/3.0-centre,rng.randf_range(0.88,1.1))
			rock.add([a1,b0,b1],rim,(a1+b0+b1)/3.0-centre,rng.randf_range(0.88,1.1))
	var top_ring: Array = rings[rings.size()-1]
	for i in range(n):
		var j := (i+1)%n
		var a0: Vector3 = top_ring[i]
		var a1: Vector3 = top_ring[j]
		var q: Vector3 = ridge[0] if (a0-ridge[0]).length() < (a0-ridge[1]).length() else ridge[1]
		rock.add([a0,q,a1],rim,(a0+a1+q)/3.0-centre+Vector3.UP,rng.randf_range(0.88,1.1))
	rock.add([ridge[0],ridge[1],top_ring[0]],rim,Vector3.UP,1.0)

# --- The skirt ---------------------------------------------------------------------------
#
# The mesa's sides, round its rim: not a plain wall but the islets' hanging
# rock, a column of facets every few metres. The lip is flush with the turf
# (and a step where the rim steps); under it the rock stands out in
# buttresses that wander round the rim, sharper crags at the plan's corners,
# their tops lying back as ledges of talus, the bays between set in; under
# the lawn's level it all tapers in, unevenly, column by column, a spur
# hanging lower here and there, to a keel off the middle.

## How far a column's last wall point stands out of its rim point `p`.
static func o_last(column: Array[Vector3], p: Vector2, out: Vector2) -> float:
	var q: Vector3 = column[column.size()-1]
	return maxf((Vector2(q.x,q.z)-p).dot(out),0.0)

## Whether ring point `p` is at one of the nonagon's corners (not the lawn's).
static func at_corner(p: Vector2) -> bool:
	var d := p-O
	var a := fposmod(atan2(d.y,d.x)-PHI0,TAU)
	var off := absf(a-roundf(a/SECTOR)*SECTOR)
	return off*d.length() < 1.6 and not on_lawn(p)

## The skirt round `ring` (the island's outline, closed) into `rock`.
static func skirt(rock: KitLook.RockMesh, ring: Array, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*13+5
	var wander := FastNoiseLite.new()
	wander.seed = seed_value+211
	wander.frequency = 0.06
	var outs := KitLand.outward(ring)
	var centre := KitLand.centre_of(ring)
	var count := ring.size()
	var rims := PackedFloat32Array()
	for p: Vector2 in ring: rims.append(ground(p.x,p.y))
	# The columns: ring points every SKIRT_COL m or so, and both sides of
	# every step in the rim (so the lip steps where the turf does).
	var cols: Array[int] = []
	var since := 0.0
	var want := rng.randf_range(SKIRT_COL.x,SKIRT_COL.y)
	var corner_seen := {}
	for i in range(count):
		var j := (i+1)%count
		var take := i == 0 or since >= want
		var stepped := absf(rims[j]-rims[i]) > 0.3 or absf(rims[i]-rims[(i-1+count)%count]) > 0.3
		var corner := at_corner(ring[i])
		if corner:
			var k := roundi(fposmod(atan2((ring[i] as Vector2).y-O.y,(ring[i] as Vector2).x-O.x)-PHI0,TAU)/SECTOR)%SIDES
			if not corner_seen.has(k):
				corner_seen[k] = true
				take = true
		if take or stepped:
			cols.append(i)
			since = 0.0
			want = rng.randf_range(SKIRT_COL.x,SKIRT_COL.y)
		since += (ring[i] as Vector2).distance_to(ring[j])
	var tip := Vector3(centre.x+rng.randf_range(-3.0,3.0),TOP-KEEL,centre.y+rng.randf_range(-3.0,3.0))
	var lawn_c := O+normal_of(SIDES-1)*(AC+LAWN_AT)
	var bulge := FastNoiseLite.new()
	bulge.seed = seed_value+977
	bulge.frequency = 0.09
	var grid: Array = []
	var col_rims := PackedFloat32Array()
	var col_outs: Array[Vector2] = []
	var length := 0.0
	var last := 0
	for c in range(cols.size()):
		var i := cols[c]
		for k in range(last,i): length += (ring[k] as Vector2).distance_to(ring[(k+1)%count])
		last = i
		var p: Vector2 = ring[i]
		var out: Vector2 = outs[i]
		var rim := rims[i]
		var tall := rim-(TOP-WALL_BASE)
		# How far this column stands out: the wander, a corner's crag, a
		# column of its own now and then.
		var stand := maxf(wander.get_noise_1d(length)*1.6+0.15,0.0)*BUTTRESS
		if at_corner(p): stand = maxf(stand,rng.randf_range(CORNER.x,CORNER.y))
		elif rng.randf() < 0.18: stand += rng.randf_range(0.8,1.8)
		elif rng.randf() < 0.25: stand = -rng.randf_range(0.3,0.9)
		stand *= clampf(tall/12.0,0.35,1.0)
		# Where the rim looks over the lawn, it stands out little.
		if (p+out*4.0).distance_to(lawn_c) < LAWN_R+1.5: stand *= 0.2
		var column: Array[Vector3] = []
		column.append(Vector3(p.x,rim-0.02,p.y))
		var skin := p+out*rng.randf_range(0.15,0.35)
		column.append(Vector3(skin.x,rim-0.5,skin.y))
		var under := minf(BUTTRESS_UNDER,maxf(tall*0.2,0.6))
		var head := rim-0.5-under
		var foot := TOP-WALL_BASE
		# The rows: WALL_ROWS down the wall, and a pair at each tier that
		# stands in it (its ledge between), else two more down the wall.
		var ys: Array[float] = []
		var tiers: Array[float] = []
		var spare := 0
		for k in range(TIERS.size()):
			# A tier holds for a stretch of the rim, then breaks off; its
			# height wanders along it.
			var gate := wander.get_noise_1d(length*1.7+400.0*k)
			var at := TOP+float(TIERS[k])+wander.get_noise_1d(length*0.9-300.0*k)*3.0
			if gate > 0.05 and at < head-1.0 and at > foot+1.5:
				ys.append(at+0.15)
				ys.append(at-0.35)
				tiers.append(at)
			else: spare += 2
		var rows := WALL_ROWS+spare
		for r in range(1,rows+1):
			var f := float(r)/rows
			if r < rows: f = clampf(f+rng.randf_range(-0.3,0.3)/rows,0.02,0.98)
			ys.append(head if r == 1 else lerpf(head,foot,f))
		ys.sort()
		ys.reverse()
		var steps := PackedFloat32Array()
		for t in tiers: steps.append(rng.randf_range(TIER_OUT.x,TIER_OUT.y)*clampf(stand/BUTTRESS+0.6,0.6,1.3))
		var scale := clampf(tall/12.0,0.35,1.0)*(0.2 if (p+out*4.0).distance_to(lawn_c) < LAWN_R+1.5 else 1.0)
		for r in range(ys.size()):
			var y := ys[r]
			var f := clampf((head-y)/maxf(head-foot,0.1),0.0,1.0)
			# Out to the full stand within the wall's first rows, swelling a
			# little lower down, leaning out (the batter), stepping out at
			# each tier passed; each point set in or out its own bit.
			var o := stand*(0.75 if r == 0 else 1.0+0.15*sin(f*PI))+rng.randf_range(-0.4,0.3)
			# Bulges and hollows down the face (the islets' slumped walls).
			if r > 0: o += bulge.get_noise_2d(length,y*1.4)*BULGE*scale
			o += minf((rim-y)*BATTER,BATTER_MOST)*scale
			for t in range(tiers.size()):
				if y < tiers[t]-0.1: o += steps[t]*scale
			var q := p+out*o
			column.append(Vector3(q.x,y,q.y))
		var bottom := o_last(column,p,out)
		# The keel: in toward the middle, each column its own drop, a spur
		# hanging lower now and then.
		var drop := rng.randf_range(0.85,1.12)
		var spur := rng.randf_range(0.12,0.3) if rng.randf() < 0.16 else 0.0
		for spec: Array in KEEL_ROWS:
			var inset := clampf(float(spec[0])+rng.randf_range(-0.04,0.04),0.0,0.95)
			var f := float(spec[1])*drop+spur*float(spec[1])
			var q := p.lerp(centre,inset)+out*bottom*(1.0-inset)*0.8
			column.append(Vector3(q.x,minf(TOP-WALL_BASE-1.0,TOP-KEEL*minf(f,0.97)),q.y))
		grid.append(column)
		col_rims.append(rim)
		col_outs.append(out)
	for c in range(grid.size()):
		var d := (c+1)%grid.size()
		var a: Array = grid[c]
		var b: Array = grid[d]
		var out2 := (col_outs[c]+col_outs[d]).normalized()
		var rim := maxf(col_rims[c],col_rims[d])
		for r in range(a.size()-1):
			var a0: Vector3 = a[r]
			var a1: Vector3 = a[r+1]
			var b0: Vector3 = b[r]
			var b1: Vector3 = b[r+1]
			var down := 0.0 if r < WALL_ROWS+2*TIERS.size()+1 else 0.6
			var toward := Vector3(out2.x,-down,out2.y)
			if rng.randf() < 0.5:
				rock.add([a0,a1,b1],rim,toward,rng.randf_range(0.88,1.1))
				rock.add([a0,b1,b0],rim,toward,rng.randf_range(0.88,1.1))
			else:
				rock.add([a0,a1,b0],rim,toward,rng.randf_range(0.88,1.1))
				rock.add([b0,a1,b1],rim,toward,rng.randf_range(0.88,1.1))
		var la: Vector3 = a[a.size()-1]
		var lb: Vector3 = b[b.size()-1]
		rock.add([la,tip,lb],rim,Vector3(out2.x,-1.5,out2.y),rng.randf_range(0.88,1.1))

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
## (The last out 1 m and 3 m off the wall: a token line keeps a THREAD's
## room from the rock, CollectibleLines WING.)
const SLOT := [[16.0,22.0,11.0],[8.0,9.0,17.0],[0.0,6.5,22.0],[-8.0,11.0,25.5]]
const CORK_R := 31.0
const CORK_UP := 3.0
