extends Node3D
## Breakable temple-kit pieces: a site's few cracked pieces the plane smashes
## through in a hot surge roll (scripts/endless/surge_smash.gd), as it does the
## cracked walls (cracked_walls.gd). Out of a surge each is stone like the rest.
##
## A site (aqueduct_site.gd, street_site.gd, agora_site.gd, arena_site.gd,
## theatre_site.gd, baths_site.gd, tholos_site.gd) leaves the piece out
## of its MultiMeshes and boxes and hands it here instead:
##
##   const TempleBreaks = preload("res://scripts/endless/temple_breaks.gd")
##   breaks = TempleBreaks.new()
##   add_child(breaks)
##   breaks.setup(game)
##   breaks.add("agora/wall_3",&"agora_stoa_wall_cracked",xf,[[&"agora_stoa_wall_holed",xf]])
##   ...
##   breaks.step(eye,quiet)  # each frame, from the site's own step; quiet: no kit build runs
##
## `add`'s name is the pilot book's key (PilotBook `opened`): broken once, it
## stays broken, as a cracked wall does (`--pilot=fresh`: whole again). Its
## piece is the cracked model (art/blender/temple_kit/breaks_build.py), drawn
## alone; its frame is the world's (a uniform scale is fine, a lean is not: the
## solid is the piece's boxes turned about y only). The last list is what is
## left once it's broken, each [piece, world frame].
##
## Standing, a piece is one LandArches `loose` record with a `strike` (SurgeSmash
## `_hit` calls it, then gives the hit's own stop, kick, sound and dust) and a
## StaticBody3D of its boxes on the arches' layer. Struck: the record, the body
## and the model go at once, what is left shows, chunks of the kit's stone fly
## off the plane's line and fall (one pooled MultiMesh, moved here), dust
## bursts along the piece (FlightDebris), and the line gets a `smash` moment
## (LineMoves `smash`, "ruin"). What is left turns solid once the plane is
## ARM_M m clear of it. Nothing is built at the hit: every model, body and solid
## is made when the piece comes within REACH m.

const TempleKit = preload("res://scripts/temple_kit.gd")
const BoxSolid = preload("res://scripts/endless/box_solid.gd")

## `handle` broke, the first time.
signal broken(handle: String)

const REACH := 1600.0
const FREE := 1900.0
## A breakable draws its near mesh this far (m), so its crack shows where a
## fast plane still has to choose.
const NEAR_TO := 340.0
## What is left turns solid once the plane is this far from the hit (m), or
## after ARM_S s.
const ARM_M := 28.0
const ARM_S := 2.0
## The debris: chunks in the pool, how many a break throws, their size (m),
## how long one lies before it sinks away (s) and how long the sinking takes.
const CHUNKS := 72
const THROWN := 44
const SIZE := Vector2(0.45,1.7)
const LIES := Vector2(4.0,7.0)
const SINKS := 1.2
const GRAVITY := 24.0
const CHUNK := &"temple_break_chunk"
## Dust bursts along a broken piece.
const DUSTS := 4

var game: Node3D
## Each: {name, id, xf, left, state ("away", "up"), broken, stood ({node, body,
## record}), rest ([stood]), boxes (world AABBs of its stone, for the debris), floor}.
var pieces: Array = []
## For drivers: breaks so far, the last one's name, the worst strike (us).
var stats := {"broken": 0, "last": "", "worst_us": 0}

## id -> {near, far (meshes), boxes}: the kit's pieces used here (`_take`).
var _kit := {}
var _debris: MultiMeshInstance3D
## Per chunk: [pos, vel, axis, spin, turn, size (Vector3), left (s), down (lying), the ground under it].
var _chunks: Array = []
var _live := 0
var _turn := 0
var _tick := 0
var _rng := RandomNumberGenerator.new()
## Broken pieces whose remains aren't solid yet: [piece, at, since].
var _arming: Array = []

func _init() -> void:
	name = "TempleBreaks"

