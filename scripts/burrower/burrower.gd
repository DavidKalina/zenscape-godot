extends Node3D
## The burrower (docs/design/endless-flight/spec-burrower.md): something
## unseen moving under the turf. It is never drawn itself; what shows is the
## ground it heaves:
##
##   ridge  a strip laid on the ground along its path (shaders/
##          burrower_ridge.gdshader), each sample heaved by its age: a bow
##          rising ahead, the peak as it passes, a ring of follow-through,
##          then a low cracked scar that settles over SCAR_LIFE s. Built in
##          chunks of CHUNK samples; only the live one is rebuilt.
##   grass  GrassReact stamps along the path: parted out either side and
##          pressed, springing back after GRASS_HOLD.
##   clods  sod clods and pebbles kicked up from the head, falling back,
##          bouncing once, lying a moment and sinking (a MultiMesh).
##   dust   soft puffs that hang behind the head and thin out.
##
## On the pond the same thing is a wake with no boat (shaders/
## burrower_pond.gdshader): a bulge over the head, rings dropped from it
## every WAKE_DT s that add up to a V, froth on its track, spray thrown off
## the bulge and a mist; the ridge ends at the water's edge and starts again
## where it comes out.
##
## It moves with intent: a heading that turns smoothly (turn rate eased),
## a speed that surges and slows (SURGE), steering round the land's rocks,
## ruins and knoll (looked for ahead; the pond it crosses) and keeping to the meadow,
## passing beside trees (their trunks a small reach; roaming, it often makes
## for a tree's side) and shuddering them (scripts/burrower/tree_shudder.gd).
## Two ways to move: `lead(plane)` comes in from out of the chase camera's
## view at one side, cuts across ahead of the plane and runs on away from it
## to be chased (the entrance, then the run); `roam()` wanders the meadow
## alone (the watch camera's). `dive()` sinks it away.

const Land = preload("res://scripts/burrower/burrower_land.gd")
const Ground = preload("res://scripts/burrower/burrower_ground.gd")
const GrassReact = preload("res://scripts/endless/grass_react.gd")
const RIDGE_SHADER = preload("res://shaders/burrower_ridge.gdshader")
const DUST_SHADER = preload("res://shaders/burrower_dust.gdshader")
const SOIL_SHADER = preload("res://shaders/burrower_soil.gdshader")
const TreeShudder = preload("res://scripts/burrower/tree_shudder.gd")

## The ridge: a sample every SAMPLE m, ACROSS vertices across HALF_W m each
## side, CHUNK samples to a mesh, the bow drawn NOSE samples ahead; the scar
## lasts SCAR_LIFE s (the shader's `life`).
const SAMPLE := 0.6
const ACROSS := 11
const HALF_W := 2.3
const CHUNK := 32
const NOSE := 6
## The bow's rows ask the land at every BOW_EVERYth point across: they're
## redone each frame, and the land's the dear part (spec item 6).
const BOW_EVERY := 5
const BOW_ROWS := 3
const BOW := 0.24
const SCAR_LIFE := 12.0
## Lies this far over the ground mesh (no z-fight at its rest).
const LIFT := 0.03
## Moving: base speeds (m/s) roaming, the most it turns (rad/s) and how fast
## its turning changes (rad/sÃ‚Â²), its speed's ease (m/sÃ‚Â²), how far ahead it
## looks for things to steer round (s of travel, at least m), the margin it
## keeps from them (m).
const ROAM_SPEED := 17.0
const MAX_TURN := 1.1
const TURN_EASE := 2.2
## Leading the plane it turns harder and quicker, to keep ahead through the
## plane's turns.
const LEAD_TURN := 2.4
const LEAD_TURN_EASE := 7.0
## Still lost after all that (the head behind the plane, or LOST_FAR m from
## its slot, for LOST_S s) it sounds: sinks in SOUND_S s and comes up in its
## slot ahead.
const LOST_FAR := 75.0
const LOST_S := 0.45
const SOUND_S := 0.3
## Clods thrown up where it breaks the turf again after a sounding.
const BREACH_CLODS := 22
const ACCEL := 14.0
const LOOK_S := 0.9
const LOOK_M := 10.0
const MARGIN := 6.0
## A trunk's reach: kept small, so it passes beside a tree (the shudder's
## reach is 15 m), and how often a roam goal is a tree's side.
const TRUNK := 0.5
const TREE_GOAL := 0.55
## A trunk is pushed off only close in: within TRUNK_MARGIN+TRUNK_RAMP m.
const TRUNK_MARGIN := 2.5
const TRUNK_RAMP := 4.0
## A land that `probes` has no list of trees: the trunks in the corridor
## ahead of the head (TRUNK_SIDE m each side), at most TRUNK_MOST, asked every
## TRUNK_EVERY s. A stand of trees within WOOD_LOOK m ahead of the plane
## draws a free run into it (WOOD_TURN rad/s), asked every WOOD_EVERY s.
const TRUNK_SIDE := 9.0
const TRUNK_MOST := 14
const TRUNK_EVERY := 0.12
const WOOD_LOOK := 260.0
const WOOD_TURN := 0.7
const WOOD_EVERY := 0.5
## Its surge: speed times 1 + SURGE * a slow noise, and now and then a burst.
const SURGE := 0.28
## Leading the plane: how far ahead (m, a slow noise between) and to the side.
const LEAD_AHEAD := Vector2(22.0,46.0)
const LEAD_SIDE := Vector2(6.0,13.0)
## The entrance (lead()): it comes up ENTER_FWD m along the plane's way
## (behind abeam), out at the side with the most open meadow, ENTER_OUT s of
## the plane's flight out (at least ENTER_SIDE.x m) and further until the
## chase camera (`view`) can't see it (at most ENTER_SIDE.y); then at
## ENTER_SPEED times the plane's speed it closes on its line on an intercept,
## to cross it CROSS_AHEAD s ahead of the plane (out of view the first second
## or so); across (or after ENTER_MOST s) it breaks away BREAK rad off the
## plane's heading on the far side.
const ENTER_FWD := -5.0
const ENTER_OUT := 1.4
const ENTER_SIDE := Vector2(30.0,90.0)
const ENTER_SPEED := 1.5
const CROSS_AHEAD := 1.6
const ENTER_MOST := 6.0
const BREAK := 0.5
## The run: a course of its own that the plane chases, RUN_AHEAD m ahead
## along the plane's nose (a slow noise between), wandering at up to WANDER
## rad/s; strayed past RUN_OFF rad off the plane's nose it bends back
## (OFF_TURN rad/s); past RUN_RIM m from the middle it bends along the
## meadow's edge (RIM_TURN rad/s) rather than run out. Lost past RUN_LOST m.
const RUN_AHEAD := Vector2(30.0,48.0)
const WANDER := 0.45
const RUN_OFF := 0.6
const OFF_TURN := 1.2
const RUN_RIM := 180.0
## RUN_RIM as room left inside the land's rim (m; the study's meadow: 75).
const RUN_ROOM := 255.0-RUN_RIM
const RIM_TURN := 1.0
const RUN_LOST := 120.0
## Grass: a stamp every GRASS_STEP m, its reach (m), push and hold (s).
const GRASS_STEP := 1.5
const GRASS_REACH := 3.4
const GRASS_PUSH := 2.6
const GRASS_HOLD := 0.45
## Clods: at most CLODS alive, kicked at CLOD_RATE a second at full speed.
const CLODS := 360
const CLOD_RATE := 34.0
## The spout: earth flung high off the head (so it shows over the grass from
## a skimming chase camera), SPOUT_RATE a second at full speed, up SPOUT_UP
## m/s, keeping SPOUT_KEEP of the head's speed so it arcs over the head.
const SPOUT_RATE := 16.0
const SPOUT_UP := Vector2(7.5,12.5)
const SPOUT_KEEP := Vector2(0.55,0.95)
const GRAVITY := 14.0
## Dust: at most DUSTS puffs, DUST_RATE a second, living DUST_LIFE s.
const DUSTS := 160
const DUST_RATE := 9.0
const DUST_LIFE := 2.8

