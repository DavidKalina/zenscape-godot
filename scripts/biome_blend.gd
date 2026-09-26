extends RefCounted
## Two or three habitats per generated inland world.
##
## The recipe's `biome` stays the dominant habitat: it still sets the rock
## slope, the redwood mist and anything else read per world. An optional
## `blend` list adds up to two more habitats, and each one claims ground by a
## single rule:
##   moist   near water and low ground
##   high    normalised altitude
##   low     the inverse of high
##   facing  slopes that face the layer's `turn` (degrees; 0 faces +z, 180 -z)
## Layers apply in order, so a later layer wins where rules overlap. Every edge
## is a smoothstep broken up by noise, so habitats grade into each other.
##
## A layer is {"biome","by","at","soft","turn"}, all numbers integers (at and
## soft in hundredths), so a saved recipe replays exactly after JSON. Recipes
## without `blend`, which is every save from before this, dress as they always
## did. The generator derives the blend from the terrain seed (`plan`).
const Genome = preload("res://scripts/inland_genome.gd")
const Shape = preload("res://scripts/native_formation_shape.gd")
const RULES := ["moist","high","low","facing"]
const MAX_LAYERS := 2
## One-metre cells across the 28 m plate.
const CELLS := 28
const JITTER := 0.08
## Metres. Woodland below alpine ground stays under the rock band, which the
## mesh paints from 1.8 m below the alpine snowline.
const WOOD_CEILING := 5.5

var biomes: Array[String] = []
var layers: Array = []
var shares := PackedFloat32Array()
var has_water := false
## Land height range in metres (3rd percentile to the top).
var low := 0.0
var top := 0.0
var _land := PackedByteArray()
var _altitude := PackedFloat32Array()
var _moist := PackedFloat32Array()
var _water_distance := PackedFloat32Array()
var _facing := PackedVector2Array()
var _jitter := PackedFloat32Array()
var _weights: Array[PackedFloat32Array] = []

## Reads the terrain once. `sampler` is the inland heightfield (height, wet).
func _init(genome: Dictionary,sampler: RefCounted) -> void:
	var count := CELLS*CELLS
	var heights := PackedFloat32Array()
	heights.resize(count)
	_land.resize(count)
	_jitter.resize(count)
	_water_distance.resize(count)
	var noise := FastNoiseLite.new()
	noise.seed = int(genome.plant_seed)+3301
	noise.frequency = 0.16
	var land_heights := PackedFloat32Array()
	for z in range(CELLS):
		for x in range(CELLS):
			var i := z*CELLS+x
			var p := _center(x,z)
			heights[i] = sampler.height(p.x,p.y)
			var inside := maxf(absf(p.x),absf(p.y))<12.5 and Genome.has_ground(genome,p)
			_land[i] = 1 if inside else 0
			_jitter[i] = noise.get_noise_2d(p.x,p.y)*JITTER
			var wet: bool = sampler.wet(p)
			_water_distance[i] = 0.0 if wet else 1e6
			if inside:
				land_heights.append(heights[i])
				if wet: has_water = true
	land_heights.sort()
	if land_heights.is_empty(): land_heights.append(0.0)
	low = land_heights[int((land_heights.size()-1)*0.03)]
	top = land_heights[-1]
	var span := maxf(top-low,0.5)
	# Two-pass chamfer distance to the nearest wet cell, in metres.
	for pass_index in range(2):
		var order := range(count) if pass_index==0 else range(count-1,-1,-1)
		var step := -1 if pass_index==0 else 1
		for i in order:
			var x: int = i%CELLS
			var z: int = i/CELLS
			var d := _water_distance[i]
			for offset: Vector3 in [Vector3(step,0,1.0),Vector3(0,step,1.0),Vector3(step,step,1.414),Vector3(-step,step,1.414)]:
				var nx := x+int(offset.x)
				var nz := z+int(offset.y)
				if nx<0 or nz<0 or nx>=CELLS or nz>=CELLS: continue
				d = minf(d,_water_distance[nz*CELLS+nx]+offset.z)
			_water_distance[i] = d
	_altitude.resize(count)
	_moist.resize(count)
	_facing.resize(count)
	for z in range(CELLS):
		for x in range(CELLS):
			var i := z*CELLS+x
			var a := clampf((heights[i]-low)/span,0.0,1.0)
			_altitude[i] = a
			_moist[i] = 0.7*exp(-_water_distance[i]/2.5)+0.3*(1.0-a)
			var gradient := Vector2(heights[z*CELLS+mini(x+1,CELLS-1)]-heights[z*CELLS+maxi(x-1,0)],heights[mini(z+1,CELLS-1)*CELLS+x]-heights[maxi(z-1,0)*CELLS+x])*0.5
			var steep := clampf(gradient.length()/0.5,0.0,1.0)
			_facing[i] = -gradient.normalized()*steep if gradient.length()>0.0001 else Vector2.ZERO

