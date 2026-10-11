extends "res://scripts/breeze_ribbons.gd"
## The dragon's breath (docs/design/rim-dragon.md, round 8): the game's own
## breeze ribbons (scripts/breeze_ribbons.gd: its flow, its ground probe,
## its eddies and sweeps), born in the dragon's mouth in a burst through each
## blow, bigger and bolder so they read from the aqueduct isle 350 to 450 m
## off. scripts/dragon_gale.gd owns one and feeds it.
##
## Each ribbon pours across the held isle along its own way (the head's aim
## when it left the mouth), riding `ground_height`: the gale's probe of the
## isle's floor as it is posed now (tipped, sagged, trembling), the top of
## its turf and of anything standing on it (ruins, bells, trees), so it rises
## before a wall and never passes through turf or stone. Where the floor
## drops away behind a wall or a ruin it curls in an eddy (the lee). Some take
## a sweep: they dive to skim the turf and kick up off the far rim. Past the
## rim they sink out over the cloud sea and fade.
##
## Round 10: a ground layer. Over half the ribbons come down out of the
## mouth onto the turf and skim it all the way across (`ground` ribbons): a
## sweep from their birth, a short look ahead so they hug the floor rather
## than ride over what stands further on, a hard pull down to their skim,
## and a steer round a wall or ruin ahead toward the lower side (through a
## gap, round an end). They lift off at the far rim as the sweeps do. They
## kick up grass blades (`kicks`, for scripts/wind_kicked_blades.gd), and
## their air (`air_near`) is what knocks and pushes the pilot and buffets
## the plane. The rest still arc over as before.
##
## The zs_ribbon_* slots are the isle breeze's own (kit_life's ribbons). While
## the gale says so (`claim`: it blows near the eye), the ground ribbons'
## heads take them over for the frame (published after kit_life's), so the
## plants under them bow in their wake; otherwise it publishes none. The
## gale's zs_blow_* lanes bow and thrash the plants along the blast.

## Its ribbons' speed out of the mouth (m/s), the height they ride over the
## floor (m), their true width (m) and tail (s of path).
const SPEED := Vector2(19.0,26.0)
const RIDE_M := Vector2(1.4,3.6)
const WIDE := Vector2(1.5,3.0)
const TAIL_S := Vector2(1.2,1.8)
## How far either side of the head's aim a ribbon leaves the mouth (rad).
const FAN := 0.26
## Share of ribbons given a sweep that kicks up off the far rim, and the
## height they skim at (m: half the stroke's width or so, so it never
## shows through the turf).
const SWEEP_SHARE := 0.5
const SKIM := Vector2(1.1,1.7)
## A ribbon is never drawn nearer the floor than this (m).
const CLEAR := 0.9
## The lee: the floor falling this far (m) under a ribbon since the highest
## it rode over lately (that memory sinking at LEE_FORGET m/s) curls it in
## an eddy, at most once every LEE_GAP s. Eddies here are tight (s for a
## turn): at 20 m/s the breeze's own 3 s turn would be a loop 15 m across.
const LEE_DROP := 1.8
const LEE_FORGET := 3.0
const LEE_GAP := 0.8
const EDDY_SPAN := Vector2(0.75,1.15)
## Past the far rim: how fast (m/s) the floor it remembers sinks, so it
## spills down off the edge and out over the cloud sea.
const SPILL := Vector2(3.0,7.0)
## Seconds a ribbon lives at most.
const LIFE := 7.5
## Round 10, the ground layer: its share of the ribbons, their speed out of
## the mouth (m/s; a sweep runs SWEEP_FAST quicker low), the height they
## skim the floor at (m), their width (m: narrower, so the stroke facing the
## eye stays off the turf), how far ahead they read the floor (share of the
## breeze's LOOK_AHEAD: some 6 m), how hard they are pulled down to the skim
## (1/s), the seconds they take to come down out of the mouth, and the
## nearest a ground ribbon is drawn to the floor (m).
const GROUND_SHARE := 0.65
const GROUND_SPEED := Vector2(15.0,20.0)
const GROUND_SKIM := Vector2(1.0,1.6)
const GROUND_WIDE := Vector2(0.9,1.5)
const GROUND_LOOK := 0.12
const GROUND_PULL := 6.0
const GROUND_DESCEND := Vector2(0.25,0.45)
const GROUND_CLEAR := 0.7
## The steepest they come down out of the mouth (m/s down): about as fast
## as they go along, so the blast drives down into the turf some 8 m out.
const GROUND_DIVE := 24.0
## How far ahead (s of its travel) a ground ribbon reads the floor it is
## pulled to.
const GROUND_AHEAD := 0.12
## The steer round what stands: something standing more than AROUND_RISE
## (m) over the turf this far ahead (m; in the isle's own frame, so its tip
## doesn't count) turns its way toward the lower side (probed AROUND_SIDE
## rad either way) at AROUND_TURN rad/s, at most AROUND_MOST off its aim;
## clear, it eases back at AROUND_BACK rad/s.
const AROUND_AHEAD := 7.0
const AROUND_RISE := 2.0
const AROUND_SIDE := 0.55
const AROUND_TURN := 2.6
const AROUND_MOST := 0.8
const AROUND_BACK := 0.7
## A ground ribbon kicks up blades under it while it skims below this (m),
## at this share of the breeze's rate (they are many).
const KICK_SKIM := 2.4
const KICK_SHARE := 0.3

