extends Node3D
## The Olmec field's breakable arena (spec: docs/design/olmec-boss/
## spec-olmec-boss.md, item 1): a horseshoe of tall colossus columns
## (RuinKit `hall_column`), a broken colonnade gate (`arch`), a few
## standing stones and low walls for cover, all breaking through the
## kit-breaks hub (scripts/breaks/breakables.gd, kit_breaks.gd), not a
## breaking system of its own. The west side, the plane's landing run, is
## kept clear (RUN), and so is the middle round the Olmec (OPEN).
##
## Three ways a piece breaks:
##   - his bulk: every headless body in the study's enemies gets the hub as
##     its `breaker`, so he walks into the pieces and breaks them (the hub's
##     `met`, as in the motif yard's --olmec);
##   - an air ball: any DragonAirBlast handed to `watch_blast` (the study's
##     gust shot is watched on its own) hits what it pops on or bursts by,
##     at its strength;
##   - `hit_at(point, radius, strength, source)`: the entry point the head's
##     attacks call.
## A hit at or over a piece's toughness cracks it and, CRACK_BEAT s later,
## it topples into rubble that stays (the hub's cut, fall and rubble). A
## weaker hit (at least CRACK_SHARE of it) cracks it only: a pale split on
## its face, a lean away from the blow, chips and dust; the cracks add up,
## and the one that brings the sum to its toughness topples it.
## `rebuild()` (the study's R) puts the arena back whole.
const Breakables = preload("res://scripts/breaks/breakables.gd")
const KitBreaks = preload("res://scripts/breaks/kit_breaks.gd")
const Dust = preload("res://scripts/breaks/body_dust.gd")
const DragonAirBlast = preload("res://scripts/dragon_air_blast.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")

## The pieces. [id, x, z, facing (deg), seed, weathered]; x, z on the field
## (its middle 0, 0; west -x; the plane parks at -24, 22 nosed north).
## The columns stand a ring COLUMN_R m out, open to the west.
const COLUMN_R := 21.0
const COLUMN_AT := [-100.0,-72.0,-44.0,-16.0,12.0,40.0,68.0,96.0]
## The broken colonnade: a gate arch at the north-east rim, a column lone
## beside it, and a short wall run fallen against it.
const PIECES := [
	["arch",17.5,-25.5,-35.0,7311,0.3],
	["hall_column",27.0,-14.5,0.0,7312,0.35],
	["wall",8.5,-31.0,-20.0,7313,0.25],
	# Low walls: cover between your start (south) and the middle, and
	# across the east.
	["wall",-7.0,14.0,8.0,7321,0.15],
	["wall",8.0,15.5,-12.0,7322,0.15],
	["wall",18.0,22.0,-40.0,7323,0.2],
	["wall",29.0,4.0,80.0,7324,0.2],
	["wall",-6.0,-24.0,15.0,7325,0.2],
]
## Standing stones: [x, z, facing (deg), breadth, height, depth] in walker
## heights; each a stack of rough blocks (so it breaks along its joints).
const STONES := [[-9.5,3.0,20.0,1.6,4.2,0.9],[13.0,4.5,-30.0,1.8,5.0,1.0],
	[-7.0,-12.5,60.0,1.5,3.6,0.8],[15.0,-12.0,10.0,1.9,4.6,1.0]]
## Kept clear: the plane's run (x, z rect: its line x -24, from its stand
## north to the rim, its span and room either side) and the middle round
## the Olmec (OPEN m).
const RUN := Rect2(-31.0,-40.0,14.0,70.0)
const OPEN := 8.0

## What a gust shot's ball hits pieces with, and how near its pop or burst
## (m, past the ball) a piece takes it.
const GUST_STRENGTH := 0.3
const BALL_REACH := 0.8
## A hit of at least this share of a piece's toughness cracks it.
const CRACK_SHARE := 0.3
## A standing stone's toughness (a column's, `pier`, is 0.5).
const STONE_TOUGH := 0.6
## The big pieces (the columns too): his charge stops short at them
## (`big_ahead`) and smashes through the rest.
const BIG := ["arch","hall_column"]
## A crack to its fall (s).
const CRACK_BEAT := 0.22
## A crack's lean (rad), the most cracks lean it.
const CRACK_LEAN := 0.035
const LEAN_MOST := 0.1

