extends Node3D
## The endless flight's birds (docs/design/endless-flight/birds-handoff.md):
## the game's songbirds (the isles', scripts/kit_isle/kit_birds.gd), their
## carved bodies (scripts/songbird_body.gd's meshes and numbers) and their
## moves: the perched life (look-about snaps, tail flicks, hops along the
## boughs, short hops and pecks on the ground) and the bounding
## flap-and-glide of small birds.
##
## Perched flocks wait in spruce crowns near where the plane is heading (the
## trees' own plan, LandTrees `cell_trees`, no physics). The plane coming
## within FLUSH_SPANS of its span flushes one: each bird crouches a beat and
## bursts up and out, the flock forms up and flies alongside the plane for
## RIDE seconds, then peels off away from it and is dropped out of sight.
## On foot, flocks sit in trees round him (some foraging under them); him
## coming near (FIGURE_NEAR, more at a run) flushes one: out all at once,
## wheeling over the tree, then off to another tree away from him. A few
## loose flocks wheel far off over the land.
##
## Drawing: per species, six MultiMeshes of the songbird's parts (a sitting
## body with its wings folded and its head apart, so it can look about; a
## flying body with the wings tucked, for the bounds; a flying body with no
## wings, and each spread wing hinged at its shoulder), so every bird is
## the isles' bird at every distance, with no LOD to pop, in 18 draw calls.
## Visual only: nothing collides, nothing touches the plane.
##
## Smoothness: every bird is stepped every frame at render rate; flying birds
## follow their place in the flock on a critically damped spring (no
## clamped, bang-bang steering), face their smoothed velocity and bank from
## their smoothed turn; the wings beat at the songbirds' 2.4 a second.
##
## Flags: --birds=0 off, --birds=X how many flocks wait in the trees (1),
## --bird-range=X the flush reach over its default (1), --bird-size=X (1),
## --bird-ride=S seconds alongside (6), --ambient-birds=X the far flocks
## (1; 0 none). The grass flush has its own: scripts/endless/grass_birds.gd
## (--grass-birds=X, --flush-gap=S, --flush-size=X, --flush-sound=N); --birds=0
## stops it too.
##
## The covey (`put_covey`, `_covey`): the grass flush's birds. Each flies itself
## here, not a place in the flock: one goes, the rest after it, a hard low
## scramble along the flush's way with jinks and elbowing, a flare off the
## plane's line as it nears, then level and fanning out, whirring and gliding,
## and down into the grass one by one.
##
## Native: with the library built, a flock whose birds all fly (wheeling,
## alongside, peeling off or leaving) is flown in C++ (ZenScapeBirds,
## native/terrain_kernels/flight_fx.h: `_fly_birds` and `_pose_air` for it,
## the same numbers), and every bird's parts are laid out there (`_draw`).
## The flocks, the perched life and every random draw stay here.
## --native-birds=0 (or --gdscript-kernels) runs it all here.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const Plan = preload("res://scripts/endless/tree_plan.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const Body = preload("res://scripts/songbird_body.gd")
const GrassBirds = preload("res://scripts/endless/grass_birds.gd")
const SHADER = preload("res://shaders/endless_birds.gdshader")

## The most birds drawn at once.
const MAX_BIRDS := 160
## A bird's span over the plane's (WorldScale.span): about 0.85 m at the
## sizes' knobs, the songbird (0.38 m on the isles) made readable at the
## plane's scale.
const SPAN_SHARE := 0.3
## The songbird's span in its own (built) units: wingtip to wingtip.
const BODY_SPAN := 0.9
## The plane within this many of its spans of a perched flock flushes it.
const FLUSH_SPANS := 16.0
## Where perched flocks are put: this far ahead along the plane's way (m),
## within this far to either side of it, not nearer its line than LANE_MIN.
const AHEAD := Vector2(140.0,280.0)
const LANE := 38.0
const LANE_MIN := 5.0
## The plane higher than this over the ground puts no flocks in the trees.
const LOW := 80.0
## Flocks waiting in the trees at once (times --birds=), and the seconds
## between putting one (over --birds=).
const PERCHED := 2
const PERCH_GAP := 5.0
## Birds in a flock.
const FLOCK := Vector2i(9,17)
## On foot: flocks kept in trees this near him (m), with this share of a
## flock foraging under its tree; dropped past FOOT_GONE.
const FOOT_FLOCKS := 2
const FOOT_AT := Vector2(22.0,85.0)
const FOOT_GONE := 240.0
const FORAGE_SHARE := 0.3
## Flush reach on foot (m, the isles' FIGURE_NEAR and RUN_NEAR over RUN_PACE
## m/s), scaled with the birds; measured across, not up the tree.
const FIGURE_NEAR := 3.6
const RUN_NEAR := 5.5
const RUN_PACE := 4.0
## The perched life (the isles'): seconds sat before a hop, a hop's reach
## (m, songbird units: times the birds' scale) and time, tail flicks a
## second; the turf's hops and pecks. Only flocks this near the eye live it.
const SIT := Vector2(4.0,14.0)
const HOP_REACH := 1.7
const HOP_TIME := 0.35
const FLICK_RATE := 0.3
const GROUND_HOP := Vector2(0.12,0.3)
const GROUND_HOP_TIME := 0.16
const PECK := Vector2(0.4,1.4)
const LIFE_NEAR := 110.0
## Settled after a flit: no flush for CALM s.
const CALM := 6.0
## Flushed on foot: the wheel over the tree (radius m, seconds), the flit to
## another tree (its distance from him, the flock's speed m/s).
const WHEEL_R := 6.0
const WHEEL_TIME := Vector2(2.5,4.5)
const FLIT_TO := Vector2(45.0,95.0)
const FLIT_SPEED := 9.0
## The alongside: seconds, the slot beside the plane (lateral m, from ahead
## to beside m, over it m), and the birds' top speed over the plane's cruise.
const RIDE := 6.0
const SLOT_SIDE := Vector2(6.0,9.0)
const SLOT_AHEAD := Vector2(16.0,0.0)
const SLOT_OVER := Vector2(0.0,2.5)
const TOP_SPEED := 1.08
## Peeled: the turn away (rad) and its seconds, the speed over cruise, and
## the distance from the eye they are dropped past (or PEEL_LONGEST s).
const PEEL_TURN := 1.0
const PEEL_TIME := 3.0
const PEEL_SPEED := 0.78
const GONE := 200.0
const GONE_BEHIND := 50.0
const PEEL_LONGEST := 20.0
## The startle: each bird's delay (s, nearest the plane first), its crouch,
## and the burst (up, out from the tree, m/s) and its time.
const STARTLE_SPREAD := 0.35
const CROUCH := 0.12
const BURST_UP := Vector2(4.5,7.0)
const BURST_OUT := 3.0
const BURST_TIME := 0.7
## Wings (the songbirds'): beat rate (rad/s; 2.4 beats a second), the burst's,
## and the bounds (s of beating, s of wings tucked).
const BEAT := 15.0
const BURST_BEAT := 24.0
const BOUND := Vector2(0.34,0.22)
## A flying bird keeps to its place on a spring: velocity response (1/s);
## the place's pull is a quarter of it (critically damped).
const RESPONSE := 4.0
## The far flocks: how many, their birds, size over the near ones, how far
## from the eye they are put and dropped, and their height over the ground.
const AMBIENT := 2
const AMBIENT_FLOCK := Vector2i(16,26)
const AMBIENT_SIZE := 2.0
const AMBIENT_AT := Vector2(130.0,300.0)
const AMBIENT_GONE := 650.0
const AMBIENT_OVER := Vector2(28.0,70.0)
const SPECIES_LIST := ["sparrow","sparrow","robin","goldfinch"]

## The covey. A bird's first spring (up, along its way, m/s); the top of its
## climb (m/s); how hard it holds its height; how fast it takes up what it
## wants, panicked and calmed (1/s).
const COVEY_SPRING := Vector2(7.0,10.5)
const COVEY_ALONG := 2.5
const COVEY_CLIMB := 8.5
const COVEY_HOLD := 4.0
const COVEY_PANIC := 8.0
const COVEY_CALM := 2.8
## Its ragged start (s): the first alone, then the rest within COVEY_FOLLOW,
## and COVEY_LATE of them, the slow ones, up to COVEY_LATE_BY later still.
const COVEY_FIRST := 0.14
const COVEY_FOLLOW := 0.42
const COVEY_LATE := 0.16
const COVEY_LATE_BY := Vector2(0.3,0.75)
## The jinks: a new one every so often (s), this much (m/s across, m/s up).
const COVEY_JINK := Vector2(0.16,0.42)
const COVEY_JINK_SIDE := 6.5
const COVEY_JINK_UP := 3.0
## Elbow room (m) and how hard they keep it (m/s at touching).
const COVEY_ROOM := 1.3
const COVEY_SHOVE := 7.0
## The flare: the plane this many seconds off and this near its line (m) turns
## a bird away from the line, up to this much (m/s).
const FLARE_TIME := 1.1
const FLARE_NEAR := 15.0
const FLARE := 26.0
## The plane going by this near (m) tosses a bird (m/s), and no bird is ever
## nearer than SWEPT (m).
const TOSS_NEAR := 7.0
const TOSS := 5.5
const SWEPT := 1.8
## Levelled, it goes on at this share of its pace and this share of its peak;
## going down, this fast (m/s), and under this (m) it flares in.
const LEVEL_PACE := 0.72
const LEVEL_PEAK := 0.55
const DOWN_SINK := 3.2
const DOWN_FLARE := 2.0
## The wings (rad/s; about 10 beats a second), each bird's spread on it, the
## stroke's share down over up; once level whirring this long (s), then set
## and gliding this long, drooped at GLIDE_BEAT.
const COVEY_BEAT := 62.0
const COVEY_BEATS := Vector2(0.88,1.16)
const COVEY_STROKE := 1.3
const WHIRR := Vector2(0.3,0.65)
const GLIDE := Vector2(0.25,0.55)
const GLIDE_BEAT := -0.4
## Past this (s) a covey is over, wherever it is; or this far from the plane.
const COVEY_LONGEST := 16.0
const COVEY_GONE := 420.0

