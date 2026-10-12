extends Node3D
## An airship tows an islet: a sky event. Now and then, while the sky is out
## (scripts/sky_islands.gd `show_air`), a little cargo airship of the sky
## folk (scripts/airship_build.gd) comes in over a lone islet near the eye
## (scripts/sky_islets.gd), slows to a hover over it, lowers grapples on
## three lines that bite its rim, winds them taut, and tears it free: a
## shudder, a burst of dust off its rim and pebbles tumbling off its rock.
## Then it tows it away across the sky, the islet swinging on its tethers
## behind and below, and moors it somewhere new, lets go and flies off; or,
## now and then, carries it on out of view. A moored islet stays where it
## was left for the session (SkyIslets `moved`); one carried off is gone
## for the session. Nothing of it is saved.
##
## Only lone islets: never a cluster's member, a claimable island or the
## plate. The islet stays in the islets' `built` the whole time, so it is a
## solid to the plane and can be perched on; marked `fixed` while towed so
## it is never let go. Its motion is only ever its record's `home` moving
## (islets are never turned), the bob riding on top, so the perched pilot,
## whose feet are kept in the islet's own frame (scripts/wanderer_eye.gd
## `_advance_perch`), is carried with the ground exactly: no slide, no
## jitter. To keep the pilot and the camera drawn in the same frame's
## place as the islet, this runs before the wanderer each frame
## (process_priority), moving the islet's node itself.
##
## This node stands at the islets' origin (home coordinates), so the swaps
## that move the world (SkyIslands `arrive`) carry the ship, its lines and
## its dust along with the islet.
##
## Its timing (`EVERY`) counts only while the sky is out. --airship-now
## starts one at once by the first islet in reach of the first flight
## (for testing and captures); --no-airship leaves the sky without.

