extends Node
## The burrower in endless flight (docs/design/endless-flight/
## spec-burrower-flight.md, Sightings): the study's creature (scripts/burrower/
## burrower.gd) and its push-ups (push_ups.gd) on the game's land
## (scripts/burrower/game_land.gd).
##
## Every so often, at any height, he's out there: a few hundred metres off, in the
## camera's view but off the nose, in a wood or on water, where he shows from
## altitude, roaming at his own pace and paying the plane no mind. No wood or water
## there: no sighting that time. Ignored, he sinks after SIGHT_S s. A plane that
## comes down near him (`_near_him`) starts the run from where he is. It has
## RUN_ORBS orbs, each from him, then he dives; or he dives after CLIMB_HOLD s over
## CLIMB_OFF spans, after RUN s, or when the plane lands or crashes.
## `--no-burrower` leaves him out; `--burrower-every=S` makes the rest S s.

const Burrower = preload("res://scripts/burrower/burrower.gd")
const PushUps = preload("res://scripts/burrower/push_ups.gd")
const GameLand = preload("res://scripts/burrower/game_land.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const CLIMB_OFF := 5.0
const CLIMB_HOLD := 1.4
## In a wood the plane can't skim under the crowns, so high over the ground
## it stays on the run while within CANOPY_OFF spans over the tallest crown
## round the head (CANOPY_HEAD m) or the plane (CANOPY_PLANE m), and over a
## clearing the roof it last had for ROOF_HOLD s (time to drop back in).
const CANOPY_OFF := 4.0
const CANOPY_HEAD := 16.0
const CANOPY_PLANE := 24.0
const ROOF_HOLD := 3.0
const RUN := 40.0
const RUN_ORBS := 3
## An orb's reach past the study's (m): a near miss counts.
const ORB_MORE := 2.5
## Between sightings (s of flight). Rare: he's a thing you come across, about one
## every two to three minutes where there's a wood or water to find him in, a
## minute into the first flight so a new player meets him. Nothing to show him
## in: LOOK_S s of looking, then a shorter wait.
const FIRST := 60.0
const REST := Vector2(120.0,180.0)
const LOOK_S := 12.0
const NOTHING_REST := 30.0
## A look, every ASK s while one is due: off the view's axis between the cosines
## (not on the nose, well inside the frame), SIGHT_M m off.
const ASK := 0.4
const SIGHT_M := Vector2(280.0,420.0)
const NOSE_COS := 0.985
const WIDE_COS := 0.82
## Ignored, he sinks after this (s).
const SIGHT_S := Vector2(20.0,30.0)
## He must have this far of wood or water ahead (m): STRIP's trees or LENGTH's
## looks all wet.
const LENGTH := 160.0
const STRIP := 30.0
const WOOD_MIN := 14
## The plane near him: within NOTICE_M m and NOTICE_UP m over him, him ahead.
const NOTICE_M := 110.0
const NOTICE_UP := 60.0
const NOTICE_EVERY := 0.1
## It came down from high: this long (s) to get low before climbing counts.
const DROP_IN := 5.0
## Past this he's `distant`, with some slip either side.
const FAR_M := 220.0
const FAR_SLIP := 20.0
## The gust's gain on a sighting, from 1 up close to GUST_FAR at GUST_FAR_M m off the
## eye, so a wood goes over as far as the eye needs it to.
const GUST_FAR := 1.6
const GUST_NEAR_M := 120.0
const GUST_FAR_M := 300.0

var land: GameLand
var burrower: Burrower
var push_ups: PushUps
var _idle := 0
var _ask := 0.0
var _roof := -INF
var _roof_at := -INF
var _rng := RandomNumberGenerator.new()
## The flag's rest (s), negative when not set.
var _every := -1.0
var _sighted := false
var _sight_left := 0.0
var _look_left := -1.0
var _drop_in := 0.0
var _try := 0
## Rest left (s), time over CLIMB_OFF (s), the last reason a run or sighting
## ended, and counts (for drivers).
var rouse := {"rest": FIRST, "high": 0.0, "why": "", "sightings": 0, "noticed": 0, "ignored": 0, "dives": 0,
	"nothing": 0, "canopy": 0.0, "kind": "", "at": Vector2.ZERO, "off": 0.0, "first_way": 0.0}

static func wanted() -> bool:
	return not "--no-burrower" in OS.get_cmdline_user_args()

## The flag: seconds between sightings, or negative.
static func every_flag() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--burrower-every="): return maxf(float(a.trim_prefix("--burrower-every=")),0.0)
	return -1.0

func _init() -> void:
	name = "BurrowerFlight"

func setup(game: Node3D) -> void:
	land = GameLand.new()
	land.setup(game)
	add_child(land)
	burrower = Burrower.new()
	add_child(burrower)
	burrower.setup(land,game.react)
	burrower.view = game.camera
	push_ups = PushUps.new()
	add_child(push_ups)
	push_ups.setup(land,burrower)
	push_ups.at_head = true
	push_ups.run_most = RUN_ORBS
	push_ups.reach_more = ORB_MORE
	push_ups.taken.connect(_taken.bind(game))
	_rng.randomize()
	_every = every_flag()
	if _every >= 0.0: rouse.rest = _every

## One frame: the sighting's clock (asleep, only that), the creature and its
## push-ups.
func step(delta: float, game: Node3D) -> void:
	_rouse(delta,game)
	# Asleep and all settled: nothing more a frame (a couple of frames on
	# after, so the last halo and mote are cleared).
	_idle = _idle+1 if burrower.settled() and push_ups.settled() else 0
	if _idle > 2: return
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	burrower.tick(delta)
	var bumped: bool = game.hand_landing.flying() and push_ups.bump(game.get_world_3d().direct_space_state,game.plane)
	push_ups.tick(delta,game.plane,span*0.5,bumped)

## A push-up taken: a move in the chain (LineMoves `push_up`), when the chain
## is running (NearMiss is stepped only then).
func _taken(kind: StringName, at: Vector3, game: Node3D) -> void:
	if game.plane.weighted and game.hand_landing.flying(): game.near.moves.push_up(str(kind),at,game)

func _rouse(delta: float, game: Node3D) -> void:
	var flying: bool = game.hand_landing.flying()
	if burrower.active:
		if burrower.diving(): return
		if _sighted: _roaming(delta,game,flying)
		else: _running(delta,game,flying)
		return
	if not flying: return
	rouse.rest = maxf(float(rouse.rest)-delta,0.0)
	if float(rouse.rest) > 0.0: return
	_looking(delta,game)

## The run: what ends it.
func _running(delta: float, game: Node3D, flying: bool) -> void:
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	var clear := _clear(game)
	_drop_in = 0.0 if clear <= span*CLIMB_OFF else maxf(_drop_in-delta,0.0)
	rouse.high = float(rouse.high)+delta if clear > span*CLIMB_OFF and _drop_in <= 0.0 else 0.0
	var why := ""
	if not flying: why = "down"
	elif float(rouse.high) > CLIMB_HOLD: why = "climb"
	elif burrower._run > RUN: why = "run"
	elif push_ups.run_done(): why = "orbs"
	if why != "":
		burrower.dive()
		rouse.why = why
		rouse.dives = int(rouse.dives)+1
		_rest()

## The next rest, the flag's if it's set.
func _rest() -> void:
	rouse.rest = _every if _every >= 0.0 else _rng.randf_range(REST.x,REST.y)

## Out on his own: his time, and whether the plane has come to him.
func _roaming(delta: float, game: Node3D, flying: bool) -> void:
	_sight_left -= delta
	var p: Vector3 = game.plane.position
	var d := burrower.pos.distance_to(Vector2(p.x,p.z))
	burrower.set_distant(d > FAR_M+(-FAR_SLIP if burrower.distant else FAR_SLIP))
	game.react.gust_gain = remap(clampf(d,GUST_NEAR_M,GUST_FAR_M),GUST_NEAR_M,GUST_FAR_M,1.0,GUST_FAR)
	if _sight_left <= 0.0:
		_sighted = false
		burrower.dive()
		rouse.why = "ignored"
		rouse.ignored = int(rouse.ignored)+1
		_rest()
		return
	_ask -= delta
	if _ask > 0.0: return
	_ask = NOTICE_EVERY
	if flying and _near_him(game): notice(game)

## Coming down near him: close, low over him, and he's ahead.
func _near_him(game: Node3D) -> bool:
	var p: Vector3 = game.plane.position
	var at: Vector2 = burrower.pos
	var to := at-Vector2(p.x,p.z)
	if to.length() > NOTICE_M: return false
	if p.y-maxf(land.height(at.x,at.y),land.water_y(at.x,at.y)) > NOTICE_UP: return false
	var f: Vector3 = game.plane.forward()
	return to.dot(Vector2(f.x,f.z)) > 0.0

## The run, from where he is (a driver's, or `_roaming`'s).
func notice(game: Node3D) -> void:
	_sighted = false
	rouse.high = 0.0
	rouse.noticed = int(rouse.noticed)+1
	_drop_in = DROP_IN
	burrower.shudder.sight = false
	game.react.gust_gain = 1.0
	burrower.notice(game.plane)
	push_ups.begin_run()

## A sighting is due: a look now and then, until one suits or the time's up.
func _looking(delta: float, game: Node3D) -> void:
	if _look_left < 0.0: _look_left = LOOK_S
	_look_left -= delta
	_ask -= delta
	if _ask > 0.0: return
	_ask = ASK
	_try += 1
	var spot := _spot_wood(game) if _try % 2 == 0 else _spot_water(game)
	if not spot.is_empty():
		sight(game,spot)
		return
	if _look_left <= 0.0:
		_look_left = -1.0
		rouse.nothing = int(rouse.nothing)+1
		rouse.rest = _every if _every >= 0.0 else NOTHING_REST

## He's out there at `spot` ({at, way, kind}, what `_spot_*` gave).
func sight(game: Node3D, spot: Dictionary) -> void:
	_look_left = -1.0
	_sighted = true
	_sight_left = _rng.randf_range(SIGHT_S.x,SIGHT_S.y)
	_ask = NOTICE_EVERY
	burrower.wake(spot.at,float(spot.way))
	burrower.shudder.sight = true
	burrower.plume = true
	var p: Vector3 = game.plane.position
	var d: float = (spot.at as Vector2).distance_to(Vector2(p.x,p.z))
	burrower.set_distant(d > FAR_M)
	rouse.sightings = int(rouse.sightings)+1
	rouse.kind = spot.kind
	rouse.at = spot.at
	rouse.off = d
	rouse.trees = int(spot.get("trees",0))

## The view along the ground from the camera: the eye and way (unit).
func _view(game: Node3D) -> Array:
	var cam: Camera3D = game.camera
	var f := -cam.global_transform.basis.z
	var way := Vector2(f.x,f.z)
	if way.length() < 0.05:
		var pf: Vector3 = game.plane.forward()
		way = Vector2(pf.x,pf.z)
	var e := cam.global_position
	return [Vector2(e.x,e.z),way.normalized()]

## In the frame, and no hill between it and the camera.
func _in_view(game: Node3D, at: Vector2) -> bool:
	var cam: Camera3D = game.camera
	var y := maxf(land.height(at.x,at.y),land.water_y(at.x,at.y))+6.0
	var q := Vector3(at.x,y,at.y)
	if not cam.is_position_in_frustum(q): return false
	var e := cam.global_position
	for i in range(1,8):
		var c := e.lerp(q,float(i)/8.0)
		if land.height(c.x,c.z) > c.y: return false
	return true

## Off the nose, inside the frame.
func _off_nose(eye: Vector2, way: Vector2, at: Vector2) -> bool:
	var c := way.dot((at-eye).normalized())
	return c < NOSE_COS and c > WIDE_COS

## The ways across his line from the eye, the first to try first.
func _across(eye: Vector2, at: Vector2) -> Array:
	var side := (at-eye).normalized().orthogonal()
	var s := -1.0 if _rng.randf() < 0.5 else 1.0
	return [side*s,-side*s,(side*s).rotated(0.6),(-side*s).rotated(-0.6)]

## A thick stood wood in view, and the way through it with most trees.
func _spot_wood(game: Node3D) -> Dictionary:
	var v := _view(game)
	var eye: Vector2 = v[0]
	var way: Vector2 = v[1]
	var cells: Array = land.stands_round(eye,SIGHT_M.y)
	for c: Vector2 in cells:
		if c.distance_to(eye) < SIGHT_M.x or c.distance_to(eye) > SIGHT_M.y: continue
		if not _off_nose(eye,way,c) or not land.open(c) or not _in_view(game,c): continue
		var best := Vector2.ZERO
		var most := WOOD_MIN-1
		for w: Vector2 in _across(eye,c):
			var n: int = land.trees_along(c,w,LENGTH,STRIP)
			if n > most:
				most = n
				best = w
		if best != Vector2.ZERO: return {"at": c, "way": best.angle(), "kind": "wood", "trees": most}
	return {}

## Open water in view, and a way along it.
func _spot_water(game: Node3D) -> Dictionary:
	var v := _view(game)
	var eye: Vector2 = v[0]
	var way: Vector2 = v[1]
	for i in 6:
		var a := _rng.randf_range(0.18,0.6)*(-1.0 if _rng.randf() < 0.5 else 1.0)
		var at := eye+way.rotated(a)*_rng.randf_range(SIGHT_M.x,SIGHT_M.y)
		if not _off_nose(eye,way,at) or not land.wet(at) or not land.open(at) or not _in_view(game,at): continue
		for w: Vector2 in _across(eye,at):
			if land.wet_along(at,w,LENGTH): return {"at": at, "way": w.angle(), "kind": "water"}
	return {}

## The plane's height for the climb-off: over the ground, or in a wood, in
## the same terms, over the crowns (only asked once high).
func _clear(game: Node3D) -> float:
	var clear := float(game.near.ground_clear)
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	if clear <= span*CLIMB_OFF: return clear
	var p: Vector3 = game.plane.position
	var top := maxf(land.canopy_top(burrower.pos,CANOPY_HEAD),land.canopy_top(Vector2(p.x,p.z),CANOPY_PLANE))
	var now := Time.get_ticks_msec()*0.001
	if top > -INF:
		_roof = top
		_roof_at = now
	elif now-_roof_at < ROOF_HOLD: top = _roof
	if top == -INF: return clear
	rouse.canopy = float(rouse.canopy)+1.0
	return minf(clear,(p.y-top)*CLIMB_OFF/CANOPY_OFF)
