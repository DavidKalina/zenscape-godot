extends RefCounted
const Genome = preload("res://scripts/inland_genome.gd")
const Desert = preload("res://scripts/desert_landscape.gd")
var genome: Dictionary
var ponds: Array[Dictionary] = []
var streams: Array[Dictionary] = []
var sampler: RefCounted
func _init(settings: Dictionary) -> void:
	genome = Genome.sample(int(settings.seed),{"composition":settings.composition,"archetype":settings.archetype,"landform":settings.landform,"habitat":settings.biome,"relief":settings.relief,"breadth":settings.breadth},int(settings.version))
	var water = preload("res://scripts/native_formation_water.gd").new()
	if genome.composition == "valley":
		var anchors: Array = []
		for i in range(45):
			var z := -11.0+i*0.5
			anchors.append([Genome.channel(genome,z),z,1.12+(11.0-z)*0.009])
		water._add(anchors,genome.river_width,false,false)
		streams.assign(water.routes.duplicate(true))
	elif genome.composition == "salt-basin":
		var level := 0.8+0.99*0.65*float(genome.relief)
		for z in range(-10,12,2):
			for x in range(-10,12,2):
				var f := Desert.field(genome,Vector2(x,z))
				if f.z>0.85 and f.x<level:
					ponds.append({"x":float(x),"z":float(z),"level":level})
	elif genome.composition == "marsh":
		for pool in genome.wetland:
			ponds.append({"x":pool.x,"z":pool.z,"level":pool.level})
	elif genome.composition in ["basin","mountain","massif","foothills"]:
		var p := Vector2(0,0) if genome.composition == "basin" else Vector2(2.5,6.0)
		var radius: float = genome.lake.radius if genome.composition == "basin" else 3.4
		if genome.composition == "basin": p = Vector2(genome.lake.x,genome.lake.z)
		ponds.append({"x":p.x,"z":p.y,"level":1.7,"basin":[radius,radius*float(genome.lake.stretch)]})
	var recipe = preload("res://scripts/inland_heightfield.gd").new(genome,ponds,water)
	# Local headwater and tributary courses use the same monotone level plan as the original formation water.
	if genome.composition in ["mountain","massif"] and not ponds.is_empty():
		var pool: Dictionary = ponds[0]
		var start := Vector2(-0.5,-2.0)
		var end := Vector2(pool.x,pool.z)
		var level: float = maxf(pool.level,recipe.height(start.x,start.y)+0.06)
		var anchors: Array = []
		for i in range(17):
			var t := float(i)/16.0
			var point := start.lerp(end,t)+Vector2(sin(t*PI)*0.7,0.0)
			level = maxf(pool.level,minf(level,recipe.height(point.x,point.y)+0.06))
			anchors.append([point.x,point.y,level])
		anchors[-1][2] = pool.level
		water._add(anchors,0.85,true,false)
	elif genome.composition == "valley":
		var z := -5.5
		var receiving := 1.12+(11.0-z)*0.009
		var x: float = Genome.channel(genome,z)
		var head := Vector2(x-4.5,z-2.0)
		var level := maxf(receiving+0.6,recipe.height(head.x,head.y)+0.06)
		water._add([[head.x,head.y,level],[x-2.0,z-0.7,receiving+0.25],[x,z,receiving]],0.65,true,false)
	streams.assign(water.routes.duplicate(true))
	if int(genome.version)>=4:
		# The final routes must also stay outside the inhabited clearings.
		recipe.places.clear()
		recipe.places = preload("res://scripts/inland_places.gd").plan(recipe)
	sampler = recipe

func height(x: float,z: float) -> float:
	return sampler.height(x,z)
