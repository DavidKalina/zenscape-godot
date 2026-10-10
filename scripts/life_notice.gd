extends RefCounted
## The life notices the hand and the wanderer (docs/scenic/life.md
## "Noticing"). Player actions raise a disturbance (scripts/disturbance.gd):
## a gust, a poke on the clay, a snap to night or day, the wanderer's stride.
## Each is answered once, when it comes: the creatures near it are found then
## (a few dozen at most), their reactions are scheduled, and only those
## reacting are stepped after. Nothing here looks for the hand each frame.
##
## - **A gust** reaches each creature as its head passes (the front's own
##   easing, from the gust's record): gulls lift and wheel off downwind, fish
##   dart with it and drift home, fireflies scatter on it and drift back,
##   deer lift their heads or, in a strong one, bolt for the trees, and a
##   heron standing in it flies off. A hard one sends sitting frogs in.
## - **A poke** near water: frogs plop in and stay under a while, fish
##   scatter from it, then come back to nose at the rings. Deer look up, or
##   walk off if it is close; a heron near it leaves.
## - **The snap to night** wakes the fireflies in a travelling wave out from
##   where you are looking, each lighting on its first flash; **the snap to
##   day** brings a short dawn chorus, if the world has woods or birds to sing.
## - **The wanderer:** frogs jump in as it passes and stay under while it is
##   near, fish drift over to its shadow at the bank, deer lift their heads,
##   step away, or bolt from a runner, a heron leaves, and the snake watches
##   and hisses at it as it does at you (LifeSnakes.watcher).
##
## Reactions write into what the creatures already read, so nothing is kept
## once it is over: a fish's `nudge`, `hush` and `steer`, a frog's `lurk`, a
## deer's `hurry`, the gulls' flight state, the fireflies' instances. A
## creature that leaves or is released mid-reaction is simply dropped.
## `--no-notice` turns it all off.

const Disturbance = preload("res://scripts/disturbance.gd")

# --- Fish ---------------------------------------------------------------------
## A dart: metres at the weakest and strongest, the spring (stiffness 1/s²,
## damping 1/s; under critical, so it overshoots a little and swings back),
## and how long it holds out before turning back (s, by the fish's hash).
const DART := Vector2(0.35,0.95)
const DART_SPRING := Vector2(90.0,11.0)
const DART_HOLD := Vector2(0.9,1.7)
## Coming back and settling: a soft, near-critical spring.
const HOME_SPRING := Vector2(3.0,3.2)
## How far the circling quiets (share) while darting, and while nosing or
## following, where the fish hangs nearly still and faces what it is nosing.
const DART_HUSH := 0.6
const NOSE_HUSH := 0.85
const HUSH_RATE := 1.2
## Nosing at the rings: stop this short of them, go at most this far from
## home, and stay this long (s).
const NOSE_GAP := 0.25
const NOSE_REACH := 1.6
const NOSE_TIME := Vector2(4.0,7.0)
## Poke reach (m) and the share of it a fish just darts and never noses from.
const FISH_POKE := 3.5
## The wanderer: fish within FISH_FOLLOW m drift over to its shadow, and one
## within FISH_SHY m of a figure in the water darts instead. Following lasts
## FOLLOW_HOLD s after its last stride (it pings while standing).
const FISH_FOLLOW := 4.5
const FISH_SHY := 1.0
const FOLLOW_HOLD := 3.0
## A gust darts fish whose air share is over this.
const FISH_GUST := 0.15

# --- Frogs --------------------------------------------------------------------
## Sitting frogs within these metres go in: of a poke, and of the wanderer
## (plus FROG_FIGURE_RUN more for a runner). A gust sends them in over this
## share of full.
const FROG_POKE := 3.0
const FROG_FIGURE := 2.2
const FROG_FIGURE_RUN := 1.0
const FROG_GUST := 0.6
## The beat before a frog goes (s): a base, per metre from the disturbance,
## and a scatter by frog, so a bank empties one after another.
const FROG_BEAT := Vector3(0.12,0.08,0.25)
## Extra seconds under water (on top of its usual swim), and while the
## wanderer stays near, at least this long after its last stride, but never
## more than LURK_MOST in all: a frog waited out comes back to its bank.
const LURK := Vector2(3.0,7.0)
const LURK_NEAR := 3.0
const LURK_MOST := 15.0

