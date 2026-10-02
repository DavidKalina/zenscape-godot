extends SceneTree
## Headless probe of how the live water is drawn (ZenScapeWaterFlow::surface
## and its GDScript mirror; docs/scenic/water-flow.md "Glide"). On a flat
## 16 × 16 test grid, for the native kernel (when built) and the mirror:
##   1. without the new params the surface is the sim's, as before;
##   2. with `ease` the drawn depth follows the sim's over several builds,
##      reports `settled` only once caught up, and a load is drawn at once;
##   3. with `emerge` a cell only just wet stands under the ground while deep
##      water stands at its full height;
##   4. with `wet_off` a cell drawn wet stays drawn as it thins, while the same
##      depth on a cell not yet drawn stays dry.
##   godot --headless --path . -s res://tools/probe_water_glide.gd
var failures := []
const Mirror := preload("res://scripts/water_flow_reference.gd")
const N := 16
const CELL := 0.25
const LIFT := 0.012
## The cell checks look at: (8, 8), well inside the draining edge ring.
const AT := 8*N+8

func _initialize() -> void: run.call_deferred()

func check(label: String, ok: bool, detail: Variant = "") -> void:
	if not ok: failures.append(label)
	print(("OK   " if ok else "FAIL ")+label+("" if str(detail).is_empty() else "  "+str(detail)))

## A kernel over flat ground at height 0.
func flat(kernel: RefCounted) -> RefCounted:
	var faces := PackedInt32Array()
	var weights := PackedFloat32Array()
	for c in range(N*N):
		faces.append_array([0,1,2])
		weights.append_array([1.0/3.0,1.0/3.0])
	kernel.configure(N,N,CELL,Vector2(-N*CELL*0.5,-N*CELL*0.5),faces,weights)
	kernel.step(PackedFloat32Array([0.0,0.0,0.0]),PackedFloat32Array(),0,1.0/60.0)
	return kernel

static func depths(value_at: Dictionary) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(N*N)
	for c in value_at: out[c] = value_at[c]
	return out

## The drawn height of cell `c`'s vertex in the still mesh, or NAN if undrawn.
static func drawn(arrays: Dictionary, c: int) -> float:
	var x := -N*CELL*0.5+(c%N+0.5)*CELL
	var z := -N*CELL*0.5+(c/N+0.5)*CELL
	for v: Vector3 in arrays.still.vertices:
		if absf(v.x-x) < 0.001 and absf(v.z-z) < 0.001: return v.y
	return NAN

func probe(name: String, make: Callable) -> void:
	print("-- ",name)
	# 1. Defaults draw the sim as it is.
	var k: RefCounted = flat(make.call())
	k.set_depth(depths({AT:0.3}))
	var raw: Dictionary = k.surface({"lift":LIFT})
	check(name+": without the new params a pond stands at its depth",is_equal_approx(drawn(raw,AT),0.3+LIFT),drawn(raw,AT))
	check(name+": and is settled",raw.get("settled",false))
	# 2. Easing.
	k = flat(make.call())
	k.add_water(Vector2.ZERO,0.6,0.2)
	var sim: float = k.get_depth()[AT]
	var first: Dictionary = k.surface({"lift":LIFT,"ease":0.25,"ease_flow":0.25})
	var shown := drawn(first,AT)-LIFT
	check(name+": an eased build draws a quarter of new water",absf(shown-sim*0.25) < 0.002,[shown,sim])
	check(name+": and is not settled",not first.settled)
	var builds := 1
	var last := first
	while not last.settled and builds < 200:
		last = k.surface({"lift":LIFT,"ease":0.25,"ease_flow":0.25})
		builds += 1
	check(name+": it catches up and settles",last.settled and absf(drawn(last,AT)-LIFT-sim) < 0.001,[builds,drawn(last,AT)-LIFT,sim])
	k.set_depth(depths({AT:0.5}))
	var loaded := drawn(k.surface({"lift":LIFT,"ease":0.25}),AT)-LIFT
	check(name+": a load is drawn at once, not eased",is_equal_approx(loaded,0.5),loaded)
	# 3. Emerge.
	var soft := {"lift":LIFT,"wet":0.012,"wet_off":0.006,"emerge":0.015}
	k = flat(make.call())
	k.set_depth(depths({AT:0.0121,AT+4:0.3}))
	var rising: Dictionary = k.surface(soft)
	check(name+": a cell only just wet stands under the ground",drawn(rising,AT) < 0.0,drawn(rising,AT))
	check(name+": deep water stands at full height",is_equal_approx(drawn(rising,AT+4),0.3+LIFT),drawn(rising,AT+4))
	# 4. wet_off.
	k.set_depth(depths({AT:0.009}))
	check(name+": a drawn cell stays drawn as it thins past wet",not is_nan(drawn(k.surface(soft),AT)))
	k = flat(make.call())
	k.set_depth(depths({AT:0.009}))
	check(name+": the same depth on a dry cell is not drawn",is_nan(drawn(k.surface(soft),AT)))

func run() -> void:
	if ClassDB.class_exists("ZenScapeWaterFlow"): probe("native",func() -> RefCounted: return ClassDB.instantiate("ZenScapeWaterFlow"))
	else: check("native kernel is built",false)
	probe("mirror",func() -> RefCounted: return Mirror.new())
	print("RESULT ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	quit(0 if failures.is_empty() else 1)
