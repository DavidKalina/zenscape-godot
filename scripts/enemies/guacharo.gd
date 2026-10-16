extends Node3D
## The guacharo (feature `flyer`):
## a giant oilbird that hunts the wanderer where he is exposed. Its body is
## scripts/enemies/guacharo_look.gd; this is its mind, its flight and its
## voice. Laid and stepped by scripts/roguelike/layer_flyers.gd.
##
## What it does, as states:
##   home    circles high over its home (the layer's widest gulf) while he
##           is out of its range or the layer's grace runs
##   circle  circles high over him (CIRCLE_R, CIRCLE_UP of his heights),
##           gliding, a few heavy beats now and then, its shadow sliding
##           over the ground; it reads how exposed he is (`_sense`): in the
##           air over the void, hanging on a ledge or a wall, on a rope, or
##           stood by a rim with the void round him; never under cover (stone
##           over his head) or when he is down. Exposure fills its hunger;
##           full, it marks him (a call, beat "marked") and swings in fast on
##           a tighter, lower ring; COVER_BREAK s under stone unmarks him.
##   stalk   marked and within two circles of him: it
##           drops to a stalk point in the camera's view, STALK_SIDE rad off
##           its forward, STALK_OUT out and STALK_UP over him (so the dive
##           comes across the screen and knocks him sideways off a narrow
##           way), its line to him clear; boxed in under stone with a gap
##           over him (a fallen roof bay), up through the gap instead
##           (STALK_PITCHES), so a gap is a quick dash under open sky; and
##           hangs there circling tight,
##           clicking (oilbirds find their way by clicks), the clicks faster
##           as it makes up its mind; its shadow tightens on him. Gets up
##           again if he stays safe ABORT s or covered COVER_BREAK s.
##   fold    the tell: a scream, the beak wide, wings thrown up (the
##           anticipation), then folded into a teardrop, braking to a hang;
##           FOLD s. The aim is locked with the scream on where he will be
##           if he keeps on (LEAD of his pace): kept on, he is hit; stopped,
##           turned or started, he is missed. Under stone in the fold, it
##           balks (beat "balked") and gets up again.
##   stoop   the dive: accelerating to STOOP_TOP, turning towards him at
##           only HOME_TURN rad/s (so a sidestep or a turn back on the
##           scream dodges it), talons thrown forward and wings flared at
##           the last instant. Past him or blocked, it pulls out.
##   strike  touching his middle (HIT of his height): in the air he is
##           buffeted (a knock, BUFFET_OUT out, BUFFET_UP up: the fall is
##           the danger); stood or hanging, he is snatched (PilotMotor
##           `seize`): carried out over the nearest void and dropped, unless
##           he struggles free (STRUGGLE presses of jump or twirl). Both
##           harm a heart through the motor's `harm`. The carry's first LIFT
##           s it beats hard to get him up (he drops back where he was if he
##           struggles free now); then out over the void if his exposure put
##           a void within VOID_CARRY of him (rim, hold, wall, rope, leap)
##           (snatched up through a gap, straight up till clear of stone),
##           else along over the ground and dropped there (`drop_over_void`).
##   pull    heavy beats back up; then a cool-down (COOL s) before it can
##           mark him again.
## Every size is in his heights (`unit`, the study's ground `head_top`).
const Look = preload("res://scripts/enemies/guacharo_look.gd")
const PilotMotor = preload("res://scripts/pilot_motor.gd")

signal beat(what: String)

const CAUSE := "the guácharo"

## The state timings (s): the contract guacharo_look.gd's clips match.
## STALK_MIN..STALK_MAX: the stalk's hover with clicks, the clicks from
## CLICK_SLOW to CLICK_FAST apart as it commits. TELL: the fold (the
## scream with the beak wide and wings thrown up for TELL*TELL_SCREAM, then
## folded into the teardrop for the rest). STOOP_MAX: the longest dive;
## FLARE: the flare, talons forward, starts this long before contact. LIFT
## then CARRY: the snatch's hard beats, then out over the void, let go at
## CARRY. PULL: the heavy beats back up. COOL_MIN..COOL_MAX: the back-off
## after a strike or a miss before it can mark him again.
const STALK_MIN := 1.6
const STALK_MAX := 5.5
const CLICK_SLOW := 0.42
const CLICK_FAST := 0.07
const TELL := 0.95
const TELL_SCREAM := 0.45
const STOOP_MAX := 2.5
const FLARE := 0.22
const LIFT := 0.7
const CARRY := 1.5
const PULL := 1.1
const COOL_MIN := 7.0
const COOL_MAX := 12.0
## A gap in his cover: when no stalk point out toward the camera has a
## clear line to him, it tries these slopes (deg off the level) up through
## the gap, hanging on a ring GAP_RING of the usual over it.
const STALK_PITCHES: Array[float] = [50.0,62.0,72.0,80.0,86.0]
const GAP_RING := 0.25
## It stalks where he can see it: with a camera, the stalk point must sit
## inside STALK_FRAME of the half-frame; failing the usual point, nearer
## (STALK_NEAR of STALK_OUT) and lower (STALK_LOW of STALK_UP).
const STALK_FRAME := 0.62
const STALK_NEAR: Array[float] = [1.0,0.8,0.65,0.5]
const STALK_LOW: Array[float] = [1.0,0.6,0.3,0.0]
const STALK_SEEN := 0.8
## The least gap (his heights) its body keeps off stone and turf; in the
## dive less, so it still reaches his middle.
const CLEAR := 0.6
const CLEAR_STOOP := 0.15

## Its knobs (sizes in his heights, speeds m/s, times s); `--flyer-<knob>=`
## overrides one (layer_flyers.gd).
const KNOBS := {
	"span":3.0, "circle_r":17.0, "circle_up":10.0, "circle_speed":10.5,
	"stalk_out":9.5, "stalk_side":0.45, "stalk_up":1.4, "stalk_r":2.6, "stalk_speed":8.0,
	"stalk_at":0.9, "stalk_min":STALK_MIN, "stalk_max":STALK_MAX, "abort":1.6,
	"fold":TELL, "lead":0.9, "home_turn":0.12, "stoop_accel":58.0, "stoop_top":30.0,
	"hit":0.8, "buffet_out":4.5, "buffet_up":0.9, "buffet_down":0.0,
	"snatch":1.0, "lift":LIFT, "carry":CARRY, "carry_speed":5.5, "carry_rise":1.8, "struggle":4,
	"cool_min":COOL_MIN, "cool_max":COOL_MAX, "cover_up":30.0, "void_down":14.0, "rim_r":1.4,
	"mark_swing":2.2, "cover_break":0.3, "void_carry":4.0,
}

var knobs: Dictionary = KNOBS.duplicate()
var look: Node3D
var flyers
var motor: PilotMotor
var field
## His height (m) and the bird's span (m).
var unit := 1.12
var span := 3.4
var home := Vector3.ZERO
var turn := 1.0

