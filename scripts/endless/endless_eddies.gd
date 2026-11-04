extends Node3D
## The endless gusts as the aqueduct isle has them (docs/design/endless-flight/
## endless-eddies-handoff.md): the isle's breeze ribbons (scripts/breeze_ribbons.gd,
## whole: its flow, eddies, sweeps, strokes and shader) ride the air over the
## land round the eye, a few at a time along a gust front, curling through
## eddies and now and then diving to skim the grass and kick up off it. The
## isle's grass bows under each ribbon head through zs_ribbon_0..7; the
## endless grass reads one map (zs_react_map), so each low head also rolls a
## band through it: a train of TRAIL stamps along the head's last seconds of
## path, moved every frame (GrassReact `set_flows`), the push rising as the
## head comes, then easing back with a little swing past rest behind it. (It
## once dropped a fixed stamp every 2 m, each popping in over 0.1 s: the
## grass moved in steps, three or four a second.) The ribbons still publish
## zs_ribbon_N, which the near tufts' own sway reads too.
##
## With a wind field (`wind`, scripts/endless/wind_field.gd) they follow the
## local wind: fronts come as often as RATE says for the wind ahead of the
## eye (none in a calm hollow or a still hour, about twice as often on a
## windy ridge as on open land on a breezy afternoon), more of them and
## quicker where it blows, along the wind's heading there; the lone ribbons
## between fronts too. Without one (other worlds, --wind=off) as before.
##
## Flags: --gusts=eddies|rings|both (default eddies), --eddy-reach=M,
## --eddy-push=X, --eddy-scale=X (the strokes' width, 1 = the isle's),
## --eddy-every=S (seconds between fronts at rate 1), --eddy-radius=M.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Ribbons = preload("res://scripts/breeze_ribbons.gd")

## Seconds between fronts (+-JITTER), and the plate the ribbons live on.
var every := 6.0
const JITTER := 3.0
var radius := 150.0
## How far ahead of the eye (along its facing) the plate sits, as a share of radius.
const AHEAD := 0.55
## Where a front comes in, metres ahead of the eye.
const AHEAD_NEAR := 40.0
const AHEAD_FAR := 130.0
## A band's reach (m) and push.
var reach := 7.0
var push := 3.0
## The band behind a head: a stamp every TRAIL_GAP s of its path back to
## TRAIL_SPAN s; its push there follows `band` (the head's push x that).
const TRAIL_GAP := 0.3
const TRAIL_SPAN := 2.1
## How fast a head's push follows where it is (s).
const K_EASE := 0.15
## Each band stamp's share of the push (they overlap about 3 deep).
const TRAIL_GAIN := 0.2
## How fronts come with the local wind (wind_field.gd's scale): none under
## RATE.x, rate 1 by RATE.y, RATE.w by RATE.z (a windy ridge).
const RATE := Vector4(0.12, 0.55, 1.2, 1.9)
## How many a front brings and how fast they go, light wind to strong.
const SPEED := Vector2(4.5, 8.0)
## The wind field (EndlessLook.wind), or null: then fronts every `every` s.
var wind: RefCounted
## The strokes' width (x the isle's): the isle's thin ones.
var stroke := 1.0
## Their tails (x the isle's).
var tail_scale := 1.0

var ribbons: Node3D
var react: Node
var field_height: Callable
var _rng := RandomNumberGenerator.new()
var _until := 1.0
## Each head's recent path: id -> {rows: PackedFloat32Array of (t, x, z,
## push) rows, v: its last way (xz m/s), pushed: when it last pushed}.
var _trails := {}
var _clock := 0.0
## For drivers: the band stamps this frame, the rate now, fronts so far.
var stats := {"flows": 0, "rate": 1.0, "fronts": 0, "skipped": 0}

static func mode() -> String:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--gusts="): return a.get_slice("=", 1)
	return "eddies"