const Build = preload("res://scripts/airship_build.gd")
const Dust = preload("res://scripts/airship_dust.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyPeaks = preload("res://scripts/sky_peaks.gd")
const SkyTowers = preload("res://scripts/sky_towers.gd")
const SkyForestIsles = preload("res://scripts/sky_forest_isles.gd")
const IslanderFigure = preload("res://scripts/islander_figure.gd")
const StoneLampLights = preload("res://scripts/stone_lamp_lights.gd")
const SURFACE := preload("res://shaders/airship_surface.gdshader")
const HALO := preload("res://shaders/cluster_halo.gdshader")

## Seconds of open sky before the first event (least, most) and between
## events after.
const FIRST := Vector2(90.0,180.0)
const EVERY := Vector2(180.0,330.0)
## An islet is picked between these distances from the eye (m, flat), in
## front of it (the eye's forward on the flat, dot at least FACING), no
## wider than REACH m from its middle to its rim.
const PICK := Vector2(110.0,420.0)
const FACING := 0.35
const REACH := 9.5
## The ship turns up SPAWN m off its hover, behind the way it will tow,
## SPAWN_UP m higher, and fades in over FADE s.
const SPAWN := 240.0
const SPAWN_UP := 22.0
## With --airship-now it turns up nearer (m), for a quick look.
const SPAWN_NOW := 110.0
const FADE := 4.0
## The ship's cruise (m/s), its towing speed, how fast it gathers speed
## (m/s²), its turn (rad/s at most), and how near it comes before it eases
## off (m per m/s).
const CRUISE := 9.0
const TOW_SPEED := 3.6
const ACCEL := 0.9
const TOW_ACCEL := 0.22
const TURN := 0.22
const EASE := 3.2
## The hover: the deck at least HOVER m over the islet's middle, and
## CLEAR m over its highest crown.
const HOVER := 11.0
const CLEAR := 5.5
## Seconds of each step: lowering the grapples, their bite, the lines
## winding taut, the tear, settling at the mooring, and letting go.
const LOWER := 5.0
const BITE := 1.1
const TAUT := 2.6
const TEAR := 2.6
const SETTLE := 4.5
const RELEASE := 3.4
## The release (all tunable): under the still ship the islet is let down
## LOWERED of the LIFT it was raised (the rest it drops on its own). Then
## the grapples pop free, POP m up and out over POP_TIME s, and the lines
## spring back up to the winch over REEL s, overshooting a little (REEL_BOUNCE
## rad/s of wobble). Freed, the islet spins about up by SPIN turns (least,
## most; either way), easing in over SPIN_IN of the spin and out over the
## rest (its rate falling as (1-v)^SPIN_FALL), SPIN_TIME s plus SPIN_PER s a
## turn; at once it drops, kicked down at
## DROP m/s, and rebounds on a spring (stiffness 1/s², damping 1/s) from
## where it hung to where it first stood, settling into the islets' own bob;
## a little dust is shaken off it.
const LOWERED := 0.5
const POP := Vector2(0.8,0.6)
const POP_TIME := 0.35
const REEL := 1.9
const REEL_BOUNCE := 7.5
const SPIN := Vector2(0.25,0.8)
const SPIN_IN := 0.12
const SPIN_FALL := 1.4
const SPIN_TIME := 8.0
const SPIN_PER := 11.0
const BOUNCE := Vector2(1.5,0.5)
const DROP := 0.5
const FREE_PUFFS := 18
const FREE_PEBBLES := 12
## The tear: how high the islet is lifted (m), how hard it shudders (m)
## and how fast (Hz); dust puffs and pebbles let go.
const LIFT := 2.4
const SHUDDER := 0.14
const SHUDDER_RATE := 11.0
const TEAR_PUFFS := 60
const TEAR_PEBBLES := 40
## The tow: how far (m, least and most) to the mooring, the islet's spring
## to its place under the ship (1/s²) and its damping (1/s), how far behind
## the ship's way it trails (s of the ship's speed), and its sway (m, s).
const TOW_DISTANCE := Vector2(230.0,330.0)
const SPRING := 0.55
const DAMP := 0.75
const TRAIL := 1.6
const SWAY := Vector2(0.7,10.0)
## A pebble off the towed islet now and then (s between, least and most).
const TRICKLE := Vector2(0.7,2.2)
## Carried on out of view one time in AWAY (never with the pilot on it):
## gone once this far from the eye (m).
const AWAY := 0.3
const AWAY_GONE := 960.0
## The mooring keeps this far off any other islet (m) and an island's spot
## (SkyIslets CLEAR); its way there is checked every PATH_STEP m.
const MOOR_APART := 55.0
const PATH_STEP := 30.0
## Leaving: it climbs (m/s) as it goes, and is let go past GONE m from the
## eye or after LEAVE s.
const CLIMB := 1.4
const GONE := 700.0
const LEAVE := 70.0
## Too far from the eye mid-event (m), it ends at once where it is.
const LOST := 1150.0
## The night's glow: windows and lantern, their halos (size near m,
## strength), the lantern's light (reach m, energy) and the halos' least
## size far off (share of distance, as shaders/cluster_halo.gdshader).
const WARM := Color("ffb466")
const HALO_WINDOW := Vector2(1.5,0.65)
const HALO_LANTERN := Vector2(2.4,0.75)
const LIGHT := Vector2(10.0,1.6)
const FAR_SIZE := 0.03
## ...but never more than FAR_PIXELS pixels across (night light round 1:
## at 500 m FAR_SIZE alone made each light a 15 m disc, the ship a blob),
## so far off the ship is its dark shape with a few warm points on it.
const FAR_PIXELS := 4.0
## The cargo lamp under the keel at night, shining down on the load: its
## reach (m), cone (degrees) and energy.
const CARGO_LAMP := Vector3(34.0,32.0,2.2)
## The tow lines: their thickness (m half), their segments, their sag when
## slack and when taut (share of length), and their colour.
const LINE := 0.06
const LINE_SEGMENTS := 16
const SLACK := 0.1
const TAUT_SAG := 0.008
const LINE_COLOUR := Color("a08a62")

## The islets (scripts/sky_islets.gd) and the scene (daylight), set by
## SkyIslands; `eye_override` (home coordinates) stands in for the camera
## (tests, captures), INF when unset.
var islets: Node3D
var scene: Node
var eye_override := Vector3.INF
## Seconds of open sky till the next event.
var wait := 0.0
## The event under way, or {}: {key, b (the islet's built record), phase,
## t (s into it), pos, vel (the ship's, home), heading, hover, anchors
## (islet frame), islet (its tow place), ivel, lift, dest, dir, away, age}.
var event := {}
## Each phase the event has been through, for probes.
var phases: Array[String] = []
## For tests and probes: a daylight override (0..1), or -1; and a speed-up
## of the event's own clock.
var daylight_override := -1.0
var pace := 1.0
## The odds an event carries its islet off (AWAY; tests set it).
var away_odds := AWAY
var night := 0.0
## Starts one at once (--airship-now) as soon as an islet is in reach.
var now := false
var enabled := true

var _ship: Node3D
var _body: MeshInstance3D
var _props: Array[Node3D] = []
var _drum: MeshInstance3D
var _windows: MeshInstance3D
var _halos: MultiMeshInstance3D
var _light: OmniLight3D
var _cargo: SpotLight3D
var _crew: Array[Node3D] = []
var _lines: MeshInstance3D
var _grapples: Array[MeshInstance3D] = []
var _dust: Node3D
var _glow: StandardMaterial3D
var _halo: ShaderMaterial
var _line_material: ShaderMaterial
var _rng := RandomNumberGenerator.new()
var _clock := 0.0
var _trickle := 0.0

static func flag_now() -> bool:
	return "--airship-now" in preload("res://scripts/launch_args.gd").user_args()

static func flag_off() -> bool:
	return "--no-airship" in preload("res://scripts/launch_args.gd").user_args()

func _init() -> void:
	name = "SkyAirship"
	# Before the wanderer (-10), so the islet stands where it will be drawn
	# when the perched pilot and the camera are placed on it.
	process_priority = -20
	_rng.randomize()
	now = flag_now()
	enabled = not flag_off()
	wait = _rng.randf_range(FIRST.x,FIRST.y)

func _exit_tree() -> void:
	clear()

## Ends any event at once (the sky cleared or the world changed): the ship
## and its lines go; an islet mid-tow is left where it is.
func clear() -> void:
	if not event.is_empty(): _end(true)
	event = {}

## A new world: what was moved in the last one is forgotten.
func forget_session() -> void:
	clear()
	if islets != null:
		islets.moved.clear()
		islets.turned.clear()
	now = flag_now()
	wait = _rng.randf_range(FIRST.x,FIRST.y)

func _process(delta: float) -> void:
	if islets == null or not is_inside_tree(): return
	if not islets.is_visible_in_tree() or not visible: return
	advance(delta)

## One step of the sky's clock: count to the next event, or carry the one
## under way on.
func advance(delta: float) -> void:
	if islets == null: return
	position = islets.position
	var eye: Variant = _eye()
	if eye == null: return
	_clock += delta
	if event.is_empty():
		if not enabled: return
		wait -= delta
		if now or wait <= 0.0:
			if start(eye,now,SPAWN_NOW if now else SPAWN): now = false
			elif wait <= 0.0: wait = 8.0
		return
	_step(delta*pace,eye)

## The eye in home coordinates, or null.
func _eye() -> Variant:
	if eye_override != Vector3.INF: return eye_override
	var viewport := get_viewport() if is_inside_tree() else null
	var camera := viewport.get_camera_3d() if viewport != null else null
	if camera == null: return null
	return camera.global_position-islets.global_position

## The way the eye looks, flat (home), or zero if unknown.
func _eye_forward() -> Vector3:
	if eye_override != Vector3.INF: return Vector3.ZERO
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	if camera == null: return Vector3.ZERO
	var f := -camera.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.ZERO

# --- Starting one -----------------------------------------------------------------

## A lone islet the eye can see is chosen and an airship sent for it; with
## `forced` any lone islet near the eye will do. False if none would do.
func start(eye: Vector3, forced := false, spawn := SPAWN) -> bool:
	var key: String = pick(eye,forced)
	if key == "": return false
	return start_on(key,eye,spawn)

## Starts the event on the built islet `key` (a lone one), its ship coming
## in from off to the side; false if there is nowhere to tow it.
func start_on(key: String, eye: Vector3, spawn := SPAWN) -> bool:
	var b: Dictionary = islets.built.get(key,{})
	if b.is_empty() or not is_instance_valid(b.node): return false
	var home: Vector3 = b.home
	var away: bool = _rng.randf() < away_odds and b.node != islets.pinned
	var dir: Variant = _tow_way(home,eye,away)
	if dir == null and away:
		away = false
		dir = _tow_way(home,eye,false)
	if dir == null: return false
	var way: Vector3 = dir.way
	var shape: RefCounted = b.shape
	var top := float(shape.ground_at(Vector2.ZERO))
	for c: Vector4 in shape.crowns: top = maxf(top,float(shape.ground_at(Vector2(c.x,c.y)))+c.z)
	var hover := home+Vector3.UP*maxf(HOVER,top+CLEAR)
	# In from behind the way it will tow, a little to the eye's side, so it
	# crosses the view coming in and goes on the same way.
	var side := Vector3(-way.z,0.0,way.x)
	if side.dot(eye-home) < 0.0: side = -side
	var from := hover-way*spawn+side*spawn*0.35+Vector3.UP*SPAWN_UP*spawn/SPAWN
	if Vector2(from.x-eye.x,from.z-eye.z).length() < 60.0: from = hover-way*spawn-side*spawn*0.35+Vector3.UP*SPAWN_UP*spawn/SPAWN
	var to_hover := hover-from
	_make_ship()
	event = {"key":key,"b":b,"phase":"come","t":0.0,"pos":from,"vel":to_hover.normalized()*CRUISE,
		"heading":atan2(-to_hover.x,-to_hover.z),"hover":hover,"anchors":[],"islet":home,"ivel":Vector3.ZERO,
		"rest":home,"start_y":home.y,"dest":dir.dest,"way":way,"away":away,"age":0.0,"lift":0.0,"pitch":0.0,"bank":0.0,
		"was_fixed":bool(b.get("fixed",false)),"turn_rate":0.0}
	b.fixed = true
	b.towed = true
	phases.clear()
	phases.append("come")
	_ship.visible = true
	_place_ship(0.0)
	_set_fade(1.0)
	return true

## The lone islet the event would take, by its key, or "": built, faded in,
## not a cluster's, small enough, in reach and (unless `forced`) before
## the eye.
func pick(eye: Vector3, forced := false) -> String:
	var forward := _eye_forward()
	var best := ""
	var best_score := INF
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		if not lone(b): continue
		if float(b.get("age",SkyIslets.FADE_IN)) < SkyIslets.FADE_IN: continue
		if float(b.shape.reach) > REACH: continue
		var off: Vector3 = b.home-eye
		off.y = 0.0
		var d := off.length()
		if forced:
			if d < 25.0 or d > 600.0: continue
			if d < best_score:
				best_score = d
				best = key
			continue
		if d < PICK.x or d > PICK.y: continue
		if forward != Vector3.ZERO and forward.dot(off/d) < FACING: continue
		var score := absf(d-(PICK.x+PICK.y)*0.5)
		if score < best_score:
			best_score = score
			best = key
	return best

## True for a lone seeded islet: not a cluster's member, not fixed, not in a
## group, not towed already.
static func lone(b: Dictionary) -> bool:
	if b.get("fixed",false) or b.has("group") or b.get("towed",false): return false
	return is_instance_valid(b.get("node"))

## The way the islet will be towed and where to: {way, dest}, or null. A
## mooring TOW_DISTANCE off, clear of the islands' spots, the ranges, the
## cumulus, the forested isles, the clusters' room and every other islet,
## its way there clear too; the way across the eye's view preferred, so
## the tow reads as a long pass. Carried away, the way leads out of view.
func _tow_way(home: Vector3, eye: Vector3, away: bool) -> Variant:
	var to_eye := eye-home
	to_eye.y = 0.0
	to_eye = to_eye.normalized() if to_eye.length() > 0.01 else Vector3.FORWARD
	var across := Vector3(-to_eye.z,0.0,to_eye.x)
	var best: Variant = null
	var best_score := -INF
	var turn := _rng.randf_range(0.0,TAU)
	for k in range(16):
		var a := turn+TAU*k/16.0
		var way := Vector3(cos(a),0.0,sin(a))
		var length := _rng.randf_range(TOW_DISTANCE.x,TOW_DISTANCE.y)
		if away: length = AWAY_GONE+200.0
		var dest := home+way*length
		if not _clear_way(home,dest,away): continue
		var score := absf(way.dot(across))-0.4*maxf(0.0,way.dot(to_eye))
		if away: score = -way.dot(to_eye)
		if score > best_score:
			best_score = score
			best = {"way":way,"dest":dest}
	return best

func _clear_way(home: Vector3, dest: Vector3, away: bool) -> bool:
	var length := Vector2(dest.x-home.x,dest.z-home.z).length()
	var steps := maxi(2,ceili(length/PATH_STEP))
	for s in range(1,steps+1):
		var p := home.lerp(dest,float(s)/steps)
		if not _open(p,s == steps and not away,home): return false
	return true

## True where a towed islet may pass (or, `moor`, stay): no island's spot,
## range, cumulus or forested isle near, no cluster's room, no other islet.
func _open(p: Vector3, moor: bool, home: Vector3) -> bool:
	var cells: RefCounted = islets.cells
	if cells != null and not cells.spots_near(p,SkyIslets.CLEAR*(1.0 if moor else 0.75)).is_empty(): return false
	if SkyPeaks.blocks(p) or SkyTowers.blocks(p) or SkyForestIsles.blocks(p,SkyIslets.CLEAR*0.3): return false
	for k: Vector3 in islets.keep_clear:
		if Vector2(p.x-k.x,p.z-k.y).length() < k.z: return false
	var apart := MOOR_APART if moor else MOOR_APART*0.6
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		var h: Vector3 = b.home
		if h.distance_to(home) < 0.5: continue
		if Vector2(p.x-h.x,p.z-h.z).length() < apart: return false
	# The seeded islets not built yet round it.
	var cell := Vector2i(floori(p.x/SkyIslets.CELL),floori(p.z/SkyIslets.CELL))
	for x in range(-1,2):
		for z in range(-1,2):
			var s: Variant = islets.spot(cell+Vector2i(x,z))
			if s == null or (s as Vector3).distance_to(home) < 0.5: continue
			if Vector2(p.x-s.x,p.z-s.z).length() < apart: return false
	return true

# --- The event --------------------------------------------------------------------

func _step(delta: float, eye: Vector3) -> void:
	var b: Dictionary = event.b
	# The islet gone from under it (the sky cleared), or the eye far off:
	# it ends at once, the islet left where it is.
	if not is_instance_valid(b.get("node")) or islets.built.get(event.key) != b:
		_end(true)
		return
	var far := Vector2(event.pos.x-eye.x,event.pos.z-eye.z).length()
	if far > LOST and b.node != islets.pinned and event.phase != "leave":
		_end(true)
		return
	event.t += delta
	event.age += delta
	if event.age < FADE: _set_fade(1.0-smoothstep(0.0,1.0,event.age/FADE))
	elif event.age-delta < FADE: _set_fade(0.0)
	match str(event.phase):
		"come": _come(delta)
		"lower": _hold(delta)
		"bite": _hold(delta)
		"taut": _taut(delta)
		"tear": _tear(delta)
		"tow": _tow(delta,eye)
		"settle": _settle(delta)
		"release": _hold(delta)
		"leave": _leave(delta,eye)
	if event.is_empty(): return
	if event.has("free"): _free_step(delta)
	_carry_islet()
	_place_ship(delta)
	_draw_lines()
	_animate(delta,eye)
	_next_phase()

func _phase(name_of: String) -> void:
	event.phase = name_of
	event.t = 0.0
	phases.append(name_of)

## The phases' ends: each step on to the next when its time is up.
func _next_phase() -> void:
	var t: float = event.t
	match str(event.phase):
		"lower": if t >= LOWER: _phase("bite")
		"bite": if t >= BITE: _phase("taut")
		"taut":
			if t >= TAUT:
				_phase("tear")
				_burst()
		"tear":
			if t >= TEAR:
				_phase("tow")
				event.ivel = Vector3.ZERO
				event.rel = event.islet-event.pos
		"settle":
			if t >= SETTLE:
				_moor()
				_phase("release")
				_let_go()
		"release":
			if t >= RELEASE:
				_phase("leave")
				var away_from: Vector3 = event.way
				event.leave_way = away_from

## Coming in: on to the hover, easing off as it nears, turning to face the
## way it will tow for the last stretch.
func _come(delta: float) -> void:
	var to: Vector3 = event.hover-event.pos
	var d := to.length()
	var want := minf(CRUISE,d/EASE+0.05)
	_fly(delta,to.normalized()*want if d > 0.01 else Vector3.ZERO,ACCEL)
	var face := atan2(-to.x,-to.z) if d > 30.0 else atan2(-event.way.x,-event.way.z)
	_turn_to(face,delta)
	if d < 0.5 and (event.vel as Vector3).length() < 0.3:
		event.pos = event.hover
		event.vel = Vector3.ZERO
		_hook_points()
		_phase("lower")

## Holding over the islet (lowering, biting, letting go): only a little
## drift on the air.
func _hold(delta: float) -> void:
	_fly(delta,Vector3.ZERO,ACCEL)

## The lines wind taut: the ship strains up a little.
func _taut(delta: float) -> void:
	_fly(delta,Vector3.UP*0.25*sin(PI*event.t/TAUT),ACCEL)

## Torn free: the islet shudders and rises LIFT on its lines, the ship
## rising with it.
func _tear(delta: float) -> void:
	_fly(delta,Vector3.UP*0.4,ACCEL)
	event.lift = LIFT*smoothstep(0.0,1.0,event.t/TEAR)
	event.islet = (event.rest as Vector3)+Vector3.UP*float(event.lift)
	if _rng.randf() < delta*6.0: _shed(1,2)

## Towing: on toward the mooring, gathering speed slowly and easing off to
## a stop over it; the islet hangs on its spring under and behind the ship,
## swaying. Carried away, it goes on till out of view.
func _tow(delta: float, eye: Vector3) -> void:
	var b: Dictionary = event.b
	if event.away and b.node == islets.pinned:
		# The pilot landed on it: it is moored a little further on instead.
		event.away = false
		event.dest = (event.pos as Vector3)+(event.way as Vector3)*60.0
	var to: Vector3 = event.dest-event.pos
	to.y = 0.0
	var d := to.length()
	var want := minf(TOW_SPEED,d/(EASE*2.5)+0.03)
	_fly(delta,to.normalized()*want if d > 0.01 else Vector3.ZERO,TOW_ACCEL)
	if d > 6.0: _turn_to(atan2(-to.x,-to.z),delta)
	_swing(delta)
	_trickle -= delta
	if _trickle <= 0.0:
		_trickle = _rng.randf_range(TRICKLE.x,TRICKLE.y)
		_shed(0,1)
	if event.away:
		var from_eye := Vector2(event.islet.x-eye.x,event.islet.z-eye.z).length()
		if from_eye > AWAY_GONE and b.node != islets.pinned:
			_carried_off()
			return
	elif d < 0.6 and (event.vel as Vector3).length() < 0.15:
		_phase("settle")

## At the mooring: the islet is let down the LIFT it was raised, settling on
## its spring under the still ship.
func _settle(delta: float) -> void:
	_fly(delta,Vector3.ZERO,TOW_ACCEL)
	var k := smoothstep(0.0,1.0,event.t/SETTLE)
	event.rel = Vector3((event.rel as Vector3).x*(1.0-delta),(event.rel as Vector3).y-LIFT*LOWERED*delta/SETTLE,(event.rel as Vector3).z*(1.0-delta))
	_swing(delta,1.0+3.0*k)

## The islet's spring to its place under the ship: `stiff` firms it up.
func _swing(delta: float, stiff := 1.0) -> void:
	var vel: Vector3 = event.vel
	var flat := Vector3(vel.x,0.0,vel.z)
	var across := Vector3(-flat.z,0.0,flat.x).normalized() if flat.length() > 0.05 else Vector3.ZERO
	var sway := across*SWAY.x*sin(TAU*_clock/SWAY.y)*clampf(flat.length()/TOW_SPEED,0.0,1.0)
	var target: Vector3 = (event.pos as Vector3)+(event.rel as Vector3)-flat*TRAIL+sway
	var ivel: Vector3 = event.ivel
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		ivel += (SPRING*stiff*(target-event.islet)-DAMP*sqrt(stiff)*(ivel-vel))*dt
		event.islet += ivel*dt
		left -= dt
	event.ivel = ivel

## Moored: the islet's new home, kept for the session: where it is let go,
## at the height it first stood, turned as far as its spin will take it.
func _moor() -> void:
	var b: Dictionary = event.b
	var home := Vector3((event.islet as Vector3).x,float(event.start_y),(event.islet as Vector3).z)
	event.rest = home
	event.moored = true
	var turns := _rng.randf_range(SPIN.x,SPIN.y)*(1.0 if _rng.randf() < 0.5 else -1.0)
	event.spin = turns*TAU
	event.spin_time = SPIN_TIME+SPIN_PER*absf(turns)
	event.yaw0 = SkyIslets.yaw_of(b)
	islets.moved[_cell_key(b)] = home
	islets.turned[_cell_key(b)] = float(event.yaw0)+float(event.spin)

## Let go: the grapples pop free where they bit, a little dust is shaken
## off, and the islet starts its spin and its drop from where it hung.
func _let_go() -> void:
	var b: Dictionary = event.b
	var node: Node3D = b.node
	var popped := []
	for i in range(Build.TETHERS.size()):
		var anchor: Vector3 = event.anchors[i]
		var out := Vector3(anchor.x,0.0,anchor.z)
		out = node.transform.basis*(out.normalized() if out.length() > 0.01 else Vector3.FORWARD)
		popped.append([node.transform*anchor,out])
	event.popped = popped
	event.free = 0.0
	event.drop = (event.islet as Vector3).y-float(event.start_y)
	event.drop_vel = -DROP
	_shed(FREE_PUFFS,FREE_PEBBLES)

## The freed islet's turn `t` s after it is let go: the spin's share eased
## in over SPIN_IN and out over the rest (a smooth rise of the turn rate
## and a long fall), 0 to 1.
func _spin_share(t: float) -> float:
	var u := clampf(t/float(event.spin_time),0.0,1.0)
	# The rate: up over SPIN_IN, then down as (1-v)^SPIN_FALL; its integral, scaled
	# to reach 1 at the end.
	var a := SPIN_IN
	var ramp := (u*u/(2.0*a)) if u < a else a*0.5
	var tail := 0.0
	if u > a:
		var v := (u-a)/(1.0-a)
		tail = (1.0-a)*(1.0-pow(1.0-v,SPIN_FALL+1.0))/(SPIN_FALL+1.0)
	var whole := a*0.5+(1.0-a)/(SPIN_FALL+1.0)
	return (ramp+tail)/whole

## The freed islet's drop and rebound, and its spin, on along with time.
func _free_step(delta: float) -> void:
	event.free = float(event.free)+delta
	var y: float = event.drop
	var v: float = event.drop_vel
	var left := delta
	while left > 0.0:
		var dt := minf(left,1.0/60.0)
		v += (-BOUNCE.x*y-BOUNCE.y*v)*dt
		y += v*dt
		left -= dt
	event.drop = y
	event.drop_vel = v

## Out of view with its islet: both gone for the session.
func _carried_off() -> void:
	var b: Dictionary = event.b
	islets.moved[_cell_key(b)] = null
	islets.built.erase(event.key)
	if islets.pinned == b.node: islets.pinned = null
	(b.node as Node3D).queue_free()
	event.carried = true
	_end(false)

## Letting go done: away it flies, climbing, along the way it towed, and
## goes once out of view.
func _leave(delta: float, eye: Vector3) -> void:
	var way: Vector3 = event.get("leave_way",event.way)
	_fly(delta,way*CRUISE+Vector3.UP*CLIMB,ACCEL*0.6)
	_turn_to(atan2(-way.x,-way.z),delta)
	var far := Vector2(event.pos.x-eye.x,event.pos.z-eye.z).length()
	var fade := smoothstep(GONE-150.0,GONE,far)
	if event.t > LEAVE-FADE: fade = maxf(fade,smoothstep(LEAVE-FADE,LEAVE,event.t))
	_set_fade(fade)
	if fade >= 1.0: _end(false)

## The ship's velocity eases toward `want` at `accel` (m/s²).
func _fly(delta: float, want: Vector3, accel: float) -> void:
	var vel: Vector3 = event.vel
	var change := want-vel
	var most := accel*delta
	if change.length() > most: change = change.normalized()*most
	vel += change
	event.vel = vel
	event.pos += vel*delta

func _turn_to(heading: float, delta: float) -> void:
	var off := wrapf(heading-float(event.heading),-PI,PI)
	var rate := clampf(off*0.6,-TURN,TURN)
	event.turn_rate = lerpf(float(event.turn_rate),rate,1.0-exp(-delta/1.2))
	event.heading = float(event.heading)+float(event.turn_rate)*delta

## The grapples' bites on the rim (islet frame): where each line's
## direction from under the ship, turned to the ship's heading, meets the
## rim, a little in, at the ground.
func _hook_points() -> void:
	var b: Dictionary = event.b
	var shape: RefCounted = b.shape
	var anchors := []
	var turn := Basis(Vector3.UP,float(event.heading))
	for t: Vector3 in Build.TETHERS:
		var flat := turn*Vector3(t.x,0.0,t.z)
		var a := atan2(flat.z,flat.x)
		var p: Vector2 = shape.rim_point(a)*0.9
		anchors.append(Vector3(p.x,float(shape.ground_at(p))+0.05,p.y))
	event.anchors = anchors

## The islet's record and node at its tow place (shuddering in the tear),
## the bob riding on top as the islets give it.
func _carry_islet() -> void:
	var b: Dictionary = event.b
	if not event.has("anchors") or (event.anchors as Array).is_empty() or event.phase in ["come","lower","bite","taut"]:
		return
	var at: Vector3 = event.islet
	if event.phase == "tear":
		var fall := 1.0-smoothstep(0.0,TEAR,event.t)
		var w: float = TAU*SHUDDER_RATE*event.t
		at += Vector3(sin(w),0.6*sin(w*1.37+1.0),cos(w*0.83))*SHUDDER*(0.35+0.65*fall)
	var node: Node3D = b.node
	if event.has("free"):
		at = (event.rest as Vector3)+Vector3.UP*float(event.drop)
		SkyIslets.turn(b,float(event.yaw0)+float(event.spin)*_spin_share(float(event.free)))
	var bob := node.position-(b.home as Vector3)
	b.home = at
	node.position = at+bob

# --- The ship ---------------------------------------------------------------------

## The ship's pose: at its place, turned to its heading, pitched with its
## pull and banked into its turn, bobbing a little on the air.
func _place_ship(delta: float) -> void:
	var vel: Vector3 = event.vel
	var forward := Vector3(-sin(float(event.heading)),0.0,-cos(float(event.heading)))
	var pull := clampf(forward.dot(vel)/CRUISE,-1.0,1.0)
	var k := 1.0-exp(-delta/1.5) if delta > 0.0 else 1.0
	event.pitch = lerpf(float(event.pitch),-0.05*pull,k)
	event.bank = lerpf(float(event.bank),clampf(-float(event.turn_rate)*0.6,-0.12,0.12),k)
	var bob := Vector3.UP*0.22*sin(_clock*TAU/6.5)
	_ship.transform = Transform3D(Basis.from_euler(Vector3(float(event.pitch),float(event.heading),float(event.bank))),(event.pos as Vector3)+bob)

## Where the islet's grapple `i` is now (this node's frame): with the ship
## while stowed, on its way down, at its bite, or winding back up.
func _grapple_at(i: int) -> Vector3:
	var hard: Vector3 = _ship.transform*(Build.TETHERS[i] as Vector3)
	var stowed := hard+Vector3.DOWN*0.05
	if (event.anchors as Array).is_empty(): return stowed
	var b: Dictionary = event.b
	var bite: Vector3 = (b.node as Node3D).transform*(event.anchors[i] as Vector3)
	var t: float = event.t
	match str(event.phase):
		"lower":
			var u := smoothstep(0.0,1.0,clampf((t-0.25*i)/(LOWER-0.6),0.0,1.0))
			var swing := Vector3(sin(t*1.7+i),0.0,cos(t*1.3+i*2.0))*0.35*sin(PI*u)
			return stowed.lerp(bite+Vector3.UP*0.25,u)+swing
		"bite":
			return bite+Vector3.UP*0.25*(1.0-smoothstep(0.0,0.5,t))
		"release":
			# Popped free up and out, then sprung back up to the winch.
			var from: Vector3 = event.popped[i][0]
			var out: Vector3 = event.popped[i][1]
			var pop := smoothstep(0.0,1.0,clampf(t/POP_TIME,0.0,1.0))
			var popped := from+(Vector3.UP*POP.x+out*POP.y)*(1.0-pow(1.0-pop,2.0))
			var u := clampf((t-POP_TIME-0.08*i)/REEL,0.0,1.0)
			var reel := 1.0-exp(-4.5*u)*cos(REEL_BOUNCE*u)
			reel = lerpf(reel,1.0,smoothstep(0.75,1.0,u))
			var whip := Vector3(cos(t*9.0+i*2.1),0.0,sin(t*8.0+i))*0.35*sin(PI*u)*(1.0-u)
			return popped.lerp(stowed,reel)+whip
		"come", "leave":
			return stowed
	return bite

## How slack line `i` is, 0 taut to 1 slack.
func _slack(i: int) -> float:
	var t: float = event.t
	match str(event.phase):
		"lower": return 0.35
		"bite": return 0.9
		"taut": return 0.9*(1.0-smoothstep(0.0,1.0,t/(TAUT*0.8)))
		"release": return 0.9*(1.0-smoothstep(POP_TIME,POP_TIME+REEL*0.8,t))
		"come", "leave": return 0.0
	return 0.0

## The tow lines, each a faceted rope hung from its hardpoint to its
## grapple: a parabola's sag as long as it is slack, a little down and
## back from the way the islet swings when taut.
func _draw_lines() -> void:
	var mesh := _lines.mesh as ArrayMesh
	mesh.clear_surfaces()
	var showing: bool = not (event.phase in ["come","leave"])
	for g: MeshInstance3D in _grapples: g.visible = showing
	if not showing: return
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var swing: Vector3 = (event.ivel as Vector3)-(event.vel as Vector3) if event.phase in ["tow","settle"] else Vector3.ZERO
	for i in range(Build.TETHERS.size()):
		var a: Vector3 = _ship.transform*(Build.TETHERS[i] as Vector3)
		var g := _grapple_at(i)
		_grapples[i].position = g
		var up := (a-g).normalized()
		_grapples[i].basis = _pointing(up,float(event.heading)+TAU*i/3.0)
		var length := a.distance_to(g)
		var slack := _slack(i)
		var sag := length*lerpf(TAUT_SAG,SLACK,slack)
		var down := (Vector3.DOWN-up*up.dot(Vector3.DOWN)).normalized()
		if down.length() < 0.5: down = Vector3.RIGHT
		var bend := down*sag-swing*0.25*(1.0-slack)
		var points := PackedVector3Array()
		for s in range(LINE_SEGMENTS+1):
			var u := float(s)/LINE_SEGMENTS
			points.append(a.lerp(g,u)+bend*4.0*u*(1.0-u))
		_rope(points,verts,normals)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	var colours := PackedColorArray()
	colours.resize(verts.size())
	colours.fill(LINE_COLOUR.srgb_to_linear())
	arrays[Mesh.ARRAY_COLOR] = colours
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,_line_material)