var state := "home"
var state_t := 0.0
var vel := Vector3(8.0,0.0,0.0)
var bank := 0.0
var hunger := 0.0
## His exposure (0..1) as last read, and what kind ("leap", "air", "hold",
## "wall", "rope", "rim", "open", "cover", "down").
var exposure := 0.0
var exposure_kind := ""
var cool := 0.0
var aim := Vector3.ZERO
var stoop_dir := Vector3.DOWN
var strikes := 0
var snatches := 0
var misses := 0
var dives := 0
var last_strike := ""
## Marked: it has noticed him exposed (a call, then it swings in on him).
var marked := false
## The last snatch's drop: over a void (his exposure took him there) or
## back on the ground.
var drop_over_void := false

var _pose: Dictionary = Look.REST.duplicate()
var _flap := 0.0
var _flap_w := 0.0
var _bout := 0.0
var _sense_t := 0.0
var _ground_t := 0.0
var _ground_y := -INF
var _block_t := 0.0
var _blocked_ahead := false
var _theta := 0.0
var _centre := Vector3.INF
var _stalk_at := Vector3.ZERO
var _stalk_ang := 0.0
var _stalk_up := 1.0
## The stalk point's lift off the level (rad): 0 for the usual point out
## toward the camera; steep for a point up through a gap in his cover.
var _stalk_pitch := 0.0
var _stalk_near := 1.0
var _seen_t := 0.0
var _stalk_check := 0.0
var _safe_t := 0.0
var _cover_t := 0.0
var _click_t := 0.0
## How far the stalk has made up its mind (0..1): the clicks' pace, pitch
## and loudness; it only rises within a stalk.
var _click_ready := 0.0
var _flap_c := 0.0
var _prev := Vector3.ZERO
var _clear_ray := PhysicsRayQueryParameters3D.new()
var _grazed := false
var _vel_prev := Vector3.ZERO
var _carry_dir := Vector3.ZERO
var _struggles := 0
var _cam_fwd := Vector3.FORWARD
var _shadow: Decal
var _voices := {}
var _feathers: CPUParticles3D
var _rng := RandomNumberGenerator.new()
## The voices' own dice (pitch wobble), so sound never shifts the hunt.
var _voice_rng := RandomNumberGenerator.new()

# --- Standing it ---------------------------------------------------------------------

func setup(owner_flyers: Variant, at_home: Vector3, seed_value: int, over := {}) -> void:
	flyers = owner_flyers
	motor = flyers.motor
	field = flyers.field
	unit = float(flyers.unit)
	knobs.merge(over,true)
	_rng.seed = seed_value
	turn = 1.0 if _rng.randf() < 0.5 else -1.0
	home = at_home
	span = float(knobs.span)*unit
	name = "Guacharo"
	look = Look.new()
	look.size_to(span)
	add_child(look)
	position = home+Vector3(float(knobs.circle_r)*unit,0.0,0.0)
	_prev = position
	_theta = _rng.randf()*TAU
	_shadow_make()
	_tell_make()
	_voices_make()
	_feathers_make()

func reset() -> void:
	state = "home"
	state_t = 0.0
	hunger = 0.0
	cool = 0.0
	marked = false
	position = home+Vector3(float(knobs.circle_r)*unit,0.0,0.0)
	_prev = position
	vel = Vector3(8.0,0.0,0.0)
	if motor.seized() and flyers.carrier == self: motor.knock(Vector3.ZERO,self)

func _go(s: String) -> void:
	if s == state: return
	state = s
	state_t = 0.0
	_seen_t = 0.0
	beat.emit(s)

# --- Each step -----------------------------------------------------------------------

## Ahead of the motor's step: it reads him, decides and flies.
func step(delta: float, cam_fwd: Vector3) -> void:
	_cam_fwd = cam_fwd
	state_t += delta
	cool = maxf(cool-delta,0.0)
	_prev = position
	_sense_t -= delta
	if _sense_t <= 0.0:
		_sense_t = 0.1
		_sense()
	_ground_t -= delta
	if _ground_t <= 0.0:
		_ground_t = 0.25
		_ground_y = field.floor_under(position,0.0,60.0)
	_block_t -= delta
	if _block_t <= 0.0:
		_block_t = 0.15
		_blocked_ahead = vel.length() > 1.0 and field.blocked(position,vel*0.9)
	var hunting: bool = flyers.hunting()
	match state:
		"home": _home(delta,hunting)
		"circle": _circle(delta,hunting)
		"stalk": _stalk(delta,hunting)
		"fold": _fold(delta)
		"stoop": _stoop(delta)
		"carry": _carry(delta)
		"pull": _pull(delta)
	position += vel*delta
	_keep_clear()
	_orient(delta)
	_animate(delta)
	_shadow_place(delta)
	_tell_place(delta)

## After the motor's step: the dive's contact with him.
func after_step(_delta: float) -> void:
	if state != "stoop": return
	var mid := _middle()
	var near := Geometry3D.get_closest_point_to_segment(mid,_prev,position)
	if near.distance_to(mid) <= float(knobs.hit)*unit and not motor.seized() and not motor.recovering():
		_strike()

func _middle() -> Vector3:
	return motor.feet+Vector3.UP*unit*0.55

# --- Reading him ---------------------------------------------------------------------

## How exposed he is now (`exposure`, `exposure_kind`), and hunger from it.
func _sense() -> void:
	var m := motor
	var mid := _middle()
	var e := 0.0
	var kind := "open"
	if m.seized() or m.recovering():
		kind = "down"
	elif field.blocked(mid,Vector3.UP*float(knobs.cover_up)*unit):
		kind = "cover"
	elif m.on_ledge():
		e = 1.0
		kind = "hold"
	elif m.move == "wall" or m.move == "wallrun":
		e = 0.9
		kind = "wall"
	elif m.rider != null:
		e = 0.9
		kind = "rope"
	elif not m.grounded:
		var under: float = field.floor_under(m.feet,0.2,float(knobs.void_down)*unit)
		if under == -INF:
			e = 1.0
			kind = "leap"
		else:
			e = 0.4
			kind = "air"
	else:
		# Two rings round him: the void close counts full, further out
		# (an island of a ledge, a stepping stone) a little less.
		var miss := 0.0
		for ring: Array in [[float(knobs.rim_r),1.0],[float(knobs.rim_r)*2.3,0.6]]:
			for i in range(8):
				var a := TAU*(float(i)+0.5*float(ring[1] < 1.0))/8.0
				var p := m.feet+Vector3(cos(a),0.0,sin(a))*float(ring[0])*unit
				if field.floor_under(p,unit,4.0*unit) == -INF: miss += float(ring[1])
		if miss > 0.0:
			e = minf(0.45+0.55*miss/8.0,1.0)
			kind = "rim"
		else:
			e = 0.12
		# Stood still out there it is worse.
		if Vector2(m.velocity.x,m.velocity.z).length() < 0.6: e = minf(e*1.35,1.0)
	exposure = e
	exposure_kind = kind
	if e >= 0.4: hunger = minf(hunger+e*0.1,3.0)
	else: hunger = maxf(hunger-0.1*0.6,0.0)
	if e < 0.3: _safe_t += 0.1
	else: _safe_t = 0.0
	if kind == "cover": _cover_t += 0.1
	else: _cover_t = 0.0

