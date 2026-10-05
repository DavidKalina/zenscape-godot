extends RefCounted
## Flower drifts on the ground (docs/scenic/handful.md "Flower seed"): the
## slots, the ground's rules (`suits`, `_free`), the meadow type a slot
## composes as, and the ground's faint `wash`. The hand paints flowers with
## these (scripts/flower_paint.gd, since 2026-10-02).
##
## `grow` is the veil's way, kept for pollen from existing life later (the
## slots no longer use it): a veil of seed and fluff (scripts/pollen_cloud.gd,
## the tree seeds' own veil), light enough that the breeze and any gust carry it
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
##   the flower's colour (`wash`), following the flowers that stand: the
##   flowers carry the colour.
## - **The ground decides.** Nothing takes on water, rock (too steep for the
##   habitat, or painted rock, earth or sand), snow, ground steeper than
##   STEEP, on a tree's trunk (TRUNK), or where a plant
##   or stone already stands.
## - **It blooms as it landed.** Each flower is born (Emergence's clock, the
##   shader's grow-in, scripts/emergence.gd `rise_seconds`) in the order its
##   nearest mote came down, over BLOOM seconds from the write.
##
## Which flowers: SLOTS. The wildflower slot sows the wildflower meadow's mix,
## or, in a world made as a meadow type, that type's own.
##
## Preloaded, not a class_name.

const Plate = preload("res://scripts/plate.gd")
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
	# Wheat (docs/scenic/wheat.md): a crop, not a meadow. Only wheat, drilled
	# in rows (`drift` is merged over the type's): rows `spacing` m apart, each
	# clump on a `band` m wide line down its row with a clear furrow between,
	# `square` to the plate's sides, wavering only a little; candidates on
	# the rows themselves, `along` m apart down each (the row lattice,
	# `spot`), `room` m kept between clumps, each turned along its row
	# (`align`), so a patch reads as a tidy field.
	"wheat":{"type":"sunflower","flowers":[["wheat",1.0]],"mix":0.0,"sizes":{"wheat":[0.82,0.95]},
		"drift":{"rows":{"kind":"wheat","spacing":0.32,"band":0.1,"along":0.2,"room":0.05,"align":true,"face":false,"square":true,"waver":0.06}}},
}
## The veil's look per slot (sRGB): seed and fluff, pale and warm, leaning to
## the flower's colour.
const LOOKS := {"wildflower":"f2e2b4","dandelion":"f6f2e6","poppy":"f2b8a0","cosmos":"f4c8da","sunflower":"f0d27a","wheat":"eedcae"}
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
## The candidate lattice (m), as the meadow types'. A slot whose rows give
## `along` (wheat) sets its candidates on its rows instead (`spot`).
const SPACING := 0.2
## The row lattice's jitter: down a row, the share of `along` a candidate
## strays either side of its place; across, the share of the row's `band`.
const ALONG_JITTER := 0.25
const BAND_JITTER := 0.4
## Ground the flowers refuse: steeper than STEEP (the meadow types' 0.75),
## within SNOW_GAP below the snowline, painted at least PAINTED weight with a
## colour within BARE of rock, earth or sand.
const STEEP := 0.75
const SNOW_GAP := 1.2
const PAINTED := 0.5
const BARE := 0.07
## Round trees: no flower within TRUNK m of a tree's foot (times its record
## scale), so none clips a trunk but the ground between trees and right up to
## them takes flowers, as wildflowers grow under and around trees. (The canopy
## and forest-density rules once left bare rings and gaps between trees.)
const TRUNK := 0.35
## How far (m) the survey looks past the brush for trees.
const TREE_REACH := 1.0
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
## The row lattice (`spot`): empty for the jittered square lattice, else
## {"along", "spacing", "band", "room"} from the slot's rows.
var _lattice := {}

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
	if spec.has("flowers") or spec.has("mix") or spec.has("drift") or spec.has("sizes"):
		var type: Dictionary = meadow.type.duplicate(true)
		if spec.has("flowers"): type.flowers = spec.flowers
		if spec.has("mix"): type.drift.mix = float(spec.mix)
		if spec.has("drift"): type.drift.merge(spec.drift.duplicate(true),true)
		if spec.has("sizes"): type.sizes = spec.sizes
		meadow.type = type
		# Rows square to the plate's sides, along x or z by the world.
		if type.drift.get("rows",{}).get("square",false):
			meadow._row = Vector2.RIGHT if Variety.unit([salt,29]) < 0.5 else Vector2.DOWN
		var rows: Dictionary = type.drift.get("rows",{})
		if rows.has("along"):
			_lattice = {"along":float(rows.along),"spacing":float(rows.spacing),"band":float(rows.get("band",0.0)),"room":float(rows.get("room",ROOM))}
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
	var g := Vector2i(((p+Vector2.ONE*Plate.HALF)/data.MEADOW_STEP).floor())
	if g.x < 0 or g.y < 0 or g.x >= data.MEADOW_CELLS or g.y >= data.MEADOW_CELLS: return -1
	return g.y*data.MEADOW_CELLS+g.x