## The study (studies/olmec_field.gd): its ground, enemies, gust shot.
var study: Node = null
var hub: Node3D = null
var kit_breaks: Node3D = null
var pieces: Node3D = null
## Counts, for checks: cracks made, breaks begun by a hit (not his bulk).
var cracks := 0
var hit_breaks := 0
## Damage so far: {piece instance id: strength summed}.
var _damage := {}
## Breaks waiting their beat: [{node, at, dir, t}].
var _pending: Array = []
## Watched blasts: {instance id: [blast, strength]}.
var _blasts := {}
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "Arena"

## Built on `the_study`'s field (its enemies already up).
func setup(the_study: Node) -> void:
	study = the_study
	hub = Breakables.new()
	hub.field = study.get("enemies")
	add_child(hub)
	_build()

## The arena back whole: every piece, crack and rubble gone, built again.
func rebuild() -> void:
	_pending.clear()
	_damage.clear()
	if kit_breaks != null:
		hub.others.erase(kit_breaks)
		kit_breaks.queue_free()
		remove_child(kit_breaks)
	if pieces != null:
		pieces.queue_free()
		remove_child(pieces)
	_build()
	hub.changed(AABB(Vector3(-50.0,_ground(0.0,0.0)-5.0,-50.0),Vector3(100.0,40.0,100.0)))

func _build() -> void:
	_rng.seed = 7301
	pieces = Node3D.new()
	pieces.name = "ArenaPieces"
	add_child(pieces)
	for i in range(COLUMN_AT.size()):
		var a := deg_to_rad(float(COLUMN_AT[i]))
		var at := Vector2(cos(a),sin(a))*COLUMN_R
		# Every other one broken off low (weathered: shorter, rubble at its foot).
		_place(RuinKit.piece("hall_column",7200+i,0.05 if i%2 == 0 else 0.32),at,float(i)*37.0,true)
	for p: Array in PIECES:
		_place(RuinKit.piece(str(p[0]),int(p[4]),float(p[5])),Vector2(float(p[1]),float(p[2])),float(p[3]),str(p[0]) in BIG)
	for i in range(STONES.size()):
		var s: Array = STONES[i]
		_place(_stone(i),Vector2(float(s[0]),float(s[1])),float(s[2]))
	kit_breaks = KitBreaks.new()
	kit_breaks.name = "KitBreaks"
	kit_breaks.hub = hub
	kit_breaks.field = hub.field
	kit_breaks.lost_y = float(study.get("lost")) if study != null and study.get("lost") != null else -INF
	add_child(kit_breaks)
	var n: int = kit_breaks.adopt(pieces)
	for node: Node in pieces.get_children():
		if node.has_meta("arena_rebuild") and kit_breaks.add(node as Node3D,"pier",node.get_meta("arena_rebuild") as Callable,hash(node.name)) >= 0: n += 1
	hub.others.append(kit_breaks)
	print("olmec arena: %d breakable piece(s)" % n)

func _place(node: Node3D, at: Vector2, face_deg: float, big := false) -> void:
	if node == null: return
	if big: node.set_meta("arena_big",true)
	pieces.add_child(node)
	node.position = Vector3(at.x,_ground(at.x,at.y)-0.15,at.y)
	node.rotation.y = deg_to_rad(face_deg)

## Standing stone `i`: two or three rough blocks stacked, each a little
## narrower, a pier to the breaks (cut along its joints).
func _stone(i: int) -> Node3D:
	var s: Array = STONES[i]
	var w := DragonAirBlast.walker_tall()
	var size := Vector3(float(s[3]),float(s[4]),float(s[5]))*w
	var make := func() -> Node3D:
		var b: RuinKit.Build = RuinKit.Build.new(7400+i,0.4,"Stone%d" % i)
		b.ground = 0.0
		var n := 3 if size.y > 4.5 else 2
		var y := 0.0
		for k in range(n):
			var h := size.y/float(n)*(1.08 if k == 0 else 0.96)
			var shrink := 1.0-0.08*float(k)
			RuinKit._sarsen(b,Transform3D(Basis(Vector3.UP,0.08*float(k)-0.05),Vector3(0.0,y,0.0)),Vector3(size.x*shrink,h-0.3,size.z*shrink),0.1)
			y += h
		return b.finish()
	var node: Node3D = make.call()
	node.set_meta("toughness",STONE_TOUGH)
	# Not tagged (adopt would take it without a rebuild): `_build` adds it
	# with its own build as the rebuild.
	node.set_meta("arena_rebuild",make)
	return node

