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
## The charge is the updraft's alone. Its pair is the slam (scripts/slam.gd),
## which spends nothing: the updraft lifts him, and a fresh crouch press up
## there cashes the height in as impact. Updraft then slam in one airtime
## is the combo; it gains no height overall, as the next updraft needs the
## charge built afresh from flow.
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
## After a forward burst nothing charges until its ride is over, the slide it
## rode has ended and his pace is back to what it was before the burst (or
## SPENT_MOST s pass): the burst's own pace never refills it, so bursts can't
## be chained by spamming the key. At least SPENT_LEAST s either way.
const SPENT_LEAST := 1.2
const SPENT_MOST := 5.0

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
const RING_RIBBONS := 7       # strokes curling out from his feet
const RING_TAIL := 0.35        # s of path each keeps
const FADE := 0.3              # s a spent ring's streaks fade over
const DIP := 0.35              # m the camera dips at full charge, then rises
const DIP_TIME := 0.4          # s dip + rise

# --- The directional burst (stick toward travel + Q): a flat kick, no lift
const BURST_ON := true          # master toggle for the whole forward burst
const BURST_AIR_ON := false        # the mid-air version; off: Q in the air is always the updraft
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
const BURST_FOV := 5.0          # deg of FOV kick at full charge
const BURST_FOV_TIME := 0.5     # s the kick takes to settle
const UP_SLIDE_SCALE := 1.35    # rise multiplier when the updraft fires out of a fast slide
const UP_SLIDE_PACE := 8.0      # m/s: "fast slide" for that

# --- Segments (the wind gauge, docs/design/wind-gauge/spec-wind-gauge.md).
## Off (the default): every unleash spends all the charge, its strength
## scaled by it. On (`segmented`, set by kit_isle): the charge is SEGMENTS
## equal parts, and each unleash (updraft, burst, gust shot) spends one at a
## fixed strength; the partial part above them is kept.
const SEGMENTS := 3
const SEG := 1.0/SEGMENTS
const SEG_HAIR := 0.002         # charge this short of a segment still counts as one
const SEG_RISE := 3.2           # m one segment's updraft lifts him (from a standstill in the air)
const SEG_CHAIN := 0.6          # each further updraft in one airtime rises this share of the one before
const SEG_UP_P := 0.5           # charge-equivalent look (ring, dip) of a one-segment updraft
const SEG_BURST_P := 0.6        # charge-equivalent strength of a one-segment forward burst
const SEG_SHOT_P := 0.7         # charge-equivalent strength handed to the gust shot
## Segmented only: Q / RB in a grounded slide is the forward burst along the
## slide's travel, whatever the stick (off: the old stick-toward-travel rule).
const SLIDE_BOOST := true
## Segmented only: the charge comes from moves through the air, not the
## ground. Running and sliding build nothing; each air move starting bumps it
## (SEG_BUMPS, about three to a segment), held air moves add per second
## (SEG_HOLDS), and airtime at pace over FLOW_PACE adds SEG_AIR a second (not
## while his own updrafts carry him). Off: the old pace-and-moves rule.
const AIR_CHARGE := true
const SEG_BUMPS := {"flip":0.14,"kick":0.14,"long":0.12,"wallrun":0.12,"rope":0.12,"twirl":0.09,"pump":0.06}
const SEG_HOLDS := {"wallrun":0.10,"rope":0.08}
const SEG_AIR := 0.06           # a second airborne above FLOW_PACE
## The gentler drain (segmented): the lull before it starts, then per second
## for the partial part over the full segments; full segments are held till
## SEG_HELD_GRACE s of lull, then drain at SEG_DECAY_HELD (~22 s a segment).
const SEG_GRACE := 3.0
const SEG_DECAY := 0.04
const SEG_HELD_GRACE := 15.0
const SEG_DECAY_HELD := 0.015

