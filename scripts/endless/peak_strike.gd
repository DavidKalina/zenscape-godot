extends Node3D
## The mountain's anger: while the plane climbs it, the tip of a spiral notices,
## draws up and strikes, a stream of the spiral's own cloud coursing down the
## ridges and gullies at where the plane is going. Seen coming, dodgeable, and
## where it lands a shove back and down the mountain, no more.
##
## One strike at a time, in stages:
##   GATHER  the ribbon quickens, its tip runs on along the coil and thickens.
##   REAR    it leaves the coil, turns to the plane and holds: the snake's cock.
##   RUN     it hunts: it leads the plane, steers at a set rate, hugs the land
##           and leans into the gullies.
##   LUNGE   the last stretch, fast and straight. Too late to steer: a turn made
##           now beats it. Rock in the way breaks it (`_broke`).
##   RECOIL  it spools back up the way it came.
## The body is shaders/peak_strike.gdshader, a line of points through the sky
## drawn in the ribbon's look; the head drops a point as it goes. Nothing here
## runs while it sleeps but `_watch`, some arithmetic a frame; the box is hidden.
##
## The shove reaches the plane through the air callable (`air_at`, wrapping the
## lift's): "wind" in m/s, "jet" for the camera's kick, "shove" for the nose. So
## the plane's own step eases it back and the stick stays live throughout.
##
## --peak-strike=0 none. --peak-strike=SECONDS forces a strike that long after
## launch and every SECONDS after, wherever the plane is, for proofs
## (`--peak-strike-spire=i` picks the spire). `force(i)` does the same at once.

const SHADER := preload("res://shaders/peak_strike.gdshader")
const LaunchArgs := preload("res://scripts/launch_args.gd")
const Field := preload("res://scripts/endless/land_field.gd")

enum { IDLE, GATHER, REAR, RUN, LUNGE, RECOIL }

## The shader's POINTS and GROUP.
const POINTS := 33
const GROUP := 8
const PRIORITY := 9

# --- When ------------------------------------------------------------------------

## Over the sea (m): under the first nothing stirs; by the second it is at its
## angriest (the spires' feet).
const SHOULDER := 520.0
const SPIRE_FOOT := 1150.0
## Over the ground from the crown's middle (m): watched inside the first, not
## past the second.
const WATCH := Vector2(1300.0,1900.0)
## The climb that counts (m/s up, smoothed over CLIMB_EASE s): none, all of it.
const CLIMB := Vector2(4.0,12.0)
const CLIMB_EASE := 1.2
## Seconds of climbing before the first strike, and between the end of one and
## the next, at the shoulders and at the spires. The wait only runs while the
## plane climbs on the mountain.
const FIRST_WAIT := 2.5
const GAP := Vector2(15.0,7.0)
const GAP_SPREAD := Vector2(0.8,1.3)
## A spire within this of the plane doesn't strike (m): it would come on top of
## it. Past the second it doesn't reach.
const RANGE := Vector2(420.0,1900.0)
## The plateau's keep: inside this reach of its centre and under KEEP_OVER over
## the strip no strike starts, a live one goes home and no shove lands.
const KEEP_R := 420.0
const KEEP_OVER := 170.0
## Over the plateau the stream stays this far over the strip (m).
const KEEP_FLOOR := 70.0
## It reaches this far over the highest tip (m), and no further: over that the
## plane is out of its reach.
const REACH_OVER := 140.0

# --- The strike ------------------------------------------------------------------

## Seconds drawing up and holding, at the shoulders and at the spires.
const GATHER_TIME := Vector2(2.0,1.5)
const REAR_TIME := Vector2(1.2,0.9)
## Along the ribbon, as shares of its length, where the head starts and leaves.
const COIL_FROM := 0.72
const COIL_TO := 0.92
## Rearing: how far out it comes (m) toward the plane, and how far up.
const REAR_OUT := 130.0
const REAR_UP := 30.0
## Hunting speed (m/s), at the shoulders and at the spires, and how fast it
## steers (radians/s).
const SPEED := Vector2(125.0,145.0)
const TURN := Vector2(0.55,0.85)
## Spin-up out of the rear (m/s²).
const ACCEL := 90.0
## The lead: of the seconds to arrival, at most LEAD_MAX s, LEAD_SHARE of the way.
const LEAD_MAX := 2.2
const LEAD_SHARE := 0.75
## The lunge: from this far (m), at this speed (m/s), steering this much (rad/s).
const LUNGE_FROM := 380.0
const LUNGE_SPEED := 160.0
const LUNGE_TURN := 0.03
## Past this far from where the lunge began it's spent (m).
const LUNGE_RUN := 520.0
## At the shoulders the first strikes are warnings: aimed this far (m) wide of
## the plane, to cross its way ahead. Under WARN_UNDER of the way up.
const WARN_WIDE := 170.0
const WARN_UNDER := 0.3
## Gives up after this long hunting (s), or past this much line (m).
const RUN_MAX := 11.0
const LINE_MAX := 2600.0
## Back up the line at this speed (m/s), and at this when the land took the plane.
const RECOIL_SPEED := 420.0
const HOME_SPEED := 800.0

