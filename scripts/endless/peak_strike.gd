extends Node3D
## The mountain's anger: while the plane climbs it, a spire picks the way down
## the mountain on the plane's side and strikes along it: one body of the spiral's
## cloud growing fast, head first, down a ridge or a gully at the plane, the rest
## of it laid along the way it came. Seen coming, dodged by leaving that way, and
## where it lands a shove back and down the mountain, no more.
##
## One strike at a time, in stages:
##   TELL    the spiral's tip draws in and a point pushes out of the spire, down
##           the way it has picked. That point is the warning.
##   RUN     it lengthens fast down its route, close over the land. On a stretch
##           shared with another route it can still take the fork nearer the plane.
##   LUNGE   near a plane still by the route (LUNGE_REACH, less if it's leaving),
##           with no rock between, it leaves the route and goes straight for the
##           plane's line. Hold that line and it lands. Rock breaks it.
##           Otherwise it runs on past and stops, OVERRUN further.
##   RECOIL  it draws back up the way it came.
## Routes: scripts/endless/peak_strike_routes.gd. The body is
## shaders/peak_strike.gdshader, a line of points in the ribbon's look. Nothing
## here runs while it sleeps but `_watch` and `_top`, some arithmetic a frame; the
## box is hidden.
##
## Once the plane reaches the top (`_topped`: over the crown's floor inside the
## ring of spires, TOP_R, TOP_Y) strikes stop, and any under way go home. They
## start again only when the plane is well back down or gone (RESET_Y, RESET_R).
##
## The shove reaches the plane through the air callable (`air_at`, wrapping the
## lift's): "wind" in m/s, "jet" for the camera's kick, "shove" for the nose. So
## the plane's own step eases it back and the stick stays live throughout.
##
## --peak-strike=0 none. --peak-strike=SECONDS forces a strike that long after
## launch and every SECONDS after, wherever the plane is, for proofs
## (--peak-strike-spire=i picks the spire, --peak-strike-route=n the route).
## `force(i)` does the same at once.

const SHADER := preload("res://shaders/peak_strike.gdshader")
const LaunchArgs := preload("res://scripts/launch_args.gd")
const Field := preload("res://scripts/endless/land_field.gd")
const Routes := preload("res://scripts/endless/peak_strike_routes.gd")

enum { IDLE, TELL, RUN, LUNGE, RECOIL }

## The shader's POINTS and GROUP.
const POINTS := 65
const GROUP := 8
const GROUPS := 8
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
## A spire within this of the plane doesn't strike (m): it would come on top of it.
const NEAR_SPIRE := 420.0
## The plateau's keep: inside this reach of its centre and under KEEP_OVER over
## the strip no strike starts, a live one goes home and no shove lands.
const KEEP_R := 420.0
const KEEP_OVER := 170.0
## The top of the climb: over TOP_Y (over the sea, a little under the strip) inside
## TOP_R of the plateau's centre, which takes in the rim and stops inside the ring
## of spires; or over the highest tip anywhere. Strikes stop there, and start
## again only under RESET_Y over the sea or past RESET_R of the crown's middle.
const TOP_R := 370.0
const TOP_Y := 860.0
const RESET_Y := 640.0
const RESET_R := 1300.0

# --- The strike ------------------------------------------------------------------

