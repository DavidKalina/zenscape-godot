extends Node3D
## The endless gusts as the aqueduct isle has them (docs/design/endless-flight/
## endless-eddies-handoff.md): the isle's breeze ribbons (scripts/breeze_ribbons.gd,
## whole: its flow, eddies, sweeps, strokes and shader) ride the air over the
## land round the eye, a few at a time along a gust front, curling through
## eddies and now and then diving to skim the grass and kick up off it. The
## isle's grass bows under each ribbon head through zs_ribbon_0..7; the
## endless grass reads one map (zs_react_map), so each head also drops a
## chain of react stamps along its path (GrassReact `eddy`): a swept band,
## no landing ring. The ribbons still publish zs_ribbon_N, which the near
## tufts' own sway reads too.
##
## Flags: --gusts=eddies|rings|both (default eddies), --eddy-reach=M,
## --eddy-push=X, --eddy-scale=X (the strokes' width, 1 = the isle's),
## --eddy-every=S (seconds between fronts), --eddy-radius=M.

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Ribbons = preload("res://scripts/breeze_ribbons.gd")

## Seconds between fronts (+-JITTER), and the plate the ribbons live on.
var every := 3.0
const JITTER := 2.0
var radius := 150.0
## How far ahead of the eye (along its facing) the plate sits, as a share of radius.
const AHEAD := 0.55
## Where a front comes in, metres ahead of the eye.
const AHEAD_NEAR := 40.0
const AHEAD_FAR := 130.0
## Stamp spacing along a head (m), its reach (m) and push.
var spacing := 2.0
var reach := 7.0
var push := 3.0
## The strokes seen from cruise are far: widen and brighten them (x the isle's).
var stroke := 10.0
## Their tails, longer to read from up here (x the isle's).
var tail_scale := 3.0

var ribbons: Node3D
var react: Node
var field_height: Callable
var _rng := RandomNumberGenerator.new()
var _until := 1.0
var _last := {}
var _stamps := 0

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

func step(delta: float, eye: Vector3, facing: Vector2, wind: Vector2, strength: float, land: Callable) -> void:
	if facing.length() < 0.05: facing = Vector2(0, -1)
	facing = facing.normalized()
	var mid := Vector2(eye.x, eye.z) + facing * radius * AHEAD
	ribbons.set_bounds(mid, radius)
	_until -= delta
	if _until <= 0.0:
		_until = every + _rng.randf_range(-JITTER, JITTER)
		# A front comes into the view: a line of ribbons across the wind,
		# a little upwind of a spot ahead of the eye, one of them given a sweep.
		var way := wind.normalized()
		var side := Vector2(-way.y, way.x)
		var spot := Vector2(eye.x, eye.z) + facing * _rng.randf_range(AHEAD_NEAR, AHEAD_FAR) + side * _rng.randf_range(-45.0, 45.0)
		var count := _rng.randi_range(3, 5)
		var swept := _rng.randi_range(0, count - 1)
		var speed := _rng.randf_range(5.0, 7.0)
		for i in count:
			var at := spot - way * 14.0 + side * (float(i) - float(count - 1) * 0.5) * _rng.randf_range(5.0, 9.0) - way * _rng.randf_range(0.0, 6.0)
			ribbons._birth(at, way, speed, _rng.randf_range(0.8, 1.1), 0.6 if i == swept else -1.0)
			if not ribbons.ribbons.is_empty(): ribbons.ribbons.back().tail = float(ribbons.ribbons.back().tail) * tail_scale
	ribbons.advance(delta, strength, atan2(wind.y, wind.x))
	if react == null: return
	var alive := {}
	for r: Dictionary in ribbons.ribbons:
		var id := int(r.id)
		alive[id] = true
		var pos: Vector3 = r.pos
		var here := Vector2(pos.x, pos.z)
		var v := Vector2((r.vel as Vector3).x, (r.vel as Vector3).z)
		if v.length() < 0.5: continue
		if _last.has(id) and here.distance_to(_last[id]) < spacing: continue
		_last[id] = here
		if is_nan(float(land.call(here.x, here.y))): continue
		var above: float = pos.y - float(r.ground)
		var high := 1.0 - smoothstep(3.0, 8.0, above)
		var low := 1.0 + 0.8 * (1.0 - smoothstep(0.3, 2.0, above))
		var k: float = clampf(float(r.fade), 0.0, 1.0) * smoothstep(0.0, 0.7, float(r.age)) * float(r.weight)
		if high * k <= 0.02: continue
		react.eddy(here, v.normalized(), push * k * high * low, reach)
		_stamps += 1
	for id: int in _last.keys():
		if not alive.has(id): _last.erase(id)