## Logged: lee eddies begun, ground ribbons born and their steers round.
var lees := 0
var grounds := 0
var steers := 0
## The gale sets this while it blows near the eye: the ground ribbons'
## heads take the zs_ribbon_* slots for the frame.
var claim := false
## The gale's `stands_at`: how high something stands over the turf at a
## point (m), for the steer round it.
var standing: Callable
var _claimed := false

func setup_breath(floor_probe: Callable) -> void:
	setup(floor_probe)
	capacity = 60
	# No lone ribbons between blasts: only the mouth makes them.
	_until_lone = INF
	_view.name = "DragonBreath"
	_view.extra_cull_margin = 400.0
	_material.shader = _far_shader()

## The breeze's stroke shader made for a breath seen from far: not hazed by
## the fog (the isle 400 m off is half lost in it, and so was the breath),
## and widened with distance (FAR_WIDEN), so it reads from the aqueduct isle
## as a bold gust while it stays its true width close to.
static var _far: Shader
const FAR_WIDEN := Vector2(90.0,3.0)
static func _far_shader() -> Shader:
	if _far != null: return _far
	var code := SHADER.code
	code = code.replace("depth_draw_never;","depth_draw_never, fog_disabled;")
	code = code.replace("float rb_true = min(UV2.x * rb_taper","float rb_true = min(UV2.x * clamp(rb_dist / %.1f, 1.0, %.1f) * rb_taper" % [FAR_WIDEN.x,FAR_WIDEN.y])
	_far = Shader.new()
	_far.code = code
	return _far