# --- The states ----------------------------------------------------------------------

func _home(delta: float, hunting: bool) -> void:
	_glide_round(home,float(knobs.circle_r)*unit*1.4,0.0,float(knobs.circle_speed)*0.85,delta)
	if hunting: _go("circle")

func _circle(delta: float, hunting: bool) -> void:
	if not hunting:
		_go("home")
		return
	var feet := motor.feet
	_centre = feet if _centre == Vector3.INF else _centre.lerp(feet,1.0-exp(-1.2*delta))
	var ready_to: bool = cool <= 0.0 and hunger >= float(knobs.stalk_at) and exposure >= 0.4 and flyers.may_stalk(self)
	# Marking him: it has noticed him exposed; a call, and it swings in.
	if ready_to and not marked: _mark(true)
	# Cover (or safety long enough) unmarks him.
	if marked and (_cover_t >= float(knobs.cover_break) or _safe_t >= float(knobs.abort) or cool > 0.0): _mark(false)
	# Far off, it comes on fast (twice its circling pace); marked, faster
	# still and on a tighter, lower ring, straight for him.
	var far := clampf(position.distance_to(feet)/(float(knobs.circle_r)*unit*3.0)-1.0,0.0,1.0)
	var pace := float(knobs.circle_speed)*(1.0+far)
	var ring := float(knobs.circle_r)*unit
	var up := float(knobs.circle_up)*unit
	if marked:
		pace *= float(knobs.mark_swing)
		ring *= 0.6
		up *= 0.7
		_centre = feet
	_glide_round(_centre,ring,up,pace,delta)
	var close := position.distance_to(feet) < float(knobs.circle_r)*unit*2.0
	# It drops to the stalk from the far half of its ring (out past him,
	# away from the camera), so it comes down in view, not over the
	# camera from behind.
	var flat_fwd := Vector3(_cam_fwd.x,0.0,_cam_fwd.z).normalized()
	if (position-feet).dot(flat_fwd) < 0.0: close = false
	if close and ready_to:
		if _pick_stalk():
			_go("stalk")
			flyers.stalker = self
			# The first click waits out the marking call (it may mark and
			# stalk in one step).
			_click_t = 0.45
			_click_ready = 0.0
			return
	# Marked and swinging in: a few slow, quiet clicks (it has you).
	if marked:
		_click_t -= delta
		if _click_t <= 0.0:
			_click_t = CLICK_MARKED
			_say(&"click",-7.0,0.9)

## Circles `centre` at `radius`, `up` over it, at `speed`: pursuing a point
## LEAD rad ahead of where it is on the circle; kept over the ground under
## it and off what's ahead.
func _glide_round(centre: Vector3, radius: float, up: float, speed: float, delta: float) -> void:
	var off := Vector2(position.x-centre.x,position.z-centre.z)
	var ang := atan2(off.y,off.x)+0.55*turn
	var target := centre+Vector3(cos(ang)*radius,up,sin(ang)*radius)
	target.y += sin(state_t*0.4)*unit*1.5
	if _ground_y != -INF: target.y = maxf(target.y,_ground_y+5.0*unit)
	if _blocked_ahead: target.y += 12.0*unit
	_steer(target,speed,9.0,delta,false)
	var climbing := vel.y > 1.2 or _blocked_ahead
	_bout -= delta
	if _bout <= 0.0 and _rng.randf() < delta*0.12: _bout = _rng.randf_range(1.0,2.2)
	_flap_w = move_toward(_flap_w,1.0 if (climbing or _bout > 0.0) else 0.0,delta*2.5)

func _steer(target: Vector3, speed: float, accel: float, delta: float, arrive: bool) -> void:
	var to := target-position
	var d := to.length()
	var want := to/d*speed if d > 0.01 else Vector3.ZERO
	if arrive and d < speed: want *= d/speed
	vel = vel.move_toward(want,accel*delta)

## A stalk point: in front of the camera's view of him (so the dive comes
## at the player), out and over him, the line to his middle clear. Boxed in
## under stone with a gap over him (a fallen roof bay), steeper and steeper
## up through the gap (STALK_PITCHES), so the dive comes down through it.
func _pick_stalk() -> bool:
	var mid := _middle()
	var fwd := Vector3(_cam_fwd.x,0.0,_cam_fwd.z)
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := float(knobs.stalk_side)
	# In view first; failing that wider round him, then higher.
	var sides: Array[float] = [side,-side,side*0.4,-side*0.4,side*1.8,-side*1.8,side*3.0,-side*3.0,0.0]
	# Where the player can see it: well inside the camera's frame
	# (STALK_FRAME of the half-frame), nearer and lower if need be.
	if _view() != null:
		for out: float in STALK_NEAR:
			for up: float in STALK_LOW:
				for a: float in sides:
					if _try_stalk(mid,fwd,a*turn,0.0,up,out,true): return true
	for up: float in [1.0,2.2]:
		for a: float in sides:
			if _try_stalk(mid,fwd,a*turn,0.0,up): return true
	for pitch: float in STALK_PITCHES:
		for a: float in sides:
			if _try_stalk(mid,fwd,a*turn,deg_to_rad(pitch),1.0): return true
	return false

## The stalk point for a heading `ang` off the camera's forward, `pitch`
## off the level (0: STALK_OUT out, STALK_UP*`up` over him; else STALK_OUT
## away on that slope).
func _stalk_point(mid: Vector3, fwd: Vector3, ang: float, pitch: float, up: float, near := 1.0) -> Vector3:
	var way := fwd.rotated(Vector3.UP,ang)
	var out := float(knobs.stalk_out)*unit*near
	if pitch <= 0.0: return mid+way*out+Vector3.UP*float(knobs.stalk_up)*up*unit
	return mid+(way*cos(pitch)+Vector3.UP*sin(pitch))*out

func _try_stalk(mid: Vector3, fwd: Vector3, ang: float, pitch: float, up: float, near := 1.0, framed := false) -> bool:
	var p := _stalk_point(mid,fwd,ang,pitch,up,near)
	if framed and not _in_view(p,STALK_FRAME): return false
	if field.blocked(mid+Vector3.UP*0.3,p-mid-Vector3.UP*0.3): return false
	# Room under it to hang (not in the grass).
	if field.floor_under(p,0.5,1.4*unit) != -INF: return false
	_stalk_ang = ang
	_stalk_up = up
	_stalk_pitch = pitch
	_stalk_near = near
	_stalk_at = p
	return true

