extends RefCounted
## A copy of the aqueduct isle's (studies/aqueduct_isle_flora.gd) wired to the
## bell spires isle's art (studies/bell_spires_isle_art.gd); an extraction
## candidate for a shared kit isle builder (docs/scenic/bell-spires.md).
## The aqueduct isle's grass and flowers, grown the way the game grows them
## on its sky islands (scripts/sky_islet.gd, scripts/sky_islets.gd): plant
## records (the plate catalog's shader grass tuft, scripts/
## grass_tuft_mesh.gd, and the meadow flowers, scripts/
## meadow_flower_mesh.gd) turned into per-part transforms by the plate's own
## instance builder (scripts/garden_instance_samples.gd `add_item`) and
## drawn as multimeshes with the catalog's materials made safe for the sky
## (SkyIslets `_plant_material`). So the breeze and the gust fronts sway
## them (shaders/reference_surface.gdshader: zs_wind_*, zs_breeze,
## zs_gust_*), the pilot's wake (scripts/pilot_wake.gd, zs_tread_*) parts
## them, and they take the scene look's grass and flower colours and the
## seasons (zs_palette_*, zs_autumn, zs_snow) as the game's do.
##
## Placed over what the physics space stands there: a ray down must land
## on an island's own turf (its ground body), on a face no steeper than
## the palette's rock slope (the crags stay bare rock), and the same within
## REACH round it, so nothing grows into a stone's foot, a wall, the
## stairs' treads or the station's boxes. The worn paths' middles stay bare
## and thin toward their edges; the islands' rims are kept clear.
##
## Grass comes in drifts (TUFTS a square metre at their thickest, THIN
## between). Flowers follow a meadow type's composition (scripts/
## meadow_types.gd, MEADOW: drifts of one kind with a companion, a few
## strays) at a sparse share of its packing, so they read as wildflowers
## in the grass, not a carpet.
##
## Drawn in TILE m tiles, one multimesh a tile and part, so each tile culls
## on its own and fades out past its kind's range.
const Art = preload("res://studies/bell_spires_isle_art.gd")
const SkyIslets = preload("res://scripts/sky_islets.gd")
const Samples = preload("res://scripts/garden_instance_samples.gd")
const MeadowTypes = preload("res://scripts/meadow_types.gd")

## Grass tufts a square metre at a drift's thickest, the least share of it
## between drifts, the drifts' scale (1/m), the tufts' size range.
const TUFTS := 4.6
const THIN := 0.35
const DRIFT_FREQUENCY := 0.07
const TUFT_SIZE := Vector2(0.85,1.45)
## The meadow type the flowers compose as, flower candidates a square
## metre, the share of the type's packing kept (a sparse sowing), strays.
const MEADOW := "alpine"
const FLOWER_TRIES := 2.2
const FLOWER_SHARE := 0.16
const STRAY := 0.006
## Kept bare: in from the rim (m), the worn paths (their wear past
## PATH_BARE, thinning from PATH_THIN), anything else than turf within
## REACH of the root, faces steeper than the palette's rock slope times
## STEEP_SHARE.
const RIM := 0.5
const PATH_BARE := 0.5
const PATH_THIN := 0.1
const REACH := 0.25
const STEEP_SHARE := 0.85
## Tiles (m) and how far each kind draws (m), with the fade's margin.
const TILE := 16.0
const GRASS_RANGE := 95.0
const FLOWER_RANGE := 65.0
const FADE := 15.0

## What the instance builder asks of the land a record stands on.
class Ground extends RefCounted:
	var heights := {}
	func object_position(item: Dictionary) -> Vector3:
		return Vector3(item.x,float(heights.get(item.id,Art.ground(item.x,item.z))),item.z)

