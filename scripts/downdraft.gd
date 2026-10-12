extends Node3D
## The downdraft: the updraft's opposite, in the pilot's own wind (docs/
## design/downdraft/round1.md; docs/game-direction.md "The downdraft"). In
## the air with crouch held, Q (pad RB) spends the flow charge (scripts/
## updraft.gd, `spend_down`: the same charge and its lock, so it is one or
## the other, never chained) as a burst of wind driven straight down
## beneath him. Q alone in the air stays the updraft.
##
## - **The gather.** For GATHER s the wind draws in over him: he hangs, his
##   fall stopped and his flat pace held back to GATHER_FLAT (all of it
##   comes back), strokes of wind spiralling in and down onto him, the view
##   narrowing a touch (FOV_GATHER).
## - **The slam.** Then he's driven down (the motor's `slam`): kicked to
##   SLAM_KICK of his pace and pulled on to it, SLAM_PACE by the charge
##   spent, far past his falling pace; his flat pace kept (SLAM_KEEP), the
##   view widening (FOV_SLAM), streaks of wind riding down over him.
## - **The touch.** Landing heavy: the camera drops and shakes (KICK,
##   SHAKE), the pad thumps, and a ring of wind runs out from his feet,
##   pressing down and out (RING_*), RADIUS round by the charge. The host
##   throws dust and plays the whump off the step's "downdraft" event; his
##   landing is the motor's as ever (crouch held, the slide at his pace), so
##   he slides out of it and goes on.
## - **The push.** Everything in GROUP within the ring hears
##   `downdraft(at, radius, strength)` once, at the touch (`blast`): `at` his
##   feet, `radius` the ring's reach (m), `strength` 0..1 (STRENGTH by the
##   charge). Each decides for itself with `share` (1 at his feet, falling
##   off FALLOFF to the rim, 0 past it or more than REACH_UP of the radius
##   over or under) and `way` (out and down from his feet). The floating
##   slabs sag, tip and shove, the swing ropes swing, the bells swing,
##   loose leaves fly, the grass lies flat in a ring (scripts/pilot_wake.gd),
##   a buried find blows open (scripts/buried_find.gd), the jammed cowl
##   drops. An enemy joins GROUP and answers it (its own `knock`, as the
##   motor's, with `knock_way`).
##
## Lengths go by the walker's size (the motor's `size`, from scripts/
## world_scale.gd), paces by it to PilotMotor.PACE_POWER, as the motor's
## own.
##
## The host (studies/character_study.gd) makes it beside the updraft and
## hands it over (`updraft.downdraft`); each frame `update` before the motor
## steps, `after(events)` after it (its events merged into the step's),
## `apply_feel(camera)` once the camera is set.
const PilotMotor = preload("res://scripts/pilot_motor.gd")
const Updraft = preload("res://scripts/updraft.gd")
const Pad = preload("res://scripts/pad.gd")

## The group whatever the downdraft pushes joins (see the header).
const GROUP := &"downdraft"

# --- The move
const GATHER := 0.11            # s he hangs as the wind gathers
const GATHER_FLAT := 0.45       # share of his flat pace through the hang
const SLAM_PACE := Vector2(16.0,30.0)   # m/s down, at the least charge and at full
const SLAM_KICK := 0.7          # share of it he's kicked to at once
const SLAM_KEEP := 0.94         # share of his flat pace kept into the slam
# --- The ring and its push
const RADIUS := Vector2(3.2,7.5)        # m it reaches, least charge and full
const STRENGTH := Vector2(0.4,1.0)      # its strength, least charge and full
const FALLOFF := 0.6            # share of the push lost at the rim
const DOWN := 0.45              # down-share of the push's way (before normalising)
const REACH_UP := 0.6           # share of the radius it reaches over and under his feet
const KNOCK_OUT := 7.0          # m/s out at full, for an enemy's knock (`knock_way`)
const KNOCK_UP := 3.0           # m/s up with it, off an edge
# --- Feel
const FOV_GATHER := -3.0        # deg as it gathers
const FOV_SLAM := 7.0           # deg at full, on the way down
const FOV_EASE := 0.12          # s the view takes to follow
const KICK := 0.34              # m the camera drops on the touch, at full
const KICK_TIME := 0.42         # s it takes to drop and come back
const SHAKE := 0.07             # m of shake on the touch, at full
const SHAKE_TIME := 0.45        # s it dies over
const PULSE := Vector3(0.35,0.75,0.16)  # the pad's thump: weak, strong, s (at full)
# --- Look (the breeze ribbons' brush, as the updraft's)
const GATHER_RIBBONS := 5       # strokes spiralling in over him
const GATHER_HIGH := 2.2        # m over his feet they start
const GATHER_WIDE := 1.5        # m out they start
const SLAM_STREAKS := 4         # strokes riding down over him
const SLAM_TAIL := 0.16         # s of his path they keep
const RING_RIBBONS := 9         # strokes running out from his feet
const RING_TIME := 0.32         # s the ring takes to spread
const RING_FADE := 0.35         # s it fades over
const RING_TAIL := 0.3          # s of path each stroke keeps
const RING_PRESS := 0.7         # m over his feet a stroke starts, pressing down
const LOOSE_LIFE := 0.35        # s the gather's and slam's strokes linger after

