extends RefCounted
const Plate = preload("res://scripts/plate.gd")
## Inland lab genome v1. Independent feature streams; no saved-world schema changes.
## Compositions/archetypes and crest/wall profiles adapted from zenscape/genome.js and landforms.js.
const VERSION := 1
const COMPOSITIONS := ["mountain","massif","valley","basin","foothills","plateau","meadow","marsh","dunes","tablelands","buttes"]
const ARCHETYPES := ["ridgeback","cone","range","horn"]
const LANDFORMS := ["original","twin-summits","sawtooth-ridge","buttressed-canyon","glacial-valley","rolling-uplands","tall-massif","volcanic-crown"]
const HABITATS := ["alpine","woodland","meadow","wetland","arid","redwood"]
static func stream(seed_value: int,salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value*7919+salt
	return rng
static func sample(seed_value: int,overrides: Dictionary = {}) -> Dictionary:
	var rc := stream(seed_value,101)
	var ra := stream(seed_value,211)
	var rl := stream(seed_value,307)
	var rh := stream(seed_value,419)
	var rw := stream(seed_value,521)
	var composition: String = ["valley","basin","foothills","mountain","mountain","plateau","massif","meadow","marsh","dunes","tablelands","buttes"][rc.randi_range(0,11)]
	composition = overrides.get("composition",composition)
	var archetype: String = ARCHETYPES[ra.randi_range(0,3)]
	archetype = overrides.get("archetype",archetype)
	var landform := "original"
	if composition in ["mountain","massif"]: landform = ["original","twin-summits","sawtooth-ridge","tall-massif","volcanic-crown"][rl.randi_range(0,4)]
	elif composition == "valley": landform = ["original","buttressed-canyon","glacial-valley"][rl.randi_range(0,2)]
	elif composition == "foothills": landform = "rolling-uplands"
	landform = overrides.get("landform",landform)
	var habitat := "alpine"
	if composition in ["dunes","tablelands","buttes"]: habitat = "arid"
	elif composition == "marsh": habitat = "wetland"
	elif composition in ["meadow","foothills"]: habitat = "meadow" if rh.randf()<0.5 else "woodland"
	elif composition in ["valley","basin","plateau"]: habitat = "woodland"
	habitat = overrides.get("habitat",habitat)
	var peaks: Array = []
	for i in range(4): peaks.append({"at":(i-1.5)*4.0+rl.randf_range(-0.5,0.5),"height":rl.randf_range(0.72,1.0),"width":rl.randf_range(3.4,4.8)})
	return {"version":VERSION,"seed":seed_value,"composition":composition,"archetype":archetype,"landform":landform,"habitat":habitat,
		"relief":overrides.get("relief",1.0),"breadth":overrides.get("breadth",1.0),"height":ra.randf_range(10.0,17.0),"phase":rl.randf()*TAU,"peaks":peaks,
		"wall_spacing":rl.randf_range(5.0,8.0),"wall_relief":rl.randf_range(0.25,0.42),"floor_width":rc.randf_range(3.2,5.4),
		"river_width":rw.randf_range(1.2,2.0),"water_phase":rw.randf()*TAU,"plant_seed":seed_value*7919+631,"noise_seed":seed_value*7919+743,
		"tree_density":rh.randf_range(0.75,1.2)}
static func channel(g: Dictionary,z: float) -> float:
	return sin(z*0.23+g.water_phase)*1.4
static func height(g: Dictionary,p: Vector2,noise: FastNoiseLite) -> float:
	var q := p/float(g.breadth)
	var n := noise.get_noise_2d(q.x,q.y)
	var ground := 1.45+n*0.22
	var mass := 0.0
	var h: float = g.height
	var comp: String = g.composition
	if comp == "valley":
		var across := q.x-channel(g,q.y)*0.65
		var phase: float = q.y/g.wall_spacing*TAU+g.phase+(1.9 if across<0 else 0.0)
		var buttress := clampf(0.5+0.32*cos(phase)+0.18*cos(phase*0.53+1.2),0.0,1.0)
		var run := 4.8 if g.landform == "glacial-valley" else 2.4 if g.landform == "buttressed-canyon" else 5.5
		var u := clampf((absf(across)-g.floor_width)/(run*(0.8+0.4*buttress)),0.0,1.0)
		var toe := 0.32 if g.landform == "glacial-valley" else 0.12
		var face := 0.12*smoothstep(0.0,toe,u)+0.88*smoothstep(toe,1.0,u)
		mass = h*(1.0-g.wall_relief*(1.0-buttress))*face
	elif comp in ["meadow","marsh"]:
		mass = (0.08 if comp == "marsh" else 0.8)*(n+1.0)
	elif comp == "foothills":
		mass = 1.8*(1.0+noise.get_noise_2d(q.x*0.7,q.y*1.7))+0.4*sin(q.x*0.3)
	elif comp == "dunes":
		mass = pow(1.0-absf(sin(q.x*0.38+n*0.8+q.y*0.08)),1.5)*3.0
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
		elif g.archetype == "ridgeback": mass = h*0.45*exp(-z*z/20.0)*(1.0-smoothstep(8.0,13.0,absf(q.x)))
		elif g.archetype == "range": mass = h*exp(-pow(z-sin(q.x*0.3),2.0)/15.0)*(0.65+0.2*sin(q.x*0.7+g.phase))*(1.0-smoothstep(8.0,13.0,absf(q.x)))
		else:
			var r := Vector2(q.x,z).length()/9.5
			mass = h*pow(maxf(0.0,1.0-r),1.45 if g.archetype == "horn" else 0.9)
		if comp == "massif": mass *= 1.15
	var edge := 1.0-smoothstep(Plate.LEGACY_HALF-2.6,Plate.LEGACY_HALF,maxf(absf(p.x),absf(p.y)))
	return 0.8+(ground+mass*float(g.relief)-0.8)*edge
