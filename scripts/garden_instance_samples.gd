extends RefCounted
## Worker-owned instance recipes. RNG order, coordinates, transforms and tints
## are the same as the sequential GardenView builder. No scene resources.
## `world` is SeededVariety.world for the recipe: which rock and layered-tree
## variants this world leans on. Variants are picked per record by stable hash.
static func build(data: RefCounted, catalog_parts: Dictionary, catalog_poses: Dictionary, tints: Dictionary, world: Dictionary = {}) -> Dictionary:
	const Stones = preload("res://scripts/rock_variants.gd")
	const Variety = preload("res://scripts/seeded_variety.gd")
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
		var tint: Variant = preload("res://scripts/native_object_pose.gd").decode_tint(item.tint) if item.has("tint") else null
		var position: Vector3 = data.object_position(item)
		var basis := preload("res://scripts/native_object_pose.gd").decode_basis(item.pose) if item.has("pose") else Basis(Vector3.UP, item.angle).scaled(Vector3.ONE * item.scale)
		var transform := Transform3D(basis, position)
		var anchor := {"x":item.x,"z":item.z,"basis":basis,"item":item.duplicate(true),"pose":null,"lift":0.0}
		# Rocks and boulders draw from the seeded stone family.
		if catalog_parts.has("rock_variants") and Stones.is_stone(item.asset):
			var stone: String = catalog_parts.rock_variants[Stones.index(item,world)]
			var shape := Stones.pose(item,world)
			transforms[stone].append(transform*shape)
			var placed := anchor.duplicate()
			placed.pose = shape
			sources[stone].append(placed)
			instance_tints[stone].append(Stones.color(item,tint,world))
			continue
		if catalog_parts.has(item.asset):
			var part_keys: Array = catalog_parts[item.asset]
			var shaping := Transform3D.IDENTITY
			if item.asset == "layered_tree" and catalog_parts.has("layered_variants"):
				var form := 2*Variety.layered_index(item,world)
				part_keys = catalog_parts.layered_variants.slice(form,form+2)
				shaping = Variety.layered_shape(item,world)
			for source_key in part_keys:
				var key: String = "explosive_leaves" if item.asset == "explosive" and item.leaf_cover else source_key
				transforms[key].append(transform*catalog_poses[key]*shaping)
				var part := anchor.duplicate()
				part.pose = catalog_poses[key]*shaping
				sources[key].append(part)
				var colored: bool = catalog_parts[item.asset].size()==1 or "canopies" in key or "flowers-" in key or "fungus-caps" in key
				instance_tints[key].append(tint if tint != null and colored else tints.get(key,Color.WHITE))
		match item.asset:
			"tree":
				var trunk_key := "trunk"
				var canopy_key := "canopy"
				if catalog_parts.has("tree_variants"):
					var index := 2*preload("res://scripts/hero_trees.gd").spruce_index(item)
					trunk_key = catalog_parts.tree_variants[index]
					canopy_key = catalog_parts.tree_variants[index+1]
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
	var cells: int = data.meadow_side()
	for z in range(cells):
		for x in range(cells):
			var index := z * cells + x
			# Up to eight tufts a cell. A golden-ratio dither per cell rounds the
			# fraction up in its share of cells, so light cover (0.14 is 1.1
			# tufts) is not truncated away and cover thickens smoothly.
			var count := int(data.grass_density(index) * 8.0 + fposmod(float(index) * 0.618034, 1.0))
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
				transforms.grass.append(transform)
				sources.grass.append(blade)
				if i < int(data.meadow[index] * 8.0) and i % 4 == 0:
					transforms.stem.append(transform)
					sources.stem.append(blade)
					transforms.petal.append(transform)
					sources.petal.append(blade)
	return {"transforms":transforms,"tints":instance_tints,"sources":sources}