## One ribbon out of the mouth at `mouth` (world) along `aim` (flat, unit),
## `power` the blow's envelope (0..1).
func blast(mouth: Vector3, aim: Vector3, power: float) -> void:
	var dir := Vector2(aim.x,aim.z)
	if dir.length_squared() < 0.0001: return
	dir = dir.normalized().rotated(_rng.randf_range(-FAN,FAN))
	var side := Vector2(-dir.y,dir.x)
	var at := Vector2(mouth.x,mouth.z)+dir*1.5+side*_rng.randf_range(-1.5,1.5)
	var speed := _rng.randf_range(SPEED.x,SPEED.y)
	var low := _rng.randf() < GROUND_SHARE
	if low: speed = _rng.randf_range(GROUND_SPEED.x,GROUND_SPEED.y)
	var before := ribbons.size()
	_birth(at,dir,speed,0.9+0.35*clampf(power,0.0,1.0))
	if ribbons.size() == before: return
	var r: Dictionary = ribbons[ribbons.size()-1]
	var pos := Vector3(at.x,mouth.y+_rng.randf_range(-0.8,0.6),at.y)
	var floor_y: Variant = ground_height.call(at)
	if low:
		_ground_birth(r,pos,dir,speed,floor_y)
		return
	r.way = dir
	r.pos = pos
	r.path = PackedVector3Array([pos])
	r.vel = Vector3(dir.x,-0.08,dir.y)*speed
	r.ride = _rng.randf_range(RIDE_M.x,RIDE_M.y)
	r.ground = float(floor_y) if floor_y != null else mouth.y-3.0
	r.width = _rng.randf_range(WIDE.x,WIDE.y)
	r.tail = _rng.randf_range(TAIL_S.x,TAIL_S.y)
	r.landed = floor_y != null
	r.peak = float(floor_y) if floor_y != null else -INF
	r.lee_wait = 0.0
	r.spill = _rng.randf_range(SPILL.x,SPILL.y)
	r.sweep_wait = _rng.randf_range(0.15,0.4) if _rng.randf() < SWEEP_SHARE and sweep_gain > 0.0 else -1.0

## A ground ribbon (round 10): down out of the mouth onto the turf, a sweep
## from its birth that skims to the far rim and lifts off there.
func _ground_birth(r: Dictionary, pos: Vector3, dir: Vector2, speed: float, floor_y: Variant) -> void:
	var skim := _rng.randf_range(GROUND_SKIM.x,GROUND_SKIM.y)
	var descend := _rng.randf_range(GROUND_DESCEND.x,GROUND_DESCEND.y)
	var floor_at := float(floor_y) if floor_y != null else pos.y-4.0
	r.way = dir
	r.aim = dir
	r.pos = pos
	r.path = PackedVector3Array([pos])
	r.vel = Vector3(dir.x*speed,-clampf((pos.y-floor_at-skim)/maxf(descend,0.2),0.0,GROUND_DIVE),dir.y*speed)
	r.ride = skim
	r.ground = floor_at
	r.width = _rng.randf_range(GROUND_WIDE.x,GROUND_WIDE.y)
	r.tail = _rng.randf_range(TAIL_S.x,TAIL_S.y)
	r.landed = floor_y != null
	r.peak = floor_at
	r.lee_wait = 0.0
	r.spill = _rng.randf_range(SPILL.x,SPILL.y)
	r.look = GROUND_LOOK
	r.low = true
	r.sweep_wait = -1.0
	var sweep := {"t":0.0,"descend":descend,"skim":2.0,"lift":_rng.randf_range(1.4,2.2),"height":skim,"mine":true}
	r.sweep = sweep
	var to_rim := _to_rim(r)
	if to_rim > 0.0: sweep.skim = clampf(to_rim/(speed*SWEEP_FAST)-descend*0.3,0.4,4.0)
	_kicks_stale = true
	grounds += 1

## A ground ribbon is pulled down hard to its skim while it is low (the
## breeze's own pull would let it arc on for 20 m out of the mouth).
func flow(r: Dictionary, way: Vector2) -> Vector3:
	var v := super.flow(r,way)
	if not bool(r.get("low",false)): return v
	var sweep: Dictionary = r.sweep
	if sweep.is_empty() or _sweep_lift(sweep) > 0.0: return v
	# The floor under it and a few metres on (the breeze's look ahead takes
	# the highest over 25 m and would hold it high over a tipped isle).
	var pos: Vector3 = r.pos
	var p2 := Vector2(pos.x,pos.z)
	var on := Vector2((r.vel as Vector3).x,(r.vel as Vector3).z)*GROUND_AHEAD
	var floor_y := -INF
	for at: Vector2 in [p2,p2+on*0.5,p2+on]:
		var h: Variant = ground_height.call(at)
		if h != null: floor_y = maxf(floor_y,float(h))
	if floor_y == -INF: floor_y = float(r.ground)
	var want := clampf((floor_y+float(sweep.height)-pos.y)*GROUND_PULL,-GROUND_DIVE,14.0)
	v.y = lerpf(v.y,want,maxf(_sweep_low(sweep),0.6))
	return v