## The tell (s), at the shoulders and at the spires, and how far the point pushes
## out in it (m).
const TELL_TIME := Vector2(1.2,1.0)
const TELL_OUT := 150.0
## A route is taken if it passes within PICK_R (m) of where the plane will be in
## PICK_AHEAD s, and it starts at least PICK_FROM m of it down from the spire.
const PICK_R := 480.0
const PICK_AHEAD := 2.5
const PICK_FROM := 500.0
## Against repeating a route (m of the score), and the score's random spread.
const PICK_AGAIN := 220.0
const PICK_SPREAD := 60.0
## Down the route (m/s), at the shoulders and at the spires, and its spin-up (m/s²).
const SPEED := Vector2(270.0,330.0)
const ACCEL := 1100.0
## How often it reads where the plane is (s). A fork is taken if it comes nearer
## the plane by SWITCH_BY (m).
const READ_EVERY := 0.1
const SWITCH_BY := 70.0
## It aims down the route for the plane's place: of the seconds to arrival, at
## most LEAD_MAX s, LEAD_SHARE of the way.
const LEAD_MAX := 2.0
const LEAD_SHARE := 0.75
## The lunge: from this far (m), for a plane within LUNGE_REACH of the route, at
## this speed (m/s), steering this much (rad/s).
const LUNGE_FROM := 340.0
const LUNGE_REACH := 120.0
## A plane leaving the route, LEAVE_BY m further off it in LEAVE_T s on its line,
## is only reached within this share of LUNGE_REACH: that's the dodge.
const LEAVE_T := 1.2
const LEAVE_BY := 20.0
const LEAVE_REACH := 0.4
const LUNGE_SPEED := 190.0
const LUNGE_TURN := 0.03
## Past this far from where the lunge began it's spent (m).
const LUNGE_RUN := 520.0
## Runs on this far past the plane's place (m), then stops and holds HOLD s.
const OVERRUN := 180.0
const HOLD := 0.3
## Under this share of the way up, strikes are warnings: no lunge.
const WARN_UNDER := 0.3
## Gives up after this long running (s).
const RUN_MAX := 9.0
## Back up the line at this speed (m/s), gaining RECOIL_RISE m/s², and at
## HOME_SPEED when the land took the plane.
const RECOIL_SPEED := 460.0
const RECOIL_RISE := 400.0
const HOME_SPEED := 900.0

# --- The body --------------------------------------------------------------------

## The body's girth (m, radius): head, body, tail.
const GIRTH := Vector3(66.0,30.0,10.0)
## Where on the ribbon the body comes off: the shares it may take, the nearest
## the route's start. Under the tip's draw (PeakSpirals.ROUSE_TIP).
const ROOT_SHARE := Vector2(0.58,0.78)
## How much of the head's speed the cloud runs along the body with.
const FLOW_SHARE := 0.55
## Whole tiles of the shader's ALONG, and at rest.
const WRAP := 6450.0
const FLOW_REST := 40.0
## The box's reach past the line (m).
const BOX := 170.0
const LOOK_EVERY := 0.5
## Points in the bend off the route into a lunge.
const BEND := 5

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
## What the last strike did: for the proofs. {spire, route, name, warned (s, TELL
## began), ran (s, RUN began), from (m, head to plane at RUN), forks ([names taken]),
## hit (s), lunge, broke, missed, passed, gave_up, shove: {at, dir, wind, down}}.
var last := {}
var strikes := 0
var hits := 0
var anger := 0.0
## The baked routes.
var routes: Array = []

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
var _box: MeshInstance3D
var _mat: ShaderMaterial
var _clock := 0.0
var _force_every := 0.0
var _force_wait := INF
var _force_spire := -1
var _force_route := -1

# Watching.
var _climb := 0.0
var _wait := FIRST_WAIT
var _last_route := -1
## The plane has reached the top and not yet gone back down.
var _topped := false

# The live strike.
var _spire := -1
var _route: Dictionary = {}
var _route_i := -1
var _root_share := 0.7
var _t := 0.0
var _fury := 0.0
var _warn := false
var _rouse := 0.0
var _head := Vector3.ZERO
var _dir := Vector3.DOWN
var _speed := 0.0
var _top_speed := 0.0
var _read := 0.0
var _join := Vector2(INF,INF)
var _held := -1.0
var _lunge_at := Vector3.ZERO
var _head_s := 0.0
var _off_from := 0.0
var _off_way := Vector3.ZERO
var _off_end := Vector3.ZERO
var _off_k := 0.0
var _line: Array[Vector3] = []
var _flow := 0.0
var _look_wait := 0.0
var _recoil_speed := RECOIL_SPEED
var _pts := PackedVector4Array()
var _nrm := PackedVector3Array()
var _grp := PackedVector4Array()
var _closest := INF

# The shove.
var _push_t := -1.0
var _push_dir := Vector3.ZERO
var _push_turn := Vector3.ZERO
var _guard_k := 1.0