static func _center(x: int,z: int) -> Vector2:
	return Vector2(-14.0+x+0.5,-14.0+z+0.5)

func _signal(rule: String,i: int,turn: int) -> float:
	match rule:
		"moist": return _moist[i]
		"high": return _altitude[i]
		"low": return 1.0-_altitude[i]
		_:
			var angle := deg_to_rad(float(turn))
			return 0.5+0.5*_facing[i].dot(Vector2(sin(angle),cos(angle)))

## Build the per-cell weights for the dominant habitat plus its layers.
func apply(base: String,blend: Array) -> void:
	biomes.assign([base])
	layers = blend.duplicate(true)
	for layer: Dictionary in layers: biomes.append(str(layer.biome))
	_weights.clear()
	for b in biomes:
		var values := PackedFloat32Array()
		values.resize(CELLS*CELLS)
		_weights.append(values)
	shares.resize(biomes.size())
	shares.fill(0.0)
	var land_count := 0
	var w := PackedFloat32Array()
	w.resize(biomes.size())
	for i in range(CELLS*CELLS):
		w.fill(0.0)
		w[0] = 1.0
		for k in range(layers.size()):
			var layer: Dictionary = layers[k]
			var at := float(layer.at)/100.0
			var soft := maxf(float(layer.soft)/100.0,0.01)
			var t := smoothstep(at-soft,at+soft,_signal(str(layer.by),i,int(layer.turn))+_jitter[i])
			for j in range(k+1): w[j] *= 1.0-t
			w[k+1] = t
		for j in range(biomes.size()):
			_weights[j][i] = w[j]
			if _land[i]==1: shares[j] += w[j]
		if _land[i]==1: land_count += 1
	for j in range(biomes.size()): shares[j] /= maxf(1.0,float(land_count))

func _bilinear(values: PackedFloat32Array,p: Vector2) -> float:
	var g := p+Vector2(14.0-0.5,14.0-0.5)
	var x0 := clampi(int(floor(g.x)),0,CELLS-1)
	var z0 := clampi(int(floor(g.y)),0,CELLS-1)
	var x1 := mini(x0+1,CELLS-1)
	var z1 := mini(z0+1,CELLS-1)
	var fx := clampf(g.x-x0,0.0,1.0)
	var fz := clampf(g.y-z0,0.0,1.0)
	return lerpf(lerpf(values[z0*CELLS+x0],values[z0*CELLS+x1],fx),lerpf(values[z1*CELLS+x0],values[z1*CELLS+x1],fx),fz)

func weight(index: int,p: Vector2) -> float:
	return _bilinear(_weights[index],p)

## The habitat at a point, dithered through the soft edges with a stable
## position hash so no planting random number is consumed.
func pick(p: Vector2) -> String:
	var u := fposmod(sin(p.x*12.9898+p.y*78.233)*43758.5453,1.0)
	for j in range(biomes.size()-1,0,-1):
		var share := weight(j,p)
		if u<share: return biomes[j]
		u -= share
	return biomes[0]

## Ground cover for the grass layer; alpine ground thins toward the summit.
func cover(p: Vector2) -> float:
	var altitude := _bilinear(_altitude,p)
	var total := 0.0
	for j in range(biomes.size()):
		var value: float = Shape.BIOMES[biomes[j]].grass
		if biomes[j]=="alpine": value = lerpf(value,0.5,smoothstep(0.7,1.0,altitude))
		total += weight(j,p)*value
	return total

func water_distance(p: Vector2) -> float:
	return _bilinear(_water_distance,p)

func share(biome: String) -> float:
	var index := biomes.find(biome)
	return shares[index] if index>=0 else 0.0

func _quantile(rule: String,turn: int,fraction: float) -> float:
	var values := PackedFloat32Array()
	for i in range(CELLS*CELLS):
		if _land[i]==1: values.append(_signal(rule,i,turn)+_jitter[i])
	if values.is_empty(): return 0.5
	values.sort()
	return values[clampi(int(fraction*(values.size()-1)),0,values.size()-1)]

## Metres to normalised altitude for this world.
func _altitude_of(height: float) -> float:
	return (height-low)/maxf(top-low,0.5)

