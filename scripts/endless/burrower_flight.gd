extends Node
## The burrower in endless flight (docs/design/endless-flight/
## spec-burrower-flight.md, Sightings): the study's creature (scripts/burrower/
## burrower.gd) and its push-ups (push_ups.gd) on the game's land
## (scripts/burrower/game_land.gd).
##
## He lives by the cave mouths. A plane that comes within MOUTH_NEAR m of an opening of
## a stood sunk cave, flying so that he can still lead it (`_can_lead`), finds him
## out there: a few hundred metres off, in the camera's view but off the nose, on open
## ground on the sinkhole's open side, already making for it, throwing a plume that
## shows from altitude. A plane that comes near him (`_near_him`) starts the run: he
## keeps ahead of it along his route (`_try_spot`), in along the sinkhole's open way, so
## that following him lines the plane up with the opening, and goes in (`_in`). The
## plane is left behind, or the run's orbs are out: he goes on all the same, and he
## only stops short if caught, or if the plane lands or crashes. The caves are there
## without him: he shows one, he doesn't open it.
## Inside he carries on along the bore (scripts/endless/burrower_bore.gd). There is no
## timer: he's seen at a mouth or not at all. REST s after a run he can be found again,
## and each mouth once until the plane has been well away from it.
## `--no-burrower` leaves him out; `--burrower-every=S` makes the rest S s;
## `--burrower-near=M` makes MOUTH_NEAR M m (it stays inside the caves' build reach).
## The run's tuning: `--burrower-orb-off=M` (least m off the plane's line an orb comes
## up, the band ORB_OFF's width; 0: on the line as he crosses it), `--burrower-reach=M`
## (ORB_MORE), `--burrower-swing=M` (his swing each side; 0: none) and
## `--burrower-swing-s=S` (there and back).

## A surge roll into his ridge on a run (`try_catch`, scripts/endless/
## surge_smash.gd): the ground bursts at `at` (world), a prize comes up ahead, he
## dives. Once a run. The `finds` lane's `event` binds to this.
signal caught(at: Vector3)

