extends Node
## The land that teaches (docs/ship/spec-ship.md, Round 2, lane
## `tutorial-land`): `game.tutorial_land` while the world is `tutorial`
## (scripts/endless/world/profiles/tutorial.gd).
##
## The contract: it reads `game.lesson.stage` when `game.get("lesson")`
## exists, else the `--lesson-stage=N` launch flag (0 GRASS, 1 TREES, 2 WATER,
## 3 PARRY, 4 GAUGE, 5 WALL, 6 DONE), and emits `broke_through` once the wall is
## broken and the plane has swapped to the wilderness.
##
##   the gating   the stage goes to the world profile (`stage`), which gates
##                what the meadow builds from then on: tree blocks committed
##                below TREES stand bare; ponds and straight reaches only
##                from WATER on. On each change the tree blocks past
##                REPLAN_PAST m are dropped and planned again under the new
##                stage, so the new land shows from there out; the near ones
##                (and their solids) stay as they stood. At WATER the land
##                past KEEP_NEAR m is built again in place (LandStream
##                `restream`), no pond comes in a square that meets the land
##                left standing, and a straight reach is
##                stamped in the first clear square ahead (AHEAD_FROM to
##                AHEAD_MOST m along the flight), so water is in reach
##                within seconds.
##   the ship     at PARRY a pirate ship (pirate_ship.gd, in her lesson temper)
##                rides at anchor on a lake stamped ahead for her (the profile's
##                `stamp_lake`: the meadow's ponds and reaches are narrower than
##                her beam), about LAKE_AT m out along the flight, broadside to
##                it; the land over its square is built again (LandStream
##                `restream` with `only`), its tree blocks planned again. She
##                shows, and fires (a stream), once that land is in. Once
##                she is out of her fire's view or far off (SHIP_LOST) a
##                second ship takes over on a new lake ahead the same way,
##                she going quiet where she is; from then on the two take
##                turns, the one left behind moored ahead (PirateShip `moor`)
##                once off the screen, so a ball is always coming. From GAUGE
##                on they stay where they are, quiet.
##   the wall     at WALL the ruin hall (tutorial_hall.gd) stands HALL_AHEAD m
##                ahead of the plane, a cracked wall across its mouth, a
##                beam of light over it; flown away from past HALL_LOST m with
##                the wall whole, it stands again ahead. A surge roll breaks
##                the wall; through the hall the land swaps to the wilderness.
##   the deck     a flat cloud deck DECK m over the turf: from under, a pale
##                ceiling; climbing into it whites the view out, descending
##                clears it. Nothing touches the flight.
##   the skip     `skip()` (the lesson's, on Backspace): the view whites out,
##                the hall stands if it does not yet, the wilderness land is
##                stepped round the far mouth, and the plane comes out of
##                the wilderness ruin SKIP_OUT m before its mouth, SKIP_OVER m
##                up, flying away from it at cruise; then the white clears and
##                `broke_through` fires as the wall's path does.

signal broke_through

const Hall = preload("res://scripts/endless/tutorial/tutorial_hall.gd")
const Ponds = preload("res://scripts/endless/land_ponds.gd")
const PirateShip = preload("res://scripts/endless/pirate_ship.gd")

enum Stage {GRASS, TREES, WATER, PARRY, GAUGE, WALL, DONE}