## Choose the extra habitats for a generated world from its seed and terrain.
## `world` is the chosen inland_world (genome, sampler, ponds and streams).
## Deserts keep one habitat: their ground comes from the desert geology.
static func plan(recipe: Dictionary,world: RefCounted) -> Array:
	var base := str(recipe.biome)
	if base=="arid": return []
	var rng := RandomNumberGenerator.new()
	rng.seed = int(recipe.seed)*7919+4441
	var field = new(world.genome,world.sampler)
	var wet: bool = field.has_water
	var sun := int(rng.randf_range(-60.0,60.0)+360.0)%360
	var shade := (sun+180)%360
	# [habitat, rule, share of the land, turn]
	var picks: Array = []
	match base:
		"alpine":
			picks.append(["woodland","low",rng.randf_range(0.35,0.5),0])
			var roll := rng.randf()
			if wet and roll<0.6: picks.append(["meadow","moist",rng.randf_range(0.12,0.22),0])
			elif not wet and roll<0.35: picks.append(["meadow","facing",rng.randf_range(0.15,0.25),sun])
		"woodland":
			if rng.randf()<0.8: picks.append(["meadow","moist" if wet else "low",rng.randf_range(0.2,0.35),0])
			var roll := rng.randf()
			if field.top>8.0 and roll<0.85: picks.append(["alpine","high",rng.randf_range(0.15,0.3),0])
			elif wet and roll<0.45: picks.append(["wetland","moist",rng.randf_range(0.08,0.15),0])
			if picks.is_empty(): picks.append(["meadow","facing",rng.randf_range(0.2,0.3),sun])
		"redwood":
			if rng.randf()<0.7: picks.append(["woodland","facing",rng.randf_range(0.25,0.4),sun])
			if rng.randf()<0.5 or picks.is_empty(): picks.append(["meadow","moist" if wet else "low",rng.randf_range(0.12,0.2),0])
		"meadow":
			if rng.randf()<0.8:
				if rng.randf()<0.5: picks.append(["woodland","facing",rng.randf_range(0.25,0.4),shade])
				else: picks.append(["woodland","high",rng.randf_range(0.2,0.35),0])
			if wet and rng.randf()<0.55: picks.append(["wetland","moist",rng.randf_range(0.1,0.18),0])
			if picks.is_empty(): picks.append(["woodland","high",rng.randf_range(0.2,0.3),0])
		"wetland":
			if rng.randf()<0.9: picks.append(["meadow","high",rng.randf_range(0.3,0.45),0])
			if rng.randf()<0.5 or picks.is_empty(): picks.append(["woodland","high",rng.randf_range(0.1,0.2),0])
	var blend: Array = []
	for item: Array in picks.slice(0,MAX_LAYERS):
		var rule: String = item[1]
		var at: float = field._quantile(rule,int(item[3]),1.0-float(item[2]))
		if item[0]=="alpine" and rule=="high":
			# Claim everything above the woodland ceiling, so no broadleaf
			# stands on the rock band below the snow.
			at = minf(at,field._altitude_of(WOOD_CEILING))
		elif base=="alpine" and item[0]=="woodland" and rule=="low":
			at = maxf(at,1.0-field._altitude_of(minf(WOOD_CEILING,float(world.genome.treeline))))
		blend.append({"biome":item[0],"by":rule,"at":clampi(roundi(at*100.0),0,100),"soft":roundi(rng.randf_range(0.06,0.12)*100.0),"turn":int(item[3])})
	# Drop a habitat that ends up with almost no ground.
	field.apply(base,blend)
	var kept: Array = []
	for layer: Dictionary in blend:
		if field.share(layer.biome)>=0.04: kept.append(layer)
	return kept

static func valid(blend: Variant,base: Variant) -> bool:
	if not blend is Array or blend.is_empty() or blend.size()>MAX_LAYERS: return false
	var seen := [base]
	for layer: Variant in blend:
		if not layer is Dictionary or layer.size()!=5: return false
		if layer.get("biome") not in Genome.HABITATS or layer.biome in seen or layer.get("by") not in RULES: return false
		seen.append(layer.biome)
		if not GardenData._integer(layer.get("at")) or not GardenData._number(layer.at,0,100): return false
		if not GardenData._integer(layer.get("soft")) or not GardenData._number(layer.soft,1,50): return false
		if not GardenData._integer(layer.get("turn")) or not GardenData._number(layer.turn,0,359): return false
	return true

## JSON reads integers back as floats; restore them.
static func normalized(blend: Array) -> Array:
	var result: Array = []
	for layer: Dictionary in blend:
		result.append({"biome":str(layer.biome),"by":str(layer.by),"at":int(layer.at),"soft":int(layer.soft),"turn":int(layer.turn)})
	return result

## The snowline the mesh paints: an alpine layer brings its snow to the peaks.
static func snowline(settings: Dictionary,fallback: float) -> float:
	var line: float = Shape.BIOMES.get(settings.get("biome",""),{}).get("snowline",fallback)
	for layer: Dictionary in settings.get("blend",[]):
		line = minf(line,float(Shape.BIOMES[layer.biome].snowline))
	return line

## "Woodland", or "Woodland, meadow and alpine" for a blended world.
static func title(settings: Dictionary) -> String:
	var names: Array = [str(settings.get("biome","")).capitalize()]
	for layer: Dictionary in settings.get("blend",[]): names.append(str(layer.biome))
	if names.size()==1: return names[0]
	return ", ".join(names.slice(0,-1))+" and "+names[-1]