const Burrower = preload("res://scripts/burrower/burrower.gd")
const PushUps = preload("res://scripts/burrower/push_ups.gd")
const BurrowerBore = preload("res://scripts/endless/burrower_bore.gd")
const GameLand = preload("res://scripts/burrower/game_land.gd")
const Tunnels = preload("res://scripts/endless/tunnel_sites.gd")
const WorldScale = preload("res://scripts/world_scale.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The crowns round his head count as ground for a catch (m round it).
const CANOPY_HEAD := 16.0
const RUN_ORBS := 3
## A surge roll runs him down: his pace under it; caught within CATCH_M m of his
## head or the CATCH_TRAIL m of ridge behind it, within CATCH_UP m over the ground
## or the crowns. The prize comes up PRIZE_AHEAD s of flight on.
const RUN_DOWN := 0.55
const CATCH_M := 14.0
const CATCH_TRAIL := 26.0
const CATCH_UP := 16.0
const CATCH_CLODS := 40
const PRIZE_AHEAD := 1.3
const CATCH_PRIZE := &"gong"
## An orb's reach past the study's (m).
const ORB_MORE := 2.0
## How far off the plane's line an orb comes up (m): flying straight misses it, a
## turn takes it. PushUps holds it to what the plane can reach in the time.
const ORB_OFF := Vector2(9.0,15.0)
## His swing on the run: m each side of his course, s there and back.
const SWING_M := 18.0
const SWING_S := 7.0
## The plane within this of a mouth (m), what it can be set to (the most under the
## caves' build reach, 2500; the least leaves him LEAD_LEAST), and how far past it the
## plane must go before that mouth has him again.
const MOUTH_NEAR := 1000.0
const MOUTH_NEAR_SET := Vector2(700.0,2200.0)
const MOUTH_AWAY := 400.0
## Between runs (s of flight): at most one at a time, and never straight after another.
const REST := Vector2(45.0,75.0)
## A look, every ASK s while the plane is near a mouth: off the view's axis between the
## cosines (not on the nose, well inside the frame), SIGHT_M m off, the nearer the closer
## the plane is to the mouth (SIGHT_FROM m), so that it's left a run behind him. The way
## in must be within LEAD_COS of the plane's nose and at least LEAD_LEAST m off.
const ASK := 0.4
const SIGHT_M := Vector2(240.0,420.0)
const SIGHT_FROM := Vector2(650.0,1000.0)
const SIGHT_FAN := [0.2,0.3,0.4,0.5,0.58]
const NOSE_COS := 0.985
const WIDE_COS := 0.82
const LEAD_COS := 0.2
const LEAD_LEAST := 420.0
const SIGHT_STEPS := 4
## His route: to the way in, on the sinkhole's axis WAY_IN m out past its rim, then up
## that axis, nothing turning him aside from the rim on, to LIP_M m out of the opening.
## His spot is at most TURN_M m nearer the mouth than the way in, or he'd have to run
## back on himself there.
const WAY_IN := 70.0
const LIP_M := 16.0
const TURN_M := 40.0
## The sinkhole counts a bit past its rim for keeping his spot and way off it.
const BOWL_GROW := 1.2
## The plane near him: within NOTICE_M m and NOTICE_UP m over him, him ahead.
const NOTICE_M := 170.0
const NOTICE_UP := 130.0
const NOTICE_EVERY := 0.1
## The plane this far over him (m) on a run: he keeps his plume.
const PLUME_OVER := 22.0
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
var bore: BurrowerBore
var _idle := 0
var _ask := 0.0
var _rng := RandomNumberGenerator.new()
## The flag's rest (s), negative when not set, and the flag's reach (m).
var _every := -1.0
var _near := MOUTH_NEAR
var _sighted := false
## The mouth this run makes for (Tunnels.mouths), and the mouths he has shown and the
## plane hasn't left since.
var _mouth := {}
var _spent := {}
## The spots this look still has to try (`_spots_for`).
var _spots: Array = []
## Rest left (s), the last reason a run ended, counts and this run's mouth (for
## drivers).
var rouse := {"rest": 0.0, "why": "", "sightings": 0, "noticed": 0, "dives": 0, "mouths": 0,
	"mouth": "", "at": Vector2.ZERO, "off": 0.0}

static func wanted() -> bool:
	return not "--no-burrower" in OS.get_cmdline_user_args()

## The flag: seconds between sightings, or negative.
static func every_flag() -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--burrower-every="): return maxf(float(a.trim_prefix("--burrower-every=")),0.0)
	return -1.0

## A run's flag (not negative), or `default`.
static func _flag(flag: String, default: float) -> float:
	for a: String in LaunchArgs.user_args():
		if a.begins_with(flag+"="): return maxf(float(a.trim_prefix(flag+"=")),0.0)
	return default

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
	push_ups.reach_more = _flag("--burrower-reach",ORB_MORE)
	var off := _flag("--burrower-orb-off",ORB_OFF.x)
	if off > 0.0: push_ups.off_line = Vector2(off,off+ORB_OFF.y-ORB_OFF.x)
	burrower.swing_m = _flag("--burrower-swing",SWING_M)
	burrower.swing_s = maxf(_flag("--burrower-swing-s",SWING_S),1.0)
	push_ups.taken.connect(_taken.bind(game))
	bore = BurrowerBore.new()
	add_child(bore)
	bore.setup(game.tunnels)
	bore.ended.connect(_bore_over)
	_rng.randomize()
	_every = every_flag()
	_near = clampf(_flag("--burrower-near",MOUTH_NEAR),MOUTH_NEAR_SET.x,MOUTH_NEAR_SET.y)

## One frame: whether he's about (asleep, only that), the creature and its push-ups.
func step(delta: float, game: Node3D) -> void:
	bore.step(delta,game)
	FrameLog.mark(&"b_bore")
	_rouse(delta,game)
	# Asleep and all settled: nothing more a frame (a couple of frames on
	# after, so the last halo and mote are cleared).
	_idle = _idle+1 if burrower.settled() and push_ups.settled() else 0
	if _idle > 2: return
	FrameLog.mark(&"b_rouse")
	var span: float = WorldScale.TOY_SPAN*game.ground_scale.size()
	burrower.tick(delta)
	FrameLog.mark(&"b_tick")
	var bumped: bool = game.hand_landing.flying() and push_ups.bump(game.get_world_3d().direct_space_state,game.plane)
	FrameLog.mark(&"b_bump")
	push_ups.tick(delta,game.plane,span*0.5,bumped)
	FrameLog.mark(&"b_pushups")

## A push-up taken: a move in the chain (LineMoves `push_up`), when the chain
## is running (NearMiss is stepped only then).
func _taken(kind: StringName, at: Vector3, game: Node3D) -> void:
	if game.plane.weighted and game.hand_landing.flying(): game.near.moves.push_up(str(kind),at,game)

func _rouse(delta: float, game: Node3D) -> void:
	var flying: bool = game.hand_landing.flying()
	if bore.running() and not burrower.active: return
	if burrower.active:
		if burrower.diving(): return
		if burrower.route_done(): _in(game)
		elif _sighted: _roaming(delta,game,flying)
		else: _running(game,flying)
		return
	if not flying: return
	rouse.rest = maxf(float(rouse.rest)-delta,0.0)
	if not _spots.is_empty():
		_try_spot(game)
		return
	_ask -= delta
	if _ask > 0.0: return
	_ask = ASK
	_free_mouths(game)
	if float(rouse.rest) <= 0.0: _spots = _spots_by_mouth(game)

## The run: what ends it short of the mouth. Left far behind, or high over him where
## the ridge doesn't show, the plume marks him.
func _running(game: Node3D, flying: bool) -> void:
	_far(game)
	burrower.plume = burrower.distant or float(game.plane.position.y)-float(burrower.head().y) > PLUME_OVER
	if flying: return
	burrower.dive()
	rouse.why = "down"
	rouse.dives = int(rouse.dives)+1
	_rest()

## Too far off for the ridge, or not.
func _far(game: Node3D) -> void:
	var p: Vector3 = game.plane.position
	var d := burrower.pos.distance_to(Vector2(p.x,p.z))
	burrower.set_distant(d > FAR_M+(-FAR_SLIP if burrower.distant else FAR_SLIP))
	game.react.gust_gain = remap(clampf(d,GUST_NEAR_M,GUST_FAR_M),GUST_NEAR_M,GUST_FAR_M,1.0,GUST_FAR)

## At the end of his route: he goes in, and the bore has him (the rest starts when
## that's over, `_bore_over`).
func _in(game: Node3D) -> void:
	_sighted = false
	burrower.shudder.sight = false
	burrower.plunge(_mouth.out)
	burrower.want_at = Vector2(NAN,NAN)
	game.sound.shot("crack",0.9,0.55,burrower.head())
	game.sound.shot("thud",1.0,0.6,burrower.head())
	rouse.why = "mouth"
	rouse.dives = int(rouse.dives)+1
	rouse.mouths = int(rouse.mouths)+1
	rouse.bore = ""
	bore.begin(_mouth.site,int(_mouth.end),game.plane)

## The chase in the bore is over.
func _bore_over(why: StringName) -> void:
	rouse.bore = why
	_rest()

## On a run, up and running: he can be caught.
func on_run() -> bool:
	return burrower.active and not _sighted and not burrower.diving() and not burrower._sounding and burrower.phase == &"run"

## A surge roll under way (`on`): he can't keep ahead of it, so the plane runs
## him down.
func chased(on: bool) -> void:
	burrower.run_pace = RUN_DOWN if on else 1.0

## Each frame of a surge roll: the plane low over his head or the ridge just
## behind it is a catch. True when he's caught now.
func try_catch(game: Node3D) -> bool:
	if not on_run(): return false
	var p: Vector3 = game.plane.position
	var at: Vector2 = burrower.pos
	var top := maxf(land.height(at.x,at.y),land.canopy_top(at,CANOPY_HEAD))
	if p.y-top > CATCH_UP: return false
	var q := Vector2(p.x,p.z)
	var line := Geometry2D.get_closest_point_to_segment(q,at,at-burrower.forward()*CATCH_TRAIL)
	if q.distance_to(line) > CATCH_M: return false
	catch(game)
	return true

## Caught: the burst at his head, the prize ahead of the plane, he dives.
func catch(game: Node3D) -> void:
	var head: Vector3 = burrower.head()
	burrower.throw_earth(head+Vector3.UP*0.4,CATCH_CLODS,9.0,17.0,2.5)
	burrower.puff(head,14)
	var v: Vector3 = game.plane.velocity
	var flat := Vector2(v.x,v.z)
	var spot := Vector2(game.plane.position.x,game.plane.position.z)+flat*PRIZE_AHEAD
	push_ups.push(spot if land.open(spot) else burrower.pos,CATCH_PRIZE,-flat.normalized())
	burrower.run_pace = 1.0
	burrower.dive()
	rouse.why = "caught"
	rouse.dives = int(rouse.dives)+1
	rouse.caught = int(rouse.get("caught",0))+1
	_rest()
	caught.emit(head)

## The next rest, the flag's if it's set.
func _rest() -> void:
	rouse.rest = _every if _every >= 0.0 else _rng.randf_range(REST.x,REST.y)

## Out on his own, on his way: whether the plane has come to him.
func _roaming(delta: float, game: Node3D, flying: bool) -> void:
	_far(game)
	_ask -= delta
	if _ask > 0.0: return
	_ask = NOTICE_EVERY
	if flying and _near_him(game): notice(game)

## The plane near him: close, not far over him, and he's ahead.
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
	rouse.noticed = int(rouse.noticed)+1
	burrower.shudder.sight = false
	game.react.gust_gain = 1.0
	burrower.notice(game.plane)
	push_ups.begin_run()

## He's out there at `spot` ({at, way, route, down, mouth}, what `_try_spot` gave).
func sight(game: Node3D, spot: Dictionary) -> void:
	_sighted = true
	_mouth = spot.mouth
	_spent[_mouth.name] = _mouth
	_ask = NOTICE_EVERY
	burrower.wake(spot.at,float(spot.way))
	burrower.set_route(spot.route,float(spot.down))
	burrower.shudder.sight = true
	burrower.plume = true
	burrower.plume_water = false
	var p: Vector3 = game.plane.position
	var d: float = (spot.at as Vector2).distance_to(Vector2(p.x,p.z))
	burrower.set_distant(d > FAR_M)
	rouse.sightings = int(rouse.sightings)+1
	rouse.mouth = _mouth.name
	rouse.at = spot.at
	rouse.off = d

## Mouths he has shown come back once the plane has been well away from them.
func _free_mouths(game: Node3D) -> void:
	var p: Vector3 = game.plane.position
	for key: String in _spent.keys():
		if (_spent[key].at as Vector2).distance_to(Vector2(p.x,p.z)) > _near+MOUTH_AWAY: _spent.erase(key)

## The spots to try by a mouth the plane is coming to, best first ([]: no mouth).
func _spots_by_mouth(game: Node3D) -> Array:
	var p: Vector3 = game.plane.position
	var p2 := Vector2(p.x,p.z)
	var f: Vector3 = game.plane.forward()
	var nose := Vector2(f.x,f.z).normalized()
	for t: Tunnels.Site in game.tunnels.stood():
		if not t.sunk: continue
		for m: Dictionary in Tunnels.mouths(t):
			if _spent.has(m.name) or not _can_lead(m,p2,nose): continue
			return _spots_for(game,t,m,p2)
	return []

## The plane is within reach of mouth `m`, out on its open side, not already past the
## way in, and flying near enough toward it.
func _can_lead(m: Dictionary, p: Vector2, nose: Vector2) -> bool:
	var at: Vector2 = m.at
	if at.distance_to(p) > _near: return false
	var out: Vector2 = m.out
	if (p-at).dot(out) < 0.0: return false
	var way_in := at+out*(float(m.reach)+WAY_IN)
	var to := way_in-p
	return to.length() > LEAD_LEAST and nose.dot(to.normalized()) > LEAD_COS

## The spots near enough the view and nearer the mouth's way in than the plane, the
## ones nearest the line to it and the distance wanted first. They're asked of the land
## one a frame (`_try_spot`): that's slow, and the plane barely moves meanwhile.
func _spots_for(game: Node3D, t: Tunnels.Site, m: Dictionary, p: Vector2) -> Array:
	var v := _view(game)
	var eye: Vector2 = v[0]
	var way: Vector2 = v[1]
	var at: Vector2 = m.at
	var out: Vector2 = m.out
	var way_in := at+out*(float(m.reach)+WAY_IN)
	var to := (way_in-p).normalized()
	var want := remap(clampf(p.distance_to(at),SIGHT_FROM.x,SIGHT_FROM.y),SIGHT_FROM.x,SIGHT_FROM.y,SIGHT_M.x,SIGHT_M.y)
	var found: Array = []
	for a: float in SIGHT_FAN:
		for s: float in [-1.0,1.0]:
			for i in SIGHT_STEPS:
				var d := lerpf(SIGHT_M.x,SIGHT_M.y,float(i)/(SIGHT_STEPS-1))
				var q := eye+way.rotated(a*s)*d
				if q.distance_to(way_in) >= p.distance_to(way_in): continue
				if (q-at).dot(out) < float(m.reach)+WAY_IN-TURN_M: continue
				found.append({"score": absf((q-p).cross(to))*0.5+absf(d-want), "at": q, "site": t, "mouth": m})
	found.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return float(x.score) < float(y.score))
	return found