# --- Gulls --------------------------------------------------------------------
## Metres beyond a gust's air a gull still feels it, and the least share
## that lifts it. The lift: downwind push (m/s), climb (m/s) and the pull-up's
## seconds at full; WHEEL is the chance it turns its circling round.
const BIRD_MARGIN := 3.0
const BIRD_GUST := 0.1
const BIRD_PUSH := Vector2(1.5,4.5)
const BIRD_CLIMB := Vector2(1.2,3.2)
const BIRD_PULL := Vector2(1.6,3.0)
const WHEEL := 0.45

# --- Fireflies ------------------------------------------------------------------
## A gust's scatter: metres downwind (weakest, strongest), metres up, a
## jitter, the spring out, the hold (s) and the slow drift back.
const FLY_SCATTER := Vector2(0.5,1.6)
const FLY_RISE := 0.35
const FLY_JITTER := 0.4
const FLY_SPRING := Vector2(20.0,5.0)
const FLY_HOLD := Vector2(0.4,1.0)
const FLY_HOME := Vector2(1.2,2.2)
const FLY_MARGIN := 1.5
## The night wave: a lead (s) before the first, its speed (m/s), a scatter
## (s) by firefly, and the rise of each one's presence (s).
const WAVE_LEAD := 0.35
const WAVE_SPEED := 3.0
const WAVE_SCATTER := 0.5
const WAVE_RISE := 0.35

# --- Deer and heron ---------------------------------------------------------------
## Levels of alarm: 1 lifts the head (the Alert clip first), 2 walks off
## into the trees a little quicker, 3 bolts. Metres for each from a poke
## and from the wanderer; a gust bolts them over DEER_GUST_BOLT share.
const DEER_POKE := Vector3(7.0,3.5,0.0)
const DEER_FIGURE := Vector3(8.0,5.0,2.5)
## A runner bolts them from this far.
const DEER_RUN := 5.0
const DEER_GUST_BOLT := 0.6
const DEER_GUST_MARGIN := 3.0
## Seconds the head stays up, the beat of alarm before moving off, and the
## pace (share of the walk) of stepping away and of a bolt.
const DEER_LOOK := Vector2(4.0,6.0)
const DEER_TENSE := 0.55
const DEER_STEP := 1.4
const DEER_BOLT := 2.3
## Metres from a poke and from the wanderer that send a standing heron off,
## and the air share of a gust that does; it goes after HERON_BEAT s.
const HERON_POKE := 4.0
const HERON_FIGURE := 5.0
const HERON_GUST := 0.5
const HERON_BEAT := 0.6

# --- Dawn chorus ----------------------------------------------------------------
## Seconds after a snap to day each song starts (the wildlife allows three at
## once), their gain, and the songs.
const CHORUS := [0.3,0.85,1.6]
const CHORUS_GAIN := 0.3
const CHORUS_SONGS := ["robin","chickadee","kinglet","bluebird","hermit-thrush"]
## The wanderer's head height, where the snake looks.
const FIGURE_EYE := 0.85

var life: Node3D
var enabled := "--no-notice" not in preload("res://scripts/launch_args.gd").user_args()
## For probes: reactions started, by what.
var reactions := {}
var _pending: Array = []
var _fish: Array[Dictionary] = []
var _flies: Array[Dictionary] = []
var _wave: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()

func _init(owner: Node3D) -> void:
	life = owner
	_rng.seed = 40417
	Disturbance.hub().raised.connect(_raised)

## Every reaction ends at once (a new world); what they wrote is taken back.
func clear() -> void:
	_pending.clear()
	for site in _fish: _calm_fish(site)
	_fish.clear()
	for site in _flies:
		if site.here: _place_fly(site,Vector3.ZERO)
		site.erase("notice")
	_flies.clear()
	_wave.clear()

