extends Node3D
## The storm front's lightning (docs/design/endless-flight/spec-storm-front.md,
## the lightning lane): bolts, the flash, thunder and strikes on the land.
## Built by studies/endless_flight.gd only when there is a storm
## (scripts/endless/storm_front.gd); stepped each frame after the look.
##
## Three kinds, all on the storm's own clock (held while the menu holds
## the flight) and one seeded draw, so a run repeats:
##   inside   a flash in the cloud over the core (often, from far off too),
##            now and then a channel crawling along under the base; no
##            ground. FLICKER_EVERY apart, more often the nearer the core.
##   far      a bolt to the ground somewhere in the core FAR_MIN m or more
##            off: seen, lit, heard; it touches nothing.
##   ground   a bolt near the plane's view under the core (STRIKE_RANGE m,
##            within VIEW_HALF of the camera's way, OFF_LINE m off the
##            plane's line, never at it), every STRIKE_EVERY s, the first
##            as soon as the core is within FIRST_AT m. It strikes, by
##            preference, a ruin (an arch gate or an aqueduct of
##            scripts/endless/land_arches.gd, broken through the breaks:
##            scripts/breaks/breakables.gd `hit` -> kit_breaks.gd), else the
##            tallest spruce in reach (LandTrees `knock`, TreeKnock `_fall`:
##            the tree's own fall, no cost to the plane), else a hilltop;
##            sparks, dirt and smoke burst where it lands.
## A bolt is a jagged channel from the cloud base (CLOUD_BASE, or BASE_OVER
## m over its foot) with branches and twigs, drawn as ribbons turned to the
## eye (shaders/storm_bolt.gdshader); it flashes as a run of strokes (the
## first lights the whole tree, restrikes the main channel only), then goes.
## The flash: a light from the bolt over the whole land (FLASH_LIGHT, night
## too), a local glow at a near strike's foot, the sky's pop
## (zs_storm_flash, the dome brightens toward it), and zs_lightning (vec4:
## the latest flash's xz, seconds since it began, its light now) for the
## cloud lane to light the cloud from inside.
## Thunder (assets/audio/thunder-1..3.mp3 through FlightSound `shot`) comes
## SOUND_SPEED late by the distance: a crack and the roll near, a low long
## roll far, a faint late rumble for a far flicker.
##
## It never touches the plane: no forces, and its strikes keep OFF_LINE m
## off the plane's line and STRIKE_RANGE.x away. A struck ruin's flight
## solid (land_arches.gd columns) is made again from what stands of it
## (LandArches `reshape`), and its stones, rubble and their ground are
## freed when its arch streams out (`_let_go`).
##
## Flags (for stills and checks):
##   --strike-at=F        one strike F frames in (the auto ones off unless
##                        --strike-auto)
##   --strike-kind=ground|far|inside   (ground)
##   --strike-range=M  --strike-bearing=DEG (off the view's middle, + right)
##   --strike-ruin        the forced strike takes the nearest ruin within
##                        RUIN_FORCED m in the storm, wherever it is
##   --strike-hold=S      the forced strike frozen S s into its flash
##   --strike-log         a line per strike

const LaunchArgs = preload("res://scripts/launch_args.gd")
const Field = preload("res://scripts/endless/land_field.gd")
const KitBreaks = preload("res://scripts/breaks/kit_breaks.gd")
const Kinds = preload("res://scripts/breaks/break_kinds.gd")

## The breaks' hub for the lightning: the shared one but for its hit-stop
## (a break's pause would slow the whole game's clock, the plane's too).
class Hub extends "res://scripts/breaks/breakables.gd":
	func pause(_frames: int, _scale: float) -> void:
		pass

## Sound's pace (m/s).
const SOUND_SPEED := 343.0
## The cloud base (world y) a bolt comes from, at least BASE_OVER m over
## its foot. (The cloud lane's base; tune together.)
const CLOUD_BASE := 200.0
const BASE_OVER := 170.0
## Ground strikes: how far from the plane (m), how far off the camera's
## way (rad), how far off the plane's line at least (m), how often (s), and
## the core this near the eye (m, its leading edge's d) for the first.
const STRIKE_RANGE := Vector2(260.0,1400.0)
const VIEW_HALF := 0.62
const OFF_LINE := 45.0
const STRIKE_EVERY := Vector2(5.0,9.0)
const FIRST_AT := 700.0
## The rain under a spot (StormFront `rain_at`) for a ground strike there.
const STRIKE_RAIN := 0.3
## Flickers and far bolts: how often (s, at the core and SEEN m off), the
## share that are far bolts, and how far a far bolt is at least (m).
const FLICKER_EVERY := Vector2(0.7,3.2)
const SEEN := 9000.0
const FAR_SHARE := 0.35
const FAR_MIN := 1600.0
## A ruin the forced strike takes, this near (m); a ruin's cut is made on
## a worker before the bolt, at most RUIN_WAIT s.
const RUIN_FORCED := 2500.0
const RUIN_WAIT := 8.0
## The tallest spruce near a spot: searched TREE_REACH m round it, at
## least TREE_TALL m; a hilltop HILL_REACH m round it.
const TREE_REACH := 70.0
const TREE_TALL := 9.0
const HILL_REACH := 160.0
## The channel: half width (m) of the main stroke, its branches' and their
## twigs'; their brightness; how far it wanders (share of its length).
const WIDTH := Vector3(0.6,0.32,0.16)
const BRIGHT := Vector3(1.0,0.5,0.28)
const WANDER := 0.2
const BRANCHES := Vector2i(6,12)
## The strokes: how many (a range), the gap between (s), the restrikes'
## strength, each one's fall-off (per s), a continuing current's.
const STROKES := Vector2i(2,5)
const STROKE_GAP := Vector2(0.04,0.14)
const RESTRIKE := Vector2(0.45,0.9)
const STROKE_DECAY := 20.0
const HANG_DECAY := 6.0
const HANG_CHANCE := 0.35
## The flash: the sky's pop at REACH m (as REACH over the distance, within
## POP_RANGE), the land's light (DirectionalLight energy at full), a near
## strike's glow at its foot (OmniLight energy, range).
const POP := 0.6
const REACH := 700.0
const POP_RANGE := Vector2(0.15,2.0)
const FLASH_LIGHT := 1.7
const GLOW := 9.0
const GLOW_RANGE := 420.0
## The rubble's ground under a struck ruin (the land's own colliders stand
## only round the eye): a patch GROUND_HALF m round it, GROUND_STEP m
## cells, on its own layer that only the falling stones see.
const GROUND_HALF := 48.0
const GROUND_STEP := 4.0
const GROUND_LAYER := 1 << 19