const SOD := Color("4c5a2c")
const SOIL := Color("4a3826")
const PEBBLE := Color("8e877a")
const DUST := Color(0.36,0.31,0.24)
## Water: wet where the bed lies WET_DEEP m under the water; a wake point
## every WAKE_DT s (the shader holds WAKES); spray, at most SPRAYS drops,
## SPRAY_RATE a second at full speed, a burst of SPLASH going in.
const WET_DEEP := 0.15
const WAKES := 64
const WAKE_DT := 0.07
const SPRAYS := 420
const SPRAY_RATE := 90.0
const SPLASH := 70
const SPRAY := Color(0.86,0.92,0.95,0.85)
const MIST := Color(0.80,0.85,0.87)
## How often a roam goal is the pond's far side.
const POND_GOAL := 0.3

## The ground it runs in: the study's land (burrower_land.gd) or the game's
## (game_land.gd); both answer height, normal, mesh_height, colour, water_y,
## room, inward, stone, trees, pond_rect and pond_material.
var land: Ground
var react: GrassReact
var time := 0.0
## Under way (moving and heaving), and how hard: 0 sunk, 1 at the turf.
var active := false
var strength := 0.0
var pos := Vector2.ZERO
var heading := 0.0
var speed := 0.0
var mode := &"roam"
var stats := {"samples": 0, "chunks": 0, "clods": 0, "dust": 0, "stamps": 0, "nearest": INF,
	"wakes": 0, "spray": 0, "splashes": 0, "wet_time": 0.0, "soundings": 0, "lost_why": {}}
## In the water now, and the wake's ease in (0 on land, 1 in the water).
var wet := false
var wet_k := 0.0

## Set by what it pushes up (push_ups.gd): the least it runs ahead of the
## plane while leading (m), so a push-up comes a beat ahead; 0 none.
var want_ahead := 0.0
## While a push-up is due, the spot it runs for (x, z: on the plane's line, a
## little past where the push-up will be; NAN: its own slot).
var want_at := Vector2(NAN,NAN)
## The chase camera, to come up out of its view (null: ENTER_SIDE.x out).
var view: Camera3D
## Leading: &"enter" (coming in across the plane's way), &"run" (away, chased).
var phase := &"run"
var _phase_t := 0.0
## Its own course on the run (rad, as heading).
var _course := 0.0
var _plane: Object
var _turn := 0.0
var _goal := Vector2.ZERO
var _side := 1.0
var _diving := false
## Lost the plane (fell behind it through a turn): sinking to come up again
## in its slot ahead (not a dive: it stays active and leading).
var _sounding := false
var _lost := 0.0
var _run := 0.0
var _noise := FastNoiseLite.new()
var _rng := RandomNumberGenerator.new()
var _obstacles: Array = []
var _trunks: Array = []
var _trunk_ask := 0.0
var _wood_ask := 0.0
var _wood_at := Vector2(NAN,NAN)
var shudder: TreeShudder
var _samples: Array = []
var _live_mesh: ArrayMesh
var _strip_index := {}
var _since_sample := 0.0
var _since_stamp := 0.0
var _chunks: Array = []
var _live: MeshInstance3D
var _ridge_mat := ShaderMaterial.new()
var _clods: Array = []
var _clod_mm := MultiMesh.new()
var _clod_carry := 0.0
var _spout_carry := 0.0
var _dusts: Array = []
var _dust_mm := MultiMesh.new()
var _dust_carry := 0.0
var _wake := PackedVector4Array()
var _wake_i := 0
var _since_wake := 0.0
var _sprays: Array = []
var _spray_mm := MultiMesh.new()
var _spray_carry := 0.0

func _init() -> void:
	name = "Burrower"

func setup(the_land: Ground, the_react: GrassReact) -> void:
	land = the_land
	react = the_react
	_noise.seed = 5
	_noise.frequency = 0.35
	_rng.seed = 41
	for r: Dictionary in land.stone():
		_obstacles.append({"at": r.at, "reach": float(r.reach)})
	for tree: Node3D in land.trees:
		_obstacles.append({"at": Vector2(tree.position.x,tree.position.z), "reach": TRUNK, "margin": TRUNK_MARGIN, "ramp": TRUNK_RAMP, "tree": true})
	shudder = TreeShudder.new()
	shudder.setup(land)
	shudder.react = react
	add_child(shudder)
	_ridge_mat.shader = RIDGE_SHADER
	_ridge_mat.set_shader_parameter("life",SCAR_LIFE)
	_ridge_mat.set_shader_parameter("bow",BOW)
	_live = MeshInstance3D.new()
	_live.name = "RidgeLive"
	_live.material_override = _ridge_mat
	add_child(_live)
	# Crumbs and clods: a few ragged faceted lumps of mixed roughness (the
	# multimesh has one mesh, so one merged mesh holds them as a pile; each
	# instance is one fixed lump, shaded gritty by shaders/burrower_soil).
	var lump := GritMesh.lump(7,0.45,1)
	var clod_m := ShaderMaterial.new()
	clod_m.shader = SOIL_SHADER
	clod_m.set_shader_parameter("use_instance",true)
	lump.surface_set_material(0,clod_m)
	_clod_mm.transform_format = MultiMesh.TRANSFORM_3D
	_clod_mm.use_colors = true
	_clod_mm.mesh = lump
	_clod_mm.instance_count = CLODS
	_clod_mm.visible_instance_count = 0
	var clods := MultiMeshInstance3D.new()
	clods.name = "Clods"
	clods.multimesh = _clod_mm
	add_child(clods)
	var quad := QuadMesh.new()
	var dust_m := ShaderMaterial.new()
	dust_m.shader = DUST_SHADER
	dust_m.set_shader_parameter("pond",land.pond_rect())
	quad.material = dust_m
	_dust_mm.transform_format = MultiMesh.TRANSFORM_3D
	_dust_mm.use_custom_data = true
	_dust_mm.mesh = quad
	_dust_mm.instance_count = DUSTS
	_dust_mm.visible_instance_count = 0
	var dusts := MultiMeshInstance3D.new()
	dusts.name = "Dust"
	dusts.multimesh = _dust_mm
	dusts.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dusts)
	var drop := SphereMesh.new()
	drop.radius = 0.5
	drop.height = 1.0
	drop.radial_segments = 6
	drop.rings = 3
	var drop_m := StandardMaterial3D.new()
	drop_m.vertex_color_use_as_albedo = true
	drop_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	drop_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	drop.material = drop_m
	_spray_mm.transform_format = MultiMesh.TRANSFORM_3D
	_spray_mm.use_colors = true
	_spray_mm.mesh = drop
	_spray_mm.instance_count = SPRAYS
	_spray_mm.visible_instance_count = 0
	var sprays := MultiMeshInstance3D.new()
	sprays.name = "Spray"
	sprays.multimesh = _spray_mm
	sprays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprays)
	_wake.resize(WAKES)
	_wake.fill(Vector4.ZERO)

## Up under the turf at `at` heading `way` (rad, 0 along +x), leading `plane`
## (null: roaming the meadow).
func wake(at: Vector2, way: float, plane: Object = null) -> void:
	_finish_live()
	pos = at
	heading = way
	_turn = 0.0
	_plane = plane
	mode = &"lead" if plane != null else &"roam"
	_side = -1.0 if _rng.randf() < 0.5 else 1.0
	phase = &"run"
	_phase_t = 0.0
	_course = way
	speed = _plane_speed() if plane != null else ROAM_SPEED
	strength = 0.0
	active = true
	_diving = false
	_sounding = false
	_lost = 0.0
	_run = 0.0
	_goal = _roam_goal()
	_since_sample = SAMPLE
	wet = _wet_at(pos)