## Flock states. PERCH..WHEEL as before; SCATTER (wheeling over the tree,
## flushed on foot), FLIT (off to another tree), SETTLE (each bird coming in
## to its perch), LEAVE (away, no tree to go to), COVEY (the grass flush, each
## bird on its own).
enum { PERCH, BURST, RIDING, PEEL, WHEEL, SCATTER, FLIT, SETTLE, LEAVE, COVEY }
## A bird's own state.
enum { SAT, HOPPING, GROUND, FLYING, LANDING }

## The six parts drawn per species.
enum { P_SIT, P_HEAD, P_TUCK, P_FLY, P_WING_L, P_WING_R }
const PARTS := 6

class Bird:
	var mode := SAT
	var p := Vector3.ZERO
	var v := Vector3.ZERO
	var off := Vector3.ZERO      # its place in the flock, in the flock's frame
	var face := Vector3.FORWARD  # level heading
	var pitch := 0.0
	var roll := 0.0
	var delay := 0.0             # startle delay
	var t := 0.0                 # since it startled (or sat)
	var beat := 0.0              # wingbeat phase (rad)
	var bound := 0.0             # place in the flap-and-glide bound (s)
	var squash := 0.0            # - squat, + stretched
	var seed := 0.0
	# Perched life.
	var spot := Vector3.ZERO     # its perch or its patch of turf
	var spot_face := Vector3.FORWARD
	var timer := 0.0
	var look := 0.0
	var look_goal := 0.0
	var look_at := 0.0
	var flick := 0.0
	var peck := 0.0
	var hop_from := Vector3.ZERO
	var hop_to := Vector3.ZERO
	var hop_t := -1.0
	var angle := 0.0             # where round its crown it sits
	var height := 0.0            # how far up the crown (0 its foot, 1 the tip)
	# In a covey.
	var way := Vector3.FORWARD   # its own way off
	var fan := 0.0               # how far it fans from that, -1..1
	var peak := 0.0              # the height it climbs to (m)
	var linger := 1.0            # its stay in the air over the covey's
	var rate := 1.0              # its wingbeat over the covey's
	var floor_y := 0.0           # the ground under it
	var jink := Vector3.ZERO
	var jink_at := 0.0
	var whirr := 0.0             # the whirr-and-glide's clock, + beating, - set
	var tossed := false          # the plane has gone by it

class Crown:
	var x := 0.0
	var z := 0.0
	var foot := 0.0
	var height := 0.0
	var crown := 0.0             # the crown's foot over the tree's
	var radius := 1.0            # the crown's radius at its foot

class Flock:
	var state := PERCH
	var species := "sparrow"
	var birds: Array = []
	var a := Vector3.ZERO        # the anchor the birds keep station on
	var av := Vector3.ZERO
	var heading := Vector3.FORWARD  # the flock's frame, smoothed
	var t := 0.0                 # in this state
	var tree: Crown
	var to: Crown                 # flitting to
	var side := 1.0
	var lateral := 10.0
	var over := 2.0
	var peel_from := Vector3.FORWARD
	var climb := 0.0
	var spread := 1.0
	var size := 1.0
	var ground := 0.0
	var centre := Vector3.ZERO   # a wheel's middle
	var radius := 50.0
	var spin := 1.0
	var until := 0.0
	var calm := 0.0
	var nid := -1                # flown natively (ZenScapeBirds), or -1
	var plan := {}               # a covey's flush (grass_birds.gd `_try`)

var enabled := true
var density := 1.0
var reach := 1.0
var size := 1.0
var ride := RIDE
var ambient := 1.0
var flocks: Array = []
## The numbers (F1) and the harness: flushes so far, and the last step's ms.
var stats := {"flushed":0,"rode":0,"peeled":0,"dropped":0,"foot_flushed":0,"settled":0,"hops":0,"ms":0.0,"ms_avg":0.0,"draw_ms":0.0,"covey_near":INF}

var _field: RefCounted
var _trees: Node3D
var _rng := RandomNumberGenerator.new()
## The species drawn, and per species and part (species*PARTS+part) its
## MultiMesh, node and count; every part's transforms in one buffer, MAX_BIRDS
## a part.
var _kinds: Array[String] = []
var _mm: Array[MultiMesh] = []
var _mmi: Array[MultiMeshInstance3D] = []
var _n := PackedInt32Array()
var _data := PackedFloat32Array()
var _perch_wait := 0.0
var _span := 0.85
## The bodies' scale (over songbird units), and over the isles' (for reaches).
var _scale := 1.0
var _k := 1.0
var _clock := 0.0
## Each part's place on the body (songbird units).
var _wing_at := [Vector3.ZERO,Vector3.ZERO]
var _head_at := Vector3.ZERO
## The C++ flying and drawing (ZenScapeBirds), or null for the GDScript.
var native: Object = null
## The grass flush: when and where its coveys go.
var grass: Node3D = null

const NATIVE_CLASS := &"ZenScapeBirds"
const NATIVE_VERSION := 1
static func native_wanted() -> bool:
	var args := LaunchArgs.user_args()
	if "--native-birds=0" in args or "--gdscript-kernels" in args: return false
	Field.native_available()
	if not ClassDB.class_exists(NATIVE_CLASS): return false
	var probe: Object = ClassDB.instantiate(NATIVE_CLASS)
	return probe.has_method("version") and int(probe.version()) == NATIVE_VERSION

static func flags() -> Dictionary:
	# The world's birds layer, the flags over it.
	var out := {"on":bool(preload("res://scripts/endless/world/world_profile.gd").current().layer("birds",true)),"density":1.0,"reach":1.0,"size":1.0,"ride":RIDE,"ambient":1.0}
	for a: String in LaunchArgs.user_args():
		var v := a.get_slice("=",1)
		if a.begins_with("--birds="):
			out.density = maxf(0.0,float(v))
			out.on = out.density > 0.0
		elif a == "--no-birds": out.on = false
		elif a.begins_with("--bird-range="): out.reach = maxf(0.1,float(v))
		elif a.begins_with("--bird-size="): out.size = maxf(0.1,float(v))
		elif a.begins_with("--bird-ride="): out.ride = maxf(0.0,float(v))
		elif a.begins_with("--ambient-birds="): out.ambient = maxf(0.0,float(v))
	return out

func setup(land_seed: int, field: RefCounted, trees: Node3D) -> void:
	var f := flags()
	enabled = f.on
	density = f.density
	reach = f.reach
	size = f.size
	ride = f.ride
	ambient = f.ambient
	_field = field
	_trees = trees
	_rng.seed = hash("birds%d" % land_seed)
	_span = WorldScale.span*SPAN_SHARE*size
	_scale = _span/BODY_SPAN
	_k = _scale/Body.SIZE
	_head_at = Body.HEAD_AT
	_wing_at = [Vector3(-Body.SHOULDER.x,Body.SHOULDER.y,Body.SHOULDER.z),Body.SHOULDER]
	if not enabled: return
	var paint := ShaderMaterial.new()
	paint.shader = SHADER
	for kind: String in Body.SPECIES:
		_kinds.append(kind)
		var meshes := _part_meshes(kind)
		for part in PARTS:
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = meshes[part]
			mm.instance_count = MAX_BIRDS
			mm.visible_instance_count = 0
			var node := MultiMeshInstance3D.new()
			node.name = "Birds_%s_%d" % [kind,part]
			node.multimesh = mm
			node.material_override = paint
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(node)
			_mm.append(mm)
			_mmi.append(node)
	_n.resize(_mm.size())
	_data.resize(_mm.size()*MAX_BIRDS*12)
	if native_wanted():
		native = ClassDB.instantiate(NATIVE_CLASS)
		native.configure({"span": _span, "avoid": WorldScale.span*1.5, "response": RESPONSE, "crouch": CROUCH, "beat": BEAT,
			"bound": BOUND, "max_birds": MAX_BIRDS, "parts": _mm.size(), "head_at": _head_at, "wing_l": _wing_at[0], "wing_r": _wing_at[1]})
	grass = GrassBirds.new()
	grass.name = "GrassBirds"
	add_child(grass)
	grass.setup(land_seed,field)