## A basis whose Y is `up`, turned `spin` about it.
static func _pointing(up: Vector3, spin: float) -> Basis:
	var side := up.cross(Vector3.FORWARD if absf(up.z) < 0.9 else Vector3.RIGHT).normalized()
	var front := side.cross(up).normalized()
	return Basis(side,up,front)*Basis(Vector3.UP,spin)

## A four-sided rope along `points`, flat-shaded.
static func _rope(points: PackedVector3Array, verts: PackedVector3Array, normals: PackedVector3Array) -> void:
	var rings := []
	for s in range(points.size()):
		var along := (points[mini(s+1,points.size()-1)]-points[maxi(s-1,0)]).normalized()
		var x := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
		var y := along.cross(x).normalized()
		rings.append([points[s]+x*LINE,points[s]+y*LINE,points[s]-x*LINE,points[s]-y*LINE])
	for s in range(points.size()-1):
		var r0: Array = rings[s]
		var r1: Array = rings[s+1]
		var mid := (points[s]+points[s+1])*0.5
		for k in range(4):
			var a: Vector3 = r0[k]
			var b: Vector3 = r0[(k+1)%4]
			var c: Vector3 = r1[(k+1)%4]
			var d: Vector3 = r1[k]
			for tri: Array in [[a,b,c],[a,c,d]]:
				var p0: Vector3 = tri[0]
				var p1: Vector3 = tri[1]
				var p2: Vector3 = tri[2]
				var n := (p1-p0).cross(p2-p0)
				if n.dot((p0+p1+p2)/3.0-mid) > 0.0:
					var swap := p1
					p1 = p2
					p2 = swap
					n = -n
				n = -n.normalized()
				for v: Vector3 in [p0,p1,p2]:
					verts.append(v)
					normals.append(n)