## Up out of the chase camera's view abeam of `plane`, at the side with
## the more open meadow, heading in to cross ahead of it (the entrance).
func lead(plane: Object) -> void:
	var p: Vector3 = plane.position
	var f: Vector3 = plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	if fwd == Vector2.ZERO: fwd = Vector2(0,-1)
	var left := Vector2(-fwd.y,fwd.x)
	var p2 := Vector2(p.x,p.z)
	var v: Vector3 = plane.velocity
	var vp := maxf(Vector2(v.x,v.z).length(),8.0)
	var cross := p2+fwd*vp*(CROSS_AHEAD+2.5)
	var best := {}
	for s: float in ([1.0,-1.0] if _rng.randf() < 0.5 else [-1.0,1.0]):
		var out := clampf(vp*ENTER_OUT,ENTER_SIDE.x,ENTER_SIDE.y)
		var at := p2+fwd*ENTER_FWD+left*s*out
		while out < ENTER_SIDE.y and _seen(at):
			out += 4.0
			at = p2+fwd*ENTER_FWD+left*s*out
		at = _clear_of_stone(at)
		# Room: the start, the crossing and the way it breaks off, all well
		# inside the meadow (the pond is fine: it comes in as a wake).
		var away := cross+fwd.rotated(-s*BREAK)*60.0
		var room := minf(minf(land.room(at),land.room(cross)),land.room(away))
		if _seen(at): room -= 100.0
		if best.is_empty() or room > float(best.room)+0.5: best = {"at": at, "s": s, "room": room}
	var start: Vector2 = best.at
	wake(start,fwd.angle(),plane)
	_side = -float(best.s)
	phase = &"enter"
	_phase_t = 0.0
	speed = vp*ENTER_SPEED
	heading = _intercept(p2,fwd,vp).angle()
	stats.enter_side = float(best.s)
	stats.enter_out = (start-p2).dot(left)*float(best.s)
	stats.enter_seen = _seen(start)

## Whether the chase camera sees a point on the ground here (1 m up).
func _seen(at: Vector2) -> bool:
	if view == null or not is_instance_valid(view) or not view.is_inside_tree(): return false
	var h := Vector3(at.x,land.height(at.x,at.y)+1.0,at.y)
	return view.is_position_in_frustum(h)

## `at` pushed out of the rocks', ruins' and knoll's reach.
func _clear_of_stone(at: Vector2) -> Vector2:
	for o: Dictionary in _obstacles:
		if o.has("tree"): continue
		var r := float(o.reach)+float(o.get("margin",MARGIN))
		if at.distance_to(o.at) < r: at = (o.at as Vector2)+(at-(o.at as Vector2)).normalized()*r
	return at

## A land with no lists (the game's): the angles (rad off its heading, each
## side) it feels ahead along when straight on is shut, nearest first; the head's own probe FEEL_HEAD m on.
const FEEL_TURN := [0.45,0.9,1.35]
const FEEL_HEAD := 4.0
const FEEL_PULL := 3.0
## Up from a sounding, it runs FEEL_GRACE s before a wall can sound it again.
const FEEL_GRACE := 0.8
var _grace := 0.0

## The pull round what the land holds ahead (a land that `probes`): none
## while the way straight on is open; else toward the nearest open feeler,
## the side its goal lies first; nothing open, on as it goes. A wall right
## at the head (a cliff, a ruin wall, stone) and leading it sounds, to come
## up ahead past it.
func _feel(look: float, delta: float) -> Vector2:
	if not land.probes or _diving or _sounding: return Vector2.ZERO
	var fw := forward()
	var lead := mode == &"lead" and _plane != null
	_grace -= delta
	# Just up, only what stands sounds it (steep ground alone would hop it along
	# a cliff).
	if lead and phase != &"enter" and (land.stands(pos+fw*FEEL_HEAD) if _grace > 0.0 else land.wall(pos+fw*FEEL_HEAD)):
		_sound("edge")
		return Vector2.ZERO
	if land.open(pos+fw*look*0.5) and land.open(pos+fw*look): return Vector2.ZERO
	var to_goal := _goal-pos
	for a: float in FEEL_TURN:
		var l := fw.rotated(a)
		var r := fw.rotated(-a)
		for way: Vector2 in ([l,r] if l.dot(to_goal) >= r.dot(to_goal) else [r,l]):
			if land.open(pos+way*look*0.5) and land.open(pos+way*look):
				stats.feels = int(stats.get("feels",0))+1
				return way*FEEL_PULL
	# Shut every way (a long slope): on as it goes; a wall still sounds it.
	return Vector2.ZERO

## The trunks it will weave next (a land that `probes`), nearest first.
func _ask_trunks(look: float, delta: float) -> void:
	if not land.probes: return
	_trunk_ask -= delta
	if _trunk_ask > 0.0: return
	_trunk_ask = TRUNK_EVERY
	_trunks.clear()
	var fw := forward()
	var t: PackedFloat32Array = land.trees_near(pos+fw*look*0.5,look*0.5+TRUNK_SIDE)
	var found: Array = []
	for q in range(0,t.size(),4):
		var rel := Vector2(t[q],t[q+1])-pos
		var along := rel.dot(fw)
		if along < -2.0 or absf(rel.dot(fw.orthogonal())) > TRUNK_SIDE: continue
		found.append([along,Vector2(t[q],t[q+1])])
	found.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for f: Array in found.slice(0,TRUNK_MOST):
		_trunks.append({"at": f[1], "reach": TRUNK, "margin": TRUNK_MARGIN, "ramp": TRUNK_RAMP, "tree": true})
	stats.trunks = int(stats.get("trunks",0))+_trunks.size()

## A free run's course bent into a stand of trees ahead of the plane.
func _into_woods(fwd: Vector2, delta: float) -> void:
	if not land.probes: return
	_wood_ask -= delta
	if _wood_ask <= 0.0:
		_wood_ask = WOOD_EVERY
		_wood_at = land.stand_ahead(pos,fwd,WOOD_LOOK)
	if is_nan(_wood_at.x) or not _trunks.is_empty(): return
	_course = rotate_toward(_course,(_wood_at-pos).angle(),WOOD_TURN*delta)
	stats.wood_pull = float(stats.get("wood_pull",0.0))+delta

func _sound(why: String) -> void:
	_sounding = true
	stats.soundings = int(stats.soundings)+1
	stats.lost_why[why] = int(stats.lost_why.get(why,0))+1

## `at`, or the nearest open spot on along `fwd` and to its sides with no
## wall just on (a land that `probes`; else `at`). A grace starts.
func _open_spot(at: Vector2, fwd: Vector2) -> Vector2:
	if not land.probes: return at
	_grace = FEEL_GRACE
	var side := fwd.orthogonal()
	for k in range(0,9):
		for off: Vector2 in ([Vector2.ZERO] if k == 0 else [fwd*k*12.0,fwd*k*12.0+side*k*8.0,fwd*k*12.0-side*k*8.0,side*k*10.0,-side*k*10.0]):
			var q := at+off
			if land.open(q) and not land.wall(q+fwd*FEEL_HEAD*3.0): return q
	return at

## Coming in across the plane's way (the entrance), not yet running.
func entering() -> bool:
	return active and mode == &"lead" and phase == &"enter"

## On its own from here: wandering the meadow, the plane left be.
func roam() -> void:
	mode = &"roam"
	_plane = null
	_goal = _roam_goal()

## Sinks away: the head eases down, the trail settles on.
func dive() -> void:
	if active: _diving = true

