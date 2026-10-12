extends "res://scripts/kit_isle/kit_motif.gd"
## The dragon's roost as a motif (scripts/kit_isle/kit_motif.gd; docs/design/
## dragon-roost/round2.md): a craggy, lopsided mountain on its own floating
## rock, the sky dragon's home. A strip of turf round its foot on the side
## facing the aqueduct isle; a massif of stepped crags out of it; halfway up,
## standing out to one side, a broad ledge, its floor a little hollowed and
## worn bare, scattered with bones, broken stone and a chest (its hoard): the
## nest. Behind the ledge a summit tower rises to a broken peak, with a lower
## spur beside it.
##
## The dragon (scripts/dragon_roost.gd) lies curled on the ledge like a cat on
## a shelf: chest at the ledge's inner side by the tower, the trunk and folded
## hind legs along the ledge's back, the tail round its outer rim and back
## along its front rim, curled round the hoard. From the chest the neck rises
## round the front of the tower (the side the aqueduct isle sees) on a shelf
## worn into the rock (`_groove`), and the head rests on that shelf on the
## tower's far flank, horns against the sky, under the peak. The line is laid
## here (`coil`) so the rock and the pose agree: the neck's shelf is cut (and
## carried) under it, and the body lies on the ledge's own floor.
##
## Everything is laid out in "layout metres" at the dragon's size 1.5 (SPAN
## scales it, so a bigger dragon gets a bigger mountain), in (u, v) about
## AXIS: v toward the aqueduct isle, u across (the ledge's side, the viewer's
## left from the aqueduct isle), heights over the turf (TOP).
##
## Its own frame is every motif's (the middle near the aqueduct isle's, its
## turf at 30 m); the aqueduct isle's sky stands it AT from there, out past
## the motif isles to the south-east and high, a landmark from the aqueduct
## isle (scripts/kit_isle/motif_sky.gd, with --dragon-roost). The ground
## (`ground`) is one height function, so the dragon's pose reads the same
## rock the isle is built of, without a physics query.
const SkyDragon = preload("res://scripts/sky_dragon.gd")

## Where it stands from its own frame (motif_sky.gd PLACES' way): its middle
## about world (610, 455), 710 m south-east of the aqueduct isle's (120 m
## clear of the hollow keel's reach, 250 m off the airships' loops), its turf
## 55 m over the aqueduct isle's.
const AT := Vector3(520.0,55.0,475.0)
const SEED := 97
const TOP := 30.0
## The dragon's size (the flying dragon's, sky_dragon.gd SIZE) and the
## mountain's scale with it (laid out for 1.5).
const DRAGON_SIZE: float = SkyDragon.SIZE
const SPAN: float = DRAGON_SIZE/1.5
## The summit's axis (own x, z) and the layout's frame: V toward the
## aqueduct isle, U across it.
const AXIS := Vector2(88.0,-2.0)
const V := Vector2(-0.728,-0.686)
const U := Vector2(0.686,-0.728)
## The outline: its middle (u, v) and radius (layout m).
const ISLE_C := Vector2(14.0,12.0)
const ISLE_R := 80.0
## The summit tower: its middle (u, v); its radius at the ledge's height
## (TOWER_BASE) narrowing to TOWER_SHOULDER at SHOULDER_H, then the peak to
## PEAK_H.
const TOWER_C := Vector2(-2.0,-3.0)
const TOWER_BASE := 20.0
const TOWER_SHOULDER := 15.0
const SHOULDER_H := 82.0
const PEAK_H := 100.0
## The ledge: its middle (u, v), radius, floor height; how much its floor
## dishes and its rim lifts.
const LEDGE_C := Vector2(40.0,0.0)
const LEDGE_R := 22.0
const LEDGE_H := 50.0
const DISH := 1.8
const LIP := 1.1
## The spur beside the tower: middle (u, v), radius, top.
const SPUR := Vector3(-34.0,-6.0,10.0)
const SPUR_H := 64.0
## The massif under them: how far its crags reach out from the tower and
## ledge to the turf (layout m, by angle), its steps.
const FALL := 27.0
const STEP := 6.5
const STEPPED := 0.6
## The keel under the turf (m).
const DEPTH := 70.0