# --- Look: the charge is a wake of wind behind him, drawn in the breeze
# ribbons' brush (shaders/breeze_ribbon.gdshader), as the dragon's breath is.
const WAKE_STRANDS := 3         # strokes in the wake at full charge
const WAKE_TAIL := 0.9          # s of his path the wake keeps
const WAKE_SAMPLE := 1.0/30.0   # s between samples of it
const WAKE_SIDE := [-0.35,0.3,0.05]   # m each strand rides off his line, at his heels...
const WAKE_HIGH := [0.55,0.95,1.35]   # m over his feet
const WAKE_SPREAD := 1.8        # ...the offsets grown this much by the tail: the wake opens
const WAKE_RISE := 0.35         # m the tail drifts up
const WAKE_WIDTH := 0.22        # m, at full charge
const WAKE_ALPHA := 0.45        # peak opacity at full charge
const WAKE_FADE := 0.4          # s the shown charge eases toward the charge
const WAKE_MIN_RUN := 0.6       # m of path before a strand is drawn
const LOOSE_LIFE := 0.7         # s a spent wake lingers, drifting back
const LOOSE_DRIFT := 3.0        # m/s it drifts back along the burst
const FLARE_TIME := 0.5         # s a burst flares the loose strands wider

var charge := 0.0
## Segments on (SEG*): see above.
var segmented := false
## A press of the key with no segment to spend (segmented only): the wind
## gauge's empty cue.
signal empty_press
var _air_ups := 0               # updrafts since he last stood on the ground
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
## Charging is locked after a forward burst (SPENT_*): s since, and the pace
## he had before it.
var spent := false
var _spent_t := 0.0
var _spent_pace := 0.0
var _shown := 0.0               # the charge as drawn, eased (WAKE_FADE)
var _trail: Array[Dictionary] = []   # {at, side, t}: his recent path, newest last
var _trail_carry := 0.0
var _loose: Array[Dictionary] = []   # {path, width, alpha, seed, t, drift}
var _mesh: ImmediateMesh
var _view: MeshInstance3D

func setup(host: Node3D) -> void:
	host.add_child(self)
	_mesh = ImmediateMesh.new()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/breeze_ribbon.gdshader")
	_view = MeshInstance3D.new()
	_view.name = "UpdraftWake"
	_view.mesh = _mesh
	_view.material_override = mat
	_view.top_level = true
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_view.extra_cull_margin = 32.0
	add_child(_view)

func reset() -> void:
	charge = 0.0
	_shown = 0.0
	_cool = 0.0
	_ride = 0.0
	_quiet = 0.0
	_prev_move = ""
	_dip_t = 0.0
	spent = false
	_rings.clear()
	_trail.clear()
	_loose.clear()
	if _mesh != null: _mesh.clear_surfaces()

## One frame, before the motor steps. `pressed` is the key's press edge.
func update(delta: float, m: PilotMotor, pressed: bool, want := Vector2.ZERO) -> void:
	_clock += delta
	if _cam != null and _fov_applied != 0.0:
		_cam.fov -= _fov_applied
		_fov_applied = 0.0
	_cool = maxf(_cool-delta,0.0)
	_unlock(delta,m)
	_charge(delta,m)
	if m.grounded: _air_ups = 0
	if pressed and not burst(m,want) and not updraft(m) and segmented and not can_spend():
		empty_press.emit()
	_ride_top(delta,m)
	_step_rings(delta)
	_track(delta,m)
	_draw()

## The lock after a burst: lifted once its ride is over, the slide has ended
## and his pace is back to what it was before (SPENT_LEAST..SPENT_MOST s).
func _unlock(delta: float, m: PilotMotor) -> void:
	if not spent: return
	_spent_t += delta
	var settled := _ride <= 0.0 and m.move != "slide" and m.speed() <= _spent_pace+0.5*UNIT
	if _spent_t >= SPENT_MOST or (_spent_t >= SPENT_LEAST and settled):
		spent = false
		_prev_move = m.move

func _charge(delta: float, m: PilotMotor) -> void:
	if segmented and AIR_CHARGE:
		_air_charge(delta,m)
		return
	# Gliding on the pocket sail is riding the air, not flowing: it builds nothing.
	if spent or m.recovering() or m.swimming or m.sail.open:
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

## Segmented charge from the air (AIR_CHARGE). A burst's `spent` lock does
## not block it: the ground pace a burst gives builds nothing here.
func _air_charge(delta: float, m: PilotMotor) -> void:
	if m.recovering() or m.swimming or m.sail.open:
		_decay(delta)
		_prev_move = ""
		return
	var key: String = m.move if m.rider == null else "rope"
	var gain := 0.0
	if key in SEG_BUMPS and key != _prev_move:
		charge = minf(charge+float(SEG_BUMPS[key]),1.0)
		_quiet = 0.0
	if key in SEG_HOLDS: gain += float(SEG_HOLDS[key])
	if not m.grounded and m.rider == null and _air_ups == 0 and m.speed() > FLOW_PACE*UNIT:
		gain += SEG_AIR
	_prev_move = key
	if gain > 0.0:
		charge = minf(charge+gain*delta,1.0)
		_quiet = 0.0
	elif key in SEG_BUMPS: _quiet = 0.0   # mid flip, mid kick: no drain
	else: _decay(delta)

