extends Node3D
## The Peak's hero towers: each stands from one entry of a table, built on a
## worker (scripts/endless/rocks/peak_tower_shape.gd), in the land's rock paint
## (LandRocks' bare material). Not a rock kind: a tower is taller and wider
## than the rock plan's 480 m cell can hold, and it is always there.
##
## The trunk's calls (studies/endless_flight.gd has them all):
##   var t := PeakTowers.entry(at, base, tip, lean, girth, seed)
##     (the crown's table is PeakMassif.CROWN, through `peak.crown`)
##     at     world XZ of the base point
##     base   height of the base point, m over the sea (it stands buried
##            under this: `PeakTowerShape.SINK`, so any slope takes it)
##     tip    the highest point, m over the sea
##     lean   Vector2 in world XZ: the way the tip stands off the base and
##            how far (m), mostly high up
##     girth  half the width at the base, m (buttresses stand past it)
##     seed   its shape
##   towers.setup(table, land_seed, bare_material, field)
##   towers.prime(eye), towers.step(eye)
##   look.ground_copies gets towers.far_material and towers.rock_material
##   rocks.extra = towers      the flight, camera and rivals' solid goes
##                             through LandRocks from then on
##   `axes()` gives each tower's base, tip and radius for the spirals.
##
## --towers=0 stands none. Each is named `peak/tower/<n>` and placed through
## scripts/layout_overrides.gd: a move in the layout file wins (its place, not
## its yaw), a tower it lists as deleted is not built.
##
## Past the camera's far plane: `Far` holds every tower's coarse level and the
## massif's body, read off the land's height on a coarse grid, in
## shaders/peak_tower_far.gdshader, which draws it behind all the real land.
## So the crown stands on the skyline from any distance with no swap to see:
## the real rock stands in front of it wherever the real rock is drawn.

