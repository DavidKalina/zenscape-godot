extends Node3D
## The slam: his height cashed in as impact (docs/design/slam/round2.md;
## round 1, as the downdraft, docs/design/downdraft/round1.md). In the air,
## a fresh press of crouch (Shift or C, pad LT) with at least LOW m of air
## under him drives him straight down, and what he hits with is the energy
## he brings: the height he falls plus the speed he was already falling at.
## It spends nothing. The flow charge is the updraft's alone (scripts/
## updraft.gd), and the two are a pair: the updraft lifts him, the slam
## cashes the height in. Any height counts: a long fall off a ledge, the
## top of a long jump off an edge, a twirl, an updraft's rise or its top.
##
## - **When.** Only a fresh press, with LOW m (by his size) of air over the
##   ground under him. Crouch held from the ground (the long jump, the
##   slide) carries into the air as ever and never slams; a press lower
##   than LOW keeps its old meaning, the slide on landing. Not on a ledge
##   or a rope, in the water or knocked. Under the sail a tap slams and a
##   hold brakes: a press is kept from the sail's brake for SAIL_TAP s;
##   let go inside it, the sail folds and he slams; held past it, it
##   brakes as ever.
## - **The energy.** A drop, m: the height fallen from the press to the
##   touch, plus his downward speed at the press as the height it's worth
##   (v²/2g at his falling gravity). `power_for` maps it by his size from
##   DROP.x (0) to DROP.y (1, full), straight. By that power go the ring's
##   RADIUS, the push's STRENGTH, the drive's pace, the camera's KICK, SHAKE
##   and FOV_PUNCH, the pad, the sound's weight, the clods and the cracks;
##   and whether a buried find or the jammed cowl gives (`decent`: a
##   DECENT m drop, so a hop off a step won't open them).
## - **The drive.** A HANG s catch at the top (his fall stopped, his flat
##   pace held back to HANG_FLAT), then he's driven down (the motor's
##   `slam`): kicked to SLAM_KICK of his pace and pulled on to it, SLAM_PACE
##   by the drop he has ahead (the height under him at the press), past his
##   falling pace; his flat pace kept (SLAM_KEEP), the view widening
##   (FOV_DRIVE), a short pale smear behind him (SMEAR_*): weight and speed,
##   no wind.
## - **The cancel.** A fresh Jump in the catch or the drive, with room for
##   the sail (PocketSail `can_open`: a press just before the touch is
##   still the jump out of the landing), opens the sail and ends the slam
##   with no touch (the motor's "slam_cancel"; the drive's pace past his
##   falling pace given up). A miss isn't a sure fall.
## - **The touch.** He lands heavy: the view punches in, the camera drops
##   and shakes, the pad thumps. A shockwave ring runs out flat through the
##   grass and the dust (RING_*: air pushed out by the hit, in the breeze
##   ribbons' brush, as the updraft's ring), clods of turf fly (CLODS), and
##   a scuff with cracks running out of it is left in the turf (SCUFF,
##   CRACKS), fading after SCUFF_HOLD s. The host throws dust and plays the
##   thump off the step's "slam" event; his landing is the motor's as ever
##   (crouch still held: the slide at his pace; Jump buffered: out of it).
## - **The push.** Everything in GROUP hears `slam(at, radius, strength)`
##   once, at the touch (`blast`): `at` his feet, `radius` the ring's reach
##   (m), `strength` 0..1. Each decides for itself with `share` (1 at his
##   feet, falling off FALLOFF to the rim, 0 past it or more than REACH_UP
##   of the radius over or under) and `way` (out and down from his feet).
##   The floating slabs sag, tip and shove, the swing ropes swing, the
##   bells swing, loose leaves fly, the grass lies flat in a ring (scripts/
##   pilot_wake.gd), a buried find breaks open (scripts/buried_find.gd), the
##   jammed cowl drops. An enemy joins GROUP and answers it (its own
##   `knock`, as the motor's, with `knock_way`).
##
## Lengths go by the walker's size (the motor's `size`, from scripts/
## world_scale.gd), paces by it to PilotMotor.PACE_POWER, as the motor's
## own; the drop is measured against his size, so a smaller wanderer needs
## a smaller fall for the same hit.
##
## The host (studies/character_study.gd) makes it beside the updraft; each
## frame `update(delta, motor, ground)` before the motor steps (crouch set),
## `after(events, motor)` after it (its events merged into the step's),
## `apply_feel(camera)` once the camera is set.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Updraft = preload("res://scripts/updraft.gd")
const Pad = preload("res://scripts/pad.gd")

