extends Node3D
## One islet unit (scripts/kit_isle/islet_unit.gd) standing as a node with
## the layout contract (scripts/layout_overrides.gd), so a placer names it
## (`<route>/<piece>`) and the world view moves it and tunes its knobs
## (each knob a tune; a changed one builds the unit again under the same
## node, so its name, place and undo stay). Its origin is its turf's middle.

var spec := {}
var unit: Node3D = null
## A slow drift (round 3's loose chunks): the unit bobs this many metres
## and turns about its own up, the node itself (its layout pose) still.
var drift := 0.0
var _phase := 0.0
var _yaw_rate := 0.0

func set_drift(metres: float, seed_value: int) -> void:
	drift = metres
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(["islet_drift",seed_value])
	_phase = rng.randf()*TAU
	_yaw_rate = rng.randf_range(0.015,0.05)*(1.0 if rng.randf() < 0.5 else -1.0)
	set_process(drift > 0.0)

func _process(_dt: float) -> void:
	if unit == null or drift <= 0.0: return
	var t := Time.get_ticks_msec()/1000.0
	unit.position = Vector3(0.0,sin(t*0.45+_phase)*drift,0.0)
	unit.rotation = Vector3(0.0,t*_yaw_rate+_phase,0.0)

func _ready() -> void:
	set_process(drift > 0.0)

func setup(t: Transform3D, a_spec: Dictionary) -> void:
	transform = t
	spec = IsletUnit.knobs_of(a_spec)
	_build()

func _build() -> void:
	if unit != null:
		remove_child(unit)
		unit.queue_free()
	unit = IsletUnit.build(spec)
	add_child(unit)

## Its turf's bodies (for a scene's turf list).
func turf_bodies() -> Array:
	return [unit.get_node("Body")]

## Its outline in the world (x, z).
func world_outline() -> Array:
	var out: Array = []
	for p: Vector2 in unit.get_meta("outline"):
		var w := global_transform*Vector3(p.x,0.0,p.y)
		out.append(Vector2(w.x,w.z))
	return out

# --- The layout contract ------------------------------------------------------------------

func layout_pose() -> Transform3D:
	return transform

func layout_place(t: Transform3D) -> void:
	transform = t

func layout_mid() -> Vector3:
	return global_position

func layout_reach() -> float:
	return float(spec.size)

func layout_tunes() -> Array:
	var out: Array = [["seed","seed (shape)",1,1,999,1],["style","style (0 round 2, 1 crag)",IsletUnit.CRAG,0,1,1]]
	for k: String in IsletUnit.KNOBS:
		var r: Array = IsletUnit.KNOBS[k]
		var label := "shape (slab, boulder, cone, cluster, spire)" if k == "shape" else k
		out.append([k,label,r[0],r[1],r[2],0.25 if k == "size" else 0.05])
	out.append(["landmark","landmark (-1 drawn, 0 none, 1 tree, 2 ruin)",-1,-1,2,1])
	out.append(["debris","debris",1.0,0.0,2.0,0.1])
	return out

func layout_tune(key: String) -> float:
	return float(spec.get(key,0.0))

func layout_retune(key: String, v: float) -> void:
	var was: float = float(spec.get(key,0.0))
	if key == "seed": spec.seed = clampi(int(round(v)),1,999)
	elif key in ["style","landmark"]: spec = IsletUnit.knobs_of(spec.merged({key:int(round(v))},true))
	else: spec = IsletUnit.knobs_of(spec.merged({key:v},true))
	if is_equal_approx(was,float(spec.get(key,0.0))): return
	_build()
