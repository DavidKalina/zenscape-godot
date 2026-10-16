extends Node3D
## The sky round the aqueduct isle (studies/aqueduct_isle.gd), lived in with
## what the game already has, wired here rather than rewritten:
##
##   motif isles the four ruin motifs' isles (the bell spires, the cloister
##               tarn, the Sundered gorge, the colonnade spine), each placed
##               a few hundred metres off the isle at its own height, whole:
##               its art, turf, water, rope bridges, grass and flowers, life,
##               bells and tokens, to fly to, land on and walk (scripts/
##               kit_isle/motif_sky.gd, docs/scenic/motif-sky.md). Built
##               after the isle is up, on a worker and a slice a frame
##               within the sky's frame budget (scripts/sky_commits.gd), so
##               the pilot walks as soon as ever. Only where the scene asks
##               for them (`wants_motifs`: the aqueduct isle; a motif's own
##               scene has none). --no-far-isles (or --no-motifs) leaves
##               them out.
##   airships    the sky folk's cargo airship (scripts/sky_airship.gd's ship,
##               scripts/airship_build.gd) on slow loops between the motif
##               isles, propellers turning, crew waving when you pass, lit
##               at night, solid to the plane; one passing close hums with
##               the plane's own propeller drone (scripts/glide_air.gd
##               `engine`). One is the ferry (scripts/kit_isle/
##               airship_ferry.gd): a bigger ship on its own loop that
##               shuttles round the isle's south edge, the Sundered gorge,
##               the drowned nave, the cloister tarn and the bell spires,
##               resting by a turf edge at each, ridden on foot
##               (--ferry-aboard[=<stop>] starts on its deck, --ferry-at=
##               <stop> by a stop; --no-ferry). --no-airships.
##   traffic     the game's CPU biplanes (scripts/sky_traffic.gd): laps
##               round the motif isles, buzzes of their tops and passes
##               through the drifting clouds, climbing over what stands.
##               --no-traffic.
##   clouds      the game's towering cumulus, drifting clouds and cloud
##               tearing (scripts/kit_isle/kit_clouds.gd, the sky's cloud
##               host): towers rising out of the cloud sea round the isle,
##               puffs on the breeze, and the plane's and the traffic's
##               tunnels through both. --no-sky-clouds.
##   life        the open-air life of the other islands (scripts/
##               sky_ambient_life.gd): gulls on thermals over the nearest
##               motif isles. --no-sky-life.
##   motes       the sky's motes of light (scripts/sky_motes.gd) round the
##               isle and the two nearest motif isles. --no-motes.
##   tokens      a few glyph tokens for the plane (scripts/
##               sky_collectibles.gd, CollectibleLines `line`), each a
##               skill moment through the isle's own stone (TOKENS), and
##               each motif isle's own. --no-sky-tokens.
##   serpent     a giant rune serpent (scripts/rune_serpent.gd) slithering
##               its long way round the isle, down the Sundered gorge, down
##               into the cloud sea under the bell spires and home; it
##               watches and paces the plane, solid to it. --no-serpent.
##               See docs/scenic/rune-serpent.md. Where the motif isles
##               stand (the aqueduct isle, the game's scene) it is left
##               out unless --serpent asks for it; then it flies the route
##               between them, ridden on foot from a ledge at each
##               (scripts/kit_isle/serpent_route.gd, docs/design/
##               serpent-route.md), or with --serpent-old-route the long
##               way above (and no ferry).
## --no-sky leaves all of it out. See docs/scenic/aqueduct-isle-sky.md.
## The far isles, the clusters and the pierced isle this sky had are gone
## (docs/scenic/motif-sky.md); the old game still has them (scripts/
## sky_islets.gd, sky_clusters.gd, sky_pierced.gd).

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
const RuneSerpent = preload("res://scripts/rune_serpent.gd")
const KitClouds = preload("res://scripts/kit_isle/kit_clouds.gd")
const MotifSky = preload("res://scripts/kit_isle/motif_sky.gd")
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const AirshipFerry = preload("res://scripts/kit_isle/airship_ferry.gd")

