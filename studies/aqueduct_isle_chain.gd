extends Node3D
## The end of the aqueduct isle's loop (docs/design/isle-hall-chain.md):
## the ring by the lodestone's shard, and the hall chain it starts.
##
## The plane flies where the nose arrow points (the shard, studies/
## aqueduct_isle.gd `lode_target`). Coming near with the stone seated, a
## gothic arch on a keel of lode stone rises quietly out of the cloud sea
## past the shard (`ring`): no beacon, no glow, no pulse, and the arrow
## goes on pointing at the shard. Threading its opening is the only thing
## that counts (crossing its plane outside the opening, or flying round it,
## does nothing; you can come round and go through). Then nothing happens
## for `pause` s (a held breath); then `started` (the isle runs its pulse
## through the plane) and the first Sundered hall starts rising out of the
## cloud dead ahead, on the heading the plane left the ring with, its way
## in `lead` m on, so the plane flies straight into its gate. From there
## it is the hall chain (scripts/hall_chain.gd) as its study has it.
##
## The cloud sea is the hall chain's greybox sea (shaders/
## isle_cloud_sea.gdshader), a patch of it round the ring and the halls
## that follows the chain, breaking up into clumps at its rim and kept
## off the isle (its hole): the isle's own clouds are the sky's, drawn at
## infinity, which nothing can rise through. Its top is SEA_TOP.
##
## The isle calls `setup`, then `step` every frame (with the plane while
## flying), and asks `floor_at` for the plane's cloud floor over the patch.