## The group whatever the slam pushes joins (see the header).
const GROUP := &"slam"

# --- When and how hard (m at size 1)
const LOW := 1.8                 # m of air under him for a fresh press to slam
const SAIL_TAP := 0.2            # s: under the sail, let go inside this slams, held past it brakes
const DROP := Vector2(1.8,11.0)  # m of drop: the weakest hit, and full
const DECENT := 4.0              # m of drop that opens a buried find, drops the cowl
# --- The drive
const HANG := 0.05               # s he's caught at the top
const HANG_FLAT := 0.6           # share of his flat pace through the catch
const SLAM_PACE := Vector2(20.0,34.0)   # m/s down, the least drop ahead and full
const SLAM_KICK := 0.75          # share of it he's kicked to at once
const SLAM_KEEP := 0.94          # share of his flat pace kept into the drive
# --- The ring and its push
const RADIUS := Vector2(2.4,8.5)        # m it reaches, weakest and full
const STRENGTH := Vector2(0.25,1.0)     # its strength, weakest and full
const FALLOFF := 0.6             # share of the push lost at the rim
const DOWN := 0.45               # down-share of the push's way (before normalising)
const REACH_UP := 0.6            # share of the radius it reaches over and under his feet
const KNOCK_OUT := 7.0           # m/s out at full, for an enemy's knock (`knock_way`)
const KNOCK_UP := 3.0            # m/s up with it, off an edge
# --- Feel (weakest, full)
const FOV_DRIVE := Vector2(2.0,8.0)     # deg wider on the way down
const FOV_EASE := 0.12           # s the view takes to follow
const FOV_PUNCH := 5.0           # deg narrower on the touch at full, easing back
const KICK := Vector2(0.08,0.5)         # m the camera drops on the touch
const KICK_TIME := Vector2(0.3,0.55)    # s it takes to drop and come back
const SHAKE := Vector2(0.012,0.12)      # m of shake on the touch
const SHAKE_TIME := Vector2(0.2,0.6)    # s it dies over
const PULSE_WEAK := Vector2(0.15,0.55)  # the pad's light motor
const PULSE_STRONG := Vector2(0.25,1.0) # its heavy one
const PULSE_TIME := Vector2(0.1,0.28)   # s
# --- Look
const SMEAR_TAIL := 0.1          # s of his fall the smear shows behind him
const SMEAR_MOST := 3.2          # m it reaches at most
const SMEAR_WIDTH := 0.55        # m across
const SMEAR_ALPHA := 0.26        # at its thickest
const SMEAR_LINES := 4           # thin speed lines beside it
const PALE := Color(0.97,0.95,0.9)
const RING_ARCS := 6             # arcs of the shockwave ring
const RING_TIME := Vector2(0.16,0.3)    # s it takes to run out
const RING_FADE := 0.3           # s it fades over
const RING_HIGH := 0.16          # m over the ground it runs
const CLODS := Vector2i(4,18)    # clods of turf thrown
const CLOD_OUT := Vector2(1.5,6.5)      # m/s out
const CLOD_UP := Vector2(2.0,7.5)       # m/s up
const CLOD_LIFE := 1.2           # s they last
const CLOD_GRAVITY := 20.0
const SCUFF := Vector2(0.45,1.4)        # m round the scuff
const CRACKS := Vector2i(0,8)    # cracks running out of it (none under CRACK_FROM)
const CRACK_FROM := 0.15         # least power that cracks the turf
const CRACK_LONG := Vector2(0.6,2.8)    # m long
const SCUFF_HOLD := 5.0          # s it stays
const SCUFF_FADE := 2.0          # s it fades over
const EARTH := Color(0.15,0.11,0.075)

