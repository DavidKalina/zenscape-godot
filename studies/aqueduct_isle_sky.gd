extends Node3D
## The sky round the aqueduct isle (studies/aqueduct_isle.gd), lived in with
## what the game already has, wired here rather than rewritten:
##
##   far isles   other sky islands at a range of distances, made as the
##               game's islets are (scripts/sky_islets.gd `stand`, scripts/
##               sky_islet.gd `author`): a few near enough to fly to, more
##               out in the air, the farthest big and coarse in the haze;
##               the clusters of the sky (scripts/sky_clusters.gd: the
##               solver, the dresser: cabins, windmills, docks, lighthouses,
##               sky folk), and one pierced isle to thread (scripts/
##               sky_pierced.gd). Their trees hand over to the far stand-ins
##               (scripts/far_trees.gd) past FAR_TREES m. Each is worked out
##               on a worker and stood up a part a frame within the sky's
##               frame budget (scripts/sky_commits.gd), fading in. Their
##               ground and rock collide (a trimesh on the isle's layers),
##               so the plane skims, bumps and sets down on them as on the
##               isle; the pierced isle's rock bumps as the game's does
##               (SkyPierced `bump`). --no-far-isles leaves them out.
##   airships    the sky folk's cargo airship (scripts/sky_airship.gd's ship,
##               scripts/airship_build.gd) on slow loops between the far
##               isles, propellers turning, crew waving when you pass, lit
##               at night, solid to the plane; one passing close hums with
##               the plane's own propeller drone (scripts/glide_air.gd
##               `engine`). --no-airships.
##   traffic     the game's CPU biplanes (scripts/sky_traffic.gd): laps
##               round the clusters and buzzes of the islets, climbing over
##               what stands. --no-traffic.
##   life        the open-air life of the other islands (scripts/
##               sky_ambient_life.gd): gulls on thermals over the nearest
##               isles, songbird flocks bursting from their crowns as you
##               pass. --no-sky-life.
##   motes       the sky's motes of light (scripts/sky_motes.gd) round the
##               isle and the nearest clusters. --no-motes.
##   tokens      a few glyph tokens for the plane (scripts/
##               sky_collectibles.gd, CollectibleLines `line`), each a
##               skill moment through the isle's own stone (TOKENS).
##               --no-sky-tokens.
## --no-sky leaves all of it out. See docs/scenic/aqueduct-isle-sky.md.

const SkyIslets = preload("res://scripts/sky_islets.gd")
const SkyIslet = preload("res://scripts/sky_islet.gd")
const SkyClusters = preload("res://scripts/sky_clusters.gd")
const SkyPierced = preload("res://scripts/sky_pierced.gd")
const PiercedRuins = preload("res://scripts/pierced_ruins.gd")
const PiercedMesh = preload("res://scripts/pierced_mesh.gd")
const Cabin = preload("res://scripts/cabin.gd")
const Dresser = preload("res://scripts/cluster_dresser.gd")
const RockLooks = preload("res://scripts/rock_looks.gd")
const SkyCommits = preload("res://scripts/sky_commits.gd")
const SkyTraffic = preload("res://scripts/sky_traffic.gd")
const SkyAirship = preload("res://scripts/sky_airship.gd")
const AirshipBuild = preload("res://scripts/airship_build.gd")
const GlideAir = preload("res://scripts/glide_air.gd")
const SkyAmbientLife = preload("res://scripts/sky_ambient_life.gd")
const SkyMotes = preload("res://scripts/sky_motes.gd")
const SkyCollectibles = preload("res://scripts/sky_collectibles.gd")
const SkyCells = preload("res://scripts/sky_cells.gd")
const Lines = preload("res://scripts/collectible_lines.gd")
const IslanderFigure = preload("res://scripts/islander_figure.gd")

## The isle's own layers (studies/aqueduct_isle.gd TURF_LAYER): ground the
## plane skims and the pilot is set down on; and what bumps it.
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1
## The isle's middle (world), for distances.
const MIDDLE := Vector3(85.0,30.0,-20.0)