var study: Node3D
var storm: RefCounted
var strikes := 0
var ground_strikes := 0
var ruin_breaks := 0
var tree_knocks := 0
var flickers := 0
## Every strike: [clock, kind, what, distance, at].
var log_lines: Array = []
## The flash now (the brightest), where, and the sky's.
var flash := 0.0
var flash_at := Vector3.ZERO
var sky_at := Vector3.ZERO
var hub: Node3D
var breaks: Node3D

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _frames := 0
var _wait_flicker := 1.0
var _wait_strike := 0.0
var _strikes: Array[Dictionary] = []
var _thunders: Array = []
var _pending := {}
var _struck := {}
var _light: DirectionalLight3D
var _glow: OmniLight3D
var _shader := preload("res://shaders/storm_bolt.gdshader")
var _pop := 0.0
var _latest := Vector4(0.0,0.0,10000.0,0.0)
var _bursts := {}
var _soft: GradientTexture2D
var _dress := false
var _struck_root: Node3D
## Each struck ruin: {name, root, breaks (its own KitBreaks: its stones and
## rubble), patch (its stones' ground), gone (root-frame boxes of what
## broke)}; all freed when its arch's cell streams out (`_let_go`).
var _ruins: Array[Dictionary] = []
var _turn := {}
## The flags.
var _strike_at := -1
var _kind := "ground"
var _range := -1.0
var _bearing := NAN
var _hold := -1.0
var _ruin := false
var _auto := true
var _say := false

func setup(scene: Node3D, front: RefCounted) -> void:
	name = "StormLightning"
	study = scene
	storm = front
	_rng.seed = hash([int(scene.get("seed")),"storm-lightning"])
	for arg in LaunchArgs.user_args():
		if arg.begins_with("--strike-at="):
			_strike_at = int(arg.get_slice("=",1))
			_say = true
		elif arg.begins_with("--strike-kind="): _kind = arg.get_slice("=",1)
		elif arg.begins_with("--strike-range="): _range = float(arg.get_slice("=",1))
		elif arg.begins_with("--strike-bearing="): _bearing = deg_to_rad(float(arg.get_slice("=",1)))
		elif arg.begins_with("--strike-hold="): _hold = float(arg.get_slice("=",1))
		elif arg == "--strike-ruin": _ruin = true
		elif arg == "--strike-log": _say = true
	_auto = _strike_at < 0 or "--strike-auto" in LaunchArgs.user_args()
	_light = DirectionalLight3D.new()
	_light.name = "Flash"
	_light.light_color = Color(0.97,0.97,1.0)
	_light.shadow_enabled = false
	_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_light.visible = false
	add_child(_light)
	_glow = OmniLight3D.new()
	_glow.name = "Glow"
	_glow.light_color = Color(0.97,0.96,0.98)
	_glow.shadow_enabled = false
	_glow.omni_range = GLOW_RANGE
	_glow.omni_attenuation = 1.2
	_glow.visible = false
	add_child(_glow)
	hub = Hub.new()
	hub.set_breaker(&"lightning",true,1.0)
	hub.sound_hook = _ruin_sound
	add_child(hub)
	breaks = _new_breaks()
	_bursts_made()
	_wait_flicker = _rng.randf_range(0.3,1.5)

