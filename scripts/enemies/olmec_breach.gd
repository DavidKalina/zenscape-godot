extends Node3D
## Masonry doesn't stop him:
## the roaming Olmec (scripts/enemies/headless_body.gd, `breach` on, this
## its `breacher`) smashes through the city's walls, pillars and parapets
## in the way of his hunt, and the crossings' spans give way under his
## weight. The colonnade's breaks (olmec-destruction-round1/2.md) were
## pre-cut; the city's stone is not (each kit piece is one merged mesh and
## one body of convex hulls, scripts/city_kit.gd `Piece`), so this cuts it
## where he hits it, at run time:
##   - what goes is the piece's hulls (CollisionShape3D) inside the breach
##     box, each a block of masonry: a block wider than BLOCK_MOST flat (a
##     pillar's mass, a terrace) or standing lower than his feet (the floor
##     he is on, the piers under it) is not a wall and stops the breach;
##   - those hulls are switched off, and the mesh's triangles in them
##     (by their middles) cut out of a copy of its mesh (`_cut`);
##   - chunks of the stone fly out the way he punched, a plume, a crack and
##     a boom, a hit-stop and the camera's quake through the layer's hub
##     (scripts/breaks/breakables.gd: `pause`, `shake`, `sound`,
##     `changed`, so every body's routes read the gap afresh).
## The punch is the body's own `smash` beat (fists up, then down: the tell).
## A span (`crack_under`): the crossings' stone under his feet cracks (dust
## sifting, a crack: SPAN_TELL s), then the blocks under him go and he
## falls; a walker on that stretch falls too. Cut off: he has to go round
## (the layer's Olmec brings him back up a cliff, scripts/roguelike/
## layer_olmec.gd).

const Dust = preload("res://scripts/breaks/body_dust.gd")

## A block wider than this (m, flat) is no wall.
const BLOCK_MOST := 9.0
## A block standing lower than this under his feet (m) is his floor or
## what holds it up.
const FLOOR_UNDER := 0.6
## The breach box: his breadth times BREACH_W across, from a step over his
## feet up BREACH_UP neck heights, BREACH_D m deep past where he met it.
const BREACH_W := 0.75
const BREACH_UP := 2.4
const BREACH_D := 3.0
## A span's crack: its tell (s), the stretch that goes (m round his feet,
## m under them), a block on it no wider than SPAN_MOST and no narrower
## than SPAN_LEAST (m: a column top stands).
const SPAN_TELL := 0.75
const SPAN_R := 5.0
const SPAN_DOWN := 10.0
const SPAN_MOST := 26.0
const SPAN_LEAST := 2.0
## Chunks thrown a breach, most; their life (s).
const CHUNKS := 14
const CHUNK_LIFE := 30.0

var field: Node = null
var hub: Node3D = null
## The crossings' stone (layer_stage.gd `stones`), whose spans crack.
var spans: Node3D = null
## Counted, for checks: breaches made, hulls cut, triangles cut, spans
## broken, the last breach's cut (ms).
var breaches := 0
var blocks := 0
var triangles := 0
var spans_broken := 0
var last_ms := 0
var last_at := Vector3.INF
var _cache := {}
var _chunks: Array = []
var _cracks: Array = []

func _init() -> void:
	name = "OlmecBreach"

# --- What may go ----------------------------------------------------------------------

## Whether `body` can smash through what its wall ray `hit`.
func can_breach(body: Node3D, hit: Dictionary) -> bool:
	var col: Object = hit.get("collider")
	if not (col is StaticBody3D) or not is_instance_valid(col): return false
	if WalkerOnly.marked(col) or (col as Node).is_in_group(&"breakable"): return false
	var cut := _cut_list(col,_box(body,hit),body)
	return not cut.is_empty()

## The breach box in front of `body` where `hit` met it (world AABB).
func _box(body: Node3D, hit: Dictionary) -> AABB:
	var fwd := PilotMotor_forward(float(body.facing))
	var at: Vector3 = hit.position
	var half := float(body.width)*BREACH_W
	var lo := float(body.position.y)+float(body.knobs.step)
	var hi := float(body.position.y)+float(body.neck_h)*BREACH_UP
	var mid := Vector3(at.x,0.0,at.z)+fwd*BREACH_D*0.5
	var ext := Vector3(absf(fwd.x)*BREACH_D*0.5+absf(fwd.z)*half,0.0,absf(fwd.z)*BREACH_D*0.5+absf(fwd.x)*half)
	return AABB(Vector3(mid.x-ext.x,lo,mid.z-ext.z),Vector3(ext.x*2.0,hi-lo,ext.z*2.0))