## The isle's own layers (studies/aqueduct_isle.gd TURF_LAYER): ground the
## plane skims and the pilot is set down on; and what bumps it.
const TURF_LAYER := 1 << 11
const SOLID_LAYER := 1
## The isle's middle (world), for distances.
const MIDDLE := Vector3(85.0,30.0,-20.0)

## The airships' loops (world waypoints, flown round and round, a Catmull-Rom
## through them) and their speeds (m/s). The first circles the colonnade
## spine; the second the cloister tarn, high (84 m and up) so the ferry's
## way in and out of the tarn passes some 25 m under it. Both keep well off
## the rune serpent's way. The ship that passed the isle close and out by
## the bell spires is the ferry now (scripts/kit_isle/airship_ferry.gd: its
## own loop round five isles, ridden on foot), last in `airships`.
const ROUTES := [
	[[Vector3(-190.0,64.0,-140.0),Vector3(-440.0,60.0,-230.0),Vector3(-380.0,64.0,-560.0),Vector3(-60.0,58.0,-520.0),Vector3(-40.0,60.0,-300.0)],7.5],
	[[Vector3(60.0,92.0,210.0),Vector3(290.0,84.0,360.0),Vector3(60.0,86.0,590.0),Vector3(-170.0,84.0,360.0)],8.0],
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
## Laid off the isle's own numbers (studies/aqueduct_isle_art.gd).
const IsleArt = preload("res://studies/aqueduct_isle_art.gd")
static var TOKENS := [
	# Knife edge (Q or E held) along IsleArt KNIFE_Z, x east: between two
	# stepping stumps (their `stump_slot`) and on under the aqueduct's sky
	# arch, between its hanging piers.
	["aq:knife","air","knife",[Vector3(IsleArt.STUMPS_X-0.2,IsleArt.TOP-5.0,IsleArt.KNIFE_Z),Vector3(IsleArt.MID_X,IsleArt.TOP-5.0,IsleArt.KNIFE_Z)]],
	# Through the fallen span, where the channel's water falls (a little over
	# the springing, the toy's 1.5 m grown with the arch).
	["aq:break","air","break",[Vector3(IsleArt.MID_X,IsleArt.TOP+1.5*IsleArt.GROW,-IsleArt.arch(IsleArt.FALLEN))]],
	# Under the near island's keel, at its lowest point.
	["aq:keel","under","keel",[Vector3(85.0,-9.5,0.0)]],
	# Threading the gap between the west islet and the hill's crag.
	["aq:west","air","thread",[Vector3(37.8,34.0,-0.5)]],
	# Threading between the east islet and the isle's rim.
	["aq:east","air","thread",[Vector3(128.8,27.5,-8.0)]],
]
const TOKEN_SEED := 11

var scene: Node3D
## The motif isles (scripts/kit_isle/motif_sky.gd), or null.
var motifs: Node3D
var traffic: Node
## The sky's cloud host (scripts/kit_isle/kit_clouds.gd), or null.
var clouds: Node3D
var life: Node3D
var collectibles: Node3D
var airships: Array[Dictionary] = []
## The ferry (scripts/kit_isle/airship_ferry.gd), or null (--no-ferry).
var ferry: Node3D
var motes: Array[Node3D] = []
var drone: Node3D
## What is on (flags).
var on := {"isles":true,"airships":true,"traffic":true,"life":true,"motes":true,"tokens":true,"serpent":true,"clouds":true}
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
	if args.has("--no-far-isles") or args.has("--no-motifs"): on.isles = false
	if args.has("--no-airships"): on.airships = false
	if args.has("--no-traffic"): on.traffic = false
	if args.has("--no-sky-life"): on.life = false
	if args.has("--no-motes"): on.motes = false
	if args.has("--no-sky-tokens"): on.tokens = false
	if args.has("--no-serpent"): on.serpent = false
	if args.has("--no-sky-clouds"): on.clouds = false
	if on.isles and _with_motifs(): _start_motifs(args)
	if on.airships: _build_airships()
	if on.traffic: _build_traffic()
	if on.clouds: _build_clouds()
	if on.life and motifs != null: _build_life()
	if on.motes: _build_motes()
	if on.tokens: _build_tokens()
	# The motif isles' sky (the aqueduct isle's, the game's) has no serpent
	# unless --serpent asks for it; the ferry shuttles between its isles.
	if on.serpent and (not _with_motifs() or args.has("--serpent")): _build_serpent()

# --- The motif isles ----------------------------------------------------------------

## Whether the scene asks for the motif isles (`wants_motifs`: the aqueduct
## isle, the game's scene).
func _with_motifs() -> bool:
	return scene.has_method("wants_motifs") and scene.wants_motifs()

## The four ruin motifs' isles, placed (scripts/kit_isle/motif_sky.gd): each
## built on a worker and stood a slice a frame within the sky's budget.
func _start_motifs(args: PackedStringArray) -> void:
	motifs = MotifSky.new()
	add_child(motifs)
	motifs.setup(scene,self,args)

## Where the motif isles stand: [id, middle (world; y its top), reach (m)]
## each, none without them (scripts/kit_isle/kit_clouds.gd keeps its towers
## and puffs off them); the dragon's roost too, with --dragon-roost.
func places() -> Array:
	return motifs.stood_places() if motifs != null else []

## Every motif isle stood up at once (tests, captures), and the towers whole.
func flush() -> void:
	if clouds != null: clouds.flush()
	if motifs != null: motifs.flush()

## True once every motif isle stands whole.
func isles_ready() -> bool:
	return motifs == null or motifs.all_stood()

## The highest ground or rock under a point (world), or null: what stands
## (physics: the aqueduct isle and the motif isles).
func ground(p: Vector3) -> Variant:
	var space := get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(p.x,260.0,p.z),Vector3(p.x,-200.0,p.z),SOLID_LAYER|TURF_LAYER)
	var hit := space.intersect_ray(ray)
	return (hit.position as Vector3).y if not hit.is_empty() else null