## The cloud deck's underside over the turf (m), and the whiteout's ramp
## (m below it to m into it).
const DECK := 60.0
const WHITE_FROM := -10.0
const WHITE_FULL := 8.0
const DECK_SIZE := 16000.0
## At WATER the land within this of the plane (m) stays as it stood (past
## its colliders, COLLIDE 70 m); the rest is built again with its ponds.
const KEEP_NEAR := 110.0
## The reach stamped ahead at WATER: its near end from this far along the
## flight (m), its square looked for out to AHEAD_MOST m.
const AHEAD_FROM := 120.0
const AHEAD_MOST := 420.0
## Tree blocks wholly past this (m) are planned again on a stage change;
## at TREES nearer (the copses come up round the plane to be grazed: the
## block it is in and its first ring stay as they stood).
const REPLAN_PAST := 420.0
const REPLAN_TREES := 160.0
## PARRY: with no room for the ship's lake ahead, tried again this often (s).
const SHIP_RETRY := 0.5
## She shows once the land over her lake is in, at the latest this long after
## she is put there (s).
const SHIP_SHOW_MOST := 4.0
## PARRY: once the ship firing has been out of her fire's view (PirateShip
## `in_view`, LESSON_SCREEN) or farther than [1] m off (flat) for [0] s on end,
## the other ship takes over on a new lake ahead: built the first time, then
## moored there (only once she is off the screen, so she never vanishes in
## view; while she is on it the one firing is moored ahead instead, once she
## is off it).
const SHIP_LOST := Vector2(0.5,650.0)
## Moored again, her lake is wanted this far ahead (m; the first is the
## profile's LAKE_AT), nearer, so she is in range soon (the pond squares put
## it 380 to 650 m off; her first ball reaches PirateShip.LESSON_FIRST).
const SHIP_AGAIN := 380.0
## The hall's mouth ahead of the plane at WALL (m), and how far off it may be
## left before it stands ahead again.
const HALL_AHEAD := 780.0
const HALL_LOST := 3000.0
## Trees held off the ruin and the way in (m).
const KEEP_RUIN := 190.0
const KEEP_WAY := 140.0
## The skip: the white's ramp in and out (s), the longest wait for the far
## land (s) and the share of it standing that is enough, and where the plane
## comes out (m before the wilderness ruin's mouth, m over its ground).
const SKIP_IN := 0.35
const SKIP_OUT_FADE := 0.8
const SKIP_WAIT := 4.0
const SKIP_WARM := 0.9
const SKIP_OUT := 70.0
const SKIP_OVER := 28.0

var game: Node3D
var world: RefCounted
var stage := -1
var hall: Node3D
var done := false
var _flag_stage := 0
var _deck: MeshInstance3D
var _white: ColorRect
var _beam: MeshInstance3D
var _turf := 0.0
## The skip: -1 not asked, else its seconds; the white over the view (0 to 1).
var _skip_t := -1.0
var _skip_white := 0.0
var _skip_at := Vector3.INF
## PARRY: the ship firing (pirate_ship.gd) and her lake (the profile's
## `stamp_lake`); the other, quiet where she was left (her twin), or null.
var ship: Node3D
var lake := {}
var spare: Node3D
## The hall being built ahead of WALL (tutorial_hall.gd `warm`).
var _hall_next: Node3D
## Where it is to stand, fixed when WALL first asks for it ([at, way]).
var _hall_spot := []
var _ship_wait := 0.0
var _ship_t := 0.0
var _ship_lost := 0.0

func setup(g: Node3D) -> void:
	name = "TutorialLand"
	game = g
	world = g.world
	for a: String in preload("res://scripts/launch_args.gd").user_args():
		if a.begins_with("--lesson-stage="): _flag_stage = clampi(a.get_slice("=",1).to_int(),0,Stage.DONE)
	var at: Vector2 = world.spawn.at
	_turf = float(game.field.height(at.x,at.y))
	if not ("--no-deck" in preload("res://scripts/launch_args.gd").user_args()): _build_deck()
	_set_stage(wanted_stage())
	_warm_hall()

func _exit_tree() -> void:
	PirateShip.cool()
	if _hall_next != null:
		_hall_next.discard()
		_hall_next.free()
		_hall_next = null

## The next hall's pieces built ahead (on a worker), so WALL has no long frame.
func _warm_hall() -> void:
	if _hall_next != null or done: return
	_hall_next = Hall.new()
	_hall_next.warm(game)

## The stage the lesson asks for (its own, else the flag's).
func wanted_stage() -> int:
	var lesson: Variant = game.get("lesson")
	if lesson != null and is_instance_valid(lesson): return int(lesson.stage)
	return _flag_stage

## Sets the flag's stage by hand (scratch drivers): as `--lesson-stage=N`.
func force_stage(s: int) -> void:
	_flag_stage = s

## Out to the wilderness at once, without the wall (the lesson's skip).
func skip() -> void:
	if done or _skip_t >= 0.0: return
	_skip_t = 0.0
	print("tutorial land: skip asked")