## "" (idle), "gather" (hanging), "slam" (driven down).
var phase := ""
var lands := 0
## The last touch: {at, radius, strength, p, hit} ({} none yet); `hit` how
## many in GROUP heard it.
var last := {}
var _p := 0.0
var _t := 0.0
var _flat := Vector2.ZERO
var _size := 1.0
var _events := {}
var _clock := 0.0
var _fov := 0.0
var _fov_goal := 0.0
var _fov_applied := 0.0
var _kick_t := 0.0
var _kick_amp := 0.0
var _shake_amp := 0.0
var _cam: Camera3D
var _at := Vector3.ZERO
var _trail: Array[Dictionary] = []    # {at, t}: his path through the slam, newest last
var _rings: Array = []
var _loose: Array[Dictionary] = []    # {path, width, alpha, seed, t}
var _seeds := PackedFloat32Array()
var _mesh: ImmediateMesh
var _view: MeshInstance3D

func setup(host: Node3D) -> void:
	host.add_child(self)
	name = "Downdraft"
	_mesh = ImmediateMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/breeze_ribbon.gdshader")
	_view = MeshInstance3D.new()
	_view.name = "DowndraftWind"
	_view.mesh = _mesh
	_view.material_override = mat
	_view.top_level = true
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.extra_cull_margin = 32.0
	add_child(_view)
	for i in range(GATHER_RIBBONS): _seeds.append(randf())

func reset() -> void:
	phase = ""
	_events = {}
	_fov_goal = 0.0
	_kick_t = 0.0
	_trail.clear()
	_rings.clear()
	_loose.clear()
	if _mesh != null: _mesh.clear_surfaces()

func busy() -> bool:
	return phase != ""

## Whether a press of the key now is the downdraft's: crouch held in the
## air, free (not on a ledge, a rope, in the water, knocked or held).
func wanted(m: PilotMotor) -> bool:
	return m.crouch and not m.grounded and not m.swimming and m.hold == "" and m.rider == null and not m.recovering() and phase == ""

## Spent: the charge from the updraft, the gather begun. False with too
## little charge (then nothing happens: crouch + Q is never the updraft).
func fire(updraft: Node3D, m: PilotMotor) -> bool:
	var p: float = updraft.spend_down(m)
	if p < 0.0: return false
	_p = p
	_t = 0.0
	_size = m.size
	_flat = Vector2(m.velocity.x,m.velocity.z)
	phase = "gather"
	_fov_goal = FOV_GATHER
	_trail.clear()
	_events["downdraft_gather"] = p
	return true

## How hard it pushes for charge `p` (STRENGTH), and how far (m, RADIUS at
## size `size`).
static func strength_for(p: float) -> float:
	return lerpf(STRENGTH.x,STRENGTH.y,_k(p))

static func radius_for(p: float, size := 1.0) -> float:
	return lerpf(RADIUS.x,RADIUS.y,_k(p))*size

## The slam's pace for charge `p` (m/s, SLAM_PACE at size `size`).
static func pace_for(p: float, size := 1.0) -> float:
	return lerpf(SLAM_PACE.x,SLAM_PACE.y,_k(p))*pow(size,PilotMotor.PACE_POWER)

static func _k(p: float) -> float:
	return clampf((p-Updraft.MIN_RELEASE)/(1.0-Updraft.MIN_RELEASE),0.0,1.0)

