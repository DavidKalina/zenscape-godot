extends Node3D
## A copy of the aqueduct isle's (studies/aqueduct_isle_life.gd) wired to the
## bell spires isle's art (studies/bell_spires_isle_art.gd); an extraction
## candidate for a shared kit isle builder (docs/scenic/bell-spires.md).
## Life on the aqueduct isle (docs/scenic/aqueduct-isle-life.md), all of it
## the game's own systems wired to the isle's ground:
##
## - undergrowth at the ruins' feet (studies/aqueduct_isle_undergrowth.gd:
##   the game's fern, shrub, mushroom, leaf bed and mossy log);
## - butterflies over the flower patches (scripts/life_butterflies.gd, fed a
##   survey of the isle's own meadow flowers, one per patch) and fireflies
##   over the undergrowth at dusk (studies/fireflies.gd);
## - songbirds on the stones (studies/aqueduct_isle_birds.gd, the game's
##   songbirds perched on parapets, lintels and stumps);
## - the wind made visible: the breeze ribbons riding the gust fronts
##   (scripts/breeze_ribbons.gd, through the atmosphere, so the grass and
##   vines bow in their wake), loose leaves at the ruins' feet
##   (scripts/wind_leaf_litter.gd), grass chaff on the meadow
##   (scripts/wind_grass_chaff.gd) and blades a sweeping ribbon kicks up
##   (scripts/wind_kicked_blades.gd);
## - a few on-foot tokens, each a move (studies/aqueduct_isle_tokens.gd).
##
## The isle's ground is read once into a grid (`ground_at`: the turf's top,
## null off it; `standing_at`: something built stands over the turf there),
## so the creatures and the loose bits ask it, not the physics space.
##
## Every part is on by default; each has its opt-out (`--no-undergrowth`,
## `--no-butterflies`, `--no-fireflies`, `--no-birds`, `--no-wind-life`,
## `--no-tokens`), and `--no-life` leaves all of it out.
const Art = preload("res://studies/bell_spires_isle_art.gd")
const Undergrowth = preload("res://studies/bell_spires_isle_undergrowth.gd")
const Birds = preload("res://studies/bell_spires_isle_birds.gd")
const Tokens = preload("res://studies/bell_spires_isle_tokens.gd")
const Butterflies = preload("res://scripts/life_butterflies.gd")
const Fireflies = preload("res://studies/fireflies.gd")
const Survey = preload("res://scripts/life_survey.gd")
const LeafLitter = preload("res://scripts/wind_leaf_litter.gd")
const GrassChaff = preload("res://scripts/wind_grass_chaff.gd")
const KickedBlades = preload("res://scripts/wind_kicked_blades.gd")
const Lines = preload("res://scripts/collectible_lines.gd")

## The isle's turf layer (studies/aqueduct_isle.gd TURF_LAYER) and the
## undergrowth's seed.
const TURF_LAYER := 1 << 11
const UNDERGROWTH_SEED := 32
## The ground grid's cell (m), and what counts as standing over the turf.
const CELL := 0.6
const STANDING := 0.8
## Butterflies: the flower patches they keep to (PATCH m tiles, the PATCHES
## fullest), and at most PATCH_FLOWERS flowers of each (a butterfly for
## every five: life_butterflies.gd FLOWERS_EACH).
const PATCH := 16.0
const PATCHES := 4
const PATCH_FLOWERS := 30
## Fireflies: how many, over the undergrowth, and their height (m).
const FIREFLIES := 70
const FIREFLY_HEIGHT := Vector2(0.4,1.8)
## The loose leaves' anchors at most (ruin feet, shrubs, logs), and the
## meadow the chaff lies on (world rect).
const LEAF_ANCHORS := 24
const CHAFF_MEADOW := Rect2(88.0,-14.0,22.0,16.0)

var scene: Node3D
var flags := {}
var undergrowth: Node3D
var meadows: Array[Node3D] = []
var fireflies: MultiMeshInstance3D
var birds: Node3D
var tokens: Node3D
var leaf_litter: MultiMeshInstance3D
var grass_chaff: MultiMeshInstance3D
var kicked_blades: MultiMeshInstance3D
## The ground grid: origin, size in cells, turf heights (NAN off the turf),
## and 1 where something built stands over it.
var _origin := Vector2.ZERO
var _w := 0
var _h := 0
var _heights := PackedFloat32Array()
var _standing := PackedByteArray()
## What each part cost to set up (ms), for the handoff and tests.
var timings := {}