## The parts, from the songbird's own meshes: sitting (body and folded
## wings), the head, the flying body with its wings tucked (the bounds) and
## without, each spread wing about its shoulder.
static func _part_meshes(kind: String) -> Array:
	var m := Body.meshes_for(kind)
	var air_head := Transform3D(Basis(Vector3.RIGHT,-0.12),Body.HEAD_AT)
	var folded := func(st: SurfaceTool) -> void:
		for i in 2:
			var side := -1.0 if i == 0 else 1.0
			st.append_from(m.folded[i],0,Transform3D(Basis.IDENTITY,Vector3(Body.SHOULDER.x*side,Body.SHOULDER.y,Body.SHOULDER.z)))
	var sit := SurfaceTool.new()
	sit.append_from(m.body,0,Transform3D.IDENTITY)
	folded.call(sit)
	var tuck := SurfaceTool.new()
	tuck.append_from(m.body,0,Transform3D.IDENTITY)
	tuck.append_from(m.head,0,air_head)
	folded.call(tuck)
	var fly := SurfaceTool.new()
	fly.append_from(m.body,0,Transform3D.IDENTITY)
	fly.append_from(m.head,0,air_head)
	return [sit.commit(),m.head,tuck.commit(),fly.commit(),m.spread[0],m.spread[1]]

func bird_count() -> int:
	var n := 0
	for f: Flock in flocks: n += f.birds.size()
	return n

func count_in(state: int) -> int:
	var n := 0
	for f: Flock in flocks:
		if f.state == state: n += 1
	return n

## The flush reach (m).
func flush_reach() -> float:
	return WorldScale.span*FLUSH_SPANS*reach

## One frame: flocks put and dropped round the plane (or him on foot),
## flushed, flown and drawn. `plane` is the SkyPlane (position, velocity,
## speed, cruise()).
func step(delta: float, eye: Vector3, plane: RefCounted) -> void:
	if not enabled or delta <= 0.0: return
	var began := Time.get_ticks_usec()
	_clock += delta
	var pp: Vector3 = plane.position
	var pv: Vector3 = plane.velocity
	var cruise: float = plane.cruise()
	var feet := _feet()
	_perch_wait -= delta
	if _perch_wait <= 0.0:
		_perch_wait = 0.5
		if feet != Vector3.INF: _put_near(feet,eye)
		else: _put_perched(pp,pv)
		_put_ambient(eye)
	for i in range(flocks.size()-1,-1,-1):
		var f: Flock = flocks[i]
		if not _flock_step(f,delta,eye,pp,pv,cruise,feet):
			if f.nid >= 0: native.drop(f.nid)
			flocks.remove_at(i)
			stats.dropped += 1
	var t_draw := Time.get_ticks_usec()
	_draw()
	stats.draw_ms = lerpf(float(stats.draw_ms),(Time.get_ticks_usec()-t_draw)/1000.0,0.05)
	grass.step(delta,plane)
	var ms := (Time.get_ticks_usec()-began)/1000.0
	stats.ms = ms
	stats.ms_avg = lerpf(float(stats.ms_avg),ms,0.05)

## His feet while he is on foot, else INF (a host with `on_foot` and a
## `walker`; endless flight has none since walking was cut, docs/archive.md).
func _feet() -> Vector3:
	var host := get_parent()
	if host == null or host.get("on_foot") != true: return Vector3.INF
	var walker: Variant = host.get("walker")
	if walker == null: return Vector3.INF
	var motor: Variant = (walker as Node).get("motor")
	return motor.feet if motor != null else Vector3.INF

func _run_speed() -> float:
	var walker: Variant = get_parent().get("walker")
	var motor: Variant = (walker as Node).get("motor") if walker != null else null
	return float(motor.speed()) if motor != null else 0.0

# --- Putting flocks --------------------------------------------------------------

func _tree_of(list: PackedFloat32Array, q: int) -> Crown:
	var t := Crown.new()
	t.x = list[q]
	t.z = list[q+1]
	t.foot = list[q+2]
	t.height = list[q+3]
	t.crown = clampf(list[q+4],0.0,t.height*0.8)
	t.radius = list[q+6] if list[q+6] > 0.3 else t.height*0.19
	return t

func _put_perched(pp: Vector3, pv: Vector3) -> void:
	if _trees == null or not _trees.enabled or density <= 0.0: return
	if count_in(PERCH) >= ceili(PERCHED*density): return
	var flat := Vector3(pv.x,0.0,pv.z)
	if flat.length() < 3.0: return
	if pp.y-_field.height(pp.x,pp.z) > LOW: return
	var fwd := flat.normalized()
	var right := fwd.cross(Vector3.UP)
	# Cells along the way ahead; a few trees sampled from each.
	var tried := {}
	var best: Crown = null
	for k in 5:
		var along := lerpf(AHEAD.x,AHEAD.y,k/4.0)
		var c := pp+fwd*along
		var ck := Plan.cell_of(c.x,c.z)
		if tried.has(ck): continue
		tried[ck] = true
		var list: PackedFloat32Array = _trees.cell_trees(ck)
		var n := list.size()/8
		if n == 0: continue
		for s in 24:
			var q := _rng.randi_range(0,n-1)*8
			var d := Vector3(list[q]-pp.x,0.0,list[q+1]-pp.z)
			var ahead := d.dot(fwd)
			var side := absf(d.dot(right))
			if ahead < AHEAD.x or ahead > AHEAD.y or side > LANE or side < LANE_MIN: continue
			if list[q+3] < 4.0: continue
			if _taken(list[q],list[q+1],60.0): continue
			best = _tree_of(list,q)
			break
		if best != null: break
	if best == null: return
	if bird_count()+FLOCK.y > MAX_BIRDS: return
	_perch(best,0.0)
	_perch_wait = PERCH_GAP/maxf(density,0.1)

## On foot: trees round him, the ones in view first.
func _put_near(feet: Vector3, eye: Vector3) -> void:
	if _trees == null or not _trees.enabled or density <= 0.0: return
	var near := 0
	for f: Flock in flocks:
		if f.state != WHEEL and f.tree != null and Vector2(f.tree.x-feet.x,f.tree.z-feet.z).length() < FOOT_AT.y*1.3: near += 1
	if near >= ceili(FOOT_FLOCKS*density): return
	if bird_count()+FLOCK.y > MAX_BIRDS: return
	var t := _tree_near(feet,eye,FOOT_AT,40.0)
	if t == null: return
	_perch(t,FORAGE_SHARE)

## A tree `range` m from `from` (x, z), not within `apart` of a flock's,
## more often one in the eye's view.
func _tree_near(from: Vector3, eye: Vector3, ring: Vector2, apart: float) -> Crown:
	var view := get_viewport().get_camera_3d()
	var look := -view.global_basis.z if view != null else Vector3.FORWARD
	look.y = 0.0
	var c0 := Plan.cell_of(from.x,from.z)
	var cells: Array[Vector2i] = []
	for dz in range(-1,2):
		for dx in range(-1,2): cells.append(c0+Vector2i(dx,dz))
	var best: Crown = null
	var best_score := -INF
	for ck in cells:
		var list: PackedFloat32Array = _trees.cell_trees(ck)
		var n := list.size()/8
		if n == 0: continue
		for s in 10:
			var q := _rng.randi_range(0,n-1)*8
			var d := Vector2(list[q]-from.x,list[q+1]-from.z)
			var l := d.length()
			if l < ring.x or l > ring.y or list[q+3] < 4.0: continue
			if _taken(list[q],list[q+1],apart): continue
			var score := _rng.randf()
			var e := Vector2(list[q]-eye.x,list[q+1]-eye.z)
			if look.length() > 0.01 and e.length() > 0.1: score += e.normalized().dot(Vector2(look.x,look.z).normalized())
			if score > best_score:
				best_score = score
				best = _tree_of(list,q)
	return best

func _taken(x: float, z: float, apart: float) -> bool:
	for f: Flock in flocks:
		if f.state == WHEEL: continue
		for t: Crown in [f.tree,f.to]:
			if t != null and Vector2(t.x-x,t.z-z).length() < apart: return true
	return false

## A perch on tree `t`'s crown, `h` of the way up it (0 its foot, 1 the tip)
## at `angle` round it: on the cone's face, a little in.
func _crown_spot(t: Crown, h: float, angle: float) -> Vector3:
	var y := t.foot+t.crown+(t.height-t.crown)*h
	var r := t.radius*(1.0-h)*0.92
	return Vector3(t.x+cos(angle)*r,y,t.z+sin(angle)*r)