# --- The land --------------------------------------------------------------------

## How often it reads the land (s), how far ahead (m), the spread of its two
## feelers (radians).
const FEEL_EVERY := 0.1
const FEEL_AHEAD := 110.0
const FEEL_SPREAD := 0.6
## Over the land, m: its hug far from the plane, and the least it keeps.
const HUG := 38.0
const HUG_LEAST := 16.0
## Inside the first (m) it comes up to the plane's height; past the second it
## keeps to the land.
const HUG_NEAR := Vector2(200.0,480.0)
## A height difference between the feelers of this (m) turns it GULLY_TURN rad/s
## toward the low side, out of the plane's reach only.
const GULLY_SPAN := 50.0
const GULLY_TURN := 0.55
## Far out it swings wide of the line to the plane, by this (m), so the body
## shows side on and it curls in; and weaves, by this much bend at this rate
## (radians, radians/s).
const SWING := 300.0
const WEAVE := Vector2(0.5,2.2)
## How fast it changes height (m/s), a share of its speed.
const CLIMB_SHARE := 0.8
## Clear of a tower by this past its girth (m).
const TOWER_ROOM := 45.0

# --- The body --------------------------------------------------------------------

## The rope's girth (m): head, body, tail. A point every STEP m of line.
const GIRTH := Vector3(58.0,32.0,12.0)
const STEP := 46.0
## The body's slither: a wave of this many m, this long, this fast.
const SLITHER := Vector3(9.0,170.0,4.5)
## How fast the cloud runs along the body toward the head (m/s), and turns.
const FLOW := 70.0
const WRAP := 6450.0
const SPIN_RATE := 4.0
## The box's reach past the line (m).
const BOX := 130.0
const LOOK_EVERY := 0.5

# --- The shove -------------------------------------------------------------------

## It lands within this of the head (m); and of a point the last NECK m of body.
const HIT_R := 44.0
const NECK := 70.0
## The wind's peak (m/s), its rise and its fall (s; the fall is an exponential).
const WIND := 170.0
const RISE := 0.12
const FALL := 0.75
## How far below level it pushes (radians).
const DOWN := 0.7
## On the plane: the nose down and turned (rad/s at the peak), the wings tipped.
const NOSE_DOWN := 1.1
const NOSE_TURN := 0.5
const WINGS := 1.6
## Ways tried round the push (radians either side of straight back), and the
## clearance along it (m) that's good enough.
const WAYS := [0.0,0.5,-0.5,1.0,-1.0,1.6,-1.6]
const FEELS := [50.0,100.0,160.0]
const CLEAR := 45.0
## Under this clearance ahead of the push it lifts off it (m).
const GUARD := 35.0
const GUARD_AHEAD := 0.4
## Done under this share of its peak.
const SPENT := 0.03

var state := IDLE
## What the last strike did: for the proofs. {spire, warned (s, GATHER began),
## ran (s, RUN began), from (m, head to plane at RUN), hit (s), broke, gave_up,
## shove: {at, dir, wind, down}}.
var last := {}
var strikes := 0
var hits := 0
var anger := 0.0

var _game: Node
var _peak: RefCounted
var _spirals: Node3D
var _towers: Node3D
var _height: Callable
var _under: Callable
var _rng := RandomNumberGenerator.new()
var _plane: RefCounted
var _middle := Vector2.ZERO
var _plateau := Vector2.ZERO
var _strip_y := 0.0
var _tips: Array[Vector3] = []
var _tower_axes: Array = []
var _box: MeshInstance3D
var _mat: ShaderMaterial
var _clock := 0.0
var _force_every := 0.0
var _force_wait := INF
var _force_spire := -1

# Watching.
var _climb := 0.0
var _wait := FIRST_WAIT
var _last_spire := -1

