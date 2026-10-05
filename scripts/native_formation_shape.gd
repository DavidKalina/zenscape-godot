extends RefCounted
const Plate = preload("res://scripts/plate.gd")
## Large silhouettes first, surface detail second. Inspired by the original
## landforms.js / world.js profiles; water bowls are part of the same ground.
const FAMILIES := ["redwood_grove","valley","plateau","cone","ridgeback","horn","canyon","terraced_pools"]
const BIOMES := {
	"redwood":{"title":"Redwood forest", "snowline":99.0, "rock_slope":1.25, "grass":0.72, "trees":65, "tree":"redwood", "treeline":12.0},
	"alpine":{"title":"Alpine", "snowline":7.8, "rock_slope":1.05, "grass":0.8, "trees":85, "tree":"tree", "treeline":5.0},
	"woodland":{"title":"Woodland", "snowline":99.0, "rock_slope":1.4, "grass":0.95, "trees":155, "tree":"broadleaf", "treeline":9.0},
	"meadow":{"title":"Wildflower meadow", "snowline":99.0, "rock_slope":1.3, "grass":1.0, "trees":32, "tree":"broadleaf", "treeline":6.0},
	"arid":{"title":"Dry highlands", "snowline":99.0, "rock_slope":0.8, "grass":0.14, "trees":14, "tree":"shrub", "treeline":9.0},
	"wetland":{"title":"Lush wetland", "snowline":99.0, "rock_slope":1.35, "grass":1.0, "trees":90, "tree":"broadleaf", "treeline":7.0}
}
var composition_offset := Vector2.ZERO
var breadth := 1.0
var water: RefCounted
var pool_specs: Array
var family: String
var noise: RefCounted
func _init(id: String, source: RefCounted,variation := 37) -> void:
	family = id
	noise = source
	if variation != 37:
		var rng := RandomNumberGenerator.new()
		rng.seed = variation*7919+31
		composition_offset = Vector2(rng.randf_range(-1.4,1.4),rng.randf_range(-0.75,0.75))
		breadth = rng.randf_range(0.86,1.12)
	pool_specs = pools()
	for pool: Dictionary in pool_specs:
		pool.x += composition_offset.x*0.75
		pool.rx *= breadth

func channel_x(z: float) -> float:
	return sin(z*0.25+composition_offset.y)*1.3*breadth+composition_offset.x*0.5

func connect_water(flowing := true) -> void:
	water = preload("res://scripts/native_formation_water.gd").new()
	water.setup(self)
	pool_specs = water.pools
	if not flowing: water.disable_flow()

func height(x: float,z: float) -> float:
	var h := raw_height(x,z)
	return water.carve(x,z,h) if water != null else h

func raw_height(x: float,z: float) -> float:
	var n: float = noise.fbm(x*0.24+13.0,z*0.24-7.0)
	var ground := 1.1+(n-0.45)*0.45
	var mass := 0.0
	var across := absf(x-channel_x(z))
	match family:
		"redwood_grove":
			ground = 1.35+(n-0.45)*1.4
			mass = 0.65*sin(x*0.28+composition_offset.x)*sin(z*0.22+composition_offset.y)
			ground -= 0.22*(1.0-smoothstep(0.7,2.2,across))
		"valley":
			var wall := smoothstep(2.8,9.6,across)
			mass = 6.5*wall*(0.8+0.2*sin(z*0.42+x*0.2))
			ground = 0.9+(11.0-z)*0.035+(n-0.45)*0.14
			ground -= 0.42*(1.0-smoothstep(0.8,1.8,across))
		"plateau":
			var r := Vector2((x+1.3-composition_offset.x)/(8.7*breadth),(z+2.2-composition_offset.y)/7.0).length()
			mass = 6.1*(1.0-smoothstep(0.73,1.06,r+(n-0.45)*0.1))
			mass += 1.5*exp(-((x-8.0)*(x-8.0)+(z-4.5)*(z-4.5))/7.0)
		"cone":
			var r := Vector2(x+0.9-composition_offset.x,z+2.3-composition_offset.y).length()/breadth
			mass = 11.8*pow(maxf(0.0,1.0-r/10.3),1.25)
			mass *= 0.96+0.04*sin(atan2(z+2.3,x+0.9)*7.0)
		"ridgeback":
			var line := z+2.5-1.4*sin(x*0.22+composition_offset.y)*breadth
			mass = 6.4*exp(-line*line/17.0)*(1.0-smoothstep(8.0,13.0,absf(x)))
			mass *= 0.92+0.08*cos(x*0.65)
		"horn":
			var r := maxf(absf(x+1.5-composition_offset.x)*0.94,absf(z+2.3-composition_offset.y)*1.2)+Vector2(x+1.5,z+2.3).length()*0.22
			mass = 13.2*pow(maxf(0.0,1.0-r/9.0),1.45)
			mass += 2.0*exp(-((x-5.5)*(x-5.5)+(z+3.0)*(z+3.0))/10.0)
		"canyon":
			var wall := smoothstep(1.3,3.5+(n-0.4)*1.2,across)
			var mesa: float = 6.7+(floorf(n*5.0)/5.0-0.4)*1.1
			mass = wall*mesa
			ground = 0.9+(11.0-z)*0.035
			ground -= 0.4*(1.0-smoothstep(0.8,1.8,across))
		"terraced_pools":
			var shelf := 1.8*(1.0-smoothstep(2.5,3.5,z))+1.8*(1.0-smoothstep(-3.0,-2.0,z))
			var outer := 1.0-smoothstep(7.0,10.5,absf(x)+(n-0.4))
			ground = 1.3+(n-0.45)*0.12
			mass = shelf*outer+0.65*smoothstep(5.0,8.0,absf(x))*outer
	var h := ground+mass
	for pool: Dictionary in pool_specs:
		var r := Vector2((x-pool.x)/pool.rx,(z-pool.z)/pool.rz).length()
		# A closed lip retains each pool independently, including upper shelves.
		if r < 1.6:
			var bowl: float = pool.level-1.1+1.5*smoothstep(0.48,1.02,r)
			h = lerpf(bowl,h,smoothstep(1.2,1.6,r))
	var rim := 1.0-smoothstep(Plate.LEGACY_HALF-2.7,Plate.LEGACY_HALF,maxf(absf(x),absf(z)))
	return 0.6+(h-0.6)*rim

func pools() -> Array:
	match family:
		"plateau": return [{"x":-1.0,"z":-2.0,"rx":2.8,"rz":2.0,"level":7.1}]
		"cone": return [{"x":3.3,"z":7.0,"rx":3.5,"rz":2.0,"level":1.6}]
		"ridgeback": return [{"x":2.0,"z":6.5,"rx":3.8,"rz":2.0,"level":1.6}]
		"horn": return [{"x":3.6,"z":5.8,"rx":3.2,"rz":2.3,"level":1.65}]
		"terraced_pools": return [
			{"x":-0.8,"z":-5.9,"rx":4.2,"rz":2.5,"level":4.9},
			{"x":1.0,"z":-0.1,"rx":4.7,"rz":2.3,"level":3.1},
			{"x":-0.7,"z":5.6,"rx":5.0,"rz":2.2,"level":1.3}]
	return []