func _process(delta: float) -> void:
	if game == null or game.plane == null: return
	var t0 := Time.get_ticks_usec()
	var s := wanted_stage()
	if s != stage: _set_stage(s)
	FrameLog.add(&"tl_stage",(Time.get_ticks_usec()-t0)/1000.0)
	t0 = Time.get_ticks_usec()
	_step_skip(delta)
	FrameLog.add(&"tl_skip",(Time.get_ticks_usec()-t0)/1000.0)
	t0 = Time.get_ticks_usec()
	if stage == Stage.PARRY and not done and (ship == null or _left_behind(delta)): _ship_step(delta)
	FrameLog.add(&"tl_ship",(Time.get_ticks_usec()-t0)/1000.0)
	if ship != null:
		_ship_t += delta
		var shown: bool = ship.visible or _lake_in() or _ship_t > SHIP_SHOW_MOST
		# The lake's tree blocks once more as she shows: a block planned before
		# the stamp and still in flight then stood its trees in the water.
		if shown and not ship.visible: _replan_in(lake.rect)
		ship.visible = shown
		ship.quiet = stage != Stage.PARRY or not shown
	if spare != null: spare.quiet = true
	t0 = Time.get_ticks_usec()
	if stage >= Stage.WALL and hall == null and not done and bool(game.get("walk_ready")): _place_hall()
	FrameLog.add(&"tl_hall",(Time.get_ticks_usec()-t0)/1000.0)
	t0 = Time.get_ticks_usec()
	if hall != null: _watch_hall()
	FrameLog.add(&"tl_watch",(Time.get_ticks_usec()-t0)/1000.0)
	_step_deck()

func _set_stage(s: int) -> void:
	var was := stage
	stage = s
	var wet := was >= 0 and s >= Stage.WATER and was < Stage.WATER
	# Everything dry while the land kept is found: no build in flight may
	# cut a pond into it.
	if wet: world.dry = [Rect2(-1e9,-1e9,2e9,2e9)] as Array[Rect2]
	if not done: world.stage = mini(s,Stage.WALL)
	print("tutorial land: stage %d (was %d)" % [s,was])
	# PARRY's ship built ahead (PirateShip `warm`, on a worker): asked at the
	# land's setup, in the load (at WATER it ran beside WATER's own land
	# rebuild, which then took 15 ms frames for half a second); again here, a
	# no-op once asked.
	if s <= Stage.PARRY and ship == null and not done: PirateShip.warm()
	if was < 0: return
	if wet:
		_wet()
		return
	_replan(REPLAN_TREES if s == Stage.TREES else REPLAN_PAST)

## WATER: the land and tree blocks past KEEP_NEAR m built again with the
## ponds; the land left standing stays dry (a kept tree block a pond reaches
## into is planned again); a reach stamped ahead.
func _wet() -> void:
	var p: Vector3 = game.plane.position
	var at := Vector2(p.x,p.z)
	var dry: Array[Rect2] = []
	var land: Node = game.get("land")
	if land != null and land.has_method("restream"): dry = land.restream(KEEP_NEAR)
	var trees: Node = game.get("trees")
	var kept_trees: Array[Vector2i] = []
	if trees != null and ("_blocks" in trees):
		var block: float = trees.BLOCK
		for key: Vector2i in trees._blocks:
			var r := Rect2(key.x*block,key.y*block,block,block)
			if _flat_d(r,at) <= KEEP_NEAR: kept_trees.append(key)
	var v: Vector3 = game.plane.velocity
	var dir := Vector2(v.x,v.z)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(-sin(float(game.plane.heading)),-cos(float(game.plane.heading)))
	world.dry = dry
	var c: Vector2 = world.stamp_ahead(at,dir,AHEAD_FROM,AHEAD_MOST)
	print("tutorial land: water ahead at %s (%.0f m)" % [str(c.round()),c.distance_to(at)])
	_replan(KEEP_NEAR)
	# Kept tree blocks a pond reaches into are planned again too.
	if trees != null and not kept_trees.is_empty():
		var boxes: Array[Rect2] = []
		for q: PackedFloat32Array in game.field.ponds_in(at.x-1000.0,at.y-1000.0,at.x+1000.0,at.y+1000.0):
			var b: float = q[11]+Ponds.REACH
			boxes.append(Rect2(q[0]-b,q[1]-b,b*2.0,b*2.0))
		var block: float = trees.BLOCK
		var n := 0
		for key: Vector2i in kept_trees:
			if not trees._blocks.has(key): continue
			var r := Rect2(key.x*block,key.y*block,block,block)
			for b: Rect2 in boxes:
				if r.intersects(b):
					trees._free_block(key)
					n += 1
					break
		if n > 0: print("tutorial land: %d near tree blocks planned again round the water" % n)