# The live strike.
var _spire := -1
var _t := 0.0
var _fury := 0.0
var _warn := 0.0
var _swing := 0.0
var _rouse := 0.0
var _head := Vector3.ZERO
var _dir := Vector3.DOWN
var _speed := 0.0
var _top_speed := 0.0
var _turn := 0.0
var _feel := 0.0
var _floor := -INF
var _gully := 0.0
var _here_y := -INF
var _lunge_at := Vector3.ZERO
var _rear_from := Vector3.ZERO
var _rear_to := Vector3.ZERO
var _line: Array[Vector3] = []
var _coil_shares := PackedFloat32Array()
var _dropped := 0.0
var _line_m := 0.0
var _head_s := 0.0
var _tail_s := 0.0
var _flow := 0.0
var _spin := 0.0
var _wiggle := 0.0
var _look_wait := 0.0
var _recoil_speed := RECOIL_SPEED
var _pts := PackedVector4Array()
var _nrm := PackedVector3Array()
var _grp := PackedVector4Array()

# The shove.
var _push_t := -1.0
var _push_dir := Vector3.ZERO
var _push_turn := Vector3.ZERO
var _guard_k := 1.0


## Whether strikes run: --peak-strike=0 not.
static func wanted() -> bool:
	for a in LaunchArgs.user_args():
		if a.begins_with("--peak-strike="): return a.get_slice("=",1) != "0"
	return true


## Built once at the land's setup. `air` is the air it wraps; pass `air_at` to
## the plane in its place.
func setup(game: Node, peak: RefCounted, spirals: Node3D, towers: Node3D, height: Callable, seed: int, air: Callable) -> void:
	_game = game
	_peak = peak
	_spirals = spirals
	_towers = towers
	_height = height
	_under = air
	_plane = game.plane
	_rng.seed = hash(seed)^int(Time.get_ticks_usec())
	var tarn: Dictionary = peak.tarn()
	_plateau = tarn.plateau
	_strip_y = (tarn.strip[0] as Vector3).y
	if towers != null: _tower_axes = towers.axes()
	var mid := Vector2.ZERO
	for t: Dictionary in _tower_axes:
		var tip: Vector3 = t.tip
		_tips.append(tip)
		mid += Vector2(tip.x,tip.z)
	_middle = mid/maxf(float(_tips.size()),1.0)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.render_priority = PRIORITY
	_box = MeshInstance3D.new()
	_box.name = "StrikeBox"
	_box.mesh = BoxMesh.new()
	_box.material_override = _mat
	_box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_box.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	_box.top_level = true
	add_child(_box)
	_pts.resize(POINTS)
	_nrm.resize(POINTS)
	_grp.resize(4)
	for a in LaunchArgs.user_args():
		if a.begins_with("--peak-strike=") and a.get_slice("=",1).is_valid_float() and a.get_slice("=",1) != "1":
			_force_every = a.get_slice("=",1).to_float()
			_force_wait = _force_every
		if a.begins_with("--peak-strike-spire="): _force_spire = a.get_slice("=",1).to_int()
	# Drawn once out of sight with nothing to draw (`count` 0 discards), so its
	# shader is built during the load and not in the first strike. See `step`.
	_box.visible = true
	_box.position = Vector3(_tips[0].x,_tips[0].y+4000.0,_tips[0].z) if not _tips.is_empty() else Vector3.ZERO
	_primed = 8

var _primed := 0


## Strike now, from spire `i` (< 0: the best placed), wherever the plane is.
func force(i := -1) -> bool:
	if state != IDLE or _tips.is_empty(): return false
	if i < 0: i = _pick(true)
	if i < 0: i = 0
	_begin(i)
	last["forced"] = true
	return true


## One frame.
func step(delta: float) -> void:
	_plane = _game.plane
	if _primed > 0:
		_primed -= 1
		if _primed == 0: _box.visible = false
	_clock += delta
	_shove_step(delta)
	if _force_wait < INF and _game.get("hand_landing") != null and _game.hand_landing.flying():
		_force_wait -= delta
		if _force_wait <= 0.0:
			_force_wait = _force_every
			force(_force_spire)
	if state == IDLE:
		_watch(delta)
		return
	_t += delta
	_climb = lerpf(_climb,float(_plane.velocity.y),1.0-exp(-delta/CLIMB_EASE))
	if state != RECOIL and _called_off(): _go_home(HOME_SPEED)
	match state:
		GATHER: _gather(delta)
		REAR: _rear(delta)
		RUN: _run(delta)
		LUNGE: _lunge(delta)
		RECOIL: _recoil(delta)
	if state == IDLE: return
	_rouse = move_toward(_rouse,0.0 if state == RECOIL else 1.0,delta*(0.5 if state == RECOIL else 1.2))
	_spirals.rouse(_spire,_rouse)
	_drop()
	_draw(delta)
	_cue()