## The lone isles: [name, kind, seed, middle (world; y the rim), radius
## (m), grid step (m; 0 the plate's)]. Near ones to fly to, a ring further
## out, and big coarse ones far off in the haze. Kept off the lodestone's
## shard (studies/aqueduct_isle.gd TARGET) and the clusters.
const ISLES := [
	["grove_east","grove",4101,Vector3(215.0,40.0,-35.0),16.0,0.0],
	["spring_west","spring",4102,Vector3(-75.0,46.0,55.0),15.0,0.0],
	["meadow_south","meadow",4103,Vector3(45.0,16.0,185.0),13.0,0.0],
	["spring_north","spring",4104,Vector3(105.0,22.0,-165.0),12.0,0.0],
	["hills_ne","hills",4105,Vector3(330.0,52.0,-120.0),18.0,1.0],
	["grove_w","grove",4106,Vector3(-380.0,34.0,-70.0),22.0,1.0],
	["crag_se","crag",4107,Vector3(560.0,50.0,140.0),14.0,1.0],
	["hills_nw","hills",4108,Vector3(-190.0,22.0,-560.0),24.0,1.0],
	["spring_s","spring",4109,Vector3(250.0,44.0,520.0),18.0,1.0],
	["shore_sw","shore",4110,Vector3(-470.0,10.0,480.0),20.0,1.0],
	["far_n","grove",4111,Vector3(-160.0,30.0,-1500.0),48.0,2.5],
	["far_ne","hills",4112,Vector3(1300.0,48.0,-900.0),55.0,2.5],
	["far_e","grove",4113,Vector3(1650.0,20.0,350.0),46.0,2.5],
	["far_se","spring",4114,Vector3(900.0,38.0,1350.0),42.0,2.5],
	["far_sw","hills",4115,Vector3(-1100.0,26.0,1250.0),58.0,2.5],
	["far_w","grove",4116,Vector3(-1700.0,44.0,100.0),50.0,2.5],
	["far_nw","crag",4117,Vector3(-1200.0,60.0,-1150.0),40.0,2.5],
]
## Trees an isle bears, per square metre of land (groves more): so a big
## isle reads wooded from far off.
const TREE_DENSITY := {"grove":0.035,"spring":0.016,"hills":0.012,"meadow":0.01,"crag":0.008,"shore":0.006}
## Its trees hand over to the far stand-ins past this (m).
const FAR_TREES := 300.0
## The clusters: [motif, seed, middle (world)].
const CLUSTERS := [
	["farmstead",21,Vector3(340.0,26.0,150.0)],
	["falls",5,Vector3(-250.0,36.0,215.0)],
	["hamlet",9,Vector3(-80.0,12.0,-430.0)],
	["reef",4,Vector3(780.0,6.0,-310.0)],
	["lake",7,Vector3(-720.0,28.0,-170.0)],
	["forest",12,Vector3(560.0,40.0,760.0)],
]
## The pierced isle: its seed and middle (world).
const PIERCED := [3,Vector3(520.0,64.0,-700.0)]

## The airships' loops (world waypoints, flown round and round, a Catmull-Rom
## through them) and their speeds (m/s). The first passes the isle close
## (its drone heard on the isle's top), the others ply the far isles.
const ROUTES := [
	[[Vector3(60.0,62.0,140.0),Vector3(330.0,58.0,200.0),Vector3(420.0,64.0,-60.0),Vector3(230.0,66.0,-130.0),Vector3(40.0,60.0,-70.0)],6.5],
	[[Vector3(-90.0,40.0,-470.0),Vector3(-700.0,52.0,-230.0),Vector3(-260.0,58.0,240.0),Vector3(-120.0,48.0,-60.0)],7.5],
	[[Vector3(780.0,38.0,-260.0),Vector3(560.0,70.0,-760.0),Vector3(560.0,60.0,700.0),Vector3(900.0,44.0,300.0)],8.0],
]
## The airship's bank per radian a second of turn, and most.
const SHIP_BANK := 0.9
const SHIP_BANK_MAX := 0.14
## The drone: heard from DRONE_FAR m, full at DRONE_NEAR.
const DRONE_FAR := 170.0
const DRONE_NEAR := 45.0
## The crew wave within this (m) of the camera.
const WAVE_NEAR := 70.0

## The tokens: [line id, category, kind, points (world)]; each a moment
## (see the doc for the flying line each asks for).
const TOKENS := [
	# Knife edge (Q or E held) along z -29.2, x east: between the first two
	# stepping stumps (1.9 m apart) and on under the first arch's pier.
	["aq:knife","air","knife",[Vector3(91.8,25.0,-29.2),Vector3(100.0,25.0,-29.2)]],
	# Through the fallen span, where the channel's water falls.
	["aq:break","air","break",[Vector3(100.0,31.5,-34.0)]],
	# Under the near island's keel, at its lowest point.
	["aq:keel","under","keel",[Vector3(85.0,-9.5,0.0)]],
	# Threading the gap between the west islet and the hill's crag.
	["aq:west","air","thread",[Vector3(37.8,34.0,-0.5)]],
	# Threading between the east islet and the isle's rim.
	["aq:east","air","thread",[Vector3(128.8,27.5,-8.0)]],
]
const TOKEN_SEED := 11