static func _flat_d(r: Rect2, at: Vector2) -> float:
	return Vector2(clampf(at.x,r.position.x,r.end.x),clampf(at.y,r.position.y,r.end.y)).distance_to(at)

## The tree blocks wholly past `past` m of the plane dropped, to be planned
## again under the stage now (LandTrees streams them back in).
func _replan(past: float) -> void:
	var trees: Node = game.get("trees")
	if trees == null or not ("_blocks" in trees): return
	var p: Vector3 = game.plane.position
	var block: float = trees.BLOCK
	var drop: Array[Vector2i] = []
	for key: Vector2i in trees._blocks:
		var lo := Vector2(key.x*block,key.y*block)
		var near := Vector2(clampf(p.x,lo.x,lo.x+block),clampf(p.z,lo.y,lo.y+block))
		if near.distance_to(Vector2(p.x,p.z)) > past and world.side(lo.x+block*0.5,lo.y+block*0.5) == 1: drop.append(key)
	for key: Vector2i in drop: trees._free_block(key)
	trees._planned_at = Vector3.INF
	print("tutorial land: %d tree blocks planned again" % drop.size())

# --- The ship ------------------------------------------------------------------

## PARRY: the lake stamped ahead (tried again while none fits), then the ship
## on it.
func _ship_step(delta: float) -> void:
	_ship_wait -= delta
	if _ship_wait > 0.0: return
	_ship_wait = SHIP_RETRY
	if game.get("coast") == null or not game.has_method("water_at"): return
	var p: Vector3 = game.plane.position
	var at := Vector2(p.x,p.z)
	var v: Vector3 = game.plane.velocity
	var dir := Vector2(v.x,v.z)
	dir = dir.normalized() if dir.length() > 1.0 else Vector2(-sin(float(game.plane.heading)),-cos(float(game.plane.heading)))
	var land: Node = game.get("land")
	var kept: Array[Rect2] = []
	if land != null and land.has_method("kept_squares"): kept = land.kept_squares(KEEP_NEAR)
	var t0 := Time.get_ticks_usec()
	var got: Dictionary = world.stamp_lake(at,dir,kept) if ship == null else world.stamp_lake(at,dir,kept,SHIP_AGAIN)
	var ms_lake := (Time.get_ticks_usec()-t0)/1000.0
	FrameLog.add(&"tl_lake",ms_lake)
	if got.is_empty():
		print("tutorial land: no room for the ship's lake ahead; again in %.1f s" % SHIP_RETRY)
		return
	lake = got
	var c: Vector2 = lake.centre
	_ship_wait = 0.0
	_ship_lost = 0.0
	print("tutorial land: a lake for the ship at %s, %.0f m ahead, %.0f by %.0f m (the meadow's ponds are narrower than she is)" % [str(c.round()),c.distance_to(at),(float(lake.half)+float(lake.r))*2.0,float(lake.r)*2.0])
	t0 = Time.get_ticks_usec()
	if land != null and land.has_method("restream"): land.restream(KEEP_NEAR,lake.square)
	var ms_re := (Time.get_ticks_usec()-t0)/1000.0
	FrameLog.add(&"tl_restream",ms_re)
	t0 = Time.get_ticks_usec()
	_replan_in(lake.rect)
	var ms_tr := (Time.get_ticks_usec()-t0)/1000.0
	FrameLog.add(&"tl_replan",ms_tr)
	t0 = Time.get_ticks_usec()
	if ship == null: ship = _sail(c,float(lake.angle))
	elif spare == null:
		spare = ship
		ship = _sail(c,float(lake.angle),spare)
	elif not _seen(spare) and not spare.busy():
		var was := ship
		ship = spare
		spare = was
		_moor(c,float(lake.angle))
	else: _moor(c,float(lake.angle))
	var ms_sail := (Time.get_ticks_usec()-t0)/1000.0
	FrameLog.add(&"tl_sail",ms_sail)
	print("tutorial land: PARRY parts ms: lake %.1f restream %.1f replan %.1f sail %.1f" % [ms_lake,ms_re,ms_tr,ms_sail])

