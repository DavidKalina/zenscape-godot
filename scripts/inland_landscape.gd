extends RefCounted
const Plate = preload("res://scripts/plate.gd")
const Desert = preload("res://scripts/desert_landscape.gd")
## The band the generator plants, half-widths in x and z: 3 and 3.5 m in
## from the edge of the old 28 m square a generated world sits on, so its
## fixed try counts plant the density they were tuned for.
const BAND := Vector2(Plate.LEGACY_HALF-3.0,Plate.LEGACY_HALF-3.5)
const Variety = preload("res://scripts/seeded_variety.gd")
const Stands = preload("res://scripts/tree_stands.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")
## Generated worlds draw emergence's species pools, but a redwood world stays
## led by redwoods, which carry its canopy mist (redwood_biome_mist.gd), and a
## desert's few trees by Joshua trees, its silhouette; spruce, broadleaf and
## juniper come as companions and the odd stand.
const TREE_POOLS := {
	"redwood":{"redwood":3.0,"tree":0.45,"broadleaf":0.15},
	"arid":{"joshua":2.0,"cactus":0.8,"juniper":0.4,"broadleaf":0.0,"willow":0.0},
}
## Low-cover candidates per habitat; any other habitat draws 250.
const COVER := {"arid":25,"wetland":620}
var data: NativeTerrainData
var genome: Dictionary
## Present only for recipes with a biome blend (scripts/biome_blend.gd).
## Without one, every habitat choice below is the genome's single habitat.
var blend: RefCounted
## 1 when the recipe asks for seeded prop variety (generated worlds since the
## seeded-variants work). 0 keeps the old fixed cycles, so older saves dress
## exactly as before.
var variety := 0
## This world's key for variety hashes, from the planting seed.
var salt := 0
## The key tree stands hash from (scripts/tree_stands.gd): the salt emergence
## gives this world, so a forest painted later grows on in the same stands.
var stand_salt := 0
## The moisture, altitude and water distance stands lean by: the blend, or for
## a one-habitat world a plain field over its terrain.
var _stand_field: RefCounted
var _pools: Dictionary = Stands.TREE_POOLS.merged(TREE_POOLS,true)
var _drift: FastNoiseLite
## The recipe's meadow type (scripts/meadow_types.gd), or null: its meadow
## ground is dressed by the type, not by the cover cycle below.
var meadow: RefCounted
func form(terrain: NativeTerrainData,settings: Dictionary,tree: SceneTree = null) -> void:
	data = terrain
	data.reset_flat()
	if not await data._set_recipe(settings,tree): return
	genome = data._recipe.inland.genome
	variety = int(settings.get("variety",0))
	salt = Variety.mix([int(genome.plant_seed),7])
	_drift = FastNoiseLite.new()
	_drift.seed = int(genome.plant_seed)+53
	_drift.frequency = 0.3
	meadow = null
	if not MeadowTypes.of(settings).is_empty(): meadow = MeadowTypes.new(MeadowTypes.of(settings),int(genome.plant_seed))
	data.grass.fill(preload("res://scripts/native_formation_shape.gd").BIOMES[genome.habitat].grass)
	data.heights = data._recipe_heights.duplicate()
	data.ponds.assign(data._recipe.inland.ponds.duplicate(true))
	data.streams.assign(data._recipe.inland.streams.duplicate(true))
	var work = preload("res://scripts/frame_work_budget.gd").new(tree)
	if settings.has("blend"):
		blend = preload("res://scripts/biome_blend.gd").new(genome,data._recipe.inland.sampler)
		blend.apply(genome.habitat,settings.blend)
		await work.checkpoint()
		# Ground cover follows the habitats, so the mesh colour and the dense
		# grass mask grade between them too.
		for z in range(data.MEADOW_CELLS):
			for x in range(data.MEADOW_CELLS):
				data.grass[z*data.MEADOW_CELLS+x] = blend.cover(data.meadow_position(x,z)+Vector2.ONE*0.25)
	# Flood connected pools once, including salt pans.
	if genome.composition in ["marsh","salt-basin"]:
		var masks: Array = []
		var unique: Array[Dictionary] = []
		for pond in data.ponds:
			await work.checkpoint()
			var field: Dictionary = NativeRecipeWater.field(data,pond)
			if field.is_empty() or field.wet in masks: continue
			masks.append(field.wet)
			unique.append(pond)
		data.ponds = unique
	# Independent planting stream; habitat changes cannot alter terrain or water.
	var rng := RandomNumberGenerator.new()
	rng.seed = genome.plant_seed
	var budget: int = _tree_budget(genome.habitat)
	# A blend plants each habitat's own density on its share of the ground.
	# Thinning uses a position hash, so the planting stream is not disturbed.
	var densest := 1.0
	if blend != null:
		var total := 0.0
		for b: String in blend.biomes:
			total += blend.share(b)*_tree_budget(b)
			densest = maxf(densest,_tree_budget(b))
		budget = int(total)
	budget = int(budget*float(genome.tree_density))
	stand_salt = Variety.mix([int(genome.plant_seed),97])
	_stand_field = blend
	if _stand_field == null and variety >= 1 and budget > 0:
		_stand_field = preload("res://scripts/biome_blend.gd").new(genome,data._recipe.inland.sampler)
		_stand_field.apply(genome.habitat,[])
	var planted := 0
	var occupied: Array[Vector2] = []
	var habitat_noise := FastNoiseLite.new()
	habitat_noise.seed = genome.plant_seed
	habitat_noise.frequency = 0.22
	for i in range(1600 if budget>0 else 0):
		if i%16 == 0: await work.checkpoint()
		var p := Vector2(rng.randf_range(-BAND.x,BAND.x),rng.randf_range(-BAND.y,BAND.y))
		var angle := rng.randf()*TAU
		var size := rng.randf_range(0.6,1.05)
		var pick := rng.randf()
		if data.ground_height(p) == null: continue
		var h: float = data.ground_height(p)
		if _is_wet(p) or _is_salt(p) or _clearing(p): continue
		if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.85: continue
		var habitat := _habitat(p)
		var treeline := float(genome.treeline) if habitat == "alpine" else 10.0
		if h>treeline: continue
		if habitat_noise.get_noise_2d(p.x,p.y)<-0.15: continue
		if blend != null and _hash(p)*densest>=_tree_budget(habitat): continue
		var crowded := false
		for other in occupied:
			if other.distance_squared_to(p)<1.2: crowded = true; break
		if crowded: continue
		var kind: String = "tree"
		var tint := ""
		# Seeded worlds plant emergence's species by stand, with its crown
		# colours and autumns; the stand draws are hashes, and `pick` comes
		# from the planting stream as before.
		var key := [stand_salt,61,i]
		var by_stand := variety >= 1 and habitat != "wetland"
		if by_stand:
			kind = Stands.tree_kind(habitat,p,pick,Variety.unit(key+[25]),stand_salt,_stand_field,_pools)
			tint = Stands.tree_tint(kind,p,key,stand_salt,_stand_field)
		elif habitat == "woodland": kind = "layered_tree" if pick<0.15 else "broadleaf" if pick<0.6 else "tree"
		elif habitat == "redwood": kind = "redwood"
		elif habitat == "arid": kind = "joshua" if pick<0.55 else "cactus"
		elif habitat == "wetland": kind = "reeds"
		if data.place(kind,p,angle,size,{},tint)>=0:
			if by_stand: data.objects.back()["autumn"] = Stands.autumn(p,stand_salt,_stand_field)
			planted += 1
			occupied.append(p)
		if planted>=budget: break
	# Low cover gives marsh/meadow their own habitat beyond a palette swap.
	# A blend draws enough candidates for its densest habitat and thins the
	# rest to their own density.
	var cover_count: int = COVER.get(genome.habitat,250)
	if blend != null:
		for b: String in blend.biomes: cover_count = maxi(cover_count,COVER.get(b,250))
	for i in range(cover_count):
		if i%16 == 0: await work.checkpoint()
		var p := Vector2(rng.randf_range(-BAND.x,BAND.x),rng.randf_range(-BAND.y,BAND.y))
		if data.ground_height(p) == null or _is_salt(p): continue
		var habitat := _habitat(p)
		if blend != null and _hash(p+Vector2(0.71,0.29))*cover_count>=COVER.get(habitat,250): continue
		if meadow != null and habitat == "meadow": continue
		if (_is_wet(p) and not (habitat == "wetland" and float(data.ground_height(p))>1.30)) or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.6: continue
		if data.ground_height(p)>5.0: continue
		var kind: String
		if variety >= 1: kind = _cover_kind(habitat,p)
		else:
			kind = "reeds" if habitat == "wetland" else ["daisy_flower","button_flower","spike_flower","grass_tuft"][i%4] if habitat == "meadow" else "shrub" if habitat == "arid" else "grass_tuft"
			if habitat in ["woodland","redwood"]:
				if i%29 == 0: kind = "log"
				elif i%31 == 0: kind = "stump"
				elif i%37 == 0: kind = "snag"
				elif i%11 == 0: kind = "fern"
				elif i%13 == 0: kind = "mushroom"
		if habitat == "wetland":
			# Marsh worlds sit at one water level. A wet corner of another world
			# keeps reeds at the water's edge and bank grass behind them.
			if blend == null or genome.habitat == "wetland":
				if float(data.ground_height(p))>1.65: kind = "bank_grass"
			elif blend.water_distance(p)>1.6: kind = "bank_grass"
		data.place(kind,p,rng.randf()*TAU,rng.randf_range(0.5,0.9))
	if int(genome.version)>=4: await _dress_places(work)
	if meadow != null: await meadow.dress(self,work)
	data.objects_revision += 1
	data.discard_cache()

