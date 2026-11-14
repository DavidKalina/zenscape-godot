extends Node3D
## What the door between the regions shares (--world=doors with --doors=1;
## scripts/endless/world/profiles/doors.gd; docs/design/endless-flight/
## doors-handoff.md). The door itself is the ruin hall (hall_doors.gd, which
## extends this); the wall of standing amber cloud that was the first door
## is gone (2026-11-13).
##
##   the lands    each side has its own land stream, the far one prewarmed
##                while the plane is near a mouth (`_make_lands`, `_swap_land`).
##   the hour     each side keeps its own clock: the day cycle (when it
##                runs) is put on the far side's hour as it was left, the
##                first time its region's own (paint.hour) (`_set_hour`).
##   the wash     the near dressing primed for the far side (`_wash`).
##   the hint     now and then one traffic plane flies a line into the
##                wilderness door and is gone (EndlessTraffic `door_run`).

const Field = preload("res://scripts/endless/land_field.gd")
const LayoutOverrides = preload("res://scripts/layout_overrides.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

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
## The carry: "" (none), "in", "hold", "out".
var phase := ""
## Carries done, and the worst frame (ms) through the last one.
var passes := 0
var worst_ms := 0.0
var _host: Node3D
var _world: RefCounted
var _field: RefCounted
var _overlay: ColorRect
var _overlay_layer: CanvasLayer
var _hint_wait := 0.0
var _rng := RandomNumberGenerator.new()
## Each side's sun phase as it was left (-1: not yet visited).
var _clock: Array[float] = [-1.0,-1.0]

## Whether the doors run: the world has them, and --doors=1 (taken out of
## play 2026-11-12: no door to the amberlands by default).
static func wanted(world: RefCounted) -> bool:
	return flagged() and world != null and world.has_method("side_of")

## Whether --doors=1 asks for the doors.
static func flagged() -> bool:
	return "--doors=1" in LaunchArgs.user_args()

# --- What the hall door answers (hall_doors.gd) ------------------------------------------

func ground(_p: Vector3, h: Variant, _pad := -1.0) -> Variant:
	return h

func holds(_p: Vector3) -> bool:
	return false

func hall_floor() -> float:
	return 0.0

func late(_eye: Vector3) -> void:
	pass

## What a traffic plane flies into (EndlessTraffic `door_run`).
func door_for_traffic() -> Dictionary:
	return {}

# --- Places --------------------------------------------------------------------------

## The yaw that turns the box's z onto `dir` (XZ).
static func _yaw_of(dir: Vector2) -> float:
	return atan2(dir.x,dir.y)

func _ground(at: Vector2) -> float:
	return maxf(float(_field.height(at.x,at.y)),Field.SEA_Y)

func _xz(i: int) -> Vector2:
	var o: Vector3 = (walls[i].xform as Transform3D).origin
	return Vector2(o.x,o.z)

# --- The view's wash -------------------------------------------------------------------

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


# --- The far side's land --------------------------------------------------------------
#
# Each side has its own land stream (LandStream), the host's `land` the
# one the plane is on. Near a wall, the far side's stream is stepped round
# the spot it will come out at, so the carry finds it standing; the side
# left keeps its chunks for the way back.

## The streams by side (the host's own is the side it starts on).
var lands: Array[Node3D] = [null,null]
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

## The host's land swapped to side `to`'s stream.
func _swap_land(to: int) -> void:
	var c: Dictionary = lands[to].counts()
	_warm_share = float(c.standing)/maxf(float(c.wanted),1.0)
	_host.land = lands[to]

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