## A flock put in tree `t`, `ground` of it foraging round its foot.
func _perch(t: Crown, ground: float) -> void:
	var f := Flock.new()
	f.state = PERCH
	f.species = SPECIES_LIST[_rng.randi_range(0,SPECIES_LIST.size()-1)]
	f.tree = t
	f.size = 1.0
	f.a = Vector3(t.x,t.foot+t.height,t.z)
	f.ground = t.foot
	var n := _rng.randi_range(FLOCK.x,FLOCK.y)
	for i in n:
		var b := _new_bird(f,i,n)
		if i > 0 and _rng.randf() < ground:
			_ground_spot(f,b)
			b.mode = GROUND
		else:
			b.height = 1.0 if i == 0 else _rng.randf_range(0.45,0.95)
			b.angle = _rng.randf()*TAU
			_crown_place(f,b)
			b.mode = SAT
		b.p = b.spot
		b.face = b.spot_face
		b.timer = _rng.randf_range(0.5,SIT.y)
		f.birds.append(b)
	flocks.append(f)

func _new_bird(f: Flock, i: int, n: int) -> Bird:
	var b := Bird.new()
	# Its place in the flock: a sunflower disc, so no two crowd (no
	# separation steering needed).
	var r := sqrt((i+0.5)/float(n))
	var a := i*2.39996
	b.off = Vector3(cos(a)*r,_rng.randf_range(-0.35,0.35),sin(a)*r*1.3)
	b.seed = _rng.randf()*100.0
	b.beat = _rng.randf()*TAU
	b.bound = _rng.randf()*(BOUND.x+BOUND.y)
	b.look_at = _rng.randf()
	return b

func _crown_place(f: Flock, b: Bird) -> void:
	b.spot = _crown_spot(f.tree,b.height,b.angle)
	var out := Vector3(cos(b.angle),0.0,sin(b.angle))
	b.spot_face = out.rotated(Vector3.UP,_rng.randf_range(-0.7,0.7))

func _ground_spot(f: Flock, b: Bird) -> void:
	var a := _rng.randf()*TAU
	var r := f.tree.radius+_rng.randf_range(0.6,3.5)
	var x := f.tree.x+cos(a)*r
	var z := f.tree.z+sin(a)*r
	b.spot = Vector3(x,_field.height(x,z),z)
	b.spot_face = Vector3(cos(a+_rng.randf_range(-2.0,2.0)),0.0,sin(a+_rng.randf_range(-2.0,2.0))).normalized()
	b.peck = _rng.randf_range(PECK.x,PECK.y)

func _put_ambient(eye: Vector3) -> void:
	if ambient <= 0.0: return
	var far := 0
	for f: Flock in flocks:
		if f.state == WHEEL: far += 1
	if far >= roundi(AMBIENT*ambient): return
	if bird_count()+AMBIENT_FLOCK.y > MAX_BIRDS: return
	var view := get_viewport().get_camera_3d()
	var fwd := -view.global_basis.z if view != null else Vector3.FORWARD
	fwd.y = 0.0
	fwd = fwd.normalized() if fwd.length() > 0.01 else Vector3.FORWARD
	var dir := fwd.rotated(Vector3.UP,_rng.randf_range(-0.9,0.9))
	var c := eye+dir*_rng.randf_range(AMBIENT_AT.x,AMBIENT_AT.y)
	# Over the higher of two spots: along ridges more than in hollows.
	var c2 := c+dir.rotated(Vector3.UP,PI*0.5)*_rng.randf_range(-60.0,60.0)
	var g1: float = _field.height(c.x,c.z)
	var g2: float = _field.height(c2.x,c2.z)
	if g2 > g1:
		c = c2
		g1 = g2
	g1 = maxf(g1,Field.SEA_Y)
	var f := Flock.new()
	f.state = WHEEL
	f.species = "sparrow" if _rng.randf() < 0.7 else "goldfinch"
	f.size = AMBIENT_SIZE
	f.ground = g1
	f.centre = Vector3(c.x,g1+_rng.randf_range(AMBIENT_OVER.x,AMBIENT_OVER.y),c.z)
	f.radius = _rng.randf_range(35.0,75.0)
	f.spin = 1.0 if _rng.randf() < 0.5 else -1.0
	f.spread = _rng.randf_range(1.8,2.8)
	f.t = _rng.randf()*30.0
	var ph := _rng.randf()*TAU
	f.a = f.centre+Vector3(cos(ph),0.0,sin(ph))*f.radius
	f.av = Vector3(-sin(ph),0.0,cos(ph))*10.0*f.spin
	f.heading = f.av.normalized()
	var n := _rng.randi_range(AMBIENT_FLOCK.x,AMBIENT_FLOCK.y)
	for i in n:
		var b := _new_bird(f,i,n)
		b.mode = FLYING
		b.p = f.a+_place_off(f,b)
		b.v = f.av
		b.face = f.heading
		b.t = 10.0
		f.birds.append(b)
	flocks.append(f)

# --- Flocks --------------------------------------------------------------------------

## One flock's frame; false once it is to be dropped.
func _flock_step(f: Flock, delta: float, eye: Vector3, pp: Vector3, pv: Vector3, cruise: float, feet: Vector3) -> bool:
	f.t += delta
	var flat := Vector3(pv.x,0.0,pv.z)
	var fwd := flat.normalized() if flat.length() > 0.5 else f.heading
	var right := fwd.cross(Vector3.UP)
	match f.state:
		PERCH:
			var to := pp-f.a
			if feet == Vector3.INF and to.length() < flush_reach() and to.dot(pv) < 0.0:
				_flush(f,pp,fwd,right)
			elif feet != Vector3.INF and _clock > f.calm and _him_near(f,feet):
				_scatter(f,feet)
			elif feet == Vector3.INF and (to.dot(fwd) > 60.0 or to.length() > AHEAD.y*1.6):
				return false
			elif feet != Vector3.INF and Vector2(f.a.x-feet.x,f.a.z-feet.z).length() > FOOT_GONE:
				return false
			else:
				if (f.a-eye).length() < LIFE_NEAR: _perched_life(f,delta)
				return true
		BURST:
			# Up out of the tree and away ahead of the plane, toward the slot.
			var rise := clampf((pp.y+f.over-f.a.y)*0.9,2.0,8.0)
			var want := fwd*cruise*0.75+Vector3.UP*rise+right*f.side*2.5
			f.av = f.av.move_toward(want,delta*14.0)
			f.a += f.av*delta
			if f.t > BURST_TIME:
				f.state = RIDING
				f.t = 0.0
				stats.rode += 1
		RIDING:
			var k := clampf(f.t/maxf(ride,0.1),0.0,1.0)
			var along := lerpf(SLOT_AHEAD.x,SLOT_AHEAD.y,k)
			var slot := pp+fwd*along+right*f.side*f.lateral+Vector3.UP*f.over
			var want := pv+(slot-f.a)*1.1
			var top := cruise*TOP_SPEED
			if want.length() > top: want = want.normalized()*top
			f.av = f.av.move_toward(want,delta*10.0)
			f.a += f.av*delta
			# Left behind (a boost) or done: away.
			if f.t > ride or (pp-f.a).dot(fwd) > 25.0:
				f.state = PEEL
				f.t = 0.0
				f.peel_from = fwd
				f.climb = _rng.randf_range(-0.8,2.2)
				stats.peeled += 1
		PEEL:
			var k := smoothstep(0.0,PEEL_TIME,f.t)
			var dir := f.peel_from.rotated(Vector3.UP,-f.side*PEEL_TURN*k)
			var want := dir*cruise*PEEL_SPEED+Vector3.UP*f.climb*k
			f.av = f.av.move_toward(want,delta*6.0)
			f.a += f.av*delta
			if _gone(f,eye,GONE,PEEL_LONGEST): return false
		WHEEL:
			var rel := f.a-f.centre
			rel.y = 0.0
			var tang := Vector3(-rel.z,0.0,rel.x).normalized()*f.spin
			var pull := -rel.normalized()*(rel.length()-f.radius)*0.15
			var bob := sin(f.t*0.7+f.radius)*2.5
			var want := tang*10.0+pull+Vector3.UP*(f.centre.y+bob-f.a.y)*0.4
			f.av = f.av.move_toward(want,delta*5.0)
			f.a += f.av*delta
			f.centre += Vector3(0.6,0.0,0.3)*delta
			f.spread = lerpf(f.spread,2.3+0.8*sin(f.t*0.35+f.radius),delta*0.5)
			if (f.a-eye).length() > AMBIENT_GONE: return false
		SCATTER:
			# Round over the tree, then off.
			var rel := f.a-f.centre
			rel.y = 0.0
			var tang := Vector3(-rel.z,0.0,rel.x).normalized()*f.spin if rel.length() > 0.1 else Vector3.RIGHT
			var pull := -rel.normalized()*(rel.length()-f.radius)*0.8 if rel.length() > 0.1 else Vector3.ZERO
			var want := tang*FLIT_SPEED*0.8+pull+Vector3.UP*(f.centre.y-f.a.y)*0.8
			f.av = f.av.move_toward(want,delta*12.0)
			f.a += f.av*delta
			if f.t > f.until: _flit(f,feet if feet != Vector3.INF else eye,eye)
		FLIT:
			var top := _crown_spot(f.to,1.0,0.0)+Vector3.UP*3.0*_k/2.0
			var d := top-f.a
			var want := d.normalized()*FLIT_SPEED*clampf(d.length()/12.0,0.35,1.0)
			f.av = f.av.move_toward(want,delta*8.0)
			f.a += f.av*delta
			if d.length() < 6.0: _settle(f)
		SETTLE:
			var sat := 0
			for b: Bird in f.birds:
				if b.mode == SAT or b.mode == GROUND: sat += 1
			f.av = f.av.move_toward(Vector3.ZERO,delta*6.0)
			f.a += f.av*delta
			if sat == f.birds.size():
				f.state = PERCH
				f.t = 0.0
				f.calm = _clock+CALM
				f.a = Vector3(f.tree.x,f.tree.foot+f.tree.height,f.tree.z)
				stats.settled += 1
				return true
		LEAVE:
			var away := f.heading
			var want := away*FLIT_SPEED*1.2+Vector3.UP*1.5
			f.av = f.av.move_toward(want,delta*5.0)
			f.a += f.av*delta
			if _gone(f,eye,GONE*0.7,25.0): return false
		COVEY:
			return _covey(f,delta,pp,pv)
	# The ground under the anchor, once a frame for the flock.
	if f.state != WHEEL:
		f.ground = maxf(_field.height(f.a.x,f.a.z),Field.SEA_Y)
		if f.a.y < f.ground+3.0 and f.state != SETTLE:
			f.a.y = f.ground+3.0
			f.av.y = maxf(f.av.y,0.0)
	# The flock's frame turns smoothly with it.
	var hv := Vector3(f.av.x,0.0,f.av.z)
	if hv.length() > 1.0:
		f.heading = _turn(f.heading,hv.normalized(),1.0-exp(-delta*3.0))
	_fly_birds(f,delta,pp)
	return true