## The tear's burst: dust off the rim all round, pebbles off the rock.
func _burst() -> void:
	_shed(TEAR_PUFFS,TEAR_PEBBLES)

## `puffs` dust puffs off the rim and `pebbles` pebbles off the underside of
## the islet as it stands now.
func _shed(puffs: int, pebbles: int) -> void:
	var b: Dictionary = event.b
	var shape: RefCounted = b.shape
	var at: Vector3 = (b.node as Node3D).position
	for i in range(puffs):
		var a := _rng.randf_range(0.0,TAU)
		var rim: Vector2 = shape.rim_point(a)
		var low := _rng.randf_range(0.0,1.0)
		var y := lerpf(float(shape.ground_at(rim*0.95)),float(shape.underside(rim*0.7)),low*0.6)
		var out := Vector3(cos(a),0.0,sin(a))
		var from := at+Vector3(rim.x,y,rim.y)+out*0.3
		var throw := out*_rng.randf_range(1.2,3.6)+Vector3.UP*_rng.randf_range(-1.2,0.6)
		var size := _rng.randf_range(0.3,0.85)
		_dust.puff(from,throw,size)
		# A smaller lobe or two heaped on it, so it reads as a little cloud.
		for k in range(_rng.randi_range(1,2)):
			_dust.puff(from+Vector3(_rng.randf_range(-0.4,0.4),_rng.randf_range(0.0,0.35),_rng.randf_range(-0.4,0.4))*size,throw*0.9,size*_rng.randf_range(0.5,0.75))
	for i in range(pebbles):
		var p := Vector2.from_angle(_rng.randf_range(0.0,TAU))*_rng.randf_range(0.0,0.8)*float(shape.reach)*0.7
		if not shape.inside(p): p *= 0.5
		var under := float(shape.underside(p)) if shape.inside(p) else float(shape.base)
		_dust.pebble(at+Vector3(p.x,under+_rng.randf_range(0.0,1.5),p.y),Vector3(_rng.randf_range(-0.8,0.8),_rng.randf_range(-1.5,0.3),_rng.randf_range(-0.8,0.8)),_rng.randf_range(0.2,0.55))

