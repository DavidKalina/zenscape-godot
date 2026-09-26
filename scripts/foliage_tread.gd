extends Node
## Where the walker is and where he has just been, for the low foliage shaders.
##
## `reference_surface.gdshader`'s sway branch parts flowers, bank grass, reeds
## and mushrooms around every TREAD published here (`shaders/foliage_tread.gdshaderinc`):
## stems push radially away from a tread's centre and lie over, so from above
## the walker sits in a hole in the meadow and a trough of pressed stems trails
## behind him. Same shape as `local_wind_field.gd` publishing its gusts: a small
## fixed ring of shader globals, `zs_tread_0..7`, each `(x, z, radius, strength)`.
##
## Slot 0 is the walker HIMSELF, restated every tick, so the ring round him is
## exact however fast he moves. Slots 1..7 are the wake: a record is laid each
## `SPACING` metres of his walk and fades over `WAKE_SECONDS`. The decay runs
## here rather than on a shader clock -- the study's motion clock keeps running
## while the world is held, and a wake that fades through a pause would be
## wrong -- so each tick republishes the ring with the strengths already aged.
## Two additional vec4s carry the smoother tree contribution envelopes.
##
## No class_name: this is a stitched-world script, reached by preload.

const CAPACITY := 8
## Metres of walk between two wake records. Under the wake radius, so the
## trough is continuous and not a row of dimples.
const SPACING := 0.6
## How long a pressed patch stays pressed. At his walking pace this is three
## and a half metres of trough behind him, which is what the ring holds.
const WAKE_SECONDS := 5.0
## Reach of the parting round the walker himself, and of one wake record. The
## live ring is wider than his stride so the stems part BEFORE his foot lands;
## the wake is nearly as wide, because the shader's falloff presses only the
## inner half of a record flat and the trough has to read from twenty metres.
const LIVE_RADIUS := 1.2
const WAKE_RADIUS := 1.0
## A new wake record opens at this strength, and the live ring stands at 1.
const WAKE_STRENGTH := 0.85

## Newest first: `[{x, z, age}]`, at most CAPACITY-1 entries.
var _wake: Array[Dictionary] = []
var _live := Vector4.ZERO
var _last := Vector2(INF, INF)
var _published := false

## One tick of the walker's own time. `position` is his world position or null
## when there is nobody on the map; `paused` holds the wake where it is.
func tick(position: Variant, delta: float, paused := false) -> void:
	if position == null or not (position as Vector3).is_finite():
		if _live.w > 0.0 or not _wake.is_empty(): clear()
		return
	var here := Vector2((position as Vector3).x, (position as Vector3).z)
	if not paused and is_finite(delta) and delta > 0.0:
		for i in range(_wake.size()-1, -1, -1):
			_wake[i].age += delta
			if _wake[i].age >= WAKE_SECONDS: _wake.remove_at(i)
		if _last.x == INF or here.distance_to(_last) >= SPACING:
			_lay(here)
	_live = Vector4(here.x, here.y, LIVE_RADIUS, 1.0)
	publish()

func _lay(at: Vector2) -> void:
	_last = at
	_wake.push_front({"x": at.x, "z": at.y, "age": 0.0})
	if _wake.size() > CAPACITY-1: _wake.resize(CAPACITY-1)

## Strength of a wake record at `age`: full for the first fraction of its life,
## then a smooth fade to nothing, so a stem does not spring straight back up
## the instant the foot lifts.
static func fade(age: float) -> float:
	return WAKE_STRENGTH*(1.0-smoothstep(0.25, 1.0, clampf(age/WAKE_SECONDS, 0.0, 1.0)))

## The ring as the shader sees it: CAPACITY vec4s, slot 0 the walker, the rest
## the wake newest first, zeros after the last live record.
func records() -> Array[Vector4]:
	var out: Array[Vector4] = []
	out.append(_live)
	for record: Dictionary in _wake:
		out.append(Vector4(float(record.x), float(record.z), WAKE_RADIUS, fade(float(record.age))))
	while out.size() < CAPACITY: out.append(Vector4.ZERO)
	return out

func publish() -> void:
	_published = true
	var ring := records()
	for i in CAPACITY:
		RenderingServer.global_shader_parameter_set("zs_tread_%d" % i, ring[i])
	var weights := tree_weights()
	RenderingServer.global_shader_parameter_set("zs_tree_tread_weights_0",Vector4(weights[0],weights[1],weights[2],weights[3]))
	RenderingServer.global_shader_parameter_set("zs_tree_tread_weights_1",Vector4(weights[4],weights[5],weights[6],weights[7]))

## Trees need continuous forces, not the meadow's immediate footprint stamps.
## Fade samples in, and fade the tail before a full ring evicts its oldest slot.
func tree_weights() -> Array[float]:
	var weights: Array[float] = [1.0 if _live.w>0.0 else 0.0]
	var progress := 0.0 if _last.x == INF else clampf(Vector2(_live.x,_live.y).distance_to(_last)/SPACING,0.0,1.0)
	for i in range(_wake.size()):
		var born := smoothstep(0.0,0.5,float(_wake[i].age))
		var tail := 1.0-smoothstep(5.0,7.0,float(i+1)+progress)
		weights.append(born*tail)
	while weights.size()<CAPACITY: weights.append(0.0)
	return weights

func clear() -> void:
	_wake.clear()
	_live = Vector4.ZERO
	_last = Vector2(INF, INF)
	publish()

func _exit_tree() -> void:
	if _published: clear()