func _gone(f: Flock, eye: Vector3, far_m: float, longest: float) -> bool:
	var far := (f.a-eye).length()
	var view := get_viewport().get_camera_3d()
	var behind := view != null and (f.a-eye).dot(-view.global_basis.z) < 0.0
	return far > far_m or f.t > longest or (behind and far > GONE_BEHIND)

## Him near enough: a bird within reach across (at a run, more) and not far
## over his head, or him under the crown.
func _him_near(f: Flock, feet: Vector3) -> bool:
	var near := (RUN_NEAR if _run_speed() > RUN_PACE else FIGURE_NEAR)*maxf(_k*0.6,1.0)
	if Vector2(f.tree.x-feet.x,f.tree.z-feet.z).length() < f.tree.radius+near*0.5: return true
	for b: Bird in f.birds:
		if Vector2(b.p.x-feet.x,b.p.z-feet.z).length() < near and absf(b.p.y-feet.y) < 14.0: return true
	return false

func _flush(f: Flock, pp: Vector3, fwd: Vector3, right: Vector3) -> void:
	f.state = BURST
	f.t = 0.0
	stats.flushed += 1
	var lat := (f.a-pp).dot(right)
	f.side = signf(lat) if absf(lat) > 0.5 else (1.0 if _rng.randf() < 0.5 else -1.0)
	f.lateral = clampf(absf(lat),SLOT_SIDE.x,SLOT_SIDE.y)
	f.over = _rng.randf_range(SLOT_OVER.x,SLOT_OVER.y)
	f.av = Vector3.UP*4.0
	f.heading = fwd
	f.spread = _rng.randf_range(0.9,1.3)
	_startle(f,pp)

## Flushed on foot: out all at once, round over the tree.
func _scatter(f: Flock, feet: Vector3) -> void:
	f.state = SCATTER
	f.t = 0.0
	stats.flushed += 1
	stats.foot_flushed += 1
	f.centre = Vector3(f.tree.x,f.tree.foot+f.tree.height+3.0*_k/2.0,f.tree.z)
	f.radius = WHEEL_R*_k/2.0
	f.spin = 1.0 if _rng.randf() < 0.5 else -1.0
	f.until = _rng.randf_range(WHEEL_TIME.x,WHEEL_TIME.y)
	var away := Vector3(f.tree.x-feet.x,0.0,f.tree.z-feet.z)
	f.heading = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	f.a = Vector3(f.tree.x,f.tree.foot+f.tree.height*0.8,f.tree.z)
	f.av = Vector3.UP*4.0+f.heading*2.0
	f.spread = 0.9
	_startle(f,feet)

## Each bird off the tree in a ripple, nearest `from` first.
func _startle(f: Flock, from: Vector3) -> void:
	var near := INF
	var far := -INF
	for b: Bird in f.birds:
		var d := (b.p-from).length()
		near = minf(near,d)
		far = maxf(far,d)
	for b: Bird in f.birds:
		var d := (b.p-from).length()
		b.delay = remap(d,near,far+0.01,0.0,STARTLE_SPREAD)+_rng.randf_range(0.0,0.08)
		b.t = -b.delay
		b.hop_t = -1.0

## Off to another tree away from him, or away if there is none.
func _flit(f: Flock, feet: Vector3, eye: Vector3) -> void:
	f.t = 0.0
	var t: Crown = _tree_near(feet,eye,FLIT_TO,30.0) if _trees != null and _trees.enabled else null
	if t == null:
		f.state = LEAVE
		return
	f.to = t
	f.state = FLIT

func _settle(f: Flock) -> void:
	f.state = SETTLE
	f.t = 0.0
	f.tree = f.to
	f.to = null
	for b: Bird in f.birds:
		b.height = _rng.randf_range(0.45,0.97)
		b.angle = _rng.randf()*TAU
		_crown_place(f,b)
		b.mode = FLYING
		b.delay = 0.0
		b.t = _rng.randf_range(-0.6,0.0)

# --- The covey ---------------------------------------------------------------------

func covey_room(n: int) -> bool:
	return bird_count()+n <= MAX_BIRDS

## A covey down in the grass at `at`, on ground tilted `tilt` (height per m, x
## and z), going by `plan`. Its birds sit unseen until their turn: first the
## one nearest `from` (where the plane will cross), the others after it.
func put_covey(at: Vector3, tilt: Vector2, n: int, from: Vector3, plan: Dictionary) -> Flock:
	var f := Flock.new()
	f.state = COVEY
	f.species = "starling"
	f.plan = plan
	f.size = float(plan.size)/SPAN_SHARE
	f.a = at
	f.heading = plan.way
	var line: Vector3 = plan.line
	var right := line.cross(Vector3.UP)
	var patch: float = plan.patch
	var way: Vector3 = plan.way
	for i in n:
		var b := _new_bird(f,i,n)
		var d := Vector2.from_angle(_rng.randf()*TAU)*patch*sqrt((i+_rng.randf())/n)
		b.spot = at+Vector3(d.x,d.x*tilt.x+d.y*tilt.y,d.y)
		b.p = b.spot+Vector3.UP*0.1
		b.floor_y = b.spot.y
		b.face = Vector3.FORWARD.rotated(Vector3.UP,_rng.randf()*TAU)
		b.mode = SAT
		var lat := (b.spot-at).dot(right)
		# A split covey goes both ways round the line, each to its own side.
		b.way = way
		if plan.split and signf(lat) != signf(way.dot(right)):
			b.way = (way-right*way.dot(right)*2.0).normalized()
		b.way = b.way.rotated(Vector3.UP,_rng.randf_range(-0.14,0.14))
		b.fan = clampf(-(b.spot-at).dot(way.cross(Vector3.UP))/patch*0.7+_rng.randf_range(-0.3,0.3),-1.0,1.0)
		b.peak = float(plan.peak)*_rng.randf_range(0.65,1.3)
		b.linger = _rng.randf_range(0.75,1.35)
		b.rate = _rng.randf_range(COVEY_BEATS.x,COVEY_BEATS.y)
		b.whirr = _rng.randf_range(WHIRR.x,WHIRR.y)
		f.birds.append(b)
	_startle(f,from)
	# The ripple stretched by the flush: one first, alone; a few left behind.
	var first := INF
	for b: Bird in f.birds: first = minf(first,b.delay)
	var opened := false
	for b: Bird in f.birds:
		var k := (b.delay-first)/maxf(STARTLE_SPREAD+0.08,0.01)
		if not opened and b.delay == first:
			b.delay = 0.0
			opened = true
		else:
			b.delay = COVEY_FIRST+k*COVEY_FOLLOW*float(plan.ragged)+_rng.randf_range(0.0,0.07)
			if _rng.randf() < COVEY_LATE: b.delay += _rng.randf_range(COVEY_LATE_BY.x,COVEY_LATE_BY.y)
		b.t = -b.delay
	flocks.append(f)
	return f