func _habitat(p: Vector2) -> String:
	return genome.habitat if blend == null else blend.pick(p)

func _tree_budget(habitat: String) -> int:
	if habitat == "meadow" and meadow != null: return int(meadow.type.trees)
	return {"alpine":int(genome.tree_count),"woodland":int(genome.tree_count)+int(genome.broadleaf_count),"meadow":0 if genome.composition == "meadow" else 15,"wetland":0,"arid":12,"redwood":70}[habitat]

## A stable 0..1 value per position, so thinning a blend consumes no draws.
static func _hash(p: Vector2) -> float:
	return fposmod(sin(p.x*39.3468+p.y*11.1353)*24634.6345,1.0)

func _is_wet(p: Vector2) -> bool:
	if data.ground_height(p) == null: return true
	if int(genome.version)>=4: return data._recipe.inland.sampler.wet(p)
	for route in data.streams:
		for point in route.pts:
			if p.distance_squared_to(Vector2(point.x,point.z))<pow(float(route.width)*0.6+0.4,2.0): return true
	for pool: Dictionary in data.ponds:
		if genome.composition in ["marsh","salt-basin"]:
			if float(data.ground_height(p))<float(pool.level)+0.08: return true
		elif Vector2((p.x-pool.x)/pool.basin[0],(p.y-pool.z)/pool.basin[1]).length()<1.05: return true
	return false