var _primed := 0


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
	var axes: Array = towers.axes() if towers != null else []
	var mid := Vector2.ZERO
	for t: Dictionary in axes:
		var tip: Vector3 = t.tip
		_tips.append(tip)
		mid += Vector2(tip.x,tip.z)
	_middle = mid/maxf(float(_tips.size()),1.0)
	routes = Routes.bake(peak,height,towers,POINTS-BEND-4)
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
	_grp.resize(GROUPS)
	for a in LaunchArgs.user_args():
		if a.begins_with("--peak-strike=") and a.get_slice("=",1).is_valid_float() and a.get_slice("=",1) != "1":
			_force_every = a.get_slice("=",1).to_float()
			_force_wait = _force_every
		if a.begins_with("--peak-strike-spire="): _force_spire = a.get_slice("=",1).to_int()
		if a.begins_with("--peak-strike-route="): _force_route = a.get_slice("=",1).to_int()
	# Drawn once out of sight with nothing to draw (`count` 0 discards), so its
	# shader is built during the load and not in the first strike. See `step`.
	_box.visible = true
	_box.position = Vector3(_tips[0].x,_tips[0].y+4000.0,_tips[0].z) if not _tips.is_empty() else Vector3.ZERO
	_primed = 8


## Strike now, from spire `i` (< 0: any), wherever the plane is. --peak-strike-route
## or `route` names the route; else the one nearest the plane.
func force(i := -1, route := -1) -> bool:
	if state != IDLE or routes.is_empty(): return false
	if route < 0: route = _force_route
	if route < 0 or route >= routes.size(): route = _pick(true,i)
	if route < 0: route = 0
	_begin(route)
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
	_top()
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
	if state != RECOIL and _called_off():
		last["called_off"] = _clock
		_go_home(HOME_SPEED)
	match state:
		TELL: _tell(delta)
		RUN: _run(delta)
		LUNGE: _lunge(delta)
		RECOIL: _recoil(delta)
	if state == IDLE: return
	_rouse = move_toward(_rouse,0.0 if state == RECOIL else 1.0,delta*(0.6 if state == RECOIL else 2.5))
	_spirals.rouse(_spire,_rouse)
	_lay()
	_draw(delta)
	_cue()


# --- Watching --------------------------------------------------------------------

func _height_share(y: float) -> float:
	return clampf((y-Field.SEA_Y-SHOULDER)/(SPIRE_FOOT-SHOULDER),0.0,1.0)

func _kept(p: Vector3) -> bool:
	return Vector2(p.x,p.z).distance_to(_plateau) < KEEP_R and p.y < _strip_y+KEEP_OVER

## Whether the plane has got to the top, and whether it has since gone back down.
func _top() -> void:
	var p: Vector3 = _plane.position
	var over := p.y-Field.SEA_Y
	if _topped:
		if over < RESET_Y or Vector2(p.x,p.z).distance_to(_middle) > RESET_R: _topped = false
		return
	if over > TOP_Y and Vector2(p.x,p.z).distance_to(_plateau) < TOP_R or p.y > _ceiling():
		_topped = true

## The highest tip, world.
func _ceiling() -> float:
	var top := -INF
	for t in _tips: top = maxf(top,t.y)
	return top

## The plane's left, landed, come in to land or got to the top.
func _called_off() -> bool:
	if _force_every > 0.0 or bool(last.get("forced",false)): return false
	if not _game.hand_landing.flying(): return true
	var p: Vector3 = _plane.position
	if _topped or _kept(p): return true
	return Vector2(p.x,p.z).distance_to(_middle) > WATCH.y+300.0

func _watch(delta: float) -> void:
	_climb = lerpf(_climb,float(_plane.velocity.y),1.0-exp(-delta/CLIMB_EASE))
	var p: Vector3 = _plane.position
	var flat := Vector2(p.x,p.z).distance_to(_middle)
	var high := _height_share(p.y)
	var on := smoothstep(CLIMB.x,CLIMB.y,_climb)*(1.0-smoothstep(WATCH.x,WATCH.y,flat))
	if p.y-Field.SEA_Y < SHOULDER: on = 0.0
	anger = lerpf(anger,on*(0.4+0.6*high),1.0-exp(-delta/3.0))
	if on < 0.5 or _topped or _kept(p) or not _game.hand_landing.flying(): return
	_wait -= delta
	if _wait > 0.0: return
	var i := _pick(false)
	if i < 0:
		_wait = 1.0
		return
	_begin(i)

