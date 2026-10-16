extends Node3D
## The layer's flyers (feature `flyer`, docs/design/roguelike/flyer-round1.md):
## the guacharos (scripts/enemies/guacharo.gd) laid over a generated layer's
## gulfs and stepped round the motor by scripts/roguelike/layer_stage.gd
## (its `# [flyer]` hooks). Cut from the run (run-trim-round1.md): off
## unless `--flyer` (or `--flyers=N`, or a plan with its own `flyers`, the
## flyer yard's); `--loot=off` turns it off.
##
## Laying (`lay`, data only): a layer with a gulf, or MANY_EDGES crossings or
## more, gets one; a second from DANGER_TWO of the danger (LayerWorlds
## `danger`). `--flyers=N` pins the count (0 none). Home is over the widest
## gulf (else the longest crossing), HOME_UP over its lips; a second over
## the crossing furthest from the first. A plan's own `flyers` list ([{home,
## grace, range}]: the flyer yard's) is taken as it is.
##
## They hunt him (`hunting`) once the layer's GRACE is out and he is within
## RANGE of a home or NEAR_EDGE of a crossing's lip; one dives at a time
## (`may_stalk`, `stalker`), one carries him at a time (`carrier`).
## Knobs: `--flyer-<knob>=<value>` overrides one of Guacharo KNOBS (e.g.
## `--flyer-fold=0.8`, `--flyer-snatch=0`).
const Guacharo = preload("res://scripts/enemies/guacharo.gd")
const RunFeatures = preload("res://scripts/roguelike/run_features.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

const MANY_EDGES := 5
const DANGER_TWO := 0.6
const HOME_UP := 26.0
const GRACE := 12.0
const RANGE := 140.0
const NEAR_EDGE := 55.0
## A second's home at least this far (m, flat) from the first.
const APART := 60.0

var study: Node3D
var motor: Variant
var field: Node
var unit := 1.12
var birds: Array = []
var stalker: Node = null
var carrier: Node = null
var grace := GRACE
var range_m := RANGE
var zones: Array = []
var _clock := 0.0
var _cam_fwd := Vector3.FORWARD

## The flyers laid for `plan`: [{home, grace}].
static func lay(plan: Dictionary) -> Array:
	if "--loot=off" in OS.get_cmdline_user_args(): return []
	if plan.has("flyers"): return plan.flyers
	if not RunFeatures.opted(&"flyer") and RunFeatures.value("flyers","") == "": return []
	var edges: Array = plan.get("edges",[])
	if edges.is_empty(): return []
	var gulfs: Array = plan.get("gulfs",[])
	var n := 0
	if not gulfs.is_empty() or edges.size() >= MANY_EDGES: n = 1
	if n > 0 and LayerPlan.LayerWorlds.danger(plan.get("knobs",{})) >= DANGER_TWO: n = 2
	var pinned := RunFeatures.value("flyers","")
	if pinned != "": n = int(pinned)
	if n <= 0: return []
	# The widest gulf first, then the longest crossings.
	var order: Array = []
	for i in range(edges.size()):
		var e: Dictionary = edges[i]
		var a: Vector3 = e.a
		var b: Vector3 = e.b
		var w := Vector2(a.x-b.x,a.z-b.z).length()+(1000.0 if str(e.kind) == "gulf" else 0.0)
		order.append([w,(a+b)*0.5+Vector3.UP*HOME_UP])
	order.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) > float(y[0]))
	var out: Array = []
	for o: Array in order:
		if out.size() >= n: break
		var at: Vector3 = o[1]
		var far := true
		for f: Dictionary in out:
			if Vector2(at.x-(f.home as Vector3).x,at.z-(f.home as Vector3).z).length() < APART: far = false
		if far: out.append({"home":at,"grace":GRACE})
	return out

## The flyers of `layer` stood on `stage` (a LayerStage), or null.
static func dress(stage: Node3D, layer: Dictionary) -> Node3D:
	var laid := lay(layer)
	if laid.is_empty() or stage.get("enemies") == null: return null
	var node: Node3D = new()
	node.name = "LayerFlyers"
	stage.add_child(node)
	node.setup(stage,layer,laid)
	return node

func setup(stage: Node3D, layer: Dictionary, laid: Array) -> void:
	study = stage.study
	motor = study.motor
	field = stage.enemies
	unit = float(study.ground.head_top)
	var over := {}
	for a: String in LaunchArgs.user_args():
		if not a.begins_with("--flyer-"): continue
		var k := a.trim_prefix("--flyer-").get_slice("=",0)
		if Guacharo.KNOBS.has(k): over[k] = float(a.get_slice("=",1))
	for e: Dictionary in layer.get("edges",[]):
		zones.append(e.a)
		zones.append(e.b)
	var i := 0
	# A laid `range` is taken as it is (the widest of them); RANGE only
	# where none gives one.
	var given := laid.filter(func(f: Dictionary) -> bool: return f.has("range"))
	if not given.is_empty(): range_m = 0.0
	for f: Dictionary in laid:
		grace = minf(grace,float(f.get("grace",GRACE)))
		range_m = maxf(range_m,float(f.get("range",RANGE)))
		# A laid flyer's own `knobs` (a place's tuning) under the flags'.
		var mine: Dictionary = over.duplicate()
		mine.merge(f.get("knobs",{}),false)
		var bird = Guacharo.new()
		add_child(bird)
		bird.setup(self,f.home,int(layer.get("seed",0))*31+i,mine)
		bird.beat.connect(_beat.bind(bird))
		birds.append(bird)
		i += 1
	print("layer flyers: %d guácharo%s over %s" % [birds.size(),"" if birds.size() == 1 else "s",", ".join(PackedStringArray(laid.map(func(f: Dictionary) -> String: return "%.0f,%.0f,%.0f" % [f.home.x,f.home.y,f.home.z])))])

## Whether the birds hunt him now.
func hunting() -> bool:
	if _clock < grace: return false
	var feet: Vector3 = motor.feet
	for b in birds:
		if Vector2(feet.x-b.home.x,feet.z-b.home.z).length() < range_m: return true
	for z: Vector3 in zones:
		if Vector2(feet.x-z.x,feet.z-z.z).length() < NEAR_EDGE: return true
	return false

func may_stalk(bird: Node) -> bool:
	return (stalker == null or stalker == bird or not is_instance_valid(stalker)) and carrier == null

func before(delta: float) -> void:
	_clock += delta
	for b in birds: b.step(delta,_cam_fwd)

func after(delta: float, _events: Dictionary) -> void:
	for b in birds: b.after_step(delta)

func frame(camera: Camera3D, _delta: float) -> void:
	if camera != null: _cam_fwd = -camera.global_basis.z

func reset() -> void:
	stalker = null
	carrier = null
	for b in birds: b.reset()

func _exit_tree() -> void:
	# Never leave him held.
	if carrier != null and motor != null and motor.seized(): motor.knock(Vector3.ZERO,carrier)

## Its beats, for the log (`--flyer-log`) and the drivers.
var log_on := "--flyer-log" in LaunchArgs.user_args() or "--flyer-log" in OS.get_cmdline_user_args()
var beats: Array = []
func _beat(what: String, bird: Variant) -> void:
	beats.append([_clock,what])
	if log_on and not what.begins_with("sound click"): print("flyer %.2f %s: %s (exposure %s %.2f, hunger %.2f)" % [_clock,bird.name,what,bird.exposure_kind,bird.exposure,bird.hunger])