func _is_salt(p: Vector2) -> bool:
	return genome.composition == "salt-basin" and Desert.field(genome,p).z>0.25


func _clearing(p: Vector2) -> bool:
	for place: Dictionary in data._recipe.inland.sampler.places:
		if p.distance_to(place.center)<1.15: return true
	return false

func _dress_places(work: RefCounted) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(genome.plant_seed)+967
	var palettes := {
		"woodland":["fern","mushroom","grass_tuft","fern"],
		"redwood":["fern","fern","mushroom","grass_tuft"],
		"alpine":["grass_tuft","rock","grass_tuft","grass_tuft"],
		"meadow":["daisy_flower","button_flower","spike_flower","grass_tuft"],
		"wetland":["bank_grass","reeds","rock","grass_tuft"],
		"arid":["rock","shrub","shrub","grass_tuft"]}
	# Fine ground cover binds the small props into patches instead of isolated dots.
	if genome.habitat!="arid":
		for z in range(data.MEADOW_CELLS):
			if z%4==0: await work.checkpoint()
			for x in range(data.MEADOW_CELLS):
				var p := data.meadow_position(x,z)+Vector2.ONE*0.25
				if maxf(absf(p.x),absf(p.y))>BAND.x or _is_wet(p): continue
				var near := false
				for place: Dictionary in data._recipe.inland.sampler.places:
					if p.distance_to(place.center)<float(place.radius)+1.8: near = true
				if not near or preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.65: continue
				data.blades[z*data.MEADOW_CELLS+x] = 0.35
				if _habitat(p)=="meadow": data.meadow[z*data.MEADOW_CELLS+x] = 0.16
	var place_index := -1
	for place: Dictionary in data._recipe.inland.sampler.places:
		place_index += 1
		# A log, rock grouping or flower patch gives each clearing an edge;
		# the middle stays available for Bigfoot and the player's own objects.
		# In a blend, each clearing is dressed for the habitat it sits in.
		var habitat := _habitat(place.center)
		var cluster := Vector2.from_angle(rng.randf()*TAU)
		var anchor: Vector2 = place.center+cluster*1.45
		var focal := "log" if habitat in ["woodland","redwood"] and int(place.kind)==0 else "boulder_"+str(1+int(place.kind))
		if not _is_wet(anchor) and not _is_salt(anchor):
			data.place(focal,anchor,rng.randf()*TAU,0.55)
			if variety >= 1 and focal.begins_with("boulder_"): _satellites(anchor,place_index)
		var planted := 0
		for attempt in range(160):
			if attempt%16==0: await work.checkpoint()
			var p: Vector2 = anchor+Vector2.from_angle(rng.randf()*TAU)*sqrt(rng.randf())*1.8
			if p.distance_to(place.center)<0.95 or _is_wet(p) or _is_salt(p): continue
			if preload("res://scripts/native_landscape_presets.gd")._slope(data,p)>0.65: continue
			var choices: Array = palettes[habitat]
			var kind: String = choices[(planted+int(place.kind))%choices.size()] if variety < 1 else _place_kind(choices,place_index,attempt)
			# Angle, then size: the planting stream's order as it always was.
			var angle := rng.randf()*TAU
			var size := rng.randf_range(0.5,0.85)
			var tint := ""
			var pose := {}
			if meadow != null and habitat == "meadow":
				var key := [salt,42,place_index,attempt]
				var typed: Array = meadow.clearing_kind(p,Variety.unit(key),key,inverse_lerp(0.5,0.85,size))
				kind = typed[0]
				if typed.size() > 1:
					size = typed[1]
					tint = typed[2]
					pose = typed[3]
					angle = typed[4]
			if data.place(kind,p,angle,size,pose,tint)>=0: planted += 1
			if planted>=28: break

