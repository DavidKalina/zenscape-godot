extends RefCounted
## Worker-owned instance recipes. RNG order, coordinates, transforms and tints
## are the same as the sequential GardenView builder. No scene resources.
## `world` is SeededVariety.world for the recipe: which rock and layered-tree
## variants this world leans on. Variants are picked per record by stable hash.
## Emerged records and meadow tufts still growing in give their source a `born`
## and `rise` (seconds), and emerged trees their stand's `autumn`, for
## GardenView to write into the instance custom data.
static func build(data: RefCounted, catalog_parts: Dictionary, catalog_poses: Dictionary, tints: Dictionary, world: Dictionary = {}) -> Dictionary:
	const Emergence = preload("res://scripts/emergence.gd")
	const Flowers = preload("res://scripts/meadow_flower_mesh.gd")
	# Opt-in (--meadow-flowers): draw the old flower forms and the painted
	# meadow's flowers with the flower kit. Records and saves are untouched.
	var remap := Flowers.remap_enabled() and catalog_parts.has(Flowers.KINDS[0])
	var sources := {}
	var transforms := {"trunk": [], "canopy": [], "grass": [], "stem": [], "petal": [], "rock": [], "explosive_leaves": []}
	for kind in catalog_parts:
		for key in catalog_parts[kind]:
			transforms[key] = []
	var instance_tints := {}
	for key in transforms:
		instance_tints[key] = []
		sources[key] = []
	for item: Dictionary in data.objects:
		add_item(item,data,catalog_parts,catalog_poses,tints,world,remap,transforms,sources,instance_tints)
	var cells: int = data.meadow_side()
	var births: Dictionary = data.cover_births if data is NativeTerrainData else {}
	for z in range(cells):
		for x in range(cells):
			var index := z * cells + x
			var count := int(data.grass_density(index) * 8.0)
			var rng := RandomNumberGenerator.new()
			rng.seed = index * 7919 + 17041
			for i in range(count):
				var p: Vector2 = data.meadow_position(x,z) + Vector2(rng.randf(), rng.randf()) * data.meadow_step()
				var height: Variant = data.ground_height(p)
				if height == null:
					continue
				var size := rng.randf_range(0.65, 1.3)
				var transform := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * size), Vector3(p.x, height, p.y))
				var blade := {"x":p.x,"z":p.y,"basis":transform.basis,"item":null,"pose":null,"lift":0.0}
				if births.has(index) and i < 8 and births[index].tufts[i] >= 0.0:
					blade.born = births[index].tufts[i]
					blade.rise = Emergence.TUFT_RISE
				transforms.grass.append(transform)
				sources.grass.append(blade)
				if i < int(data.meadow[index] * 8.0) and i % 4 == 0 and remap:
					# One kind per drift of cells, as meadows bloom.
					var kind: String = Flowers.drift_kind(x, z)
					var key: String = catalog_parts[kind][0]
					var bloom := blade.duplicate()
					bloom.basis = transform.basis.scaled(Vector3.ONE * Flowers.DRIFT_SCALE)
					transforms[key].append(Transform3D(bloom.basis, transform.origin))
					sources[key].append(bloom)
					instance_tints[key].append(Color.WHITE)
				elif i < int(data.meadow[index] * 8.0) and i % 4 == 0:
					transforms.stem.append(transform)
					sources.stem.append(blade)
					transforms.petal.append(transform)
					sources.petal.append(blade)
	return {"transforms":transforms,"tints":instance_tints,"sources":sources}