var scene: Node3D
var islets: Node3D
var clusters: Node3D
var pierced: Node3D
var traffic: Node
var life: Node3D
var collectibles: Node3D
var airships: Array[Dictionary] = []
var motes: Array[Node3D] = []
var drone: Node3D
## What is on (flags).
var on := {"isles":true,"airships":true,"traffic":true,"life":true,"motes":true,"tokens":true}
## Lone isles being made ({task, spec, out}) and their built records by name.
var _making: Array[Dictionary] = []
var isles := {}
## Built records given collision already (by node).
var _solid := {}
var _palette := {}
var _clock := 0.0
## The life's stand-in for SkyIslands (`IsleHosts`).
var _hosts: Node3D

static func flags() -> PackedStringArray:
	return PackedStringArray(preload("res://scripts/launch_args.gd").user_args())

func _init() -> void:
	name = "Sky"

## Builds the sky round `study` (once it stands and the pilot walks).
func setup(study: Node3D) -> void:
	scene = study
	var args := flags()
	if args.has("--no-sky"):
		for k in on: on[k] = false
	if args.has("--no-far-isles"): on.isles = false
	if args.has("--no-airships"): on.airships = false
	if args.has("--no-traffic"): on.traffic = false
	if args.has("--no-sky-life"): on.life = false
	if args.has("--no-motes"): on.motes = false
	if args.has("--no-sky-tokens"): on.tokens = false
	if on.isles: _start_isles()
	if on.airships: _build_airships()
	if on.traffic: _build_traffic()
	if on.life and on.isles: _build_life()
	if on.motes: _build_motes()
	if on.tokens: _build_tokens()

func _exit_tree() -> void:
	for m: Dictionary in _making: WorkerThreadPool.wait_for_task_completion(int(m.task))
	_making.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for m: Dictionary in _making: WorkerThreadPool.wait_for_task_completion(int(m.task))

# --- The far isles ------------------------------------------------------------------

## The islets' host (SkyIslets, at the origin: every isle's home is world),
## the clusters' and the pierced isle's on it; every lone isle set making
## on a worker, the clusters and the pierced isle planned.
func _start_isles() -> void:
	islets = SkyIslets.new()
	add_child(islets)
	_palette = islets.prepare_authored()
	Cabin.info()
	Dresser._mats()
	var catalog: Dictionary = SkyIslets.catalog()
	for spec: Array in ISLES:
		var out := {}
		var recipe := _recipe(spec)
		var home: Vector3 = spec[3]
		var palette := _palette
		var plants: Dictionary = catalog.data
		var task := WorkerThreadPool.add_task(func() -> void:
			SkyIslets._make(int(spec[2]),palette,plants,out,home.y,recipe),false,"Aqueduct sky isle")
		_making.append({"task":task,"spec":spec,"out":out})
	clusters = SkyClusters.new()
	clusters.islets = islets
	clusters.scene = scene
	clusters._palette = _palette
	add_child(clusters)
	# The game's own flags leave the clusters (--no-clusters) and the
	# pierced isle (--no-pierced) out.
	if SkyClusters.random_enabled():
		for c: Array in CLUSTERS:
			var s := {"key":"aq:"+str(c[0]),"at":c[2],"motif":c[0],"seed":int(c[1])}
			clusters.spots.append(s)
			clusters._plan(s)
	pierced = SkyPierced.new()
	pierced.islets = islets
	pierced._palette = _palette
	PiercedRuins.prepare()
	PiercedMesh.material()
	add_child(pierced)
	if SkyPierced.random_enabled():
		var p := {"key":"aq","at":PIERCED[1],"seed":int(PIERCED[0])}
		pierced.spots = [p]
		SkyPierced.taken.clear()
		SkyPierced.taken.append(PIERCED[1])
		pierced._plan(p)