## Each ribbon on its own way (the breeze's single way is the wind's).
func _move(r: Dictionary, way: Vector2) -> void:
	if bool(r.get("low",false)): _steer_round(r)
	super._move(r,r.get("way",way))
	_tune(r)
	var pos: Vector3 = r.pos
	var under: Variant = ground_height.call(Vector2(pos.x,pos.z))
	r.lee_wait = maxf(float(r.get("lee_wait",0.0))-STEP,0.0)
	if under != null:
		r.landed = true
		var peak := maxf(float(r.get("peak",-INF))-STEP*LEE_FORGET,float(under))
		if peak-float(under) > LEE_DROP and float(r.lee_wait) <= 0.0 and not bool(r.dying) \
				and (r.eddy as Dictionary).is_empty() and (r.sweep as Dictionary).is_empty():
			_lee(r,peak-float(under))
			peak = float(under)
		r.peak = peak
	elif bool(r.get("landed",false)):
		# Off the far rim: it spills down and out over the cloud sea.
		r.ground = float(r.ground)-STEP*float(r.get("spill",5.0))
	if float(r.age) > LIFE: r.dying = true

## A ground ribbon turns round a wall or ruin ahead, toward the lower side
## (a gap, an end), and eases back to its aim once clear. Only while it
## skims; every third step (its probes are the gale's floor).
func _steer_round(r: Dictionary) -> void:
	var sweep: Dictionary = r.sweep
	if sweep.is_empty() or _sweep_lift(sweep) > 0.0: return
	r.steer_n = int(r.get("steer_n",0))+1
	if int(r.steer_n)%3 != 0: return
	var dt := STEP*3.0
	var pos: Vector3 = r.pos
	var p := Vector2(pos.x,pos.z)
	var way: Vector2 = r.way
	var aim: Vector2 = r.aim
	if not standing.is_valid() or ground_height.call(p) == null: return
	var off := aim.angle_to(way)
	if float(standing.call(p+way*AROUND_AHEAD)) > AROUND_RISE:
		var hl := float(standing.call(p+way.rotated(-AROUND_SIDE)*AROUND_AHEAD))
		var hr := float(standing.call(p+way.rotated(AROUND_SIDE)*AROUND_AHEAD))
		var turn := -1.0 if hl < hr else 1.0
		if absf(hl-hr) < 0.3: turn = -signf(off) if absf(off) > 0.05 else (1.0 if int(r.id)%2 == 0 else -1.0)
		off = clampf(off+turn*AROUND_TURN*dt,-AROUND_MOST,AROUND_MOST)
		if not bool(r.get("steered",false)):
			r.steered = true
			steers += 1
	else:
		off = move_toward(off,0.0,AROUND_BACK*dt)
	r.way = aim.rotated(off)

## The breeze's own eddies and sweeps, sized for the dragon's air: an eddy
## turns quicker (so the loop is metres across, not a field), a sweep skims
## higher (the stroke is wide) and is timed to lift off at the far rim.
func _tune(r: Dictionary) -> void:
	var eddy: Dictionary = r.eddy
	if not eddy.is_empty() and not eddy.has("mine"):
		eddy.mine = true
		eddy.span = _rng.randf_range(EDDY_SPAN.x,EDDY_SPAN.y)
	var sweep: Dictionary = r.sweep
	if not sweep.is_empty() and not sweep.has("mine"):
		sweep.mine = true
		sweep.height = _rng.randf_range(SKIM.x,SKIM.y)
		var to_rim := _to_rim(r)
		if to_rim > 0.0:
			sweep.skim = clampf(to_rim/(float(r.speed)*SWEEP_FAST)-float(sweep.descend)*0.6,0.3,3.0)