func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("zs_storm_flash",Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("zs_lightning",Vector4(0.0,0.0,10000.0,0.0))

# --- Each frame -----------------------------------------------------------------------------

func step(delta: float, held := false) -> void:
	var camera: Camera3D = study.camera
	if camera == null: return
	var dt := 0.0 if held else delta
	_t += dt
	_frames += 1
	var eye := camera.global_position
	if _strike_at >= 0 and _frames == _strike_at: _forced(eye,camera)
	if _auto and not held: _schedule(dt,eye,camera)
	if not _pending.is_empty(): _ruin_ready()
	elif breaks.ready_all and (breaks._deferred as Dictionary).is_empty(): _ready_off()
	_let_go()
	var falling := false
	for ruin: Dictionary in _ruins:
		if not ((ruin.breaks as Node).live as Array).is_empty(): falling = true
	if falling:
		_stones_see_ground()
		if not _dress and is_instance_valid(_struck_root): _stone(_struck_root)
		_dress = true
	elif _dress:
		# The rubble come to rest (merged): in the arches' own stone.
		_dress = false
		for ruin: Dictionary in _ruins: _stone(ruin.breaks)
		if is_instance_valid(_struck_root): _stone(_struck_root)
	for i in range(_thunders.size()-1,-1,-1):
		if float(_thunders[i][0]) <= _t:
			_thunder(_thunders[i])
			_thunders.remove_at(i)
	_update(dt,camera)

## The auto strikes: flickers while the core is in sight, ground strikes
## while it is over or near the plane.
func _schedule(dt: float, eye: Vector3, camera: Camera3D) -> void:
	var here := Vector2(eye.x,eye.z)
	var off := _core_off(here)
	if off < SEEN:
		_wait_flicker -= dt
		if _wait_flicker <= 0.0:
			if _rng.randf() < FAR_SHARE: _far(eye,camera,-1.0,NAN)
			else: _inside(eye,camera)
			var mean := lerpf(FLICKER_EVERY.x,FLICKER_EVERY.y,clampf(off/SEEN,0.0,1.0))
			_wait_flicker = maxf(-log(1.0-_rng.randf()*0.95)*mean,0.25)
	if storm.edge_distance(here) < FIRST_AT and _pending.is_empty():
		_wait_strike -= dt
		if _wait_strike <= 0.0:
			_wait_strike = _rng.randf_range(STRIKE_EVERY.x,STRIKE_EVERY.y) if _ground(eye,camera,-1.0,NAN,false) else 0.6

func _forced(eye: Vector3, camera: Camera3D) -> void:
	match _kind:
		"far": _far(eye,camera,_range,_bearing)
		"inside": _inside(eye,camera,_range,_bearing)
		_:
			if not _ground(eye,camera,_range,_bearing,_ruin): print("lightning: no spot for a ground strike")

## How far the eye is from the core's band (m, 0 under it).
func _core_off(p: Vector2) -> float:
	var d: float = storm.edge_distance(p)
	var across := 0.0
	if d > -300.0: across = d+300.0
	elif d < -3000.0: across = -3000.0-d
	var along := maxf(0.0,absf(float(storm.along(p)))-float(storm.length)*0.5)
	return Vector2(across,along).length()

# --- Picking where ----------------------------------------------------------------------

## The camera's way flat, and the plane's.
func _ways(camera: Camera3D) -> Array:
	var f := -camera.global_basis.z
	var view := Vector2(f.x,f.z)
	view = view.normalized() if view.length() > 0.05 else Vector2(0.0,-1.0)
	var v: Vector3 = study.plane.velocity
	var fly := Vector2(v.x,v.z)
	fly = fly.normalized() if fly.length() > 1.0 else view
	return [view,fly]

## Whether a spot keeps clear of the plane: STRIKE_RANGE.x away, and
## OFF_LINE m off its line ahead.
func _clear(p: Vector2, plane: Vector2, fly: Vector2) -> bool:
	var rel := p-plane
	if rel.length() < STRIKE_RANGE.x*0.8: return false
	var ahead := rel.dot(fly)
	var aside := absf(rel.dot(Vector2(-fly.y,fly.x)))
	return ahead < 0.0 or aside >= OFF_LINE

## A spot on the ground under the core in the camera's view, or INF.
func _spot(eye: Vector3, camera: Camera3D, range_m: float, bearing: float) -> Vector2:
	var ways := _ways(camera)
	var view: Vector2 = ways[0]
	var pp: Vector3 = study.plane.position
	var plane := Vector2(pp.x,pp.z)
	var e := Vector2(eye.x,eye.z)
	for k in range(32):
		var r := range_m if range_m > 0.0 else lerpf(STRIKE_RANGE.x,STRIKE_RANGE.y,pow(_rng.randf(),0.8))
		var b := bearing if not is_nan(bearing) else _rng.randf_range(-VIEW_HALF,VIEW_HALF)
		var p := e+view.rotated(b)*r
		if storm.rain_at(p) < STRIKE_RAIN and range_m < 0.0: continue
		if not _clear(p,plane,ways[1]): continue
		return p
	return Vector2.INF

## The ruin to strike: an arch gate or aqueduct in the storm, in view and
## in range (`forced`: the nearest within RUIN_FORCED m, anywhere), or {}.
func _ruin_near(eye: Vector3, camera: Camera3D, forced: bool) -> Dictionary:
	var arches: Node = study.get("arches")
	if arches == null: return {}
	var ways := _ways(camera)
	var view: Vector2 = ways[0]
	var pp: Vector3 = study.plane.position
	var plane := Vector2(pp.x,pp.z)
	var e := Vector2(eye.x,eye.z)
	var best := {}
	var best_d := INF
	for r: Dictionary in arches.standing():
		var spec: Dictionary = r.spec
		if not str(spec.kind) in ["gate","aqueduct"] or _struck.has(r.name): continue
		if not is_instance_valid(r.node): continue
		var at: Vector3 = r.pos
		var p := Vector2(at.x,at.z)
		var d := p.distance_to(e)
		if forced:
			if d > RUIN_FORCED or storm.amount_at(p) < 0.2: continue
		else:
			if d < STRIKE_RANGE.x or d > STRIKE_RANGE.y*1.1: continue
			if absf(view.angle_to(p-e)) > VIEW_HALF*1.25: continue
			if storm.rain_at(p) < STRIKE_RAIN*0.7: continue
			if not _clear(p,plane,ways[1]): continue
		# Nearest to the middle of the range (forced: nearest).
		var score := d if forced else absf(d-650.0)
		if score < best_d:
			best_d = score
			best = r
	return best

## The tallest spruce near `p`, {} if none is TREE_TALL m.
func _tree_near(p: Vector2) -> Dictionary:
	var trees: Node = study.get("trees")
	if trees == null or not bool(trees.get("enabled")): return {}
	var field: RefCounted = study.field
	var best := Vector3.INF
	var best_h := TREE_TALL
	for k in range(28):
		var q := p+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*TREE_REACH
		var top: float = trees.top_at(Vector3(q.x,0.0,q.y))
		if top == -INF: continue
		var h := top-float(field.height(q.x,q.y))
		if h > best_h:
			best_h = h
			best = Vector3(q.x,top,q.y)
	if best == Vector3.INF: return {}
	return trees.tree_in(best+Vector3.DOWN*0.4,true,0.5)

## The highest ground near `p` (world), the sea's top if lower.
func _hill_near(p: Vector2) -> Vector3:
	var field: RefCounted = study.field
	var best := Vector3(p.x,float(field.height(p.x,p.y)),p.y)
	for k in range(16):
		var q := p+Vector2.from_angle(_rng.randf()*TAU)*sqrt(_rng.randf())*HILL_REACH
		var h := float(field.height(q.x,q.y))
		if h > best.y: best = Vector3(q.x,h,q.y)
	best.y = maxf(best.y,Field.SEA_Y)
	return best

# --- The strikes ------------------------------------------------------------------------

## A ground strike near the view: a ruin, a tree or a hilltop. False if
## no spot would do.
func _ground(eye: Vector3, camera: Camera3D, range_m: float, bearing: float, ruin_forced: bool) -> bool:
	var ruin := _ruin_near(eye,camera,ruin_forced)
	if not ruin.is_empty() and _aim_ruin(ruin): return true
	if ruin_forced: print("lightning: no ruin in reach; striking the land")
	var p := _spot(eye,camera,range_m,bearing)
	if p == Vector2.INF: return false
	var t := _tree_near(p)
	if not t.is_empty():
		var top := Vector3(float(t.x),float(t.foot)+float(t.height),float(t.z))
		var stood: Dictionary = study.trees.knock(t)
		_bolt("ground",top,eye,1.0)
		ground_strikes += 1
		if not stood.is_empty():
			tree_knocks += 1
			var away := Vector3(top.x-eye.x,0.0,top.z-eye.z).normalized().rotated(Vector3.UP,_rng.randf_range(-1.2,1.2))
			if study.get("knock") != null: study.knock._fall(study,t,stood,away,14.0,top,0.8)
		_burst_at(top,"tree")
		_note("tree",top,eye)
		return true
	var hill := _hill_near(p)
	_bolt("ground",hill,eye,1.0)
	ground_strikes += 1
	_burst_at(hill,"water" if hill.y <= Field.SEA_Y+0.01 else "land")
	_note("water" if hill.y <= Field.SEA_Y+0.01 else "hill",hill,eye)
	return true

## A ruin made a breaks target, its cut begun on a worker; the bolt comes
## when the cut is made (`_ruin_ready`). False if it can't be broken.
func _aim_ruin(r: Dictionary) -> bool:
	var root: Node3D = r.node
	var spec: Dictionary = r.spec
	# Each ruin its own breaks, freed with it (`_let_go`).
	if not (breaks.targets as Array).is_empty(): breaks = _new_breaks()
	_ruins.append({"name":r.name,"root":root,"breaks":breaks,"patch":null,"gone":[]})
	var first: int = breaks.targets.size()
	if str(spec.kind) == "gate":
		for c: Node in root.get_children():
			if c is Node3D and c.name != "Body":
				if not c.has_meta("kit_piece"): c.set_meta("kit_piece",["arch",int(spec.seed),float(spec.weathered)])
				breaks.add(c as Node3D,"arch")
				break
	else:
		breaks.adopt(root)
	_struck[r.name] = true
	if breaks.targets.size() <= first:
		_ruins.pop_back()
		return false
	# The tallest of its pieces, struck at its top.
	var pick := first
	var top := -INF
	for i in range(first,breaks.targets.size()):
		var t: Dictionary = breaks.targets[i]
		var b: AABB = t.box
		var y: float = ((t.node as Node3D).global_transform*Vector3(b.get_center().x,b.end.y,b.get_center().z)).y
		if y > top + _rng.randf_range(-3.0,3.0):
			top = y
			pick = i
	var t: Dictionary = breaks.targets[pick]
	var box: AABB = t.box
	var xf: Transform3D = (t.node as Node3D).global_transform
	var at := xf*Vector3(box.get_center().x+_rng.randf_range(-0.2,0.2)*box.size.x,box.end.y,box.get_center().z)
	breaks.ready_all = true
	breaks._ready_job(pick,at)
	_pending = {"i":pick,"at":at,"root":root,"name":r.name,"by":_t+RUIN_WAIT}
	return true

## The ruin's bolt and its break, once its cut is made (or it waited too long).
func _ruin_ready() -> void:
	var i: int = _pending.i
	var t: Dictionary = breaks.targets[i]
	var root: Node3D = _pending.root
	if not is_instance_valid(root) or not is_instance_valid(t.node):
		_pending = {}
		return
	var pre: Dictionary = t.pre
	if not pre.is_empty() and not Kinds.done(pre) and _t < float(_pending.by): return
	var at: Vector3 = _pending.at
	_pending = {}
	var camera: Camera3D = study.camera
	var eye := camera.global_position
	_bolt("ground",at,eye,1.0)
	ground_strikes += 1
	var patch := _ground_patch(at)
	for ruin: Dictionary in _ruins:
		if ruin.root == root: ruin.patch = patch
	var broke: int = hub.hit(at,3.5,1.0,&"lightning")
	# A cut not made in time: the hit waits on it (KitBreaks ready mode).
	if broke == 0 and not (breaks._deferred as Dictionary).is_empty(): broke = 1
	if broke > 0:
		ruin_breaks += 1
		# The arch's stand-in boxes (scripts/endless/arch_build.gd) out of
		# the stones' way: what stands has its own hulls now.
		var body := root.get_node_or_null("Body") as CollisionObject3D
		if body != null: body.collision_layer = 0
		_stone(root)
		_struck_root = root
	_stones_see_ground()
	_burst_at(at,"stone")
	_note("ruin" if broke > 0 else "ruin (held)",at,eye)

## Ready mode off once the hits waiting on their cuts have landed, and no
## cut made ahead for what stands of a struck ruin (it isn't struck again;
## a stands' cut on the main thread's serve once hitched 0.8 s).
func _ready_off() -> void:
	breaks.ready_all = false
	for left: Dictionary in breaks.targets:
		if not (left.pre as Dictionary).is_empty():
			Kinds.drop(left.pre)
			left.pre = {}

## Every falling stone meets the rubble's ground (a burst's parts are
## new), in the arches' own stone.
func _stones_see_ground() -> void:
	for ruin: Dictionary in _ruins:
		for c: Node in (ruin.breaks as Node).get_children():
			if c is RigidBody3D and (c as RigidBody3D).collision_mask & GROUND_LAYER == 0:
				(c as RigidBody3D).collision_mask |= GROUND_LAYER
				_stone(c)

## A KitBreaks for the lightning's hits, on the hub.
func _new_breaks() -> Node3D:
	var b: Node3D = KitBreaks.new()
	b.name = "Breaks"
	b.hub = hub
	b.lost_y = Field.SEA_Y-80.0
	hub.add_child(b,true)
	hub.others.append(b)
	b.broke.connect(_on_broke.bind(b))
	return b

## A piece of a struck ruin broke: its box (the ruin's frame) noted, and
## the arch's flight solid made again from what is left once what stands
## of it is in (it comes in right after this signal).
func _on_broke(node: Node3D, _at: Vector3, from: Node3D) -> void:
	for ruin: Dictionary in _ruins:
		var root: Node3D = ruin.root
		if ruin.breaks != from or not is_instance_valid(root) or not root.is_ancestor_of(node): continue
		var box := AABB()
		for t: Dictionary in from.targets:
			if t.node == node: box = t.box
		if box.size == Vector3.ZERO: box = from._box_of(node)
		(ruin.gone as Array).append((root.global_transform.affine_inverse()*node.global_transform)*box)
		_reshape.call_deferred(ruin)

func _reshape(ruin: Dictionary) -> void:
	var root: Node3D = ruin.root
	var arches: Node = study.get("arches")
	if arches == null or not arches.has_method("reshape") or not is_instance_valid(root): return
	var t0 := Time.get_ticks_usec()
	arches.reshape(root,ruin.gone)
	if _say: print("lightning: %s's flight solid made again from what stands (%.1f ms)" % [ruin.name,(Time.get_ticks_usec()-t0)/1000.0])

## A struck ruin whose arch has streamed out (its cell freed past the
## arches' reach): its stones, rubble and ground freed with it, and its
## name free to be struck again when the arch is built anew.
func _let_go() -> void:
	for i in range(_ruins.size()-1,-1,-1):
		var ruin: Dictionary = _ruins[i]
		var root: Node3D = ruin.root
		if is_instance_valid(root) and not root.is_queued_for_deletion(): continue
		if not _pending.is_empty() and _pending.root == root: _pending = {}
		var b: Node3D = ruin.breaks
		hub.others.erase(b)
		if b == breaks:
			breaks = _new_breaks()
		b.queue_free()
		var patch: Variant = ruin.patch
		if patch != null and is_instance_valid(patch): (patch as Node).queue_free()
		_struck.erase(ruin.name)
		_ruins.remove_at(i)

## The kit's stone under `node` swapped for the endless arches' lit one
## (LandArches `_sunlit`), as the arch it broke from wore.
func _stone(node: Node) -> void:
	var arches: Node = study.get("arches")
	if arches != null and arches.has_method("_sunlit") and not bool(arches.get("_old_stone")): arches._sunlit(node)

## A far bolt: somewhere in the core, FAR_MIN m or more off.
func _far(eye: Vector3, camera: Camera3D, range_m: float, bearing: float) -> void:
	var e := Vector2(eye.x,eye.z)
	var view: Vector2 = _ways(camera)[0]
	for k in range(24):
		var p: Vector2
		if range_m > 0.0 or not is_nan(bearing):
			var b := bearing if not is_nan(bearing) else _rng.randf_range(-VIEW_HALF,VIEW_HALF)
			p = e+view.rotated(b)*(range_m if range_m > 0.0 else _rng.randf_range(FAR_MIN,6000.0))
		else:
			p = _in_core(_rng.randf_range(-2900.0,-500.0))
		if p.distance_to(e) < FAR_MIN*0.8 and range_m < 0.0: continue
		if storm.rain_at(p) < 0.2 and range_m < 0.0: continue
		var foot := Vector3(p.x,maxf(float(study.field.height(p.x,p.y)),Field.SEA_Y),p.y)
		_bolt("far",foot,eye,1.0)
		_note("far",foot,eye)
		return

## A flash in the cloud over the core; now and then a channel crawling
## along under its base. A forced one with --strike-range= (and
## --strike-bearing=) flashes there instead.
func _inside(eye: Vector3, camera: Camera3D, range_m := -1.0, bearing := NAN) -> void:
	var e := Vector2(eye.x,eye.z)
	var p := _in_core(_rng.randf_range(-2900.0,-400.0))
	# Mostly the nearer stretch of the line.
	if p.distance_to(e) > 7000.0: p = _in_core(_rng.randf_range(-2900.0,-400.0),e)
	if range_m > 0.0: p = e+(_ways(camera)[0] as Vector2).rotated(0.0 if is_nan(bearing) else bearing)*range_m
	var at := Vector3(p.x,CLOUD_BASE+_rng.randf_range(40.0,260.0),p.y)
	_bolt("inside",at,eye,_rng.randf_range(0.5,1.0))
	flickers += 1

## A point at `d` (the edge's distance) in the core: along the line at a
## random place (near `near` if given).
func _in_core(d: float, near := Vector2.INF) -> Vector2:
	var h: Vector2 = storm.heading()
	var side := Vector2(-h.y,h.x)
	var edge: Vector2 = storm.edge()
	var half := float(storm.length)*0.5-600.0
	var a := _rng.randf_range(-half,half)
	if near != Vector2.INF: a = clampf((near-edge).dot(side)+_rng.randf_range(-2500.0,2500.0),-half,half)
	return edge+h*d+side*a

## A strike's light and look: `kind` ground, far (a bolt down to `at`) or
## inside (a flash at `at`, maybe a channel along the base).
func _bolt(kind: String, at: Vector3, eye: Vector3, gain: float) -> void:
	var lines: Array = []
	var sky := at
	var distance := eye.distance_to(at)
	if kind == "inside":
		if _rng.randf() < 0.45:
			var side := Vector3(_rng.randf_range(-1.0,1.0),0.0,_rng.randf_range(-1.0,1.0)).normalized()
			var length := _rng.randf_range(300.0,1100.0)
			var y := CLOUD_BASE+_rng.randf_range(-10.0,30.0)
			var a := Vector3(at.x,y,at.z)-side*length*0.5
			var b := Vector3(at.x,y-_rng.randf_range(-20.0,40.0),at.z)+side*length*0.5
			lines = _tree(a,b,true)
		distance = eye.distance_to(at)
	else:
		var top := maxf(CLOUD_BASE,at.y+BASE_OVER)+_rng.randf_range(0.0,60.0)
		var lean := Vector3(_rng.randf_range(-1.0,1.0),0.0,_rng.randf_range(-1.0,1.0))*(top-at.y)*0.22
		var root := Vector3(at.x,top,at.z)+lean
		lines = _tree(root,at,false)
		sky = root.lerp(at,0.25)
		distance = eye.distance_to(root.lerp(at,0.6))
	var strokes: Array = [[0.0,1.0,STROKE_DECAY]]
	var count := 1 if kind == "inside" and _rng.randf() < 0.5 else _rng.randi_range(STROKES.x,STROKES.y)
	var t := 0.0
	for s in range(count-1):
		t += _rng.randf_range(STROKE_GAP.x,STROKE_GAP.y)
		var decay := HANG_DECAY if _rng.randf() < HANG_CHANCE/count else STROKE_DECAY
		strokes.append([t,_rng.randf_range(RESTRIKE.x,RESTRIKE.y),decay])
	var strike := {"kind":kind,"at":at,"sky":sky,"t":0.0,"strokes":strokes,"end":t+0.9,"distance":distance,
		"gain":gain*(0.8 if kind == "inside" else 1.0),"hold":_hold >= 0.0 and _frames == _strike_at}
	if not lines.is_empty():
		var mi := MeshInstance3D.new()
		mi.name = "Bolt"
		mi.top_level = true
		mi.mesh = _ribbons(lines)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.extra_cull_margin = 400.0
		var m := ShaderMaterial.new()
		m.shader = _shader
		m.render_priority = 5
		mi.material_override = m
		add_child(mi)
		mi.global_transform = Transform3D.IDENTITY
		strike.mesh = mi
		strike.material = m
	_strikes.append(strike)
	strikes += 1
	var big := 1.0 if kind == "ground" else (0.75 if kind == "far" else 0.35)
	_thunders.append([_t+distance/SOUND_SPEED,distance,big*gain])

func _note(what: String, at: Vector3, eye: Vector3) -> void:
	var d := eye.distance_to(at)
	log_lines.append([_t,what,d,at])
	if _say: print("lightning: %s %.0f m off at %s (t %.1f s)" % [what,d,at.round(),_t])

# --- The channel ------------------------------------------------------------------------

## The channels from `a` to `b`: the main one and its branches, each
## {points, width, bright, main}. `across` hangs its branches down too.
func _tree(a: Vector3, b: Vector3, across: bool) -> Array:
	var length := a.distance_to(b)
	var main := _channel(a,b,WANDER,7 if length < 400.0 else 8)
	var lines: Array = [{"points":main,"width":WIDTH.x,"bright":BRIGHT.x,"main":true,"ends":across}]
	var count := _rng.randi_range(BRANCHES.x,BRANCHES.y)
	for k in range(count):
		# More near the root, where the leader forked most.
		var u := pow(_rng.randf(),1.5)*0.85
		var i := clampi(int(u*(main.size()-1)),1,main.size()-2)
		var from: Vector3 = main[i]
		var along := (main[mini(i+4,main.size()-1)]-main[maxi(i-4,0)]).normalized()
		var off := _rng.randf_range(0.35,0.9)*(1.0 if _rng.randf() < 0.5 else -1.0)
		var sideways := along.cross(Vector3.UP if absf(along.y) < 0.9 else Vector3.RIGHT).normalized().rotated(along,_rng.randf_range(0.0,TAU))
		var dir := (along+sideways*off*1.4).normalized()
		if across: dir = (dir+Vector3.DOWN*_rng.randf_range(0.3,1.2)).normalized()
		var reach := length*(1.0-u)*_rng.randf_range(0.15,0.45)
		var end := from+dir*reach
		if not across: end.y = maxf(end.y,b.y+4.0)
		var branch := _channel(from,end,WANDER*1.3,5)
		lines.append({"points":branch,"width":WIDTH.y,"bright":BRIGHT.y*_rng.randf_range(0.6,1.2),"main":false})
		for s in range(_rng.randi_range(0,2)):
			var j := _rng.randi_range(2,branch.size()-3)
			var twig_from: Vector3 = branch[j]
			var twig_dir := (dir+Vector3(_rng.randf_range(-0.6,0.6),_rng.randf_range(-0.5,0.1),_rng.randf_range(-0.6,0.6))).normalized()
			var twig := _channel(twig_from,twig_from+twig_dir*reach*_rng.randf_range(0.2,0.45),WANDER*1.4,4)
			lines.append({"points":twig,"width":WIDTH.z,"bright":BRIGHT.z,"main":false})
	return lines

## A jagged channel from `a` to `b`: the line halved `levels` times, each
## new middle thrown aside by `wander` of its span (a little less each
## level: lightning is ragged at every size).
func _channel(a: Vector3, b: Vector3, wander: float, levels: int) -> PackedVector3Array:
	var points := PackedVector3Array([a,b])
	var amount := wander
	for level in range(levels):
		var out := PackedVector3Array([points[0]])
		for i in range(points.size()-1):
			var p := points[i]
			var q := points[i+1]
			var span := p.distance_to(q)
			var d := (q-p)/maxf(span,0.001)
			var n1 := d.cross(Vector3.UP if absf(d.y) < 0.95 else Vector3.RIGHT).normalized()
			var n2 := d.cross(n1)
			var push := (n1*_rng.randf_range(-1.0,1.0)+n2*_rng.randf_range(-1.0,1.0))*span*amount
			out.append((p+q)*0.5+push+d*span*_rng.randf_range(-0.12,0.12))
			out.append(q)
		points = out
		amount *= 0.88
	return points

## The ribbons' mesh (shaders/storm_bolt.gdshader's layout).
func _ribbons(lines: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var uv2s := PackedVector2Array()
	var colours := PackedColorArray()
	var index := PackedInt32Array()
	for line: Dictionary in lines:
		var points: PackedVector3Array = line.points
		var n := points.size()
		var base := verts.size()
		var main: bool = line.main
		var bead := _rng.randf()*100.0
		for i in range(n):
			var tangent := (points[mini(i+1,n-1)]-points[maxi(i-1,0)]).normalized()
			var u := float(i)/float(n-1)
			var w: float = float(line.width)*(lerpf(1.0,0.75,u) if main else lerpf(1.0,0.35,u))
			# Its brightness beads along it (a channel is never even).
			var beads := 1.0+0.35*sin(bead+float(i)*0.9)*sin(bead*0.37+float(i)*0.23)
			for side in [-1.0,1.0]:
				verts.append(points[i])
				normals.append(tangent)
				uvs.append(Vector2(side,u))
				uv2s.append(Vector2(w,float(line.bright)*beads))
				colours.append(Color(1.0 if main else 0.0,1.0 if line.get("ends",false) else 0.0,0.0,1.0))
		for i in range(n-1):
			var k := base+i*2
			index.append_array(PackedInt32Array([k,k+1,k+2,k+1,k+3,k+2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_COLOR] = colours
	arrays[Mesh.ARRAY_INDEX] = index
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh

# --- The flash --------------------------------------------------------------------------

## The strikes' flashes this frame: each one's strokes summed, the ribbons
## lit, the brightest made the flash; the lights and the globals set.
func _update(dt: float, camera: Camera3D) -> void:
	var size := get_viewport().get_visible_rect().size
	var pixel := 2.0*tan(deg_to_rad(camera.fov)*0.5)/maxf(size.y,1.0)
	var veil: float = storm.rain_at(Vector2(camera.global_position.x,camera.global_position.z))
	flash = 0.0
	_pop = 0.0
	var light_k := 0.0
	var light_from := Vector3.ZERO
	var glow_k := 0.0
	var glow_at := Vector3.ZERO
	for i in range(_strikes.size()-1,-1,-1):
		var s: Dictionary = _strikes[i]
		if s.hold: s.t = _hold
		else: s.t += dt
		var t: float = s.t
		var main := 0.0
		var first := 0.0
		for k in range((s.strokes as Array).size()):
			var stroke: Array = s.strokes[k]
			var since: float = t-float(stroke[0])
			if since < 0.0: continue
			var v: float = float(stroke[1])*exp(-since*float(stroke[2]))
			main = maxf(main,v)
			if k == 0: first = v
		# The channel glows faintly between the strokes while they last.
		if t < float(s.strokes[-1][0]): main = maxf(main,0.12)
		if s.has("material"):
			var m: ShaderMaterial = s.material
			m.set_shader_parameter("flash",main)
			m.set_shader_parameter("branch_flash",first)
			m.set_shader_parameter("pixel",pixel)
			m.set_shader_parameter("veil",veil)
			(s.mesh as Node3D).visible = main > 0.004
		var reach := clampf(REACH/maxf(float(s.distance),1.0),POP_RANGE.x,POP_RANGE.y)
		var lit := main*float(s.gain)
		if lit > flash:
			flash = lit
			flash_at = s.at
			sky_at = s.sky
			_latest = Vector4(flash_at.x,flash_at.z,t,0.0)
		_pop = maxf(_pop,main*reach*float(s.gain))
		var k_light := main*float(s.gain)*clampf(reach,0.25,1.0)*(0.45 if s.kind == "inside" else 1.0)
		if k_light > light_k:
			light_k = k_light
			light_from = s.sky
		if s.kind == "ground" and main > glow_k:
			glow_k = main
			glow_at = (s.at as Vector3)+Vector3.UP*25.0
		if not s.hold and t > float(s.end):
			if s.has("mesh"): (s.mesh as Node).queue_free()
			_strikes.remove_at(i)
	_light.visible = light_k > 0.01
	if _light.visible:
		_light.light_energy = light_k*FLASH_LIGHT
		var way := (camera.global_position+Vector3.DOWN*60.0)-light_from
		way = (way.normalized()+Vector3.DOWN*0.8).normalized()
		_light.global_transform = Transform3D(Basis.looking_at(way,Vector3.RIGHT if absf(way.y) > 0.95 else Vector3.UP),Vector3.ZERO)
	_glow.visible = glow_k > 0.01
	if _glow.visible:
		_glow.global_position = glow_at
		_glow.light_energy = glow_k*GLOW
	if flash <= 0.0: _latest.z += dt
	_latest.w = flash
	RenderingServer.global_shader_parameter_set("zs_storm_flash",Vector4(sky_at.x,sky_at.y,sky_at.z,_pop*POP))
	RenderingServer.global_shader_parameter_set("zs_lightning",_latest)

# --- Thunder ----------------------------------------------------------------------------

## [when, distance, loudness]: a crack and the roll near, a lower longer
## roll far, a faint rumble for a far flicker.
func _thunder(th: Array) -> void:
	var sound: Node = study.get("sound")
	if sound == null: return
	var d := float(th[1])
	var big := float(th[2])
	if d < 700.0:
		sound.shot("thunder",1.0*big,1.05)
		sound.shot("crack",0.9*big,0.55)
	elif d < 2500.0:
		sound.shot("thunder",lerpf(0.85,0.45,(d-700.0)/1800.0)*big,0.88)
	else:
		sound.shot("thunder",clampf(0.4*2500.0/d,0.07,0.4)*big,0.72)

## The breaks' sounds (BreakPieces VOICES), far off: by their distance.
func _ruin_sound(sound_name: StringName, at: Vector3) -> void:
	var sound: Node = study.get("sound")
	var camera: Camera3D = study.camera
	if sound == null or camera == null: return
	var d := camera.global_position.distance_to(at)
	var g := clampf(90.0/maxf(d,1.0),0.0,0.7)
	match sound_name:
		&"ruin_crack", &"ruin_boom": sound.shot("crash",g,0.8)
		_: sound.shot("debris",g*0.8,0.85)

# --- What it leaves ---------------------------------------------------------------------

## A trimesh of the land round `at` for the falling stones (GROUND_LAYER).
func _ground_patch(at: Vector3) -> StaticBody3D:
	var field: RefCounted = study.field
	var n := int(GROUND_HALF*2.0/GROUND_STEP)+1
	var o := Vector2(snappedf(at.x,GROUND_STEP)-GROUND_HALF,snappedf(at.z,GROUND_STEP)-GROUND_HALF)
	var h := PackedFloat32Array()
	h.resize(n*n)
	for j in range(n):
		for i in range(n):
			h[j*n+i] = float(field.height(o.x+i*GROUND_STEP,o.y+j*GROUND_STEP))
	var faces := PackedVector3Array()
	for j in range(n-1):
		for i in range(n-1):
			var a := Vector3(o.x+i*GROUND_STEP,h[j*n+i],o.y+j*GROUND_STEP)
			var b := Vector3(a.x+GROUND_STEP,h[j*n+i+1],a.z)
			var c := Vector3(a.x,h[(j+1)*n+i],a.z+GROUND_STEP)
			var d := Vector3(a.x+GROUND_STEP,h[(j+1)*n+i+1],a.z+GROUND_STEP)
			faces.append_array(PackedVector3Array([a,b,c,b,d,c]))
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	shape.backface_collision = true
	var body := StaticBody3D.new()
	body.name = "RubbleGround"
	body.collision_layer = GROUND_LAYER
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	add_child(body)
	return body

## The bursts: sparks, dirt and smoke (two of each, taken in turn).
func _bursts_made() -> void:
	var round := Gradient.new()
	round.set_color(0,Color(1,1,1,1))
	round.set_color(1,Color(1,1,1,0))
	round.add_point(0.45,Color(1,1,1,0.7))
	_soft = GradientTexture2D.new()
	_soft.gradient = round
	_soft.fill = GradientTexture2D.FILL_RADIAL
	_soft.fill_from = Vector2(0.5,0.5)
	_soft.fill_to = Vector2(1.0,0.5)
	_soft.width = 64
	_soft.height = 64
	var kinds := {
		"sparks":{"color":Color(3.0,2.6,2.0),"amount":48,"size":0.7,"speed":Vector2(10.0,32.0),"gravity":-9.8,"life":0.9,"spread":85.0,"lit":false,"grow":false},
		"dirt":{"color":Color(0.2,0.16,0.12),"amount":36,"size":1.3,"speed":Vector2(6.0,22.0),"gravity":-14.0,"life":1.8,"spread":60.0,"lit":true,"grow":false},
		"smoke":{"color":Color(0.24,0.24,0.25,0.6),"amount":18,"size":8.0,"speed":Vector2(1.0,5.0),"gravity":0.6,"life":4.5,"spread":70.0,"lit":true,"grow":true},
		"stones":{"color":Color(0.5,0.47,0.42),"amount":30,"size":0.9,"speed":Vector2(5.0,18.0),"gravity":-12.0,"life":2.0,"spread":70.0,"lit":true,"grow":false},
		"spray":{"color":Color(0.85,0.9,0.95,0.7),"amount":40,"size":2.2,"speed":Vector2(6.0,20.0),"gravity":-9.8,"life":1.6,"spread":40.0,"lit":true,"grow":true},
	}
	for kind: String in kinds:
		var k: Dictionary = kinds[kind]
		var pool: Array = []
		for i in range(2):
			var p := CPUParticles3D.new()
			p.name = "Burst_%s_%d" % [kind,i]
			p.emitting = false
			p.one_shot = true
			p.explosiveness = 0.92
			p.amount = int(k.amount)
			p.lifetime = float(k.life)
			p.spread = float(k.spread)
			p.gravity = Vector3(0.0,float(k.gravity),0.0)
			p.damping_min = 1.0
			p.damping_max = 3.0
			p.scale_amount_min = 0.5
			p.scale_amount_max = 1.4
			var fade := Gradient.new()
			var c: Color = k.color
			fade.set_color(0,c)
			fade.set_color(1,Color(c.r,c.g,c.b,0.0))
			p.color_ramp = fade
			if bool(k.grow):
				var curve := Curve.new()
				curve.add_point(Vector2(0.0,0.35))
				curve.add_point(Vector2(1.0,1.0))
				p.scale_amount_curve = curve
			var quad := QuadMesh.new()
			quad.size = Vector2.ONE*float(k.size)
			var m := StandardMaterial3D.new()
			m.albedo_texture = _soft
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.vertex_color_use_as_albedo = true
			m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL if bool(k.lit) else BaseMaterial3D.SHADING_MODE_UNSHADED
			if not bool(k.lit): m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			quad.material = m
			p.mesh = quad
			p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			p.visibility_aabb = AABB(Vector3(-60,-60,-60),Vector3(120,120,120))
			add_child(p)
			pool.append(p)
		_bursts[kind] = pool
		_turn[kind] = 0

func _burst(kind: String, at: Vector3, normal := Vector3.UP) -> void:
	var pool: Array = _bursts[kind]
	var i: int = _turn[kind]
	_turn[kind] = (i+1)%pool.size()
	var p: CPUParticles3D = pool[i]
	p.global_position = at
	p.direction = normal
	p.initial_velocity_min = 0.0
	var k_speed := {"sparks":Vector2(10.0,32.0),"dirt":Vector2(6.0,22.0),"smoke":Vector2(1.0,5.0),"stones":Vector2(5.0,18.0),"spray":Vector2(6.0,20.0)}
	p.initial_velocity_min = (k_speed[kind] as Vector2).x
	p.initial_velocity_max = (k_speed[kind] as Vector2).y
	p.restart()
	p.emitting = true

## What a strike throws up where it lands.
func _burst_at(at: Vector3, what: String) -> void:
	_burst("sparks",at+Vector3.UP*0.5)
	match what:
		"water": _burst("spray",at)
		"stone":
			_burst("stones",at)
			_burst("smoke",at)
		"tree": _burst("smoke",at)
		_:
			_burst("dirt",at)
			_burst("smoke",at)

## A line for --storm-debug.
func note() -> String:
	return "lightning  %d strikes (%d ground: %d ruins broken, %d trees)  ·  %d flickers  ·  flash %.2f" % [
		strikes,ground_strikes,ruin_breaks,tree_knocks,flickers,flash]