func _decay(delta: float) -> void:
	_quiet += delta
	if not (segmented and AIR_CHARGE):
		if _quiet > GRACE: charge = maxf(charge-DECAY*delta,0.0)
		return
	if _quiet <= SEG_GRACE: return
	var whole := floorf((charge+SEG_HAIR)/SEG)*SEG
	if charge > whole+SEG_HAIR: charge = maxf(charge-SEG_DECAY*delta,whole)
	elif _quiet > SEG_HELD_GRACE: charge = maxf(charge-SEG_DECAY_HELD*delta,0.0)

## The least charge an unleash takes: a segment, or MIN_RELEASE unsegmented.
func least() -> float:
	return SEG-SEG_HAIR if segmented else MIN_RELEASE

## Whether there is a segment (or, unsegmented, enough charge) to spend.
func can_spend() -> bool:
	return charge >= least()

## Spends what one unleash takes and returns its strength (0..1, as charge):
## one segment at `fixed`, or unsegmented all of it at its own size.
func _take(fixed: float) -> float:
	_quiet = 0.0
	if segmented:
		charge = maxf(charge-SEG,0.0)
		if charge < SEG_HAIR: charge = 0.0
		return fixed
	var p := charge
	charge = 0.0
	return p

## The updraft: all the charge straight up through `toss`, his flat pace kept
## (a fall is cancelled: vy is set, not added), and a ring blast at his feet.
## Returns false if there is too little charge.
func updraft(m: PilotMotor) -> bool:
	if not can_spend() or m.recovering() or m.swimming or m.seized():
		return false
	var p := _take(SEG_UP_P)
	updrafts += 1
	last_rise = lerpf(UP_RISE_MIN,UP_RISE_MAX,p)*UNIT
	if segmented: last_rise = SEG_RISE*pow(SEG_CHAIN,_air_ups)*UNIT
	_air_ups += 1
	if m.move == "slide" and m.speed() > UP_SLIDE_PACE*UNIT: last_rise *= UP_SLIDE_SCALE
	var vy := sqrt(2.0*PilotMotor.GRAVITY*last_rise)
	var face := m.facing
	var v := m.velocity
	m.toss(Vector3(v.x,maxf(vy,v.y),v.z))
	m.facing = face
	_let_go(Vector3.ZERO)
	_blast_ring(m.feet+Vector3(0.0,0.1*UNIT,0.0),p)
	_dip_t = DIP_TIME
	_dip_amp = DIP*p*UNIT
	return true

## The charge (segmented: one segment) spent on something else (the gust shot,
## scripts/lock_on/gust_shot.gd): the wake comes away drifting `drift` m/s.
## Returns what was spent, 0 (nothing spent) under MIN_RELEASE.
func spend(m: PilotMotor, drift := Vector3.ZERO) -> float:
	if not can_spend() or m.recovering() or m.swimming or m.seized(): return 0.0
	var p := _take(SEG_SHOT_P)
	_let_go(drift)
	return p