## Route `r`'s nearest point to `q`: Vector2(metres along, metres off).
func _nearest(r: Dictionary, q: Vector3) -> Vector2:
	var pts: PackedVector3Array = r.pts
	var ds: PackedFloat32Array = r.s
	var best := 0
	var least := INF
	var i := 0
	while i < pts.size():
		var d := pts[i].distance_squared_to(q)
		if d < least:
			least = d
			best = i
		i += 3
	return Vector2(ds[best],sqrt(least))

## The route on the plane's side: the one passing nearest where it will be, not
## the last one if another's about as near. -1 if none is (`any`: reach waived).
## `only`: from that spire.
func _pick(any: bool, only := -1) -> int:
	var p: Vector3 = _plane.position
	var q: Vector3 = p+(_plane.velocity as Vector3)*PICK_AHEAD
	var best := -1
	var low := INF
	for i in routes.size():
		var r: Dictionary = routes[i]
		var spire := int(r.spire)
		if spire >= _spirals.count() or (only >= 0 and spire != only): continue
		if not any and _tips[spire].distance_to(p) < NEAR_SPIRE: continue
		var n := _nearest(r,q)
		if not any and (n.y > PICK_R or n.x < PICK_FROM): continue
		var score := n.y+_rng.randf_range(0.0,PICK_SPREAD)
		if i == _last_route: score += PICK_AGAIN
		if score < low:
			low = score
			best = i
	return best

func _begin(i: int) -> void:
	_route_i = i
	_route = routes[i]
	_spire = int(_route.spire)
	_last_route = i
	strikes += 1
	_t = 0.0
	var high := _height_share(_plane.position.y)
	_fury = high
	_warn = high < WARN_UNDER and _force_every <= 0.0
	state = TELL
	last = {"spire":_spire,"route":i,"name":_route.name,"warned":_clock,"warn":_warn,"fury":high,"forced":_force_every > 0.0,"forks":[]}
	_top_speed = lerpf(SPEED.x,SPEED.y,_fury)
	_head_s = 0.0
	_off_k = 0.0
	_held = -1.0
	_flow = 0.0
	_speed = 0.0
	_read = 0.0
	_closest = INF
	# The body comes off the ribbon where it passes nearest the route's start.
	var first: Vector3 = (_route.pts as PackedVector3Array)[0]
	var least := INF
	for q in 12:
		var share := lerpf(ROOT_SHARE.x,ROOT_SHARE.y,float(q)/11.0)
		var d: float = _spirals.ribbon_at(_spire,share).distance_to(first)
		if d < least:
			least = d
			_root_share = share
	_head = _spirals.ribbon_at(_spire,_root_share)
	_join = _nearest(_route,_plane.position)
	_mat.set_shader_parameter("seed",float(strikes)*1.3+float(_spire))
	_mat.set_shader_parameter("girth",GIRTH)
	_spirals.lend_look(_mat)
	_look_wait = LOOK_EVERY
	_box.visible = true
	_lay()
	if _game.get("sound") != null: _game.sound.shot("whoosh",0.5,0.5,_tips[_spire],&"SFX",true)


# --- The stages ------------------------------------------------------------------

## Route `r` at `s` metres along.
func _at(r: Dictionary, s: float) -> Vector3:
	var pts: PackedVector3Array = r.pts
	var ds: PackedFloat32Array = r.s
	var i := clampi(ds.bsearch(s,true)-1,0,ds.size()-2)
	return pts[i].lerp(pts[i+1],clampf((s-ds[i])/maxf(ds[i+1]-ds[i],0.01),0.0,1.0))

## The point pushes out of the spire, down the way it has picked, and holds.
func _tell(_delta: float) -> void:
	var span := lerpf(TELL_TIME.x,TELL_TIME.y,_fury)
	var k := clampf(_t/(span*0.7),0.0,1.0)
	_head_s = TELL_OUT*(1.0-(1.0-k)*(1.0-k)*(1.0-k))
	_head = _at(_route,_head_s)
	_read_plane()
	if _t >= span:
		state = RUN
		_t = 0.0
		_speed = 30.0
		last["ran"] = _clock
		last["from"] = _head.distance_to(_plane.position)
		last["run_from"] = _head
		if _game.get("sound") != null: _game.sound.shot("whoosh",0.7,0.8,_head,&"SFX",true)

