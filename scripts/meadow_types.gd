extends RefCounted
## Meadow types (docs/scenic/meadows.md): five meadows a new world can start
## from, each its own grass, its own flowers and its own neighbours.
##
## A meadow type rides on a generated inland recipe as `"meadow": "<id>"`,
## over the "meadow" habitat. Recipes without the key (every save and every
## generated world from before) dress exactly as they always did; with it,
## scripts/inland_landscape.gd hands the meadow ground to `dress`, and
## scripts/emergence.gd grows the type's own flowers on new meadow ground.
##
## Composition, not confetti: flowers stand in drifts of one kind (a cellular
## noise gives each drift its species), thin out into plain grass at a drift's
## edge (a slow presence noise), and leave soft gaps of grass between drifts.
## Heights layer: low buttercup and dandelion, mid daisy and cosmos, tall
## sunflower. The ground under a drift is washed toward its flower's colour,
## so a drift reads from the diorama camera even where single heads don't.
##
## Everything is position hashes and seeded noise: no draw is taken from the
## planting stream, so trees, water and the land are the recipe's own.
const Plate = preload("res://scripts/plate.gd")
const Variety = preload("res://scripts/seeded_variety.gd")
const BiomeBlend = preload("res://scripts/biome_blend.gd")
const Presets = preload("res://scripts/native_landscape_presets.gd")

## The flower kinds meadows ask for, and what stands in for each until the
## flower kit's meshes are in the catalog. This is the one place the kit's
## keys meet the old forms: `asset` uses the key itself as soon as
## NativeTerrainData.ASSETS lists it, so merging the kit needs no change here.
## Each entry:
## - `fallback`: the old form that stands in;
## - `height` and `head`: the kind's height and flower width in metres at
##   record size 1. The kit's meshes are expected at this size; a stand-in is
##   stretched to it with a pose;
## - `tints` (sRGB): the stand-in's head colours, one per drift;
## - `wash` (sRGB): the ground colour under its drift;
## - `tint_real`, when present and true, paints the kit's own mesh with
##   `tints` too (absent: the kit's heads keep their own colours);
## - `cover`, when present, how much of the ground a drift of it hides from
##   the diorama camera (1 if absent): a low kind's wash is that much weaker,
##   so the ground supports its heads instead of standing in for them;
## - `pack`, when present, the share of candidates it keeps at a drift's
##   heart instead of `packing`'s;
## - `soil`, when present, the weight a drift of it lays its wash with, all
##   the way to its colour, in place of FlowerSowing's light lean (a crop's
##   tilled ground: wheat's furrows read as earth, not lawn).
const FLOWER_KEYS := {
	"oxeye_daisy":{"fallback":"daisy_flower","height":0.57,"head":0.2,"tints":["f6f2e4"],"wash":"ece6cf"},
	"buttercup":{"fallback":"button_flower","height":0.38,"head":0.14,"tints":["f5c832"],"wash":"e9bd24","cover":0.65},
	"dandelion":{"fallback":"button_flower","height":0.26,"head":0.17,"tints":["f6c21e"],"wash":"e8b81c","cover":0.85},
	"dandelion_clock":{"fallback":"umbel_flower","height":0.45,"head":0.18,"tints":["f4f2ea"],"wash":"e6d9b0","cover":0.6},
	"cosmos":{"fallback":"daisy_flower","height":0.94,"head":0.22,"tints":["e8609f","c22f78","fcefe2"],"washes":["de78a8","b9468a","e8dccf"],"wash":"de78a8","tint_real":true},
	"sunflower":{"fallback":"daisy_flower","height":1.83,"head":0.44,"tints":["f4b61e"],"wash":"c4b040","pack":0.42},
	"poppy":{"fallback":"button_flower","height":0.63,"head":0.16,"tints":["e0442f"],"wash":"d8452c"},
	"lupine":{"fallback":"spike_flower","height":0.85,"head":0.12,"tints":["7b4cc6","9c48b8"],"washes":["8a68c0","9a62b4"],"wash":"8a68c0","tint_real":true},
	# Wheat, painted from the hand only (FlowerSowing SLOTS "wheat",
	# docs/scenic/wheat.md): one record a clump of six straws, its rows
	# packed whole (a narrow head keeps every candidate), the ground under a
	# patch warmed toward stubble gold.
	"wheat":{"fallback":"spike_flower","height":0.6,"head":0.06,"tints":["e3bf62"],"wash":"a8743c","soil":0.8},
}
## With the kit in the catalog a `tint_real` kind's `tints` are the kit's own
## petal variants (MeadowFlowerMesh SPEC `variants`), so GardenView draws a
## drift in that one variant, mesh shading intact (MeadowFlowerMesh
## `instance_color`); `washes`, when present, is the ground under each.
## The stand-ins' own form at size 1, measured from the reference geometry
## (NativeAssetCatalog parts with their pivots): [top of the head, head width].
const FALLBACK_FORMS := {"daisy_flower":[0.258,0.17],"button_flower":[0.242,0.088],"umbel_flower":[0.232,0.11],"spike_flower":[0.42,0.051]}