const Chain = preload("res://scripts/hall_chain.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Lodestone = preload("res://scripts/lodestone.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SEA_SHADER := preload("res://shaders/isle_cloud_sea.gdshader")

## The cloud top (world) and how far under it the sea's mesh sits (its
## heaps stand up to 7 m over that; the chain study's is the same).
const SEA_TOP := 0.0
const SEA_BASE := 3.0
## The patch: opaque out to PATCH.x m from its centre, gone by PATCH.y more;
## round the isle's middle (ISLE) none within HOLE.x, all by HOLE.y more.
const PATCH := Vector2(420.0,120.0)
const HOLE := Vector2(220.0,100.0)
const ISLE := Vector2(85.0,-20.0)
## The patch's centre follows the chain over this long (s).
const FOLLOW := 4.0
## The ring: RING_PAST m on past the shard (on the line from the isle's
## middle to it) and RING_ASIDE m to its left, its opening's middle at
## RING_UP (world), facing along that line. The kit's pointed arch at RING_SCALE: a clear span of 9.2 m and a
## crown 15 m over its feet (the wooden plane is 1.4 m across). The plane
## threads it THREAD_UP m over its feet.
const RING_PAST := 90.0
const RING_ASIDE := 35.0
const RING_UP := 25.0
const RING_SCALE := 2.2
const THREAD_UP := 6.0
const RING_SEED := 52
const RING_WEATHERED := 0.25
## Its keel: half across, half deep, how deep it hangs (m).
const KEEL := Vector3(10.5,5.0,9.0)
## It rises when the plane is within RING_NEAR m with the stone seated,
## over RING_RISE s from RING_DROP m down (under the cloud), easing to a
## stop. Its sea swell (the hall rise's) as it breaks through.
const RING_NEAR := 230.0
const RING_RISE := 6.0
const RING_DROP := 46.0
const RING_SWELL := Vector2(16.0,3.0)
## The held breath after threading it (s), and how far on the first hall's
## way in stands (m; its gate is ChainPlan.LEAD_IN more). At cruise the
## plane gets to the gate about as the gate settles.
const PAUSE := 1.5
const LEAD := 180.0
## The first hall's hand: mirrored (it swings you left), so the chain's S
## runs north-north-west from the ring, into open sky.
const HAND := -1
## The margin (m) the plane's middle keeps inside the opening's stone.
const OPEN_MARGIN := 0.6

signal passed
signal started

var chain: Node3D
var ring: Node3D
var _lift: Node3D
var arch: Node3D
## The pass point (world: the opening's middle at the plane's height) and
## the way the ring faces (rad, SkyPlane's heading).
var ring_at := Vector3.ZERO
var ring_heading := 0.0
## "hidden", "rising", "standing", "passed" (the pause), "started".
var state := "hidden"
var rise_clock := 0.0
var pause := PAUSE
var pause_left := 0.0
var lead := LEAD
## Where and on what heading the plane threaded it.
var pass_point := Vector3.INF
var pass_heading := 0.0
## Crossings of the ring's plane outside the opening (the tests).
var misses := 0
var sea: MeshInstance3D
var patch_centre := Vector2.ZERO
var _bodies: Array[CollisionObject3D] = []
var _prev := Vector3.INF

func _init() -> void:
	name = "IsleChain"

## The ring past `target` (or at --ring=x,y,z), the sea, the chain (planned,
## not started). Flags: --ring=x,y,z (the opening's middle), --ring-pause=<s>,
## --chain-lead=<m>, and the chain's and rise's (scripts/hall_chain.gd,
## scripts/hall_rise.gd `options`).
func setup(target: Vector3, args: PackedStringArray) -> void:
	var way := Vector2(target.x-ISLE.x,target.z-ISLE.y).normalized()
	# Left of the line (as you fly out), so its axis runs past the shard's
	# keel, not under it.
	var left := Vector2(way.y,-way.x)
	ring_at = Vector3(target.x+way.x*RING_PAST+left.x*RING_ASIDE,RING_UP,target.z+way.y*RING_PAST+left.y*RING_ASIDE)
	for a: String in args:
		var v := a.get_slice("=",1)
		if a.begins_with("--ring="):
			var p := v.split(",")
			if p.size() == 3: ring_at = Vector3(float(p[0]),float(p[1]),float(p[2]))
		elif a.begins_with("--ring-pause="): pause = maxf(0.0,float(v))
		elif a.begins_with("--chain-lead="): lead = maxf(40.0,float(v))
	# It faces out along the isle-to-shard line.
	ring_heading = atan2(-way.x,-way.y)
	_build_sea()
	_build_ring()
	patch_centre = Vector2(ring_at.x,ring_at.z)
	chain = Chain.new()
	chain.sea_top = SEA_TOP
	chain.plane_box = Callable()
	add_child(chain)
	chain.configure(Chain.options(args),Rise.options(args))

## How much cloud sea there is at `p` (0-1), as the sea's shader has it.
func cover(p: Vector3) -> float:
	var w := Vector2(p.x,p.z)
	var inside := 1.0-smoothstep(PATCH.x,PATCH.x+PATCH.y,w.distance_to(patch_centre))
	var clear := smoothstep(HOLE.x,HOLE.x+HOLE.y,w.distance_to(ISLE))
	return inside*clear

## The plane's cloud floor at `p`: the sea's top where there is sea, else
## `otherwise`.
func floor_at(p: Vector3, otherwise: float) -> float:
	return SEA_TOP if cover(p) > 0.5 else otherwise

func _build_sea() -> void:
	var mesh := PlaneMesh.new()
	var across := (PATCH.x+PATCH.y)*2.0+40.0
	mesh.size = Vector2(across,across)
	mesh.subdivide_width = 200
	mesh.subdivide_depth = 200
	var m := ShaderMaterial.new()
	m.shader = SEA_SHADER
	m.set_shader_parameter("hole",Vector4(ISLE.x,ISLE.y,HOLE.x,HOLE.y))
	mesh.material = m
	sea = MeshInstance3D.new()
	sea.name = "CloudSea"
	sea.mesh = mesh
	sea.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sea.custom_aabb = AABB(Vector3(-across*0.5,-20.0,-across*0.5),Vector3(across,40.0,across))
	add_child(sea)
	_place_sea()

func _place_sea() -> void:
	sea.position = Vector3(snappedf(patch_centre.x,20.0),SEA_TOP-SEA_BASE,snappedf(patch_centre.y,20.0))
	var m := (sea.mesh as PrimitiveMesh).material as ShaderMaterial
	m.set_shader_parameter("patch",Vector4(patch_centre.x,patch_centre.y,PATCH.x,PATCH.y))

## The arch of the gothic kit on a keel of the shard's lode stone, at its
## place but hidden, sunk RING_DROP m (it rises when `appear`s). It collides
## (the ruins' layer 1, as the shard) only once it stands.
func _build_ring() -> void:
	ring = Node3D.new()
	ring.name = "Ring"
	ring.transform = Transform3D(Basis(Vector3.UP,ring_heading),ring_at-Vector3.UP*THREAD_UP)
	ring.visible = false
	add_child(ring)
	_lift = Node3D.new()
	_lift.name = "Lift"
	_lift.position = Vector3.DOWN*RING_DROP
	ring.add_child(_lift)
	arch = RuinKit.piece("arch",RING_SEED,RING_WEATHERED)
	arch.scale = Vector3.ONE*RING_SCALE
	_lift.add_child(arch)
	var rng := RandomNumberGenerator.new()
	rng.seed = RING_SEED
	var outline := PackedVector2Array()
	for i in range(12):
		var a := -TAU*i/12.0
		var r := rng.randf_range(0.85,1.1)
		outline.append(Vector2(cos(a)*KEEL.x*r,sin(a)*KEEL.y*r))
	var mesh: ArrayMesh = Lodestone.keel_mesh(outline,KEEL.z,RING_SEED,true)
	var rock := MeshInstance3D.new()
	rock.name = "Keel"
	rock.mesh = mesh
	var stone := ShaderMaterial.new()
	stone.shader = Lodestone.STONE_SHADER
	stone.set_shader_parameter("hum",0.0)
	rock.material_override = stone
	_lift.add_child(rock)
	var body := StaticBody3D.new()
	body.name = "KeelBody"
	var collider := CollisionShape3D.new()
	var hull := ConvexPolygonShape3D.new()
	hull.points = mesh.get_faces()
	collider.shape = hull
	body.add_child(collider)
	_lift.add_child(body)
	_collect(_lift)
	_solid(false)

func _collect(node: Node) -> void:
	if node is CollisionObject3D: _bodies.append(node)
	for child in node.get_children(): _collect(child)

func _solid(on: bool) -> void:
	for b: CollisionObject3D in _bodies: b.collision_layer = 1 if on else 0

## Starts it rising (`step` does this when the plane comes near).
func appear() -> void:
	if state != "hidden": return
	state = "rising"
	rise_clock = 0.0
	ring.visible = true

## The opening's clear (x, y in the ring's frame, feet at 0): within the
## arch's span and under its pointed head, OPEN_MARGIN in from the stone.
func in_opening(x: float, y: float) -> bool:
	var h := RuinKit.ARCH_SPAN*0.5*RING_SCALE
	var spring := RuinKit.SPRING*RING_SCALE
	var r := RuinKit.ARCH_SPAN*RuinKit.ARCH_PITCH*RING_SCALE
	var ax := absf(x)
	if ax > h-OPEN_MARGIN or y < OPEN_MARGIN: return false
	var off := ax+r-h
	var head := spring+sqrt(maxf(r*r-off*off,0.0))
	return y < head-OPEN_MARGIN

## Forgets where the plane was (a jump, not a flight: no crossing counted).
func forget() -> void:
	_prev = Vector3.INF

## One frame. `plane` (a SkyPlane) while flying, else null; `seated`: the
## lodestone rides in it; `eye`: the camera, for the sea's swells.
func step(delta: float, plane: RefCounted, seated: bool, eye: Vector3) -> void:
	var at: Variant = null if plane == null else (plane.position as Vector3)
	match state:
		"hidden":
			if at != null and seated and (at as Vector3).distance_to(ring_at) < RING_NEAR: appear()
		"rising":
			rise_clock += delta
			var u := clampf(rise_clock/RING_RISE,0.0,1.0)
			_lift.position = Vector3.DOWN*RING_DROP*pow(1.0-u,3.0)
			if u >= 1.0:
				_lift.position = Vector3.ZERO
				state = "standing"
				_solid(true)
		"passed":
			pause_left -= delta
			if pause_left <= 0.0: _start()
	if at != null and state == "standing": _watch(at as Vector3,plane)
	if at == null: _prev = Vector3.INF
	if state == "started":
		chain.advance(delta,at)
		var follow := Vector2(chain.halls[-1].pose.origin.x,chain.halls[-1].pose.origin.z) if not chain.halls.is_empty() else patch_centre
		if at != null: follow = follow.lerp(Vector2((at as Vector3).x,(at as Vector3).z),0.5)
		patch_centre = patch_centre.lerp(follow,1.0-exp(-delta/FOLLOW))
		_place_sea()
	_swell(eye)

## A crossing of the ring's plane (its local z through 0): through the
## opening it is threaded, else a miss.
func _watch(at: Vector3, plane: RefCounted) -> void:
	var local := ring.global_transform.affine_inverse()*at
	if _prev != Vector3.INF and signf(_prev.z) != signf(local.z) and absf(local.z-_prev.z) < 30.0:
		var u := _prev.z/(_prev.z-local.z)
		var cross := _prev.lerp(local,u)
		if in_opening(cross.x,cross.y):
			state = "passed"
			pass_point = ring.global_transform*cross
			pass_heading = float(plane.heading)
			pause_left = pause
			passed.emit()
		else: misses += 1
	_prev = local

## After the held breath: the first hall rising ahead, its way in `lead`
## m on along the heading the plane left the ring with.
func _start() -> void:
	state = "started"
	var way_in := pass_point+ChainPlan.ahead(pass_heading)*lead
	chain.reset(-1,chain.first_pose_at(way_in,pass_heading,HAND))
	started.emit()

## The gate of the first hall (world), once started.
func first_gate() -> Vector3:
	if chain.halls.is_empty(): return Vector3.INF
	var pose: Dictionary = chain.halls[0].pose
	return ChainPlan.xform(pose)*ChainPlan.local(ChainPlan.line()[0],ChainPlan.hand_of(pose))

func _swell(eye: Vector3) -> void:
	var out := []
	if state == "rising":
		var u := clampf(rise_clock/RING_RISE,0.0,1.0)
		out.append(Vector4(ring_at.x,ring_at.z,RING_SWELL.x,RING_SWELL.y*sin(minf(u*1.8,1.0)*PI)))
	if state == "started":
		for v: Vector4 in chain.swells(eye):
			if out.size() < Rise.SWELLS: out.append(v)
	var n := out.size()
	while out.size() < Rise.SWELLS: out.append(Vector4.ZERO)
	var m := (sea.mesh as PrimitiveMesh).material as ShaderMaterial
	m.set_shader_parameter("swells",out)
	m.set_shader_parameter("swell_count",n)