# --- Traffic ------------------------------------------------------------------------

## The game's CPU biplanes, lapping the motif isles and buzzing their tops;
## shown always (the game shows them in flight).
func _build_traffic() -> void:
	traffic = IsleTraffic.new()
	add_child(traffic)
	var slots: Array = []
	for place: Array in MotifSky.places(): slots.append(place[1])
	traffic.buzz = slots.duplicate()
	traffic.ground = ground
	traffic.build(self,slots)
	traffic.show(true)

## The cloud host, made after the traffic so it traces the planes once
## they have flown each frame, and flies them through its clouds.
func _build_clouds() -> void:
	clouds = KitClouds.new()
	add_child(clouds)
	clouds.setup_sky(scene,self)
	if traffic != null: clouds.hook(traffic)

## SkyTraffic's pilots here: what they buzz is this sky's motif isles, not
## the seeded cells' islets; through a drifting cloud as often as the game's
## (GOALS), when the cloud host flies them through its clouds.
class IsleTraffic extends SkyTraffic:
	var buzz: Array = []
	const CLOUD_SHARE := 0.3
	const BUZZ_SHARE := 0.35
	func _choose(plane: Dictionary) -> Dictionary:
		var rng: RandomNumberGenerator = plane.rng
		var at: Vector3 = plane.flight.position
		var roll := rng.randf()
		if roll < CLOUD_SHARE:
			var through := _through_cloud(plane)
			if not through.is_empty(): return through
		elif roll < CLOUD_SHARE+BUZZ_SHARE:
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
## slow loops (ROUTES); a body each for the plane to bump; the ferry on its
## own loop (scripts/kit_isle/airship_ferry.gd, its own body: he rides it);
## and the drone.
func _build_airships() -> void:
	for k in range(ROUTES.size()):
		var route: Array = ROUTES[k]
		var ship := _new_airship("Airship%d" % k)
		var body := AnimatableBody3D.new()
		body.name = "Solid"
		body.collision_layer = SOLID_LAYER
		body.collision_mask = 0
		body.sync_to_physics = false
		# The envelope as two capsules inside its teardrop (`envelope_solid`):
		# one capsule its whole length stood out round the tail's taper.
		for part: Vector3 in envelope_solid():
			var envelope := CollisionShape3D.new()
			var capsule := CapsuleShape3D.new()
			capsule.radius = part.z
			capsule.height = part.y-part.x+2.0*part.z
			envelope.shape = capsule
			envelope.transform = Transform3D(Basis(Vector3.RIGHT,PI*0.5),AirshipBuild.ENVELOPE_AT+Vector3(0.0,0.0,(part.x+part.y)*0.5))
			body.add_child(envelope)
		# The gondola as drawn (AirshipBuild `gondola_hulls`: the hull and
		# the cabin); one box round both stood out over the bow's taper
		# and the open deck.
		for points: PackedVector3Array in AirshipBuild.gondola_hulls():
			var gondola := CollisionShape3D.new()
			var hull := ConvexPolygonShape3D.new()
			hull.points = points
			gondola.shape = hull
			body.add_child(gondola)
		ship._ship.add_child(body)
		var points: Array = route[0]
		var length := 0.0
		for i in range(points.size()): length += (points[i] as Vector3).distance_to(points[(i+1)%points.size()])
		# Their phases round their loops as when a third flew before them.
		airships.append({"ship":ship,"points":points,"speed":float(route[1]),"length":length,
			"u":float(k+1)*0.37,"heading":0.0,"bank":0.0,"at":Vector3.ZERO})
		_place_airship(airships[-1],0.0)
	if AirshipFerry.wanted():
		var ship := _new_airship("Airship%d" % ROUTES.size(),false)
		ferry = AirshipFerry.new()
		add_child(ferry)
		ferry.setup(scene,ship)
		airships.append({"ship":ship,"ferry":true,"points":AirshipFerry.loop_points(),"at":ferry.at()})
	drone = GlideAir.new()
	drone.name = "AirshipDrone"
	add_child(drone)
	drone.start()
	drone.visible = false

