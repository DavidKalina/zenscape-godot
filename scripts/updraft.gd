extends Node3D
## The updraft: flow charges it, one press of Q (pad RB) spends it straight up.
## docs/design/updraft.md. Extracted from study/wind-store (scripts/wind_store.gd).
##
## Charge (0..1) builds from moving well, never from a button: pace over
## FLOW_PACE, the notable moves (slide, long jump, wall run / kick, side flip,
## twirl, a rope ride, the jump chain) and fast airtime. Walking and plain
## running add nothing, and the open pocket sail builds nothing. After GRACE s
## without a gain it drains at DECAY a second.
##
## Press the key with at least MIN_RELEASE charge: all of it is spent, he is
## tossed straight up (flat pace kept, a fall cancelled, the sail ready again)
## and a ring blast spreads from his feet. It works anywhere: standing, out of
## a slide, in any jump, off a rope, falling.
##
## It touches the motor only through `toss`. The host calls
## `update(delta, motor, pressed)` once a frame BEFORE stepping the motor and
## `apply_feel(camera)` after the camera is set.
const PilotMotor = preload("res://scripts/pilot_motor.gd")

const GROUP := &"wind_pushable"
## Scale for lengths and speeds if the wanderer shrinks (0.83 planned).
const UNIT := 1.0

# --- Charge
const FLOW_PACE := 6.0       # m/s: pace past this charges
const PACE_GAIN := 0.05      # per m/s over FLOW_PACE, a second
const MOVE_GAIN := 0.12      # a second in a notable move or a chain
const AIR_GAIN := 0.10       # a second airborne above FLOW_PACE
const MOVE_BUMP := 0.06      # on starting a notable move
const FLOW_MOVES := ["slide","long","wallrun","kick","flip","twirl"]
const GRACE := 0.9           # s after the last gain before it drains
const DECAY := 0.4           # per s once draining
const MIN_RELEASE := 0.15    # least charge that does anything

# --- The updraft
const UP_RISE_MIN := 1.0       # m of rise from standing at charge 0...
const UP_RISE_MAX := 7.0       # m at full charge (0.15 gives 1.9 m, as the branch measured)
const RING_R_MIN := 3.0        # m the ring blast spreads to, weak
const RING_R_MAX := 8.0        # m, full
const RING_TIME := 0.4         # s the ring takes to spread out
const RING_PUSH_MIN := 0.3     # push power at the feet, weak
const RING_PUSH := 1.0         # push power at the feet, full
const RING_FALLOFF := 0.5      # share of the push lost at the rim
const RING_LIFT := 0.3         # up-share of the push direction (before normalising)
const RING_STREAKS := 28
const FADE := 0.3              # s a spent ring's streaks fade over
const DIP := 0.35              # m the camera dips at full charge, then rises
const DIP_TIME := 0.4          # s dip + rise

# --- The directional burst (stick toward travel + Q): a flat kick, no lift
const BURST_ON := true          # master toggle for the whole forward burst
const BURST_AIR_ON := true      # the mid-air version; false = Q in the air is always the updraft
const BURST_CONE := 50.0        # deg: stick within this of his flat travel is "forward"
const BURST_STICK := 0.5        # least stick length that counts
const BURST_SLOW := 3.0         # m/s: slower than this, any stick way is "forward"
const BURST_ADD_MIN := 5.0      # m/s added at charge 0.15...
const BURST_ADD_MAX := 12.0     # m/s added at full charge
const BURST_SOFT := 14.0        # m/s: bursts start adding less above this pace
const BURST_CAP := 28.0         # m/s: a burst adds nothing at this pace (soft ceiling)
const BURST_FLOOR := 0.12       # share of the add kept near the cap, so it never feels dead
const BURST_COOLDOWN := 0.6     # s between forward bursts
const BURST_AIR_SHARE := 0.6    # share of the add in mid-air
const BURST_AIR_LIFT := 0.0     # m/s of vy added in mid-air (a fall is not cancelled)
const BURST_GROUND_HOP := 0.0   # m/s of vy added on the ground (0 = stays down)
const BURST_SLIDE_TOP := 28.0   # m/s the slide's own top is raised to while a burst rides
const BURST_AIR_DRAG := 0.4     # share of the slide's air drag kept while a burst rides (it is v squared)
const BURST_RIDE := 2.5         # s the raised top lasts after a burst
const BURST_FOV := 7.0          # deg of FOV kick at full charge
const BURST_FOV_TIME := 0.5     # s the kick takes to settle
const BURST_STREAKS := 10       # wind streaks left behind
const BURST_STREAK_LEN := 1.6   # m long
const UP_SLIDE_SCALE := 1.35    # rise multiplier when the updraft fires out of a fast slide
const UP_SLIDE_PACE := 8.0      # m/s: "fast slide" for that