## The next spot: in view, off the nose, on open ground, with a clear way to the mouth's
## way in, and he's there.
func _try_spot(game: Node3D) -> void:
	var f: Dictionary = _spots.pop_front()
	var q: Vector2 = f.at
	var t: Tunnels.Site = f.site
	var m: Dictionary = f.mouth
	var v := _view(game)
	if not _off_nose(v[0],v[1],q) or Tunnels.on_bowl(t,q.x,q.y,BOWL_GROW): return
	var at: Vector2 = m.at
	var out: Vector2 = m.out
	var way_in := at+out*(float(m.reach)+WAY_IN)
	if land.wet(q) or not land.open(q) or not _way_clear(t,q,way_in) or not _in_view(game,q): return
	_spots.clear()
	var rim := at+out*(float(m.reach)+WAY_IN*0.3)
	var route := PackedVector2Array([q,way_in,rim,at+out*LIP_M])
	sight(game,{"at": q, "way": (way_in-q).angle(), "route": route, "mouth": m, "down": q.distance_to(way_in)+way_in.distance_to(rim)})

## The line from `a` to `b` keeps off the sinkhole.
func _way_clear(t: Tunnels.Site, a: Vector2, b: Vector2) -> bool:
	for i in range(1,8):
		var q := a.lerp(b,float(i)/8.0)
		if Tunnels.on_bowl(t,q.x,q.y,BOWL_GROW): return false
	return true

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
