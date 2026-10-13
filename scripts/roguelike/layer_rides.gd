extends Node3D
## The rides over a generated layer's gulfs (docs/design/roguelike/
## layer-round3.md; scripts/roguelike/layer_plan.gd `_gulf`), each the
## game's own set piece on a loop the plan laid for that gulf:
##   - a rune serpent (scripts/rune_serpent.gd) on its own SerpentRoute
##     (scripts/kit_isle/serpent_route.gd: the route's ledges, here long
##     piers jutting off each rim, and its rider, serpent_rider.gd): it runs
##     straight past each pier every lap, a schedule to learn and wait for;
##   - or the sky folk's ferry (scripts/kit_isle/airship_ferry.gd, its ship
##     scripts/sky_airship.gd's) shuttling between a pier at each rim,
##     resting HOLD s at each.
## A gulf narrow enough also has a cannon behind its near rim (the stage's
## CannonField), aimed over it.
##
## A far neighbourhood's isles are built on a worker after the near ones
## (scripts/kit_isle/motif_sky.gd, nearest first), so a gulf's crossings
## open only once the isles at both its ends stand (`ready`): till then
## no pier stands to board from (the serpent flies by, out of reach), the
## ferry waits at the near pier, and there is no cannon.
const SerpentRoute = preload("res://scripts/kit_isle/serpent_route.gd")
const AirshipFerry = preload("res://scripts/kit_isle/airship_ferry.gd")
const SkyAirship = preload("res://scripts/sky_airship.gd")
const LayerPlan = preload("res://scripts/roguelike/layer_plan.gd")

var study: Node3D
var plan: Dictionary
var stage: Node3D
## Each gulf's: {edge, ride, a, b (its isles), route (a SerpentRoute) or
## ferry, ship and piers ([spec, node]), ready, cannon (or null)}.
var gulfs: Array[Dictionary] = []
## When each gulf opened (ms since the stage was made), -1 not yet.
var _made := 0

func _init() -> void:
	name = "Rides"

func setup(scene: Node3D, layer: Dictionary, owner_stage: Node3D) -> void:
	study = scene
	plan = layer
	stage = owner_stage
	_made = Time.get_ticks_msec()
	for gi: int in layer.gulfs:
		var e: Dictionary = layer.edges[gi]
		var g := {"edge":e,"ride":str(e.ride),"a":int(e.from[0]),"b":int(e.to[0]),"ready":false,"cannon":null,"opened_ms":-1}
		# A ring's serpent opens once every isle it passes stands
		# (scripts/roguelike/layer_ring.gd `stops`); a "cannon" gulf has no
		# ride, only its cannon.
		g.isles = e.get("stops",[g.a,g.b])
		if g.ride == "serpent": g.route = _serpent(e,gulfs.size())
		elif g.ride == "ferry": _ferry(e,g,gulfs.size())
		gulfs.append(g)
	_open_ready()

## The isle's name for a ride's spot: the base's "aqueduct", else isle<i>.
static func isle_name(i: int) -> String:
	return "aqueduct" if i == 0 else "isle%d" % i

## The motif isle node of plan isle `i` (the sky's, in plan order), or null.
func isle_node(i: int) -> Node3D:
	var sky: Variant = study.get("sky")
	if sky == null or sky.motifs == null or i < 1 or i-1 >= (sky.motifs.isles as Array).size(): return null
	return sky.motifs.isles[i-1]

func _lookup(id: String) -> Node3D:
	return isle_node(int(id.trim_prefix("isle"))) if id.begins_with("isle") else null

## Whether plan isle `i` stands.
func isle_up(i: int) -> bool:
	if i == 0: return true
	var node := isle_node(i)
	return node != null and node.is_up()

func _serpent(e: Dictionary, n: int) -> Node3D:
	var s: Dictionary = e.serpent
	var route: Node3D = SerpentRoute.new()
	route.name = "Serpent%d" % n
	route.route_points = s.points
	route.route_marks = s.marks
	route.start_mark = str(s.start)
	var specs: Array = []
	for spot: Dictionary in s.spots:
		specs.append([str(spot.name),isle_name(int(spot.isle)),str(spot.name),[str(spot.name)],float(spot.side)])
	route.spot_specs = specs
	route.isle_lookup = _lookup
	# A ring's serpent (many piers) builds each as its isle stands.
	route.auto_build = e.has("stops")
	route.ledge_deep = LayerPlan.LEDGE_JUT+LayerPlan.PIER_OVER
	add_child(route)
	route.holder = route
	route.setup(study,study.sky)
	return route

