extends Node3D
## The end of the aqueduct isle's loop (docs/design/isle-hall-chain.md):
## the ring by the lodestone's shard, and the hall chain it starts.
##
## The plane flies where the nose arrow points (the shard, studies/
## aqueduct_isle.gd `lode_target`). Coming near with the stone seated, a
## gothic arch on a keel of lode stone erupts quietly out of the cloud sea
## far below, past the shard (`ring`), and climbs to stand in the plane's
## way: no beacon, no glow, no pulse, and the arrow goes on pointing at the
## shard. It rises early enough to stand still well before the plane gets
## there, even at boost (`ring_near`, and RING_SPARE s before the plane at
## its speed). Threading its opening is the only thing that counts
## (crossing its plane outside the opening, or flying round it, does
## nothing; you can come round and go through). The first Sundered hall
## starts rising at once, still deep in the cloud (`first_at` "thread");
## nothing shows for `pause` s (a held breath); then `started` (the isle
## runs its pulse through the plane and the nose arrow goes quiet) as the
## hall's first chunk bursts out of the cloud dead ahead, on the heading
## the plane left the ring with. Its way in stands `lead` m on, or further
## at speed, so its gate is still `spare` s before the plane gets there.
## From there it is the Sundered line (scripts/hall_line.gd, docs/design/
## isle-hall-line.md): big whole pieces of nave on their islands rising one
## after another, end to end in straight runs, sidestepping now and then,
## each the game's own Sundered hall (scripts/hall_line_build.gd: the ruin
## kit in its basalt, the overgrowth, its ridge island), built on a worker
## from when the ring wakes (--line-look=greybox: round 1's boxes).
## --chain-style=halls brings back the hall chain (scripts/hall_chain.gd:
## the moments hall in four chunks, a long S). Either way its triggers are
## arrival-aware here (`settle_by`, `catch_up`).
##
## The cloud is the game's own: the near cloud sea round the isle (scripts/
## sky_sea.gd, drawn in the unified cloud volume, scripts/cloud_volume.gd),
## its heaps' tops about SEA_TOP. Everything rises up out of it, through
## the open sky, to where the plane flies, bursting through the heaps in
## puffs of the game's cloud (scripts/sky_puff_burst.gd: the sky peaks' and
## the glide's own puff shader). No cloud of its own: no patch, no hole.
##
## The isle calls `setup`, then `step` every frame (with the plane while
## flying).