## One record's part instances, appended to `transforms`, `sources` and
## `instance_tints` (keyed by part; a key missing from them is added): what
## `build` does for each record, and what GardenView's paint preview draws a
## record painted mid-stroke with (scripts/flower_paint.gd).
static func add_item(item: Dictionary, data: RefCounted, catalog_parts: Dictionary, catalog_poses: Dictionary, tints: Dictionary, world: Dictionary, remap: bool, transforms: Dictionary, sources: Dictionary, instance_tints: Dictionary) -> void:
	const Stones = preload("res://scripts/rock_variants.gd")
	const Variety = preload("res://scripts/seeded_variety.gd")
	const Emergence = preload("res://scripts/emergence.gd")
	const Flowers = preload("res://scripts/meadow_flower_mesh.gd")
	for key in ["trunk","canopy","stem","petal","rock","explosive_leaves"]: _ensure(key,transforms,sources,instance_tints)
	var tint: Variant = preload("res://scripts/native_object_pose.gd").decode_tint(item.tint) if item.has("tint") else null
	var position: Vector3 = data.object_position(item)
	var basis := preload("res://scripts/native_object_pose.gd").decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP, item.angle).scaled(Vector3.ONE * item.scale)
	var transform := Transform3D(basis, position)
	var anchor := {"x":item.x,"z":item.z,"basis":basis,"item":item.duplicate(true),"pose":null,"lift":0.0}
	if item.has("born"):
		anchor.born = float(item.born)
		anchor.rise = Emergence.rise_seconds(item.asset)
	if item.has("autumn"): anchor.autumn = float(item.autumn)
	# Rocks and boulders draw from the seeded stone family.
	if catalog_parts.has("rock_variants") and Stones.is_stone(item.asset):
		var stone: String = catalog_parts.rock_variants[Stones.index(item,world)]
		var shape := Stones.pose(item,world)
		_ensure(stone,transforms,sources,instance_tints)
		transforms[stone].append(transform*shape)
		var placed := anchor.duplicate()
		placed.pose = shape
		sources[stone].append(placed)
		instance_tints[stone].append(Stones.color(item,tint,world))
		return
	var drawn: String = item.asset
	if remap and Flowers.REMAP.has(drawn):
		drawn = Flowers.REMAP[drawn]
		tint = null
	elif tint != null and Flowers.SPEC.has(drawn):
		tint = Flowers.instance_color(drawn,tint)
	if catalog_parts.has(drawn):
		var part_keys: Array = catalog_parts[drawn]
		var shaping := Transform3D.IDENTITY
		if item.asset == "layered_tree" and catalog_parts.has("layered_variants"):
			var form := 2*Variety.layered_index(item,world)
			part_keys = catalog_parts.layered_variants.slice(form,form+2)
			shaping = Variety.layered_shape(item,world)
		for source_key in part_keys:
			var key: String = "explosive_leaves" if item.asset == "explosive" and item.leaf_cover else source_key
			_ensure(key,transforms,sources,instance_tints)
			transforms[key].append(transform*catalog_poses[key]*shaping)
			var part := anchor.duplicate()
			part.pose = catalog_poses[key]*shaping
			sources[key].append(part)
			var colored: bool = catalog_parts[drawn].size()==1 or "canopies" in key or "flowers-" in key or "fungus-caps" in key
			instance_tints[key].append(tint if tint != null and colored else tints.get(key,Color.WHITE))
	match item.asset:
		"tree":
			var trunk_key := "trunk"
			var canopy_key := "canopy"
			if catalog_parts.has("tree_variants"):
				var index := 2*preload("res://scripts/hero_trees.gd").spruce_index(item)
				trunk_key = catalog_parts.tree_variants[index]
				canopy_key = catalog_parts.tree_variants[index+1]
				_ensure(trunk_key,transforms,sources,instance_tints)
				_ensure(canopy_key,transforms,sources,instance_tints)
			transforms[trunk_key].append(transform)
			sources[trunk_key].append(anchor)
			instance_tints[trunk_key].append(Color.WHITE)
			transforms[canopy_key].append(transform)
			sources[canopy_key].append(anchor)
			instance_tints[canopy_key].append(tint if tint != null else tints.canopy)
		"flower":
			transforms.stem.append(transform)
			sources.stem.append(anchor)
			instance_tints.stem.append(Color.WHITE)
			transforms.petal.append(transform)
			sources.petal.append(anchor)
			instance_tints.petal.append(tint if tint != null else tints.petal)
		"rock":
			transform.origin.y += 0.24 * item.scale
			transforms.rock.append(transform)
			var lifted := anchor.duplicate()
			lifted.lift = 0.24 * item.scale
			sources.rock.append(lifted)
			instance_tints.rock.append(tint if tint != null else Color.WHITE)

static func _ensure(key: String, transforms: Dictionary, sources: Dictionary, instance_tints: Dictionary) -> void:
	if transforms.has(key): return
	transforms[key] = []
	sources[key] = []
	instance_tints[key] = []
