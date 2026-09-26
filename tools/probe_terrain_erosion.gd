extends SceneTree
## Headless probe for genome v7 erosion (scripts/terrain_erosion.gd).
## godot --headless --path . -s res://tools/probe_terrain_erosion.gd -- [count] [--reference N] [--candidates]
##  - per-family cut depth, deposit and timing of the grid sample and erosion;
##  - --reference N: checks the GDScript mirror matches the native kernel exactly
##    on the first N seeds and times it;
##  - --candidates: rebuilds the generator's six candidates, eroded and not,
##    to see whether scoring previews still picks a good eroded world;
##  - --hillshade DIR: writes a hillshade PNG per seed, uneroded left, eroded right.
const Genome = preload("res://scripts/inland_genome.gd")
const Erosion = preload("res://scripts/terrain_erosion.gd")
const Generator = preload("res://scripts/cozy_world_generator.gd")
const World = preload("res://scripts/inland_world.gd")
const Beauty = preload("res://scripts/world_beauty.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var count := int(args[0]) if args.size()>0 and args[0].is_valid_int() else 40
	var reference := int(args[args.find("--reference")+1]) if "--reference" in args else 0
	var candidates := "--candidates" in args
	var shade_dir: String = args[args.find("--hillshade")+1] if "--hillshade" in args else ""
	var kernel = preload("res://scripts/native_terrain_kernels.gd").get_kernel()
	print("native kernel: ",kernel != null and kernel.has_method("erode"))
	var stats := {}
	var sample_ms := 0.0
	var erode_ms := 0.0
	var eroded_worlds := 0
	var mismatches := 0
	var reference_ms := 0.0
	var same_pick := 0
	var pick_loss := 0.0
	var worst_loss := 0.0
	for seed_value in range(count):
		var recipe: Dictionary = Generator.sample(seed_value).terrain
		var g := Genome.sample(int(recipe.seed),{"composition":recipe.composition,"archetype":recipe.archetype,"landform":recipe.landform,"habitat":recipe.biome,"relief":recipe.relief,"breadth":recipe.breadth},int(recipe.version))
		var settings := Erosion.params(g)
		if not stats.has(g.composition): stats[g.composition] = {"n":0,"cut":0.0,"deepest":0.0,"fill":0.0,"moved":0.0}
		var family: Dictionary = stats[g.composition]
		family.n += 1
		if settings.is_empty(): continue
		var noise := FastNoiseLite.new()
		noise.seed = g.noise_seed
		noise.frequency = 0.13
		var t0 := Time.get_ticks_usec()
		var base := PackedFloat64Array()
		var fixed := PackedByteArray()
		for j in range(Erosion.SIZE):
			for i in range(Erosion.SIZE):
				var p := Vector2(Erosion.ORIGIN+i*Erosion.CELL,Erosion.ORIGIN+j*Erosion.CELL)
				base.append(Genome.height(g,p,noise))
				fixed.append(0 if Genome.has_ground(g,p) else 1)
		var t1 := Time.get_ticks_usec()
		var delta := Erosion.erode(base,fixed,settings)
		var t2 := Time.get_ticks_usec()
		sample_ms += (t1-t0)/1000.0
		erode_ms += (t2-t1)/1000.0
		eroded_worlds += 1
		var cut := 0.0
		var fill := 0.0
		var moved := 0.0
		for d in delta:
			cut = minf(cut,d)
			fill = maxf(fill,d)
			moved += absf(d)
		family.cut += cut
		family.deepest = minf(family.deepest,cut)
		family.fill += fill
		family.moved += moved/delta.size()
		if seed_value<reference:
			var t3 := Time.get_ticks_usec()
			var mirror := Erosion.erode_reference(base,fixed,settings)
			reference_ms += (Time.get_ticks_usec()-t3)/1000.0
			if mirror != delta:
				mismatches += 1
				var worst := 0.0
				for i in range(mini(mirror.size(),delta.size())): worst = maxf(worst,absf(mirror[i]-delta[i]))
				print("MISMATCH seed %d %s max diff %g sizes %d/%d" % [seed_value,g.composition,worst,mirror.size(),delta.size()])
		if not shade_dir.is_empty(): _hillshade(recipe,"%s/seed_%03d_%s.png" % [shade_dir,seed_value,g.composition])
		if candidates:
			var pick := _candidates(seed_value)
			if pick.preview_best == pick.eroded_best: same_pick += 1
			var loss: float = pick.eroded_scores[pick.eroded_best]-pick.eroded_scores[pick.preview_best]
			pick_loss += loss
			worst_loss = maxf(worst_loss,loss)
	for name in stats:
		var f: Dictionary = stats[name]
		if f.fill==0.0 and f.cut==0.0:
			print("%-17s n=%3d not eroded" % [name,f.n])
			continue
		print("%-17s n=%3d mean deepest cut %.2f m (worst %.2f), mean top deposit %.2f m, mean |change| %.3f m" % [name,f.n,f.cut/f.n,f.deepest,f.fill/f.n,f.moved/f.n])
	if eroded_worlds>0: print("grid sample %.1f ms, erosion %.2f ms per eroded world (%d worlds)" % [sample_ms/eroded_worlds,erode_ms/eroded_worlds,eroded_worlds])
	if reference>0: print("reference mirror: %d mismatches over first %d seeds, %.0f ms per world" % [mismatches,reference,reference_ms/maxi(1,mini(reference,eroded_worlds))])
	if candidates: print("preview pick is the eroded best in %d of %d eroded worlds; mean eroded-score loss %.4f, worst %.4f" % [same_pick,eroded_worlds,pick_loss/maxi(1,eroded_worlds),worst_loss])
	quit()

## Replays cozy_world_generator.gd's candidate draws and scores each candidate
## both as a preview and eroded.
func _candidates(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var terrain_seed := rng.randi_range(0,999999)
	var g: Dictionary = Genome.sample(terrain_seed)
	var biome: String = g.habitat
	if biome=="woodland" and rng.randf()<0.28: biome = "redwood"
	var recipe := {"kind":"inland","version":Genome.VERSION,"seed":terrain_seed,"composition":g.composition,"archetype":g.archetype,"landform":g.landform,"biome":biome,"relief":rng.randf_range(0.65,1.3),"breadth":rng.randf_range(0.72,1.3)}
	var preview_scores: Array[float] = []
	var eroded_scores: Array[float] = []
	for attempt in range(Generator.CANDIDATES):
		if attempt>0:
			recipe.seed = rng.randi_range(0,999999)
			recipe.relief = rng.randf_range(0.65,1.3)
			recipe.breadth = rng.randf_range(0.72,1.3)
		preview_scores.append(Beauty.score(World.new(recipe,true).sampler).total)
		eroded_scores.append(Beauty.score(World.new(recipe).sampler).total)
	return {"preview_best":_argmax(preview_scores),"eroded_best":_argmax(eroded_scores),"eroded_scores":eroded_scores}

func _argmax(values: Array[float]) -> int:
	var best := 0
	for i in range(values.size()):
		if values[i]>values[best]: best = i
	return best

## Hillshade of the full water-carved field, uneroded | eroded | change
## (red cut, blue fill, full colour at 0.5 m).
func _hillshade(recipe: Dictionary,path: String) -> void:
	var size := 280
	var step := 28.0/size
	var image := Image.create(size*3+8,size,false,Image.FORMAT_RGB8)
	image.fill(Color.BLACK)
	var light := Vector3(-1,2.5,-0.6).normalized()
	var fields := [World.new(recipe,true).sampler,World.new(recipe).sampler]
	var grids: Array = []
	for side in range(2):
		var rows: Array[PackedFloat64Array] = []
		for j in range(size+1):
			var row := PackedFloat64Array()
			for i in range(size+1): row.append(fields[side].height(-14.0+i*step,-14.0+j*step))
			rows.append(row)
		grids.append(rows)
		for j in range(size):
			for i in range(size):
				var dx: float = rows[j][i+1]-rows[j][i]
				var dz: float = rows[j+1][i]-rows[j][i]
				var shade := clampf(Vector3(-dx,step,-dz).normalized().dot(light),0.0,1.0)
				var tint := clampf((rows[j][i]-0.5)/12.0,0.0,1.0)
				var ground: bool = fields[side].has_ground(Vector2(-14.0+i*step,-14.0+j*step))
				image.set_pixel(side*(size+4)+i,j,Color(0.3,0.1,0.1) if not ground else Color(shade*(0.7+0.3*tint),shade*0.85,shade*(1.0-0.3*tint)))
	for j in range(size):
		for i in range(size):
			var d: float = grids[1][j][i]-grids[0][j][i]
			var t := clampf(absf(d)/0.5,0.0,1.0)
			image.set_pixel(2*(size+4)+i,j,Color(0.5+0.5*t,0.5-0.4*t,0.5-0.4*t) if d<0.0 else Color(0.5-0.4*t,0.5-0.3*t,0.5+0.5*t))
	image.save_png(path)