const Shape = preload("res://scripts/endless/rocks/peak_tower_shape.gd")
const Build = preload("res://scripts/endless/rocks/rock_build.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const RockShape = preload("res://scripts/endless/rock_shape.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const PeakMassif = preload("res://scripts/endless/peak_massif.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const LAYER := 1
## The solid's scan up a tower: every SCAN slices, then bisected.
const SCAN := 4
## `face`'s ball: its two shells, m past the reach it was asked for, and the
## ways on each.
const FACE_SHELLS := Vector2(2.0,8.0)
const FACE_WAYS := 24
## The massif's body in the far mesh: a grid this wide round the peak (m),
## this fine. It melts away (vertex alpha) over BODY_FOOT m over the sea and out
## over BODY_EDGE m from the peak, so it has no edge and no plate under it.
const BODY_REACH := 3400.0
const BODY_STEP := 150.0
const BODY_FOOT := Vector2(90.0,640.0)
## The foot's melt with the old rock (--spire-rock=0).
const BODY_FOOT_OLD := Vector2(300.0,560.0)
const BODY_EDGE := Vector2(2000.0,3200.0)
## Far on when some of it could be past the far plane, less this (m).
const FAR_MARGIN := 600.0
## Its colours (linear): rock, and the snow that holds to gentle high ground.
const FAR_ROCK := Color(0.105,0.098,0.092)
const FAR_SNOW := Color(0.5,0.54,0.6)
const FAR_SNOW_FROM := 620.0
## The towers' own copy of the rock paint: its bands, facets and blocks this
## many times the land's, for a face hundreds of metres tall, its even seams and
## beds turned down (the beds that show are the shape's), and the height haze
## cut this far over them and the far mesh, so they stand dark on the sky.
const PAINT := {"rock_size":2.4,"rock_seams":0.03,"rock_beds":0.38,"rock_bump":0.75,"rock_relief":1.5,"rock_tint":Vector3(0.2,0.2,0.24),"peak_granite":0.012,"peak_basalt":0.0}
const HAZE_CUT := 0.86
const HAZE_RISE := 260.0

## {name, built, ...}: entries, moved by the layout file, in table order.
var table: Array = []
var far_material: ShaderMaterial
## The towers' rock paint: join the look's ground_copies.
var rock_material: Material
var stats := {"towers":0,"tris":0,"build_ms":0.0,"body_ms":0.0,"commit_ms":0.0}

var _material: Material
var _tasks: Array = []     # [task id, index or -1 the body]
var _built := {}           # index -> built
var _far_parts: Array = []  # each tower's far level, until the far mesh stands
var _body: Dictionary = {}
var _done := false
var _lock := Mutex.new()
var _solids: Array = []
var _far: MeshInstance3D
var _centre := Vector3.ZERO
var _far_reach := 0.0
var _quit := false
var _strata: Dictionary
var _pad := Build.wingtip()
var _ball := PackedVector3Array()

static func wanted() -> bool:
	return not "--towers=0" in LaunchArgs.user_args()

## An entry of the table (see the header).
static func entry(at: Vector2, base: float, tip: float, lean: Vector2, girth: float, shape_seed: int) -> Dictionary:
	return {"at":at,"base":base,"tip":tip,"lean":lean,"girth":girth,"seed":shape_seed}

## `field`: a land field of the tower's own (a worker reads it for the far
## mesh's body), or null for no body. Starts the builds; `prime` waits for them.
func setup(entries: Array, land_seed: int, bare: Material, field: RefCounted = null, peak_at := Vector2.ZERO) -> void:
	far_material = ShaderMaterial.new()
	far_material.shader = preload("res://shaders/peak_tower_far.gdshader")
	var haze := Vector4(HAZE_RISE,300.0,HAZE_CUT,0.0)
	rock_material = bare
	if bare is ShaderMaterial:
		rock_material = (bare as ShaderMaterial).duplicate()
		for k: String in PAINT: (rock_material as ShaderMaterial).set_shader_parameter(k,PAINT[k])
		var land: Variant = (bare as ShaderMaterial).get_shader_parameter("haze_height")
		if land is Vector4: haze = Vector4(HAZE_RISE,(land as Vector4).y,HAZE_CUT,(land as Vector4).w)
		(rock_material as ShaderMaterial).set_shader_parameter("haze_height",haze)
	far_material.set_shader_parameter("haze_height",haze)
	_material = rock_material
	_strata = Shape.strata(land_seed)
	for k in entries.size():
		var t: Dictionary = (entries[k] as Dictionary).duplicate()
		var name := "peak/tower/%d" % k
		if LayoutOverrides.deleted(name): continue
		var coded := Transform3D(Basis.IDENTITY,Vector3((t.at as Vector2).x,float(t.base)+Field.SEA_Y,(t.at as Vector2).y))
		var moved := LayoutOverrides.xform(name,coded).origin
		t.tip = float(t.tip)+(moved.y-coded.origin.y)
		t.base = moved.y-Field.SEA_Y
		t.at = Vector2(moved.x,moved.z)
		t.name = name
		t.coded = coded
		table.append(t)
		_centre += moved
	if table.is_empty(): return
	_centre /= table.size()
	for k in table.size():
		_tasks.append([WorkerThreadPool.add_task(_build.bind(k)),k])
	if field != null:
		_tasks.append([WorkerThreadPool.add_task(_build_body.bind(field,peak_at)),-1])

func _exit_tree() -> void:
	_quit = true
	for e: Array in _tasks: WorkerThreadPool.wait_for_task_completion(int(e[0]))

func _build(k: int) -> void:
	if _quit: return
	var t0 := Time.get_ticks_usec()
	var b := Shape.build(table[k],_strata)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(b.faces)
	b["shape"] = shape
	var ms := (Time.get_ticks_usec()-t0)/1000.0
	_lock.lock()
	_built[k] = b
	stats.build_ms = maxf(float(stats.build_ms),ms)
	_lock.unlock()

## The massif's coarse skin, off the land's own height: {v, n, c, i}.
func _build_body(field: RefCounted, at: Vector2) -> void:
	if _quit: return
	var t0 := Time.get_ticks_usec()
	var cells := int(BODY_REACH*2.0/BODY_STEP)
	var side := cells+1
	var hs := PackedFloat32Array()
	hs.resize(side*side)
	var x0 := at.x-BODY_REACH
	var z0 := at.y-BODY_REACH
	for j in side:
		for i in side:
			hs[j*side+i] = float(field.height(x0+i*BODY_STEP,z0+j*BODY_STEP))
	var alpha := PackedFloat32Array()
	alpha.resize(side*side)
	var foot := BODY_FOOT if PeakMassif.dark_wanted() else BODY_FOOT_OLD
	for q in side*side:
		var off := Vector2(x0+(q%side)*BODY_STEP,z0+(q/side)*BODY_STEP)-at
		alpha[q] = smoothstep(foot.x,foot.y,hs[q]-Field.SEA_Y)*(1.0-smoothstep(BODY_EDGE.x,BODY_EDGE.y,off.length()))
	var map := PackedInt32Array()
	map.resize(side*side)
	map.fill(-1)
	var v := PackedVector3Array()
	var idx := PackedInt32Array()
	var melt := PackedFloat32Array()
	var add := func(q: int) -> int:
		if map[q] < 0:
			map[q] = v.size()
			v.append(Vector3(x0+(q%side)*BODY_STEP,hs[q],z0+(q/side)*BODY_STEP))
			melt.append(alpha[q])
		return map[q]
	for j in cells:
		for i in cells:
			var a := j*side+i
			var c := a+side
			if maxf(maxf(alpha[a],alpha[a+1]),maxf(alpha[c],alpha[c+1])) <= 0.0: continue
			var p: int = add.call(a)
			var q: int = add.call(a+1)
			var r: int = add.call(c)
			var s: int = add.call(c+1)
			idx.append_array([p,q,r,q,s,r])
	var n := Build._normals(v,idx)
	var c := PackedColorArray()
	c.resize(v.size())
	for k in v.size():
		var over := v[k].y-Field.SEA_Y
		var snow := smoothstep(FAR_SNOW_FROM,FAR_SNOW_FROM+200.0,over)*smoothstep(0.62,0.82,n[k].y)
		c[k] = FAR_ROCK.lerp(FAR_SNOW,snow)
		c[k].a = melt[k]
	_lock.lock()
	_body = {"v":v,"n":n,"c":c,"i":idx}
	stats.body_ms = (Time.get_ticks_usec()-t0)/1000.0
	_lock.unlock()

## Waits for the towers and stands them, on this thread (the far mesh comes
## when the body's task ends: `step`).
func prime(eye: Vector3) -> void:
	var open: Array = []
	for e: Array in _tasks:
		if int(e[1]) >= 0: WorkerThreadPool.wait_for_task_completion(int(e[0]))
		else: open.append(e)
	_tasks = open
	_commit_towers()
	step(eye)

func step(eye: Vector3) -> void:
	if not _done or _far == null:
		var open: Array = []
		for e: Array in _tasks:
			if WorkerThreadPool.is_task_completed(int(e[0])): WorkerThreadPool.wait_for_task_completion(int(e[0]))
			else: open.append(e)
		_tasks = open
		if _tasks.is_empty() and not table.is_empty():
			_commit_towers()
			_far_mesh()
	if _far == null: return
	var cam := get_viewport().get_camera_3d()
	var far := cam.far if cam != null else 7904.0
	var at := cam.global_position if cam != null else eye
	var on := Vector2(at.x-_centre.x,at.z-_centre.z).length() > far-_far_reach-FAR_MARGIN
	if on != _far.visible: _far.visible = on
	if on: far_material.set_shader_parameter("far_m",far)

func _commit_towers() -> void:
	if _done or table.is_empty(): return
	_done = true
	var t0 := Time.get_ticks_usec()
	for k in table.size():
		var t: Dictionary = table[k]
		var b: Dictionary = _built[k]
		var node := Node3D.new()
		node.name = String(t.name).replace("/","_")
		node.position = Vector3((t.at as Vector2).x,float(t.base)+Field.SEA_Y,(t.at as Vector2).y)
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,b.arrays,[],b.lods,RockShape.format(b.arrays))
		mesh.surface_set_material(0,_material)
		var mi := MeshInstance3D.new()
		mi.name = "Mesh"
		mi.mesh = mesh
		node.add_child(mi)
		var body := StaticBody3D.new()
		body.name = "Body"
		body.collision_layer = LAYER
		body.collision_mask = 0
		var cs := CollisionShape3D.new()
		cs.shape = b.shape
		body.add_child(cs)
		node.add_child(body)
		add_child(node)
		LayoutOverrides.track(String(t.name),node,"piece",t.coded)
		_solids.append(_world_solid(b.solid,node.position))
		GroundNative.bump()
		stats.towers = int(stats.towers)+1
		stats.tris = int(stats.tris)+int(b.tris[0])
		stats["levels"] = b.tris
		_far_parts.append(b.far)
	stats.commit_ms = (Time.get_ticks_usec()-t0)/1000.0
	_built.clear()

