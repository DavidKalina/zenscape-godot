extends RefCounted
## The line's moves (endless flight; docs/design/endless-flight/
## spec-wild-loop.md, lane `line`): what each of NearMiss's moments was,
## read off the plane and the land, and the held moves no single moment is.
## NearMiss (near_miss.gd) owns one, steps it each frame after its own
## scoring and chains what it gives.
##
## Moments NearMiss scores (`dress`): the pull-out, graze and thread stay,
## and become
## - late pull: a pull-out (close or razor) that ends a dive of DIVE_MIN s
##   or more down a path steeper than DIVE_SHARE, falling DIVE_DROP m or
##   more; the drop counts (DIVE_REF m is the most it pays for).
## - knife edge: a thread or graze with the wings rolled past KNIFE.
## - inverted: any moment flown rolled past INVERTED (upside down).
## Held moves (`step`), each scored when it lets go (GRACE s off) after its
## least time held, its points by how long (to HELD_TOP times the least)
## and how close (its own band):
## - carve: rolled past CARVE_ROLL, turning, low (CARVE_LOW spans) over open
##   land or water.
## - canopy run: skimming the treetops (CANOPY_LOW spans over a crown).
## - canyon run: walls on both sides at once (level rays CANYON_REACH spans
##   past each wingtip, land or stone, not trees).
## - climb / surf: up / down a face steeper than SLOPE, hugging it (HUG
##   spans), the path along the fall line climbing / falling past PATH.
## - slalom: SLALOM_PASSES or more trees passed abeam (within SLALOM_REACH
##   spans past a wingtip, at the plane's height) on alternating sides, each
##   within SLALOM_GAP s of the last; scored when the run ends.
## - stack orbit: round one rock pillar (a sea stack) within ORBIT_REACH
##   spans of its face, ORBIT_TURN of a turn about its middle.
## While a held move is under way (`holding`), the chain does not bank.
##
## Every move gets its glyph (near_glyphs.gd), the kind of land under it
## (`terrain_at`: meadow, forest, canyon, mountain, sea, river, lake,
## ruin) and its difficulty (`difficulty`): what it adds to the chain's
## multiplier before the repeat cut (NearMiss `_chain`).

const WorldScale = preload("res://scripts/world_scale.gd")

## Base points of the held moves and the renamed moments' gain on theirs.
const BASE := {"carve":150.0,"canopy run":220.0,"canyon run":320.0,"climb":220.0,"surf":200.0,
	"slalom":110.0,"stack orbit":420.0}
const GAIN := {"knife edge":1.5,"inverted":2.0}
## Held moves: least seconds held.
const HELD_MIN := {"carve":1.0,"canopy run":1.2,"canyon run":1.2,"climb":1.0,"surf":1.0}
const HELD_TOP := 3.0
const GRACE := 0.35
## Glyphs (near_glyphs.gd ids) of the moves that have their own.
const GLYPH := {"late pull":"dive","knife edge":"knife","inverted":"inverted","carve":"carve",
	"canopy run":"canopy","canyon run":"canyon","climb":"climb","surf":"surf","slalom":"slalom",
	"stack orbit":"orbit"}

const KNIFE := deg_to_rad(60.0)
const INVERTED := deg_to_rad(120.0)
const FAST_FROM := 0.8
const CARVE_ROLL := deg_to_rad(40.0)
const CARVE_LOW := 4.0
const CARVE_TURN := 0.3
const CANOPY_LOW := 1.5
const CANYON_REACH := 10.0
const SLOPE := 0.7
const HUG := 5.0
const PATH := 0.2
const SLALOM_REACH := 3.0
const SLALOM_GAP := 1.8
const SLALOM_PASSES := 3
const ORBIT_REACH := 12.0
const ORBIT_TURN := 1.4*PI
const ORBIT_LOST := 1.0
const DIVE_SHARE := 0.35
const DIVE_MIN := 0.8
const DESCEND := 0.12
const DIVE_DROP := 20.0
const DIVE_REF := 80.0
## A dive is remembered this long after it stops descending (s), for its
## pull-out.
const DIVE_KEEP := 2.5