static func PilotMotor_forward(facing: float) -> Vector3:
	var f: Vector2 = preload("res://scripts/pilot_motor.gd").forward(facing)
	return Vector3(f.x,0.0,f.y)

## The hulls of `col` in `box` that go, [] where any is no wall (or one
## is under the walker's feet).
func _cut_list(col: StaticBody3D, box: AABB, body: Node3D) -> Array:
	var feet_y := float(body.position.y) if body != null else -INF
	var under := _walker_shape()
	var out: Array = []
	for e: Array in _shapes(col):
		var cs: CollisionShape3D = e[0]
		if not is_instance_valid(cs) or cs.disabled: continue
		var bb: AABB = e[1]
		if not bb.intersects(box): continue
		if maxf(bb.size.x,bb.size.z) > BLOCK_MOST: return []
		if bb.position.y < feet_y-FLOOR_UNDER: return []
		if cs == under: return []
		out.append(e)
	return out

## The CollisionShape3D the walker stands on, or null.
func _walker_shape() -> CollisionShape3D:
	if field == null: return null
	var m: Object = field.motor
	var q := PhysicsRayQueryParameters3D.create(m.feet+Vector3.UP*0.3,m.feet-Vector3.UP*0.4,field.study.ground.mask)
	var hit: Dictionary = field.study.get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty() or not (hit.collider is CollisionObject3D): return null
	var co: CollisionObject3D = hit.collider
	var owner_id := co.shape_find_owner(int(hit.shape))
	var o: Object = co.shape_owner_get_owner(owner_id)
	return o as CollisionShape3D

## `col`'s hulls with their world boxes (cached while it stands still).
func _shapes(col: StaticBody3D) -> Array:
	var key := col.get_instance_id()
	var c: Dictionary = _cache.get(key,{})
	var xf := col.global_transform
	var n := col.get_child_count()
	if not c.is_empty() and c.xf == xf and int(c.n) == n: return c.list
	var list: Array = []
	for ch: Node in col.get_children():
		var cs := ch as CollisionShape3D
		if cs == null or cs.shape == null: continue
		list.append([cs,_shape_box(cs)])
	_cache[key] = {"xf":xf,"n":n,"list":list}
	return list

static func _shape_box(cs: CollisionShape3D) -> AABB:
	var xf := cs.global_transform
	var sh := cs.shape
	var pts := PackedVector3Array()
	if sh is ConvexPolygonShape3D: pts = (sh as ConvexPolygonShape3D).points
	elif sh is BoxShape3D:
		var h := (sh as BoxShape3D).size*0.5
		for i in 8: pts.append(Vector3(h.x*(1 if i&1 else -1),h.y*(1 if i&2 else -1),h.z*(1 if i&4 else -1)))
	else:
		var bb := sh.get_debug_mesh().get_aabb()
		for i in 8: pts.append(bb.position+bb.size*Vector3(i&1,(i>>1)&1,(i>>2)&1))
	if pts.is_empty(): return AABB(xf.origin,Vector3.ZERO)
	var box := AABB(xf*pts[0],Vector3.ZERO)
	for p: Vector3 in pts: box = box.expand(xf*p)
	return box

# --- The punch ----------------------------------------------------------------------

## The fists come down (the body's `smash` beat): what `hit` met goes.
func smash(body: Node3D, hit: Dictionary) -> void:
	var col: Object = hit.get("collider")
	if not (col is StaticBody3D) or not is_instance_valid(col): return
	var box := _box(body,hit)
	var cut := _cut_list(col,box,body)
	if cut.is_empty(): return
	var fwd := PilotMotor_forward(float(body.facing))
	_take(col,cut,fwd,float(body.hh))
	breaches += 1
	last_at = hit.position
	if body.has_method("stagger"): body.stagger(0.6)
	if hub != null:
		hub.pause(6,0.08)
		hub.shake(0.9)
		hub.sound(&"ruin_crack",hit.position)
		hub.sound(&"ruin_boom",hit.position)
	elif field != null:
		field.sound(&"ruin_boom",hit.position)
	# The walker right in front: knocked back by the stone (no harm: the
	# punch's tell is the windup).
	var m: Object = field.motor
	var to: Vector3 = m.feet-(hit.position as Vector3)
	if Vector2(to.x,to.z).length() < 5.0 and Vector2(to.x,to.z).normalized().dot(Vector2(fwd.x,fwd.z)) > 0.2 and absf(to.y) < 4.0 and not m.seized():
		m.knock(m.knock_velocity(Vector2(fwd.x,fwd.z),float(body.knobs.shove_out),float(body.knobs.shove_up)),body)