func _count(kind: String) -> void:
	reactions[kind] = int(reactions.get(kind,0))+1

# --- The event ----------------------------------------------------------------------

func _raised(point: Vector3, _radius: float, strength: float, kind: String, detail: Dictionary) -> void:
	if not enabled or life == null or not is_instance_valid(life) or not life.active or life.survey == null: return
	var at: Vector3 = life.to_local(point)
	match kind:
		"gust": _gust(at,strength,detail)
		"poke": _poke(at,strength)
		"figure": _figure(at,strength)
		"night": _night(at)
		"dawn": _dawn()

## A gust: each creature in its path answers as the head reaches it.
func _gust(origin: Vector3, power: float, detail: Dictionary) -> void:
	var front := detail.duplicate()
	front.origin = origin
	if str(front.get("shape","")) == "lane":
		var way: Vector3 = life.global_basis.inverse()*Vector3(front.way)
		way.y = 0.0
		if way.length_squared() < 0.000001: return
		front.way = way.normalized()
	var now: float = life.clock
	for site in life.present("fish"):
		var hit := _front(front,site.p,1.0)
		if hit.y*power > FISH_GUST: _later(now+hit.x,_dart.bind(site,_downwind(front,site.p),hit.y*power,Vector3.INF))
	for site in life.present("frog"):
		var hit := _front(front,site.p,1.0)
		if hit.y*power > FROG_GUST: _later(now+hit.x+_hash(site)*FROG_BEAT.z,_plop.bind(site,hit.y*power))
	for site in life.present("bird"):
		var bird: Dictionary = life._birds.birds[site.slot]
		var hit := _front(front,Vector3(bird.x,bird.y,bird.z),BIRD_MARGIN)
		if hit.y*power > BIRD_GUST: _later(now+hit.x,_lift.bind(site,_downwind(front,Vector3(bird.x,bird.y,bird.z)),hit.y*power))
	if _fireflies_lit():
		for site in life.present("firefly"):
			var hit := _front(front,site.p,FLY_MARGIN)
			if hit.y > 0.05: _later(now+hit.x,_scatter.bind(site,_downwind(front,site.p),hit.y*power))
	# Deer take the breeze's own gust fronts in their stride; only a sent gust alarms them.
	var deer: Array = [] if bool(front.get("steady",false)) else _deer()
	for m: Dictionary in deer:
		var p := _plane(m.p)
		var hit := _front(front,p,DEER_GUST_MARGIN)
		if hit.y > 0.05: _later(now+hit.x,_alarm.bind(m,3 if hit.y*power > DEER_GUST_BOLT else 1))
	var heron := _heron()
	if not heron.is_empty():
		var hit := _front(front,heron.spot,1.0)
		if hit.y*power > HERON_GUST: _later(now+hit.x,_heron_off.bind(heron))

## A tap on the clay: rings if it landed in water; frogs in, fish scatter and
## come back to nose at it, deer and heron look up or go.
func _poke(at: Vector3, strength: float) -> void:
	var now: float = life.clock
	var flat := Vector2(at.x,at.z)
	var rings := at
	if life.survey.wet_at(flat):
		rings.y = life.survey.level_at(flat)
		life.ripple(rings,0.55)
	for site in life.present("frog"):
		var d := _reach(site.p,at)
		if d < FROG_POKE: _later(now+FROG_BEAT.x+d*FROG_BEAT.y+_hash(site)*FROG_BEAT.z,_plop.bind(site,strength))
	for site in life.present("fish"):
		var d := _reach(site.p,at)
		if d < FISH_POKE:
			var away := _away(site.p,at)
			_later(now+d*0.05,_dart.bind(site,away,strength*(1.0-0.5*d/FISH_POKE),rings))
	for m: Dictionary in _deer():
		var d := _reach(_plane(m.p),at)
		if d < DEER_POKE.x: _later(now+0.15+d*0.03,_alarm.bind(m,2 if d < DEER_POKE.y else 1))
	var heron := _heron()
	if not heron.is_empty() and _reach(heron.spot,at) < HERON_POKE: _later(now+0.2,_heron_off.bind(heron))