## A ship at anchor on the lake at `c`, her length along `ang` (rad, XZ), the
## twin of `first` (sharing its meshes) if one, hidden until the land is in.
func _sail(c: Vector2, ang: float, first: Node3D = null) -> Node3D:
	var level := float(game.water_at(Vector3(c.x,0.0,c.y)))
	var s: Node3D = PirateShip.new()
	s.lesson = true
	s.quiet = true
	s.sea_y = level
	s.speed = 0.0
	s.rock = 0.0
	# Her route's middle put so that its start (`route_pose(0)`, ROUTE_R off the
	# middle) is the lake's: her bow along `ang`.
	var turn := -ang
	var mid := c+Vector2(PirateShip.ROUTE_R*sin(turn),PirateShip.ROUTE_R*cos(turn))
	var coast: Node3D = game.coast
	coast.add_child(s)
	s.setup(game,mid,"tutorial/ship2" if first != null else "tutorial/ship",first,PirateShip.ROUTE_LEG,turn)
	coast.add_ship(s)
	s.visible = false
	_ship_t = 0.0
	print("tutorial land: %s at anchor at %s, water %.2f" % ["the second ship" if first != null else "the ship",str(Vector2(s.position.x,s.position.z).round()),level])
	return s

## PARRY: whether the ship firing has been out of her fire's view or far off
## (SHIP_LOST) long enough for a ship ahead; not while she is hidden. Moving
## her herself (no spare off the screen) waits until she is off it too, no
## tell is on and no parried ball is going home to her.
func _left_behind(delta: float) -> bool:
	if not ship.visible or ship.state != PirateShip.AFLOAT or not bool(game.hand_landing.flying()):
		_ship_lost = 0.0
		return false
	var p: Vector3 = game.plane.position
	var to := Vector2(ship.position.x-p.x,ship.position.z-p.z)
	var lost: bool = to.length() > SHIP_LOST.y or not bool(ship.in_view())
	_ship_lost = _ship_lost+delta if lost else 0.0
	if _ship_lost < SHIP_LOST.x: return false
	if spare == null or (not _seen(spare) and not spare.busy()): return true
	return not _seen(ship) and not ship.busy()

## Whether any of ship `s` (her middle or either end) is in the camera's view.
func _seen(s: Node3D) -> bool:
	var cam: Camera3D = game.get("camera")
	if cam == null: return true
	var along: Vector3 = s.global_transform.basis.z.normalized()*PirateShip.LONG*0.5
	for at: Vector3 in [s.global_position,s.global_position+along,s.global_position-along]:
		if cam.is_position_in_frustum(at): return true
	return false

## The ship moored again on the new lake at `c` (as `_sail`), hidden until
## the land over it is in.
func _moor(c: Vector2, ang: float) -> void:
	var level := float(game.water_at(Vector3(c.x,0.0,c.y)))
	var turn := -ang
	ship.moor(c+Vector2(PirateShip.ROUTE_R*sin(turn),PirateShip.ROUTE_R*cos(turn)),turn,level)
	ship.visible = false
	_ship_t = 0.0
	print("tutorial land: the ship moored again at %s, water %.2f" % [str(Vector2(ship.position.x,ship.position.z).round()),level])

## Whether the land over the lake's square is built again (no chunk meeting
## it waits on its new build).
func _lake_in() -> bool:
	var land: Node = game.get("land")
	if lake.is_empty() or land == null or not land.has_method("stale_in"): return true
	return not land.stale_in(lake.square)

## The tree blocks meeting `r` (world XZ) planned again (the lake's trees).
func _replan_in(r: Rect2) -> void:
	var trees: Node = game.get("trees")
	if trees == null or not ("_blocks" in trees): return
	var block: float = trees.BLOCK
	var drop: Array[Vector2i] = []
	for key: Vector2i in trees._blocks:
		if Rect2(key.x*block,key.y*block,block,block).intersects(r): drop.append(key)
	for key: Vector2i in drop: trees._free_block(key)
	trees._planned_at = Vector3.INF
	print("tutorial land: %d tree blocks planned again round the lake" % drop.size())

