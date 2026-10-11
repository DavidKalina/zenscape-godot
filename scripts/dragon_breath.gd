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
## It publishes no heads: the zs_ribbon_* slots are the isle breeze's own
## (kit_life's ribbons would be overwritten). The gale's zs_blow_* lanes bow
## and thrash the plants along the blast.

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

## Logged: lee eddies begun.
var lees := 0

func setup_breath(floor_probe: Callable) -> void:
	setup(floor_probe)
	capacity = 36
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
	var before := ribbons.size()
	_birth(at,dir,speed,0.9+0.35*clampf(power,0.0,1.0))
	if ribbons.size() == before: return
	var r: Dictionary = ribbons[ribbons.size()-1]
	var pos := Vector3(at.x,mouth.y+_rng.randf_range(-0.8,0.6),at.y)
	var floor_y: Variant = ground_height.call(at)
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

## Each ribbon on its own way (the breeze's single way is the wind's).
func _move(r: Dictionary, way: Vector2) -> void:
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
	if h == null or pos.y >= float(h)+CLEAR: return
	pos.y = float(h)+CLEAR
	r.pos = pos
	var path: PackedVector3Array = r.path
	if path.size() > 0:
		path[path.size()-1] = pos
		r.path = path
	var v: Vector3 = r.vel
	if v.y < 0.0: r.vel = Vector3(v.x,0.0,v.z)

## The heads are not published (the isle breeze owns those slots).
func publish() -> void:
	heads.clear()

## How many ribbons are out (for the log).
func count() -> int:
	return ribbons.size()