## A lone isle's recipe (SkyIslet `author`): its kind, radius, step, trees
## by its land, its rock as a seeded islet's, its trees' far stand-ins.
static func _recipe(spec: Array) -> Dictionary:
	var recipe := RockLooks.seeded(int(spec[2]))
	var kind: String = spec[1]
	var radius: float = spec[4]
	recipe.kind = kind
	recipe.radius = radius
	if float(spec[5]) > 0.0: recipe.step = float(spec[5])
	var trees := int(PI*radius*radius*float(TREE_DENSITY.get(kind,0.01)))
	if trees > 0: recipe.trees = Vector2i(trees,int(trees*1.3)+1)
	recipe.far_trees = FAR_TREES
	return recipe

## Each frame: what the workers made stood up (a part a frame within the
## sky's budget), new ones faded in and given collision, the clusters'
## sails turned and lights lit.
func _advance_isles(delta: float, eye: Vector3) -> void:
	for i in range(_making.size()-1,-1,-1):
		var m: Dictionary = _making[i]
		if not WorkerThreadPool.is_task_completed(int(m.task)) or not SkyCommits.open(): continue
		WorkerThreadPool.wait_for_task_completion(int(m.task))
		_making.remove_at(i)
		var began := Time.get_ticks_usec()
		_stand_isle(m.spec,m.out)
		SkyCommits.spend("aqueduct isle",Time.get_ticks_usec()-began)
	clusters._stand_some(eye)
	clusters._animate(delta)
	pierced._stand_some()
	for key in pierced.isles:
		var s: Dictionary = pierced.isles[key]
		if float(s.get("age",SkyPierced.FADE_IN)) < SkyPierced.FADE_IN:
			s.age = float(s.age)+delta
			pierced._fade(s)
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		if float(b.get("age",SkyIslets.FADE_IN)) < SkyIslets.FADE_IN:
			b.age = float(b.get("age",0.0))+delta
			islets._fade(b)
		if not _solid.has(b.node) and is_instance_valid(b.node):
			_solid[b.node] = true
			_solidify(b.node)

func _stand_isle(spec: Array, out: Dictionary) -> void:
	var b: Dictionary = islets.stand("Isle_"+str(spec[0]),spec[3],out)
	b.fixed = true
	b.age = 0.0
	b.out = out
	islets.built["aq:"+str(spec[0])] = b
	isles[spec[0]] = b
	islets._fade(b)

## Every isle stood up at once (tests, captures).
func flush() -> void:
	if islets == null: return
	for m: Dictionary in _making:
		WorkerThreadPool.wait_for_task_completion(int(m.task))
		_stand_isle(m.spec,m.out)
	_making.clear()
	clusters.flush(MIDDLE)
	pierced.flush()
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		b.age = SkyIslets.FADE_IN
		islets._fade(b)
		if not _solid.has(b.node):
			_solid[b.node] = true
			_solidify(b.node)

## True once every isle, cluster and the pierced isle stands.
func isles_ready() -> bool:
	if islets == null: return true
	if not _making.is_empty(): return false
	for key in clusters.clusters:
		var c: Dictionary = clusters.clusters[key]
		if int(c.get("task",-1)) >= 0 or not (c.get("waiting",[]) as Array).is_empty(): return false
	for key in pierced.isles:
		if int(pierced.isles[key].get("task",-1)) >= 0 or not (pierced.isles[key].get("stage",[]) as Array).is_empty(): return false
	return true

## The isle's ground and rock as the plane meets the isle's: its top on the
## turf's layer (skimmed, set down on) and the bump's, its sides (shore wall
## and hanging rock) the bump's; a trimesh each, under the drawn mesh.
func _solidify(node: Node3D) -> void:
	for part: String in ["Body","Sides"]:
		var mesh_node := node.get_node_or_null(part) as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null: continue
		var faces := mesh_node.mesh.get_faces()
		if faces.size() < 3: continue
		var body := StaticBody3D.new()
		body.name = "Solid"
		body.collision_layer = SOLID_LAYER|(TURF_LAYER if part == "Body" else 0)
		body.collision_mask = 0
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var collider := CollisionShape3D.new()
		collider.shape = shape
		body.add_child(collider)
		mesh_node.add_child(body)