# --- The wall ------------------------------------------------------------------

func _place_hall() -> void:
	_warm_hall()
	if not _hall_next.warmed(): return
	if _hall_spot.is_empty():
		var p: Vector3 = game.plane.position
		var v: Vector3 = game.plane.velocity
		var way := Vector2(v.x,v.z)
		if way.length() < 1.0: way = Vector2(-sin(float(game.plane.heading)),-cos(float(game.plane.heading)))
		way = way.normalized()
		_hall_spot = [Vector2(p.x,p.z)+way*HALL_AHEAD,way]
	var at: Vector2 = _hall_spot[0]
	var way: Vector2 = _hall_spot[1]
	# Its meadow seat built over the next frames (sampled here, built on a worker).
	if not _hall_next.seat_ready(at,way): return
	_hall_spot = []
	world.keep_off = [[at+way*80.0,KEEP_RUIN],[at-way*170.0,KEEP_WAY]]
	if game.doors != null:
		push_warning("tutorial land: the world already has doors; the hall replaces them")
		game.doors.queue_free()
	hall = _hall_next
	_hall_next = null
	game.add_child(hall)
	hall.place(game,at,way,int(game.seed))
	game.doors = hall
	_build_beam()
	_replan(REPLAN_PAST)

## The hall stood ahead again when it has been left far behind (the wall
## whole); the swap seen through to the end.
func _watch_hall() -> void:
	if done: return
	if hall.through():
		done = true
		world.keep_off = []
		if _deck != null: _deck.visible = false
		if _beam != null: _beam.visible = false
		# The first shop's pointer from the wilderness's own start, not the meadow's.
		var shops: Node = game.get("shops")
		if shops != null and "start" in shops: shops.start = (world.regions[0].spawn.at as Vector2)
		print("tutorial land: broke through to the wilderness at %s" % str(game.plane.position.round()))
		broke_through.emit()
		return
	var p: Vector3 = game.plane.position
	var m: Vector3 = hall.mouth()
	if not hall.inside_hall and not hall.broken() and Vector2(p.x-m.x,p.z-m.z).length() > HALL_LOST: _drop_hall()

func _drop_hall() -> void:
	var cw: Node = game.smash.walls
	var site: Dictionary = cw.sites.get(hall.wall_handle,{})
	if str(site.get("state","")) == "building": return
	if str(site.get("state","")) == "up": cw._free(site)
	cw.sites.erase(hall.wall_handle)
	if hall.lands[0] != null and hall.lands[0] != game.land: hall.lands[0].queue_free()
	game.doors = null
	hall.queue_free()
	hall = null
	if _beam != null:
		_beam.queue_free()
		_beam = null
	print("tutorial land: the hall left behind; it stands ahead again")
	_place_hall()

## A column of light over the ruin, seen from far over the meadow.
func _build_beam() -> void:
	_beam = MeshInstance3D.new()
	_beam.name = "HallBeam"
	var c := CylinderMesh.new()
	c.top_radius = 5.0
	c.bottom_radius = 7.0
	c.height = 420.0
	c.radial_segments = 16
	c.cap_top = false
	c.cap_bottom = false
	_beam.mesh = c
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(1.0,0.78,0.42,0.55)
	m.disable_fog = true
	_beam.material_override = m
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	game.add_child(_beam)
	# Over the ruin's back, clear of the way in.
	var f: Transform3D = hall._frames[1]
	_beam.global_position = f*Vector3(0.0,0.0,float(hall._out)+40.0)+Vector3.UP*(c.height*0.5+20.0)

# --- The skip ------------------------------------------------------------------

## The white up, the hall stood, the far land stepped round the way out, the
## plane carried out; then the white down.
func _step_skip(delta: float) -> void:
	if _skip_t < 0.0: return
	_skip_t += delta
	if done:
		_skip_white = move_toward(_skip_white,0.0,delta/SKIP_OUT_FADE)
		if _skip_white <= 0.0: _skip_t = -1.0
		return
	if _white == null: _build_white()
	_skip_white = move_toward(_skip_white,1.0,delta/SKIP_IN)
	if hall == null:
		if bool(game.get("walk_ready")): _place_hall()
		return
	var f: Transform3D = hall._frames[0]
	if _skip_at == Vector3.INF:
		var a: Vector3 = f*Vector3(0.0,0.0,-SKIP_OUT)
		a.y = maxf(float(game.field.height(a.x,a.z)),float(game.water_at(a)) if game.has_method("water_at") else -INF)+SKIP_OVER
		_skip_at = a
		_skip_t = 0.0
	var far: Node3D = hall.lands[0]
	far.step(_skip_at)
	var c: Dictionary = far.counts()
	var share := float(c.standing)/maxf(float(c.wanted),1.0)
	if _skip_white < 1.0 or (share < SKIP_WARM and _skip_t < SKIP_WAIT): return
	_carry_out(f)

