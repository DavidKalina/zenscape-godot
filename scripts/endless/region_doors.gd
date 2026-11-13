extends Node3D
## The doors between the regions (--world=doors; scripts/endless/world/
## profiles/doors.gd; docs/design/endless-flight/doors-handoff.md): a wall
## of standing cloud on each side, and flying into one carries the plane to
## the other.
##
##   the walls    `doors/amber-wall` stands in wilderness, a few km off the
##                start meadow over the sea or low land, in sight of the
##                meadow, warm amber in the morning light; `doors/morning-wall`
##                stands at the same spot on the amberlands side (the far
##                side's home is the doors world's `offset` away), cool and
##                pale. Each is a few dozen camera-facing puffs
##                (shaders/door_cloud.gdshader) in a box WIDTH x HEIGHT x
##                DEPTH, its through way the box's z. The layout file's moves
##                win (scripts/layout_overrides.gd).
##   the way      flying into a wall's core (CORE of the box) starts the
##                carry: the view whitens (WHITE_IN s, the wall's hue), the
##                plane is moved to the same spot in the other wall and out
##                past its far face, at the same heading, speed and height
##                over the ground, and held there while the land round it
##                stands (HOLD s at least, HOLD_MOST at most; each side has
##                its own land stream, the far one prewarmed while the plane
##                is within PREWARM m of a wall) and the near dressing is
##                primed, then the white clears
##                into the far side's light (WHITE_OUT s). The paint, sky and
##                hour follow the eye's region on their own (regions.gd
##                `paint_eye`, EndlessLook `blend_moods`).
##   hysteresis   the wall it comes out of works again only once the plane
##                is REARM m clear of its box.
##   the hour     each side keeps its own clock: the day cycle (when it
##                runs) is put on the far side's hour as it was left, the
##                first time its region's own (paint.hour).
##   blind        through the whiteout the stick is let be: it flies straight.
##   the hint     now and then one traffic plane flies a line into the
##                wilderness wall and is gone (EndlessTraffic `door_run`).
##   the logbook  each wall's first pass is a find (`door/<wall>`).
##
## Flags: --doors=0 leaves them out; --door-near puts the wilderness wall
## DOOR_NEAR m ahead of the start (for drivers and stills); --door-hold=S
## the longest hold (HOLD_MOST).

const Field = preload("res://scripts/endless/land_field.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")
const Shader_ = preload("res://shaders/door_cloud.gdshader")

## The wall (m): across, tall over its base, through.
const WIDTH := 760.0
const HEIGHT := 640.0
const DEPTH := 220.0
## Its base this far under the ground or sea it stands on (m).
const SINK := 30.0
## How far from the start meadow the wilderness wall stands (m), the
## headings and distances tried.
const REACH := [2400.0,2800.0,3200.0,3600.0]
const HEADINGS := 24
## The ground under it no higher than this over the sea (m): the flight's
## ceiling (Field CEILING_OVER) leaves room to fly in.
const LOW_GROUND := 60.0
## With the Peak (LandField `peak`): the wall stands off to one side of the
## line to its summit, best PEAK_SIDE degrees off it (the massif's flanks
## fill about 45 degrees either side of that line from the meadow), and its
## ends too over low ground, so it never stands on the massif nor hides it.
## That side counts for more than the sea (SIDE_WORTH against the sea's 1.5),
## so the summit and the wall stand in one view.
const PEAK_SIDE := 55.0
const SIDE_WORTH := 3.0
## With the Peak the wall is no taller than puts its billows' top PEAK_UNDER
## of the summit's angle up from the meadow's eye (BILLOW m over its
## columns), nor under HEIGHT_LEAST: from the meadow the summit stands
## clearly over it.
const PEAK_UNDER := 0.6
const BILLOW := 100.0
const HEIGHT_LEAST := 300.0
## --door-near: the wall this far ahead of the start (m).
const DOOR_NEAR := 900.0
## The core that carries (shares of the box's half sizes; height whole).
const CORE := Vector3(0.8,1.0,0.3)
## Out past the far face (m) where it comes out.
const EXIT := 50.0
## The wall it came out of works again this far clear of its box (m).
const REARM := 300.0
## The carry's times (s).
const WHITE_IN := 0.35
const HOLD := 0.45
const HOLD_MOST := 4.0
const WHITE_OUT := 0.85
## Height over the ground kept through the carry (m), least and most.
const KEEP_LOW := 25.0
const KEEP_HIGH := 400.0
## The hint: first after this many s of flight, then every so often (s),
## while the plane is within HINT_REACH m of the wilderness wall.
const HINT_FIRST := Vector2(20.0,40.0)
const HINT_EVERY := Vector2(80.0,160.0)
const HINT_REACH := 6000.0