## The difficulty's parts (see `difficulty`).
const DIFF_BASE := 0.3
const DIFF_CLOSE := 0.5
const DIFF_RAZOR := 0.35
const DIFF_NEAR_CLOSE := 0.15
const DIFF_FAST := 0.6
const DIFF_TIGHT := 0.7
const DIFF_KNIFE := 0.5
const DIFF_INVERTED := 0.8
const DIFF_DIVE := 0.8
const DIFF_HELD := 0.4

## A rich line's name by its kinds and multiplier (placeholder words; the
## user names them): [kinds at least, multiplier at least, name], best last.
const NAMES := [[3,3.0,"Fine Line"],[4,5.0,"Bold Line"],[5,7.0,"Wild Line"],[7,9.5,"Legend Line"]]

## A held move under way.
class Hold:
	var t := 0.0
	var off := 0.0
	var least := INF
	var sum := 0.0
	var pace := 0.0
	var knife := 0.0
	var inv := 0.0
	var width := INF
	var at := Vector3.ZERO
	var surface := "land"
	func feed(dt: float, clear: float, p: float, roll: float, where: Vector3) -> void:
		t += dt
		off = 0.0
		least = minf(least,clear)
		sum += clear*dt
		pace = maxf(pace,p)
		if roll > INVERTED: inv += dt
		elif roll > KNIFE: knife += dt
		at = where
	func wipe() -> void:
		t = 0.0
		off = 0.0
		least = INF
		sum = 0.0
		pace = 0.0
		knife = 0.0
		inv = 0.0
		width = INF

## True while a held move (or a slalom's run, or an orbit) is under way.
var holding := false
## Held moves done, waiting to be chained (one a frame).
var pending: Array[Dictionary] = []

var _holds := {}
var _clock := 0.0
var _last_p := Vector3.INF
var _last_h := 0.0
var _vel := Vector3.ZERO
var _turn := 0.0
var _ray: PhysicsRayQueryParameters3D
## The dive: its steep time, its top (world y), how far down, how long since
## it stopped descending (INF: none).
var _dive_t := 0.0
var _dive_top := 0.0
var _dive_drop := 0.0
var _dive_since := INF
## The slalom: trees abeam last frame by side, the run's passes, last side
## and time, its least gap.
var _abeam := {-1:false,1:false}
var _run := 0
var _run_side := 0
var _run_t := -INF
var _run_least := INF
var _run_at := Vector3.ZERO
var _run_pace := 0.0
## The orbit: the pillar's id and middle, the angle round it, how far round.
var _orbit_id := ""
var _orbit_c := Vector2.ZERO
var _orbit_a := 0.0
var _orbit_sum := 0.0
var _orbit_least := INF
var _orbit_lost := 0.0

func _init() -> void:
	for name: String in HELD_MIN: _holds[name] = Hold.new()

## Everything under way dropped (a scrape, a crash, a respawn, landing).
func drop() -> void:
	for h: Hold in _holds.values(): h.wipe()
	pending.clear()
	holding = false
	_dive_t = 0.0
	_dive_since = INF
	_run = 0
	_run_t = -INF
	_orbit_id = ""
	_orbit_sum = 0.0

static func roll_of(plane: RefCounted) -> float:
	return wrapf(float(plane.bank)+float(plane.spin),-PI,PI)

## The plane's path (m/s, smoothed) and turn rate (rad/s), for drivers.
func path() -> Vector3:
	return _vel

func turn_rate() -> float:
	return _turn

# --- Held moves -------------------------------------------------------------------