## The propellers turn with the pull, the winch drum as the lines pay out
## or wind in, the crew act, and the night lights glow.
func _animate(delta: float, eye: Vector3) -> void:
	var spin := 6.0+18.0*clampf((event.vel as Vector3).length()/CRUISE,0.0,1.0)
	if event.phase in ["taut","tear"]: spin = 26.0
	for p: Node3D in _props: p.rotate_object_local(Vector3.BACK,spin*delta)
	var drum := 0.0
	match str(event.phase):
		"lower": drum = 3.0
		"taut": drum = -4.0
		"release": drum = -14.0*(1.0-smoothstep(POP_TIME,POP_TIME+REEL,event.t))
	_drum.rotate_object_local(Vector3.RIGHT,drum*delta)
	if _crew.size() >= 2:
		var near := (event.pos as Vector3).distance_to(eye) < 70.0
		var bow := "idle"
		if event.phase == "tear": bow = "hail"
		elif near and event.phase in ["come","tow","leave"]: bow = "wave"
		var stern := "walk" if event.phase in ["lower","taut","release"] else "idle"
		if (_crew[0] as IslanderFigure).move != bow: _crew[0].play(bow)
		if (_crew[1] as IslanderFigure).move != stern: _crew[1].play(stern)
	_night_lights(delta)