## Each meadow type:
## - `flowers`: [kind, weight] for the drifts; `sizes` per kind, its size
##   range on the kind's own height and head (FLOWER_KEYS).
## - `drift`, the composition: `frequency` (1/m) of the drifts, `cover` the
##   share of meadow in drift, `spacing` (m) of flower candidates, `density`
##   at a drift's heart, `mix` the share of a drift its companion kind takes,
##   `stray` flowers standing alone in the grass between drifts, `wash` the
##   ground's lean to the drift's colour under its core and `carpet` the
##   paint's weight there, so a dense drift reads as one carpet of colour;
##   `rows` for a kind planted in
##   loose rows (`spacing` in metres apart; `width`, the share of `spacing`
##   either side of a row's middle that counts as on it). A crop's rows
##   (FlowerSowing SLOTS "wheat") may instead give `band`, the on-row band's
##   whole width in metres, and `align`, turning each record along its row.
## - `grass`, the ground paint (sRGB): its `green` and `weight`, the `straw`
##   it turns in dry patches and their `share`; grass tufts per 0.9 m
##   candidate (`tufts`, fewer inside a drift), their `tuft_size` and the
##   share tinted straw (`tuft_straw`).
## - `trees`: the meadow's own tree budget, a few lone trees at most;
##   `rocks`: stones per 0.9 m candidate.
## - `terrain` and `blend` shape the land and its neighbours (scripts/
##   meadow_recipe.gd plans them from here; BiomeBlend
##   layers [habitat, rule, share, turn], the turn "sun" or "shade" of the
##   world's own sun side; "moist" only where there is water).
## - `land`: the New world land that forms it (scripts/world_library.gd);
##   `mood` (a SceneLookPresets `preset` and its overrides) and `visuals`
##   light it (scripts/world_lands.gd).
const TYPES := {
	"wildflower":{
		"title":"Wildflower meadow",
		"land":"wildflowers",
		"terrain":{"composition":"basin","archetype":"ridgeback","landform":"original","relief":[0.75,0.95],"breadth":[1.05,1.2]},
		"blend":[["wetland","moist",0.1,0],["woodland","facing",0.2,"shade"]],
		"grass":{"green":"92be55","weight":0.38,"straw":"c6c07a","share":0.1,"tufts":0.2,"tuft_size":[0.5,0.85],"tuft_straw":0.12},
		"flowers":[["oxeye_daisy",1.0],["buttercup",1.0],["poppy",0.8],["cosmos",0.35],["lupine",0.35]],
		"sizes":{"oxeye_daisy":[0.85,1.15],"buttercup":[0.85,1.15],"poppy":[0.85,1.15],"cosmos":[0.8,1.1],"lupine":[0.85,1.15]},
		"drift":{"frequency":0.2,"cover":0.68,"spacing":0.2,"density":1.0,"mix":0.12,"stray":0.01,"wash":0.7,"carpet":0.8},
		"trees":6,"rocks":0.0,
		"mood":{"preset":"golden_meadow","phase":0.37,"weather":"fair","clouds":0.2,"mist":0.1,"haze":0.1,"rays":0.5,"wind":0.3,"summit_mist":0.05,"exposure":1.1,
			"colors":{"sky":"79a8c6","horizon":"aebfb8","glow":"f2d6a8","grass":"84ad57","foliage":"5a8a49","water":"58a0a0"}},
		"visuals":{"fog_density":0.04,"fog_height":3.0,"peak_density":0.02}},
	"sunflower":{
		"title":"Sunflower field",
		"land":"sunflowers",
		"terrain":{"composition":"meadow","archetype":"horn","landform":"original","relief":[0.55,0.75],"breadth":[1.15,1.35]},
		"blend":[["woodland","high",0.12,0]],
		"grass":{"green":"a2b84c","weight":0.42,"straw":"c8bc5c","share":0.14,"tufts":0.22,"tuft_size":[0.55,0.9],"tuft_straw":0.25},
		"flowers":[["sunflower",1.0],["buttercup",0.1],["oxeye_daisy",0.08]],
		"sizes":{"sunflower":[0.9,1.15],"buttercup":[0.85,1.1],"oxeye_daisy":[0.85,1.1]},
		"drift":{"frequency":0.13,"cover":0.7,"spacing":0.2,"density":1.0,"mix":0.05,"stray":0.004,"wash":0.3,"carpet":0.5,
			"rows":{"kind":"sunflower","spacing":0.95,"width":0.2,"face":true}},
		"trees":3,"rocks":0.0,
		"mood":{"preset":"golden_meadow","phase":0.58,"weather":"clear","clouds":0.1,"mist":0.05,"haze":0.14,"rays":0.55,"wind":0.25,"summit_mist":0.0,"exposure":1.1,
			"colors":{"sky":"84a9c4","horizon":"c9bba0","glow":"f6c88a","sun":"ffd79c","grass":"8eab4e","foliage":"6b8444","water":"62a0a0"}},
		"visuals":{"fog_density":0.02,"fog_height":3.0,"peak_density":0.0}},
	"dandelion":{
		"title":"Dandelion meadow",
		"land":"dandelions",
		"terrain":{"composition":"meadow","archetype":"range","landform":"original","relief":[1.0,1.25],"breadth":[0.85,1.0]},
		"blend":[["woodland","facing",0.16,"shade"]],
		"grass":{"green":"7cbb48","weight":0.42,"straw":"b7c46a","share":0.0,"tufts":0.1,"tuft_size":[0.4,0.6],"tuft_straw":0.0},
		"flowers":[["dandelion",1.0],["dandelion_clock",0.6],["buttercup",0.15],["oxeye_daisy",0.12]],
		"sizes":{"dandelion":[1.0,1.3],"dandelion_clock":[0.9,1.2],"buttercup":[0.8,1.0],"oxeye_daisy":[0.8,1.0]},
		"drift":{"frequency":0.15,"cover":0.7,"spacing":0.2,"density":1.0,"mix":0.3,"stray":0.015,"wash":0.7,"carpet":0.72},
		"trees":4,"rocks":0.0,
		"mood":{"preset":"after_the_rain","phase":0.36,"weather":"fair","clouds":0.28,"mist":0.1,"haze":0.08,"rays":0.55,"wind":0.35,"wet":0.12,"humidity":0.45,"rainbow":0.0,"summit_mist":0.03,"exposure":1.1,
			"colors":{"sky":"76abc9","horizon":"aac3c2","glow":"ece2b8","grass":"72ab58","foliage":"4c8550","water":"58a2a3"}},
		"visuals":{"fog_density":0.04,"fog_height":2.5,"peak_density":0.02}},
	"cosmos":{
		"title":"Cosmos field",
		"land":"cosmos",
		"terrain":{"composition":"meadow","archetype":"horn","landform":"original","relief":[0.9,1.1],"breadth":[1.2,1.4]},
		"blend":[["woodland","high",0.08,0]],
		"grass":{"green":"8cb257","weight":0.38,"straw":"bdb46e","share":0.18,"tufts":0.16,"tuft_size":[0.5,0.85],"tuft_straw":0.35},
		"flowers":[["cosmos",1.0],["oxeye_daisy",0.07]],
		"sizes":{"cosmos":[0.8,1.15],"oxeye_daisy":[0.8,1.0]},
		"drift":{"frequency":0.11,"cover":0.74,"spacing":0.2,"density":1.0,"mix":0.04,"stray":0.008,"wash":0.65,"carpet":0.8},
		"trees":4,"rocks":0.0,
		"mood":{"preset":"golden_meadow","phase":0.4,"weather":"clear","clouds":0.14,"mist":0.08,"haze":0.12,"rays":0.45,"wind":0.25,"summit_mist":0.03,"exposure":1.1,
			"colors":{"sky":"8aaecb","horizon":"c7bcbe","glow":"f2cdb2","grass":"84aa5a","foliage":"8a8a4a","water":"64a0aa"}},
		"visuals":{"fog_density":0.03,"fog_height":2.5,"peak_density":0.0}},
	"alpine":{
		"title":"Alpine flower meadow",
		"land":"alpine_meadow",
		"terrain":{"composition":"mountain","archetype":"range","landform":"original","relief":[0.8,0.95],"breadth":[1.0,1.15]},
		"blend":[["woodland","facing",0.12,"shade"],["alpine","high",0.34,0]],
		"grass":{"green":"86b65c","weight":0.3,"straw":"b5ad7a","share":0.08,"tufts":0.12,"tuft_size":[0.35,0.55],"tuft_straw":0.1},
		"flowers":[["buttercup",1.0],["lupine",0.7],["oxeye_daisy",0.55],["dandelion",0.25]],
		"sizes":{"buttercup":[0.8,1.0],"lupine":[0.65,0.85],"oxeye_daisy":[0.75,0.95],"dandelion":[0.85,1.05]},
		"drift":{"frequency":0.2,"cover":0.62,"spacing":0.2,"density":1.0,"mix":0.3,"stray":0.02,"wash":0.45,"carpet":0.55},
		"trees":0,"rocks":0.06,
		"mood":{"preset":"alpine_morning","phase":0.4,"weather":"clear","clouds":0.14,"mist":0.06,"haze":0.08,"rays":0.35,"wind":0.35,"summit_mist":0.12,
			"colors":{"sky":"6f9fc4","horizon":"9fb6c6","glow":"e6dccb","grass":"7fa65c","foliage":"4e7a55","water":"4f93a3"}},
		"visuals":{"fog_density":0.0,"fog_height":4.0,"peak_density":0.08}},
}
## The order the New world screen lists them.
const ORDER := ["wildflower","sunflower","dandelion","cosmos","alpine"]
## The head width the candidate lattice packs whole (see `packing`).
const PACK_HEAD := 0.16
## Flower candidates stand no closer than this to a clearing's centre, the
## same ground inland_landscape.gd keeps open for the player.
const CLEARING := 1.15
## Meadow ground flowers stop this far below the snowline.
const SNOW_GAP := 1.2
## Drifts thin out between these distances from the centre, on the rounded
## square `_rim` measures: a meadow world sits on the old 28 m square, whose
## edge is at 12 m (2 m in from its rim), so the meadow runs to its rim
## instead of stopping two metres short. A sowing on a plain island, which
## may reach further, thins at PLATE_RIM instead (`rim_band`).
const RIM := Vector2(Plate.LEGACY_HALF-3.1,Plate.LEGACY_HALF-2.15)
const PLATE_RIM := Vector2(Plate.HALF-3.1,Plate.HALF-2.15)
## The flower candidates' lattice covers this half-width round the centre.
const REACH := Plate.LEGACY_HALF-2.1
## The yaw that turns a kit flower's face (its local +x) toward the noon
## sun's side of the plate: studies/celestial.gd's sun ring is yawed
## atan2(20, 12) round, so at noon the sun stands toward +x, +z, which is
## also the side the diorama camera starts on.
const SUN_FACE := -0.54