## The highest ground or rock under a point (world), or null: what stands
## (physics, every isle and the aqueduct isle) or the pierced isle's box.
func ground(p: Vector3) -> Variant:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,260.0,p.z),Vector3(p.x,-200.0,p.z),SOLID_LAYER|TURF_LAYER)
	var hit := space.intersect_ray(ray)
	var top: Variant = (hit.position as Vector3).y if not hit.is_empty() else null
	if pierced != null:
		for key in pierced.isles:
			var s: Dictionary = pierced.isles[key]
			if s.get("plan") == null: continue
			var box: AABB = s.plan.bounds()
			var at: Vector3 = s.spot.at
			if absf(p.x-at.x-box.get_center().x) < box.size.x*0.5 and absf(p.z-at.z-box.get_center().z) < box.size.z*0.5:
				top = maxf(float(top) if top != null else -INF,at.y+box.end.y)
	return top

# --- Traffic ------------------------------------------------------------------------

## The game's CPU biplanes, lapping the clusters and the pierced isle and
## buzzing the lone isles; shown always (the game shows them in flight).
func _build_traffic() -> void:
	traffic = IsleTraffic.new()
	add_child(traffic)
	var slots: Array = []
	for c: Array in CLUSTERS: slots.append(c[2])
	slots.append(PIERCED[1])
	for spec: Array in ISLES:
		if float(spec[5]) < 2.0: traffic.buzz.append(spec[3])
	traffic.ground = ground
	traffic.build(self,slots)
	traffic.show(true)

## SkyTraffic's pilots here: their islets are this sky's lone isles, not
## the seeded cells'.
class IsleTraffic extends SkyTraffic:
	var buzz: Array = []
	func _choose(plane: Dictionary) -> Dictionary:
		var rng: RandomNumberGenerator = plane.rng
		var at: Vector3 = plane.flight.position
		if rng.randf() < 0.35:
			var near: Array = buzz.filter(func(p: Vector3) -> bool: return p.distance_to(at) < REACH and p.distance_to(at) > ARRIVE*3.0)
			if not near.is_empty():
				var p: Vector3 = near[rng.randi_range(0,near.size()-1)]
				var under: Variant = ground.call(p) if ground.is_valid() else null
				p.y = (float(under) if under != null else p.y)+BUZZ
				return {"kind":"islet","point":p}
		var here := at-_origin
		var order := range(_slots.size())
		order.sort_custom(func(a: int, b: int) -> bool: return (_slots[a] as Vector3).distance_to(here) < (_slots[b] as Vector3).distance_to(here))
		if order.size() > 1: order.erase(int(plane.goal.get("island",-1)))
		return _lap(plane,order[rng.randi_range(0,mini(2,order.size()-1))])

# --- Airships -----------------------------------------------------------------------

## The sky folk's airships: the tow event's own ship (SkyAirship `_make_ship`:
## envelope, gondola, crew, windows and lantern for the night), flown on
## slow loops (ROUTES); a body each for the plane to bump; and the drone.
func _build_airships() -> void:
	for k in range(ROUTES.size()):
		var route: Array = ROUTES[k]
		var ship: Node3D = SkyAirship.new()
		ship.name = "Airship%d" % k
		ship.scene = scene
		# No islets: the tow event never runs (`_process` waits on them).
		ship.islets = null
		add_child(ship)
		ship._make_ship()
		ship._ship.visible = true
		ship._lines.visible = false
		for g: MeshInstance3D in ship._grapples: g.visible = false
		ship._set_fade(0.0)
		var body := AnimatableBody3D.new()
		body.name = "Solid"
		body.collision_layer = SOLID_LAYER
		body.collision_mask = 0
		body.sync_to_physics = false
		var envelope := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = AirshipBuild.ENVELOPE_RADIUS*0.95
		capsule.height = AirshipBuild.ENVELOPE_LENGTH
		envelope.shape = capsule
		envelope.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),AirshipBuild.ENVELOPE_AT)
		body.add_child(envelope)
		var gondola := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(AirshipBuild.HULL.x*2.0,AirshipBuild.HULL.y+1.6,AirshipBuild.HULL.z*2.0)
		gondola.shape = box
		gondola.position = Vector3(0.0,(1.6-AirshipBuild.HULL.y)*0.5,0.0)
		body.add_child(gondola)
		ship._ship.add_child(body)
		var points: Array = route[0]
		var length := 0.0
		for i in range(points.size()): length += (points[i] as Vector3).distance_to(points[(i+1)%points.size()])
		airships.append({"ship":ship,"points":points,"speed":float(route[1]),"length":length,
			"u":float(k)*0.37,"heading":0.0,"bank":0.0,"at":Vector3.ZERO})
		_place_airship(airships[-1],0.0)
	drone = GlideAir.new()
	drone.name = "AirshipDrone"
	add_child(drone)
	drone.start()
	drone.visible = false