## The line (scripts/dragon_roost.gd lays the dragon on it): its spine by
## rest z (model m, head tip to tail tip, every COIL_DZ), its girth there
## (GIRTH: the hide's reach round its bones, about the 90th percentile).
const HEAD_TIP := -35.5
const CHEST_Z := 3.5
const TAIL_TIP := 52.5
const COIL_DZ := 0.5
const GIRTH := [[-35.5,1.5],[-31.0,2.3],[-24.5,3.3],[-20.6,3.1],[-16.2,3.2],[-11.9,3.8],[-7.5,4.7],[-3.0,5.5],[3.5,5.3],
	[8.5,3.3],[13.5,2.7],[19.0,2.1],[24.5,1.7],[30.0,1.3],[35.5,1.0],[41.0,0.7],[46.5,0.45],[52.5,0.3]]
## The head and neck round the tower: [angle round TOWER_C (deg, u toward v),
## radius, the spine's height] each (layout m), head tip first, to the chest.
const NECK := [[165.0,19.0,71.0],[125.0,18.0,72.0],[88.0,18.0,70.0],[50.0,19.0,66.0],[22.0,22.5,62.0],[9.5,30.4,58.0]]
## The trunk and tail on the ledge from the chest: (u, v) each: the trunk
## along the back of the ledge, the tail round its outer rim and along its
## front rim (the side the aqueduct isle sees), curled round the hoard.
const BODY := [Vector2(32.0,-6.0),Vector2(40.0,-12.0),Vector2(50.0,-12.0),Vector2(58.0,-5.0),Vector2(60.0,5.0),Vector2(55.0,13.0),
	Vector2(49.0,18.5),Vector2(42.0,20.5),Vector2(35.0,19.0)]
## The neck's shelf: its floor GROOVE_GAP under the belly across GROOVE_FLAT
## of the girth either side of the line, then rising GROOVE_RISE m a metre
## (and carried under it where the rock falls short: `_groove`).
const GROOVE_GAP := 0.35
const GROOVE_FLAT := 1.1
const GROOVE_RISE := 3.0
## How far the neck's up leans out from the tower.
const UP_OUT := 0.25
## The rock round where it lies, paled and warmed this much (the hide reads
## dark against it), within PALE m of the line.
const PALE_TONE := Color(0.86,0.74,0.58)
const PALE := 7.0

static var _coil := {}
## The neck's shelf: its points [flat, floor (own y), girth], bucketed by
## GRID m cell.
static var _groove_pts: Array = []
static var _groove_cells := {}
const GRID := 10.0

## Where it stands (motif_sky.gd `places`' kind): [id, middle (world; y its
## turf), reach (m)].
static func place() -> Array:
	var c := own(ISLE_C)
	return ["dragon_roost",Vector3(c.x+AT.x,TOP+AT.y,c.y+AT.z),ISLE_R*SPAN]

func id() -> String:
	return "dragon_roost"

func isle_name() -> String:
	return "dragon's roost"

## Placeholder name and line until the isle is named.
func isle_card() -> Dictionary:
	return {"name":"The Dragon's Roost","epithet":"Something sleeps on the ledge","finds":[]}

func top() -> float:
	return TOP

## The air's summit: the peak.
func summit() -> Vector3:
	var p := own(TOWER_C)
	return Vector3(p.x,TOP+PEAK_H*SPAN,p.y)

func flora_site() -> KitFlora.Site:
	var site := KitFlora.Site.new(TOP,func(p: Vector2) -> float: return nest_wear(p))
	site.ray = Vector2(TOP+(PEAK_H+10.0)*SPAN,TOP-8.0)
	return site

func flora_seed() -> int:
	return SEED+3

## A mountain, not a run: the plane sets down on the turf only.
func landing_run() -> bool:
	return false

func warm() -> void:
	super.warm()
	coil()

func build(into: Node3D) -> void:
	super.build(into)
	var began := Time.get_ticks_msec()
	var land := island(SEED)
	_pale(land)
	art.add_child(land)
	for spec: Array in RUINS:
		var piece: Node3D = RuinKit.piece(spec[0],SEED+int(spec[1]),float(spec[2]))
		piece.name = str(spec[0])
		var at := ruin_at(spec)
		piece.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(spec[5]))),at)
		art.add_child(piece)
	art.add_child(bones())
	turf(land)
	built_ms = Time.get_ticks_msec()-began

# --- The frame ------------------------------------------------------------------------------