var id := ""
var type: Dictionary = {}
var plant_seed := 0
var salt := 0
var _drift := FastNoiseLite.new()
var _species := FastNoiseLite.new()
var _warp := FastNoiseLite.new()
var _straw := FastNoiseLite.new()
var _row := Vector2.RIGHT
## Where this meadow's drifts thin out: RIM, or PLATE_RIM on a plain.
var rim_band := RIM

## A meadow of type `type_id` for the world planted from `seed_value` (the
## genome's `plant_seed`).
func _init(type_id: String, seed_value: int) -> void:
	id = type_id
	type = TYPES.get(type_id,{})
	plant_seed = seed_value
	salt = Variety.mix([plant_seed,1931])
	if type.is_empty(): return
	var drift: Dictionary = type.drift
	_drift.seed = plant_seed+1901
	_drift.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_drift.frequency = float(drift.frequency)
	_drift.fractal_octaves = 2
	# One species per cell of a Voronoi field the size of a drift.
	_species.seed = plant_seed+1907
	_species.noise_type = FastNoiseLite.TYPE_CELLULAR
	_species.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	_species.cellular_jitter = 0.9
	_species.frequency = float(drift.frequency)*1.25
	_species.fractal_type = FastNoiseLite.FRACTAL_NONE
	# Drift borders interleave over about half a metre instead of a hard line.
	_warp.seed = plant_seed+1913
	_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_warp.frequency = 0.9
	_straw.seed = plant_seed+1919
	_straw.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_straw.frequency = 0.18
	_row = Vector2.from_angle(Variety.unit([salt,3])*PI)

