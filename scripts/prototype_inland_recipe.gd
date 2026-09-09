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