## (u, v) layout m to own (x, z).
static func own(uv: Vector2) -> Vector2:
	return AXIS+(U*uv.x+V*uv.y)*SPAN

## Own (x, z) to (u, v) layout m.
static func layout(p: Vector2) -> Vector2:
	var d := (p-AXIS)/SPAN
	return Vector2(d.dot(U),d.dot(V))

# --- The ground ----------------------------------------------------------------------------

## The crags' noise (broad, every 1/0.045 m) and the rock's grain (fine,
## 1/0.16 m), -1..1: a smooth value noise from hashed lattice points, pure
## arithmetic (no noise resource held in a static, so nothing outlives the
## run, and any thread may call it).
static func crag(x: float, z: float) -> float:
	return _value(x*0.045,z*0.045,SEED)

static func grain(x: float, z: float) -> float:
	return _value(x*0.16,z*0.16,SEED+1)

static func _value(x: float, z: float, seed_value: int) -> float:
	var ix := floori(x)
	var iz := floori(z)
	var fx := x-float(ix)
	var fz := z-float(iz)
	var sx := fx*fx*(3.0-2.0*fx)
	var sz := fz*fz*(3.0-2.0*fz)
	var a := lerpf(_lattice(ix,iz,seed_value),_lattice(ix+1,iz,seed_value),sx)
	var b := lerpf(_lattice(ix,iz+1,seed_value),_lattice(ix+1,iz+1,seed_value),sx)
	return lerpf(a,b,sz)

static func _lattice(ix: int, iz: int, seed_value: int) -> float:
	var h := (ix*374761393+iz*668265263+seed_value*2147483) & 0x7fffffff
	h = ((h ^ (h >> 13))*1274126177) & 0x7fffffff
	return float(h % 20001)/10000.0-1.0

## A crag's reach round its middle at angle `a`: creased buttresses (the
## folded sines' sharp troughs cut its faces into planes), share about 1.
static func _creased(a: float, seed_value: float) -> float:
	return 1.0+0.11*(1.0-2.0*absf(sin(2.5*a+seed_value)))+0.06*(1.0-2.0*absf(sin(4.5*a+seed_value*1.7)))+0.05*sin(7.0*a+seed_value*2.3)

## The ledge's reach round its middle at angle `a` (share of LEDGE_R): a
## little broken, so its rim is cut in a few straight runs.
static func _ledge_reach(a: float) -> float:
	return 1.0+0.05*(1.0-2.0*absf(sin(2.5*a+0.4)))+0.03*sin(5.0*a+1.1)

## The ledge's height over TOP at `q` (layout), -INF off it.
static func ledge_h(q: Vector2) -> float:
	var p := q-LEDGE_C
	var t := p.length()/(LEDGE_R*_ledge_reach(atan2(p.y,p.x)))
	if t >= 1.0: return -INF
	return LEDGE_H-DISH*(1.0-t*t)+LIP*smoothstep(0.8,1.0,t)

## How far out of the ledge and the tower's foot `q` is (layout m, 0 or less
## on them).
static func _out_of_core(q: Vector2) -> float:
	var pt := q-TOWER_C
	var dt := pt.length()/_creased(atan2(pt.y,pt.x),1.3)-TOWER_BASE
	var pl := q-LEDGE_C
	var dl := pl.length()/_ledge_reach(atan2(pl.y,pl.x))-LEDGE_R
	return minf(dt,dl)