static func has(type_id: String) -> bool:
	return TYPES.has(type_id)

## The type a recipe asks for, or "" for none.
static func of(settings: Dictionary) -> String:
	var value: Variant = settings.get("meadow","")
	return str(value) if value is String and TYPES.has(value) else ""

## The New world land that forms `type_id` (its name and description are
## scripts/world_library.gd LANDS'), and back.
static func land_id(type_id: String) -> String:
	return str(TYPES[type_id].land)

static func type_of_land(land: String) -> String:
	for type_id: String in TYPES:
		if TYPES[type_id].land == land: return type_id
	return ""

# --- Flower keys ----------------------------------------------------------------
## The asset placed for `kind`: the kit's own key once the catalog has it.
static func asset(kind: String) -> String:
	if kind in NativeTerrainData.ASSETS or not FLOWER_KEYS.has(kind): return kind
	return str(FLOWER_KEYS[kind].fallback)

static func standing_in(kind: String) -> bool:
	return FLOWER_KEYS.has(kind) and asset(kind) != kind

## The record tint for `kind` in colour `variant`, or "" for the asset's own.
static func tint(kind: String, variant: float) -> String:
	if not FLOWER_KEYS.has(kind): return ""
	var entry: Dictionary = FLOWER_KEYS[kind]
	if not standing_in(kind) and not entry.get("tint_real",false): return ""
	var tints: Array = entry.tints
	return NativeObjectPose.encode_tint(Color(tints[mini(int(variant*tints.size()),tints.size()-1)]).srgb_to_linear())