## One frame after NearMiss's measuring (`near` its clearances).
func step(delta: float, game: Node3D, near: RefCounted) -> void:
	_clock += delta
	var plane = game.plane
	if not bool(game.hand_landing.flying()) or delta <= 0.0:
		drop()
		_last_p = Vector3.INF
		return
	var p: Vector3 = plane.position
	var h := float(plane.heading)
	if _last_p != Vector3.INF:
		_vel = _vel.lerp((p-_last_p)/delta,1.0-exp(-delta/0.1))
		_turn = lerpf(_turn,wrapf(h-_last_h,-PI,PI)/delta,1.0-exp(-delta/0.15))
	_last_p = p
	_last_h = h
	var span := WorldScale.span
	var cruise := maxf(float(plane.cruise()),1.0)
	var speed := float(plane.speed)
	var pace := speed/cruise
	var fast := pace >= FAST_FROM
	var roll := absf(roll_of(plane))
	var clear := float(near.ground_clear)
	var surface := str(near.ground_surface)
	var field = game.field
	# Carve: rolled hard, turning, low over open land or water.
	var carving := fast and roll > CARVE_ROLL and roll < INVERTED and clear < CARVE_LOW*span \
		and surface in ["land","water"] and absf(_turn) > CARVE_TURN
	_held("carve",carving,clear,pace,roll,p,surface,delta,game,CARVE_LOW*span)
	# Canopy run: low over the crowns.
	_held("canopy run",fast and surface == "tree" and clear < CANOPY_LOW*span,clear,pace,roll,p,"tree",delta,game,CANOPY_LOW*span)
	# Canyon run: walls both sides at once.
	var walls := _walls(game,p,h,span) if fast and clear < 40.0*span else INF
	var canyon: Hold = _holds["canyon run"]
	if walls < INF: canyon.width = minf(canyon.width,walls)
	_held("canyon run",walls < INF,clear,pace,roll,p,"land",delta,game,HUG*span)
	# Climb and surf: along the fall line of a steep face, hugging it.
	var climbing := false
	var surfing := false
	if fast and clear < HUG*span and surface in ["land","stone"]:
		var e := 2.0
		var grad := Vector2(float(field.height(p.x+e,p.z))-float(field.height(p.x-e,p.z)),
			float(field.height(p.x,p.z+e))-float(field.height(p.x,p.z-e)))/(2.0*e)
		var steep := grad.length()
		if steep > SLOPE:
			var along := grad.dot(Vector2(-sin(h),-cos(h)))/steep
			climbing = along > 0.5 and _vel.y > PATH*speed
			surfing = along < -0.5 and _vel.y < -PATH*speed
	_held("climb",climbing,clear,pace,roll,p,"land",delta,game,HUG*span)
	_held("surf",surfing,clear,pace,roll,p,"land",delta,game,HUG*span)
	# The dive, for a late pull: a descent (past DESCEND of the speed) from
	# its top, and its time steeper than DIVE_SHARE.
	if _vel.y < -DESCEND*speed:
		if _dive_since > DIVE_KEEP:
			_dive_top = p.y
			_dive_t = 0.0
		_dive_since = 0.0
		if _vel.y < -DIVE_SHARE*speed: _dive_t += delta
		_dive_drop = _dive_top-p.y
	else:
		_dive_since += delta
	_slalom(game,p,h,span,pace,fast)
	_orbit(game,p,span,pace,fast,delta)
	holding = _run >= 2 or (_orbit_id != "" and absf(_orbit_sum) > 0.5*PI)
	for h2: Hold in _holds.values():
		if h2.t > 0.3: holding = true

## One held move's frame: fed while `on`, scored once it has been off GRACE s.
func _held(kind: String, on: bool, clear: float, pace: float, roll: float, p: Vector3, surface: String, delta: float, game: Node3D, band: float) -> void:
	var hold: Hold = _holds[kind]
	if on:
		hold.feed(delta,maxf(clear,0.0),pace,roll,p)
		hold.surface = surface
		return
	if hold.t <= 0.0: return
	hold.off += delta
	if hold.off < GRACE: return
	var least_t := float(HELD_MIN[kind])
	if hold.t >= least_t:
		var mean := hold.sum/maxf(hold.t,0.001)
		var k := clampf(1.0-mean/band,0.0,1.0)
		var m := _held_move(kind,hold.t,least_t,k,hold.least,hold.at,hold.surface,hold.pace)
		if hold.inv > 0.6*hold.t: m.attitude = "inverted"
		elif hold.knife > 0.6*hold.t: m.attitude = "knife"
		if hold.width < INF: m.width = hold.width
		_finish(m,game)
	hold.wipe()