func _ground(x: float, z: float) -> float:
	if study != null and study.has_method("_ground_y"): return float(study.call("_ground_y",x,z))
	return 0.0

# --- Hits -------------------------------------------------------------------------------------

## The entry point: a hit at `point` (world) reaching `radius` m, at
## `strength` (the Olmec's bulk is 1.0; a column, `pier`, takes 0.5, a
## wall or the gate 0.6, a standing stone 0.6), from `source` (a hub
## breaker: &"olmec" by default; one that is off does nothing). Every
## piece within reach cracks or, hit hard enough, cracks and topples a
## beat later. Returns how many pieces it cracked or set falling.
func hit_at(point: Vector3, radius: float, strength: float, source: StringName = &"olmec", spare_big := false) -> int:
	if kit_breaks == null or hub == null or not hub.allows(source): return 0
	var n := 0
	for i in range(kit_breaks.targets.size()):
		var t: Dictionary = kit_breaks.targets[i]
		if not t.alive or not is_instance_valid(t.node): continue
		var node: Node3D = t.node
		if _is_pending(node) or (spare_big and node.has_meta("arena_big")): continue
		var q: Vector3 = kit_breaks._nearest(t,point)
		if q.distance_to(point) > radius: continue
		var tough := float(t.tough)
		if strength < tough*CRACK_SHARE: continue
		var id := node.get_instance_id()
		var sum := float(_damage.get(id,0.0))+strength
		_damage[id] = sum
		var dir := _away(t,point,q)
		_crack(node,q,dir)
		n += 1
		if strength >= tough or sum >= tough:
			_pending.append({"node":node,"at":q,"dir":dir,"t":CRACK_BEAT})
	return n

## How far along `way` (flat, unit) from `from` a big piece still standing
## comes within `half_w` m of the line, looked at up to `reach` m (INF
## none).
func big_ahead(from: Vector3, way: Vector3, reach: float, half_w: float) -> float:
	if kit_breaks == null: return INF
	var best := INF
	for t: Dictionary in kit_breaks.targets:
		if not t.alive or not is_instance_valid(t.node): continue
		var node: Node3D = t.node
		if not node.has_meta("arena_big") or _is_pending(node): continue
		var d := 0.0
		while d <= minf(reach,best):
			var p := from+way*d
			var q: Vector3 = kit_breaks._nearest(t,p)
			if Vector2(q.x-p.x,q.z-p.z).length() < half_w and q.y > from.y-0.5:
				best = d
				break
			d += 0.5
	return best

## Air balls from `blast` (a DragonAirBlast) hit pieces where they pop or
## burst, at `strength`, from `source`.
func watch_blast(blast: Node, strength: float, source: StringName = &"olmec") -> void:
	if blast == null or _blasts.has(blast.get_instance_id()): return
	_blasts[blast.get_instance_id()] = [blast,strength]
	var on_hit := func(at: Vector3) -> void: hit_at(at,DragonAirBlast.ball_radius()+BALL_REACH,strength,source)
	blast.landed.connect(on_hit)
	blast.broke.connect(on_hit)

## Whether any piece stands or lies in the plane's run (`RUN`): a standing
## piece's middle, a falling or settled part's place.
func run_clear() -> bool:
	return _in_run().is_empty()

func _in_run() -> Array:
	var out: Array = []
	if kit_breaks == null: return out
	for n: Node in kit_breaks.find_children("*","Node3D",true,false):
		var p := (n as Node3D).global_position
		if (n is RigidBody3D or n.name.begins_with("Rubble")) and RUN.has_point(Vector2(p.x,p.z)): out.append(n)
	for t: Dictionary in kit_breaks.targets:
		if not t.alive or not is_instance_valid(t.node): continue
		var c: Vector3 = (t.node as Node3D).global_transform*(t.box as AABB).get_center()
		if RUN.has_point(Vector2(c.x,c.z)): out.append(t.node)
	return out

## Standing pieces now (whole or what stands of a broken one).
func standing() -> int:
	var n := 0
	if kit_breaks == null: return 0
	for t: Dictionary in kit_breaks.targets:
		if t.alive and is_instance_valid(t.node): n += 1
	return n

func _is_pending(node: Node3D) -> bool:
	for p: Dictionary in _pending:
		if p.node == node: return true
	return false

