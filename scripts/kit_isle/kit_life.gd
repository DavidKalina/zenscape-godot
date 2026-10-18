extends Node3D
## Life on a kit isle (docs/scenic/kit-isle-shared.md; the aqueduct isle's,
## docs/scenic/aqueduct-isle-life.md, made every motif's), all of it the
## game's own systems wired to the isle's ground:
##
## - undergrowth at the ruins' feet (KitFlora `undergrowth`: the game's fern,
##   shrub, mushroom, leaf bed and mossy log);
## - butterflies over the flower patches (scripts/life_butterflies.gd, fed a
##   survey of the isle's own meadow flowers, one per patch) and fireflies
##   over the undergrowth at dusk (studies/fireflies.gd);
## - songbirds on the stones (`make_birds`, a scripts/kit_isle/kit_birds.gd
##   with the isle's perches);
## - the wind made visible: the breeze ribbons riding the gust fronts
##   (scripts/breeze_ribbons.gd, through the atmosphere, so the grass and
##   vines bow in their wake), loose leaves at the ruins' feet
##   (scripts/wind_leaf_litter.gd), grass chaff on the meadow
##   (scripts/wind_grass_chaff.gd) and blades a sweeping ribbon kicks up
##   (scripts/wind_kicked_blades.gd);
## - a few on-foot tokens, each a move (`make_tokens`, a scripts/kit_isle/
##   kit_tokens.gd with the isle's spots).
##
## The isle's ground is read once into a grid (`ground_at`: the turf's top,
## null off it; `standing_at`: something built stands over the turf there),
## so the creatures and the loose bits ask it, not the physics space.
##
## An isle's life extends this and answers its hooks: `make_birds`,
## `make_tokens`, `chaff_meadow` (or `chaff_anchors`), `leaf_spots`, and
## where its ground lies (`ground_span`, `wind_box`, `ride_y`); its scene
## gives its top (`isle_top`) and its ground's site (`flora_site`, a
## KitFlora.Site: its worn paths, its water).
##
## Every part is on by default; each has its opt-out (`--no-undergrowth`,
## `--no-butterflies`, `--no-fireflies`, `--no-birds`, `--no-wind-life`,
## `--no-tokens`), and `--no-life` leaves all of it out.
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
## The loose leaves' anchors at most (ruin feet, shrubs, logs).
const LEAF_ANCHORS := 24

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
## A placed isle (scripts/kit_isle/motif_isle.gd): where it stands from its
## own frame, which its hooks answer in (`top`, `ground_span`, `ride_y`,
## `chaff_meadow`, `leaf_spots`, the birds' perches and the tokens' spots
## are moved by it); and whether it shares the scene's wind (the home
## isle's life set up the breeze ribbons, which are the atmosphere's one).
var offset := Vector3.ZERO
var shares_wind := false
## The staged setup (`begin`, then `step`): the part it is at, the ground
## grid's next row, the undergrowth's job.
var _stage := 0
var _row := 0
var _col := 0
var _under: KitFlora.Undergrow

static func wanted(args: PackedStringArray) -> Dictionary:
	var all := not args.has("--no-life")
	return {"undergrowth":all and not args.has("--no-undergrowth"),"butterflies":all and not args.has("--no-butterflies"),
		"fireflies":all and not args.has("--no-fireflies"),"birds":all and not args.has("--no-birds"),
		"wind":all and not args.has("--no-wind-life"),"tokens":all and not args.has("--no-tokens")}

func setup(isle: Node3D, args: PackedStringArray) -> void:
	begin(isle,args)
	while not step(-1): pass

## The setup in steps (a placed isle's, a slice a frame): `begin`, then
## `step(usec)` until it answers true, each working on for about `usec`
## (-1: to the end). The same life as `setup`.
func begin(isle: Node3D, args: PackedStringArray) -> void:
	scene = isle
	name = "Life"
	flags = wanted(args)
	_stage = 0
	_row = 0
	_col = 0

func step(usec: int) -> bool:
	var end := Time.get_ticks_usec()+usec
	var space := scene.get_world_3d().direct_space_state
	var t := Time.get_ticks_msec()
	if _stage == 0:
		if _row == 0 and _col == 0: _ground_grid()
		var done := _read_rows(space,end if usec >= 0 else -1)
		timings.ground = int(timings.get("ground",0))+Time.get_ticks_msec()-t
		if not done: return false
		_stage = 1
		if usec >= 0 and Time.get_ticks_usec() > end: return false
	if _stage == 1:
		if flags.undergrowth:
			t = Time.get_ticks_msec()
			if _under == null: _under = undergrowth_job(space)
			var done := _under.step(maxi(end-Time.get_ticks_usec(),0) if usec >= 0 else -1)
			timings.undergrowth = int(timings.get("undergrowth",0))+Time.get_ticks_msec()-t
			if not done: return false
			undergrowth = _under.node
			_under = null
			add_child(undergrowth)
		_stage = 2
		if usec >= 0 and Time.get_ticks_usec() > end: return false
	if _stage == 2:
		if flags.butterflies and scene.flora != null: _meadows()
		if flags.fireflies: _fireflies()
		_stage = 3
		if usec >= 0 and Time.get_ticks_usec() > end: return false
	if _stage == 3:
		if flags.wind:
			t = Time.get_ticks_msec()
			_wind()
			timings.wind = Time.get_ticks_msec()-t
		_stage = 4
		if usec >= 0 and Time.get_ticks_usec() > end: return false
	if _stage == 4:
		if flags.birds:
			t = Time.get_ticks_msec()
			birds = make_birds()
			if birds != null:
				birds.set("offset",offset)
				add_child(birds)
				birds.setup(scene,ground_at)
			timings.birds = Time.get_ticks_msec()-t
		if flags.tokens:
			tokens = make_tokens()
			if tokens != null:
				tokens.set("offset",offset)
				add_child(tokens)
				tokens.setup(scene)
		_stage = 5
	return true