func setup(land_seed: int, height: Callable, react_node: Node) -> void:
	name = "EndlessEddies"
	_rng.seed = land_seed * 4001 + 29
	field_height = height
	react = react_node
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--eddy-reach="): reach = float(a.get_slice("=", 1))
		elif a.begins_with("--eddy-push="): push = float(a.get_slice("=", 1))
		elif a.begins_with("--eddy-scale="): stroke = float(a.get_slice("=", 1))
		elif a.begins_with("--eddy-tail="): tail_scale = float(a.get_slice("=", 1))
		elif a.begins_with("--eddy-every="): every = maxf(float(a.get_slice("=", 1)), 0.5)
		elif a.begins_with("--eddy-radius="): radius = float(a.get_slice("=", 1))
	ribbons = Ribbons.new()
	add_child(ribbons)
	ribbons.setup(Callable(self, "_ground"))
	ribbons.capacity = 14
	ribbons.width_scale = stroke
	ribbons.set_bounds(Vector2.ZERO, radius)

## The ground a ribbon rides over; the sea's level over water.
func _ground(p: Vector2) -> Variant:
	return maxf(float(field_height.call(p.x, p.y)), -40.0)

## The fronts' rate (x the default) for wind strength `w`.
static func rate_of(w: float) -> float:
	return smoothstep(RATE.x, RATE.y, w)*lerpf(1.0, RATE.w, smoothstep(RATE.y, RATE.z, w))

## The local wind at (x, z) and how far the field reaches there (0 past it).
func _wind_here(p: Vector2) -> Vector2:
	if wind == null: return Vector2(1.0, 0.0)
	return Vector2(wind.wind_at(p.x, p.y), wind.reach(p.x, p.y))

## The rate at `p`: the field's where it reaches, 1 past it.
func _rate_at(p: Vector2) -> float:
	var w := _wind_here(p)
	return lerpf(1.0, rate_of(w.x), w.y) if wind != null else 1.0

## A band's push at `back` s behind its head: rising over the head's
## first metres, easing off, a little swing past rest at the tail.
static func band(back: float) -> float:
	return exp(-back*1.1)*cos(back*1.25)

func step(delta: float, eye: Vector3, facing: Vector2, way_now: Vector2, strength: float, land: Callable) -> void:
	_clock += delta
	if facing.length() < 0.05: facing = Vector2(0, -1)
	facing = facing.normalized()
	var mid := Vector2(eye.x, eye.z) + facing * radius * AHEAD
	ribbons.set_bounds(mid, radius)
	var ahead := Vector2(eye.x, eye.z) + facing * (AHEAD_NEAR + AHEAD_FAR) * 0.5
	var rate := _rate_at(ahead)
	stats.rate = rate
	ribbons.lone_gain = rate
	if wind != null and wind.has_method("direction_at"):
		var d: Vector2 = wind.direction_at(ahead.x, ahead.y)
		way_now = way_now.lerp(d, _wind_here(ahead).y).normalized() if d.length() > 0.01 else way_now
	_until -= delta * rate
	if _until <= 0.0:
		_until = every + _rng.randf_range(-JITTER, JITTER)
		# A front comes into the view: a line of ribbons across the wind,
		# a little upwind of a spot ahead of the eye, one of them given a sweep.
		var way := way_now.normalized()
		var side := Vector2(-way.y, way.x)
		var spot := Vector2(eye.x, eye.z) + facing * _rng.randf_range(AHEAD_NEAR, AHEAD_FAR) + side * _rng.randf_range(-45.0, 45.0)
		# The spot's own wind: a calm hollow ahead of a windy ridge stays still.
		var w := _wind_here(spot)
		var gust := lerpf(0.6, clampf(w.x, 0.0, 1.5), w.y) if wind != null else 0.6
		var here := lerpf(1.0, rate_of(w.x), w.y) if wind != null else 1.0
		if _rng.randf() < here:
			stats.fronts = int(stats.fronts) + 1
			var count := _rng.randi_range(1, 2) + (1 if _rng.randf() < smoothstep(0.7, 1.3, gust) else 0)
			var swept := _rng.randi_range(0, count - 1)
			var speed := lerpf(SPEED.x, SPEED.y, smoothstep(0.2, 1.3, gust)) * _rng.randf_range(0.9, 1.1)
			for i in count:
				var at := spot - way * 14.0 + side * (float(i) - float(count - 1) * 0.5) * _rng.randf_range(5.0, 9.0) - way * _rng.randf_range(0.0, 6.0)
				ribbons._birth(at, way, speed, _rng.randf_range(0.8, 1.1), 0.6 if i == swept else -1.0)
				if not ribbons.ribbons.is_empty(): ribbons.ribbons.back().tail = float(ribbons.ribbons.back().tail) * tail_scale
		else:
			stats.skipped = int(stats.skipped) + 1
	ribbons.advance(delta, strength, atan2(way_now.y, way_now.x))
	if react == null: return
	_roll(land, delta)