# --- Watching --------------------------------------------------------------------

func _height_share(y: float) -> float:
	return clampf((y-Field.SEA_Y-SHOULDER)/(SPIRE_FOOT-SHOULDER),0.0,1.0)

func _kept(p: Vector3) -> bool:
	return Vector2(p.x,p.z).distance_to(_plateau) < KEEP_R and p.y < _strip_y+KEEP_OVER

## As high as it reaches, world.
func _ceiling() -> float:
	var top := -INF
	for t in _tips: top = maxf(top,t.y)
	return top+REACH_OVER

## The plane's left, landed or come in to land: nothing to be angry at.
func _called_off() -> bool:
	if _force_every > 0.0 or bool(last.get("forced",false)): return false
	if not _game.hand_landing.flying(): return true
	var p: Vector3 = _plane.position
	if _kept(p): return true
	return Vector2(p.x,p.z).distance_to(_middle) > WATCH.y+300.0

func _watch(delta: float) -> void:
	_climb = lerpf(_climb,float(_plane.velocity.y),1.0-exp(-delta/CLIMB_EASE))
	var p: Vector3 = _plane.position
	var flat := Vector2(p.x,p.z).distance_to(_middle)
	var high := _height_share(p.y)
	var on := smoothstep(CLIMB.x,CLIMB.y,_climb)*(1.0-smoothstep(WATCH.x,WATCH.y,flat))
	if p.y-Field.SEA_Y < SHOULDER: on = 0.0
	anger = lerpf(anger,on*(0.4+0.6*high),1.0-exp(-delta/3.0))
	if on < 0.5 or p.y > _ceiling() or _kept(p) or not _game.hand_landing.flying(): return
	_wait -= delta
	if _wait > 0.0: return
	var i := _pick(false)
	if i < 0:
		_wait = 1.0
		return
	_begin(i)

## The spire to strike from: ahead of the plane, in range, not the one before.
## -1 if none is (`any`: range waived).
func _pick(any: bool) -> int:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	var way := Vector3(v.x,maxf(v.y,0.0),v.z).normalized()
	var best := -1
	var top := -INF
	for i in mini(_tips.size(),_spirals.count()):
		var to := _tips[i]-p
		var d := to.length()
		if not any and (d < RANGE.x or d > RANGE.y): continue
		var score := to.normalized().dot(way)+_rng.randf_range(0.0,0.6)
		if i == _last_spire: score -= 0.7
		if score > top:
			top = score
			best = i
	return best

func _begin(i: int) -> void:
	_spire = i
	_last_spire = i
	strikes += 1
	_t = 0.0
	var high := _height_share(_plane.position.y)
	_fury = high
	_warn = WARN_WIDE*(1.0 if _rng.randf() < 0.5 else -1.0) if high < WARN_UNDER and _force_every <= 0.0 else 0.0
	_swing = SWING*_rng.randf_range(0.6,1.2)*(1.0 if _rng.randf() < 0.5 else -1.0)
	state = GATHER
	last = {"spire":i,"warned":_clock,"warn_wide":_warn,"fury":high,"forced":_force_every > 0.0}
	_top_speed = lerpf(SPEED.x,SPEED.y,_fury)
	_turn = lerpf(TURN.x,TURN.y,_fury)
	_line.clear()
	_coil_shares.clear()
	_head = _spirals.ribbon_at(i,COIL_FROM)
	_line.append(_head)
	_coil_shares.append(COIL_FROM)
	_dropped = 0.0
	_head_s = 0.0
	_tail_s = 0.0
	_flow = 0.0
	_speed = 0.0
	_feel = 0.0
	_floor = -INF
	_gully = 0.0
	_here_y = -INF
	var c: Vector3 = _spirals.coil(i)
	_mat.set_shader_parameter("hand",c.x)
	_mat.set_shader_parameter("seed",float(strikes)*1.3+float(i))
	_mat.set_shader_parameter("girth",GIRTH)
	_spirals.lend_look(_mat)
	_look_wait = LOOK_EVERY
	_box.visible = true
	var tip := _tips[i]
	if _game.get("sound") != null: _game.sound.shot("whoosh",0.5,0.5,tip,&"SFX",true)


# --- The stages ------------------------------------------------------------------

