extends Node
## Strain on the plane (docs/design/carry/spec-carry.md, task 10): 0 sound
## to 1 broken, made by the carry host (scripts/carry/carry_host.gd) with
## its bag and stepped each frame after the load (`step`). Numbers in
## scripts/carry/carry_weights.gd STRAIN and TEAR.
##
## - **Builds** in the air from hard moves: a turn's rate past STRAIN
##   turn_from of a full-stick turn, the nose's rate up (a pull-up), a knock
##   on stone or turf (the study's `bumps` counting up), the bag hitting
##   something (`bag_hit`). The bag's load makes each cost more (load_mul)
##   and holds it up off nothing (hold). It always eases off at `ease`/s.
## - **Shows** on the plane, not in a meter: creaks (a stick-slip of wood,
##   more and louder as it builds and on hard moves), the wings flexing up
##   (the plane's paint, shaders/folk_surface.gdshaderinc ZS_PLANE_FLEX
##   `flex`), the airframe rattling, the engine labouring (its hum and
##   propeller dipping and beating: SkyPlane `sputter`).
## - **Breaks** at 1: a part (TEAR's weights, of those on the plane) tears off
##   with a crack and falls as a loose body, and the engine dies (SkyPlane
##   `power` 0: no Boost, it settles to a glide, can't climb and sinks), so
##   it must put down; on the wheels it won't lift off (the manual
##   landing's `too_heavy`) till the part is fitted again. The part comes
##   to rest on land and lies there to be found (scripts/plane_arc/
##   wreck_arc.gd `lay_at`); into the sky it lies again on a free part spot
##   in the cluster. The plane sunk under the study's `lost` is hauled home
##   (parked broken, he by the start); put down far (TOW_FAR) from where
##   its part lies, it is hauled home as he gets out. Either way the deal
##   stays winnable.
const Weights = preload("res://scripts/carry/carry_weights.gd")
const PlaneParts = preload("res://scripts/plane_parts.gd")
const PlaneFigure = preload("res://scripts/plane_figure.gd")
const PartSpots = preload("res://scripts/plane_arc/part_spots.gd")
const SkyPlane = preload("res://scripts/sky_plane.gd")
const GenesisAudio = preload("res://scripts/genesis_audio.gd")

const SOLID_MASK := 1|(1 << 11)
const LOOSE_LAYER := 1 << 24
## The torn part's size falling (m across), its ball, how fast it leaves.
const PART_SIZE := 0.9
const PART_BALL := 0.3
const TEAR_OUT := 3.0
const TEAR_UP := 2.0
const TEAR_KEEP := 0.85
## Still under these for SETTLE_TIME s, it has come to rest.
const SETTLE_SPEED := 0.3
const SETTLE_TIME := 0.6
## Put down further than this (m, flat) from where its part lies, the
## plane is hauled home.
const TOW_FAR := 150.0

var study: Node3D = null
var strain := 0.0
## This frame's hard-move share (0 calm, 1 a full turn or pull).
var hard := 0.0
var breaks := 0
var creaks := 0
var peak := 0.0
## The part torn off last ("" none), its falling body (null once at rest).
var torn_id := ""
var falling: RigidBody3D = null
var tows := 0
var _still := 0.0
var _towed := false
var _heading := NAN
var _pitch := NAN
var _bumps := -1
var _clock := 0.0
var _creak_t := 99.0
var _creak: AudioStreamPlayer = null
var _flexed := false
static var _creak_stream: AudioStreamWAV = null

func setup(host: Node3D) -> void:
	study = host
	name = "Strain"
	_creak = AudioStreamPlayer.new()
	_creak.name = "Creak"
	_creak.bus = GenesisAudio.BUS
	if _creak_stream == null: _creak_stream = _make_creak()
	_creak.stream = _creak_stream
	add_child(_creak)

## Sound again, the engine running, nothing falling (a deal).
func reset() -> void:
	strain = 0.0
	peak = 0.0
	torn_id = ""
	_towed = false
	if falling != null: falling.queue_free()
	falling = null
	var plane: Variant = study.get("plane") if study != null else null
	if plane != null:
		plane.power = 1.0
		plane.sputter = 1.0

## Whether a part is torn off and not yet fitted again.
func broken() -> bool:
	var arc: Variant = study.get("plane_arc")
	return arc != null and arc.get("torn") != null and not (arc.torn as Dictionary).is_empty()