## Sunk after losing the plane: up again in its slot ahead of it, heading
## its way (the ridge starts afresh; strength rises from 0 as at a wake).
func _resurface() -> void:
	_sounding = false
	_lost = 0.0
	_finish_live()
	var p: Vector3 = _plane.position
	var f: Vector3 = _plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	if fwd == Vector2.ZERO: fwd = Vector2(0,-1)
	var at := Vector2(p.x,p.z)+fwd*maxf(32.0,want_ahead)+Vector2(-fwd.y,fwd.x)*_side*9.0
	var room: float = land.room(at)
	if room < 30.0: at += land.inward(at)*(30.0-room)
	for o: Dictionary in _obstacles:
		var r := float(o.reach)+float(o.get("margin",MARGIN))
		if at.distance_to(o.at) < r: at = (o.at as Vector2)+(at-(o.at as Vector2)).normalized()*r
	at = _open_spot(at,fwd)
	pos = at
	heading = fwd.angle()
	_course = heading
	phase = &"run"
	_turn = 0.0
	speed = _plane_speed()
	_since_sample = SAMPLE
	wet = _wet_at(pos)
	_breach()

## Coming up ahead after a sounding: earth bursts up where the head breaks
## the turf (water off the pond), so the eye finds it before the mound grows.
func _breach() -> void:
	var at := Vector3(pos.x,land.height(pos.x,pos.y),pos.y)
	if wet:
		var water := Vector3(pos.x,land.water_y(pos.x,pos.y),pos.y)
		throw_water(water,40,4.0,8.0,2.5)
		puff(water,6,true)
	else:
		throw_earth(at+Vector3(0.0,0.4,0.0),BREACH_CLODS,4.5,10.0,1.2)
		puff(at,7)
	stats.breaches = int(stats.get("breaches",0))+1

## Sinking away (dive() called, not yet down).
func diving() -> bool:
	return active and _diving

func forward() -> Vector2:
	return Vector2(cos(heading),sin(heading))

## The head on the ground (world).
func head() -> Vector3:
	return Vector3(pos.x,land.height(pos.x,pos.y),pos.y)

func _plane_speed() -> float:
	if _plane == null: return ROAM_SPEED
	var v: Vector3 = _plane.velocity
	return maxf(Vector2(v.x,v.z).length(),8.0)

func _wet_at(p: Vector2) -> bool:
	return land.height(p.x,p.y) < land.water_y(p.x,p.y)-WET_DEEP

## (Roaming is the study's alone: its goals are its meadow's pond and trees.)
func _roam_goal() -> Vector2:
	# Now and then across the pond: a point past its far side, in the meadow.
	if _rng.randf() < POND_GOAL and pos.distance_to(Land.POND) > Land.POND_R+15.0:
		var across := (Land.POND-pos).normalized()
		for i in 6:
			var g := Land.POND+across.rotated(_rng.randf_range(-0.7,0.7))*(Land.POND_R+_rng.randf_range(12.0,24.0))
			if g.length() < Land.MEADOW_R-35.0: return g
	# Often past a tree's side: a point beside it, so the way runs by it.
	if not land.trees.is_empty() and _rng.randf() < TREE_GOAL:
		for i in 8:
			var tree: Node3D = land.trees[_rng.randi() % land.trees.size()]
			var at := Vector2(tree.position.x,tree.position.z)
			if at.distance_to(pos) < 45.0: continue
			var side := (at-pos).normalized().orthogonal()*(-1.0 if _rng.randf() < 0.5 else 1.0)
			var g := at+side*_rng.randf_range(7.0,10.0)+(at-pos).normalized()*18.0
			if g.length() < Land.MEADOW_R-35.0: return g
	for i in 20:
		var g := Vector2(_rng.randf_range(-140.0,140.0),_rng.randf_range(-140.0,140.0))
		if g.length() > 150.0 or g.distance_to(pos) < 50.0: continue
		var clear := true
		for o: Dictionary in _obstacles:
			if not o.has("tree") and g.distance_to(o.at) < float(o.reach)+MARGIN*2.0: clear = false
		if clear: return g
	return -pos.normalized()*60.0

func tick(delta: float) -> void:
	time += delta
	_ridge_mat.set_shader_parameter("now",time)
	if active: _move(delta)
	_step_clods(delta)
	_step_dust(delta)
	_step_spray(delta)
	shudder.tick(delta,pos,strength if active and not wet else 0.0)
	wet_k = move_toward(wet_k,1.0 if active and wet else 0.0,delta/0.25)
	_feed_pond()
	_drop_old_chunks()
	if active or not _samples.is_empty(): _rebuild_live()

## Asleep with nothing left of it to move or fade (a host may skip `tick`).
func settled() -> bool:
	return not active and _samples.is_empty() and _chunks.is_empty() and _clods.is_empty() 		and _dusts.is_empty() and _sprays.is_empty() and wet_k <= 0.0 and shudder.settled() and not land.wake_busy()

func _move(delta: float) -> void:
	_run += delta
	var target := 0.0 if _diving or _sounding else 1.0
	strength = move_toward(strength,target,delta/(1.1 if _diving else SOUND_S if _sounding else 0.5))
	if _diving and strength <= 0.0:
		active = false
		_finish_live()
		return
	if _sounding and strength <= 0.0:
		_resurface()
	var surge := 1.0+SURGE*_noise.get_noise_1d(time)
	# A burst now and then: the noise's peaks pushed harder.
	surge += 0.35*maxf(_noise.get_noise_1d(time*0.6+300.0)-0.25,0.0)/0.75
	var want_speed := ROAM_SPEED*surge
	if mode == &"lead" and _plane != null and phase == &"enter":
		want_speed = _enter(delta)
	elif mode == &"lead" and _plane != null and phase == &"run":
		want_speed = _run_on(delta,surge)
	elif mode == &"lead" and _plane != null:
		var p: Vector3 = _plane.position
		var f: Vector3 = _plane.forward()
		var fwd := Vector2(f.x,f.z).normalized()
		var side := Vector2(-fwd.y,fwd.x)
		var ahead := lerpf(LEAD_AHEAD.x,LEAD_AHEAD.y,clampf(0.5+1.1*_noise.get_noise_1d(time*0.45+100.0),0.0,1.0))
		ahead = maxf(ahead,want_ahead)
		var off := lerpf(LEAD_SIDE.x,LEAD_SIDE.y,clampf(0.5+1.0*_noise.get_noise_1d(time*0.3+200.0),0.0,1.0))
		# Its slot by the plane sets the speed; it steers for a point on
		# along the plane's way from there (else it would turn back for a
		# slot it had overrun).
		var slot := Vector2(p.x,p.z)+fwd*ahead+side*_side*off
		# Lost is judged by its own slot: a push-up's spot far out on the
		# plane's arc is run for, not a reason to sound.
		var home := slot
		if not is_nan(want_at.x): slot = want_at
		var to_slot := slot-pos
		var behind := to_slot.dot(fwd)
		# Off to the side counts as behind too (after the plane turns, the
		# slot swings away across its way).
		var gap := behind+0.6*absf(to_slot.dot(side))
		var vp := _plane_speed()
		want_speed = clampf(vp*surge+gap*1.1,vp*0.5,vp*1.8)
		# Near its slot it runs on along the plane's way; far from it (the
		# plane turned) it cuts across for the slot itself, so it swings
		# round inside the turn and comes out ahead, not wide and behind.
		var cut := clampf((to_slot.length()-15.0)/30.0,0.0,1.0)
		_goal = slot+fwd*lerpf(maxf(speed*0.9,20.0),8.0,cut)
		# Lost all the same (a hard turn by the rim or a rock): it sounds.
		var lost := (pos-Vector2(p.x,p.z)).dot(fwd) < 0.0 or (home-pos).length() > LOST_FAR
		_lost = _lost+delta if lost and not _diving else 0.0
		if _lost > LOST_S and not _sounding:
			_sounding = true
			stats.soundings = int(stats.soundings)+1
			var lw := "behind" if (pos-Vector2(p.x,p.z)).dot(fwd) < 0.0 else ("far (due)" if not is_nan(want_at.x) else "far")
			stats.lost_why[lw] = int(stats.lost_why.get(lw,0))+1
	elif pos.distance_to(_goal) < 18.0:
		_goal = _roam_goal()
	var dir := (_goal-pos).normalized()
	# Steering round what lies ahead and keeping to the meadow.
	var look := maxf(LOOK_M,speed*LOOK_S)
	var ahead_at := pos+forward()*look
	var nearest := INF
	_ask_trunks(look,delta)
	for list: Array in [_obstacles,_trunks]:
		for o: Dictionary in list:
			var r := float(o.reach)+float(o.get("margin",MARGIN))
			var ramp := float(o.get("ramp",12.0))
			for probe: Vector2 in [pos,pos+forward()*look*0.5,ahead_at]:
				var d := probe.distance_to(o.at)
				nearest = minf(nearest,pos.distance_to(o.at)-float(o.reach))
				if d < r+ramp:
					var away := (probe-(o.at as Vector2)).normalized()
					# Round the side it is already going (leading: the side its
					# slot lies, so a rock doesn't carry it off the plane's way).
					var tang := Vector2(-away.y,away.x)
					var lean := (_goal-pos).normalized() if mode == &"lead" and _plane != null else forward()
					if tang.dot(lean) < 0.0: tang = -tang
					var w := clampf(1.0-(d-r)/ramp,0.0,1.6)
					dir += (away*0.9+tang*0.6)*w*1.8
	stats.nearest = minf(float(stats.nearest),nearest)
	dir += _feel(look,delta)
	# (Coming in it keeps its intercept unless right at the edge.)
	var keep := 8.0 if mode == &"lead" and phase == &"enter" else 28.0
	var room: float = land.room(pos)
	if room < keep: dir += land.inward(pos)*clampf((keep-room)/12.0,0.0,2.0)*2.0
	var want := angle_difference(heading,dir.angle())
	# Leading, it turns as hard as the plane can (a banked plane comes round
	# at ~1 rad/s; the slot ahead swings wider and faster than that).
	var leading := mode == &"lead" and _plane != null
	var most := LEAD_TURN if leading else MAX_TURN
	var rate := clampf(want*2.4,-most,most)
	_turn = move_toward(_turn,rate,(LEAD_TURN_EASE if leading else TURN_EASE)*delta)
	heading = wrapf(heading+_turn*delta,-PI,PI)
	speed = move_toward(speed,want_speed,ACCEL*delta)
	var step := speed*delta
	pos += forward()*step
	var now_wet := _wet_at(pos)
	if now_wet != wet:
		wet = now_wet
		# The ridge ends at the water and starts again where it comes out.
		_finish_live()
		_since_sample = SAMPLE
		_splash(SPLASH if wet else SPLASH/2)
	_since_sample += step
	_since_stamp += step
	if wet:
		stats.wet_time = float(stats.wet_time)+delta
		_since_wake += delta
		if _since_wake >= WAKE_DT:
			_since_wake = 0.0
			_drop_wake(pos,strength*clampf(speed/ROAM_SPEED,0.7,1.4))
	else:
		if _since_sample >= SAMPLE:
			_since_sample = 0.0
			# A surge heaves harder.
			_add_sample(pos,strength*clampf(1.0+0.7*(surge-1.0),0.7,1.35))
		if _since_stamp >= GRASS_STEP:
			_since_stamp = 0.0
			_stamp_grass()
	_kick(delta)