func daylight() -> float:
	if daylight_override >= 0.0: return daylight_override
	var celestial: Variant = scene.get("_celestial") if scene != null else null
	if celestial != null and celestial.get("state") is Dictionary and celestial.state.has("zs_daylight"):
		return float(celestial.state.zs_daylight)
	return 1.0

func _night_lights(delta: float) -> void:
	var goal := StoneLampLights.night_for(daylight())
	night = goal if delta <= 0.0 or daylight_override >= 0.0 else move_toward(night,goal,delta/2.0)
	_glow.emission_energy_multiplier = 3.0*night
	_halo.set_shader_parameter("glow",night)
	_light.visible = night > 0.01
	_light.light_energy = LIGHT.y*night
	# The cargo lamp only while something hangs under it.
	var hung := 1.0 if event.get("phase","") in ["lower","bite","taut","tear","tow","settle","release"] else 0.0
	_cargo.visible = night*hung > 0.01
	_cargo.light_energy = CARGO_LAMP.z*night*hung

# --- Making and ending ------------------------------------------------------------

## The ship's nodes, made once and kept between events (hidden).
func _make_ship() -> void:
	if _ship != null: return
	var solid := ShaderMaterial.new()
	solid.shader = SURFACE
	solid.set_shader_parameter("fill",1.25)
	solid.set_shader_parameter("rim",0.45)
	solid.set_shader_parameter("roughness_value",0.85)
	_line_material = solid
	_ship = Node3D.new()
	_ship.name = "Ship"
	add_child(_ship)
	_body = MeshInstance3D.new()
	_body.name = "Body"
	_body.mesh = Build.body()
	_body.material_override = solid
	_ship.add_child(_body)
	for side in [-1.0,1.0]:
		var prop := MeshInstance3D.new()
		prop.name = "Propeller"
		prop.mesh = Build.propeller()
		prop.material_override = solid
		prop.position = Vector3(Build.PROP.x*side,Build.PROP.y,Build.PROP.z)
		_ship.add_child(prop)
		_props.append(prop)
	_drum = MeshInstance3D.new()
	_drum.name = "Drum"
	_drum.mesh = Build.drum()
	_drum.material_override = solid
	_drum.position = Build.DRUM
	_ship.add_child(_drum)
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color("4a4038")
	_glow.roughness = 0.6
	_glow.emission_enabled = true
	_glow.emission = WARM
	_glow.emission_energy_multiplier = 0.0
	_windows = MeshInstance3D.new()
	_windows.name = "Windows"
	_windows.mesh = Build.windows()
	_windows.material_override = _glow
	_ship.add_child(_windows)
	_halo = ShaderMaterial.new()
	_halo.shader = HALO
	_halo.set_shader_parameter("far_size",FAR_SIZE)
	_halo.set_shader_parameter("far_pixels",FAR_PIXELS)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = quad
	var spots: Array = []
	for w: Vector3 in Build.WINDOWS: spots.append([w,HALO_WINDOW])
	spots.append([Build.LANTERN,HALO_LANTERN])
	multi.instance_count = spots.size()
	for k in range(spots.size()):
		var size: Vector2 = spots[k][1]
		multi.set_instance_transform(k,Transform3D(Basis.from_scale(Vector3.ONE*size.x),spots[k][0]))
		multi.set_instance_color(k,Color(WARM,size.y))
	_halos = MultiMeshInstance3D.new()
	_halos.name = "Halos"
	_halos.multimesh = multi
	_halos.material_override = _halo
	_halos.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halos.custom_aabb = AABB(Vector3(-20.0,-10.0,-20.0),Vector3(40.0,30.0,40.0))
	_ship.add_child(_halos)
	_light = OmniLight3D.new()
	_light.name = "Lantern"
	_light.light_color = Color("ffb36b")
	_light.omni_range = LIGHT.x
	_light.light_energy = 0.0
	_light.shadow_enabled = false
	_light.distance_fade_enabled = true
	_light.distance_fade_begin = 220.0
	_light.distance_fade_length = 60.0
	_light.position = Build.LANTERN+Vector3.DOWN*0.2
	_light.visible = false
	_ship.add_child(_light)
	_cargo = SpotLight3D.new()
	_cargo.name = "CargoLamp"
	_cargo.light_color = Color("ffc483")
	_cargo.spot_range = CARGO_LAMP.x
	_cargo.spot_angle = CARGO_LAMP.y
	_cargo.spot_attenuation = 0.6
	_cargo.shadow_enabled = false
	_cargo.distance_fade_enabled = true
	_cargo.distance_fade_begin = 180.0
	_cargo.distance_fade_length = 60.0
	_cargo.position = Vector3(0.0,-0.8,0.2)
	_cargo.rotation = Vector3(-PI*0.5,0.0,0.0)
	_cargo.visible = false
	_ship.add_child(_cargo)
	for i in range(Build.CREW.size()):
		var figure := IslanderFigure.new(IslanderFigure.SCARVES[(i*2+1) % IslanderFigure.SCARVES.size()])
		figure.scale = Vector3.ONE*IslanderFigure.SKY_SCALE
		figure.position = Build.CREW[i]+Vector3.UP*0.06
		figure.rotation.y = 0.0 if i == 0 else PI*0.85
		_ship.add_child(figure)
		figure.play("idle")
		_crew.append(figure)
	_lines = MeshInstance3D.new()
	_lines.name = "Lines"
	_lines.mesh = ArrayMesh.new()
	_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_lines.custom_aabb = AABB(Vector3(-4000.0,-400.0,-4000.0),Vector3(8000.0,800.0,8000.0))
	add_child(_lines)
	var hook := Build.grapple()
	for i in range(Build.TETHERS.size()):
		var g := MeshInstance3D.new()
		g.name = "Grapple%d" % i
		g.mesh = hook
		g.material_override = solid
		add_child(g)
		_grapples.append(g)
	_dust = Dust.new()
	add_child(_dust)