## The walls: [wilderness (to amberlands), amberlands (back)], each
## {name, find, xform (Transform3D: origin at the base's middle, z through),
## node, lit, shade, glow, white (the whiteout's hue), arrive (the far
## side's light, the clearing's hue)}.
var walls: Array[Dictionary] = []
## Whether each wall carries now (hysteresis).
var armed: Array[bool] = [true,true]
## The carry: "" (none), "in", "hold", "out".
var phase := ""
## The wall being passed (index into `walls`) and the time in the phase.
var passing := -1
var _t := 0.0
## Where the carry put the plane (held there in "hold").
var _arrive := Vector3.ZERO
## Carries done, and the worst frame (ms) through the last one.
var passes := 0
var worst_ms := 0.0
var last_hold := 0.0
var _host: Node3D
var _world: RefCounted
var _field: RefCounted
var _overlay: ColorRect
var _overlay_layer: CanvasLayer
var _hint_wait := 0.0
var _rng := RandomNumberGenerator.new()
var _last_tick := 0
## Each side's sun phase as it was left (-1: not yet visited).
var _clock: Array[float] = [-1.0,-1.0]
## The longest hold (s; --door-hold=).
var hold_most := HOLD_MOST
## The land's commits pumped per frame through the hold (ms).
const PUMP_MS := 40.0
var _hold_began := 0
## The walls' height over their base (m): HEIGHT, or less with the Peak.
var height := HEIGHT

## Whether the doors run: the world has them, and --doors=1 (taken out of
## play 2026-11-12: no door to the amberlands by default).
static func wanted(world: RefCounted) -> bool:
	return flagged() and world != null and world.has_method("side_of")

## Whether --doors=1 asks for the doors.
static func flagged() -> bool:
	return "--doors=1" in LaunchArgs.user_args()

## Placed round the start meadow `start` (XZ) whose takeoff heads along
## `heading` (radians, SkyGlide's: forward is (-sin, 0, -cos)).
func setup(host: Node3D, start: Vector2, heading: float, seed: int) -> void:
	name = "Doors"
	_host = host
	_world = host.world
	_field = host.field
	_rng.seed = seed*977+31
	for a: String in LaunchArgs.user_args():
		if a.begins_with("--door-hold="): hold_most = maxf(HOLD,a.get_slice("=",1).to_float())
	_hint_wait = _rng.randf_range(HINT_FIRST.x,HINT_FIRST.y)
	var spot := _wild_spot(start,heading)
	height = _height_for(start,spot.at)
	var off: Vector2 = _world.offset
	var wild := _frame_at(spot.at,spot.yaw)
	var amber := _frame_at(spot.at+off,spot.yaw)
	walls = [
		{"name":"doors/amber-wall","find":"door/amber-wall","coded":wild,
			"lit":Color(1.0,0.82,0.42),"shade":Color(0.88,0.58,0.36),"glow":Color(1.0,0.62,0.2),
			"white":Color(1.0,0.9,0.72),"arrive":Color(1.0,0.78,0.5)},
		{"name":"doors/morning-wall","find":"door/morning-wall","coded":amber,
			"lit":Color(0.86,0.93,1.0),"shade":Color(0.55,0.64,0.78),"glow":Color(0.66,0.82,1.0),
			"white":Color(0.92,0.96,1.0),"arrive":Color(0.84,0.92,1.0)},
	]
	for w: Dictionary in walls:
		w.xform = LayoutOverrides.xform(String(w.name),w.coded as Transform3D)
		w.node = _build_wall(w)
		LayoutOverrides.track(String(w.name),w.node,"door",w.coded as Transform3D)
	_build_overlay()
	_make_lands()
	print("doors: %s at %s (%.0f m from the start, %s), %s at %s" % [walls[0].name,str(_xz(0).round()),_xz(0).distance_to(start),spot.why,walls[1].name,str(_xz(1).round())])

# --- What the hall door answers (hall_doors.gd); a wall stands in nothing ---------------