## The entrance's step: for the point CROSS_AHEAD s ahead on the plane's
## line; across it (or out of time) it breaks away and runs. Its speed.
func _enter(delta: float) -> float:
	_phase_t += delta
	var p: Vector3 = _plane.position
	var f: Vector3 = _plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	var left := Vector2(-fwd.y,fwd.x)
	var vp := _plane_speed()
	var p2 := Vector2(p.x,p.z)
	_goal = pos+_intercept(p2,fwd,vp)*30.0
	# _side is the far side (where it runs off to); across once it is there.
	var across := (pos-p2).dot(left)*_side > 1.0
	if across or _phase_t > ENTER_MOST:
		phase = &"run"
		_phase_t = 0.0
		_course = fwd.angle()+_side*BREAK
		stats.crossed_at = snappedf((pos-p2).dot(fwd),0.1)
		stats.crossed_t = snappedf(_run,0.01)
	return vp*ENTER_SPEED

## The way (unit) that brings it, at ENTER_SPEED times the plane's speed
## `vp`, onto the plane's line CROSS_AHEAD s ahead of it (the plane flying on
## straight): its velocity is the plane's plus a part along the line from it
## to that spot, in the plane's frame.
func _intercept(p2: Vector2, fwd: Vector2, vp: float) -> Vector2:
	var rel := pos-p2
	var to := fwd*(vp*CROSS_AHEAD-rel.dot(fwd))-fwd.orthogonal()*rel.dot(fwd.orthogonal())
	if to.dot(fwd) < 4.0: to += fwd*(4.0-to.dot(fwd))
	var u := to.normalized()
	var fu := fwd.dot(u)
	var k := ENTER_SPEED
	var lam := vp*(-fu+sqrt(fu*fu+k*k-1.0))
	return (fwd*vp+u*lam).normalized()

## The run's step: its own course, chased by the plane. Its speed.
func _run_on(delta: float, surge: float) -> float:
	_phase_t += delta
	var p: Vector3 = _plane.position
	var f: Vector3 = _plane.forward()
	var fwd := Vector2(f.x,f.z).normalized()
	var p2 := Vector2(p.x,p.z)
	var rel := pos-p2
	var along := rel.dot(fwd)
	var vp := _plane_speed()
	var ahead := lerpf(RUN_AHEAD.x,RUN_AHEAD.y,clampf(0.5+1.1*_noise.get_noise_1d(time*0.45+100.0),0.0,1.0))
	ahead = maxf(ahead,want_ahead)
	if not is_nan(want_at.x):
		# A push-up due: it runs for the spot on the plane's line (as it led),
		# its course following the way it goes.
		var to := want_at-pos
		var cut := clampf((to.length()-15.0)/30.0,0.0,1.0)
		_goal = want_at+fwd*lerpf(maxf(speed*0.9,20.0),8.0,cut)
		_course = heading
	else:
		# Its own way: a slow wander...
		_course += WANDER*clampf(2.0*_noise.get_noise_1d(time*0.25+400.0),-1.0,1.0)*delta
		_into_woods(fwd,delta)
		var cv := Vector2.from_angle(_course)
		var out: Vector2 = -land.inward(pos)
		var room: float = land.room(pos)
		if room < RUN_ROOM and out != Vector2.ZERO and cv.dot(out) > -0.3:
			# ...bent along the meadow's edge, the way nearer its course...
			var tang := out.orthogonal()
			if tang.dot(cv) < 0.0: tang = -tang
			var k := clampf((RUN_ROOM-room)/30.0,0.3,1.5)
			_course = rotate_toward(_course,(tang-out*0.35).angle(),RIM_TURN*k*delta)
			stats.rim_bends = float(stats.get("rim_bends",0.0))+delta
		else:
			# ...and back toward the plane's nose when strayed wide of it.
			var off := fwd.angle_to(rel)
			if absf(off) > RUN_OFF or along < 8.0:
				_course = rotate_toward(_course,fwd.angle(),OFF_TURN*delta*clampf(absf(off)/RUN_OFF,0.5,2.0))
		_goal = pos+Vector2.from_angle(_course)*30.0
	# Kept ahead along the plane's nose (it surges and slows for that).
	var gap := ahead-along
	var want := clampf(vp*surge+gap*1.1,vp*0.5,vp*1.8)
	# Lost all the same (the plane turned away hard, or behind it): it sounds.
	var lost := along < 0.0 or rel.length() > RUN_LOST
	_lost = _lost+delta if lost and not _diving else 0.0
	if _lost > LOST_S and not _sounding:
		_sounding = true
		stats.soundings = int(stats.soundings)+1
		var lw := "behind" if along < 0.0 else "far"
		stats.lost_why[lw] = int(stats.lost_why.get(lw,0))+1
	return want

