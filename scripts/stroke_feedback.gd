extends Node
## A painted stroke answers the hand. Listens to NativeChunkEditor's stroke
## signals and drives five cheap, time-damped responses:
## - tremor: the camera rumbles while land rises, scaled by how fast it rises;
## - fog: a reveal hole (global `zs_reveal`) parts the fog over the stroke;
##   each brush's mix of these is in BRUSH_FEEL (pouring water does not
##   rumble; it swells the air more softly);
## - wind: `atmosphere.swell` eases up during a stroke and down after it, and
##   fog-parting puffs ride the air across the brush;
## - growth: `zs_growth_wave_N` slots replay the plant grow-in pop locally, so
##   plants the brush passes shrink and pop back while the rest stays grown;
## - arrival gusts: a light puff over each batch of emerged trees as they are
##   born, long after the stroke, so they sway as they settle in.
## Nothing here allocates per frame; globals are only written while they move.

const LAND_MODES := ["raise", "lower", "flatten", "smooth", "mountain", "land"]
const GROWTH_MODES := ["grass", "blades", "meadow", "flower", "assets"]
## The creation brushes (scripts/genesis_canvas.gd), by the brush id their
## strokes carry: rumble scale (0 is none), wind swell, fog reveal, seconds
## between fog-parting puffs (0 is none) and the local grow-in wave. The
## craft Meadow tool shares the meadow brush's feel.
const BRUSH_FEEL := {
	"land": {"rumble": 1.0, "swell": 0.45, "reveal": true, "gust": 0.7, "wave": true},
	"meadow": {"rumble": 0.0, "swell": 0.28, "reveal": true, "gust": 1.2, "wave": true},
	# A strong swell, so the standing trees heave as the new forest is wished.
	"forest": {"rumble": 0.15, "swell": 0.62, "reveal": true, "gust": 0.55, "wave": true},
	# Wearing a path is quiet: no rumble, no puffs, plants are not re-popped.
	"path": {"rumble": 0.0, "swell": 0.1, "reveal": true, "gust": 0.0, "wave": false},
	# Pouring water is gentle: the fog parts over the pour and the air swells
	# softly; no rumble, no puffs, no grow-in wave.
	"water": {"rumble": 0.0, "swell": 0.28, "reveal": true, "gust": 0.0, "wave": false},
}

# Tremor. Kicks stay under the creature's 0.2 stumble threshold; a mountain thump does not.
const RUMBLE_MAX := 0.42
const RUMBLE_KICK := 0.15
## Brush strength spent per second that reads as a full-speed rise.
const RUMBLE_FULL_RATE := 2.0
const RUMBLE_MODE := {"raise": 1.0, "mountain": 1.3, "lower": 0.7, "flatten": 0.35, "smooth": 0.25, "land": 1.0}
const RATE_RESPONSE := 6.0
const MOUNTAIN_THUMP := 0.5

# Wind swell, added to the eased wind dial (dial units, 0.4 is a normal breeze).
const SWELL_LAND := 0.45
const SWELL_GROWTH := 0.2
const SWELL_RISE := 1.4
const SWELL_FALL := 0.4
const SWELL_HOLD := 0.8
## Seconds between fog-parting air puffs sent across a land stroke.
const GUST_INTERVAL := 0.7
## Arrival gusts: emerged trees (scripts/emergence.gd `tree_arrived`) arrive
## long after the stroke's swell has eased, so each little batch gets its own
## light puff as it is born. A puff starts upwind and reaches the trees about
## as they finish rising, so they sway as they settle in. Trees born within
## ARRIVAL_GAP s of each other share one puff at their middle.
const ARRIVAL_GAP := 1.2
const ARRIVAL_PUFF := 0.3

# Fog reveal over the stroke's bounds.
const REVEAL_STRENGTH := 0.85
const REVEAL_MARGIN := 1.8
const REVEAL_MIN_RADIUS := 3.5
const REVEAL_MAX_RADIUS := 10.0
const REVEAL_RISE := 1.6
const REVEAL_FALL := 0.3
const REVEAL_FOLLOW := 2.5
## How long the fog stays parted after the hand lifts.
const REVEAL_HOLD := 2.5

# Local grow-in waves.
const WAVE_SLOTS := 6
## Wave radius as a multiple of the brush radius.
const WAVE_REACH := 1.25
## A new wave drops when the brush has moved this many brush radii from the last.
const WAVE_SPACING := 0.9
const WAVE_SECONDS := 1.8
## Plants a new wave covers shrink away this fast before they pop back.
const WAVE_SHRINK_SECONDS := 0.16
const WAVE_GLOBALS: Array[StringName] = [&"zs_growth_wave_0", &"zs_growth_wave_1", &"zs_growth_wave_2", &"zs_growth_wave_3", &"zs_growth_wave_4", &"zs_growth_wave_5"]