static func wanted(args: PackedStringArray) -> Dictionary:
	var all := not args.has("--no-life")
	return {"undergrowth":all and not args.has("--no-undergrowth"),"butterflies":all and not args.has("--no-butterflies"),
		"fireflies":all and not args.has("--no-fireflies"),"birds":all and not args.has("--no-birds"),
		"wind":all and not args.has("--no-wind-life"),"tokens":all and not args.has("--no-tokens")}

func setup(isle: Node3D, args: PackedStringArray) -> void:
	scene = isle
	name = "Life"
	flags = wanted(args)
	var space := scene.get_world_3d().direct_space_state
	var t := Time.get_ticks_msec()
	_read_ground(space)
	timings.ground = Time.get_ticks_msec()-t
	if flags.undergrowth:
		t = Time.get_ticks_msec()
		undergrowth = Undergrowth.grow(UNDERGROWTH_SEED,space,scene._turf,scene._outlines)
		add_child(undergrowth)
		timings.undergrowth = Time.get_ticks_msec()-t
	if flags.butterflies and scene.flora != null: _meadows()
	if flags.fireflies: _fireflies()
	if flags.wind:
		t = Time.get_ticks_msec()
		_wind()
		timings.wind = Time.get_ticks_msec()-t
	if flags.birds:
		t = Time.get_ticks_msec()
		birds = Birds.new()
		add_child(birds)
		birds.setup(scene,ground_at)
		timings.birds = Time.get_ticks_msec()-t
	if flags.tokens:
		tokens = Tokens.new()
		add_child(tokens)
		tokens.setup(scene)

# --- The ground -----------------------------------------------------------------------

## Reads the isle's turf (its ground bodies on the scene's TURF_LAYER) and
## what is built over it into the grid.
func _read_ground(space: PhysicsDirectSpaceState3D) -> void:
	var box := Rect2()
	for i in range(scene._outlines.size()):
		var outline: PackedVector2Array = scene._outlines[i]
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	box = box.grow(1.0)
	_origin = box.position
	_w = int(ceil(box.size.x/CELL))+1
	_h = int(ceil(box.size.y/CELL))+1
	_heights.resize(_w*_h)
	_standing.resize(_w*_h)
	var turf := PhysicsRayQueryParameters3D.new()
	turf.collision_mask = TURF_LAYER
	var all := PhysicsRayQueryParameters3D.new()
	for j in range(_h):
		for i in range(_w):
			var p := _origin+Vector2(i,j)*CELL
			turf.from = Vector3(p.x,Art.TOP+60.0,p.y)
			turf.to = Vector3(p.x,Art.TOP-10.0,p.y)
			var hit := space.intersect_ray(turf)
			var k := j*_w+i
			if hit.is_empty() or (hit.normal as Vector3).y < 0.3:
				_heights[k] = NAN
				_standing[k] = 0
				continue
			var y: float = (hit.position as Vector3).y
			_heights[k] = y
			all.from = turf.from
			all.to = Vector3(p.x,y-0.05,p.y)
			var top := space.intersect_ray(all)
			_standing[k] = 1 if not top.is_empty() and (top.position as Vector3).y > y+STANDING else 0

## The turf's height at `p` (world x, z), or null off it.
func ground_at(p: Vector2) -> Variant:
	var f := (p-_origin)/CELL
	var i := int(floor(f.x))
	var j := int(floor(f.y))
	if i < 0 or j < 0 or i >= _w-1 or j >= _h-1: return null
	var a := _heights[j*_w+i]
	var b := _heights[j*_w+i+1]
	var c := _heights[(j+1)*_w+i]
	var d := _heights[(j+1)*_w+i+1]
	var u := f.x-i
	var v := f.y-j
	if is_nan(a) or is_nan(b) or is_nan(c) or is_nan(d):
		var nearest := _heights[(j+int(round(v)))*_w+i+int(round(u))]
		return null if is_nan(nearest) else nearest
	return lerpf(lerpf(a,b,u),lerpf(c,d,u),v)

## True where something built stands over the turf at `p`.
func standing_at(p: Vector2) -> bool:
	var f := ((p-_origin)/CELL).round()
	var i := int(f.x)
	var j := int(f.y)
	if i < 0 or j < 0 or i >= _w or j >= _h: return false
	return _standing[j*_w+i] == 1

## Open grass at `p`: turf, nothing standing over it, off the worn paths.
func grass_at(p: Vector2) -> float:
	if ground_at(p) == null or standing_at(p): return 0.0
	return 1.0-smoothstep(0.1,0.5,Art.path_wear(p))

