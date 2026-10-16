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
##           way), its line to him clear, and hangs there circling tight,
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
##           a void within VOID_CARRY of him (rim, hold, wall, rope, leap),
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
var _stalk_check := 0.0
var _safe_t := 0.0
var _cover_t := 0.0
var _click_t := 0.0
var _prev := Vector3.ZERO
var _vel_prev := Vector3.ZERO
var _carry_dir := Vector3.ZERO
var _struggles := 0
var _cam_fwd := Vector3.FORWARD
var _shadow: Decal
var _voices := {}
var _feathers: CPUParticles3D
var _rng := RandomNumberGenerator.new()

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
	_orient(delta)
	_animate(delta)
	_shadow_place()

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
	if close and ready_to:
		if _pick_stalk():
			_go("stalk")
			flyers.stalker = self
			_click_t = 0.0

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
## at the player), out and over him, the line to his middle clear.
func _pick_stalk() -> bool:
	var mid := _middle()
	var fwd := Vector3(_cam_fwd.x,0.0,_cam_fwd.z)
	fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
	var side := float(knobs.stalk_side)
	# In view first; failing that wider round him, then higher.
	for up: float in [1.0,2.2]:
		for a: float in [side,-side,side*0.4,-side*0.4,side*1.8,-side*1.8,side*3.0,-side*3.0,0.0]:
			var way := fwd.rotated(Vector3.UP,a*turn)
			var p := mid+way*float(knobs.stalk_out)*unit+Vector3.UP*float(knobs.stalk_up)*up*unit
			if field.blocked(mid+Vector3.UP*0.3,p-mid-Vector3.UP*0.3): continue
			# Room under it to hang (not in the grass).
			if field.floor_under(p,0.5,1.4*unit) != -INF: continue
			_stalk_ang = a*turn
			_stalk_up = up
			_stalk_at = p
			return true
	return false

func _stalk(delta: float, hunting: bool) -> void:
	_stalk_check -= delta
	if _stalk_check <= 0.0:
		_stalk_check = 0.5
		if not _pick_stalk():
			_give_up()
			return
	var mid := _middle()
	var fwd := Vector3(_cam_fwd.x,0.0,_cam_fwd.z).normalized()
	_stalk_at = _stalk_at.lerp(mid+fwd.rotated(Vector3.UP,_stalk_ang)*float(knobs.stalk_out)*unit+Vector3.UP*float(knobs.stalk_up)*_stalk_up*unit,1.0-exp(-2.0*delta))
	var r := float(knobs.stalk_r)*unit
	var ang := state_t*float(knobs.stalk_speed)/maxf(r,0.5)*0.5*turn
	var target := _stalk_at+Vector3(cos(ang)*r,sin(state_t*1.7)*0.3*unit,sin(ang)*r)
	_steer(target,float(knobs.stalk_speed)+position.distance_to(target)*0.6,16.0,delta,false)
	_flap_w = move_toward(_flap_w,0.6,delta*2.0)
	# The clicks: slow, then fast as it makes up its mind.
	var ready := clampf(state_t/float(knobs.stalk_max),0.0,1.0)
	_click_t -= delta
	if _click_t <= 0.0:
		_click_t = lerpf(CLICK_SLOW,CLICK_FAST,ready)
		_say(&"click")
	if not hunting or _safe_t >= float(knobs.abort) or _cover_t >= float(knobs.cover_break):
		_give_up()
		return
	var near := position.distance_to(_stalk_at) < r*2.0 and vel.length() < float(knobs.stalk_speed)*1.6
	if near and state_t >= float(knobs.stalk_min) and (exposure >= 0.85 or (state_t >= float(knobs.stalk_max) and exposure >= 0.4)):
		# The aim is locked with the scream: where he will be if he keeps
		# on as he is (LEAD of his pace over the fold and the dive). Kept
		# on, he is hit; turned, stopped or started, he is missed.
		var flat := Vector3(motor.velocity.x,0.0,motor.velocity.z)
		var dive := mid.distance_to(position)/(float(knobs.stoop_top)*0.55)
		aim = mid+flat*(float(knobs.fold)+dive)*float(knobs.lead)
		_go("fold")
		_say(&"cry")

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

## A soft dark bird-shape thrown straight down (the abyss's light is from
## above), sharper and darker the nearer it is to what's under it: as it
## stalks and dives, its shadow grows and closes on him.
func _shadow_make() -> void:
	_shadow = Decal.new()
	_shadow.name = "Shadow"
	_shadow.texture_albedo = _shadow_texture()
	_shadow.cull_mask = 0xFFFFF & ~Look.LAYER
	_shadow.upper_fade = 0.0
	_shadow.lower_fade = 0.15
	_shadow.albedo_mix = 1.0
	add_child(_shadow)
	_shadow.top_level = true

static var _shadow_tex: ImageTexture = null
static func _shadow_texture() -> ImageTexture:
	if _shadow_tex != null: return _shadow_tex
	var n := 96
	var img := Image.create(n,n,false,Image.FORMAT_RGBA8)
	for j in range(n):
		for i in range(n):
			var x := (float(i)+0.5)/n*2.0-1.0
			var z := (float(j)+0.5)/n*2.0-1.0
			var ax := absf(x)
			var mid := -0.05+0.18*ax
			var chord := 0.2*(1.0-ax*0.55)
			var wing := (1.0-smoothstep(chord-0.06,chord+0.08,absf(z-mid)))*(1.0-smoothstep(0.82,1.0,ax))
			var body := 1.0-smoothstep(0.7,1.15,Vector2(x/0.13,(z-0.05)/0.45).length())
			var tail := 1.0-smoothstep(0.7,1.2,Vector2(x/0.12,(z-0.55)/0.2).length())
			var a := clampf(maxf(wing,maxf(body,tail)),0.0,1.0)
			img.set_pixel(i,j,Color(0.02,0.018,0.02,a))
	_shadow_tex = ImageTexture.create_from_image(img)
	return _shadow_tex

func _shadow_place() -> void:
	var h := position.y-_ground_y if _ground_y != -INF else 40.0
	var near := clampf(1.0-h/(14.0*unit),0.0,1.0)
	var open := 1.0-clampf(float(_pose.get("wrist",0.0))/2.5,0.0,0.7)
	var size := span*(1.0+(1.0-near)*0.8)
	_shadow.size = Vector3(size*open,80.0,size*0.55)
	_shadow.global_position = position-Vector3.UP*40.0
	var f := -global_basis.z
	_shadow.global_rotation = Vector3(0.0,atan2(-f.x,-f.z),0.0)
	_shadow.modulate = Color(1,1,1,lerpf(0.18,0.72,near))

# --- Voice and feathers ---------------------------------------------------------------

## The voices: a click (its sonar), the cry (a harsh, snarling scream:
## the tell), the rush of the stoop, the hit's thump and a wingbeat.
static var _streams := {}
func _voices_make() -> void:
	if _streams.is_empty():
		_streams[&"click"] = _synth_click()
		_streams[&"cry"] = _synth_cry()
		_streams[&"rush"] = _synth_rush()
		_streams[&"hit"] = _synth_hit()
		_streams[&"mark"] = _synth_mark()
	for k: StringName in _streams:
		var p := AudioStreamPlayer3D.new()
		p.stream = _streams[k]
		p.unit_size = 14.0 if k == &"click" else 40.0
		p.max_db = 3.0
		add_child(p)
		_voices[k] = p

func _say(what: StringName) -> void:
	beat.emit("sound "+String(what))
	var p: AudioStreamPlayer3D = _voices.get(what)
	if p != null and p.is_inside_tree(): p.play()

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