func setup(g: Node3D) -> void:
	game = g
	_rng.seed = 90417
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = TempleKit.mesh(CHUNK)
	mm.instance_count = CHUNKS
	mm.custom_aabb = AABB(Vector3(-1e5,-1e4,-1e5),Vector3(2e5,2e4,2e5))
	_debris = MultiMeshInstance3D.new()
	_debris.name = "Debris"
	_debris.multimesh = mm
	_debris.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_debris.visible = false
	add_child(_debris)
	for i in CHUNKS:
		mm.set_instance_transform(i,_gone())
		_chunks.append([Vector3.ZERO,Vector3.ZERO,Vector3.UP,0.0,0.0,Vector3.ONE,0.0,false,0.0])

## A breakable: see the header. Its models are loaded here, at setup.
func add(handle: String, id: StringName, xf: Transform3D, left: Array) -> void:
	var b := {"name":handle,"id":id,"xf":xf,"left":left,"state":"away","rest":[],
		"broken":game.book != null and game.book.opened.has(handle)}
	_take(id)
	for e: Array in left: _take(e[0])
	pieces.append(b)

## Piece `id`'s meshes and boxes, loaded now: a site's `setup` runs before any
## kit worker, and the kit's loads hold one lock (a load on a worker with the
## main thread waiting on that lock never ends).
func _take(id: StringName) -> void:
	if _kit.has(id): return
	_kit[id] = {"near":TempleKit.mesh(id),"far":TempleKit.mesh(id,true),"boxes":TempleKit.boxes(id)}

func is_broken(handle: String) -> bool:
	for b: Dictionary in pieces:
		if str(b.name) == handle: return bool(b.broken)
	return false

## The piece named `handle`, or {} (drivers).
func piece(handle: String) -> Dictionary:
	for b: Dictionary in pieces:
		if str(b.name) == handle: return b
	return {}

## One frame: the pieces streamed round the eye (one raised a frame, and only
## when `quiet`: no temple-kit build is on a worker, as way_towers.gd keeps
## those to one at a time), what is left of a broken one made solid behind the
## plane, the debris moved.
func step(eye: Vector3, quiet := true) -> void:
	var raised := not quiet or _kit_building()
	for b: Dictionary in pieces:
		var d := (b.xf as Transform3D).origin.distance_to(eye)
		if str(b.state) == "away":
			if d < REACH and not raised:
				_raise(b)
				raised = true
		elif d > FREE: _lower(b)
	if not _arming.is_empty():
		var p: Vector3 = game.plane.position
		var dt := get_process_delta_time()
		for i in range(_arming.size()-1,-1,-1):
			var e: Array = _arming[i]
			e[2] = float(e[2])+dt
			if p.distance_to(e[1]) < ARM_M and float(e[2]) < ARM_S: continue
			var b: Dictionary = e[0]
			if str(b.state) == "up":
				for s: Dictionary in b.rest: _solid_on(s)
			_arming.remove_at(i)
	if _live > 0: _fly(get_process_delta_time())

## Whether a site beside this one's (way_towers.gd's children) has a chunk on
## a worker now: a site's own `busy` knows only the sites stepped before it.
func _kit_building() -> bool:
	var site := get_parent()
	if site == null or site.get_parent() == null: return false
	for other: Node in site.get_parent().get_children():
		var chunks: Variant = other.get("chunks")
		if not (chunks is Array): continue
		for ch: Variant in chunks:
			if ch is Dictionary and str((ch as Dictionary).get("state","")) == "building": return true
	return false

# --- Standing and gone -----------------------------------------------------

func _raise(b: Dictionary) -> void:
	b.state = "up"
	b.rest = []
	for e: Array in b.left:
		var s := _stand(e[0],e[1],{})
		(s.node as Node3D).visible = bool(b.broken)
		if bool(b.broken): _solid_on(s)
		(b.rest as Array).append(s)
	if bool(b.broken): return
	var whole := _stand(b.id,b.xf,b)
	_solid_on(whole)
	b.stood = whole
	# Its stone as world boxes (the debris starts in them) and the ground under it.
	var boxes: Array = []
	var frame: Transform3D = whole.frame
	for box: AABB in whole.boxes: boxes.append(frame*box)
	b.boxes = boxes
	var o: Vector3 = (b.xf as Transform3D).origin
	b.floor = float(game.field.height(o.x,o.z))