## A tower's solid in world space.
static func _world_solid(s: Dictionary, at: Vector3) -> Dictionary:
	var c: PackedVector2Array = (s.c as PackedVector2Array).duplicate()
	var xz := Vector2(at.x,at.z)
	for k in c.size(): c[k] += xz
	var field: Dictionary = s.field
	var h: PackedFloat32Array = (field.h as PackedFloat32Array).duplicate()
	for k in h.size():
		if h[k] != Shape.NO_TOP: h[k] += at.y
	return {"c":c,"r":s.r,"y0":float(s.y0)+at.y,"dy":float(s.dy),"slices":int(s.slices),"top":float(s.top)+at.y,
		"mid":(s.mid as Vector2)+xz,"reach":float(s.reach),"rim_y":float(s.rim_y)+at.y,
		"field":{"h":h,"at":(field.at as Vector2)+xz,"w":field.w,"d":field.d}}

func _far_mesh() -> void:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()
	var add := func(fv: PackedVector3Array, fn: PackedVector3Array, fc: PackedColorArray, fi: PackedInt32Array, at: Vector3) -> void:
		var first := v.size()
		for k in fv.size():
			v.append(fv[k]+at)
			n.append(fn[k])
			c.append(fc[k])
		for k in fi.size(): idx.append(fi[k]+first)
	for k in table.size():
		var t: Dictionary = table[k]
		var f: Dictionary = _far_parts[k]
		var fb: PackedFloat32Array = f.b
		var fc := PackedColorArray()
		fc.resize(fb.size())
		for q in fb.size():
			fc[q] = FAR_ROCK*(1.0+fb[q]*0.4)
			fc[q].a = 1.0
		add.call(f.v,f.n,fc,f.i,Vector3((t.at as Vector2).x,float(t.base)+Field.SEA_Y,(t.at as Vector2).y)-_centre)
	if not _body.is_empty():
		add.call(_body.v,_body.n,_body.c,_body.i,-_centre)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = v
	arrays[Mesh.ARRAY_NORMAL] = n
	arrays[Mesh.ARRAY_COLOR] = c
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,far_material)
	_far = MeshInstance3D.new()
	_far.name = "Far"
	_far.mesh = mesh
	_far.position = _centre
	_far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# It stands past the far plane by design: never culled by it.
	_far.custom_aabb = AABB(Vector3(-400000.0,-400000.0,-400000.0),Vector3(800000.0,800000.0,800000.0))
	add_child(_far)
	_far_parts.clear()
	for p in v: _far_reach = maxf(_far_reach,Vector2(p.x,p.z).length())
	stats["far_tris"] = idx.size()/3