# --- The ridge -------------------------------------------------------------------

func _add_sample(at: Vector2, k: float) -> void:
	stats.samples = int(stats.samples)+1
	_samples.append(_sample(at,forward(),time,k))
	if _samples.size() > CHUNK:
		var mesh := _strip(_samples,[])
		var node := MeshInstance3D.new()
		node.mesh = mesh
		node.material_override = _ridge_mat
		node.set_meta("dies",time+SCAR_LIFE+1.0)
		add_child(node)
		_chunks.append(node)
		stats.chunks = _chunks.size()
		_samples = [_samples.back()]

## One row of the ridge, ready to draw: the land asked at every `every`th point
## across (the bow's rows, redone each frame, ask less), lerped between; its
## arrays laid out once so `_strip` only joins them.
func _sample(at: Vector2, way: Vector2, born: float, k: float, every := 1) -> Dictionary:
	var side := Vector2(-way.y,way.x)
	var hw := HALF_W*(0.85+0.3*k)
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var cols := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var tangents := PackedFloat32Array()
	verts.resize(ACROSS)
	normals.resize(ACROSS)
	cols.resize(ACROSS)
	uv.resize(ACROSS)
	uv2.resize(ACROSS)
	tangents.resize(ACROSS*4)
	var lo := INF
	var hi := -INF
	# A bow row has one slope and colour, from its middle.
	var one := every > 1
	var nm0 := land.normal(at.x,at.y) if one else Vector3.UP
	var col0 := land.colour(at.x,at.y,land.height(at.x,at.y),nm0) if one else Color.BLACK
	var c := 0
	while c < ACROSS:
		var p := at+side*(-1.0+2.0*c/(ACROSS-1))*hw
		var nm := nm0 if one else land.normal(p.x,p.y)
		var y := land.mesh_height(p.x,p.y)+LIFT
		lo = minf(lo,y)
		hi = maxf(hi,y)
		verts[c] = Vector3(p.x,y,p.y)
		normals[c] = nm
		cols[c] = col0 if one else land.colour(p.x,p.y,land.height(p.x,p.y),nm)
		if c > 0:
			for m in range(1,every):
				var i := c-every+m
				var t := float(m)/every
				var q := at+side*(-1.0+2.0*i/(ACROSS-1))*hw
				verts[i] = Vector3(q.x,lerpf(verts[c-every].y,y,t),q.y)
				normals[i] = normals[c-every].lerp(nm,t).normalized()
				cols[i] = cols[c-every].lerp(cols[c],t)
		c += every
	for i in ACROSS:
		uv[i] = Vector2(-1.0+2.0*i/(ACROSS-1),hw)
		uv2[i] = Vector2(born,k)
		tangents[i*4] = side.x
		tangents[i*4+2] = side.y
		tangents[i*4+3] = 1.0
	var flat := side*hw
	var box := AABB(Vector3(at.x,lo,at.y),Vector3.ZERO).expand(Vector3(at.x+flat.x,hi,at.y+flat.y)).expand(Vector3(at.x-flat.x,hi,at.y-flat.y))
	return {"verts": verts, "normals": normals, "cols": cols, "uv": uv, "uv2": uv2, "tangents": tangents, "box": box}

## A bow row between two read from the land.
func _between(a: Dictionary, b: Dictionary, t: float) -> Dictionary:
	var verts: PackedVector3Array = a.verts
	var to: PackedVector3Array = b.verts
	var uv2: PackedVector2Array = a.uv2
	var uv2b: PackedVector2Array = b.uv2
	var v := PackedVector3Array()
	var w := PackedVector2Array()
	v.resize(ACROSS)
	w.resize(ACROSS)
	for i in ACROSS:
		v[i] = verts[i].lerp(to[i],t)
		w[i] = uv2[i].lerp(uv2b[i],t)
	return {"verts": v, "normals": a.normals, "cols": a.cols, "uv": a.uv, "uv2": w, "tangents": a.tangents, "box": a.box.merge(b.box)}

## The live chunk: the samples since the last whole chunk, the head and the
## bow ahead of it (born in the future, rising).
func _rebuild_live() -> void:
	var extra: Array = []
	if active and strength > 0.0 and not wet:
		var last := _sample(pos,forward(),time,strength,BOW_EVERY)
		extra.append(last)
		var bow_len := BOW*maxf(speed,4.0)
		# Every BOW_ROWS-th row reads the land, the rows between are lerped.
		for i in range(BOW_ROWS,NOSE+1,BOW_ROWS):
			var d := bow_len*float(i)/NOSE
			var at := pos+forward()*d
			# The bow stops at the water's edge.
			if _wet_at(at): break
			var row := _sample(at,forward(),time+d/maxf(speed,4.0),strength,BOW_EVERY)
			for m in range(1,BOW_ROWS): extra.append(_between(last,row,float(m)/BOW_ROWS))
			extra.append(row)
			last = row
	if _samples.size()+extra.size() < 2:
		_live.mesh = null
		return
	if _live_mesh == null: _live_mesh = ArrayMesh.new()
	_live.mesh = _strip(_samples,extra,_live_mesh)

func _finish_live() -> void:
	if _samples.size() >= 2:
		var node := MeshInstance3D.new()
		node.mesh = _strip(_samples,[])
		node.material_override = _ridge_mat
		node.set_meta("dies",time+SCAR_LIFE+1.0)
		add_child(node)
		_chunks.append(node)
	_samples = []
	_live.mesh = null

func _drop_old_chunks() -> void:
	while not _chunks.is_empty() and time > float((_chunks[0] as Node).get_meta("dies")):
		(_chunks.pop_front() as Node).queue_free()
	stats.chunks = _chunks.size()

func _strip(a: Array, b: Array, into: ArrayMesh = null) -> ArrayMesh:
	var rows: Array = a+b
	var n := rows.size()
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var colours := PackedColorArray()
	var uv := PackedVector2Array()
	var uv2 := PackedVector2Array()
	var box: AABB = rows[0].box
	for s: Dictionary in rows:
		verts.append_array(s.verts)
		normals.append_array(s.normals)
		tangents.append_array(s.tangents)
		colours.append_array(s.cols)
		uv.append_array(s.uv)
		uv2.append_array(s.uv2)
		box = box.merge(s.box)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TANGENT] = tangents
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_INDEX] = _indices(n)
	var mesh := into if into != null else ArrayMesh.new()
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	# The heave lifts it past the ground's box: room for it.
	mesh.custom_aabb = box.grow(5.0)
	return mesh

## The strip's triangles for `n` rows, kept (the live strip asks each frame).
func _indices(n: int) -> PackedInt32Array:
	if _strip_index.has(n): return _strip_index[n]
	var index := PackedInt32Array()
	index.resize((n-1)*(ACROSS-1)*6)
	var k := 0
	for r in n-1:
		for c in ACROSS-1:
			var i0 := r*ACROSS+c
			var i1 := i0+ACROSS
			# Clockwise from above (Godot's front face, as the ground's).
			index[k] = i0
			index[k+1] = i1
			index[k+2] = i0+1
			index[k+3] = i0+1
			index[k+4] = i1
			index[k+5] = i1+1
			k += 6
	_strip_index[n] = index
	return index

# --- The grass -------------------------------------------------------------------

func _stamp_grass() -> void:
	if react == null or strength <= 0.05: return
	var overlap := maxf(2.0*GRASS_REACH/GRASS_STEP,1.0)
	stats.stamps = int(stats.stamps)+1
	# Parted and pressed in stretches, barely stirred between: the tail
	# breaks up, the grass standing back over the furrow.
	var held := _noise.get_noise_1d(time*2.6+300.0) > 0.1
	react._add({"at": pos, "way": forward()*0.25, "strength": GRASS_PUSH*strength*2.2/overlap*3.0*(0.7 if held else 0.2),
		"swirl": 0.0, "reach": GRASS_REACH*(0.85+0.3*strength), "front": 0.0, "hold": GRASS_HOLD*_rng.randf_range(0.6,1.4),
		# Pressed flat in stretches, only parted between: the tail breaks up.
		"press": 0.45 if held else 0.1})