## One frame, before the motor steps: the hang, then the slam.
func update(delta: float, m: PilotMotor) -> void:
	_clock += delta
	if _cam != null:
		if _fov_applied != 0.0: _cam.fov -= _fov_applied
		_fov_applied = 0.0
	if phase == "gather":
		_t += delta
		if m.grounded: _touch(m)
		elif m.swimming or m.hold != "" or m.rider != null or m.recovering(): _end()
		elif _t >= GATHER:
			var keep := _flat*SLAM_KEEP
			m.velocity.x = keep.x
			m.velocity.z = keep.y
			var pace := pace_for(_p,_size)
			m.slam(pace,pace*SLAM_KICK)
			phase = "slam"
			_fov_goal = FOV_SLAM*lerpf(0.5,1.0,_k(_p))
			_events["downdraft_slam"] = pace
		else:
			# The hang: his fall stopped, his flat pace held back.
			m.velocity = Vector3(_flat.x*GATHER_FLAT,0.0,_flat.y*GATHER_FLAT)
	_step_rings(delta)
	_step_loose(delta)
	_draw(m)

## After the motor's step: the touch (the slam landed, or he came down in
## the hang), or the slam ended some other way (a twirl, the water: no
## ring). Its events, to merge into the step's.
func after(events: Dictionary, m: PilotMotor) -> Dictionary:
	if phase == "slam":
		if events.has("slammed") or (m.grounded and m.move != "slam"): _touch(m)
		elif m.swimming or m.move != "slam": _end()
		else: _trail.append({"at":m.feet,"t":_clock})
	while _trail.size() > 2 and _clock-float(_trail[0].t) > SLAM_TAIL: _trail.pop_front()
	var out := _events
	_events = {}
	return out

## The touch at his feet: the ring, the push, the feel.
func _touch(m: PilotMotor) -> void:
	var at := m.feet
	var radius := radius_for(_p,_size)
	var strength := strength_for(_p)
	_let_go()
	phase = ""
	_fov_goal = 0.0
	lands += 1
	var hit := blast(get_tree(),at,radius,strength)
	last = {"at":at,"radius":radius,"strength":strength,"p":_p,"hit":hit}
	_events["downdraft"] = last
	_blast_ring(at,radius)
	_kick_t = KICK_TIME
	_kick_amp = KICK*lerpf(0.5,1.0,_k(_p))*_size
	_shake_amp = SHAKE*lerpf(0.4,1.0,_k(_p))*_size
	var k := lerpf(0.5,1.0,_k(_p))
	Pad.pulse(PULSE.x*k,PULSE.y*k,PULSE.z)

## Ended without a touch: the strokes let go.
func _end() -> void:
	_let_go()
	phase = ""
	_fov_goal = 0.0

## The push: every node in GROUP hears `downdraft(at, radius, strength)`.
## How many did. Anything may call it (an enemy's own slam, a test).
static func blast(tree: SceneTree, at: Vector3, radius: float, strength: float) -> int:
	if tree == null: return 0
	var n := 0
	for node: Node in tree.get_nodes_in_group(GROUP):
		if not is_instance_valid(node) or not node.has_method("downdraft"): continue
		node.downdraft(at,radius,strength)
		n += 1
	return n

## A point's share of a downdraft at `at`, `radius` round: 1 at the feet,
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
## downdraft at `at` pushing `point`: out from his feet and up a little,
## off an edge, by its share and strength. Zero out of reach.
static func knock_way(at: Vector3, radius: float, strength: float, point: Vector3) -> Vector3:
	var s := share(at,radius,point)*strength
	if s <= 0.0: return Vector3.ZERO
	var out := Vector3(point.x-at.x,0.0,point.z-at.z)
	out = out.normalized() if out.length() > 0.05 else Vector3.RIGHT
	return out*KNOCK_OUT*s+Vector3.UP*KNOCK_UP*s

# --- Feel ---------------------------------------------------------------------------

## The view: narrowed as it gathers, wide on the way down; on the touch a
## drop and a shake, dying fast.
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
		var u := 1.0-_kick_t/KICK_TIME
		# Down hard in the first sixth, then back up, easing.
		var drop := minf(u/0.16,1.0)*pow(1.0-u,2.0)
		var shake := pow(maxf(1.0-u*KICK_TIME/SHAKE_TIME,0.0),2.0)*_shake_amp
		var jolt := camera.global_basis.x*sin(_clock*71.0)*shake+camera.global_basis.y*sin(_clock*59.0+1.3)*shake
		camera.global_position += Vector3.DOWN*_kick_amp*drop+jolt

# --- Look ---------------------------------------------------------------------------

## The strokes on him let go where they are, to fade.
func _let_go() -> void:
	for st: Dictionary in _strokes_on(null): _loose.append({"path":st.path,"width":st.width,"alpha":st.alpha,"seed":st.seed,"t":0.0})
	_trail.clear()

func _step_loose(delta: float) -> void:
	for l: Dictionary in _loose: l.t += delta
	_loose = _loose.filter(func(l: Dictionary) -> bool: return l.t < LOOSE_LIFE)