## On a trunk: within TRUNK m (times the tree's scale) of a tree's foot.
func _shaded(p: Vector2) -> bool:
	var cell := Vector2i(p.floor())
	for dz in range(-2,3):
		for dx in range(-2,3):
			for tree: Vector3 in _trees.get(cell+Vector2i(dx,dz),[]):
				if p.distance_to(Vector2(tree.x,tree.y)) < TRUNK*tree.z: return true
	return false

## What already stands round `bounds`: trees (for shade), plants and stones
## (for room).
func _survey(bounds: Rect2) -> void:
	_trees.clear()
	_taken.clear()
	var reach := bounds.grow(TREE_REACH+1.0)
	for item: Dictionary in data.objects:
		var p := Vector2(float(item.x),float(item.z))
		if not reach.has_point(p): continue
		var asset := str(item.asset)
		if asset in preload("res://scripts/emergence.gd").TREES:
			_trees.get_or_add(Vector2i(p.floor()),[]).append(Vector3(p.x,p.y,clampf(float(item.get("scale",1.0)),0.5,2.0)))
		var room := STONE*float(item.get("scale",1.0)) if asset == "rock" or asset.begins_with("boulder") else ROOM
		if not _lattice.is_empty() and asset in kinds(): room = float(_lattice.room)
		_taken.get_or_add(Vector2i((p/0.5).floor()),[]).append(Vector3(p.x,p.y,room))

## The room a plant this sowing places keeps about it (m).
func room() -> float:
	return ROOM if _lattice.is_empty() else float(_lattice.room)

# --- The lattice -----------------------------------------------------------------

## The candidate cells over `area` (plate): [first, last), as Vector2i.
## On the square lattice, SPACING cells of x and z; on the row lattice, x
## counts `along` steps down the rows and y the rows across.
func cells(area: Rect2) -> Array:
	if _lattice.is_empty():
		return [Vector2i((area.position/SPACING).floor()),Vector2i((area.end/SPACING).ceil())]
	var u: Vector2 = meadow._row
	var n := Vector2(-u.y,u.x)
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for corner: Vector2 in [area.position,Vector2(area.end.x,area.position.y),Vector2(area.position.x,area.end.y),area.end]:
		var q := Vector2(u.dot(corner),n.dot(corner))
		low = low.min(q)
		high = high.max(q)
	var along := float(_lattice.along)
	var spacing := float(_lattice.spacing)
	return [Vector2i(floori(low.x/along),floori(low.y/spacing)-1),Vector2i(ceili(high.x/along),ceili(high.y/spacing)+1)]

## The hash keying candidate `cell`'s draws, the world's own: a second
## sowing finds the same spots.
func key_of(cell: Vector2i) -> Array:
	return [salt,71 if _lattice.is_empty() else 73,cell.x,cell.y]