## A stride of the wanderer, or its being set down or standing a while.
func _figure(at: Vector3, pace: float) -> void:
	var now: float = life.clock
	var flat := Vector2(at.x,at.z)
	var wading: bool = life.survey.wet_at(flat)
	var frog_reach := FROG_FIGURE+FROG_FIGURE_RUN*pace
	for site in life.present("frog"):
		var d := _reach(site.p,at)
		if d >= frog_reach: continue
		if site.mode == "swim": _keep_under(site)
		elif pace > 0.2: _later(now+FROG_BEAT.x+_hash(site)*FROG_BEAT.z,_plop.bind(site,pace))
	for site in life.present("fish"):
		var d := _reach(site.p,at)
		if wading and d < FISH_SHY:
			_dart(site,_away(site.p,at),pace,Vector3.INF)
		elif d < FISH_FOLLOW:
			_follow(site,at)
	for m: Dictionary in _deer():
		var d := _reach(_plane(m.p),at)
		var level := 3 if d < DEER_FIGURE.z or (pace > 0.8 and d < DEER_RUN) else (2 if d < DEER_FIGURE.y else (1 if d < DEER_FIGURE.x else 0))
		if level > 0: _later(now+0.1,_alarm.bind(m,level))
	var heron := _heron()
	if not heron.is_empty() and _reach(heron.spot,at) < HERON_FIGURE: _later(now+0.3,_heron_off.bind(heron))

# --- Each frame ------------------------------------------------------------------

func advance(step: float) -> void:
	_watch_figure()
	if not enabled: return
	var now: float = life.clock
	if not _pending.is_empty():
		var due: Array = []
		for i in range(_pending.size()-1,-1,-1):
			if float(_pending[i][0]) <= now:
				due.append(_pending[i][1])
				_pending.remove_at(i)
		for call: Callable in due: call.call()
	if not _fish.is_empty(): _step_fish(step)
	if not _flies.is_empty(): _step_flies(step)
	if not _wave.is_empty(): _step_wave()

func _later(at: float, call: Callable) -> void:
	_pending.append([at,call])

## The snake watches the wanderer as it watches you, while there is one.
func _watch_figure() -> void:
	var snakes: Node = life.snakes
	if snakes == null or not "watcher" in snakes: return
	var wanderer: Variant = life.scene.get("wanderer")
	var seen := Vector3.INF
	if enabled and wanderer != null and snakes.showing() != "" and wanderer.has_figure():
		seen = life.to_local((wanderer.figure as Node3D).global_position+Vector3.UP*FIGURE_EYE)
	snakes.watcher = seen

# --- Fish --------------------------------------------------------------------------

## Dart `way` (a flat unit vector) as far as `force` says, into water it can
## swim; then nose at `nose` if it is set, or drift home.
func _dart(site: Dictionary, way: Vector3, force: float, nose: Vector3) -> void:
	if not _alive(site): return
	var reach := lerpf(DART.x,DART.y,clampf(force,0.0,1.0))
	var state := _fish_state(site)
	state.goal = _wet_goal(site,way,reach)
	state.spring = DART_SPRING
	state.stage = "dart"
	state.hush = DART_HUSH
	state.until = life.clock+lerpf(DART_HOLD.x,DART_HOLD.y,_hash(site))
	state.nose = nose
	_count("fish_dart")

## Drift over to the wanderer's shadow at the bank and hang there.
func _follow(site: Dictionary, at: Vector3) -> void:
	if not _alive(site): return
	var state := _fish_state(site)
	if state.stage == "dart": return
	if state.stage != "follow": _count("fish_follow")
	state.stage = "follow"
	state.goal = _toward(site,at)
	state.spring = HOME_SPRING
	state.hush = NOSE_HUSH
	state.look = at
	state.until = life.clock+FOLLOW_HOLD