## The forward burst: stick toward his travel (or any way when slow) plus the
## key adds flat pace along it, scaled by charge and eased off near BURST_CAP.
## No ring; wind streaks behind him and a FOV kick. Grounded he stays down (and
## keeps sliding); in the air it is a share, no lift. Returns false when it is
## not a forward burst (the caller then fires the updraft).
func burst(m: PilotMotor, want: Vector2) -> bool:
	var slide_boost := segmented and SLIDE_BOOST and m.grounded and m.move == "slide"
	if not BURST_ON or not can_spend(): return false
	if not slide_boost and want.length() < BURST_STICK: return false
	if m.recovering() or m.swimming or m.seized() or m.rider != null or m.hold != "": return false
	if not m.grounded and not BURST_AIR_ON: return false
	# On the ground only a slide takes the forward burst; running, it is the updraft.
	if m.grounded and m.move != "slide": return false
	var h := Vector2(m.velocity.x,m.velocity.z)
	var pace := h.length()
	var dir := want.normalized()
	if slide_boost:
		# The slide boost: always along the slide, the stick plays no part.
		dir = h/pace if pace > 0.05*UNIT else Vector2(-sin(m.facing),-cos(m.facing))
	elif pace > BURST_SLOW*UNIT:
		var vdir := h/pace
		if rad_to_deg(acos(clampf(vdir.dot(dir),-1.0,1.0))) > BURST_CONE: return false
		dir = (vdir+dir).normalized()
	if _cool > 0.0: return true   # a forward press inside the cooldown does nothing, not an updraft
	var p := _take(SEG_BURST_P)
	bursts += 1
	_cool = BURST_COOLDOWN
	spent = true
	_spent_t = 0.0
	_spent_pace = pace
	var soft := clampf((BURST_CAP-pace/UNIT)/(BURST_CAP-BURST_SOFT),BURST_FLOOR,1.0)
	var add := lerpf(BURST_ADD_MIN,BURST_ADD_MAX,p)*soft*UNIT
	if not m.grounded: add *= BURST_AIR_SHARE
	last_add = add
	m.velocity.x += dir.x*add
	m.velocity.z += dir.y*add
	if m.grounded: m.velocity.y += BURST_GROUND_HOP*UNIT
	else: m.velocity.y += BURST_AIR_LIFT*UNIT
	_ride = BURST_RIDE
	_let_go(-Vector3(dir.x,0.0,dir.y)*LOOSE_DRIFT*UNIT)
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
	var r := {"origin":origin,"p":p,"t":0.0,"R":lerpf(RING_R_MIN,RING_R_MAX,p)*UNIT,"hit":{},"ribs":[]}
	for i in range(RING_RIBBONS):
		var a := (float(i)+randf()*0.5)*TAU/float(RING_RIBBONS)
		r.ribs.append({"a":a,"k":randf_range(0.7,1.0),"curl":randf_range(0.5,0.9),"h":randf_range(0.1,0.6)*UNIT,
			"seed":randf()*100.0,"path":PackedVector3Array(),"times":PackedFloat32Array()})
	_rings.append(r)

func _step_rings(delta: float) -> void:
	for i in range(_rings.size()-1,-1,-1):
		var r: Dictionary = _rings[i]
		r.t += delta
		var k := clampf(r.t/RING_TIME,0.0,1.0)
		var radius: float = r.R*k
		# Each stroke's head runs out and curls round a little, easing off
		# as it goes, and rises a touch: a soft gust ring, not a hoop.
		var ease := 1.0-pow(1.0-clampf(r.t/(RING_TIME+FADE),0.0,1.0),2.0)
		for rib: Dictionary in r.ribs:
			var a: float = rib.a+rib.curl*ease
			var head: Vector3 = r.origin+Vector3(cos(a),0.0,sin(a))*r.R*ease*rib.k+Vector3.UP*(0.15*UNIT+rib.h*ease)
			rib.path.append(head)
			rib.times.append(r.t)
			while rib.times.size() > 2 and r.t-rib.times[0] > RING_TAIL:
				rib.path.remove_at(0)
				rib.times.remove_at(0)
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
			_rings.remove_at(i)

## His path for the wake: a sample every WAKE_SAMPLE s, WAKE_TAIL s of it.
func _track(delta: float, m: PilotMotor) -> void:
	_shown = move_toward(_shown,charge,delta/WAKE_FADE)
	for l: Dictionary in _loose:
		l.t += delta
		var drift: Vector3 = l.drift*delta
		var path: PackedVector3Array = l.path
		for j in range(path.size()): path[j] += drift
		l.path = path
	_loose = _loose.filter(func(l: Dictionary) -> bool: return l.t < LOOSE_LIFE)
	_trail_carry += delta
	if _trail_carry < WAKE_SAMPLE and not _trail.is_empty(): return
	_trail_carry = 0.0
	var h := Vector2(m.velocity.x,m.velocity.z)
	var side := Vector3.RIGHT
	if h.length() > 0.5: side = Vector3(-h.y,0.0,h.x).normalized()
	elif not _trail.is_empty(): side = _trail[-1].side
	_trail.append({"at":m.feet,"side":side,"t":_clock})
	while _trail.size() > 2 and _clock-float(_trail[0].t) > WAKE_TAIL: _trail.pop_front()