## The ground colour (sRGB) under a drift of `kind` in colour `variant`:
## the wash of the same colour `tint` picks for its heads.
static func wash_of(kind: String, variant: float) -> String:
	var entry: Dictionary = FLOWER_KEYS[kind]
	var washes: Array = entry.get("washes",[])
	if washes.is_empty(): return str(entry.wash)
	return str(washes[mini(int(variant*washes.size()),washes.size()-1)])

## A flower record's size and pose for `kind` at `size` (1 stands at the
## kind's own height) turned `angle`: [record size, pose]. The kit's mesh
## takes the size as it is; a stand-in is stretched to the kind's height and
## head width, and its record size is the head's stretch.
static func form(kind: String, size: float, angle: float, lift := 1.0) -> Array:
	if not standing_in(kind):
		if is_equal_approx(lift,1.0): return [size,{}]
		return [size,NativeObjectPose.make(Basis(Vector3.UP,angle)*Basis.from_scale(Vector3(size,size*lift,size)),0.0)]
	var entry: Dictionary = FLOWER_KEYS[kind]
	var stand_in: Array = FALLBACK_FORMS[entry.fallback]
	var across := size*float(entry.head)/float(stand_in[1])
	var up := size*float(entry.height)/float(stand_in[0])*lift
	var basis := Basis(Vector3.UP,angle)*Basis.from_scale(Vector3(across,up,across))
	return [clampf(across,0.1,5.0),NativeObjectPose.make(basis,0.0)]