## The way a hit at `from` drives target `t` (flat, world), its nearest `q`.
func _away(t: Dictionary, from: Vector3, q: Vector3) -> Vector3:
	var out := Vector3(q.x-from.x,0.0,q.z-from.z)
	if out.length() < 0.05:
		var c: Vector3 = (t.node as Node3D).global_transform*(t.box as AABB).get_center()
		out = Vector3(c.x-from.x,0.0,c.z-from.z)
	return out.normalized() if out.length() > 0.05 else Vector3.FORWARD

## A crack on `node` at `at` (world): a split of fresh stone drawn on its face, a lean
## away from the blow about its foot, chips and dust.
func _crack(node: Node3D, at: Vector3, dir: Vector3) -> void:
	cracks += 1
	var xf := node.global_transform
	var lean_now := float(node.get_meta("arena_lean",0.0))
	var lean := minf(CRACK_LEAN,LEAN_MOST-lean_now)
	if lean > 0.0:
		node.set_meta("arena_lean",lean_now+lean)
		var axis := Vector3.UP.cross(dir).normalized()
		node.global_transform = Transform3D(Basis(axis,lean)*xf.basis,xf.origin)
	var mark := _split_mesh(_rng.randf_range(1.8,2.6))
	node.add_child(mark)
	mark.name = "Crack"
	mark.global_transform = Transform3D(Basis.looking_at(-dir,Vector3.UP).rotated(-dir,_rng.randf_range(-0.5,0.5)),at-dir*0.06)
	Dust.puff(self,at,1.4,-dir)
	Dust.rocks(self,at,-dir,6,0.18)
	hub.shake(0.12)
	hub.sound(&"ruin_crack",at)

## A pale jagged split (fresh stone) `length` m long, in its own XY plane.
func _split_mesh(length: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	var segs := 7
	for k in range(segs+1):
		var y := (float(k)/float(segs)-0.5)*length
		pts.append(Vector3(_rng.randf_range(-0.18,0.18),y,0.0))
	for k in range(segs):
		var a := pts[k]
		var b := pts[k+1]
		var wa := 0.11*(1.0-absf(float(k)/float(segs)-0.5)*1.6)+0.015
		var wb := 0.11*(1.0-absf(float(k+1)/float(segs)-0.5)*1.6)+0.015
		var side := Vector3.RIGHT
		for v: Vector3 in [a-side*wa,a+side*wa,b+side*wb,a-side*wa,b+side*wb,b-side*wb]: st.add_vertex(v)
		# A branch off the middle.
		if k == segs/2:
			var c := b+Vector3(_rng.randf_range(0.3,0.5)*(1.0 if _rng.randf() < 0.5 else -1.0),_rng.randf_range(-0.2,0.2),0.0)
			for v: Vector3 in [b-side*0.03,b+side*0.03,c,]: st.add_vertex(v)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.86,0.78,0.62)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

# --- The loop ---------------------------------------------------------------------------------

func _process(delta: float) -> void:
	_wire_breakers()
	# The study's gust shot (made at its first shot).
	var gust: Variant = study.get("gust_shot") if study != null else null
	if gust is Node and is_instance_valid(gust) and (gust as Node).get("blast") != null:
		watch_blast((gust as Node).get("blast"),GUST_STRENGTH)
	for p: Dictionary in _pending.duplicate():
		p.t = float(p.t)-delta
		if float(p.t) > 0.0: continue
		_pending.erase(p)
		# Broken meanwhile another way (a shockwave through the hub): gone.
		if not is_instance_valid(p.node): continue
		_fell(p.node,p.at,p.dir)

## Every headless body breaks through the hub (a new one after R too).
func _wire_breakers() -> void:
	var field: Variant = study.get("enemies") if study != null else null
	if not field is Node or not is_instance_valid(field): return
	hub.field = field
	if kit_breaks != null: kit_breaks.field = field
	for e: Node in (field as Node).get("enemies"):
		if is_instance_valid(e) and e.has_method("world_changed") and e.get("breaker") == null: e.breaker = hub

## Its crack's beat out: `node` cut and fallen (the hub's break).
func _fell(node: Node3D, at: Vector3, dir: Vector3) -> void:
	if not is_instance_valid(node) or kit_breaks == null: return
	for i in range(kit_breaks.targets.size()):
		var t: Dictionary = kit_breaks.targets[i]
		if t.node != node or not t.alive: continue
		if kit_breaks._break(i,at,dir,dir*2.0,null):
			hit_breaks += 1
			kit_breaks._pause()
		return