## It runs on along its own coil; the line's points on the coil keep to the
## ribbon as it turns.
func _gather(delta: float) -> void:
	var span := lerpf(GATHER_TIME.x,GATHER_TIME.y,_fury)
	var k := clampf(_t/span,0.0,1.0)
	var share := lerpf(COIL_FROM,COIL_TO,k*k*(3.0-2.0*k))
	var last_share: float = _coil_shares[_coil_shares.size()-1]
	if share-last_share > 0.018:
		_coil_shares.append(share)
		_line.append(_spirals.ribbon_at(_spire,share))
	_head = _spirals.ribbon_at(_spire,share)
	_keep_coil()
	if k >= 1.0:
		state = REAR
		_t = 0.0
		var to := _aim()-_head
		_rear_from = _head
		_rear_to = _head+to.normalized()*REAR_OUT+Vector3.UP*REAR_UP
		var ground := float(_height.call(_rear_to.x,_rear_to.z))
		_rear_to.y = maxf(_rear_to.y,ground+HUG)
		_dir = (_rear_to-_head).normalized()

## The points on the coil, where the ribbon is now.
func _keep_coil() -> void:
	for i in _coil_shares.size(): _line[i] = _spirals.ribbon_at(_spire,_coil_shares[i])

## It comes off the coil, turns and holds, swaying: the telegraph's last beat.
func _rear(delta: float) -> void:
	_keep_coil()
	var span := lerpf(REAR_TIME.x,REAR_TIME.y,_fury)
	var k := clampf(_t/span,0.0,1.0)
	var eased := 1.0-(1.0-k)*(1.0-k)*(1.0-k)
	var sway := Vector3(_dir.z,0.0,-_dir.x)*sin(_t*7.0)*6.0*k
	var was := _head
	_head = _rear_from.lerp(_rear_to,eased)+sway
	_speed = was.distance_to(_head)/maxf(delta,0.001)
	var to := (_aim()-_head).normalized()
	_dir = _dir.slerp(to,clampf(delta*3.0,0.0,1.0)).normalized()
	if k >= 1.0:
		state = RUN
		_t = 0.0
		_speed = 25.0
		_dir = to
		last["ran"] = _clock
		last["from"] = _head.distance_to(_plane.position)
		last["run_from"] = _head

## Where it wants to be: the plane's place ahead, `_warn` wide of it.
func _aim() -> Vector3:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	var d := _head.distance_to(p)
	var eta := d/maxf(_top_speed,1.0)
	var goal := p+v*minf(eta,LEAD_MAX)*LEAD_SHARE
	var across := Vector3(p.x-_head.x,0.0,p.z-_head.z).normalized()
	goal += Vector3(across.z,0.0,-across.x)*_swing*smoothstep(HUG_NEAR.x,HUG_NEAR.y*1.5,d)
	if _warn != 0.0:
		var flat := Vector3(v.x,0.0,v.z).normalized()
		goal += Vector3(flat.z,0.0,-flat.x)*_warn+flat*absf(_warn)*0.5
	return goal

## The lunge's mark: where the plane will be if it holds its line. Hold it and
## this lands; leave it and it doesn't.
func _line_on() -> Vector3:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	var d := _head.distance_to(p)
	var goal := p+v*d/LUNGE_SPEED
	if _warn != 0.0:
		var flat := Vector3(v.x,0.0,v.z).normalized()
		goal += Vector3(flat.z,0.0,-flat.x)*_warn+flat*absf(_warn)*0.5
	return goal

func _run(delta: float) -> void:
	_speed = move_toward(_speed,_top_speed,ACCEL*delta)
	_feel -= delta
	if _feel <= 0.0:
		_feel = FEEL_EVERY
		_feel_land()
	var goal := _aim()
	var d := _head.distance_to(goal)
	var far := smoothstep(HUG_NEAR.x,HUG_NEAR.y,Vector2(goal.x-_head.x,goal.z-_head.z).length())
	# Across the ground: at the goal, leaning into the low side while it's far.
	var flat := Vector3(goal.x-_head.x,0.0,goal.z-_head.z)
	var ang := atan2(flat.x,flat.z)
	var now := atan2(_dir.x,_dir.z)
	var bend := angle_difference(now,ang)+_gully*GULLY_TURN*far/maxf(_turn,0.01)
	bend += sin(_t*WEAVE.y)*WEAVE.x*far
	bend += _round_towers(now)
	now += clampf(bend,-_turn*delta,_turn*delta) if absf(bend) > _turn*delta else bend
	# Up and down: the land's hug far out, the goal's height near.
	var y_goal := lerpf(goal.y,_floor,far)
	y_goal = maxf(minf(y_goal,_ceiling()),_floor-HUG+HUG_LEAST)
	if Vector2(_head.x,_head.z).distance_to(_plateau) < KEEP_R: y_goal = maxf(y_goal,_strip_y+KEEP_FLOOR)
	var v_rate := clampf((y_goal-_head.y)/0.7,-_speed*CLIMB_SHARE,_speed*CLIMB_SHARE)
	var level := sqrt(maxf(1.0-v_rate*v_rate/(_speed*_speed),0.04))
	_dir = Vector3(sin(now)*level,v_rate/_speed,cos(now)*level).normalized()
	_head += _dir*_speed*delta
	if _here_y > -INF: _head.y = maxf(_head.y,_here_y+HUG_LEAST*0.5)
	if _try_hit(): return
	if _t > RUN_MAX or _head_s > LINE_MAX:
		last["gave_up"] = _clock
		_go_home(RECOIL_SPEED)
		return
	if _head.distance_to(goal) < LUNGE_FROM and _warn == 0.0 or (_warn != 0.0 and _head.distance_to(goal) < 90.0):
		state = LUNGE
		_t = 0.0
		_lunge_at = _head
		_dir = (_line_on()-_head).normalized()
		last["lunge"] = _clock
		last["lunge_d"] = _head.distance_to(_plane.position)