# --- Look
const STREAKS := 14
const IDLE_COL := Color(0.75,0.92,1.0,0.8)
const FULL_COL := Color(1.0,0.85,0.3,0.95)

var charge := 0.0
var updrafts := 0
var last_rise := 0.0            # m planned for the last updraft
var _quiet := 0.0               # s since the last gain
var _prev_move := ""
var _clock := 0.0
var _dip_t := 0.0
var _dip_amp := 0.0
var bursts := 0
var last_add := 0.0             # m/s added by the last forward burst
var _cool := 0.0
var _ride := 0.0
var _base_top := -1.0
var _base_air := 0.0
var _fov := 0.0
var _fov_applied := 0.0
var _cam: Camera3D
var _rings: Array = []
var _streaks: Array[MeshInstance3D] = []
var _streak_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D

func setup(host: Node3D) -> void:
	host.add_child(self)
	var box := BoxMesh.new()
	box.size = Vector3(0.04,0.04,0.5)*UNIT
	_streak_mat = _glow(IDLE_COL)
	for i in range(STREAKS):
		var m := MeshInstance3D.new()
		m.mesh = box
		m.material_override = _streak_mat
		m.visible = false
		add_child(m)
		_streaks.append(m)
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8*UNIT
	torus.outer_radius = 0.9*UNIT
	torus.rings = 32
	torus.ring_segments = 4
	_ring = MeshInstance3D.new()
	_ring.mesh = torus
	_ring_mat = _glow(FULL_COL)
	_ring.material_override = _ring_mat
	_ring.scale.y = 0.15
	_ring.visible = false
	add_child(_ring)

static func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	return m

func reset() -> void:
	charge = 0.0
	_cool = 0.0
	_ride = 0.0
	_quiet = 0.0
	_prev_move = ""
	_dip_t = 0.0
	for r: Dictionary in _rings: _free_ring(r)
	_rings.clear()
	_draw(Vector3.ZERO)

## One frame, before the motor steps. `pressed` is the key's press edge.
func update(delta: float, m: PilotMotor, pressed: bool, want := Vector2.ZERO) -> void:
	_clock += delta
	if _cam != null and _fov_applied != 0.0:
		_cam.fov -= _fov_applied
		_fov_applied = 0.0
	_cool = maxf(_cool-delta,0.0)
	_charge(delta,m)
	if pressed and not burst(m,want): updraft(m)
	_ride_top(delta,m)
	_step_rings(delta)
	_draw(m.feet)

func _charge(delta: float, m: PilotMotor) -> void:
	# Gliding on the pocket sail is riding the air, not flowing: it builds nothing.
	if m.recovering() or m.swimming or m.sail.open:
		_decay(delta)
		_prev_move = ""
		return
	var pace := m.speed()
	var gain := 0.0
	var over := pace-FLOW_PACE*UNIT
	if over > 0.0: gain += PACE_GAIN*over/UNIT
	var notable := m.move in FLOW_MOVES or m.rider != null
	if notable or m.chain > 0: gain += MOVE_GAIN
	if not m.grounded and over > 0.0: gain += AIR_GAIN
	var key: String = m.move if m.rider == null else "rope"
	if notable and key != _prev_move: charge = minf(charge+MOVE_BUMP,1.0)
	_prev_move = key if notable else ""
	if gain > 0.0:
		charge = minf(charge+gain*delta,1.0)
		_quiet = 0.0
	else: _decay(delta)