## The plants for the isle: a Node3D of tiled multimeshes, its meta
## "records" (the plant records), "counts" (records by asset), "instances"
## (instances by part) and "triangles" (instanced triangles drawn at most).
## `space` the physics space the isle stands in; `turf` the islands'
## ground bodies (a ray must land on one); `outlines` the islands' (world
## x, z) polygons.
static func grow(seed_value: int, space: PhysicsDirectSpaceState3D, turf: Array, outlines: Array) -> Node3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var drift := FastNoiseLite.new()
	drift.seed = seed_value+5
	drift.frequency = DRIFT_FREQUENCY
	var meadow := MeadowTypes.new(MEADOW,seed_value+9)
	# The isle stands far off the plate: no plate rim thins its drifts.
	meadow.rim_band = Vector2(1.0e6,2.0e6)
	var turf_ids := {}
	for body: Object in turf: turf_ids[body.get_instance_id()] = true
	var steep: float = float(Art.palette().rock_slope)*STEEP_SHARE
	var ray := PhysicsRayQueryParameters3D.new()
	var ground := Ground.new()
	var records: Array = []
	# The turf's height under `p`, or NAN where it is not open turf.
	var probe := func(p: Vector2) -> float:
		var top := NAN
		for off: Vector2 in [Vector2.ZERO,Vector2(REACH,0.0),Vector2(-REACH,0.0),Vector2(0.0,REACH),Vector2(0.0,-REACH)]:
			ray.from = Vector3(p.x+off.x,Art.TOP+60.0,p.y+off.y)
			ray.to = Vector3(p.x+off.x,Art.TOP-8.0,p.y+off.y)
			var hit := space.intersect_ray(ray)
			if hit.is_empty() or not turf_ids.has((hit.collider as Object).get_instance_id()): return NAN
			var normal: Vector3 = hit.normal
			if normal.y <= 0.0 or sqrt(maxf(0.0,1.0-normal.y*normal.y))/normal.y > steep: return NAN
			if off == Vector2.ZERO: top = (hit.position as Vector3).y
		return top
	var inside := func(p: Vector2, rim: float) -> bool:
		for outline: PackedVector2Array in outlines:
			if Geometry2D.is_point_in_polygon(p,outline): return Art._edge_distance(p,outline) >= rim
		return false
	var add := func(asset: String, p: Vector2, size: float, extra := {}) -> bool:
		var h: float = probe.call(p)
		if is_nan(h): return false
		var item := {"id":records.size()+1,"asset":asset,"x":p.x,"z":p.y,"angle":rng.randf()*TAU,"scale":size}
		item.merge(extra,true)
		ground.heights[item.id] = h
		records.append(item)
		return true
	var area := 0.0
	var box := Rect2()
	for i in range(outlines.size()):
		var outline: PackedVector2Array = outlines[i]
		area += absf(Art._area(Array(outline)))
		var b := Rect2(outline[0],Vector2.ZERO)
		for q in outline: b = b.expand(q)
		box = b if i == 0 else box.merge(b)
	# Grass: thick in drifts, thinner between, thinning onto the paths.
	for n in range(int(box.get_area()*TUFTS)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var thick := clampf(0.6+drift.get_noise_2d(p.x,p.y)*1.3,THIN,1.0)
		var worn := Art.path_wear(p)
		if worn > PATH_BARE or rng.randf() > thick*(1.0-smoothstep(PATH_THIN,PATH_BARE,worn)): continue
		if not inside.call(p,RIM): continue
		add.call("grass_tuft",p,rng.randf_range(TUFT_SIZE.x,TUFT_SIZE.y)*lerpf(1.0,0.75,worn))
	# Flowers: the meadow type's drifts, sown sparse.
	var sizes: Dictionary = meadow.type.sizes
	for n in range(int(box.get_area()*FLOWER_TRIES)):
		var p := Vector2(rng.randf_range(box.position.x,box.end.x),rng.randf_range(box.position.y,box.end.y))
		var presence := meadow.presence(p)
		var kind := meadow.kind_at(p,rng.randf())
		var keep := pow(presence,1.2)*MeadowTypes.packing(kind)*FLOWER_SHARE
		if rng.randf() > maxf(keep,STRAY): continue
		if Art.path_wear(p) > PATH_THIN or not inside.call(p,RIM+0.3): continue
		var range_of: Array = sizes.get(kind,[0.85,1.1])
		var formed: Array = MeadowTypes.form(kind,rng.randf_range(float(range_of[0]),float(range_of[1])),rng.randf()*TAU)
		var extra := {}
		var tint := MeadowTypes.tint(kind,meadow.variant(p))
		if tint != "": extra.tint = tint
		if not (formed[1] as Dictionary).is_empty(): extra.pose = formed[1]
		add.call(MeadowTypes.asset(kind),p,float(formed[0]),extra)
	return _draw(records,ground,area)

## The records drawn as the islets draw theirs, one multimesh a tile and
## catalog part.
static func _draw(records: Array, ground: Ground, area: float) -> Node3D:
	var catalog: Dictionary = SkyIslets.catalog()
	var data: Dictionary = catalog.data
	var meshes: Dictionary = catalog.meshes
	# Records by tile, each built on its own so its parts stay together.
	var tiles := {}
	for item: Dictionary in records:
		var key := Vector2i(floori(float(item.x)/TILE),floori(float(item.z)/TILE))
		if not tiles.has(key): tiles[key] = []
		(tiles[key] as Array).append(item)
	var node := Node3D.new()
	node.name = "Flora"
	var instances := {}
	var triangles := 0
	for tile: Vector2i in tiles:
		var transforms := {}
		var sources := {}
		var tints := {}
		for item: Dictionary in tiles[tile]:
			Samples.add_item(item,ground,data.parts,data.poses,data.tints,data.world,false,transforms,sources,tints)
		for key: String in transforms:
			var list: Array = transforms[key]
			if list.is_empty() or not meshes.has(key): continue
			var colours: Array = tints[key]
			var multimesh := MultiMesh.new()
			multimesh.transform_format = MultiMesh.TRANSFORM_3D
			multimesh.use_colors = true
			multimesh.mesh = meshes[key]
			multimesh.instance_count = list.size()
			for i in range(list.size()):
				multimesh.set_instance_transform(i,list[i])
				multimesh.set_instance_color(i,colours[i] if i < colours.size() else Color.WHITE)
			var batch := MultiMeshInstance3D.new()
			batch.name = "%s_%d_%d" % [key.replace(":","_"),tile.x,tile.y]
			batch.multimesh = multimesh
			batch.material_override = SkyIslets._plant_material(key)
			batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			batch.visibility_range_end = GRASS_RANGE if key.begins_with("grass") else FLOWER_RANGE
			batch.visibility_range_end_margin = FADE
			batch.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			batch.set_meta("part",key)
			node.add_child(batch)
			instances[key] = int(instances.get(key,0))+list.size()
			triangles += _mesh_triangles(meshes[key])*list.size()
	var counts := {}
	for item: Dictionary in records: counts[item.asset] = int(counts.get(item.asset,0))+1
	node.set_meta("records",records)
	node.set_meta("counts",counts)
	node.set_meta("instances",instances)
	node.set_meta("triangles",triangles)
	node.set_meta("area",area)
	return node

static func _mesh_triangles(mesh: Mesh) -> int:
	var count := 0
	for s in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(s)
		var idx = arrays[Mesh.ARRAY_INDEX]
		count += (idx.size() if idx != null and idx is PackedInt32Array and idx.size() > 0 else (arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size())/3
	return count