func _fish_state(site: Dictionary) -> Dictionary:
	if not site.has("notice"):
		site.notice = {"x":Vector3(site.get("nudge",Vector3.ZERO)),"v":Vector3.ZERO,"goal":Vector3.ZERO,"spring":HOME_SPRING,
			"stage":"settle","hush":0.0,"until":0.0,"nose":Vector3.INF,"look":Vector3.INF,"yaw":0.0}
		_fish.append(site)
	return site.notice

func _step_fish(step: float) -> void:
	var now: float = life.clock
	for i in range(_fish.size()-1,-1,-1):
		var site: Dictionary = _fish[i]
		if not _alive(site):
			_calm_fish(site)
			_fish.remove_at(i)
			continue
		var s: Dictionary = site.notice
		if now >= float(s.until):
			match s.stage:
				"dart":
					if s.nose != Vector3.INF:
						# Back to nose at the rings.
						s.stage = "nose"
						s.goal = _toward(site,s.nose)
						s.look = s.nose
						s.spring = HOME_SPRING
						s.hush = NOSE_HUSH
						s.until = now+lerpf(NOSE_TIME.x,NOSE_TIME.y,_hash(site))
					else: _settle(s)
				"nose","follow": _settle(s)
		_spring(s,step)
		site.hush = move_toward(float(site.get("hush",0.0)),float(s.hush),step*HUSH_RATE)
		site.nudge = s.x
		# Faces where it swims when quick, else what it is nosing at.
		var velocity: Vector3 = s.v
		var speed := velocity.length()
		if speed > 0.05: s.yaw = atan2(velocity.x,velocity.z)
		var weight := clampf(speed/0.4,0.0,1.0)
		if s.look != Vector3.INF and s.stage in ["nose","follow"] and speed < 0.15:
			var p: Vector3 = site.p
			var look: Vector3 = s.look
			if Vector2(look.x-p.x,look.z-p.z).length() > 0.1:
				s.yaw = lerp_angle(float(s.yaw),atan2(look.x-p.x,look.z-p.z),1.0-exp(-step*2.0))
			weight = maxf(weight,float(site.hush))
		weight = maxf(weight,float(site.hush))
		site.steer = Vector2(float(s.yaw),weight)
		if s.stage == "settle" and Vector3(s.x).length() < 0.02 and speed < 0.02 and float(site.hush) <= 0.0:
			_calm_fish(site)
			_fish.remove_at(i)

func _settle(s: Dictionary) -> void:
	s.stage = "settle"
	s.goal = Vector3.ZERO
	s.spring = HOME_SPRING
	s.hush = 0.0
	s.look = Vector3.INF
	s.until = INF

## Everything the reaction wrote into the fish, taken back.
func _calm_fish(site: Dictionary) -> void:
	for key in ["notice","nudge","hush","steer"]: site.erase(key)

## Where a fish aims (an offset from home) to come up short of `point`,
## within NOSE_REACH, in water.
func _toward(site: Dictionary, point: Vector3) -> Vector3:
	var home: Vector3 = site.home
	var way := Vector3(point.x-home.x,0.0,point.z-home.z)
	var length := way.length()
	if length < 0.01: return Vector3.ZERO
	return _wet_goal(site,way/length,clampf(length-NOSE_GAP,0.0,NOSE_REACH))

## The furthest of a few offsets near `way`·`reach` from home that is still
## in water (with room for the overshoot); zero when none is.
func _wet_goal(site: Dictionary, way: Vector3, reach: float) -> Vector3:
	var home: Vector3 = site.home
	for share: float in [1.0,0.65,0.35]:
		for turn: float in [0.0,0.45,-0.45,0.9,-0.9]:
			var goal := way.rotated(Vector3.UP,turn)*reach*share
			var tip := home+goal*1.2
			if life.survey.wet_at(Vector2(tip.x,tip.z)): return goal
	return Vector3.ZERO

# --- Frogs ------------------------------------------------------------------------

