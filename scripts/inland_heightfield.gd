extends RefCounted
## One continuous surface for mesh, habitat placement, and native water flooding.
const Genome = preload("res://scripts/inland_genome.gd")
const Places = preload("res://scripts/inland_places.gd")
const Erosion = preload("res://scripts/terrain_erosion.gd")
var places: Array[Dictionary] = []
var genome: Dictionary
var pools: Array
var courses: RefCounted
var noise := FastNoiseLite.new()
## Version 7 erosion and ridged detail (scripts/terrain_erosion.gd); empty
## for older versions, uneroded families and preview fields.
var erosion := PackedFloat64Array()
## A preview skips erosion. The generator scores candidates on previews and
## only the kept world is ever eroded, when its terrain is built.
func _init(g: Dictionary,ponds: Array,water_plan: RefCounted,preview := false) -> void:
	genome = g.duplicate(true)
	pools = ponds.duplicate(true)
	courses = water_plan
	noise.seed = genome.noise_seed
	noise.frequency = 0.13
	if not preview: erosion = Erosion.delta(genome,noise)
	if int(genome.version)>=4: places = Places.plan(self)
func height(x: float,z: float) -> float:
	var p := Vector2(x,z)
	# From version 6 the clearings are only dressed; the land keeps its shape.
	if int(genome.version)>=6: return original_height(x,z)
	return _water_height(x,z,Places.shape(places,p,Genome.height(genome,p,noise)))

func original_height(x: float,z: float) -> float:
	var base := Genome.height(genome,Vector2(x,z),noise)
	if not erosion.is_empty(): base += Erosion.sample(erosion,x,z)
	return _water_height(x,z,base)

func _water_height(x: float,z: float,base: float) -> float:
	var h: float = courses.carve(x,z,base)
	if genome.composition == "marsh" and int(genome.version)>=2:
		# Original wetland.js profile: rotated ellipses, irregular shores, shallow shelves.
		for pool: Dictionary in genome.wetland:
			var d := Vector2(x-pool.x,z-pool.z).rotated(-float(pool.angle))
			d.x /= float(pool.stretch)
			var angle := atan2(d.y,d.x)
			var radius: float = pool.radius*(1.0+0.2*sin(3.0*angle+pool.phase)+0.1*sin(5.0*angle-pool.phase))
			var r := d.length()/radius
			if r<1.5: h = minf(h,pool.level-pool.depth+(pool.depth+0.16)*r*r)
		return h
	if genome.composition == "salt-basin": return h
	for pool: Dictionary in pools:
		var r := Vector2((x-pool.x)/pool.basin[0],(z-pool.z)/pool.basin[1]).length()
		if r<1.4:
			var bowl: float = pool.level-0.85+1.25*smoothstep(0.35,1.05,r)
			h = lerpf(bowl,h,smoothstep(1.0,1.4,r))
	return h

func has_ground(p: Vector2,margin := 0.0) -> bool:
	return Genome.has_ground(genome,p,margin)

func wet(p: Vector2,margin := 0.0) -> bool:
	var h := height(p.x,p.y)
	for pool: Dictionary in pools:
		if h<float(pool.level)+0.12+margin*0.1:
			if not pool.has("basin") or Vector2((p.x-pool.x)/(pool.basin[0]+margin),(p.y-pool.z)/(pool.basin[1]+margin)).length()<1.2: return true
	for route: Dictionary in courses.routes:
		for point: Dictionary in route.pts:
			if p.distance_squared_to(Vector2(point.x,point.z))<pow(float(route.width)*0.6+0.4+margin,2.0): return true
	return false