## "" (idle), "hang" (caught at the top), "drive" (driven down).
var phase := ""
var lands := 0
## The last touch: {at, radius, strength, power, drop, hit} ({} none yet);
## `hit` how many in GROUP heard it.
var last := {}
var _crouch_was := false
var _sail_t := -1.0              # s since a crouch press under the sail (-1 none)
var _from_y := 0.0               # where he pressed (y)
var _v0 := 0.0                   # m/s down at the press
var _ahead := 0.0                # power by the drop ahead at the press
var _pace := 0.0
var _t := 0.0
var _flat := Vector2.ZERO
var _size := 1.0
var _ground := Callable()
var _events := {}
var _clock := 0.0
var _fov := 0.0
var _fov_goal := 0.0
var _fov_applied := 0.0
var _kick_t := 0.0
var _kick_time := 0.4
var _kick_amp := 0.0
var _shake_amp := 0.0
var _shake_time := 0.4
var _cam: Camera3D
var _trail: Array[Dictionary] = []    # {at, t}: his path through the drive, newest last
var _rings: Array[Dictionary] = []
var _clods: Array[Dictionary] = []
var _scuff := {}                 # {at, r, cracks: [PackedVector3Array], t, p}
var _ribbons: ImmediateMesh
var _marks: ImmediateMesh
var _clod_mesh: BoxMesh
var _clod_mats: Array[StandardMaterial3D] = []