## Piece `id` at `xf` (world): its model (near, then far past NEAR_TO), its
## body off, its record not yet in the flight's solid. `b`: the breakable it
## is (its record gets the `strike`), or {} for stone that stays.
func _stand(id: StringName, xf: Transform3D, b: Dictionary) -> Dictionary:
	var sc := xf.basis.get_scale().x
	var yaw := xf.basis.orthonormalized().get_euler().y
	var frame := Transform3D(Basis(Vector3.UP,yaw),xf.origin)
	var node := Node3D.new()
	node.name = String(id)
	add_child(node)
	node.global_transform = frame
	var model := Node3D.new()
	model.transform = frame.affine_inverse()*xf
	node.add_child(model)
	var kit: Dictionary = _kit[id]
	var far_mesh: Mesh = kit.far
	var near := MeshInstance3D.new()
	near.name = "Mesh"
	near.mesh = kit.near
	if far_mesh != null: near.visibility_range_end = NEAR_TO
	model.add_child(near)
	if far_mesh != null:
		var far := MeshInstance3D.new()
		far.name = "Far"
		far.mesh = far_mesh
		far.visibility_range_begin = NEAR_TO
		model.add_child(far)
	var boxes: Array = []
	var reach := 0.0
	for box: AABB in kit.boxes:
		var a := AABB(box.position*sc,box.size*sc)
		boxes.append(a)
		reach = maxf(reach,maxf(Vector2(a.position.x,a.position.z).length(),Vector2(a.end.x,a.end.z).length()))
		reach = maxf(reach,maxf(Vector2(a.position.x,a.end.z).length(),Vector2(a.end.x,a.position.z).length()))
	var body := StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 0
	body.collision_mask = 0
	for a: AABB in boxes:
		var cs := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = a.size
		cs.shape = shape
		cs.position = a.get_center()
		body.add_child(cs)
	node.add_child(body)
	var record := {"name":"break/%s" % id,"kind":"way","node":node,"pos":frame.origin,"cos":cos(yaw),"sin":sin(yaw),
		"solid":BoxSolid.build(boxes),"reach":reach+BoxSolid.grow_most()+10.0,"spec":{}}
	if b.is_empty(): record["no_break"] = true
	else:
		record["name"] = "break/%s" % b.name
		record["strike"] = Callable(self,"_struck")
		record["breakable"] = b
	return {"node":node,"body":body,"record":record,"boxes":boxes,"frame":frame,"on":false}

func _solid_on(s: Dictionary) -> void:
	if bool(s.on): return
	s.on = true
	(s.body as StaticBody3D).collision_layer = game.arches.LAYER
	# First in the list: where a breakable stands in a gap of its site's stone
	# (an arch walled up), the surge's look ahead finds it before the stone by it.
	game.arches.loose.push_front(s.record)
	GroundNative.bump_loose()

func _solid_off(s: Dictionary) -> void:
	if not bool(s.on): return
	s.on = false
	(s.body as StaticBody3D).collision_layer = 0
	game.arches.loose.erase(s.record)
	GroundNative.bump_loose()

func _drop(s: Dictionary) -> void:
	_solid_off(s)
	if is_instance_valid(s.node): (s.node as Node).queue_free()

func _lower(b: Dictionary) -> void:
	if b.has("stood"): _drop(b.stood)
	b.erase("stood")
	for s: Dictionary in b.rest: _drop(s)
	b.rest = []
	b.state = "away"

# --- The break ---------------------------------------------------------------

## The plane's breaking record `r` at `q` (SurgeSmash `_hit`): the piece gone,
## what is left shown, its stone thrown.
func _struck(r: Dictionary, q: Vector3) -> void:
	var t0 := Time.get_ticks_usec()
	var b: Dictionary = r.breakable
	if bool(b.broken) or not b.has("stood"): return
	b.broken = true
	var s: Dictionary = b.stood
	_solid_off(s)
	(s.node as Node3D).visible = false
	(s.node as Node).queue_free()
	b.erase("stood")
	for left: Dictionary in b.rest: (left.node as Node3D).visible = true
	_arming.append([b,q,0.0])
	var v: Vector3 = game.plane.velocity
	_throw(b,q,v)
	var boxes: Array = b.boxes
	for i in mini(DUSTS,boxes.size()):
		var box: AABB = boxes[(i*boxes.size())/mini(DUSTS,boxes.size())]
		game.debris.burst("dust",box.get_center(),Vector3.UP,true)
	game.sound.shot("thump",1.2,0.6,q)
	game.near.moves.smash(game,"ruin",q,hash(str(b.name)))
	if game.book != null: game.book.open_up(str(b.name))
	stats.broken = int(stats.broken)+1
	stats.last = str(b.name)
	stats.worst_us = maxi(int(stats.worst_us),Time.get_ticks_usec()-t0)
	broken.emit(str(b.name))