## Fast and straight: this is the strike.
func _lunge(delta: float) -> void:
	_speed = move_toward(_speed,LUNGE_SPEED,ACCEL*2.5*delta)
	var to := (_line_on()-_head).normalized()
	var ang := _dir.angle_to(to)
	if ang > 0.001: _dir = _dir.slerp(to,minf(LUNGE_TURN*delta/ang,1.0)).normalized()
	_head += _dir*_speed*delta
	if _try_hit(): return
	_feel -= delta
	if _feel <= 0.0:
		_feel = FEEL_EVERY*0.5
		var ground := float(_height.call(_head.x,_head.z))
		if _head.y < ground+6.0 or (_towers != null and _towers.inside(_head,0.0)):
			last["broke"] = _clock
			_go_home(RECOIL_SPEED)
			return
	if _head.distance_to(_lunge_at) > LUNGE_RUN or (_head-_plane.position).dot(_dir) > 90.0:
		last["missed"] = _clock
		last["missed_by"] = _closest
		_go_home(RECOIL_SPEED)

var _closest := INF

## It goes back up its line. When it's home the spiral is itself again.
func _go_home(speed: float) -> void:
	_recoil_speed = speed
	state = RECOIL
	_t = 0.0

func _recoil(delta: float) -> void:
	_recoil_speed += delta*260.0
	_head_s = maxf(_head_s-_recoil_speed*delta,0.0)
	if _head_s <= 40.0:
		_finish()

func _finish() -> void:
	state = IDLE
	_box.visible = false
	_rouse = 0.0
	_spirals.rouse(_spire,0.0)
	var high := _height_share(_plane.position.y)
	_wait = lerpf(GAP.x,GAP.y,high)*_rng.randf_range(GAP_SPREAD.x,GAP_SPREAD.y)
	if _game.get("sound") != null: _game.sound.strike = 0.0

## Reads the land under and ahead of the head.
func _feel_land() -> void:
	var f := Vector3(_dir.x,0.0,_dir.z).normalized()
	var here := float(_height.call(_head.x,_head.z))
	var ahead := _head+f*FEEL_AHEAD
	var centre := float(_height.call(ahead.x,ahead.z))
	var left := _head+f.rotated(Vector3.UP,FEEL_SPREAD)*FEEL_AHEAD
	var right := _head+f.rotated(Vector3.UP,-FEEL_SPREAD)*FEEL_AHEAD
	var hl := float(_height.call(left.x,left.z))
	var hr := float(_height.call(right.x,right.z))
	_here_y = here
	_floor = maxf(here,centre)+HUG
	# Positive: the left is higher, so lean right, which is -y round UP.
	_gully = clampf((hl-hr)/GULLY_SPAN,-1.0,1.0)*-1.0

## A bend (radians) round any tower close ahead.
func _round_towers(now: float) -> float:
	var out := 0.0
	for t: Dictionary in _tower_axes:
		var base: Vector3 = t.base
		var tip: Vector3 = t.tip
		var k := clampf((_head.y-base.y)/maxf(tip.y-base.y,1.0),0.0,1.0)
		var c := base.lerp(tip,k)
		var r := float(t.radius)*lerpf(1.5,0.26,k)+TOWER_ROOM
		var off := Vector2(_head.x-c.x,_head.z-c.z)
		var d := off.length()
		if d > r*1.6 or d < 1.0: continue
		var away := atan2(off.x,off.y)
		out += angle_difference(now,away)*(1.0-smoothstep(r,r*1.6,d))*2.0
	return out


# --- The line --------------------------------------------------------------------