# --- Clods and pebbles -----------------------------------------------------------

func _kick(delta: float) -> void:
	var pace := clampf(speed/ROAM_SPEED,0.4,1.6)
	if wet:
		_spray_carry += SPRAY_RATE*strength*pace*delta
		while _spray_carry >= 1.0:
			_spray_carry -= 1.0
			_spawn_drop(false)
	else:
		_clod_carry += CLOD_RATE*strength*pace*delta
		while _clod_carry >= 1.0:
			_clod_carry -= 1.0
			_spawn_clod()
		# The spout comes in gouts: a slow noise gates it.
		var gout := clampf(0.55+0.9*_noise.get_noise_1d(time*2.3+50.0),0.15,1.3)
		_spout_carry += SPOUT_RATE*strength*strength*pace*gout*delta
		while _spout_carry >= 1.0:
			_spout_carry -= 1.0
			_spawn_spout()
	_dust_carry += DUST_RATE*strength*clampf(speed/ROAM_SPEED,0.5,1.4)*delta*(1.6 if wet else 1.0)
	while _dust_carry >= 1.0:
		_dust_carry -= 1.0
		_spawn_dust()

func _spawn_clod() -> void:
	if _clods.size() >= CLODS: _clods.pop_front()
	var side := Vector2(-forward().y,forward().x)
	var u := _rng.randf_range(-1.0,1.0)
	var at := pos-forward()*_rng.randf_range(0.0,2.5)+side*u*1.2
	var kind := _rng.randf()
	var colour := SOD if kind < 0.45 else (SOIL if kind < 0.8 else PEBBLE)
	colour = colour.lerp(Color.BLACK,_rng.randf()*0.25)
	var size := _rng.randf_range(0.14,0.42)*(0.6 if kind >= 0.8 else 1.0)*(0.7+0.5*strength)
	var out := side*signf(u if u != 0.0 else 1.0)*_rng.randf_range(1.5,4.5)
	var fwd := forward()*speed*_rng.randf_range(0.05,0.3)
	var v := Vector3(out.x+fwd.x,_rng.randf_range(3.0,7.5)*strength,out.y+fwd.y)
	_clods.append({"p": Vector3(at.x,land.height(at.x,at.y)+0.3,at.y), "v": v,
		"spin": Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
		"rate": _rng.randf_range(4.0,14.0), "turn": 0.0, "size": size, "colour": colour,
		"bounced": false, "rest": -1.0, "squash": Vector3(_rng.randf_range(0.8,1.3),_rng.randf_range(0.6,1.0),_rng.randf_range(0.8,1.2))})

## A clod flung high off the head, arcing on over it.
func _spawn_spout() -> void:
	if _clods.size() >= CLODS: _clods.pop_front()
	var side := Vector2(-forward().y,forward().x)
	var at := pos+forward()*_rng.randf_range(-0.5,0.8)+side*_rng.randf_range(-0.5,0.5)
	var kind := _rng.randf()
	var colour := SOD if kind < 0.35 else (SOIL if kind < 0.9 else PEBBLE)
	colour = colour.lerp(Color.BLACK,_rng.randf()*0.15).lightened(0.12)
	var size := _rng.randf_range(0.18,0.5)*(0.6 if kind >= 0.9 else 1.0)
	var fwd := forward()*speed*_rng.randf_range(SPOUT_KEEP.x,SPOUT_KEEP.y)
	var out := side*_rng.randf_range(-2.2,2.2)
	var v := Vector3(fwd.x+out.x,_rng.randf_range(SPOUT_UP.x,SPOUT_UP.y)*strength,fwd.y+out.y)
	_clods.append({"p": Vector3(at.x,land.height(at.x,at.y)+1.2,at.y), "v": v,
		"spin": Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
		"rate": _rng.randf_range(4.0,14.0), "turn": 0.0, "size": size, "colour": colour,
		"bounced": false, "rest": -1.0, "squash": Vector3(_rng.randf_range(0.8,1.3),_rng.randf_range(0.6,1.0),_rng.randf_range(0.8,1.2))})
	stats.spout = int(stats.get("spout",0))+1

## Earth thrown off a point (a push-up cracking out, or falling off it):
## `n` clods from `at` (world, y their start), out `out` m/s, up `up` m/s.
func throw_earth(at: Vector3, n: int, out: float, up: float, spread := 1.0) -> void:
	for i in n:
		if _clods.size() >= CLODS: _clods.pop_front()
		var a := _rng.randf()*TAU
		var dir := Vector2(cos(a),sin(a))
		var p := at+Vector3(dir.x,0.0,dir.y)*_rng.randf_range(0.2,spread)
		var kind := _rng.randf()
		var colour := SOD if kind < 0.4 else (SOIL if kind < 0.85 else PEBBLE)
		colour = colour.lerp(Color.BLACK,_rng.randf()*0.25)
		var size := _rng.randf_range(0.12,0.38)*(0.6 if kind >= 0.85 else 1.0)
		var h := dir*out*_rng.randf_range(0.4,1.0)
		_clods.append({"p": p, "v": Vector3(h.x,up*_rng.randf_range(0.5,1.0),h.y),
			"spin": Vector3(_rng.randf_range(-1,1),_rng.randf_range(-1,1),_rng.randf_range(-1,1)).normalized(),
			"rate": _rng.randf_range(4.0,14.0), "turn": 0.0, "size": size, "colour": colour,
			"bounced": false, "rest": -1.0, "squash": Vector3(_rng.randf_range(0.8,1.3),_rng.randf_range(0.6,1.0),_rng.randf_range(0.8,1.2))})

## Water thrown off a point: `n` drops from `at` (world), out and up (m/s),
## and a ring on the pond when `ring` > 0.
func throw_water(at: Vector3, n: int, out: float, up: float, ring := 0.0) -> void:
	if ring > 0.0:
		_wake[_wake_i] = Vector4(at.x,at.z,time,ring)
		_wake_i = (_wake_i+1) % WAKES
	for i in n:
		if _sprays.size() >= SPRAYS: _sprays.pop_front()
		var a := _rng.randf()*TAU
		var dir := Vector2(cos(a),sin(a))
		var h := dir*out*_rng.randf_range(0.3,1.0)
		_sprays.append({"p": at+Vector3(dir.x,0.0,dir.y)*_rng.randf_range(0.1,0.9), "v": Vector3(h.x,up*_rng.randf_range(0.4,1.0),h.y),
			"sea": land.water_y(at.x,at.z), "size": _rng.randf_range(0.05,0.13)})

## A puff of dust (or mist over water) at a point.
func puff(at: Vector3, n: int, water := false) -> void:
	for i in n:
		if _dusts.size() >= DUSTS: _dusts.pop_front()
		var a := _rng.randf()*TAU
		var d := Vector2(cos(a),sin(a))*_rng.randf_range(0.6,2.0)
		_dusts.append({"p": at+Vector3(d.x*0.5,0.3,d.y*0.5), "v": Vector3(d.x,_rng.randf_range(0.6,1.4),d.y),
			"age": 0.0, "life": DUST_LIFE*_rng.randf_range(0.6,1.0), "size": _rng.randf_range(0.7,1.2),
			"shade": _rng.randf_range(0.85,1.1), "colour": MIST if water else DUST, "most": 0.24})