## Each tower for the spirals and the like: [{name, base (world), tip
## (world), radius}]. The tip stands off the axis by the lean.
func axes() -> Array:
	var out: Array = []
	for t: Dictionary in table:
		var at: Vector2 = t.at
		var tip_at: Vector2 = at+(t.lean as Vector2)
		out.append({"name":t.name,"base":Vector3(at.x,float(t.base)+Field.SEA_Y,at.y),"tip":Vector3(tip_at.x,float(t.tip)+Field.SEA_Y,tip_at.y),"radius":float(t.girth)})
	return out

# --- The flight's solid -----------------------------------------------------
# Through LandRocks `extra`: the same answers its pillars give, read off the
# towers' slices. `pad` is the wingtip's reach when not given.

## How far inside slice `k` of `s`, grown by `pad`, world XZ `q` is (m; under
## 0 outside).
static func _gap(s: Dictionary, k: int, q: Vector2, pad: float) -> float:
	var c: PackedVector2Array = s.c
	var r: PackedFloat32Array = s.r
	var off := q-c[k]
	var f := fposmod(off.angle(),TAU)/TAU*Shape.SOLID_WAYS
	var b := int(f)
	var at := k*Shape.SOLID_WAYS
	return lerpf(r[at+b%Shape.SOLID_WAYS],r[at+(b+1)%Shape.SOLID_WAYS],f-b)+pad-off.length()

## The highest rock of the top within `pad` of world XZ `q`, or NO_TOP.
static func _top_at(s: Dictionary, q: Vector2, pad: float) -> float:
	var f: Dictionary = s.field
	var h: PackedFloat32Array = f.h
	var w := int(f.w)
	var d := int(f.d)
	var rel := (q-(f.at as Vector2))/Shape.TOP_CELL
	var spread := pad/Shape.TOP_CELL
	var best := Shape.NO_TOP
	for z in range(maxi(int(floor(rel.y-spread)),0),mini(int(floor(rel.y+spread)),d-1)+1):
		for x in range(maxi(int(floor(rel.x-spread)),0),mini(int(floor(rel.x+spread)),w-1)+1):
			best = maxf(best,h[x+z*w])
	return best

