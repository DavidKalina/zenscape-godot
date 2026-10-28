extends RefCounted
## Lays a bridge's run (scripts/endless/bridge_plan.gd) from the ruin kit's
## aqueduct pieces (scripts/ruin_kit_aqueduct.gd), in the run's frame as
## `Aqueduct.run` lays one: `count` spans SPAN apart along +X from x 0, each
## pier grown down to `ground` (Callable(x, z) -> y, the run's frame), merged
## into one mesh and one body. arch_build.gd grows it and gives its solid.
##   whole        single spans, each standing its right pier (the first its
##                left too).
##   tier         two-tier spans (`Aqueduct.two_tier`).
##   broken       the A half `cut` spans from x 0, its last snapped off over a
##                stump; `miss` spans fallen; the B half the rest, laid from
##                the far end back toward the middle (turned half round), its
##                last snapped off too, so both halves end in mid-air facing
##                each other over the gap.
##   road         (bridge.style "road", bridge_plan.gd `_road_spec`) a great
##                road bridge, scripts/ruin_kit_bridge.gd, the run's length.

const Aqueduct = preload("res://scripts/ruin_kit_aqueduct.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const Road = preload("res://scripts/ruin_kit_bridge.gd")

static func piece(spec: Dictionary, ground: Callable) -> Node3D:
	var b: Dictionary = spec.bridge
	# The road form: one piece, the run's length, at grow 1.
	if str(b.get("style","")) == "road":
		return Road.piece(int(spec.seed),float(spec.weathered),float(spec.length),float(b.gap),float(spec.drop),bool(b.broken),ground)
	var seed_value := int(spec.seed)
	var weathered := float(spec.weathered)
	var count := int(spec.count)
	var wet := bool(b.wet)
	var tier := bool(b.tier)
	var cut := int(b.cut)
	var miss := int(b.miss)
	var root := Node3D.new()
	root.name = "BridgeRun"
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed_value,"bridge run"])
	var shift := func(dx: float) -> Callable:
		return func(x: float, z: float) -> float: return float(ground.call(x+dx,z))
	# A piece turned half round about its middle at dx: its (x, z) is the
	# run's (dx-x, -z).
	var mirror := func(dx: float) -> Callable:
		return func(x: float, z: float) -> float: return float(ground.call(dx-x,-z))
	var span: float = Aqueduct.SPAN
	for i in range(count):
		var w := clampf(weathered+rng.randf_range(-0.15,0.15),0.0,1.0)
		var x := span*(0.5+i)
		var node: Node3D
		if cut < 0:
			var piers := 2|(1 if i == 0 else 0)
			if tier: node = Aqueduct.two_tier(seed_value+i,w,piers,wet,shift.call(x))
			else: node = Aqueduct.span(seed_value+i,w,piers,wet,shift.call(x))
			node.position = Vector3(x,0.0,0.0)
		elif i < cut:
			# The A half, out from x 0.
			if i == cut-1: node = Aqueduct.broken(seed_value+i,w,i == 0,"stump",wet,shift.call(x))
			else: node = Aqueduct.span(seed_value+i,w,2|(1 if i == 0 else 0),wet,shift.call(x))
			node.position = Vector3(x,0.0,0.0)
		elif i < cut+miss:
			continue
		else:
			# The B half, turned: each span stands its pier toward the gap
			# (the far end's both).
			var j := i
			var first := j == count-1
			if j == cut+miss: node = Aqueduct.broken(seed_value+j,w,first,"none" if miss == 0 else "stump",wet,mirror.call(x))
			else: node = Aqueduct.span(seed_value+j,w,2|(1 if first else 0),wet,mirror.call(x))
			node.transform = Transform3D(Basis(Vector3.UP,PI),Vector3(x,0.0,0.0))
		root.add_child(node)
	RuinKit.merge(root)
	return root

## The land under a run in its frame (as arch_build.gd places it: its middle
## at spec.pos, turned by its yaw): Callable(x, z) -> y over the deck.
static func run_ground(spec: Dictionary, field: RefCounted) -> Callable:
	var shift := -float(Aqueduct.SPAN)*int(spec.count)*0.5
	var pos: Vector3 = spec.pos
	var basis := Basis(Vector3.UP,float(spec.yaw))
	return func(x: float, z: float) -> float:
		var w := pos+basis*Vector3(x+shift,0.0,z)
		return float(field.height(w.x,w.z))-pos.y

## A road bridge the land breaks through (over its road's top, past its
## ramps and cuttings: Road.through): the placer leaves it out.
static func road_through(spec: Dictionary, field: RefCounted) -> bool:
	var b: Dictionary = spec.bridge
	# A coarse look first; one near the line is read in full.
	var ground := run_ground(spec,field)
	var p := Road.plan(int(spec.seed),float(spec.weathered),float(spec.length),float(b.gap),float(spec.drop),bool(b.broken),ground,true)
	var most := Road.through(p)
	if most > 0.3 or most < -2.0: return most > 0.3
	p = Road.plan(int(spec.seed),float(spec.weathered),float(spec.length),float(b.gap),float(spec.drop),bool(b.broken),ground)
	return Road.through(p) > 0.3

## A road bridge's flown openings in the world (Road.openings, placed as
## arch_build.gd places the run: its middle at spec.pos, turned by its yaw).
static func road_openings(spec: Dictionary, field: RefCounted) -> Array:
	var shift := -float(Aqueduct.SPAN)*int(spec.count)*0.5
	var place := Transform3D(Basis(Vector3.UP,float(spec.yaw)),spec.pos)*Transform3D(Basis.IDENTITY,Vector3(shift,0.0,0.0))
	var ground := run_ground(spec,field)
	var b: Dictionary = spec.bridge
	var p := Road.full_plan(int(spec.seed),float(spec.weathered),float(spec.length),float(b.gap),float(spec.drop),bool(b.broken),ground)
	var out: Array = []
	for o: Dictionary in Road.openings(p):
		var w := o.duplicate()
		w["frame"] = place*(o.frame as Transform3D)
		out.append(w)
	return out
