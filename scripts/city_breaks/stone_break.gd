extends Node3D
## What city breaks round 2's pieces share (scripts/city_kit_breaks2.gd builds
## them): a piece of
## the breakables hub (scripts/kit_isle/breakables.gd), its stone, its
## scripted falls, its hits on the wanderer, and its word to the bodies'
## planners when its rest is down.
##
## The three-state rule:
## every piece is authored whole, cracked (a tell, the same collision) and
## fallen (an authored rest: clean walk boxes, ground to the walker and to
## the Olmec's rays and planner). What flies between is the show: scripted
## transforms (no Jolt bodies, so no piece ever touches the 24-body cap),
## steered into the rest, and the rest's collision goes in when they land.
##
## A piece answers the hub's calls (`standing_rids`, `rubble_rids`, `met`,
## `wave`, `takes_shock`) and the slam's (scripts/slam.gd GROUP: `slam(at,
## radius, strength)`). Subclasses override `_met`, `_wave`, `_slam`, `_step`.
const Stone = preload("res://scripts/city_kit_stone.gd")
const Dust = preload("res://scripts/enemies/body_dust.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const HeadlessBody = preload("res://scripts/enemies/headless_body.gd")
const Slam = preload("res://scripts/slam.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const BREAKABLE := &"breakable"

## The city's measures (scripts/city_kit.gd's, from the walker's numbers;
## not preloaded from there: that file is another round's).
const CELL := RuinKit.BAY
const SET_OFF := RuinKit.SET_OFF
const COURSE := 3.0*SET_OFF
## His lane (his bulk with his arms needs 8.8 m).
const LANE := 2.0*CELL
## The Olmec's stride in the city (city_kit_breaks.gd OLMEC_STEP).
const OLMEC_STEP := 2.4
## Every rest shape's foot is kept LIFT m clear of what it rests on (city
## breaks round 1: his planner's room ray starts 0.1 m over a floor, so a
## solid flush on the ground leaves a phantom floor under it).
const LIFT := 0.15
## Fresh-cut stone's tone (pale: the break's read in the haze).
const FRESH := 1.45

## "whole", "cracked", "falling", "fallen".
var state := "whole"
## What broke it: "body", "shock", "slam", "code".
var cause := ""
## The hits it dealt the wanderer: [source, kind].
var dealt: Array = []
## Seconds from the break to its rest (for the handoff).
var fall_s := 0.0
var seed_value := 1
var weathered := 0.0
var _hub: Node = null
var _sources := {}
var _tell_box := AABB()
var _tell_in := 0
var _rng := RandomNumberGenerator.new()

func _setup(id: String, seed_in: int, weathered_in: float) -> void:
	name = id
	seed_value = seed_in
	weathered = weathered_in
	_rng.seed = seed_in*7919+13
	add_to_group(BREAKABLE)
	add_to_group(Slam.GROUP)

## The node a hit on the wanderer is from (the motor keeps one stun gap per
## source node): one per name, a child of the piece.
func source(source_name: String) -> Node:
	if not _sources.has(source_name):
		var n := Node.new()
		n.name = source_name
		add_child(n)
		_sources[source_name] = n
	return _sources[source_name]

# --- The hub's calls -------------------------------------------------------------------

func standing_rids() -> Array[RID]:
	return []

func rubble_rids() -> Array[RID]:
	return []

func met(hub: Node, b: Node3D) -> void:
	_hub = hub
	_met(b)

func wave(hub: Node, b: Node3D, w: Dictionary) -> void:
	_hub = hub
	var key := "sb_%d" % get_instance_id()
	if w.has(key): return
	if _wave(b,w): w[key] = true

func takes_shock(_hub_in: Node, _b: Node3D, _w: Dictionary) -> bool:
	return false

## The wanderer's slam (scripts/slam.gd GROUP).
func slam(at: Vector3, radius: float, strength: float) -> void:
	_slam(at,radius,strength)

func _met(_b: Node3D) -> void:
	pass

## True once this wave is done with (it won't be asked again).
func _wave(_b: Node3D, _w: Dictionary) -> bool:
	return true

func _slam(_at: Vector3, _radius: float, _strength: float) -> void:
	pass

# --- Services --------------------------------------------------------------------------

## The hub: the one that called last, else the scene's (a slam can come first).
func hub() -> Node:
	if _hub != null and is_instance_valid(_hub): return _hub
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null:
		for n: Node in scene.find_children("Breakables","",true,false):
			if n.has_method("changed"):
				_hub = n
				return n
	return null

func motor() -> PilotMotor:
	var h := hub()
	return h.motor() as PilotMotor if h != null else null

## The scene's Olmecs (whole or headless bodies), for a rest laid on one.
func bodies() -> Array:
	var out: Array = []
	var h := hub()
	if h == null or h.field == null: return out
	for e in h.field.enemies:
		if is_instance_valid(e) and e.has_method("world_changed") and e.get("hh") != null: out.append(e)
	return out

func _sound(n: StringName, at: Vector3) -> void:
	var h := hub()
	if h != null: h.sound(n,at)

func _shake(k: float) -> void:
	var h := hub()
	if h != null: h.shake(k)

func _pause(frames: int, scale: float) -> void:
	var h := hub()
	if h != null: h.pause(frames,scale)

## The bodies' routes read `box` (world) afresh, two physics frames on (once
## the rest's shapes are in the space: told the same frame, the planner
## read the old columns).
func tell(box: AABB) -> void:
	_tell_box = box if _tell_in <= 0 else _tell_box.merge(box)
	_tell_in = 2

## A hit on the wanderer from `source_name`: a knock (stunned already: a
## toss, still stunned), or a toss (`toss`: no stun).
func hit(m: PilotMotor, source_name: String, kind: String, v: Vector3, toss := false, down := 0.0) -> void:
	if toss or m.move == "tumble": m.toss(v)
	else:
		m.knock(v,source(source_name),down)
		m.harm("stone",1,source(source_name))
	dealt.append([source_name,kind])
	var h := hub()
	if h != null: h.knocked(source_name,kind,v)

func _physics_process(delta: float) -> void:
	if _tell_in > 0:
		_tell_in -= 1
		if _tell_in == 0:
			var h := hub()
			if h != null: h.changed(_tell_box)
	_step(delta)

func _step(_delta: float) -> void:
	pass

# --- Stone -------------------------------------------------------------------------------

## A mesher in the city's stone.
static func mesher(moss := 0.25) -> Stone.Mesher:
	Stone.warm()
	return Stone.Mesher.new(Stone.stone_colour(),moss)

## A block into `m`: `size` m, at `xf` (its middle), chamfered `bevel`,
## lighter or darker `tone`.
static func block(m: Stone.Mesher, xf: Transform3D, size: Vector3, bevel := 0.12, tone := 1.0) -> void:
	m.solid(Stone.box(xf,size*0.5,minf(bevel,minf(size.x,minf(size.y,size.z))*0.3)),NAN,tone)

## A part's mesh: `blocks` [[xf, size, tone]] in the piece's frame, drawn
## round `centre` (the part's own origin), its grain where it stood.
static func part_mesh(blocks: Array, centre: Transform3D, moss := 0.25, runes: Array = []) -> ArrayMesh:
	var m := mesher(moss)
	m.rest_frame = centre
	var inv := centre.affine_inverse()
	for b: Array in blocks:
		var xf: Transform3D = b[0]
		var size: Vector3 = b[1]
		block(m,inv*xf,size,0.12 if b.size() < 4 else float(b[3]),float(b[2]) if b.size() > 2 else 1.0)
	for r: Array in runes:
		m.runes(inv*(r[0] as Vector3),inv*(r[1] as Vector3),(inv.basis*(r[2] as Vector3)).normalized(),(inv.basis*(r[3] as Vector3)).normalized(),float(r[4]))
	return Stone.mesh_of(m)

static func box_shape(on: CollisionObject3D, size: Vector3, xf: Transform3D, shape_name := "") -> CollisionShape3D:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.transform = xf
	if shape_name != "": c.name = shape_name
	on.add_child(c)
	return c

## A static body with `boxes` [[xf, size]] (piece frame) as its shapes.
func static_body(body_name: String, boxes: Array) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = body_name
	add_child(body)
	for b: Array in boxes: box_shape(body,b[1],b[0])
	return body

## A mesh instance named `n` with `mesh`, at `xf`, under this.
func mesh_node(n: String, mesh: Mesh, xf := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = n
	mi.mesh = mesh
	mi.transform = xf
	add_child(mi)
	return mi

## A box at `centre` (piece frame) `size` across: its transform.
static func at(centre: Vector3, yaw := 0.0, pitch := 0.0, roll := 0.0) -> Transform3D:
	return Transform3D(Basis.from_euler(Vector3(pitch,yaw,roll)),centre)

## The highest of `boxes` [[xf, size]] (piece frame, axis-aligned tops)
## under world point `p` (its top, world y), -INF none.
func top_under(boxes: Array, p: Vector3) -> float:
	var local := to_local(p)
	var best := -INF
	for b: Array in boxes:
		var xf: Transform3D = b[0]
		var size: Vector3 = b[1]
		var q := xf.affine_inverse()*local
		if absf(q.x) <= size.x*0.5 and absf(q.z) <= size.z*0.5:
			best = maxf(best,(xf*Vector3(0.0,size.y*0.5,0.0)).y)
	return to_global(Vector3(0.0,best,0.0)).y if best > -INF else -INF

## An Olmec whose feet are inside the rest just laid is set on it (else his
## floor ray starts in the stone and he stands sunk in it).
func lift_bodies(boxes: Array) -> void:
	for b: Node3D in bodies():
		var top := top_under(boxes,b.position)
		if top > b.position.y+0.05 and top < b.position.y+COURSE*2.0:
			b.position.y = top
			if b.has_method("stagger"): b.stagger(1.0)

## The world AABB of `boxes` [[xf, size]] in the piece frame, grown `grow`.
func world_box(boxes: Array, grow := 2.0) -> AABB:
	var out := AABB()
	var first := true
	for b: Array in boxes:
		var xf: Transform3D = b[0]
		var size: Vector3 = b[1]
		for sx: float in [-0.5,0.5]:
			for sy: float in [-0.5,0.5]:
				for sz: float in [-0.5,0.5]:
					var p := to_global(xf*Vector3(size.x*sx,size.y*sy,size.z*sz))
					if first:
						out = AABB(p,Vector3.ZERO)
						first = false
					else: out = out.expand(p)
	return out.grow(grow)

## Scripted flights (a piece let go): each {node, from, to (local
## transforms), delay, dur (s), arc (m up mid-flight), t, landed, ...}.
## Eased in as a fall is (slow first: weight), turned from `from` to `to`.
var flights: Array = []

## `node` flown from where it is to `to` (its parent's frame) after `delay`
## s, over `dur` s, lifted `arc` m mid-flight; `extra` kept on the flight.
func fly(node: Node3D, to: Transform3D, delay: float, dur: float, arc := 0.0, extra := {}) -> Dictionary:
	var f := {"node":node,"from":node.transform,"to":to,"delay":delay,"dur":maxf(dur,0.05),"arc":arc,"t":0.0,"landed":false}
	f.merge(extra,true)
	flights.append(f)
	return f

## A frame of the flights: true while any is still in the air.
func fly_step(delta: float) -> bool:
	var busy := false
	for f: Dictionary in flights:
		if f.landed: continue
		busy = true
		f.t = float(f.t)+delta
		var k := clampf((float(f.t)-float(f.delay))/float(f.dur),0.0,1.0)
		if float(f.t) < float(f.delay): continue
		var a: Transform3D = f.from
		var b: Transform3D = f.to
		var kk := k*k
		var p := a.origin.lerp(b.origin,kk)+Vector3.UP*float(f.arc)*sin(PI*k)
		var q := a.basis.orthonormalized().get_rotation_quaternion().slerp(b.basis.orthonormalized().get_rotation_quaternion(),smoothstep(0.0,1.0,k))
		var s := a.basis.get_scale()
		(f.node as Node3D).transform = Transform3D(Basis(q).scaled(s),p)
		if k >= 1.0:
			f.landed = true
			_landed(f)
	return busy

## A flight came down (override): its dust, its hit.
func _landed(_f: Dictionary) -> void:
	pass

## Dust down a line (world points), every `step` m.
func dust_line(a: Vector3, b: Vector3, size: float, step := 3.0) -> void:
	var n := maxi(1,int(a.distance_to(b)/step))
	for i in n+1:
		Dust.plume(get_parent(),a.lerp(b,float(i)/n),size)