func setup(host: Node3D) -> void:
	host.add_child(self)
	name = "Slam"
	_ribbons = ImmediateMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/breeze_ribbon.gdshader")
	_view("SlamRing",_ribbons,mat)
	_marks = ImmediateMesh.new()
	var flat := StandardMaterial3D.new()
	flat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flat.vertex_color_use_as_albedo = true
	flat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	flat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_view("SlamMarks",_marks,flat)
	_clod_mesh = BoxMesh.new()
	for c: Color in [Color(0.3,0.23,0.14),Color(0.24,0.19,0.12),Color(0.32,0.41,0.19)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 1.0
		_clod_mats.append(m)

func _view(called: String, mesh: ImmediateMesh, mat: Material) -> void:
	var view := MeshInstance3D.new()
	view.name = called
	view.mesh = mesh
	view.material_override = mat
	view.top_level = true
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 32.0
	add_child(view)

func reset() -> void:
	phase = ""
	_events = {}
	_fov_goal = 0.0
	_kick_t = 0.0
	_trail.clear()
	_rings.clear()
	for c: Dictionary in _clods: (c.node as Node).queue_free()
	_clods.clear()
	_scuff = {}
	if _ribbons != null: _ribbons.clear_surfaces()
	if _marks != null: _marks.clear_surfaces()

func busy() -> bool:
	return phase != ""

## Metres of air under his feet: down to the ground under him last step,
## or to the water's top over it (a pool is a floor here, not a drop), INF
## over nothing.
static func air_under(m: PilotMotor) -> float:
	var under := maxf(m.ground_y,m.surface) if is_finite(m.surface) else m.ground_y
	return m.feet.y-under if is_finite(under) else INF

## Whether a fresh crouch press now is the slam's: in the air, LOW over the
## ground (by his size), free (not on a ledge, a rope, in the water, under
## the sail, knocked or held).
func wanted(m: PilotMotor) -> bool:
	return phase == "" and not m.grounded and not m.swimming and m.hold == "" and m.rider == null and not m.recovering() \
		and not m.seized() and m.move != "sail" and m.move != "tumble" and air_under(m) >= LOW*m.size

## The press: caught at the top, the drive's pace set by the drop ahead.
## Spends nothing.
func fire(m: PilotMotor) -> void:
	_size = m.size
	_from_y = m.feet.y
	_v0 = maxf(-m.velocity.y,0.0)
	_ahead = power_for(minf(air_under(m),DROP.y*_size)+worth(_v0,m),_size)
	_pace = pace_for(_ahead,_size)
	_flat = Vector2(m.velocity.x,m.velocity.z)
	_t = 0.0
	_trail.clear()
	phase = "hang"
	_events["slam_start"] = _ahead
	if HANG <= 0.0: _drive(m)
	else: m.velocity = Vector3(_flat.x*HANG_FLAT,0.0,_flat.y*HANG_FLAT)

## The height `down` m/s of falling is worth (v²/2g at his falling gravity).
static func worth(down: float, m: PilotMotor) -> float:
	return down*down/(2.0*m.gravity*m.fall)

## The hit's power (0..1) for a drop of `drop` m by a walker `size` big.
static func power_for(drop: float, size := 1.0) -> float:
	return clampf((drop/size-DROP.x)/(DROP.y-DROP.x),0.0,1.0)

## How hard it pushes at power `p` (STRENGTH), and how far (m, RADIUS at
## size `size`).
static func strength_for(p: float) -> float:
	return lerpf(STRENGTH.x,STRENGTH.y,p)

static func radius_for(p: float, size := 1.0) -> float:
	return lerpf(RADIUS.x,RADIUS.y,p)*size

## The drive's pace at power `p` (m/s, SLAM_PACE at size `size`).
static func pace_for(p: float, size := 1.0) -> float:
	return lerpf(SLAM_PACE.x,SLAM_PACE.y,p)*pow(size,PilotMotor.PACE_POWER)

## The least strength that breaks a buried find open or drops the cowl: a
## DECENT m drop's.
static func decent() -> float:
	return strength_for(power_for(DECENT))

## One frame, before the motor steps (its `crouch` set): a fresh press
## slams; the catch, then the drive. `ground` gives the height at (x, z),
## for laying the ring, the clods and the scuff on it.
func update(delta: float, m: PilotMotor, ground := Callable()) -> void:
	_clock += delta
	_ground = ground
	if _cam != null:
		if _fov_applied != 0.0: _cam.fov -= _fov_applied
		_fov_applied = 0.0
	var held := m.crouch
	var pressed := held and not _crouch_was
	_crouch_was = held
	if _sail_tap(delta,m,held,pressed): fire(m)
	elif pressed and wanted(m): fire(m)
	elif phase == "hang":
		_t += delta
		if m.swimming or m.hold != "" or m.rider != null or m.recovering(): _end()
		elif _t >= HANG: _drive(m)
		else: m.velocity = Vector3(_flat.x*HANG_FLAT,0.0,_flat.y*HANG_FLAT)
	_step_rings(delta)
	_step_clods(delta)
	_draw(m)

## Under the sail: a press is kept from the brake (`m.crouch` off) for
## SAIL_TAP s; let go inside it with LOW of air under him, the sail folds
## and this is the slam's (true); held past it, the brake has it.
func _sail_tap(delta: float, m: PilotMotor, held: bool, pressed: bool) -> bool:
	if m.move != "sail" or phase != "":
		_sail_t = -1.0
		return false
	if pressed: _sail_t = 0.0
	if _sail_t < 0.0: return false
	if held:
		_sail_t += delta
		if _sail_t < SAIL_TAP: m.crouch = false
		else: _sail_t = -1.0
		return false
	_sail_t = -1.0
	if m.recovering() or m.seized() or air_under(m) < LOW*m.size: return false
	m.sail.fold()
	m.move = ""
	return true

func _drive(m: PilotMotor) -> void:
	var keep := _flat*SLAM_KEEP
	m.velocity.x = keep.x
	m.velocity.z = keep.y
	m.slam(_pace,_pace*SLAM_KICK)
	phase = "drive"
	_fov_goal = lerpf(FOV_DRIVE.x,FOV_DRIVE.y,_ahead)
	_events["slam_drive"] = _pace

## After the motor's step: the touch (the drive landed, or he came down in
## the catch), or the drive ended some other way (a twirl, the water, a
## ledge: no hit). Its events, to merge into the step's.
func after(events: Dictionary, m: PilotMotor) -> Dictionary:
	if phase == "drive":
		if events.has("slammed") or (m.grounded and m.move != "slam"): _touch(m)
		elif m.swimming or m.move != "slam": _end()
		else: _trail.append({"at":m.feet,"t":_clock})
	elif phase == "hang" and m.move == "sail": _end()
	elif phase == "hang" and m.grounded: _touch(m)
	while _trail.size() > 2 and _clock-float(_trail[0].t) > SMEAR_TAIL: _trail.pop_front()
	var out := _events
	_events = {}
	return out

## The touch at his feet: the drop measured, the push, the marks, the feel.
func _touch(m: PilotMotor) -> void:
	var at := m.feet
	var drop := maxf(_from_y-at.y,0.0)+worth(_v0,m)
	var p := power_for(drop,_size)
	var radius := radius_for(p,_size)
	var strength := strength_for(p)
	phase = ""
	_trail.clear()
	_fov_goal = 0.0
	lands += 1
	var hit := blast(get_tree(),at,radius,strength)
	last = {"at":at,"radius":radius,"strength":strength,"power":p,"drop":drop,"hit":hit}
	_events["slam"] = last
	_rings.append({"at":at,"R":radius,"p":p,"t":0.0,"time":lerpf(RING_TIME.x,RING_TIME.y,p),"turn":randf()*TAU})
	_throw_clods(at,p)
	_lay_scuff(at,p)
	_kick_time = lerpf(KICK_TIME.x,KICK_TIME.y,p)
	_kick_t = _kick_time
	_kick_amp = lerpf(KICK.x,KICK.y,p)*_size
	_shake_amp = lerpf(SHAKE.x,SHAKE.y,p)*_size
	_shake_time = lerpf(SHAKE_TIME.x,SHAKE_TIME.y,p)
	_fov = -FOV_PUNCH*p
	Pad.pulse(lerpf(PULSE_WEAK.x,PULSE_WEAK.y,p),lerpf(PULSE_STRONG.x,PULSE_STRONG.y,p),lerpf(PULSE_TIME.x,PULSE_TIME.y,p))

## Ended without a touch.
func _end() -> void:
	phase = ""
	_trail.clear()
	_fov_goal = 0.0

## The push: every node in GROUP hears `slam(at, radius, strength)`. How
## many did. Anything may call it (an enemy's own slam, a test).
static func blast(tree: SceneTree, at: Vector3, radius: float, strength: float) -> int:
	if tree == null: return 0
	var n := 0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(node) or not node.has_method("slam"): continue
		node.slam(at,radius,strength)
		n += 1
	return n

## A point's share of a slam at `at`, `radius` round: 1 at the feet,
## 1-FALLOFF at the rim, 0 past it or more than REACH_UP of the radius over
## or under.
static func share(at: Vector3, radius: float, point: Vector3) -> float:
	var flat := Vector2(point.x-at.x,point.z-at.z).length()
	if radius <= 0.0 or flat > radius or absf(point.y-at.y) > radius*REACH_UP: return 0.0
	return 1.0-FALLOFF*flat/radius

## The way it pushes at `point`: out from `at` and down (straight down
## under the feet).
static func way(at: Vector3, point: Vector3) -> Vector3:
	var out := Vector3(point.x-at.x,0.0,point.z-at.z)
	if out.length() < 0.05: return Vector3.DOWN
	return (out.normalized()+Vector3.DOWN*DOWN).normalized()

## An enemy's knock (PilotMotor `knock`'s pattern: a velocity, m/s) for a
## slam at `at` pushing `point`: out from his feet and up a little, off an
## edge, by its share and strength. Zero out of reach.
static func knock_way(at: Vector3, radius: float, strength: float, point: Vector3) -> Vector3:
	var s := share(at,radius,point)*strength
	if s <= 0.0: return Vector3.ZERO
	var out := Vector3(point.x-at.x,0.0,point.z-at.z)
	out = out.normalized() if out.length() > 0.05 else Vector3.RIGHT
	return out*KNOCK_OUT*s+Vector3.UP*KNOCK_UP*s

# --- Feel ---------------------------------------------------------------------------

## The view: wide on the way down; on the touch punched in, a drop and a
## shake, all dying fast.
func apply_feel(camera: Camera3D) -> void:
	_cam = camera
	if camera == null: return
	var dt := get_process_delta_time()
	_fov = lerpf(_fov,_fov_goal,1.0-exp(-dt/FOV_EASE)) if dt > 0.0 else _fov
	if absf(_fov) > 0.01:
		camera.fov += _fov
		_fov_applied = _fov
	if _kick_t > 0.0:
		_kick_t = maxf(_kick_t-dt,0.0)
		var u := 1.0-_kick_t/_kick_time
		# Down hard in the first sixth, then back up, easing.
		var drop := minf(u/0.16,1.0)*pow(1.0-u,2.0)
		var shake := pow(maxf(1.0-u*_kick_time/_shake_time,0.0),2.0)*_shake_amp
		var jolt := camera.global_basis.x*sin(_clock*71.0)*shake+camera.global_basis.y*sin(_clock*59.0+1.3)*shake
		camera.global_position += Vector3.DOWN*_kick_amp*drop+jolt

# --- Look ---------------------------------------------------------------------------

## The ground's height at `p` (x, z), or `otherwise` without one or off a
## step more than `step` m from it.
func _ground_at(p: Vector3, otherwise: float, step: float) -> float:
	if not _ground.is_valid(): return otherwise
	var y: float = _ground.call(Vector2(p.x,p.z))
	return y if is_finite(y) and absf(y-otherwise) <= step else otherwise

func _step_rings(delta: float) -> void:
	for i in range(_rings.size()-1,-1,-1):
		_rings[i].t += delta
		if float(_rings[i].t) > float(_rings[i].time)+RING_FADE: _rings.remove_at(i)

## Clods of turf thrown out from his feet, more and faster the harder.
func _throw_clods(at: Vector3, p: float) -> void:
	if not is_inside_tree(): return
	_clod_mesh.size = Vector3(0.15,0.085,0.12)*_size
	var n := roundi(lerpf(float(CLODS.x),float(CLODS.y),p))
	for i in range(n):
		var clod := MeshInstance3D.new()
		clod.mesh = _clod_mesh
		clod.material_override = _clod_mats[i%_clod_mats.size()]
		clod.top_level = true
		clod.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(clod)
		var a := TAU*(float(i)+randf()*0.6)/float(n)
		var out := Vector3(cos(a),0.0,sin(a))
		clod.global_position = at+out*0.3*_size+Vector3.UP*0.08*_size
		var k := randf_range(0.6,1.0)
		var pace := pow(_size,PilotMotor.PACE_POWER)
		_clods.append({"node":clod,"v":(out*lerpf(CLOD_OUT.x,CLOD_OUT.y,p)*k+Vector3.UP*lerpf(CLOD_UP.x,CLOD_UP.y,p)*randf_range(0.5,1.0))*pace,
			"spin":Vector3(randf()-0.5,randf()-0.5,randf()-0.5)*16.0,"t":0.0,"floor":at.y,"rest":false})

func _step_clods(delta: float) -> void:
	for i in range(_clods.size()-1,-1,-1):
		var c: Dictionary = _clods[i]
		c.t += delta
		var node: MeshInstance3D = c.node
		if not c.rest:
			var v: Vector3 = c.v
			v.y -= CLOD_GRAVITY*delta
			c.v = v
			node.global_position += v*delta
			node.rotation += (c.spin as Vector3)*delta
			var under := _ground_at(node.global_position,float(c.floor),2.0*_size)
			if v.y < 0.0 and node.global_position.y <= under:
				node.global_position.y = under
				c.rest = true
		node.scale = Vector3.ONE*clampf(1.0-pow(float(c.t)/CLOD_LIFE,3.0),0.01,1.0)
		if c.t >= CLOD_LIFE:
			node.queue_free()
			_clods.remove_at(i)

## The scuff and its cracks, laid on the turf where he hit (the last only).
func _lay_scuff(at: Vector3, p: float) -> void:
	var cracks: Array[PackedVector3Array] = []
	var n := 0 if p < CRACK_FROM else roundi(lerpf(float(CRACKS.x)+1.0,float(CRACKS.y),(p-CRACK_FROM)/(1.0-CRACK_FROM)))
	var turn := randf()*TAU
	for i in range(n):
		var a := turn+TAU*(float(i)+randf()*0.5)/float(n)
		var long := lerpf(CRACK_LONG.x,CRACK_LONG.y,p)*randf_range(0.6,1.0)*_size
		var path := PackedVector3Array()
		for j in range(5):
			var s := float(j)/4.0
			a += randf_range(-0.35,0.35)*(1.0 if j > 0 else 0.0)
			var r := lerpf(0.25*_size,long,s)
			var pt := at+Vector3(cos(a)*r,0.0,sin(a)*r)
			pt.y = _ground_at(pt,at.y,0.6*_size)+0.025*_size
			path.append(pt)
		cracks.append(path)
	var ring := PackedVector3Array()
	var r0 := lerpf(SCUFF.x,SCUFF.y,p)*_size
	for j in range(16):
		var a := TAU*float(j)/16.0
		var pt := at+Vector3(cos(a),0.0,sin(a))*r0*randf_range(0.8,1.1)
		pt.y = _ground_at(pt,at.y,0.6*_size)+0.02*_size
		ring.append(pt)
	_scuff = {"at":at+Vector3.UP*0.03*_size,"ring":ring,"cracks":cracks,"t":_clock,"p":p}

## The ring in the breeze's brush; the smear, the scuff and the cracks in
## flat colour.
func _draw(m: PilotMotor) -> void:
	if _ribbons == null: return
	_ribbons.clear_surfaces()
	var strokes: Array = []
	for r: Dictionary in _rings:
		var t: float = r.t
		var time: float = r.time
		var u := clampf(t/time,0.0,1.0)
		var e := 1.0-pow(1.0-u,3.0)
		var fade := 1.0 if t <= time else clampf(1.0-(t-time)/RING_FADE,0.0,1.0)
		var radius: float = float(r.R)*maxf(e,0.08)
		var at: Vector3 = r.at
		for i in range(RING_ARCS):
			var a0: float = float(r.turn)+TAU*float(i)/float(RING_ARCS)
			var path := PackedVector3Array()
			for j in range(9):
				var a := a0+TAU/float(RING_ARCS)*0.82*float(j)/8.0
				var pt := at+Vector3(cos(a),0.0,sin(a))*radius
				pt.y = _ground_at(pt,at.y,1.0*_size)+RING_HIGH*_size*(1.0+0.6*e)
				path.append(pt)
			strokes.append({"path":path,"width":lerpf(0.25,0.6,float(r.p))*_size*(1.0-0.4*e),"alpha":lerpf(0.35,0.7,float(r.p))*fade,"seed":float(i)*11.0+float(r.turn)})
	Updraft.draw_strokes(_ribbons,strokes,0.3*_size)
	_marks.clear_surfaces()
	var begun := false
	if phase == "drive" and _trail.size() >= 2:
		begun = _smear(m,begun)
	if not _scuff.is_empty():
		var age := _clock-float(_scuff.t)
		if age > SCUFF_HOLD+SCUFF_FADE: _scuff = {}
		else: begun = _scuff_draw(1.0-clampf((age-SCUFF_HOLD)/SCUFF_FADE,0.0,1.0),begun)
	if begun: _marks.surface_end()

func _begin(begun: bool) -> bool:
	if not begun: _marks.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	return true

func _tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	for v in [[a,ca],[b,cb],[c,cc]]:
		_marks.surface_set_color(v[1])
		_marks.surface_add_vertex(v[0])

## The smear: a pale strip behind him along his fall, facing the camera,
## thick at his body and gone at its tail, and thin speed lines beside it.
func _smear(m: PilotMotor, begun: bool) -> bool:
	var feet := m.feet
	var top: Vector3 = _trail[0].at
	var long := clampf(top.y-feet.y,0.0,SMEAR_MOST*_size)
	if long < 0.2*_size: return begun
	begun = _begin(begun)
	var eye := _cam.global_position if _cam != null else feet+Vector3.BACK*5.0
	var side := (eye-feet).cross(Vector3.UP)
	side = side.normalized() if side.length() > 0.01 else Vector3.RIGHT
	var body := feet+Vector3.UP*0.35*_size
	var tail := feet+Vector3.UP*(1.6*_size+long)
	var w := SMEAR_WIDTH*0.5*_size
	var thick := Color(PALE,SMEAR_ALPHA)
	var gone := Color(PALE,0.0)
	_tri(body-side*w,body+side*w,tail+side*w*0.4,thick,thick,gone)
	_tri(body-side*w,tail+side*w*0.4,tail-side*w*0.4,thick,gone,gone)
	for i in range(SMEAR_LINES):
		var off := (float(i)/float(SMEAR_LINES-1)-0.5)*2.0*w*1.7
		var hi := 0.8+0.5*fposmod(float(i)*0.618,1.0)
		var a := feet+side*off+Vector3.UP*0.6*_size
		var b := a+Vector3.UP*long*hi
		var thin := 0.02*_size
		var line := Color(PALE,SMEAR_ALPHA*1.6)
		_tri(a-side*thin,a+side*thin,b,line,line,gone)
	return begun

## The scuff, dark at its middle and gone at its rim, and its cracks.
func _scuff_draw(k: float, begun: bool) -> bool:
	if k <= 0.0: return begun
	begun = _begin(begun)
	var p: float = _scuff.p
	var mid: Vector3 = _scuff.at
	var ring: PackedVector3Array = _scuff.ring
	var dark := Color(EARTH,lerpf(0.3,0.55,p)*k)
	var rim := Color(EARTH,0.0)
	for j in range(ring.size()): _tri(mid,ring[j],ring[(j+1)%ring.size()],dark,rim,rim)
	for path: PackedVector3Array in _scuff.cracks:
		for j in range(path.size()-1):
			var a := path[j]
			var b := path[j+1]
			var across := (b-a).cross(Vector3.UP)
			across = across.normalized() if across.length() > 0.001 else Vector3.RIGHT
			var wa := lerpf(0.07,0.015,float(j)/float(path.size()-1))*_size
			var wb := lerpf(0.07,0.015,float(j+1)/float(path.size()-1))*_size
			var ca := Color(EARTH*0.7,0.75*k)
			var cb := Color(EARTH*0.7,(0.75 if j+2 < path.size() else 0.0)*k)
			_tri(a-across*wa,a+across*wa,b+across*wb,ca,ca,cb)
			_tri(a-across*wa,b+across*wb,b-across*wb,ca,cb,cb)
	return begun