## The hulls `cut` of `col` gone: switched off, their stone cut out of the
## mesh, chunks thrown along `push`, the routes told.
func _take(col: StaticBody3D, cut: Array, push: Vector3, hh: float) -> void:
	var t0 := Time.get_ticks_msec()
	var boxes: Array[AABB] = []
	var all := AABB()
	for e: Array in cut:
		(e[0] as CollisionShape3D).disabled = true
		var bb: AABB = e[1]
		boxes.append(bb.grow(0.12))
		all = bb if all.size == Vector3.ZERO else all.merge(bb)
		blocks += 1
	_cache.erase(col.get_instance_id())
	var piece := col.get_parent()
	if piece != null:
		for mi: Node in piece.get_children():
			if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null and (mi as MeshInstance3D).visible:
				_cut(mi as MeshInstance3D,boxes,all)
	_throw(all,push,hh,_material(piece))
	if field != null: Dust.plume(field,all.get_center(),hh*3.0)
	if hub != null: hub.changed(all.grow(2.0))
	elif field != null:
		for e in field.enemies:
			if is_instance_valid(e) and e.has_method("world_changed"): e.world_changed(all.grow(2.0))
	last_ms = Time.get_ticks_msec()-t0

## `mi`'s triangles whose middles are in `boxes` cut out (a copy of its
## mesh, so a mesh shared with another piece keeps them).
func _cut(mi: MeshInstance3D, boxes: Array[AABB], all: AABB) -> void:
	var mesh := mi.mesh
	var xf := mi.global_transform
	if not (xf*mesh.get_aabb()).intersects(all): return
	var inv := xf.affine_inverse()
	# The boxes in the mesh's own frame (a box's corners, re-boxed).
	var local: Array[AABB] = []
	for b: AABB in boxes: local.append(inv*b)
	var any := AABB()
	for b: AABB in local: any = b if any.size == Vector3.ZERO else any.merge(b)
	var out := ArrayMesh.new()
	var cut_n := 0
	for si in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var tris := idx.size()/3 if not idx.is_empty() else verts.size()/3
		var kept := PackedInt32Array()
		kept.resize(tris*3)
		var k := 0
		for t in range(tris):
			var a := idx[t*3] if not idx.is_empty() else t*3
			var b := idx[t*3+1] if not idx.is_empty() else t*3+1
			var c := idx[t*3+2] if not idx.is_empty() else t*3+2
			var mid := (verts[a]+verts[b]+verts[c])/3.0
			var gone := false
			if any.has_point(mid):
				for lb: AABB in local:
					if lb.has_point(mid):
						gone = true
						break
			if gone:
				cut_n += 1
				continue
			kept[k] = a
			kept[k+1] = b
			kept[k+2] = c
			k += 3
		kept.resize(k)
		# A surface cut away whole is left out.
		if k == 0: continue
		arrays[Mesh.ARRAY_INDEX] = kept
		var fmt: int = mesh.surface_get_format(si)
		var flags := 0
		for cu in 4:
			var shift: int = Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT+cu*Mesh.ARRAY_FORMAT_CUSTOM_BITS
			flags |= fmt & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
		out.add_surface_from_arrays(mesh.surface_get_primitive_type(si),arrays,[],{},flags)
		out.surface_set_material(out.get_surface_count()-1,mesh.surface_get_material(si))
	if cut_n == 0: return
	triangles += cut_n
	mi.mesh = out

func _material(piece: Node) -> Material:
	if piece == null: return null
	for mi: Node in piece.get_children():
		if mi is MeshInstance3D and (mi as MeshInstance3D).mesh != null:
			var m: MeshInstance3D = mi
			if m.material_override != null: return m.material_override
			if m.mesh.get_surface_count() > 0: return m.mesh.surface_get_material(0)
	return null

# --- Chunks ---------------------------------------------------------------------------

## Chunks of the stone in `box` thrown along `push` (a share falling
## straight, the rest flung), landing and lying as rubble.
func _throw(box: AABB, push: Vector3, hh: float, mat: Material) -> void:
	var n := clampi(int(box.get_volume()/6.0)+5,5,CHUNKS)
	var rng := RandomNumberGenerator.new()
	rng.seed = breaches*977+blocks
	for i in n:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		var s := rng.randf_range(0.35,1.0)*clampf(hh*0.3,0.5,1.4)
		bm.size = Vector3(s*rng.randf_range(0.8,1.6),s*rng.randf_range(0.6,1.1),s*rng.randf_range(0.8,1.4))
		mi.mesh = bm
		if mat != null: mi.material_override = mat
		add_child(mi)
		var p := box.position+box.size*Vector3(rng.randf(),rng.randf(),rng.randf())
		mi.global_position = p
		mi.rotation = Vector3(rng.randf()*TAU,rng.randf()*TAU,rng.randf()*TAU)
		var v := push*rng.randf_range(3.0,9.0)+Vector3(rng.randf_range(-2.5,2.5),rng.randf_range(1.0,5.0),rng.randf_range(-2.5,2.5))
		_chunks.append({"node":mi,"v":v,"spin":Vector3(rng.randf_range(-4,4),rng.randf_range(-4,4),rng.randf_range(-4,4)),"t":0.0,"rest":false})