func _decay(delta: float) -> void:
	_quiet += delta
	if _quiet > GRACE: charge = maxf(charge-DECAY*delta,0.0)

## The updraft: all the charge straight up through `toss`, his flat pace kept
## (a fall is cancelled: vy is set, not added), and a ring blast at his feet.
## Returns false if there is too little charge.
func updraft(m: PilotMotor) -> bool:
	if charge < MIN_RELEASE or m.recovering() or m.swimming or m.seized():
		return false
	var p := charge
	charge = 0.0
	_quiet = 0.0
	updrafts += 1
	last_rise = lerpf(UP_RISE_MIN,UP_RISE_MAX,p)*UNIT
	if m.move == "slide" and m.speed() > UP_SLIDE_PACE*UNIT: last_rise *= UP_SLIDE_SCALE
	var vy := sqrt(2.0*PilotMotor.GRAVITY*last_rise)
	var face := m.facing
	var v := m.velocity
	m.toss(Vector3(v.x,maxf(vy,v.y),v.z))
	m.facing = face
	_blast_ring(m.feet+Vector3(0.0,0.1*UNIT,0.0),p)
	_dip_t = DIP_TIME
	_dip_amp = DIP*p*UNIT
	return true

## The forward burst: stick toward his travel (or any way when slow) plus the
## key adds flat pace along it, scaled by charge and eased off near BURST_CAP.
## No ring; wind streaks behind him and a FOV kick. Grounded he stays down (and
## keeps sliding); in the air it is a share, no lift. Returns false when it is
## not a forward burst (the caller then fires the updraft).
func burst(m: PilotMotor, want: Vector2) -> bool:
	if not BURST_ON or charge < MIN_RELEASE or want.length() < BURST_STICK: return false
	if m.recovering() or m.swimming or m.seized() or m.rider != null or m.hold != "": return false
	if not m.grounded and not BURST_AIR_ON: return false
	var h := Vector2(m.velocity.x,m.velocity.z)
	var pace := h.length()
	var dir := want.normalized()
	if pace > BURST_SLOW*UNIT:
		var vdir := h/pace
		if rad_to_deg(acos(clampf(vdir.dot(dir),-1.0,1.0))) > BURST_CONE: return false
		dir = (vdir+dir).normalized()
	if _cool > 0.0: return true   # a forward press inside the cooldown does nothing, not an updraft
	var p := charge
	charge = 0.0
	_quiet = 0.0
	bursts += 1
	_cool = BURST_COOLDOWN
	var soft := clampf((BURST_CAP-pace/UNIT)/(BURST_CAP-BURST_SOFT),BURST_FLOOR,1.0)
	var add := lerpf(BURST_ADD_MIN,BURST_ADD_MAX,p)*soft*UNIT
	if not m.grounded: add *= BURST_AIR_SHARE
	last_add = add
	m.velocity.x += dir.x*add
	m.velocity.z += dir.y*add
	if m.grounded: m.velocity.y += BURST_GROUND_HOP*UNIT
	else: m.velocity.y += BURST_AIR_LIFT*UNIT
	_ride = BURST_RIDE
	_streaks_behind(m.feet,dir,p)
	_fov = BURST_FOV*p
	return true

## The slide caps its pace at slide_top; while a burst rides, raise it.
func _ride_top(delta: float, m: PilotMotor) -> void:
	if _ride > 0.0:
		if _base_top < 0.0:
			_base_top = m.slide_top
			_base_air = m.slide_air
		m.slide_top = maxf(_base_top,BURST_SLIDE_TOP*UNIT)
		m.slide_air = _base_air*BURST_AIR_DRAG
		_ride -= delta
	elif _base_top >= 0.0:
		m.slide_top = _base_top
		m.slide_air = _base_air
		_base_top = -1.0

