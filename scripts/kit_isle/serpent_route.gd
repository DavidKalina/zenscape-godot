extends Node3D
## The rune serpent's route between isles (docs/design/serpent-route.md):
## the plane-free way round region one. The serpent (scripts/rune_serpent.gd)
## flies a fixed, learnable loop (ROUTE) linking the aqueduct isle and three
## of its motif isles, and at each it passes low and close beside a boarding
## ledge (SPOTS) built from the ruin kit: a worn flight of steps climbing
## from the isle's turf out over its rim to a walled landing that juts into
## the sky, its end a short jump from the serpent's back as it goes by.
## Riding it is scripts/kit_isle/serpent_rider.gd's.
##
## The loop, east-about from the aqueduct isle (about 2 km, some three
## minutes a lap): east along the aqueduct isle's south rim, past its ledge
## at the south tip ("home"); out south-east and down in a long dip toward
## the cloud sea and up again ("dip"); south past the cloister tarn's east
## rim and its ledge ("tarn"); west under the tarn and across to the
## drowned nave, past its south tip and its ledge ("nave"); north up the
## nave's west side to the Sundered gorge's south mouth, past the ledge on
## its west lip ("gorge"), and up into the gorge to thread its length over
## the rope bridge and between the halves' rims as the old way did; out of
## the north mouth and east home. By each ledge it runs straight and level,
## its slither held in (weave share 0.1), at three quarters of its pace,
## and its head kept to its way (`look_share`), so it passes the same every
## lap and its head never swings into the ledge.
##
## Each ledge is laid off the serpent's own way: its end LEDGE_GAP m off its
## widest flank (head included) at its slither's most there, its top
## LEDGE_DROP m under its back's crest, the flight's foot fitted to
## the turf under it (rays, once its isle stands: a motif isle's ledge is
## built when the isle is up). So the pass is the same jump at every ledge.
##
## Flags (the game's, after --):
##   --serpent-old-route        the serpent's old long way, no ledges, no riding
##   --serpent-board=<isle>     start on foot at that isle's ledge, the
##                              serpent's head BOARD_LEAD m off: home
##                              (or aqueduct), tarn, nave, gorge
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const RuinKit = preload("res://scripts/ruin_kit.gd")
const SerpentRider = preload("res://scripts/kit_isle/serpent_rider.gd")
const LaunchArgs = preload("res://scripts/launch_args.gd")