## A curl in the lee of whatever it just passed over: rolling down into the
## hollow behind a tall wall, a flat swirl behind a low one.
func _lee(r: Dictionary, drop: float) -> void:
	var way: Vector2 = r.get("way",Vector2.RIGHT)
	var along := Vector3(way.x,0.0,way.y)
	var upright := along.cross(Vector3.UP).normalized()
	var roll := drop > 3.0 and _rng.randf() < 0.6
	var axis := upright.slerp(Vector3.UP,_rng.randf_range(0.0,0.3)) if roll else upright.slerp(Vector3.UP,_rng.randf_range(0.6,1.0))
	r.eddy = {"t":0.0,"span":_rng.randf_range(EDDY_SPAN.x,EDDY_SPAN.y),"spin":-1.0 if roll else (1.0 if _rng.randf() < 0.5 else -1.0),
		"axis":axis.normalized(),"mine":true,"lee":true}
	r.lee_wait = LEE_GAP
	lees += 1

## Metres along its way from where it is to the far rim (where the floor
## ends after it has run over land), or -1 if it never does within 140 m.
func _to_rim(r: Dictionary) -> float:
	var pos: Vector3 = r.pos
	var way: Vector2 = r.get("way",Vector2.RIGHT)
	var p := Vector2(pos.x,pos.z)
	var seen := false
	var last := -1.0
	var d := 0.0
	while d <= 140.0:
		var h: Variant = ground_height.call(p+way*d)
		if h != null:
			seen = true
			last = d
		elif seen and d-last > 4.0:
			return last
		d += 2.0
	return last if seen else -1.0

## Never in the floor, sweeping or not, however the floor ahead rises or
## the isle tips under it.
func _keep_above_ground(r: Dictionary) -> void:
	var pos: Vector3 = r.pos
	var h: Variant = ground_height.call(Vector2(pos.x,pos.z))
	var clear := GROUND_CLEAR if bool(r.get("low",false)) else CLEAR
	if h == null or pos.y >= float(h)+clear: return
	pos.y = float(h)+clear
	r.pos = pos
	var path: PackedVector3Array = r.path
	if path.size() > 0:
		path[path.size()-1] = pos
		r.path = path
	var v: Vector3 = r.vel
	if v.y < 0.0: r.vel = Vector3(v.x,0.0,v.z)