func _streaks_behind(feet: Vector3, dir: Vector2, p: float) -> void:
	var back := Vector3(-dir.x,0.0,-dir.y)
	var box := BoxMesh.new()
	box.size = Vector3(0.04,0.04,BURST_STREAK_LEN*UNIT)
	for i in range(BURST_STREAKS):
		var side := Vector3(-back.z,0.0,back.x)
		var n := MeshInstance3D.new()
		n.mesh = box
		var mat := _glow(IDLE_COL.lerp(FULL_COL,p))
		n.material_override = mat
		n.top_level = true
		add_child(n)
		var from := feet+back*randf_range(0.3,0.9)*UNIT+side*randf_range(-0.7,0.7)*UNIT+Vector3(0.0,randf_range(0.1,1.3)*UNIT,0.0)
		n.position = from
		n.basis = Basis.looking_at(back,Vector3.UP)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(n,"position",from+back*randf_range(2.0,4.0)*UNIT,0.35)
		tw.tween_property(mat,"albedo_color:a",0.0,0.35)
		tw.chain().tween_callback(n.queue_free)
	var dust := BoxMesh.new()
	dust.size = Vector3.ONE*0.16*UNIT
	for i in range(6):
		var d := MeshInstance3D.new()
		d.mesh = dust
		var dm := _glow(Color(0.6,0.55,0.5,0.5))
		d.material_override = dm
		d.top_level = true
		add_child(d)
		d.position = feet
		var tw := create_tween().set_parallel(true)
		tw.tween_property(d,"position",feet+back*randf_range(1.0,2.5)*UNIT+Vector3(randf_range(-0.5,0.5),randf_range(0.2,0.7),randf_range(-0.5,0.5))*UNIT,0.45)
		tw.tween_property(dm,"albedo_color:a",0.0,0.45)
		tw.chain().tween_callback(d.queue_free)

## The camera dips, then rises, after an updraft; a burst kicks the FOV.
func apply_feel(camera: Camera3D) -> void:
	_cam = camera
	if _fov > 0.01 and camera != null:
		_fov = maxf(_fov-BURST_FOV*get_process_delta_time()/BURST_FOV_TIME,0.0)
		camera.fov += _fov
		_fov_applied = _fov
	if _dip_t > 0.0 and camera != null:
		_dip_t = maxf(_dip_t-get_process_delta_time(),0.0)
		var u := 1.0-_dip_t/DIP_TIME
		var y := -sin(u*TAU)*(1.0-u)   # down first, then up past level, settled
		camera.global_position.y += _dip_amp*y

func _blast_ring(origin: Vector3, p: float) -> void:
	var r := {"origin":origin,"p":p,"t":0.0,"R":lerpf(RING_R_MIN,RING_R_MAX,p)*UNIT,"hit":{},"streaks":[],
		"mat":_glow(IDLE_COL.lerp(FULL_COL,p))}
	var box := BoxMesh.new()
	box.size = Vector3(0.05,0.05,0.8)*UNIT
	for i in range(RING_STREAKS):
		var s := MeshInstance3D.new()
		s.mesh = box
		s.material_override = r.mat
		s.top_level = true
		s.visible = false
		add_child(s)
		var a := (float(i)+randf()*0.6)*TAU/float(RING_STREAKS)
		r.streaks.append({"node":s,"a":a,"k":randf_range(0.75,1.0)})
	# Dust kicked up at his feet.
	var dust := BoxMesh.new()
	dust.size = Vector3.ONE*0.18*UNIT
	for i in range(8):
		var d := MeshInstance3D.new()
		d.mesh = dust
		var dm := _glow(Color(0.6,0.55,0.5,0.5))
		d.material_override = dm
		d.top_level = true
		add_child(d)
		var a := randf()*TAU
		d.position = origin
		var to := origin+Vector3(cos(a),0.5,sin(a))*randf_range(0.8,1.6)*UNIT*(0.5+p)
		var tw := create_tween().set_parallel(true)
		tw.tween_property(d,"position",to,0.5)
		tw.tween_property(dm,"albedo_color:a",0.0,0.5)
		tw.chain().tween_callback(d.queue_free)
	_rings.append(r)

