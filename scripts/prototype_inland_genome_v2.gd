extends RefCounted
## Inland lab genome v2. Independent feature streams; no saved-world schema changes.
## Compositions/archetypes and crest/wall profiles adapted from zenscape/genome.js and landforms.js.
const VERSION := 2
const Legacy = preload("res://scripts/prototype_inland_genome_v1.gd")
const COMPOSITIONS := ["mountain","massif","valley","basin","foothills","plateau","meadow","marsh","dunes","tablelands","buttes"]
const ARCHETYPES := ["ridgeback","cone","range","horn"]
const LANDFORMS := ["original","twin-summits","sawtooth-ridge","buttressed-canyon","glacial-valley","rolling-uplands","tall-massif","volcanic-crown"]
const HABITATS := ["alpine","woodland","meadow","wetland","arid","redwood"]
static func stream(seed_value: int,salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7919+salt
	return rng
# Parameter ranges and weights from the original inland archetype table.
const TRAITS := {
	"ridgeback":{"weight":0.20,"length":[21.0,26.0],"falloff":[5.5,7.5],"base":[4.6,5.8],"amp":[1.1,2.3],"frequency":[0.07,0.11],"sharp":0.35,"snow":[99.0,100.0],"treeline":[5.6,7.2],"trees":[90,200],"broadleaf":[40,105]},
	"cone":{"weight":0.15,"length":[1.0,2.0],"falloff":[7.5,9.5],"base":[8.2,10.6],"amp":[1.2,2.6],"frequency":[0.06,0.10],"sharp":0.15,"snow":[5.8,7.0],"treeline":[3.6,4.6],"trees":[40,100],"broadleaf":[14,38]},
	"range":{"weight":0.45,"length":[15.0,26.0],"falloff":[4.2,6.5],"base":[6.2,9.0],"amp":[3.5,6.2],"frequency":[0.085,0.14],"sharp":1.0,"snow":[5.6,7.2],"treeline":[3.6,5.0],"trees":[45,115],"broadleaf":[22,60]},
	"horn":{"weight":0.20,"length":[4.0,8.0],"falloff":[3.4,4.6],"base":[7.0,8.8],"amp":[2.6,3.6],"frequency":[0.12,0.17],"sharp":1.0,"snow":[5.2,6.4],"treeline":[3.4,4.4],"trees":[35,90],"broadleaf":[6,20]}}
static func draw(rng: RandomNumberGenerator,bounds: Array) -> float:
	return rng.randf_range(bounds[0],bounds[1])
static func weighted(rng: RandomNumberGenerator,names: Array,weights: Array) -> String:
	var roll := rng.randf()
	for i in range(names.size()):
		roll -= float(weights[i])
		if roll<0.0: return names[i]
	return names[-1]
static func sample(seed_value: int,overrides: Dictionary = {},version := VERSION) -> Dictionary:
	if version == 1: return Legacy.sample(seed_value,overrides)
	assert(version == VERSION,"Unsupported inland genome version")
	var rc := stream(seed_value,101)
	var ra := stream(seed_value,211)
	var rl := stream(seed_value,307)
	var rh := stream(seed_value,419)
	var rw := stream(seed_value,521)
	var composition := weighted(rc,["valley","basin","foothills","mountain","plateau","massif"],[0.13,0.10,0.17,0.32,0.14,0.14])
	# Preserve the original distribution within mountain country; additional inland families get their own draw.
	var re := stream(seed_value,853)
	if re.randf()<0.30: composition = ["meadow","marsh","dunes","tablelands","buttes"][re.randi_range(0,4)]
	composition = overrides.get("composition",composition)
	var archetype := weighted(ra,ARCHETYPES,[0.20,0.15,0.45,0.20])
	archetype = overrides.get("archetype",archetype)
	var traits: Dictionary = TRAITS[archetype]
	var landform := "original"
	var roll := rl.randf()
	if composition in ["mountain","massif"]:
		landform = "twin-summits" if roll<0.40 else "sawtooth-ridge" if roll<0.68 else "original" if roll<0.82 else "tall-massif" if roll<0.94 else "volcanic-crown"
	elif composition == "valley": landform = "buttressed-canyon" if roll<0.45 else "glacial-valley" if roll<0.90 else "original"
	elif composition == "foothills": landform = "rolling-uplands" if roll<0.75 else "original"
	landform = overrides.get("landform",landform)
	var habitat_roll := rh.randf()
	var habitat := "alpine"
	if composition in ["dunes","tablelands","buttes"]: habitat = "arid"
	elif composition == "marsh": habitat = "wetland"
	elif composition in ["meadow","foothills"]: habitat = "meadow" if habitat_roll<0.65 else "woodland"
	elif composition in ["valley","basin","plateau"] or archetype == "ridgeback": habitat = "woodland"
	habitat = overrides.get("habitat",habitat)
	var peaks: Array = []
	for i in range(4): peaks.append({"at":(i-1.5)*4.0+rl.randf_range(-0.5,0.5),"height":rl.randf_range(0.72,1.0),"width":rl.randf_range(3.4,4.8)})
	var g := {"version":VERSION,"seed":seed_value,"composition":composition,"archetype":archetype,"landform":landform,"habitat":habitat,
		"relief":overrides.get("relief",1.0),"breadth":overrides.get("breadth",1.0),"height":draw(ra,traits.base),"phase":rl.randf()*TAU,"peaks":peaks,
		"wall_spacing":rl.randf_range(5.0,8.0),"wall_relief":rl.randf_range(0.25,0.42),"floor_width":rc.randf_range(3.2,5.4),
		"river_width":rw.randf_range(1.2,2.0),"water_phase":rw.randf()*TAU,"plant_seed":seed_value*7919+631,"noise_seed":seed_value*7919+743,
		"tree_density":rh.randf_range(0.75,1.2),"ridge_length":draw(ra,traits.length),"ridge_falloff":draw(ra,traits.falloff),"ridge_amp":draw(ra,traits.amp),
		"ridge_frequency":draw(ra,traits.frequency),"ridge_sharpness":traits.sharp,"snowline":draw(ra,traits.snow),"treeline":draw(ra,traits.treeline),
		"tree_count":int(draw(rh,traits.trees)),"broadleaf_count":int(draw(rh,traits.broadleaf)),"bend":ra.randf_range(0.4,1.8),
		"valley_height":rc.randf_range(10.0,18.0),"hill_stretch":rl.randf_range(1.8,2.6),"hill_amp":rl.randf_range(1.1,1.9),
		"dune_angle":re.randf_range(-0.65,0.65),"dune_spacing":re.randf_range(1.3,2.0),"dune_height":re.randf_range(2.5,4.8)}
	var knolls: Array = []
	for i in range(7): knolls.append({"x":rc.randf_range(-9,9),"z":rc.randf_range(-9,9),"radius":rc.randf_range(4.5,7.5),"height":rc.randf_range(0.6,2.6)})
	g.knolls = knolls
	var wetland: Array = []
	var turn := rw.randf()*TAU
	for spec in [Vector3(-4,-3,4.5),Vector3(3,-3,3.4),Vector3(4,5,2.6),Vector3(-5,5,3.2)]:
		var center := Vector2(spec.x+rw.randf_range(-0.9,0.9),spec.y+rw.randf_range(-0.9,0.9)).rotated(turn)
		wetland.append({"x":center.x,"z":center.y,"radius":spec.z+rw.randf_range(-0.4,0.4),"stretch":rw.randf_range(1.05,1.60),"angle":turn+rw.randf()*PI,"phase":rw.randf()*TAU,"depth":rw.randf_range(0.43,0.56),"level":1.42})
	g.wetland = wetland
	g.lake = {"x":rw.randf_range(-1.0,1.0),"z":rw.randf_range(-0.5,0.5),"radius":rw.randf_range(3.8,5.5),"stretch":rw.randf_range(0.7,0.95)}
	return g
static func channel(g: Dictionary,z: float) -> float:
	return sin(z*0.23+g.water_phase)*1.4
static func height(g: Dictionary,p: Vector2,noise: FastNoiseLite) -> float:
	if int(g.version) == 1: return Legacy.height(g,p,noise)
	var q := p/float(g.breadth)
	var n := noise.get_noise_2d(q.x,q.y)
	var ground := 1.62+n*0.05 if g.composition == "marsh" else 1.45+n*0.22
	var mass := 0.0
	var h: float = g.height+(g.ridge_amp if g.landform != "original" else 0.0)
	var comp: String = g.composition
	if comp == "valley":
		var across := q.x-channel(g,q.y)*0.65
		var phase: float = q.y/g.wall_spacing*TAU+g.phase+(1.9 if across<0 else 0.0)
		var buttress := clampf(0.5+0.32*cos(phase)+0.18*cos(phase*0.53+1.2),0.0,1.0)
		var run := 4.8 if g.landform == "glacial-valley" else 2.4 if g.landform == "buttressed-canyon" else 5.5
		var u := clampf((absf(across)-g.floor_width)/(run*(0.8+0.4*buttress)),0.0,1.0)
		var toe := 0.32 if g.landform == "glacial-valley" else 0.12
		var face := 0.12*smoothstep(0.0,toe,u)+0.88*smoothstep(toe,1.0,u)
		mass = float(g.valley_height)*(1.0-g.wall_relief*(1.0-buttress))*face
	elif comp in ["meadow","marsh"]:
		mass = 0.03*(n+1.0)
		if comp == "meadow":
			mass += float(g.hill_amp)*(noise.get_noise_2d(q.x*0.5,q.y*0.5)+1.0)*0.4
			for i in range(2):
				var k: Dictionary = g.knolls[i]
				mass += float(k.height)*0.5*exp(-q.distance_squared_to(Vector2(k.x,k.z))/55.0)
	elif comp == "foothills":
		mass = float(g.hill_amp)*(1.0+noise.get_noise_2d(q.x/float(g.hill_stretch),q.y))*0.4
		for k in g.knolls:
			mass += float(k.height)*exp(-q.distance_squared_to(Vector2(k.x,k.z))/(float(k.radius)*float(k.radius)))
	elif comp == "dunes":
		var d := q.rotated(float(g.dune_angle))/float(g.dune_spacing)
		var phase := (d.y+noise.get_noise_2d(d.x*1.3+8,d.y*0.8+3)*1.5)/4.5
		var u := fposmod(phase,1.0)
		var ridge := smoothstep(0.0,0.72,u) if u<0.72 else 1.0-smoothstep(0.72,1.0,u)
		mass = pow(ridge,1.3)*float(g.dune_height)
	elif comp in ["plateau","tablelands","buttes"]:
		var centers := [Vector3(-4,-4,1.0),Vector3(6,-5,0.75)]
		if comp == "buttes": centers = [Vector3(-7,-6,1),Vector3(-1,-7,0.8),Vector3(6,-5,0.95),Vector3(-5,4,0.7),Vector3(5,3,0.6)]
		for center in centers:
			var radius := 2.0 if comp == "buttes" else 5.0
			var r := Vector2((q.x-center.x)/radius,(q.y-center.y)/(radius*0.8)).length()+n*0.10
			mass = maxf(mass,h*0.6*center.z*(1.0-smoothstep(0.7,1.1,r)))
	elif comp == "basin":
		var r := Vector2(q.x/9.0,(q.y+1.5)/8.0).length()
		mass = h*0.55*exp(-pow((r-0.85)*3.2,2.0))*(0.65+0.2*sin(q.x*0.4))
	else:
		var z := q.y+3.0
		if g.landform in ["twin-summits","sawtooth-ridge"]:
			var top := 0.0
			var count := 2 if g.landform == "twin-summits" else 4
			for i in range(count):
				var peak: Dictionary = g.peaks[i]
				var at: float = (-3.5 if i==0 else 3.5) if count==2 else peak.at
				top = maxf(top,peak.height*pow(clampf(1.0-absf(q.x-at)/peak.width,0.0,1.0),0.85))
			mass = h*(0.23+0.77*top)*pow(clampf(1.0-absf(z)/7.5,0.0,1.0),1.1)*(1.0-smoothstep(8.0,12.0,absf(q.x)))
		elif g.landform in ["tall-massif","volcanic-crown"]:
			var r := Vector2(q.x/8.5,z/7.5).length()
			mass = h*1.55*pow(maxf(0.0,1.0-r),1.1)
			if g.landform == "volcanic-crown": mass -= h*0.45*exp(-r*r/0.024)
			else: mass = maxf(mass,h*0.85*maxf(0.0,1.0-Vector2((q.x+5)/5.5,z/6.0).length()))
		elif g.archetype == "ridgeback": mass = (h+float(g.ridge_amp)*(n+1.0)*0.5)*exp(-pow(z-float(g.bend)*sin(q.x*0.22),2.0)/pow(float(g.ridge_falloff)*0.7,2.0))*(1.0-smoothstep(float(g.ridge_length)*0.35,float(g.ridge_length)*0.5,absf(q.x)))
		elif g.archetype == "range": mass = (h+float(g.ridge_amp)*(0.5+0.5*sin(q.x*float(g.ridge_frequency)*TAU+g.phase)))*exp(-pow(z-float(g.bend)*sin(q.x*0.3),2.0)/pow(float(g.ridge_falloff)*0.7,2.0))*(1.0-smoothstep(float(g.ridge_length)*0.35,float(g.ridge_length)*0.5,absf(q.x)))
		else:
			var r := Vector2(q.x,z).length()/float(g.ridge_falloff)
			mass = h*pow(maxf(0.0,1.0-r),1.45 if g.archetype == "horn" else 0.9)
		if comp == "massif": mass *= 1.15
	var edge := 1.0-smoothstep(11.4,14.0,maxf(absf(p.x),absf(p.y)))
	return 0.8+(ground+mass*float(g.relief)-0.8)*edge