# --- Butterflies and fireflies ------------------------------------------------------

## A flower patch's butterflies: life_butterflies.gd's owner as LandLife is
## to it (its survey, clock, material and scene), holding one patch's
## flowers.
class Meadow extends Node3D:
	var scene: Node3D
	var material: Material
	var survey: RefCounted
	var salt := 0
	var flies: Node3D
	func _season() -> float:
		# The look presets' surface weather stands in for the year: snow is
		# winter, autumn is autumn, else high summer.
		var weather: Variant = scene._precipitation.surface_weather
		if float(weather.cold) > 0.5: return 0.875
		if float(weather.autumn) > 0.5: return 0.625
		return 0.375
	func _daylight() -> float:
		return float(scene._celestial.state.get("zs_daylight",1.0))

## LifeSurvey's part the butterflies read: the flowers' spots and heads,
## and the ground under them.
class FlowerSurvey extends RefCounted:
	var flower_spots := PackedVector2Array()
	var flower_tops := PackedFloat32Array()
	var ground: Callable
	func ground_at(p: Vector2) -> float:
		var h: Variant = ground.call(p)
		return NAN if h == null else float(h)

## The meadow flowers' fullest patches, a Meadow each.
func _meadows() -> void:
	var tiles := {}
	for item: Dictionary in scene.flora.get_meta("records"):
		if item.asset == "grass_tuft": continue
		var key := Vector2i(floori(float(item.x)/PATCH),floori(float(item.z)/PATCH))
		if not tiles.has(key): tiles[key] = []
		(tiles[key] as Array).append(item)
	var keys: Array = tiles.keys()
	keys.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (tiles[a] as Array).size() > (tiles[b] as Array).size())
	var material := life_material()
	for n in range(mini(PATCHES,keys.size())):
		var items: Array = tiles[keys[n]]
		if items.size() < Butterflies.FLOWERS_MIN: continue
		var survey := FlowerSurvey.new()
		survey.ground = ground_at
		var step := maxi(1,items.size()/PATCH_FLOWERS)
		for k in range(0,items.size(),step):
			var item: Dictionary = items[k]
			survey.flower_spots.append(Vector2(float(item.x),float(item.z)))
			survey.flower_tops.append(Survey._flower_top(str(item.asset),item))
		var meadow := Meadow.new()
		meadow.name = "Meadow_%d" % n
		meadow.scene = scene
		meadow.material = material
		meadow.survey = survey
		meadow.salt = 7+n*31
		add_child(meadow)
		var flies: Node3D = Butterflies.new()
		meadow.add_child(flies)
		flies.setup(meadow)
		meadow.flies = flies
		# Their batches are boxed for the plate round the origin: box them
		# round the patch instead.
		var middle := Vector3((keys[n].x+0.5)*PATCH,Art.TOP,(keys[n].y+0.5)*PATCH)
		for child in flies.get_children():
			if child is MultiMeshInstance3D:
				(child as MultiMeshInstance3D).multimesh.custom_aabb = AABB(middle-Vector3(PATCH,4.0,PATCH),Vector3(PATCH*2.0,20.0,PATCH*2.0))
		meadows.append(meadow)

## The faceted life material LandLife shares (the Fidelity reference's
## creature material: the reference surface, flat faces).
static func life_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/reference_surface.gdshader")
	material.set_shader_parameter("flat_faces",true)
	material.set_shader_parameter("roughness_value",0.7)
	material.set_shader_parameter("base_color",Color.WHITE)
	return material

## Fireflies over the undergrowth (or the flowers without it), lit at dusk.
func _fireflies() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6113
	var roots: Array = []
	if undergrowth != null:
		for item: Dictionary in undergrowth.get_meta("records"):
			if item.asset in ["fern","shrub","log"]: roots.append(Vector2(float(item.x),float(item.z)))
	elif scene.flora != null:
		for item: Dictionary in scene.flora.get_meta("records"):
			if item.asset != "grass_tuft": roots.append(Vector2(float(item.x),float(item.z)))
	if roots.is_empty(): return
	var data := {"positions":[],"phase":[],"amplitude":[],"rate":[]}
	for n in range(FIREFLIES):
		var root: Vector2 = roots[rng.randi_range(0,roots.size()-1)]+Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(0.0,1.5)
		var h: Variant = ground_at(root)
		if h == null: continue
		data.positions.append_array([root.x,float(h)+rng.randf_range(FIREFLY_HEIGHT.x,FIREFLY_HEIGHT.y),root.y])
		data.phase.append(rng.randf())
		data.amplitude.append(rng.randf_range(0.12,0.42))
		data.rate.append(rng.randf())
	fireflies = Fireflies.new()
	fireflies.name = "Fireflies"
	add_child(fireflies)
	fireflies.setup(data)