## The solid stretches over world XZ `p` (world y, low to high).
func stretches(p: Vector3, pad := -1.0) -> Array:
	var out: Array = []
	if pad < 0.0: pad = _pad
	var q := Vector2(p.x,p.z)
	for s: Dictionary in _solids:
		if q.distance_to(s.mid) > float(s.reach)+pad: continue
		var y0 := float(s.y0)
		var dy := float(s.dy)
		var n := int(s.slices)
		var k := 0
		var g0 := _gap(s,0,q,pad)
		var from := y0 if g0 > 0.0 else -INF
		while k < n-1:
			var next := mini(k+SCAN,n-1)
			var g1 := _gap(s,next,q,pad)
			if (g0 > 0.0) != (g1 > 0.0):
				var lo := k
				var hi := next
				var glo := g0
				var ghi := g1
				while hi-lo > 1:
					var m := (lo+hi)/2
					var gm := _gap(s,m,q,pad)
					if (gm > 0.0) == (glo > 0.0):
						lo = m
						glo = gm
					else:
						hi = m
						ghi = gm
				var y := y0+(lo+glo/(glo-ghi))*dy
				if g1 > 0.0: from = y
				else:
					out.append(Vector2(from,y))
					from = -INF
			g0 = g1
			k = next
		var rim := float(s.rim_y)
		var top := _top_at(s,q,pad)
		if from != -INF: out.append(Vector2(from,maxf(rim,top)))
		elif top > rim: out.append(Vector2(rim,top))
	return out

## True inside a tower's solid, grown by `pad`.
func inside(p: Vector3, pad := -1.0) -> bool:
	if pad < 0.0: pad = _pad
	var q := Vector2(p.x,p.z)
	for s: Dictionary in _solids:
		if q.distance_to(s.mid) > float(s.reach)+pad: continue
		if p.y >= float(s.rim_y):
			if _top_at(s,q,pad) > p.y: return true
			continue
		var f := (p.y-float(s.y0))/float(s.dy)
		var last := int(s.slices)-1
		if f < 0.0 or f >= last: continue
		var k := int(f)
		if lerpf(_gap(s,k,q,pad),_gap(s,k+1,q,pad),f-k) > 0.0: return true
	return false

## The way out of the rock at world `p`, a unit vector, or ZERO with no tower
## within `reach` m of it. The flight grades a touch by this: its solid is a
## step, so a finite difference across a wall can only say one of eight ways
## (FlightContact `_slope`), and over the rim a wall is the top's height field,
## where no gradient means much. So: which side of a ball round `p` is rock, on
## shells FACE_SHELLS m past `reach`, which reads the wall at a wing's scale.
func face(p: Vector3, reach: float) -> Vector3:
	var q := Vector2(p.x,p.z)
	var far := reach+FACE_SHELLS.y
	var near := false
	for s: Dictionary in _solids:
		if q.distance_to(s.mid) <= float(s.reach)+far: near = true
	if not near: return Vector3.ZERO
	if _ball.is_empty(): _ball = _ball_ways()
	var rock := Vector3.ZERO
	var hits := 0
	var half := _ball.size()/2
	for k in _ball.size():
		var off: Vector3 = _ball[k]*(reach+(FACE_SHELLS.x if k < half else FACE_SHELLS.y))
		if inside(p+off,0.0):
			rock += off
			hits += 1
	if hits == 0 or rock.length() < 0.001: return Vector3.ZERO
	return -rock.normalized()

## FACE_WAYS ways round a ball, even, twice over: the second shell turned off
## the first so the two together see more ways.
static func _ball_ways() -> PackedVector3Array:
	var out := PackedVector3Array()
	var golden := PI*(3.0-sqrt(5.0))
	for shell in 2:
		for k in FACE_WAYS:
			var y := 1.0-2.0*(k+0.5)/FACE_WAYS
			var a := golden*k+shell*1.1
			out.append(Vector3(cos(a)*sqrt(1.0-y*y),y,sin(a)*sqrt(1.0-y*y)))
	return out

## The highest solid (world y) within `r` m of world XZ `p`, or -INF.
func top_near(p: Vector3, r: float) -> float:
	var best := -INF
	var q := Vector2(p.x,p.z)
	for s: Dictionary in _solids:
		if q.distance_to(s.mid) > float(s.reach)+_pad+r: continue
		var top := _top_at(s,q,_pad+r)
		if top > float(s.rim_y):
			best = maxf(best,top)
			continue
		var k := int(s.slices)-1
		while k >= 0:
			if _gap(s,k,q,_pad+r) > 0.0:
				best = maxf(best,float(s.y0)+k*float(s.dy))
				break
			k -= 2
	return best

## The F1 numbers' line.
func note() -> String:
	return "towers: %d, %dk tris at full detail, levels %s, far %d tris; slowest build %.0f ms on a worker, the body's %.0f ms, commit %.1f ms" % [
		int(stats.towers),int(stats.tris)/1000,str(stats.get("levels",[])),int(stats.get("far_tris",0)),float(stats.build_ms),float(stats.body_ms),float(stats.commit_ms)]