## One covey's frame; false once it is over.
func _covey(f: Flock, delta: float, pp: Vector3, pv: Vector3) -> bool:
	var speed := pv.length()
	var fwd := pv/speed if speed > 1.0 else f.heading
	var n := f.birds.size()
	var shove := PackedVector3Array()
	shove.resize(n)
	# Elbows, among those in the air.
	for i in n:
		var a: Bird = f.birds[i]
		if a.mode != FLYING: continue
		for j in range(i+1,n):
			var b: Bird = f.birds[j]
			if b.mode != FLYING: continue
			var d := a.p-b.p
			var l := d.length()
			if l >= COVEY_ROOM or l < 0.001: continue
			var push := d/l*(1.0-l/COVEY_ROOM)*COVEY_SHOVE
			shove[i] += push
			shove[j] -= push
	var mid := Vector3.ZERO
	var up := 0
	var near := INF
	var read := int(_clock*60.0)
	for i in n:
		var b: Bird = f.birds[i]
		if b.mode == GROUND: continue
		b.t += delta
		if b.t < 0.0: continue
		if b.mode == SAT: _covey_lift(b)
		if (read+i)%6 == 0: b.floor_y = maxf(_field.height(b.p.x,b.p.z),Field.SEA_Y)
		near = minf(near,_covey_fly(f,b,delta,pp,fwd,speed,shove[i]))
		mid += b.p
		up += 1
	f.t += delta
	if up > 0:
		var was := f.a
		f.a = mid/up
		f.av = (f.a-was)/maxf(delta,0.001)
	stats.covey_near = minf(float(stats.covey_near),near)
	var waiting := false
	for b: Bird in f.birds:
		if b.mode != GROUND: waiting = true
	return waiting and f.t <= COVEY_LONGEST and (f.a-pp).length() <= COVEY_GONE

## Its turn: up out of the grass, wings flung up for the first stroke.
func _covey_lift(b: Bird) -> void:
	b.mode = FLYING
	b.t = 0.0
	b.v = Vector3.UP*_rng.randf_range(COVEY_SPRING.x,COVEY_SPRING.y)+b.way*COVEY_ALONG
	b.beat = PI*0.5
	b.bound = 0.0
	b.squash = 1.0
	b.pitch = 1.0
	b.face = b.way
	grass.lifted(b.spot)

## One bird's frame; its distance from the plane.
func _covey_fly(f: Flock, b: Bird, delta: float, pp: Vector3, fwd: Vector3, speed: float, shove: Vector3) -> float:
	var plan := f.plan
	var age := b.t
	var level: float = plan.level
	var calm := smoothstep(level,level+0.7,age)
	var going_down := age > float(plan.drop)*b.linger
	var over := b.p.y-b.floor_y
	var way := b.way.rotated(Vector3.UP,b.fan*float(plan.fan)*smoothstep(level*0.7,level+1.0,age))
	var pace: float = float(plan.pace)*lerpf(1.0,LEVEL_PACE,calm)*smoothstep(-0.2,0.45,age)
	var hold := b.peak*lerpf(1.0,LEVEL_PEAK,calm)
	var rise := clampf((hold-over)*COVEY_HOLD,-3.5,COVEY_CLIMB)
	if going_down:
		rise = -DOWN_SINK
		pace *= clampf(over/DOWN_FLARE,0.45,0.8)
	# The jinks: a new way to dart, less of them as it calms.
	b.jink_at -= delta
	if b.jink_at <= 0.0:
		b.jink_at = _rng.randf_range(COVEY_JINK.x,COVEY_JINK.y)*(1.0+calm*2.5)
		var across := way.cross(Vector3.UP)
		b.jink = across*_rng.randf_range(-COVEY_JINK_SIDE,COVEY_JINK_SIDE)+Vector3.UP*_rng.randf_range(-COVEY_JINK_UP,COVEY_JINK_UP)*0.6
	var want := way*pace+Vector3.UP*rise+b.jink*lerpf(1.0,0.3,calm)+shove
	# The flare: off the line, the harder the nearer and sooner the plane is.
	var rel := b.p-pp
	var along := rel.dot(fwd)
	var off := rel-fwd*along
	var off_m := off.length()
	var soon := along/maxf(speed,1.0)
	if soon > -0.1 and soon < FLARE_TIME and off_m < FLARE_NEAR:
		var flat := Vector3(off.x,off.y*0.4,off.z)
		var side := flat.normalized() if flat.length() > 0.4 else b.way
		want += side*FLARE*(1.0-maxf(soon,0.0)/FLARE_TIME)*(1.0-off_m/FLARE_NEAR)
	if not b.tossed and along < 0.0:
		b.tossed = true
		if off_m < TOSS_NEAR:
			var side := off.normalized() if off_m > 0.2 else Vector3.UP
			b.v += (side+Vector3(0.0,_rng.randf_range(-0.5,0.6),0.0))*TOSS*(1.0-off_m/TOSS_NEAR)
			b.roll += _rng.randf_range(-1.0,1.0)
			b.jink_at = 0.0
	b.v = b.v.lerp(want,1.0-exp(-delta*lerpf(COVEY_PANIC,COVEY_CALM,calm)))
	b.p += b.v*delta
	var dist := (b.p-pp).length()
	if dist < SWEPT:
		b.p = pp+(b.p-pp)/maxf(dist,0.01)*SWEPT
		dist = SWEPT
	over = b.p.y-b.floor_y
	if going_down and over < 0.4:
		b.mode = GROUND
		b.spot = b.p
		b.peck = 0.0
		return dist
	if over < 0.5 and not going_down:
		b.p.y = b.floor_y+0.5
		b.v.y = maxf(b.v.y,0.0)
	_covey_pose(b,delta,calm,going_down,over)
	return dist

## Facing, bank and a body that follows its climb, more than a flock bird's;
## the wings beating hard, then whirr and set glide, and hard again to come in.
func _covey_pose(b: Bird, delta: float, calm: float, going_down: bool, over: float) -> void:
	var flat := Vector3(b.v.x,0.0,b.v.z)
	var was := b.face
	if flat.length_squared() > 0.25: b.face = _turn(b.face,flat.normalized(),1.0-exp(-delta*11.0))
	var yaw_rate := was.cross(b.face).y/maxf(delta,0.0001)
	var bank := clampf(atan(yaw_rate*flat.length()/9.8)*0.9,-1.1,1.1)
	b.roll = lerpf(b.roll,bank,1.0-exp(-delta*9.0))
	var flaring := going_down and over < DOWN_FLARE
	var pitch := clampf(atan2(b.v.y,maxf(flat.length(),0.3))*0.9,-0.6,1.25)
	if flaring: pitch = 0.85
	b.pitch = lerpf(b.pitch,pitch,1.0-exp(-delta*12.0))
	b.squash = move_toward(b.squash,0.0,delta*4.0)
	b.bound = 0.0
	var beating := calm < 0.5 or flaring
	if not beating:
		if b.whirr > 0.0:
			b.whirr -= delta
			if b.whirr <= 0.0: b.whirr = -_rng.randf_range(GLIDE.x,GLIDE.y)
		else:
			b.whirr += delta
			if b.whirr >= 0.0: b.whirr = _rng.randf_range(WHIRR.x,WHIRR.y)
		beating = b.whirr > 0.0
	if beating:
		# The down stroke quicker than the way back up.
		var stroke := COVEY_STROKE if cos(b.beat) < 0.0 else 1.0/COVEY_STROKE
		b.beat += delta*COVEY_BEAT*b.rate*stroke
	else:
		b.beat = lerp_angle(b.beat,GLIDE_BEAT,1.0-exp(-delta*16.0))

# --- The perched life -------------------------------------------------------------------

func _perched_life(f: Flock, delta: float) -> void:
	for b: Bird in f.birds:
		match b.mode:
			SAT: _sit(f,b,delta)
			HOPPING: _hop(b,delta)
			GROUND: _forage(f,b,delta)

## On the bough: look about in quick snaps, flick the tail; after a while
## hop to another spot near along the crown.
func _sit(f: Flock, b: Bird, delta: float) -> void:
	b.timer -= delta
	b.p = b.spot
	b.face = _turn(b.face,b.spot_face,minf(delta*5.0,1.0))
	_glance(b,delta)
	if _rng.randf() < delta*FLICK_RATE: b.flick = 1.0
	if b.timer > 0.0: return
	b.timer = _rng.randf_range(SIT.x,SIT.y)
	# A hop: round and up or down the crown, within HOP_REACH.
	var reach_m := HOP_REACH*Body.SIZE*_k*1.6
	for tries in 4:
		var h := clampf(b.height+_rng.randf_range(-0.12,0.12),0.4,0.97)
		var ang := b.angle+_rng.randf_range(-0.9,0.9)
		var to := _crown_spot(f.tree,h,ang)
		if to.distance_to(b.p) > reach_m or to.distance_to(b.p) < 0.2*_k: continue
		b.height = h
		b.angle = ang
		b.hop_from = b.p
		b.hop_to = to
		b.hop_t = 0.0
		b.mode = HOPPING
		stats.hops += 1
		return