## The ring at `origin`: strokes from over his feet pressing down to the
## ground and running out flat, curling a little.
func _blast_ring(origin: Vector3, radius: float) -> void:
	var r := {"origin":origin,"R":radius,"p":_k(_p),"t":0.0,"ribs":[]}
	for i in range(RING_RIBBONS):
		var a := (float(i)+randf()*0.6)*TAU/float(RING_RIBBONS)
		r.ribs.append({"a":a,"k":randf_range(0.75,1.0),"curl":randf_range(-0.5,0.5),"seed":randf()*100.0,
			"path":PackedVector3Array(),"times":PackedFloat32Array()})
	_rings.append(r)

func _step_rings(delta: float) -> void:
	for i in range(_rings.size()-1,-1,-1):
		var r: Dictionary = _rings[i]
		r.t += delta
		var e := 1.0-pow(1.0-clampf(r.t/(RING_TIME+RING_FADE),0.0,1.0),2.5)
		for rib: Dictionary in r.ribs:
			var a: float = rib.a+rib.curl*e
			# Down first (the first fifth), then out along the ground.
			var high := maxf(RING_PRESS*(1.0-e*5.0),0.0)+0.12+0.25*e
			var head: Vector3 = r.origin+Vector3(cos(a),0.0,sin(a))*r.R*e*rib.k+Vector3.UP*high*_size
			rib.path.append(head)
			rib.times.append(r.t)
			while rib.times.size() > 2 and r.t-rib.times[0] > RING_TAIL:
				rib.path.remove_at(0)
				rib.times.remove_at(0)
		if r.t > RING_TIME+RING_FADE: _rings.remove_at(i)

## The strokes riding on him now: the gather's spirals closing in, the
## slam's streaks over him. `m` null: as last drawn (for letting go).
var _on: Array[Dictionary] = []
func _strokes_on(m: PilotMotor) -> Array[Dictionary]:
	if m == null: return _on
	var out: Array[Dictionary] = []
	var feet := m.feet
	if phase == "gather":
		var u := clampf(_t/GATHER,0.0,1.0)
		for i in range(GATHER_RIBBONS):
			var a0 := float(i)*TAU/float(GATHER_RIBBONS)+_seeds[i]*0.8
			var path := PackedVector3Array()
			# From high and wide, spiralling in and down onto him; drawn in
			# as it gathers.
			for j in range(10):
				var s := float(j)/9.0*lerpf(0.35,1.0,u)
				var a := a0+s*2.2
				var w := lerpf(GATHER_WIDE,0.25,s)*_size
				var h := lerpf(GATHER_HIGH,0.5,s)*_size
				path.append(feet+Vector3(cos(a)*w,h,sin(a)*w))
			out.append({"path":path,"width":0.22*_size,"alpha":0.45*u,"seed":_seeds[i]*100.0})
	elif phase == "slam" and _trail.size() >= 2:
		var top: Vector3 = _trail[0].at
		var rise := maxf(top.y-feet.y,0.0)+0.8*_size
		for i in range(SLAM_STREAKS):
			var a := float(i)*TAU/float(SLAM_STREAKS)+0.4
			var path := PackedVector3Array()
			for j in range(8):
				var s := float(j)/7.0
				var w := lerpf(0.55,0.3,s)*_size
				path.append(feet+Vector3(cos(a+s*0.6)*w,lerpf(rise+1.2*_size,0.35*_size,s),sin(a+s*0.6)*w))
			out.append({"path":path,"width":0.2*_size,"alpha":0.5,"seed":float(i)*17.0})
	_on = out
	return out

## All of it, one mesh in the breeze's brush (Updraft `draw_strokes`).
func _draw(m: PilotMotor) -> void:
	if _mesh == null: return
	_mesh.clear_surfaces()
	var strokes: Array = []
	strokes.append_array(_strokes_on(m))
	for l: Dictionary in _loose:
		var u: float = l.t/LOOSE_LIFE
		strokes.append({"path":l.path,"width":l.width,"alpha":float(l.alpha)*(1.0-u)*(1.0-u),"seed":l.seed})
	for r: Dictionary in _rings:
		var fade := 1.0 if r.t <= RING_TIME else clampf(1.0-(r.t-RING_TIME)/RING_FADE,0.0,1.0)
		for rib: Dictionary in r.ribs:
			strokes.append({"path":rib.path,"width":lerpf(0.3,0.5,r.p)*_size,"alpha":lerpf(0.4,0.65,r.p)*fade,"seed":rib.seed})
	Updraft.draw_strokes(_mesh,strokes,0.3*_size)