## Its body never goes into stone: after each move, a sweep from where it
## was (its way into a cliff or a keel) and a probe down from the higher
## of then and now (into turf below) hold it CLEAR of his heights off
## whatever it met (CLEAR_STOOP in the dive, so it still reaches his
## middle), and take out the speed into it. `_grazed` says it touched.
func _keep_clear() -> void:
	_grazed = false
	var need := (CLEAR_STOOP if state == "stoop" else CLEAR)*unit
	var mask := WalkerOnly.strip(field.study.ground.mask)
	var space := get_world_3d().direct_space_state
	var moved := position-_prev
	if moved.length() > 0.001:
		var dir := moved.normalized()
		_clear_ray.from = _prev
		_clear_ray.to = position+dir*need
		_clear_ray.collision_mask = mask
		var hit := space.intersect_ray(_clear_ray)
		if not hit.is_empty():
			var n: Vector3 = hit.normal
			position = (hit.position as Vector3)+n*need
			vel -= n*minf(vel.dot(n),0.0)
			_grazed = true
	_clear_ray.from = Vector3(position.x,maxf(_prev.y,position.y)+0.05,position.z)
	_clear_ray.to = position-Vector3.UP*need
	_clear_ray.collision_mask = mask
	var under := space.intersect_ray(_clear_ray)
	if not under.is_empty():
		var floor_y := (under.position as Vector3).y
		if position.y < floor_y+need:
			position.y = floor_y+need
			vel.y = maxf(vel.y,0.0)
			_grazed = true

## The camera the player sees through (null without one).
func _view() -> Camera3D:
	var vp := get_viewport()
	return vp.get_camera_3d() if vp != null else null

## Whether `p` lies inside `frame` of the camera's half-frame (1.0: the
## frame's edge). True without a camera.
func _in_view(p: Vector3, frame: float) -> bool:
	var cam := _view()
	if cam == null: return true
	var q := cam.global_transform.affine_inverse()*p
	if q.z > -0.5: return false
	var size := get_viewport().get_visible_rect().size
	var ty := tan(deg_to_rad(cam.fov)*0.5)
	var tx := ty*(size.x/maxf(size.y,1.0))
	return absf(q.x/-q.z) <= tx*frame and absf(q.y/-q.z) <= ty*frame

func _stalk(delta: float, hunting: bool) -> void:
	_stalk_check -= delta
	if _stalk_check <= 0.0:
		_stalk_check = 0.5
		if not _pick_stalk():
			_give_up()
			return
	var mid := _middle()
	var fwd := Vector3(_cam_fwd.x,0.0,_cam_fwd.z).normalized()
	_stalk_at = _stalk_at.lerp(_stalk_point(mid,fwd,_stalk_ang,_stalk_pitch,_stalk_up,_stalk_near),1.0-exp(-2.0*delta))
	# Over a gap it hangs on a tight ring, so it stays over the gap.
	var r := float(knobs.stalk_r)*unit*(GAP_RING if _stalk_pitch > 0.0 else 1.0)
	var ang := state_t*float(knobs.stalk_speed)/maxf(r,0.5)*0.5*turn
	var target := _stalk_at+Vector3(cos(ang)*r,sin(state_t*1.7)*0.3*unit,sin(ang)*r)
	_steer(target,float(knobs.stalk_speed)+position.distance_to(target)*0.6,16.0,delta,false)
	_flap_w = move_toward(_flap_w,0.6,delta*2.0)
	# The clicks: slow, then fast, higher and louder as it makes up its
	# mind; paced on when it will fold (STALK_MIN with him wide open, else
	# STALK_MAX), so the clicks run to a buzz just before the scream.
	var due := float(knobs.stalk_min) if exposure >= 0.85 else float(knobs.stalk_max)
	_click_ready = maxf(_click_ready,clampf(state_t/maxf(due,0.1),0.0,1.0))
	var ready := _click_ready*_click_ready
	_click_t -= delta
	if _click_t <= 0.0:
		_click_t = lerpf(CLICK_SLOW,CLICK_FAST,ready)
		_say(&"click",lerpf(-4.0,2.0,ready),lerpf(1.0,1.4,ready)*_voice_rng.randf_range(0.97,1.03))
	if not hunting or _safe_t >= float(knobs.abort) or _cover_t >= float(knobs.cover_break):
		_give_up()
		return
	var near := position.distance_to(_stalk_at) < r*2.0 and vel.length() < float(knobs.stalk_speed)*1.6
	# Only with its own line to him clear (over a gap, not over the roof).
	if near and _stalk_pitch > 0.0: near = not field.blocked(position,(mid-position)*0.9)
	# In the open it screams only once he has seen it hang there in view
	# STALK_SEEN s (or at its longest).
	if _in_view(position,0.92): _seen_t += delta
	if near and _stalk_pitch <= 0.0 and state_t < float(knobs.stalk_max): near = _seen_t >= STALK_SEEN and _in_view(position,0.92)
	if near and state_t >= float(knobs.stalk_min) and (exposure >= 0.85 or (state_t >= float(knobs.stalk_max) and exposure >= 0.4)):
		# The aim is locked with the scream: where he will be if he keeps
		# on as he is (LEAD of his pace over the fold and the dive). Kept
		# on, he is hit; turned, stopped or started, he is missed.
		var flat := Vector3(motor.velocity.x,0.0,motor.velocity.z)
		var dive := mid.distance_to(position)/(float(knobs.stoop_top)*0.55)
		aim = mid+flat*(float(knobs.fold)+dive)*float(knobs.lead)
		_go("fold")
		_say(&"scream")
		_tell_pop = 1.0

## Marks or unmarks him: the noticing (a call), or letting him go.
func _mark(on: bool) -> void:
	if on == marked: return
	marked = on
	if on:
		beat.emit("marked")
		_say(&"mark")
	else:
		beat.emit("unmarked")
		hunger = 0.0

func _give_up() -> void:
	if flyers.stalker == self: flyers.stalker = null
	marked = false
	hunger = 0.0
	cool = float(knobs.cool_min)*0.5
	_go("circle")

## The tell: thrown up, then folded; the aim locked at the end.
func _fold(delta: float) -> void:
	var f := float(knobs.fold)
	# Ducked under stone on the scream: it balks (no dive at stone).
	if exposure_kind == "cover":
		beat.emit("balked")
		_give_up()
		return
	# Rearing back: it rises a little and nearly stops.
	vel = vel.move_toward(Vector3.UP*1.2*unit,45.0*delta)
	_flap_w = move_toward(_flap_w,0.0,delta*6.0)
	if state_t >= f:
		stoop_dir = (aim-position).normalized()
		vel = stoop_dir*maxf(vel.length(),8.0)
		dives += 1
		_go("stoop")
		_say(&"rush")

func _stoop(delta: float) -> void:
	var speed := minf(vel.length()+float(knobs.stoop_accel)*delta,float(knobs.stoop_top))
	var to := (_middle()-position).normalized()
	var ang := stoop_dir.angle_to(to)
	if ang > 0.001 and stoop_dir.dot(to) > 0.0:
		stoop_dir = stoop_dir.slerp(to,minf(1.0,float(knobs.home_turn)*delta/ang)).normalized()
	vel = stoop_dir*speed
	var passed := (aim-position).dot(stoop_dir) < -2.0*unit and (_middle()-position).dot(stoop_dir) < -1.0*unit
	# Stone in the way short of him (not the ground beyond him) breaks it off.
	var short := minf(speed*0.2,position.distance_to(_middle())-1.5*unit)
	var blocked: bool = short > 0.3 and field.blocked(position,stoop_dir*short)
	var ground_close := _ground_y != -INF and position.y-_ground_y < 0.6*unit and vel.y < 0.0 and passed
	# Stopped dead against stone or turf short of him: it pulls out.
	if _grazed and vel.length() < 3.0 and position.distance_to(_middle()) > float(knobs.hit)*unit*1.5: ground_close = true
	if passed or blocked or ground_close or state_t > STOOP_MAX:
		misses += 1
		last_strike = "miss"
		_end_dive()
		beat.emit("miss")

