extends NativeTerrainRecipe
## One continuous surface for mesh, habitat placement, and native water flooding.
const Genome = preload("res://scripts/prototype_inland_genome.gd")
var genome: Dictionary
var pools: Array
var courses: RefCounted
var noise := FastNoiseLite.new()
func _init(g: Dictionary,ponds: Array,water_plan: RefCounted) -> void:
	super._init({"kind":"foundation","elevation":0.0,"relief":1.0})
	genome = g.duplicate(true)
	pools = ponds.duplicate(true)
	courses = water_plan
	noise.seed = genome.noise_seed
	noise.frequency = 0.13
func height(x: float,z: float) -> float:
	var p := Vector2(x,z)
	var h: float = courses.carve(x,z,Genome.height(genome,p,noise))
	for pool: Dictionary in pools:
		var r := Vector2((x-pool.x)/pool.basin[0],(z-pool.z)/pool.basin[1]).length()
		if r<1.4:
			var bowl: float = pool.level-0.85+1.25*smoothstep(0.35,1.05,r)
			h = lerpf(bowl,h,smoothstep(1.0,1.4,r))
	return h