## A sitting frog leaps into its water and stays under a while.
func _plop(site: Dictionary, force: float) -> void:
	if not _alive(site): return
	if site.mode == "swim":
		_keep_under(site)
		return
	if site.mode != "sit": return
	site.lurk = lerpf(LURK.x,LURK.y,clampf(force,0.0,1.0))
	life._hop(site,site.landing,"in")
	_count("frog_plop")

## A swimming frog stays under at least LURK_NEAR s more, within LURK_MOST.
func _keep_under(site: Dictionary) -> void:
	site.lurk = minf(maxf(float(site.get("lurk",0.0)),float(site.age)-3.5+LURK_NEAR),LURK_MOST)

# --- Gulls ------------------------------------------------------------------------

## A gull lifts off the gust and wheels away downwind.
func _lift(site: Dictionary, way: Vector3, force: float) -> void:
	if not _alive(site) or site.slot < 0: return
	var bird: Dictionary = life._birds.birds[site.slot]
	if float(bird.delay) >= 0.0: return
	var k := clampf(force,0.0,1.0)
	bird.vx = float(bird.vx)+way.x*lerpf(BIRD_PUSH.x,BIRD_PUSH.y,k)
	bird.vz = float(bird.vz)+way.z*lerpf(BIRD_PUSH.x,BIRD_PUSH.y,k)
	bird.vy = float(bird.vy)+lerpf(BIRD_CLIMB.x,BIRD_CLIMB.y,k)
	bird.flap = 1.0
	bird.mode = "pullup"
	bird.timer = lerpf(BIRD_PULL.x,BIRD_PULL.y,k)
	if _rng.randf() < WHEEL*k and bird.has("spin"): bird.spin = -float(bird.spin)
	_count("bird_lift")

# --- Fireflies ----------------------------------------------------------------------

func _fireflies_lit() -> bool:
	var flies: Node3D = life.scene.get("_fireflies")
	return flies != null and flies.visible

## A firefly is blown off its place and drifts back.
func _scatter(site: Dictionary, way: Vector3, force: float) -> void:
	if not _alive(site) or site.slot < 0: return
	var k := clampf(force,0.0,1.0)
	var jitter := Vector3(_rng.randf_range(-1.0,1.0),_rng.randf_range(-0.3,1.0),_rng.randf_range(-1.0,1.0))*FLY_JITTER
	var goal := way*lerpf(FLY_SCATTER.x,FLY_SCATTER.y,k)+Vector3.UP*FLY_RISE*k+jitter
	if not site.has("notice"):
		site.notice = {"x":Vector3.ZERO,"v":Vector3.ZERO}
		_flies.append(site)
	var s: Dictionary = site.notice
	s.goal = goal
	s.spring = FLY_SPRING
	s.stage = "out"
	s.until = life.clock+_rng.randf_range(FLY_HOLD.x,FLY_HOLD.y)
	_count("firefly_scatter")

func _step_flies(step: float) -> void:
	var now: float = life.clock
	for i in range(_flies.size()-1,-1,-1):
		var site: Dictionary = _flies[i]
		if not site.here or site.slot < 0:
			site.erase("notice")
			_flies.remove_at(i)
			continue
		var s: Dictionary = site.notice
		if s.stage == "out" and now >= float(s.until):
			s.stage = "home"
			s.goal = Vector3.ZERO
			s.spring = FLY_HOME
		_spring(s,step)
		var x: Vector3 = s.x
		if s.stage == "home" and x.length() < 0.01 and Vector3(s.v).length() < 0.01:
			x = Vector3.ZERO
			site.erase("notice")
			_flies.remove_at(i)
		_place_fly(site,x)

func _place_fly(site: Dictionary, offset: Vector3) -> void:
	var flies: MultiMesh = life.scene._fireflies.multimesh
	if site.slot < 0 or site.slot >= flies.instance_count: return
	flies.set_instance_transform(site.slot,Transform3D(Basis.IDENTITY,life.to_global(Vector3(site.p)+offset)))