## A point on a loop's Catmull-Rom at `u` (0 to 1 round it).
static func _loop(points: Array, u: float) -> Vector3:
	var n := points.size()
	var f := fposmod(u,1.0)*n
	var i := int(f)
	var t := f-i
	var p0: Vector3 = points[(i-1+n)%n]
	var p1: Vector3 = points[i%n]
	var p2: Vector3 = points[(i+1)%n]
	var p3: Vector3 = points[(i+2)%n]
	return 0.5*((2.0*p1)+(-p0+p2)*t+(2.0*p0-5.0*p1+4.0*p2-p3)*t*t+(-p0+3.0*p1-3.0*p2+p3)*t*t*t)

func _place_airship(a: Dictionary, delta: float) -> void:
	a.u = fposmod(float(a.u)+float(a.speed)*delta/float(a.length),1.0)
	var at := _loop(a.points,a.u)
	var ahead := _loop(a.points,float(a.u)+4.0/float(a.length))
	var way := ahead-at
	var heading := atan2(-way.x,-way.z)
	var turn := angle_difference(float(a.heading),heading)/maxf(delta,0.001) if delta > 0.0 else 0.0
	a.heading = heading
	a.bank = lerpf(float(a.bank),clampf(-turn*SHIP_BANK,-SHIP_BANK_MAX,SHIP_BANK_MAX),1.0-exp(-delta/1.5)) if delta > 0.0 else 0.0
	a.at = at
	var ship: Node3D = a.ship
	ship._ship.transform = Transform3D(Basis(Vector3.UP,heading)*Basis(Vector3.BACK,float(a.bank)),at)

## Each frame: along their loops, the propellers turning, the crew waving
## at a passing camera, the lights at night; the nearest one's drone.
func _advance_airships(delta: float, eye: Vector3) -> void:
	var nearest := INF
	for a: Dictionary in airships:
		_place_airship(a,delta)
		var ship: Node3D = a.ship
		for p: Node3D in ship._props: p.rotate_object_local(Vector3.BACK,14.0*delta)
		var d := (a.at as Vector3).distance_to(eye)
		nearest = minf(nearest,d)
		if ship._crew.size() >= 2:
			var bow := "wave" if d < WAVE_NEAR else "idle"
			if (ship._crew[0] as IslanderFigure).move != bow: ship._crew[0].play(bow)
		ship._night_lights(delta)
	if drone != null:
		var running := 1.0-smoothstep(DRONE_NEAR,DRONE_FAR,nearest)
		drone.engine(7.0,0.0,running)
		drone._fill()

# --- Open-air life ------------------------------------------------------------------

## The other islands' life (SkyAmbientLife) on this sky's isles: each lone
## isle with trees and each cluster's member with the most, read through a
## stand-in of the islands it asks (`IsleHosts`).
func _build_life() -> void:
	_hosts = IsleHosts.new()
	_hosts.name = "LifeHosts"
	_hosts.scene = scene
	add_child(_hosts)
	life = IsleLife.new()
	life.radius = 420.0
	life.release = 480.0
	add_child(life)
	life.setup(_hosts)

## Each standing isle not yet known to the life, laid out for it (its
## trees' crowns, its gulls' columns), once.
func _advance_life(delta: float, eye: Vector3) -> void:
	for key: String in islets.built:
		var b: Dictionary = islets.built[key]
		if _hosts.known.has(key) or not is_instance_valid(b.node): continue
		var plants: Variant = null
		if b.has("out"): plants = (b.out as Dictionary).get("plants")
		elif b.has("cluster"):
			var c: Dictionary = clusters.clusters.get(b.cluster,{})
			if c.has("out") and (c.out as Dictionary).has("made"): plants = (c.out.made.get(b.member,{}) as Dictionary).get("plants")
		_hosts.known[key] = true
		if not plants is Dictionary: continue
		var catalog: Dictionary = SkyIslets.catalog()
		var trees: Array[Vector4] = SkyAmbientLife._trees(plants,catalog.roles,(catalog.data as Dictionary).boxes,Transform3D.IDENTITY)
		if trees.size() < 3: continue
		trees.sort_custom(func(p: Vector4, q: Vector4) -> bool: return p.y > q.y)
		var shape: RefCounted = b.shape
		var middle := Vector3(0.0,float(shape.ground_at(Vector2.ZERO)),0.0)
		var columns: Array[Vector3] = []
		for t: Vector4 in trees.slice(0,2): columns.append(Vector3(t.x,float(shape.ground_at(Vector2(t.x,t.z))),t.z))
		columns.append(middle)
		_hosts.add(b.node,b.home,{"middle":middle,"trees":trees,"columns":columns,"chaff":[]})
	life.advance(delta,eye)