## The ground's height at (x, z) (own frame): the turf; the massif's stepped
## crags rising from it to the ledge and the tower's foot; the ledge; the
## tower to the peak; the spur; the highest of them, the neck's shelf cut in.
static func ground(x: float, z: float) -> float:
	var q := layout(Vector2(x,z))
	var n := crag(x,z)
	# The turf: a gentle swell rising toward the mountain's foot.
	var meadow := 0.9*grain(x*0.4,z*0.4)
	var e := _out_of_core(q)
	var h := meadow
	# The massif: from the ledge's height at the core down to the turf over
	# FALL (by angle round the ledge: steep under its outer edge, broader
	# toward the aqueduct isle), stepped into crags.
	var a := atan2(q.y-LEDGE_C.y*0.5,q.x-LEDGE_C.x*0.5)
	var reach := FALL*(1.0+0.28*sin(a)-0.38*maxf(cos(a),0.0)*maxf(cos(a),0.0))*_creased(a,2.2)
	if e <= 0.0:
		h = maxf(h,LEDGE_H-3.0)
	elif e < reach:
		var t := e/reach
		var fall := (LEDGE_H-3.0)*pow(1.0-t,0.85)+3.5*n*smoothstep(0.0,0.1,t)*(1.0-smoothstep(0.85,1.0,t))
		var stepped := floorf(fall/STEP)*STEP+STEP*smoothstep(0.7,1.0,fposmod(fall,STEP)/STEP)
		h = maxf(h,lerpf(fall,stepped,STEPPED*smoothstep(0.02,0.12,t)))
	# The ledge (its floor, under the massif's core).
	var l := ledge_h(q)
	if l > -INF: h = l
	# The tower: steep flanks to its shoulder, then the broken peak.
	var pt := q-TOWER_C
	var at := atan2(pt.y,pt.x)
	var d := pt.length()/_creased(at,1.3)
	if d < TOWER_BASE:
		var tower: float
		if d > TOWER_SHOULDER: tower = LEDGE_H+(TOWER_BASE-d)/(TOWER_BASE-TOWER_SHOULDER)*(SHOULDER_H-LEDGE_H)
		else: tower = SHOULDER_H+(PEAK_H-SHOULDER_H)*(1.0-pow(d/TOWER_SHOULDER,1.6))
		# Its faces broken into steps and leaning facets.
		tower += 2.6*n+1.6*crag(x*2.3,z*2.3)
		tower = lerpf(tower,floorf(tower/4.0)*4.0+4.0*smoothstep(0.75,1.0,fposmod(tower,4.0)/4.0),0.45)
		h = maxf(h,tower)
	# The spur: a lower crag beside the tower.
	var ps := q-Vector2(SPUR.x,SPUR.y)
	var ds := ps.length()/(SPUR.z*_creased(atan2(ps.y,ps.x),3.1))
	if ds < 1.0: h = maxf(h,SPUR_H-(SPUR_H-LEDGE_H*0.6)*pow(ds,1.3)+1.5*n)
	var y := TOP+h*SPAN
	var shelf := _groove(Vector2(x,z))
	return minf(maxf(y,shelf.y),shelf.x)

## How worn bare the nest is at `p` (own x, z), 0..1: the ledge's floor.
static func nest_wear(p: Vector2) -> float:
	var q := layout(p)-LEDGE_C
	return 1.0-smoothstep(0.82,1.02,q.length()/LEDGE_R)

# --- The line ------------------------------------------------------------------------------

## The line's girth at rest z `z` (m, at its size).
static func girth_at(z: float) -> float:
	return table(GIRTH,z)*DRAGON_SIZE