func _end_dive() -> void:
	if flyers.stalker == self: flyers.stalker = null
	marked = false
	hunger = 0.0
	cool = _rng.randf_range(float(knobs.cool_min),float(knobs.cool_max))
	_go("pull")

func _pull(delta: float) -> void:
	var up := Vector3(vel.x,0.0,vel.z)
	up = up.normalized() if up.length() > 0.5 else Vector3(_cam_fwd.x,0.0,_cam_fwd.z).normalized()
	_steer(position+up*20.0+Vector3.UP*14.0,13.0,34.0,delta,false)
	_flap_w = 1.0
	if state_t >= PULL: _go("circle")

## Touched him: snatched stood or hanging, buffeted in the air.
func _strike() -> void:
	var m := motor
	var way := Vector2(vel.x,vel.z)
	if way.length() < 0.5: way = Vector2(m.feet.x-position.x,m.feet.z-position.z)
	way = way.normalized() if way.length() > 0.01 else Vector2(0.0,-1.0)
	strikes += 1
	var stood := m.grounded or m.on_ledge() or m.move == "wall" or m.move == "wallrun" or m.rider != null
	_say(&"hit")
	_feathers.global_position = _middle()
	_feathers.restart()
	if stood and float(knobs.snatch) > 0.0 and flyers.carrier == null:
		snatches += 1
		last_strike = "snatch"
		m.seize()
		m.harm(CAUSE,1,self)
		flyers.carrier = self
		# Over the void only if his exposure put the void by him (a rim, a
		# hold, a wall, a rope, a leap); else lifted and dropped back on the
		# ground, the fall short.
		var fallback := Vector3(way.x,0.0,way.y)
		drop_over_void = false
		_carry_dir = fallback.normalized() if fallback.length() > 0.01 else Vector3.FORWARD
		if exposure_kind in ["rim","hold","wall","rope","leap"]:
			var v := _void_way(m.feet,fallback,float(knobs.void_carry))
			if v != Vector3.ZERO:
				_carry_dir = v
				drop_over_void = true
		_struggles = 0
		vel = vel*0.15
		_go("carry")
	else:
		last_strike = "buffet"
		m.knock(m.knock_velocity(way,float(knobs.buffet_out)*unit,float(knobs.buffet_up)*unit),self,float(knobs.buffet_down))
		m.harm(CAUSE,1,self)
		_end_dive()
	beat.emit(last_strike)

## The way from `at` to the nearest void (a ring of rays out to `reach` of
## his heights, at most 8), or ZERO if none that near.
func _void_way(at: Vector3, fallback: Vector3, reach := 8.0) -> Vector3:
	for r: float in [2.0,4.0,6.0,8.0]:
		if r > reach: break
		var best := Vector3.ZERO
		var best_dot := -INF
		for i in range(12):
			var a := TAU*float(i)/12.0
			var w := Vector3(cos(a),0.0,sin(a))
			if field.floor_under(at+w*r*unit,unit,6.0*unit) != -INF: continue
			var d := w.dot(fallback)
			if d > best_dot:
				best_dot = d
				best = w
		if best != Vector3.ZERO: return best
	return Vector3.ZERO

## Carrying him: out over the void, rising, then let go; he can struggle free.
func _carry(delta: float) -> void:
	var m := motor
	# First the lift (LIFT s): beating hard to get him up, hardly moving
	# out (his weight); struggled free now, he drops back where he was.
	# Then out over the void.
	var lifting := state_t < float(knobs.lift)
	var want := Vector3.UP*float(knobs.carry_rise)*0.8+_carry_dir*1.0 if lifting else _carry_dir*float(knobs.carry_speed)+Vector3.UP*float(knobs.carry_rise)
	vel = vel.move_toward(want,(30.0 if lifting else 10.0)*delta)
	if _blocked_ahead: vel.y = maxf(vel.y,4.0)
	# Snatched up through a gap in stone: straight up till clear of it.
	var flat := Vector3(vel.x,0.0,vel.z)
	if flat.length() > 0.1 and field.blocked(position+flat.normalized()*unit*0.8,Vector3.UP*3.0*unit):
		vel.x = 0.0
		vel.z = 0.0
		vel.y = maxf(vel.y,4.0)
	# Dropping him on the ground: it never takes him out past the floor.
	if not drop_over_void and not lifting:
		var ahead := m.feet+Vector3(vel.x,0.0,vel.z).normalized()*unit*1.5
		if Vector2(vel.x,vel.z).length() > 0.1 and field.floor_under(ahead,2.0*unit,6.0*unit) == -INF:
			vel.x = 0.0
			vel.z = 0.0
	_flap_w = 1.0
	if state_t > 0.1 and (Input.is_action_just_pressed(&"walk_jump") or Input.is_action_just_pressed(&"walk_twirl")):
		_struggles += 1
		vel += Vector3(_rng.randf_range(-1.0,1.0),-0.6,_rng.randf_range(-1.0,1.0))*1.5
	var held := position+vel*delta-Vector3.UP*(unit*0.95+span*0.06)
	# Snatched off the ground, he stays on it until the bird's climb takes
	# him up (the bird is held off the stone lower than his height).
	var under := maxf(field.floor_under(m.feet,unit*0.5,unit*1.5),field.floor_under(held,unit*1.5,unit*0.5))
	if under != -INF and held.y < under: held.y = under
	if m.seized():
		m.feet = held
		m.velocity = vel
	if _struggles >= int(knobs.struggle) or state_t >= float(knobs.carry) or not m.seized():
		var freed := _struggles >= int(knobs.struggle)
		if m.seized(): m.knock(vel*0.5+Vector3.DOWN*0.5,self)
		flyers.carrier = null
		last_strike = "freed" if freed else "dropped"
		beat.emit(last_strike)
		_say(&"cry")
		_end_dive()

# --- Flight and the body --------------------------------------------------------------