## The head's trail: a point every STEP m; full, the older half thins.
func _drop() -> void:
	if state == GATHER or state == RECOIL: return
	if _line.is_empty(): return
	if _line[_line.size()-1].distance_to(_head) < STEP: return
	_line.append(_head)
	if _line.size() >= POINTS:
		var keep: Array[Vector3] = []
		var shares := _coil_shares.size()
		var half := (POINTS+shares)/2
		for i in _line.size():
			if i < shares or i >= half or (i-shares)%2 == 0: keep.append(_line[i])
		_line = keep

## The line to the shader, the body slithering; its groups, box and frame.
func _draw(delta: float) -> void:
	_wiggle = fmod(_wiggle+SLITHER.z*delta,TAU)
	_flow = fmod(_flow+FLOW*(1.0+_rouse*0.5)*delta,WRAP)
	_spin = fmod(_spin+SPIN_RATE*delta,TAU)
	var n := _line.size()+1
	var s := 0.0
	var prev := _line[0]
	var normal := Vector3.UP
	var lo := prev
	var hi := prev
	var way := Vector3.ZERO
	var end := _head
	var total := 0.0
	for i in n-1: total += _line[i].distance_to(_line[i+1] if i+1 < n-1 else end)
	if state != RECOIL: _head_s = total
	var shares := _coil_shares.size()
	var g := 0
	var g_lo := prev
	var g_hi := prev
	for i in n:
		var p := _line[i] if i < n-1 else end
		if i > 0: s += p.distance_to(_line[i-1])
		var next := (_line[i+1] if i+1 < n-1 else end) if i+1 < n else p
		var t := (next-p).normalized() if next != p else way
		if t != Vector3.ZERO:
			way = t
			normal = (normal-t*normal.dot(t)).normalized() if absf(t.dot(normal)) < 0.98 else t.cross(Vector3.RIGHT).normalized()
		if i >= shares and i < n-1:
			var off := t.cross(normal)*sin(s/SLITHER.y*TAU-_wiggle)*SLITHER.x*minf((total-s)/120.0,1.0)
			p += off
		_pts[i] = Vector4(p.x,p.y,p.z,s)
		_nrm[i] = normal
		lo = lo.min(p)
		hi = hi.max(p)
		g_lo = g_lo.min(p)
		g_hi = g_hi.max(p)
		# A group's sphere covers its GROUP segments, the point it shares included.
		if i > 0 and i%GROUP == 0 or i == n-1:
			var c := (g_lo+g_hi)*0.5
			_grp[g] = Vector4(c.x,c.y,c.z,c.distance_to(g_hi)+GIRTH.x*2.0)
			g += 1
			g_lo = p
			g_hi = p
	for i in range(g,4): _grp[i] = Vector4(0.0,0.0,0.0,0.0)
	var head_end := _head_s+(30.0 if state != RECOIL else 0.0)
	# The tail fills in as the head draws away; on the way home the head eats it.
	_tail_s = 0.0
	_mat.set_shader_parameter("pts",_pts)
	_mat.set_shader_parameter("normals",_nrm)
	_mat.set_shader_parameter("groups",_grp)
	_mat.set_shader_parameter("count",n)
	_mat.set_shader_parameter("head_s",head_end)
	_mat.set_shader_parameter("tail_s",_tail_s)
	_mat.set_shader_parameter("flow",_flow)
	_mat.set_shader_parameter("spin",-_spin)
	var grow := Vector3.ONE*BOX
	var low := lo-grow
	var high := hi+grow
	_box.global_position = (low+high)*0.5
	_box.scale = high-low
	_look_wait -= delta
	if _look_wait <= 0.0:
		_look_wait = LOOK_EVERY
		_spirals.lend_look(_mat)

## The roar as it comes, by nearness.
func _cue() -> void:
	if _game.get("sound") == null: return
	var d := _head.distance_to(_plane.position)
	var k := 0.0
	if state == GATHER or state == REAR: k = 0.25*_rouse
	elif state == RUN or state == LUNGE: k = lerpf(0.25,1.0,1.0-smoothstep(120.0,900.0,d))
	_game.sound.strike = k


# --- The shove -------------------------------------------------------------------

func _try_hit() -> bool:
	var p: Vector3 = _plane.position
	var d := p.distance_to(_head)
	var near := d
	# The neck: the last stretch of body.
	var i := _line.size()-1
	var along := 0.0
	var a := _head
	while i >= 0 and along < NECK:
		var b := _line[i]
		var ab := b-a
		var len2 := ab.length_squared()
		var u := clampf((p-a).dot(ab)/len2,0.0,1.0) if len2 > 0.0 else 0.0
		near = minf(near,p.distance_to(a+ab*u))
		along += sqrt(len2)
		a = b
		i -= 1
	_closest = minf(_closest,near)
	if near > HIT_R: return false
	if not _game.hand_landing.flying() or _kept(p): return false
	if _rock_between(_head,p): return false
	_hit()
	return true