# --- Composition ------------------------------------------------------------------
## How much of a drift stands at `p`: 1 at its heart, easing to 0 in the
## grass, and to nothing in the plate's last half metre (RIM).
func presence(p: Vector2) -> float:
	var cover := float(type.drift.cover)
	var at := lerpf(0.42,-0.42,cover)
	return smoothstep(at-0.12,at+0.22,_drift.get_noise_2d(p.x,p.y))*(1.0-smoothstep(rim_band.x,rim_band.y,_rim(p)))

## The drift's colour variant at `p` (0..1), shared by the whole drift.
func variant(p: Vector2) -> float:
	var q := _warped(p)
	return fposmod(_species.get_noise_2d(q.x,q.y)*0.5+0.5+0.37,1.0)

## Distance toward the plate's rim on a rounded square, so the meadow's
## edge follows the plate without drawing its corners.
static func _rim(p: Vector2) -> float:
	return pow(pow(absf(p.x),4.0)+pow(absf(p.y),4.0),0.25)

## `p` moved by up to about half a metre, so neighbouring drifts interleave
## at their border instead of meeting on a line.
func _warped(p: Vector2) -> Vector2:
	return p+Vector2(_warp.get_noise_2d(p.x,p.y),_warp.get_noise_2d(p.y+31.0,p.x-17.0))*0.55

## The kind a drift grows at `p`; `roll` (0..1) takes the drift's companion
## for its `mix` share.
func kind_at(p: Vector2, roll: float) -> String:
	var flowers: Array = type.flowers
	var weights: Array = flowers.map(func(entry: Array) -> float: return float(entry[1]))
	var q := _warped(p)
	var u := clampf(_species.get_noise_2d(q.x,q.y)*0.5+0.5,0.0,0.999)
	var first: int = Variety.weighted(weights,u)
	if roll < float(type.drift.mix) and flowers.size() > 1:
		var second: int = Variety.weighted(weights,fposmod(u*7.31+0.13,0.999))
		if second == first: second = (first+1)%flowers.size()
		return str(flowers[second][0])
	return str(flowers[first][0])

## The share of candidates `kind` keeps at a drift's heart, so its heads
## nearly touch there: PACK_HEAD (m) and smaller heads keep every one.
static func packing(kind: String) -> float:
	if not FLOWER_KEYS.has(kind): return 1.0
	if FLOWER_KEYS[kind].has("pack"): return float(FLOWER_KEYS[kind].pack)
	return clampf(pow(PACK_HEAD/float(FLOWER_KEYS[kind].head),2.0),0.0,1.0)

## True where a row-planted kind may stand: on loose rows across the field,
## wavering up to the rows' `waver` (m, 0.25 if absent) either side.
func on_row(p: Vector2, kind: String) -> bool:
	var rows: Dictionary = type.drift.get("rows",{})
	if rows.is_empty() or rows.kind != kind: return true
	var across := Vector2(-_row.y,_row.x).dot(p)+_warp.get_noise_2d(p.x*0.3,p.y*0.3)*float(rows.get("waver",0.25))
	var f := fposmod(across/float(rows.spacing),1.0)
	if rows.has("band"): return absf(f-0.5)*float(rows.spacing) < float(rows.band)*0.5
	return absf(f-0.5) < float(rows.width)

## How far the rows waver at `p` (m, across them), as `on_row` reads them.
func row_waver(p: Vector2) -> float:
	return _warp.get_noise_2d(p.x*0.3,p.y*0.3)*float(type.drift.get("rows",{}).get("waver",0.25))

## A flower record for `kind` at `p` from the hash `key`, sized by `draw`
## (0..1, or a hash) within the type's range for it:
## [asset, size, tint, pose, angle].
func flower(kind: String, p: Vector2, key: Array, draw := -1.0) -> Array:
	var span: Array = type.sizes.get(kind,[0.85,1.15])
	var size := lerpf(float(span[0]),float(span[1]),Variety.unit(key+[11]) if draw < 0.0 else draw)
	var angle := Variety.unit(key+[5])*TAU
	var rows: Dictionary = type.drift.get("rows",{})
	# A field of row-planted heads that `face` turns them all one way, the
	# noon sun's (SUN_FACE), each a little off it, as a real field does.
	if rows.get("face",false) and rows.kind == kind: angle = SUN_FACE+(Variety.unit(key+[5])-0.5)*0.8
	# A crop's clumps (`align`) turn their long side along the row, each a
	# little off it, so a row reads as one drilled line.
	if rows.get("align",false) and rows.kind == kind: angle = atan2(-_row.y,_row.x)+(Variety.unit(key+[5])-0.5)*0.5
	var shaped := form(kind,size,angle)
	return [asset(kind),shaped[0],tint(kind,variant(p)),shaped[1],angle]