## True once the staged setup is done.
func is_set_up() -> bool:
	return _stage >= 5

# --- The isle's hooks -------------------------------------------------------------------

## The isle's datum (its own frame's y): its scene's `isle_top`.
func top() -> float:
	return float(scene.isle_top())-offset.y

## The undergrowth (KitFlora `undergrowth` over the scene's turf and site).
func make_undergrowth(space: PhysicsDirectSpaceState3D) -> Node3D:
	return KitFlora.undergrowth(UNDERGROWTH_SEED,space,scene._turf,scene._outlines,scene.flora_site())

## The undergrowth's job, in steps (as `make_undergrowth`).
func undergrowth_job(space: PhysicsDirectSpaceState3D) -> KitFlora.Undergrow:
	return KitFlora.Undergrow.new(UNDERGROWTH_SEED,space,scene._turf,scene._outlines,scene.flora_site())

## The songbirds (a scripts/kit_isle/kit_birds.gd), or null for none.
func make_birds() -> Node3D:
	return null

## The on-foot tokens (a scripts/kit_isle/kit_tokens.gd), or null for none.
func make_tokens() -> Node3D:
	return null

## The ground grid's rays (y from, to, in the isle's frame).
func ground_span() -> Vector2:
	return Vector2(top()+60.0,top()-10.0)

## The loose bits' box: from this far under the top, this tall (m).
func wind_box() -> Vector2:
	return Vector2(6.0,30.0)

## Where a ribbon rides off the turf (over the sky between islands).
func ride_y() -> float:
	return top()

## The meadow the chaff lies on (the isle's frame).
func chaff_meadow() -> Rect2:
	return Rect2()

## A rect in the isle's frame, where it stands (moved by `offset`).
func placed(rect: Rect2) -> Rect2:
	return Rect2(rect.position+Vector2(offset.x,offset.z),rect.size)

## What stands over an island's `outline` that no island claims as a node
## (scripts/world_islands.gd `grab`, through the isle's `island_carriers`):
## Callables(step: Transform3D, a world move) carrying its songbirds'
## perches, its fireflies, its undergrowth's plants in batches that span
## islands, and its loose leaves and chaff.
func island_carriers(outline: PackedVector2Array) -> Array:
	var out: Array = []
	if birds != null and birds.has_method("carrier"): out.append(birds.carrier(outline))
	if fireflies != null: out.append(WorldIslandsRef.instances_carrier(fireflies,outline))
	if undergrowth != null:
		for b: Node in undergrowth.find_children("*","MultiMeshInstance3D",true,false):
			out.append(WorldIslandsRef.instances_carrier(b as MultiMeshInstance3D,outline))
	for litter: MultiMeshInstance3D in [leaf_litter,grass_chaff]:
		if litter != null and litter.has_method("carrier"): out.append(litter.carrier(outline))
	return out.filter(func(c: Callable) -> bool: return c.is_valid())

## The chaff's anchors: over `chaff_meadow`'s open grass.
func chaff_anchors() -> Array:
	var meadow := chaff_meadow()
	if meadow.size == Vector2.ZERO: return []
	return GrassChaff.anchors_on(grass_at,GrassChaff.count_for(meadow.get_area()*0.8),placed(meadow))

## Where loose leaves gather besides the undergrowth: the feet of the ruins
## the walker passes (x, z in the isle's frame).
func leaf_spots() -> Array:
	return []

# --- The ground -----------------------------------------------------------------------

## Reads the isle's turf (its ground bodies on the scene's TURF_LAYER) and
## what is built over it into the grid.
func _read_ground(space: PhysicsDirectSpaceState3D) -> void:
	_ground_grid()
	_read_rows(space,-1)

## The grid's box round the scene's outlines (world).
func _ground_grid() -> void:
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
	_row = 0