## Whether rock stands between: a few reads of the land and the towers.
func _rock_between(a: Vector3, b: Vector3) -> bool:
	for k: float in [0.33,0.66]:
		var q := a.lerp(b,k)
		if float(_height.call(q.x,q.z)) > q.y: return true
		if _towers != null and _towers.inside(q,0.0): return true
	return false

## Lands: picks a way back and down that's clear and starts the push.
func _hit() -> void:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	hits += 1
	var out := Vector3(p.x-_middle.x,0.0,p.z-_middle.y).normalized()
	var flow := Vector3(_dir.x,0.0,_dir.z)
	var back := (flow.normalized()*0.6+out*0.7).normalized()
	var best := back
	var clear := -INF
	var down := DOWN
	for w: float in WAYS:
		var way := back.rotated(Vector3.UP,w)
		var push := (way*cos(DOWN)+Vector3.DOWN*sin(DOWN)).normalized()
		var least := INF
		for m: float in FEELS:
			var q := p+push*m+Vector3(v.x,0.0,v.z)*m/WIND*0.5
			var g := float(_height.call(q.x,q.z))
			least = minf(least,q.y-g)
			if _towers != null and _towers.inside(q,20.0): least = minf(least,0.0)
		if least > clear:
			clear = least
			best = way
		if least >= CLEAR: break
	# Nothing clear below: it pushes level, or up if it's tight.
	if clear < CLEAR*0.5: down = lerpf(-0.3,DOWN*0.5,clampf(clear/(CLEAR*0.5),0.0,1.0))
	_push_dir = (best*cos(down)+Vector3.DOWN*sin(down)).normalized()
	# The nose turned toward the push, wings tipped with it.
	var side := signf(Vector3(-cos(float(_plane.heading)),0.0,sin(float(_plane.heading))).dot(_push_dir))
	if side == 0.0: side = 1.0
	_push_turn = Vector3(-NOSE_DOWN*clampf(clear/CLEAR,0.2,1.0),NOSE_TURN*side,WINGS*side)
	_push_t = 0.0
	_guard_k = 1.0
	last["hit"] = _clock
	last["shove"] = {"at":p,"dir":_push_dir,"wind":WIND,"clear":clear,"way_ms":v.length()}
	if _game.get("sound") != null:
		_game.sound.shot("slam",1.0,0.85)
		_game.sound.shot("whoosh",0.7,0.7)
	if _game.get("rumble") != null: _game.rumble.knock(Vector3(0.7,1.0,0.7))
	_go_home(RECOIL_SPEED*0.6)

func _envelope(t: float) -> float:
	return t/RISE if t < RISE else exp(-(t-RISE)/FALL)

## The push's guard: lifts off the land coming at it.
func _shove_step(delta: float) -> void:
	if _push_t < 0.0: return
	_push_t += delta
	var env := _envelope(_push_t)
	if env < SPENT:
		_push_t = -1.0
		return
	var p: Vector3 = _plane.position
	var ahead := p+(_push_dir*WIND*env+Vector3(_plane.velocity.x,0.0,_plane.velocity.z)*0.5)*GUARD_AHEAD
	var clear := ahead.y-float(_height.call(ahead.x,ahead.z))
	_guard_k = lerpf(_guard_k,clampf(clear/GUARD,0.0,1.0),clampf(delta*12.0,0.0,1.0))
	if _kept(p) or not _game.hand_landing.flying(): _push_t = -1.0

## The air at `p`: what it wraps, and the push while it lasts. Asleep it is one
## branch.
func air_at(p: Vector3) -> Dictionary:
	var here: Dictionary = _under.call(p) if _under.is_valid() else {}
	if _push_t < 0.0: return here
	var env := _envelope(_push_t)
	var wind := _push_dir*WIND*env
	# Short of the land the down goes first, then the rest.
	if wind.y < 0.0: wind.y *= _guard_k
	wind *= lerpf(0.35,1.0,_guard_k)
	var out := here.duplicate()
	out["wind"] = (here.get("wind",Vector3.ZERO) as Vector3)+wind
	out["jet"] = maxf(float(here.get("jet",0.0)),minf(env*1.2,1.0))
	out["shove"] = _push_turn*env*lerpf(0.4,1.0,_guard_k)
	return out