## One wake strand's path, oldest first: his path, each point off his line
## by the strand's offset, opening and rising toward the tail, with a slow
## sway so it breathes rather than flickers.
func _strand(i: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for s: Dictionary in _trail:
		var age := clampf((_clock-float(s.t))/WAKE_TAIL,0.0,1.0)
		var open := 1.0+WAKE_SPREAD*age
		var sway := 0.12*sin(float(s.t)*2.1+float(i)*2.0)*age
		var p: Vector3 = s.at+s.side*(float(WAKE_SIDE[i])*open+sway)*UNIT+Vector3.UP*(float(WAKE_HIGH[i])+WAKE_RISE*age)*UNIT
		if not out.is_empty() and p.distance_squared_to(out[-1]) < 0.0025: continue
		out.append(p)
	return out

## The wake comes away when the charge is spent: its strands linger a moment,
## drifting (`drift` m/s), and fade.
func _let_go(drift: Vector3) -> void:
	for i in range(WAKE_STRANDS):
		var a := _strand_alpha(i)
		if a <= 0.01: continue
		_loose.append({"path":_strand(i),"width":WAKE_WIDTH*1.3*UNIT,"alpha":a*1.6,"seed":float(i)*13.0,"t":0.0,"drift":drift})
	_shown = charge   # what is left (0 unless segmented)

## A strand's opacity at the charge shown: the first shows from a little
## charge, the rest join as it builds.
func _strand_alpha(i: int) -> float:
	var k := clampf((_shown-MIN_RELEASE*0.5)*float(WAKE_STRANDS)-float(i)*0.8,0.0,1.0)
	return WAKE_ALPHA*k*lerpf(0.6,1.0,_shown)

## Wake, loose strands and gust rings, all one mesh in the breeze's brush
## (the layout breeze_ribbons.gd `_draw` feeds the shader).
func _draw() -> void:
	if _mesh == null: return
	_mesh.clear_surfaces()
	var strokes: Array[Dictionary] = []
	for i in range(WAKE_STRANDS):
		var a := _strand_alpha(i)
		if a > 0.01: strokes.append({"path":_strand(i),"width":WAKE_WIDTH*lerpf(0.6,1.0,_shown)*UNIT,"alpha":a,"seed":float(i)*13.0})
	for l: Dictionary in _loose:
		var u: float = l.t/LOOSE_LIFE
		var flare := 1.0+0.6*clampf(1.0-l.t/FLARE_TIME,0.0,1.0)
		strokes.append({"path":l.path,"width":l.width*flare,"alpha":l.alpha*(1.0-u)*(1.0-u),"seed":l.seed})
	for r: Dictionary in _rings:
		var fade := 1.0 if r.t <= RING_TIME else clampf(1.0-(r.t-RING_TIME)/FADE,0.0,1.0)
		for rib: Dictionary in r.ribs:
			strokes.append({"path":rib.path,"width":lerpf(0.25,0.4,r.p)*UNIT,"alpha":lerpf(0.35,0.6,r.p)*fade,"seed":rib.seed})
	draw_strokes(_mesh,strokes,WAKE_MIN_RUN*UNIT)

## Strokes ({path, width, alpha, seed}) into `mesh` in the breeze ribbons'
## brush (the layout breeze_ribbons.gd `_draw` feeds the shader), each run
## at least `min_run` m. Shared with the slam's shockwave ring.
static func draw_strokes(mesh: ImmediateMesh, strokes: Array, min_run: float) -> void:
	var begun := false
	for st in strokes:
		var path: PackedVector3Array = st.path
		var n := path.size()
		if n < 3 or st.alpha <= 0.005: continue
		var along := PackedFloat32Array([0.0])
		for j in range(1,n): along.append(along[j-1]+path[j].distance_to(path[j-1]))
		var total := along[n-1]
		if total < min_run: continue
		if not begun:
			mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			begun = true
		var size := Vector2(st.width,st.alpha)
		var prev := Vector3.ZERO
		for j in range(n):
			var tangent := (path[mini(j+1,n-1)]-path[maxi(j-1,0)]).normalized()
			if j > 0:
				for corner in [[0,0.0],[1,0.0],[1,1.0],[0,0.0],[1,1.0],[0,1.0]]:
					var k: int = corner[0]
					mesh.surface_set_normal(prev if k == 0 else tangent)
					mesh.surface_set_uv(Vector2(total-along[j-1+k],corner[1]))
					mesh.surface_set_uv2(size)
					mesh.surface_set_color(Color(0.0,0.0,float(st.seed)*0.01,along[j-1+k]/total))
					mesh.surface_add_vertex(path[j-1+k])
			prev = tangent
	if begun: mesh.surface_end()