func _ferry(e: Dictionary, g: Dictionary, n: int) -> void:
	var ship: Node3D = SkyAirship.new()
	ship.name = "FerryShip%d" % n
	ship.scene = study
	# No islets: the tow event never runs.
	ship.islets = null
	add_child(ship)
	ship._make_ship()
	ship._ship.visible = true
	ship._lines.visible = false
	for grapple: MeshInstance3D in ship._grapples: grapple.visible = false
	ship._set_fade(0.0)
	var ferry: Node3D = AirshipFerry.new()
	ferry.name = "Ferry%d" % n
	ferry.route = e.ferry.route
	ferry.envelope_parts = study.sky.envelope_solid()
	add_child(ferry)
	ferry.setup(study,ship)
	ferry.set_clock(ferry.clock_before("a",-1.0))
	g.ferry = ferry
	g.ship = ship
	g.piers = []
	for p: Dictionary in e.ferry.piers: g.piers.append([p.duplicate(),null])

## Every gulf whose two isles stand opened: its piers built, its cannon set.
func _open_ready() -> void:
	for g: Dictionary in gulfs:
		if g.ready or not (g.isles as Array).all(isle_up): continue
		g.ready = true
		g.opened_ms = Time.get_ticks_msec()-_made
		if g.has("route"):
			for s: Dictionary in g.route.spots: if s.built == null: g.route.build(s)
		elif g.has("piers"):
			var space := get_world_3d().direct_space_state
			for pier: Array in g.piers:
				var node := SerpentRoute.make_ledge(space,pier[0],LayerPlan.LEDGE_JUT+LayerPlan.PIER_OVER)
				node.name = "Pier_%s" % str(pier[0].id)
				add_child(node)
				pier[1] = node
		var c: Dictionary = g.edge.get("cannon",{})
		if not c.is_empty():
			g.cannon = stage.cannons.add_cannon(c.at,float(c.heading),{"speed_max":float(c.speed)})
			for at: Vector3 in c.kegs: stage.cannons.add_keg(at)

## Whether every gulf is open.
func all_open() -> bool:
	return gulfs.all(func(g: Dictionary) -> bool: return g.ready)

func _process(delta: float) -> void:
	_open_ready()
	for g: Dictionary in gulfs:
		if not g.has("ferry"): continue
		# Waiting at the near pier till the far isle stands.
		if not g.ready: g.ferry.set_clock(g.ferry.clock_before("a",-1.0))
		for p: Node3D in g.ship._props: p.rotate_object_local(Vector3.BACK,14.0*delta)

# --- The schedule -----------------------------------------------------------------

## A line for the card: the ride at the pier nearest `feet` (within NEAR m),
## when it comes or goes; "" for none near.
const NEAR := 45.0
## The serpent's middle (m back from its snout), what a boarder jumps for.
const MIDDLE := 30.0
func schedule(feet: Vector3) -> String:
	var best := ""
	var near := NEAR
	for g: Dictionary in gulfs:
		var piers: int = (g.route.spots as Array).size() if g.has("route") else (g.piers as Array).size() if g.has("piers") else 0
		for k in range(piers):
			var at := _pier_at(g,k)
			var d := Vector2(at.x-feet.x,at.z-feet.z).length()
			if d >= near: continue
			near = d
			best = _when(g,k)
	return best

## Where the pier at end `k` (0 near, 1 far) of gulf `g` stands (its end).
func _pier_at(g: Dictionary, k: int) -> Vector3:
	if g.has("route"): return (g.route.spots[k].end as Vector3)
	return (g.piers[k][0].end as Vector3)

func _when(g: Dictionary, k: int) -> String:
	if not g.ready: return "The far isles are still rising: no ride yet"
	if g.has("route"):
		var route: Node3D = g.route
		var serpent: Node3D = route.serpent
		var at := float(route.spots[k].at)
		var go := fposmod(at+MIDDLE-float(serpent.s),float(serpent.route_length))
		var pace := maxf(float(serpent.speed()),1.0)
		return "Serpent by this pier in %d s" % roundi(go/pace)
	var ferry: Node3D = g.ferry
	var n := "ab"[k]
	if ferry.resting() == n:
		var s: Dictionary = ferry.stop(n)
		return "Ferry here: it leaves in %d s" % roundi(float(s.at)+AirshipFerry.HOLD-float(ferry.clock)) if float(ferry.clock) >= float(s.at) else "Ferry here"
	return "Ferry here in %d s (every %d s)" % [roundi(fposmod(float(ferry.stop(n).at)-float(ferry.clock),float(ferry.lap))),roundi(float(ferry.lap))]