## What emergence grows on new meadow ground at `p` from its `pick` and the
## candidate's `key`: a flower record (see `flower`), or ["grass_tuft"] a
## third of the time and more in the gaps between drifts.
func emerged(p: Vector2, pick: float, key: Array) -> Array:
	if pick < 0.3+0.4*(1.0-presence(p)): return ["grass_tuft"]
	var kind := kind_at(p,Variety.unit(key+[91]))
	if not on_row(p,kind): return ["grass_tuft"]
	return flower(kind,p,key)

## A clearing's flower patch prop (inland_landscape.gd `_dress_places`): a
## flower record (see `flower`) sized by `draw`, or ["grass_tuft"].
func clearing_kind(p: Vector2, roll: float, key: Array, draw: float) -> Array:
	if roll < 0.3: return ["grass_tuft"]
	return flower(kind_at(p,roll),p,key,draw)

# --- The meadow's ground --------------------------------------------------------------
## The ground colour (linear) and weight a meadow cell at `p` is painted with.
func ground(p: Vector2) -> Array:
	var grass: Dictionary = type.grass
	var green := Color(grass.green)
	var dry := smoothstep(0.55-float(grass.share)*1.3,0.85-float(grass.share)*1.3,_straw.get_noise_2d(p.x,p.y)*0.5+0.5) if float(grass.share) > 0.0 else 0.0
	var colour := green.lerp(Color(grass.straw),dry*0.85)
	var d := presence(p)
	var kind := kind_at(p,1.0)
	var wash := Color(wash_of(kind,variant(p))) if FLOWER_KEYS.has(kind) else colour
	# Under a drift's core the ground itself carries the flower's colour, so
	# the carpet has no green between its heads from the diorama camera. The
	# wash follows the flowers that actually stand there (presence, the drift's
	# density and how close its heads pack), so it fades before the flowers do
	# and never runs past them. A fine noise breaks its edge into feathers,
	# and a low kind that hides little ground (`cover`) washes it less: the
	# ground supports the heads instead of standing in for them.
	var standing := float(type.drift.density)*pow(d,1.2)*packing(kind) if FLOWER_KEYS.has(kind) else 0.0
	var feather := clampf(0.7+0.6*_warp.get_noise_2d(p.x*2.6+40.0,p.y*2.6-23.0),0.0,1.0)
	var core := smoothstep(0.3,0.9,standing)*lerpf(feather,1.0,smoothstep(0.75,1.0,standing))
	var hides := float(FLOWER_KEYS[kind].get("cover",1.0)) if FLOWER_KEYS.has(kind) else 1.0
	colour = colour.lerp(wash,float(type.drift.wash)*core*hides)
	# The paint fades out in the plate's last metre, so the meadow has no frame.
	var rim := 1.0-smoothstep(rim_band.x+0.5,rim_band.y+1.0,_rim(p))
	return [colour.srgb_to_linear(),lerpf(float(grass.weight),float(type.drift.get("carpet",grass.weight)),core*hides)*rim]

