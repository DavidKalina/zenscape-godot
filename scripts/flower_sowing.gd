extends RefCounted
## Flowers sown from the hand (docs/scenic/handful.md "Flower seed"; the
## materials bar's flower slots, scripts/hand_materials.gd). You release
## something; the world decides what becomes of it.
##
## A flower slot flicks a veil of seed and fluff (scripts/pollen_cloud.gd, the
## tree seeds' own veil), light enough that the breeze and any gust carry it
## further than tree seed (`CARRY`). Where its motes come down is all this
## module is told: the landings, and when each landed. It grows them into a
## drift the way a meadow type composes one (scripts/meadow_types.gd):
##
## - **Presence from the landings.** How thickly the motes came down at a
##   point (a soft kernel over the landings, motes per square metre) is how
##   much of the drift stands there: thin at THIN, full at FULL, broken at its
##   edge by a fine feather noise. A sweep comes up as a band, a tap as a small
##   round drift, a held-still thickening as a packed core.
## - **The meadow type's composition.** Candidates on a 0.2 m jittered lattice
##   keep `pow(presence, 1.2)` times the kind's packing, so heads nearly touch
##   at the core; the kind is the type's (`kind_at`: drifts of one kind, a few
##   companions by its `mix`); sunflowers keep to their rows (`on_row`), so
##   they come up as stands, not carpets; size, colour variant and pose are
##   the type's (`flower`). The ground under the drift is only warmed toward
##   the flower's colour (`_wash`), following the flowers that stand: the
##   flowers carry the colour.
## - **The ground decides.** Nothing takes on water, rock (too steep for the
##   habitat, or painted rock, earth or sand), snow, ground steeper than
##   STEEP, under a tree's crown or in dense forest (FOREST), or where a plant
##   or stone already stands.
## - **It blooms as it landed.** Each flower is born (Emergence's clock, the
##   shader's grow-in, scripts/emergence.gd `rise_seconds`) in the order its
##   nearest mote came down, over BLOOM seconds from the write.
##
## Which flowers: SLOTS. The wildflower slot sows the wildflower meadow's mix,
## or, in a world made as a meadow type, that type's own.
##
## Preloaded, not a class_name.