## A ship of the sky folk's, made and shown, its tow gear hidden.
func _new_airship(ship_name: String, crewed := true) -> Node3D:
	var ship: Node3D = SkyAirship.new()
	ship.crewed = crewed
	ship.name = ship_name
	ship.scene = scene
	# No islets: the tow event never runs (`_process` waits on them).
	ship.islets = null
	add_child(ship)
	ship._make_ship()
	ship._ship.visible = true
	ship._lines.visible = false
	for g: MeshInstance3D in ship._grapples: g.visible = false
	ship._set_fade(0.0)
	return ship

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
		# The ferry is moved on by its own frame, ahead of the pilot's step.
		if a.has("ferry"): a.at = ferry.at()
		else: _place_airship(a,delta)
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

## The other islands' life (SkyAmbientLife) on this sky's isles: each motif
## isle once it stands, its gulls riding the thermals over its middle and
## its high points (it has no trees, so no songbird flock in a crown: its
## own songbirds are its life's), read through a stand-in of the islands it
## asks (`IsleHosts`).
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

## Each standing motif isle not yet known to the life, laid out for it (its
## gulls' columns: its middle and its summit), once.
func _advance_life(delta: float, eye: Vector3) -> void:
	for isle: Node3D in motifs.isles:
		var key := str(isle.name)
		if _hosts.known.has(key) or not isle.stands(): continue
		_hosts.known[key] = true
		var c: Vector3 = isle.circle()
		var top: float = isle.isle_top()
		var under: Variant = ground(Vector3(c.x,0.0,c.y))
		var middle := Vector3(c.x,float(under) if under != null else top,c.y)
		var columns: Array[Vector3] = [middle,isle.isle_summit()]
		_hosts.add(isle,Vector3(c.x,top,c.y),{"middle":middle,"trees":[],"columns":columns,"chaff":[]})
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
## size) and round the two motif isles nearest it.
func _build_motes() -> void:
	var spots := [[MIDDLE+Vector3(0.0,-6.0,0.0),2.0]]
	var near: Array = MotifSky.places()
	near.sort_custom(func(a: Array, b: Array) -> bool: return (a[1] as Vector3).distance_to(MIDDLE) < (b[1] as Vector3).distance_to(MIDDLE))
	for place: Array in near.slice(0,2): spots.append([(place[1] as Vector3)+Vector3(0.0,6.0,0.0),1.6])
	for s: Array in spots:
		var m: Node3D = SkyMotes.new()
		m.position = s[0]
		m.scale = Vector3.ONE*float(s[1])
		add_child(m)
		m.set_strength(0.75)
		motes.append(m)