## Dresses the meadow ground of an inland world being formed by `land`
## (scripts/inland_landscape.gd): ground paint, flower drifts, grass tufts
## and stones on every point whose habitat is "meadow".
func dress(land: RefCounted, work: RefCounted) -> void:
	var data: NativeTerrainData = land.data
	var snow := BiomeBlend.snowline(data._recipe_settings,99.0)
	var meadow_index: int = land.blend.biomes.find("meadow") if land.blend != null else -1
	# The painted ground: meadow cells, faded by the meadow's weight at an edge.
	var tint := data.tint
	var blades := data.blades
	var tufted := data.meadow
	for z in range(data.MEADOW_CELLS):
		if z%8 == 0: await work.checkpoint()
		for x in range(data.MEADOW_CELLS):
			var p := data.meadow_position(x,z)+Vector2.ONE*data.MEADOW_STEP*0.5
			if maxf(absf(p.x),absf(p.y)) > Plate.LEGACY_HALF-1.0 or land._is_wet(p): continue
			var share := 1.0
			if land.blend != null: share = land.blend.weight(meadow_index,p) if meadow_index >= 0 else 0.0
			elif land.genome.habitat != "meadow": share = 0.0
			if share <= 0.02: continue
			# A typed meadow is painted ground and its own flowers: no standing
			# blades or tuft flowers round its clearings, which read as dark
			# stubble among the drifts.
			if land._habitat(p) == "meadow":
				blades[z*data.MEADOW_CELLS+x] = 0.0
				tufted[z*data.MEADOW_CELLS+x] = 0.0
			var painted := ground(p)
			var k := (z*data.MEADOW_CELLS+x)*NativeTerrainTint.STRIDE
			tint[k] = painted[0].r
			tint[k+1] = painted[0].g
			tint[k+2] = painted[0].b
			tint[k+3] = float(painted[1])*share
	data.tint = tint
	data.blades = blades
	data.meadow = tufted
	var drift: Dictionary = type.drift
	var spacing := float(drift.spacing)
	var steps := int(ceil(2.0*REACH/spacing))
	for gz in range(steps):
		if gz%4 == 0: await work.checkpoint()
		for gx in range(steps):
			var key := [salt,71,gx,gz]
			var p := Vector2(-REACH+(gx+Variety.unit(key+[1]))*spacing,-REACH+(gz+Variety.unit(key+[2]))*spacing)
			# The cheap draws first: most candidates fall in the grass.
			var d := presence(p)
			var roll := Variety.unit(key+[3])
			if roll >= float(drift.density)*pow(d,1.2)+float(drift.stray): continue
			var kind := kind_at(p,Variety.unit(key+[4]))
			# Heads nearly touch in a drift's core: a wide head takes more ground.
			if roll >= (float(drift.density)*pow(d,1.2)+float(drift.stray))*packing(kind): continue
			if not on_row(p,kind) or not _meadow_ground(land,p,snow): continue
			var record := flower(kind,p,key)
			if data.place(record[0],p,record[4],record[1],record[3],record[2]) < 0: return
	# Grass tufts in the gaps between drifts, few inside one; some straw-tinted
	# in a dry meadow. Stones on a stony one.
	var grass: Dictionary = type.grass
	for gz in range(27):
		if gz%6 == 0: await work.checkpoint()
		for gx in range(27):
			var key := [salt,73,gx,gz]
			var p := Vector2(-REACH+(gx+Variety.unit(key+[1]))*0.88,-REACH+(gz+Variety.unit(key+[2]))*0.88)
			if not _meadow_ground(land,p,snow): continue
			var stones := float(type.rocks)
			if stones > 0.0 and Variety.unit(key+[6]) < stones:
				var boulder := Variety.unit(key+[7]) < 0.15
				data.place("boulder_"+str(1+int(Variety.unit(key+[8])*4.0)%4) if boulder else "rock",p,Variety.unit(key+[5])*TAU,
					lerpf(0.3,0.55,Variety.unit(key+[9])) if boulder else lerpf(0.25,0.5,Variety.unit(key+[9])))
				continue
			if Variety.unit(key+[3]) >= float(grass.tufts)*(1.0-0.85*presence(p)): continue
			var span: Array = grass.tuft_size
			var straw := Variety.unit(key+[4]) < float(grass.tuft_straw)
			var tint_text := NativeObjectPose.encode_tint(Color(grass.straw).srgb_to_linear()) if straw else ""
			data.place("grass_tuft",p,Variety.unit(key+[5])*TAU,lerpf(float(span[0]),float(span[1]),Variety.unit(key+[9])),{},tint_text)

func _meadow_ground(land: RefCounted, p: Vector2, snow: float) -> bool:
	var data: NativeTerrainData = land.data
	var h: Variant = data.ground_height(p)
	if h == null or float(h) > snow-SNOW_GAP or land._is_wet(p) or land._clearing(p): return false
	if land._habitat(p) != "meadow": return false
	return Presets._slope(data,p) <= 0.75