## Where candidate `cell` stands (plate). On the row lattice: down its row
## at its `along` step, a little either way, and across within the row's
## band, following the row's waver (MeadowTypes `row_waver`).
func spot(cell: Vector2i) -> Vector2:
	var key := key_of(cell)
	if _lattice.is_empty():
		return Vector2((cell.x+Variety.unit(key+[1]))*SPACING,(cell.y+Variety.unit(key+[2]))*SPACING)
	var u: Vector2 = meadow._row
	var n := Vector2(-u.y,u.x)
	var down := (cell.x+0.5+(Variety.unit(key+[1])-0.5)*2.0*ALONG_JITTER)*float(_lattice.along)
	var across := (cell.y+0.5)*float(_lattice.spacing)+(Variety.unit(key+[2])-0.5)*2.0*BAND_JITTER*float(_lattice.band)*0.5
	var p := u*down+n*across
	for i in range(3): p = u*down+n*(across-meadow.row_waver(p))
	return p

## Candidate `cell`'s middle, for a rough look before it is judged.
func middle(cell: Vector2i) -> Vector2:
	if _lattice.is_empty(): return Vector2((cell.x+0.5)*SPACING,(cell.y+0.5)*SPACING)
	var u: Vector2 = meadow._row
	return u*(cell.x+0.5)*float(_lattice.along)+Vector2(-u.y,u.x)*(cell.y+0.5)*float(_lattice.spacing)

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
	var span: Array = cells(bounds)
	var first: Vector2i = span[0]
	var last: Vector2i = span[1]
	var placed: Array = result.placed
	for gz in range(first.y,last.y):
		for gx in range(first.x,last.x):
			# The lattice is the world's: a second sowing finds the same spots.
			var key := key_of(Vector2i(gx,gz))
			var p := spot(Vector2i(gx,gz))
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
			_taken.get_or_add(Vector2i((p/0.5).floor()),[]).append(Vector3(p.x,p.y,room()))
			placed.append(id)
			result.kinds[kind] = int(result.kinds.get(kind,0))+1
	if not placed.is_empty(): data.objects_revision += 1
	result.washed = wash(func(p: Vector2) -> float: return float(_density(buckets,p)[0]),bounds)
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
func wash(density_at: Callable, bounds: Rect2) -> int:
	var drift: Dictionary = meadow.type.drift
	var base := data.tint.duplicate()
	var tint := data.tint
	var provenance := data.provenance
	var count := 0
	for z in range(data.MEADOW_CELLS):
		for x in range(data.MEADOW_CELLS):
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5
			if not bounds.has_point(p): continue
			var d := presence(float(density_at.call(p)),p)
			if d <= 0.0: continue
			var kind: String = meadow.kind_at(p,1.0)
			if not MeadowTypes.FLOWER_KEYS.has(kind): continue
			var standing := float(drift.get("density",1.0))*pow(d,1.2)*MeadowTypes.packing(kind)
			var core := smoothstep(WASH_FROM,1.0,standing)
			if core <= 0.0 or not _ground_takes(p): continue
			var hides := float(MeadowTypes.FLOWER_KEYS[kind].get("cover",1.0))
			var soil := float(MeadowTypes.FLOWER_KEYS[kind].get("soil",0.0))
			var cell := z*data.MEADOW_CELLS+x
			var grass := Brush.surface_colour("grass",data._palette,p)
			var colour := grass.lerp(Color(MeadowTypes.wash_of(kind,meadow.variant(p))).srgb_to_linear(),1.0 if soil > 0.0 else WASH_LEAN)
			var before := NativeTerrainTint.weight_at(tint,cell)
			NativeTerrainTint.coat(tint,base,cell,colour,maxf(before,(soil if soil > 0.0 else WASH)*core*hides))
			if NativeTerrainTint.weight_at(tint,cell) > before:
				provenance[cell] = NativeTerrainData.SOURCE_HAND
				count += 1
	data.tint = tint
	data.provenance = provenance
	return count