## What SkyAmbientLife reads of the islands (scripts/sky_islands.gd), for
## this sky's isles: their nodes, homes and life plans.
class IsleHosts extends Node3D:
	var scene: Node
	var _copies: Array = []
	var homes: Array = []
	var lands: Array = []
	var _rise: Array = []
	var offsets: Array = []
	var known := {}
	func add(node: Node3D, home: Vector3, plan: Dictionary) -> void:
		node.set_meta("far",{})
		node.set_meta("life",plan)
		_copies.append(node)
		homes.append(home)
		lands.append(true)
		_rise.append(Vector3.ZERO)
		offsets.append(Vector3(1000.0,0.0,0.0))
	func copy_count() -> int:
		return _copies.size()
	func _key(home: Vector3) -> String:
		return "%d,%d,%d" % [roundi(home.x),roundi(home.y),roundi(home.z)]
	func seed_of(home: Vector3) -> int:
		return hash(_key(home)) & 0xffffff

## SkyAmbientLife over this sky's isles: an isle's middle from its plan, the
## gulls the Fidelity source gull (as LandLife's, assets/zen_reference/
## geometry.scn) since no LandLife stands here.
class IsleLife extends SkyAmbientLife:
	static var _source_gull: Mesh
	func _middle_of(index: int) -> Vector3:
		var node: Node3D = islands._copies[index]
		if not is_instance_valid(node): return Vector3.INF
		return node.global_transform*(node.get_meta("life",{}).get("middle",Vector3.ZERO) as Vector3)
	func _gulls_source() -> Mesh:
		if _source_gull == null:
			var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/zen_reference/bird-flight.json"))
			var reference: Node = preload("res://assets/zen_reference/geometry.scn").instantiate()
			var node := reference.get_node_or_null(str(source.mesh)) as MultiMeshInstance3D
			if node != null and node.multimesh != null: _source_gull = node.multimesh.mesh
			reference.free()
		return _source_gull
	func _exit_tree() -> void:
		_source_gull = null

# --- Motes --------------------------------------------------------------------------

## The sky's motes of light (SkyMotes), faint, round the isle (spread to its
## size) and round the two nearest clusters.
func _build_motes() -> void:
	var spots := [[MIDDLE+Vector3(0.0,-6.0,0.0),2.0]]
	for c: Array in CLUSTERS.slice(0,2): spots.append([(c[2] as Vector3)+Vector3(0.0,6.0,0.0),1.6])
	for s: Array in spots:
		var m: Node3D = SkyMotes.new()
		m.position = s[0]
		m.scale = Vector3.ONE*float(s[1])
		add_child(m)
		m.set_strength(0.75)
		motes.append(m)

# --- Tokens -------------------------------------------------------------------------

## The tokens (SkyCollectibles): one source of hand-laid lines in world
## coordinates on its own (no seeded trails, islets or clusters lay any);
## the plane (and the pilot) take them as the game's do, with its readout,
## blip and run.
func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in TOKENS:
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source("aqueduct",lines)

# --- Each frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if scene == null or scene.camera == null: return
	_clock += delta
	var eye: Vector3 = scene.camera.global_position
	if islets != null: _advance_isles(delta,eye)
	if not airships.is_empty(): _advance_airships(delta,eye)
	if life != null: _advance_life(delta,eye)
	if collectibles != null:
		collectibles.advance(delta,eye)
		if scene.flying and scene.plane_figure != null: collectibles.touch_plane(scene.plane_figure.global_position)
		elif scene.figure != null: collectibles.touch_walker(scene.figure.global_position+Vector3.UP*Lines.WALKER_MIDDLE)
	# The pierced isle's rock bumps the plane as the game's does (its field;
	# its ruins on their own layer); the stone's bodies bump it in the
	# isle's own step.
	if pierced != null and scene.flying and scene.plane != null and delta > 0.0:
		if pierced.bump(scene.plane): scene.bumps += 1