func _physics_process(delta: float) -> void:
	_step_cracks(delta)
	if _chunks.is_empty(): return
	var keep: Array = []
	for c: Dictionary in _chunks:
		var node: MeshInstance3D = c.node
		if not is_instance_valid(node): continue
		c.t = float(c.t)+delta
		if float(c.t) > CHUNK_LIFE or node.global_position.y < -2000.0:
			node.queue_free()
			continue
		if not bool(c.rest):
			var v: Vector3 = c.v
			v.y -= 22.0*delta
			var to := node.global_position+v*delta
			var g: float = field.floor_under(to,0.3,maxf(0.3,-v.y*delta+0.3)) if field != null else -INF
			if g != -INF and v.y < 0.0:
				to.y = g+0.25
				# Settled after a bounce or two.
				if v.length() < 4.0: c.rest = true
				v = Vector3(v.x*0.35,-v.y*0.25,v.z*0.35)
			node.global_position = to
			node.rotation += (c.spin as Vector3)*delta*(0.0 if bool(c.rest) else 1.0)
			c.v = v
		keep.append(c)
	_chunks = keep

# --- Spans --------------------------------------------------------------------------

## Whether `body` stands on the crossings' stone (a span).
func on_span(body: Node3D) -> bool:
	if spans == null or not is_instance_valid(spans) or field == null: return false
	var q := PhysicsRayQueryParameters3D.create(body.position+Vector3.UP*1.0,body.position-Vector3.UP*1.2,WalkerOnly.strip(field.study.ground.mask))
	var bb: Object = body.get("body")
	if bb is CollisionObject3D: q.exclude = [(bb as CollisionObject3D).get_rid()]
	var hit: Dictionary = field.study.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit.collider is Node and spans.is_ancestor_of(hit.collider)

## The span under `body` cracks: a tell, then it goes (once a spot).
func crack_under(body: Node3D) -> bool:
	for c: Dictionary in _cracks:
		if (c.at as Vector3).distance_to(body.position) < SPAN_R*1.5: return false
	_cracks.append({"at":body.position,"t":0.0,"body":body,"dust":0.0})
	if hub != null: hub.sound(&"ruin_crack",body.position)
	return true

func _step_cracks(delta: float) -> void:
	if _cracks.is_empty(): return
	var keep: Array = []
	for c: Dictionary in _cracks:
		c.t = float(c.t)+delta
		c.dust = float(c.dust)-delta
		var at: Vector3 = c.at
		if float(c.dust) <= 0.0 and field != null:
			c.dust = 0.18
			Dust.puff(field,at+Vector3(randf_range(-3,3),-0.5,randf_range(-3,3)),1.6)
			Dust.rocks(field,at-Vector3.UP*0.8,Vector3.DOWN,2,0.25)
		if float(c.t) < SPAN_TELL:
			keep.append(c)
			continue
		_break_span(at,c.body)
	_cracks = keep

func _break_span(at: Vector3, body: Variant) -> void:
	if spans == null or not is_instance_valid(spans): return
	var box := AABB(at-Vector3(SPAN_R,SPAN_DOWN,SPAN_R),Vector3(SPAN_R*2.0,SPAN_DOWN+1.0,SPAN_R*2.0))
	for col: Node in spans.find_children("*","StaticBody3D",true,false):
		var cut: Array = []
		for e: Array in _shapes(col as StaticBody3D):
			var cs: CollisionShape3D = e[0]
			if cs.disabled: continue
			var bb: AABB = e[1]
			if not bb.intersects(box): continue
			var wide := maxf(bb.size.x,bb.size.z)
			if wide > SPAN_MOST or wide < SPAN_LEAST: continue
			cut.append(e)
		if cut.is_empty(): continue
		_take(col as StaticBody3D,cut,Vector3.ZERO,3.0)
		spans_broken += 1
	if hub != null:
		hub.pause(4,0.15)
		hub.shake(0.7)
		hub.sound(&"ruin_boom",at)
	if body is Node3D and is_instance_valid(body) and body.has_method("stagger"): body.stagger(1.0)