## The way round (world): a closed cubic B-spline through these control
## points, each [point, weave share, pace share, veer share] (as
## rune_serpent.gd's ROUTE). Four or more control points in a line run it
## straight by each ledge.
const ROUTE := [
	# Home: east along the aqueduct isle's south rim, past its south tip.
	[Vector3(-30.0,29.0,36.0),0.5,0.85,0.0],
	[Vector3(13.0,28.0,33.0),0.1,0.75,0.0],
	[Vector3(38.0,28.0,33.0),0.1,0.75,0.0],
	[Vector3(63.0,28.0,33.0),0.1,0.75,0.0],
	[Vector3(88.0,28.0,33.0),0.1,0.75,0.0],
	[Vector3(113.0,28.0,33.0),0.2,0.8,0.0],
	# Out south-east, the dip toward the cloud sea and up again.
	[Vector3(152.0,28.0,52.0),0.7,0.95,0.3],
	[Vector3(174.0,20.0,100.0),1.0,1.0,0.5],
	[Vector3(180.0,2.0,150.0),1.0,1.0,0.5],
	[Vector3(168.0,-14.0,200.0),1.0,1.0,0.5],
	[Vector3(144.0,-10.0,248.0),1.0,1.0,0.5],
	[Vector3(122.0,10.0,288.0),0.8,1.0,0.3],
	[Vector3(108.0,27.0,318.0),0.4,0.9,0.0],
	# The cloister tarn: south past its east rim.
	[Vector3(103.0,31.2,342.0),0.1,0.75,0.0],
	[Vector3(103.0,31.2,358.0),0.1,0.75,0.0],
	[Vector3(103.0,31.2,374.0),0.1,0.75,0.0],
	[Vector3(103.0,31.2,390.0),0.1,0.75,0.0],
	[Vector3(98.0,29.0,425.0),0.4,0.85,0.0],
	# West under the tarn and across to the drowned nave.
	[Vector3(55.0,31.0,442.0),0.9,1.0,0.3],
	[Vector3(-25.0,33.0,446.0),1.0,1.0,0.5],
	[Vector3(-110.0,32.0,432.0),1.0,1.0,0.5],
	[Vector3(-160.0,29.0,410.0),0.5,0.9,0.0],
	# The drowned nave: west past its south tip.
	[Vector3(-191.0,28.0,405.5),0.1,0.75,0.0],
	[Vector3(-211.0,28.0,405.5),0.1,0.75,0.0],
	[Vector3(-231.0,28.0,405.5),0.1,0.75,0.0],
	[Vector3(-251.0,28.0,405.5),0.1,0.75,0.0],
	[Vector3(-285.0,30.0,398.0),0.4,0.9,0.0],
	# North up the nave's west side to the Sundered gorge.
	[Vector3(-318.0,32.0,345.0),0.9,1.0,0.3],
	[Vector3(-326.0,34.0,270.0),1.0,1.0,0.3],
	[Vector3(-323.0,35.0,200.0),0.6,0.9,0.0],
	# Its south mouth: up its west lip, past the ledge.
	[Vector3(-318.0,37.0,146.5),0.1,0.75,0.0],
	[Vector3(-312.3,37.0,132.7),0.1,0.75,0.0],
	[Vector3(-306.6,37.0,118.9),0.1,0.75,0.0],
	[Vector3(-300.9,37.0,105.1),0.1,0.75,0.0],
	# Up over the rope bridge and down the gorge's length between the rims.
	[Vector3(-296.5,45.0,91.0),0.2,0.85,0.0],
	[Vector3(-298.0,47.0,72.0),0.3,0.9,0.0],
	[Vector3(-299.0,48.0,45.0),0.3,0.9,0.0],
	[Vector3(-299.0,48.0,20.0),0.3,0.9,0.0],
	[Vector3(-297.0,47.0,-15.0),0.5,0.95,0.0],
	# Out of the north mouth and east home.
	[Vector3(-235.0,42.0,-5.0),0.9,1.0,0.4],
	[Vector3(-150.0,36.0,25.0),1.0,1.0,0.4],
	[Vector3(-80.0,31.0,40.0),0.8,1.0,0.2],
]
## Places on the way, by control point (--serpent-at=<name>).
const MARKS := {"home":3,"dip":9,"tarn":15,"nave":24,"gorge":32,"thread":36}
## Where it starts (a mark).
const START := "dip"
## The boarding ledges: [id, the isle it stands on (the aqueduct isle's
## "aqueduct", else a motif's id), the mark it stands by, the flags' names
## for it].
const SPOTS := [
	["home","aqueduct","home",["home","aqueduct"]],
	["tarn","cloister_tarn","tarn",["tarn","cloister_tarn"]],
	["nave","drowned_nave","nave",["nave","drowned_nave"]],
	["gorge","sundered_gorge","gorge",["gorge","sundered_gorge"]],
]
## Its girth while it carries riders (rune_serpent.gd's times this): the
## serpent ride's (studies/serpent_ride.gd GIRTH), 6 m through, its back's
## flat top about 2 m across.
const GIRTH := 1.5
## A ledge: its end this far (m) off the serpent's widest flank (its head's
## jowls) at the slither's most there, so about 1.2 m off its back's
## flank where riders stand; its top this far under its back's crest there
## (RIDE_ARCS m back from its snout), so a rider steps across onto its
## shoulder getting on and hops down onto the ledge getting off (the motor's
## jump is 0.8 m high: a ledge over its back can't be jumped back up to);
## the terrace's span along the way, its depth out to its end and its
## slab's thickness; the flight's width (m); how weathered. At the pass's
## pace (about 10 m/s) the terrace's span is some 0.6 s of its back going
## by, to land on getting off.
const LEDGE_GAP := 0.9
const LEDGE_DROP := 0.4
const RIDE_ARCS := Vector2(20.0,60.0)
const LEDGE_SPAN := 6.0
const LEDGE_DEEP := 3.6
const LEDGE_SLAB := 0.5
const LEDGE_WIDTH := 2.4
const LEDGE_WEATHERED := 0.45
## The least the flight's walls reach under its foot (m), so a landing
## jutting over the rim stands on a wall with some depth to it.
const LEDGE_DEPTH := 2.6
## Its head kept to its way by a ledge: its look's share within LOOK_NEAR
## m (along its way) of a ledge's mark, easing back over LOOK_EASE m.
const LOOK_NEAR := 40.0
const LOOK_EASE := 30.0
const LOOK_HELD := 0.1
## --serpent-board: its head this far (m along its way) short of the mark:
## at the pass's pace its head goes by in about five seconds, its middle in
## about ten.
const BOARD_LEAD := 45.0