## A held move's moment.
func _held_move(kind: String, held: float, least_t: float, k: float, least: float, at: Vector3, surface: String, pace: float) -> Dictionary:
	var points := float(BASE[kind])*minf(held/least_t,HELD_TOP)*(1.0+3.0*k*k)*clampf(pace,0.5,2.0)
	var band := "razor" if k > 0.85 else ("close" if k > 0.6 else "near")
	return {"kind":kind,"of":kind,"band":band,"points":points,"k":k,"clear":least,"at":at,"surface":surface,
		"pace":pace,"held":held,"held_min":least_t,"attitude":"","under":false,
		"id":hash(Vector2i(floori(at.x/30.0),floori(at.z/30.0)))}

## Glyph, land and difficulty, then queued for the chain.
func _finish(m: Dictionary, game: Node3D) -> void:
	if str(m.attitude) == "inverted": m.points = float(m.points)*float(GAIN.inverted)
	elif str(m.attitude) == "knife": m.points = float(m.points)*float(GAIN["knife edge"])
	m.glyph = str(GLYPH.get(m.kind,""))
	m.terrain = terrain_at(game,m.at,str(m.surface))
	m.diff = difficulty(m)
	pending.append(m)

## The wall-to-wall width (m) when land or stone stands within CANYON_REACH
## spans of both wingtips on a level line, else INF.
func _walls(game: Node3D, p: Vector3, h: float, span: float) -> float:
	if _ray == null:
		_ray = PhysicsRayQueryParameters3D.new()
		_ray.collision_mask = 1
	var space: PhysicsDirectSpaceState3D = game.get_world_3d().direct_space_state
	var right := Vector3(cos(h),0.0,-sin(h))
	var reach := span*0.5+CANYON_REACH*span
	var width := 0.0
	for side: float in [-1.0,1.0]:
		_ray.from = p
		_ray.to = p+right*side*reach
		var hit := space.intersect_ray(_ray)
		if hit.is_empty(): return INF
		var node := hit.collider as Node
		if node != null and game.trees != null and game.trees.is_ancestor_of(node): return INF
		width += p.distance_to(hit.position)
	return width

## Trees passing abeam, side by side.
func _slalom(game: Node3D, p: Vector3, h: float, span: float, pace: float, fast: bool) -> void:
	if _run > 0 and _clock-_run_t > SLALOM_GAP:
		if _run >= SLALOM_PASSES:
			var k := clampf(1.0-_run_least/(SLALOM_REACH*span),0.0,1.0)
			var m := _held_move("canopy run",1.0,1.0,k,_run_least,_run_at,"tree",_run_pace)
			m.kind = "slalom"
			m.of = "slalom"
			m.points = float(BASE.slalom)*_run*(1.0+3.0*k*k)*clampf(_run_pace,0.5,2.0)
			m.passes = _run
			m.held = float(_run)
			m.held_min = float(SLALOM_PASSES)
			_finish(m,game)
		_run = 0
	if game.trees == null or not fast or float(game.field.height(p.x,p.z)) < p.y-30.0:
		_abeam = {-1:false,1:false}
		return
	var right := Vector3(cos(h),0.0,-sin(h))
	for side: int in [-1,1]:
		var near_d := INF
		for d: float in [0.3,1.0,1.8,2.6]:
			var q := p+right*side*(span*0.5+d*span)
			if float(game.trees.top_at(q)) > p.y:
				near_d = d*span
				break
		var now := near_d < INF
		if now and not bool(_abeam[side]):
			if _run > 0 and side != _run_side and _clock-_run_t <= SLALOM_GAP:
				_run += 1
			else:
				_run = 1
				_run_least = INF
				_run_pace = 0.0
			_run_side = side
			_run_t = _clock
			_run_least = minf(_run_least,near_d)
			_run_at = p
			_run_pace = maxf(_run_pace,pace)
		_abeam[side] = now