## Seeded low cover. Rates and flower mixes lean per world, and a position
## hash picks the kind, so neither the planting stream nor a fixed cycle
## shows. Meadow flowers follow a low-frequency drift, so each species
## gathers into its own patches instead of alternating plant by plant.
func _cover_kind(habitat: String, p: Vector2) -> String:
	var roll := Variety.unit([salt,31]+Variety.cell(p))
	match habitat:
		"wetland": return "reeds"
		"meadow":
			if roll < clampf(0.25*Variety.lean(salt,"tuft"),0.12,0.4): return "grass_tuft"
			var flowers := ["daisy_flower","button_flower","spike_flower","umbel_flower"]
			var weights := []
			for f: String in flowers: weights.append((0.4 if f == "umbel_flower" else 1.0)*Variety.lean(salt,f))
			var drift := clampf(_drift.get_noise_2d(p.x,p.y)*0.6+0.5+(Variety.unit([salt,32]+Variety.cell(p))-0.5)*0.3,0.0,0.999)
			return flowers[Variety.weighted(weights,drift)]
		"woodland","redwood":
			var fern := 1.5 if habitat == "redwood" else 1.0
			for entry in [["log",1.0/29.0],["stump",1.0/31.0],["snag",1.0/37.0],["fern",fern/11.0],["mushroom",1.0/13.0]]:
				roll -= float(entry[1])*Variety.lean(salt,entry[0])
				if roll < 0.0: return entry[0]
			return "grass_tuft"
		"alpine": return "rock" if roll < 0.1*Variety.lean(salt,"rock") else "grass_tuft"
		"arid":
			var stones := 0.16*Variety.lean(salt,"rock")
			if roll < stones: return "rock"
			return "grass_tuft" if roll < stones+0.1*Variety.lean(salt,"tuft") else "shrub"
	return "grass_tuft"

## A clearing prop from the habitat's palette, weighted by how often the
## palette lists it and leaned per world.
func _place_kind(choices: Array, place_index: int, attempt: int) -> String:
	var kinds := []
	var weights := []
	for kind: String in choices:
		var at := kinds.find(kind)
		if at < 0:
			kinds.append(kind)
			weights.append(0.0)
			at = kinds.size()-1
		weights[at] += Variety.lean(salt,kind)
	return kinds[Variety.weighted(weights,Variety.unit([salt,41,place_index,attempt]))]

## One to three small stones around a clearing's focal boulder, so it reads
## as a weathered group rather than a single rock.
func _satellites(anchor: Vector2, place_index: int) -> void:
	var count := 1+Variety.mix([salt,43,place_index])%3
	for n in range(count):
		var key := [salt,44,place_index,n]
		var q := anchor+Vector2.from_angle(Variety.unit(key+[1])*TAU)*lerpf(0.55,0.95,Variety.unit(key+[2]))
		if _is_wet(q) or _is_salt(q) or preload("res://scripts/native_landscape_presets.gd")._slope(data,q)>0.65: continue
		data.place("rock",q,Variety.unit(key+[3])*TAU,lerpf(0.26,0.45,Variety.unit(key+[4])))