var scene: Node3D
var sky: Node3D
var serpent: Node3D
var rider: Node3D
## Each ledge: {id, isle, mark, at (route m), pass (the way's point by it,
## its slither in), way (flat, along it), toward (flat, from the ledge to
## its way), side (+1 the way's right), end (the landing's end, middle, on
## its top), top (y), stand (where to stand on it, facing `toward`),
## built (its node, or null), names}.
var spots: Array[Dictionary] = []
## The isle to start at (--serpent-board), or "".
var board := ""

static func wanted() -> bool:
	return not LaunchArgs.user_args().has("--serpent-old-route")

func _init() -> void:
	name = "SerpentRoute"

## The serpent on this route in `owner_sky` (the aqueduct isle's), its
## rider and the ledges (the aqueduct isle's at once, each motif isle's
## once it stands).
func setup(study: Node3D, owner_sky: Node3D) -> Node3D:
	scene = study
	sky = owner_sky
	for arg: String in LaunchArgs.user_args():
		if arg.begins_with("--serpent-board="): board = arg.get_slice("=",1)
	serpent = RuneSerpent.new()
	serpent.route = ROUTE
	serpent.route_marks = MARKS
	serpent.start_mark = START
	serpent.girth = GIRTH
	# It advances before the rider carries him and the pilot steps.
	serpent.process_priority = -101
	sky.add_child(serpent)
	serpent.setup(scene)
	rider = SerpentRider.new()
	add_child(rider)
	rider.setup(scene,serpent)
	_lay_spots()
	_build_ready()
	if board != "" and scene.has_signal("isle_ready"):
		scene.isle_ready.connect(_board_start,CONNECT_ONE_SHOT)
	return serpent

# --- The ledges ---------------------------------------------------------------------

## Each ledge laid off the serpent's way at its mark (not built yet).
func _lay_spots() -> void:
	var flank := widest_flank()
	var crest := ride_crest()
	for spec: Array in SPOTS:
		var at := float(serpent.marks()[spec[2]])
		var p := pass_point(at)
		var ahead: Vector3 = serpent.route_point(at+2.0)-serpent.route_point(at-2.0)
		var way := Vector2(ahead.x,ahead.z).normalized()
		var right := Vector2(-way.y,way.x)
		# The ledge on the side toward the isle's middle.
		var isle := isle_middle(str(spec[1]))
		var side := 1.0 if (isle-Vector2(p.x,p.z)).dot(right) > 0.0 else -1.0
		var out: float = flank+serpent.weave_reach()*float(serpent.route_shares(at).x)+LEDGE_GAP
		var end2 := Vector2(p.x,p.z)+right*side*out
		# Under its back's crest as it passes (its heave there is the
		# same every lap: the waves stand still in the sky).
		var top := p.y+crest-LEDGE_DROP
		spots.append({"id":spec[0],"isle":spec[1],"mark":spec[2],"at":at,"pass":p,"way":way,
			"toward":-right*side,"side":side,"end":Vector3(end2.x,top,end2.y),"top":top,
			"stand":Vector3(end2.x+right.x*side*0.7,top,end2.y+right.y*side*0.7),
			"built":null,"names":spec[3]})

## Where the head's way passes at route arc `at`: the route, its slither
## (the weave at its share, its spring at rest) and its heave, unbanked: as
## its body goes by there each lap.
func pass_point(at: float) -> Vector3:
	var p: Vector3 = serpent.route_point(at)
	var ahead: Vector3 = serpent.route_point(at+1.0)-serpent.route_point(at-1.0)
	var t := ahead.normalized()
	var right := t.cross(Vector3.UP).normalized()
	var up := right.cross(t).normalized()
	var weave: float = serpent.weave_reach()*float(serpent.route_shares(at).x)*sin(TAU*at/float(serpent._wave))
	var heave: float = serpent.heave_reach()*sin(TAU*at/float(serpent._heave_wave)+1.3)
	return p+right*weave+up*heave