## Where the plane will be, on this route, and a better fork if the way's still shared.
func _read_plane() -> void:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	var eta := _head.distance_to(p)/maxf(_top_speed,1.0)
	var q := p+v*minf(eta,LEAD_MAX)*LEAD_SHARE
	_join = _nearest(_route,q)
	var forks: Dictionary = _route.forks
	for j: int in forks:
		if _head_s >= float(forks[j])-20.0: continue
		var n := _nearest(routes[j],q)
		if n.y < _join.y-SWITCH_BY:
			_route_i = j
			_route = routes[j]
			_join = n
			_last_route = j
			last["route"] = j
			last["name"] = _route.name
			(last.forks as Array).append(_route.name)
			break

func _run(delta: float) -> void:
	_read -= delta
	var fresh := _read <= 0.0
	if fresh:
		_read = READ_EVERY
		_read_plane()
	var length := float(_route.length)
	var stop := minf(_join.x+OVERRUN,length)
	# Slowing into its reach's end, so it doesn't stop dead.
	var left := stop-_head_s
	_speed = move_toward(_speed,minf(_top_speed,maxf(left*5.0,20.0)),ACCEL*delta)
	var was := _head
	_head_s = minf(_head_s+_speed*delta,maxf(stop,_head_s))
	_head = _at(_route,_head_s)
	if _head.distance_squared_to(was) > 0.01: _dir = (_head-was).normalized()
	if _try_hit(): return
	var p: Vector3 = _plane.position
	if fresh and _can_lunge(p):
		state = LUNGE
		_t = 0.0
		_lunge_at = _head
		_off_from = _head_s
		_off_way = _dir
		_off_end = _head
		_off_k = 1.0
		_dir = (_line_on()-_head).normalized()
		last["lunge"] = _clock
		last["lunge_d"] = _head.distance_to(p)
		return
	if left < 6.0 or _t > RUN_MAX:
		if _held < 0.0: _held = 0.0
		_held += delta
		if _held >= HOLD:
			last["passed"] = _clock
			last["passed_by"] = _closest
			_go_home(RECOIL_SPEED)

## Close enough, the plane still by the route, no rock between, and no warning.
func _can_lunge(p: Vector3) -> bool:
	if _warn: return false
	if _head.distance_to(p) > LUNGE_FROM: return false
	var off := _nearest(_route,p).y
	var leaving := _nearest(_route,p+(_plane.velocity as Vector3)*LEAVE_T).y > off+LEAVE_BY
	if off > LUNGE_REACH*(LEAVE_REACH if leaving else 1.0): return false
	return not _rock_between(_head,p)

## The lunge's mark: where the plane will be if it holds its line. Hold it and
## this lands; leave it and it doesn't.
func _line_on() -> Vector3:
	var p: Vector3 = _plane.position
	var v: Vector3 = _plane.velocity
	return p+v*_head.distance_to(p)/LUNGE_SPEED

## Fast and straight: this is the strike.
func _lunge(delta: float) -> void:
	_speed = move_toward(_speed,LUNGE_SPEED,ACCEL*0.5*delta)
	var to := (_line_on()-_head).normalized()
	var ang := _dir.angle_to(to)
	if ang > 0.001: _dir = _dir.slerp(to,minf(LUNGE_TURN*delta/ang,1.0)).normalized()
	_head += _dir*_speed*delta
	_off_end = _head
	if _try_hit(): return
	_read -= delta
	if _read <= 0.0:
		_read = READ_EVERY*0.5
		var ground := float(_height.call(_head.x,_head.z))
		if _head.y < ground+6.0 or (_towers != null and _towers.inside(_head,0.0)):
			last["broke"] = _clock
			_go_home(RECOIL_SPEED)
			return
	if _head.distance_to(_lunge_at) > LUNGE_RUN or (_head-_plane.position).dot(_dir) > 90.0:
		last["missed"] = _clock
		last["missed_by"] = _closest
		_go_home(RECOIL_SPEED)