## The grid's rows from `_row` on, until `end` (usec; -1 all): true once
## the last is read.
func _read_rows(space: PhysicsDirectSpaceState3D, end: int) -> bool:
	var span := ground_span()+Vector2.ONE*offset.y
	var turf := PhysicsRayQueryParameters3D.new()
	turf.collision_mask = TURF_LAYER
	var all := PhysicsRayQueryParameters3D.new()
	while _row < _h:
		var j := _row
		# A row is read a few cells at a time (a long row's rays ran
		# 15-40 ms over the slice rendered), `_col` where it left off.
		while _col < _w:
			if end >= 0 and _col % 8 == 0 and Time.get_ticks_usec() > end: return false
			var i := _col
			_col += 1
			var p := _origin+Vector2(i,j)*CELL
			turf.from = Vector3(p.x,span.x,p.y)
			turf.to = Vector3(p.x,span.y,p.y)
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
		_col = 0
		_row += 1
	return true

## The turf's height at `p` (world x, z), or null off it.
func ground_at(p: Vector2) -> Variant:
	# An island the world view (or the layout file) moved: its turf where it went.
	var built: Variant = WorldIslandsRef.as_built(p,scene) if scene != null and not WorldIslandsRef.islands.is_empty() else Vector3(p.x,0.0,p.y)
	if built == null: return null
	var b3: Vector3 = built
	var h: Variant = _grid_at(Vector2(b3.x,b3.z))
	return null if h == null else float(h)+b3.y

const WorldIslandsRef = preload("res://scripts/world_islands.gd")

func _grid_at(p: Vector2) -> Variant:
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
	return 1.0-smoothstep(0.1,0.5,(scene.flora_site() as KitFlora.Site).worn(p))

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
		var middle := Vector3((keys[n].x+0.5)*PATCH,top()+offset.y,(keys[n].y+0.5)*PATCH)
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
		return h if h != null else ride_y()+offset.y
	# A placed isle's life rides the home isle's ribbons (the atmosphere has
	# one set), its canopy theirs.
	if not shares_wind:
		atmosphere.setup_wind_trails(ride,false)
		var trails: Node = atmosphere.wind_trails
		if trails.has_method("set_canopy"): trails.set_canopy(func(p: Vector2) -> float: return 0.6 if standing_at(p) else 0.0)
	var tall := wind_box()
	var box := AABB(Vector3(_origin.x,top()+offset.y-tall.x,_origin.y),Vector3(_w*CELL,tall.y,_h*CELL))
	leaf_litter = LeafLitter.new()
	leaf_litter.custom_aabb = box
	add_child(leaf_litter)
	leaf_litter.seed_from(_leaf_anchors(),ground_at)
	grass_chaff = GrassChaff.new()
	grass_chaff.custom_aabb = box
	add_child(grass_chaff)
	grass_chaff.seed_from(chaff_anchors(),ground_at)
	kicked_blades = KickedBlades.new()
	kicked_blades.custom_aabb = box
	add_child(kicked_blades)
	kicked_blades.setup(ground_at,grass_at)

## Where loose leaves gather: at the feet of the ruins the walker passes
## (`leaf_spots`), by the undergrowth's shrubs and logs.
func _leaf_anchors() -> Array:
	var anchors: Array = leaf_spots().map(func(p: Vector2) -> Vector2: return p+Vector2(offset.x,offset.z))
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

## Past these from the isle's edge (m, `advance`'s gap) its small life
## holds still, hidden: the loose leaves, chaff, kicked blades and
## butterflies, a few centimetres, are under a pixel past SMALL_NEAR at
## 1080 lines; the songbirds past BIRDS_NEAR. Their steps are the most of a
## frame's script time: a layer has
## four or five lives in reach of the eye.
const SMALL_NEAR := 60.0
const BIRDS_NEAR := 150.0

## One frame of the isle's life, after the look (its air, its light);
## `gap` how far the eye is from the isle's edge (m, 0 on it).
func advance(delta: float, gap := 0.0) -> void:
	if delta <= 0.0: return
	var day := float(scene._celestial.state.get("zs_daylight",1.0))
	var small := gap < SMALL_NEAR
	for meadow in meadows:
		meadow.visible = small
		if small: meadow.flies.advance(delta)
	if fireflies != null:
		var weather: Variant = scene._precipitation.surface_weather
		fireflies.update_conditions(day,float(scene._precipitation.state.x),float(weather.cold),1.0)
	var atmosphere: Node = scene._atmosphere
	if flags.wind and atmosphere.wind_trails != null:
		var fronts: RefCounted = atmosphere.fronts
		atmosphere.wind_trails.set_bounds(fronts.center,fronts.radius)
		for bits: Node3D in [leaf_litter,grass_chaff,kicked_blades]: bits.visible = small
		if small:
			leaf_litter.advance(delta,false,atmosphere)
			grass_chaff.advance(delta,false,atmosphere)
			kicked_blades.advance(delta,false,atmosphere.wind_trails,atmosphere)
	if birds != null:
		birds.visible = gap < BIRDS_NEAR
		if birds.visible: birds.advance(delta)
	if tokens != null: tokens.glow_for(1.0-smoothstep(0.1,0.5,day))

## After each step of the pilot on foot (or the plane): his middle takes
## the tokens he reaches.
func step_pilot() -> void:
	if tokens == null: return
	if bool(scene.get("flying")): tokens.touch(Vector3.INF)
	else: tokens.touch(scene.motor.feet+Vector3.UP*Lines.FOOT_Y)