func ground(_p: Vector3, h: Variant, _pad := -1.0) -> Variant:
	return h

func holds(_p: Vector3) -> bool:
	return false

func hall_floor() -> float:
	return 0.0

func late(_eye: Vector3) -> void:
	pass

# --- The walls' places ----------------------------------------------------------------

## The wilderness wall's spot: {at (XZ), yaw (its through way's), why}. The
## best of REACH x HEADINGS round the start: over low ground (the sea best),
## in sight from the meadow, ahead of the takeoff.
func _wild_spot(start: Vector2, heading: float) -> Dictionary:
	var ahead := Vector2(-sin(heading),-cos(heading))
	if "--door-near" in LaunchArgs.user_args():
		var at := start+ahead*DOOR_NEAR
		return {"at":at,"yaw":_yaw_of(ahead),"why":"--door-near"}
	var eye_y := _ground(start)+3.0
	var peak: RefCounted = _field.peak() if _field.has_method("peak") else null
	var to_peak := Vector2.ZERO
	if peak != null:
		var s: Vector3 = peak.summit()
		to_peak = (Vector2(s.x,s.z)-start).normalized()
	var best := {}
	var best_score := -INF
	# With the Peak, twice the headings: the side it wants is narrow.
	var ways := HEADINGS*(2 if peak != null else 1)
	for k in ways:
		var a := TAU*k/ways
		var dir := Vector2(cos(a),sin(a))
		for d: float in REACH:
			var at := start+dir*d
			var h := float(_field.height(at.x,at.y))
			if h > Field.SEA_Y+LOW_GROUND: continue
			var off_peak := 0.0
			if peak != null:
				var across := Vector2(-dir.y,dir.x)*WIDTH*0.5
				var ends_low := true
				for e: Vector2 in [at+across,at-across]:
					if float(_field.height(e.x,e.y)) > Field.SEA_Y+LOW_GROUND: ends_low = false
				if not ends_low: continue
				off_peak = rad_to_deg(acos(clampf(dir.dot(to_peak),-1.0,1.0)))
			var score := 0.0
			var seen := _sight(start,eye_y,at,maxf(h,Field.SEA_Y)+HEIGHT*0.3)
			score += 4.0*seen
			if h < Field.SEA_Y-2.0: score += 1.5
			if peak != null: score += SIDE_WORTH*(1.0-2.0*absf(off_peak-PEAK_SIDE)/90.0)
			else: score += 1.5*dir.dot(ahead)
			score -= (d-REACH[0])/1200.0*0.6
			# The far side's arrival over low ground too.
			var far := at+(_world.offset as Vector2)
			if float(_field.height(far.x,far.y)) < Field.SEA_Y+LOW_GROUND*2.0: score += 0.8
			if score > best_score:
				best_score = score
				best = {"at":at,"yaw":_yaw_of(dir),"why":"%s, %s, %.0f deg off the takeoff" % ["the sea" if h < Field.SEA_Y else "low land","in sight" if seen > 0.99 else "%d%% seen" % roundi(seen*100.0),rad_to_deg(acos(clampf(dir.dot(ahead),-1.0,1.0)))]}
	if best.is_empty():
		var at := start+ahead*REACH[0]
		best = {"at":at,"yaw":_yaw_of(ahead),"why":"no low ground; ahead"}
	return best

## The walls' height for a wall at `at` seen from the meadow `start` (see
## PEAK_UNDER).
func _height_for(start: Vector2, at: Vector2) -> float:
	var peak: RefCounted = _field.peak() if _field.has_method("peak") else null
	if peak == null or "--door-near" in LaunchArgs.user_args(): return HEIGHT
	var eye_y := _ground(start)+3.0
	var s: Vector3 = peak.summit()
	var up := (s.y-eye_y)/maxf(Vector2(s.x,s.z).distance_to(start),1.0)
	var top := eye_y+up*PEAK_UNDER*at.distance_to(start)
	return clampf((top-(_ground(at)-SINK)-BILLOW)/0.94,HEIGHT_LEAST,HEIGHT)

## How much of the line from the meadow's eye to (at, top) is clear of the
## land (1: all of it).
func _sight(from: Vector2, from_y: float, at: Vector2, top: float) -> float:
	var clear := 0
	const STEPS := 48
	for i in range(1,STEPS):
		var t := float(i)/STEPS
		var p := from.lerp(at,t)
		if float(_field.height(p.x,p.y)) < lerpf(from_y,top,t): clear += 1
	return float(clear)/float(STEPS-1)