var _scene: Node3D
var _atmosphere: Node3D
var _tremor: RefCounted
var _stroking := false
var _land := false
var _growth := false
var _mode := ""
## The stroke's feel: BRUSH_FEEL's shape, derived for craft tools.
var _rumble := 0.0
var _swell_goal := 0.0
var _reveal := false
var _gust_interval := 0.0
var _wave := false
var _brush := Vector2.ZERO
var _brush_radius := 0.0
var _spent := 0.0
var _rate := 0.0
var _after := INF
var _swell := 0.0
var _gust_timer := 0.0
var _bounds_min := Vector2.ZERO
var _bounds_max := Vector2.ZERO
var _reveal_center := Vector2.ZERO
var _reveal_radius := 0.0
var _reveal_strength := 0.0
var _reveal_published := true
var _waves := PackedVector4Array()
var _newest := -1
var _editor: NativeChunkEditor
## Emerged trees waiting for their birth: Vector3(x, z, born) in plate metres.
var _arriving := PackedVector3Array()
var _arrival_wait := 0.0

func setup(scene: Node3D) -> void:
	_scene = scene
	_atmosphere = scene._atmosphere
	_tremor = scene._tremor
	_waves.resize(WAVE_SLOTS)
	for i in range(WAVE_SLOTS):
		_waves[i] = Vector4(0.0, 0.0, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set(WAVE_GLOBALS[i], _waves[i])
	RenderingServer.global_shader_parameter_set(&"zs_reveal", Vector4.ZERO)
	var editor: NativeChunkEditor = scene._chunk_editor
	editor.stroke_started.connect(_on_stroke_started)
	editor.stroke_moved.connect(_on_stroke_moved)
	editor.stroke_finished.connect(_on_stroke_finished)
	_editor = editor
	editor.emergence.tree_arrived.connect(func(p: Vector2, born: float) -> void: _arriving.append(Vector3(p.x, p.y, born)))
	editor.data.state_restored.connect(func(_state: Dictionary) -> void: _arriving.clear())

func _on_stroke_started(center: Vector3, radius: float, mode: String) -> void:
	_mode = mode
	var feel: Dictionary = BRUSH_FEEL.get(mode, {})
	_land = mode in LAND_MODES
	_growth = mode in GROWTH_MODES
	if feel.is_empty():
		if not _land and not _growth:
			return
		feel = {"rumble": float(RUMBLE_MODE.get(mode, 0.0)), "swell": SWELL_LAND if _land else SWELL_GROWTH, "reveal": _land, "gust": GUST_INTERVAL if _land else 0.0, "wave": true}
	# The clay's strokes shake by how far the land moves (scripts/clay_tremor.gd),
	# not by the brush mode the editor was left in.
	var clay: Node = _scene.get("land_clay") as Node
	_rumble = 0.0 if clay != null and bool(clay.stroking) else feel.rumble
	_swell_goal = feel.swell
	_reveal = feel.reveal
	_gust_interval = feel.gust
	_wave = feel.wave
	_stroking = true
	_after = 0.0
	_brush = Vector2(center.x, center.z)
	_brush_radius = radius
	_bounds_min = _brush
	_bounds_max = _brush
	_gust_timer = 0.0
	if _wave:
		_drop_wave()
	if _reveal and _reveal_strength < 0.02:
		_reveal_center = _brush
		_reveal_radius = maxf(REVEAL_MIN_RADIUS, radius * REVEAL_MARGIN)
	if mode == "mountain" and not _scene._paused:
		if _rumble > 0.0: _tremor.add(MOUNTAIN_THUMP)
		_swell = maxf(_swell, SWELL_LAND * 0.6)

func _on_stroke_moved(center: Vector3, radius: float, _mode_name: String, amount: float) -> void:
	if not _stroking:
		return
	_brush = Vector2(center.x, center.z)
	_brush_radius = radius
	_spent += amount
	_bounds_min = _bounds_min.min(_brush)
	_bounds_max = _bounds_max.max(_brush)
	var newest := _waves[_newest] if _newest >= 0 else Vector4.ZERO
	if _wave and (newest.z <= 0.0 or _brush.distance_to(Vector2(newest.x, newest.y)) > radius * WAVE_SPACING):
		_drop_wave()

func _on_stroke_finished(_center: Vector3, _radius: float, _mode_name: String) -> void:
	_stroking = false

## One light puff over the trees whose birth has come, at their middle.
func _puff_arrivals() -> void:
	var now: float = preload("res://scripts/emergence.gd").time
	var waiting := PackedVector3Array()
	var sum := Vector2.ZERO
	var count := 0
	for tree in _arriving:
		if tree.z <= now:
			sum += Vector2(tree.x, tree.y)
			count += 1
		else:
			waiting.append(tree)
	if count == 0:
		return
	_arriving = waiting
	_arrival_wait = ARRIVAL_GAP
	var middle := sum / float(count)
	var ground: Variant = _editor.data.ground_height(middle)
	var at: Vector3 = _editor.terrain.global_transform * Vector3(middle.x, float(ground) if ground != null else 0.0, middle.y)
	_atmosphere.send_gust(at, ARRIVAL_PUFF)

func _drop_wave() -> void:
	# Reuse an idle slot, else the one furthest along (usually already grown).
	var pick := 0
	for i in range(WAVE_SLOTS):
		if _waves[i].z <= 0.0:
			pick = i
			break
		if _waves[i].w > _waves[pick].w:
			pick = i
	_waves[pick] = Vector4(_brush.x, _brush.y, _brush_radius * WAVE_REACH, -1.0)
	_newest = pick
	RenderingServer.global_shader_parameter_set(WAVE_GLOBALS[pick], _waves[pick])

func _process(delta: float) -> void:
	if _scene == null or delta <= 0.0:
		return
	var paused: bool = _scene._paused
	if not _stroking:
		_after += delta
	var live := _stroking or _after < SWELL_HOLD
	_rate = lerpf(_rate, _spent / delta, 1.0 - exp(-delta * RATE_RESPONSE))
	_spent = 0.0
	if not _stroking:
		_rate = 0.0

	# Tremor: hold a rumble proportional to rise speed, in small kicks.
	if _stroking and _rumble > 0.0 and not paused:
		var target: float = RUMBLE_MAX * _rumble * clampf(_rate / RUMBLE_FULL_RATE, 0.0, 1.0)
		if _tremor.trauma < target:
			_tremor.add(minf(RUMBLE_KICK, target - _tremor.trauma))

	# Wind: swell up while painting, settle after.
	var swell_target := _swell_goal if live else 0.0
	var response := SWELL_RISE if swell_target > _swell else SWELL_FALL
	_swell = lerpf(_swell, swell_target, 1.0 - exp(-delta * response))
	if _swell < 0.001 and swell_target == 0.0:
		_swell = 0.0
	_atmosphere.swell = _swell
	if _stroking and _gust_interval > 0.0 and not paused:
		_gust_timer -= delta
		if _gust_timer <= 0.0:
			_gust_timer = _gust_interval
			_atmosphere.send_gust(Vector3(_brush.x, 0.0, _brush.y))
	_arrival_wait -= delta
	if not _arriving.is_empty() and _arrival_wait <= 0.0 and not paused:
		_puff_arrivals()

	# Fog: part over the stroke's bounds, hold, then close slowly.
	var revealing := _reveal and (_stroking or _after < REVEAL_HOLD)
	if revealing:
		var goal_center := (_bounds_min + _bounds_max) * 0.5
		var goal_radius := clampf(_bounds_min.distance_to(_bounds_max) * 0.5 + _brush_radius * REVEAL_MARGIN, REVEAL_MIN_RADIUS, REVEAL_MAX_RADIUS)
		var follow := 1.0 - exp(-delta * REVEAL_FOLLOW)
		_reveal_center = _reveal_center.lerp(goal_center, follow)
		_reveal_radius = lerpf(_reveal_radius, goal_radius, follow)
	var reveal_target := REVEAL_STRENGTH if revealing else 0.0
	_reveal_strength = lerpf(_reveal_strength, reveal_target, 1.0 - exp(-delta * (REVEAL_RISE if revealing else REVEAL_FALL)))
	if not revealing and _reveal_strength < 0.005:
		_reveal_strength = 0.0
	if _reveal_strength > 0.0 or not _reveal_published:
		RenderingServer.global_shader_parameter_set(&"zs_reveal", Vector4(_reveal_center.x, _reveal_center.y, _reveal_radius, _reveal_strength))
		_reveal_published = _reveal_strength == 0.0

	# Growth: shrink (-1..0), grow (0..1), then wait at 1. Done waves stay
	# published until every wave is grown, so an overlapping younger wave never
	# drags an already-grown plant back down; then all retire together.
	var waiting := true
	for i in range(WAVE_SLOTS):
		var wave := _waves[i]
		if wave.z <= 0.0 or wave.w >= 1.0:
			continue
		wave.w = minf(1.0, wave.w + delta / (WAVE_SHRINK_SECONDS if wave.w < 0.0 else WAVE_SECONDS))
		_waves[i] = wave
		RenderingServer.global_shader_parameter_set(WAVE_GLOBALS[i], wave)
		waiting = false
	if waiting and not _stroking and _newest >= 0:
		_newest = -1
		for i in range(WAVE_SLOTS):
			if _waves[i].z > 0.0:
				_waves[i] = Vector4(0.0, 0.0, 0.0, 1.0)
				RenderingServer.global_shader_parameter_set(WAVE_GLOBALS[i], _waves[i])