## The line (see the head): {z, at (own x, y, z: the spine's), up, girth}
## arrays, head tip first, every COIL_DZ of rest z (COIL_DZ x size apart).
## The head and neck round the tower first (their heights laid), then the
## shelf cut for them, then the trunk and tail on the rock. Made once.
static func coil() -> Dictionary:
	if not _coil.is_empty(): return _coil
	var step := COIL_DZ*DRAGON_SIZE
	var count := int(round((TAIL_TIP-HEAD_TIP)/COIL_DZ))+1
	var chest_i := int(round((CHEST_Z-HEAD_TIP)/COIL_DZ))
	# The head and neck: a smooth line through NECK's points.
	var ctrl := PackedVector3Array()
	for c: Array in NECK:
		var a := deg_to_rad(float(c[0]))
		var uv := TOWER_C+Vector2(cos(a),sin(a))*float(c[1])
		var f := own(uv)
		ctrl.append(Vector3(f.x,TOP+float(c[2])*SPAN,f.y))
	var neck := _resample(_spline(ctrl),step,chest_i+1)
	var zs := PackedFloat32Array()
	var at := PackedVector3Array()
	var ups := PackedVector3Array()
	var girth := PackedFloat32Array()
	for i in range(count):
		var z := HEAD_TIP+COIL_DZ*float(i)
		zs.append(z)
		girth.append(girth_at(z))
	var tower := own(TOWER_C)
	for i in range(chest_i+1):
		at.append(neck[i])
		var out := Vector2(neck[i].x,neck[i].z)-tower
		out = out.normalized()
		ups.append((Vector3.UP+Vector3(out.x,0.0,out.y)*UP_OUT).normalized())
	# The shelf under the neck, so the trunk's rock reads it.
	_groove_pts = []
	_groove_cells = {}
	for i in range(0,chest_i+1): _add_groove(at[i],girth[i])
	# The trunk and tail: on along BODY from the chest, each point on the
	# rock (its height the ground's plus its girth), spaced along the line.
	var flat := PackedVector2Array([Vector2(at[chest_i].x,at[chest_i].z)])
	for b: Vector2 in BODY: flat.append(own(b))
	var dense := _spline2(flat)
	var pts := PackedVector3Array()
	for k in range(dense.size()):
		var p := dense[k]
		pts.append(Vector3(p.x,ground(p.x,p.y),p.y))
	# Spaced by length along the rock (so the drape is as long as it lies).
	var lengths := PackedFloat32Array([0.0])
	for k in range(1,pts.size()): lengths.append(lengths[k-1]+pts[k].distance_to(pts[k-1]))
	var j := 0
	for i in range(chest_i+1,count):
		var want := float(i-chest_i)*step
		while j < lengths.size()-2 and lengths[j+1] < want: j += 1
		var p: Vector2
		if want >= lengths[lengths.size()-1]:
			var last := dense[dense.size()-1]
			var dir := (last-dense[dense.size()-2]).normalized()
			p = last+dir*(want-lengths[lengths.size()-1])
		else:
			p = dense[j].lerp(dense[j+1],(want-lengths[j])/maxf(lengths[j+1]-lengths[j],0.001))
		at.append(Vector3(p.x,ground(p.x,p.y)+girth[i],p.y))
		ups.append(Vector3.UP)
	_coil = {"z":zs,"at":at,"up":ups,"girth":girth}
	return _coil

## A point of the neck's shelf: its floor GROOVE_GAP under the belly of a
## body of girth `g` along `at` (own), indexed by cell.
static func _add_groove(at: Vector3, g: float) -> void:
	var p := Vector2(at.x,at.z)
	var k := _groove_pts.size()
	_groove_pts.append([p,at.y-g-GROOVE_GAP,g])
	var reach := g*GROOVE_FLAT+14.0
	for cx in range(floori((p.x-reach)/GRID),floori((p.x+reach)/GRID)+1):
		for cz in range(floori((p.y-reach)/GRID),floori((p.y+reach)/GRID)+1):
			var key := Vector2i(cx,cz)
			if not _groove_cells.has(key): _groove_cells[key] = []
			(_groove_cells[key] as Array).append(k)

## A Catmull-Rom through `ctrl`, densely (every tenth of a span).
static func _spline(ctrl: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := ctrl.size()
	for i in range(n-1):
		var p0 := ctrl[maxi(i-1,0)]
		var p1 := ctrl[i]
		var p2 := ctrl[i+1]
		var p3 := ctrl[mini(i+2,n-1)]
		for k in range(20):
			var t := float(k)/20.0
			out.append(0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t))
	out.append(ctrl[n-1])
	return out

static func _spline2(ctrl: PackedVector2Array) -> PackedVector2Array:
	var c3 := PackedVector3Array()
	for p in ctrl: c3.append(Vector3(p.x,0.0,p.y))
	var out := PackedVector2Array()
	for p in _spline(c3): out.append(Vector2(p.x,p.z))
	return out

## `count` points along `dense`, `step` apart by length (on past its end
## straight, if short).
static func _resample(dense: PackedVector3Array, step: float, count: int) -> PackedVector3Array:
	var out := PackedVector3Array([dense[0]])
	var k := 0
	var from := dense[0]
	var left := step
	while out.size() < count:
		if k+1 >= dense.size():
			var dir := (dense[dense.size()-1]-dense[dense.size()-2]).normalized()
			out.append(out[out.size()-1]+dir*step)
			continue
		var seg := from.distance_to(dense[k+1])
		if seg >= left:
			from = from.lerp(dense[k+1],left/seg)
			out.append(from)
			left = step
		else:
			left -= seg
			from = dense[k+1]
			k += 1
	return out

## A rest-z table's value at `z` (GIRTH's kind), straight between its rows.
static func table(rows: Array, z: float) -> float:
	if z <= float(rows[0][0]): return float(rows[0][1])
	for i in range(1,rows.size()):
		if z <= float(rows[i][0]):
			var a: Array = rows[i-1]
			var b: Array = rows[i]
			return lerpf(float(a[1]),float(b[1]),(z-float(a[0]))/(float(b[0])-float(a[0])))
	return float(rows[rows.size()-1][1])