const MeadowTypes = preload("res://scripts/meadow_types.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Strata = preload("res://scripts/strata.gd")
const Brush = preload("res://scripts/clay_tools/brush.gd")

## The hand's flower slots: the meadow type each composes as (its drift,
## sizes, rows and wash), and, when present, its own `flowers` (kind, weight;
## a 0-weight kind is the drift's companion only, MeadowTypes `kind_at`, so a
## handful is always mostly what was sown) and `mix` over the type's (small
## for sunflowers: their companions do not keep to the rows).
const SLOTS := {
	"wildflower":{"type":"wildflower","own_world":true},
	"dandelion":{"type":"dandelion","flowers":[["dandelion",1.0],["dandelion_clock",0.6],["buttercup",0.0]]},
	"poppy":{"type":"wildflower","flowers":[["poppy",1.0],["oxeye_daisy",0.0]],"mix":0.08},
	"cosmos":{"type":"cosmos","flowers":[["cosmos",1.0],["oxeye_daisy",0.0]]},
	"sunflower":{"type":"sunflower","flowers":[["sunflower",1.0],["buttercup",0.0]],"mix":0.02},
}
## The veil's look per slot (sRGB): seed and fluff, pale and warm, leaning to
## the flower's colour.
const LOOKS := {"wildflower":"f2e2b4","dandelion":"f6f2e6","poppy":"f2b8a0","cosmos":"f4c8da","sunflower":"f0d27a"}
## The veil: brush radius (m) at the middle pip (pollen_cloud.gd scales it
## within its SIZE), its strength (more motes than a tree's veil, so the drift
## has a density to read), its spread (a share of the tree veil's: a flower
## handful comes down closer to where it was swept) and how much more the air
## carries it than tree seed.
const RADIUS := 2.6
const STRENGTH := 2.0
const SPREAD := 0.55
const CARRY := 1.3
## The landings' kernel (m, its standard deviation), and the motes per m²
## where a drift starts and where it stands full.
const KERNEL := 0.55
const THIN := 1.6
const FULL := 7.0
## The candidate lattice (m), as the meadow types'.
const SPACING := 0.2
## Ground the flowers refuse: steeper than STEEP (the meadow types' 0.75),
## within SNOW_GAP below the snowline, painted at least PAINTED weight with a
## colour within BARE of rock, earth or sand.
const STEEP := 0.75
const SNOW_GAP := 1.2
const PAINTED := 0.5
const BARE := 0.07
## Under trees: no flower within CROWN m of a tree's foot (times its record
## scale), and none where FOREST trees or more stand within FOREST_REACH m.
const CROWN := 0.9
const FOREST := 3
const FOREST_REACH := 2.6
## Nothing grows within ROOM m of a plant already standing, STONE m (times its
## scale) of a stone.
const ROOM := 0.12
const STONE := 0.45
## The ground under a drift: the share of the way its grass leans to the
## flower's wash, the most weight that is laid, and the standing density
## (presence^1.2 times packing) it starts from.
const WASH_LEAN := 0.4
const WASH := 0.16
const WASH_FROM := 0.4
## Seconds over which the drift blooms from the write, in the order its motes
## landed; each flower a little off that (BLOOM_JITTER).
const BLOOM := 1.8
const BLOOM_JITTER := 0.35
const BLOOM_DELAY := 0.1

var data: NativeTerrainData
var slot := ""
var meadow: RefCounted
## Plate x, z -> true where live water stands.
var wet: Callable = func(_p: Vector2) -> bool: return false
## The habitat at a point ("" for none known).
var habitat: Callable = func(_p: Vector2) -> String: return ""
var salt := 0
var _snowline := 99.0
var _bare: Array[Color] = []
var _feather := FastNoiseLite.new()
var _trees := {}
var _taken := {}

static func has(id: String) -> bool:
	return SLOTS.has(id)

## The veil's colour for `id` (sRGB).
static func look(id: String) -> Color:
	return Color(LOOKS.get(id,"f2e2b4"))

## The meadow type `id` composes as in a world whose recipe is `settings`.
static func type_for(id: String, settings: Dictionary) -> String:
	var spec: Dictionary = SLOTS[id]
	var own := MeadowTypes.of(settings)
	if spec.get("own_world",false) and not own.is_empty(): return own
	return str(spec.type)

## Sowing `id` on `ground` from a world keyed by `world_seed`.
func _init(ground: NativeTerrainData, id: String, world_seed: int) -> void:
	data = ground
	slot = id
	salt = Variety.mix([world_seed,6113])
	var settings: Dictionary = data._recipe_settings
	var type_id := type_for(id,settings)
	# In its own meadow world the drifts follow the world's (its plant seed).
	var seed_value := world_seed
	if type_id == MeadowTypes.of(settings) and data._recipe != null and data._recipe.get("inland") != null:
		seed_value = int(data._recipe.inland.genome.plant_seed)
	meadow = MeadowTypes.new(type_id,seed_value)
	var spec: Dictionary = SLOTS[id]
	if spec.has("flowers") or spec.has("mix"):
		var type: Dictionary = meadow.type.duplicate(true)
		if spec.has("flowers"): type.flowers = spec.flowers
		if spec.has("mix"): type.drift.mix = float(spec.mix)
		meadow.type = type
	_snowline = BiomeBlend.snowline(settings,data._palette.snowline)
	for colour: Color in data._palette.rock: _bare.append(colour)
	_bare.append(data._palette.sand)
	_bare.append(Color(Strata.COLORS.topsoil).srgb_to_linear())
	_feather.seed = salt%100000
	_feather.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_feather.frequency = 1.4

## The kinds this sowing may grow.
func kinds() -> Array:
	return meadow.type.flowers.map(func(entry: Array) -> String: return str(entry[0]))

# --- The ground ------------------------------------------------------------------

## True where the ground takes flower seed at `p` (plate x, z): land, not
## water, rock, bare paint or snow, not too steep, not under trees.
func suits(p: Vector2) -> bool:
	return _ground_takes(p) and not _shaded(p)

func _ground_takes(p: Vector2) -> bool:
	var h: Variant = data.ground_height(p)
	if h == null: return false
	if float(h) > _snowline-SNOW_GAP: return false
	if wet.call(p) or _under_pond(p,float(h)): return false
	var slope := Presets._slope(data,p)
	var where: String = habitat.call(p)
	var rock := STEEP
	if not where.is_empty() and preload("res://scripts/native_formation_shape.gd").BIOMES.has(where):
		rock = minf(rock,float(preload("res://scripts/native_formation_shape.gd").BIOMES[where].rock_slope))
	if slope > rock: return false
	return not _painted_bare(p)

func _under_pond(p: Vector2, h: float) -> bool:
	for pond: Dictionary in data.ponds:
		if h < float(pond.get("level",-INF))+0.05 and p.distance_to(Vector2(float(pond.get("x",0.0)),float(pond.get("z",0.0)))) < 7.0: return true
	return false

## Painted rock, earth or sand (the Brush, the Paddle's Plane).
func _painted_bare(p: Vector2) -> bool:
	var cell := _cell(p)
	if cell < 0 or NativeTerrainTint.weight_at(data.tint,cell) < PAINTED: return false
	var colour := NativeTerrainTint.color_at(data.tint,cell)
	for bare: Color in _bare:
		if Vector3(colour.r-bare.r,colour.g-bare.g,colour.b-bare.b).length() < BARE: return true
	return false

func _cell(p: Vector2) -> int:
	var g := Vector2i(((p+Vector2(14,14))/data.MEADOW_STEP).floor())
	if g.x < 0 or g.y < 0 or g.x >= data.MEADOW_CELLS or g.y >= data.MEADOW_CELLS: return -1
	return g.y*data.MEADOW_CELLS+g.x

## Under a crown, or in dense forest.
func _shaded(p: Vector2) -> bool:
	var near := 0
	var cell := Vector2i(p.floor())
	for dz in range(-3,4):
		for dx in range(-3,4):
			for tree: Vector3 in _trees.get(cell+Vector2i(dx,dz),[]):
				var d := p.distance_to(Vector2(tree.x,tree.y))
				if d < CROWN*tree.z: return true
				if d < FOREST_REACH: near += 1
	return near >= FOREST

## What already stands round `bounds`: trees (for shade), plants and stones
## (for room).
func _survey(bounds: Rect2) -> void:
	_trees.clear()
	_taken.clear()
	var reach := bounds.grow(FOREST_REACH+1.0)
	for item: Dictionary in data.objects:
		var p := Vector2(float(item.x),float(item.z))
		if not reach.has_point(p): continue
		var asset := str(item.asset)
		if asset in preload("res://scripts/emergence.gd").TREES:
			_trees.get_or_add(Vector2i(p.floor()),[]).append(Vector3(p.x,p.y,clampf(float(item.get("scale",1.0)),0.5,2.0)))
		var room := STONE*float(item.get("scale",1.0)) if asset == "rock" or asset.begins_with("boulder") else ROOM
		_taken.get_or_add(Vector2i((p/0.5).floor()),[]).append(Vector3(p.x,p.y,room))

func _free(p: Vector2) -> bool:
	var cell := Vector2i((p/0.5).floor())
	for dz in range(-2,3):
		for dx in range(-2,3):
			for other: Vector3 in _taken.get(cell+Vector2i(dx,dz),[]):
				if p.distance_to(Vector2(other.x,other.y)) < other.z: return false
	return true

# --- The drift ---------------------------------------------------------------------

## The landings bucketed by 0.5 m cell: [point, time] pairs.
func _buckets(points: PackedVector2Array, times: PackedFloat32Array) -> Dictionary:
	var out := {}
	for i in range(points.size()):
		out.get_or_add(Vector2i((points[i]/0.5).floor()),[]).append(Vector3(points[i].x,points[i].y,times[i] if i < times.size() else 0.0))
	return out

## Motes per m² that came down round `p`, and when the nearest landed:
## [density, time, distance to the nearest].
func _density(buckets: Dictionary, p: Vector2) -> Array:
	var sum := 0.0
	var nearest := INF
	var when := 0.0
	var cell := Vector2i((p/0.5).floor())
	var span := int(ceil(KERNEL*2.6/0.5))
	var k := 1.0/(2.0*KERNEL*KERNEL)
	for dz in range(-span,span+1):
		for dx in range(-span,span+1):
			for q: Vector3 in buckets.get(cell+Vector2i(dx,dz),[]):
				var d2 := p.distance_squared_to(Vector2(q.x,q.y))
				sum += exp(-d2*k)
				if d2 < nearest:
					nearest = d2
					when = q.z
	return [sum*k/PI,when,sqrt(nearest)]

## How much of the drift stands at `p` from the motes' density there.
func presence(density: float, p: Vector2) -> float:
	var feather := clampf(0.8+0.45*_feather.get_noise_2d(p.x,p.y),0.0,1.2)
	return clampf(smoothstep(THIN,FULL,density*feather),0.0,1.0)

## Grows the drift the landings `points` (plate x, z; `times`, seconds since
## the veil was let go, alongside) make: places its flowers in `data` (hand
## work, born from `now` on Emergence's clock) and washes the ground under
## it. `serial` keys this sowing's draws, so a second sweep fills what the
## first left. Call inside an open stroke. {"placed" (ids), "kinds" (kind ->
## count), "washed" (cells), "bounds" (Rect2), "refused" (candidates the
## ground refused)}.
func grow(points: PackedVector2Array, times: PackedFloat32Array, serial: int, now: float) -> Dictionary:
	var result := {"placed":[],"kinds":{},"washed":0,"bounds":Rect2(),"refused":0}
	if points.is_empty(): return result
	var bounds := Rect2(points[0],Vector2.ZERO)
	for q in points: bounds = bounds.expand(q)
	bounds = bounds.grow(KERNEL*2.0)
	result.bounds = bounds
	var t0 := INF
	var t1 := -INF
	for t in times:
		t0 = minf(t0,t)
		t1 = maxf(t1,t)
	if t0 == INF:
		t0 = 0.0
		t1 = 0.0
	_survey(bounds)
	var buckets := _buckets(points,times)
	var drift: Dictionary = meadow.type.drift
	var density := float(drift.get("density",1.0))
	var first := Vector2i((bounds.position/SPACING).floor())
	var last := Vector2i((bounds.end/SPACING).ceil())
	var placed: Array = result.placed
	for gz in range(first.y,last.y):
		for gx in range(first.x,last.x):
			# The lattice is the world's: a second sowing finds the same spots.
			var key := [salt,71,gx,gz]
			var p := Vector2((gx+Variety.unit(key+[1]))*SPACING,(gz+Variety.unit(key+[2]))*SPACING)
			var near: Array = _density(buckets,p)
			var d := presence(float(near[0]),p)
			if d <= 0.0: continue
			var roll := Variety.unit([salt,serial,gx,gz,3])
			var standing := density*pow(d,1.2)
			if roll >= standing: continue
			var kind: String = meadow.kind_at(p,Variety.unit([salt,serial,gx,gz,4]))
			if roll >= standing*MeadowTypes.packing(kind) or not meadow.on_row(p,kind): continue
			if not _free(p): continue
			if not suits(p):
				result.refused = int(result.refused)+1
				continue
			var record: Array = meadow.flower(kind,p,key)
			var id := data.place(record[0],p,record[4],record[1],record[3],record[2])
			if id < 0: continue
			var item: Dictionary = data.objects.back()
			item["source"] = "hand"
			var order := (float(near[1])-t0)/maxf(t1-t0,0.001)
			item["born"] = now+BLOOM_DELAY+BLOOM*order+BLOOM_JITTER*Variety.unit([salt,serial,gx,gz,6])
			_taken.get_or_add(Vector2i((p/0.5).floor()),[]).append(Vector3(p.x,p.y,ROOM))
			placed.append(id)
			result.kinds[kind] = int(result.kinds.get(kind,0))+1
	if not placed.is_empty(): data.objects_revision += 1
	result.washed = _wash(buckets,bounds)
	return result

## The ground under the drift, warmed a little toward its flowers where they
## stand thickly: the world's own grass there (the Brush's grass, scripts/
## clay_tools/brush.gd `surface_colour`) leaning WASH_LEAN of the way to the
## flower's wash (MeadowTypes `wash_of`), laid at most WASH weight, eased in
## with the flowers' standing density (`standing`, presence^1.2 times the
## kind's packing, from WASH_FROM to full) and less for a low kind that hides
## little ground (`cover`). The painted layer is per 0.5 m cell and shows per
## face, so it stays this faint: the flowers carry the colour, the ground only
## supports it, and a cell's edge never reads as a patch of bare earth.
## Painted cells are only ever deepened (NativeTerrainTint `coat`) and become
## hand work. Returns the cells washed.
func _wash(buckets: Dictionary, bounds: Rect2) -> int:
	var drift: Dictionary = meadow.type.drift
	var base := data.tint.duplicate()
	var tint := data.tint
	var provenance := data.provenance
	var count := 0
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5
			if not bounds.has_point(p): continue
			var d := presence(float(_density(buckets,p)[0]),p)
			if d <= 0.0: continue
			var kind: String = meadow.kind_at(p,1.0)
			if not MeadowTypes.FLOWER_KEYS.has(kind): continue
			var standing := float(drift.get("density",1.0))*pow(d,1.2)*MeadowTypes.packing(kind)
			var core := smoothstep(WASH_FROM,1.0,standing)
			if core <= 0.0 or not _ground_takes(p): continue
			var hides := float(MeadowTypes.FLOWER_KEYS[kind].get("cover",1.0))
			var cell := z*data.MEADOW_CELLS+x
			var grass := Brush.surface_colour("grass",data._palette,p)
			var colour := grass.lerp(Color(MeadowTypes.wash_of(kind,meadow.variant(p))).srgb_to_linear(),WASH_LEAN)
			var before := NativeTerrainTint.weight_at(tint,cell)
			NativeTerrainTint.coat(tint,base,cell,colour,maxf(before,WASH*core*hides))
			if NativeTerrainTint.weight_at(tint,cell) > before:
				provenance[cell] = NativeTerrainData.SOURCE_HAND
				count += 1
	data.tint = tint
	data.provenance = provenance
	return count