func _orient(delta: float) -> void:
	var fwd := vel
	if state == "fold" or state == "carry" or fwd.length() < 1.0:
		fwd = -global_basis.z
		if state == "fold" or state == "carry":
			var to := (_middle()-position) if state == "fold" else _carry_dir
			to.y = 0.0
			if to.length() > 0.1: fwd = fwd.slerp(to.normalized(),1.0-exp(-6.0*delta))
	fwd = fwd.normalized()
	var acc := (vel-_vel_prev)/maxf(delta,0.001)
	_vel_prev = vel
	var right := fwd.cross(Vector3.UP)
	var lat := acc.dot(right.normalized()) if right.length() > 0.01 else 0.0
	var want_bank := clampf(-lat/9.8*0.9,-1.15,1.15) if state in ["home","circle","stalk","pull"] else 0.0
	bank = lerpf(bank,want_bank,1.0-exp(-3.0*delta))
	var up := Vector3.UP if absf(fwd.y) < 0.97 else global_basis.y
	var b := Basis.looking_at(fwd,up)
	b = Basis(fwd,bank)*b
	global_basis = b.orthonormalized()

## Poses the body for its state, eased; the beats' phase run.
func _animate(delta: float) -> void:
	var freq := 1.7 if state in ["home","circle"] else (2.4 if state in ["pull","carry"] else 2.0)
	_flap += delta*freq*TAU
	var s := sin(_flap)
	var c := cos(_flap)
	# A wingbeat's whump on each downstroke (the top of the beat), as loud
	# as the beat is full; heavier with him in its talons.
	if _flap_c >= 0.0 and c < 0.0 and _flap_w > 0.35 and state not in ["fold","stoop"]:
		var heavy := state in ["carry","pull"]
		_say(&"wing",linear_to_db(_flap_w)+(2.0 if heavy else 0.0),(0.8 if heavy else 1.0)*_voice_rng.randf_range(0.92,1.08))
	_flap_c = c
	var glide := {"elev":0.14+sin(state_t*0.9)*0.04,"sweep":0.06,"wrist":0.14,"droop":-0.12,"spread":1.0,"tail":0.75}
	var beat_pose := {"elev":0.15+0.85*s,"sweep":0.1-0.15*s,"wrist":0.15+0.6*maxf(c,0.0),"droop":-0.25*s,
		"spread":0.8+0.2*s,"tail":0.65,"pitch":0.05*c}
	var want: Dictionary = Look.mix_pose(glide,beat_pose,_flap_w)
	var k := 5.0
	match state:
		"stalk":
			want.head = 0.55
			want.pitch = 0.12
			want.tail = 1.0
		"fold":
			var f := state_t/float(knobs.fold)
			if f < TELL_SCREAM:
				# Thrown up: the anticipation, the beak wide, the scream.
				want = {"elev":1.15,"sweep":-0.15,"wrist":0.05,"droop":0.25,"spread":1.0,"tail":1.0,"pitch":0.45,"head":-0.2,"jaw":1.0,"stretch":0.86}
				k = 16.0
			else:
				# Folded: the teardrop, the hold before the drop.
				want = {"elev":0.32,"sweep":1.2,"wrist":2.5,"droop":0.1,"spread":0.0,"tail":0.0,"pitch":-0.35,"head":0.35,"jaw":0.6,"stretch":1.12}
				k = 18.0
		"stoop":
			var left := (_middle()-position).length()/maxf(vel.length(),1.0)
			if left < FLARE:
				# The flare: wings thrown wide, talons forward.
				want = {"elev":0.55,"sweep":-0.25,"wrist":0.0,"droop":0.3,"spread":1.0,"tail":1.0,"pitch":0.9,"head":-0.3,"jaw":0.8,"talons":1.0,"stretch":0.82}
				k = 26.0
			else:
				want = {"elev":0.3,"sweep":1.25,"wrist":2.6,"droop":0.05,"spread":0.0,"tail":0.0,"pitch":0.0,"head":0.15,"jaw":0.3,"stretch":1.28}
				k = 14.0
		"carry":
			want = Look.mix_pose(beat_pose,{"talons":1.0,"pitch":0.5,"tail":1.0,"head":0.4},0.5)
			want.elev = 0.25+1.0*s
			want.talons = 1.0
			k = 12.0
		"pull":
			want.talons = maxf(0.0,1.0-state_t*2.0)
			want.pitch = 0.35
			k = 8.0
	_pose = Look.mix_pose(_pose,want,1.0-exp(-k*delta))
	look.drive(_pose)

# --- The shadow -----------------------------------------------------------------------

## Thrown straight down (the abyss's light is from above) as two decals: a
## soft wide penumbra and a hard dark core. Both grow and darken the nearer
## it is to him (SHADOW_FAR, in his heights) and to what's under it; the
## core only shows while it commits (stalk, fold, stoop, carry), so a hard
## shadow on the ground means it is coming. While it commits the shadow is
## also pulled off the plumb line toward his feet (SHADOW_PULL of the way):
## its stalk point is often over the void, where a true shadow lands on
## nothing, so the shadow slides in toward him on the stalk, then sits on
## the spot the dive is locked on (`aim`) through the tell and the stoop:
## step off it on the scream and the shadow stays where you were.
const SHADOW_FAR := 20.0
const SHADOW_COMMIT := {"stalk":0.6, "fold":1.0, "stoop":1.0, "carry":0.7, "pull":0.4}
const SHADOW_PULL := {"stalk":0.55, "fold":1.0, "stoop":1.0}
var _shadow_core: Decal
var _shadow_commit := 0.0
var _shadow_pull := 0.0

func _shadow_make() -> void:
	_shadow = _shadow_decal("Shadow",_shadow_texture(false))
	_shadow_core = _shadow_decal("ShadowCore",_shadow_texture(true))
	_shadow_core.sorting_offset = 1.0
	_shadow_core.visible = false

func _shadow_decal(n: String, tex: Texture2D) -> Decal:
	var d := Decal.new()
	d.name = n
	d.texture_albedo = tex
	d.cull_mask = 0xFFFFF & ~Look.LAYER
	d.upper_fade = 0.0
	d.lower_fade = 0.15
	d.albedo_mix = 1.0
	add_child(d)
	d.top_level = true
	return d

static var _shadow_tex := {}
static func _shadow_texture(hard: bool) -> ImageTexture:
	if _shadow_tex.has(hard): return _shadow_tex[hard]
	var n := 128 if hard else 96
	var e := 0.25 if hard else 1.0
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for j in range(n):
		for i in range(n):
			var x := (float(i)+0.5)/n*2.0-1.0
			var z := (float(j)+0.5)/n*2.0-1.0
			var ax := absf(x)
			var mid := -0.05+0.18*ax
			var chord := 0.2*(1.0-ax*0.55)
			var wing := (1.0-smoothstep(chord-0.06*e,chord+0.08*e,absf(z-mid)))*(1.0-smoothstep(1.0-0.18*e,1.0,ax))
			var body := 1.0-smoothstep(1.0-0.3*e,1.0+0.15*e,Vector2(x/0.13,(z-0.05)/0.45).length())
			var tail := 1.0-smoothstep(1.0-0.3*e,1.0+0.2*e,Vector2(x/0.12,(z-0.55)/0.2).length())
			var a := clampf(maxf(wing,maxf(body,tail)),0.0,1.0)
			img.set_pixel(i,j,Color(0.02,0.018,0.02,a))
	_shadow_tex[hard] = ImageTexture.create_from_image(img)
	return _shadow_tex[hard]