## The ship's parts, faded (0 whole to 1 gone).
func _set_fade(t: float) -> void:
	var parts: Array = [_body,_drum,_windows,_lines]
	parts.append_array(_grapples)
	parts.append_array(_props)
	for g: GeometryInstance3D in parts: g.transparency = t
	_halos.visible = t < 0.98
	if not _crew.is_empty():
		for c: Node3D in _crew: c.visible = t < 0.6

## The event over: the ship hidden, its lines gone, the islet back to an
## ordinary one (where it was moored, or, cut short, where it is).
func _end(cut: bool) -> void:
	var b: Dictionary = event.get("b",{})
	if not b.is_empty() and not event.get("carried",false) and is_instance_valid(b.get("node")):
		if cut and not event.get("moored",false) and event.phase in ["tear","tow","settle"]:
			islets.moved[_cell_key(b)] = b.home
		# Let go mid-spin (the event cut short): it stands where its spin
		# would have left it.
		if event.has("free"):
			var node: Node3D = b.node
			var bob := node.position-(b.home as Vector3)
			b.home = event.rest
			node.position = (b.home as Vector3)+bob
			SkyIslets.turn(b,float(event.yaw0)+float(event.spin))
		b.erase("towed")
		b.fixed = bool(event.get("was_fixed",false))
	if not event.is_empty(): phases.append("done")
	event = {}
	if _ship != null:
		_ship.visible = false
		(_lines.mesh as ArrayMesh).clear_surfaces()
		for g: MeshInstance3D in _grapples: g.visible = false
		_dust.clear()
		_light.visible = false
		_cargo.visible = false
	wait = _rng.randf_range(EVERY.x,EVERY.y)