## Each low head's band, rolled on: note where the head is and how hard it
## pushes now, then lay the band's stamps along its last TRAIL_SPAN s. A
## head gone (faded out) leaves its band to roll on along its last way with
## no push behind it, so it eases out of the grass as it came.
func _roll(land: Callable, delta: float) -> void:
	var alive := {}
	var flows: Array = []
	for r: Dictionary in ribbons.ribbons:
		var id := int(r.id)
		alive[id] = true
		var pos: Vector3 = r.pos
		var here := Vector2(pos.x, pos.z)
		var v := Vector2((r.vel as Vector3).x, (r.vel as Vector3).z)
		var k := 0.0
		if v.length() >= 0.5 and not is_nan(float(land.call(here.x, here.y))):
			var above: float = pos.y - float(r.ground)
			var high := 1.0 - smoothstep(3.0, 8.0, above)
			var low := 1.0 + 0.8 * (1.0 - smoothstep(0.3, 2.0, above))
			k = clampf(float(r.fade), 0.0, 1.0) * smoothstep(0.0, 0.7, float(r.age)) * float(r.weight) * high * low
		var trail: Dictionary = _trails.get(id, {"rows": PackedFloat32Array(), "pushed": -INF, "k": k})
		trail.v = v
		# Eased, so a head crossing a patch with no grass (a rock, a path)
		# fades its push rather than cutting it.
		trail.k = lerpf(float(trail.k), k, 1.0 - exp(-delta / K_EASE))
		_note(trail, here, push * float(trail.k))
		_trails[id] = trail
	for id: int in _trails.keys():
		if alive.has(id): continue
		var trail: Dictionary = _trails[id]
		if _clock - float(trail.pushed) > TRAIL_SPAN + 0.1:
			_trails.erase(id)
			continue
		var rows: PackedFloat32Array = trail.rows
		var n := rows.size()
		_note(trail, Vector2(rows[n - 3], rows[n - 2]) + Vector2(trail.v) * delta, 0.0)
	for trail: Dictionary in _trails.values(): _lay(trail.rows, flows)
	stats.flows = flows.size()
	react.set_flows(flows)

## A head's row now on its trail: where, and its push.
func _note(trail: Dictionary, here: Vector2, k: float) -> void:
	var t: PackedFloat32Array = trail.rows
	t.append_array(PackedFloat32Array([_clock, here.x, here.y, k]))
	if k > 0.0: trail.pushed = _clock
	# Keep one row past the span, for the last stamp's in-between.
	var drop := 0
	while t.size() - drop >= 8 and _clock - t[drop + 4] > TRAIL_SPAN: drop += 4
	if drop > 0: t = t.slice(drop)
	trail.rows = t

## The band's stamps along one head's path `t` (its rows newest last).
func _lay(t: PackedFloat32Array, flows: Array) -> void:
	var rows := t.size() / 4
	if rows < 2: return
	var j := rows - 1
	var back := 0.0
	while back <= TRAIL_SPAN:
		var when := _clock - back
		while j > 0 and t[(j - 1) * 4] > when: j -= 1
		if j == 0: break
		var a := (j - 1) * 4
		var b := j * 4
		var f := clampf((when - t[a]) / maxf(t[b] - t[a], 1e-4), 0.0, 1.0)
		var at := Vector2(lerpf(t[a + 1], t[b + 1], f), lerpf(t[a + 2], t[b + 2], f))
		var k := lerpf(t[a + 3], t[b + 3], f) * band(back) * TRAIL_GAIN
		if absf(k) > 0.004:
			var way := Vector2(t[b + 1] - t[a + 1], t[b + 2] - t[a + 2])
			way = way.normalized() if way.length() > 1e-4 else Vector2.ZERO
			flows.append({"at": at, "way": way, "strength": k, "reach": reach})
		back += TRAIL_GAP