## Its widest half width (m): the body's rings' and the head's sections'.
func widest_flank() -> float:
	var most := 0.0
	for k in range(RuneSerpent.STATIONS):
		for c: Vector3 in serpent.ring_corners(k): most = maxf(most,absf(c.x))
	for i in range(RuneSerpent.HEAD_SECTIONS.size()):
		for c: Vector3 in serpent.head_corners(i): most = maxf(most,absf(c.x))
	# Its breath swells it a little.
	return most*1.03

## Its back's crest over its spine (m) where riders stand (RIDE_ARCS m
## back from its snout), at its highest.
func ride_crest() -> float:
	var most := 0.0
	var arcs: PackedFloat32Array = serpent.stations()
	for k in range(RuneSerpent.STATIONS):
		if arcs[k] < RIDE_ARCS.x or arcs[k] > RIDE_ARCS.y: continue
		for c: Vector3 in serpent.ring_corners(k): most = maxf(most,c.y)
	return most

## An isle's middle (x, z): the aqueduct isle's, or a motif isle's.
func isle_middle(id: String) -> Vector2:
	if id == "aqueduct": return Vector2(85.0,-20.0)
	for place: Array in sky.places() if sky.has_method("places") else []:
		if str(place[0]) == id: return Vector2((place[1] as Vector3).x,(place[1] as Vector3).z)
	return Vector2.ZERO

## The motif isle `id` (scripts/kit_isle/motif_isle.gd), or null.
func motif_isle(id: String) -> Node3D:
	var motifs: Variant = sky.get("motifs")
	if motifs == null: return null
	for isle: Node3D in motifs.isles:
		if str(isle.motif.id()) == id: return isle
	return null

## Whether the isle under spot `s` stands (its turf there to fit to).
func isle_up(s: Dictionary) -> bool:
	if str(s.isle) == "aqueduct": return true
	var isle := motif_isle(str(s.isle))
	return isle != null and isle.is_up()

## Every ledge whose isle stands, built.
func _build_ready() -> void:
	for s: Dictionary in spots:
		if s.built == null and isle_up(s): build(s)

## All the ledges whose isles stand, built (a test, after the sky's flush).
func build_all() -> void:
	_build_ready()

