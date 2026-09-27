extends Node
## The ground rumbles while the world is busy becoming something else, and a
## heavy fog pours across it (docs/scenic/stroke-feel.md, "Rumble and pour").
##
## - Rumble: callers `hold(source, strength)` for as long as their work runs
##   and `release(source)` when it is done. The envelope `level` builds toward
##   the strongest hold, then, once the last hold is released, keeps a low
##   tail while the editor is still resolving (forming, refreshing, settling
##   water) and eases out once it is not. The level drives the tremor's
##   rolling `rumble` (with slow swells) and GenesisAudio's rumble voice.
##   Presentation only: it runs while the world clock is paused.
## - Pour: `pour_fog(area, duration)` rolls a low, heavy fog in from upwind
##   (or out from the area's middle), pools it in the low ground up to a lid
##   that follows the drawn terrain as it forms, holds it, then lowers the lid
##   and thins it away. Published as the globals `zs_pour` and `zs_pour_area`
##   (shaders/reference_globals.gdshaderinc `zs_pour_at`), read by the display
##   fog and the native fog volume.
## Nothing allocates per frame; globals are written only while they move.

## Level response per second toward a stronger and a weaker target.
const RISE := 1.3
const FALL := 1.1
## Tremor rumble strength at level 1, before swells. Formation kicks (0.3-0.8
## trauma, squared) stay the sharp accents on top of this roll.
const PEAK := 0.36
## Swells: a slow breathing share and an occasional surge on top.
const BREATH := 0.22
const SURGE := 0.4
## Level the tail keeps while the editor is still resolving after the last
## release, as a share of the last hold's strength.
const TAIL := 0.55
## Rolling clock speed: slow at a whisper, quicker at full strength.
const ROLL_SPEED := Vector2(0.7,1.15)

## Seconds the fog takes to roll across the plate (or out to the area's edge).
const ROLL_IN := 2.6
## Lid depth above the plate floor while pouring, and where draining lowers it.
const POUR_DEPTH := 2.4
const DRAIN_DEPTH := 0.15
## Amount and lid response per second, filling and draining.
const FILL_RATE := 1.4
const DRAIN_RATE := 0.8
const LOWER_RATE := 1.0
## Flow clock speed (drives the pour's churn), still and at full rumble.
const FLOW := Vector2(0.35,1.0)

var scene: Node3D
var editor: NativeChunkEditor
var tremor: RefCounted
## The eased envelope, 0..1.
var level := 0.0
## The rumble strength last handed to the tremor (after swells).
var strength := 0.0
## True while anything holds the rumble or its tail runs.
var holding := false
## The pour: amount 0..1, lid depth above floor (m), front 0..1, flow clock.
var pour := Vector4.ZERO
var pouring := false
var _holds := {}
var _tail := 0.0
var _swell_clock := 0.0
var _pour_left := -1.0
var _pour_area := Vector4.ZERO
var _pour_published := true
var _rumble_published := true

func setup(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "WorldRumble"
	editor = scene._chunk_editor
	tremor = scene._tremor
	# Before the scene applies the tremor to the camera.
	process_priority = -10
	RenderingServer.global_shader_parameter_set(&"zs_pour", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set(&"zs_pour_area", Vector4.ZERO)

## Keep the ground rumbling at `strength` (0..1) until `release(source)`.
## Call again to change the strength; the strongest hold wins.
func hold(source: StringName, value := 1.0) -> void:
	_holds[source] = clampf(value, 0.0, 1.0)

func release(source: StringName) -> void:
	if not _holds.has(source): return
	var value: float = _holds[source]
	_holds.erase(source)
	if _holds.is_empty(): _tail = maxf(_tail, value * TAIL)

## Roll a heavy fog in. An empty `area` (plate metres) covers the whole plate
## from upwind; otherwise it spreads out over the area from its middle.
## `duration` < 0 holds it until the rumble has eased out; otherwise it drains
## after that many seconds. `drain_fog()` starts the drain early.
func pour_fog(area := Rect2(), duration := -1.0) -> void:
	var whole := area.size == Vector2.ZERO
	var next := Vector4.ZERO if whole else Vector4(area.get_center().x, area.get_center().y, maxf(3.0, area.size.length() * 0.5 + 2.0), 0.0)
	if pour.x < 0.02 or next != _pour_area:
		pour.z = 0.0
	_pour_area = next
	pouring = true
	_pour_left = duration
	RenderingServer.global_shader_parameter_set(&"zs_pour_area", _pour_area)

func drain_fog() -> void:
	pouring = false

## Anything the editor still has in hand after the last release.
func _resolving() -> bool:
	return editor != null and (editor.forming or editor.refresh_pending > 0 or editor.water_settling)

func _process(delta: float) -> void:
	if scene == null or delta <= 0.0: return
	delta = minf(delta, 0.1)
	var target := 0.0
	for value: float in _holds.values(): target = maxf(target, value)
	if _holds.is_empty() and _tail > 0.0:
		if _resolving(): target = _tail
		else: _tail = 0.0
	holding = target > 0.0
	level = lerpf(level, target, 1.0 - exp(-delta * (RISE if target > level else FALL)))
	if target == 0.0 and level < 0.01: level = 0.0
	_advance_rumble(delta)
	_advance_pour(delta)

func _advance_rumble(delta: float) -> void:
	if level <= 0.0:
		strength = 0.0
		if not _rumble_published:
			tremor.rumble = 0.0
			_rumble_published = true
		return
	_swell_clock += delta
	var t := _swell_clock
	var breath := sin(t * 1.3) * 0.6 + sin(t * 0.71 + 1.7) * 0.4
	var surge := maxf(0.0, sin(t * 0.43) * sin(t * 0.67 + 1.1))
	strength = PEAK * level * (1.0 - BREATH + BREATH * breath + SURGE * surge * level)
	strength = maxf(strength, 0.0)
	tremor.rumble = strength
	tremor.rumble_clock += delta * lerpf(ROLL_SPEED.x, ROLL_SPEED.y, level)
	_rumble_published = false

func _advance_pour(delta: float) -> void:
	if pouring and _pour_left >= 0.0:
		_pour_left -= delta
		if _pour_left <= 0.0: pouring = false
	# An open-ended pour drains as the rumble eases out.
	if pouring and _pour_left < 0.0 and not holding and pour.z >= 1.0: pouring = false
	if not pouring and pour.x <= 0.0:
		if not _pour_published:
			RenderingServer.global_shader_parameter_set(&"zs_pour", Vector4.ZERO)
			_pour_published = true
		return
	if pouring:
		pour.z = minf(1.0, pour.z + delta / ROLL_IN)
		pour.x = lerpf(pour.x, 1.0, 1.0 - exp(-delta * FILL_RATE))
		pour.y = lerpf(pour.y, POUR_DEPTH, 1.0 - exp(-delta * FILL_RATE))
	else:
		# The lid sinks into the valleys first, then what is left thins away.
		pour.y = lerpf(pour.y, DRAIN_DEPTH, 1.0 - exp(-delta * LOWER_RATE))
		var thin := smoothstep(POUR_DEPTH * 0.8, DRAIN_DEPTH, pour.y)
		pour.x = lerpf(pour.x, 0.0, 1.0 - exp(-delta * DRAIN_RATE * (0.35 + thin)))
		if pour.x < 0.01: pour = Vector4(0.0, 0.0, 0.0, pour.w)
	pour.w += delta * lerpf(FLOW.x, FLOW.y, level)
	RenderingServer.global_shader_parameter_set(&"zs_pour", pour)
	_pour_published = pour.x <= 0.0