func _free_ring(r: Dictionary) -> void:
	for st: Dictionary in r.streaks: (st.node as Node).queue_free()

func _step_rings(delta: float) -> void:
	for i in range(_rings.size()-1,-1,-1):
		var r: Dictionary = _rings[i]
		r.t += delta
		var k := clampf(r.t/RING_TIME,0.0,1.0)
		var radius: float = r.R*k
		var fade := 1.0 if r.t <= RING_TIME else clampf(1.0-(r.t-RING_TIME)/FADE,0.0,1.0)
		r.mat.albedo_color.a = 0.85*fade
		for st: Dictionary in r.streaks:
			var s: MeshInstance3D = st.node
			var way := Vector3(cos(st.a),0.0,sin(st.a))
			s.visible = radius > 0.3*UNIT and fade > 0.0
			s.position = r.origin+way*radius*st.k
			s.basis = Basis.looking_at(way,Vector3.UP)
		# Anything in the group "wind_pushable" (swing ropes) is shoved once
		# as the rim passes: wind_push(origin, dir, power).
		for n: Node in get_tree().get_nodes_in_group(GROUP):
			if not n.has_method("wind_push") or r.hit.has(n.get_instance_id()): continue
			var at: Vector3 = n.wind_point() if n.has_method("wind_point") else (n as Node3D).global_position
			var v: Vector3 = at-r.origin
			var flat := Vector3(v.x,0.0,v.z)
			if flat.length() > radius or absf(v.y) > r.R*0.6: continue
			r.hit[n.get_instance_id()] = true
			var way := flat.normalized() if flat.length() > 0.05 else Vector3.RIGHT
			var push := (way+Vector3.UP*RING_LIFT).normalized()
			var power: float = lerpf(RING_PUSH_MIN,RING_PUSH,r.p)*(1.0-RING_FALLOFF*flat.length()/r.R)
			n.wind_push(r.origin,push,power)
		if r.t > RING_TIME+FADE:
			_free_ring(r)
			_rings.remove_at(i)

## The charge swirl on the wanderer; at full, all gold with a pulsing ring.
func _draw(feet: Vector3) -> void:
	var full := charge >= 0.999
	_streak_mat.albedo_color = IDLE_COL.lerp(FULL_COL,clampf((charge-0.6)/0.4,0.0,1.0))
	var shown := ceili(charge*STREAKS)
	var spin := 3.0+9.0*charge
	for i in range(STREAKS):
		var s := _streaks[i]
		s.visible = i < shown and charge > 0.02
		if not s.visible: continue
		var a := _clock*spin+float(i)*TAU/float(STREAKS)*2.0
		var h := fposmod(float(i)*0.618,1.0)
		var r := (0.55+0.08*sin(_clock*3.0+float(i)))*UNIT*(1.0+0.25*charge)
		s.position = feet+Vector3(cos(a)*r,(0.12+1.5*h)*UNIT,sin(a)*r)
		s.basis = Basis.looking_at(Vector3(-sin(a),0.25,cos(a)).normalized(),Vector3.UP)
		s.scale = Vector3(1.0,1.0,0.5+charge)
	_ring.visible = full
	if full:
		_ring.position = feet+Vector3(0.0,0.06,0.0)
		var pulse := 1.0+0.15*sin(_clock*14.0)
		_ring.scale = Vector3(pulse,0.15,pulse)