func _shadow_place(dt: float) -> void:
	var want := float(SHADOW_COMMIT.get(state,0.0))
	_shadow_commit = move_toward(_shadow_commit,want,dt*(6.0 if want > _shadow_commit else 2.0))
	var pull := float(SHADOW_PULL.get(state,0.0))
	_shadow_pull = move_toward(_shadow_pull,pull,dt*(4.0 if pull > _shadow_pull else 1.5))
	var on: Vector3 = motor.feet if state == "stalk" or aim == Vector3.ZERO else aim-Vector3.UP*unit*0.55
	var h := position.y-_ground_y if _ground_y != -INF else 40.0
	h = lerpf(h,position.y-on.y,_shadow_pull)
	var near := clampf(1.0-h/(14.0*unit),0.0,1.0)
	var close := clampf(1.0-position.distance_to(_middle())/(SHADOW_FAR*unit),0.0,1.0)
	var open := 1.0-clampf(float(_pose.get("wrist",0.0))/2.5,0.0,0.7)
	var f := -global_basis.z
	var rot := Vector3(0.0,atan2(-f.x,-f.z),0.0)
	var at := position
	if _shadow_pull > 0.0:
		at.x = lerpf(at.x,on.x,_shadow_pull)
		at.z = lerpf(at.z,on.z,_shadow_pull)
		at.y = maxf(at.y,on.y+unit*2.0)
	at -= Vector3.UP*40.0
	var pop := _tell_pop*_tell_pop
	var size := span*(1.0+(1.0-near)*0.8)*(1.0+0.4*close)*(1.0+0.5*pop)
	_shadow.size = Vector3(size*open,80.0,size*0.55)
	_shadow.global_position = at
	_shadow.global_rotation = rot
	_shadow.modulate = Color(1,1,1,lerpf(0.16,0.62,maxf(near,close*0.85))*(1.0-0.45*_shadow_commit))
	_shadow_core.visible = _shadow_commit > 0.01
	if not _shadow_core.visible: return
	var core := span*(0.7+0.5*close)*(0.75+0.25*_shadow_commit)*(1.0+TELL_POP*pop)
	_shadow_core.size = Vector3(core*maxf(open,0.6),80.0,core*0.55)
	_shadow_core.global_position = at
	_shadow_core.global_rotation = rot
	_shadow_core.modulate = Color(1,1,1,maxf(_shadow_commit*lerpf(0.5,0.92,maxf(near,close)),0.97*pop))

# --- The tell -------------------------------------------------------------------------

## The tell is the biggest beat. With the scream (the loudest voice) come:
## the shadow's pop (the hard core thrown out TELL_POP wider and full dark,
## then drawn in onto the locked spot over the scream) and the glare (its
## eyes catch: a hot ember glow at the head, a fixed size on screen so it
## reads at any range, and a small light on the bird and the ground under
## it; alpha-blended, not added, so it reads on bright cloud). The glare is full through the scream, a pinpoint through the folded
## hold and the stoop (it tracks the drop), and out after.
const TELL_POP := 0.9
const GLARE_COLOR := Color(1.0,0.3,0.06)
## The glare's size as a fraction of the screen-ish (fixed-size quad).
const GLARE_SIZE := 0.3
const GLARE := {"scream":1.0, "hold":0.45, "stoop":0.3}
var _tell_pop := 0.0
var _glare_w := 0.0
var _glare: MeshInstance3D
var _glare_light: OmniLight3D

func _tell_make() -> void:
	var q := QuadMesh.new()
	q.size = Vector2.ONE*GLARE_SIZE
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.fixed_size = true
	m.no_depth_test = true
	m.albedo_texture = _glare_texture()
	m.albedo_color = GLARE_COLOR
	m.render_priority = 10
	q.material = m
	_glare = MeshInstance3D.new()
	_glare.name = "Glare"
	_glare.mesh = q
	_glare.layers = Look.LAYER
	_glare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glare.visible = false
	add_child(_glare)
	_glare.top_level = true
	_glare_light = OmniLight3D.new()
	_glare_light.name = "GlareLight"
	_glare_light.light_color = GLARE_COLOR
	_glare_light.omni_range = span*2.5
	_glare_light.shadow_enabled = false
	_glare_light.visible = false
	add_child(_glare_light)
	_glare_light.top_level = true

## A soft round glow with a hot centre: two eyes' worth of eyeshine.
static var _glare_tex: ImageTexture
static func _glare_texture() -> ImageTexture:
	if _glare_tex: return _glare_tex
	var n := 64
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for j in range(n):
		for i in range(n):
			var r := Vector2((float(i)+0.5)/n*2.0-1.0,(float(j)+0.5)/n*2.0-1.0).length()
			var a := clampf(pow(maxf(1.0-r,0.0),1.4)*0.85+exp(-r*r*40.0),0.0,1.0)
			var hot := exp(-r*r*30.0)
			img.set_pixel(i,j,Color(1.0,0.75+0.25*hot,0.6+0.4*hot,a))
	_glare_tex = ImageTexture.create_from_image(img)
	return _glare_tex

func _tell_place(dt: float) -> void:
	var scream := float(knobs.fold)*TELL_SCREAM
	_tell_pop = move_toward(_tell_pop,0.0,dt/scream)
	var want := 0.0
	match state:
		"fold": want = GLARE.scream if state_t < scream else GLARE.hold
		"stoop": want = GLARE.stoop
	# On fast at the scream, out slower after the dive.
	_glare_w = want if want > _glare_w else move_toward(_glare_w,want,dt*3.0)
	var on := _glare_w > 0.01
	_glare.visible = on
	_glare_light.visible = on
	if not on: return
	# Flicker through the scream: the throat working.
	var flick := 1.0
	if state == "fold" and state_t < scream: flick = 0.85+0.15*sin(state_t*TAU*11.0)
	# On the head bone: it rides the scream's rear-back and the stoop's tuck.
	var head: Vector3 = look.eyes()
	_glare.global_position = head
	_glare.scale = Vector3.ONE*lerpf(0.35,1.0,_glare_w)*(1.0+0.5*_tell_pop)*flick
	_glare.transparency = 1.0-clampf(_glare_w*flick,0.0,1.0)
	_glare_light.global_position = head
	_glare_light.light_energy = 4.0*_glare_w*flick

# --- Voice and feathers ---------------------------------------------------------------