## The heads are not published (the isle breeze owns those slots), except
## while the gale claims them: then the ground ribbons skimming the turf
## bow the plants in a wake behind them, as the breeze's heads do. Let go,
## the slots are cleared once (the isle breeze writes them again next frame).
func publish() -> void:
	heads.clear()
	if not claim:
		if _claimed:
			_claimed = false
			for i in range(CAPACITY): RenderingServer.global_shader_parameter_set("zs_ribbon_%d" % i,Vector4.ZERO)
		return
	_claimed = true
	var lift := Vector4.ZERO
	var lift_b := Vector4.ZERO
	var i := 0
	for r in ribbons:
		if i >= CAPACITY: break
		if not bool(r.get("low",false)) or bool(r.dying): continue
		var pos: Vector3 = r.pos
		var v := Vector2((r.vel as Vector3).x,(r.vel as Vector3).z)
		if v.length_squared() < 0.01: continue
		var strength := WAKE*wake_gain*float(r.weight)*smoothstep(0.0,0.3,float(r.age))*clampf(float(r.fade),0.0,1.0)
		var unit := v.normalized()
		var head := Vector4(pos.x,pos.z,unit.x*strength,unit.y*strength)
		var above := pos.y-float(r.ground)
		if i < 4: lift[i] = above
		else: lift_b[i-4] = above
		heads.append(head)
		RenderingServer.global_shader_parameter_set("zs_ribbon_%d" % i,head)
		i += 1
	for k in range(i,CAPACITY): RenderingServer.global_shader_parameter_set("zs_ribbon_%d" % k,Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("zs_ribbon_lift_a",lift)
	RenderingServer.global_shader_parameter_set("zs_ribbon_lift_b",lift_b)

## The breeze's kicks (sweeps near the turf), and the ground ribbons'
## while they skim under KICK_SKIM: the grass blades they tear up
## (scripts/wind_kicked_blades.gd) and the air that drags them along.
func kicks() -> Array[Dictionary]:
	var stale := _kicks_stale
	var list := super.kicks()
	if not stale or not enabled: return list
	var seen := {}
	for kick in list: seen[int(kick.id)] = true
	for r in ribbons:
		if not bool(r.get("low",false)) or seen.has(int(r.id)): continue
		var sweep: Dictionary = r.sweep
		if sweep.is_empty() or _sweep_lift(sweep) > 0.0: continue
		var pos: Vector3 = r.pos
		var ground: Variant = ground_height.call(Vector2(pos.x,pos.z))
		if ground == null: continue
		var strength := (1.0-smoothstep(1.4,KICK_SKIM,pos.y-float(ground)))*KICK_SHARE*clampf(float(r.fade),0.0,1.0)*_sweep_low(sweep)
		if strength <= 0.0: continue
		list.append({"at":Vector3(pos.x,float(ground),pos.z),"vel":r.vel,"lift":0.0,"strength":strength,"id":int(r.id)})
	return list

## The ground ribbons skimming the turf now: [head (world), velocity, the
## floor's height under it], for the gale's dust and leaves along them.
func skimming() -> Array:
	var out := []
	for r in ribbons:
		if not bool(r.get("low",false)) or bool(r.dying): continue
		var sweep: Dictionary = r.sweep
		if sweep.is_empty() or _sweep_lift(sweep) > 0.0 or _sweep_low(sweep) < 0.8: continue
		var pos: Vector3 = r.pos
		var ground: Variant = ground_height.call(Vector2(pos.x,pos.z))
		if ground == null or pos.y-float(ground) > KICK_SKIM: continue
		out.append([pos,r.vel,float(ground)])
	return out

## The air the ribbons are at `p` (m/s): each ribbon whose stroke passes
## within `reach` m of it to the side (past its half width; along its head
## and the last half second of its tail) and `rise` m up or down adds its
## velocity, by how near (the nearest of its points; strongest ribbon
## counts in full, the rest add half), and as it fades. The pilot's knock
## and push (reach 2 m) and the plane's buffet (reach 7 m) read it.
func air_near(p: Vector3, reach: float, rise: float) -> Vector3:
	var air := Vector3.ZERO
	var best := 0.0
	var best_v := Vector3.ZERO
	for r in ribbons:
		var path: PackedVector3Array = r.path
		var n := path.size()
		if n == 0: continue
		var half := float(r.width)*0.5
		var near := 0.0
		var k := n-1
		var last := maxi(n-16,0)
		while k >= last:
			var q: Vector3 = path[k]
			if absf(q.y-p.y) <= rise:
				var gap := Vector2(q.x-p.x,q.z-p.z).length()-half
				if gap < reach:
					var w := (1.0-smoothstep(0.0,reach,maxf(gap,0.0)))*(1.0-smoothstep(rise*0.5,rise,absf(q.y-p.y)))
					near = maxf(near,w)
			k -= 3
		if near <= 0.0: continue
		var v: Vector3 = (r.vel as Vector3)*near*clampf(float(r.fade),0.0,1.0)*smoothstep(0.0,0.2,float(r.age))
		air += v*0.5
		if v.length() > best:
			best = v.length()
			best_v = v
	return air+best_v*0.5

## How many ribbons are out (for the log).
func count() -> int:
	return ribbons.size()