## THROWN chunks from the piece's stone near `q`, blown along the plane's way
## `v` (m/s) and out from the hit.
func _throw(b: Dictionary, q: Vector3, v: Vector3) -> void:
	var boxes: Array = b.boxes
	if boxes.is_empty(): return
	var mm := _debris.multimesh
	var way := v.normalized() if v.length() > 1.0 else Vector3.FORWARD
	var speed := clampf(v.length(),20.0,90.0)
	for _i in THROWN:
		# A point in the stone, the nearer the hit the likelier.
		var at := Vector3.ZERO
		for attempt in 4:
			var box: AABB = boxes[_rng.randi_range(0,boxes.size()-1)]
			at = box.position+Vector3(_rng.randf(),_rng.randf(),_rng.randf())*box.size
			if at.distance_to(q) < 9.0+4.0*attempt: break
		var out := at-q
		out = out.normalized() if out.length() > 0.2 else Vector3.UP
		var near := clampf(1.0-at.distance_to(q)/16.0,0.0,1.0)
		var c: Array = _chunks[_turn]
		if not (float(c[6]) > 0.0): _live += 1
		c[0] = at
		c[1] = way*speed*_rng.randf_range(0.08,0.2+0.5*near)+out*_rng.randf_range(2.0,6.0+8.0*near)+Vector3.UP*_rng.randf_range(-1.0,5.0+4.0*near)
		c[2] = Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized()
		c[3] = _rng.randf_range(2.0,9.0)
		c[4] = _rng.randf_range(0.0,TAU)
		var size := _rng.randf_range(SIZE.x,SIZE.y)*(0.7+0.5*_rng.randf())
		c[5] = Vector3(size*_rng.randf_range(0.8,1.6),size,size*_rng.randf_range(0.7,1.3))
		c[6] = _rng.randf_range(LIES.x,LIES.y)+SINKS
		c[7] = false
		c[8] = float(b.floor)
		mm.set_instance_transform(_turn,Transform3D(Basis(c[2],float(c[4])).scaled_local(c[5]),at))
		_turn = (_turn+1)%CHUNKS
	_debris.visible = true

## The chunks' frame: thrown ones fall, turn, hit the ground once and lie;
## lying ones sink away at the end.
func _fly(delta: float) -> void:
	var mm := _debris.multimesh
	_tick += 1
	for i in CHUNKS:
		var c: Array = _chunks[i]
		var left := float(c[6])
		if left <= 0.0: continue
		left -= delta
		c[6] = left
		if left <= 0.0:
			mm.set_instance_transform(i,_gone())
			_live -= 1
			continue
		var pos: Vector3 = c[0]
		var size: Vector3 = c[5]
		if not bool(c[7]):
			var vel: Vector3 = c[1]
			vel.y -= GRAVITY*delta
			pos += vel*delta
			c[4] = float(c[4])+float(c[3])*delta
			# The ground under it, asked a few chunks a frame.
			if (i+_tick)%6 == 0: c[8] = float(game.field.height(pos.x,pos.z))
			var ground := float(c[8])+size.y*0.3
			if pos.y <= ground and vel.y < 0.0:
				pos.y = ground
				if vel.y < -7.0:
					vel = Vector3(vel.x*0.45,-vel.y*0.22,vel.z*0.45)
					c[3] = float(c[3])*0.5
				else: c[7] = true
			c[0] = pos
			c[1] = vel
		elif left > SINKS: continue
		var sunk := 1.0-clampf(left/SINKS,0.0,1.0)
		mm.set_instance_transform(i,Transform3D(Basis(c[2],float(c[4])).scaled_local(size),pos-Vector3.UP*sunk*size.y*1.5))
	if _live <= 0:
		_live = 0
		_debris.visible = false

static func _gone() -> Transform3D:
	return Transform3D(Basis().scaled(Vector3.ONE*0.0001),Vector3(0.0,-9000.0,0.0))