## The voices, each a distinct cue: the marking call (two rising barks:
## it has noticed you), the click (its sonar: slow and quiet while marked,
## then faster, higher and louder through the stalk), the scream (the tell,
## the loudest beat: as long as the fold, loud through the scream, choked
## off into a held silence before the drop), the rush of the stoop, the
## hit's thump, the wingbeat's whump and the cry (snatch over: a let-go).
## VOICES: per voice, its level (dB) and its reach (unit_size, m).
const VOICES := {
	&"mark":[0.0,40.0], &"click":[-3.0,16.0], &"scream":[8.0,70.0], &"rush":[0.0,40.0],
	&"hit":[2.0,40.0], &"wing":[-4.0,20.0], &"cry":[-3.0,40.0],
}
## The marked circle's slow clicks (s apart).
const CLICK_MARKED := 0.9
static var _streams := {}
func _voices_make() -> void:
	if _streams.is_empty():
		_streams[&"click"] = _synth_click()
		_streams[&"cry"] = _synth_cry()
		_streams[&"scream"] = _synth_scream()
		_streams[&"rush"] = _synth_rush()
		_streams[&"hit"] = _synth_hit()
		_streams[&"mark"] = _synth_mark()
		_streams[&"wing"] = _synth_wing()
	for k: StringName in _streams:
		var p := AudioStreamPlayer3D.new()
		p.name = "Voice_"+String(k)
		p.stream = _streams[k]
		p.unit_size = float(VOICES[k][1])
		p.max_db = maxf(3.0,float(VOICES[k][0])+2.0)
		add_child(p)
		_voices[k] = p

## Plays a voice, `db` over its level, at `pitch`; logged as a beat
## ("sound <voice>") with the level it played at.
var last_voice := {}
func _say(what: StringName, db := 0.0, pitch := 1.0) -> void:
	var lvl := float(VOICES.get(what,[0.0])[0])+db
	last_voice = {"what":what,"db":lvl,"pitch":pitch}
	beat.emit("sound "+String(what))
	var p: AudioStreamPlayer3D = _voices.get(what)
	if p == null or not p.is_inside_tree(): return
	p.volume_db = lvl
	p.pitch_scale = pitch
	p.play()

static func _wav(data: PackedFloat32Array, rate: int) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size()*2)
	for i in range(data.size()): bytes.encode_s16(i*2,int(clampf(data[i],-1.0,1.0)*32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.data = bytes
	return wav

static func _synth_click() -> AudioStreamWAV:
	var rate := 22050
	var n := int(0.03*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in range(n):
		var t := float(i)/rate
		var env := exp(-t*260.0)
		out[i] = (sin(TAU*2300.0*t)*0.6+rng.randf_range(-1.0,1.0)*0.4)*env*0.9
	return _wav(out,rate)

static func _synth_cry() -> AudioStreamWAV:
	var rate := 22050
	var dur := 1.05
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var ph := 0.0
	var ph2 := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		var k := t/dur
		var env := minf(t/0.03,1.0)*pow(1.0-k,1.2)*(0.75+0.25*sin(TAU*31.0*t))
		var f := lerpf(980.0,620.0,k)*(1.0+0.035*sin(TAU*7.0*t))
		ph += f/rate
		ph2 += f*1.51/rate
		var saw := fposmod(ph,1.0)*2.0-1.0
		var saw2 := fposmod(ph2,1.0)*2.0-1.0
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.5)
		out[i] = (saw*0.45+saw2*0.2+low*0.5)*env*0.85
	return _wav(out,rate)

## The tell's scream: TELL long. Harsh and full (two detuned saws, noise,
## a rough flutter, driven into soft clipping) through the scream
## (TELL*TELL_SCREAM), pitch rising then breaking down; then choked off by
## 0.75 of the tell, so the folded hold before the drop is silent.
static func _synth_scream() -> AudioStreamWAV:
	var rate := 22050
	var dur := TELL
	var cut := TELL*TELL_SCREAM
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var ph := 0.0
	var ph2 := 0.0
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		var env := minf(t/0.015,1.0)
		if t > cut: env *= pow(clampf(1.0-(t-cut)/(dur*0.75-cut),0.0,1.0),2.0)
		env *= 0.8+0.2*sin(TAU*38.0*t)
		var f := lerpf(1150.0,1450.0,clampf(t/(cut*0.6),0.0,1.0))
		if t > cut*0.6: f = lerpf(1450.0,620.0,clampf((t-cut*0.6)/(dur*0.75-cut*0.6),0.0,1.0))
		f *= 1.0+0.04*sin(TAU*9.0*t)
		ph += f/rate
		ph2 += f*1.49/rate
		var saw := fposmod(ph,1.0)*2.0-1.0
		var saw2 := fposmod(ph2,1.0)*2.0-1.0
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.55)
		out[i] = tanh((saw*0.6+saw2*0.35+low*0.55)*2.2)*env*0.95
	return _wav(out,rate)

## A wingbeat: a soft low whump (low-passed air and a 60 Hz thud).
static func _synth_wing() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.26
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		var env := minf(t/0.035,1.0)*exp(-maxf(t-0.035,0.0)*16.0)
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.06)
		out[i] = (low*2.2+sin(TAU*60.0*t)*0.35)*env*0.8
	return _wav(out,rate)

## The marking call: two short harsh barks, rising, quieter than the cry.
static func _synth_mark() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.42
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in range(n):
		var t := float(i)/rate
		var b := 0 if t < 0.17 else 1
		var bt := t-0.22*float(b)
		var env := 0.0 if bt < 0.0 else minf(bt/0.012,1.0)*exp(-bt*16.0)
		var f := lerpf(520.0,760.0,clampf(bt/0.12,0.0,1.0))*(1.0+0.25*float(b))
		ph += f/rate
		var saw := fposmod(ph,1.0)*2.0-1.0
		out[i] = (saw*0.6+sin(TAU*ph*2.0)*0.3)*env*0.7
	return _wav(out,rate)

static func _synth_rush() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.9
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		var k := t/dur
		var env := k*k*(1.0-smoothstep(0.85,1.0,k))
		low = lerpf(low,rng.randf_range(-1.0,1.0),lerpf(0.04,0.35,k))
		out[i] = low*env*1.6
	return _wav(out,rate)

static func _synth_hit() -> AudioStreamWAV:
	var rate := 22050
	var dur := 0.35
	var n := int(dur*rate)
	var out := PackedFloat32Array()
	out.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var low := 0.0
	for i in range(n):
		var t := float(i)/rate
		var env := exp(-t*14.0)
		low = lerpf(low,rng.randf_range(-1.0,1.0),0.12)
		out[i] = (low*0.9+sin(TAU*70.0*t)*0.5)*env
	return _wav(out,rate)

## Loose feathers that drift down from a strike.
func _feathers_make() -> void:
	_feathers = CPUParticles3D.new()
	_feathers.name = "Feathers"
	_feathers.emitting = false
	_feathers.one_shot = true
	_feathers.amount = 10
	_feathers.lifetime = 3.5
	_feathers.explosiveness = 0.95
	var q := QuadMesh.new()
	q.size = Vector2(0.09,0.32)*(span/3.4)
	_feathers.mesh = q
	_feathers.material_override = look.feather_mat
	_feathers.direction = Vector3.UP
	_feathers.spread = 80.0
	_feathers.initial_velocity_min = 1.5
	_feathers.initial_velocity_max = 4.0
	_feathers.gravity = Vector3(0.0,-1.2,0.0)
	_feathers.damping_min = 1.5
	_feathers.damping_max = 2.5
	_feathers.angular_velocity_min = -200.0
	_feathers.angular_velocity_max = 200.0
	add_child(_feathers)
	_feathers.top_level = true