func _in_air() -> bool:
	var hl: Variant = study.get("hand_landing")
	return bool(study.get("flying")) and study.get("takeoff") == null and hl != null and hl.flying()

## The bag hit something `speed` m/s hard.
func bag_hit(speed: float, w: float) -> void:
	if not _in_air() or broken(): return
	_add(maxf(speed-float(Weights.STRAIN.bag_from),0.0)*float(Weights.STRAIN.bag)*_mul(w))

func _mul(w: float) -> float:
	return 1.0+float(Weights.STRAIN.load_mul)*clampf(w,0.0,1.0)

func _add(amount: float) -> void:
	strain += amount
	peak = maxf(peak,strain)

## One frame, `w` the bag's load share (carry_weights `load_of`).
func step(delta: float, w: float) -> void:
	if delta <= 0.0: return
	_clock += delta
	var plane: Variant = study.get("plane")
	var is_broken := broken()
	if plane != null: plane.power = 0.0 if is_broken else 1.0
	_falling_step(delta)
	_haul_check(is_broken)
	var S: Dictionary = Weights.STRAIN
	hard = 0.0
	if plane != null and _in_air() and not is_broken:
		var bumps := int(study.get("bumps"))
		if _bumps >= 0 and bumps > _bumps: _add(float(S.bump)*_mul(w)*float(bumps-_bumps))
		_bumps = bumps
		if not is_nan(_heading):
			var turn_rate := absf(angle_difference(_heading,float(plane.heading)))/delta/(SkyPlane.TURN_RATE*float(plane.turn_scale))
			var pull_rate := maxf(float(plane.pitch)-_pitch,0.0)/delta/SkyPlane.PITCH_SPEED
			var t := clampf((turn_rate-float(S.turn_from))/(1.0-float(S.turn_from)),0.0,1.5)
			var p := clampf((pull_rate-float(S.pull_from))/(1.0-float(S.pull_from)),0.0,1.5)
			hard = clampf(maxf(t,p),0.0,1.0)
			_add((t*float(S.turn)+p*float(S.pull))*_mul(w)*delta)
		_heading = float(plane.heading)
		_pitch = float(plane.pitch)
		strain = maxf(strain-float(S.ease)*delta,float(S.hold)*clampf(w,0.0,1.0))
		if strain >= 1.0: _tear()
	else:
		_heading = NAN
		_bumps = int(study.get("bumps")) if study.get("bumps") != null else -1
		strain = maxf(strain-float(S.ease)*delta*3.0,0.0)
	_cues(delta,plane,broken())

# --- The cues ------------------------------------------------------------------------

func _cues(delta: float, plane: Variant, is_broken: bool) -> void:
	var S: Dictionary = Weights.STRAIN
	var figure: Node3D = study.get("plane_figure")
	var flying := bool(study.get("flying"))
	var s := clampf(strain,0.0,1.0) if flying else 0.0
	if plane != null:
		var beat := 0.6+0.4*sin(_clock*11.0+sin(_clock*2.7)*3.0)
		plane.sputter = 0.0 if is_broken else 1.0-float(S.labour)*s*s*beat
		var air: Variant = study.get("air")
		if air != null and air.get("_hum_pitch") != null and flying:
			air._hum_pitch = float(air._hum_pitch)*(1.0-0.18*s*s*beat)
	if figure == null: return
	# The wings flex up with it, a flutter on top; the airframe rattles.
	var paints: Variant = figure.get("_paints")
	var flex := 0.0
	if flying and s > 0.0:
		flex = float(S.flex)*s*(0.55+0.45*hard)+0.12*s*sin(_clock*23.0)
	if paints is Dictionary and (flex != 0.0 or _flexed):
		for m: Variant in (paints as Dictionary).values():
			if m is ShaderMaterial: (m as ShaderMaterial).set_shader_parameter("flex",flex)
		_flexed = flex != 0.0
	if flying and s > 0.05:
		var r := float(S.rattle)*s*s
		var shake := Vector3(sin(_clock*71.0),sin(_clock*83.0+1.3),sin(_clock*97.0+2.1))*r
		figure.transform = Transform3D(figure.transform.basis*Basis.from_euler(shake),figure.transform.origin+shake*0.5)
	# The creaks.
	_creak_t += delta
	if flying and s > 0.2 and _creak_t > float(S.creak_gap) and randf() < float(S.creak)*pow(s,1.5)*(1.0+2.0*hard)*delta:
		_play_creak(randf_range(0.8,1.25),0.3+0.7*s)