## Round a rock pillar.
func _orbit(game: Node3D, p: Vector3, span: float, pace: float, fast: bool, delta: float) -> void:
	var pillar := _pillar_near(game,p,ORBIT_REACH*span) if fast else {}
	if pillar.is_empty() or str(pillar.id) != _orbit_id:
		if _orbit_id != "" and pillar.is_empty():
			_orbit_lost += delta
			if _orbit_lost < ORBIT_LOST: return
		_orbit_id = "" if pillar.is_empty() else str(pillar.id)
		_orbit_sum = 0.0
		_orbit_least = INF
		_orbit_lost = 0.0
		if pillar.is_empty(): return
		_orbit_c = pillar.c
		_orbit_a = atan2(p.z-_orbit_c.y,p.x-_orbit_c.x)
		return
	_orbit_lost = 0.0
	var a := atan2(p.z-_orbit_c.y,p.x-_orbit_c.x)
	_orbit_sum += wrapf(a-_orbit_a,-PI,PI)
	_orbit_a = a
	_orbit_least = minf(_orbit_least,float(pillar.d))
	if absf(_orbit_sum) >= ORBIT_TURN:
		var k := clampf(1.0-_orbit_least/(ORBIT_REACH*span),0.0,1.0)
		var m := _held_move("canopy run",1.0,1.0,k,_orbit_least,p,"stone",pace)
		m.kind = "stack orbit"
		m.of = "stack orbit"
		m.points = float(BASE["stack orbit"])*(1.0+3.0*k*k)*clampf(pace,0.5,2.0)
		m.held = absf(_orbit_sum)
		m.held_min = ORBIT_TURN
		m.id = hash(_orbit_id)
		_finish(m,game)
		_orbit_sum = 0.0
		_orbit_least = INF

## The nearest rock pillar (land_rocks.gd's) whose face is within `r` m of
## `p` and whose top is over it: {id, c (its middle, world XZ), d (m to its
## face)}, or {}.
func _pillar_near(game: Node3D, p: Vector3, r: float) -> Dictionary:
	var rocks = game.get("rocks")
	if rocks == null: return {}
	var grid: Variant = rocks.get("_grid")
	if not grid is Dictionary or (grid as Dictionary).is_empty(): return {}
	var cell := float(rocks.GRID)
	var best := {}
	var best_d := r
	var a := Vector2i(floori((p.x-r)/cell),floori((p.z-r)/cell))
	var b := Vector2i(floori((p.x+r)/cell),floori((p.z+r)/cell))
	for gz in range(a.y,b.y+1):
		for gx in range(a.x,b.x+1):
			var list: Variant = (grid as Dictionary).get(Vector2i(gx,gz))
			if list == null: continue
			for e: Array in list:
				var rec: Dictionary = e[0]
				var s: Dictionary = (rec.solid as Array)[int(e[1])]
				var xf: Transform3D = rec.xf
				if p.y > float(s.top)+xf.origin.y+2.0*WorldScale.span: continue
				var mid: Vector2 = s.mid
				var w := xf*Vector3(mid.x,0.0,mid.y)
				var d := Vector2(w.x-p.x,w.z-p.z).length()-float(s.reach)
				if d < best_d:
					best_d = d
					best = {"id":"%s/%d" % [str(rec.name),int(e[1])],"c":Vector2(w.x,w.z),"d":maxf(d,0.0)}
	return best

# --- Moments ------------------------------------------------------------------------

## A moment NearMiss scored (`m`: its kind, band, points, k, clear, at,
## surface, speed, roll, width...), named for how it was flown, given its
## glyph, land and difficulty. `cruise` the plane's.
func dress(m: Dictionary, game: Node3D, cruise: float) -> void:
	var kind := str(m.kind)
	m.of = kind
	m.attitude = ""
	m.pace = float(m.get("speed",cruise))/maxf(cruise,1.0)
	var roll := absf(wrapf(float(m.get("roll",0.0)),-PI,PI))
	if roll > INVERTED:
		m.kind = "inverted"
		m.attitude = "inverted"
		m.points = float(m.points)*float(GAIN.inverted)
	elif kind in ["thread","graze"] and roll > KNIFE:
		m.kind = "knife edge"
		m.attitude = "knife"
		m.points = float(m.points)*float(GAIN["knife edge"])
	elif kind == "pull-out" and str(m.band) != "near" and _dive_since <= DIVE_KEEP and _dive_t >= DIVE_MIN and _dive_drop >= DIVE_DROP:
		m.kind = "late pull"
		m.dive = _dive_drop
		m.points = float(m.points)*(1.0+clampf(_dive_drop/DIVE_REF,0.0,1.0))
	if kind == "pull-out":
		m.dive_seen = Vector3(_dive_t,_dive_drop,_dive_since)
		_dive_since = INF
	m.glyph = str(GLYPH.get(m.kind,""))
	m.terrain = terrain_at(game,m.at,str(m.surface))
	m.diff = difficulty(m)