# --- Tokens -------------------------------------------------------------------------

## The tokens (SkyCollectibles): one source of hand-laid lines in world
## coordinates on its own (no seeded trails, islets or clusters lay any),
## and each motif isle's, moved to where it stands; the plane (and the
## pilot) take them as the game's do, with its readout, blip and run.
func _build_tokens() -> void:
	collectibles = SkyCollectibles.new()
	collectibles.cells = SkyCells.new()
	collectibles.seed_value = TOKEN_SEED
	collectibles._trails_laid = true
	add_child(collectibles)
	var lines: Array = []
	for t: Array in plane_tokens():
		lines.append(Lines.line(t[0],t[1],t[2],PackedVector3Array(t[3]),TOKEN_SEED))
	collectibles.add_source(token_source(),lines)
	if motifs != null: motifs.add_tokens(collectibles,TOKEN_SEED)

## The plane's tokens: [line id, category, kind, points (world)]. A kit
## isle's sky (a subclass) answers with its own.
func plane_tokens() -> Array:
	return TOKENS

## The tokens' source name on the collectibles.
func token_source() -> String:
	return "aqueduct"

# --- The rune serpent ---------------------------------------------------------------

## The rune serpent (scripts/rune_serpent.gd): self-contained, it runs its
## own frame and physics frame and reads the study's camera and plane. With
## the motif isles (only with --serpent) it flies the route between them
## (`route`, scripts/kit_isle/serpent_route.gd: the ledges and the rider),
## unless --serpent-old-route.
var serpent: Node3D
var route: Node3D

func _build_serpent() -> void:
	if motifs != null and SerpentRoute.wanted():
		route = SerpentRoute.new()
		add_child(route)
		serpent = route.setup(scene,self)
		return
	serpent = RuneSerpent.new()
	add_child(serpent)
	serpent.setup(scene)

# --- Each frame ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if scene == null or scene.camera == null: return
	_clock += delta
	var eye: Vector3 = scene.camera.global_position
	if not airships.is_empty(): _advance_airships(delta,eye)
	if life != null and motifs != null: _advance_life(delta,eye)
	if collectibles != null:
		collectibles.advance(delta,eye)
		if scene.flying and scene.plane_figure != null: collectibles.touch_plane(scene.plane_figure.global_position)
		elif scene.figure != null: collectibles.touch_walker(scene.figure.global_position+Vector3.UP*Lines.WALKER_MIDDLE)

## The airship envelope's solid: capsules (z from, z to along it from its
## middle, radius) inside the drawn teardrop (AirshipBuild
## `envelope_radius`): a fat middle and a long slimmer one to the nose and
## down the tail, each ENVELOPE_INSIDE of the profile where it is thinnest.
const ENVELOPE_INSIDE := 0.92
static func envelope_solid() -> Array[Vector3]:
	var h := AirshipBuild.ENVELOPE_LENGTH*0.5
	var out: Array[Vector3] = []
	for span: Vector2 in [Vector2(-0.35,0.2),Vector2(-0.75,0.6)]:
		var r := minf(AirshipBuild.envelope_radius(span.x*h),AirshipBuild.envelope_radius(span.y*h))*ENVELOPE_INSIDE
		out.append(Vector3(span.x*h,span.y*h,r))
	return out