## Night falls: every settled firefly goes dark, then each lights in turn,
## out from `at`, on the first flash of its own cycle.
func _night(at: Vector3) -> void:
	var sites: Array = life.present("firefly")
	if sites.is_empty(): return
	var flies: MultiMesh = life.scene._fireflies.multimesh
	var motion: float = float(life.scene.get("_motion_time")) if life.scene.get("_motion_time") != null else 0.0
	var now: float = life.clock
	# From the firefly nearest where you look.
	var start: Vector3 = sites[0].p
	for site in sites:
		if _reach(site.p,at) < _reach(start,at): start = site.p
	_wave.clear()
	for site in sites:
		var slot: int = site.slot
		if slot < 0 or slot >= flies.instance_count or life._fading_flies.has(slot): continue
		var delay := WAVE_LEAD+_reach(site.p,start)/WAVE_SPEED+_hash(site)*WAVE_SCATTER
		# Its blink cycle (shaders/reference_fireflies.gdshader) starts as the
		# wave reaches it: a flash is its first sight. The drift moves with the
		# phase, unseen while it is dark.
		var source: Color = life._firefly_source[slot][1]
		var period := 2.8+source.b*2.6
		source.r = fposmod(-(motion+delay/maxf(float(life.pace),0.001))/period,1.0)
		life._firefly_source[slot][1] = source
		life._fly_presence(slot,0.0)
		_wave.append({"site":site,"at":now+delay})
	_count("firefly_wave")

func _step_wave() -> void:
	var now: float = life.clock
	for i in range(_wave.size()-1,-1,-1):
		var entry: Dictionary = _wave[i]
		var site: Dictionary = entry.site
		# A firefly leaving or arriving is LandLife's to fade.
		if not site.here or site.leaving or site.slot < 0 or life._fading_flies.has(site.slot):
			_wave.remove_at(i)
			continue
		var presence := smoothstep(float(entry.at),float(entry.at)+WAVE_RISE,now)
		life._fly_presence(site.slot,presence)
		if presence >= 1.0: _wave.remove_at(i)

# --- Dawn -------------------------------------------------------------------------

## Day breaks: a few songs from the woods at once, if there is anyone to sing.
func _dawn() -> void:
	var audio: Variant = life.scene.get("_ambient_audio")
	var nature: Node = audio.get("nature") if audio != null else null
	if nature == null or not nature.has_method("call_bird"): return
	var presence := float(nature.get("song_presence"))
	if presence < 0.15: return
	var clips: Dictionary = nature.get("clips")
	var points: PackedVector3Array = nature.get("song_points")
	var listener: Vector3 = life.scene.camera.global_position
	var now: float = life.clock
	for delay: float in CHORUS:
		var song: String = CHORUS_SONGS[_rng.randi_range(0,CHORUS_SONGS.size()-1)]
		if not clips.has(song): continue
		var point := points[_rng.randi_range(0,points.size()-1)] if not points.is_empty() else listener+Vector3(_rng.randf_range(-12,12),_rng.randf_range(-1,3),-10)
		_later(now+delay+_rng.randf_range(0.0,0.2),func() -> void: nature.call_bird(song,point,CHORUS_GAIN*presence))
	_count("dawn_chorus")

# --- Deer and heron ------------------------------------------------------------------

func _deer() -> Array:
	var state: Dictionary = life.moments._deer_state
	return state.get("members",[])

## 1: the head comes up and the ears go round (the Alert clip). 2 and 3: the
## same beat, then off into the trees, stepping briskly or bolting.
func _alarm(m: Dictionary, level: int) -> void:
	if not _member(m): return
	if m.phase == "graze":
		if m.down: m.ups = 0
		m.down = false
		m.next = maxf(float(m.next),float(m.age)+lerpf(DEER_LOOK.x,DEER_LOOK.y,_rng.randf()))
	_count("deer_alarm")
	if level >= 2: _later(life.clock+DEER_TENSE,_flee.bind(m,DEER_BOLT if level >= 3 else DEER_STEP))