## What a move adds to the multiplier before the repeat cut: DIFF_BASE, its
## closeness (kÂ²) and band, speed over cruise, an opening's tightness (its
## width, both sides measured, from one span to three), its attitude, a
## dive's drop and a held move's time past its least.
static func difficulty(m: Dictionary) -> float:
	var d := DIFF_BASE
	var k := float(m.get("k",0.0))
	d += DIFF_CLOSE*k*k
	var band := str(m.get("band","near"))
	if band == "razor": d += DIFF_RAZOR
	elif band == "close": d += DIFF_NEAR_CLOSE
	d += DIFF_FAST*clampf(float(m.get("pace",1.0))-1.0,0.0,1.0)
	if m.has("width"):
		var span := WorldScale.span
		d += DIFF_TIGHT*clampf(1.0-(float(m.width)/span-1.0)/2.0,0.0,1.0)
	var att := str(m.get("attitude",""))
	if att == "knife": d += DIFF_KNIFE
	elif att == "inverted": d += DIFF_INVERTED
	if m.has("dive"): d += DIFF_DIVE*clampf(float(m.dive)/DIVE_REF,0.0,1.0)
	if m.has("held"): d += DIFF_HELD*clampf(float(m.held)/maxf(float(m.get("held_min",1.0)),0.001)-1.0,0.0,1.0)
	return d

## The kind of land at `p` (a moment's spot; `surface` what NearMiss saw
## there): sea, river, lake, ruin, canyon, forest, mountain or meadow.
static func terrain_at(game: Node3D, p: Vector3, surface := "land") -> String:
	var field = game.field
	if field == null: return "meadow"
	var h := float(field.height(p.x,p.z))
	var water := float(game.water_at(Vector3(p.x,h+0.01,p.z)))
	var rock := false
	var rocks = game.get("rocks")
	if rocks != null and rocks.has_method("top_near"): rock = float(rocks.top_near(p,6.0)) > -INF
	if water > h:
		if not is_nan(float(field.river_y(p.x,p.z))):
			if field.has_method("ponds_in") and not (field.ponds_in(p.x-2.0,p.z-2.0,p.x+2.0,p.z+2.0) as Array).is_empty(): return "lake"
			return "river"
		return "sea"
	if surface == "stone" and not rock: return "ruin"
	if field.has_method("hall_at") and not (field.hall_at(p.x,p.z,10.0) as PackedFloat32Array).is_empty(): return "ruin"
	if field.has_method("split_at") and not (field.split_at(p.x,p.z,10.0) as PackedFloat32Array).is_empty(): return "canyon"
	if surface == "tree": return "forest"
	var trees = game.get("trees")
	if trees != null:
		var n := 0
		for o: Vector2 in [Vector2.ZERO,Vector2(12,0),Vector2(-12,0),Vector2(0,12),Vector2(0,-12)]:
			if float(trees.top_at(Vector3(p.x+o.x,p.y,p.z+o.y))) > h+1.0: n += 1
		if n >= 2: return "forest"
	var shape: Dictionary = field.shape(p.x,p.z)
	if float(shape.get("mountain",0.0)) > 0.3 or rock: return "mountain"
	var e := 3.0
	var grad := Vector2(float(field.height(p.x+e,p.z))-float(field.height(p.x-e,p.z)),
		float(field.height(p.x,p.z+e))-float(field.height(p.x,p.z-e)))/(2.0*e)
	if grad.length() > SLOPE: return "mountain"
	return "meadow"

## A rich line's name ("" for a plain one): `kinds` how many kinds of move,
## `mult` its multiplier.
static func name_for(kinds: int, mult: float) -> String:
	var out := ""
	for n: Array in NAMES:
		if kinds >= int(n[0]) and mult >= float(n[1]): out = str(n[2])
	return out