func _glance(b: Bird, delta: float) -> void:
	b.look_at -= delta
	if b.look_at <= 0.0:
		b.look_goal = _rng.randf_range(-0.9,0.9) if _rng.randf() < 0.8 else 0.0
		b.look_at = _rng.randf_range(0.4,1.6)

func _hop(b: Bird, delta: float) -> void:
	b.hop_t += delta/HOP_TIME
	var t := minf(b.hop_t,1.0)
	var flat := Vector3(b.hop_to.x-b.hop_from.x,0.0,b.hop_to.z-b.hop_from.z)
	if flat.length_squared() > 0.0001: b.face = _turn(b.face,flat.normalized(),minf(delta*20.0,1.0))
	b.p = b.hop_from.lerp(b.hop_to,t)+Vector3.UP*sin(t*PI)*0.12*_k
	b.squash = 0.6*sin(t*PI)
	if t >= 1.0:
		b.mode = SAT
		b.hop_t = -1.0
		b.squash = -0.5
		b.spot = b.hop_to
		var out := Vector3(cos(b.angle),0.0,sin(b.angle))
		b.spot_face = out.rotated(Vector3.UP,_rng.randf_range(-0.7,0.7))

## On the turf: short hops this way and that, a peck between.
func _forage(f: Flock, b: Bird, delta: float) -> void:
	if b.hop_t >= 0.0:
		b.hop_t += delta/GROUND_HOP_TIME
		var t := minf(b.hop_t,1.0)
		b.p = b.hop_from.lerp(b.hop_to,t)+Vector3.UP*sin(t*PI)*0.07*_k
		if t >= 1.0:
			b.hop_t = -1.0
			b.peck = _rng.randf_range(PECK.x,PECK.y)
			b.squash = -0.4
		return
	b.peck -= delta
	_glance(b,delta)
	if b.peck > 0.0: return
	var way := b.face.rotated(Vector3.UP,_rng.randf_range(-1.4,1.4))
	var to := b.p+way*_rng.randf_range(GROUND_HOP.x,GROUND_HOP.y)*_k
	if Vector2(to.x-b.spot.x,to.z-b.spot.z).length() > 1.6*_k or Vector2(to.x-f.tree.x,to.z-f.tree.z).length() < f.tree.radius*0.7:
		b.face = (b.spot-b.p).normalized() if b.p.distance_to(b.spot) > 0.05 else -b.face
		b.face.y = 0.0
		b.face = b.face.normalized() if b.face.length() > 0.01 else Vector3.FORWARD
		b.peck = 0.2
		return
	to.y = _field.height(to.x,to.z)
	b.face = way
	b.hop_from = b.p
	b.hop_to = to
	b.hop_t = 0.0

# --- Flying ------------------------------------------------------------------------

## A bird's place in the flock, off the anchor (world m).
func _place_off(f: Flock, b: Bird) -> Vector3:
	var fx := f.heading
	var rx := fx.cross(Vector3.UP)
	var keep := _span*f.size*1.1*sqrt(float(f.birds.size()+1))*f.spread
	var w := b.off+Vector3(sin(_clock*0.5+b.seed),sin(_clock*0.37+b.seed*1.7)*0.5,cos(_clock*0.43+b.seed))*0.12
	return rx*w.x*keep+Vector3.UP*w.y*keep*0.6-fx*w.z*keep

func _fly_birds(f: Flock, delta: float, pp: Vector3) -> void:
	if native != null and _fly_native(f,delta,pp): return
	var avoid := WorldScale.span*1.5
	var damp := 1.0-exp(-delta*RESPONSE)
	for b: Bird in f.birds:
		b.t += delta
		if f.state == SETTLE:
			_land_in(b,delta)
			continue
		if b.mode == SAT or b.mode == GROUND or b.mode == HOPPING:
			if b.t < 0.0:
				# Still sat, not yet startled: keeps its perched life.
				if b.mode == SAT: _glance(b,delta)
				_pose_air(b,delta,false)
				continue
			if b.t < CROUCH:
				# The crouch: a squat, a lean forward, the wings still folded.
				b.squash = -b.t/CROUCH
				b.pitch = lerpf(b.pitch,-0.3,minf(1.0,delta*20.0))
				continue
			# Off: up and out from the tree, wings flung up for the first stroke.
			var out := b.p-Vector3(f.tree.x,b.p.y,f.tree.z) if f.tree != null else f.heading
			out.y = 0.0
			out = out.normalized() if out.length() > 0.1 else f.heading
			b.v = Vector3.UP*_rng.randf_range(BURST_UP.x,BURST_UP.y)*0.5*(1.0+_k*0.25)+out*BURST_OUT+f.heading*2.0
			b.beat = PI*0.5
			b.bound = 0.0
			b.squash = 1.0
			b.mode = FLYING
			b.face = out
			b.t = CROUCH
		# The place on a critically damped spring: velocity eased toward the
		# place's own plus the gap's pull (a quarter of the response), so it
		# swings in on smooth arcs. Fresh from the burst, the pull fades in.
		var place := f.a+_place_off(f,b)
		var dp := place-pp
		var lp := dp.length()
		if lp < avoid: place += dp/maxf(lp,0.01)*(avoid-lp)
		place.y = maxf(place.y,f.ground+1.5)
		var gain := RESPONSE*0.25*(smoothstep(CROUCH,CROUCH+BURST_TIME*1.4,b.t) if f.state == BURST or f.state == SCATTER else 1.0)
		var want := f.av+(place-b.p)*gain
		b.v = b.v.lerp(want,damp*(0.35 if b.t < CROUCH+0.3 else 1.0))
		b.p += b.v*delta
		if b.p.y < f.ground+0.5:
			b.p.y = f.ground+0.5
			b.v.y = maxf(b.v.y,0.0)
		_pose_air(b,delta,true,f.state == BURST or f.state == SCATTER and f.t < 1.0)

## A flock all in flight, not settling, bursting or scattering, flown by
## ZenScapeBirds `fly` (its birds handed over the first time); true if so.
## Any other state hands them back to `_fly_birds` here.
func _fly_native(f: Flock, delta: float, pp: Vector3) -> bool:
	if f.state != WHEEL and f.state != RIDING and f.state != PEEL and f.state != LEAVE:
		if f.nid >= 0: _hand_back(f)
		return false
	if f.nid < 0:
		var rec := PackedFloat64Array()
		for b: Bird in f.birds:
			if b.mode != FLYING: return false
			rec.append_array([b.p.x,b.p.y,b.p.z,b.v.x,b.v.y,b.v.z,b.off.x,b.off.y,b.off.z,b.face.x,b.face.y,b.face.z,
				b.pitch,b.roll,b.t,b.beat,b.bound,b.squash,b.seed])
		f.nid = native.adopt(rec)
	native.fly(f.nid,delta,_clock,f.a,f.av,f.heading,f.size,f.spread,f.ground,pp)
	return true

## A natively flown flock's birds written back into its Birds (flight_fx.h
## BIRD_REC). `keep` leaves it flown natively (for drivers and checks).
func _hand_back(f: Flock, keep := false) -> void:
	var r: PackedFloat64Array = native.records(f.nid)
	for i in f.birds.size():
		var b: Bird = f.birds[i]
		var o := i*19
		b.p = Vector3(r[o],r[o+1],r[o+2])
		b.v = Vector3(r[o+3],r[o+4],r[o+5])
		b.off = Vector3(r[o+6],r[o+7],r[o+8])
		b.face = Vector3(r[o+9],r[o+10],r[o+11])
		b.pitch = r[o+12]
		b.roll = r[o+13]
		b.t = r[o+14]
		b.beat = r[o+15]
		b.bound = r[o+16]
		b.squash = r[o+17]
		b.look = 0.0
	if keep: return
	native.drop(f.nid)
	f.nid = -1

## Every natively flown flock's birds written back (they keep flying
## natively): for drivers that read the birds.
func sync_native() -> void:
	for f: Flock in flocks:
		if f.nid >= 0: _hand_back(f,true)

## Settling: in to its perch, slowing for the last stretch (the isles'
## approach, from its open side), then down.
func _land_in(b: Bird, delta: float) -> void:
	if b.mode == SAT or b.mode == GROUND:
		_pose_air(b,delta,false)
		return
	if b.t < 0.0:
		_pose_air(b,delta,true)
		b.p += b.v*delta
		return
	var front := b.spot+b.spot_face*0.9*_k*Body.SIZE*2.0+Vector3.UP*0.35*_k*Body.SIZE*2.0
	var goal := front if b.mode == FLYING else b.spot
	var d := goal-b.p
	if b.mode == FLYING and d.length() < 0.35*_k*0.5: b.mode = LANDING
	var speed := FLIT_SPEED*0.8 if b.mode == FLYING else 1.1*_k*0.6
	var want := d.normalized()*speed*clampf(d.length()/(1.6*_k*0.5),0.3 if b.mode == FLYING else 0.6,1.0)
	b.v = b.v.lerp(want,1.0-exp(-delta*6.0))
	b.p += b.v*delta
	if b.mode == LANDING and (b.spot-b.p).length() < 0.05*_k:
		b.p = b.spot
		b.v = Vector3.ZERO
		b.mode = SAT
		b.squash = -0.6
		b.timer = _rng.randf_range(SIT.x,SIT.y)
		_pose_air(b,delta,false)
		return
	_pose_air(b,delta,true)