## It draws back up its line. When it's home the spiral is itself again.
func _go_home(speed: float) -> void:
	_recoil_speed = speed
	state = RECOIL
	_t = 0.0

func _recoil(delta: float) -> void:
	_recoil_speed += delta*RECOIL_RISE
	var go := _recoil_speed*delta
	if _off_k > 0.0:
		_off_k = maxf(_off_k-go/maxf(_lunge_at.distance_to(_off_end),1.0),0.0)
		return
	_head_s = maxf(_head_s-go,0.0)
	if _head_s <= 20.0: _finish()

func _finish() -> void:
	state = IDLE
	_box.visible = false
	_rouse = 0.0
	_spirals.rouse(_spire,0.0)
	var high := _height_share(_plane.position.y)
	_wait = lerpf(GAP.x,GAP.y,high)*_rng.randf_range(GAP_SPREAD.x,GAP_SPREAD.y)
	if _game.get("sound") != null: _game.sound.strike = 0.0


# --- The line --------------------------------------------------------------------

## The body: off the ribbon, along the route as far as the head has grown, and
## the bend off it into a lunge.
func _lay() -> void:
	_line.clear()
	_line.append(_spirals.ribbon_at(_spire,_root_share))
	var pts: PackedVector3Array = _route.pts
	var ds: PackedFloat32Array = _route.s
	var k: int = _route.k
	var i := 0
	while i < pts.size() and ds[i] < _head_s-k*Routes.STRIDE*0.5:
		_line.append(pts[i])
		i += k
	var end := _at(_route,_head_s)
	_line.append(end)
	if _off_k <= 0.0:
		if state == RECOIL: _head = end
		return
	var l := _lunge_at.distance_to(_off_end)
	var c := end+_off_way*l*0.45
	var tip := end
	for b in BEND:
		var u := float(b+1)/float(BEND)*_off_k
		tip = end.bezier_interpolate(c,c.lerp(_off_end,0.5),_off_end,u)
		_line.append(tip)
	if state == RECOIL: _head = tip

## The line to the shader; its groups, box and frame.
func _draw(delta: float) -> void:
	var n := mini(_line.size(),POINTS)
	var way := 1.0 if state != RECOIL else -1.0
	_flow = fposmod(_flow+(FLOW_REST+_speed*FLOW_SHARE)*way*delta,WRAP)
	var s := 0.0
	var prev := _line[0]
	var normal := Vector3.UP
	var lo := prev
	var hi := prev
	var along := Vector3.DOWN
	var g := 0
	var g_lo := prev
	var g_hi := prev
	for i in n:
		var p := _line[i]
		if i > 0: s += p.distance_to(_line[i-1])
		if i+1 < n and _line[i+1] != p: along = (_line[i+1]-p).normalized()
		# Up, as near as the line lets it, so the body's grain keeps its place.
		normal = normal*0.5+Vector3.UP
		normal = (normal-along*normal.dot(along))
		normal = normal.normalized() if normal.length_squared() > 0.001 else along.cross(Vector3.RIGHT).normalized()
		_pts[i] = Vector4(p.x,p.y,p.z,s)
		_nrm[i] = normal
		lo = lo.min(p)
		hi = hi.max(p)
		g_lo = g_lo.min(p)
		g_hi = g_hi.max(p)
		# A group's sphere covers its GROUP segments, the point it shares included.
		if i > 0 and i%GROUP == 0 or i == n-1:
			var c := (g_lo+g_hi)*0.5
			_grp[g] = Vector4(c.x,c.y,c.z,c.distance_to(g_hi)+GIRTH.x*2.5)
			g += 1
			g_lo = p
			g_hi = p
	for i in range(g,GROUPS): _grp[i] = Vector4(0.0,0.0,0.0,0.0)
	_mat.set_shader_parameter("pts",_pts)
	_mat.set_shader_parameter("normals",_nrm)
	_mat.set_shader_parameter("groups",_grp)
	_mat.set_shader_parameter("count",n)
	_mat.set_shader_parameter("head_s",s)
	_mat.set_shader_parameter("flow",_flow)
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
	if state == TELL: k = 0.25*_rouse
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