## The neck's shelf at `p` (own x, z): (the groove's top, the shelf's
## least), the lowest of the floors of the neck's points near it rising
## away from them (INF away from it), and the highest of them falling
## away under it (SHELF_FALL m a metre past half its girth; -INF away), so
## the neck is carried where the rock under it falls short.
const SHELF_FALL := 2.2
static func _groove(p: Vector2) -> Vector2:
	var key := Vector2i(floori(p.x/GRID),floori(p.y/GRID))
	if not _groove_cells.has(key): return Vector2(INF,-INF)
	var best := INF
	var most := -INF
	for k: int in _groove_cells[key]:
		var g: Array = _groove_pts[k]
		var q := p.distance_to(g[0])
		var gi := float(g[2])
		if q > gi*GROOVE_FLAT+14.0: continue
		best = minf(best,float(g[1])+GROOVE_RISE*maxf(q-gi*GROOVE_FLAT,0.0))
		most = maxf(most,float(g[1])-SHELF_FALL*maxf(q-gi*0.5,0.0))
	return Vector2(best,most)

## How near `p` (own x, y, z) is to the line (m past its girth there).
static func line_gap(p: Vector3) -> float:
	var c := coil()
	var at: PackedVector3Array = c.at
	var girth: PackedFloat32Array = c.girth
	var best := INF
	for i in range(0,at.size(),2): best = minf(best,p.distance_to(at[i])-girth[i])
	return best

# --- The land --------------------------------------------------------------------------------

## Its outline (own frame), a wandering ring ISLE_R round its middle.
static func outline() -> Array:
	return KitLand.blob(own(ISLE_C),ISLE_R*SPAN,SEED)

## The island: the turf and the mountain's crags (faces too steep for turf
## drawn as rock) over `ground`, collided, the keel under it; the mountain
## on the finer grid. The nest's floor worn bare.
static func island(seed_value: int) -> Node3D:
	var spec := {"outline":outline(),"depth":DEPTH*SPAN,"seed":seed_value,"ground":func(x: float, z: float) -> float: return ground(x,z),
		"top":TOP,"hang":true,"cell":2.4,"fine":1.5,"fine_box":Rect2(own(Vector2(12.0,0.0))-Vector2.ONE*62.0*SPAN,Vector2.ONE*124.0*SPAN),
		"resample":[60.0,140,64],"tone":KitLook.turf(seed_value,func(p: Vector2) -> float: return nest_wear(p))}
	var node := KitLand.island(spec)
	node.name = "Mountain"
	return node

## The rock where it lies paled and warmed (PALE_TONE), so its dark hide
## reads against it from afar: the crag faces within PALE of the line and
## the ledge's rim and underside.
static func _pale(land: Node3D) -> void:
	var crags := land.get_node_or_null("Crags") as MeshInstance3D
	if crags == null or crags.mesh == null: return
	var mesh := crags.mesh as ArrayMesh
	var tint := PALE_TONE.srgb_to_linear()
	var out := ArrayMesh.new()
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colours: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		if colours.size() == verts.size():
			for i in range(0,verts.size(),3):
				var m := (verts[i]+verts[i+1]+verts[i+2])/3.0
				var q := layout(Vector2(m.x,m.z))
				# The ledge's rim and the crag just under it.
				var dl := (q-LEDGE_C).length()/LEDGE_R
				var under := (TOP+LEDGE_H*SPAN)-m.y
				var k := (1.0-smoothstep(1.0,1.5,dl))*(1.0-smoothstep(6.0,16.0,under))
				# Round the neck's shelf.
				var gap := line_gap(m)
				k = maxf(k,1.0-smoothstep(1.0,PALE,gap))
				if k <= 0.0: continue
				for v in range(3):
					var c := colours[i+v]
					var lit := Color(tint.r,tint.g,tint.b,c.a)*lerpf(0.75,1.05,clampf(c.get_luminance()*6.0,0.0,1.0))
					colours[i+v] = c.lerp(lit,k*0.85)
			arrays[Mesh.ARRAY_COLOR] = colours
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		out.surface_set_material(out.get_surface_count()-1,mesh.surface_get_material(s))
	crags.mesh = out