const Chain = preload("res://scripts/hall_chain.gd")
const Line = preload("res://scripts/hall_line.gd")
const ChainPlan = preload("res://scripts/hall_chain_plan.gd")
const Rise = preload("res://scripts/hall_rise.gd")
const RisePlan = preload("res://scripts/hall_rise_plan.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Lodestone = preload("res://scripts/lodestone.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const SkySea = preload("res://scripts/sky_sea.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const PuffBurst = preload("res://scripts/sky_puff_burst.gd")

## The cloud top things break through (world): just under the near sea's
## tallest heaps (SkySea FLOOR + TALL, -105), so a chunk comes out among
## their crowns.
const SEA_TOP := SkySea.FLOOR+SkySea.TALL-3.0
## The halls' rise here (scripts/hall_rise_plan.gd RISE's keys; the rise's
## flags, --rise-speed= and the rest, still win): they climb some 160 m
## from deep in the sea to the plane's height, so quicker than the study's
## 9 m/s, bursting through the heaps at full speed and easing over the last
## 30 m; each starts 25 m under the heaps' tops so none shows in a gap.
const RISE_OPTS := {"speed":30.0,"ease_in":10.0,"ease_out":30.0,"under":25.0,"gap":1.2,"lead":0.4}
## Later halls' lowest stone stands within this of the first's (m).
const CLIMB_BAND := 8.0
## The bursts: the hall rise's puffs this many times their size (a chunk
## breaks through heaps 70 m across, seen from 130 m over them).
const PUFF_SCALE := 2.2
## The ring: RING_PAST m on past the shard (on the line from the isle's
## middle, ISLE, to it) and RING_ASIDE m to its left, its opening's middle
## at RING_UP (world), facing along that line. The kit's pointed arch at
## RING_SCALE: a clear span of 9.2 m and a crown 15 m over its feet (the
## wooden plane is 1.4 m across). The plane threads it THREAD_UP m over
## its feet.
const ISLE := Vector2(85.0,-20.0)
const RING_PAST := 90.0
const RING_ASIDE := 35.0
const RING_UP := 25.0
const RING_SCALE := 2.2
const THREAD_UP := 6.0
const RING_SEED := 52
const RING_WEATHERED := 0.25
const RING_CROWN := (RuinKit.SPRING+RuinKit.ARCH_SPAN*0.866)*RING_SCALE
## Its keel: half across, half deep, how deep it hangs (m).
const KEEL := Vector3(10.5,5.0,9.0)
## It rises when the plane, with the stone seated, is within RING_NEAR m
## (--ring-near=<m>), or sooner at speed: once the plane would be there
## within the rise and RING_SPARE s. Its motion is a hall chunk's
## (RisePlan.height_at), its crown starting RING_UNDER m under the cloud
## top, with RING_RISE's keys.
const RING_NEAR := 420.0
const RING_SPARE := 8.0
const RING_UNDER := 20.0
const RING_RISE := {"speed":26.0,"ease_in":8.0,"ease_out":26.0,"over":0.3,"settle":1.0,"lead":0.0,"gap":0.0}
## The held breath after threading it (s), and how far on the first hall's
## way in stands at the least (m; its gate is ChainPlan.LEAD_IN more).
const PAUSE := 1.5
const LEAD := 180.0
## Arrival: each gate still SPARE s before the plane reaches it at its
## speed (--arrive-spare=<s>: the first hall's lead, the chain's
## triggers); a hall the plane outruns anyway rises up to CATCH_UP times
## quicker (--catch-up=<x>, 1 for none).
const SPARE := 2.0
const CATCH_UP := 1.6
## The first hall's hand: mirrored (it swings you left), so the chain's S
## runs north-north-west from the ring, into open sky.
const HAND := -1
## The margin (m) the plane's middle keeps inside the opening's stone.
const OPEN_MARGIN := 0.6
## The ring's burst: puffs round its keel as its crown breaks through, and
## a stream off it while its keel's foot clears the top (a second).
const RING_BURST := 40
const RING_STREAM := 30.0

signal passed
signal started

var chain: Node3D
var ring: Node3D
var _lift: Node3D
var arch: Node3D
var burst: MultiMeshInstance3D
## The pass point (world: the opening's middle at the plane's height) and
## the way the ring faces (rad, SkyPlane's heading).
var ring_at := Vector3.ZERO
var ring_heading := 0.0
## "hidden", "rising", "standing", "passed" (the pause), "started".
var state := "hidden"
var rise_clock := 0.0
## The ring's motion (a RisePlan chunk: from_y, t_in, ... in its frame).
var ring_motion := {}
var ring_near := RING_NEAR
## Where the plane was (m from the ring) and how fast, when the ring began
## to rise (the tests, the doc's timings).
var ring_woke_at := Vector2.ZERO
var ring_broke := false
var _owed := 0.0
var pause := PAUSE
var pause_left := 0.0
var lead := LEAD
var spare := SPARE
## "thread": the first hall starts rising (unseen, deep in the cloud) as
## the ring is threaded; "pulse": after the pause, as before
## (--first-at=pulse).
var first_at := "thread"
## "line" (the Sundered line, scripts/hall_line.gd) or "halls" (the hall
## chain, --chain-style=halls).
var style := "line"
## The first hall's way in as placed (m past the pass point).
var lead_used := 0.0
## Where and on what heading the plane threaded it.
var pass_point := Vector3.INF
var pass_heading := 0.0
var pass_speed := 0.0
## Crossings of the ring's plane outside the opening (the tests).
var misses := 0
var _bodies: Array[CollisionObject3D] = []
var _prev := Vector3.INF
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "IsleChain"
	_rng.seed = 17

## The ring past `target` (or at --ring=x,y,z), the bursts, the chain
## (planned, not started). Flags: --ring=x,y,z (the opening's middle),
## --ring-near=<m>, --ring-pause=<s>, --chain-lead=<m>, --arrive-spare=<s>,
## --catch-up=<x>, --first-at=thread|pulse, and the chain's and rise's
## (scripts/hall_chain.gd, scripts/hall_rise.gd `options`).
func setup(target: Vector3, args: PackedStringArray) -> void:
	var way := Vector2(target.x-ISLE.x,target.z-ISLE.y).normalized()
	# Left of the line (as you fly out), so its axis runs past the shard's
	# keel, not under it.
	var left := Vector2(way.y,-way.x)
	ring_at = Vector3(target.x+way.x*RING_PAST+left.x*RING_ASIDE,RING_UP,target.z+way.y*RING_PAST+left.y*RING_ASIDE)
	var catch_up := CATCH_UP
	for a: String in args:
		var v := a.get_slice("=",1)
		if a.begins_with("--ring="):
			var p := v.split(",")
			if p.size() == 3: ring_at = Vector3(float(p[0]),float(p[1]),float(p[2]))
		elif a.begins_with("--ring-pause="): pause = maxf(0.0,float(v))
		elif a.begins_with("--ring-near="): ring_near = maxf(20.0,float(v))
		elif a.begins_with("--chain-lead="): lead = maxf(40.0,float(v))
		elif a.begins_with("--arrive-spare="): spare = float(v)
		elif a.begins_with("--catch-up="): catch_up = maxf(1.0,float(v))
		elif a.begins_with("--first-at=") and v in ["thread","pulse"]: first_at = v
		elif a.begins_with("--chain-style=") and v in ["line","halls"]: style = v
	# It faces out along the isle-to-shard line.
	ring_heading = atan2(-way.x,-way.y)
	burst = PuffBurst.new()
	burst.base_y = SEA_TOP
	add_child(burst)
	_build_ring()
	chain = Line.new() if style == "line" else Chain.new()
	chain.sea_top = SEA_TOP
	chain.plane_box = Callable()
	chain.burst = burst
	chain.puff_scale = PUFF_SCALE
	add_child(chain)
	var rise := RISE_OPTS.duplicate()
	rise.merge(Rise.options(args),true)
	if style == "line":
		# The line keeps its floors within its own band of the first's; its
		# islands' falls are planned from about the ring's height.
		chain.home_y = ring_at.y
		chain.configure(Line.options(args),rise)
	else:
		chain.configure(Chain.options(args),rise)
		# The halls stand about the ring's height, far over the sea.
		var clear: float = ring_at.y-2.0-SEA_TOP+float(chain.lowest())
		chain.clear_range = Vector2(clear-CLIMB_BAND,clear+CLIMB_BAND)
	chain.settle_by = spare
	chain.catch_up = catch_up

## The arch of the gothic kit on a keel of the shard's lode stone, at its
## place but hidden, sunk deep in the cloud (it rises when it `appear`s).
## It collides (the ruins' layer 1, as the shard) only once it stands.
func _build_ring() -> void:
	ring = Node3D.new()
	ring.name = "Ring"
	ring.transform = Transform3D(Basis(Vector3.UP,ring_heading),ring_at-Vector3.UP*THREAD_UP)
	ring.visible = false
	add_child(ring)
	ring_motion = {"pivot":Vector3.ZERO,"top":RING_CROWN}
	var opts := RING_RISE.duplicate()
	opts.under = RING_UNDER
	opts.sea = SEA_TOP-ring.position.y
	RisePlan.schedule([ring_motion],opts)
	_lift = Node3D.new()
	_lift.name = "Lift"
	_lift.position = Vector3.UP*float(ring_motion.from_y)
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

## How long the ring takes from waking to standing still (s).
func ring_length() -> float:
	return RisePlan.settles(ring_motion)

## The cloud top in the ring's frame (its feet at 0).
func _ring_sea() -> float:
	return SEA_TOP-ring.position.y

## Starts it rising (`step` does this when the plane comes near).
func appear() -> void:
	if state != "hidden": return
	state = "rising"
	rise_clock = 0.0
	ring.visible = true

## Whether the plane at `at`, flying `speed`, wakes the ring: within
## `ring_near`, or near enough at its speed that it would be there within
## the ring's rise and RING_SPARE s.
func wakes(at: Vector3, speed: float) -> bool:
	var d := at.distance_to(ring_at)
	return d < ring_near or d < maxf(speed,SkyPlane.CRUISE_SPEED)*(ring_length()+RING_SPARE)

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
## lodestone rides in it; `_eye`: the camera (unused since the greybox sea
## went; kept for the isle's call).
func step(delta: float, plane: RefCounted, seated: bool, _eye := Vector3.ZERO) -> void:
	var at: Variant = null if plane == null else (plane.position as Vector3)
	var speed := 0.0 if plane == null else float(plane.speed)
	match state:
		"hidden":
			if at != null and seated and wakes(at as Vector3,speed):
				ring_woke_at = Vector2((at as Vector3).distance_to(ring_at),speed)
				appear()
		"rising":
			rise_clock += delta
			_ring_frame(delta)
			if rise_clock >= ring_length():
				_lift.position = Vector3.ZERO
				state = "standing"
				_solid(true)
		"passed":
			pause_left -= delta
			if pause_left <= 0.0: _start()
	if at != null and state == "standing": _watch(at as Vector3,plane)
	if at == null: _prev = Vector3.INF
	# The line's pieces built ahead from when the ring wakes.
	if style == "line" and state != "hidden": chain.prefetch()
	if chain.halls.size() > 0:
		chain.plane_speed = speed
		chain.advance(delta,at)
	burst.step(delta)

## The ring this frame: where it has risen to, its burst as its crown
## breaks the cloud top, the stream off its keel as that clears.
func _ring_frame(delta: float) -> void:
	var y := RisePlan.height_at(ring_motion,rise_clock)
	_lift.position = Vector3.UP*y
	var sea := _ring_sea()
	if not ring_broke and y+RING_CROWN > sea:
		ring_broke = true
		for k in range(RING_BURST):
			var a := _rng.randf()*TAU
			var out := Vector3(cos(a),0.0,sin(a))
			var p := ring.global_transform*Vector3(cos(a)*KEEL.x*1.1,sea+_rng.randf_range(-0.5,2.0),sin(a)*KEEL.y*1.3)
			burst.puff(p,ring.global_basis*(out*_rng.randf_range(3.0,9.0))+Vector3.UP*_rng.randf_range(3.0,8.0),
				_rng.randf_range(10.0,18.0),_rng.randf_range(0.6,1.2),_rng.randf_range(3.0,5.0))
	if ring_broke and y-KEEL.z < sea+6.0:
		_owed += RING_STREAM*delta
		var v := RisePlan.speed_at(ring_motion,rise_clock)
		while _owed >= 1.0:
			_owed -= 1.0
			var a := _rng.randf()*TAU
			var p := ring.global_transform*Vector3(cos(a)*KEEL.x,_rng.randf_range(sea,minf(y+RING_CROWN,sea+14.0)),sin(a)*KEEL.y)
			burst.puff(p,Vector3.UP*v*0.5*_rng.randf_range(0.6,1.0)+ring.global_basis*Vector3(cos(a),0.0,sin(a))*_rng.randf_range(1.0,4.0),
				_rng.randf_range(6.0,11.0),_rng.randf_range(0.6,1.4),_rng.randf_range(1.6,2.8))

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
			pass_speed = float(plane.speed)
			pause_left = pause
			if first_at == "thread": _place_first()
			passed.emit()
		else: misses += 1
	_prev = local

## The first hall, rising ahead on the heading the plane left the ring
## with: its way in `lead` m on, or further, so that at the plane's speed
## its gate is still `spare` s before the plane gets there.
func _place_first() -> void:
	var v := maxf(pass_speed,SkyPlane.CRUISE_SPEED)
	var still: float = float(chain.length_at(first_y()))+(pause if first_at == "pulse" else 0.0)
	lead_used = maxf(lead,v*(still+spare)-lead_in())
	var way_in := pass_point+ChainPlan.ahead(pass_heading)*lead_used
	chain.plane_speed = v
	chain.reset(-1,chain.first_pose_at(way_in,pass_heading,HAND))

## The height the first hall's rise is timed at: the hall chain's origin
## (2 m under the way in), or the line's lane (the way in's height).
func first_y() -> float:
	return pass_point.y-2.0 if style == "halls" else pass_point.y

## How far the way in stands before the first gate or entry (m).
func lead_in() -> float:
	return ChainPlan.LEAD_IN if style == "halls" else Line.LEAD_IN

## After the held breath: the pulse (and the first hall, if it waits).
func _start() -> void:
	state = "started"
	if first_at == "pulse": _place_first()
	started.emit()

## The gate of the first hall, or the first piece's entry (world), once
## placed.
func first_gate() -> Vector3:
	if chain.halls.is_empty(): return Vector3.INF
	return Chain.gate_of(chain.halls[0].pose) if style == "halls" else Line.gate_of(chain.halls[0].pose)