## Facing, pitch, bank and the squash eased each frame; in the air, from
## the bird's own smoothed velocity.
func _pose_air(b: Bird, delta: float, airborne: bool, startled := false) -> void:
	if airborne:
		var flat := Vector3(b.v.x,0.0,b.v.z)
		var was := b.face
		if flat.length_squared() > 0.04: b.face = _turn(b.face,flat.normalized(),1.0-exp(-delta*8.0))
		# Bank into the turn: the turn rate times speed is the side pull.
		var yaw_rate := was.cross(b.face).y/maxf(delta,0.0001)
		var bank := clampf(atan(yaw_rate*flat.length()/9.8)*0.8,-0.8,0.8)
		b.roll = lerpf(b.roll,bank,1.0-exp(-delta*6.0))
		var pitch := clampf(atan2(b.v.y,maxf(flat.length(),0.3))*0.6,-0.6,0.6)
		b.pitch = lerpf(b.pitch,pitch,1.0-exp(-delta*10.0))
		b.bound = fmod(b.bound+delta,BOUND.x+BOUND.y)
		b.beat += delta*(BURST_BEAT if startled else BEAT)
	else:
		b.roll = lerpf(b.roll,0.0,1.0-exp(-delta*10.0))
		b.pitch = lerpf(b.pitch,0.0,1.0-exp(-delta*12.0))
	b.squash = move_toward(b.squash,0.0,delta*4.0)

## Level heading `a` turned `t` of the way to `b`.
static func _turn(a: Vector3, b: Vector3, t: float) -> Vector3:
	var turned := a.lerp(b,t)
	turned.y = 0.0
	return turned.normalized() if turned.length_squared() > 0.0001 else b

# --- Drawing -------------------------------------------------------------------------

func _draw() -> void:
	if native != null:
		_draw_native()
		return
	_n.fill(0)
	var lo := Vector3.INF
	var hi := -Vector3.INF
	var drawn := 0
	var dt := get_process_delta_time()
	for f: Flock in flocks:
		var k0 := maxi(_kinds.find(f.species),0)*PARTS
		var sz := _scale*f.size
		for b: Bird in f.birds:
			# Each bird's look eased (the isles' snap), its flick decayed.
			if b.mode == SAT or b.mode == GROUND:
				b.look = lerpf(b.look,b.look_goal,1.0-exp(-dt*14.0))
				b.flick = maxf(b.flick-dt*5.0,0.0)
			else: b.look = 0.0
			if drawn >= MAX_BIRDS: continue
			drawn += 1
			var yaw := atan2(-b.face.x,-b.face.z)
			var pitch := b.pitch
			var airborne := b.mode == FLYING or b.mode == LANDING
			if not airborne:
				pitch -= 0.18*b.flick
				if b.mode == GROUND and b.hop_t < 0.0: pitch -= 0.45*maxf(0.0,sin(b.peck*9.0))
			# Squash and stretch: - squat and wide, + long and thin.
			var sq := b.squash
			var s := Vector3(1.0-0.1*sq,1.0+(0.15*sq if sq < 0.0 else -0.08*sq),1.0+maxf(sq,0.0)*0.15)*sz
			var basis := Basis(Vector3.UP,yaw)*Basis(Vector3.RIGHT,pitch)*Basis(Vector3.BACK,b.roll)*Basis.from_scale(s)
			var body := Transform3D(basis,b.p)
			lo = lo.min(b.p)
			hi = hi.max(b.p)
			if not airborne:
				_put(k0+P_SIT,body)
				_put(k0+P_HEAD,body*Transform3D(Basis(Vector3.UP,b.look),_head_at))
				continue
			var beating := b.mode == LANDING or b.bound < BOUND.x*(1.4 if f.state != SETTLE else 1.0) or b.v.y > 1.2
			if not beating:
				_put(k0+P_TUCK,body)
				continue
			_put(k0+P_FLY,body)
			var landing := b.mode == LANDING
			var lift := sin(b.beat)*(0.55 if landing else 0.95)+(0.5 if landing else 0.15)
			_put(k0+P_WING_L,body*Transform3D(Basis(Vector3.BACK,-lift),_wing_at[0]))
			_put(k0+P_WING_R,body*Transform3D(Basis(Vector3.BACK,lift),_wing_at[1]))
	var pad := Vector3.ONE*(_span*AMBIENT_SIZE+1.0)
	var box := AABB(lo-pad,hi-lo+pad*2.0) if drawn > 0 else AABB()
	for k in _mm.size():
		var n := _n[k]
		_mm[k].visible_instance_count = n
		_mmi[k].visible = n > 0
		if n == 0: continue
		var at := k*MAX_BIRDS*12
		RenderingServer.multimesh_set_buffer(_mm[k].get_rid(),_data.slice(at,at+MAX_BIRDS*12))
		_mmi[k].custom_aabb = box

## `_draw` laid out by ZenScapeBirds: a natively flown flock from its own
## birds, the others from their records (flight_fx.h DRAW_REC), in order.
func _draw_native() -> void:
	var dt := get_process_delta_time()
	native.draw_begin()
	for f: Flock in flocks:
		var k0 := maxi(_kinds.find(f.species),0)*PARTS
		var sz := _scale*f.size
		if f.nid >= 0:
			native.draw_flock(f.nid,k0,sz,f.state == SETTLE)
			continue
		var rec := PackedFloat64Array()
		rec.resize(f.birds.size()*16)
		var o := 0
		for b: Bird in f.birds:
			if b.mode == SAT or b.mode == GROUND:
				b.look = lerpf(b.look,b.look_goal,1.0-exp(-dt*14.0))
				b.flick = maxf(b.flick-dt*5.0,0.0)
			else: b.look = 0.0
			rec[o] = b.mode
			rec[o+1] = b.p.x
			rec[o+2] = b.p.y
			rec[o+3] = b.p.z
			rec[o+4] = b.face.x
			rec[o+5] = b.face.z
			rec[o+6] = b.pitch
			rec[o+7] = b.roll
			rec[o+8] = b.squash
			rec[o+9] = b.flick
			rec[o+10] = b.peck
			rec[o+11] = b.hop_t
			rec[o+12] = b.look
			rec[o+13] = b.bound
			rec[o+14] = b.beat
			rec[o+15] = b.v.y
			o += 16
		native.draw_records(rec,k0,sz,f.state == SETTLE)
	var counts: PackedInt32Array = native.draw_counts()
	var drawn: int = native.drawn()
	var span_box: Array = native.draw_box()
	var lo: Vector3 = span_box[0]
	var hi: Vector3 = span_box[1]
	var pad := Vector3.ONE*(_span*AMBIENT_SIZE+1.0)
	var box := AABB(lo-pad,hi-lo+pad*2.0) if drawn > 0 else AABB()
	for k in _mm.size():
		var n := counts[k]
		_n[k] = n
		_mm[k].visible_instance_count = n
		_mmi[k].visible = n > 0
		if n == 0: continue
		RenderingServer.multimesh_set_buffer(_mm[k].get_rid(),native.part(k))
		_mmi[k].custom_aabb = box

func _put(k: int, t: Transform3D) -> void:
	var q := (k*MAX_BIRDS+_n[k])*12
	_n[k] += 1
	_data[q] = t.basis.x.x; _data[q+1] = t.basis.y.x; _data[q+2] = t.basis.z.x; _data[q+3] = t.origin.x
	_data[q+4] = t.basis.x.y; _data[q+5] = t.basis.y.y; _data[q+6] = t.basis.z.y; _data[q+7] = t.origin.y
	_data[q+8] = t.basis.x.z; _data[q+9] = t.basis.y.z; _data[q+10] = t.basis.z.z; _data[q+11] = t.origin.z

## The numbers line (F1).
func note() -> String:
	if not enabled: return "\nno birds"
	var flying := 0
	var perched := 0
	for f: Flock in flocks:
		for b: Bird in f.birds:
			if b.mode == FLYING or b.mode == LANDING: flying += 1
			else: perched += 1
	return "\nbirds: %d flying, %d perched in %d flocks  ·  %d flushed  ·  %.2f ms (avg %.2f, draw %.2f)" % [
		flying,perched,flocks.size(),int(stats.flushed),float(stats.ms),float(stats.ms_avg),float(stats.draw_ms)]+grass.note()