# --- The ruins and the nest ------------------------------------------------------------------

## [piece, seed, weathered, (u, v) layout, turn (deg)]: the hoard in the
## curl (a chest, slabs, a fallen pier) and, below, a broken stair up the
## crags and a shrine's arch on the turf toward the aqueduct isle.
const RUINS := [
	["tomb_chest",2,0.3,Vector2(44.0,2.0),0.0,30.0],
	["floor",4,0.6,Vector2(46.0,-3.0),0.0,15.0],
	["fallen_pier",3,0.5,Vector2(36.0,14.0),0.0,70.0],
	["stairs",5,0.65,Vector2(12.0,40.0),0.0,190.0],
	["stairs",6,0.75,Vector2(22.0,34.0),0.0,215.0],
	["arch",7,0.55,Vector2(4.0,58.0),0.0,200.0],
	["pier",8,0.7,Vector2(-14.0,52.0),0.0,0.0],
]

## Where a ruin stands (own frame): on the ground at its place.
static func ruin_at(spec: Array) -> Vector3:
	var p := own(spec[3])
	return Vector3(p.x,ground(p.x,p.y)-0.15,p.y)

## Bones in the nest: a few long bones and a broken rib cage, pale, lying on
## the ledge's floor clear of the dragon.
const BONES := [
	# [u, v, length, thickness, turn (deg)]
	[48.0,4.0,5.5,0.45,20.0],[41.0,8.0,4.2,0.38,110.0],[34.0,8.0,6.0,0.5,60.0],[50.0,-2.0,3.4,0.32,150.0],
	[44.0,12.0,3.8,0.35,80.0],[38.0,-2.0,2.8,0.3,35.0],[28.0,16.0,4.6,0.4,10.0]]
const RIBS := [Vector2(47.0,9.0),Vector2(32.0,12.5)]

static func bones() -> Node3D:
	var root := Node3D.new()
	root.name = "Bones"
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.86,0.82,0.72)
	mat.roughness = 0.95
	for b: Array in BONES:
		var p := own(Vector2(b[0],b[1]))
		var len := float(b[2])*SPAN
		var r := float(b[3])*SPAN
		var bone := _bone_mesh(len,r,mat)
		var y := ground(p.x,p.y)+r*0.7
		bone.transform = Transform3D(Basis(Vector3.UP,deg_to_rad(float(b[4])))*Basis(Vector3.RIGHT,PI*0.5),Vector3(p.x,y,p.y))
		root.add_child(bone)
	for c: Vector2 in RIBS:
		var p := own(c)
		var y := ground(p.x,p.y)
		var cage := Node3D.new()
		cage.transform = Transform3D(Basis(Vector3.UP,0.7+c.x*0.1),Vector3(p.x,y,p.y))
		for k in range(6):
			for s in [-1.0,1.0]:
				var rib := _bone_mesh(3.4*SPAN*(1.0-absf(float(k)-2.5)*0.08),0.16*SPAN,mat)
				rib.transform = Transform3D(Basis(Vector3.BACK,s*(0.55+0.08*k))*Basis(Vector3.RIGHT,0.25*s),Vector3(s*0.5*SPAN,1.1*SPAN,(float(k)-2.5)*0.9*SPAN))
				cage.add_child(rib)
		var spine := _bone_mesh(6.0*SPAN,0.22*SPAN,mat)
		spine.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),Vector3(0.0,0.35*SPAN,0.0))
		cage.add_child(spine)
		root.add_child(cage)
	return root

## A bone: a faceted shaft with knobbed ends, along its y.
static func _bone_mesh(length: float, r: float, mat: Material) -> MeshInstance3D:
	var shaft := CylinderMesh.new()
	shaft.top_radius = r*0.8
	shaft.bottom_radius = r*0.8
	shaft.height = length
	shaft.radial_segments = 6
	shaft.rings = 1
	shaft.material = mat
	var mi := MeshInstance3D.new()
	mi.mesh = shaft
	for s in [-1.0,1.0]:
		var knob := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = r*1.3
		sphere.height = r*2.2
		sphere.radial_segments = 6
		sphere.rings = 3
		sphere.material = mat
		knob.mesh = sphere
		knob.position = Vector3(0.0,s*length*0.5,0.0)
		mi.add_child(knob)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mi