## The ledge at `s`: a jutting terrace, LEDGE_SPAN m along the serpent's
## way and LEDGE_DEEP m out to its end, a heavy worn slab on two courses of
## masonry carried down under it (LEDGE_DEPTH at least, to the turf), and a
## flight of the kit's steps (RuinKit `_flight`, LEDGE_WIDTH wide) climbing
## to it from the turf, toward the way. The flight's foot fitted to the
## turf (rays), so its steps start on it.
func build(s: Dictionary) -> Node3D:
	var space := get_world_3d().direct_space_state
	var toward: Vector2 = s.toward
	var end: Vector3 = s.end
	var top: float = s.top
	var end2 := Vector2(end.x,end.z)
	var turf := top-2.0
	var steps := 1
	var run := RuinKit.LANDING
	for i in range(5):
		steps = clampi(roundi((top-turf)/RuinKit.RISER),1,48)
		run = (steps-1)*RuinKit.TREAD+RuinKit.LANDING
		var y: Variant = _turf_y(space,end2-toward*(LEDGE_DEEP+run),top)
		if y == null: break
		turf = float(y)
	# The lowest turf under it, for its walls' depth.
	var low := turf
	for f: float in [0.0,0.5,1.0]:
		var y: Variant = _turf_y(space,end2-toward*(LEDGE_DEEP+run*f),top)
		if y != null: low = minf(low,float(y))
	var depth := maxf(top-low+0.4,LEDGE_DEPTH)
	# Its own frame: the origin the end's middle on its top, -Z toward the
	# serpent's way.
	var z := Vector3(-toward.x,0.0,-toward.y)
	var x := Vector3.UP.cross(z).normalized()
	var b := RuinKit.Build.new(hash(str(s.id))&0xffff,LEDGE_WEATHERED,"SerpentLedge")
	var half := Vector3(LEDGE_SPAN*0.5,LEDGE_SLAB*0.5,LEDGE_DEEP*0.5)
	var slab := Transform3D(Basis.IDENTITY,Vector3(0.0,-half.y,half.z))
	b.lean = true
	b.solid(RuinKit._box(b,half),slab,RuinKit._stone(b,1.04),false,true)
	b.lean = false
	RuinKit._walk_hull(b,slab,[Plane(Vector3.RIGHT,half.x),Plane(Vector3.LEFT,half.x),Plane(Vector3.UP,half.y),Plane(Vector3.DOWN,half.y),Plane(Vector3.BACK,half.z),Plane(Vector3.FORWARD,half.z)])
	# Two courses under it, each set in from the one above, the lower
	# carried down to the turf (or hanging past the rim, broken off).
	var upper := Vector3(half.x-0.18,0.55,half.z-0.15)
	b.solid(RuinKit._box(b,upper),Transform3D(Basis.IDENTITY,Vector3(0.0,-LEDGE_SLAB-upper.y,half.z+0.1)),RuinKit._stone(b,0.97))
	var lower_h := maxf(depth-LEDGE_SLAB-upper.y*2.0,0.6)*0.5
	var lower := Vector3(half.x-0.45,lower_h,half.z-0.35)
	b.solid(RuinKit._box(b,lower),Transform3D(Basis.IDENTITY,Vector3(0.0,-LEDGE_SLAB-upper.y*2.0-lower_h,half.z+0.25)),RuinKit._stone(b,0.92))
	# The flight up to it from the turf.
	var flight := Transform3D(Basis.IDENTITY,Vector3(0.0,-steps*RuinKit.RISER,LEDGE_DEEP+run*0.5-0.02))
	RuinKit._flight(b,flight,steps,LEDGE_WIDTH,RuinKit.LANDING,maxf(top-steps*RuinKit.RISER-low+0.4,0.4))
	var node := b.finish()
	node.name = "Ledge_%s" % s.id
	node.transform = Transform3D(Basis(x,Vector3.UP,z),end)
	add_child(node)
	s.built = node
	s.steps = steps
	s.foot = Vector3(end.x-toward.x*(LEDGE_DEEP+run),turf,end.z-toward.y*(LEDGE_DEEP+run))
	return node

## The turf's (or stone's) top at (x, z) within reach under `over`, or null.
static func _turf_y(space: PhysicsDirectSpaceState3D, p: Vector2, over: float) -> Variant:
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,over+6.0,p.y),Vector3(p.x,over-24.0,p.y),1|(1 << 11))
	var hit := space.intersect_ray(ray)
	return (hit.position as Vector3).y if not hit.is_empty() else null

## The ledge spot named `name` (its id or a flag's name for it), or {}.
func spot(name_or_isle: String) -> Dictionary:
	for s: Dictionary in spots:
		if str(s.id) == name_or_isle or (s.names as Array).has(name_or_isle): return s
	return {}

# --- Each frame ---------------------------------------------------------------------

func _process(_delta: float) -> void:
	if serpent == null: return
	_build_ready()
	# Its head kept to its way by a ledge.
	var near := INF
	for s: Dictionary in spots:
		var d := absf(wrapf(float(serpent.s)-float(s.at),-float(serpent.route_length)*0.5,float(serpent.route_length)*0.5))
		near = minf(near,d)
	serpent.look_share = lerpf(LOOK_HELD,1.0,smoothstep(LOOK_NEAR,LOOK_NEAR+LOOK_EASE,near))

# --- --serpent-board ------------------------------------------------------------------

## On foot on the named isle's ledge, at its end facing the serpent's way,
## the serpent's head BOARD_LEAD m short of the ledge: its isle stood up at
## once if it is a motif isle not yet up, its ledge built.
func _board_start() -> void:
	var s := spot(board)
	if s.is_empty():
		push_warning("serpent route: no ledge '%s' (home, tarn, nave, gorge)" % board)
		return
	start_at(s)

## Him on ledge `s`, the serpent coming.
func start_at(s: Dictionary) -> void:
	if str(s.isle) != "aqueduct":
		var isle := motif_isle(str(s.isle))
		if isle != null and not isle.is_up():
			isle.build_now()
			isle.work(-1)
	if s.built == null: build(s)
	serpent.place(fposmod(float(s.at)-BOARD_LEAD,float(serpent.route_length)))
	rider.reset()
	var toward: Vector2 = s.toward
	scene.place(s.stand,toward)
	scene.set("_last_stood",s.stand)