## The plane at `_skip_at`, flying out of the wilderness ruin (frame `f`, its
## z inward), on the wilderness's land and hour.
func _carry_out(f: Transform3D) -> void:
	var out := -f.basis.z
	var way := Vector2(out.x,out.z).normalized()
	hall._swap_land(0)
	hall._side = 0
	hall.swaps += 1
	hall.passes += 1
	# The same plane launched level at cruise (stood still on the grass too);
	# a new one (`_launch`) left the run hanging at quit.
	var plane: RefCounted = game.plane
	var fwd := Vector3(way.x,0.0,way.y)
	plane.launch(_skip_at,atan2(-way.x,-way.y),plane.cruise(),false)
	game.hand_landing.begin(plane,false)
	game.near.reset()
	game.contact.reset()
	game.plane_figure.reset(plane)
	game.chase.reset(plane,_skip_at-fwd*24.0+Vector3.UP*6.0,(game.camera as Camera3D).fov)
	hall._wash()
	hall._set_hour(1,0)
	print("tutorial land: skipped out of the wilderness ruin at %s" % str(_skip_at.round()))
	_watch_hall()

func _build_white() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	_white = ColorRect.new()
	_white.set_anchors_preset(Control.PRESET_FULL_RECT)
	_white.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_white.color = Color(0.93,0.94,0.96,0.0)
	_white.visible = false
	layer.add_child(_white)

# --- The deck ------------------------------------------------------------------

func _build_deck() -> void:
	_deck = MeshInstance3D.new()
	_deck.name = "CloudDeck"
	var pm := PlaneMesh.new()
	pm.size = Vector2(DECK_SIZE,DECK_SIZE)
	pm.subdivide_width = 31
	pm.subdivide_depth = 31
	_deck.mesh = pm
	_deck.custom_aabb = AABB(Vector3(-DECK_SIZE*0.5,-40.0,-DECK_SIZE*0.5),Vector3(DECK_SIZE,80.0,DECK_SIZE))
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always, shadows_disabled;
uniform vec3 tone = vec3(0.9, 0.92, 0.95);
varying vec3 wp;
float h(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float n(vec2 p) { vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(h(i), h(i + vec2(1, 0)), f.x), mix(h(i + vec2(0, 1)), h(i + vec2(1, 1)), f.x), f.y); }
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float d = length(wp.xz - CAMERA_POSITION_WORLD.xz);
	float puff = n(wp.xz / 90.0) * 0.6 + n(wp.xz / 23.0) * 0.4;
	ALBEDO = tone * mix(0.8, 1.02, puff);
	ALPHA = mix(0.78, 0.96, puff) * (1.0 - smoothstep(3000.0, 7800.0, d));
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	_deck.material_override = m
	_deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_deck)
	_build_white()

func _step_deck() -> void:
	if _deck == null:
		if _white != null:
			_white.visible = _skip_white > 0.002
			_white.color.a = _skip_white*0.98
		return
	var eye: Vector3 = (game.camera as Camera3D).global_position
	var on: bool = not done and int(world.side(eye.x,eye.z)) == 1
	var deck_y := _turf+DECK
	_deck.visible = on and eye.y < deck_y+WHITE_FULL
	_deck.global_position = Vector3(eye.x,deck_y,eye.z)
	var w := smoothstep(deck_y+WHITE_FROM,deck_y+WHITE_FULL,eye.y) if on else 0.0
	w = maxf(w,_skip_white)
	_white.visible = w > 0.002
	_white.color.a = w*0.98

## Whether the eye is in the deck (for drivers).
func whited() -> float:
	return _white.color.a if _white != null and _white.visible else 0.0