## Still one of the deer on show (a visit ends and the next is new).
func _member(m: Dictionary) -> bool:
	if m.phase == "gone": return false
	for other: Dictionary in _deer():
		if is_same(other,m): return true
	return false

func _flee(m: Dictionary, hurry: float) -> void:
	if not _member(m): return
	m.hurry = maxf(float(m.get("hurry",1.0)),hurry)
	if m.phase == "out": return
	var into: Vector2 = life.moments._deer_state.into
	var cover: Vector2 = m.from if m.phase == "in" else Vector2(m.p)+into*4.2
	m.phase = "out"
	m.age = 0.0
	m.from = m.p
	m.to = cover
	_count("deer_flee")

func _heron() -> Dictionary:
	var state: Dictionary = life.moments._heron_state
	return state if str(state.get("phase","")) == "stand" else {}

## A standing heron has had enough: it goes once it finishes what it is at.
func _heron_off(state: Dictionary) -> void:
	if not is_same(state,life.moments._heron_state) or str(state.get("phase","")) != "stand": return
	state.stay = minf(float(state.stay),float(state.age)+HERON_BEAT)
	_count("heron_off")

# --- Helpers ------------------------------------------------------------------------

## A gust's front at `p` (life-local): Vector2(seconds after it went until the
## head is there, the share of its air there), share 0 where it never comes.
## `margin` is how far outside the air something still feels it.
func _front(front: Dictionary, p: Vector3, margin: float) -> Vector2:
	var origin: Vector3 = front.origin
	var rel := Vector3(p.x-origin.x,0.0,p.z-origin.z)
	var along := rel.length()
	var across := 0.0
	var spread := margin
	if str(front.shape) == "lane":
		var way: Vector3 = front.way
		along = rel.dot(way)
		across = absf(rel.dot(way.cross(Vector3.UP)))
		spread = float(front.across)+margin
	var from := float(front.from)
	var span := maxf(float(front.span),0.01)
	if across > spread or along < from-margin or along > from+span+margin: return Vector2.ZERO
	var k := clampf((along-from)/span,0.0,1.0)
	# A gust front (studies/gust_fronts.gd) runs at a steady pace and keeps
	# its strength across the plate; a sent gust's head eases out and fades.
	var steady := bool(front.get("steady",false))
	var u := k if steady else 1.0-sqrt(1.0-k)
	var share := (1.0 if steady else 1.0-smoothstep(0.55,1.0,u))*(1.0-smoothstep(spread-margin,spread,across))
	if str(front.shape) != "lane": share *= 1.0-smoothstep(from+span,from+span+margin,along)
	return Vector2(float(front.wind_up)+u*float(front.run),share)

## The way a gust pushes at `p`: along its lane, or out from a burst.
func _downwind(front: Dictionary, p: Vector3) -> Vector3:
	if str(front.shape) == "lane": return front.way
	return _away(p,front.origin)

func _away(p: Vector3, from: Vector3) -> Vector3:
	var way := Vector3(p.x-from.x,0.0,p.z-from.z)
	return way.normalized() if way.length_squared() > 0.0001 else Vector3.FORWARD.rotated(Vector3.UP,_rng.randf()*TAU)

static func _reach(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

static func _plane(p: Vector2) -> Vector3:
	return Vector3(p.x,0.0,p.y)

func _alive(site: Dictionary) -> bool:
	return site.here and not site.leaving

func _hash(site: Dictionary) -> float:
	return life._hash(site,77)

## One step of a damped spring from `x` toward `goal` (stiffness and damping
## in `spring`), in small steps so a stiff one stays steady.
static func _spring(s: Dictionary, step: float) -> void:
	var goal: Vector3 = s.goal
	var spring: Vector2 = s.spring
	var x: Vector3 = s.x
	var v: Vector3 = s.v
	var count := maxi(1,ceili(step/0.012))
	var h := step/float(count)
	for i in range(count):
		v += ((goal-x)*spring.x-v*spring.y)*h
		x += v*h
	s.x = x
	s.v = v