## The yaw that turns the box's z onto `dir` (XZ).
static func _yaw_of(dir: Vector2) -> float:
	return atan2(dir.x,dir.y)

func _ground(at: Vector2) -> float:
	return maxf(float(_field.height(at.x,at.y)),Field.SEA_Y)

func _frame_at(at: Vector2, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP,yaw),Vector3(at.x,_ground(at)-SINK,at.y))

func _xz(i: int) -> Vector2:
	var o: Vector3 = (walls[i].xform as Transform3D).origin
	return Vector2(o.x,o.z)

# --- The walls' look ------------------------------------------------------------------

## A wall's puffs under one node at its frame.
func _build_wall(w: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = String(w.name).get_file()
	add_child(root)
	root.transform = w.xform
	var mat := ShaderMaterial.new()
	mat.shader = Shader_
	mat.set_shader_parameter("lit_colour",w.lit)
	mat.set_shader_parameter("shade_colour",w.shade)
	mat.set_shader_parameter("glow_colour",w.glow)
	mat.set_shader_parameter("glow",0.45)
	w.material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0,2.0)
	quad.custom_aabb = AABB(Vector3(-1.0,-1.0,-1.0),Vector3(2.0,2.0,2.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(w.name))
	var phase_x := rng.randf()*TAU
	var puffs: Array = []
	# The body: columns across, each up to the billowing top.
	for i in 64:
		var u := rng.randf()
		var x := (u-0.5)*WIDTH
		var top := _top(x,phase_x)
		var y := pow(rng.randf(),0.75)*top
		var r := lerpf(150.0,85.0,y/top)*rng.randf_range(0.8,1.2)
		puffs.append([Vector3(x,y,rng.randf_range(-0.3,0.3)*DEPTH),r,(1.0-absf(2.0*u-1.0))*(1.0-0.4*y/top)])
	# The billows along the top and the skirt along the foot.
	for i in 16:
		var x := (float(i)+rng.randf_range(0.1,0.9))/16.0*WIDTH-WIDTH*0.5
		var top := _top(x,phase_x)
		puffs.append([Vector3(x,top-rng.randf_range(0.0,40.0),rng.randf_range(-0.25,0.25)*DEPTH),rng.randf_range(70.0,115.0),0.3])
	for i in 10:
		var x := (float(i)+rng.randf_range(0.2,0.8))/10.0*WIDTH-WIDTH*0.5
		puffs.append([Vector3(x,rng.randf_range(20.0,70.0),rng.randf_range(-0.3,0.3)*DEPTH),rng.randf_range(140.0,190.0),0.6])
	var n := 0
	for p: Array in puffs:
		var m := MeshInstance3D.new()
		m.name = "Puff%d" % n
		m.mesh = quad
		m.material_override = mat
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		m.position = p[0]
		m.scale = Vector3.ONE*float(p[1])
		m.set_instance_shader_parameter("puff_seed",float(n)*1.618)
		m.set_instance_shader_parameter("core",float(p[2]))
		root.add_child(m)
		n += 1
	return root

## The wall's top over its base at `x` across (m): billowing, lower to the ends.
func _top(x: float, phase_x: float) -> float:
	var u := absf(x)/(WIDTH*0.5)
	return height*(0.82+0.12*sin(x*0.013+phase_x)+0.06*sin(x*0.031+phase_x*2.0))*(1.0-0.35*pow(u,3.0))

func _build_overlay() -> void:
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.layer = 5
	add_child(_overlay_layer)
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat r = length(UV - 0.5) * 1.4;\n\tCOLOR = vec4(COLOR.rgb * mix(1.04, 0.9, r * r), COLOR.a);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	_overlay.material = m
	_overlay.color = Color(1.0,1.0,1.0,0.0)
	_overlay.visible = false
	_overlay_layer.add_child(_overlay)

# --- Each frame -----------------------------------------------------------------------

## The region side (0 wilderness, 1 amberlands) world point `p` is on.
func side_at(p: Vector3) -> int:
	return int(_world.side_of(p.x,p.z))

## A wall's box frame point of world `p`.
func local_of(i: int, p: Vector3) -> Vector3:
	return (walls[i].xform as Transform3D).affine_inverse()*p

## Whether `p` is in wall `i`'s core (the carry starts there).
func in_core(i: int, p: Vector3) -> bool:
	var q := local_of(i,p)
	return absf(q.x) < WIDTH*0.5*CORE.x and q.y > 0.0 and q.y < height*CORE.y and absf(q.z) < DEPTH*0.5*CORE.z

## Whether `p` is within `margin` m of wall `i`'s box.
func near_box(i: int, p: Vector3, margin: float) -> bool:
	var q := local_of(i,p)
	return absf(q.x) < WIDTH*0.5+margin and q.y > -margin and q.y < height+margin and absf(q.z) < DEPTH*0.5+margin

## How deep `p` is in wall `i` (0 at EXIT m outside its face, 1 at the core).
func depth_in(i: int, p: Vector3) -> float:
	var q := local_of(i,p)
	var face := DEPTH*0.5
	var core_z := face*CORE.z
	var through := 1.0-clampf((absf(q.z)-core_z)/(face-core_z+EXIT),0.0,1.0)
	var across := 1.0-clampf((absf(q.x)-WIDTH*0.5*CORE.x)/(WIDTH*0.5*(1.0-CORE.x)+EXIT),0.0,1.0)
	var up := 1.0-clampf((q.y-height*0.85)/(height*0.15+EXIT),0.0,1.0)
	return through*across*up

## What a traffic plane flies into (EndlessTraffic `door_run`): the
## wilderness wall's frame, its core's half sizes and the point aimed at.
func door_for_traffic() -> Dictionary:
	var xf: Transform3D = walls[0].xform
	return {"xform":xf,"half":Vector3(WIDTH*0.5*CORE.x,height,DEPTH*0.5*CORE.z),"aim":xf*Vector3(0.0,SINK+150.0,0.0)}

## One frame, after the flight's step and before the camera follows.
func step(delta: float) -> void:
	if walls.is_empty(): return
	var h := _host
	var plane: RefCounted = h.plane
	var p: Vector3 = plane.position
	var eye: Vector3 = h.camera.global_position
	var racing: bool = h.race != null and str(h.race.state) != "free"
	var flying: bool = h.hand_landing.flying()
	for i in walls.size():
		if not armed[i] and not near_box(i,p,REARM): armed[i] = true
	var white := 0.0
	var hue: Color = walls[0].white
	# Into the wall: the view whitens with the depth.
	var deepest := 0.0
	for i in walls.size():
		var d := depth_in(i,eye)
		if d > deepest:
			deepest = d
			hue = walls[i].white
	var approach := smoothstep(0.0,1.0,deepest)*0.92
	match phase:
		"":
			white = approach
			if flying and not racing:
				for i in walls.size():
					if armed[i] and in_core(i,p):
						_begin(i)
						break
		"in":
			_t += delta
			white = lerpf(_t_from,1.0,clampf(_t/WHITE_IN,0.0,1.0))
			hue = walls[passing].white
			if _t >= WHITE_IN:
				_carry()
				phase = "hold"
				_t = 0.0
				white = 1.0
		"hold":
			_t += delta
			white = 1.0
			hue = walls[passing].white
			# Held where it came out while the land round it stands (most
			# of it already, prewarmed on the way in): what is missing
			# committed PUMP_MS a frame (the white hides the frame's cost),
			# then the near dressing primed there at once (one long white
			# frame on a side's first visit; the trees stream on their own:
			# their prime is seconds on a fresh side).
			plane.carry(_arrive,plane.velocity,float(plane.speed))
			var eye_now: Vector3 = h.chase.eye
			var began := Time.get_ticks_usec()
			while not h.land.settled() and (Time.get_ticks_usec()-began)/1000.0 < PUMP_MS:
				h.land.step(eye_now)
				OS.delay_usec(300)
			var real := (Time.get_ticks_msec()-_hold_began)/1000.0
			var stood: bool = h.land.settled()
			if (_t >= HOLD and stood) or real >= hold_most:
				var t0 := Time.get_ticks_msec()
				for part: Node3D in [h.arches,h.rocks,h.halls,h.tunnels]:
					if part != null: part.prime(eye_now)
				if h.grass != null and h.grass.enabled: h.grass.prime(eye_now,-(h.camera as Camera3D).global_basis.z)
				last_hold = (Time.get_ticks_msec()-_hold_began)/1000.0
				print("doors: held %.2f s, the land %s (%s; %.0f%% prewarmed), the near dressing primed in %.2f s" % [last_hold,"stood" if stood else "still coming",str(h.land.counts()),_warm_share*100.0,(Time.get_ticks_msec()-t0)/1000.0])
				phase = "out"
				_t = 0.0
		"out":
			_t += delta
			var k := clampf(_t/WHITE_OUT,0.0,1.0)
			white = maxf(1.0-smoothstep(0.0,1.0,k),approach)
			hue = (walls[passing].white as Color).lerp(walls[passing].arrive,smoothstep(0.0,0.6,k))
			if _t >= WHITE_OUT:
				phase = ""
				_t = 0.0
				_watch = WATCH
	# The worst frame from the carry's start to WATCH s after it.
	if phase != "" or _watch > 0.0:
		var now := Time.get_ticks_usec()
		if _last_tick > 0: worst_ms = maxf(worst_ms,(now-_last_tick)/1000.0)
		_last_tick = now
		if phase == "": _watch -= delta
	if phase == "": _prewarm(p)
	_haze(delta)
	_overlay.visible = white > 0.002
	_overlay.color = Color(hue.r,hue.g,hue.b,white)
	_hint(delta,p,flying,racing)

var _t_from := 0.0
var _haze_wait := 0.0


## The walls' haze colour from the environment's fog, now and then.
func _haze(delta: float) -> void:
	_haze_wait -= delta
	if _haze_wait > 0.0: return
	_haze_wait = 0.5
	var look: Node = _host.look
	if look == null: return
	var env: Environment = look.get("environment")
	if env == null: return
	var c := env.fog_light_color
	for w: Dictionary in walls:
		(w.material as ShaderMaterial).set_shader_parameter("haze_colour",c)
## Seconds left watching the frames after a carry.
var _watch := 0.0
const WATCH := 3.0

# --- The far side's land --------------------------------------------------------------
#
# Each side has its own land stream (LandStream), the host's `land` the
# one the plane is on. Near a wall, the far side's stream is stepped round
# the spot it will come out at, so the carry finds it standing; the side
# left keeps its chunks for the way back.

## The streams by side (the host's own is the side it starts on).
var lands: Array[Node3D] = [null,null]
## Within this far of a wall's box (m) the far side is prewarmed.
const PREWARM := 1800.0
## How much of the far side's land stood at the last carry (0 to 1).
var _warm_share := 0.0

func _make_lands() -> void:
	var home := side_at(_host.plane.position) if _host.plane != null else 0
	lands[home] = _host.land
	var other: Node3D = _host.land.get_script().new()
	other.name = "LandFar"
	_host.add_child(other)
	var look: Node = _host.look
	other.setup(int(_host.seed),look.ground if look != null else null)
	lands[1-home] = other

## Near a wall on its own side, the far side's land stepped round where the
## plane would come out.
func _prewarm(p: Vector3) -> void:
	var side := side_at(p)
	if side < 0 or side > 1 or lands[1-side] == null: return
	if not near_box(side,p,PREWARM): return
	var q := local_of(side,p)
	var out_z := (DEPTH*0.5+EXIT)*(1.0 if q.z < 0.0 else -1.0)
	var at: Vector3 = (walls[1-side].xform as Transform3D)*Vector3(clampf(q.x,-WIDTH*0.4,WIDTH*0.4),SINK+60.0,out_z)
	lands[1-side].step(at)

## The host's land swapped to side `to`'s stream.
func _swap_land(to: int) -> void:
	var c: Dictionary = lands[to].counts()
	_warm_share = float(c.standing)/maxf(float(c.wanted),1.0)
	_host.land = lands[to]

## The flight's input this frame (endless_flight `tick`): through the
## whiteout the stick is let be.
func input(asked: Dictionary) -> Dictionary:
	if phase != "in" and phase != "hold": return asked
	var out := asked.duplicate()
	out["turn"] = 0.0
	out["pitch"] = 0.0
	out["lean"] = 0.0
	out["roll"] = 0.0
	out["look"] = Vector2.ZERO
	return out

func _begin(i: int) -> void:
	passing = i
	phase = "in"
	_t = 0.0
	_t_from = _overlay.color.a if _overlay.visible else 0.0
	worst_ms = 0.0
	_last_tick = Time.get_ticks_usec()

## The plane moved from wall `passing` to the other: the same spot in its
## box, out past its far face the way it was going, its height over the
## ground kept, heading and speed kept (turned by the walls' yaws' difference).
func _carry() -> void:
	var h := _host
	var from: Transform3D = walls[passing].xform
	var to_i := 1-passing
	var to: Transform3D = walls[to_i].xform
	var plane: RefCounted = h.plane
	var p: Vector3 = plane.position
	var q := from.affine_inverse()*p
	var way := from.basis.inverse()*(plane.velocity as Vector3)
	q.z = (DEPTH*0.5+EXIT)*(1.0 if way.z >= 0.0 else -1.0)
	var at := to*q
	var over := clampf(p.y-_ground(Vector2(p.x,p.z)),KEEP_LOW,KEEP_HIGH)
	at.y = minf(_ground(Vector2(at.x,at.z))+over,float(plane.ceiling_y)-8.0)
	var turn := to.basis.get_euler().y-from.basis.get_euler().y
	var v: Vector3 = (plane.velocity as Vector3).rotated(Vector3.UP,turn)
	plane.carry(at,v,float(plane.speed))
	if absf(turn) > 1e-5: plane.heading = wrapf(float(plane.heading)+turn,-PI,PI)
	_arrive = at
	_hold_began = Time.get_ticks_msec()
	_swap_land(to_i)
	var by := at-p
	armed[to_i] = false
	passes += 1
	h.plane_figure.reset(plane)
	h.chase.reset(plane,(h.chase.eye as Vector3)+by,h.camera.fov)
	_wash()
	_set_hour(passing,to_i)
	if h.book != null and h.book.find(String(walls[passing].find)): print("doors: first pass of %s" % walls[passing].name)
	print("doors: through %s to %s, at %s, %.0f m over the ground" % [walls[passing].name,walls[to_i].name,str(at.round()),over])

## What kept last frame's place after the plane moved: the near misses'
## clearance, the sea's wake, the clouds' history, the grass's stamps.
func _wash() -> void:
	var h := _host
	if "_last_ground" in h.near: h.near._last_ground = INF
	var look: Node = h.look
	if look != null:
		var sea: Object = look.get("water")
		if sea != null and "_trail" in sea:
			sea._trail.clear()
			sea._last = Vector2.INF
		var clouds: Object = look.get("clouds")
		if clouds != null and "_has_prev" in clouds:
			clouds._has_prev = false
			var fx: Object = clouds.get("effect")
			if fx != null and "history_ok" in fx: fx.history_ok = false
	if h.react != null and h.react.has_method("set_enabled"):
		h.react.set_enabled(false)
		h.react.set_enabled(true)
		if "wash_spot" in h.react: h.react.wash_spot = {}
	if h.eddies != null and "_last" in h.eddies: h.eddies._last.clear()

## The day cycle (when it runs, and no --hour= took it) from side `from`'s
## hour to side `to`'s.
var _held := false

func _set_hour(from: int, to: int) -> void:
	var look: Node = _host.look
	if look == null or look.get("cycle") == null or look.get("celestial") == null: return
	if (not bool(look.cycle.running) and not _held) or bool(look.get("_hour_taken")): return
	_clock[from] = float(look.land_phase())
	var p := _clock[to]
	var regions: Array = _world.get("regions")
	var paint: Dictionary = regions[to].paint if to < regions.size() else {}
	if p < 0.0:
		var hour := float(paint.get("hour",-1.0))
		if hour < 0.0: return
		p = hour/24.0
	look.cycle.set_phase(p)
	look.celestial.set_phase(p)
	# A world that holds its hour (the Amberlands' low sun) holds it past a door
	# too; the clock runs again on the way back.
	_held = bool(paint.get("still",false))
	look.cycle.running = not _held

# --- The hint -------------------------------------------------------------------------

func _hint(delta: float, p: Vector3, flying: bool, racing: bool) -> void:
	var traffic: Node = _host.traffic
	if traffic == null or not traffic.has_method("door_run"): return
	if not flying or racing or phase != "" or side_at(p) != 0: return
	_hint_wait -= delta
	if _hint_wait > 0.0: return
	_hint_wait = _rng.randf_range(HINT_EVERY.x,HINT_EVERY.y)
	if Vector2(p.x,p.z).distance_to(_xz(0)) > HINT_REACH: return
	traffic.door_run(door_for_traffic())