# --- The wind made visible ----------------------------------------------------------

## The breeze ribbons through the atmosphere (they ride its gust fronts and
## bow what they pass over), lifted over what is built as over a wood; the
## loose leaves at the ruins' feet, the chaff on the meadow, the blades a
## sweep kicks up.
func _wind() -> void:
	var atmosphere: Node = scene._atmosphere
	# Off the turf (over the sky between the islands) a ribbon keeps to the
	# islands' height rather than drop to the world's zero.
	var ride := func(p: Vector2) -> Variant:
		var h: Variant = ground_at(p)
		return h if h != null else Art.TOP
	atmosphere.setup_wind_trails(ride,false)
	var trails: Node = atmosphere.wind_trails
	if trails.has_method("set_canopy"): trails.set_canopy(func(p: Vector2) -> float: return 0.6 if standing_at(p) else 0.0)
	var box := AABB(Vector3(_origin.x,Art.TOP-6.0,_origin.y),Vector3(_w*CELL,44.0,_h*CELL))
	leaf_litter = LeafLitter.new()
	leaf_litter.custom_aabb = box
	add_child(leaf_litter)
	leaf_litter.seed_from(_leaf_anchors(),ground_at)
	grass_chaff = GrassChaff.new()
	grass_chaff.custom_aabb = box
	add_child(grass_chaff)
	var meadow := CHAFF_MEADOW
	var count := GrassChaff.count_for(meadow.get_area()*0.8)
	grass_chaff.seed_from(GrassChaff.anchors_on(grass_at,count,meadow),ground_at)
	kicked_blades = KickedBlades.new()
	kicked_blades.custom_aabb = box
	add_child(kicked_blades)
	kicked_blades.setup(ground_at,grass_at)

## Where loose leaves gather: at the feet of the ruins the walker passes
## (the castellum, the blind wall, the heel stone, the gate), by the
## undergrowth's shrubs and logs.
func _leaf_anchors() -> Array:
	var anchors: Array = []
	var l: Dictionary = Art.layout()
	anchors.append(Vector2(l.start.x,l.start.z))
	for name: String in ["hero","low","fin_low","fin_high"]:
		var s: Dictionary = l.spires[name]
		var c: Vector2 = s.c
		var toward := (Vector2(l.start.x,l.start.z)-c).normalized()
		anchors.append(c+toward*(float(s.r)*1.18+0.6))
	if undergrowth != null:
		var rng := RandomNumberGenerator.new()
		rng.seed = 233
		var picks: Array = []
		for item: Dictionary in undergrowth.get_meta("records"):
			if item.asset in ["shrub","log","leaf_bed"]: picks.append(Vector2(float(item.x),float(item.z)))
		while anchors.size() < LEAF_ANCHORS and not picks.is_empty():
			anchors.append(picks.pop_at(rng.randi_range(0,picks.size()-1)))
	return anchors

# --- Each frame ---------------------------------------------------------------------

## One frame of the isle's life, after the look (its air, its light).
func advance(delta: float) -> void:
	if delta <= 0.0: return
	var day := float(scene._celestial.state.get("zs_daylight",1.0))
	for meadow in meadows: meadow.flies.advance(delta)
	if fireflies != null:
		var weather: Variant = scene._precipitation.surface_weather
		fireflies.update_conditions(day,float(scene._precipitation.state.x),float(weather.cold),1.0)
	var atmosphere: Node = scene._atmosphere
	if flags.wind and atmosphere.wind_trails != null:
		var fronts: RefCounted = atmosphere.fronts
		atmosphere.wind_trails.set_bounds(fronts.center,fronts.radius)
		leaf_litter.advance(delta,false,atmosphere)
		grass_chaff.advance(delta,false,atmosphere)
		kicked_blades.advance(delta,false,atmosphere.wind_trails,atmosphere)
	if birds != null: birds.advance(delta)
	if tokens != null: tokens.glow_for(1.0-smoothstep(0.1,0.5,day))

## After each step of the pilot on foot (or the plane): his middle takes
## the tokens he reaches.
func step_pilot() -> void:
	if tokens == null: return
	if bool(scene.get("flying")): tokens.touch(Vector3.INF)
	else: tokens.touch(scene.motor.feet+Vector3.UP*Lines.FOOT_Y)