func _play_creak(pitch: float, loud: float) -> void:
	_creak_t = 0.0
	creaks += 1
	_creak.pitch_scale = pitch
	_creak.volume_db = linear_to_db(maxf(loud,0.05))
	_creak.play()

## A wooden creak: a stick-slip of clicks slowing through a swell, each
## ringing a small resonance (the spars) and a low one (the body).
static func _make_creak() -> AudioStreamWAV:
	var rate := 22050
	var n := int(rate*0.5)
	var data := PackedByteArray()
	data.resize(n*2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w1 := TAU*560.0/rate
	var w2 := TAU*190.0/rate
	var r1 := 0.985
	var r2 := 0.993
	var a1 := 0.0
	var b1 := 0.0
	var a2 := 0.0
	var b2 := 0.0
	var phase := 0.0
	var out := PackedFloat32Array()
	out.resize(n)
	var top := 0.0
	for i in range(n):
		var t := float(i)/rate
		var u := t/0.5
		phase += lerpf(48.0,26.0,u)*(1.0+0.15*sin(t*40.0))/rate
		var x := 0.0
		if phase >= 1.0:
			phase -= 1.0
			x = 0.6+0.4*rng.randf()
		x += (rng.randf()*2.0-1.0)*0.02
		var y1 := 2.0*r1*cos(w1)*a1-r1*r1*b1+x
		b1 = a1
		a1 = y1
		var y2 := 2.0*r2*cos(w2)*a2-r2*r2*b2+x
		b2 = a2
		a2 = y2
		var env := smoothstep(0.0,0.06,t)*(1.0-smoothstep(0.3,0.5,t))
		out[i] = (y1*0.6+y2*0.4)*env
		top = maxf(top,absf(out[i]))
	for i in range(n):
		data.encode_s16(i*2,int(clampf(out[i]/maxf(top,0.0001)*0.8,-1.0,1.0)*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = data
	return wav

# --- The break -----------------------------------------------------------------------

## A part tears off (TEAR's weights, of those on the plane) and falls; the
## engine dies.
func _tear() -> void:
	var arc: Variant = study.get("plane_arc")
	var figure: Node3D = study.get("plane_figure")
	var plane: Variant = study.get("plane")
	if arc == null or figure == null or plane == null: return
	# On the plane: not missing (with --plane-fixed the found ones lie
	# laid in the world too, and the plane has all six).
	var gone: Array = arc.missing()
	var total := 0.0
	for id: String in Weights.TEAR:
		if not id in gone: total += float(Weights.TEAR[id])
	if total <= 0.0: return
	var pick := randf()*total
	var id := ""
	for k: String in Weights.TEAR:
		if k in gone: continue
		pick -= float(Weights.TEAR[k])
		id = k
		if pick <= 0.0: break
	var seat: Dictionary = PlaneFigure.SEATS.get(id,{})
	var local: Vector3 = seat.get("at",Vector3.ZERO)
	var at: Vector3 = figure.global_transform*local
	var out_dir: Vector3 = (figure.global_transform.basis*Vector3(signf(local.x) if absf(local.x) > 0.05 else 0.0,0.3,0.6)).normalized()
	arc.tear(id)
	breaks += 1
	torn_id = id
	_towed = false
	strain = 0.0
	plane.power = 0.0
	if falling != null: falling.queue_free()
	var body := RigidBody3D.new()
	body.name = "Torn_"+id
	body.collision_layer = LOOSE_LAYER
	body.collision_mask = SOLID_MASK
	body.mass = 3.0
	body.continuous_cd = true
	body.linear_damp = 0.15
	body.angular_damp = 0.8
	var shape := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = PART_BALL
	shape.shape = ball
	body.add_child(shape)
	var holder: Node3D = PlaneParts.part(id,PART_SIZE,"piece",0.0)
	holder.set("turning",false)
	if holder.has_method("beacon_on"): holder.beacon_on(false)
	body.add_child(holder)
	study.add_child(body)
	body.global_position = at
	body.linear_velocity = (plane.velocity as Vector3)*TEAR_KEEP+out_dir*TEAR_OUT+Vector3.UP*TEAR_UP
	body.angular_velocity = Vector3(randf_range(-1,1),randf_range(-1,1),randf_range(-1,1))*6.0
	falling = body
	_still = 0.0
	_play_creak(0.5,1.0)
	_pop("Crack! The %s tears off and the engine dies: put her down" % str(arc.NAMES.get(id,id)).to_lower(),3.2)
	if OS.is_debug_build(): print("strain: broke at %s, the %s torn off (speed %.1f, y %.1f)" % [at,id,float(plane.speed),at.y])

## The torn part falling: at rest on land it lies there; under the
## study's `lost`, or at rest on no floor, back on a free spot in the
## cluster.
func _falling_step(delta: float) -> void:
	if falling == null: return
	var lost_y: Variant = study.get("lost")
	var floor_y := float(lost_y) if lost_y != null and is_finite(float(lost_y)) else -200.0
	if falling.global_position.y < floor_y:
		_to_cluster("fell into the sky")
		return
	if falling.linear_velocity.length() < SETTLE_SPEED: _still += delta
	else: _still = 0.0
	if _still < SETTLE_TIME and not falling.sleeping: return
	var p := falling.global_position
	var ray := PhysicsRayQueryParameters3D.create(p+Vector3.UP*0.5,p+Vector3.DOWN*3.0,SOLID_MASK)
	var hit := falling.get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or (hit.normal as Vector3).y < 0.6:
		_to_cluster("came to rest out of reach")
		return
	var at: Vector3 = (hit.position as Vector3)+Vector3.UP*PartSpots.HOVER
	falling.queue_free()
	falling = null
	study.plane_arc.lay_at(torn_id,at)
	_pop("The %s came down on land: find it there" % str(study.plane_arc.NAMES.get(torn_id,torn_id)).to_lower(),2.6)
	if OS.is_debug_build(): print("strain: the %s came to rest at %s" % [torn_id,at])

## The torn part laid again on a free part spot in the cluster.
func _to_cluster(why: String) -> void:
	if falling != null: falling.queue_free()
	falling = null
	var taken: Array = (study.get("dealt") as Dictionary).values() if study.get("dealt") != null else []
	var boxes: Array = study.cache_spots() if study.has_method("cache_spots") else []
	var spots: Array = study.get("spot_nodes") if study.get("spot_nodes") != null else []
	var free: Array = []
	for i in range(spots.size()):
		if i in taken or i in boxes: continue
		if study.settle_spot(i) != Vector3.INF: free.append(i)
	if free.is_empty():
		for i in range(spots.size()):
			if not i in boxes and study.settle_spot(i) != Vector3.INF: free.append(i)
	if free.is_empty(): return
	var i: int = free[randi()%free.size()]
	var at: Vector3 = study.settle_spot(i)
	study.plane_arc.lay_at(torn_id,at)
	_pop("The %s %s: it lies back in the cluster" % [str(study.plane_arc.NAMES.get(torn_id,torn_id)).to_lower(),why],3.0)
	if OS.is_debug_build(): print("strain: the %s %s, laid on part spot %d at %s" % [torn_id,why,i+1,at])

## Broken, the plane sunk under `lost`: hauled home, he by the start. Out of
## it, parked TOW_FAR from where its part lies: hauled home.
func _haul_check(is_broken: bool) -> void:
	if not is_broken: return
	var plane: Variant = study.get("plane")
	var lost_y: Variant = study.get("lost")
	if bool(study.get("flying")) and plane != null and lost_y != null and float(plane.position.y) < float(lost_y):
		study.leave_plane(study.get("start"))
		tows += 1
		_pop("Down through the cloud: the broken plane is hauled home",3.0)
		return
	if bool(study.get("flying")) or _towed or not bool(study.get("parked")) or falling != null: return
	var arc: Variant = study.get("plane_arc")
	if str(arc.state.get(torn_id,"")) != "laid" or not is_instance_valid(arc.holders.get(torn_id)): return
	var part: Vector3 = (arc.holders[torn_id] as Node3D).global_position
	var parked: Vector3 = study.get("parked_at")
	if Vector2(part.x-parked.x,part.z-parked.z).length() < TOW_FAR: return
	_towed = true
	tows += 1
	study.park_home()
	study.call("_return_to_plane")
	_pop("Its %s lies far off: the plane is hauled home" % str(arc.NAMES.get(torn_id,torn_id)).to_lower(),3.0)

func _pop(text: String, seconds: float) -> void:
	var moments: Variant = study.get("_moments")
	if moments != null: moments.pop(text,seconds)