## The islets' key for a built record's cell (SkyIslets `_key`).
static func _cell_key(b: Dictionary) -> String:
	var cell: Vector2i = b.get("cell",Vector2i.ZERO)
	return "%d,%d" % [cell.x,cell.y]

## True while an event is under way.
func busy() -> bool:
	return not event.is_empty()

## The towed islet's built record, or {}.
func towed() -> Dictionary:
	return event.get("b",{}) if not event.is_empty() else {}

## The ship as a solid to the plane (SkyIslands `body`): over its
## envelope or its gondola, Vector2(its top, its underside) at a point of
## the islands' frame, the envelope read as a fat ellipsoid round its axis;
## or null. Only while it is out, whole enough to see.
func body(point: Vector3) -> Variant:
	if event.is_empty() or _ship == null or not _ship.visible or float(event.age) < FADE*0.5: return null
	if event.phase == "leave" and (_body.transparency > 0.5): return null
	var local := (transform*_ship.transform).affine_inverse()*point
	if absf(local.z) > Build.ENVELOPE_LENGTH*0.5+0.5 or absf(local.x) > Build.ENVELOPE_RADIUS+2.0: return null
	var top := -INF
	var under := INF
	var r := Build.envelope_radius(local.z-Build.ENVELOPE_AT.z)
	var x := local.x-Build.ENVELOPE_AT.x
	if absf(x) < r:
		var half := sqrt(r*r-x*x)*0.94
		top = Build.ENVELOPE_AT.y+half
		under = Build.ENVELOPE_AT.y-half
	if absf(local.x) < Build.HULL.x and absf(local.z) < Build.HULL.z:
		top = maxf(top,1.6)
		under = minf(under,-Build.HULL.y)
	if top == -INF: return null
	var lift: float = (transform*_ship.transform).origin.y
	return Vector2(top+lift,under+lift)

## Where the ship stands (this node's frame, home), or INF.
func ship_position() -> Vector3:
	return event.pos if not event.is_empty() else Vector3.INF