func _step_clods(delta: float) -> void:
	var i := 0
	while i < _clods.size():
		var c: Dictionary = _clods[i]
		var p: Vector3 = c.p
		if float(c.rest) < 0.0:
			# The land only when it's coming down (a clod's flight is all a
			# frame's work).
			var ground := float(c.get("g",-INF))
			var v0: Vector3 = c.v
			if v0.y < 0.0 and p.y < ground+3.0 or ground == -INF:
				ground = land.height(p.x,p.z)
				c.g = ground
			var v: Vector3 = c.v
			v.y -= GRAVITY*delta
			v *= 1.0-0.3*delta
			p += v*delta
			c.turn = float(c.turn)+float(c.rate)*delta
			if p.y < ground+float(c.size)*0.3 and v.y < 0.0:
				p.y = ground+float(c.size)*0.3
				if not c.bounced and v.y < -2.0:
					c.bounced = true
					v = Vector3(v.x*0.45,-v.y*0.3,v.z*0.45)
					c.rate = float(c.rate)*0.5
				else:
					c.rest = 0.0
					v = Vector3.ZERO
			c.v = v
		else:
			c.rest = float(c.rest)+delta
			# Lying a moment, then sinking into the grass.
			if float(c.rest) > 1.6: p.y -= delta*0.35
			if float(c.rest) > 3.2:
				_clods.remove_at(i)
				continue
		c.p = p
		i += 1
	var n := _clods.size()
	_clod_mm.visible_instance_count = n
	for k in n:
		var c: Dictionary = _clods[k]
		# 2.3: the ragged lump (GritMesh.lump) is some 15% smaller than the
		# round clod it replaced; at 2.0 the spout thinned from the chase cam.
		var b := Basis(c.spin,float(c.turn)).scaled(Vector3(c.squash)*float(c.size)*2.3)
		_clod_mm.set_instance_transform(k,Transform3D(b,c.p))
		_clod_mm.set_instance_color(k,c.colour)
	stats.clods = n

# --- Dust ------------------------------------------------------------------------

func _spawn_dust() -> void:
	if _dusts.size() >= DUSTS: _dusts.pop_front()
	var side := Vector2(-forward().y,forward().x)
	var at := pos-forward()*_rng.randf_range(0.5,3.0)+side*_rng.randf_range(-1.0,1.0)
	var drift := forward()*speed*0.12+side*_rng.randf_range(-1.2,1.2)
	var y: float = land.water_y(at.x,at.y)+0.5 if wet else land.height(at.x,at.y)+0.4
	_dusts.append({"p": Vector3(at.x,y,at.y), "v": Vector3(drift.x,_rng.randf_range(0.6,1.4)*(1.5 if wet else 1.0),drift.y),
		"age": 0.0, "life": DUST_LIFE*_rng.randf_range(0.7,1.3)*(0.7 if wet else 1.0), "size": _rng.randf_range(0.6,1.1)*(1.3 if wet else 1.0),
		"shade": _rng.randf_range(0.85,1.1), "colour": MIST if wet else DUST, "most": 0.22 if wet else 0.2})

func _step_dust(delta: float) -> void:
	var i := 0
	while i < _dusts.size():
		var d: Dictionary = _dusts[i]
		d.age = float(d.age)+delta
		if float(d.age) >= float(d.life):
			_dusts.remove_at(i)
			continue
		var v: Vector3 = d.v
		v *= 1.0-1.6*delta
		v.y = maxf(v.y,0.15)
		d.v = v
		d.p = Vector3(d.p)+v*delta
		i += 1
	var n := _dusts.size()
	_dust_mm.visible_instance_count = n
	for k in n:
		var d: Dictionary = _dusts[k]
		var t := float(d.age)/float(d.life)
		var s := float(d.size)*(1.0+2.6*sqrt(t))
		_dust_mm.set_instance_transform(k,Transform3D(Basis.IDENTITY.scaled(Vector3.ONE*s),d.p))
		var a := smoothstep(0.0,0.08,t)*(1.0-smoothstep(0.2,1.0,t))*float(d.most)
		var c: Color = (d.colour as Color)*float(d.shade)
		_dust_mm.set_instance_custom_data(k,Color(c.r,c.g,c.b,a))
	stats.dust = n

# --- The wake --------------------------------------------------------------------

func _drop_wake(at: Vector2, k: float) -> void:
	_wake[_wake_i] = Vector4(at.x,at.y,time,k)
	_wake_i = (_wake_i+1) % WAKES
	stats.wakes = int(stats.wakes)+1
	land.wake_point(at,time,k)

## Going in or coming out: a ring and a burst of spray.
func _splash(n: int) -> void:
	stats.splashes = int(stats.splashes)+1
	_drop_wake(pos,1.6*maxf(strength,0.5))
	for i in n: _spawn_drop(true)

func _feed_pond() -> void:
	land.wake_tick(time,pos,forward(),wet_k)
	var m := land.pond_material
	# On the game's land, nothing to send while no wake shows.
	if m == null or (land.probes and not land.wake_busy()): return
	m.set_shader_parameter("now",time)
	m.set_shader_parameter("wake",_wake)
	m.set_shader_parameter("head",Vector4(pos.x,pos.y,strength*wet_k,speed))
	m.set_shader_parameter("head_way",forward())

## A drop thrown off the bulge: most out to the sides and up, some in a
## plume left behind the head; `burst` a splash's, flung every way.
func _spawn_drop(burst: bool) -> void:
	if _sprays.size() >= SPRAYS: _sprays.pop_front()
	var fwd := forward()
	var side := Vector2(-fwd.y,fwd.x)
	var at: Vector2
	var v: Vector3
	if burst:
		var a := _rng.randf()*TAU
		var out := Vector2(cos(a),sin(a))
		at = pos+out*_rng.randf_range(0.3,2.0)
		var h := out*_rng.randf_range(1.0,5.0)+fwd*speed*0.25
		v = Vector3(h.x,_rng.randf_range(4.0,10.0),h.y)
	elif _rng.randf() < 0.3:
		at = pos-fwd*_rng.randf_range(1.5,4.5)+side*_rng.randf_range(-0.6,0.6)
		var h := fwd*speed*_rng.randf_range(0.1,0.3)+side*_rng.randf_range(-0.8,0.8)
		v = Vector3(h.x,_rng.randf_range(5.0,10.0)*strength,h.y)
	else:
		var u := _rng.randf_range(-1.0,1.0)
		var sgn := signf(u) if u != 0.0 else 1.0
		at = pos+fwd*_rng.randf_range(-1.5,1.5)+side*(sgn*1.2+u)
		var h := side*sgn*_rng.randf_range(2.0,6.0)+fwd*speed*_rng.randf_range(0.2,0.55)
		v = Vector3(h.x,_rng.randf_range(2.5,7.0)*strength,h.y)
	var sea: float = land.water_y(at.x,at.y)
	_sprays.append({"p": Vector3(at.x,sea+0.3,at.y), "sea": sea, "v": v, "size": _rng.randf_range(0.05,0.14)})

func _step_spray(delta: float) -> void:
	var i := 0
	while i < _sprays.size():
		var d: Dictionary = _sprays[i]
		var v: Vector3 = d.v
		v.y -= GRAVITY*delta
		v *= 1.0-0.9*delta
		var p: Vector3 = (d.p as Vector3)+v*delta
		if p.y < float(d.get("sea",-INF)) and v.y < 0.0:
			_sprays.remove_at(i)
			continue
		d.v = v
		d.p = p
		i += 1
	var n := _sprays.size()
	_spray_mm.visible_instance_count = n
	for k in n:
		var d: Dictionary = _sprays[k]
		var v: Vector3 = d.v
		var size := float(d.size)
		# Drawn as a streak along its flight.
		var up := v.normalized() if v.length() > 0.1 else Vector3.UP
		var x := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(up)
		var stretch := 1.0+v.length()*0.12
		_spray_mm.set_instance_transform(k,Transform3D(Basis(x*size,up*size*stretch,z*size),d.p))
		_spray_mm.set_instance_color(k,SPRAY)
	stats.spray = n
